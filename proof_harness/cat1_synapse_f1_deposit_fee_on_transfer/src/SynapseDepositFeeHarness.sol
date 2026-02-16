// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IERC20Like {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/// @notice ERC20-like token that charges inbound fee when sent to a configured target.
contract MockInboundFeeToken {
    address public immutable feeCollector;
    uint16 public immutable inboundFeeBps;

    address public feeTarget;
    bool public feeTargetLocked;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor(address _feeCollector, uint16 _inboundFeeBps) {
        require(_feeCollector != address(0), "collector=0");
        require(_inboundFeeBps <= 10_000, "bps too high");
        feeCollector = _feeCollector;
        inboundFeeBps = _inboundFeeBps;
    }

    function setFeeTarget(address _feeTarget) external {
        require(!feeTargetLocked, "fee target locked");
        require(_feeTarget != address(0), "target=0");
        feeTarget = _feeTarget;
        feeTargetLocked = true;
    }

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _move(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (msg.sender != from) {
            uint256 allowed = allowance[from][msg.sender];
            require(allowed >= amount, "!allowance");
            unchecked {
                allowance[from][msg.sender] = allowed - amount;
            }
        }
        _move(from, to, amount);
        return true;
    }

    function _move(address from, address to, uint256 amount) internal {
        uint256 bal = balanceOf[from];
        require(bal >= amount, "!balance");
        unchecked {
            balanceOf[from] = bal - amount;
        }

        uint256 fee = 0;
        if (to == feeTarget && inboundFeeBps > 0) {
            fee = (amount * inboundFeeBps) / 10_000;
        }

        uint256 received = amount - fee;
        balanceOf[to] += received;
        if (fee > 0) balanceOf[feeCollector] += fee;
    }
}

/// @notice Model of SynapseBridge deposit/depositAndSwap accounting by intent amount.
/// Cross-chain credit intent (as consumed by off-chain relayers/nodes) is modeled as remoteLiability.
contract SynapseDepositBugModel {
    IERC20Like public immutable token;
    uint256 public remoteLiability;

    event TokenDeposit(uint256 amount);
    event TokenDepositAndSwap(uint256 amount);

    constructor(address _token) {
        require(_token != address(0), "token=0");
        token = IERC20Like(_token);
    }

    function deposit(uint256 amount) external {
        emit TokenDeposit(amount);
        require(token.transferFrom(msg.sender, address(this), amount), "transferFrom failed");
        remoteLiability += amount;
    }

    function depositAndSwap(uint256 amount) external {
        emit TokenDepositAndSwap(amount);
        require(token.transferFrom(msg.sender, address(this), amount), "transferFrom failed");
        remoteLiability += amount;
    }

    function collateral() external view returns (uint256) {
        return token.balanceOf(address(this));
    }
}

/// @notice Reference fix model: credit cross-chain amount by actual received collateral.
contract SynapseDepositFixedModel {
    IERC20Like public immutable token;
    uint256 public remoteLiability;

    event TokenDeposit(uint256 amount);
    event TokenDepositAndSwap(uint256 amount);

    constructor(address _token) {
        require(_token != address(0), "token=0");
        token = IERC20Like(_token);
    }

    function deposit(uint256 amount) external {
        uint256 balBefore = token.balanceOf(address(this));
        require(token.transferFrom(msg.sender, address(this), amount), "transferFrom failed");
        uint256 balAfter = token.balanceOf(address(this));
        require(balAfter >= balBefore, "balance decreased");
        uint256 received = balAfter - balBefore;
        emit TokenDeposit(received);
        remoteLiability += received;
    }

    function depositAndSwap(uint256 amount) external {
        uint256 balBefore = token.balanceOf(address(this));
        require(token.transferFrom(msg.sender, address(this), amount), "transferFrom failed");
        uint256 balAfter = token.balanceOf(address(this));
        require(balAfter >= balBefore, "balance decreased");
        uint256 received = balAfter - balBefore;
        emit TokenDepositAndSwap(received);
        remoteLiability += received;
    }

    function collateral() external view returns (uint256) {
        return token.balanceOf(address(this));
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IERC20LikeV2 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/// @notice ERC20-like token with optional sender-side transfer tax.
contract MockSenderTaxTokenV2 {
    address public immutable feeCollector;
    uint16 public immutable senderTaxBps;

    address public taxSender;
    bool public taxSenderLocked;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor(address _feeCollector, uint16 _senderTaxBps) {
        require(_feeCollector != address(0), "collector=0");
        require(_senderTaxBps <= 10_000, "bps too high");
        feeCollector = _feeCollector;
        senderTaxBps = _senderTaxBps;
    }

    function setTaxSender(address _taxSender) external {
        require(!taxSenderLocked, "tax sender locked");
        require(_taxSender != address(0), "tax sender=0");
        taxSender = _taxSender;
        taxSenderLocked = true;
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
        if (from == taxSender && senderTaxBps > 0) {
            fee = (amount * senderTaxBps) / 10_000;
        }

        uint256 received = amount - fee;
        balanceOf[to] += received;
        if (fee > 0) balanceOf[feeCollector] += fee;
    }
}

interface ISynapseRoleTarget {
    function grantNode(address account) external;
    function settleWithdraw(address payable to, uint256 amount) external;
}

contract RoleCaller {
    function callGrant(ISynapseRoleTarget target, address account) external {
        target.grantNode(account);
    }

    function callWithdraw(ISynapseRoleTarget target, address payable to, uint256 amount) external {
        target.settleWithdraw(to, amount);
    }
}

/// @notice F2 bug model: default admin can directly grant settlement role.
contract SynapseRoleEscalationBugModel is ISynapseRoleTarget {
    address public immutable defaultAdmin;
    mapping(address => bool) public isNode;
    mapping(address => uint256) public credited;
    uint256 public collateral;

    constructor(address _defaultAdmin, uint256 initialCollateral) {
        require(_defaultAdmin != address(0), "admin=0");
        defaultAdmin = _defaultAdmin;
        collateral = initialCollateral;
    }

    function grantNode(address account) external override {
        require(msg.sender == defaultAdmin, "!admin");
        isNode[account] = true;
    }

    function settleWithdraw(address payable to, uint256 amount) external override {
        require(isNode[msg.sender], "!node");
        require(collateral >= amount, "!collateral");
        unchecked {
            collateral -= amount;
        }
        credited[to] += amount;
    }
}

/// @notice F2 fixed model: settlement role assignment requires governance actor.
contract SynapseRoleEscalationFixedModel is ISynapseRoleTarget {
    address public immutable defaultAdmin;
    address public immutable governance;
    mapping(address => bool) public isNode;
    mapping(address => uint256) public credited;
    uint256 public collateral;

    constructor(address _defaultAdmin, address _governance, uint256 initialCollateral) {
        require(_defaultAdmin != address(0), "admin=0");
        require(_governance != address(0), "gov=0");
        defaultAdmin = _defaultAdmin;
        governance = _governance;
        collateral = initialCollateral;
    }

    function grantNode(address account) external override {
        require(msg.sender == governance, "!governance");
        isNode[account] = true;
    }

    function settleWithdraw(address payable to, uint256 amount) external override {
        require(isNode[msg.sender], "!node");
        require(collateral >= amount, "!collateral");
        unchecked {
            collateral -= amount;
        }
        credited[to] += amount;
    }
}

/// @notice F3 bug model: minOut check is applied to quoted swap amount, not to user receipt.
contract SynapseMinOutBugModel {
    IERC20LikeV2 public immutable token;

    event SwapSettled(address indexed to, uint256 quotedOut, uint256 minOut, uint256 actualReceived);

    constructor(address _token) {
        require(_token != address(0), "token=0");
        token = IERC20LikeV2(_token);
    }

    function settleSwap(address to, uint256 quotedOut, uint256 minOut) external returns (uint256 actualReceived) {
        require(to != address(0), "to=0");
        require(quotedOut >= minOut, "quoted<min");
        uint256 beforeBal = token.balanceOf(to);
        require(token.transfer(to, quotedOut), "transfer failed");
        uint256 afterBal = token.balanceOf(to);
        require(afterBal >= beforeBal, "balance decreased");
        actualReceived = afterBal - beforeBal;
        emit SwapSettled(to, quotedOut, minOut, actualReceived);
    }
}

/// @notice F3 fixed model: enforce minOut against actual recipient delta.
contract SynapseMinOutFixedModel {
    IERC20LikeV2 public immutable token;

    event SwapSettled(address indexed to, uint256 quotedOut, uint256 minOut, uint256 actualReceived);

    constructor(address _token) {
        require(_token != address(0), "token=0");
        token = IERC20LikeV2(_token);
    }

    function settleSwap(address to, uint256 quotedOut, uint256 minOut) external returns (uint256 actualReceived) {
        require(to != address(0), "to=0");
        require(quotedOut >= minOut, "quoted<min");
        uint256 beforeBal = token.balanceOf(to);
        require(token.transfer(to, quotedOut), "transfer failed");
        uint256 afterBal = token.balanceOf(to);
        require(afterBal >= beforeBal, "balance decreased");
        actualReceived = afterBal - beforeBal;
        require(actualReceived >= minOut, "received<min");
        emit SwapSettled(to, quotedOut, minOut, actualReceived);
    }
}

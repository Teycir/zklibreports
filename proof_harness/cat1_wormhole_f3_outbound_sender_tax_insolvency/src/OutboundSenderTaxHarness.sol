// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IERC20Like {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/// @notice ERC20-like token where bridge-originated transfers can debit sender by
/// amount + extra fee (sender-tax mode).
contract MockBridgeSenderTaxToken {
    string public constant name = "Bridge Sender Tax Token";
    string public constant symbol = "BST";
    uint8 public constant decimals = 18;

    address public immutable bridge;
    address public immutable feeCollector;
    uint16 public immutable bridgeSenderTaxBps;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor(address _bridge, address _feeCollector, uint16 _bridgeSenderTaxBps) {
        require(_bridge != address(0), "bridge=0");
        require(_feeCollector != address(0), "collector=0");
        require(_bridgeSenderTaxBps <= 10_000, "bps too high");
        bridge = _bridge;
        feeCollector = _feeCollector;
        bridgeSenderTaxBps = _bridgeSenderTaxBps;
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

    function transferFrom(address from, address to, uint256 amount)
        external
        returns (bool)
    {
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
        uint256 senderTax = 0;
        if (from == bridge && bridgeSenderTaxBps > 0) {
            senderTax = (amount * bridgeSenderTaxBps) / 10_000;
        }

        uint256 totalDebit = amount + senderTax;
        uint256 bal = balanceOf[from];
        require(bal >= totalDebit, "!balance");
        unchecked {
            balanceOf[from] = bal - totalDebit;
        }

        balanceOf[to] += amount;
        if (senderTax > 0) {
            balanceOf[feeCollector] += senderTax;
        }
    }
}

/// @notice Model that mirrors Wormhole native-token accounting shape:
/// inbound measures received amount, outbound debits outstanding by requested amount.
contract OutboundSenderTaxBugModel {
    mapping(address => uint256) public outstanding;

    function depositAndBridgeOut(address token, address from, uint256 amount)
        external
        returns (uint256 received)
    {
        uint256 balBefore = IERC20Like(token).balanceOf(address(this));
        require(
            IERC20Like(token).transferFrom(from, address(this), amount),
            "transferFrom failed"
        );
        uint256 balAfter = IERC20Like(token).balanceOf(address(this));
        received = balAfter - balBefore;
        outstanding[token] += received;
    }

    function completeTransfer(address token, address recipient, uint256 amount) external {
        require(outstanding[token] >= amount, "insufficient outstanding");
        unchecked {
            outstanding[token] -= amount;
        }
        require(IERC20Like(token).transfer(recipient, amount), "transfer failed");
    }

    function collateral(address token) external view returns (uint256) {
        return IERC20Like(token).balanceOf(address(this));
    }
}

/// @notice Reference fix model:
/// require bridge-side debit to equal logical redeemed amount.
contract OutboundSenderTaxFixedModel {
    mapping(address => uint256) public outstanding;

    function depositAndBridgeOut(address token, address from, uint256 amount)
        external
        returns (uint256 received)
    {
        uint256 balBefore = IERC20Like(token).balanceOf(address(this));
        require(
            IERC20Like(token).transferFrom(from, address(this), amount),
            "transferFrom failed"
        );
        uint256 balAfter = IERC20Like(token).balanceOf(address(this));
        received = balAfter - balBefore;
        outstanding[token] += received;
    }

    function completeTransfer(address token, address recipient, uint256 amount) external {
        require(outstanding[token] >= amount, "insufficient outstanding");

        uint256 balBefore = IERC20Like(token).balanceOf(address(this));
        require(IERC20Like(token).transfer(recipient, amount), "transfer failed");
        uint256 balAfter = IERC20Like(token).balanceOf(address(this));

        require(balBefore >= balAfter, "balance increased");
        require(balBefore - balAfter == amount, "unexpected sender-side debit");

        unchecked {
            outstanding[token] -= amount;
        }
    }

    function collateral(address token) external view returns (uint256) {
        return IERC20Like(token).balanceOf(address(this));
    }
}


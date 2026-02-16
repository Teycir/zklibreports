// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IERC20Like {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/// @notice ERC20-like token that can charge extra sender-side debit for one configured sender.
/// Recipient still receives the full requested amount.
contract MockSenderDebitTaxToken {
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
        uint256 tax = 0;
        if (from == taxSender && senderTaxBps > 0) {
            tax = (amount * senderTaxBps) / 10_000;
        }

        uint256 debit = amount + tax;
        uint256 bal = balanceOf[from];
        require(bal >= debit, "!balance");

        unchecked {
            balanceOf[from] = bal - debit;
        }
        balanceOf[to] += amount;
        if (tax > 0) balanceOf[feeCollector] += tax;
    }
}

/// @notice Bug model for Connext `bumpTransfer` style fee flow:
/// pull relayer fee in exactly, then transfer out without sender-debit validation.
contract ConnextBumpTransferBugModel {
    IERC20Like public immutable token;
    address public immutable relayerVault;

    mapping(address => uint256) public routerBalances;
    uint256 public totalRouterBalances;

    constructor(address _token, address _relayerVault) {
        require(_token != address(0), "token=0");
        require(_relayerVault != address(0), "vault=0");
        token = IERC20Like(_token);
        relayerVault = _relayerVault;
    }

    /// @notice Seed router liabilities/collateral to model an in-use bridge.
    function addRouterLiquidity(address router, uint256 amount) external {
        require(router != address(0), "router=0");
        require(amount > 0, "amount=0");
        require(token.transferFrom(msg.sender, address(this), amount), "transferFrom failed");
        routerBalances[router] += amount;
        totalRouterBalances += amount;
    }

    /// @notice Models ERC20 relayer-fee bump path.
    function bumpTransferLike(uint256 relayerFee) external {
        require(relayerFee > 0, "fee=0");

        // Incoming leg with exact-delta validation (mirrors handleIncomingAsset).
        uint256 start = token.balanceOf(address(this));
        require(token.transferFrom(msg.sender, address(this), relayerFee), "transferFrom failed");
        require(token.balanceOf(address(this)) - start == relayerFee, "fee-on-transfer in unsupported");

        // Outgoing leg with no sender-debit validation (mirrors handleOutgoingAsset).
        require(token.transfer(relayerVault, relayerFee), "transfer failed");
    }

    function collateral() external view returns (uint256) {
        return token.balanceOf(address(this));
    }
}

/// @notice Fixed reference model: reject sender-tax payouts by validating sender-side debit on outgoing fee transfer.
contract ConnextBumpTransferFixedModel {
    IERC20Like public immutable token;
    address public immutable relayerVault;

    mapping(address => uint256) public routerBalances;
    uint256 public totalRouterBalances;

    constructor(address _token, address _relayerVault) {
        require(_token != address(0), "token=0");
        require(_relayerVault != address(0), "vault=0");
        token = IERC20Like(_token);
        relayerVault = _relayerVault;
    }

    function addRouterLiquidity(address router, uint256 amount) external {
        require(router != address(0), "router=0");
        require(amount > 0, "amount=0");
        require(token.transferFrom(msg.sender, address(this), amount), "transferFrom failed");
        routerBalances[router] += amount;
        totalRouterBalances += amount;
    }

    function bumpTransferLike(uint256 relayerFee) external {
        require(relayerFee > 0, "fee=0");

        uint256 start = token.balanceOf(address(this));
        require(token.transferFrom(msg.sender, address(this), relayerFee), "transferFrom failed");
        require(token.balanceOf(address(this)) - start == relayerFee, "fee-on-transfer in unsupported");

        uint256 beforeBal = token.balanceOf(address(this));
        require(token.transfer(relayerVault, relayerFee), "transfer failed");
        uint256 afterBal = token.balanceOf(address(this));
        require(beforeBal >= afterBal, "balance increased");
        require(beforeBal - afterBal == relayerFee, "sender-tax unsupported");
    }

    function collateral() external view returns (uint256) {
        return token.balanceOf(address(this));
    }
}

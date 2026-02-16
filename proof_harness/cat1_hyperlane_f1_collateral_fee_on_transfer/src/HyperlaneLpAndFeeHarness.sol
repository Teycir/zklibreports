// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IERC20LikeV2 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/// @notice ERC20-like token with inbound transfer fee when tokens are sent to feeTarget.
contract MockInboundFeeTokenV2 {
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
        if (fee > 0) {
            balanceOf[feeCollector] += fee;
        }
    }
}

/// @notice ERC20-like token that charges sender-side extra debit for transfers from taxSender.
contract MockSenderTaxTokenV2 {
    address public taxSender;
    bool public taxSenderLocked;
    address public immutable feeCollector;
    uint16 public immutable senderTaxBps;

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
        require(_taxSender != address(0), "taxSender=0");
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
        uint256 extra = 0;
        if (from == taxSender && senderTaxBps > 0) {
            extra = (amount * senderTaxBps) / 10_000;
        }

        uint256 debit = amount + extra;
        uint256 bal = balanceOf[from];
        require(bal >= debit, "!balance");
        unchecked {
            balanceOf[from] = bal - debit;
        }

        balanceOf[to] += amount;
        if (extra > 0) {
            balanceOf[feeCollector] += extra;
        }
    }
}

/// @notice Model of LpCollateralRouter accounting where lpAssets tracks requested deposit amount.
contract HyperlaneLpAssetsBugModel {
    IERC20LikeV2 public immutable token;
    uint256 public lpAssets;
    mapping(address => uint256) public shares;

    constructor(address _token) {
        require(_token != address(0), "token=0");
        token = IERC20LikeV2(_token);
    }

    function deposit(uint256 assets) external {
        require(token.transferFrom(msg.sender, address(this), assets), "transferFrom failed");
        lpAssets += assets;
        shares[msg.sender] += assets;
    }

    function withdraw(uint256 assets) external {
        require(shares[msg.sender] >= assets, "insufficient shares");
        unchecked {
            shares[msg.sender] -= assets;
        }
        lpAssets -= assets;
        require(token.transfer(msg.sender, assets), "transfer failed");
    }

    function collateral() external view returns (uint256) {
        return token.balanceOf(address(this));
    }
}

/// @notice Reference fix: lpAssets tracks actual token delta received.
contract HyperlaneLpAssetsFixedModel {
    IERC20LikeV2 public immutable token;
    uint256 public lpAssets;
    mapping(address => uint256) public shares;

    constructor(address _token) {
        require(_token != address(0), "token=0");
        token = IERC20LikeV2(_token);
    }

    function deposit(uint256 assets) external {
        uint256 balBefore = token.balanceOf(address(this));
        require(token.transferFrom(msg.sender, address(this), assets), "transferFrom failed");
        uint256 balAfter = token.balanceOf(address(this));
        require(balAfter >= balBefore, "balance decreased");
        uint256 received = balAfter - balBefore;

        lpAssets += received;
        shares[msg.sender] += received;
    }

    function withdraw(uint256 assets) external {
        require(shares[msg.sender] >= assets, "insufficient shares");
        unchecked {
            shares[msg.sender] -= assets;
        }
        lpAssets -= assets;
        require(token.transfer(msg.sender, assets), "transfer failed");
    }

    function collateral() external view returns (uint256) {
        return token.balanceOf(address(this));
    }
}

/// @notice Model of TokenRouter fee flow where sender-tax on `_transferFee` can drain extra collateral.
contract HyperlaneFeeTransferBugModel {
    IERC20LikeV2 public immutable token;
    address public immutable feeRecipient;
    uint256 public remoteLiabilityLD;

    constructor(address _token, address _feeRecipient) {
        require(_token != address(0), "token=0");
        require(_feeRecipient != address(0), "feeRecipient=0");
        token = IERC20LikeV2(_token);
        feeRecipient = _feeRecipient;
    }

    function transferRemoteWithFee(uint256 amountLD, uint256 feeAmountLD) external {
        uint256 charge = amountLD + feeAmountLD;
        require(token.transferFrom(msg.sender, address(this), charge), "transferFrom failed");
        if (feeAmountLD > 0) {
            require(token.transfer(feeRecipient, feeAmountLD), "fee transfer failed");
        }
        remoteLiabilityLD += amountLD;
    }

    function collateralLD() external view returns (uint256) {
        return token.balanceOf(address(this));
    }
}

/// @notice Reference fix: assert sender-side debit for fee transfer equals logical fee amount.
contract HyperlaneFeeTransferFixedModel {
    IERC20LikeV2 public immutable token;
    address public immutable feeRecipient;
    uint256 public remoteLiabilityLD;

    constructor(address _token, address _feeRecipient) {
        require(_token != address(0), "token=0");
        require(_feeRecipient != address(0), "feeRecipient=0");
        token = IERC20LikeV2(_token);
        feeRecipient = _feeRecipient;
    }

    function transferRemoteWithFee(uint256 amountLD, uint256 feeAmountLD) external {
        uint256 charge = amountLD + feeAmountLD;
        require(token.transferFrom(msg.sender, address(this), charge), "transferFrom failed");

        if (feeAmountLD > 0) {
            uint256 balBefore = token.balanceOf(address(this));
            require(token.transfer(feeRecipient, feeAmountLD), "fee transfer failed");
            uint256 balAfter = token.balanceOf(address(this));
            require(balBefore >= balAfter, "balance increased");
            require(balBefore - balAfter == feeAmountLD, "unexpected sender debit");
        }

        remoteLiabilityLD += amountLD;
    }

    function collateralLD() external view returns (uint256) {
        return token.balanceOf(address(this));
    }
}

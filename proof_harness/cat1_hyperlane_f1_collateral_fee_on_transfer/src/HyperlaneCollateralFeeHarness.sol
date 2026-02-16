// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IERC20Like {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/// @notice Minimal ERC20-like token that charges a fee when tokens are transferred
/// into a configured target address.
contract MockInboundFeeToken {
    string public constant name = "Inbound Fee Token";
    string public constant symbol = "IFT";
    uint8 public constant decimals = 18;

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

/// @notice Model of Hyperlane TokenRouter + ERC20Collateral amount accounting:
/// `transferRemote` charges by intent and credits remote liability by intent.
contract HyperlaneCollateralBugModel {
    IERC20Like public immutable token;
    uint256 public remoteLiabilityLD;
    uint256 public immutable scale;

    constructor(address _token, uint256 _scale) {
        require(_token != address(0), "token=0");
        require(_scale > 0, "scale=0");
        token = IERC20Like(_token);
        scale = _scale;
    }

    function transferRemote(uint256 amountLD, uint256 minAmountLD) external returns (uint256 amountSentLD, uint256 amountReceivedLD) {
        amountSentLD = amountLD;

        // Mirrors `_transferFromSender` via ERC20Collateral.safeTransferFrom with no balance-delta measurement.
        require(token.transferFrom(msg.sender, address(this), amountSentLD), "transferFrom failed");

        uint256 scaledAmount = _outboundAmount(amountLD);
        amountReceivedLD = _inboundAmount(scaledAmount);
        require(amountReceivedLD >= minAmountLD, "slippage exceeded");

        remoteLiabilityLD += amountReceivedLD;
    }

    function collateralLD() external view returns (uint256) {
        return token.balanceOf(address(this));
    }

    function _outboundAmount(uint256 _localAmount) internal view returns (uint256) {
        return _localAmount * scale;
    }

    function _inboundAmount(uint256 _messageAmount) internal view returns (uint256) {
        return _messageAmount / scale;
    }
}

/// @notice Reference-fix model: credits remote liability by actual collateral received.
contract HyperlaneCollateralFixedModel {
    IERC20Like public immutable token;
    uint256 public remoteLiabilityLD;
    uint256 public immutable scale;

    constructor(address _token, uint256 _scale) {
        require(_token != address(0), "token=0");
        require(_scale > 0, "scale=0");
        token = IERC20Like(_token);
        scale = _scale;
    }

    function transferRemote(uint256 amountLD, uint256 minAmountLD) external returns (uint256 amountSentLD, uint256 amountReceivedLD) {
        amountSentLD = amountLD;
        uint256 balBefore = token.balanceOf(address(this));
        require(token.transferFrom(msg.sender, address(this), amountSentLD), "transferFrom failed");
        uint256 balAfter = token.balanceOf(address(this));
        require(balAfter >= balBefore, "balance decreased");

        uint256 actualReceivedLD = balAfter - balBefore;
        uint256 scaledAmount = _outboundAmount(actualReceivedLD);
        amountReceivedLD = _inboundAmount(scaledAmount);
        require(amountReceivedLD >= minAmountLD, "slippage exceeded");

        remoteLiabilityLD += amountReceivedLD;
    }

    function collateralLD() external view returns (uint256) {
        return token.balanceOf(address(this));
    }

    function _outboundAmount(uint256 _localAmount) internal view returns (uint256) {
        return _localAmount * scale;
    }

    function _inboundAmount(uint256 _messageAmount) internal view returns (uint256) {
        return _messageAmount / scale;
    }
}

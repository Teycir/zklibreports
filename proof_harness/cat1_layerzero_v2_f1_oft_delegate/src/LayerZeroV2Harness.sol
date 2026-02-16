// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IERC20Like {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/// @notice Minimal ERC20-like token that charges an inbound fee when tokens are
/// transferred into a configured target (for example, an OFT adapter).
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

/// @notice Model of OFTAdapter debit semantics from LayerZero-v2:
/// amountReceived is inferred from amount intent (not actual token received).
contract OFTAdapterBugModel {
    IERC20Like public immutable token;
    uint256 public remoteLiabilityLD;

    constructor(address _token) {
        require(_token != address(0), "token=0");
        token = IERC20Like(_token);
    }

    function send(uint256 amountLD, uint256 minAmountLD) external returns (uint256 amountSentLD, uint256 amountReceivedLD) {
        (amountSentLD, amountReceivedLD) = _debitView(amountLD, minAmountLD);
        require(token.transferFrom(msg.sender, address(this), amountSentLD), "transferFrom failed");
        remoteLiabilityLD += amountReceivedLD;
    }

    function _debitView(uint256 amountLD, uint256 minAmountLD) internal pure returns (uint256 amountSentLD, uint256 amountReceivedLD) {
        amountSentLD = amountLD;
        amountReceivedLD = amountLD;
        require(amountReceivedLD >= minAmountLD, "slippage exceeded");
    }

    function collateralLD() external view returns (uint256) {
        return token.balanceOf(address(this));
    }
}

/// @notice Reference fix model: tracks actual tokens received by the adapter.
contract OFTAdapterFixedModel {
    IERC20Like public immutable token;
    uint256 public remoteLiabilityLD;

    constructor(address _token) {
        require(_token != address(0), "token=0");
        token = IERC20Like(_token);
    }

    function send(uint256 amountLD, uint256 minAmountLD) external returns (uint256 amountSentLD, uint256 amountReceivedLD) {
        amountSentLD = amountLD;
        uint256 balBefore = token.balanceOf(address(this));
        require(token.transferFrom(msg.sender, address(this), amountSentLD), "transferFrom failed");
        uint256 balAfter = token.balanceOf(address(this));

        require(balAfter >= balBefore, "balance decreased");
        amountReceivedLD = balAfter - balBefore;
        require(amountReceivedLD >= minAmountLD, "slippage exceeded");

        remoteLiabilityLD += amountReceivedLD;
    }

    function collateralLD() external view returns (uint256) {
        return token.balanceOf(address(this));
    }
}

/// @notice Minimal endpoint auth model from LayerZero-v2:
/// calls are authorized for _oapp or endpoint-side delegate of _oapp.
contract EndpointDelegateAuthModel {
    error Unauthorized();

    address public constant BLOCKED_LIBRARY = address(0xB10C);

    mapping(address oapp => address delegate) public delegates;
    mapping(address oapp => mapping(uint32 eid => address lib)) public sendLibrary;

    function setDelegate(address _delegate) external {
        delegates[msg.sender] = _delegate;
    }

    function setSendLibrary(address _oapp, uint32 _eid, address _newLib) external {
        if (msg.sender != _oapp && msg.sender != delegates[_oapp]) revert Unauthorized();
        sendLibrary[_oapp][_eid] = _newLib;
    }
}

/// @notice Bug model: ownership transfer does not rotate endpoint delegate.
contract BuggyOAppOwnershipModel {
    EndpointDelegateAuthModel public immutable endpoint;
    address public owner;

    constructor(address _endpoint, address _delegate) {
        require(_endpoint != address(0), "endpoint=0");
        require(_delegate != address(0), "delegate=0");
        endpoint = EndpointDelegateAuthModel(_endpoint);
        owner = msg.sender;
        endpoint.setDelegate(_delegate);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "newOwner=0");
        owner = _newOwner;
    }

    function setDelegate(address _delegate) external onlyOwner {
        endpoint.setDelegate(_delegate);
    }
}

/// @notice Fixed model: rotate endpoint delegate during ownership transfer.
contract FixedOAppOwnershipModel {
    EndpointDelegateAuthModel public immutable endpoint;
    address public owner;

    constructor(address _endpoint, address _delegate) {
        require(_endpoint != address(0), "endpoint=0");
        require(_delegate != address(0), "delegate=0");
        endpoint = EndpointDelegateAuthModel(_endpoint);
        owner = msg.sender;
        endpoint.setDelegate(_delegate);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "newOwner=0");
        owner = _newOwner;
        endpoint.setDelegate(_newOwner);
    }

    function setDelegate(address _delegate) external onlyOwner {
        endpoint.setDelegate(_delegate);
    }
}

/// @notice Model of EndpointV2 lzToken fee accounting where supplied fee is
/// derived from total endpoint token balance (including preloaded residual).
contract EndpointLzTokenSweepBugModel {
    IERC20Like public immutable token;
    address public immutable feeSink;
    uint256 public immutable lzTokenFee;

    constructor(address _token, address _feeSink, uint256 _lzTokenFee) {
        require(_token != address(0), "token=0");
        require(_feeSink != address(0), "feeSink=0");
        token = IERC20Like(_token);
        feeSink = _feeSink;
        lzTokenFee = _lzTokenFee;
    }

    function preloadResidual(uint256 amount) external {
        require(token.transferFrom(msg.sender, address(this), amount), "preload transfer failed");
    }

    function sendWithPayInLzToken(address refundAddress) external returns (uint256 refunded) {
        uint256 supplied = token.balanceOf(address(this));
        require(supplied > 0, "zero supplied");
        require(supplied >= lzTokenFee, "insufficient lzToken");

        require(token.transfer(feeSink, lzTokenFee), "fee transfer failed");
        if (supplied > lzTokenFee) {
            refunded = supplied - lzTokenFee;
            require(token.transfer(refundAddress, refunded), "refund failed");
        }
    }
}

/// @notice Reference fix model: isolates caller-supplied fee deltas and does
/// not consume/refund pre-existing residual token balances.
contract EndpointLzTokenSweepFixedModel {
    IERC20Like public immutable token;
    address public immutable feeSink;
    uint256 public immutable lzTokenFee;

    constructor(address _token, address _feeSink, uint256 _lzTokenFee) {
        require(_token != address(0), "token=0");
        require(_feeSink != address(0), "feeSink=0");
        token = IERC20Like(_token);
        feeSink = _feeSink;
        lzTokenFee = _lzTokenFee;
    }

    function preloadResidual(uint256 amount) external {
        require(token.transferFrom(msg.sender, address(this), amount), "preload transfer failed");
    }

    function sendWithIsolatedPayment(address refundAddress, uint256 callerSupplied) external returns (uint256 refunded) {
        uint256 balBefore = token.balanceOf(address(this));
        require(token.transferFrom(msg.sender, address(this), callerSupplied), "payment transfer failed");
        uint256 balAfter = token.balanceOf(address(this));
        uint256 supplied = balAfter - balBefore;

        require(supplied >= lzTokenFee, "insufficient supplied");
        require(token.transfer(feeSink, lzTokenFee), "fee transfer failed");
        if (supplied > lzTokenFee) {
            refunded = supplied - lzTokenFee;
            require(token.transfer(refundAddress, refunded), "refund failed");
        }
    }
}

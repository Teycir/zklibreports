// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IBridgeRedeemer {
    function completeTransfer(bytes32 vmHash) external;
}

interface IERC20LikeR {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

struct ReplayTransfer {
    address token;
    address recipient;
    uint256 amount;
    bool valid;
}

/// @notice Token that can reenter bridge redemption once during bridge-originated transfer.
contract MockReentrantToken {
    string public constant name = "Reentrant Token";
    string public constant symbol = "RNT";
    uint8 public constant decimals = 18;

    address public immutable bridge;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    bool public hookEnabled;
    bool public entered;
    bytes32 public hookVmHash;

    constructor(address _bridge) {
        require(_bridge != address(0), "bridge=0");
        bridge = _bridge;
    }

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function configureHook(bytes32 vmHash, bool enabled) external {
        hookVmHash = vmHash;
        hookEnabled = enabled;
        entered = false;
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
        uint256 bal = balanceOf[from];
        require(bal >= amount, "!balance");
        unchecked {
            balanceOf[from] = bal - amount;
        }
        balanceOf[to] += amount;

        if (from == bridge && hookEnabled && !entered) {
            entered = true;
            // Reentrancy trigger is intentionally swallowed if rejected.
            try IBridgeRedeemer(bridge).completeTransfer(hookVmHash) {} catch {}
        }
    }
}

/// @notice Control bug model: marks transfer completed after external token transfer.
/// This ordering is intentionally vulnerable to same-VM reentrancy double redemption.
contract BridgeReplayBugModel is IBridgeRedeemer {
    mapping(address => uint256) public outstanding;
    mapping(bytes32 => bool) public completed;
    mapping(bytes32 => uint256) public redeemCount;
    mapping(bytes32 => ReplayTransfer) public transfers;

    function seed(address token, address from, uint256 amount) external {
        require(IERC20LikeR(token).transferFrom(from, address(this), amount), "seed transferFrom failed");
        outstanding[token] += amount;
    }

    function registerTransfer(
        bytes32 vmHash,
        address token,
        address recipient,
        uint256 amount
    ) external {
        transfers[vmHash] = ReplayTransfer({
            token: token,
            recipient: recipient,
            amount: amount,
            valid: true
        });
    }

    function completeTransfer(bytes32 vmHash) external override {
        ReplayTransfer memory t = transfers[vmHash];
        require(t.valid, "invalid vm");
        require(!completed[vmHash], "transfer already completed");
        require(outstanding[t.token] >= t.amount, "insufficient outstanding");

        require(IERC20LikeR(t.token).transfer(t.recipient, t.amount), "transfer failed");

        completed[vmHash] = true;
        unchecked {
            outstanding[t.token] -= t.amount;
        }
        redeemCount[vmHash] += 1;
    }
}

/// @notice Guard model matching Wormhole's key safety ordering:
/// mark completed and update accounting before external token transfer.
contract BridgeReplayGuardModel is IBridgeRedeemer {
    mapping(address => uint256) public outstanding;
    mapping(bytes32 => bool) public completed;
    mapping(bytes32 => uint256) public redeemCount;
    mapping(bytes32 => ReplayTransfer) public transfers;

    function seed(address token, address from, uint256 amount) external {
        require(IERC20LikeR(token).transferFrom(from, address(this), amount), "seed transferFrom failed");
        outstanding[token] += amount;
    }

    function registerTransfer(
        bytes32 vmHash,
        address token,
        address recipient,
        uint256 amount
    ) external {
        transfers[vmHash] = ReplayTransfer({
            token: token,
            recipient: recipient,
            amount: amount,
            valid: true
        });
    }

    function completeTransfer(bytes32 vmHash) external override {
        ReplayTransfer memory t = transfers[vmHash];
        require(t.valid, "invalid vm");
        require(!completed[vmHash], "transfer already completed");
        completed[vmHash] = true;
        require(outstanding[t.token] >= t.amount, "insufficient outstanding");
        unchecked {
            outstanding[t.token] -= t.amount;
        }

        require(IERC20LikeR(t.token).transfer(t.recipient, t.amount), "transfer failed");
        redeemCount[vmHash] += 1;
    }
}


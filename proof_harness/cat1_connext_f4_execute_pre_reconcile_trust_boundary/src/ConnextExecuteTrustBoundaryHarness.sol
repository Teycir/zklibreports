// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IXReceiverLike {
    function xReceive(
        bytes32 _transferId,
        uint256 _amount,
        address _asset,
        address _originSender,
        uint32 _origin,
        bytes calldata _callData
    ) external returns (bytes memory);
}

contract MockToken {
    mapping(address => uint256) public balanceOf;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        uint256 fromBal = balanceOf[msg.sender];
        require(fromBal >= amount, "!balance");
        unchecked {
            balanceOf[msg.sender] = fromBal - amount;
        }
        balanceOf[to] += amount;
        return true;
    }
}

enum DestinationTransferStatus {
    None,
    Reconciled,
    Executed,
    Completed
}

struct ExecuteParams {
    address to;
    address originSender;
    uint32 originDomain;
    bytes callData;
}

/// @notice Minimal model for execute/reconcile trust boundary behavior.
/// Captures the critical semantics:
/// - fast path (`useRouters=true`) passes unauthenticated `originSender=0` and reverts loudly if calldata call fails.
/// - slow/reconciled path passes authenticated originSender and swallows calldata failure.
contract ConnextExecuteTrustBoundaryModel {
    MockToken public immutable token;
    mapping(bytes32 => DestinationTransferStatus) internal status;

    constructor(address _token) {
        require(_token != address(0), "token=0");
        token = MockToken(_token);
    }

    function transferStatus(bytes32 transferId) external view returns (DestinationTransferStatus) {
        return status[transferId];
    }

    function reconcile(bytes32 transferId) external {
        DestinationTransferStatus st = status[transferId];
        require(st == DestinationTransferStatus.None || st == DestinationTransferStatus.Executed, "already reconciled");
        status[transferId] = st == DestinationTransferStatus.None
            ? DestinationTransferStatus.Reconciled
            : DestinationTransferStatus.Completed;
    }

    function execute(ExecuteParams calldata params, bytes32 transferId, uint256 amount, bool useRouters) external {
        DestinationTransferStatus st = status[transferId];
        if (useRouters) {
            require(st == DestinationTransferStatus.None, "bad fast status");
            status[transferId] = DestinationTransferStatus.Executed;
        } else {
            require(st == DestinationTransferStatus.Reconciled, "not reconciled");
            status[transferId] = DestinationTransferStatus.Completed;
        }

        // Mirrors BridgeFacet ordering: transfer first, then external calldata call.
        require(token.transfer(params.to, amount), "transfer failed");

        (bool success, ) = params.to.call(
            abi.encodeWithSelector(
                IXReceiverLike.xReceive.selector,
                transferId,
                amount,
                address(token),
                useRouters ? address(0) : params.originSender,
                params.originDomain,
                params.callData
            )
        );

        if (useRouters && !success) {
            revert("external call failed on fast path");
        }
    }
}

/// @notice Strict destination receiver: requires authenticated origin sender.
contract StrictReceiver is IXReceiverLike {
    address public immutable connext;
    address public immutable trustedOriginSender;

    uint256 public successfulCalls;
    address public lastOriginSender;

    constructor(address _connext, address _trustedOriginSender) {
        require(_connext != address(0), "connext=0");
        require(_trustedOriginSender != address(0), "trusted=0");
        connext = _connext;
        trustedOriginSender = _trustedOriginSender;
    }

    function xReceive(
        bytes32,
        uint256,
        address,
        address originSender,
        uint32,
        bytes calldata
    ) external returns (bytes memory) {
        require(msg.sender == connext, "!connext");
        require(originSender == trustedOriginSender, "!origin");
        successfulCalls += 1;
        lastOriginSender = originSender;
        return bytes("");
    }
}

/// @notice Lenient destination receiver: accepts whatever origin sender is provided.
contract LenientReceiver is IXReceiverLike {
    address public immutable connext;

    uint256 public calls;
    address public lastOriginSender;

    constructor(address _connext) {
        require(_connext != address(0), "connext=0");
        connext = _connext;
    }

    function xReceive(
        bytes32,
        uint256,
        address,
        address originSender,
        uint32,
        bytes calldata
    ) external returns (bytes memory) {
        require(msg.sender == connext, "!connext");
        calls += 1;
        lastOriginSender = originSender;
        return bytes("");
    }
}

/// @notice Receiver that always reverts to model reconciled-path fail-open semantics.
contract RevertingReceiver is IXReceiverLike {
    address public immutable connext;

    constructor(address _connext) {
        require(_connext != address(0), "connext=0");
        connext = _connext;
    }

    function xReceive(
        bytes32,
        uint256,
        address,
        address,
        uint32,
        bytes calldata
    ) external returns (bytes memory) {
        require(msg.sender == connext, "!connext");
        revert("receiver revert");
    }
}

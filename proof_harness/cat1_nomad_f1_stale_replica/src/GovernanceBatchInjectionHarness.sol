// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IXcmReplicaViewBatch {
    function isReplica(address _replica) external view returns (bool);
}

/// @notice Minimal governance batch codec and hashing to model Nomad batch handling.
library GovernanceBatchMessageLite {
    uint8 internal constant BATCH = 1;
    uint256 internal constant BATCH_LEN = 33;

    struct Call {
        bytes32 to;
        bytes data;
    }

    enum BatchStatus {
        Unknown,
        Pending,
        Complete
    }

    function formatBatch(bytes32 _batchHash) internal pure returns (bytes memory) {
        return abi.encodePacked(bytes1(BATCH), _batchHash);
    }

    function isBatch(bytes memory _message) internal pure returns (bool) {
        return _message.length == BATCH_LEN && uint8(_message[0]) == BATCH;
    }

    function batchHash(bytes memory _message) internal pure returns (bytes32 _batchHash) {
        require(isBatch(_message), "!batch");
        assembly {
            _batchHash := mload(add(_message, 33))
        }
    }

    function getBatchHash(Call[] memory _calls) internal pure returns (bytes32) {
        bytes memory encoded = abi.encodePacked(uint8(_calls.length));
        for (uint256 i = 0; i < _calls.length; i++) {
            encoded = abi.encodePacked(
                encoded,
                _calls[i].to,
                uint32(_calls[i].data.length),
                _calls[i].data
            );
        }
        return keccak256(encoded);
    }

    function getBatchHashCalldata(Call[] calldata _calls)
        internal
        pure
        returns (bytes32)
    {
        bytes memory encoded = abi.encodePacked(uint8(_calls.length));
        for (uint256 i = 0; i < _calls.length; i++) {
            encoded = abi.encodePacked(
                encoded,
                _calls[i].to,
                uint32(_calls[i].data.length),
                _calls[i].data
            );
        }
        return keccak256(encoded);
    }
}

/// @notice Minimal GovernanceRouter-like target for forged batch injection witness.
contract GovernanceBatchInjectionTarget {
    using GovernanceBatchMessageLite for bytes;

    IXcmReplicaViewBatch public xcm;
    uint32 public governorDomain;
    mapping(uint32 => bytes32) public routers;
    mapping(bytes32 => GovernanceBatchMessageLite.BatchStatus) public inboundCallBatches;

    uint256 public criticalValue;

    constructor(
        address _xcm,
        uint32 _governorDomain,
        bytes32 _governorRouter
    ) {
        xcm = IXcmReplicaViewBatch(_xcm);
        governorDomain = _governorDomain;
        routers[_governorDomain] = _governorRouter;
    }

    modifier onlyReplica() {
        require(xcm.isReplica(msg.sender), "!replica");
        _;
    }

    modifier onlyGovernorRouter(uint32 _domain, bytes32 _router) {
        require(_domain == governorDomain && _router == routers[_domain], "!governorRouter");
        _;
    }

    modifier onlyGovernor() {
        require(msg.sender == address(this), "!called by governor");
        _;
    }

    function handle(
        uint32 _origin,
        uint32,
        bytes32 _sender,
        bytes calldata _message
    ) external onlyReplica onlyGovernorRouter(_origin, _sender) {
        bytes memory message_ = _message;
        bytes32 _batchHash = message_.batchHash();
        if (inboundCallBatches[_batchHash] == GovernanceBatchMessageLite.BatchStatus.Pending) {
            return;
        }
        inboundCallBatches[_batchHash] = GovernanceBatchMessageLite.BatchStatus.Pending;
    }

    function executeCallBatch(GovernanceBatchMessageLite.Call[] calldata _calls)
        external
    {
        bytes32 _batchHash = GovernanceBatchMessageLite.getBatchHashCalldata(_calls);
        require(
            inboundCallBatches[_batchHash] == GovernanceBatchMessageLite.BatchStatus.Pending,
            "!batch pending"
        );
        inboundCallBatches[_batchHash] = GovernanceBatchMessageLite.BatchStatus.Complete;
        for (uint256 i = 0; i < _calls.length; i++) {
            _callLocal(_calls[i]);
        }
    }

    function privilegedSet(uint256 _value) external onlyGovernor {
        criticalValue = _value;
    }

    function _callLocal(GovernanceBatchMessageLite.Call calldata _call) internal {
        address _to = address(uint160(uint256(_call.to)));
        (bool _ok, ) = _to.call(_call.data);
        require(_ok, "call failed");
    }
}

/// @notice Stable sender shim for sink `handle` calls.
contract GovernanceBatchReplicaCallerHarness {
    function callHandle(
        address _target,
        uint32 _origin,
        uint32 _nonce,
        bytes32 _sender,
        bytes calldata _message
    ) external returns (bool ok, bytes memory ret) {
        return
            _target.call(
                abi.encodeWithSignature(
                    "handle(uint32,uint32,bytes32,bytes)",
                    _origin,
                    _nonce,
                    _sender,
                    _message
                )
            );
    }
}


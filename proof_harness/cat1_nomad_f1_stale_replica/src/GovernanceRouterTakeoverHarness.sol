// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IXcmReplicaView {
    function isReplica(address _replica) external view returns (bool);
}

/// @notice Minimal transfer-governor message codec matching Nomad's packed shape:
/// 1 byte type (2) + 4 byte domain + 32 byte governor.
library GovernanceMessageLite {
    uint8 internal constant TRANSFER_GOVERNOR = 2;
    uint256 internal constant TRANSFER_GOVERNOR_LEN = 37;

    function formatTransferGovernor(uint32 _domain, bytes32 _governor)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(bytes1(TRANSFER_GOVERNOR), _domain, _governor);
    }

    function isTransferGovernor(bytes memory _message)
        internal
        pure
        returns (bool)
    {
        return
            _message.length == TRANSFER_GOVERNOR_LEN &&
            uint8(_message[0]) == TRANSFER_GOVERNOR;
    }

    function transferGovernorDomain(bytes memory _message)
        internal
        pure
        returns (uint32 _domain)
    {
        require(isTransferGovernor(_message), "!transfer governor");
        assembly {
            _domain := shr(224, mload(add(_message, 33)))
        }
    }

    function transferGovernorAddress(bytes memory _message)
        internal
        pure
        returns (bytes32 _governor)
    {
        require(isTransferGovernor(_message), "!transfer governor");
        assembly {
            _governor := mload(add(_message, 37))
        }
    }
}

/// @notice Minimal governance receiver model for proving stale-replica takeover path:
/// onlyReplica + onlyGovernorRouter + transfer-governor handling.
contract GovernanceRouterTakeoverTarget {
    using GovernanceMessageLite for bytes;

    IXcmReplicaView public xcm;

    uint32 public immutable localDomain;
    uint32 public governorDomain;
    address public governor;

    mapping(uint32 => bytes32) public routers;

    // Privileged state used as a concrete takeover witness.
    address public privilegedTarget;

    constructor(
        address _xcm,
        uint32 _localDomain,
        uint32 _governorDomain,
        bytes32 _governorRouter
    ) {
        xcm = IXcmReplicaView(_xcm);
        localDomain = _localDomain;
        governorDomain = _governorDomain;
        routers[_governorDomain] = _governorRouter;
        privilegedTarget = _xcm;
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
        require(msg.sender == governor || msg.sender == address(this), "!called by governor");
        _;
    }

    function handle(
        uint32 _origin,
        uint32,
        bytes32 _sender,
        bytes calldata _message
    ) external onlyReplica onlyGovernorRouter(_origin, _sender) {
        bytes memory message_ = _message;
        if (message_.isTransferGovernor()) {
            uint32 _newDomain = message_.transferGovernorDomain();
            address _newGovernor = _bytes32ToAddress(message_.transferGovernorAddress());
            bool _isLocalGovernor = _newDomain == localDomain;
            _transferGovernor(_newDomain, _newGovernor, _isLocalGovernor);
            return;
        }
        revert("!valid message type");
    }

    function setPrivilegedTarget(address _newTarget) external onlyGovernor {
        privilegedTarget = _newTarget;
    }

    function _transferGovernor(
        uint32 _newDomain,
        address _newGovernor,
        bool _isLocalGovernor
    ) internal {
        if (!_isLocalGovernor) {
            require(routers[_newDomain] != bytes32(0), "!router");
        }
        governorDomain = _newDomain;
        governor = _isLocalGovernor ? _newGovernor : address(0);
    }

    function _bytes32ToAddress(bytes32 _value) internal pure returns (address) {
        return address(uint160(uint256(_value)));
    }
}

/// @notice Stable caller shim used to emulate an enrolled replica sender.
contract GovernanceReplicaCallerHarness {
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

/// @notice External caller shim used to prove post-takeover privileged execution.
contract GovernancePrivilegedCallerHarness {
    function callSetPrivilegedTarget(address _target, address _newTarget)
        external
        returns (bool ok, bytes memory ret)
    {
        return
            _target.call(
                abi.encodeWithSignature(
                    "setPrivilegedTarget(address)",
                    _newTarget
                )
            );
    }
}


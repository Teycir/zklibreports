// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {XAppConnectionManagerBug} from "./XAppConnectionManagerHarness.sol";

interface IXcm {
    function isReplica(address _replica) external view returns (bool);
    function ownerEnrollReplica(address _replica, uint32 _domain) external;
    function domainToReplica(uint32 _domain) external view returns (address);
}

/// @notice Minimal sink that mirrors auth gates in Nomad xApps:
/// onlyReplica + onlyRemoteRouter(origin,sender).
contract SinkAuthTarget {
    IXcm public xcm;
    mapping(uint32 => bytes32) public remotes;
    uint256 public handled;

    constructor(address _xcm) {
        xcm = IXcm(_xcm);
    }

    modifier onlyReplica() {
        require(xcm.isReplica(msg.sender), "!replica");
        _;
    }

    modifier onlyRemoteRouter(uint32 _origin, bytes32 _router) {
        require(remotes[_origin] == _router, "!remote router");
        _;
    }

    function setRemote(uint32 _domain, bytes32 _router) external {
        remotes[_domain] = _router;
    }

    function handle(
        uint32 _origin,
        uint32,
        bytes32 _sender,
        bytes calldata
    ) external onlyReplica onlyRemoteRouter(_origin, _sender) {
        handled += 1;
    }
}

/// @notice Caller shim so `msg.sender` at the sink is a stable contract address.
contract SinkCallerHarness {
    function callHandle(
        address target,
        uint32 origin,
        uint32 nonce,
        bytes32 sender,
        bytes calldata message
    ) external returns (bool ok, bytes memory ret) {
        return
            target.call(
                abi.encodeWithSignature(
                    "handle(uint32,uint32,bytes32,bytes)",
                    origin,
                    nonce,
                    sender,
                    message
                )
            );
    }
}

/// @notice Stateful Medusa harness proving stale replica auth reaches a sink.
contract MedusaSinkAuthHarness {
    uint32 internal constant DOMAIN = 1;
    bytes32 internal constant ROUTER = bytes32(uint256(0xBEEF));

    XAppConnectionManagerBug public xcm;
    SinkAuthTarget public sink;
    SinkCallerHarness public r1;
    SinkCallerHarness public r2;

    mapping(address => bool) public retiredReplica;
    bool public retiredReplicaReachedSink;

    constructor() {
        xcm = new XAppConnectionManagerBug();
        sink = new SinkAuthTarget(address(xcm));
        r1 = new SinkCallerHarness();
        r2 = new SinkCallerHarness();
        sink.setRemote(DOMAIN, ROUTER);
    }

    function _pickReplica(uint8 id) internal view returns (address) {
        return id % 2 == 0 ? address(r1) : address(r2);
    }

    function _pickCaller(uint8 id) internal view returns (SinkCallerHarness) {
        return id % 2 == 0 ? r1 : r2;
    }

    // -------- Actions --------

    function action_enrollReplica(uint8 replicaId) external {
        address next = _pickReplica(replicaId);
        address current = xcm.domainToReplica(DOMAIN);
        if (current != address(0) && current != next) {
            retiredReplica[current] = true;
        }
        xcm.ownerEnrollReplica(next, DOMAIN);
    }

    function action_tryHandle(
        uint8 callerId,
        bool correctOrigin,
        bool correctRouter
    ) external {
        SinkCallerHarness caller = _pickCaller(callerId);
        uint32 origin = correctOrigin ? DOMAIN : DOMAIN + 1;
        bytes32 sender = correctRouter ? ROUTER : bytes32(uint256(0xCAFE));

        (bool ok, ) = caller.callHandle(
            address(sink),
            origin,
            0,
            sender,
            bytes("")
        );

        if (ok && retiredReplica[address(caller)]) {
            retiredReplicaReachedSink = true;
        }
    }

    // -------- Invariant --------

    /// @notice Retired replicas should never be able to execute sink `handle`.
    function property_retired_replica_cannot_reach_sink()
        external
        view
        returns (bool)
    {
        return !retiredReplicaReachedSink;
    }

    /// @notice Echidna-compatible alias for the same invariant.
    function echidna_retired_replica_cannot_reach_sink()
        external
        view
        returns (bool)
    {
        return !retiredReplicaReachedSink;
    }
}

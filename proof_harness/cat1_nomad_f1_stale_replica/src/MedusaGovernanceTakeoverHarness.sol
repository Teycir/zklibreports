// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {XAppConnectionManagerBug} from "./XAppConnectionManagerHarness.sol";
import {
    GovernanceMessageLite,
    GovernancePrivilegedCallerHarness,
    GovernanceReplicaCallerHarness,
    GovernanceRouterTakeoverTarget
} from "./GovernanceRouterTakeoverHarness.sol";

/// @notice Stateful Medusa harness proving stale-replica auth can escalate into governance takeover.
contract MedusaGovernanceTakeoverHarness {
    uint32 internal constant ENROLL_DOMAIN = 1;
    uint32 internal constant LOCAL_DOMAIN = 1000;
    uint32 internal constant GOVERNOR_DOMAIN = 2000;
    bytes32 internal constant GOVERNOR_ROUTER = bytes32(uint256(0xBEEF));

    XAppConnectionManagerBug public xcm;
    GovernanceRouterTakeoverTarget public gov;
    GovernanceReplicaCallerHarness public r1;
    GovernanceReplicaCallerHarness public r2;
    GovernancePrivilegedCallerHarness public attackerA;
    GovernancePrivilegedCallerHarness public attackerB;

    mapping(address => bool) public retiredReplica;
    bool public retiredReplicaTookGovernor;

    constructor() {
        xcm = new XAppConnectionManagerBug();
        gov = new GovernanceRouterTakeoverTarget(
            address(xcm),
            LOCAL_DOMAIN,
            GOVERNOR_DOMAIN,
            GOVERNOR_ROUTER
        );
        r1 = new GovernanceReplicaCallerHarness();
        r2 = new GovernanceReplicaCallerHarness();
        attackerA = new GovernancePrivilegedCallerHarness();
        attackerB = new GovernancePrivilegedCallerHarness();
    }

    function _pickReplicaAddress(uint8 _id) internal view returns (address) {
        return _id % 2 == 0 ? address(r1) : address(r2);
    }

    function _pickReplicaCaller(uint8 _id)
        internal
        view
        returns (GovernanceReplicaCallerHarness)
    {
        return _id % 2 == 0 ? r1 : r2;
    }

    function _pickAttacker(uint8 _id)
        internal
        view
        returns (GovernancePrivilegedCallerHarness)
    {
        return _id % 2 == 0 ? attackerA : attackerB;
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

    function action_tryForgedTransferGovernor(uint8 _replicaId, uint8 _attackerId)
        external
    {
        GovernanceReplicaCallerHarness _replica = _pickReplicaCaller(_replicaId);
        GovernancePrivilegedCallerHarness _attacker = _pickAttacker(_attackerId);
        bytes memory _forged = GovernanceMessageLite.formatTransferGovernor(
            LOCAL_DOMAIN,
            bytes32(uint256(uint160(address(_attacker))))
        );

        (bool _ok, ) = _replica.callHandle(
            address(gov),
            GOVERNOR_DOMAIN,
            0,
            GOVERNOR_ROUTER,
            _forged
        );

        if (_ok && retiredReplica[address(_replica)] && gov.governor() == address(_attacker)) {
            (bool _okPriv, ) = _attacker.callSetPrivilegedTarget(
                address(gov),
                address(_attacker)
            );
            if (_okPriv && gov.privilegedTarget() == address(_attacker)) {
                retiredReplicaTookGovernor = true;
            }
        }
    }

    // -------- Invariant --------

    /// @notice A retired replica should never be able to seize governor privileges.
    function property_retired_replica_cannot_take_governor()
        external
        view
        returns (bool)
    {
        return !retiredReplicaTookGovernor;
    }

    /// @notice Echidna-compatible alias for the same invariant.
    function echidna_retired_replica_cannot_take_governor()
        external
        view
        returns (bool)
    {
        return !retiredReplicaTookGovernor;
    }
}


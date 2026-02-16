// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {
    MerkleBranchLite,
    ReplicaBootstrapBug,
    ReplicaBootstrapFixed
} from "../src/ReplicaBootstrapTimeoutHarness.sol";

interface Vm {
    function warp(uint256) external;
}

contract ReplicaBootstrapTimeoutBypassTest {
    Vm internal constant vm =
        Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function _assertTrue(bool _condition, string memory _message) internal pure {
        require(_condition, _message);
    }

    function _mkRoot(bytes32 _leaf, bytes32[32] memory _proof, uint256 _index)
        internal
        pure
        returns (bytes32)
    {
        return MerkleBranchLite.branchRoot(_leaf, _proof, _index);
    }

    /// @notice End-to-end witness:
    /// bootstrap root in buggy model is accepted immediately, bypassing optimistic timeout.
    function test_bootstrap_root_is_immediately_acceptable_in_buggy_model() public {
        bytes32 leaf = keccak256("bootstrap-leaf");
        bytes32[32] memory proof;
        uint256 index = 0;
        bytes32 root = _mkRoot(leaf, proof, index);
        uint256 timeoutSeconds = 30 days;

        ReplicaBootstrapBug bug = new ReplicaBootstrapBug(root, timeoutSeconds);
        ReplicaBootstrapFixed fixedModel = new ReplicaBootstrapFixed(
            root,
            timeoutSeconds
        );

        bool bugOk = bug.prove(leaf, proof, index);
        bool fixedOk = fixedModel.prove(leaf, proof, index);

        _assertTrue(
            bugOk,
            "bug model should accept bootstrap root immediately"
        );
        _assertTrue(
            !fixedOk,
            "fixed model should not accept bootstrap root before timeout"
        );

        vm.warp(block.timestamp + timeoutSeconds + 1);
        bool fixedAfter = fixedModel.prove(leaf, proof, index);
        _assertTrue(
            fixedAfter,
            "fixed model should accept bootstrap root after timeout"
        );
    }

    /// @notice Fuzz witness: for any leaf/index/proof seed, buggy bootstrap accepts immediately,
    /// while fixed model rejects until timeout.
    function testFuzz_buggy_bootstrap_bypasses_timeout(
        bytes32 leaf,
        uint256 indexSeed,
        bytes32 p0,
        bytes32 p1,
        bytes32 p2
    ) public {
        bytes32[32] memory proof;
        proof[0] = p0;
        proof[1] = p1;
        proof[2] = p2;
        uint256 index = indexSeed;
        bytes32 root = _mkRoot(leaf, proof, index);
        uint256 timeoutSeconds = 7 days;

        ReplicaBootstrapBug bug = new ReplicaBootstrapBug(root, timeoutSeconds);
        ReplicaBootstrapFixed fixedModel = new ReplicaBootstrapFixed(
            root,
            timeoutSeconds
        );

        bool bugOk = bug.prove(leaf, proof, index);
        bool fixedOk = fixedModel.prove(leaf, proof, index);

        _assertTrue(bugOk, "bug model did not accept immediate bootstrap proof");
        _assertTrue(
            !fixedOk,
            "fixed model unexpectedly accepted bootstrap proof early"
        );
    }
}


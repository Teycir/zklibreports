// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {
    MerkleBranchLite,
    ReplicaBootstrapBug,
    ReplicaBootstrapFixed
} from "./ReplicaBootstrapTimeoutHarness.sol";

/// @notice Stateful harness for bootstrap-root timeout behavior.
contract MedusaReplicaBootstrapHarness {
    bytes32 public leaf;
    bytes32[32] public proof;
    uint256 public index;

    uint256 public bootstrapDeadline;
    ReplicaBootstrapBug public bug;
    ReplicaBootstrapFixed public fixedModel;

    bool public bugAcceptedEarly;
    bool public fixedAcceptedEarly;

    constructor() {
        leaf = keccak256("bootstrap-leaf");
        index = 0;

        uint256 timeoutSeconds = 365 days;
        bytes32 root = MerkleBranchLite.branchRoot(leaf, proof, index);
        bootstrapDeadline = block.timestamp + timeoutSeconds;

        bug = new ReplicaBootstrapBug(root, timeoutSeconds);
        fixedModel = new ReplicaBootstrapFixed(root, timeoutSeconds);
    }

    function action_tryProveBug() external {
        try bug.prove(leaf, proof, index) returns (bool ok) {
            if (ok && block.timestamp < bootstrapDeadline) {
                bugAcceptedEarly = true;
            }
        } catch {}
    }

    function action_tryProveFixed() external {
        try fixedModel.prove(leaf, proof, index) returns (bool ok) {
            if (ok && block.timestamp < bootstrapDeadline) {
                fixedAcceptedEarly = true;
            }
        } catch {}
    }

    /// @notice Bootstrap root should not be acceptable before timeout.
    function property_bootstrap_root_waits_timeout() external view returns (bool) {
        return !bugAcceptedEarly;
    }

    /// @notice Fixed model should also not be acceptable before timeout.
    function property_fixed_model_waits_timeout() external view returns (bool) {
        return !fixedAcceptedEarly;
    }

    /// @notice Echidna-compatible alias for bootstrap timeout property.
    function echidna_bootstrap_root_waits_timeout() external view returns (bool) {
        return !bugAcceptedEarly;
    }
}


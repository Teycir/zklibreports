// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {RollupAssertionLifecycleHarness} from "../src/MantleF2AssertionAutoConfirmHarness.sol";

contract MantleF2AssertionAutoConfirmTest {
    function test_createAssertion_auto_confirms_in_same_transaction() public {
        RollupAssertionLifecycleHarness rollup = new RollupAssertionLifecycleHarness();

        uint256 newAssertionID = rollup.createAssertion(bytes32(uint256(0xA11CE)), 123);

        require(newAssertionID == rollup.lastCreatedAssertionID(), "unexpected created assertion id");
        require(
            rollup.lastConfirmedAssertionID() == newAssertionID,
            "expected created assertion to be confirmed immediately"
        );
    }

    function test_secure_invariant_is_violated_by_createAssertion() public {
        RollupAssertionLifecycleHarness rollup = new RollupAssertionLifecycleHarness();

        rollup.createAssertion(bytes32(uint256(0xB0B)), 1);

        bool secureInvariantHolds = rollup.lastConfirmedAssertionID() < rollup.lastCreatedAssertionID();
        require(!secureInvariantHolds, "expected invariant violation");
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {RollupAssertionLifecycleHarness} from "../src/MantleF2AssertionAutoConfirmHarness.sol";

/// @notice Halmos check for Mantle F-MAN-02.
contract HalmosF2AssertionAutoConfirm {
    function check_new_assertion_requires_distinct_confirmation_step(bytes32 vmHash, uint64 inboxSize) public {
        RollupAssertionLifecycleHarness rollup = new RollupAssertionLifecycleHarness();

        rollup.createAssertion(vmHash, inboxSize);

        assert(rollup.lastConfirmedAssertionID() < rollup.lastCreatedAssertionID());
    }
}

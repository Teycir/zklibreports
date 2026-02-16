// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {RollupAssertionLifecycleHarness} from "./MantleF2AssertionAutoConfirmHarness.sol";

/// @notice Stateful Medusa harness for Mantle F-MAN-02.
contract MedusaF2AssertionAutoConfirmHarness {
    RollupAssertionLifecycleHarness public rollup;
    uint256 public nonce;
    bool public created;

    constructor() {
        rollup = new RollupAssertionLifecycleHarness();
    }

    function action_create_assertion(bytes32 vmHash, uint64 inboxSize) public {
        bytes32 mixedHash = vmHash ^ bytes32(nonce);
        rollup.createAssertion(mixedHash, inboxSize);
        nonce++;
        created = true;
    }

    /// @notice Property expected in staged dispute/finality designs:
    ///         new assertions should not be confirmed in their creation call.
    function property_new_assertions_require_distinct_confirmation_step() public view returns (bool) {
        if (!created) {
            return true;
        }
        return rollup.lastConfirmedAssertionID() < rollup.lastCreatedAssertionID();
    }
}

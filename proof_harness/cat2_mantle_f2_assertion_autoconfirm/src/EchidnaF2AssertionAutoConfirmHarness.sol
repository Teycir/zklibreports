// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {RollupAssertionLifecycleHarness} from "./MantleF2AssertionAutoConfirmHarness.sol";

/// @notice Echidna property harness for Mantle F-MAN-02.
contract EchidnaF2AssertionAutoConfirmHarness {
    RollupAssertionLifecycleHarness public rollup;
    uint256 public nonce;
    bool public created;

    constructor() {
        rollup = new RollupAssertionLifecycleHarness();
    }

    function action_create_assertion() public {
        bytes32 vmHash = keccak256(abi.encodePacked(nonce));
        uint64 inboxSize = uint64(nonce);
        rollup.createAssertion(vmHash, inboxSize);
        nonce++;
        created = true;
    }

    function echidna_new_assertions_require_distinct_confirmation_step() public view returns (bool) {
        if (!created) {
            return true;
        }
        return rollup.lastConfirmedAssertionID() < rollup.lastCreatedAssertionID();
    }
}

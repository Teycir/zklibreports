// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {
    MockSenderTaxTokenV2,
    SynapseMinOutBugModel,
    SynapseMinOutFixedModel
} from "./SynapseRoleAndMinOutHarness.sol";

/// @notice Specialist-fuzz harness for F3 min-out vs actual-recipient mismatch.
contract MedusaSynapseMinOutHarness {
    uint256 internal constant INITIAL_LIQUIDITY = 10_000_000_000_000;
    uint256 internal constant MIN_STEP = 10_000;
    uint256 internal constant MAX_STEP = 1_000_000_000;
    address internal constant RECIPIENT = address(0xBEEF);

    MockSenderTaxTokenV2 public bugToken;
    MockSenderTaxTokenV2 public fixedToken;
    SynapseMinOutBugModel public bugModel;
    SynapseMinOutFixedModel public fixedModel;

    bool public bugBroken;
    bool public fixedBroken;

    constructor() {
        bugToken = new MockSenderTaxTokenV2(address(this), 500); // 5% sender-side fee.
        fixedToken = new MockSenderTaxTokenV2(address(this), 500);

        bugModel = new SynapseMinOutBugModel(address(bugToken));
        fixedModel = new SynapseMinOutFixedModel(address(fixedToken));

        bugToken.setTaxSender(address(bugModel));
        fixedToken.setTaxSender(address(fixedModel));

        bugToken.mint(address(bugModel), INITIAL_LIQUIDITY);
        fixedToken.mint(address(fixedModel), INITIAL_LIQUIDITY);
    }

    function _step(uint256 seed) internal pure returns (uint256) {
        return (seed % MAX_STEP) + MIN_STEP;
    }

    function _minOut(uint256 quotedOut, uint16 minBpsSeed) internal pure returns (uint256) {
        // 90%-100% minimum: values above 95% can violate with a 5% transfer-tax payout token.
        uint256 bps = (uint256(minBpsSeed) % 1001) + 9000;
        return (quotedOut * bps) / 10_000;
    }

    function action_bug_settle(uint96 quotedSeed, uint16 minBpsSeed) external {
        uint256 quotedOut = _step(quotedSeed);
        if (bugToken.balanceOf(address(bugModel)) < quotedOut) return;
        uint256 minOut = _minOut(quotedOut, minBpsSeed);
        try bugModel.settleSwap(RECIPIENT, quotedOut, minOut) returns (uint256 actualReceived) {
            if (actualReceived < minOut) bugBroken = true;
        } catch {}
    }

    function action_fixed_settle(uint96 quotedSeed, uint16 minBpsSeed) external {
        uint256 quotedOut = _step(quotedSeed);
        if (fixedToken.balanceOf(address(fixedModel)) < quotedOut) return;
        uint256 minOut = _minOut(quotedOut, minBpsSeed);
        try fixedModel.settleSwap(RECIPIENT, quotedOut, minOut) returns (uint256 actualReceived) {
            if (actualReceived < minOut) fixedBroken = true;
        } catch {}
    }

    function property_bug_swap_min_out_matches_actual_user_receipt() external view returns (bool) {
        return !bugBroken;
    }

    function property_fixed_swap_min_out_matches_actual_user_receipt() external view returns (bool) {
        return !fixedBroken;
    }

    function echidna_bug_swap_min_out_matches_actual_user_receipt() external view returns (bool) {
        return !bugBroken;
    }
}

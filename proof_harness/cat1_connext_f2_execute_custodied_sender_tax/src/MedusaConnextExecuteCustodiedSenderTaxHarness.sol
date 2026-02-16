// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {
    ConnextExecuteCustodiedBugModel,
    ConnextExecuteCustodiedFixedModel,
    MockSenderDebitTaxToken
} from "./ConnextExecuteCustodiedSenderTaxHarness.sol";

/// @notice Specialist-fuzz harness for Connext execute/custodied accounting drift under sender-tax payout tokens.
contract MedusaConnextExecuteCustodiedSenderTaxHarness {
    uint256 internal constant INITIAL_MINT = 10_000_000_000_000;
    uint256 internal constant MIN_STEP = 10_000;
    uint256 internal constant MAX_STEP = 1_000_000_000;
    address internal constant RECIPIENT = address(0xBEEF);

    MockSenderDebitTaxToken public bugToken;
    MockSenderDebitTaxToken public fixedToken;
    ConnextExecuteCustodiedBugModel public bugModel;
    ConnextExecuteCustodiedFixedModel public fixedModel;

    bool public bugBroken;
    bool public fixedBroken;

    constructor() {
        bugToken = new MockSenderDebitTaxToken(address(this), 500); // 5%
        fixedToken = new MockSenderDebitTaxToken(address(this), 500);

        bugModel = new ConnextExecuteCustodiedBugModel(address(bugToken));
        fixedModel = new ConnextExecuteCustodiedFixedModel(address(fixedToken));

        bugToken.setTaxSender(address(bugModel));
        fixedToken.setTaxSender(address(fixedModel));

        bugToken.mint(address(this), INITIAL_MINT);
        fixedToken.mint(address(this), INITIAL_MINT);

        bugToken.approve(address(bugModel), type(uint256).max);
        fixedToken.approve(address(fixedModel), type(uint256).max);
    }

    function _step(uint256 seed) internal pure returns (uint256) {
        return (seed % MAX_STEP) + MIN_STEP;
    }

    function action_bug_seed(uint96 amountSeed) external {
        uint256 amount = _step(amountSeed);
        try bugModel.seedCustody(amount) {} catch {}
        _refreshBug();
    }

    function action_bug_execute(uint96 amountSeed) external {
        uint256 c = bugModel.custodied();
        if (c == 0) return;
        uint256 amount = (uint256(amountSeed) % c) + 1;
        try bugModel.executeTransfer(RECIPIENT, amount) {} catch {}
        _refreshBug();
    }

    function action_fixed_seed(uint96 amountSeed) external {
        uint256 amount = _step(amountSeed);
        try fixedModel.seedCustody(amount) {} catch {}
        _refreshFixed();
    }

    function action_fixed_execute(uint96 amountSeed) external {
        uint256 c = fixedModel.custodied();
        if (c == 0) return;
        uint256 amount = (uint256(amountSeed) % c) + 1;
        try fixedModel.executeTransfer(RECIPIENT, amount) {} catch {}
        _refreshFixed();
    }

    function _refreshBug() internal {
        if (bugToken.balanceOf(address(bugModel)) < bugModel.custodied()) {
            bugBroken = true;
        }
    }

    function _refreshFixed() internal {
        if (fixedToken.balanceOf(address(fixedModel)) < fixedModel.custodied()) {
            fixedBroken = true;
        }
    }

    function property_bug_collateral_covers_custodied() external view returns (bool) {
        return !bugBroken;
    }

    function property_fixed_collateral_covers_custodied() external view returns (bool) {
        return !fixedBroken;
    }

    function echidna_bug_collateral_covers_custodied() external view returns (bool) {
        return !bugBroken;
    }
}

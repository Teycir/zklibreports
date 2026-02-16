// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {
    MockBridgeSenderTaxToken,
    OutboundSenderTaxBugModel,
    OutboundSenderTaxFixedModel
} from "./OutboundSenderTaxHarness.sol";

/// @notice Stateful specialist-fuzz harness for outbound sender-tax insolvency.
contract MedusaOutboundSenderTaxHarness {
    uint256 internal constant INITIAL_MINT = 1_000_000 ether;
    uint256 internal constant MAX_STEP = 1_000 ether;

    OutboundSenderTaxBugModel public bugModel;
    OutboundSenderTaxFixedModel public fixedModel;
    MockBridgeSenderTaxToken public bugToken;
    MockBridgeSenderTaxToken public fixedToken;

    bool public bugSolvencyBroken;
    bool public fixedSolvencyBroken;

    constructor() {
        bugModel = new OutboundSenderTaxBugModel();
        fixedModel = new OutboundSenderTaxFixedModel();

        // 100% extra sender-side debit on bridge-originated transfers.
        bugToken = new MockBridgeSenderTaxToken(address(bugModel), address(this), 10_000);
        fixedToken = new MockBridgeSenderTaxToken(address(fixedModel), address(this), 10_000);

        bugToken.mint(address(this), INITIAL_MINT);
        fixedToken.mint(address(this), INITIAL_MINT);

        bugToken.approve(address(bugModel), type(uint256).max);
        fixedToken.approve(address(fixedModel), type(uint256).max);
    }

    function _step(uint256 seed) internal pure returns (uint256) {
        return (seed % MAX_STEP) + 1;
    }

    function action_seedBug(uint96 amountSeed) external {
        uint256 amount = _step(amountSeed);
        try bugModel.depositAndBridgeOut(address(bugToken), address(this), amount) {} catch {}
        _refreshBugSolvencyFlag();
    }

    function action_redeemBug(uint96 amountSeed) external {
        uint256 out = bugModel.outstanding(address(bugToken));
        if (out == 0) return;
        uint256 amount = _step(amountSeed);
        if (amount > out) amount = out;
        try bugModel.completeTransfer(address(bugToken), address(this), amount) {} catch {}
        _refreshBugSolvencyFlag();
    }

    function action_seedFixed(uint96 amountSeed) external {
        uint256 amount = _step(amountSeed);
        try fixedModel.depositAndBridgeOut(address(fixedToken), address(this), amount) {} catch {}
        _refreshFixedSolvencyFlag();
    }

    function action_redeemFixed(uint96 amountSeed) external {
        uint256 out = fixedModel.outstanding(address(fixedToken));
        if (out == 0) return;
        uint256 amount = _step(amountSeed);
        if (amount > out) amount = out;
        try fixedModel.completeTransfer(address(fixedToken), address(this), amount) {} catch {}
        _refreshFixedSolvencyFlag();
    }

    function _refreshBugSolvencyFlag() internal {
        uint256 collateral = bugToken.balanceOf(address(bugModel));
        uint256 out = bugModel.outstanding(address(bugToken));
        if (collateral < out) bugSolvencyBroken = true;
    }

    function _refreshFixedSolvencyFlag() internal {
        uint256 collateral = fixedToken.balanceOf(address(fixedModel));
        uint256 out = fixedModel.outstanding(address(fixedToken));
        if (collateral < out) fixedSolvencyBroken = true;
    }

    /// @notice Desired invariant: collateral should cover outstanding liabilities.
    function property_bug_collateral_covers_outstanding()
        external
        view
        returns (bool)
    {
        return !bugSolvencyBroken;
    }

    /// @notice Fixed model should preserve collateral coverage.
    function property_fixed_collateral_covers_outstanding()
        external
        view
        returns (bool)
    {
        return !fixedSolvencyBroken;
    }

    /// @notice Echidna-compatible alias.
    function echidna_bug_collateral_covers_outstanding()
        external
        view
        returns (bool)
    {
        return !bugSolvencyBroken;
    }
}


// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {
    HyperlaneFeeTransferBugModel,
    HyperlaneFeeTransferFixedModel,
    MockSenderTaxTokenV2
} from "./HyperlaneLpAndFeeHarness.sol";

/// @notice Stateful specialist-fuzz harness for sender-tax fee transfer drift.
contract MedusaHyperlaneFeeTransferHarness {
    uint256 internal constant INITIAL_MINT = 1_000_000_000_000;
    uint256 internal constant MIN_STEP = 10_000;
    uint256 internal constant MAX_STEP = 1_000_000_000;

    HyperlaneFeeTransferBugModel public bugModel;
    HyperlaneFeeTransferFixedModel public fixedModel;
    MockSenderTaxTokenV2 public bugToken;
    MockSenderTaxTokenV2 public fixedToken;

    bool public bugBroken;
    bool public fixedBroken;

    constructor() {
        bugToken = new MockSenderTaxTokenV2(address(this), 10_000); // 100% sender-tax.
        fixedToken = new MockSenderTaxTokenV2(address(this), 10_000);

        bugModel = new HyperlaneFeeTransferBugModel(address(bugToken), address(this));
        fixedModel = new HyperlaneFeeTransferFixedModel(address(fixedToken), address(this));

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

    function action_bug_transferRemoteWithFee(uint96 amountSeed, uint96 feeSeed) external {
        uint256 amount = _step(amountSeed);
        uint256 feeAmount = _step(feeSeed);
        try bugModel.transferRemoteWithFee(amount, feeAmount) {} catch {}
        _refreshBug();
    }

    function action_fixed_transferRemoteWithFee(uint96 amountSeed, uint96 feeSeed) external {
        uint256 amount = _step(amountSeed);
        uint256 feeAmount = _step(feeSeed);
        try fixedModel.transferRemoteWithFee(amount, feeAmount) {} catch {}
        _refreshFixed();
    }

    function _refreshBug() internal {
        uint256 collateral = bugToken.balanceOf(address(bugModel));
        uint256 liability = bugModel.remoteLiabilityLD();
        if (collateral < liability) bugBroken = true;
    }

    function _refreshFixed() internal {
        uint256 collateral = fixedToken.balanceOf(address(fixedModel));
        uint256 liability = fixedModel.remoteLiabilityLD();
        if (collateral < liability) fixedBroken = true;
    }

    function property_bug_collateral_covers_remote_liability() external view returns (bool) {
        return !bugBroken;
    }

    function property_fixed_collateral_covers_remote_liability() external view returns (bool) {
        return !fixedBroken;
    }

    function echidna_bug_collateral_covers_remote_liability() external view returns (bool) {
        return !bugBroken;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {
    HyperlaneCollateralBugModel,
    HyperlaneCollateralFixedModel,
    MockInboundFeeToken
} from "./HyperlaneCollateralFeeHarness.sol";

/// @notice Stateful specialist-fuzz harness for Hyperlane collateral accounting under fee-on-transfer tokens.
contract MedusaHyperlaneCollateralFeeHarness {
    uint256 internal constant INITIAL_MINT = 1_000_000_000_000;
    uint256 internal constant MIN_STEP = 10_000;
    uint256 internal constant MAX_STEP = 1_000_000_000;

    HyperlaneCollateralBugModel public bugModel;
    HyperlaneCollateralFixedModel public fixedModel;
    MockInboundFeeToken public bugToken;
    MockInboundFeeToken public fixedToken;

    bool public bugBroken;
    bool public fixedBroken;

    constructor() {
        bugToken = new MockInboundFeeToken(address(this), 500); // 5% inbound fee.
        fixedToken = new MockInboundFeeToken(address(this), 500);

        bugModel = new HyperlaneCollateralBugModel(address(bugToken), 1);
        fixedModel = new HyperlaneCollateralFixedModel(address(fixedToken), 1);

        bugToken.setFeeTarget(address(bugModel));
        fixedToken.setFeeTarget(address(fixedModel));

        bugToken.mint(address(this), INITIAL_MINT);
        fixedToken.mint(address(this), INITIAL_MINT);

        bugToken.approve(address(bugModel), type(uint256).max);
        fixedToken.approve(address(fixedModel), type(uint256).max);
    }

    function _step(uint256 seed) internal pure returns (uint256) {
        return (seed % MAX_STEP) + MIN_STEP;
    }

    function action_bug_transferRemote(uint96 amountSeed) external {
        uint256 amount = _step(amountSeed);
        try bugModel.transferRemote(amount, amount) {} catch {}
        _refreshBug();
    }

    function action_fixed_transferRemote(uint96 amountSeed) external {
        uint256 amount = _step(amountSeed);
        try fixedModel.transferRemote(amount, 0) {} catch {}
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

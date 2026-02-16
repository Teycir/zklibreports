// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {
    HyperlaneLpAssetsBugModel,
    HyperlaneLpAssetsFixedModel,
    MockInboundFeeTokenV2
} from "./HyperlaneLpAndFeeHarness.sol";

/// @notice Stateful specialist-fuzz harness for LP asset accounting drift.
contract MedusaHyperlaneLpAssetsHarness {
    uint256 internal constant INITIAL_MINT = 1_000_000_000_000;
    uint256 internal constant MIN_STEP = 10_000;
    uint256 internal constant MAX_STEP = 1_000_000_000;

    HyperlaneLpAssetsBugModel public bugModel;
    HyperlaneLpAssetsFixedModel public fixedModel;
    MockInboundFeeTokenV2 public bugToken;
    MockInboundFeeTokenV2 public fixedToken;

    bool public bugBroken;
    bool public fixedBroken;

    constructor() {
        bugToken = new MockInboundFeeTokenV2(address(this), 500); // 5% inbound fee.
        fixedToken = new MockInboundFeeTokenV2(address(this), 500);

        bugModel = new HyperlaneLpAssetsBugModel(address(bugToken));
        fixedModel = new HyperlaneLpAssetsFixedModel(address(fixedToken));

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

    function action_bug_deposit(uint96 amountSeed) external {
        uint256 amount = _step(amountSeed);
        try bugModel.deposit(amount) {} catch {}
        _refreshBug();
    }

    function action_bug_withdraw(uint96 amountSeed) external {
        uint256 maxShares = bugModel.shares(address(this));
        if (maxShares == 0) return;
        uint256 amount = _step(amountSeed);
        if (amount > maxShares) amount = maxShares;
        try bugModel.withdraw(amount) {} catch {}
        _refreshBug();
    }

    function action_fixed_deposit(uint96 amountSeed) external {
        uint256 amount = _step(amountSeed);
        try fixedModel.deposit(amount) {} catch {}
        _refreshFixed();
    }

    function action_fixed_withdraw(uint96 amountSeed) external {
        uint256 maxShares = fixedModel.shares(address(this));
        if (maxShares == 0) return;
        uint256 amount = _step(amountSeed);
        if (amount > maxShares) amount = maxShares;
        try fixedModel.withdraw(amount) {} catch {}
        _refreshFixed();
    }

    function _refreshBug() internal {
        uint256 collateral = bugToken.balanceOf(address(bugModel));
        uint256 assets = bugModel.lpAssets();
        if (collateral < assets) bugBroken = true;
    }

    function _refreshFixed() internal {
        uint256 collateral = fixedToken.balanceOf(address(fixedModel));
        uint256 assets = fixedModel.lpAssets();
        if (collateral < assets) fixedBroken = true;
    }

    function property_bug_collateral_covers_lp_assets() external view returns (bool) {
        return !bugBroken;
    }

    function property_fixed_collateral_covers_lp_assets() external view returns (bool) {
        return !fixedBroken;
    }

    function echidna_bug_collateral_covers_lp_assets() external view returns (bool) {
        return !bugBroken;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {
    MockInboundFeeToken,
    SynapseDepositBugModel,
    SynapseDepositFixedModel
} from "./SynapseDepositFeeHarness.sol";

/// @notice Stateful specialist-fuzz harness for Synapse deposit accounting under fee-on-transfer tokens.
contract MedusaSynapseDepositFeeHarness {
    uint256 internal constant INITIAL_MINT = 1_000_000_000_000;
    uint256 internal constant MIN_STEP = 10_000;
    uint256 internal constant MAX_STEP = 1_000_000_000;

    SynapseDepositBugModel public bugModel;
    SynapseDepositFixedModel public fixedModel;
    MockInboundFeeToken public bugToken;
    MockInboundFeeToken public fixedToken;

    bool public bugBroken;
    bool public fixedBroken;

    constructor() {
        bugToken = new MockInboundFeeToken(address(this), 500); // 5% inbound fee.
        fixedToken = new MockInboundFeeToken(address(this), 500);

        bugModel = new SynapseDepositBugModel(address(bugToken));
        fixedModel = new SynapseDepositFixedModel(address(fixedToken));

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

    function action_bug_deposit(uint96 amountSeed, bool useSwapPath) external {
        uint256 amount = _step(amountSeed);
        if (useSwapPath) {
            try bugModel.depositAndSwap(amount) {} catch {}
        } else {
            try bugModel.deposit(amount) {} catch {}
        }
        _refreshBug();
    }

    function action_fixed_deposit(uint96 amountSeed, bool useSwapPath) external {
        uint256 amount = _step(amountSeed);
        if (useSwapPath) {
            try fixedModel.depositAndSwap(amount) {} catch {}
        } else {
            try fixedModel.deposit(amount) {} catch {}
        }
        _refreshFixed();
    }

    function _refreshBug() internal {
        uint256 collateral = bugToken.balanceOf(address(bugModel));
        uint256 liability = bugModel.remoteLiability();
        if (collateral < liability) bugBroken = true;
    }

    function _refreshFixed() internal {
        uint256 collateral = fixedToken.balanceOf(address(fixedModel));
        uint256 liability = fixedModel.remoteLiability();
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

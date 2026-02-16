// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {
    MockInboundFeeToken,
    EndpointLzTokenSweepBugModel,
    EndpointLzTokenSweepFixedModel
} from "./LayerZeroV2Harness.sol";

/// @notice Stateful specialist-fuzz harness for endpoint residual lzToken sweep risk.
contract MedusaLz3ResidualSweepHarness {
    uint256 internal constant INITIAL_MINT = 1_000_000_000_000;
    uint256 internal constant FEE = 99;
    uint256 internal constant MAX_STEP = 1_000_000_000;

    EndpointLzTokenSweepBugModel public bugModel;
    EndpointLzTokenSweepFixedModel public fixedModel;
    MockInboundFeeToken public bugToken;
    MockInboundFeeToken public fixedToken;

    bool public bugSwept;
    bool public fixedSwept;

    constructor() {
        bugToken = new MockInboundFeeToken(address(this), 0);
        fixedToken = new MockInboundFeeToken(address(this), 0);

        bugModel = new EndpointLzTokenSweepBugModel(address(bugToken), address(0xFEE1), FEE);
        fixedModel = new EndpointLzTokenSweepFixedModel(address(fixedToken), address(0xFEE1), FEE);

        bugToken.mint(address(this), INITIAL_MINT);
        fixedToken.mint(address(this), INITIAL_MINT);

        bugToken.approve(address(bugModel), type(uint256).max);
        fixedToken.approve(address(fixedModel), type(uint256).max);
    }

    function _step(uint256 seed) internal pure returns (uint256) {
        // Keep preload/payment above the fixed fee to exercise refund branches.
        return (seed % MAX_STEP) + 100;
    }

    function action_preload_bug(uint96 amountSeed) external {
        uint256 amount = _step(amountSeed);
        try bugModel.preloadResidual(amount) {} catch {}
    }

    function action_try_bug_sweep() external {
        uint256 before = bugToken.balanceOf(address(this));
        try bugModel.sendWithPayInLzToken(address(this)) returns (uint256 refunded) {
            uint256 afterBal = bugToken.balanceOf(address(this));
            if (refunded > 0 && afterBal > before) bugSwept = true;
        } catch {}
    }

    function action_preload_fixed(uint96 amountSeed) external {
        uint256 amount = _step(amountSeed);
        try fixedModel.preloadResidual(amount) {} catch {}
    }

    function action_try_fixed_send(uint96 amountSeed) external {
        uint256 amount = _step(amountSeed);
        uint256 residualBefore = fixedToken.balanceOf(address(fixedModel));
        try fixedModel.sendWithIsolatedPayment(address(this), amount) {} catch {}
        uint256 residualAfter = fixedToken.balanceOf(address(fixedModel));

        // Preloaded residual should remain untouched by caller-triggered send.
        if (residualAfter < residualBefore) fixedSwept = true;
    }

    function property_bug_residual_cannot_be_swept() external view returns (bool) {
        return !bugSwept;
    }

    function property_fixed_residual_cannot_be_swept() external view returns (bool) {
        return !fixedSwept;
    }

    function echidna_bug_residual_cannot_be_swept() external view returns (bool) {
        return !bugSwept;
    }
}


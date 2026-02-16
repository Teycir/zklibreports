// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {
    ConnextRouterLiquidityBugModel,
    ConnextRouterLiquidityFixedModel,
    MockSenderDebitTaxToken
} from "./ConnextRouterSenderTaxHarness.sol";

/// @notice Specialist-fuzz harness for Connext router-balance drift under sender-tax payout tokens.
contract MedusaConnextRouterSenderTaxHarness {
    uint256 internal constant INITIAL_MINT = 10_000_000_000_000;
    uint256 internal constant MIN_STEP = 10_000;
    uint256 internal constant MAX_STEP = 1_000_000_000;
    address internal constant ROUTER_A = address(0xA11CE);
    address internal constant ROUTER_B = address(0xB0B);
    address internal constant RECIPIENT = address(0xBEEF);

    MockSenderDebitTaxToken public bugToken;
    MockSenderDebitTaxToken public fixedToken;
    ConnextRouterLiquidityBugModel public bugModel;
    ConnextRouterLiquidityFixedModel public fixedModel;

    bool public bugBroken;
    bool public fixedBroken;

    constructor() {
        bugToken = new MockSenderDebitTaxToken(address(this), 500); // 5%
        fixedToken = new MockSenderDebitTaxToken(address(this), 500);

        bugModel = new ConnextRouterLiquidityBugModel(address(bugToken));
        fixedModel = new ConnextRouterLiquidityFixedModel(address(fixedToken));

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

    function _router(bool pickA) internal pure returns (address) {
        return pickA ? ROUTER_A : ROUTER_B;
    }

    function action_bug_add(uint96 amountSeed, bool useRouterA) external {
        uint256 amount = _step(amountSeed);
        try bugModel.addLiquidity(_router(useRouterA), amount) {} catch {}
        _refreshBug();
    }

    function action_bug_remove(uint96 amountSeed, bool useRouterA) external {
        address router = _router(useRouterA);
        uint256 bal = bugModel.routerBalances(router);
        if (bal == 0) return;
        uint256 amount = (uint256(amountSeed) % bal) + 1;
        try bugModel.removeLiquidity(router, RECIPIENT, amount) {} catch {}
        _refreshBug();
    }

    function action_fixed_add(uint96 amountSeed, bool useRouterA) external {
        uint256 amount = _step(amountSeed);
        try fixedModel.addLiquidity(_router(useRouterA), amount) {} catch {}
        _refreshFixed();
    }

    function action_fixed_remove(uint96 amountSeed, bool useRouterA) external {
        address router = _router(useRouterA);
        uint256 bal = fixedModel.routerBalances(router);
        if (bal == 0) return;
        uint256 amount = (uint256(amountSeed) % bal) + 1;
        try fixedModel.removeLiquidity(router, RECIPIENT, amount) {} catch {}
        _refreshFixed();
    }

    function _refreshBug() internal {
        if (bugToken.balanceOf(address(bugModel)) < bugModel.totalRouterBalances()) {
            bugBroken = true;
        }
    }

    function _refreshFixed() internal {
        if (fixedToken.balanceOf(address(fixedModel)) < fixedModel.totalRouterBalances()) {
            fixedBroken = true;
        }
    }

    function property_bug_collateral_covers_router_balances() external view returns (bool) {
        return !bugBroken;
    }

    function property_fixed_collateral_covers_router_balances() external view returns (bool) {
        return !fixedBroken;
    }

    function echidna_bug_collateral_covers_router_balances() external view returns (bool) {
        return !bugBroken;
    }
}

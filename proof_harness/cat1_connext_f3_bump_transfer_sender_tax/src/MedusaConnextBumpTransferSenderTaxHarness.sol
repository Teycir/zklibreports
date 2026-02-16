// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {
    ConnextBumpTransferBugModel,
    ConnextBumpTransferFixedModel,
    MockSenderDebitTaxToken
} from "./ConnextBumpTransferSenderTaxHarness.sol";

/// @notice Specialist-fuzz harness for `bumpTransfer` sender-tax induced collateral drift.
contract MedusaConnextBumpTransferSenderTaxHarness {
    uint256 internal constant INITIAL_MINT = 10_000_000_000_000;
    uint256 internal constant MIN_STEP = 10_000;
    uint256 internal constant MAX_STEP = 1_000_000_000;
    address internal constant ROUTER_A = address(0xA11CE);
    address internal constant ROUTER_B = address(0xB0B);
    address internal constant RELAYER_VAULT = address(0xFEE1);

    MockSenderDebitTaxToken public bugToken;
    MockSenderDebitTaxToken public fixedToken;
    ConnextBumpTransferBugModel public bugModel;
    ConnextBumpTransferFixedModel public fixedModel;

    bool public bugBroken;
    bool public fixedBroken;

    constructor() {
        bugToken = new MockSenderDebitTaxToken(address(this), 500); // 5%
        fixedToken = new MockSenderDebitTaxToken(address(this), 500);

        bugModel = new ConnextBumpTransferBugModel(address(bugToken), RELAYER_VAULT);
        fixedModel = new ConnextBumpTransferFixedModel(address(fixedToken), RELAYER_VAULT);

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

    function action_bug_add_router_liquidity(uint96 amountSeed, bool useRouterA) external {
        uint256 amount = _step(amountSeed);
        try bugModel.addRouterLiquidity(_router(useRouterA), amount) {} catch {}
        _refreshBug();
    }

    function action_bug_bump_transfer(uint96 feeSeed) external {
        uint256 fee = _step(feeSeed);
        try bugModel.bumpTransferLike(fee) {} catch {}
        _refreshBug();
    }

    function action_fixed_add_router_liquidity(uint96 amountSeed, bool useRouterA) external {
        uint256 amount = _step(amountSeed);
        try fixedModel.addRouterLiquidity(_router(useRouterA), amount) {} catch {}
        _refreshFixed();
    }

    function action_fixed_bump_transfer(uint96 feeSeed) external {
        uint256 fee = _step(feeSeed);
        try fixedModel.bumpTransferLike(fee) {} catch {}
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

    function property_bug_collateral_covers_router_balances_after_bump() external view returns (bool) {
        return !bugBroken;
    }

    function property_fixed_collateral_covers_router_balances_after_bump() external view returns (bool) {
        return !fixedBroken;
    }

    function echidna_bug_collateral_covers_router_balances_after_bump() external view returns (bool) {
        return !bugBroken;
    }
}

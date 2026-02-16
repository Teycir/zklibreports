// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {
    ConnextRouterLiquidityBugModel,
    ConnextRouterLiquidityFixedModel,
    MockSenderDebitTaxToken
} from "../src/ConnextRouterSenderTaxHarness.sol";

contract ConnextRouterSenderTaxTest {
    address internal constant ROUTER_A = address(0xA11CE);
    address internal constant ROUTER_B = address(0xB0B);
    address internal constant RECIPIENT = address(0xBEEF);

    function _assertTrue(bool condition, string memory message) internal pure {
        require(condition, message);
    }

    /// @notice F1 witness: sender-tax payout can push collateral below outstanding router balances.
    function test_f1_bug_model_sender_tax_withdraw_breaks_collateral_vs_router_balances() public {
        MockSenderDebitTaxToken token = new MockSenderDebitTaxToken(address(this), 500); // 5%
        ConnextRouterLiquidityBugModel bug = new ConnextRouterLiquidityBugModel(address(token));
        token.setTaxSender(address(bug));

        token.mint(address(this), 500_000);
        token.approve(address(bug), type(uint256).max);

        bug.addLiquidity(ROUTER_A, 100_000);
        bug.addLiquidity(ROUTER_B, 100_000);

        bug.removeLiquidity(ROUTER_A, RECIPIENT, 100_000);

        uint256 collateral = token.balanceOf(address(bug));
        uint256 totalRouterBalances = bug.totalRouterBalances();
        _assertTrue(collateral == 95_000, "expected sender-tax extra debit from contract");
        _assertTrue(totalRouterBalances == 100_000, "expected remaining router liabilities");
        _assertTrue(collateral < totalRouterBalances, "expected collateral deficit");
    }

    /// @notice F1 control: fixed model rejects sender-tax payouts and preserves invariant.
    function test_f1_fixed_model_rejects_sender_tax_withdrawal() public {
        MockSenderDebitTaxToken token = new MockSenderDebitTaxToken(address(this), 500); // 5%
        ConnextRouterLiquidityFixedModel fixedModel = new ConnextRouterLiquidityFixedModel(address(token));
        token.setTaxSender(address(fixedModel));

        token.mint(address(this), 500_000);
        token.approve(address(fixedModel), type(uint256).max);

        fixedModel.addLiquidity(ROUTER_A, 100_000);
        fixedModel.addLiquidity(ROUTER_B, 100_000);

        bool reverted = false;
        try fixedModel.removeLiquidity(ROUTER_A, RECIPIENT, 100_000) {} catch {
            reverted = true;
        }

        _assertTrue(reverted, "expected sender-tax rejection");
        _assertTrue(token.balanceOf(address(fixedModel)) == 200_000, "expected unchanged collateral");
        _assertTrue(fixedModel.totalRouterBalances() == 200_000, "expected unchanged liabilities");
    }

    /// @notice F1 fuzz witness: taxed payout can violate collateral >= outstanding router balances.
    function testFuzz_f1_bug_model_sender_tax_can_break_collateral_invariant(uint96 amountSeed) public {
        uint256 amount = (uint256(amountSeed) % 1_000_000_000) + 10_000;

        MockSenderDebitTaxToken token = new MockSenderDebitTaxToken(address(this), 500);
        ConnextRouterLiquidityBugModel bug = new ConnextRouterLiquidityBugModel(address(token));
        token.setTaxSender(address(bug));

        token.mint(address(this), (amount * 2) + amount);
        token.approve(address(bug), type(uint256).max);

        bug.addLiquidity(ROUTER_A, amount);
        bug.addLiquidity(ROUTER_B, amount);
        bug.removeLiquidity(ROUTER_A, RECIPIENT, amount);

        uint256 collateral = token.balanceOf(address(bug));
        uint256 totalRouterBalances = bug.totalRouterBalances();
        _assertTrue(collateral < totalRouterBalances, "expected collateral deficit in bug model");
    }
}

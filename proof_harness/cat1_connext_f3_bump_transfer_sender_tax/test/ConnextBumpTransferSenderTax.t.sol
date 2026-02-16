// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {
    ConnextBumpTransferBugModel,
    ConnextBumpTransferFixedModel,
    MockSenderDebitTaxToken
} from "../src/ConnextBumpTransferSenderTaxHarness.sol";

contract ConnextBumpTransferSenderTaxTest {
    address internal constant ROUTER_A = address(0xA11CE);
    address internal constant ROUTER_B = address(0xB0B);
    address internal constant RELAYER_VAULT = address(0xFEE1);

    function _assertTrue(bool condition, string memory message) internal pure {
        require(condition, message);
    }

    /// @notice F3 witness: sender-tax on fee payout can consume bridge collateral during bump transfer.
    function test_f3_bug_model_sender_tax_bump_transfer_breaks_collateral_vs_router_balances() public {
        MockSenderDebitTaxToken token = new MockSenderDebitTaxToken(address(this), 500); // 5%
        ConnextBumpTransferBugModel bug = new ConnextBumpTransferBugModel(address(token), RELAYER_VAULT);
        token.setTaxSender(address(bug));

        token.mint(address(this), 1_000_000);
        token.approve(address(bug), type(uint256).max);

        bug.addRouterLiquidity(ROUTER_A, 100_000);
        bug.addRouterLiquidity(ROUTER_B, 100_000);
        bug.bumpTransferLike(100_000);

        uint256 collateral = token.balanceOf(address(bug));
        uint256 totalRouterBalances = bug.totalRouterBalances();
        _assertTrue(collateral == 195_000, "expected extra sender-tax debit on fee payout");
        _assertTrue(totalRouterBalances == 200_000, "expected unchanged router liabilities");
        _assertTrue(collateral < totalRouterBalances, "expected collateral deficit after bumpTransfer");
    }

    /// @notice F3 control: fixed model rejects sender-tax fee payout and preserves collateral coverage.
    function test_f3_fixed_model_rejects_sender_tax_bump_transfer() public {
        MockSenderDebitTaxToken token = new MockSenderDebitTaxToken(address(this), 500); // 5%
        ConnextBumpTransferFixedModel fixedModel = new ConnextBumpTransferFixedModel(address(token), RELAYER_VAULT);
        token.setTaxSender(address(fixedModel));

        token.mint(address(this), 1_000_000);
        token.approve(address(fixedModel), type(uint256).max);

        fixedModel.addRouterLiquidity(ROUTER_A, 100_000);
        fixedModel.addRouterLiquidity(ROUTER_B, 100_000);

        bool reverted = false;
        try fixedModel.bumpTransferLike(100_000) {} catch {
            reverted = true;
        }

        _assertTrue(reverted, "expected sender-tax rejection");
        _assertTrue(token.balanceOf(address(fixedModel)) == 200_000, "expected unchanged collateral");
        _assertTrue(fixedModel.totalRouterBalances() == 200_000, "expected unchanged liabilities");
    }

    /// @notice F3 fuzz witness: taxed fee payout can violate collateral >= outstanding router balances.
    function testFuzz_f3_bug_model_sender_tax_bump_transfer_can_break_collateral_invariant(uint96 amountSeed) public {
        uint256 amount = (uint256(amountSeed) % 1_000_000_000) + 10_000;

        MockSenderDebitTaxToken token = new MockSenderDebitTaxToken(address(this), 500);
        ConnextBumpTransferBugModel bug = new ConnextBumpTransferBugModel(address(token), RELAYER_VAULT);
        token.setTaxSender(address(bug));

        token.mint(address(this), amount * 10);
        token.approve(address(bug), type(uint256).max);

        bug.addRouterLiquidity(ROUTER_A, amount);
        bug.addRouterLiquidity(ROUTER_B, amount);
        bug.bumpTransferLike(amount);

        uint256 collateral = token.balanceOf(address(bug));
        uint256 totalRouterBalances = bug.totalRouterBalances();
        _assertTrue(collateral < totalRouterBalances, "expected collateral deficit in bug model");
    }
}

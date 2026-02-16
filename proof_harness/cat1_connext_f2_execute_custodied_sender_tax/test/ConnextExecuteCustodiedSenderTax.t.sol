// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {
    ConnextExecuteCustodiedBugModel,
    ConnextExecuteCustodiedFixedModel,
    MockSenderDebitTaxToken
} from "../src/ConnextExecuteCustodiedSenderTaxHarness.sol";

contract ConnextExecuteCustodiedSenderTaxTest {
    address internal constant RECIPIENT = address(0xBEEF);

    function _assertTrue(bool condition, string memory message) internal pure {
        require(condition, message);
    }

    /// @notice F2 witness: sender-tax payout can push collateral below tracked `custodied`.
    function test_f2_bug_model_sender_tax_execute_breaks_collateral_vs_custodied() public {
        MockSenderDebitTaxToken token = new MockSenderDebitTaxToken(address(this), 500); // 5%
        ConnextExecuteCustodiedBugModel bug = new ConnextExecuteCustodiedBugModel(address(token));
        token.setTaxSender(address(bug));

        token.mint(address(this), 500_000);
        token.approve(address(bug), type(uint256).max);

        bug.seedCustody(200_000);
        bug.executeTransfer(RECIPIENT, 100_000);

        uint256 collateral = token.balanceOf(address(bug));
        uint256 custodied = bug.custodied();
        _assertTrue(collateral == 95_000, "expected extra sender-tax debit");
        _assertTrue(custodied == 100_000, "expected intent-level custodied decrement");
        _assertTrue(collateral < custodied, "expected collateral deficit vs custodied");
    }

    /// @notice F2 control: fixed model rejects sender-tax payout path.
    function test_f2_fixed_model_rejects_sender_tax_execute() public {
        MockSenderDebitTaxToken token = new MockSenderDebitTaxToken(address(this), 500); // 5%
        ConnextExecuteCustodiedFixedModel fixedModel = new ConnextExecuteCustodiedFixedModel(address(token));
        token.setTaxSender(address(fixedModel));

        token.mint(address(this), 500_000);
        token.approve(address(fixedModel), type(uint256).max);

        fixedModel.seedCustody(200_000);

        bool reverted = false;
        try fixedModel.executeTransfer(RECIPIENT, 100_000) {} catch {
            reverted = true;
        }

        _assertTrue(reverted, "expected sender-tax rejection");
        _assertTrue(token.balanceOf(address(fixedModel)) == 200_000, "expected unchanged collateral");
        _assertTrue(fixedModel.custodied() == 200_000, "expected unchanged custodied");
    }

    /// @notice F2 fuzz witness: taxed execute payout can violate collateral >= custodied.
    function testFuzz_f2_bug_model_sender_tax_can_break_collateral_vs_custodied(uint96 amountSeed) public {
        uint256 amount = (uint256(amountSeed) % 1_000_000_000) + 10_000;

        MockSenderDebitTaxToken token = new MockSenderDebitTaxToken(address(this), 500);
        ConnextExecuteCustodiedBugModel bug = new ConnextExecuteCustodiedBugModel(address(token));
        token.setTaxSender(address(bug));

        token.mint(address(this), amount * 3);
        token.approve(address(bug), type(uint256).max);

        bug.seedCustody(amount * 2);
        bug.executeTransfer(RECIPIENT, amount);

        uint256 collateral = token.balanceOf(address(bug));
        uint256 custodied = bug.custodied();
        _assertTrue(collateral < custodied, "expected collateral deficit in bug model");
    }
}

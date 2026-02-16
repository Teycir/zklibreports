// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {
    ISynapseRoleTarget,
    MockSenderTaxTokenV2,
    RoleCaller,
    SynapseMinOutBugModel,
    SynapseMinOutFixedModel,
    SynapseRoleEscalationBugModel,
    SynapseRoleEscalationFixedModel
} from "../src/SynapseRoleAndMinOutHarness.sol";

contract SynapseF2F3Test {
    function _assertTrue(bool condition, string memory message) internal pure {
        require(condition, message);
    }

    /// @notice F2 witness: default-admin compromise can self-grant node role and drain collateral.
    function test_f2_bug_model_admin_can_grant_node_and_drain() public {
        RoleCaller admin = new RoleCaller();
        RoleCaller attacker = new RoleCaller();
        SynapseRoleEscalationBugModel bug = new SynapseRoleEscalationBugModel(address(admin), 10 ether);

        admin.callGrant(ISynapseRoleTarget(address(bug)), address(attacker));
        attacker.callWithdraw(ISynapseRoleTarget(address(bug)), payable(address(this)), 10 ether);

        _assertTrue(bug.collateral() == 0, "expected drained collateral");
        _assertTrue(bug.credited(address(this)) == 10 ether, "expected attacker-drained credit");
    }

    /// @notice F2 control: hardening node-role assignment blocks default-admin-only escalation.
    function test_f2_fixed_model_admin_only_cannot_grant_node_or_drain() public {
        RoleCaller admin = new RoleCaller();
        RoleCaller governance = new RoleCaller();
        RoleCaller attacker = new RoleCaller();
        SynapseRoleEscalationFixedModel fixedModel =
            new SynapseRoleEscalationFixedModel(address(admin), address(governance), 10 ether);

        bool grantReverted = false;
        try admin.callGrant(ISynapseRoleTarget(address(fixedModel)), address(attacker)) {} catch {
            grantReverted = true;
        }
        _assertTrue(grantReverted, "expected admin grant to revert");

        bool drainReverted = false;
        try attacker.callWithdraw(ISynapseRoleTarget(address(fixedModel)), payable(address(this)), 1 ether) {} catch {
            drainReverted = true;
        }
        _assertTrue(drainReverted, "expected non-node withdraw to revert");
        _assertTrue(fixedModel.collateral() == 10 ether, "expected full collateral retained");
        _assertTrue(fixedModel.credited(address(this)) == 0, "expected no credited drain");
    }

    /// @notice F3 witness: quote-level minOut can pass while user receives less after payout transfer tax.
    function test_f3_bug_model_min_out_not_enforced_on_actual_user_receipt() public {
        MockSenderTaxTokenV2 token = new MockSenderTaxTokenV2(address(this), 500); // 5%
        SynapseMinOutBugModel bug = new SynapseMinOutBugModel(address(token));
        token.setTaxSender(address(bug));
        token.mint(address(bug), 1_000_000);

        address recipient = address(0xBEEF);
        uint256 actualReceived = bug.settleSwap(recipient, 100_000, 98_000);

        _assertTrue(actualReceived == 95_000, "expected payout haircut");
        _assertTrue(actualReceived < 98_000, "expected minOut violation");
        _assertTrue(token.balanceOf(recipient) == 95_000, "expected recipient under-delivery");
    }

    /// @notice F3 control: fixed model checks recipient balance delta against minOut.
    function test_f3_fixed_model_reverts_when_actual_received_below_min_out() public {
        MockSenderTaxTokenV2 token = new MockSenderTaxTokenV2(address(this), 500); // 5%
        SynapseMinOutFixedModel fixedModel = new SynapseMinOutFixedModel(address(token));
        token.setTaxSender(address(fixedModel));
        token.mint(address(fixedModel), 1_000_000);

        bool reverted = false;
        try fixedModel.settleSwap(address(0xBEEF), 100_000, 98_000) returns (uint256) {} catch {
            reverted = true;
        }

        _assertTrue(reverted, "expected minOut enforcement revert");
        _assertTrue(token.balanceOf(address(0xBEEF)) == 0, "expected no transfer on revert");
    }

    /// @notice F3 fuzz witness: for some minOut > actual-received, bug model still succeeds.
    function testFuzz_f3_bug_model_can_underdeliver_vs_min_out(uint96 amountSeed, uint16 minSeed) public {
        uint256 quotedOut = (uint256(amountSeed) % 1_000_000_000) + 10_000;
        uint256 minOutBps = (uint256(minSeed) % 401) + 9600; // 96%-100%
        uint256 minOut = (quotedOut * minOutBps) / 10_000;

        uint256 actualExpected = (quotedOut * 9500) / 10_000; // 5% sender tax
        if (minOut <= actualExpected) return;

        MockSenderTaxTokenV2 token = new MockSenderTaxTokenV2(address(this), 500);
        SynapseMinOutBugModel bug = new SynapseMinOutBugModel(address(token));
        token.setTaxSender(address(bug));
        token.mint(address(bug), quotedOut);
        address recipient = address(0xBEEF);
        uint256 beforeBal = token.balanceOf(recipient);

        uint256 actualReceived = bug.settleSwap(recipient, quotedOut, minOut);
        uint256 afterBal = token.balanceOf(recipient);
        uint256 recipientDelta = afterBal - beforeBal;
        _assertTrue(actualReceived == recipientDelta, "expected modeled recipient delta");
        _assertTrue(actualReceived < minOut, "expected under-delivery with successful settlement");
    }
}

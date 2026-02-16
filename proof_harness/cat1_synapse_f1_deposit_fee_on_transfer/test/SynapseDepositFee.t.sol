// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {
    MockInboundFeeToken,
    SynapseDepositBugModel,
    SynapseDepositFixedModel
} from "../src/SynapseDepositFeeHarness.sol";

contract SynapseDepositFeeTest {
    function _assertTrue(bool condition, string memory message) internal pure {
        require(condition, message);
    }

    /// @notice F1 witness: intent-level deposit accounting can over-credit cross-chain liability.
    function test_f1_bug_model_deposit_fee_on_transfer_breaks_collateral_invariant() public {
        MockInboundFeeToken token = new MockInboundFeeToken(address(this), 500); // 5%
        SynapseDepositBugModel bug = new SynapseDepositBugModel(address(token));
        token.setFeeTarget(address(bug));

        token.mint(address(this), 1_000_000);
        token.approve(address(bug), type(uint256).max);

        bug.deposit(100_000);

        uint256 collateral = token.balanceOf(address(bug));
        uint256 liability = bug.remoteLiability();
        _assertTrue(collateral == 95_000, "expected inbound fee haircut");
        _assertTrue(liability == 100_000, "expected intent-level liability");
        _assertTrue(collateral < liability, "expected collateral deficit");
    }

    /// @notice F1 witness applies equally to depositAndSwap path.
    function test_f1_bug_model_deposit_and_swap_fee_on_transfer_breaks_collateral_invariant() public {
        MockInboundFeeToken token = new MockInboundFeeToken(address(this), 500); // 5%
        SynapseDepositBugModel bug = new SynapseDepositBugModel(address(token));
        token.setFeeTarget(address(bug));

        token.mint(address(this), 1_000_000);
        token.approve(address(bug), type(uint256).max);

        bug.depositAndSwap(100_000);

        uint256 collateral = token.balanceOf(address(bug));
        uint256 liability = bug.remoteLiability();
        _assertTrue(collateral == 95_000, "expected inbound fee haircut");
        _assertTrue(liability == 100_000, "expected intent-level liability");
        _assertTrue(collateral < liability, "expected collateral deficit");
    }

    /// @notice F1 control: fixed model credits by actual received collateral.
    function test_f1_fixed_model_tracks_actual_received() public {
        MockInboundFeeToken token = new MockInboundFeeToken(address(this), 500); // 5%
        SynapseDepositFixedModel fixedModel = new SynapseDepositFixedModel(address(token));
        token.setFeeTarget(address(fixedModel));

        token.mint(address(this), 1_000_000);
        token.approve(address(fixedModel), type(uint256).max);

        fixedModel.deposit(100_000);
        fixedModel.depositAndSwap(100_000);

        uint256 collateral = token.balanceOf(address(fixedModel));
        uint256 liability = fixedModel.remoteLiability();
        _assertTrue(collateral == 190_000, "expected actual collateral");
        _assertTrue(liability == 190_000, "expected received-amount liability");
        _assertTrue(collateral == liability, "expected collateral coverage");
    }

    /// @notice F1 fuzz witness: non-zero fee can produce collateral < remote liability in bug model.
    function testFuzz_f1_bug_model_deposit_can_break_collateral_invariant(uint96 amountSeed, uint16 feeSeed) public {
        uint16 bps = uint16((uint256(feeSeed) % 2_000) + 1); // 0.01%..20%
        uint256 amount = (uint256(amountSeed) % 1_000_000_000) + 10_000;

        MockInboundFeeToken token = new MockInboundFeeToken(address(this), bps);
        SynapseDepositBugModel bug = new SynapseDepositBugModel(address(token));
        token.setFeeTarget(address(bug));

        token.mint(address(this), amount + 1);
        token.approve(address(bug), type(uint256).max);

        bug.deposit(amount);
        uint256 collateral = token.balanceOf(address(bug));
        uint256 liability = bug.remoteLiability();
        _assertTrue(collateral < liability, "expected collateral deficit in bug model");
    }
}

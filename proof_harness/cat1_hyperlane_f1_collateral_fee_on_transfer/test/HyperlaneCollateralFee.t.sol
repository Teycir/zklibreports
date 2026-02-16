// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {
    HyperlaneCollateralBugModel,
    HyperlaneCollateralFixedModel,
    MockInboundFeeToken
} from "../src/HyperlaneCollateralFeeHarness.sol";

contract HyperlaneCollateralFeeTest {
    function _assertTrue(bool condition, string memory message) internal pure {
        require(condition, message);
    }

    /// @notice H1 witness: fee-on-transfer inbound behavior can create collateral deficit.
    function test_h1_bug_model_fee_on_transfer_breaks_collateral_invariant() public {
        MockInboundFeeToken token = new MockInboundFeeToken(address(this), 500); // 5%
        HyperlaneCollateralBugModel bug = new HyperlaneCollateralBugModel(address(token), 1);
        token.setFeeTarget(address(bug));

        token.mint(address(this), 1_000_000);
        token.approve(address(bug), type(uint256).max);

        (uint256 sent, uint256 credited) = bug.transferRemote(100_000, 100_000);
        _assertTrue(sent == 100_000, "unexpected sent");
        _assertTrue(credited == 100_000, "unexpected credited");

        uint256 collateral = token.balanceOf(address(bug));
        uint256 liability = bug.remoteLiabilityLD();

        _assertTrue(collateral == 95_000, "expected inbound fee haircut");
        _assertTrue(liability == 100_000, "expected intent-level remote liability");
        _assertTrue(collateral < liability, "expected collateral deficit");
    }

    /// @notice H1 control: fixed model measures actual received amount.
    function test_h1_fixed_model_tracks_actual_received_and_rejects_overstrict_min() public {
        MockInboundFeeToken token = new MockInboundFeeToken(address(this), 500); // 5%
        HyperlaneCollateralFixedModel fixedModel = new HyperlaneCollateralFixedModel(address(token), 1);
        token.setFeeTarget(address(fixedModel));

        token.mint(address(this), 1_000_000);
        token.approve(address(fixedModel), type(uint256).max);

        bool reverted;
        try fixedModel.transferRemote(100_000, 100_000) {
            reverted = false;
        } catch {
            reverted = true;
        }
        _assertTrue(reverted, "expected strict-min slippage revert");

        (uint256 sent, uint256 credited) = fixedModel.transferRemote(100_000, 95_000);
        _assertTrue(sent == 100_000, "unexpected sent");
        _assertTrue(credited == 95_000, "expected actual received credit");

        uint256 collateral = token.balanceOf(address(fixedModel));
        uint256 liability = fixedModel.remoteLiabilityLD();
        _assertTrue(collateral == liability, "fixed model must keep collateral == liability");
    }

    /// @notice H1 fuzz witness: for non-zero fee and sufficient amount, bug model breaks collateral coverage.
    function testFuzz_h1_bug_model_can_break_collateral_invariant(uint96 amountSeed, uint16 feeSeed) public {
        uint16 bps = uint16((uint256(feeSeed) % 2_000) + 1); // 0.01%..20%
        uint256 amount = (uint256(amountSeed) % 1_000_000_000) + 10_000;

        MockInboundFeeToken token = new MockInboundFeeToken(address(this), bps);
        HyperlaneCollateralBugModel bug = new HyperlaneCollateralBugModel(address(token), 1);
        token.setFeeTarget(address(bug));

        token.mint(address(this), amount + 1);
        token.approve(address(bug), type(uint256).max);

        bug.transferRemote(amount, amount);

        uint256 collateral = token.balanceOf(address(bug));
        uint256 liability = bug.remoteLiabilityLD();
        _assertTrue(collateral < liability, "expected collateral deficit in bug model");
    }
}

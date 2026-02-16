// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {
    HyperlaneLpAssetsBugModel,
    HyperlaneLpAssetsFixedModel,
    HyperlaneFeeTransferBugModel,
    HyperlaneFeeTransferFixedModel,
    MockInboundFeeTokenV2,
    MockSenderTaxTokenV2
} from "../src/HyperlaneLpAndFeeHarness.sol";

contract HyperlaneLpAndFeeFindingsTest {
    function _assertTrue(bool condition, string memory message) internal pure {
        require(condition, message);
    }

    /// @notice H2 witness: LP accounting can overstate assets vs real collateral for inbound-fee tokens.
    function test_h2_bug_model_lp_assets_overstated_and_withdraw_reverts() public {
        MockInboundFeeTokenV2 token = new MockInboundFeeTokenV2(address(this), 500); // 5%
        HyperlaneLpAssetsBugModel bug = new HyperlaneLpAssetsBugModel(address(token));
        token.setFeeTarget(address(bug));

        token.mint(address(this), 1_000_000);
        token.approve(address(bug), type(uint256).max);

        bug.deposit(100_000);

        uint256 collateral = token.balanceOf(address(bug));
        uint256 assets = bug.lpAssets();
        _assertTrue(collateral == 95_000, "expected 5% collateral haircut");
        _assertTrue(assets == 100_000, "expected intent-level lpAssets");
        _assertTrue(collateral < assets, "expected lpAssets overstatement");

        bool reverted;
        try bug.withdraw(100_000) {
            reverted = false;
        } catch {
            reverted = true;
        }
        _assertTrue(reverted, "expected withdraw revert from collateral shortfall");
    }

    /// @notice H2 control: fixed model tracks actual received collateral.
    function test_h2_fixed_model_tracks_received_assets_and_withdraw_succeeds() public {
        MockInboundFeeTokenV2 token = new MockInboundFeeTokenV2(address(this), 500); // 5%
        HyperlaneLpAssetsFixedModel fixedModel = new HyperlaneLpAssetsFixedModel(address(token));
        token.setFeeTarget(address(fixedModel));

        token.mint(address(this), 1_000_000);
        token.approve(address(fixedModel), type(uint256).max);

        fixedModel.deposit(100_000);
        uint256 shares = fixedModel.shares(address(this));
        _assertTrue(shares == 95_000, "expected received-amount shares");
        _assertTrue(token.balanceOf(address(fixedModel)) == 95_000, "expected matching collateral");
        _assertTrue(fixedModel.lpAssets() == 95_000, "expected matching lpAssets");

        fixedModel.withdraw(95_000);
        _assertTrue(fixedModel.lpAssets() == 0, "expected full withdrawal");
        _assertTrue(token.balanceOf(address(fixedModel)) == 0, "expected collateral drained to zero");
    }

    /// @notice H2 fuzz witness: non-zero inbound fee can produce collateral < lpAssets in bug model.
    function testFuzz_h2_bug_model_lp_assets_can_exceed_collateral(uint96 amountSeed, uint16 feeSeed) public {
        uint16 bps = uint16((uint256(feeSeed) % 2_000) + 1); // 0.01%..20%
        uint256 amount = (uint256(amountSeed) % 1_000_000_000) + 10_000;

        MockInboundFeeTokenV2 token = new MockInboundFeeTokenV2(address(this), bps);
        HyperlaneLpAssetsBugModel bug = new HyperlaneLpAssetsBugModel(address(token));
        token.setFeeTarget(address(bug));

        token.mint(address(this), amount + 1);
        token.approve(address(bug), type(uint256).max);

        bug.deposit(amount);

        uint256 collateral = token.balanceOf(address(bug));
        uint256 assets = bug.lpAssets();
        _assertTrue(collateral < assets, "expected lpAssets overstatement");
    }

    /// @notice H3 witness: sender-tax fee transfer can break collateral coverage after charging fees.
    function test_h3_bug_model_sender_tax_fee_transfer_breaks_collateral_invariant() public {
        MockSenderTaxTokenV2 token = new MockSenderTaxTokenV2(address(this), 10_000); // 100%
        HyperlaneFeeTransferBugModel bug = new HyperlaneFeeTransferBugModel(address(token), address(this));
        token.setTaxSender(address(bug));

        token.mint(address(this), 1_000_000);
        token.approve(address(bug), type(uint256).max);

        bug.transferRemoteWithFee(100_000, 10_000);

        uint256 collateral = token.balanceOf(address(bug));
        uint256 liability = bug.remoteLiabilityLD();
        _assertTrue(collateral == 90_000, "expected sender-tax haircut on fee transfer");
        _assertTrue(liability == 100_000, "expected full remote liability");
        _assertTrue(collateral < liability, "expected collateral deficit");
    }

    /// @notice H3 control: fixed model rejects unexpected sender-side debit during fee transfer.
    function test_h3_fixed_model_rejects_sender_tax_fee_transfer() public {
        MockSenderTaxTokenV2 token = new MockSenderTaxTokenV2(address(this), 10_000); // 100%
        HyperlaneFeeTransferFixedModel fixedModel = new HyperlaneFeeTransferFixedModel(address(token), address(this));
        token.setTaxSender(address(fixedModel));

        token.mint(address(this), 1_000_000);
        token.approve(address(fixedModel), type(uint256).max);

        bool reverted;
        try fixedModel.transferRemoteWithFee(100_000, 10_000) {
            reverted = false;
        } catch {
            reverted = true;
        }

        _assertTrue(reverted, "expected fixed-model sender-tax rejection");
        _assertTrue(fixedModel.remoteLiabilityLD() == 0, "expected no liability accrual on revert");
    }

    /// @notice H3 fuzz witness: sender-tax on fee transfers can force collateral < liability in bug model.
    function testFuzz_h3_bug_model_sender_tax_fee_transfer_breaks_collateral(
        uint96 amountSeed,
        uint96 feeSeed,
        uint16 taxSeed
    ) public {
        uint16 taxBps = uint16((uint256(taxSeed) % 2_000) + 1); // 0.01%..20%
        uint256 feeAmount = (uint256(feeSeed) % 1_000_000) + 10_000;
        uint256 taxExtra = (feeAmount * uint256(taxBps)) / 10_000;
        uint256 amount = taxExtra + 1 + (uint256(amountSeed) % 1_000_000);

        MockSenderTaxTokenV2 token = new MockSenderTaxTokenV2(address(this), taxBps);
        HyperlaneFeeTransferBugModel bug = new HyperlaneFeeTransferBugModel(address(token), address(this));
        token.setTaxSender(address(bug));

        uint256 mintAmount = amount + feeAmount + taxExtra + 10_000;
        token.mint(address(this), mintAmount);
        token.approve(address(bug), type(uint256).max);

        bug.transferRemoteWithFee(amount, feeAmount);

        uint256 collateral = token.balanceOf(address(bug));
        uint256 liability = bug.remoteLiabilityLD();
        _assertTrue(collateral < liability, "expected sender-tax collateral deficit");
    }
}

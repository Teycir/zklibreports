// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {
    MockBridgeSenderTaxToken,
    OutboundSenderTaxBugModel,
    OutboundSenderTaxFixedModel
} from "../src/OutboundSenderTaxHarness.sol";

contract OutboundSenderTaxTest {
    address internal constant ATTACKER = address(0xA11CE);
    uint256 internal constant INITIAL_MINT = 1_000_000 ether;

    function _assertTrue(bool _condition, string memory _message) internal pure {
        require(_condition, _message);
    }

    function _setup()
        internal
        returns (
            OutboundSenderTaxBugModel _bug,
            OutboundSenderTaxFixedModel _fixed,
            MockBridgeSenderTaxToken _bugToken,
            MockBridgeSenderTaxToken _fixedToken
        )
    {
        _bug = new OutboundSenderTaxBugModel();
        _fixed = new OutboundSenderTaxFixedModel();

        _bugToken = new MockBridgeSenderTaxToken(address(_bug), ATTACKER, 10_000);
        _fixedToken = new MockBridgeSenderTaxToken(address(_fixed), ATTACKER, 10_000);

        _bugToken.mint(address(this), INITIAL_MINT);
        _fixedToken.mint(address(this), INITIAL_MINT);

        _bugToken.approve(address(_bug), type(uint256).max);
        _fixedToken.approve(address(_fixed), type(uint256).max);
    }

    /// @notice Witness: outbound sender-tax can break bridge collateral coverage in bug model.
    function test_bug_model_outbound_sender_tax_breaks_solvency() public {
        (
            OutboundSenderTaxBugModel bug,
            ,
            MockBridgeSenderTaxToken bugToken,
            
        ) = _setup();

        bug.depositAndBridgeOut(address(bugToken), address(this), 200 ether);
        bug.completeTransfer(address(bugToken), ATTACKER, 100 ether);

        uint256 collateral = bugToken.balanceOf(address(bug));
        uint256 out = bug.outstanding(address(bugToken));

        _assertTrue(collateral == 0, "expected bridge collateral drained to zero");
        _assertTrue(out == 100 ether, "expected residual outstanding liability");
        _assertTrue(collateral < out, "expected insolvency");
    }

    /// @notice Control: fixed model rejects unexpected sender-side debit.
    function test_fixed_model_rejects_outbound_sender_tax() public {
        (
            ,
            OutboundSenderTaxFixedModel fixedModel,
            ,
            MockBridgeSenderTaxToken fixedToken
        ) = _setup();

        fixedModel.depositAndBridgeOut(address(fixedToken), address(this), 200 ether);

        bool reverted;
        try fixedModel.completeTransfer(address(fixedToken), ATTACKER, 100 ether) {
            reverted = false;
        } catch {
            reverted = true;
        }

        _assertTrue(reverted, "expected fixed-model rejection");
        _assertTrue(
            fixedModel.outstanding(address(fixedToken)) == 200 ether,
            "expected outstanding unchanged"
        );
        _assertTrue(
            fixedToken.balanceOf(address(fixedModel)) == 200 ether,
            "expected collateral preserved"
        );
    }

    /// @notice Fuzz witness: bug model can violate collateral>=outstanding after outbound redemption.
    function testFuzz_bug_model_can_break_solvency(uint96 depositSeed, uint96 redeemSeed)
        public
    {
        (
            OutboundSenderTaxBugModel bug,
            ,
            MockBridgeSenderTaxToken bugToken,
            
        ) = _setup();

        uint256 deposit = (uint256(depositSeed) % 10_000 ether) + 2;
        uint256 maxRedeem = deposit / 2;
        uint256 redeem = (uint256(redeemSeed) % maxRedeem) + 1;

        bug.depositAndBridgeOut(address(bugToken), address(this), deposit);
        bug.completeTransfer(address(bugToken), ATTACKER, redeem);

        uint256 collateral = bugToken.balanceOf(address(bug));
        uint256 out = bug.outstanding(address(bugToken));
        _assertTrue(collateral < out, "expected solvency break in bug model");
    }
}

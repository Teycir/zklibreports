// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {
    MockInboundFeeToken,
    OFTAdapterBugModel,
    OFTAdapterFixedModel,
    EndpointDelegateAuthModel,
    BuggyOAppOwnershipModel,
    FixedOAppOwnershipModel,
    EndpointLzTokenSweepBugModel,
    EndpointLzTokenSweepFixedModel
} from "../src/LayerZeroV2Harness.sol";

contract LayerZeroV2FindingsTest {
    function _assertTrue(bool condition, string memory message) internal pure {
        require(condition, message);
    }

    /// @notice LZ1 witness: bug-model adapter overstates remote liability for inbound-fee tokens.
    function test_lz1_bug_model_fee_on_transfer_breaks_collateral_invariant() public {
        MockInboundFeeToken token = new MockInboundFeeToken(address(this), 500); // 5%
        OFTAdapterBugModel bug = new OFTAdapterBugModel(address(token));
        token.setFeeTarget(address(bug));

        token.mint(address(this), 1_000_000);
        token.approve(address(bug), type(uint256).max);

        (uint256 sent, uint256 credited) = bug.send(100_000, 100_000);
        _assertTrue(sent == 100_000, "unexpected sent");
        _assertTrue(credited == 100_000, "unexpected credit");

        uint256 collateral = token.balanceOf(address(bug));
        uint256 liability = bug.remoteLiabilityLD();

        _assertTrue(collateral == 95_000, "expected 5% inbound fee haircut");
        _assertTrue(liability == 100_000, "expected full remote liability");
        _assertTrue(collateral < liability, "expected collateral deficit");
    }

    /// @notice LZ1 control: fixed-model tracks actual received amount and enforces slippage.
    function test_lz1_fixed_model_tracks_actual_received_and_rejects_overstrict_min() public {
        MockInboundFeeToken token = new MockInboundFeeToken(address(this), 500); // 5%
        OFTAdapterFixedModel fixedModel = new OFTAdapterFixedModel(address(token));
        token.setFeeTarget(address(fixedModel));

        token.mint(address(this), 1_000_000);
        token.approve(address(fixedModel), type(uint256).max);

        bool reverted;
        try fixedModel.send(100_000, 100_000) {
            reverted = false;
        } catch {
            reverted = true;
        }
        _assertTrue(reverted, "expected strict-min slippage revert");

        (uint256 sent, uint256 credited) = fixedModel.send(100_000, 95_000);
        _assertTrue(sent == 100_000, "unexpected sent");
        _assertTrue(credited == 95_000, "expected actual received credit");

        uint256 collateral = token.balanceOf(address(fixedModel));
        uint256 liability = fixedModel.remoteLiabilityLD();
        _assertTrue(collateral == liability, "fixed model must keep collateral == liability");
    }

    /// @notice LZ1 fuzz witness: for nonzero fee-bps and sufficiently large amount, bug model violates collateral>=liability.
    function testFuzz_lz1_bug_model_can_break_collateral_invariant(uint96 amountSeed, uint16 feeSeed) public {
        uint16 bps = uint16((uint256(feeSeed) % 2_000) + 1); // 0.01%..20%
        uint256 amount = (uint256(amountSeed) % 1_000_000_000) + 10_000;

        MockInboundFeeToken token = new MockInboundFeeToken(address(this), bps);
        OFTAdapterBugModel bug = new OFTAdapterBugModel(address(token));
        token.setFeeTarget(address(bug));

        token.mint(address(this), amount + 1);
        token.approve(address(bug), type(uint256).max);

        bug.send(amount, amount);
        uint256 collateral = token.balanceOf(address(bug));
        uint256 liability = bug.remoteLiabilityLD();
        _assertTrue(collateral < liability, "expected collateral deficit in bug model");
    }

    /// @notice LZ2 witness: stale delegate remains privileged after ownership transfer.
    function test_lz2_bug_model_stale_delegate_can_reconfigure_after_transfer() public {
        EndpointDelegateAuthModel endpoint = new EndpointDelegateAuthModel();
        BuggyOAppOwnershipModel bugOApp = new BuggyOAppOwnershipModel(address(endpoint), address(this));
        address newOwner = address(0xB0B);

        bugOApp.transferOwnership(newOwner);
        endpoint.setSendLibrary(address(bugOApp), 101, endpoint.BLOCKED_LIBRARY());

        _assertTrue(
            endpoint.sendLibrary(address(bugOApp), 101) == endpoint.BLOCKED_LIBRARY(),
            "expected stale-delegate reconfiguration"
        );
    }

    /// @notice LZ2 control: fixed model rotates delegate on ownership transfer.
    function test_lz2_fixed_model_blocks_stale_delegate_after_transfer() public {
        EndpointDelegateAuthModel endpoint = new EndpointDelegateAuthModel();
        FixedOAppOwnershipModel fixedOApp = new FixedOAppOwnershipModel(address(endpoint), address(this));
        address newOwner = address(0xB0B);

        fixedOApp.transferOwnership(newOwner);

        bool reverted;
        try endpoint.setSendLibrary(address(fixedOApp), 202, endpoint.BLOCKED_LIBRARY()) {
            reverted = false;
        } catch {
            reverted = true;
        }
        _assertTrue(reverted, "expected stale delegate to be blocked after rotation");
    }

    /// @notice LZ2 fuzz witness: stale delegate can keep mutating send-library config across eids.
    function testFuzz_lz2_bug_model_stale_delegate_persists(uint16 eidSeed) public {
        uint32 eid = uint32(eidSeed) + 1;

        EndpointDelegateAuthModel endpoint = new EndpointDelegateAuthModel();
        BuggyOAppOwnershipModel bugOApp = new BuggyOAppOwnershipModel(address(endpoint), address(this));
        bugOApp.transferOwnership(address(0xCAFE));

        endpoint.setSendLibrary(address(bugOApp), eid, endpoint.BLOCKED_LIBRARY());
        _assertTrue(
            endpoint.sendLibrary(address(bugOApp), eid) == endpoint.BLOCKED_LIBRARY(),
            "expected stale delegate write after transfer"
        );
    }

    /// @notice LZ3 witness: preloaded endpoint residual can be swept through lzToken refund path.
    function test_lz3_bug_model_residual_lztoken_can_be_swept() public {
        MockInboundFeeToken token = new MockInboundFeeToken(address(this), 0);
        EndpointLzTokenSweepBugModel bugModel = new EndpointLzTokenSweepBugModel(address(token), address(0xFEE1), 99);

        uint256 residual = 1_000;
        token.mint(address(this), residual);
        token.approve(address(bugModel), type(uint256).max);
        bugModel.preloadResidual(residual);

        uint256 before = token.balanceOf(address(this));
        uint256 refunded = bugModel.sendWithPayInLzToken(address(this));
        uint256 afterBal = token.balanceOf(address(this));

        _assertTrue(refunded == residual - 99, "unexpected refund size");
        _assertTrue(afterBal - before == refunded, "expected windfall from residual");
        _assertTrue(token.balanceOf(address(bugModel)) == 0, "expected endpoint residual drained");
    }

    /// @notice LZ3 control: isolated-payment model does not expose preloaded residual.
    function test_lz3_fixed_model_preserves_preloaded_residual() public {
        MockInboundFeeToken token = new MockInboundFeeToken(address(this), 0);
        EndpointLzTokenSweepFixedModel fixedModel = new EndpointLzTokenSweepFixedModel(address(token), address(0xFEE1), 99);

        uint256 residual = 1_000;
        token.mint(address(this), residual + 99);
        token.approve(address(fixedModel), type(uint256).max);
        fixedModel.preloadResidual(residual);

        uint256 before = token.balanceOf(address(this));
        uint256 refunded = fixedModel.sendWithIsolatedPayment(address(this), 99);
        uint256 afterBal = token.balanceOf(address(this));

        _assertTrue(refunded == 0, "expected no refund windfall");
        _assertTrue(before - afterBal == 99, "expected caller only pays explicit fee");
        _assertTrue(token.balanceOf(address(fixedModel)) == residual, "expected residual preserved");
    }

    /// @notice LZ3 fuzz witness: whenever preloaded residual > fee, bug model refunds that residual.
    function testFuzz_lz3_bug_model_sweeps_preloaded_residual(uint96 residualSeed) public {
        uint256 residual = (uint256(residualSeed) % 1_000_000_000) + 100; // ensure > fee(99)

        MockInboundFeeToken token = new MockInboundFeeToken(address(this), 0);
        EndpointLzTokenSweepBugModel bugModel = new EndpointLzTokenSweepBugModel(address(token), address(0xFEE1), 99);

        token.mint(address(this), residual);
        token.approve(address(bugModel), type(uint256).max);
        bugModel.preloadResidual(residual);

        uint256 before = token.balanceOf(address(this));
        uint256 refunded = bugModel.sendWithPayInLzToken(address(this));
        uint256 afterBal = token.balanceOf(address(this));

        _assertTrue(refunded == residual - 99, "expected residual minus fee");
        _assertTrue(afterBal - before == residual - 99, "expected swept residual windfall");
    }
}

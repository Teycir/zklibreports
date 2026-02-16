// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {
    ConnextExecuteTrustBoundaryModel,
    DestinationTransferStatus,
    ExecuteParams,
    LenientReceiver,
    MockToken,
    RevertingReceiver,
    StrictReceiver
} from "../src/ConnextExecuteTrustBoundaryHarness.sol";

contract ConnextExecuteTrustBoundaryTest {
    uint32 internal constant ORIGIN_DOMAIN = 1111;
    address internal constant TRUSTED_ORIGIN = address(0xA11CE);

    function _assertTrue(bool condition, string memory message) internal pure {
        require(condition, message);
    }

    function _params(address to) internal pure returns (ExecuteParams memory p) {
        p = ExecuteParams({to: to, originSender: TRUSTED_ORIGIN, originDomain: ORIGIN_DOMAIN, callData: bytes("")});
    }

    /// @notice F4 falsification witness:
    /// strict receivers cannot be successfully called on unauthenticated fast path.
    function test_f4_fast_path_strict_receiver_reverts_and_rolls_back() public {
        MockToken token = new MockToken();
        ConnextExecuteTrustBoundaryModel model = new ConnextExecuteTrustBoundaryModel(address(token));
        StrictReceiver strictReceiver = new StrictReceiver(address(model), TRUSTED_ORIGIN);

        bytes32 transferId = keccak256("f4-fast-strict");
        token.mint(address(model), 100_000);

        bool reverted = false;
        try model.execute(_params(address(strictReceiver)), transferId, 100_000, true) {} catch {
            reverted = true;
        }

        _assertTrue(reverted, "expected fast-path revert for strict receiver");
        _assertTrue(
            model.transferStatus(transferId) == DestinationTransferStatus.None,
            "expected status rollback to none on revert"
        );
        _assertTrue(token.balanceOf(address(model)) == 100_000, "expected transfer rollback");
        _assertTrue(token.balanceOf(address(strictReceiver)) == 0, "expected no recipient funds");
        _assertTrue(strictReceiver.successfulCalls() == 0, "expected no strict receiver success");
    }

    /// @notice Control witness: lenient receivers can accept fast-path unauthenticated originSender=0 by design.
    function test_f4_fast_path_lenient_receiver_observes_zero_origin_sender() public {
        MockToken token = new MockToken();
        ConnextExecuteTrustBoundaryModel model = new ConnextExecuteTrustBoundaryModel(address(token));
        LenientReceiver lenientReceiver = new LenientReceiver(address(model));

        bytes32 transferId = keccak256("f4-fast-lenient");
        token.mint(address(model), 100_000);

        model.execute(_params(address(lenientReceiver)), transferId, 100_000, true);

        _assertTrue(
            model.transferStatus(transferId) == DestinationTransferStatus.Executed,
            "expected executed status on successful fast path"
        );
        _assertTrue(lenientReceiver.calls() == 1, "expected lenient receiver call");
        _assertTrue(lenientReceiver.lastOriginSender() == address(0), "expected unauthenticated origin sender");
    }

    /// @notice F4 authenticated path witness:
    /// once reconciled, slow execute passes authenticated originSender and strict receiver succeeds.
    function test_f4_reconciled_slow_path_authenticates_origin_sender_for_strict_receiver() public {
        MockToken token = new MockToken();
        ConnextExecuteTrustBoundaryModel model = new ConnextExecuteTrustBoundaryModel(address(token));
        StrictReceiver strictReceiver = new StrictReceiver(address(model), TRUSTED_ORIGIN);

        bytes32 transferId = keccak256("f4-slow-strict");
        token.mint(address(model), 100_000);

        model.reconcile(transferId);
        model.execute(_params(address(strictReceiver)), transferId, 100_000, false);

        _assertTrue(
            model.transferStatus(transferId) == DestinationTransferStatus.Completed,
            "expected completed status after reconciled execute"
        );
        _assertTrue(strictReceiver.successfulCalls() == 1, "expected strict receiver success on reconciled path");
        _assertTrue(strictReceiver.lastOriginSender() == TRUSTED_ORIGIN, "expected authenticated origin sender");
    }

    /// @notice Reconciled path fail-open witness:
    /// calldata failure does not revert execute after reconciliation.
    function test_f4_reconciled_path_swallows_receiver_revert() public {
        MockToken token = new MockToken();
        ConnextExecuteTrustBoundaryModel model = new ConnextExecuteTrustBoundaryModel(address(token));
        RevertingReceiver revertingReceiver = new RevertingReceiver(address(model));

        bytes32 transferId = keccak256("f4-slow-revert");
        token.mint(address(model), 100_000);

        model.reconcile(transferId);
        model.execute(_params(address(revertingReceiver)), transferId, 100_000, false);

        _assertTrue(
            model.transferStatus(transferId) == DestinationTransferStatus.Completed,
            "expected completed status despite receiver revert"
        );
        _assertTrue(
            token.balanceOf(address(revertingReceiver)) == 100_000,
            "expected funds transferred even when reconciled external call fails"
        );
    }

    /// @notice Fuzz witness:
    /// strict receiver remains unreachable on unauthenticated fast path.
    function testFuzz_f4_fast_path_strict_receiver_always_reverts(uint96 amountSeed) public {
        MockToken token = new MockToken();
        ConnextExecuteTrustBoundaryModel model = new ConnextExecuteTrustBoundaryModel(address(token));
        StrictReceiver strictReceiver = new StrictReceiver(address(model), TRUSTED_ORIGIN);

        uint256 amount = (uint256(amountSeed) % 1_000_000_000) + 1;
        bytes32 transferId = keccak256(abi.encodePacked("f4-fuzz-fast", amount));
        token.mint(address(model), amount);

        bool reverted = false;
        try model.execute(_params(address(strictReceiver)), transferId, amount, true) {} catch {
            reverted = true;
        }

        _assertTrue(reverted, "expected strict fast-path revert");
        _assertTrue(model.transferStatus(transferId) == DestinationTransferStatus.None, "expected rolled-back status");
        _assertTrue(strictReceiver.successfulCalls() == 0, "expected no strict receiver success");
    }
}

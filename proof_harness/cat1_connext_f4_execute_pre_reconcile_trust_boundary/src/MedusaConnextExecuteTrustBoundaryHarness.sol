// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {
    ConnextExecuteTrustBoundaryModel,
    DestinationTransferStatus,
    ExecuteParams,
    MockToken,
    StrictReceiver
} from "./ConnextExecuteTrustBoundaryHarness.sol";

/// @notice Specialist-fuzz harness to falsify the fast-path trust-boundary exploit hypothesis.
/// Invariant: strict receiver must never successfully process unauthenticated fast-path calls.
contract MedusaConnextExecuteTrustBoundaryHarness {
    uint256 internal constant MIN_STEP = 1;
    uint256 internal constant MAX_STEP = 1_000_000_000;
    uint32 internal constant ORIGIN_DOMAIN = 1111;
    address internal constant TRUSTED_ORIGIN = address(0xA11CE);

    MockToken public token;
    ConnextExecuteTrustBoundaryModel public model;
    StrictReceiver public strictReceiver;

    bytes32 public transferId;

    constructor() {
        token = new MockToken();
        model = new ConnextExecuteTrustBoundaryModel(address(token));
        strictReceiver = new StrictReceiver(address(model), TRUSTED_ORIGIN);
        transferId = keccak256("cat1-connext-f4-fast-path-trust-boundary");
    }

    function _step(uint256 seed) internal pure returns (uint256) {
        return (seed % MAX_STEP) + MIN_STEP;
    }

    function _params() internal view returns (ExecuteParams memory p) {
        p = ExecuteParams({
            to: address(strictReceiver),
            originSender: TRUSTED_ORIGIN,
            originDomain: ORIGIN_DOMAIN,
            callData: bytes("")
        });
    }

    function action_seed(uint96 amountSeed) external {
        token.mint(address(model), _step(amountSeed));
    }

    function action_fast_execute_strict(uint96 amountSeed) external {
        ExecuteParams memory p = _params();
        uint256 amount = _step(amountSeed);
        if (token.balanceOf(address(model)) < amount) {
            token.mint(address(model), amount);
        }
        try model.execute(p, transferId, amount, true) {} catch {}
    }

    function action_reconcile() external {
        try model.reconcile(transferId) {} catch {}
    }

    function property_fast_path_cannot_authenticate_strict_receiver() external view returns (bool) {
        return strictReceiver.successfulCalls() == 0;
    }

    function property_fast_path_not_stuck_executed_without_success() external view returns (bool) {
        DestinationTransferStatus st = model.transferStatus(transferId);
        return st != DestinationTransferStatus.Executed && st != DestinationTransferStatus.Completed;
    }

    function echidna_fast_path_cannot_authenticate_strict_receiver() external view returns (bool) {
        return strictReceiver.successfulCalls() == 0;
    }
}

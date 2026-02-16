// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {
    BridgeReplayBugModel,
    BridgeReplayGuardModel,
    MockReentrantToken
} from "./ReentrancyReplayHarness.sol";

/// @notice Stateful specialist-fuzz harness for same-VM redemption reentrancy.
contract MedusaReentrancyReplayHarness {
    uint256 internal constant INITIAL_MINT = 1_000_000 ether;
    uint256 internal constant MAX_STEP = 1_000 ether;

    BridgeReplayBugModel public bugModel;
    BridgeReplayGuardModel public guardModel;
    MockReentrantToken public bugToken;
    MockReentrantToken public guardToken;

    uint256 public vmNonce;
    bool public bugDoubleRedeemObserved;
    bool public guardDoubleRedeemObserved;

    constructor() {
        bugModel = new BridgeReplayBugModel();
        guardModel = new BridgeReplayGuardModel();
        bugToken = new MockReentrantToken(address(bugModel));
        guardToken = new MockReentrantToken(address(guardModel));

        bugToken.mint(address(this), INITIAL_MINT);
        guardToken.mint(address(this), INITIAL_MINT);

        bugToken.approve(address(bugModel), type(uint256).max);
        guardToken.approve(address(guardModel), type(uint256).max);
    }

    function _amount(uint256 seed) internal pure returns (uint256) {
        return (seed % MAX_STEP) + 1;
    }

    function _newVmHash(string memory tag, uint256 seed) internal returns (bytes32) {
        vmNonce += 1;
        return keccak256(abi.encodePacked(tag, seed, vmNonce));
    }

    function action_bug_same_vm_reentry(uint96 amountSeed) external {
        uint256 amount = _amount(amountSeed);
        bugModel.seed(address(bugToken), address(this), amount * 2);

        bytes32 vmHash = _newVmHash("bug", amountSeed);
        bugModel.registerTransfer(vmHash, address(bugToken), address(this), amount);
        bugToken.configureHook(vmHash, true);

        try bugModel.completeTransfer(vmHash) {} catch {}
        if (bugModel.redeemCount(vmHash) > 1) {
            bugDoubleRedeemObserved = true;
        }
    }

    function action_guard_same_vm_reentry(uint96 amountSeed) external {
        uint256 amount = _amount(amountSeed);
        guardModel.seed(address(guardToken), address(this), amount * 2);

        bytes32 vmHash = _newVmHash("guard", amountSeed);
        guardModel.registerTransfer(vmHash, address(guardToken), address(this), amount);
        guardToken.configureHook(vmHash, true);

        try guardModel.completeTransfer(vmHash) {} catch {}
        if (guardModel.redeemCount(vmHash) > 1) {
            guardDoubleRedeemObserved = true;
        }
    }

    /// @notice Negative-control property: expected to fail in bug model.
    function property_bug_model_same_vm_reentry_should_not_double_redeem()
        external
        view
        returns (bool)
    {
        return !bugDoubleRedeemObserved;
    }

    /// @notice Target property: guard ordering should block same-VM double redeem.
    function property_guard_model_same_vm_reentry_should_not_double_redeem()
        external
        view
        returns (bool)
    {
        return !guardDoubleRedeemObserved;
    }

    /// @notice Echidna-compatible alias for target property.
    function echidna_guard_model_same_vm_reentry_should_not_double_redeem()
        external
        view
        returns (bool)
    {
        return !guardDoubleRedeemObserved;
    }
}


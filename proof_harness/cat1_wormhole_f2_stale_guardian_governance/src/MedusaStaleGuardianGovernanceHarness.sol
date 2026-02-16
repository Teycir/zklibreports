// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {
    BridgeGovernanceBugModel,
    BridgeGovernanceFixedModel,
    CoreGovernanceModel,
    MiniVM,
    WormholeVerificationModel
} from "./StaleGuardianGovernanceHarness.sol";

/// @notice Stateful specialist-fuzz harness for stale guardian-set governance acceptance.
contract MedusaStaleGuardianGovernanceHarness {
    uint32 internal constant CURRENT_SET = 7;
    uint32 internal constant STALE_SET = 6;
    uint16 internal constant GOVERNANCE_CHAIN = 1;
    bytes32 internal constant GOVERNANCE_CONTRACT = bytes32(uint256(4));

    WormholeVerificationModel public wormhole;
    CoreGovernanceModel public core;
    BridgeGovernanceBugModel public bridgeBug;
    BridgeGovernanceFixedModel public bridgeFixed;

    bool public bugAcceptedStaleSet;
    bool public coreAcceptedStaleSet;
    bool public fixedAcceptedStaleSet;

    constructor() {
        wormhole = new WormholeVerificationModel();
        wormhole.setGuardianSet(STALE_SET, block.timestamp + 1 days);
        wormhole.setGuardianSet(CURRENT_SET, type(uint256).max);
        wormhole.setCurrentGuardianSetIndex(CURRENT_SET);

        core = new CoreGovernanceModel(
            wormhole, GOVERNANCE_CHAIN, GOVERNANCE_CONTRACT
        );
        bridgeBug = new BridgeGovernanceBugModel(
            wormhole, GOVERNANCE_CHAIN, GOVERNANCE_CONTRACT
        );
        bridgeFixed = new BridgeGovernanceFixedModel(
            wormhole, GOVERNANCE_CHAIN, GOVERNANCE_CONTRACT
        );
    }

    function _staleVm(bytes32 _hash) internal pure returns (bytes memory) {
        MiniVM memory vm = MiniVM({
            guardianSetIndex: STALE_SET,
            emitterChainId: GOVERNANCE_CHAIN,
            emitterAddress: GOVERNANCE_CONTRACT,
            hash: _hash
        });
        return abi.encode(vm);
    }

    function action_attemptBugUpgradeWithStaleSet(uint96 _seed) external {
        bytes32 h = keccak256(abi.encodePacked("bug-stale", _seed));
        try bridgeBug.upgrade(_staleVm(h)) {
            bugAcceptedStaleSet = true;
        } catch {}
    }

    function action_attemptCoreUpgradeWithStaleSet(uint96 _seed) external {
        bytes32 h = keccak256(abi.encodePacked("core-stale", _seed));
        try core.submitContractUpgrade(_staleVm(h)) {
            coreAcceptedStaleSet = true;
        } catch {}
    }

    function action_attemptFixedUpgradeWithStaleSet(uint96 _seed) external {
        bytes32 h = keccak256(abi.encodePacked("fixed-stale", _seed));
        try bridgeFixed.upgrade(_staleVm(h)) {
            fixedAcceptedStaleSet = true;
        } catch {}
    }

    /// @notice Desired invariant: stale guardian set should never authorize bridge governance.
    function property_stale_set_must_not_authorize_bridge_governance()
        external
        view
        returns (bool)
    {
        return !bugAcceptedStaleSet;
    }

    /// @notice Control invariant: core governance should reject stale guardian sets.
    function property_core_rejects_stale_guardian_set()
        external
        view
        returns (bool)
    {
        return !coreAcceptedStaleSet;
    }

    /// @notice Control invariant: fixed bridge model should reject stale guardian sets.
    function property_fixed_bridge_rejects_stale_guardian_set()
        external
        view
        returns (bool)
    {
        return !fixedAcceptedStaleSet;
    }

    /// @notice Echidna-compatible alias.
    function echidna_stale_set_must_not_authorize_bridge_governance()
        external
        view
        returns (bool)
    {
        return !bugAcceptedStaleSet;
    }
}


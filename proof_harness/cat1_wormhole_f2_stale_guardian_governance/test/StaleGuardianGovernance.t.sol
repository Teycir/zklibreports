// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {
    BridgeGovernanceBugModel,
    BridgeGovernanceFixedModel,
    CoreGovernanceModel,
    MiniVM,
    WormholeVerificationModel
} from "../src/StaleGuardianGovernanceHarness.sol";

contract StaleGuardianGovernanceTest {
    uint32 internal constant CURRENT_SET = 7;
    uint32 internal constant STALE_SET = 6;
    uint16 internal constant GOVERNANCE_CHAIN = 1;
    bytes32 internal constant GOVERNANCE_CONTRACT = bytes32(uint256(4));

    function _assertTrue(bool _condition, string memory _message) internal pure {
        require(_condition, _message);
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

    function _setup()
        internal
        returns (
            WormholeVerificationModel _wormhole,
            CoreGovernanceModel _core,
            BridgeGovernanceBugModel _bridgeBug,
            BridgeGovernanceFixedModel _bridgeFixed
        )
    {
        _wormhole = new WormholeVerificationModel();
        _wormhole.setGuardianSet(STALE_SET, block.timestamp + 1 days);
        _wormhole.setGuardianSet(CURRENT_SET, type(uint256).max);
        _wormhole.setCurrentGuardianSetIndex(CURRENT_SET);

        _core = new CoreGovernanceModel(
            _wormhole, GOVERNANCE_CHAIN, GOVERNANCE_CONTRACT
        );
        _bridgeBug = new BridgeGovernanceBugModel(
            _wormhole, GOVERNANCE_CHAIN, GOVERNANCE_CONTRACT
        );
        _bridgeFixed = new BridgeGovernanceFixedModel(
            _wormhole, GOVERNANCE_CHAIN, GOVERNANCE_CONTRACT
        );
    }

    /// @notice Witness: bridge governance bug model accepts stale-but-unexpired signer set.
    function test_bug_model_accepts_stale_guardian_set_for_upgrade() public {
        (, , BridgeGovernanceBugModel bridgeBug,) = _setup();

        bridgeBug.upgrade(_staleVm(keccak256("stale-accepted")));
        _assertTrue(
            bridgeBug.upgraded(),
            "expected stale guardian set to authorize bug-model upgrade"
        );
    }

    /// @notice Control: core governance rejects stale signer set (current set required).
    function test_core_model_rejects_stale_guardian_set_for_upgrade() public {
        (, CoreGovernanceModel core,,) = _setup();

        bool reverted;
        try core.submitContractUpgrade(_staleVm(keccak256("core-rejects")))
        {
            reverted = false;
        } catch {
            reverted = true;
        }
        _assertTrue(reverted, "expected core model stale-set rejection");
    }

    /// @notice Control: fixed bridge model rejects stale signer set.
    function test_fixed_model_rejects_stale_guardian_set_for_upgrade() public {
        (, , , BridgeGovernanceFixedModel bridgeFixed) = _setup();

        bool reverted;
        try bridgeFixed.upgrade(_staleVm(keccak256("fixed-rejects"))) {
            reverted = false;
        } catch {
            reverted = true;
        }
        _assertTrue(reverted, "expected fixed model stale-set rejection");
    }

    /// @notice Window bound: once stale set is expired, bug model no longer accepts it.
    function test_bug_model_rejects_expired_stale_guardian_set() public {
        (WormholeVerificationModel wormhole, , BridgeGovernanceBugModel bridgeBug,) =
            _setup();
        wormhole.setGuardianSet(STALE_SET, block.timestamp - 1);

        bool reverted;
        try bridgeBug.upgrade(_staleVm(keccak256("stale-expired"))) {
            reverted = false;
        } catch {
            reverted = true;
        }
        _assertTrue(reverted, "expected expired stale-set rejection");
    }

    /// @notice Fuzz witness: any fresh hash still passes bug model with stale signer set.
    function testFuzz_bug_model_accepts_stale_set_with_fresh_hash(uint96 seed)
        public
    {
        (, , BridgeGovernanceBugModel bridgeBug,) = _setup();
        bytes32 h = keccak256(abi.encodePacked("seed", seed));

        bridgeBug.upgrade(_staleVm(h));
        _assertTrue(bridgeBug.upgraded(), "expected upgrade success");
    }
}


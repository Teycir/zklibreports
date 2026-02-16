// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {
    BridgeMetadataBugModel,
    BridgeMetadataFixedModel,
    MockMetadataTokenW,
    MockNoMetadataTokenW
} from "../src/BridgeMetadataCompatHarness.sol";

contract BridgeMetadataCompatTest {
    function _assertTrue(bool _condition, string memory _message) internal pure {
        require(_condition, _message);
    }

    /// @notice Witness: bug model reverts on non-metadata token in attest path.
    function test_bug_attest_reverts_for_token_without_metadata() public {
        BridgeMetadataBugModel bug = new BridgeMetadataBugModel();
        MockNoMetadataTokenW token = new MockNoMetadataTokenW();

        bool reverted;
        try bug.attestToken(address(token)) returns (uint8, bytes32, bytes32) {
            reverted = false;
        } catch {
            reverted = true;
        }
        _assertTrue(reverted, "expected attest revert on missing metadata");
    }

    /// @notice Witness: bug model reverts on non-metadata token in transfer path.
    function test_bug_transfer_reverts_for_token_without_decimals() public {
        BridgeMetadataBugModel bug = new BridgeMetadataBugModel();
        MockNoMetadataTokenW token = new MockNoMetadataTokenW();

        bool reverted;
        try bug.transferTokens(address(token), 1 ether) returns (uint256) {
            reverted = false;
        } catch {
            reverted = true;
        }
        _assertTrue(reverted, "expected transfer revert on missing decimals");
    }

    /// @notice Fixed control: fallback metadata allows attest + transfer to proceed.
    function test_fixed_model_tolerates_missing_metadata_methods() public {
        BridgeMetadataFixedModel fixedModel = new BridgeMetadataFixedModel();
        MockNoMetadataTokenW token = new MockNoMetadataTokenW();

        (uint8 decimals, bytes32 symbol, bytes32 name) =
            fixedModel.attestToken(address(token));
        uint256 normalized = fixedModel.transferTokens(address(token), 1 ether);

        _assertTrue(decimals == 18, "expected fallback decimals");
        _assertTrue(symbol == bytes32("UNKNOWN"), "expected fallback symbol");
        _assertTrue(name == bytes32("UNKNOWN"), "expected fallback name");
        _assertTrue(normalized > 0, "expected transfer normalization result");
    }

    /// @notice Sanity control: metadata token works in both models.
    function test_models_accept_metadata_compliant_token() public {
        BridgeMetadataBugModel bug = new BridgeMetadataBugModel();
        BridgeMetadataFixedModel fixedModel = new BridgeMetadataFixedModel();
        MockMetadataTokenW token = new MockMetadataTokenW();

        (uint8 bugDecimals, , ) = bug.attestToken(address(token));
        (uint8 fixedDecimals, , ) = fixedModel.attestToken(address(token));
        uint256 bugNorm = bug.transferTokens(address(token), 5 ether);
        uint256 fixedNorm = fixedModel.transferTokens(address(token), 5 ether);

        _assertTrue(bugDecimals == 18, "bug decimals mismatch");
        _assertTrue(fixedDecimals == 18, "fixed decimals mismatch");
        _assertTrue(bugNorm == fixedNorm, "normalized amounts should match");
    }

    /// @notice Fuzz witness: any positive amount reverts in bug transfer path for non-metadata tokens.
    function testFuzz_bug_transfer_reverts_without_decimals(uint96 amountSeed) public {
        BridgeMetadataBugModel bug = new BridgeMetadataBugModel();
        MockNoMetadataTokenW token = new MockNoMetadataTokenW();
        uint256 amount = (uint256(amountSeed) % 10_000 ether) + 1;

        bool reverted;
        try bug.transferTokens(address(token), amount) returns (uint256) {
            reverted = false;
        } catch {
            reverted = true;
        }
        _assertTrue(reverted, "expected fuzzed transfer revert");
    }
}


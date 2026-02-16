// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {
    BridgeMetadataBugModel,
    BridgeMetadataFixedModel,
    MockMetadataTokenW,
    MockNoMetadataTokenW
} from "./BridgeMetadataCompatHarness.sol";

/// @notice Stateful specialist-fuzz harness for metadata-method compatibility.
contract MedusaBridgeMetadataCompatHarness {
    BridgeMetadataBugModel public bug;
    BridgeMetadataFixedModel public fixedModel;
    MockNoMetadataTokenW public noMeta;
    MockMetadataTokenW public withMeta;

    bool public bugNoMetaAttestFailed;
    bool public bugNoMetaTransferFailed;
    bool public fixedNoMetaFailed;

    constructor() {
        bug = new BridgeMetadataBugModel();
        fixedModel = new BridgeMetadataFixedModel();
        noMeta = new MockNoMetadataTokenW();
        withMeta = new MockMetadataTokenW();
        noMeta.mint(address(this), 1_000_000 ether);
        withMeta.mint(address(this), 1_000_000 ether);
    }

    function _amount(uint256 _seed) internal pure returns (uint256) {
        return (_seed % 10_000 ether) + 1;
    }

    function action_probeBugAttestNoMetadata() external {
        try bug.attestToken(address(noMeta)) returns (uint8, bytes32, bytes32) {
            // should not happen in bug model for non-metadata token
        } catch {
            bugNoMetaAttestFailed = true;
        }
    }

    function action_probeBugTransferNoMetadata(uint96 _amountSeed) external {
        uint256 amount = _amount(_amountSeed);
        try bug.transferTokens(address(noMeta), amount) returns (uint256) {
            // should not happen in bug model for non-metadata token
        } catch {
            bugNoMetaTransferFailed = true;
        }
    }

    function action_probeFixedNoMetadata(uint96 _amountSeed) external {
        uint256 amount = _amount(_amountSeed);
        try fixedModel.attestToken(address(noMeta)) returns (uint8, bytes32, bytes32) {
            try fixedModel.transferTokens(address(noMeta), amount) returns (uint256) {
                // expected pass
            } catch {
                fixedNoMetaFailed = true;
            }
        } catch {
            fixedNoMetaFailed = true;
        }
    }

    function action_probeBugAndFixedWithMetadata(uint96 _amountSeed)
        external
        view
    {
        uint256 amount = _amount(_amountSeed);
        // Control path: both models should handle metadata-compliant token.
        try bug.attestToken(address(withMeta)) returns (uint8, bytes32, bytes32) {
            try bug.transferTokens(address(withMeta), amount) returns (uint256) {} catch {}
        } catch {}
        try fixedModel.attestToken(address(withMeta)) returns (uint8, bytes32, bytes32) {
            try fixedModel.transferTokens(address(withMeta), amount) returns (uint256) {} catch {}
        } catch {}
    }

    /// @notice Nonstandard tokens should not break attestation path.
    function property_nonstandard_token_attest_should_not_fail()
        external
        view
        returns (bool)
    {
        return !bugNoMetaAttestFailed;
    }

    /// @notice Nonstandard tokens should not break transfer path.
    function property_nonstandard_token_transfer_should_not_fail()
        external
        view
        returns (bool)
    {
        return !bugNoMetaTransferFailed;
    }

    /// @notice Fixed model must tolerate missing metadata methods.
    function property_fixed_model_tolerates_missing_metadata()
        external
        view
        returns (bool)
    {
        return !fixedNoMetaFailed;
    }

    /// @notice Echidna-compatible alias.
    function echidna_nonstandard_token_attest_should_not_fail()
        external
        view
        returns (bool)
    {
        return !bugNoMetaAttestFailed;
    }
}

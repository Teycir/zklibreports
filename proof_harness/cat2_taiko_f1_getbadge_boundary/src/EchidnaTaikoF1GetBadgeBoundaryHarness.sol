// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { TrailblazersBadgesS2Like } from "./TaikoF1GetBadgeBoundaryHarness.sol";

/// @notice Echidna harness for TrailblazersBadgesS2.getBadge boundary logic.
contract EchidnaTaikoF1GetBadgeBoundaryHarness is TrailblazersBadgesS2Like {
    function action_mint(uint8 _badgeType, uint8 _movementType) public {
        if (totalSupply() >= 8) return;
        mintMock(_badgeType, _movementType);
    }

    function echidna_unminted_token_must_revert() public returns (bool) {
        if (totalSupply() == 0) {
            return true;
        }

        uint256 unmintedId = totalSupply() + 1;
        try this.getBadge(unmintedId) returns (Badge memory) {
            return false;
        } catch {
            return true;
        }
    }

    function echidna_first_minted_token_must_be_readable() public returns (bool) {
        if (totalSupply() == 0) {
            return true;
        }

        try this.getBadge(1) returns (Badge memory badge) {
            return badge.tokenId == 1;
        } catch {
            return false;
        }
    }
}

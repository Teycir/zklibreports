// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { TrailblazersBadgesS2Like } from "../src/TaikoF1GetBadgeBoundaryHarness.sol";

/// @notice Halmos checks for expected getBadge safety properties.
contract HalmosTaikoF1GetBadgeBoundary {
    function check_unminted_token_must_revert() public {
        TrailblazersBadgesS2Like nft = new TrailblazersBadgesS2Like();

        (bool success,) = address(nft).call(abi.encodeCall(nft.getBadge, (1)));
        assert(!success);
    }

    function check_old_minted_token_must_be_readable() public {
        TrailblazersBadgesS2Like nft = new TrailblazersBadgesS2Like();
        nft.mintMock(0, 1); // token 1
        nft.mintMock(1, 2); // token 2

        (bool success, bytes memory data) = address(nft).call(abi.encodeCall(nft.getBadge, (1)));
        if (!success) {
            assert(false);
        }

        TrailblazersBadgesS2Like.Badge memory badge = abi.decode(data, (TrailblazersBadgesS2Like.Badge));
        assert(badge.tokenId == 1);
    }
}
// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { TrailblazersBadgesS2Like } from "../src/TaikoF1GetBadgeBoundaryHarness.sol";

/// @notice Forge witness tests for TrailblazersBadgesS2.getBadge boundary flaw.
contract TaikoF1GetBadgeBoundaryTest {
    TrailblazersBadgesS2Like internal nft;

    function setUp() public {
        nft = new TrailblazersBadgesS2Like();
    }

    function test_getBadge_reverts_for_older_minted_token() public {
        setUp();
        nft.mintMock(0, 1); // token 1
        nft.mintMock(1, 2); // token 2

        (bool success,) = address(nft).call(abi.encodeCall(nft.getBadge, (1)));
        assert(!success);
    }

    function test_getBadge_returns_default_for_unminted_token() public {
        setUp();
        nft.mintMock(0, 1);

        (bool success, bytes memory data) = address(nft).call(abi.encodeCall(nft.getBadge, (999)));
        assert(success);

        TrailblazersBadgesS2Like.Badge memory badge =
            abi.decode(data, (TrailblazersBadgesS2Like.Badge));
        assert(badge.tokenId == 0);
    }
}

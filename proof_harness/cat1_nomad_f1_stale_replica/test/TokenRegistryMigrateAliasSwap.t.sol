// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {
    BridgeRouterMigrateAliasModel
} from "../src/TokenRegistryMigrateAliasHarness.sol";
import {
    MockCanonicalBridgeToken,
    MockRepresentationBridgeToken,
    TokenRegistryAliasBugModel,
    TokenRegistryAliasFixedModel
} from "../src/TokenRegistryAliasSwapHarness.sol";

contract TokenRegistryMigrateAliasSwapTest {
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
            BridgeRouterMigrateAliasModel localRouter,
            BridgeRouterMigrateAliasModel remoteRouter,
            MockCanonicalBridgeToken tokenA,
            MockCanonicalBridgeToken tokenB
        )
    {
        localRegistry = new TokenRegistryAliasBugModel(LOCAL_DOMAIN);
        remoteRegistry = new TokenRegistryAliasBugModel(REMOTE_DOMAIN);
        localRouter = new BridgeRouterMigrateAliasModel(address(localRegistry));
        remoteRouter = new BridgeRouterMigrateAliasModel(address(remoteRegistry));
        localRouter.setRemote(address(remoteRouter));
        remoteRouter.setRemote(address(localRouter));

        tokenA = new MockCanonicalBridgeToken();
        tokenB = new MockCanonicalBridgeToken();

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
            BridgeRouterMigrateAliasModel localRouter,
            BridgeRouterMigrateAliasModel remoteRouter,
            MockCanonicalBridgeToken tokenA,
            MockCanonicalBridgeToken tokenB
        )
    {
        localRegistry = new TokenRegistryAliasFixedModel(LOCAL_DOMAIN);
        remoteRegistry = new TokenRegistryAliasFixedModel(REMOTE_DOMAIN);
        localRouter = new BridgeRouterMigrateAliasModel(address(localRegistry));
        remoteRouter = new BridgeRouterMigrateAliasModel(address(remoteRegistry));
        localRouter.setRemote(address(remoteRouter));
        remoteRouter.setRemote(address(localRouter));

        tokenA = new MockCanonicalBridgeToken();
        tokenB = new MockCanonicalBridgeToken();

        uint256 seed = 5_000_000 ether;
        remoteRouter.seedCanonicalEscrow(address(tokenA), seed);
        remoteRouter.seedCanonicalEscrow(address(tokenB), seed);
        tokenA.mint(address(this), seed);
        tokenA.approve(address(remoteRouter), type(uint256).max);
    }

    /// @notice Witness:
    /// aliasing old representation to tokenB and rotating current B representation
    /// turns migrate(oldARepr) into local A->B conversion path.
    function test_migrate_can_swap_canonical_asset_after_alias_overwrite() public {
        (
            TokenRegistryAliasBugModel localRegistry,
            ,
            BridgeRouterMigrateAliasModel localRouter,
            BridgeRouterMigrateAliasModel remoteRouter,
            MockCanonicalBridgeToken tokenA,
            MockCanonicalBridgeToken tokenB
        ) = _deployBugPair();

        uint256 amount = 250 ether;
        uint256 tokenABefore = tokenA.balanceOf(address(this));
        uint256 tokenBBefore = tokenB.balanceOf(address(this));

        // Create legacy representation for canonical tokenA and mint it to this account.
        remoteRouter.send(address(tokenA), amount, address(this));
        address legacyARepr =
            localRegistry.getRepresentationAddress(REMOTE_DOMAIN, _id(address(tokenA)));
        _assertTrue(legacyARepr != address(0), "expected legacy repr for A");

        // Misconfiguration sequence:
        // 1) alias legacyARepr to canonical tokenB
        // 2) rotate canonical tokenB primary representation to customB
        MockRepresentationBridgeToken customB =
            new MockRepresentationBridgeToken(address(localRouter));
        localRegistry.enrollCustom(REMOTE_DOMAIN, _id(address(tokenB)), legacyARepr);
        localRegistry.enrollCustom(REMOTE_DOMAIN, _id(address(tokenB)), address(customB));

        address migratedTarget = localRegistry.oldReprToCurrentRepr(legacyARepr);
        _assertTrue(
            migratedTarget == address(customB),
            "expected migrate target to be tokenB repr"
        );

        // migrate now burns legacyARepr balance and mints customB balance.
        localRouter.migrate(legacyARepr);
        _assertTrue(
            MockRepresentationBridgeToken(legacyARepr).balanceOf(address(this)) == 0,
            "legacy repr should be burned"
        );
        _assertTrue(
            customB.balanceOf(address(this)) == amount,
            "expected migrated customB balance"
        );

        // Send migrated token to remote: settlement now releases tokenB.
        localRouter.send(address(customB), amount, address(this));

        _assertTrue(
            tokenB.balanceOf(address(this)) == tokenBBefore + amount,
            "expected tokenB gain via migrate path"
        );
        _assertTrue(
            tokenA.balanceOf(address(this)) + amount == tokenABefore,
            "expected tokenA loss"
        );
    }

    /// @notice Fixed control:
    /// alias overwrite is blocked; legal migrate for same canonical preserves asset ID.
    function test_fixed_model_blocks_aliased_migrate_swap_and_preserves_asset() public {
        (
            TokenRegistryAliasFixedModel localRegistry,
            ,
            BridgeRouterMigrateAliasModel localRouter,
            BridgeRouterMigrateAliasModel remoteRouter,
            MockCanonicalBridgeToken tokenA,
            MockCanonicalBridgeToken tokenB
        ) = _deployFixedPair();

        uint256 amount = 100 ether;
        uint256 tokenABefore = tokenA.balanceOf(address(this));
        uint256 tokenBBefore = tokenB.balanceOf(address(this));

        remoteRouter.send(address(tokenA), amount, address(this));
        address legacyARepr =
            localRegistry.getRepresentationAddress(REMOTE_DOMAIN, _id(address(tokenA)));
        _assertTrue(legacyARepr != address(0), "expected fixed legacy repr");

        bool aliasBlocked;
        try localRegistry.enrollCustom(REMOTE_DOMAIN, _id(address(tokenB)), legacyARepr) {
            aliasBlocked = false;
        } catch {
            aliasBlocked = true;
        }
        _assertTrue(aliasBlocked, "fixed model should block alias overwrite");

        MockRepresentationBridgeToken customA =
            new MockRepresentationBridgeToken(address(localRouter));
        localRegistry.enrollCustom(REMOTE_DOMAIN, _id(address(tokenA)), address(customA));

        address migratedTarget = localRegistry.oldReprToCurrentRepr(legacyARepr);
        _assertTrue(
            migratedTarget == address(customA),
            "expected migrate target to stay canonical A"
        );

        localRouter.migrate(legacyARepr);
        _assertTrue(
            customA.balanceOf(address(this)) == amount,
            "expected migrated customA balance"
        );

        localRouter.send(address(customA), amount, address(this));

        _assertTrue(
            tokenA.balanceOf(address(this)) == tokenABefore,
            "tokenA should round-trip"
        );
        _assertTrue(
            tokenB.balanceOf(address(this)) == tokenBBefore,
            "tokenB should remain unchanged"
        );
    }

    /// @notice Fuzz witness: migrate-assisted cross-asset swap persists for varied amounts.
    function testFuzz_bug_migrate_alias_swap_amount(uint96 amountSeed) public {
        (
            TokenRegistryAliasBugModel localRegistry,
            ,
            BridgeRouterMigrateAliasModel localRouter,
            BridgeRouterMigrateAliasModel remoteRouter,
            MockCanonicalBridgeToken tokenA,
            MockCanonicalBridgeToken tokenB
        ) = _deployBugPair();

        uint256 amount = _amount(amountSeed);
        uint256 tokenABefore = tokenA.balanceOf(address(this));
        uint256 tokenBBefore = tokenB.balanceOf(address(this));

        remoteRouter.send(address(tokenA), amount, address(this));
        address legacyARepr =
            localRegistry.getRepresentationAddress(REMOTE_DOMAIN, _id(address(tokenA)));

        MockRepresentationBridgeToken customB =
            new MockRepresentationBridgeToken(address(localRouter));
        localRegistry.enrollCustom(REMOTE_DOMAIN, _id(address(tokenB)), legacyARepr);
        localRegistry.enrollCustom(REMOTE_DOMAIN, _id(address(tokenB)), address(customB));

        localRouter.migrate(legacyARepr);
        localRouter.send(address(customB), amount, address(this));

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


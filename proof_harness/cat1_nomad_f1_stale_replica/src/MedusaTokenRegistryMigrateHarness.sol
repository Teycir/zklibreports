// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {
    BridgeRouterMigrateAliasModel
} from "./TokenRegistryMigrateAliasHarness.sol";
import {
    MockCanonicalBridgeToken,
    MockRepresentationBridgeToken,
    TokenRegistryAliasBugModel,
    TokenRegistryAliasFixedModel
} from "./TokenRegistryAliasSwapHarness.sol";

/// @notice Stateful harness for migrate + alias-overwrite cross-asset swap behavior.
contract MedusaTokenRegistryMigrateHarness {
    uint32 internal constant REMOTE_DOMAIN = 1000;
    uint32 internal constant LOCAL_DOMAIN = 2000;

    TokenRegistryAliasBugModel public bugLocalRegistry;
    TokenRegistryAliasBugModel public bugRemoteRegistry;
    BridgeRouterMigrateAliasModel public bugLocalRouter;
    BridgeRouterMigrateAliasModel public bugRemoteRouter;
    MockCanonicalBridgeToken public bugTokenA;
    MockCanonicalBridgeToken public bugTokenB;
    MockRepresentationBridgeToken public bugCustomB;

    TokenRegistryAliasFixedModel public fixedLocalRegistry;
    TokenRegistryAliasFixedModel public fixedRemoteRegistry;
    BridgeRouterMigrateAliasModel public fixedLocalRouter;
    BridgeRouterMigrateAliasModel public fixedRemoteRouter;
    MockCanonicalBridgeToken public fixedTokenA;
    MockCanonicalBridgeToken public fixedTokenB;
    MockRepresentationBridgeToken public fixedCustomA;

    bytes32 public bugIdA;
    bytes32 public bugIdB;
    bytes32 public fixedIdA;
    bytes32 public fixedIdB;

    address public fixedLegacyARepr;
    bool public fixedAliasCheckAttempted;
    bool public fixedAliasBlocked;

    bool public bugMigrateSwapObserved;
    bool public fixedViolationObserved;

    constructor() {
        bugLocalRegistry = new TokenRegistryAliasBugModel(LOCAL_DOMAIN);
        bugRemoteRegistry = new TokenRegistryAliasBugModel(REMOTE_DOMAIN);
        bugLocalRouter = new BridgeRouterMigrateAliasModel(address(bugLocalRegistry));
        bugRemoteRouter = new BridgeRouterMigrateAliasModel(address(bugRemoteRegistry));
        bugLocalRouter.setRemote(address(bugRemoteRouter));
        bugRemoteRouter.setRemote(address(bugLocalRouter));

        fixedLocalRegistry = new TokenRegistryAliasFixedModel(LOCAL_DOMAIN);
        fixedRemoteRegistry = new TokenRegistryAliasFixedModel(REMOTE_DOMAIN);
        fixedLocalRouter = new BridgeRouterMigrateAliasModel(
            address(fixedLocalRegistry)
        );
        fixedRemoteRouter = new BridgeRouterMigrateAliasModel(
            address(fixedRemoteRegistry)
        );
        fixedLocalRouter.setRemote(address(fixedRemoteRouter));
        fixedRemoteRouter.setRemote(address(fixedLocalRouter));

        bugTokenA = new MockCanonicalBridgeToken();
        bugTokenB = new MockCanonicalBridgeToken();
        fixedTokenA = new MockCanonicalBridgeToken();
        fixedTokenB = new MockCanonicalBridgeToken();

        bugIdA = _id(address(bugTokenA));
        bugIdB = _id(address(bugTokenB));
        fixedIdA = _id(address(fixedTokenA));
        fixedIdB = _id(address(fixedTokenB));

        bugCustomB = new MockRepresentationBridgeToken(address(bugLocalRouter));
        fixedCustomA = new MockRepresentationBridgeToken(address(fixedLocalRouter));

        uint256 _escrowSeed = 5_000_000 ether;
        bugRemoteRouter.seedCanonicalEscrow(address(bugTokenA), _escrowSeed);
        bugRemoteRouter.seedCanonicalEscrow(address(bugTokenB), _escrowSeed);
        fixedRemoteRouter.seedCanonicalEscrow(address(fixedTokenA), _escrowSeed);
        fixedRemoteRouter.seedCanonicalEscrow(address(fixedTokenB), _escrowSeed);

        bugTokenA.mint(address(this), _escrowSeed);
        fixedTokenA.mint(address(this), _escrowSeed);
        bugTokenA.approve(address(bugRemoteRouter), type(uint256).max);
        fixedTokenA.approve(address(fixedRemoteRouter), type(uint256).max);
    }

    function _id(address _token) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_token)));
    }

    function _amount(uint256 _seed) internal pure returns (uint256) {
        return (_seed % 1000 ether) + 1;
    }

    function action_tryBugMigrateAliasSwap(uint96 _amountSeed) external {
        uint256 _amnt = _amount(_amountSeed);
        uint256 _aBefore = bugTokenA.balanceOf(address(this));
        uint256 _bBefore = bugTokenB.balanceOf(address(this));

        try bugRemoteRouter.send(address(bugTokenA), _amnt, address(this)) {
            address _legacyARepr =
                bugLocalRegistry.getRepresentationAddress(REMOTE_DOMAIN, bugIdA);
            if (_legacyARepr == address(0)) return;

            // Alias overwrite sequence: legacy A repr -> canonical B; then rotate current B repr.
            bugLocalRegistry.enrollCustom(REMOTE_DOMAIN, bugIdB, _legacyARepr);
            bugLocalRegistry.enrollCustom(
                REMOTE_DOMAIN, bugIdB, address(bugCustomB)
            );

            bugLocalRouter.migrate(_legacyARepr);
            bugLocalRouter.send(address(bugCustomB), _amnt, address(this));

            uint256 _aAfter = bugTokenA.balanceOf(address(this));
            uint256 _bAfter = bugTokenB.balanceOf(address(this));
            if (_bAfter == _bBefore + _amnt && _aAfter + _amnt == _aBefore) {
                bugMigrateSwapObserved = true;
            }
        } catch {}
    }

    function action_tryFixedMigrateInvariant(uint96 _amountSeed) external {
        uint256 _amnt = _amount(_amountSeed);
        uint256 _aBefore = fixedTokenA.balanceOf(address(this));
        uint256 _bBefore = fixedTokenB.balanceOf(address(this));

        try fixedRemoteRouter.send(address(fixedTokenA), _amnt, address(this)) {
            if (fixedLegacyARepr == address(0)) {
                fixedLegacyARepr = fixedLocalRegistry.getRepresentationAddress(
                    REMOTE_DOMAIN, fixedIdA
                );
                if (fixedLegacyARepr == address(0)) {
                    fixedViolationObserved = true;
                    return;
                }

                // Legit migrate path for same canonical tokenA.
                fixedLocalRegistry.enrollCustom(
                    REMOTE_DOMAIN, fixedIdA, address(fixedCustomA)
                );
            }

            // Attempt alias overwrite should always be blocked in fixed model.
            fixedAliasCheckAttempted = true;
            try
                fixedLocalRegistry.enrollCustom(
                    REMOTE_DOMAIN,
                    fixedIdB,
                    fixedLegacyARepr
                )
            {
                fixedViolationObserved = true;
                return;
            } catch {
                fixedAliasBlocked = true;
            }

            try fixedLocalRouter.migrate(fixedLegacyARepr) {
                try
                    fixedLocalRouter.send(
                        address(fixedCustomA), _amnt, address(this)
                    )
                {
                    uint256 _aAfter = fixedTokenA.balanceOf(address(this));
                    uint256 _bAfter = fixedTokenB.balanceOf(address(this));
                    if (_aAfter != _aBefore || _bAfter != _bBefore) {
                        fixedViolationObserved = true;
                    }
                } catch {
                    fixedViolationObserved = true;
                }
            } catch {
                fixedViolationObserved = true;
            }
        } catch {}
    }

    /// @notice migrate path should never allow canonical A->B conversion.
    function property_migrate_cannot_swap_canonical_asset()
        external
        view
        returns (bool)
    {
        return !bugMigrateSwapObserved;
    }

    /// @notice fixed model must block alias overwrite and preserve canonical settlement.
    function property_fixed_model_blocks_migrate_alias_swap()
        external
        view
        returns (bool)
    {
        if (fixedViolationObserved) return false;
        if (!fixedAliasCheckAttempted) return true;
        return fixedAliasBlocked;
    }

    /// @notice Echidna-compatible alias for bug property.
    function echidna_migrate_cannot_swap_canonical_asset()
        external
        view
        returns (bool)
    {
        return !bugMigrateSwapObserved;
    }
}


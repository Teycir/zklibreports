// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {
    IBridgeAssetLike,
    BridgeRouterAliasModel,
    MockCanonicalBridgeToken,
    MockRepresentationBridgeToken,
    TokenRegistryAliasBugModel,
    TokenRegistryAliasFixedModel
} from "./TokenRegistryAliasSwapHarness.sol";

/// @notice Stateful harness for representation-alias cross-asset swap behavior.
contract MedusaTokenRegistryAliasHarness {
    uint32 internal constant REMOTE_DOMAIN = 1000;
    uint32 internal constant LOCAL_DOMAIN = 2000;

    TokenRegistryAliasBugModel public bugLocalRegistry;
    TokenRegistryAliasBugModel public bugRemoteRegistry;
    BridgeRouterAliasModel public bugLocalRouter;
    BridgeRouterAliasModel public bugRemoteRouter;
    MockCanonicalBridgeToken public bugTokenA;
    MockCanonicalBridgeToken public bugTokenB;
    MockRepresentationBridgeToken public bugCustom;

    TokenRegistryAliasFixedModel public fixedLocalRegistry;
    TokenRegistryAliasFixedModel public fixedRemoteRegistry;
    BridgeRouterAliasModel public fixedLocalRouter;
    BridgeRouterAliasModel public fixedRemoteRouter;
    MockCanonicalBridgeToken public fixedTokenA;
    MockCanonicalBridgeToken public fixedTokenB;
    MockRepresentationBridgeToken public fixedCustom;

    bytes32 public bugIdA;
    bytes32 public bugIdB;
    bytes32 public fixedIdA;
    bytes32 public fixedIdB;

    bool public bugSwapObserved;
    bool public fixedViolationObserved;
    bool public fixedAliasBlocked;

    constructor() {
        bugLocalRegistry = new TokenRegistryAliasBugModel(LOCAL_DOMAIN);
        bugRemoteRegistry = new TokenRegistryAliasBugModel(REMOTE_DOMAIN);
        bugLocalRouter = new BridgeRouterAliasModel(address(bugLocalRegistry));
        bugRemoteRouter = new BridgeRouterAliasModel(address(bugRemoteRegistry));
        bugLocalRouter.setRemote(address(bugRemoteRouter));
        bugRemoteRouter.setRemote(address(bugLocalRouter));

        fixedLocalRegistry = new TokenRegistryAliasFixedModel(LOCAL_DOMAIN);
        fixedRemoteRegistry = new TokenRegistryAliasFixedModel(REMOTE_DOMAIN);
        fixedLocalRouter = new BridgeRouterAliasModel(address(fixedLocalRegistry));
        fixedRemoteRouter = new BridgeRouterAliasModel(
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

        bugCustom = new MockRepresentationBridgeToken(address(bugLocalRouter));
        fixedCustom = new MockRepresentationBridgeToken(address(fixedLocalRouter));

        bugLocalRegistry.enrollCustom(REMOTE_DOMAIN, bugIdA, address(bugCustom));
        bugLocalRegistry.enrollCustom(REMOTE_DOMAIN, bugIdB, address(bugCustom));

        fixedLocalRegistry.enrollCustom(
            REMOTE_DOMAIN, fixedIdA, address(fixedCustom)
        );
        try
            fixedLocalRegistry.enrollCustom(
                REMOTE_DOMAIN,
                fixedIdB,
                address(fixedCustom)
            )
        {
            fixedViolationObserved = true;
        } catch {
            fixedAliasBlocked = true;
        }

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

    function action_tryBugAliasSwap(uint96 _amountSeed) external {
        uint256 _amnt = _amount(_amountSeed);
        uint256 _bBefore = bugTokenB.balanceOf(address(this));
        uint256 _aBefore = bugTokenA.balanceOf(address(this));

        try bugRemoteRouter.send(address(bugTokenA), _amnt, address(this)) {
            try bugLocalRouter.send(address(bugCustom), _amnt, address(this)) {
                uint256 _bAfter = bugTokenB.balanceOf(address(this));
                uint256 _aAfter = bugTokenA.balanceOf(address(this));
                if (_bAfter == _bBefore + _amnt && _aAfter + _amnt == _aBefore) {
                    bugSwapObserved = true;
                }
            } catch {}
        } catch {}
    }

    function action_tryFixedAliasSwap(uint96 _amountSeed) external {
        uint256 _amnt = _amount(_amountSeed);
        uint256 _bBefore = fixedTokenB.balanceOf(address(this));

        if (!fixedAliasBlocked) {
            fixedViolationObserved = true;
            return;
        }

        try fixedRemoteRouter.send(address(fixedTokenA), _amnt, address(this)) {
            try fixedLocalRouter.send(address(fixedCustom), _amnt, address(this)) {
                uint256 _bAfter = fixedTokenB.balanceOf(address(this));
                if (_bAfter > _bBefore) {
                    fixedViolationObserved = true;
                }
            } catch {
                fixedViolationObserved = true;
            }
        } catch {
            fixedViolationObserved = true;
        }
    }

    /// @notice One representation address should never enable A->B cross-asset swap.
    function property_representation_alias_cannot_swap_assets()
        external
        view
        returns (bool)
    {
        return !bugSwapObserved;
    }

    /// @notice Fixed model must reject aliasing and prevent swap behavior.
    function property_fixed_model_blocks_alias_swap()
        external
        view
        returns (bool)
    {
        return !fixedViolationObserved;
    }

    /// @notice Echidna-compatible alias for bug property.
    function echidna_representation_alias_cannot_swap_assets()
        external
        view
        returns (bool)
    {
        return !bugSwapObserved;
    }
}

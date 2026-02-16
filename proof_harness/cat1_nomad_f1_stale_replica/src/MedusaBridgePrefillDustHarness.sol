// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {
    BridgeRouterPrefillDustBugModel,
    BridgeRouterPrefillDustFixedModel,
    DustReceiver,
    MockZeroAwareToken,
    TokenRegistryPrefillModel
} from "./BridgePrefillDustDrainHarness.sol";

/// @notice Stateful harness for forged preFill dust-drain behavior.
contract MedusaBridgePrefillDustHarness {
    uint32 internal constant LOCAL_DOMAIN = 2000;
    uint32 internal constant ORIGIN_DOMAIN = 1000;

    TokenRegistryPrefillModel public bugRegistry;
    TokenRegistryPrefillModel public fixedRegistry;
    BridgeRouterPrefillDustBugModel public bugRouter;
    BridgeRouterPrefillDustFixedModel public fixedRouter;
    MockZeroAwareToken public bugToken;
    MockZeroAwareToken public fixedToken;

    bool public bugDustDrainObserved;
    bool public fixedDustDrainObserved;

    constructor() {
        bugRegistry = new TokenRegistryPrefillModel(LOCAL_DOMAIN);
        fixedRegistry = new TokenRegistryPrefillModel(LOCAL_DOMAIN);
        bugRouter = new BridgeRouterPrefillDustBugModel(address(bugRegistry));
        fixedRouter = new BridgeRouterPrefillDustFixedModel(
            address(fixedRegistry)
        );
        bugToken = new MockZeroAwareToken();
        fixedToken = new MockZeroAwareToken();
        bugRouter.seedDustPool(1 ether);
        fixedRouter.seedDustPool(1 ether);
    }

    function _tokenId(address _token) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_token)));
    }

    function action_tryForgedBugPrefill(uint32 _nonce) external {
        DustReceiver _receiver = new DustReceiver();
        try
            bugRouter.preFill(
                ORIGIN_DOMAIN,
                _nonce,
                LOCAL_DOMAIN,
                _tokenId(address(bugToken)),
                address(_receiver),
                0,
                true
            )
        {
            if (
                bugRouter.dustedWei(address(_receiver)) == bugRouter.DUST_AMOUNT()
            ) {
                bugDustDrainObserved = true;
            }
        } catch {}
    }

    function action_tryForgedFixedPrefill(uint32 _nonce) external {
        DustReceiver _receiver = new DustReceiver();
        try
            fixedRouter.preFill(
                ORIGIN_DOMAIN,
                _nonce,
                LOCAL_DOMAIN,
                _tokenId(address(fixedToken)),
                address(_receiver),
                0,
                true
            )
        {
            if (
                fixedRouter.dustedWei(address(_receiver)) ==
                fixedRouter.DUST_AMOUNT()
            ) {
                fixedDustDrainObserved = true;
            }
        } catch {}
    }

    /// @notice Forged zero-amount preFill should never drain dust.
    function property_forged_prefill_cannot_drain_dust()
        external
        view
        returns (bool)
    {
        return !bugDustDrainObserved;
    }

    /// @notice Fixed model blocks forged preFill path.
    function property_fixed_model_blocks_forged_prefill()
        external
        view
        returns (bool)
    {
        return !fixedDustDrainObserved;
    }

    /// @notice Echidna-compatible alias for forged preFill dust-drain property.
    function echidna_forged_prefill_cannot_drain_dust()
        external
        view
        returns (bool)
    {
        return !bugDustDrainObserved;
    }
}

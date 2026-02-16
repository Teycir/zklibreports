// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {
    ICustomBridgedTokenLike,
    LineaF3SimpleProxy,
    BridgedTokenV1Like,
    CustomBridgedTokenV2Like,
    LineaF3InitV2Attacker
} from "./LineaF3CustomBridgedTokenInitV2TakeoverHarness.sol";

/// @notice Echidna harness for CustomBridgedToken initializeV2 takeover.
contract EchidnaLineaF3CustomBridgedTokenInitV2TakeoverHarness {
    address internal constant USER = address(0xCAFE);

    LineaF3SimpleProxy public proxy;
    ICustomBridgedTokenLike public token;
    LineaF3InitV2Attacker public attacker;

    constructor() {
        BridgedTokenV1Like implementationV1 = new BridgedTokenV1Like();
        CustomBridgedTokenV2Like implementationV2 = new CustomBridgedTokenV2Like();
        proxy = new LineaF3SimpleProxy(address(this));

        proxy.upgradeTo(address(implementationV1));
        token = ICustomBridgedTokenLike(address(proxy));
        token.initialize("bridgeToken", "BT", 18);

        // Non-atomic upgrade leaves initializeV2 externally callable.
        proxy.upgradeTo(address(implementationV2));
        attacker = new LineaF3InitV2Attacker();
    }

    function action_attacker_seize_bridge_and_mint() public {
        try attacker.seizeBridgeAndMint(address(proxy), USER, 1_000_000) {} catch {}
    }

    function echidna_bridge_control_remains_legitimate() public view returns (bool) {
        return token.bridge() == address(this);
    }
}

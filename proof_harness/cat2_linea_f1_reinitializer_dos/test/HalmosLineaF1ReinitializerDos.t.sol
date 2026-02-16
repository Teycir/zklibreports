// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {
    LineaF1SimpleProxy,
    LineaRollupLike,
    LineaReinitDosAttacker,
    ILineaRollupLike
} from "../src/LineaF1ReinitializerDosHarness.sol";

/// @notice Halmos check for the Linea reinitializer DoS.
contract HalmosLineaF1ReinitializerDos {
    function check_attacker_cannot_brick_genesis_submission() public {
        address admin = address(this);
        address operator = address(0xA0A0);

        LineaRollupLike implementation = new LineaRollupLike();
        LineaF1SimpleProxy proxy = new LineaF1SimpleProxy(admin);
        ILineaRollupLike rollup = ILineaRollupLike(address(proxy));
        LineaReinitDosAttacker attacker = new LineaReinitDosAttacker();

        proxy.upgradeTo(address(implementation));
        rollup.initialize(0, operator);

        attacker.poisonGenesis(address(proxy));

        assert(rollup.canSubmitData(rollup.GENESIS_SHNARF(), 1, 1));
    }
}


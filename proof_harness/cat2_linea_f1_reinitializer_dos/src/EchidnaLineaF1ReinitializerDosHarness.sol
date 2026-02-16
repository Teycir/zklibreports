// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {
    LineaF1SimpleProxy,
    LineaRollupLike,
    LineaReinitDosAttacker,
    ILineaRollupLike
} from "./LineaF1ReinitializerDosHarness.sol";

/// @notice Echidna harness for Linea reinitializer DoS.
contract EchidnaLineaF1ReinitializerDosHarness {
    LineaF1SimpleProxy public proxy;
    ILineaRollupLike public rollup;
    LineaReinitDosAttacker public attacker;

    constructor() {
        LineaRollupLike implementation = new LineaRollupLike();
        proxy = new LineaF1SimpleProxy(address(this));
        proxy.upgradeTo(address(implementation));

        rollup = ILineaRollupLike(address(proxy));
        rollup.initialize(0, address(this));

        attacker = new LineaReinitDosAttacker();
    }

    function action_attacker_poison_genesis() public {
        try attacker.poisonGenesis(address(proxy)) {} catch {}
    }

    function echidna_genesis_submission_path_remains_valid() public view returns (bool) {
        return rollup.canSubmitData(rollup.GENESIS_SHNARF(), 1, 1);
    }
}


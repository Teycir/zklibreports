// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {
    LineaF1SimpleProxy,
    LineaRollupLike,
    LineaReinitDosAttacker,
    ILineaRollupLike
} from "./LineaF1ReinitializerDosHarness.sol";

/// @notice Stateful Medusa harness for Linea reinitializer DoS.
contract MedusaLineaF1ReinitializerDosHarness {
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
        attacker.poisonGenesis(address(proxy));
    }

    function property_genesis_submission_path_remains_valid() public view returns (bool) {
        return rollup.canSubmitData(rollup.GENESIS_SHNARF(), 1, 1);
    }
}


// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {
    ILineaRollupV2Like,
    LineaF2SimpleProxy,
    LineaRollupV1Like,
    LineaRollupInitV2Like,
    LineaF2InitV2Attacker
} from "./LineaF2InitV2UpgradeGapHarness.sol";

/// @notice Echidna harness for initializeV2 non-atomic upgrade takeover.
contract EchidnaLineaF2InitV2UpgradeGapHarness {
    uint256 internal constant BASELINE_BLOCK = 100;
    uint256 internal constant ATTACKER_BLOCK = 777_777;
    bytes32 internal constant ATTACKER_ROOT = keccak256("attacker-root");

    LineaF2SimpleProxy public proxy;
    ILineaRollupV2Like public rollup;
    LineaF2InitV2Attacker public attacker;

    constructor() {
        LineaRollupV1Like implementationV1 = new LineaRollupV1Like();
        LineaRollupInitV2Like implementationV2 = new LineaRollupInitV2Like();
        proxy = new LineaF2SimpleProxy(address(this));

        proxy.upgradeTo(address(implementationV1));
        rollup = ILineaRollupV2Like(address(proxy));
        rollup.initialize(BASELINE_BLOCK);

        // Non-atomic upgrade: no initializeV2 call in same transaction.
        proxy.upgradeTo(address(implementationV2));
        attacker = new LineaF2InitV2Attacker();
    }

    function action_attacker_front_run_initializeV2() public {
        try attacker.seizeMigrationState(address(proxy), ATTACKER_BLOCK, ATTACKER_ROOT) {} catch {}
    }

    function echidna_migration_anchor_remains_admin_controlled() public view returns (bool) {
        return rollup.currentL2BlockNumber() == BASELINE_BLOCK && rollup.stateRootHashes(ATTACKER_BLOCK) == bytes32(0);
    }
}


// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {
    ILineaRollupV2Like,
    LineaF2SimpleProxy,
    LineaRollupV1Like,
    LineaRollupInitV2Like,
    LineaF2InitV2Attacker
} from "../src/LineaF2InitV2UpgradeGapHarness.sol";

/// @notice Halmos check for initializeV2 non-atomic upgrade takeover.
contract HalmosLineaF2InitV2UpgradeGap {
    function check_attacker_cannot_takeover_initv2() public {
        uint256 baselineBlock = 100;
        uint256 attackerBlock = 777_777;
        bytes32 attackerRoot = keccak256("attacker-root");

        LineaRollupV1Like implementationV1 = new LineaRollupV1Like();
        LineaRollupInitV2Like implementationV2 = new LineaRollupInitV2Like();
        LineaF2SimpleProxy proxy = new LineaF2SimpleProxy(address(this));
        ILineaRollupV2Like rollup = ILineaRollupV2Like(address(proxy));
        LineaF2InitV2Attacker attacker = new LineaF2InitV2Attacker();

        proxy.upgradeTo(address(implementationV1));
        rollup.initialize(baselineBlock);

        // Non-atomic upgrade leaves initializeV2 callable by arbitrary external accounts.
        proxy.upgradeTo(address(implementationV2));
        attacker.seizeMigrationState(address(proxy), attackerBlock, attackerRoot);

        assert(rollup.currentL2BlockNumber() == baselineBlock);
    }
}


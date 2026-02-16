// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {
    GovernanceDomainChurnBugModel,
    GovernanceDomainChurnFixedModel
} from "../src/GovernanceDomainChurnHarness.sol";

contract GovernanceDomainChurnGasProfileTest {
    uint32 internal constant DOMAIN = 1111;
    bytes32 internal constant ROUTER = bytes32(uint256(0xA11CE));
    uint256 internal constant NOT_FOUND = type(uint256).max;

    event log(string message);
    event log_named_uint(string key, uint256 val);

    struct LevelSnapshot {
        uint256 bugGas;
        uint256 fixedGas;
        uint256 bugScans;
        uint256 bugActive;
        uint256 fixedScans;
        uint256 fixedActive;
    }

    function _assertTrue(bool _condition, string memory _message) internal pure {
        require(_condition, _message);
    }

    function _churnBug(GovernanceDomainChurnBugModel bug, uint256 loops) internal {
        for (uint256 i = 0; i < loops; i++) {
            bug.setRouterLocal(DOMAIN, bytes32(0));
            bug.setRouterLocal(DOMAIN, ROUTER);
        }
    }

    function _churnFixed(
        GovernanceDomainChurnFixedModel fixedModel,
        uint256 loops
    ) internal {
        for (uint256 i = 0; i < loops; i++) {
            fixedModel.setRouterLocal(DOMAIN, bytes32(0));
            fixedModel.setRouterLocal(DOMAIN, ROUTER);
        }
    }

    function _measureDispatchGasBug(
        GovernanceDomainChurnBugModel bug
    ) internal returns (uint256 _gasUsed) {
        uint256 _gasBefore = gasleft();
        bug.dispatchAll();
        _gasUsed = _gasBefore - gasleft();
    }

    function _measureDispatchGasFixed(
        GovernanceDomainChurnFixedModel fixedModel
    ) internal returns (uint256 _gasUsed) {
        uint256 _gasBefore = gasleft();
        fixedModel.dispatchAll();
        _gasUsed = _gasBefore - gasleft();
    }

    function _profileLevel(
        uint256 loops
    ) internal returns (LevelSnapshot memory _snap) {
        GovernanceDomainChurnBugModel bug = new GovernanceDomainChurnBugModel();
        GovernanceDomainChurnFixedModel fixedModel =
            new GovernanceDomainChurnFixedModel();

        bug.setRouterLocal(DOMAIN, ROUTER);
        fixedModel.setRouterLocal(DOMAIN, ROUTER);

        _churnBug(bug, loops);
        _churnFixed(fixedModel, loops);

        _snap.bugGas = _measureDispatchGasBug(bug);
        _snap.fixedGas = _measureDispatchGasFixed(fixedModel);
        _snap.bugScans = bug.lastScanCount();
        _snap.bugActive = bug.activeDomainCount();
        _snap.fixedScans = fixedModel.lastScanCount();
        _snap.fixedActive = fixedModel.activeDomainCount();
    }

    /// @notice Profiles dispatch gas under growing churn and extracts threshold crossings.
    /// This quantifies when bug-path global dispatch reaches multiples of no-churn baseline.
    function test_profile_dispatch_gas_envelope_after_domain_churn() public {
        uint256[] memory levels = new uint256[](9);
        levels[0] = 0;
        levels[1] = 10;
        levels[2] = 25;
        levels[3] = 50;
        levels[4] = 100;
        levels[5] = 200;
        levels[6] = 400;
        levels[7] = 800;
        levels[8] = 1200;

        uint256 baselineBugGas;
        uint256 baselineFixedGas;
        uint256 previousBugGas;

        uint256 cross2x = NOT_FOUND;
        uint256 cross3x = NOT_FOUND;
        uint256 cross5x = NOT_FOUND;

        emit log("governance domain-churn dispatch gas profile");

        for (uint256 i = 0; i < levels.length; i++) {
            uint256 loops = levels[i];
            LevelSnapshot memory snap = _profileLevel(loops);

            emit log_named_uint("loops", loops);
            emit log_named_uint("bug_dispatch_gas", snap.bugGas);
            emit log_named_uint("fixed_dispatch_gas", snap.fixedGas);
            emit log_named_uint("bug_scans", snap.bugScans);
            emit log_named_uint("bug_active", snap.bugActive);
            emit log_named_uint("fixed_scans", snap.fixedScans);
            emit log_named_uint("fixed_active", snap.fixedActive);

            _assertTrue(
                snap.bugScans == loops + 1,
                "bug scans should track churned historical length"
            );
            _assertTrue(snap.bugActive == 1, "bug active domains should remain 1");
            _assertTrue(
                snap.fixedScans == 1 && snap.fixedActive == 1,
                "fixed model should remain dense at one active domain"
            );

            if (i == 0) {
                baselineBugGas = snap.bugGas;
                baselineFixedGas = snap.fixedGas;
                previousBugGas = snap.bugGas;
            } else {
                _assertTrue(
                    snap.bugGas > previousBugGas,
                    "bug dispatch gas should grow with churn level"
                );
                previousBugGas = snap.bugGas;

                uint256 fixedDrift = snap.fixedGas > baselineFixedGas
                    ? snap.fixedGas - baselineFixedGas
                    : baselineFixedGas - snap.fixedGas;
                _assertTrue(
                    fixedDrift <= 1500,
                    "fixed dispatch gas should remain near baseline"
                );
            }

            if (
                cross2x == NOT_FOUND && snap.bugGas >= (baselineBugGas * 2)
            ) {
                cross2x = loops;
            }
            if (
                cross3x == NOT_FOUND && snap.bugGas >= (baselineBugGas * 3)
            ) {
                cross3x = loops;
            }
            if (
                cross5x == NOT_FOUND && snap.bugGas >= (baselineBugGas * 5)
            ) {
                cross5x = loops;
            }
        }

        emit log_named_uint("baseline_bug_dispatch_gas", baselineBugGas);
        emit log_named_uint("baseline_fixed_dispatch_gas", baselineFixedGas);
        emit log_named_uint(
            "cross_2x_baseline_loops",
            cross2x == NOT_FOUND ? 0 : cross2x
        );
        emit log_named_uint(
            "cross_3x_baseline_loops",
            cross3x == NOT_FOUND ? 0 : cross3x
        );
        emit log_named_uint(
            "cross_5x_baseline_loops",
            cross5x == NOT_FOUND ? 0 : cross5x
        );

        _assertTrue(cross2x != NOT_FOUND, "expected 2x crossing in sampled range");
        _assertTrue(cross3x != NOT_FOUND, "expected 3x crossing in sampled range");
        _assertTrue(cross5x != NOT_FOUND, "expected 5x crossing in sampled range");
        _assertTrue(cross2x <= cross3x, "2x crossing should occur before 3x");
        _assertTrue(cross3x <= cross5x, "3x crossing should occur before 5x");
    }
}

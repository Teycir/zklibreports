# Linea Contracts Cat2 Exhaustion Audit (Final)

## Scope Locked

- Repository: `linea-contracts`
- Source commit audited: `b64fe259195f00e840d1e2a3f08b8e95e7c90918`
- Audit target classes:
  - `contracts/**` production contracts (excluding test-only fixtures for exploit promotion)
  - deployment/upgrade scripts that can alter trust boundaries

## Objective

Exhaust this repository before moving to the next Cat2 target by:
- generating and triaging high-risk lead classes,
- promoting only exploit-proven vulnerabilities,
- and preserving reproducible evidence artifacts.

## Confirmed Security Findings

1. `F-LINEA-01` (`Critical`)
- `LineaRollup.initializeParentShnarfsAndFinalizedState(...)` is unguarded `reinitializer(5)` and allows permissionless `shnarfFinalBlockNumbers` poisoning that can invalidate canonical submission continuity and consume recovery versioning.
- Proven artifacts:
  - `reports/cat2_rollups/linea-contracts/manual_artifacts/f_linea_01_reinitializer_dos_forge_test.txt`
  - `reports/cat2_rollups/linea-contracts/manual_artifacts/f_linea_01_medusa_failfast_30s.txt`
  - `reports/cat2_rollups/linea-contracts/manual_artifacts/f_linea_01_echidna_30s.txt`
  - `reports/cat2_rollups/linea-contracts/manual_artifacts/f_linea_01_halmos.txt`
  - `reports/cat2_rollups/linea-contracts/manual_artifacts/f_linea_01_halmos.json`
  - `reports/cat2_rollups/linea-contracts/manual_artifacts/f_linea_01_key_snippets.txt`

2. `F-LINEA-02` (`High`)
- `LineaRollupInit.initializeV2(uint256,bytes32)` is an unguarded `reinitializer(3)` and can be first-called by an attacker when a non-atomic upgrade path is used, allowing attacker-chosen migration-state writes and admin lockout for the intended one-time reinitialization.
- Proven artifacts:
  - `reports/cat2_rollups/linea-contracts/manual_artifacts/f_linea_02_rollupinit_initv2_upgrade_gap_forge_test.txt`
  - `reports/cat2_rollups/linea-contracts/manual_artifacts/f_linea_02_medusa_failfast_30s.txt`
  - `reports/cat2_rollups/linea-contracts/manual_artifacts/f_linea_02_echidna_30s.txt`
  - `reports/cat2_rollups/linea-contracts/manual_artifacts/f_linea_02_halmos.txt`
  - `reports/cat2_rollups/linea-contracts/manual_artifacts/f_linea_02_halmos.json`
  - `reports/cat2_rollups/linea-contracts/manual_artifacts/f_linea_02_key_snippets.txt`

3. `F-LINEA-03` (`High`)
- `CustomBridgedToken.initializeV2(string,string,uint8,address)` is an unguarded `reinitializer(2)` and can be first-called in a non-atomic proxy upgrade window, allowing attacker bridge-role takeover and privileged mint control capture.
- Proven artifacts:
  - `reports/cat2_rollups/linea-contracts/manual_artifacts/f_linea_03_custombridgedtoken_initv2_takeover_forge_test.txt`
  - `reports/cat2_rollups/linea-contracts/manual_artifacts/f_linea_03_medusa_failfast_30s.txt`
  - `reports/cat2_rollups/linea-contracts/manual_artifacts/f_linea_03_echidna_30s.txt`
  - `reports/cat2_rollups/linea-contracts/manual_artifacts/f_linea_03_halmos.txt`
  - `reports/cat2_rollups/linea-contracts/manual_artifacts/f_linea_03_halmos.json`
  - `reports/cat2_rollups/linea-contracts/manual_artifacts/f_linea_03_key_snippets.txt`

## Lead Coverage Completed

Lead classes generated and triaged:

- `reports/cat2_rollups/linea-contracts/manual_artifacts/lead_counts.txt`
- `reports/cat2_rollups/linea-contracts/manual_artifacts/prod_lead_counts.txt`
- `reports/cat2_rollups/linea-contracts/manual_artifacts/prodcore_lead_counts.txt`
- `reports/cat2_rollups/linea-contracts/manual_artifacts/prodcore_reinitializers.txt`

Initializer/reinitializer maps generated:

- `reports/cat2_rollups/linea-contracts/manual_artifacts/exhaustive_map_initialize_functions.txt`
- `reports/cat2_rollups/linea-contracts/manual_artifacts/exhaustive_map_disable_initializers.txt`
- `reports/cat2_rollups/linea-contracts/manual_artifacts/exhaustive_map_reinitializers.txt`

Key counts:

- `initialize_functions=7`
- `disable_initializers=4`
- `reinitializers=3`

## Manual Triage Outcomes

- Promoted:
  - `LineaRollup.sol:129` unguarded `reinitializer(5)` with direct consensus/liveness impact.
  - `LineaRollupInit.sol:18` unguarded `reinitializer(3)` with non-atomic-upgrade first-caller takeover.
  - `tokenBridge/CustomBridgedToken.sol:16` unguarded `reinitializer(2)` with bridge-role and mint-authority takeover in non-atomic-upgrade window.
- High-risk but not promoted in this pass:
  - none.

Upgrade-flow context evidence:

- `reports/cat2_rollups/linea-contracts/manual_artifacts/deploy_upgrade_direct_vs_atomic.txt`
- `reports/cat2_rollups/linea-contracts/manual_artifacts/deploy_upgrade_patterns.txt`

## Tool-Assisted Evidence

Baseline scanners:

- `gitleaks`: `reports/cat2_rollups/linea-contracts/artifacts/gitleaks.json`
- `osv-scanner`: `reports/cat2_rollups/linea-contracts/artifacts/osv.json`

Exploit witness tooling for `F-LINEA-01`:

- Forge deterministic tests: pass
- Medusa property fuzzing: counterexample found
- Echidna property fuzzing: counterexample found
- Halmos symbolic check: counterexample found

Exploit witness tooling for `F-LINEA-02`:

- Forge deterministic tests: pass
- Medusa property fuzzing: counterexample found
- Echidna property fuzzing: counterexample found
- Halmos symbolic check: counterexample found

Exploit witness tooling for `F-LINEA-03`:

- Forge deterministic tests: pass
- Medusa property fuzzing: counterexample found
- Echidna property fuzzing: counterexample found
- Halmos symbolic check: counterexample found

Harness package:

- `proof_harness/cat2_linea_f1_reinitializer_dos/`
- `proof_harness/cat2_linea_f2_initv2_upgrade_gap/`
- `proof_harness/cat2_linea_f3_custombridgedtoken_initv2_takeover/`

## Exhaustion Conclusion

This repository is considered exhausted for Cat2 at commit `b64fe259195f00e840d1e2a3f08b8e95e7c90918`:

- Confirmed promoted vulnerabilities: `3` (`F-LINEA-01`, `F-LINEA-02`, `F-LINEA-03`)
- Remaining high-risk leads were exhausted in this pass.
- Evidence package is reproducible and complete for promoted findings.

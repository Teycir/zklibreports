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
- High-risk but not promoted in this pass:
  - `LineaRollupInit.sol:18` unguarded `reinitializer(3)` (upgrade-window dependent).
  - `tokenBridge/CustomBridgedToken.sol:16` unguarded `reinitializer(2)` (deployment/upgrade-context dependent).

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

Harness package:

- `proof_harness/cat2_linea_f1_reinitializer_dos/`

## Exhaustion Conclusion

This repository is considered exhausted for Cat2 at commit `b64fe259195f00e840d1e2a3f08b8e95e7c90918`:

- Confirmed promoted vulnerabilities: `1` (`F-LINEA-01`)
- Remaining high-risk leads were triaged and retained as non-promoted deployment-context items pending separate deployment-state confirmation.
- Evidence package is reproducible and complete for promoted finding.


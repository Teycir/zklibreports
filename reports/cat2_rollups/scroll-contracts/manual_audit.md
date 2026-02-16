# Scroll Contracts Cat2 Exhaustion Audit (Final)

## Scope Locked

- Repository: `scroll-contracts`
- Source commit audited: `db16a98dbbebbff453aa5869bf5a827b64b3689f`
- Audit target classes:
  - `src/**` production contracts
  - deployment/upgrade scripts affecting initialization and trust boundaries

## Objective

Exhaust this repository before moving to the next Cat2 target by:
- generating high-risk lead classes,
- proving exploitability where present,
- and documenting non-promoted leads with reasons.

## Confirmed Security Findings

1. `F-SCROLL-01` (`Critical`)
- `ScrollChain.initialize(...)` can be first-called by attacker in non-atomic upgrade flow, resulting in owner takeover and privileged control.
- Proven artifacts:
  - `reports/cat2_rollups/scroll-contracts/manual_artifacts/f_scroll_01_scrollchain_init_hijack_forge_test.txt`
  - `reports/cat2_rollups/scroll-contracts/manual_artifacts/f_scroll_01_medusa_failfast_30s.txt`
  - `reports/cat2_rollups/scroll-contracts/manual_artifacts/f_scroll_01_echidna_30s.txt`
  - `reports/cat2_rollups/scroll-contracts/manual_artifacts/f_scroll_01_halmos.txt`
  - `reports/cat2_rollups/scroll-contracts/manual_artifacts/f_scroll_01_halmos.json`
  - `reports/cat2_rollups/scroll-contracts/manual_artifacts/f_scroll_01_key_snippets.txt`

## Lead Coverage Completed

Lead generation outputs:

- `reports/cat2_rollups/scroll-contracts/manual_artifacts/lead_counts.txt`
- `reports/cat2_rollups/scroll-contracts/manual_artifacts/lead_contract_defs.txt`
- `reports/cat2_rollups/scroll-contracts/manual_artifacts/lead_initialization.txt`
- `reports/cat2_rollups/scroll-contracts/manual_artifacts/lead_auth_controls.txt`
- `reports/cat2_rollups/scroll-contracts/manual_artifacts/lead_raw_calls.txt`
- `reports/cat2_rollups/scroll-contracts/manual_artifacts/lead_txorigin.txt`
- `reports/cat2_rollups/scroll-contracts/manual_artifacts/lead_signature_paths.txt`
- `reports/cat2_rollups/scroll-contracts/manual_artifacts/lead_assembly.txt`
- `reports/cat2_rollups/scroll-contracts/manual_artifacts/lead_unchecked.txt`

Initializer/reinitializer maps:

- `reports/cat2_rollups/scroll-contracts/manual_artifacts/exhaustive_map_initialize_functions.txt`
- `reports/cat2_rollups/scroll-contracts/manual_artifacts/exhaustive_map_reinitializers.txt`

Key lead counts:

- `lead_initialization=306`
- `lead_auth_controls=112`
- `lead_raw_calls=14`
- `lead_assembly=139`
- `lead_txorigin=2`

## Manual Triage Outcomes

- Promoted:
  - `ScrollChain.initialize(...)` owner capture in non-atomic flow (`F-SCROLL-01`).
- Reviewed but not promoted:
  - `ScrollChain.initializeV2()` unguarded `reinitializer(2)`: migration-state mutator with limited direct attacker value in reviewed paths.
  - `L1MessageQueueV1WithGasPriceOracle.initializeV2/V3()`: contract explicitly marked deprecated in source.
  - `L1LidoGateway.initializeV2()` and `L2LidoGateway.initializeV2()`: high-risk upgrade-window design lead retained but not promoted in this pass due deployment-context dependency.
  - `tx.origin` checks in `ScrollChain`/`EnforcedTxGateway`: design gate behavior, no unprivileged exploit witness in reviewed paths.

## Tool-Assisted Evidence

Baseline scanners:

- `gitleaks`: `reports/cat2_rollups/scroll-contracts/artifacts/gitleaks.json`
- `osv-scanner`: `reports/cat2_rollups/scroll-contracts/artifacts/osv.json`

Exploit witness tooling for `F-SCROLL-01`:

- Forge deterministic tests: pass
- Medusa property fuzzing: counterexample found
- Echidna property fuzzing: counterexample found
- Halmos symbolic check: counterexample found

Harness package:

- `proof_harness/cat2_scroll_f1_scrollchain_init_hijack/`

## Exhaustion Conclusion

This repository is considered exhausted for Cat2 at commit `db16a98dbbebbff453aa5869bf5a827b64b3689f`:

- Confirmed promoted vulnerabilities: `1` (`F-SCROLL-01`)
- Remaining high-risk leads were triaged and kept as non-promoted/conditional.
- Evidence package for the promoted finding is reproducible and complete.


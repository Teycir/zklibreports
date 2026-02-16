# Era Contracts Cat2 Exhaustion Audit (Final)

## Scope Locked

- Repository: `era-contracts`
- Source commit audited: `920501207baed3f33c66914039409c49f2dea1bb`
- Audit target classes:
  - `l1-contracts/contracts/**`
  - `l2-contracts/contracts/**`
  - `da-contracts/contracts/**`
  - deployment and operational scripts that can impact trust boundaries

## Objective

Exhaust this repo before moving to the next Cat2 target by closing all high-risk lead classes, proving exploitability where present, and documenting tool and environment limits.

## Confirmed Security Finding

1. `F-ERAC-01` (`High`) - `ChainRegistrar.initialize(...)` first-caller takeover with downstream proposer top-up redirection via `changeDeployer(...)`.
- Status: confirmed and already documented with proof artifacts.
- Primary artifact families:
  - `reports/cat2_rollups/era-contracts/manual_artifacts/f_erac_01_*`
  - `proof_harness/cat2_era_contracts_f1_chain_registrar_init_hijack/**`
  - `reports/cat2_rollups/era-contracts/report.md`
  - `reports/cat2_rollups/PROVEN_SUMMARY.md`

## Exhaustive Lead Coverage Completed

All lead generation outputs were produced and triaged under:

- `reports/cat2_rollups/era-contracts/manual_artifacts/exhaustive_leads_initializers_l1.txt`
- `reports/cat2_rollups/era-contracts/manual_artifacts/exhaustive_leads_init_modifiers_l1.txt`
- `reports/cat2_rollups/era-contracts/manual_artifacts/exhaustive_leads_rawcalls_l1.txt`
- `reports/cat2_rollups/era-contracts/manual_artifacts/exhaustive_leads_txorigin_l1.txt`
- `reports/cat2_rollups/era-contracts/manual_artifacts/exhaustive_leads_selfdestruct_l1.txt`
- `reports/cat2_rollups/era-contracts/manual_artifacts/exhaustive_leads_auth_modifiers_l1.txt`
- `reports/cat2_rollups/era-contracts/manual_artifacts/exhaustive_leads_init_l2.txt`
- `reports/cat2_rollups/era-contracts/manual_artifacts/exhaustive_leads_rawcalls_l2.txt`
- `reports/cat2_rollups/era-contracts/manual_artifacts/exhaustive_leads_txorigin_l2.txt`
- `reports/cat2_rollups/era-contracts/manual_artifacts/exhaustive_leads_selfdestruct_l2.txt`
- `reports/cat2_rollups/era-contracts/manual_artifacts/exhaustive_leads_auth_modifiers_l2.txt`
- `reports/cat2_rollups/era-contracts/manual_artifacts/exhaustive_leads_highrisk_da.txt`

Initializer and lock map outputs were also produced:

- `reports/cat2_rollups/era-contracts/manual_artifacts/exhaustive_map_initialize_functions_l1.txt`
- `reports/cat2_rollups/era-contracts/manual_artifacts/exhaustive_map_initialize_functions_l2.txt`
- `reports/cat2_rollups/era-contracts/manual_artifacts/exhaustive_map_disable_initializers_l1.txt`
- `reports/cat2_rollups/era-contracts/manual_artifacts/exhaustive_map_disable_initializers_l2.txt`

## Manual Validation Results

- The only clearly exploitable initialization race with concrete attacker value path remained `ChainRegistrar`.
- Other upgradeable initializers were manually cross-checked against constructor-time proxy init flows and deployment helpers.
- Key snippets and evidence references were consolidated in:
  - `reports/cat2_rollups/era-contracts/manual_artifacts/exhaustive_key_snippets.txt`

## Tool-Assisted Validation Results

### Aderyn

- UNC path execution failed (environment/path issue), logged in:
  - `reports/cat2_rollups/era-contracts/manual_artifacts/aderyn_l1_contracts_exhaustive.txt`
- Local clone execution reached compile then crashed in tool core, logged in:
  - `reports/cat2_rollups/era-contracts/manual_artifacts/aderyn_l1_contracts_localclone.txt`

### Semgrep

- Initial encoding failure logged in:
  - `reports/cat2_rollups/era-contracts/manual_artifacts/semgrep_l1_contracts_exhaustive.txt`
- UTF-8 rerun succeeded, results in:
  - `reports/cat2_rollups/era-contracts/manual_artifacts/semgrep_l1_contracts_exhaustive_utf8.txt`
- Output did not produce a promotable production-path security issue beyond known confirmed finding set.

### Slither

- Full-repo runs hit verifier IR/tool limitations, logs in:
  - `reports/cat2_rollups/era-contracts/manual_artifacts/slither_l1_contracts_localclone.txt`
  - `reports/cat2_rollups/era-contracts/manual_artifacts/slither_l1_contracts_localclone_no_verifiers.txt`
  - `reports/cat2_rollups/era-contracts/manual_artifacts/slither_state_transition_chain_deps_localclone_seq.txt`
- Targeted critical-contract runs completed with no additional promotable findings:
  - `reports/cat2_rollups/era-contracts/manual_artifacts/slither_chain_registrar_localclone_seq.txt`
  - `reports/cat2_rollups/era-contracts/manual_artifacts/slither_bridgehub_localclone_seq.txt`
  - `reports/cat2_rollups/era-contracts/manual_artifacts/slither_bridge_localclone_seq.txt`
  - `reports/cat2_rollups/era-contracts/manual_artifacts/slither_governance_localclone_seq.txt`
  - `reports/cat2_rollups/era-contracts/manual_artifacts/slither_state_transition_da_localclone_seq.txt`
  - `reports/cat2_rollups/era-contracts/manual_artifacts/slither_transaction_filterer_localclone_seq.txt`
  - `reports/cat2_rollups/era-contracts/manual_artifacts/slither_l2_consensus_registry_localclone.txt`
  - `reports/cat2_rollups/era-contracts/manual_artifacts/slither_da_contracts_localclone.txt`

## Non-Promoted Engineering Issue

- `l2-contracts/src/deploy-consensus-registry.ts` has `PROXY_ADMIN_ARTIFACT` set to `ConsensusRegistry` artifact (line 13).
- Classification: deployment/operational bug lead, not currently a proven security vulnerability with attacker value capture.

## Exhaustion Conclusion

This repository is considered exhausted at the current commit for Cat2 purposes:

- Confirmed vulnerabilities: no change beyond `F-ERAC-01`.
- Additional high-risk lead classes were generated, triaged, and either disproven or downgraded.
- Tool limitations were mitigated with targeted runs and manual verification.
- No second proven exploit chain was found with sufficient evidence threshold.

## Move-Forward Gate

Proceed to next Cat2 repository only after treating this file and existing `report.md` as the closed evidence package for `era-contracts` at commit `920501207baed3f33c66914039409c49f2dea1bb`.


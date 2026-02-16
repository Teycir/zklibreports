# Nomad F1 Proof Harness (`stale replica authorization`)

This harness reproduces the `F1` issue documented in:

- `reports/cat1_bridges/nomad-monorepo/manual_audit.md`

## What it proves

After rotating an enrolled replica for the same domain:

- Buggy logic keeps the old replica authorized (`isReplica(old) == true`).
- The stale replica still passes an `onlyReplica`-style receiver gate.
- The stale replica can also trigger a forged governance transfer path and seize local governor privileges in a governance sink model.
- The stale replica can inject a forged governance batch hash and execute privileged calls via permissionless `executeCallBatch`.
- Bootstrap committed-root acceptance bypasses optimistic timeout in the replica root-acceptance model.
- Forged zero-amount `preFill` can drain dust credits without providing liquidity in the bridge fast-liquidity path.
- Reusing one custom representation across multiple canonical token IDs can remap assets on roundtrip bridging.
- Governance domain-list churn can inflate global dispatch scan work above active-domain count.
- `migrate` can convert canonical asset identity after representation alias-overwrite.

The harness also includes a fixed manager for side-by-side contrast.

## Layout

- `src/XAppConnectionManagerHarness.sol`
  - `XAppConnectionManagerBug`: mirrors buggy re-enrollment logic.
  - `XAppConnectionManagerFixed`: reference fix.
- `src/OnlyReplicaReceiverHarness.sol`
  - Minimal receiver that requires `xcm.isReplica(msg.sender)`.
  - Replica caller harness for message sender simulation.
- `src/GovernanceRouterTakeoverHarness.sol`
  - Minimal governance receiver model (`onlyReplica + onlyGovernorRouter`) with transfer-governor handling.
  - Includes caller shims for replica-sender and post-takeover privileged calls.
- `src/GovernanceBatchInjectionHarness.sol`
  - Minimal governance batch model with `handle` + `executeCallBatch`.
  - Proves stale replica can enqueue forged batch hash for arbitrary privileged local call execution.
- `src/ReplicaBootstrapTimeoutHarness.sol`
  - `ReplicaBootstrapBug`: bootstrap root is immediately acceptable (`confirmAt[root] = 1`).
  - `ReplicaBootstrapFixed`: reference model with timeout-gated bootstrap root.
- `src/MedusaReplicaBootstrapHarness.sol`
  - Stateful specialist-fuzz harness for bootstrap timeout invariants.
- `src/BridgePrefillDustDrainHarness.sol`
  - `BridgeRouterPrefillDustBugModel`: forged fast-transfer prefill + dust logic model.
  - `BridgeRouterPrefillDustFixedModel`: reference model requiring approved prefill IDs.
- `src/MedusaBridgePrefillDustHarness.sol`
  - Stateful specialist-fuzz harness for forged prefill dust-drain invariants.
- `src/TokenRegistryAliasSwapHarness.sol`
  - Bug/fix models for `enrollCustom` representation aliasing and roundtrip token-ID forwarding.
- `src/TokenRegistryMigrateAliasHarness.sol`
  - `BridgeRouterMigrateAliasModel` with migrate behavior for alias-overwrite migration testing.
- `src/MedusaTokenRegistryAliasHarness.sol`
  - Stateful specialist-fuzz harness for cross-asset alias-swap invariants.
- `src/MedusaTokenRegistryMigrateHarness.sol`
  - Stateful specialist-fuzz harness for migrate + alias-overwrite canonical-swap invariants.
- `src/GovernanceDomainChurnHarness.sol`
  - Bug/fix models for governance domain-list churn scan-overhead behavior.
- `src/MedusaGovernanceDomainChurnHarness.sol`
  - Stateful specialist-fuzz harness for governance domain-churn liveness invariants.
- `test/StaleReplicaAuthorization.t.sol`
  - End-to-end witness test.
- `test/GovernanceTakeoverViaStaleReplica.t.sol`
  - End-to-end witness showing stale replica -> forged transfer-governor -> privileged state mutation.
- `test/GovernanceBatchInjectionViaStaleReplica.t.sol`
  - End-to-end witness showing stale replica -> forged batch hash -> privileged batch execution.
- `test/ReplicaBootstrapTimeoutBypass.t.sol`
  - End-to-end witness + fuzz test for bootstrap timeout bypass in buggy model with fixed-model control.
- `test/BridgePrefillDustDrain.t.sol`
  - End-to-end witness + fuzz test for forged prefill dust-drain path.
- `test/TokenRegistryAliasSwap.t.sol`
  - End-to-end witness + fuzz test for representation alias cross-asset remapping.
- `test/GovernanceDomainChurnLiveness.t.sol`
  - End-to-end witness + fuzz test for governance domain-list churn scan overhead.
- `test/GovernanceDomainChurnGasProfile.t.sol`
  - Instrumented gas-envelope test for dispatch growth under churn.
- `test/TokenRegistryMigrateAliasSwap.t.sol`
  - End-to-end witness + fuzz test for migrate-assisted canonical swap after alias overwrite.

## Run

```powershell
cd proof_harness/cat1_nomad_f1_stale_replica
forge test -vv
```

Expected: test passes and demonstrates stale `R1` calls succeed against the buggy manager but fail against the fixed manager.

## Deeper fuzz run

```powershell
cd proof_harness/cat1_nomad_f1_stale_replica
forge test -vv --fuzz-runs 5000
```

This executes sequence fuzzing for:
- stale auth persistence after re-enroll
- forward/reverse mapping desync after stale unenroll
- fixed-manager control invariants

## Governance takeover witness run

```powershell
cd proof_harness/cat1_nomad_f1_stale_replica
forge test -vv --match-path test/GovernanceTakeoverViaStaleReplica.t.sol
forge test -vv --match-path test/GovernanceTakeoverViaStaleReplica.t.sol --fuzz-runs 5000
```

Expected:
- buggy manager path passes witness where stale replica forges transfer-governor and seized governor can execute privileged action
- fixed manager path blocks stale replica call at `onlyReplica`

## Governance batch-injection witness run

```powershell
cd proof_harness/cat1_nomad_f1_stale_replica
forge test -vv --match-path test/GovernanceBatchInjectionViaStaleReplica.t.sol
forge test -vv --match-path test/GovernanceBatchInjectionViaStaleReplica.t.sol --fuzz-runs 5000
```

Expected:
- buggy manager path passes witness where stale replica injects batch hash and `executeCallBatch` executes privileged call
- fixed manager path blocks stale replica injection at `onlyReplica`

## Bootstrap timeout-bypass witness run

```powershell
cd proof_harness/cat1_nomad_f1_stale_replica
forge test -vv --match-path test/ReplicaBootstrapTimeoutBypass.t.sol
forge test -vv --match-path test/ReplicaBootstrapTimeoutBypass.t.sol --fuzz-runs 5000
```

Expected:
- buggy bootstrap model accepts proof immediately
- fixed bootstrap model rejects pre-timeout and accepts after timeout

## Forged prefill dust-drain witness run

```powershell
cd proof_harness/cat1_nomad_f1_stale_replica
forge test -vv --match-path test/BridgePrefillDustDrain.t.sol
forge test -vv --match-path test/BridgePrefillDustDrain.t.sol --fuzz-runs 5000
```

Expected:
- buggy prefill model allows zero-amount forged fast transfer to drain dust credits
- fixed model rejects forged zero-amount prefill

## Representation-alias swap witness run

```powershell
cd proof_harness/cat1_nomad_f1_stale_replica
forge test -vv --match-path test/TokenRegistryAliasSwap.t.sol
forge test -vv --match-path test/TokenRegistryAliasSwap.t.sol --fuzz-runs 5000
```

Expected:
- bug model permits enrolling one custom representation for two canonical IDs
- roundtrip send of that representation forwards the wrong canonical ID (asset remapping)
- fixed model blocks alias enroll and preserves canonical ID on roundtrip

## Governance domain-churn liveness witness run

```powershell
cd proof_harness/cat1_nomad_f1_stale_replica
forge test -vv --match-path test/GovernanceDomainChurnLiveness.t.sol
forge test -vv --match-path test/GovernanceDomainChurnLiveness.t.sol --fuzz-runs 5000
```

Expected:
- bug model scan count grows with churned `domains.length` rather than active domains
- fixed model keeps dense domain set so scan count tracks active domains

## Governance domain-churn gas-profile run

```powershell
cd proof_harness/cat1_nomad_f1_stale_replica
forge test -vv --match-path test/GovernanceDomainChurnGasProfile.t.sol
```

Expected:
- bug dispatch gas grows linearly with churned historical scan length
- fixed dispatch gas remains flat near baseline
- sampled threshold crossings:
  - 2x baseline at loops `100`
  - 3x baseline at loops `200`
  - 5x baseline at loops `400`

## Migrate-alias canonical-swap witness run

```powershell
cd proof_harness/cat1_nomad_f1_stale_replica
forge test -vv --match-path test/TokenRegistryMigrateAliasSwap.t.sol
forge test -vv --match-path test/TokenRegistryMigrateAliasSwap.t.sol --fuzz-runs 5000
```

Expected:
- bug model: alias-overwrite + migrate converts canonical tokenA exposure into tokenB settlement
- fixed model: alias-overwrite is blocked and same-canonical migrate preserves token identity

## Medusa run (specialist stateful fuzzer)

```powershell
cd proof_harness/cat1_nomad_f1_stale_replica
powershell -NoProfile -ExecutionPolicy Bypass -File ..\..\scripts\medusa.ps1 fuzz --compilation-target . --target-contracts MedusaXcmF1Harness --seq-len 8 --workers 4 --timeout 30 --fail-fast --no-color --log-level info
```

Expected:
- `property_unique_replica_per_domain` fails
- `property_bidirectional_mapping_consistency` fails

These failures are the Medusa counterexample witnesses for the stale replica auth and mapping desynchronization issues.

## Medusa sink-auth run (retired replica still reaches handle sink)

```powershell
cd proof_harness/cat1_nomad_f1_stale_replica
powershell -NoProfile -ExecutionPolicy Bypass -File ..\..\scripts\medusa.ps1 fuzz --compilation-target . --target-contracts MedusaSinkAuthHarness --seq-len 10 --workers 4 --timeout 30 --fail-fast --no-color --log-level info
```

Expected:
- `property_retired_replica_cannot_reach_sink` fails with a short sequence:
  - enroll R1
  - enroll R2 (same domain)
  - call sink handle from retired R1 with valid origin/router tuple

## Medusa governance-takeover run

```powershell
cd proof_harness/cat1_nomad_f1_stale_replica
powershell -NoProfile -ExecutionPolicy Bypass -File ..\..\scripts\medusa.ps1 fuzz --compilation-target . --target-contracts MedusaGovernanceTakeoverHarness --seq-len 10 --workers 4 --timeout 30 --fail-fast --no-color --log-level info
```

Expected:
- `property_retired_replica_cannot_take_governor` fails with a minimized 3-step sequence:
  - enroll R1
  - enroll R2 (same domain)
  - forged transfer-governor from retired R1

## Medusa governance batch-injection run

```powershell
cd proof_harness/cat1_nomad_f1_stale_replica
powershell -NoProfile -ExecutionPolicy Bypass -File ..\..\scripts\medusa.ps1 fuzz --compilation-target . --target-contracts MedusaGovernanceBatchInjectionHarness --seq-len 10 --workers 4 --timeout 30 --fail-fast --no-color --log-level info
```

Expected:
- `property_retired_replica_cannot_execute_forged_batch` fails with a minimized 3-step sequence:
  - enroll R1
  - enroll R2 (same domain)
  - stale R1 injects forged batch and executes privileged call

## Medusa bootstrap timeout run

```powershell
cd proof_harness/cat1_nomad_f1_stale_replica
powershell -NoProfile -ExecutionPolicy Bypass -File ..\..\scripts\medusa.ps1 fuzz --compilation-target . --target-contracts MedusaReplicaBootstrapHarness --seq-len 10 --workers 4 --timeout 30 --fail-fast --no-color --log-level info
```

Expected:
- `property_bootstrap_root_waits_timeout` fails
- `property_fixed_model_waits_timeout` passes

## Medusa forged-prefill dust-drain run

```powershell
cd proof_harness/cat1_nomad_f1_stale_replica
powershell -NoProfile -ExecutionPolicy Bypass -File ..\..\scripts\medusa.ps1 fuzz --compilation-target . --target-contracts MedusaBridgePrefillDustHarness --seq-len 10 --workers 4 --timeout 30 --fail-fast --no-color --log-level info
```

Expected:
- `property_forged_prefill_cannot_drain_dust` fails
- `property_fixed_model_blocks_forged_prefill` passes

## Medusa representation-alias swap run

```powershell
cd proof_harness/cat1_nomad_f1_stale_replica
powershell -NoProfile -ExecutionPolicy Bypass -File ..\..\scripts\medusa.ps1 fuzz --compilation-target . --target-contracts MedusaTokenRegistryAliasHarness --seq-len 10 --workers 4 --timeout 30 --fail-fast --no-color --log-level info
```

Expected:
- `property_representation_alias_cannot_swap_assets` fails
- `property_fixed_model_blocks_alias_swap` passes

## Medusa governance domain-churn run

```powershell
cd proof_harness/cat1_nomad_f1_stale_replica
powershell -NoProfile -ExecutionPolicy Bypass -File ..\..\scripts\medusa.ps1 fuzz --compilation-target . --target-contracts MedusaGovernanceDomainChurnHarness --seq-len 10 --workers 4 --timeout 30 --fail-fast --no-color --log-level info
```

Expected:
- `property_dispatch_scan_tracks_active_domains` fails
- `property_fixed_model_avoids_scan_overhead` passes

## Medusa migrate-alias run

```powershell
cd proof_harness/cat1_nomad_f1_stale_replica
powershell -NoProfile -ExecutionPolicy Bypass -File ..\..\scripts\medusa.ps1 fuzz --compilation-target . --target-contracts MedusaTokenRegistryMigrateHarness --seq-len 10 --workers 4 --timeout 30 --fail-fast --no-color --log-level info
```

Expected:
- `property_migrate_cannot_swap_canonical_asset` fails
- `property_fixed_model_blocks_migrate_alias_swap` passes

## Echidna cross-check

```powershell
cd proof_harness/cat1_nomad_f1_stale_replica
powershell -NoProfile -ExecutionPolicy Bypass -File ..\..\scripts\echidna.ps1 src/MedusaSinkAuthHarness.sol --contract MedusaSinkAuthHarness --test-mode property --seq-len 10 --test-limit 20000 --timeout 30 --format text --corpus-dir echidna-corpus
```

Expected:
- `echidna_retired_replica_cannot_reach_sink` fails with a 3-step sequence equivalent to the Medusa witness.

## Echidna governance-takeover cross-check

```powershell
cd proof_harness/cat1_nomad_f1_stale_replica
powershell -NoProfile -ExecutionPolicy Bypass -File ..\..\scripts\echidna.ps1 src/MedusaGovernanceTakeoverHarness.sol --contract MedusaGovernanceTakeoverHarness --test-mode property --seq-len 10 --test-limit 20000 --timeout 30 --format text --corpus-dir echidna-corpus
```

Expected:
- `echidna_retired_replica_cannot_take_governor` fails with equivalent 3-step sequence.

## Echidna governance batch-injection cross-check

```powershell
cd proof_harness/cat1_nomad_f1_stale_replica
powershell -NoProfile -ExecutionPolicy Bypass -File ..\..\scripts\echidna.ps1 src/MedusaGovernanceBatchInjectionHarness.sol --contract MedusaGovernanceBatchInjectionHarness --test-mode property --seq-len 10 --test-limit 20000 --timeout 30 --format text --corpus-dir echidna-corpus
```

Expected:
- `echidna_retired_replica_cannot_execute_forged_batch` fails with equivalent 3-step sequence.

## Echidna bootstrap-timeout cross-check

```powershell
cd proof_harness/cat1_nomad_f1_stale_replica
powershell -NoProfile -ExecutionPolicy Bypass -File ..\..\scripts\echidna.ps1 src/MedusaReplicaBootstrapHarness.sol --contract MedusaReplicaBootstrapHarness --test-mode property --seq-len 10 --test-limit 20000 --timeout 30 --format text --corpus-dir echidna-corpus-f6-formal
```

Expected:
- `echidna_bootstrap_root_waits_timeout` fails with minimized sequence including `action_tryProveBug()`

## Echidna forged-prefill dust-drain cross-check

```powershell
cd proof_harness/cat1_nomad_f1_stale_replica
powershell -NoProfile -ExecutionPolicy Bypass -File ..\..\scripts\echidna.ps1 src/MedusaBridgePrefillDustHarness.sol --contract MedusaBridgePrefillDustHarness --test-mode property --seq-len 10 --test-limit 20000 --timeout 30 --format text --corpus-dir echidna-corpus-f7-formal
```

Expected:
- `echidna_forged_prefill_cannot_drain_dust` fails with minimized sequence including `action_tryForgedBugPrefill(...)`

## Echidna representation-alias swap cross-check

```powershell
cd proof_harness/cat1_nomad_f1_stale_replica
powershell -NoProfile -ExecutionPolicy Bypass -File ..\..\scripts\echidna.ps1 src/MedusaTokenRegistryAliasHarness.sol --contract MedusaTokenRegistryAliasHarness --test-mode property --seq-len 10 --test-limit 20000 --timeout 30 --format text --corpus-dir echidna-corpus-f8-formal
```

Expected:
- `echidna_representation_alias_cannot_swap_assets` fails with minimized sequence including `action_tryBugAliasSwap(...)`

## Echidna governance domain-churn cross-check

```powershell
cd proof_harness/cat1_nomad_f1_stale_replica
powershell -NoProfile -ExecutionPolicy Bypass -File ..\..\scripts\echidna.ps1 src/MedusaGovernanceDomainChurnHarness.sol --contract MedusaGovernanceDomainChurnHarness --test-mode property --seq-len 10 --test-limit 20000 --timeout 30 --format text --corpus-dir echidna-corpus-f9-formal
```

Expected:
- `echidna_dispatch_scan_tracks_active_domains` fails with minimized sequence including `action_churn(0)` and `action_dispatch()`

## Echidna migrate-alias cross-check

```powershell
cd proof_harness/cat1_nomad_f1_stale_replica
powershell -NoProfile -ExecutionPolicy Bypass -File ..\..\scripts\echidna.ps1 src/MedusaTokenRegistryMigrateHarness.sol --contract MedusaTokenRegistryMigrateHarness --test-mode property --seq-len 10 --test-limit 20000 --timeout 30 --format text --corpus-dir echidna-corpus-f10-formal
```

Expected:
- `echidna_migrate_cannot_swap_canonical_asset` fails with minimized sequence including `action_tryBugMigrateAliasSwap(...)`

## Standardized campaign runner

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/evm_specialist_campaign.ps1 -HarnessDir proof_harness/cat1_nomad_f1_stale_replica -HarnessContract MedusaGovernanceBatchInjectionHarness -HarnessSource src/MedusaGovernanceBatchInjectionHarness.sol -ArtifactDir reports/cat1_bridges/nomad-monorepo/manual_artifacts -ArtifactPrefix f5_batch_injection_formal_v2 -TimeoutSec 8 -SkipEchidna
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/evm_specialist_campaign.ps1 -HarnessDir proof_harness/cat1_nomad_f1_stale_replica -HarnessContract MedusaReplicaBootstrapHarness -HarnessSource src/MedusaReplicaBootstrapHarness.sol -ArtifactDir reports/cat1_bridges/nomad-monorepo/manual_artifacts -ArtifactPrefix f6_bootstrap_timeout_formal -TimeoutSec 30 -EchidnaCorpusDir echidna-corpus-f6-formal
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/evm_specialist_campaign.ps1 -HarnessDir proof_harness/cat1_nomad_f1_stale_replica -HarnessContract MedusaBridgePrefillDustHarness -HarnessSource src/MedusaBridgePrefillDustHarness.sol -ArtifactDir reports/cat1_bridges/nomad-monorepo/manual_artifacts -ArtifactPrefix f7_prefill_dust_formal -TimeoutSec 30 -EchidnaCorpusDir echidna-corpus-f7-formal
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/evm_specialist_campaign.ps1 -HarnessDir proof_harness/cat1_nomad_f1_stale_replica -HarnessContract MedusaTokenRegistryAliasHarness -HarnessSource src/MedusaTokenRegistryAliasHarness.sol -ArtifactDir reports/cat1_bridges/nomad-monorepo/manual_artifacts -ArtifactPrefix f8_alias_swap_formal -TimeoutSec 30 -EchidnaCorpusDir echidna-corpus-f8-formal
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/evm_specialist_campaign.ps1 -HarnessDir proof_harness/cat1_nomad_f1_stale_replica -HarnessContract MedusaGovernanceDomainChurnHarness -HarnessSource src/MedusaGovernanceDomainChurnHarness.sol -ArtifactDir reports/cat1_bridges/nomad-monorepo/manual_artifacts -ArtifactPrefix f9_domain_churn_formal -TimeoutSec 30 -EchidnaCorpusDir echidna-corpus-f9-formal
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/evm_specialist_campaign.ps1 -HarnessDir proof_harness/cat1_nomad_f1_stale_replica -HarnessContract MedusaTokenRegistryMigrateHarness -HarnessSource src/MedusaTokenRegistryMigrateHarness.sol -ArtifactDir reports/cat1_bridges/nomad-monorepo/manual_artifacts -ArtifactPrefix f10_migrate_alias_formal -TimeoutSec 30 -EchidnaCorpusDir echidna-corpus-f10-formal
```

Output:
- `<prefix>_medusa_<timeout>s.txt`
- `<prefix>_echidna_<timeout>s.txt` (unless skipped)
- `<prefix>_campaign_meta.json`

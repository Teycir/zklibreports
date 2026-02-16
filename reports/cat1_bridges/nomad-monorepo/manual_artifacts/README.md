# nomad-monorepo manual artifacts

## F1 stale replica authorization

- Harness source: `proof_harness/cat1_nomad_f1_stale_replica`
- Command:
  - `forge test -vv`
- Captured output:
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f1_stale_replica_forge_test.txt`
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f1_fuzz_5000_runs.txt`
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f1_medusa_failfast_30s.txt`

## Medusa stateful property fuzzing

- Harness source: `proof_harness/cat1_nomad_f1_stale_replica/src/MedusaXcmF1Harness.sol`
- Command:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File ..\\..\\scripts\\medusa.ps1 fuzz --compilation-target . --target-contracts MedusaXcmF1Harness --seq-len 8 --workers 4 --timeout 30 --fail-fast --no-color --log-level info`
- Captured output:
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f1_medusa_failfast_30s.txt`

## Medusa sink-auth reachability fuzzing

- Harness source: `proof_harness/cat1_nomad_f1_stale_replica/src/MedusaSinkAuthHarness.sol`
- Command:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File ..\\..\\scripts\\medusa.ps1 fuzz --compilation-target . --target-contracts MedusaSinkAuthHarness --seq-len 10 --workers 4 --timeout 30 --fail-fast --no-color --log-level info`
- Captured output:
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f3_medusa_sink_auth_30s.txt`

## Echidna sink-auth cross-check

- Harness source: `proof_harness/cat1_nomad_f1_stale_replica/src/MedusaSinkAuthHarness.sol`
- Command:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File ..\\..\\scripts\\echidna.ps1 src/MedusaSinkAuthHarness.sol --contract MedusaSinkAuthHarness --test-mode property --seq-len 10 --test-limit 20000 --timeout 30 --format text --corpus-dir echidna-corpus`
- Captured output:
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f3_echidna_sink_auth_30s.txt`

## F4 governance takeover via stale replica auth

- Harness source: `proof_harness/cat1_nomad_f1_stale_replica`
- Command:
  - `forge test -vv --match-path test/GovernanceTakeoverViaStaleReplica.t.sol`
  - `forge test -vv --match-path test/GovernanceTakeoverViaStaleReplica.t.sol --fuzz-runs 5000`
- Captured output:
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f4_governance_takeover_forge_test.txt`
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f4_governance_takeover_fuzz_5000_runs.txt`
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f4_medusa_governance_takeover_30s.txt`
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f4_echidna_governance_takeover_30s.txt`

## Medusa governance-takeover property fuzzing

- Harness source: `proof_harness/cat1_nomad_f1_stale_replica/src/MedusaGovernanceTakeoverHarness.sol`
- Command:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File ..\\..\\scripts\\medusa.ps1 fuzz --compilation-target . --target-contracts MedusaGovernanceTakeoverHarness --seq-len 10 --workers 4 --timeout 30 --fail-fast --no-color --log-level info`
- Captured output:
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f4_medusa_governance_takeover_30s.txt`

## Echidna governance-takeover cross-check

- Harness source: `proof_harness/cat1_nomad_f1_stale_replica/src/MedusaGovernanceTakeoverHarness.sol`
- Command:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File ..\\..\\scripts\\echidna.ps1 src/MedusaGovernanceTakeoverHarness.sol --contract MedusaGovernanceTakeoverHarness --test-mode property --seq-len 10 --test-limit 20000 --timeout 30 --format text --corpus-dir echidna-corpus`
- Captured output:
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f4_echidna_governance_takeover_30s.txt`

## F5 governance batch injection via stale replica auth

- Harness source: `proof_harness/cat1_nomad_f1_stale_replica`
- Command:
  - `forge test -vv --match-path test/GovernanceBatchInjectionViaStaleReplica.t.sol`
  - `forge test -vv --match-path test/GovernanceBatchInjectionViaStaleReplica.t.sol --fuzz-runs 5000`
- Captured output:
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f5_batch_injection_forge_test.txt`
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f5_batch_injection_fuzz_5000_runs.txt`
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f5_medusa_batch_injection_30s.txt`
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f5_echidna_batch_injection_30s.txt`

## F6 bootstrap committed-root timeout bypass

- Harness source: `proof_harness/cat1_nomad_f1_stale_replica`
- Command:
  - `forge test -vv --match-path test/ReplicaBootstrapTimeoutBypass.t.sol`
  - `forge test -vv --match-path test/ReplicaBootstrapTimeoutBypass.t.sol --fuzz-runs 5000`
- Captured output:
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f6_bootstrap_timeout_forge_test.txt`
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f6_bootstrap_timeout_fuzz_5000_runs.txt`
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f6_bootstrap_timeout_formal_medusa_30s.txt`
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f6_bootstrap_timeout_formal_echidna_30s.txt`
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f6_bootstrap_timeout_formal_campaign_meta.json`

## F7 forged preFill dust-drain without liquidity

- Harness source: `proof_harness/cat1_nomad_f1_stale_replica`
- Command:
  - `forge test -vv --match-path test/BridgePrefillDustDrain.t.sol`
  - `forge test -vv --match-path test/BridgePrefillDustDrain.t.sol --fuzz-runs 5000`
- Captured output:
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f7_prefill_dust_forge_test.txt`
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f7_prefill_dust_fuzz_5000_runs.txt`
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f7_prefill_dust_formal_medusa_30s.txt`
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f7_prefill_dust_formal_echidna_30s.txt`
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f7_prefill_dust_formal_campaign_meta.json`

## F8 representation alias swap via repeated enrollCustom

- Harness source: `proof_harness/cat1_nomad_f1_stale_replica`
- Command:
  - `forge test -vv --match-path test/TokenRegistryAliasSwap.t.sol`
  - `forge test -vv --match-path test/TokenRegistryAliasSwap.t.sol --fuzz-runs 5000`
- Captured output:
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f8_alias_swap_forge_test.txt`
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f8_alias_swap_fuzz_5000_runs.txt`
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f8_alias_swap_formal_medusa_30s.txt`
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f8_alias_swap_formal_echidna_30s.txt`
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f8_alias_swap_formal_campaign_meta.json`

## F9 governance domain-list churn scan-overhead

- Harness source: `proof_harness/cat1_nomad_f1_stale_replica`
- Command:
  - `forge test -vv --match-path test/GovernanceDomainChurnLiveness.t.sol`
  - `forge test -vv --match-path test/GovernanceDomainChurnLiveness.t.sol --fuzz-runs 5000`
  - `forge test -vv --match-path test/GovernanceDomainChurnGasProfile.t.sol`
- Captured output:
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f9_domain_churn_forge_test.txt`
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f9_domain_churn_fuzz_5000_runs.txt`
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f9_domain_churn_formal_medusa_30s.txt`
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f9_domain_churn_formal_echidna_30s.txt`
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f9_domain_churn_formal_campaign_meta.json`
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f9_domain_churn_gas_profile_forge_test.txt`

## F10 migrate-assisted canonical swap after alias overwrite

- Harness source: `proof_harness/cat1_nomad_f1_stale_replica`
- Command:
  - `forge test -vv --match-path test/TokenRegistryMigrateAliasSwap.t.sol`
  - `forge test -vv --match-path test/TokenRegistryMigrateAliasSwap.t.sol --fuzz-runs 5000`
- Captured output:
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f10_migrate_alias_forge_test.txt`
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f10_migrate_alias_fuzz_5000_runs.txt`
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f10_migrate_alias_formal_medusa_30s.txt`
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f10_migrate_alias_formal_echidna_30s.txt`
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f10_migrate_alias_formal_campaign_meta.json`

## Full-source parity (H1/H2)

- Harness source:
  - `proof_harness/cat1_nomad_parity_fullsource`
- H1 command:
  - `forge test -vv --match-test test_h1_full_source_parity_migrate_alias_sequence`
- H1 artifact:
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/h1_fullsource_parity_forge_test.txt`
- H2 command:
  - `forge test -vv --match-test test_h2_full_source_parity_governance_domain_churn_gas_slope`
- H2 artifact:
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/h2_fullsource_parity_forge_test.txt`
- H2 baseline comparison artifact:
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f9_domain_churn_gas_profile_forge_test.txt`

## Standardized campaign runner artifact set

- Script:
  - `scripts/evm_specialist_campaign.ps1`
- Example run:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/evm_specialist_campaign.ps1 -HarnessDir proof_harness/cat1_nomad_f1_stale_replica -HarnessContract MedusaGovernanceBatchInjectionHarness -HarnessSource src/MedusaGovernanceBatchInjectionHarness.sol -ArtifactDir reports/cat1_bridges/nomad-monorepo/manual_artifacts -ArtifactPrefix f5_batch_injection_formal_v2 -TimeoutSec 8 -SkipEchidna`
  - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/evm_specialist_campaign.ps1 -HarnessDir proof_harness/cat1_nomad_f1_stale_replica -HarnessContract MedusaReplicaBootstrapHarness -HarnessSource src/MedusaReplicaBootstrapHarness.sol -ArtifactDir reports/cat1_bridges/nomad-monorepo/manual_artifacts -ArtifactPrefix f6_bootstrap_timeout_formal -TimeoutSec 30 -EchidnaCorpusDir echidna-corpus-f6-formal`
  - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/evm_specialist_campaign.ps1 -HarnessDir proof_harness/cat1_nomad_f1_stale_replica -HarnessContract MedusaBridgePrefillDustHarness -HarnessSource src/MedusaBridgePrefillDustHarness.sol -ArtifactDir reports/cat1_bridges/nomad-monorepo/manual_artifacts -ArtifactPrefix f7_prefill_dust_formal -TimeoutSec 30 -EchidnaCorpusDir echidna-corpus-f7-formal`
  - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/evm_specialist_campaign.ps1 -HarnessDir proof_harness/cat1_nomad_f1_stale_replica -HarnessContract MedusaTokenRegistryAliasHarness -HarnessSource src/MedusaTokenRegistryAliasHarness.sol -ArtifactDir reports/cat1_bridges/nomad-monorepo/manual_artifacts -ArtifactPrefix f8_alias_swap_formal -TimeoutSec 30 -EchidnaCorpusDir echidna-corpus-f8-formal`
  - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/evm_specialist_campaign.ps1 -HarnessDir proof_harness/cat1_nomad_f1_stale_replica -HarnessContract MedusaGovernanceDomainChurnHarness -HarnessSource src/MedusaGovernanceDomainChurnHarness.sol -ArtifactDir reports/cat1_bridges/nomad-monorepo/manual_artifacts -ArtifactPrefix f9_domain_churn_formal -TimeoutSec 30 -EchidnaCorpusDir echidna-corpus-f9-formal`
  - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/evm_specialist_campaign.ps1 -HarnessDir proof_harness/cat1_nomad_f1_stale_replica -HarnessContract MedusaTokenRegistryMigrateHarness -HarnessSource src/MedusaTokenRegistryMigrateHarness.sol -ArtifactDir reports/cat1_bridges/nomad-monorepo/manual_artifacts -ArtifactPrefix f10_migrate_alias_formal -TimeoutSec 30 -EchidnaCorpusDir echidna-corpus-f10-formal`
- Captured output:
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f5_batch_injection_formal_v2_medusa_8s.txt`
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f5_batch_injection_formal_v2_campaign_meta.json`
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f6_bootstrap_timeout_formal_medusa_30s.txt`
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f6_bootstrap_timeout_formal_echidna_30s.txt`
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f6_bootstrap_timeout_formal_campaign_meta.json`
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f7_prefill_dust_formal_medusa_30s.txt`
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f7_prefill_dust_formal_echidna_30s.txt`
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f7_prefill_dust_formal_campaign_meta.json`
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f8_alias_swap_formal_medusa_30s.txt`
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f8_alias_swap_formal_echidna_30s.txt`
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f8_alias_swap_formal_campaign_meta.json`
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f9_domain_churn_formal_medusa_30s.txt`
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f9_domain_churn_formal_echidna_30s.txt`
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f9_domain_churn_formal_campaign_meta.json`
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f10_migrate_alias_formal_medusa_30s.txt`
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f10_migrate_alias_formal_echidna_30s.txt`
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f10_migrate_alias_formal_campaign_meta.json`

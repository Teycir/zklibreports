# wormhole manual artifacts

## Static analysis baselines

- `reports/cat1_bridges/wormhole/manual_artifacts/slither_messages.json`
- `reports/cat1_bridges/wormhole/manual_artifacts/slither_messages.txt`
- `reports/cat1_bridges/wormhole/manual_artifacts/slither_governance.json`
- `reports/cat1_bridges/wormhole/manual_artifacts/slither_governance.txt`
- `reports/cat1_bridges/wormhole/manual_artifacts/slither_implementation.json`
- `reports/cat1_bridges/wormhole/manual_artifacts/slither_implementation.txt`
- `reports/cat1_bridges/wormhole/manual_artifacts/slither_bridge.json`
- `reports/cat1_bridges/wormhole/manual_artifacts/slither_bridge.txt`
- `reports/cat1_bridges/wormhole/manual_artifacts/aderyn_skipbuild.stdout.txt`
- `reports/cat1_bridges/wormhole/manual_artifacts/aderyn_skipbuild.stderr.txt`

## W1 metadata-method DoS witness

- Harness source: `proof_harness/cat1_wormhole_f1_metadata_dos`
- Command:
  - `forge test -vv --match-path test/BridgeMetadataCompat.t.sol`
  - `forge test -vv --match-path test/BridgeMetadataCompat.t.sol --fuzz-runs 5000`
- Captured output:
  - `reports/cat1_bridges/wormhole/manual_artifacts/w1_metadata_dos_forge_test.txt`
  - `reports/cat1_bridges/wormhole/manual_artifacts/w1_metadata_dos_fuzz_5000_runs.txt`
  - `reports/cat1_bridges/wormhole/manual_artifacts/w1_metadata_dos_formal_medusa_30s.txt`
  - `reports/cat1_bridges/wormhole/manual_artifacts/w1_metadata_dos_formal_echidna_30s.txt`
  - `reports/cat1_bridges/wormhole/manual_artifacts/w1_metadata_dos_formal_campaign_meta.json`

## W2 stale-guardian governance acceptance witness

- Harness source: `proof_harness/cat1_wormhole_f2_stale_guardian_governance`
- Command:
  - `forge test -vv --match-path test/StaleGuardianGovernance.t.sol`
  - `forge test -vv --match-path test/StaleGuardianGovernance.t.sol --fuzz-runs 5000`
- Captured output:
  - `reports/cat1_bridges/wormhole/manual_artifacts/w2_stale_guardian_governance_forge_test.txt`
  - `reports/cat1_bridges/wormhole/manual_artifacts/w2_stale_guardian_governance_fuzz_5000_runs.txt`
  - `reports/cat1_bridges/wormhole/manual_artifacts/w2_stale_guardian_governance_formal_medusa_30s.txt`
  - `reports/cat1_bridges/wormhole/manual_artifacts/w2_stale_guardian_governance_formal_echidna_30s.txt`
  - `reports/cat1_bridges/wormhole/manual_artifacts/w2_stale_guardian_governance_formal_campaign_meta.json`

## W3 outbound sender-tax solvency-break witness

- Harness source: `proof_harness/cat1_wormhole_f3_outbound_sender_tax_insolvency`
- Command:
  - `forge test -vv --match-path test/OutboundSenderTax.t.sol`
  - `forge test -vv --match-path test/OutboundSenderTax.t.sol --fuzz-runs 5000`
- Captured output:
  - `reports/cat1_bridges/wormhole/manual_artifacts/w3_outbound_sender_tax_forge_test.txt`
  - `reports/cat1_bridges/wormhole/manual_artifacts/w3_outbound_sender_tax_fuzz_5000_runs.txt`
  - `reports/cat1_bridges/wormhole/manual_artifacts/w3_outbound_sender_tax_formal_medusa_30s.txt`
  - `reports/cat1_bridges/wormhole/manual_artifacts/w3_outbound_sender_tax_formal_echidna_30s.txt`
  - `reports/cat1_bridges/wormhole/manual_artifacts/w3_outbound_sender_tax_formal_campaign_meta.json`

## H2 reentrancy replay-guard falsification

- Harness source: `proof_harness/cat1_wormhole_h2_reentrancy_replay_guard`
- Command:
  - `forge test -vv --match-path test/ReentrancyReplay.t.sol`
  - `forge test -vv --match-path test/ReentrancyReplay.t.sol --fuzz-runs 5000`
- Captured output:
  - `reports/cat1_bridges/wormhole/manual_artifacts/h2_reentrancy_replay_guard_forge_test.txt`
  - `reports/cat1_bridges/wormhole/manual_artifacts/h2_reentrancy_replay_guard_fuzz_5000_runs.txt`
  - `reports/cat1_bridges/wormhole/manual_artifacts/h2_reentrancy_replay_guard_formal_medusa_30s.txt`
  - `reports/cat1_bridges/wormhole/manual_artifacts/h2_reentrancy_replay_guard_formal_echidna_30s.txt`
  - `reports/cat1_bridges/wormhole/manual_artifacts/h2_reentrancy_replay_guard_formal_campaign_meta.json`

## Standardized campaign example

- Script:
  - `scripts/evm_specialist_campaign.ps1`
- Example run:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/evm_specialist_campaign.ps1 -HarnessDir proof_harness/cat1_wormhole_f3_outbound_sender_tax_insolvency -HarnessContract MedusaOutboundSenderTaxHarness -HarnessSource src/MedusaOutboundSenderTaxHarness.sol -ArtifactDir reports/cat1_bridges/wormhole/manual_artifacts -ArtifactPrefix w3_outbound_sender_tax_formal -TimeoutSec 30 -EchidnaCorpusDir echidna-corpus-w3-formal`

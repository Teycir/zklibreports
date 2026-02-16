# LayerZero-v2 manual artifacts

## Deterministic + fuzz witnesses

- Harness: `proof_harness/cat1_layerzero_v2_f1_oft_delegate`
- Commands:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File ..\..\scripts\forge.ps1 test -vv --match-path test/LayerZeroV2Findings.t.sol`
  - `powershell -NoProfile -ExecutionPolicy Bypass -File ..\..\scripts\forge.ps1 test -vv --match-path test/LayerZeroV2Findings.t.sol --fuzz-runs 5000`
- Captured output:
  - `reports/cat1_bridges/LayerZero-v2/manual_artifacts/lz1_lz2_forge_test.txt`
  - `reports/cat1_bridges/LayerZero-v2/manual_artifacts/lz1_lz2_fuzz_5000_runs.txt`

## LZ3 deterministic + fuzz witnesses (endpoint residual lzToken sweep)

- Harness: `proof_harness/cat1_layerzero_v2_f1_oft_delegate`
- Commands:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File ..\..\scripts\forge.ps1 test -vv --match-test lz3_`
  - `powershell -NoProfile -ExecutionPolicy Bypass -File ..\..\scripts\forge.ps1 test -vv --match-test lz3_ --fuzz-runs 5000`
- Captured output:
  - `reports/cat1_bridges/LayerZero-v2/manual_artifacts/lz3_residual_sweep_forge_test.txt`
  - `reports/cat1_bridges/LayerZero-v2/manual_artifacts/lz3_residual_sweep_fuzz_5000_runs.txt`

## LZ1 specialist fuzz campaign (OFT lossless assumption)

- Harness contract:
  - `proof_harness/cat1_layerzero_v2_f1_oft_delegate/src/MedusaLz1OFTAdapterHarness.sol`
- Standardized campaign command:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/evm_specialist_campaign.ps1 -HarnessDir proof_harness/cat1_layerzero_v2_f1_oft_delegate -HarnessContract MedusaLz1OFTAdapterHarness -HarnessSource src/MedusaLz1OFTAdapterHarness.sol -ArtifactDir reports/cat1_bridges/LayerZero-v2/manual_artifacts -ArtifactPrefix lz1_oft_lossless_formal -TimeoutSec 30 -EchidnaCorpusDir echidna-corpus-lz1-formal`
- Captured output:
  - `reports/cat1_bridges/LayerZero-v2/manual_artifacts/lz1_oft_lossless_formal_medusa_30s.txt`
  - `reports/cat1_bridges/LayerZero-v2/manual_artifacts/lz1_oft_lossless_formal_echidna_30s.txt`
  - `reports/cat1_bridges/LayerZero-v2/manual_artifacts/lz1_oft_lossless_formal_campaign_meta.json`

## LZ2 specialist fuzz campaign (stale delegate persistence)

- Harness contract:
  - `proof_harness/cat1_layerzero_v2_f1_oft_delegate/src/MedusaLz2DelegateHarness.sol`
- Standardized campaign command:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/evm_specialist_campaign.ps1 -HarnessDir proof_harness/cat1_layerzero_v2_f1_oft_delegate -HarnessContract MedusaLz2DelegateHarness -HarnessSource src/MedusaLz2DelegateHarness.sol -ArtifactDir reports/cat1_bridges/LayerZero-v2/manual_artifacts -ArtifactPrefix lz2_stale_delegate_formal -TimeoutSec 30 -EchidnaCorpusDir echidna-corpus-lz2-formal`
- Captured output:
  - `reports/cat1_bridges/LayerZero-v2/manual_artifacts/lz2_stale_delegate_formal_medusa_30s.txt`
  - `reports/cat1_bridges/LayerZero-v2/manual_artifacts/lz2_stale_delegate_formal_echidna_30s.txt`
  - `reports/cat1_bridges/LayerZero-v2/manual_artifacts/lz2_stale_delegate_formal_campaign_meta.json`

## LZ3 specialist fuzz campaign (endpoint residual lzToken sweep)

- Harness contract:
  - `proof_harness/cat1_layerzero_v2_f1_oft_delegate/src/MedusaLz3ResidualSweepHarness.sol`
- Standardized campaign command:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/evm_specialist_campaign.ps1 -HarnessDir proof_harness/cat1_layerzero_v2_f1_oft_delegate -HarnessContract MedusaLz3ResidualSweepHarness -HarnessSource src/MedusaLz3ResidualSweepHarness.sol -ArtifactDir reports/cat1_bridges/LayerZero-v2/manual_artifacts -ArtifactPrefix lz3_residual_sweep_formal -TimeoutSec 30 -EchidnaCorpusDir echidna-corpus-lz3-formal`
- Captured output:
  - `reports/cat1_bridges/LayerZero-v2/manual_artifacts/lz3_residual_sweep_formal_medusa_30s.txt`
  - `reports/cat1_bridges/LayerZero-v2/manual_artifacts/lz3_residual_sweep_formal_echidna_30s.txt`
  - `reports/cat1_bridges/LayerZero-v2/manual_artifacts/lz3_residual_sweep_formal_campaign_meta.json`

## Full-source parity (`H1`, `H2`, `H3`)

- Harness:
  - `proof_harness/cat1_layerzero_v2_parity_fullsource`
- Commands:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File ..\..\scripts\forge.ps1 test -vv --match-test test_h1_full_source_parity_oft_adapter_inbound_fee_collapse`
  - `powershell -NoProfile -ExecutionPolicy Bypass -File ..\..\scripts\forge.ps1 test -vv --match-test test_h2_full_source_parity_stale_delegate_persists_post_transfer`
  - `powershell -NoProfile -ExecutionPolicy Bypass -File ..\..\scripts\forge.ps1 test -vv --match-test test_h3_full_source_endpoint_lztoken_residual_sweep`
- Captured output:
  - `reports/cat1_bridges/LayerZero-v2/manual_artifacts/h1_fullsource_parity_oft_adapter_forge_test.txt`
  - `reports/cat1_bridges/LayerZero-v2/manual_artifacts/h2_fullsource_parity_delegate_stale_forge_test.txt`
  - `reports/cat1_bridges/LayerZero-v2/manual_artifacts/h3_fullsource_lztoken_residual_sweep_forge_test.txt`

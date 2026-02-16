# LayerZero-v2 finding harness (`lz1`, `lz2`)

This harness captures two LayerZero-v2 modelled findings:

- `lz1`: OFTAdapter lossless-transfer assumption can break collateral accounting for inbound-fee tokens.
- `lz2`: Endpoint delegate privilege can persist across OApp ownership transfer when delegate rotation is omitted.

## Run deterministic + fuzz tests

From this directory:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ..\..\scripts\forge.ps1 test -vv --match-path test/LayerZeroV2Findings.t.sol
powershell -NoProfile -ExecutionPolicy Bypass -File ..\..\scripts\forge.ps1 test -vv --match-path test/LayerZeroV2Findings.t.sol --fuzz-runs 5000
```

## Specialist fuzzing

`lz1` harness:
- `src/MedusaLz1OFTAdapterHarness.sol`

`lz2` harness:
- `src/MedusaLz2DelegateHarness.sol`

Example standardized campaign run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/evm_specialist_campaign.ps1 -HarnessDir proof_harness/cat1_layerzero_v2_f1_oft_delegate -HarnessContract MedusaLz1OFTAdapterHarness -HarnessSource src/MedusaLz1OFTAdapterHarness.sol -ArtifactDir reports/cat1_bridges/LayerZero-v2/manual_artifacts -ArtifactPrefix lz1_oft_lossless_formal -TimeoutSec 30 -EchidnaCorpusDir echidna-corpus-lz1-formal
```


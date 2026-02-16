# cat1_wormhole_h2_reentrancy_replay_guard

Purpose:
- Validate whether redemption-path reentrancy can double-redeem the same transfer.
- Compare vulnerable ordering (control) with Wormhole-like guard ordering.

## Layout

- `src/ReentrancyReplayHarness.sol`
- `src/MedusaReentrancyReplayHarness.sol`
- `test/ReentrancyReplay.t.sol`

## Deterministic witness

From this directory:

```powershell
forge test -vv --match-path test/ReentrancyReplay.t.sol
forge test -vv --match-path test/ReentrancyReplay.t.sol --fuzz-runs 5000
```

Expected:
- bug model double-redeems same VM under reentrancy (control);
- guard model redeems same VM at most once.

## Specialist fuzz witness

Initialize Medusa config once:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ..\..\scripts\medusa.ps1 init
```

Run campaign from repo root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/evm_specialist_campaign.ps1 `
  -HarnessDir proof_harness/cat1_wormhole_h2_reentrancy_replay_guard `
  -HarnessContract MedusaReentrancyReplayHarness `
  -HarnessSource src/MedusaReentrancyReplayHarness.sol `
  -ArtifactDir reports/cat1_bridges/wormhole/manual_artifacts `
  -ArtifactPrefix h2_reentrancy_replay_guard_formal `
  -TimeoutSec 30 `
  -EchidnaCorpusDir echidna-corpus-h2-replay-guard
```


# cat1_wormhole_f2_stale_guardian_governance

Purpose:
- Prove the governance verification asymmetry where core governance enforces
  current guardian set, but token-bridge governance accepts stale-but-unexpired
  sets from Wormhole VM verification.

## Layout

- `src/StaleGuardianGovernanceHarness.sol`
- `src/MedusaStaleGuardianGovernanceHarness.sol`
- `test/StaleGuardianGovernance.t.sol`

## Deterministic witness

From this directory:

```powershell
forge test -vv --match-path test/StaleGuardianGovernance.t.sol
forge test -vv --match-path test/StaleGuardianGovernance.t.sol --fuzz-runs 5000
```

Expected:
- bug model accepts stale-set governance upgrade while stale set is unexpired;
- core and fixed models reject stale-set governance upgrade.

## Specialist fuzz witness

Initialize Medusa config once:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ..\..\scripts\medusa.ps1 init
```

Run campaign from repo root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/evm_specialist_campaign.ps1 `
  -HarnessDir proof_harness/cat1_wormhole_f2_stale_guardian_governance `
  -HarnessContract MedusaStaleGuardianGovernanceHarness `
  -HarnessSource src/MedusaStaleGuardianGovernanceHarness.sol `
  -ArtifactDir reports/cat1_bridges/wormhole/manual_artifacts `
  -ArtifactPrefix w2_stale_guardian_governance_formal `
  -TimeoutSec 30 `
  -EchidnaCorpusDir echidna-corpus-w2-formal
```


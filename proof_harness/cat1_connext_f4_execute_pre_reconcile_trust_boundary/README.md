# Connext F4 Proof Harness (`execute pre-reconcile trust boundary`)

This harness validates the Connext fast-path trust boundary behavior documented in:

- `reports/cat1_bridges/connext-monorepo/manual_audit.md`

## What it validates

For destination `execute` before reconciliation:

- Fast path (`routers > 0`) supplies unauthenticated `originSender = address(0)` to `xReceive`.
- If receiver rejects unauthenticated origin sender, fast-path execute reverts and state rolls back.
- Reconciled slow path supplies authenticated `originSender` and strict receivers can succeed.
- Reconciled path swallows `xReceive` failure (fund transfer still succeeds), matching protocol semantics.

## Layout

- `src/ConnextExecuteTrustBoundaryHarness.sol`
  - `ConnextExecuteTrustBoundaryModel`
  - `StrictReceiver`
  - `LenientReceiver`
  - `RevertingReceiver`
- `src/MedusaConnextExecuteTrustBoundaryHarness.sol`
  - Specialist-fuzz harness for fast-path strict-receiver invariant.
- `test/ConnextExecuteTrustBoundary.t.sol`
  - Deterministic + fuzz falsification witnesses.

## Forge witness run

```powershell
cd proof_harness/cat1_connext_f4_execute_pre_reconcile_trust_boundary
forge test -vv --match-path test/ConnextExecuteTrustBoundary.t.sol
```

## Forge deeper fuzz run

```powershell
cd proof_harness/cat1_connext_f4_execute_pre_reconcile_trust_boundary
forge test -vv --match-path test/ConnextExecuteTrustBoundary.t.sol --fuzz-runs 5000
```

## Specialist campaign (Medusa + Echidna)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/evm_specialist_campaign.ps1 -HarnessDir proof_harness/cat1_connext_f4_execute_pre_reconcile_trust_boundary -HarnessContract MedusaConnextExecuteTrustBoundaryHarness -HarnessSource src/MedusaConnextExecuteTrustBoundaryHarness.sol -ArtifactDir reports/cat1_bridges/connext-monorepo/manual_artifacts -ArtifactPrefix f4_execute_pre_reconcile_trust_boundary_formal -TimeoutSec 30 -EchidnaCorpusDir echidna-corpus-f4-formal
```

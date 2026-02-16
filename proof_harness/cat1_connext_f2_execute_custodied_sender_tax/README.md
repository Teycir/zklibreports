# Connext F2 Proof Harness (`execute custodied sender-tax drift`)

This harness reproduces the Connext execute/custodied accounting issue documented in:

- `reports/cat1_bridges/connext-monorepo/manual_audit.md`

## What it proves

For canonical-domain execute paths with liquidity-cap custody tracking:

- Bug model decrements `custodied` by intent amount and then transfers token out.
- Sender-tax payout tokens can debit the contract by more than transferred amount.
- Post-state can violate coverage invariant (`collateral < custodied`).
- Fixed control model validates sender-side debit equals transfer amount and reverts otherwise.

## Layout

- `src/ConnextExecuteCustodiedSenderTaxHarness.sol`
  - `MockSenderDebitTaxToken`
  - `ConnextExecuteCustodiedBugModel`
  - `ConnextExecuteCustodiedFixedModel`
- `src/MedusaConnextExecuteCustodiedSenderTaxHarness.sol`
  - Stateful specialist-fuzz harness.
- `test/ConnextExecuteCustodiedSenderTax.t.sol`
  - Deterministic + fuzz witnesses.

## Forge witness run

```powershell
cd proof_harness/cat1_connext_f2_execute_custodied_sender_tax
forge test -vv --match-path test/ConnextExecuteCustodiedSenderTax.t.sol
```

## Forge deeper fuzz run

```powershell
cd proof_harness/cat1_connext_f2_execute_custodied_sender_tax
forge test -vv --match-path test/ConnextExecuteCustodiedSenderTax.t.sol --fuzz-runs 5000
```

## Specialist campaign (Medusa + Echidna)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/evm_specialist_campaign.ps1 -HarnessDir proof_harness/cat1_connext_f2_execute_custodied_sender_tax -HarnessContract MedusaConnextExecuteCustodiedSenderTaxHarness -HarnessSource src/MedusaConnextExecuteCustodiedSenderTaxHarness.sol -ArtifactDir reports/cat1_bridges/connext-monorepo/manual_artifacts -ArtifactPrefix f2_execute_custodied_sender_tax_formal -TimeoutSec 30 -EchidnaCorpusDir echidna-corpus-f2-formal
```

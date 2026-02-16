# Connext F1 Proof Harness (`router sender-tax withdrawal collateral drift`)

This harness reproduces the Connext router-liquidity accounting issue documented in:

- `reports/cat1_bridges/connext-monorepo/manual_audit.md`

## What it proves

For router-liquidity removal paths that debit internal balances by intent amount:

- Bug model decrements router balances by `_amount` and then transfers token out.
- Sender-tax payout tokens can debit the contract by more than `_amount`.
- Post-state can violate coverage invariant (`collateral < totalRouterBalances`).
- Fixed control model validates sender-side balance delta equals `_amount` and reverts otherwise.

## Layout

- `src/ConnextRouterSenderTaxHarness.sol`
  - `MockSenderDebitTaxToken`
  - `ConnextRouterLiquidityBugModel`
  - `ConnextRouterLiquidityFixedModel`
- `src/MedusaConnextRouterSenderTaxHarness.sol`
  - Stateful specialist-fuzz harness.
- `test/ConnextRouterSenderTax.t.sol`
  - Deterministic + fuzz witnesses.

## Forge witness run

```powershell
cd proof_harness/cat1_connext_f1_router_sender_tax
forge test -vv --match-path test/ConnextRouterSenderTax.t.sol
```

## Forge deeper fuzz run

```powershell
cd proof_harness/cat1_connext_f1_router_sender_tax
forge test -vv --match-path test/ConnextRouterSenderTax.t.sol --fuzz-runs 5000
```

## Specialist campaign (Medusa + Echidna)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/evm_specialist_campaign.ps1 -HarnessDir proof_harness/cat1_connext_f1_router_sender_tax -HarnessContract MedusaConnextRouterSenderTaxHarness -HarnessSource src/MedusaConnextRouterSenderTaxHarness.sol -ArtifactDir reports/cat1_bridges/connext-monorepo/manual_artifacts -ArtifactPrefix f1_router_sender_tax_formal -TimeoutSec 30 -EchidnaCorpusDir echidna-corpus-f1-formal
```

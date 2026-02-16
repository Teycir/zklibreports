# Connext F3 Proof Harness (`bumpTransfer sender-tax collateral drift`)

This harness reproduces the Connext relayer-fee bump accounting issue documented in:

- `reports/cat1_bridges/connext-monorepo/manual_audit.md`

## What it proves

For ERC20 relayer-fee bump paths:

- Bug model pulls relayer fee in with exact-delta check and then pays out with raw transfer.
- Sender-tax payout tokens can debit the contract by more than payout amount.
- Net effect can consume existing bridge collateral and violate `collateral >= totalRouterBalances`.
- Fixed control validates sender-side debit on outgoing fee payout and reverts otherwise.

## Layout

- `src/ConnextBumpTransferSenderTaxHarness.sol`
  - `MockSenderDebitTaxToken`
  - `ConnextBumpTransferBugModel`
  - `ConnextBumpTransferFixedModel`
- `src/MedusaConnextBumpTransferSenderTaxHarness.sol`
  - Stateful specialist-fuzz harness.
- `test/ConnextBumpTransferSenderTax.t.sol`
  - Deterministic + fuzz witnesses.

## Forge witness run

```powershell
cd proof_harness/cat1_connext_f3_bump_transfer_sender_tax
forge test -vv --match-path test/ConnextBumpTransferSenderTax.t.sol
```

## Forge deeper fuzz run

```powershell
cd proof_harness/cat1_connext_f3_bump_transfer_sender_tax
forge test -vv --match-path test/ConnextBumpTransferSenderTax.t.sol --fuzz-runs 5000
```

## Specialist campaign (Medusa + Echidna)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/evm_specialist_campaign.ps1 -HarnessDir proof_harness/cat1_connext_f3_bump_transfer_sender_tax -HarnessContract MedusaConnextBumpTransferSenderTaxHarness -HarnessSource src/MedusaConnextBumpTransferSenderTaxHarness.sol -ArtifactDir reports/cat1_bridges/connext-monorepo/manual_artifacts -ArtifactPrefix f3_bump_transfer_sender_tax_formal -TimeoutSec 30 -EchidnaCorpusDir echidna-corpus-f3-formal
```

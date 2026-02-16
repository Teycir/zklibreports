# cat1_wormhole_f3_outbound_sender_tax_insolvency

Purpose:
- Validate whether outbound redemption accounting tolerates sender-tax tokens that
  debit bridge balance by more than the logical transfer amount.

## Layout

- `src/OutboundSenderTaxHarness.sol`
- `src/MedusaOutboundSenderTaxHarness.sol`
- `test/OutboundSenderTax.t.sol`

## Deterministic witness

From this directory:

```powershell
forge test -vv --match-path test/OutboundSenderTax.t.sol
forge test -vv --match-path test/OutboundSenderTax.t.sol --fuzz-runs 5000
```

Expected:
- bug model can enter `collateral < outstanding` after redemption;
- fixed model rejects unexpected sender-side debit and preserves coverage.

## Specialist fuzz witness

Initialize Medusa config once:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ..\..\scripts\medusa.ps1 init
```

Run campaign from repo root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/evm_specialist_campaign.ps1 `
  -HarnessDir proof_harness/cat1_wormhole_f3_outbound_sender_tax_insolvency `
  -HarnessContract MedusaOutboundSenderTaxHarness `
  -HarnessSource src/MedusaOutboundSenderTaxHarness.sol `
  -ArtifactDir reports/cat1_bridges/wormhole/manual_artifacts `
  -ArtifactPrefix w3_outbound_sender_tax_formal `
  -TimeoutSec 30 `
  -EchidnaCorpusDir echidna-corpus-w3-formal
```


# Hyperlane H1 Proof Harness (`fee-on-transfer collateral deficit`)

This harness reproduces the Hyperlane collateral accounting issue documented in:

- `reports/cat1_bridges/hyperlane-monorepo/manual_audit.md`

## What it proves

H1 (`transferRemote` inbound fee-on-transfer):

- Bug model credits remote liability by intent amount.
- Inbound fee-on-transfer tokens credit less collateral than intent amount.
- Post-state violates collateral coverage (`collateral < remoteLiability`).
- Fixed control model (balance-delta accounting) preserves coverage.

H2 (`LpCollateralRouter` lpAssets accounting):
- Bug model increments LP asset accounting by requested amount.
- Inbound fee-on-transfer deposits credit less real collateral than `lpAssets`.
- Post-state violates collateral coverage (`collateral < lpAssets`) and full withdraw can revert.
- Fixed control tracks actual received amount.

H3 (`TokenRouter` fee transfer sender-tax side effects):
- Bug model charges sender and then transfers fee without validating sender-side debit.
- Sender-tax behavior on fee transfers can consume extra router collateral.
- Post-state violates collateral coverage (`collateral < remoteLiability`).
- Fixed control rejects unexpected sender-side fee-transfer debit.

## Layout

- `src/HyperlaneCollateralFeeHarness.sol`
  - `MockInboundFeeToken`: fee-on-transfer token model.
  - `HyperlaneCollateralBugModel`: intent-level collateral accounting.
  - `HyperlaneCollateralFixedModel`: actual-received accounting control.
- `src/HyperlaneLpAndFeeHarness.sol`
  - `HyperlaneLpAssetsBugModel` / `HyperlaneLpAssetsFixedModel`
  - `HyperlaneFeeTransferBugModel` / `HyperlaneFeeTransferFixedModel`
  - `MockInboundFeeTokenV2` / `MockSenderTaxTokenV2`
- `src/MedusaHyperlaneCollateralFeeHarness.sol`
  - Stateful specialist-fuzz harness (`action_*`, `property_*`).
- `src/MedusaHyperlaneLpAssetsHarness.sol`
- `src/MedusaHyperlaneFeeTransferHarness.sol`
- `test/HyperlaneCollateralFee.t.sol`
  - Deterministic witness + fuzz witness.
- `test/HyperlaneLpAndFeeFindings.t.sol`
  - Deterministic + fuzz witnesses for H2/H3.

## Forge witness run

```powershell
cd proof_harness/cat1_hyperlane_f1_collateral_fee_on_transfer
forge test -vv --match-path test/HyperlaneCollateralFee.t.sol
forge test -vv --match-path test/HyperlaneLpAndFeeFindings.t.sol
```

## Forge deeper fuzz run

```powershell
cd proof_harness/cat1_hyperlane_f1_collateral_fee_on_transfer
forge test -vv --match-path test/HyperlaneCollateralFee.t.sol --fuzz-runs 5000
forge test -vv --match-path test/HyperlaneLpAndFeeFindings.t.sol --fuzz-runs 5000
```

## Specialist campaign (Medusa + Echidna)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/evm_specialist_campaign.ps1 -HarnessDir proof_harness/cat1_hyperlane_f1_collateral_fee_on_transfer -HarnessContract MedusaHyperlaneCollateralFeeHarness -HarnessSource src/MedusaHyperlaneCollateralFeeHarness.sol -ArtifactDir reports/cat1_bridges/hyperlane-monorepo/manual_artifacts -ArtifactPrefix h1_collateral_fee_on_transfer_formal -TimeoutSec 30 -EchidnaCorpusDir echidna-corpus-h1-formal
```

Output:
- `h1_collateral_fee_on_transfer_formal_medusa_30s.txt`
- `h1_collateral_fee_on_transfer_formal_echidna_30s.txt`
- `h1_collateral_fee_on_transfer_formal_campaign_meta.json`

H2 specialist campaign:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/evm_specialist_campaign.ps1 -HarnessDir proof_harness/cat1_hyperlane_f1_collateral_fee_on_transfer -HarnessContract MedusaHyperlaneLpAssetsHarness -HarnessSource src/MedusaHyperlaneLpAssetsHarness.sol -ArtifactDir reports/cat1_bridges/hyperlane-monorepo/manual_artifacts -ArtifactPrefix h2_lp_assets_overstatement_formal -TimeoutSec 30 -EchidnaCorpusDir echidna-corpus-h2-formal
```

H3 specialist campaign:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/evm_specialist_campaign.ps1 -HarnessDir proof_harness/cat1_hyperlane_f1_collateral_fee_on_transfer -HarnessContract MedusaHyperlaneFeeTransferHarness -HarnessSource src/MedusaHyperlaneFeeTransferHarness.sol -ArtifactDir reports/cat1_bridges/hyperlane-monorepo/manual_artifacts -ArtifactPrefix h3_fee_transfer_sender_tax_formal -TimeoutSec 30 -EchidnaCorpusDir echidna-corpus-h3-formal
```

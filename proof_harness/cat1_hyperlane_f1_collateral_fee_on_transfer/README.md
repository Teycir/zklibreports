# Hyperlane H1 Proof Harness (`fee-on-transfer collateral deficit`)

This harness reproduces the Hyperlane collateral accounting issue documented in:

- `reports/cat1_bridges/hyperlane-monorepo/manual_audit.md`

## What it proves

For collateral routers that use `ERC20Collateral._transferFromSender` semantics:

- Bug model credits remote liability by intent amount.
- Inbound fee-on-transfer tokens credit less collateral than intent amount.
- Post-state violates collateral coverage (`collateral < remoteLiability`).
- Fixed control model (balance-delta accounting) preserves coverage.

## Layout

- `src/HyperlaneCollateralFeeHarness.sol`
  - `MockInboundFeeToken`: fee-on-transfer token model.
  - `HyperlaneCollateralBugModel`: intent-level collateral accounting.
  - `HyperlaneCollateralFixedModel`: actual-received accounting control.
- `src/MedusaHyperlaneCollateralFeeHarness.sol`
  - Stateful specialist-fuzz harness (`action_*`, `property_*`).
- `test/HyperlaneCollateralFee.t.sol`
  - Deterministic witness + fuzz witness.

## Forge witness run

```powershell
cd proof_harness/cat1_hyperlane_f1_collateral_fee_on_transfer
forge test -vv --match-path test/HyperlaneCollateralFee.t.sol
```

## Forge deeper fuzz run

```powershell
cd proof_harness/cat1_hyperlane_f1_collateral_fee_on_transfer
forge test -vv --match-path test/HyperlaneCollateralFee.t.sol --fuzz-runs 5000
```

## Specialist campaign (Medusa + Echidna)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/evm_specialist_campaign.ps1 -HarnessDir proof_harness/cat1_hyperlane_f1_collateral_fee_on_transfer -HarnessContract MedusaHyperlaneCollateralFeeHarness -HarnessSource src/MedusaHyperlaneCollateralFeeHarness.sol -ArtifactDir reports/cat1_bridges/hyperlane-monorepo/manual_artifacts -ArtifactPrefix h1_collateral_fee_on_transfer_formal -TimeoutSec 30 -EchidnaCorpusDir echidna-corpus-h1-formal
```

Output:
- `h1_collateral_fee_on_transfer_formal_medusa_30s.txt`
- `h1_collateral_fee_on_transfer_formal_echidna_30s.txt`
- `h1_collateral_fee_on_transfer_formal_campaign_meta.json`

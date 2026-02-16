# Synapse F1 Proof Harness (`deposit fee-on-transfer collateral deficit`)

This harness reproduces the Synapse bridge deposit accounting issue documented in:

- `reports/cat1_bridges/synapse-contracts/manual_audit.md`

## What it proves

For `deposit`/`depositAndSwap` style accounting based on intent amount:

- Bug model credits remote liability by requested amount.
- Inbound fee-on-transfer tokens credit less real collateral than requested.
- Post-state violates collateral coverage (`collateral < remoteLiability`).
- Fixed control model credits by actual received collateral amount.

## Layout

- `src/SynapseDepositFeeHarness.sol`
  - `MockInboundFeeToken`
  - `SynapseDepositBugModel`
  - `SynapseDepositFixedModel`
- `src/MedusaSynapseDepositFeeHarness.sol`
  - Stateful specialist-fuzz harness.
- `test/SynapseDepositFee.t.sol`
  - Deterministic + fuzz witnesses.

## Forge witness run

```powershell
cd proof_harness/cat1_synapse_f1_deposit_fee_on_transfer
forge test -vv --match-path test/SynapseDepositFee.t.sol
```

## Forge deeper fuzz run

```powershell
cd proof_harness/cat1_synapse_f1_deposit_fee_on_transfer
forge test -vv --match-path test/SynapseDepositFee.t.sol --fuzz-runs 5000
```

## Specialist campaign (Medusa + Echidna)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/evm_specialist_campaign.ps1 -HarnessDir proof_harness/cat1_synapse_f1_deposit_fee_on_transfer -HarnessContract MedusaSynapseDepositFeeHarness -HarnessSource src/MedusaSynapseDepositFeeHarness.sol -ArtifactDir reports/cat1_bridges/synapse-contracts/manual_artifacts -ArtifactPrefix f1_deposit_fee_on_transfer_formal -TimeoutSec 30 -EchidnaCorpusDir echidna-corpus-f1-formal
```

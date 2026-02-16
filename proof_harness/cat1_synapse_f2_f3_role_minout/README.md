# Synapse F2/F3 Proof Harness (`role escalation blast radius` + `min-out receipt mismatch`)

This harness reproduces and controls the Synapse findings documented in:

- `reports/cat1_bridges/synapse-contracts/manual_audit.md`

## What it proves

F2 (`role escalation blast radius`):
- Bug model allows default-admin actor to grant settlement role directly.
- A compromised default-admin path can escalate node privileges and drain collateral.
- Fixed control requires a distinct governance actor for node-role assignment.

F3 (`min-out receipt mismatch`):
- Bug model validates `minOut` against quoted swap output only.
- Sender-tax payout tokens can reduce user receipt below `minOut` while settlement still succeeds.
- Fixed control enforces `minOut` against actual recipient balance delta.

## Layout

- `src/SynapseRoleAndMinOutHarness.sol`
  - `MockSenderTaxTokenV2`
  - `SynapseRoleEscalationBugModel` / `SynapseRoleEscalationFixedModel`
  - `SynapseMinOutBugModel` / `SynapseMinOutFixedModel`
- `src/MedusaSynapseRoleEscalationHarness.sol`
  - Stateful specialist-fuzz harness for F2.
- `src/MedusaSynapseMinOutHarness.sol`
  - Stateful specialist-fuzz harness for F3.
- `test/SynapseF2F3.t.sol`
  - Deterministic + fuzz witnesses.

## Forge witness run

```powershell
cd proof_harness/cat1_synapse_f2_f3_role_minout
forge test -vv --match-path test/SynapseF2F3.t.sol
```

## Forge deeper fuzz run

```powershell
cd proof_harness/cat1_synapse_f2_f3_role_minout
forge test -vv --match-path test/SynapseF2F3.t.sol --fuzz-runs 5000
```

## Specialist campaign (Medusa + Echidna)

F2:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/evm_specialist_campaign.ps1 -HarnessDir proof_harness/cat1_synapse_f2_f3_role_minout -HarnessContract MedusaSynapseRoleEscalationHarness -HarnessSource src/MedusaSynapseRoleEscalationHarness.sol -ArtifactDir reports/cat1_bridges/synapse-contracts/manual_artifacts -ArtifactPrefix f2_role_escalation_blast_radius_formal -TimeoutSec 30 -EchidnaCorpusDir echidna-corpus-f2-formal
```

F3:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/evm_specialist_campaign.ps1 -HarnessDir proof_harness/cat1_synapse_f2_f3_role_minout -HarnessContract MedusaSynapseMinOutHarness -HarnessSource src/MedusaSynapseMinOutHarness.sol -ArtifactDir reports/cat1_bridges/synapse-contracts/manual_artifacts -ArtifactPrefix f3_min_out_receipt_mismatch_formal -TimeoutSec 30 -EchidnaCorpusDir echidna-corpus-f3-formal
```

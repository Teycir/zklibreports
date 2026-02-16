# synapse-contracts (Manual Audit, Step 2/5)

Scope: `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\synapse-contracts`

HEAD: `60f1c25cf2f115911e11255f515e1450fe96100c`

Pass status: Exhausted for this pass (F1/F2/F3 evidence-closed with deterministic + fuzz + specialist-fuzzer witnesses).

Primary scope (this pass):
- `contracts/bridge/SynapseBridge.sol`
- Bridge router paths in `contracts/bridge/router`

Non-goals (this pass):
- DFK/game messaging contracts, auxiliary wrappers, and deployment/ops scripting unless needed for an on-chain proof.

## Protocol Snapshot (Bridge Path)

- Users initiate outbound bridge intents via:
  - `deposit(...)`
  - `depositAndSwap(...)`
  - `redeem(...)` / `redeemAndSwap(...)` / `redeemAndRemove(...)`
- Node group (`NODEGROUP_ROLE`) finalizes inbound outcomes via:
  - `withdraw(...)`
  - `mint(...)`
  - `mintAndSwap(...)`
  - `withdrawAndRemove(...)`
- Replay suppression is keyed by `kappaMap[kappa]` on node-executed paths.

## Critical Invariants

- Collateral-vs-credit:
  - Outbound credit intent consumed by relayers/nodes should not exceed actual collateral received on source chain.
- Replay safety:
  - `kappa`-keyed settlement paths must remain single-use.
- Role boundary:
  - Settlement privilege (`NODEGROUP_ROLE`) should not be reachable through unintended role-admin paths.
- User min-out safety:
  - Destination min-out guarantees should be enforced against actual user receipt, not only intermediate swap output.

## Proven Findings

### F1: `deposit` / `depositAndSwap` intent-level amount handling can over-credit cross-chain liabilities for fee-on-transfer tokens

Severity: Medium (token-specific solvency impact)

Affected code:
- `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\synapse-contracts\contracts\bridge\SynapseBridge.sol`
  - `deposit(...)`
  - `depositAndSwap(...)`

Root cause:
- Both outbound entrypoints transfer `amount` with `safeTransferFrom` but do not measure actual received collateral.
- Off-chain relay intent (modeled via emitted amount / consumed bridge amount) can remain at caller intent even if token transfer applies inbound haircut.

Concrete witness sequence:
1. Configure fee-on-transfer token behavior (5% haircut when bridge contract is recipient).
2. Call `deposit(100_000)` (or `depositAndSwap(100_000)`).
3. Bridge contract receives only `95_000` collateral.
4. Cross-chain liability/credit intent remains `100_000`.
5. Post-state violates coverage invariant (`collateral < remoteLiability`).

Impact:
- For affected tokens, source-chain collateral can be lower than destination-side credited amount.
- This creates token-specific shortfall/insolvency behavior on settlement paths.

Recommended fix:
- Measure pre/post token balance in outbound deposit paths and derive bridged amount from actual received collateral.
- Emit/relay the received amount, not the requested intent amount.
- Optionally disallow unsupported fee-on-transfer token classes.

Executable witness:
- Harness:
  - `proof_harness/cat1_synapse_f1_deposit_fee_on_transfer`
- Tests:
  - `test_f1_bug_model_deposit_fee_on_transfer_breaks_collateral_invariant`
  - `test_f1_bug_model_deposit_and_swap_fee_on_transfer_breaks_collateral_invariant`
  - `test_f1_fixed_model_tracks_actual_received`
  - `testFuzz_f1_bug_model_deposit_can_break_collateral_invariant`
- Artifacts:
  - `reports/cat1_bridges/synapse-contracts/manual_artifacts/f1_deposit_fee_on_transfer_forge_test.txt`
  - `reports/cat1_bridges/synapse-contracts/manual_artifacts/f1_deposit_fee_on_transfer_fuzz_5000_runs.txt`
  - `reports/cat1_bridges/synapse-contracts/manual_artifacts/f1_deposit_fee_on_transfer_formal_medusa_30s.txt`
  - `reports/cat1_bridges/synapse-contracts/manual_artifacts/f1_deposit_fee_on_transfer_formal_echidna_30s.txt`
  - `reports/cat1_bridges/synapse-contracts/manual_artifacts/f1_deposit_fee_on_transfer_formal_campaign_meta.json`

### F2: `DEFAULT_ADMIN_ROLE` compromise can escalate into `NODEGROUP_ROLE` settlement authority and drain bridge collateral

Severity: High (privilege-escalation blast radius under admin-key compromise)

Affected code:
- `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\synapse-contracts\contracts\bridge\SynapseBridge.sol`
  - `initialize()` (`DEFAULT_ADMIN_ROLE` bootstrap)
  - AccessControl role topology (default role-admin relationship)
  - Settlement entrypoints requiring `NODEGROUP_ROLE`:
    - `withdraw(...)`
    - `mint(...)`
    - `mintAndSwap(...)`
    - `withdrawAndRemove(...)`

Root cause:
- Settlement privilege is correctly gated by `NODEGROUP_ROLE`, but role-admin hardening is not built into the contract itself.
- Under default AccessControl semantics, `DEFAULT_ADMIN_ROLE` controls role assignment, so admin-key compromise can immediately grant settlement authority.

Concrete witness sequence:
1. Attacker obtains default-admin control.
2. Attacker grants settlement role to attacker-controlled account.
3. Attacker executes settlement withdraw path and drains modeled collateral.
4. Fixed control requiring distinct governance actor for node-role grants blocks the same admin-only path.

Impact:
- Admin-key compromise has direct path to settlement execution capability.
- This collapses intended separation between administrative control and settlement custody.

Recommended fix:
- Assign `NODEGROUP_ROLE` admin to hardened governance/timelock flow instead of direct default-admin path.
- Enforce staged role changes (delay + monitoring window) for settlement-role grants.
- Add operational monitoring/alerts on role-grant events targeting settlement roles.

Executable witness:
- Harness:
  - `proof_harness/cat1_synapse_f2_f3_role_minout`
- Tests:
  - `test_f2_bug_model_admin_can_grant_node_and_drain`
  - `test_f2_fixed_model_admin_only_cannot_grant_node_or_drain`
- Artifacts:
  - `reports/cat1_bridges/synapse-contracts/manual_artifacts/f2_f3_role_and_minout_forge_test.txt`
  - `reports/cat1_bridges/synapse-contracts/manual_artifacts/f2_f3_role_and_minout_fuzz_5000_runs.txt`
  - `reports/cat1_bridges/synapse-contracts/manual_artifacts/f2_role_escalation_blast_radius_formal_medusa_30s.txt`
  - `reports/cat1_bridges/synapse-contracts/manual_artifacts/f2_role_escalation_blast_radius_formal_echidna_30s.txt`
  - `reports/cat1_bridges/synapse-contracts/manual_artifacts/f2_role_escalation_blast_radius_formal_campaign_meta.json`

### F3: Destination min-out can be violated on actual user receipt when payout token transfer applies sender-side tax

Severity: Medium (token-specific slippage/min-out guarantee failure)

Affected code:
- `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\synapse-contracts\contracts\bridge\SynapseBridge.sol`
  - `mintAndSwap(...)`
  - `withdrawAndRemove(...)`
- Related planner path:
  - `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\synapse-contracts\contracts\bridge\router\SynapseRouter.sol`
    - `bridge(...)` forwarding `destQuery.minAmountOut` into destination min-out params

Root cause:
- Destination settlement checks are applied at swap/remove-liquidity output level.
- Final transfer to end-user is not validated via recipient balance delta.
- For sender-tax payout tokens, user receives less than `minDy` / `swapMinAmount` while settlement reports success.

Concrete witness sequence:
1. Configure payout token behavior with 5% sender-side transfer tax when bridge contract sends.
2. Execute modeled destination settlement with `quotedOut=100_000`, `minOut=98_000`.
3. Pre-transfer checks pass; transfer succeeds.
4. Recipient receives `95_000` (< `98_000`), violating min-out guarantee on actual receipt.
5. Fixed control reverts when `actualReceived < minOut`.

Impact:
- User-facing min-out guarantees can be violated for affected token classes.
- Quote-to-execution safety assumptions can break under taxed/deflationary destination payout assets.

Recommended fix:
- Measure recipient pre/post balance delta and enforce min-out against actual recipient receipt.
- Alternatively block unsupported taxed payout token classes on destination settlement paths.
- Emit explicit `actualReceived` values in settlement events when practical.

Executable witness:
- Harness:
  - `proof_harness/cat1_synapse_f2_f3_role_minout`
- Tests:
  - `test_f3_bug_model_min_out_not_enforced_on_actual_user_receipt`
  - `test_f3_fixed_model_reverts_when_actual_received_below_min_out`
  - `testFuzz_f3_bug_model_can_underdeliver_vs_min_out`
- Artifacts:
  - `reports/cat1_bridges/synapse-contracts/manual_artifacts/f2_f3_role_and_minout_forge_test.txt`
  - `reports/cat1_bridges/synapse-contracts/manual_artifacts/f2_f3_role_and_minout_fuzz_5000_runs.txt`
  - `reports/cat1_bridges/synapse-contracts/manual_artifacts/f3_min_out_receipt_mismatch_formal_medusa_30s.txt`
  - `reports/cat1_bridges/synapse-contracts/manual_artifacts/f3_min_out_receipt_mismatch_formal_echidna_30s.txt`
  - `reports/cat1_bridges/synapse-contracts/manual_artifacts/f3_min_out_receipt_mismatch_formal_campaign_meta.json`

## Specialist Fuzzing (Medusa + Echidna)

Harnesses:
- `proof_harness/cat1_synapse_f1_deposit_fee_on_transfer/src/MedusaSynapseDepositFeeHarness.sol`
- `proof_harness/cat1_synapse_f2_f3_role_minout/src/MedusaSynapseRoleEscalationHarness.sol`
- `proof_harness/cat1_synapse_f2_f3_role_minout/src/MedusaSynapseMinOutHarness.sol`

Property results:
- Bug properties falsified:
  - `property_bug_collateral_covers_remote_liability`
  - `echidna_bug_collateral_covers_remote_liability`
  - `property_bug_admin_compromise_cannot_reduce_collateral`
  - `echidna_bug_admin_compromise_cannot_reduce_collateral`
  - `property_bug_swap_min_out_matches_actual_user_receipt`
  - `echidna_bug_swap_min_out_matches_actual_user_receipt`
- Fixed controls passed:
  - `property_fixed_collateral_covers_remote_liability`
  - `property_fixed_admin_compromise_cannot_reduce_collateral`
  - `property_fixed_swap_min_out_matches_actual_user_receipt`

## Hypotheses Status

- F1: validated and promoted (proven).
- F2: validated and promoted (proven).
- F3: validated and promoted (proven).
- No remaining high/medium hypotheses are open for this pass.

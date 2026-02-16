# connext-monorepo (Manual Audit, Step 2/5)

Scope: `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\connext-monorepo`

HEAD: `7758e62037bba281b8844c37831bde0b838edd36`

Pass status: In progress (F1/F2/F3 evidence-closed; one high-signal hypothesis still open).

Primary scope (this pass):
- `packages/deployments/contracts/contracts/core/connext/facets`
- `packages/deployments/contracts/contracts/core/connext/libraries`

Non-goals (this pass):
- Deployment scripts, agent orchestration, and non-EVM surfaces unless needed for a concrete on-chain witness.

## Protocol Snapshot (Router + Execute Accounting Paths)

- Router liquidity is supplied via:
  - `RoutersFacet.addRouterLiquidityFor(...)`
  - `RoutersFacet.addRouterLiquidity(...)`
- Router liquidity is withdrawn via:
  - `RoutersFacet.removeRouterLiquidityFor(...)`
  - `RoutersFacet.removeRouterLiquidity(...)`
- Destination execute path:
  - `BridgeFacet.execute(...)` delegates to `_handleExecuteLiquidity(...)` and `_handleExecuteTransaction(...)`.
  - Canonical-domain cap-tracked path decrements `s.tokenConfigs[_key].custodied` by intent amount (`toSwap`) in `_handleExecuteLiquidity(...)`.
  - Payout to recipient uses `AssetLogic.handleOutgoingAsset(...)`.
- Relayer fee bump path:
  - `BridgeFacet._bumpTransfer(...)` pulls ERC20 relayer fee in using `AssetLogic.handleIncomingAsset(...)`.
  - It then forwards relayer fee out via `AssetLogic.handleOutgoingAsset(...)`.
- Core transfer helpers:
  - `AssetLogic.handleIncomingAsset(...)` validates exact incoming amount and rejects fee-on-transfer behavior.
  - `AssetLogic.handleOutgoingAsset(...)` performs raw transfer out without sender-side debit validation.

## Critical Invariants

- Router collateral coverage:
  - For a given local asset, contract collateral should remain at least the sum of outstanding router balances for that asset.
- Withdrawal accounting correctness:
  - Router-balance decrement amount should match actual collateral debit caused by payout transfer.
- Canonical cap/custody accounting coverage:
  - For cap-tracked canonical assets, real collateral should not fall below tracked `custodied`.
- Relayer-fee neutrality:
  - ERC20 `bumpTransfer` fee forwarding should not consume pre-existing bridge collateral.

## Proven Findings

### F1: Router liquidity withdrawal can undercollateralize remaining router balances under sender-tax payout token behavior

Severity: Medium (token-specific solvency impact)

Affected code:
- `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\connext-monorepo\packages\deployments\contracts\contracts\core\connext\facets\RoutersFacet.sol`
  - `_addLiquidityForRouter(...)` (line ~550)
  - `_removeLiquidityForRouter(...)` (line ~592)
    - decrements `s.routerBalances[_router][local]` by `_amount` (line ~624)
    - then transfers out with `AssetLogic.handleOutgoingAsset(local, recipient, _amount)` (line ~628)
- `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\connext-monorepo\packages\deployments\contracts\contracts\core\connext\libraries\AssetLogic.sol`
  - `handleIncomingAsset(...)` validates exact in amount and rejects fee-on-transfer (line ~55)
  - `handleOutgoingAsset(...)` performs transfer without sender-side debit check (line ~85)

Root cause:
- Incoming liquidity path explicitly rejects fee-on-transfer behavior by checking balance delta.
- Outgoing withdrawal path assumes `transfer(_amount)` debits contract by exactly `_amount`.
- For sender-tax token classes where transfer debits sender by `amount + tax`, router liability decreases by `_amount` while collateral decreases by more.

Concrete witness sequence:
1. Add two routers with `100_000` local asset each (`totalRouterBalances = 200_000`).
2. Configure sender-tax behavior for transfers where Connext contract is sender (5% extra debit).
3. Remove router A liquidity by `100_000`.
4. Router balances drop to `100_000`, but contract collateral drops to `95_000`.
5. Post-state violates coverage invariant (`collateral < totalRouterBalances`).

Impact:
- Remaining router balances can become undercollateralized for affected token classes.
- This creates token-specific solvency/liveness risk for router withdrawals and settlement assumptions.

Recommended fix:
- Validate contract balance delta around outgoing transfer equals intended `_amount`; revert otherwise.
- Keep router-balance updates coupled to validated actual collateral debit.
- Optionally block unsupported sender-tax token classes for router-liquidity accounting paths.

Executable witness:
- Harness:
  - `proof_harness/cat1_connext_f1_router_sender_tax`
- Tests:
  - `test_f1_bug_model_sender_tax_withdraw_breaks_collateral_vs_router_balances`
  - `test_f1_fixed_model_rejects_sender_tax_withdrawal`
  - `testFuzz_f1_bug_model_sender_tax_can_break_collateral_invariant`
- Artifacts:
  - `reports/cat1_bridges/connext-monorepo/manual_artifacts/f1_router_sender_tax_forge_test.txt`
  - `reports/cat1_bridges/connext-monorepo/manual_artifacts/f1_router_sender_tax_fuzz_5000_runs.txt`
  - `reports/cat1_bridges/connext-monorepo/manual_artifacts/f1_router_sender_tax_formal_medusa_30s.txt`
  - `reports/cat1_bridges/connext-monorepo/manual_artifacts/f1_router_sender_tax_formal_echidna_30s.txt`
  - `reports/cat1_bridges/connext-monorepo/manual_artifacts/f1_router_sender_tax_formal_campaign_meta.json`

### F2: Canonical-domain execute payout can desynchronize `custodied` from real collateral under sender-tax token behavior

Severity: Medium (token-specific solvency/liveness + cap-accounting drift)

Affected code:
- `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\connext-monorepo\packages\deployments\contracts\contracts\core\connext\facets\BridgeFacet.sol`
  - `execute(...)` (line ~446)
  - `_handleExecuteLiquidity(...)` decrements `s.tokenConfigs[_key].custodied -= toSwap` on canonical cap-tracked path (line ~924)
  - `_handleExecuteTransaction(...)` transfers out via `AssetLogic.handleOutgoingAsset(...)` (line ~963)
- `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\connext-monorepo\packages\deployments\contracts\contracts\core\connext\libraries\AssetLogic.sol`
  - `handleOutgoingAsset(...)` performs transfer without sender-side debit validation (line ~85)

Root cause:
- Cap-tracked canonical execute path decrements `custodied` by intent amount (`toSwap`) before transfer out.
- Outgoing transfer path assumes sender debit equals requested amount.
- For sender-tax token behavior on Connext-originated transfers, actual sender debit can exceed requested amount.
- Result: real collateral can decrease faster than tracked `custodied`, violating coverage (`collateral < custodied`).

Concrete witness sequence:
1. Seed canonical custody with `200_000` (tracked `custodied = 200_000`).
2. Configure sender-tax behavior for transfers where Connext contract is sender (5% extra debit).
3. Execute payout of `100_000`.
4. `custodied` decreases to `100_000` by intent-level accounting.
5. Actual token balance decreases to `95_000` due sender-tax extra debit.
6. Post-state violates coverage invariant (`collateral < custodied`).

Impact:
- Cap-tracked accounting can overstate retrievable collateral for affected token classes.
- Subsequent destination payouts can fail earlier than accounting implies, creating token-specific liveness/solvency stress.
- Cap-related operational decisions can be made on drifted custody data.

Recommended fix:
- Validate sender-side balance delta around execute payout transfer equals intended amount.
- Couple `custodied` updates to validated actual debit, or revert on mismatch.
- Optionally block unsupported sender-tax token classes for cap-tracked canonical assets.

Executable witness:
- Harness:
  - `proof_harness/cat1_connext_f2_execute_custodied_sender_tax`
- Tests:
  - `test_f2_bug_model_sender_tax_execute_breaks_collateral_vs_custodied`
  - `test_f2_fixed_model_rejects_sender_tax_execute`
  - `testFuzz_f2_bug_model_sender_tax_can_break_collateral_vs_custodied`
- Artifacts:
  - `reports/cat1_bridges/connext-monorepo/manual_artifacts/f2_execute_custodied_sender_tax_forge_test.txt`
  - `reports/cat1_bridges/connext-monorepo/manual_artifacts/f2_execute_custodied_sender_tax_fuzz_5000_runs.txt`
  - `reports/cat1_bridges/connext-monorepo/manual_artifacts/f2_execute_custodied_sender_tax_formal_medusa_30s.txt`
  - `reports/cat1_bridges/connext-monorepo/manual_artifacts/f2_execute_custodied_sender_tax_formal_echidna_30s.txt`
  - `reports/cat1_bridges/connext-monorepo/manual_artifacts/f2_execute_custodied_sender_tax_formal_campaign_meta.json`

### F3: ERC20 `bumpTransfer` fee forwarding can consume bridge collateral under sender-tax payout token behavior

Severity: Medium (token-specific collateral drift / solvency pressure)

Affected code:
- `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\connext-monorepo\packages\deployments\contracts\contracts\core\connext\facets\BridgeFacet.sol`
  - `_bumpTransfer(...)` pulls fee in (`AssetLogic.handleIncomingAsset`) then forwards fee out (`AssetLogic.handleOutgoingAsset`) (line ~719+)
- `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\connext-monorepo\packages\deployments\contracts\contracts\core\connext\libraries\AssetLogic.sol`
  - `handleIncomingAsset(...)` enforces exact incoming amount (line ~55)
  - `handleOutgoingAsset(...)` performs transfer without sender-side debit validation (line ~85)

Root cause:
- ERC20 `bumpTransfer` path is modeled as value-neutral: pull `_relayerFee` from caller, then push `_relayerFee` to relayer vault.
- Incoming leg is exact-delta validated, but outgoing leg assumes sender debit equals transfer amount.
- For sender-tax token behavior on Connext-originated transfers, outgoing fee transfer can debit `amount + tax`.
- Net effect: each bump operation can consume pre-existing contract collateral by `tax`.

Concrete witness sequence:
1. Seed bridge with router liabilities: add `100_000` for router A and `100_000` for router B (`totalRouterBalances = 200_000`).
2. Configure sender-tax behavior for transfers where Connext contract is sender (5% extra debit).
3. Call ERC20 bump-fee path with `relayerFee = 100_000`.
4. Incoming leg credits exactly `100_000` into contract.
5. Outgoing fee transfer debits `105_000` from contract.
6. Post-state: collateral `195_000` while router liabilities remain `200_000`; invariant fails (`collateral < totalRouterBalances`).

Impact:
- Repeated bump-fee operations can drain bridge-side collateral for affected token classes.
- This can undercollateralize outstanding router liabilities and stress liquidity/settlement liveness.
- Drift is created on a path expected to be accounting-neutral.

Recommended fix:
- Validate sender-side balance delta for outgoing ERC20 relayer-fee transfers.
- Revert or block unsupported sender-tax token classes for relayer-fee assets.
- Consider asset compatibility constraints requiring predictable transfer debit semantics.

Executable witness:
- Harness:
  - `proof_harness/cat1_connext_f3_bump_transfer_sender_tax`
- Tests:
  - `test_f3_bug_model_sender_tax_bump_transfer_breaks_collateral_vs_router_balances`
  - `test_f3_fixed_model_rejects_sender_tax_bump_transfer`
  - `testFuzz_f3_bug_model_sender_tax_bump_transfer_can_break_collateral_invariant`
- Artifacts:
  - `reports/cat1_bridges/connext-monorepo/manual_artifacts/f3_bump_transfer_sender_tax_forge_test.txt`
  - `reports/cat1_bridges/connext-monorepo/manual_artifacts/f3_bump_transfer_sender_tax_fuzz_5000_runs.txt`
  - `reports/cat1_bridges/connext-monorepo/manual_artifacts/f3_bump_transfer_sender_tax_formal_medusa_30s.txt`
  - `reports/cat1_bridges/connext-monorepo/manual_artifacts/f3_bump_transfer_sender_tax_formal_echidna_30s.txt`
  - `reports/cat1_bridges/connext-monorepo/manual_artifacts/f3_bump_transfer_sender_tax_formal_campaign_meta.json`

## Specialist Fuzzing (Medusa + Echidna)

Harnesses:
- `proof_harness/cat1_connext_f1_router_sender_tax/src/MedusaConnextRouterSenderTaxHarness.sol`
- `proof_harness/cat1_connext_f2_execute_custodied_sender_tax/src/MedusaConnextExecuteCustodiedSenderTaxHarness.sol`
- `proof_harness/cat1_connext_f3_bump_transfer_sender_tax/src/MedusaConnextBumpTransferSenderTaxHarness.sol`

Property results:
- Bug properties falsified:
  - `property_bug_collateral_covers_router_balances`
  - `echidna_bug_collateral_covers_router_balances`
  - `property_bug_collateral_covers_custodied`
  - `echidna_bug_collateral_covers_custodied`
  - `property_bug_collateral_covers_router_balances_after_bump`
  - `echidna_bug_collateral_covers_router_balances_after_bump`
- Fixed controls passed:
  - `property_fixed_collateral_covers_router_balances`
  - `property_fixed_collateral_covers_custodied`
  - `property_fixed_collateral_covers_router_balances_after_bump`

## Hypotheses (Ranked Leads To Validate Next)

F1: Router liquidity withdrawal under sender-tax payout tokens
- Status: validated and promoted (proven).

F2: Execute/custodied accounting drift under sender-tax payout tokens
- Status: validated and promoted (proven).

F3: ERC20 `bumpTransfer` sender-tax collateral drift
- Status: validated and promoted (proven).

F4: Fast-liquidity execute path trust boundary before reconcile
- Observation: `BridgeFacet.execute(...)` documentation notes calldata properties may be unverified prior to reconcile completion.
- Question: can any externally meaningful state change occur in pre-reconcile windows that violates intended origin authenticity assumptions?
- Status: open.

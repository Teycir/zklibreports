# connext-monorepo (Manual Audit, Step 2/5)

Scope: `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\connext-monorepo`

HEAD: `7758e62037bba281b8844c37831bde0b838edd36`

Pass status: In progress (F1 evidence-closed; additional high-signal hypotheses pending).

Primary scope (this pass):
- `packages/deployments/contracts/contracts/core/connext/facets`
- `packages/deployments/contracts/contracts/core/connext/libraries`

Non-goals (this pass):
- Deployment scripts, agent orchestration, and non-EVM surfaces unless needed for a concrete on-chain witness.

## Protocol Snapshot (Router Liquidity Path)

- Router liquidity is supplied via:
  - `RoutersFacet.addRouterLiquidityFor(...)`
  - `RoutersFacet.addRouterLiquidity(...)`
- Router liquidity is withdrawn via:
  - `RoutersFacet.removeRouterLiquidityFor(...)`
  - `RoutersFacet.removeRouterLiquidity(...)`
- Core transfer helpers:
  - `AssetLogic.handleIncomingAsset(...)` validates exact incoming amount and rejects fee-on-transfer behavior.
  - `AssetLogic.handleOutgoingAsset(...)` performs raw transfer out without sender-side debit validation.

## Critical Invariants

- Router collateral coverage:
  - For a given local asset, contract collateral should remain at least the sum of outstanding router balances for that asset.
- Withdrawal accounting correctness:
  - Router-balance decrement amount should match actual collateral debit caused by payout transfer.

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

## Specialist Fuzzing (Medusa + Echidna)

Harness:
- `proof_harness/cat1_connext_f1_router_sender_tax/src/MedusaConnextRouterSenderTaxHarness.sol`

Property results:
- Bug property falsified:
  - `property_bug_collateral_covers_router_balances`
  - `echidna_bug_collateral_covers_router_balances`
- Fixed control passed:
  - `property_fixed_collateral_covers_router_balances`

## Hypotheses (Ranked Leads To Validate Next)

F2: Fast-liquidity execute path trust boundary before reconcile
- Observation: `BridgeFacet.execute(...)` documentation notes calldata properties may be unverified prior to reconcile completion.
- Question: can any externally meaningful state change occur in pre-reconcile windows that violates intended origin authenticity assumptions?
- Status: open.

F3: Router-liquidity and cap accounting interactions across mixed asset behaviors
- Observation: router balances, custodied accounting, and transfer helpers rely on behavior assumptions that differ between incoming and outgoing paths.
- Question: are there additional accounting-drift paths across cap enforcement, router withdrawal, and representation/canonical transitions?
- Status: open.

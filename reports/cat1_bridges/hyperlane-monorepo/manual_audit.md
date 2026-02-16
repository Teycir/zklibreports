# hyperlane-monorepo (Manual Audit, Step 2/5)

Scope: `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\hyperlane-monorepo`

HEAD: `5302a89c830c5eb43b8d3f53fc65e0733f4d6bd1`

Pass status: In progress (H1 evidence-closed with deterministic + fuzz + specialist-fuzzer witnesses; full-source parity replay pending).

Primary scope (this pass):
- Solidity messaging and token routing paths under `solidity/contracts`.

Non-goals (this pass):
- Rust relayer/validator agent runtime correctness, deployment scripts, and non-EVM protocol surfaces unless needed to prove an on-chain hypothesis.

## Protocol Snapshot (Solidity Path)

- Outbound transfer path:
  - `TokenRouter.transferRemote(...)` computes fee charge, pulls collateral via `_transferFromSender(charge)`, scales amount with `_outboundAmount(...)`, and dispatches token message (`solidity/contracts/token/libs/TokenRouter.sol`).
- Inbound transfer path:
  - `TokenRouter._handle(...)` decodes recipient + amount and transfers `_inboundAmount(amount)` to recipient (`solidity/contracts/token/libs/TokenRouter.sol`).
- Collateral implementation:
  - `HypERC20Collateral._transferFromSender(...)` delegates to `ERC20Collateral._transferFromSender(...)`, which uses `safeTransferFrom` without balance-delta accounting (`solidity/contracts/token/HypERC20Collateral.sol`, `solidity/contracts/token/libs/TokenCollateral.sol`).

## Critical Invariants

- Per-token collateral coverage:
  - Router-side collateral should not fall below remote-side liability implied by dispatched transfer amounts.
- Fee/slippage correctness:
  - Slippage checks must be enforced against actual collateral received, not intent-only transfer amount.

## Proven Findings

### H1: `HypERC20Collateral` + `TokenRouter` intent-level accounting can create collateral deficits with inbound-fee tokens

Severity: Medium (token-specific solvency impact)

Affected code:
- `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\hyperlane-monorepo\solidity\contracts\token\libs\TokenRouter.sol`
  - `transferRemote(...)`
  - `_calculateFeesAndCharge(...)`
  - `_outboundAmount(...)`
  - `_inboundAmount(...)`
  - `_handle(...)`
- `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\hyperlane-monorepo\solidity\contracts\token\HypERC20Collateral.sol`
  - `_transferFromSender(...)`
- `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\hyperlane-monorepo\solidity\contracts\token\libs\TokenCollateral.sol`
  - `ERC20Collateral._transferFromSender(...)`

Root cause:
- Message-credit amount is derived from caller intent (`_amount`) through `_outboundAmount`/`_inboundAmount`.
- ERC20 collateral pull uses `safeTransferFrom(msg.sender, address(this), _amount)` and does not measure actual received collateral when token transfer behavior is deflationary/taxed on inbound transfer.

Concrete witness sequence:
1. Configure inbound-fee token behavior (5% haircut when router is transfer target).
2. Call bug-model `transferRemote(100_000, 100_000)`.
3. Router collateral increases by `95_000`.
4. Remote liability is credited as `100_000`.
5. Post-state violates coverage invariant (`collateral < remoteLiability`).

Impact:
- Affected token classes can over-credit remote-side transfer liabilities relative to source-side collateral.
- This creates token-specific insolvency / redemption shortfall risk.

Recommended fix:
- Compute actual received collateral using pre/post balance delta.
- Base outbound credited amount (and slippage checks) on actual received collateral.
- Optionally deny-list or guard unsupported fee-on-transfer collateral tokens.

Executable witness:
- Harness:
  - `proof_harness/cat1_hyperlane_f1_collateral_fee_on_transfer`
- Tests:
  - `test_h1_bug_model_fee_on_transfer_breaks_collateral_invariant`
  - `test_h1_fixed_model_tracks_actual_received_and_rejects_overstrict_min`
  - `testFuzz_h1_bug_model_can_break_collateral_invariant`
- Artifacts:
  - `reports/cat1_bridges/hyperlane-monorepo/manual_artifacts/h1_collateral_fee_on_transfer_forge_test.txt`
  - `reports/cat1_bridges/hyperlane-monorepo/manual_artifacts/h1_collateral_fee_on_transfer_fuzz_5000_runs.txt`
  - `reports/cat1_bridges/hyperlane-monorepo/manual_artifacts/h1_collateral_fee_on_transfer_formal_medusa_30s.txt`
  - `reports/cat1_bridges/hyperlane-monorepo/manual_artifacts/h1_collateral_fee_on_transfer_formal_echidna_30s.txt`
  - `reports/cat1_bridges/hyperlane-monorepo/manual_artifacts/h1_collateral_fee_on_transfer_formal_campaign_meta.json`

## Specialist Fuzzing (Medusa + Echidna)

Harness:
- `proof_harness/cat1_hyperlane_f1_collateral_fee_on_transfer/src/MedusaHyperlaneCollateralFeeHarness.sol`

Property results:
- Bug property falsified:
  - `property_bug_collateral_covers_remote_liability`
  - `echidna_bug_collateral_covers_remote_liability`
- Fixed control passed:
  - `property_fixed_collateral_covers_remote_liability`

## Full-Source Parity Validation

Status: Pending.

Planned replay:
- Add parity harness that imports/copies upstream `TokenRouter`, `HypERC20Collateral`, and `TokenCollateral` paths and replays H1 on full-source contracts.

## Hypotheses (Ranked Leads To Validate Next)

H2: LP-share accounting under fee-on-transfer collateral
- Observation: `LpCollateralRouter._deposit` increments `lpAssets` by requested `assets` after `_transferFromSender(assets)` with no balance-delta correction.
- Question: can fee-on-transfer collateral overstate `totalAssets` and create share/accounting asymmetry across LPs?
- Status: open.

H3: Token-fee side effects during `_transferFee` / `_transferTo`
- Observation: fee payments reuse token transfer semantics; non-standard sender-side fee behavior may create additional accounting drift.
- Question: does fee transfer behavior create undercollateralization beyond H1 in practical router configurations?
- Status: open.

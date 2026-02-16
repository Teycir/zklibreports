# hyperlane-monorepo (Manual Audit, Step 2/5)

Scope: `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\hyperlane-monorepo`

HEAD: `5302a89c830c5eb43b8d3f53fc65e0733f4d6bd1`

Pass status: Exhausted for this pass (H1/H2/H3 evidence-closed with deterministic + fuzz + specialist-fuzzer witnesses; full-source parity replay backlog documented).

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

### H2: `LpCollateralRouter` can overstate `lpAssets` vs real collateral under inbound-fee collateral tokens

Severity: Medium (token-specific LP solvency/liveness impact)

Affected code:
- `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\hyperlane-monorepo\solidity\contracts\token\libs\LpCollateralRouter.sol`
  - `_deposit(...)`
  - `_withdraw(...)`
  - `donate(...)`
- `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\hyperlane-monorepo\solidity\contracts\token\HypERC20Collateral.sol`
  - `_transferFromSender(...)`
- `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\hyperlane-monorepo\solidity\contracts\token\libs\TokenCollateral.sol`
  - `ERC20Collateral._transferFromSender(...)`

Root cause:
- `_deposit` and `donate` add intent-level `assets/amount` to `lpAssets` after collateral pull.
- ERC20 collateral pull does not measure actual received amount for deflationary/taxed transfers.

Concrete witness sequence:
1. Configure inbound-fee token behavior (5% haircut when LP router is transfer target).
2. Deposit `100_000`.
3. Router receives `95_000` real collateral.
4. `lpAssets` increases by `100_000`.
5. Full withdraw/redeem of intent-level amount can revert due collateral shortfall.

Impact:
- LP accounting can report more assets than physically held collateral.
- Withdraw/redeem liveness can fail for affected token classes.
- Produces token-specific insolvency/shortfall behavior at LP accounting boundary.

Recommended fix:
- Track received collateral by pre/post balance delta in `_transferFromSender` call sites.
- Increase `lpAssets` by actual received amount, not requested amount.
- Explicitly disallow unsupported fee-on-transfer collateral classes where needed.

Executable witness:
- Harness:
  - `proof_harness/cat1_hyperlane_f1_collateral_fee_on_transfer`
- Tests:
  - `test_h2_bug_model_lp_assets_overstated_and_withdraw_reverts`
  - `test_h2_fixed_model_tracks_received_assets_and_withdraw_succeeds`
  - `testFuzz_h2_bug_model_lp_assets_can_exceed_collateral`
- Artifacts:
  - `reports/cat1_bridges/hyperlane-monorepo/manual_artifacts/h2_h3_lp_and_fee_forge_test.txt`
  - `reports/cat1_bridges/hyperlane-monorepo/manual_artifacts/h2_h3_lp_and_fee_fuzz_5000_runs.txt`
  - `reports/cat1_bridges/hyperlane-monorepo/manual_artifacts/h2_lp_assets_overstatement_formal_medusa_30s.txt`
  - `reports/cat1_bridges/hyperlane-monorepo/manual_artifacts/h2_lp_assets_overstatement_formal_echidna_30s.txt`
  - `reports/cat1_bridges/hyperlane-monorepo/manual_artifacts/h2_lp_assets_overstatement_formal_campaign_meta.json`

### H3: `TokenRouter` fee transfer path can undercollateralize router accounting with sender-tax token behavior

Severity: Medium (token-specific solvency impact)

Affected code:
- `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\hyperlane-monorepo\solidity\contracts\token\libs\TokenRouter.sol`
  - `_calculateFeesAndCharge(...)`
  - `_transferFee(...)`
  - `_transferTo(...)`
- `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\hyperlane-monorepo\solidity\contracts\token\HypERC20Collateral.sol`
  - `_transferTo(...)`
- `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\hyperlane-monorepo\solidity\contracts\token\libs\TokenCollateral.sol`
  - `ERC20Collateral._transferTo(...)`

Root cause:
- Router pulls `charge = amount + fee + externalFee` from sender by intent.
- Fee payment is executed as token transfer to fee recipient with no sender-side debit validation.
- For sender-tax behaviors on router-originated transfers, fee payment can debit more than `feeAmount`.
- Remote liability credit remains intent-level `amount`, so extra debit can create `collateral < liability`.

Concrete witness sequence:
1. Configure sender-tax behavior that charges extra debit when router is sender.
2. Execute `transferRemote`-equivalent path with `amount=100_000`, `fee=10_000`.
3. Router receives `110_000` at charge step.
4. Fee transfer debits `10_000 + extraTax`.
5. Router collateral falls below credited remote liability (`collateral < remoteLiability`).

Impact:
- Token-specific accounting deficit in routers using fee transfers with sender-tax token behavior.
- Can cause undercollateralization and future redemption shortfall behavior for affected token classes.

Recommended fix:
- Validate sender-side balance delta around fee transfer equals intended fee amount.
- Revert or block unsupported sender-tax behaviors in fee-payment path.
- Consider explicit token-class compatibility checks for collateral/fee tokens.

Executable witness:
- Harness:
  - `proof_harness/cat1_hyperlane_f1_collateral_fee_on_transfer`
- Tests:
  - `test_h3_bug_model_sender_tax_fee_transfer_breaks_collateral_invariant`
  - `test_h3_fixed_model_rejects_sender_tax_fee_transfer`
  - `testFuzz_h3_bug_model_sender_tax_fee_transfer_breaks_collateral`
- Artifacts:
  - `reports/cat1_bridges/hyperlane-monorepo/manual_artifacts/h2_h3_lp_and_fee_forge_test.txt`
  - `reports/cat1_bridges/hyperlane-monorepo/manual_artifacts/h2_h3_lp_and_fee_fuzz_5000_runs.txt`
  - `reports/cat1_bridges/hyperlane-monorepo/manual_artifacts/h3_fee_transfer_sender_tax_formal_medusa_30s.txt`
  - `reports/cat1_bridges/hyperlane-monorepo/manual_artifacts/h3_fee_transfer_sender_tax_formal_echidna_30s.txt`
  - `reports/cat1_bridges/hyperlane-monorepo/manual_artifacts/h3_fee_transfer_sender_tax_formal_campaign_meta.json`
  - `reports/cat1_bridges/hyperlane-monorepo/manual_artifacts/h3_fee_transfer_sender_tax_formal_echidna_30s_retry_workers1.txt`
  - `reports/cat1_bridges/hyperlane-monorepo/manual_artifacts/h3_fee_transfer_sender_tax_formal_retry_meta.json`

## Specialist Fuzzing (Medusa + Echidna)

Harness:
- `proof_harness/cat1_hyperlane_f1_collateral_fee_on_transfer/src/MedusaHyperlaneCollateralFeeHarness.sol`
- `proof_harness/cat1_hyperlane_f1_collateral_fee_on_transfer/src/MedusaHyperlaneLpAssetsHarness.sol`
- `proof_harness/cat1_hyperlane_f1_collateral_fee_on_transfer/src/MedusaHyperlaneFeeTransferHarness.sol`

Property results:
- Bug property falsified:
  - `property_bug_collateral_covers_remote_liability`
  - `echidna_bug_collateral_covers_remote_liability`
  - `property_bug_collateral_covers_lp_assets`
  - `echidna_bug_collateral_covers_lp_assets`
- Fixed control passed:
  - `property_fixed_collateral_covers_remote_liability`
  - `property_fixed_collateral_covers_lp_assets`

H3 Echidna note:
- Standardized campaign output file captured an Echidna runtime crash message on this host for one run.
- Retry in single-worker mode produced a valid falsification witness:
  - `h3_fee_transfer_sender_tax_formal_echidna_30s_retry_workers1.txt`

## Full-Source Parity Validation

Status: Pending (not required to classify H1/H2/H3 model-level findings as proven for this pass).

Planned replay:
- Add parity harness that imports/copies upstream `TokenRouter`, `HypERC20Collateral`, `LpCollateralRouter`, and `TokenCollateral` paths and replays H1/H2/H3 on full-source contracts.

## Hypotheses Status

- H1: validated and promoted (proven).
- H2: validated and promoted (proven).
- H3: validated and promoted (proven).
- No remaining high/medium hypotheses are open for this pass.

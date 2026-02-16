# LayerZero-v2 (Manual Audit, Step 2/5)

Scope: `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\LayerZero-v2`

HEAD: `ab9b083410b9359285a5756807e1b6145d4711a7`

Pass status: In progress (top three high-signal hypotheses evidence-closed; full-source parity `H1/H2/H3` validated).

Primary scope (this pass):
- EVM OFT/OApp and Endpoint delegate-control surfaces.

Non-goals (this pass):
- Full Solana/Aptos/Sui/TON codepaths, deployment scripts, and off-chain executors/relayers.

## Protocol Snapshot (EVM)

- OFT value flow:
  - Outbound `send(...)` in `evm/oapp/contracts/oft/OFTCore.sol` calls `_debit(...)`, then emits/sends a message carrying `amountReceivedLD`.
  - Adapter implementation `evm/oapp/contracts/oft/OFTAdapter.sol` locks tokens via `safeTransferFrom` and assumes lossless transfer semantics.
- Endpoint auth/config:
  - `evm/protocol/contracts/EndpointV2.sol` stores per-OApp delegate mapping and accepts config mutations when caller is OApp or delegate.
  - `evm/oapp/contracts/oapp/OAppCore.sol` sets delegate in constructor and via explicit `setDelegate`.

## Critical Invariants

- OFT collateral accounting:
  - Adapter-side locked collateral should not fall below remote credited liability for bridged amounts.
- Admin boundary:
  - After ownership transfer, prior owner/delegate should not retain endpoint config authority unless explicitly intended.
- Fee attribution boundary:
  - `payInLzToken` refunds should only return caller-supplied excess, not pre-existing endpoint residual balances.

## Proven Findings

### LZ1: OFTAdapter lossless-transfer assumption can create collateral deficit with inbound-fee tokens

Severity: Medium (token-specific, but direct solvency-impact on affected OFT deployments)

Affected code:
- `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\LayerZero-v2\packages\layerzero-v2\evm\oapp\contracts\oft\OFTAdapter.sol`
  - `_debit(...)`
- `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\LayerZero-v2\packages\layerzero-v2\evm\oapp\contracts\oft\OFTCore.sol`
  - `send(...)`
  - `_debitView(...)`

Root cause:
- Adapter debit logic assumes `amountSent == amountReceived` by intent, without measuring actual token amount received when `transferFrom` is fee/taxed.

Concrete witness sequence:
1. Configure inbound-fee token (5%) for adapter lock step.
2. Call adapter send for `100_000` units with strict min of `100_000`.
3. Adapter accepts and records remote liability of `100_000`.
4. Actual adapter collateral increases by only `95_000`.
5. Post-state violates `collateral >= remote_liability`.

Impact:
- For non-lossless tokens, OFT mesh accounting can over-credit remote side versus locked source collateral.
- This can produce token-specific insolvency / redemption shortfall behavior.

Recommended fix:
- Measure pre/post adapter token balance and derive `amountReceivedLD` from actual delta.
- Enforce slippage on actual received amount.
- Keep default adapter restricted to explicitly lossless token classes where possible.

Executable witness:
- Harness:
  - `proof_harness/cat1_layerzero_v2_f1_oft_delegate`
- Tests:
  - `test_lz1_bug_model_fee_on_transfer_breaks_collateral_invariant`
  - `test_lz1_fixed_model_tracks_actual_received_and_rejects_overstrict_min`
  - `testFuzz_lz1_bug_model_can_break_collateral_invariant`
- Artifacts:
  - `reports/cat1_bridges/LayerZero-v2/manual_artifacts/lz1_lz2_forge_test.txt`
  - `reports/cat1_bridges/LayerZero-v2/manual_artifacts/lz1_lz2_fuzz_5000_runs.txt`
  - `reports/cat1_bridges/LayerZero-v2/manual_artifacts/lz1_oft_lossless_formal_medusa_30s.txt`
  - `reports/cat1_bridges/LayerZero-v2/manual_artifacts/lz1_oft_lossless_formal_echidna_30s.txt`
  - `reports/cat1_bridges/LayerZero-v2/manual_artifacts/lz1_oft_lossless_formal_campaign_meta.json`

### LZ2: Endpoint delegate privilege can persist after OApp ownership transfer and retain config control

Severity: High (control-plane DoS/reconfiguration risk if stale delegate key is compromised or not rotated)

Affected code:
- `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\LayerZero-v2\packages\layerzero-v2\evm\protocol\contracts\EndpointV2.sol`
  - `setDelegate(...)`
  - `_assertAuthorized(...)`
- `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\LayerZero-v2\packages\layerzero-v2\evm\oapp\contracts\oapp\OAppCore.sol`
  - constructor delegate setup
  - `setDelegate(...)`

Root cause:
- Delegate auth is endpoint-side and independent from OApp ownership transitions; ownership transfer does not automatically rotate/revoke endpoint delegate.

Concrete witness sequence:
1. OApp is initialized with delegate `D` (same actor as initial owner).
2. Ownership is transferred to `N`.
3. Old delegate `D` still satisfies endpoint auth for that OApp.
4. `D` updates send-library configuration to blocked library for an endpoint id.

Impact:
- Stale key can keep mutating endpoint config after intended ownership handoff.
- Can force message-path DoS or undesired library changes until delegate is explicitly rotated.

Recommended fix:
- Operational requirement: rotate delegate atomically during ownership transfer.
- Implementation hardening: owner-transfer flow that auto-rotates delegate (or explicit transfer-step guard that requires delegate update).

Executable witness:
- Harness:
  - `proof_harness/cat1_layerzero_v2_f1_oft_delegate`
- Tests:
  - `test_lz2_bug_model_stale_delegate_can_reconfigure_after_transfer`
  - `test_lz2_fixed_model_blocks_stale_delegate_after_transfer`
  - `testFuzz_lz2_bug_model_stale_delegate_persists`
- Artifacts:
  - `reports/cat1_bridges/LayerZero-v2/manual_artifacts/lz1_lz2_forge_test.txt`
  - `reports/cat1_bridges/LayerZero-v2/manual_artifacts/lz1_lz2_fuzz_5000_runs.txt`
  - `reports/cat1_bridges/LayerZero-v2/manual_artifacts/lz2_stale_delegate_formal_medusa_30s.txt`
  - `reports/cat1_bridges/LayerZero-v2/manual_artifacts/lz2_stale_delegate_formal_echidna_30s.txt`
  - `reports/cat1_bridges/LayerZero-v2/manual_artifacts/lz2_stale_delegate_formal_campaign_meta.json`

### LZ3: Endpoint `payInLzToken` path can sweep preloaded residual `lzToken` balance to caller-selected refund address

Severity: Medium (requires nonzero endpoint residual, but causes direct token loss of that residual once present)

Affected code:
- `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\LayerZero-v2\packages\layerzero-v2\evm\protocol\contracts\EndpointV2.sol`
  - `send(...)`
  - `_suppliedLzToken(...)`
  - `_payToken(...)`

Root cause:
- `send(...)` computes supplied token fee via `_suppliedLzToken(payInLzToken)`.
- `_suppliedLzToken(...)` returns full `IERC20(lzToken).balanceOf(address(this))` (total endpoint balance), not per-call payer contribution.
- `_payToken(...)` then refunds `_supplied - _required` to caller-controlled `_refundAddress`.
- Result: residual endpoint balance is treated as caller-supplied and can be routed out by arbitrary sender.

Concrete witness sequence:
1. Configure endpoint `lzToken` and send library with nonzero `lzToken` fee.
2. Preload endpoint with residual `1_000` `lzToken`.
3. Arbitrary caller invokes `send(payInLzToken=true, refundAddress=attacker)` with no additional `lzToken` transfer.
4. Endpoint computes supplied fee from existing residual balance.
5. Endpoint pays required fee (`99`) to send library and refunds remaining residual (`901`) to attacker address.

Impact:
- Any stranded/preloaded endpoint `lzToken` becomes permissionlessly sweepable by arbitrary send caller.
- Converts operational residual balances into publicly extractable value.

Recommended fix:
- Attribute supplied fee using per-call balance deltas (or explicit transfer-in inside `send` path), not total endpoint balance.
- Refund only caller-contributed excess above required fee.
- Optionally gate unexpected residual handling to privileged recovery flow.

Executable witness:
- Harnesses:
  - `proof_harness/cat1_layerzero_v2_f1_oft_delegate`
  - `proof_harness/cat1_layerzero_v2_parity_fullsource`
- Tests:
  - `test_lz3_bug_model_residual_lztoken_can_be_swept`
  - `test_lz3_fixed_model_preserves_preloaded_residual`
  - `testFuzz_lz3_bug_model_sweeps_preloaded_residual`
  - `test_h3_full_source_endpoint_lztoken_residual_sweep`
- Artifacts:
  - `reports/cat1_bridges/LayerZero-v2/manual_artifacts/lz3_residual_sweep_forge_test.txt`
  - `reports/cat1_bridges/LayerZero-v2/manual_artifacts/lz3_residual_sweep_fuzz_5000_runs.txt`
  - `reports/cat1_bridges/LayerZero-v2/manual_artifacts/lz3_residual_sweep_formal_medusa_30s.txt`
  - `reports/cat1_bridges/LayerZero-v2/manual_artifacts/lz3_residual_sweep_formal_echidna_30s.txt`
  - `reports/cat1_bridges/LayerZero-v2/manual_artifacts/lz3_residual_sweep_formal_campaign_meta.json`
  - `reports/cat1_bridges/LayerZero-v2/manual_artifacts/h3_fullsource_lztoken_residual_sweep_forge_test.txt`

## Specialist Fuzzing (Medusa + Echidna)

LZ1 harness:
- `proof_harness/cat1_layerzero_v2_f1_oft_delegate/src/MedusaLz1OFTAdapterHarness.sol`
- Bug property falsified:
  - `property_bug_collateral_covers_remote_liability`
- Fixed control passed:
  - `property_fixed_collateral_covers_remote_liability`

LZ2 harness:
- `proof_harness/cat1_layerzero_v2_f1_oft_delegate/src/MedusaLz2DelegateHarness.sol`
- Bug property falsified:
  - `property_stale_delegate_cannot_reconfigure_bug_model`
- Fixed control passed:
  - `property_stale_delegate_cannot_reconfigure_fixed_model`

LZ3 harness:
- `proof_harness/cat1_layerzero_v2_f1_oft_delegate/src/MedusaLz3ResidualSweepHarness.sol`
- Bug property falsified:
  - `property_bug_residual_cannot_be_swept`
- Fixed control passed:
  - `property_fixed_residual_cannot_be_swept`

## Full-Source Parity Validation

Harness:
- `proof_harness/cat1_layerzero_v2_parity_fullsource`
- Uses copied upstream source trees:
  - `evm/oapp/contracts`
  - `evm/protocol/contracts`
- Dependency pins:
  - `openzeppelin-contracts v4.8.1`
  - `solidity-bytes-utils v0.8.0`

H1 parity replay (`OFTAdapter` inbound-fee collateral collapse):
- Test:
  - `test_h1_full_source_parity_oft_adapter_inbound_fee_collapse`
- Result:
  - upstream `OFTAdapter` debit path returns intent-level `(amountSentLD, amountReceivedLD)` while actual adapter collateral receives less under inbound-fee token behavior.
- Artifact:
  - `reports/cat1_bridges/LayerZero-v2/manual_artifacts/h1_fullsource_parity_oft_adapter_forge_test.txt`

H2 parity replay (`EndpointV2` delegate persistence after ownership transfer):
- Test:
  - `test_h2_full_source_parity_stale_delegate_persists_post_transfer`
- Result:
  - stale delegate remains authorized to mutate endpoint send-library config after OApp ownership transfer until delegate is explicitly rotated.
- Artifact:
  - `reports/cat1_bridges/LayerZero-v2/manual_artifacts/h2_fullsource_parity_delegate_stale_forge_test.txt`

H3 parity replay (`EndpointV2` `payInLzToken` residual sweep):
- Test:
  - `test_h3_full_source_endpoint_lztoken_residual_sweep`
- Result:
  - preloaded endpoint `lzToken` residual is counted as supplied fee, enabling refund of residual minus required fee to attacker-selected refund address.
- Artifact:
  - `reports/cat1_bridges/LayerZero-v2/manual_artifacts/h3_fullsource_lztoken_residual_sweep_forge_test.txt`

## Hypotheses (Next Validation Targets)

H1: Full-source parity replay for LZ1 against copied `OFTAdapter` stack
- Goal: replay inbound-fee sequence directly against upstream OFT code and compare behavior/gas with model witness.
- Status: validated.

H2: Full-source parity replay for LZ2 delegate-persistence path
- Goal: replay stale-delegate authorization sequence against upstream `EndpointV2` + `OAppCore`-derived contract flow.
- Status: validated.

H3: Endpoint LZ-token residual-balance sweep path
- Goal: validate whether preloaded residual `lzToken` balance can be opportunistically consumed/refunded by third parties via `send(payInLzToken=true)` under real message-lib settings.
- Status: validated.

## Next Actions (Immediate)

1. Start next ranked high/medium hypothesis on Endpoint/OApp config safety after parity closure.
2. Extend parity checks to alternate endpoint variants (`EndpointV2Alt`) and fee-token operational edge cases.

# wormhole (Manual Audit, Step 2/5)

Scope: `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\wormhole`

Pass status: Exhausted for this pass (all high/medium hypotheses evidence-closed).

Primary scope (this pass): EVM core + EVM token bridge (Solidity under `wormhole/ethereum/contracts`).

Non-goals (this pass): Solana/Move/CosmWasm/Near/Sui/Aptos implementations, guardian node, relayer, SDK correctness. Those get pulled in only when needed to validate an on-chain hypothesis.

## Protocol Snapshot (EVM)

Core messaging:
- Users/contracts call `publishMessage` on the core implementation.
- Core emits `LogMessagePublished` (see `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\wormhole\ethereum\contracts\Implementation.sol`).
- Guardians observe events, sign a VAA (VM) over the message body.
- On-chain consumers validate a VAA via `parseAndVerifyVM` / `verifyVM` (see `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\wormhole\ethereum\contracts\Messages.sol`).

Token bridge:
- Source chain locks/burns tokens, publishes a transfer payload.
- Target chain verifies VAA, checks emitter is a registered bridge contract for that source chain, then mints/unlocks (see `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\wormhole\ethereum\contracts\bridge\Bridge.sol`).

Upgrade model:
- Core and TokenBridge are `ERC1967Proxy` proxies (see `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\wormhole\ethereum\contracts\Wormhole.sol`, `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\wormhole\ethereum\contracts\bridge\TokenBridge.sol`).
- Upgrades are triggered by governance VAAs (core: `submitContractUpgrade` in `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\wormhole\ethereum\contracts\Governance.sol`, token bridge: `upgrade` in `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\wormhole\ethereum\contracts\bridge\BridgeGovernance.sol`).
- â€œShutdownâ€ implementations exist as emergency drop-in upgrades that disable non-governance functionality (see `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\wormhole\ethereum\contracts\Shutdown.sol`, `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\wormhole\ethereum\contracts\bridge\BridgeShutdown.sol`).

## Trust Assumptions (As Implemented / Documented)

From `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\wormhole\SECURITY.md`:
- Any 2/3+ of guardians can pass messages and governance (incl upgrades and guardian set updates).
- Any 1/3+ can censor by not signing / not observing.

Implementation-specific:
- Governance VAAs must originate from a specific governance chain + governance emitter address (core checks in `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\wormhole\ethereum\contracts\Governance.sol`, token bridge checks in `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\wormhole\ethereum\contracts\bridge\BridgeGovernance.sol`).
- Token bridge accepts transfer VAAs only from per-chain registered bridge emitters (see `verifyBridgeVM` in `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\wormhole\ethereum\contracts\bridge\Bridge.sol`).

## Critical Invariants To Preserve

Core:
- VAA signature verification is bound to the message body (hash-body check) and guardian set quorum rules.
- Governance VAAs are single-use (consumed hash) and restricted to governance emitter (chainId + contract).
- Upgrades canâ€™t be replayed (consumed hash), and the new implementation is initialized exactly once per implementation address (see `_state.initializedImplementations` in `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\wormhole\ethereum\contracts\State.sol`).

Token bridge:
- A transfer VAA can be redeemed at most once on a chain (`completedTransfers[vm.hash]` in `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\wormhole\ethereum\contracts\bridge\BridgeState.sol`).
- Redemption must be for the current chain (`transfer.toChain == chainId()` in `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\wormhole\ethereum\contracts\bridge\Bridge.sol`).
- Redemption must be from an expected emitter for the source chain (`bridgeContracts(vm.emitterChainId) == vm.emitterAddress` in `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\wormhole\ethereum\contracts\bridge\Bridge.sol`).
- â€œTransfer with payloadâ€ can only be redeemed by the intended recipient (`payloadID == 3` sender check in `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\wormhole\ethereum\contracts\bridge\Bridge.sol`).

## Manual Review Targets (This Pass)

Core VAA parsing + signature checks:
- `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\wormhole\ethereum\contracts\Messages.sol`

Core governance acceptance + upgrades:
- `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\wormhole\ethereum\contracts\Governance.sol`
- `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\wormhole\ethereum\contracts\Setup.sol`
- `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\wormhole\ethereum\contracts\Implementation.sol`

Token bridge redemption/mint/unlock:
- `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\wormhole\ethereum\contracts\bridge\Bridge.sol`
- `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\wormhole\ethereum\contracts\bridge\BridgeGovernance.sol`
- `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\wormhole\ethereum\contracts\bridge\token\TokenImplementation.sol`

## Entry Points Map (EVM)

Core proxy + setup:
- Proxy wrapper: `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\wormhole\ethereum\contracts\Wormhole.sol`
- Initial setup: `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\wormhole\ethereum\contracts\Setup.sol`

Core user entry points:
- `publishMessage(uint32,bytes,uint8)` (fee-gated) in `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\wormhole\ethereum\contracts\Implementation.sol`
- VAA parsing/verification helpers are callable by anyone and are used by downstream protocols:
  - `parseVM(bytes)` / `verifyVM(VM)` / `parseAndVerifyVM(bytes)` in `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\wormhole\ethereum\contracts\Messages.sol`

Core governance entry points (VAA-gated):
- `submitContractUpgrade(bytes)` in `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\wormhole\ethereum\contracts\Governance.sol`
- `submitNewGuardianSet(bytes)` in `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\wormhole\ethereum\contracts\Governance.sol`
- `submitSetMessageFee(bytes)` in `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\wormhole\ethereum\contracts\Governance.sol`
- `submitTransferFees(bytes)` in `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\wormhole\ethereum\contracts\Governance.sol`
- `submitRecoverChainId(bytes)` (fork-only) in `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\wormhole\ethereum\contracts\Governance.sol`

Token bridge proxy + setup:
- Proxy wrapper: `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\wormhole\ethereum\contracts\bridge\TokenBridge.sol`
- Initial setup: `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\wormhole\ethereum\contracts\bridge\BridgeSetup.sol`

Token bridge user entry points:
- Outbound:
  - `transferTokens(...)` / `transferTokensWithPayload(...)` in `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\wormhole\ethereum\contracts\bridge\Bridge.sol`
  - `wrapAndTransferETH(...)` / `wrapAndTransferETHWithPayload(...)` in `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\wormhole\ethereum\contracts\bridge\Bridge.sol`
  - `attestToken(...)` in `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\wormhole\ethereum\contracts\bridge\Bridge.sol`
- Inbound:
  - `completeTransfer(...)` / `completeTransferAndUnwrapETH(...)` in `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\wormhole\ethereum\contracts\bridge\Bridge.sol`
  - `completeTransferWithPayload(...)` / `completeTransferAndUnwrapETHWithPayload(...)` in `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\wormhole\ethereum\contracts\bridge\Bridge.sol`
- Wrapped asset management:
  - `createWrapped(bytes)` / `updateWrapped(bytes)` in `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\wormhole\ethereum\contracts\bridge\Bridge.sol`

Token bridge governance entry points (VAA-gated):
- `registerChain(bytes)` in `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\wormhole\ethereum\contracts\bridge\BridgeGovernance.sol`
- `upgrade(bytes)` in `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\wormhole\ethereum\contracts\bridge\BridgeGovernance.sol`
- `submitRecoverChainId(bytes)` (fork-only) in `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\wormhole\ethereum\contracts\bridge\BridgeGovernance.sol`

## Proven Findings

### W1: Metadata-method assumptions in `attestToken` / `_transferTokens` cause deterministic token-specific DoS

Severity: Low

Affected code:
- `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\wormhole\ethereum\contracts\bridge\Bridge.sol`
  - `attestToken(...)`
  - `_transferTokens(...)`

Root cause:
- Metadata reads use low-level `staticcall`, but return data is decoded without checking call success/length.
- Tokens omitting `decimals()`, `symbol()`, or `name()` return empty data, causing `abi.decode` reverts.

Concrete witness sequence:
1. Call attestation path with a token that omits metadata methods.
2. `staticcall` fails/returns empty bytes.
3. `abi.decode` reverts, blocking attestation.
4. Same metadata assumption in transfer path blocks bridging for the same token class.

Impact:
- Affected tokens cannot be attested/bridged via this bridge path.
- Impact is token-specific DoS (no cross-token theft), but behavior contradicts the in-code support claim.

Recommended fix:
- Check `staticcall` success and return length before decode.
- Use explicit defaults or explicit `unsupported token metadata` revert messages.
- Align comments/docs with actual enforced behavior.

Executable witness:
- Harness:
  - `proof_harness/cat1_wormhole_f1_metadata_dos/src/BridgeMetadataCompatHarness.sol`
- Tests:
  - `proof_harness/cat1_wormhole_f1_metadata_dos/test/BridgeMetadataCompat.t.sol`
- Run:
  - `forge test -vv --match-path test/BridgeMetadataCompat.t.sol`
  - `forge test -vv --match-path test/BridgeMetadataCompat.t.sol --fuzz-runs 5000`
- Output artifacts:
  - `reports/cat1_bridges/wormhole/manual_artifacts/w1_metadata_dos_forge_test.txt`
  - `reports/cat1_bridges/wormhole/manual_artifacts/w1_metadata_dos_fuzz_5000_runs.txt`

Specialist fuzz witnesses:
- Medusa harness:
  - `proof_harness/cat1_wormhole_f1_metadata_dos/src/MedusaBridgeMetadataCompatHarness.sol`
  - `property_nonstandard_token_attest_should_not_fail`
  - `property_nonstandard_token_transfer_should_not_fail`
  - `property_fixed_model_tolerates_missing_metadata`
- Standardized campaign:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/evm_specialist_campaign.ps1 -HarnessDir proof_harness/cat1_wormhole_f1_metadata_dos -HarnessContract MedusaBridgeMetadataCompatHarness -HarnessSource src/MedusaBridgeMetadataCompatHarness.sol -ArtifactDir reports/cat1_bridges/wormhole/manual_artifacts -ArtifactPrefix w1_metadata_dos_formal -TimeoutSec 30 -EchidnaCorpusDir echidna-corpus-w1-formal`
- Output artifacts:
  - `reports/cat1_bridges/wormhole/manual_artifacts/w1_metadata_dos_formal_medusa_30s.txt`
  - `reports/cat1_bridges/wormhole/manual_artifacts/w1_metadata_dos_formal_echidna_30s.txt`
  - `reports/cat1_bridges/wormhole/manual_artifacts/w1_metadata_dos_formal_campaign_meta.json`

### W2: Token-bridge governance accepts stale guardian sets during expiry window

Severity: High

Affected code:
- `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\wormhole\ethereum\contracts\bridge\BridgeGovernance.sol`
  - `verifyGovernanceVM(bytes)`
- `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\wormhole\ethereum\contracts\Messages.sol`
  - `verifyVMInternal(Structs.VM,bool)`
- `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\wormhole\ethereum\contracts\Governance.sol`
  - `verifyGovernanceVM(Structs.VM)` (control path showing intended current-set requirement)

Root cause:
- Bridge governance relies on `wormhole().parseAndVerifyVM(...)` and checks governance emitter identity/consumption, but does not enforce `vm.guardianSetIndex == getCurrentGuardianSetIndex()`.
- Core governance adds this current-set check explicitly; bridge governance does not.
- Because Wormhole VM verification allows non-current guardian sets until expiry, bridge governance accepts stale-but-unexpired signer sets.

Concrete witness sequence:
1. Configure guardian set `N-1` as stale but not expired, and set current guardian set to `N`.
2. Construct a governance VM signed by stale set `N-1` from the correct governance emitter chain/address.
3. Execute bridge-governance upgrade path.
4. VM passes Wormhole verification (stale set still in expiry window).
5. Bridge governance action succeeds despite stale signer set.
6. Equivalent core governance path rejects the same VM because current-set enforcement is present.

Impact:
- If stale guardian keys are compromised during the expiry window (default 24h), attacker-signed governance VAAs can be accepted by token bridge governance.
- This can authorize high-impact governance actions (for example bridge upgrade), creating a temporary stale-signer takeover window not present in core governance checks.

Recommended fix:
- In `BridgeGovernance.verifyGovernanceVM`, enforce `vm.guardianSetIndex == getCurrentGuardianSetIndex()` before accepting governance actions.
- Keep stale-set acceptance for non-governance message flows only; governance should remain current-set strict.

Executable witness:
- Harness:
  - `proof_harness/cat1_wormhole_f2_stale_guardian_governance/src/StaleGuardianGovernanceHarness.sol`
- Tests:
  - `proof_harness/cat1_wormhole_f2_stale_guardian_governance/test/StaleGuardianGovernance.t.sol`
- Run:
  - `forge test -vv --match-path test/StaleGuardianGovernance.t.sol`
  - `forge test -vv --match-path test/StaleGuardianGovernance.t.sol --fuzz-runs 5000`
- Output artifacts:
  - `reports/cat1_bridges/wormhole/manual_artifacts/w2_stale_guardian_governance_forge_test.txt`
  - `reports/cat1_bridges/wormhole/manual_artifacts/w2_stale_guardian_governance_fuzz_5000_runs.txt`

Specialist fuzz witnesses:
- Medusa harness:
  - `proof_harness/cat1_wormhole_f2_stale_guardian_governance/src/MedusaStaleGuardianGovernanceHarness.sol`
  - `property_stale_set_must_not_authorize_bridge_governance`
  - `property_core_rejects_stale_guardian_set`
  - `property_fixed_bridge_rejects_stale_guardian_set`
- Standardized campaign:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/evm_specialist_campaign.ps1 -HarnessDir proof_harness/cat1_wormhole_f2_stale_guardian_governance -HarnessContract MedusaStaleGuardianGovernanceHarness -HarnessSource src/MedusaStaleGuardianGovernanceHarness.sol -ArtifactDir reports/cat1_bridges/wormhole/manual_artifacts -ArtifactPrefix w2_stale_guardian_governance_formal -TimeoutSec 30 -EchidnaCorpusDir echidna-corpus-w2-formal`
- Output artifacts:
  - `reports/cat1_bridges/wormhole/manual_artifacts/w2_stale_guardian_governance_formal_medusa_30s.txt`
  - `reports/cat1_bridges/wormhole/manual_artifacts/w2_stale_guardian_governance_formal_echidna_30s.txt`
  - `reports/cat1_bridges/wormhole/manual_artifacts/w2_stale_guardian_governance_formal_campaign_meta.json`

### W3: Outbound sender-tax tokens can break bridge token solvency accounting

Severity: Medium (token-specific)

Affected code:
- `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\wormhole\ethereum\contracts\bridge\Bridge.sol`
  - `_completeTransfer(...)` native-token branch (`SafeERC20.safeTransfer(...)` path)
  - `_transferTokens(...)` native-token inbound amount correction (inbound handled, outbound debit not validated)

Root cause:
- Inbound native-token deposits correct for transfer behavior via balance delta.
- Outbound native-token redemption assumes `transfer(amount)` debits bridge balance by exactly `amount` and decrements `outstanding` by `amount` before the transfer.
- For sender-tax tokens that debit sender by `amount + fee`, bridge collateral can drop faster than `outstanding`, creating `collateral < outstanding`.

Concrete witness sequence:
1. Seed bridge collateral/outstanding for a token via inbound path.
2. Redeem an outbound transfer for the same token.
3. Token applies sender-tax only when bridge is sender, debiting bridge by more than redeemed amount.
4. Bridge reduces `outstanding` only by redeemed amount.
5. Post-transfer state violates collateral coverage (`collateral < outstanding`), causing token-specific insolvency / future redemption failures.

Impact:
- For affected token classes, redemption can drive bridge accounting insolvent for that token.
- Result is token-specific fund shortfall/stuck redemption risk (not cross-token theft), but still a concrete bridge-side accounting break for listed token behavior.

Recommended fix:
- Validate sender-side debit in outbound path (balance delta around `safeTransfer`) and reject unexpected over-debit behavior.
- Alternatively, explicitly disallow/list-block sender-tax token behaviors that violate collateral coverage assumptions.

Executable witness:
- Harness:
  - `proof_harness/cat1_wormhole_f3_outbound_sender_tax_insolvency/src/OutboundSenderTaxHarness.sol`
- Tests:
  - `proof_harness/cat1_wormhole_f3_outbound_sender_tax_insolvency/test/OutboundSenderTax.t.sol`
- Run:
  - `forge test -vv --match-path test/OutboundSenderTax.t.sol`
  - `forge test -vv --match-path test/OutboundSenderTax.t.sol --fuzz-runs 5000`
- Output artifacts:
  - `reports/cat1_bridges/wormhole/manual_artifacts/w3_outbound_sender_tax_forge_test.txt`
  - `reports/cat1_bridges/wormhole/manual_artifacts/w3_outbound_sender_tax_fuzz_5000_runs.txt`

Specialist fuzz witnesses:
- Medusa harness:
  - `proof_harness/cat1_wormhole_f3_outbound_sender_tax_insolvency/src/MedusaOutboundSenderTaxHarness.sol`
  - `property_bug_collateral_covers_outstanding`
  - `property_fixed_collateral_covers_outstanding`
- Standardized campaign:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/evm_specialist_campaign.ps1 -HarnessDir proof_harness/cat1_wormhole_f3_outbound_sender_tax_insolvency -HarnessContract MedusaOutboundSenderTaxHarness -HarnessSource src/MedusaOutboundSenderTaxHarness.sol -ArtifactDir reports/cat1_bridges/wormhole/manual_artifacts -ArtifactPrefix w3_outbound_sender_tax_formal -TimeoutSec 30 -EchidnaCorpusDir echidna-corpus-w3-formal`
- Output artifacts:
  - `reports/cat1_bridges/wormhole/manual_artifacts/w3_outbound_sender_tax_formal_medusa_30s.txt`
  - `reports/cat1_bridges/wormhole/manual_artifacts/w3_outbound_sender_tax_formal_echidna_30s.txt`
  - `reports/cat1_bridges/wormhole/manual_artifacts/w3_outbound_sender_tax_formal_campaign_meta.json`

## Hypotheses (Ranked Leads To Validate)

H1: Guardian-set rotation window risks
- Observation: `verifyVMInternal` accepts non-current guardian sets as long as they have not expired (`vm.guardianSetIndex != current && guardianSet.expirationTime < now` is the only expiry rejection). See `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\wormhole\ethereum\contracts\Messages.sol`.
- Question: Is the expiry timing and rotation procedure robust against â€œold set compromised shortly after rotationâ€ scenarios?
- Validation: confirm how `expireGuardianSet` is set (core uses `+86400` seconds in `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\wormhole\ethereum\contracts\Setters.sol`) and when it is invoked (`submitNewGuardianSet`).
- Status: validated and promoted as `W2` for bridge governance paths (stale-set signer window accepted in token-bridge governance checks).

H2: Reentrancy and external call safety during redemption
- Observation: `_completeTransfer` performs external calls after marking the transfer completed (ERC20 transfers, minting via wrapped token owner, and ETH transfers when unwrapping WETH). See `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\wormhole\ethereum\contracts\bridge\Bridge.sol`.
- Hypothesis: although replay is blocked, reentrancy might still enable unexpected cross-function state interaction (e.g. calling other bridge entrypoints) depending on what is reachable and which state is already updated.
- Validation: attempt to construct a minimal reentrancy harness on redemption paths and show that no invariant breaks (proof: failing test or symbolic counterexample).
- Status: not confirmed for same-VM replay vector. Control bug-order model is exploitable, but Wormhole-like ordering (`setTransferCompleted` + accounting before token transfer) blocks same-VM double redemption in deterministic and specialist-fuzz runs.

H3: Fee-on-transfer / nonstandard ERC20 behavior edge cases
- Observation: native-token transfers correct `amount` by measuring balance delta; wrapped-token path does not (burns full `amount`). See `_transferTokens` in `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\wormhole\ethereum\contracts\bridge\Bridge.sol`.
- Hypothesis: nonstandard tokens could lead to stuck funds, incorrect normalization, or fee accounting surprises.
- Validation: design test vectors for fee-on-transfer and weird-decimals tokens; prove impact is limited to that token and not systemic.
- Status: validated and promoted as `W3` (outbound sender-tax can break token-specific collateral coverage).

H4: Metadata attestation robustness
- Observation: `attestToken` and token transfer logic decode `decimals()/symbol()/name()` without checking staticcall success. See `attestToken` and `_transferTokens` in `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\wormhole\ethereum\contracts\bridge\Bridge.sol`.
- Hypothesis: misleading comment vs behavior indicates a potential DoS class (â€œcanâ€™t attest/bridge token that doesnâ€™t implement theseâ€), or decode mismatch risks.
- Validation: minimal contract lacking `symbol/name/decimals` (or returning malformed ABI) and show how it fails; classify as UX/DoS vs security.
- Status: validated and promoted as `W1` (token-specific DoS / compatibility break).

H5: Governance surface correctness across modules
- Observation: core and token bridge each independently check governance emitter and consumed actions.
- Hypothesis: subtle differences (fork handling, chainId==0 handling, etc.) could allow unintended governance actions on forks or unexpected chains.
- Validation: compare governance VM checks in `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\wormhole\ethereum\contracts\Governance.sol` vs `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\wormhole\ethereum\contracts\bridge\BridgeGovernance.sol` and create adversarial encoded VMs to ensure rejection.
- Status: validated and promoted as `W2` (bridge governance omits current guardian-set enforcement that core governance includes).

## Tool-Backed Validation (Manual Runs, Not Batch Scripts)

Slither (Solidity static analysis):
- Config already exists in the repo: `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\wormhole\ethereum\slither.config.json`
- Suggested initial run (core + bridge): run Slither from `wormhole/ethereum` and record output as a baseline triage artifact.

Slither snapshot (this workspace):
- Artifacts:
  - `reports/cat1_bridges/wormhole/manual_artifacts/slither_messages.json`
  - `reports/cat1_bridges/wormhole/manual_artifacts/slither_governance.json`
  - `reports/cat1_bridges/wormhole/manual_artifacts/slither_implementation.json`
  - `reports/cat1_bridges/wormhole/manual_artifacts/slither_bridge.json`
- High-signal notes (still just leads until proven):
  - `controlled-delegatecall` appears in the upgrade helpers (expected due to governance-driven upgrades; this is â€œhigh impact by designâ€).
  - `reentrancy-*` findings appear around ETH flows and redemption paths; these should be validated with a concrete harness (ties to H2).
  - `arbitrary-send-eth` appears in governance fee transfer logic; validate that only governance VAAs can trigger it.

Aderyn (additional Solidity analyzer):
- Aderyn is installed on this host (`aderyn 0.1.9`), but attempting to run it on the Wormhole EVM contracts currently triggers a panic on Windows (no report emitted).
- Failure artifact: `reports/cat1_bridges/wormhole/manual_artifacts/aderyn_skipbuild.stderr.txt`
- Action: keep using Slither + targeted tests/symbolic checks for now; retry Aderyn on Linux/WSL or after upgrading Aderyn.

Halmos (symbolic / invariant testing):
- Halmos is installed on this host.
- To use it effectively, we should install Foundry (`forge`) and use the existing Foundry tests under `wormhole/ethereum/forge-test`.
- First invariants to encode: â€œredeem cannot mint/unlock without a valid VAAâ€, â€œredeem cannot be replayedâ€, â€œpayload transfers are only callable by recipientâ€, â€œguardian set upgrade only by governance emitterâ€.

Specialist fuzzing (this pass):
- Harness:
  - `proof_harness/cat1_wormhole_f1_metadata_dos/src/MedusaBridgeMetadataCompatHarness.sol`
  - `proof_harness/cat1_wormhole_f2_stale_guardian_governance/src/MedusaStaleGuardianGovernanceHarness.sol`
  - `proof_harness/cat1_wormhole_f3_outbound_sender_tax_insolvency/src/MedusaOutboundSenderTaxHarness.sol`
  - `proof_harness/cat1_wormhole_h2_reentrancy_replay_guard/src/MedusaReentrancyReplayHarness.sol`
- Campaign artifacts:
  - `reports/cat1_bridges/wormhole/manual_artifacts/w1_metadata_dos_formal_medusa_30s.txt`
  - `reports/cat1_bridges/wormhole/manual_artifacts/w1_metadata_dos_formal_echidna_30s.txt`
  - `reports/cat1_bridges/wormhole/manual_artifacts/w1_metadata_dos_formal_campaign_meta.json`
  - `reports/cat1_bridges/wormhole/manual_artifacts/w2_stale_guardian_governance_formal_medusa_30s.txt`
  - `reports/cat1_bridges/wormhole/manual_artifacts/w2_stale_guardian_governance_formal_echidna_30s.txt`
  - `reports/cat1_bridges/wormhole/manual_artifacts/w2_stale_guardian_governance_formal_campaign_meta.json`
  - `reports/cat1_bridges/wormhole/manual_artifacts/w3_outbound_sender_tax_formal_medusa_30s.txt`
  - `reports/cat1_bridges/wormhole/manual_artifacts/w3_outbound_sender_tax_formal_echidna_30s.txt`
  - `reports/cat1_bridges/wormhole/manual_artifacts/w3_outbound_sender_tax_formal_campaign_meta.json`
  - `reports/cat1_bridges/wormhole/manual_artifacts/h2_reentrancy_replay_guard_formal_medusa_30s.txt`
  - `reports/cat1_bridges/wormhole/manual_artifacts/h2_reentrancy_replay_guard_formal_echidna_30s.txt`
  - `reports/cat1_bridges/wormhole/manual_artifacts/h2_reentrancy_replay_guard_formal_campaign_meta.json`
- Result:
  - bug properties falsified quickly with short sequences,
  - fixed-model control properties passed.

## Next Actions (Immediate)

1) Wormhole high/medium hypotheses are now evidence-closed (`W1`, `W2`, `W3`, and `H2` replay-vector falsification).
2) Mark Wormhole exhausted for this pass and move immediately to next Cat1 repo (`nomad-monorepo`) per roadmap order.

# wormhole (Manual Audit, Step 1/5)

Scope: `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\wormhole`

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
- “Shutdown” implementations exist as emergency drop-in upgrades that disable non-governance functionality (see `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\wormhole\ethereum\contracts\Shutdown.sol`, `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\wormhole\ethereum\contracts\bridge\BridgeShutdown.sol`).

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
- Upgrades can’t be replayed (consumed hash), and the new implementation is initialized exactly once per implementation address (see `_state.initializedImplementations` in `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\wormhole\ethereum\contracts\State.sol`).

Token bridge:
- A transfer VAA can be redeemed at most once on a chain (`completedTransfers[vm.hash]` in `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\wormhole\ethereum\contracts\bridge\BridgeState.sol`).
- Redemption must be for the current chain (`transfer.toChain == chainId()` in `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\wormhole\ethereum\contracts\bridge\Bridge.sol`).
- Redemption must be from an expected emitter for the source chain (`bridgeContracts(vm.emitterChainId) == vm.emitterAddress` in `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\wormhole\ethereum\contracts\bridge\Bridge.sol`).
- “Transfer with payload” can only be redeemed by the intended recipient (`payloadID == 3` sender check in `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\wormhole\ethereum\contracts\bridge\Bridge.sol`).

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

## Hypotheses (Ranked Leads To Validate)

H1: Guardian-set rotation window risks
- Observation: `verifyVMInternal` accepts non-current guardian sets as long as they have not expired (`vm.guardianSetIndex != current && guardianSet.expirationTime < now` is the only expiry rejection). See `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\wormhole\ethereum\contracts\Messages.sol`.
- Question: Is the expiry timing and rotation procedure robust against “old set compromised shortly after rotation” scenarios?
- Validation: confirm how `expireGuardianSet` is set (core uses `+86400` seconds in `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\wormhole\ethereum\contracts\Setters.sol`) and when it is invoked (`submitNewGuardianSet`).

H2: Reentrancy and external call safety during redemption
- Observation: `_completeTransfer` performs external calls after marking the transfer completed (ERC20 transfers, minting via wrapped token owner, and ETH transfers when unwrapping WETH). See `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\wormhole\ethereum\contracts\bridge\Bridge.sol`.
- Hypothesis: although replay is blocked, reentrancy might still enable unexpected cross-function state interaction (e.g. calling other bridge entrypoints) depending on what is reachable and which state is already updated.
- Validation: attempt to construct a minimal reentrancy harness on redemption paths and show that no invariant breaks (proof: failing test or symbolic counterexample).

H3: Fee-on-transfer / nonstandard ERC20 behavior edge cases
- Observation: native-token transfers correct `amount` by measuring balance delta; wrapped-token path does not (burns full `amount`). See `_transferTokens` in `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\wormhole\ethereum\contracts\bridge\Bridge.sol`.
- Hypothesis: nonstandard tokens could lead to stuck funds, incorrect normalization, or fee accounting surprises.
- Validation: design test vectors for fee-on-transfer and weird-decimals tokens; prove impact is limited to that token and not systemic.

H4: Metadata attestation robustness
- Observation: `attestToken` and token transfer logic decode `decimals()/symbol()/name()` without checking staticcall success. See `attestToken` and `_transferTokens` in `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\wormhole\ethereum\contracts\bridge\Bridge.sol`.
- Hypothesis: misleading comment vs behavior indicates a potential DoS class (“can’t attest/bridge token that doesn’t implement these”), or decode mismatch risks.
- Validation: minimal contract lacking `symbol/name/decimals` (or returning malformed ABI) and show how it fails; classify as UX/DoS vs security.

H5: Governance surface correctness across modules
- Observation: core and token bridge each independently check governance emitter and consumed actions.
- Hypothesis: subtle differences (fork handling, chainId==0 handling, etc.) could allow unintended governance actions on forks or unexpected chains.
- Validation: compare governance VM checks in `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\wormhole\ethereum\contracts\Governance.sol` vs `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\wormhole\ethereum\contracts\bridge\BridgeGovernance.sol` and create adversarial encoded VMs to ensure rejection.

## Tool-Backed Validation (Manual Runs, Not Batch Scripts)

Slither (Solidity static analysis):
- Config already exists in the repo: `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\wormhole\ethereum\slither.config.json`
- Suggested initial run (core + bridge): run Slither from `wormhole/ethereum` and record output as a baseline triage artifact.

Halmos (symbolic / invariant testing):
- Halmos is installed on this host.
- To use it effectively, we should install Foundry (`forge`) and use the existing Foundry tests under `wormhole/ethereum/forge-test`.
- First invariants to encode: “redeem cannot mint/unlock without a valid VAA”, “redeem cannot be replayed”, “payload transfers are only callable by recipient”, “guardian set upgrade only by governance emitter”.

## Next Actions (Immediate)

1) Build an “architecture map” section for EVM core + token bridge: list entrypoints and which storage keys they touch.
2) Deep read the redemption and emitter verification paths (`_completeTransfer`, `verifyBridgeVM`, chain registration).
3) Validate H2 with a concrete reentrancy harness (witness: failing test or counterexample).

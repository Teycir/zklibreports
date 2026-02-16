# telepathy-contracts (Manual Audit)

Scope: `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\telepathy-contracts`

HEAD: `0f3c6812d6bda96dde6ab7bdd8f8391c47bf5d0b`

Pass status: In progress (`F1` validated with deterministic + fuzz witness; additional high/medium hypotheses still open).

## Protocol Snapshot (AMB v2)

- Source path:
  - `src/amb-v2/SourceAMB.sol` builds message bytes with `(version, nonce, sourceChain, sourceAddress, destinationChain, destinationAddress, data)`, emits `SentMessage`, increments nonce.
- Target path:
  - `src/amb-v2/TargetAMB.sol` `execute(...)` checks replay/chain/version preconditions, selects verifier path, verifies message, then calls destination `handleTelepathy`.
  - Verifier selection is destination-hint first (`verifierType()` if present), else default by source chain.
- Control plane:
  - `src/amb-v2/TelepathyAccess.sol` gives timelock authority over default verifiers/version and guardian authority over execution toggle + zk relayer list.
- Upgradeable deployment surface:
  - `src/amb-v2/TelepathyRouter.sol` exposes external `initialize(...)` (initializer pattern).
  - `src/libraries/Proxy.sol` allows proxy deployment with arbitrary constructor `_data` (including empty init data).

## Critical Invariants

- Initializer authority:
  - The first successful `initialize(...)` on proxy storage must be trusted.
- Verifier integrity:
  - `defaultVerifiers[...]` and zk relayer policy must remain under trusted governance control.
- Message authenticity:
  - `execute(...)` must not reach destination handlers unless verification logic is trustworthy and attacker-uncontrolled.

## Proven Findings

### F1: Uninitialized-proxy first-caller initialization can seize bridge control plane and enable forged message execution

Severity: High (deployment-pattern dependent, but full control impact if triggered)

Affected code:
- `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\telepathy-contracts\src\amb-v2\TelepathyRouter.sol`
  - `initialize(...)` (external initializer)
- `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\telepathy-contracts\src\amb-v2\TelepathyAccess.sol`
  - `setDefaultVerifier(...)` (timelock-gated)
  - `setZkRelayer(...)` (guardian-gated)
- `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\telepathy-contracts\src\amb-v2\TargetAMB.sol`
  - `execute(...)` + `_verifyMessage(...)`
- `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\telepathy-contracts\src\libraries\Proxy.sol`
  - `UUPSProxy` constructor accepts `_data` (can be empty).

Root cause:
- If a proxy is deployed with empty init calldata and initialized later in a separate transaction, initialization is effectively first-caller-wins.
- First caller controls `timelock`/`guardian` role assignment.
- Role control lets attacker set verifier routing and relayer policy used by `execute(...)`.

Concrete witness sequence:
1. Router proxy-equivalent model is left uninitialized.
2. Attacker initializes first, setting `timelock=attacker` and `guardian=attacker`.
3. Legitimate deployer initialization attempt fails (already initialized).
4. Attacker sets default verifier to an always-true verifier.
5. Attacker executes a forged message; destination handler processes attacker-chosen source metadata.

Impact:
- Control-plane takeover of verifier and relayer policy.
- Forged-message acceptance in execution path under attacker-controlled verifier configuration.
- Legitimate governance permanently excluded from initialization.

Recommended fix:
- Deploy proxy with non-empty initialization calldata (`ERC1967Proxy` constructor `_data`) so initialization is atomic with deployment.
- In deployment scripts, fail hard if proxy starts uninitialized or roles differ from expected addresses.
- Avoid two-transaction `deploy -> initialize` in public mempool flows for these contracts.

Executable witness:
- Harness:
  - `proof_harness/cat1_telepathy_f1_uninitialized_init_hijack`
- Tests:
  - `test_f1_bug_model_uninitialized_first_caller_seizes_roles_and_executes_forged_message`
  - `test_f1_fixed_model_trusted_first_initialize_blocks_role_takeover`
  - `test_f1_fixed_model_non_timelock_cannot_enable_forged_execute`
  - `testFuzz_f1_bug_model_attacker_initialized_router_accepts_forged_messages`
  - `testFuzz_f1_fixed_model_trusted_initialized_router_rejects_attacker_forged_messages`
- Artifacts:
  - `reports/cat1_bridges/telepathy-contracts/manual_artifacts/f1_uninitialized_init_hijack_forge_test.txt`
  - `reports/cat1_bridges/telepathy-contracts/manual_artifacts/f1_uninitialized_init_hijack_fuzz_5000_runs.txt`

## Hypotheses (Ranked, Current)

F1: Uninitialized first-caller role takeover on `TelepathyRouterV2` proxy deployments
- Status: validated and promoted (proven, deployment-conditional).

F2: Destination-provided `verifierType()` trust boundary may create verifier-mode downgrade/DoS edge cases for integrators
- Status: open.

F3: Attestation verifier dependence on external `currentResponse()` semantics may expose stale-context or gateway-coupling risks
- Status: open.

## Notes / Blockers

- Full-source parity execution in `tmp/telepathy-contracts` is currently blocked in this workspace by missing `lib/*` dependencies/submodules (notably `telepathy-v2`), so this pass used a focused model harness for proof-grade witness capture.

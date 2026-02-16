# nomad-monorepo (Manual Audit, Step 2/5)

Scope: `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\nomad-monorepo`

HEAD: `f326b402285e3255a654e5e44c919ce412c2bed0`

Pass status: Exhausted for this pass (findings + parity hypotheses evidence-closed).

Primary scope (this pass):
- Core contracts in `solidity/nomad-core/contracts`
- Token bridge xApp in `solidity/nomad-xapps/contracts/bridge`

Non-goals (this pass):
- Rust agents, relayer/watcher runtime behavior, deployment infra correctness beyond direct on-chain init wiring, and non-bridge xApps except where needed to validate auth boundaries.

## Protocol Snapshot (Solidity Path)

Message flow:
- Source-chain app calls `Home.dispatch(...)` to append a message leaf and enqueue the latest root (`solidity/nomad-core/contracts/Home.sol`).
- Updater signs `(oldRoot,newRoot)` and calls `Home.update(...)` on source chain and `Replica.update(...)` on destination chain (`solidity/nomad-core/contracts/Home.sol`, `solidity/nomad-core/contracts/Replica.sol`).
- On destination chain, processors call `Replica.prove(...)` or `Replica.proveAndProcess(...)`.
- `Replica.process(...)` calls recipient `handle(origin,nonce,sender,body)` (`solidity/nomad-core/contracts/Replica.sol`).
- Bridge recipient is `BridgeRouter.handle(...)`, which then releases escrowed canonical tokens or mints representation tokens (`solidity/nomad-xapps/contracts/bridge/BridgeRouter.sol`).

Security boundary:
- xApps trust `msg.sender` being an enrolled replica (`XAppConnectionClient.onlyReplica`).
- xApps then trust `(origin,sender)` from message bytes to enforce remote router allowlists (`Router.onlyRemoteRouter`).

## Trust Assumptions (As Implemented)

- Updater key for each remote domain is trusted until fraud proof / failover.
- `XAppConnectionManager` owner is trusted to correctly enroll/unenroll replicas and watcher permissions.
- `GovernanceRouter` trusts `xAppConnectionManager.isReplica(msg.sender)` before accepting cross-chain governance messages.
- Bridge safety relies on replica auth plus remote-router matching before mint/unlock paths execute.

## Critical Invariants To Preserve

Replica/XCM authorization invariants:
- Only the currently enrolled replica for a remote domain should remain authorized as `isReplica == true`.
- `domainToReplica` and `replicaToDomain` should behave as a consistent one-to-one relation for active routes.

Bridge invariants:
- `BridgeRouter.handle(...)` must only be reachable from a currently authorized replica.
- Once inside `handle`, remote router checks should be the only remaining trust gate before value movement.

Governance invariants:
- `GovernanceRouter.handle(...)` must only accept calls from currently authorized replicas tied to the governor router mapping.

## Entry Points Map (High Impact)

Core:
- `Home.dispatch(...)`
- `Home.update(...)`
- `Replica.update(...)`
- `Replica.prove(...)`
- `Replica.proveAndProcess(...)`
- `Replica.process(...)`

Connection / auth:
- `XAppConnectionManager.ownerEnrollReplica(...)`
- `XAppConnectionManager.ownerUnenrollReplica(...)`
- `XAppConnectionManager.unenrollReplica(...)`
- `XAppConnectionManager.isReplica(...)`

Bridge:
- `BridgeRouter.handle(...)`
- `BridgeRouter.send(...)`
- `BridgeRouter.preFill(...)`

Governance:
- `GovernanceRouter.handle(...)`
- `GovernanceRouter.executeCallBatch(...)`

## Proven Findings

### F1: Stale replicas remain authorized after domain re-enrollment (Auth boundary break)

Severity: High

Affected code:
- `solidity/nomad-core/contracts/XAppConnectionManager.sol`
  - `ownerEnrollReplica(...)`
  - `_unenrollReplica(...)`
  - `isReplica(...)`
- Auth consumers:
  - `solidity/nomad-xapps/contracts/XAppConnectionClient.sol` (`onlyReplica`)
  - `solidity/nomad-core/contracts/governance/GovernanceRouter.sol` (`onlyReplica`)

Root cause:
- `ownerEnrollReplica(_replica,_domain)` calls `_unenrollReplica(_replica)` using the new replica address, not the currently enrolled replica for `_domain`.
- If `_domain` already had an old replica, its reverse mapping entry `replicaToDomain[oldReplica]` is never cleared.
- `isReplica(addr)` only checks `replicaToDomain[addr] != 0`, so old replicas remain authorized indefinitely unless explicitly owner-unenrolled by address.

Concrete witness (state transition trace):
1. Owner calls `ownerEnrollReplica(R1, D)`.
2. Owner later rotates to `R2` with `ownerEnrollReplica(R2, D)`.
3. During step 2, `_unenrollReplica(R2)` is effectively a no-op for old enrollment state.
4. Post-state:
   - `domainToReplica[D] == R2`
   - `replicaToDomain[R2] == D`
   - `replicaToDomain[R1] == D` (stale but still non-zero)
5. Therefore `isReplica(R1) == true` and `isReplica(R2) == true`.
6. Any downstream `onlyReplica` checks now trust both addresses.

Impact:
- Attempted emergency rotation does not fully revoke previous replica authority.
- If an old replica is compromised or otherwise untrusted, it can still pass `onlyReplica` gates in bridge and governance receivers.
- This directly weakens the intended trust boundary during incident response.

Recommended fix:
- In `ownerEnrollReplica`, first resolve and remove the currently enrolled replica for the target domain:
  - `address old = domainToReplica[_domain];`
  - if `old != address(0)`, `_unenrollReplica(old)`.
- Then optionally unenroll `_replica` if it is currently mapped to a different domain, and finally write both forward/reverse mappings.
- Add invariant tests: after re-enroll, exactly one replica must satisfy `isReplica == true` for that domain lifecycle.

Executable witness:
- Harness: `proof_harness/cat1_nomad_f1_stale_replica`
- Test: `proof_harness/cat1_nomad_f1_stale_replica/test/StaleReplicaAuthorization.t.sol`
- Run: `forge test -vv` (from harness directory)
- Output artifact: `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f1_stale_replica_forge_test.txt`
- Fuzz artifact: `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f1_fuzz_5000_runs.txt`
- Medusa artifact: `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f1_medusa_failfast_30s.txt`

### F2: Unenrolling stale replica can desync forward/reverse mappings

Severity: Medium

Affected code:
- `solidity/nomad-core/contracts/XAppConnectionManager.sol`
  - `ownerEnrollReplica(...)`
  - `ownerUnenrollReplica(...)`
  - `_unenrollReplica(...)`
  - `isReplica(...)`

Root cause:
- After stale auth state exists (F1), calling `ownerUnenrollReplica(staleReplica)` clears `domainToReplica[domain]` using the stale reverse mapping.
- The active replica for that domain remains authorized via `replicaToDomain[activeReplica] != 0`.

Concrete witness sequence:
1. `ownerEnrollReplica(R1, D)`
2. `ownerEnrollReplica(R2, D)` (creates stale `replicaToDomain[R1] = D`)
3. `ownerUnenrollReplica(R1)`
4. Post-state:
   - `domainToReplica[D] == address(0)`
   - `isReplica(R2) == true`

Impact:
- Split-brain control state:
  - domain lookup says "no replica"
  - authorization lookup still says active replica is valid
- Watcher unenroll path becomes inconsistent because it resolves replica by `domainToReplica[_domain]` and requires nonzero.
- Incident response and operational tooling can make incorrect assumptions from one map while auth checks continue to use the other.

Executable witness:
- Harness: `proof_harness/cat1_nomad_f1_stale_replica`
- Fuzz test: `testFuzz_bug_unenroll_stale_desyncs_mappings_and_auth(...)`
- Run: `forge test -vv --fuzz-runs 5000`
- Output artifact: `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f1_fuzz_5000_runs.txt`

### F3: Retired replica can still pass sink auth (`onlyReplica + onlyRemoteRouter`) and execute `handle`

Severity: High

Affected logic class:
- xApp receiver auth pattern combining:
  - `onlyReplica` (`xAppConnectionManager.isReplica(msg.sender)`)
  - `onlyRemoteRouter(_origin, _sender)` (message-field checks)

Root cause linkage:
- F1 keeps retired replica addresses authorized.
- Once authorized, a retired replica caller can invoke sink `handle(...)` with `_origin/_sender` values that satisfy remote router checks.

Concrete witness sequence (Medusa-minimized):
1. Enroll replica `R1` for domain `D`.
2. Re-enroll replica `R2` for domain `D` (retires `R1` by intent, but not in auth state).
3. Call sink `handle(origin=D, sender=registeredRouter)` from `R1`.
4. Result: call succeeds and sink state mutates.

Impact:
- Rotation does not actually revoke stale replicas at sink boundaries.
- Any retired replica that can still transact can keep delivering authenticated-looking xApp messages.
- This upgrades F1 from mapping inconsistency to direct sink reachability.

Executable witness:
- Harness:
  - `proof_harness/cat1_nomad_f1_stale_replica/src/MedusaSinkAuthHarness.sol`
- Campaign:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File ..\\..\\scripts\\medusa.ps1 fuzz --compilation-target . --target-contracts MedusaSinkAuthHarness --seq-len 10 --workers 4 --timeout 30 --fail-fast --no-color --log-level info`
- Output artifact:
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f3_medusa_sink_auth_30s.txt`

Echidna cross-check:
- Campaign:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File ..\\..\\scripts\\echidna.ps1 src/MedusaSinkAuthHarness.sol --contract MedusaSinkAuthHarness --test-mode property --seq-len 10 --test-limit 20000 --timeout 30 --format text --corpus-dir echidna-corpus`
- Output artifact:
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f3_echidna_sink_auth_30s.txt`

### F4: Retired replica can forge `TransferGovernor` handling and seize local governor privileges

Severity: Critical

Affected code:
- `solidity/nomad-core/contracts/governance/GovernanceRouter.sol`
  - `handle(...)`
  - `_handleTransferGovernor(...)`
  - `_transferGovernor(...)`
- Root precondition from `solidity/nomad-core/contracts/XAppConnectionManager.sol`
  - `ownerEnrollReplica(...)`
  - `isReplica(...)`

Root cause linkage:
- F1 leaves retired replica addresses authorized at `onlyReplica`.
- `GovernanceRouter.handle` trusts `(origin,sender)` fields when `msg.sender` passes `onlyReplica`.
- A forged `TransferGovernor` message for `localDomain` sets `governor` directly to attacker-controlled address.

Concrete witness sequence:
1. Enroll replica `R1` for domain `D`.
2. Re-enroll `R2` for the same domain `D` (intended retirement of `R1`).
3. Retired `R1` calls governance sink `handle(...)` with:
   - `_origin = governorDomain`
   - `_sender = routers[governorDomain]`
   - `_message = TransferGovernor(localDomain, attacker)`
4. Governance sink updates `governor = attacker`.
5. Attacker executes privileged governor-only state mutation.

Impact:
- Local governance privilege takeover on affected chains.
- Attacker can execute `onlyGovernor` paths (e.g. router management and governance dispatch).
- This is a direct escalation from stale auth state into control-plane compromise.

Executable witness:
- Harness:
  - `proof_harness/cat1_nomad_f1_stale_replica/src/GovernanceRouterTakeoverHarness.sol`
- Tests:
  - `proof_harness/cat1_nomad_f1_stale_replica/test/GovernanceTakeoverViaStaleReplica.t.sol`
- Run:
  - `forge test -vv --match-path test/GovernanceTakeoverViaStaleReplica.t.sol`
  - `forge test -vv --match-path test/GovernanceTakeoverViaStaleReplica.t.sol --fuzz-runs 5000`
- Output artifacts:
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f4_governance_takeover_forge_test.txt`
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f4_governance_takeover_fuzz_5000_runs.txt`

Specialist fuzz witnesses:
- Medusa harness:
  - `proof_harness/cat1_nomad_f1_stale_replica/src/MedusaGovernanceTakeoverHarness.sol`
  - `property_retired_replica_cannot_take_governor`
- Medusa campaign:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File ..\\..\\scripts\\medusa.ps1 fuzz --compilation-target . --target-contracts MedusaGovernanceTakeoverHarness --seq-len 10 --workers 4 --timeout 30 --fail-fast --no-color --log-level info`
  - Artifact: `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f4_medusa_governance_takeover_30s.txt`
- Echidna cross-check:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File ..\\..\\scripts\\echidna.ps1 src/MedusaGovernanceTakeoverHarness.sol --contract MedusaGovernanceTakeoverHarness --test-mode property --seq-len 10 --test-limit 20000 --timeout 30 --format text --corpus-dir echidna-corpus`
  - Artifact: `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f4_echidna_governance_takeover_30s.txt`

### F5: Retired replica can inject forged governance batch and execute privileged calls via `executeCallBatch`

Severity: Critical

Affected code:
- `solidity/nomad-core/contracts/governance/GovernanceRouter.sol`
  - `handle(...)`
  - `_handleBatch(...)`
  - `executeCallBatch(...)`
- Root precondition from `solidity/nomad-core/contracts/XAppConnectionManager.sol`
  - `ownerEnrollReplica(...)`
  - `isReplica(...)`

Root cause linkage:
- F1 leaves retired replica addresses authorized at `onlyReplica`.
- `handle` accepts batch messages from any authorized replica that matches `(origin,sender)` governor-router tuple.
- `executeCallBatch` is externally callable and executes pending calls as `address(this)`.
- A forged batch hash inserted by retired replica enables arbitrary privileged local call execution.

Concrete witness sequence:
1. Enroll replica `R1` for domain `D`.
2. Re-enroll `R2` for the same domain `D` (intended retirement of `R1`).
3. Retired `R1` calls governance sink `handle(...)` with a forged batch message committing to a call batch.
4. External caller invokes `executeCallBatch(calls)` with matching batch hash.
5. Batch executes `onlyGovernor`-gated local state mutation via `address(this)` context.

Impact:
- Direct arbitrary governance-call execution path without requiring explicit `governor` transfer first.
- Compromises governance control plane (router management, governance dispatch, and other privileged local actions).
- Independent critical exploitation path from stale auth state.

Executable witness:
- Harness:
  - `proof_harness/cat1_nomad_f1_stale_replica/src/GovernanceBatchInjectionHarness.sol`
- Tests:
  - `proof_harness/cat1_nomad_f1_stale_replica/test/GovernanceBatchInjectionViaStaleReplica.t.sol`
- Run:
  - `forge test -vv --match-path test/GovernanceBatchInjectionViaStaleReplica.t.sol`
  - `forge test -vv --match-path test/GovernanceBatchInjectionViaStaleReplica.t.sol --fuzz-runs 5000`
- Output artifacts:
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f5_batch_injection_forge_test.txt`
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f5_batch_injection_fuzz_5000_runs.txt`

Specialist fuzz witnesses:
- Medusa harness:
  - `proof_harness/cat1_nomad_f1_stale_replica/src/MedusaGovernanceBatchInjectionHarness.sol`
  - `property_retired_replica_cannot_execute_forged_batch`
- Medusa campaign:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File ..\\..\\scripts\\medusa.ps1 fuzz --compilation-target . --target-contracts MedusaGovernanceBatchInjectionHarness --seq-len 10 --workers 4 --timeout 30 --fail-fast --no-color --log-level info`
  - Artifact: `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f5_medusa_batch_injection_30s.txt`
- Echidna cross-check:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File ..\\..\\scripts\\echidna.ps1 src/MedusaGovernanceBatchInjectionHarness.sol --contract MedusaGovernanceBatchInjectionHarness --test-mode property --seq-len 10 --test-limit 20000 --timeout 30 --format text --corpus-dir echidna-corpus`
  - Artifact: `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f5_echidna_batch_injection_30s.txt`

Formalized campaign metadata capture:
- Script:
  - `scripts/evm_specialist_campaign.ps1`
- Example artifact set:
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f5_batch_injection_formal_v2_medusa_8s.txt`
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f5_batch_injection_formal_v2_campaign_meta.json`

### F6: Bootstrap committed root is immediately acceptable (optimistic timeout bypass at initialization boundary)

Severity: High

Affected code:
- `solidity/nomad-core/contracts/Replica.sol`
  - `initialize(...)`
  - `acceptableRoot(...)`
  - `prove(...)`
  - `proveAndProcess(...)`

Root cause:
- `initialize(... _committedRoot ...)` sets `confirmAt[_committedRoot] = 1`.
- `acceptableRoot(_root)` only checks `block.timestamp >= confirmAt[_root]`.
- Therefore the bootstrap committed root is accepted immediately, independent of `optimisticSeconds`.

Concrete witness sequence:
1. Initialize bootstrap root and set non-zero `optimisticSeconds`.
2. Immediately call `prove(...)` for a leaf/branch that resolves to the committed root.
3. Proof is accepted before the optimistic timeout window elapses.
4. Fixed control model (`confirmAt[root] = block.timestamp + optimisticSeconds`) rejects the same proof pre-timeout and accepts only post-timeout.

Impact:
- Optimistic delay does not protect the bootstrap root path.
- Safety of initial root acceptance is fully delegated to deployment-time correctness.
- If bootstrap root wiring is unsafe (wrong/placeholder root), invalid-message acceptance can occur immediately.

Recommended fix:
- Time-gate bootstrap root confirmation (`confirmAt[_committedRoot] = block.timestamp + optimisticSeconds`), or
- Keep immediate bootstrap acceptance only behind explicit, verifiable initialization safeguards (strict root binding and initialization assertions).
- Add invariant regression tests enforcing "no bootstrap-root acceptance before timeout" unless an explicit emergency override is enabled.

Executable witness:
- Harness:
  - `proof_harness/cat1_nomad_f1_stale_replica/src/ReplicaBootstrapTimeoutHarness.sol`
- Tests:
  - `proof_harness/cat1_nomad_f1_stale_replica/test/ReplicaBootstrapTimeoutBypass.t.sol`
- Run:
  - `forge test -vv --match-path test/ReplicaBootstrapTimeoutBypass.t.sol`
  - `forge test -vv --match-path test/ReplicaBootstrapTimeoutBypass.t.sol --fuzz-runs 5000`
- Output artifacts:
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f6_bootstrap_timeout_forge_test.txt`
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f6_bootstrap_timeout_fuzz_5000_runs.txt`

Specialist fuzz witnesses:
- Medusa harness:
  - `proof_harness/cat1_nomad_f1_stale_replica/src/MedusaReplicaBootstrapHarness.sol`
  - `property_bootstrap_root_waits_timeout`
  - `property_fixed_model_waits_timeout`
- Standardized campaign:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/evm_specialist_campaign.ps1 -HarnessDir proof_harness/cat1_nomad_f1_stale_replica -HarnessContract MedusaReplicaBootstrapHarness -HarnessSource src/MedusaReplicaBootstrapHarness.sol -ArtifactDir reports/cat1_bridges/nomad-monorepo/manual_artifacts -ArtifactPrefix f6_bootstrap_timeout_formal -TimeoutSec 30 -EchidnaCorpusDir echidna-corpus-f6-formal`
- Output artifacts:
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f6_bootstrap_timeout_formal_medusa_30s.txt`
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f6_bootstrap_timeout_formal_echidna_30s.txt`
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f6_bootstrap_timeout_formal_campaign_meta.json`

### F7: Forged `preFill` can drain dust pool without providing liquidity

Severity: Medium

Affected code:
- `solidity/nomad-xapps/contracts/bridge/BridgeRouter.sol`
  - `preFill(...)`
  - `_dust(...)`
- Token lookup dependency:
  - `solidity/nomad-xapps/contracts/bridge/TokenRegistry.sol`
    - `mustHaveLocalToken(...)`

Root cause:
- `preFill(...)` accepts caller-supplied transfer message fields and does not verify that the message corresponds to an authenticated/pending bridge transfer.
- It records a unique prefill ID and executes token transfer side effects before any on-chain authenticity check.
- `_dust(...)` runs after `preFill` and transfers fixed native-asset dust when recipient is under threshold.
- With `_amount == 0`, token transfer can be a no-op while dust still pays out.

Concrete witness sequence:
1. Attacker chooses a valid local token ID and a fresh `(origin, nonce)` pair.
2. Attacker calls `preFill(...)` with forged fast-transfer parameters and `_amount = 0`.
3. `liquidityProvider[id]` is recorded and `transferFrom(msg.sender, recipient, 0)` succeeds with no liquidity provision.
4. `_dust(recipient)` credits/sends `DUST_AMOUNT`.
5. Repeat with new nonce and new low-balance recipients to drain the dust pool.

Impact:
- Native-asset dust reserves can be drained at near-zero token cost.
- Intended gas-bootstrapping for legitimate bridge recipients can be griefed/denied.
- Attack can be repeated permissionlessly while dust reserves remain.

Recommended fix:
- Gate `preFill` behind authenticated pending-transfer availability (for example, a committed transfer-ID registry populated by authenticated handle path).
- Reject zero-amount prefill requests.
- Treat dusting as a separately rate-limited feature rather than unconditional post-prefill side effect.

Executable witness:
- Harness:
  - `proof_harness/cat1_nomad_f1_stale_replica/src/BridgePrefillDustDrainHarness.sol`
- Tests:
  - `proof_harness/cat1_nomad_f1_stale_replica/test/BridgePrefillDustDrain.t.sol`
- Run:
  - `forge test -vv --match-path test/BridgePrefillDustDrain.t.sol`
  - `forge test -vv --match-path test/BridgePrefillDustDrain.t.sol --fuzz-runs 5000`
- Output artifacts:
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f7_prefill_dust_forge_test.txt`
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f7_prefill_dust_fuzz_5000_runs.txt`

Specialist fuzz witnesses:
- Medusa harness:
  - `proof_harness/cat1_nomad_f1_stale_replica/src/MedusaBridgePrefillDustHarness.sol`
  - `property_forged_prefill_cannot_drain_dust`
  - `property_fixed_model_blocks_forged_prefill`
- Standardized campaign:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/evm_specialist_campaign.ps1 -HarnessDir proof_harness/cat1_nomad_f1_stale_replica -HarnessContract MedusaBridgePrefillDustHarness -HarnessSource src/MedusaBridgePrefillDustHarness.sol -ArtifactDir reports/cat1_bridges/nomad-monorepo/manual_artifacts -ArtifactPrefix f7_prefill_dust_formal -TimeoutSec 30 -EchidnaCorpusDir echidna-corpus-f7-formal`
- Output artifacts:
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f7_prefill_dust_formal_medusa_30s.txt`
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f7_prefill_dust_formal_echidna_30s.txt`
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f7_prefill_dust_formal_campaign_meta.json`

### F8: `enrollCustom` allows representation aliasing across canonical IDs, enabling cross-asset remapping

Severity: Medium

Affected code:
- `solidity/nomad-xapps/contracts/bridge/TokenRegistry.sol`
  - `enrollCustom(...)`
  - `_setRepresentationToCanonical(...)`
  - `_setCanonicalToRepresentation(...)`
  - `getTokenId(...)`
- `solidity/nomad-xapps/contracts/bridge/BridgeRouter.sol`
  - `send(...)`
  - `_handleTransfer(...)`

Root cause:
- `enrollCustom(...)` does not enforce one-to-one mapping between representation address and canonical token ID.
- Re-enrolling the same custom representation for a second canonical ID overwrites `representationToCanonical[repr]` while leaving old `canonicalToRepresentation[oldId] = repr`.
- Incoming transfer handling for `oldId` still mints `repr`, but outbound `send(repr,...)` now resolves token ID as `newId`.

Concrete witness sequence:
1. Enroll custom representation `X` for canonical token `A`.
2. Enroll the same `X` again for canonical token `B`.
3. Incoming transfer for `A` mints `X` locally.
4. User sends `X` back through bridge.
5. `getTokenId(X)` resolves to `B`, so remote settlement releases/mints `B`, not `A`.

Impact:
- Cross-asset remapping becomes possible after a single configuration mistake.
- Users can effectively convert canonical `A` exposure into canonical `B` settlement path.
- Breaks token identity/conservation assumptions across chains until governance correction.

Recommended fix:
- Enforce one-to-one representation uniqueness in `enrollCustom`:
  - if `_custom` is already mapped, require it matches the same canonical `(domain,id)`.
- Add invariant tests:
  - a representation cannot map to two different canonical IDs;
  - round-trip send/handle for a token preserves canonical ID.

Executable witness:
- Harness:
  - `proof_harness/cat1_nomad_f1_stale_replica/src/TokenRegistryAliasSwapHarness.sol`
- Tests:
  - `proof_harness/cat1_nomad_f1_stale_replica/test/TokenRegistryAliasSwap.t.sol`
- Run:
  - `forge test -vv --match-path test/TokenRegistryAliasSwap.t.sol`
  - `forge test -vv --match-path test/TokenRegistryAliasSwap.t.sol --fuzz-runs 5000`
- Output artifacts:
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f8_alias_swap_forge_test.txt`
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f8_alias_swap_fuzz_5000_runs.txt`

Specialist fuzz witnesses:
- Medusa harness:
  - `proof_harness/cat1_nomad_f1_stale_replica/src/MedusaTokenRegistryAliasHarness.sol`
  - `property_representation_alias_cannot_swap_assets`
  - `property_fixed_model_blocks_alias_swap`
- Standardized campaign:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/evm_specialist_campaign.ps1 -HarnessDir proof_harness/cat1_nomad_f1_stale_replica -HarnessContract MedusaTokenRegistryAliasHarness -HarnessSource src/MedusaTokenRegistryAliasHarness.sol -ArtifactDir reports/cat1_bridges/nomad-monorepo/manual_artifacts -ArtifactPrefix f8_alias_swap_formal -TimeoutSec 30 -EchidnaCorpusDir echidna-corpus-f8-formal`
- Output artifacts:
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f8_alias_swap_formal_medusa_30s.txt`
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f8_alias_swap_formal_echidna_30s.txt`
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f8_alias_swap_formal_campaign_meta.json`

### F9: Governance domain-list churn inflates global dispatch scans (liveness/gas degradation)

Severity: Medium

Affected code:
- `solidity/nomad-core/contracts/governance/GovernanceRouter.sol`
  - `_addDomain(...)`
  - `_removeDomain(...)`
  - `setRouterGlobal(...)`
  - `_sendToAllRemoteRouters(...)`

Root cause:
- Domain removal logic leaves holes in `domains[]` instead of preserving a dense active-domain set.
- Repeated remove/re-add of the same domain appends new entries while old slots remain deleted.
- Global dispatch loops still scan `domains.length`, so cost scales with historical churn, not active routes.

Concrete witness sequence:
1. Configure a single remote domain `D` with a router.
2. Repeat churn cycle `N` times: remove `D`, then re-add `D`.
3. Dispatch a global governance action (modeled `dispatchAll()` in the harness).
4. Observe:
   - `activeDomainCount == 1`
   - `lastScanCount == domains.length == N + 1`
   - scan count strictly exceeds active domain count.

Impact:
- Governance broadcast operations can become progressively more expensive despite unchanged active topology.
- Sustained churn can push global dispatches toward practical gas/liveness limits.
- Operational safety margins degrade over time unless state is compacted.

Recommended fix:
- Maintain domains as a dense set (swap-and-pop plus index mapping) instead of delete-hole removal.
- Add invariants asserting dispatch scan count tracks active domains.
- For live deployments with pre-existing churn, include a one-time compaction/migration path.

Executable witness:
- Harness:
  - `proof_harness/cat1_nomad_f1_stale_replica/src/GovernanceDomainChurnHarness.sol`
- Tests:
  - `proof_harness/cat1_nomad_f1_stale_replica/test/GovernanceDomainChurnLiveness.t.sol`
  - `proof_harness/cat1_nomad_f1_stale_replica/test/GovernanceDomainChurnGasProfile.t.sol`
- Run:
  - `forge test -vv --match-path test/GovernanceDomainChurnLiveness.t.sol`
  - `forge test -vv --match-path test/GovernanceDomainChurnLiveness.t.sol --fuzz-runs 5000`
  - `forge test -vv --match-path test/GovernanceDomainChurnGasProfile.t.sol`
- Output artifacts:
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f9_domain_churn_forge_test.txt`
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f9_domain_churn_fuzz_5000_runs.txt`
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f9_domain_churn_gas_profile_forge_test.txt`

Gas-envelope quantification (instrumented governance-path model):
- Baseline (no churn):
  - bug dispatch gas: `45,940`
  - fixed dispatch gas: `45,917`
- Threshold crossings in bug model:
  - `2x` baseline reached at churn loops `100` (`122,040` gas)
  - `3x` baseline reached at churn loops `200` (`198,090` gas)
  - `5x` baseline reached at churn loops `400` (`350,240` gas)
- High churn reference:
  - loops `1200` -> `958,840` dispatch gas (~`20.9x` baseline)
- Fixed model stayed flat at `45,917` across all sampled churn levels.

Specialist fuzz witnesses:
- Medusa harness:
  - `proof_harness/cat1_nomad_f1_stale_replica/src/MedusaGovernanceDomainChurnHarness.sol`
  - `property_dispatch_scan_tracks_active_domains`
  - `property_fixed_model_avoids_scan_overhead`
- Standardized campaign:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/evm_specialist_campaign.ps1 -HarnessDir proof_harness/cat1_nomad_f1_stale_replica -HarnessContract MedusaGovernanceDomainChurnHarness -HarnessSource src/MedusaGovernanceDomainChurnHarness.sol -ArtifactDir reports/cat1_bridges/nomad-monorepo/manual_artifacts -ArtifactPrefix f9_domain_churn_formal -TimeoutSec 30 -EchidnaCorpusDir echidna-corpus-f9-formal`
- Output artifacts:
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f9_domain_churn_formal_medusa_30s.txt`
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f9_domain_churn_formal_echidna_30s.txt`
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f9_domain_churn_formal_campaign_meta.json`

### F10: `migrate` can convert canonical asset identity after representation alias overwrite

Severity: Medium

Affected code:
- `solidity/nomad-xapps/contracts/bridge/BridgeRouter.sol`
  - `migrate(...)`
- `solidity/nomad-xapps/contracts/bridge/TokenRegistry.sol`
  - `oldReprToCurrentRepr(...)`
  - `enrollCustom(...)`
  - `getTokenId(...)`

Root cause:
- `migrate(_oldRepr)` trusts `oldReprToCurrentRepr(_oldRepr)` as the safe successor representation.
- `oldReprToCurrentRepr` resolves through mutable `representationToCanonical` and `canonicalToRepresentation` mappings.
- After alias-overwrite conditions from F8, an old representation originally minted for canonical `A` can resolve to a current representation for canonical `B`.
- `migrate` then burns user balance in old `A` representation and mints `B` representation, enabling canonical identity change.

Concrete witness sequence:
1. User receives legacy representation `R_A_old` from canonical token `A`.
2. Governance enrolls `R_A_old` as custom representation for canonical `B`.
3. Governance rotates canonical `B` to a new current representation `R_B_new`.
4. User calls `migrate(R_A_old)`:
   - burns `R_A_old`
   - mints `R_B_new`
5. User sends `R_B_new` through bridge and receives canonical token `B` remotely.

Impact:
- Users can convert canonical `A` exposure into canonical `B` settlement path using migrate-assisted flow.
- Breaks migration assumption that old/new representation upgrades preserve canonical asset identity.
- Expands F8 impact from send/handle remapping to local opt-in migration conversion.

Recommended fix:
- Apply the F8 fix strictly (one representation address cannot map to multiple canonical IDs).
- Add migrate-specific invariant tests:
  - migrate old/new representations must preserve canonical domain/id.
  - alias-overwrite attempt must be rejected before any migrate path is reachable.
- Consider storing immutable canonical metadata per representation at creation time and validating migrate transitions against that immutable source.

Executable witness:
- Harness:
  - `proof_harness/cat1_nomad_f1_stale_replica/src/TokenRegistryMigrateAliasHarness.sol`
- Tests:
  - `proof_harness/cat1_nomad_f1_stale_replica/test/TokenRegistryMigrateAliasSwap.t.sol`
- Run:
  - `forge test -vv --match-path test/TokenRegistryMigrateAliasSwap.t.sol`
  - `forge test -vv --match-path test/TokenRegistryMigrateAliasSwap.t.sol --fuzz-runs 5000`
- Output artifacts:
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f10_migrate_alias_forge_test.txt`
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f10_migrate_alias_fuzz_5000_runs.txt`

Specialist fuzz witnesses:
- Medusa harness:
  - `proof_harness/cat1_nomad_f1_stale_replica/src/MedusaTokenRegistryMigrateHarness.sol`
  - `property_migrate_cannot_swap_canonical_asset`
  - `property_fixed_model_blocks_migrate_alias_swap`
- Standardized campaign:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/evm_specialist_campaign.ps1 -HarnessDir proof_harness/cat1_nomad_f1_stale_replica -HarnessContract MedusaTokenRegistryMigrateHarness -HarnessSource src/MedusaTokenRegistryMigrateHarness.sol -ArtifactDir reports/cat1_bridges/nomad-monorepo/manual_artifacts -ArtifactPrefix f10_migrate_alias_formal -TimeoutSec 30 -EchidnaCorpusDir echidna-corpus-f10-formal`
- Output artifacts:
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f10_migrate_alias_formal_medusa_30s.txt`
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f10_migrate_alias_formal_echidna_30s.txt`
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f10_migrate_alias_formal_campaign_meta.json`

## Specialist Fuzzing (Medusa + Echidna)

Medusa stateful harness:
- `proof_harness/cat1_nomad_f1_stale_replica/src/MedusaXcmF1Harness.sol`
  - Actions: `action_enroll`, `action_unenroll`
  - Properties: `property_unique_replica_per_domain`, `property_bidirectional_mapping_consistency`

Campaign:
- Command:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File ..\\..\\scripts\\medusa.ps1 fuzz --compilation-target . --target-contracts MedusaXcmF1Harness --seq-len 8 --workers 4 --timeout 30 --fail-fast --no-color --log-level info`
- Result: both properties failed with minimized 2-call counterexample sequences.
- Artifact: `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f1_medusa_failfast_30s.txt`

Governance takeover harness:
- `proof_harness/cat1_nomad_f1_stale_replica/src/MedusaGovernanceTakeoverHarness.sol`
  - Actions: `action_enrollReplica`, `action_tryForgedTransferGovernor`
  - Property: `property_retired_replica_cannot_take_governor`
- Medusa artifact:
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f4_medusa_governance_takeover_30s.txt`
- Echidna artifact:
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f4_echidna_governance_takeover_30s.txt`

Governance batch-injection harness:
- `proof_harness/cat1_nomad_f1_stale_replica/src/MedusaGovernanceBatchInjectionHarness.sol`
  - Actions: `action_enrollReplica`, `action_tryInjectAndExecuteBatch`
  - Property: `property_retired_replica_cannot_execute_forged_batch`
- Medusa artifact:
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f5_medusa_batch_injection_30s.txt`
- Echidna artifact:
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f5_echidna_batch_injection_30s.txt`

Bootstrap-root timeout harness:
- `proof_harness/cat1_nomad_f1_stale_replica/src/MedusaReplicaBootstrapHarness.sol`
  - Actions: `action_tryProveBug`, `action_tryProveFixed`
  - Properties: `property_bootstrap_root_waits_timeout`, `property_fixed_model_waits_timeout`
- Standardized campaign artifacts:
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f6_bootstrap_timeout_formal_medusa_30s.txt`
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f6_bootstrap_timeout_formal_echidna_30s.txt`
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f6_bootstrap_timeout_formal_campaign_meta.json`

Forged-prefill dust-drain harness:
- `proof_harness/cat1_nomad_f1_stale_replica/src/MedusaBridgePrefillDustHarness.sol`
  - Actions: `action_tryForgedBugPrefill`, `action_tryForgedFixedPrefill`
  - Properties: `property_forged_prefill_cannot_drain_dust`, `property_fixed_model_blocks_forged_prefill`
- Standardized campaign artifacts:
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f7_prefill_dust_formal_medusa_30s.txt`
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f7_prefill_dust_formal_echidna_30s.txt`
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f7_prefill_dust_formal_campaign_meta.json`

Representation-alias swap harness:
- `proof_harness/cat1_nomad_f1_stale_replica/src/MedusaTokenRegistryAliasHarness.sol`
  - Actions: `action_tryBugAliasSwap`, `action_tryFixedAliasSwap`
  - Properties: `property_representation_alias_cannot_swap_assets`, `property_fixed_model_blocks_alias_swap`
- Standardized campaign artifacts:
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f8_alias_swap_formal_medusa_30s.txt`
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f8_alias_swap_formal_echidna_30s.txt`
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f8_alias_swap_formal_campaign_meta.json`

Governance domain-churn liveness harness:
- `proof_harness/cat1_nomad_f1_stale_replica/src/MedusaGovernanceDomainChurnHarness.sol`
  - Actions: `action_churn`, `action_dispatch`
  - Properties: `property_dispatch_scan_tracks_active_domains`, `property_fixed_model_avoids_scan_overhead`
- Standardized campaign artifacts:
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f9_domain_churn_formal_medusa_30s.txt`
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f9_domain_churn_formal_echidna_30s.txt`
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f9_domain_churn_formal_campaign_meta.json`

Migrate-alias canonical-swap harness:
- `proof_harness/cat1_nomad_f1_stale_replica/src/MedusaTokenRegistryMigrateHarness.sol`
  - Actions: `action_tryBugMigrateAliasSwap`, `action_tryFixedMigrateInvariant`
  - Properties: `property_migrate_cannot_swap_canonical_asset`, `property_fixed_model_blocks_migrate_alias_swap`
- Standardized campaign artifacts:
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f10_migrate_alias_formal_medusa_30s.txt`
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f10_migrate_alias_formal_echidna_30s.txt`
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f10_migrate_alias_formal_campaign_meta.json`

## Additional Observations (Not Yet Promoted To Proven Vulns)

### O1: `UpdaterManager.slashUpdater` is a no-op in this codebase snapshot

Relevant code:
- `solidity/nomad-core/contracts/UpdaterManager.sol`

Status:
- Marked as an explicit MVP trust model limitation, not a newly discovered bug.
- Operationally important because fraud detection does not enforce economic penalties here.

## Full-Source Parity Validation

Harness:
- `proof_harness/cat1_nomad_parity_fullsource`
- Uses copied full-source Nomad Solidity trees from mounted snapshot:
  - `solidity/nomad-core`
  - `solidity/nomad-xapps`
- Dependency versions pinned to match project era:
  - `openzeppelin-contracts v3.4.2`
  - `openzeppelin-contracts-upgradeable v3.4.2`
  - `memview-sol v2.0.0`

H1 parity replay (`BridgeRouter` / `TokenRegistry` migrate-alias path):
- Test:
  - `test_h1_full_source_parity_migrate_alias_sequence`
- Result:
  - full-source `BridgeRouter.migrate` reproduces alias-overwrite conversion path:
    - `oldReprToCurrentRepr(oldRepr)` resolves to canonical-B current representation,
    - user legacy representation balance is burned,
    - canonical-B representation balance is minted.
- Artifact:
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/h1_fullsource_parity_forge_test.txt`

H2 parity replay (`GovernanceRouter` domain churn gas slope):
- Test:
  - `test_h2_full_source_parity_governance_domain_churn_gas_slope`
- Result:
  - scan-slot growth parity matches model exactly: `scan_slots = loops + 1` with one active domain,
  - threshold crossings match model: `2x@100`, `3x@200`, `5x@400`,
  - absolute gas is lower than model baseline but slope pattern is preserved.
- Model-vs-full-source gas deltas:
  - baseline: `45,940` -> `39,930` (`-13.08%`)
  - loops 100: `122,040` -> `100,730` (`-17.46%`)
  - loops 200: `198,090` -> `161,480` (`-18.48%`)
  - loops 400: `350,240` -> `283,030` (`-19.19%`)
  - loops 800: `654,540` -> `526,130` (`-19.62%`)
  - loops 1200: `958,840` -> `769,230` (`-19.77%`)
- Artifacts:
  - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/h2_fullsource_parity_forge_test.txt`
  - Baseline comparison source:
    - `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f9_domain_churn_gas_profile_forge_test.txt`

## Hypotheses (Ranked Next Validation Targets)

H1: Full-source parity replay for F10 migrate-alias witness
- Goal: run the same migrate-alias sequence against the full Nomad contract tree to confirm identical behavior and gas profile.
- Validation: replay `TokenRegistryMigrateAliasSwap` sequence with concrete `BridgeRouter`/`TokenRegistry` contracts once the source snapshot is mounted.
- Status: validated. Full-source parity replay confirms migrate-alias behavior.

H2: Cross-repo parity check against full `GovernanceRouter` implementation snapshot
- Goal: replay the same churn sequence directly on the full Nomad contract tree and compare gas slope with harness model.
- Validation: run equivalent gas-profile test once `solidity/nomad-core` sources are mounted in this workspace.
- Status: validated. Full-source parity replay confirms churn slope/threshold behavior.

## Next Actions (Immediate)

1. Mark `nomad-monorepo` exhausted for this pass (high/medium findings and parity hypotheses evidence-closed).
2. Move immediately to next Cat1 repo in roadmap order: `LayerZero-v2`.

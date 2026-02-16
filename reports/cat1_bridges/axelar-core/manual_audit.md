# axelar-core (Manual Audit, Step 2/5)

Scope: `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\axelar-core`

HEAD: `f303a5aa961771b475b63bce433ed3b0e6cf3b1a`

Pass status: Blocked for runtime-confirmation follow-up in this pass (`A1/A2` proven; `H3` still open due private-module blocker).

Primary scope (this pass):
- Runtime bridge paths in:
  - `x/axelarnet/*`
  - `x/evm/*`
  - `x/nexus/*`

Non-goals (this pass):
- CLI/codegen-only paths and docs toolchain unless directly reachable from runtime bridge execution.

## Protocol Snapshot (Core + AxelarNet + EVM Plane)

- App wiring for bridge-critical modules is in `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\axelar-core\app\app.go`:
  - Nexus chain/message routing and transfer registry.
  - EVM command/event handling.
  - Validator vote/multisig/tss stack.
  - Permission enforcement via ante decorators.
- AxelarNet receive path:
  - `OnRecvMessage(...)` in `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\axelar-core\x\axelarnet\message_handler.go`
  - Parses ICS20 packet, validates receiver/memo, resolves chain path, and routes GMP/token actions.
- EVM confirmation/command path:
  - Msg handlers in `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\axelar-core\x\evm\keeper\msg_server.go`
  - End-block processing in `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\axelar-core\x\evm\abci.go`.

## Critical Invariants

- Input-hardening invariant:
  - Untrusted IBC packet fields must return deterministic errors/acks; they must not trigger panics in receive handlers.
- Key-rotation integrity:
  - Operatorship transitions should require intended authority/evidence flow.
- Cross-chain event authenticity:
  - Confirmed EVM events should not enter command execution queues without valid vote/proof or explicit privileged override.
- Transfer accounting integrity:
  - Lock/enqueue/archive transitions should preserve asset conservation and status monotonicity.

## Entry Points Map (High Impact)

- AxelarNet inbound:
  - `OnRecvMessage(...)` in `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\axelar-core\x\axelarnet\message_handler.go`
- EVM privileged/liveness:
  - `ConfirmTransferKey(...)`
  - `CreateBurnTokens(...)`
  - `CreatePendingTransfers(...)`
  - `SignCommands(...)`
  - all in `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\axelar-core\x\evm\keeper\msg_server.go`
- Nexus chain state controls:
  - `ActivateChain(...)`
  - `DeactivateChain(...)`
  - in `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\axelar-core\x\nexus\keeper\msg_server.go`

## Proven Findings

### A1: Uppercase receiver filter in AxelarNet IBC path can panic on malformed uppercase receiver strings

Severity: Medium (packet-level liveness/ack-path DoS risk)

Affected code:
- `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\axelar-core\x\axelarnet\message_handler.go:109`
  - `OnRecvMessage(...)` calls `validateReceiver(...)` before message routing.
- `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\axelar-core\x\axelarnet\message_handler.go:430`
  - `validateReceiver(...)` branches on `strings.ToUpper(receiver) == receiver`.
- `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\axelar-core\x\axelarnet\message_handler.go:431`
  - Uses `funcs.Must(sdk.AccAddressFromBech32(receiver))`.
- `C:\Users\vboxuser\go\pkg\mod\github.com\axelarnetwork\utils@v0.0.0-20251121135440-7d92b8abb3a7\funcs\funcs.go:19`
  - `funcs.Must(...)` panics on non-nil error.
- `C:\Users\vboxuser\go\pkg\mod\github.com\cosmos\ibc-go\v8@v8.6.1\modules\apps\transfer\types\packet.go:50`
  - ICS20 `ValidateBasic()` explicitly does not validate sender/receiver address formats; it only enforces non-blank values.

Root cause:
- The uppercase receiver guard calls a panic-on-error helper (`funcs.Must`) on an untrusted packet field that is not guaranteed to be bech32-valid by ICS20 packet validation.

Concrete witness sequence:
1. Attacker sends ICS20 packet with non-empty uppercase receiver string that is not valid bech32 (for example `ABCDEF`).
2. Packet passes ICS20 basic validation because receiver format is not bech32-validated (only non-empty check).
3. AxelarNet `OnRecvMessage(...)` invokes `validateReceiver(...)`.
4. Uppercase branch executes and calls `sdk.AccAddressFromBech32(receiver)` via `funcs.Must(...)`.
5. Bech32 parse fails; `funcs.Must(...)` panics.
6. Handler panics instead of returning a normal `ErrorAcknowledgement`, enabling packet-level griefing/liveness degradation.

Impact:
- Untrusted packet data can deterministically trigger a panic in the receive handler path.
- Depending on panic-recovery and relaying behavior, this can suppress immediate error-ack handling and degrade IBC packet liveness (stuck/retry-until-timeout behavior).

Recommended fix:
- Replace panic-on-error parsing in `validateReceiver(...)` with explicit error handling:
  - parse receiver with `AccAddressFromBech32`;
  - on parse error, return a normal validation error (no panic);
  - keep uppercase-GMP-address rejection logic only for successfully parsed addresses.
- Add a regression test for uppercase non-bech32 receiver strings.

Executable witness status:
- Direct runtime test execution attempt was blocked by private module resolution:
  - `go test ./x/axelarnet -run TestHandleMessage -count=1`
  - blocker artifact: `reports/cat1_bridges/axelar-core/artifacts/manual_go_test_axelarnet_blocked.txt`
- Static witness (code-level reachability + panic semantics) satisfies proof for this pass.

### A2: `RetryFailedEvent` requeues failed events without persistent status transition, causing deterministic end-block panic

Severity: High (permissionless chain-halt trigger once any failed event exists)

Affected code:
- `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\axelar-core\proto\axelar\evm\v1beta1\tx.proto:396`
  - `RetryFailedEventRequest` is marked `ROLE_UNRESTRICTED`.
- `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\axelar-core\x\evm\keeper\msg_server.go:908`
  - `RetryFailedEvent(...)` entrypoint.
- `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\axelar-core\x\evm\keeper\msg_server.go:930`
  - requires `event.Status == EventFailed`.
- `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\axelar-core\x\evm\keeper\msg_server.go:934`
  - mutates only local copy: `event.Status = EventConfirmed`.
- `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\axelar-core\x\evm\keeper\msg_server.go:935`
  - enqueues event directly; no persistent store update for event status.
- `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\axelar-core\x\evm\keeper\chainKeeper.go:913`
  - `SetEventCompleted(...)` rejects if stored status is not `EventConfirmed`.
- `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\axelar-core\x\evm\keeper\chainKeeper.go:933`
  - `SetEventFailed(...)` rejects if stored status is not `EventConfirmed`.
- `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\axelar-core\x\evm\abci.go:566`
  - end-block calls `funcs.MustNoErr(ck.SetEventFailed(...))`.
- `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\axelar-core\x\evm\abci.go:570`
  - end-block calls `funcs.MustNoErr(ck.SetEventCompleted(...))`.

Root cause:
- The retry path enqueues an in-memory `EventConfirmed` copy, but does not persist the event status transition (`Failed -> Confirmed`) in the event store.
- End-block logic assumes the stored status is already `EventConfirmed` and hard-panics (`MustNoErr`) when that assumption is violated.

Concrete witness sequence:
1. Event `E` exists in store with status `EventFailed`.
2. Any account submits `RetryFailedEvent(E)` (request role is unrestricted).
3. Handler checks `EventFailed`, sets only local `event.Status = EventConfirmed`, enqueues `E`, and returns success.
4. Persistent store status for `E` remains `EventFailed`.
5. End-block dequeues retried `E` and processes it.
6. End-block then calls `SetEventCompleted(E)` on success path or `SetEventFailed(E)` on failure path.
7. Both setters require stored status `EventConfirmed`; both return error because store still has `EventFailed`.
8. `funcs.MustNoErr(...)` panics in end-block, creating deterministic panic/halting risk (with default non-zero `EndBlockerLimit`).

Impact:
- Any unrestricted caller can trigger a deterministic end-block panic whenever at least one failed event exists.
- This creates a consensus-liveness DoS lever on the retry endpoint.
- Operational retry workflow for failed events is unsafe in current form.

Recommended fix:
- In `RetryFailedEvent`, persist the status transition before queue enqueue (e.g., explicit store update `Failed -> Confirmed`).
- Add a guardrail test that runs retry + end-block and asserts no panic.
- Replace panic-on-error in end-block (`MustNoErr`) with explicit error handling to avoid chain-halting on recoverable state mismatches.

Executable witness status:
- Focused runtime test attempt was blocked by private module resolution:
  - `go test ./x/evm -run TestRetryFailedEvent -count=1`
  - blocker artifact: `reports/cat1_bridges/axelar-core/artifacts/manual_go_test_retry_failed_event_blocked.txt`
- Existing unit test coverage for retry currently verifies enqueue behavior only:
  - `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\axelar-core\x\evm\keeper\msg_server_test.go:1462`
  - no end-block follow-through assertion in that test path.
- Static witness (state transition + end-block panic path) satisfies proof for this pass.

## Validated / Not Promoted Hypotheses

### H1: Chain-management can force key-transfer confirmation without tx-proof poll

Severity: Trust-boundary assumption (high impact only if `ROLE_CHAIN_MANAGEMENT` is compromised)

Evidence:
- `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\axelar-core\x\evm\keeper\msg_server.go:439`
  - privileged branch skips poll and synthesizes confirmed operatorship event.
- `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\axelar-core\proto\axelar\evm\v1beta1\tx.proto:396`
  - request role metadata is unrestricted; privilege is enforced in handler role check.
- Unit-test intent is explicit in:
  - `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\axelar-core\x\evm\keeper\msg_server_test.go:1462`

Assessment:
- Explicit emergency/governance design, not an unintended bypass in this pass.

Status: validated behavior, not promoted.

### H3: Runtime-relevant dependency advisories require call-path proof

Severity: Pending triage

Evidence:
- OSV flags runtime libraries (`go-ethereum`, `btcd` class advisories), but reachability in active Axelar execution paths remains unproven.
- `govulncheck` symbol-level triage is blocked by private replacement dependency.

Status: open, not promoted.

## Tool Triage + Blockers

- `gitleaks`: 42 generic-api-key matches in generated/static docs; no runtime secret promoted.
- `gosec`: 5 findings concentrated in CLI/codegen/local file paths; not promoted as bridge runtime vulnerabilities.
- `govulncheck`:
  - blocked by unresolved private module replace target
  - evidence: `reports/cat1_bridges/axelar-core/artifacts/govulncheck.json.stderr.log`
- `go test` runtime witness attempt:
  - blocked by same private module dependency
  - evidence:
    - `reports/cat1_bridges/axelar-core/artifacts/manual_go_test_axelarnet_blocked.txt`
    - `reports/cat1_bridges/axelar-core/artifacts/manual_go_test_retry_failed_event_blocked.txt`
- Specialist EVM fuzzers (`foundry/medusa/halmos/echidna`):
  - not directly applicable to promoted findings in this pass (`A1/A2`) because both vulnerable paths are Go runtime logic.

## Hypotheses (Ranked)

A1: malformed uppercase receiver triggers panic in IBC receive path.
- Status: validated and promoted (proven).

A2: unrestricted failed-event retry path can panic end blocker due status transition mismatch.
- Status: validated and promoted (proven).

H1: forced key-transfer confirmation blast radius under compromised chain-management authority.
- Status: validated behavior, not promoted.

H3: dependency advisories (`go-ethereum`/`btcd`) are reachable in bridge-critical runtime path.
- Status: open; symbol-level tooling blocked.

## Next Actions

1. Keep target-code unchanged in this workflow; retain remediation recommendations in report form (`A1/A2`).
2. After private module access is restored, run focused `x/axelarnet` and `x/evm` tests to capture runtime witnesses for `A1/A2`.
3. Continue `H3` call-path triage and promote only witness-backed dependency issues.

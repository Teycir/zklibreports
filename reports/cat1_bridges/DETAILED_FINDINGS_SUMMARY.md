## Grouped by Vulnerability Type

1. `Initialization/upgrade first-caller takeover windows`
Covers `telepathy-contracts` (`F1`).
Shared business impact is unauthorized control capture during non-atomic deploy/upgrade windows, enabling fund diversion, state tampering, and emergency governance recovery.
2. `Authorization/governance control compromise and stale-trust acceptance`
Covers `nomad-monorepo` (`F4`), `nomad-monorepo` (`F5`), `LayerZero-v2` (`LZ2`), `nomad-monorepo` (`F1`), `nomad-monorepo` (`F3`), `nomad-monorepo` (`F6`), `synapse-contracts` (`F2`), `wormhole` (`W2`), `nomad-monorepo` (`F2`).
Shared business impact is privilege-boundary failure: stale actors retain power, governance trust assumptions break, and high-impact control-plane actions become attacker-reachable.
3. `Collateral/accounting insolvency and economic leakage`
Covers `connext-monorepo` (`F1`), `connext-monorepo` (`F2`), `connext-monorepo` (`F3`), `hyperlane-monorepo` (`H1`), `hyperlane-monorepo` (`H2`), `hyperlane-monorepo` (`H3`), `LayerZero-v2` (`LZ1`), `LayerZero-v2` (`LZ3`), `LayerZero-v2` (`LZ4`), `nomad-monorepo` (`F7`), `synapse-contracts` (`F1`), `synapse-contracts` (`F3`), `wormhole` (`W3`).
Shared business impact is value-conservation failure: liabilities are over-credited or reserves are sweepable, producing token-specific insolvency, payout shortfalls, and user loss scenarios.
4. `Runtime liveness and DoS via unsafe input/state handling`
Covers `axelar-core` (`A2`), `axelar-core` (`A1`), `nomad-monorepo` (`F9`), `wormhole` (`W1`).
Shared business impact is deterministic liveness degradation from panic/DoS-prone paths, increasing downtime risk, incident cost, and partner/user confidence damage.
5. `Token identity/migration integrity breaks`
Covers `nomad-monorepo` (`F10`), `nomad-monorepo` (`F8`).
Shared business impact is asset-identity drift across chains, enabling unintended cross-asset remapping and migration outcomes that violate canonical accounting assumptions.

### nomad-monorepo - F4 (`Critical`)
- Vulnerability type category: `Authorization/governance control compromise and stale-trust acceptance`
- [1] Program/Payout mapping: Policy class: `Access Control / Authorization Integrity / Governance Trust Boundary`; severity tier: `Critical`; target payout band: `$50k-$250k+ (program-cap dependent)`; recommended claim framing: exploitable security defect with deterministic proof artifact.
- [2] Affected scope (exact): Repo `nomad-monorepo`; component/function `Retired replica can forge TransferGovernor handling and seize local governor privileges`; audit reference `reports/cat1_bridges/nomad-monorepo/report.md`; reviewed commit hash: `f326b402285e3255a654e5e44c919ce412c2bed0`; fixed commit hash: `not provided`; affected release/version range: `TBD-pin-before-submission`.
- [3] Production exploitability verdict: Direct once stale authorization or trust-boundary preconditions are present.
- [4] Deterministic repro evidence: witness artifacts (`f4_echidna_governance_takeover_30s.txt`, `f4_governance_takeover_forge_test.txt`, `f4_governance_takeover_fuzz_5000_runs.txt`, `f4_medusa_governance_takeover_30s.txt`). Validation reference: `reports/cat1_bridges/<repo>/manual_audit.md` + listed witness files.
- [5] Mitigation gap proof: Operational policy does not reliably enforce revocation/current-trust invariants; stale roles/replicas/keys can remain exploitable without contract-level invariant checks.
- [6] Business impact quantification: Use the very-high loss range below as anchor; include likely 4-72h emergency-response and governance escalation overhead.
- [7] Abuse narrative: Attacker exploits stale or improperly revoked trust relationships to execute privileged calls that appear structurally valid.
- [8] Fix plan + cost: Patch plan: enforce current-trust checks, stale-role revocation invariants, and privileged-path authorization hardening. Estimated effort: 5-14 engineer-days + 2-4 QA days. Estimated remediation cost: ~$40k-$160k including retest.
- Direct exploitation status: Direct once stale authorization or trust-boundary preconditions are present.
- Mitigation status:
1. Contract-level: not fully mitigated in audited snapshot; witness remains reproducible in referenced artifacts.
2. Operational: compensating controls are partial unless invariant-enforced code changes are deployed and verified.
- Estimated attacker cost: low-to-medium (~$500-$50,000) for monitoring, prioritized inclusion, and follow-on calls.
- Estimated loss range: very high (~$10M-$1B+) depending bridged TVL/control-plane scope and incident duration.
- Primary mitigation layer: `Contract authorization/trust-boundary hardening`
- Mitigation feasibility: `Medium`
- Residual risk if truly mitigated: `Medium`
- Repo-specific manual check: Verify stale roles/replicas/keys are fully revoked and privileged paths enforce current-trust invariants.
- Mitigation acceptance criteria: `Implemented` (fix exists at reviewed commit), `Enforced` (no bypass path exists), and `Demonstrated` (tests/witnesses show the same exploit path is blocked).
- Business impact:
1. Local governance privilege takeover on affected chains.
2. Attacker can execute `onlyGovernor` paths (e.g. router management and governance dispatch).
3. This is a direct escalation from stale auth state into control-plane compromise.
- Preconditions:
1. Stale or over-broad authorization state exists (replica/delegate/guardian/admin trust boundary).
2. Privileged path accepts that stale state as valid caller/proof source.
3. Attacker can invoke the affected call path without target-code modification.
- Detailed execution:
1. Enroll replica `R1` for domain `D`.
2. Re-enroll `R2` for the same domain `D` (intended retirement of `R1`).
3. Governance sink updates `governor = attacker`.
4. Attacker executes privileged governor-only state mutation.
- Post-exploit objective:
1. Local governance privilege takeover on affected chains.
2. Attacker can execute `onlyGovernor` paths (e.g. router management and governance dispatch).
3. This is a direct escalation from stale auth state into control-plane compromise.

### nomad-monorepo - F5 (`Critical`)
- Vulnerability type category: `Authorization/governance control compromise and stale-trust acceptance`
- [1] Program/Payout mapping: Policy class: `Access Control / Authorization Integrity / Governance Trust Boundary`; severity tier: `Critical`; target payout band: `$50k-$250k+ (program-cap dependent)`; recommended claim framing: exploitable security defect with deterministic proof artifact.
- [2] Affected scope (exact): Repo `nomad-monorepo`; component/function `Retired replica can inject forged governance batch and execute privileged calls via executeCallBatch`; audit reference `reports/cat1_bridges/nomad-monorepo/report.md`; reviewed commit hash: `f326b402285e3255a654e5e44c919ce412c2bed0`; fixed commit hash: `not provided`; affected release/version range: `TBD-pin-before-submission`.
- [3] Production exploitability verdict: Direct once stale authorization or trust-boundary preconditions are present.
- [4] Deterministic repro evidence: witness artifacts (`f5_batch_injection_forge_test.txt`, `f5_batch_injection_formal_v2_campaign_meta.json`, `f5_batch_injection_formal_v2_medusa_8s.txt`, `f5_batch_injection_fuzz_5000_runs.txt`). Validation reference: `reports/cat1_bridges/<repo>/manual_audit.md` + listed witness files.
- [5] Mitigation gap proof: Operational policy does not reliably enforce revocation/current-trust invariants; stale roles/replicas/keys can remain exploitable without contract-level invariant checks.
- [6] Business impact quantification: Use the very-high loss range below as anchor; include likely 4-72h emergency-response and governance escalation overhead.
- [7] Abuse narrative: Attacker exploits stale or improperly revoked trust relationships to execute privileged calls that appear structurally valid.
- [8] Fix plan + cost: Patch plan: enforce current-trust checks, stale-role revocation invariants, and privileged-path authorization hardening. Estimated effort: 5-14 engineer-days + 2-4 QA days. Estimated remediation cost: ~$40k-$160k including retest.
- Direct exploitation status: Direct once stale authorization or trust-boundary preconditions are present.
- Mitigation status:
1. Contract-level: not fully mitigated in audited snapshot; witness remains reproducible in referenced artifacts.
2. Operational: compensating controls are partial unless invariant-enforced code changes are deployed and verified.
- Estimated attacker cost: low-to-medium (~$500-$50,000) for monitoring, prioritized inclusion, and follow-on calls.
- Estimated loss range: very high (~$10M-$1B+) depending bridged TVL/control-plane scope and incident duration.
- Primary mitigation layer: `Contract authorization/trust-boundary hardening`
- Mitigation feasibility: `Medium`
- Residual risk if truly mitigated: `Medium`
- Repo-specific manual check: Verify stale roles/replicas/keys are fully revoked and privileged paths enforce current-trust invariants.
- Mitigation acceptance criteria: `Implemented` (fix exists at reviewed commit), `Enforced` (no bypass path exists), and `Demonstrated` (tests/witnesses show the same exploit path is blocked).
- Business impact:
1. Direct arbitrary governance-call execution path without requiring explicit `governor` transfer first.
2. Compromises governance control plane (router management, governance dispatch, and other privileged local actions).
3. Independent critical exploitation path from stale auth state.
- Preconditions:
1. Stale or over-broad authorization state exists (replica/delegate/guardian/admin trust boundary).
2. Privileged path accepts that stale state as valid caller/proof source.
3. Attacker can invoke the affected call path without target-code modification.
- Detailed execution:
1. Enroll replica `R1` for domain `D`.
2. Re-enroll `R2` for the same domain `D` (intended retirement of `R1`).
3. Retired `R1` calls governance sink `handle(...)` with a forged batch message committing to a call batch.
4. External caller invokes `executeCallBatch(calls)` with matching batch hash.
5. Batch executes `onlyGovernor`-gated local state mutation via `address(this)` context.
- Post-exploit objective:
1. Direct arbitrary governance-call execution path without requiring explicit `governor` transfer first.
2. Compromises governance control plane (router management, governance dispatch, and other privileged local actions).
3. Independent critical exploitation path from stale auth state.

### axelar-core - A2 (`High`)
- Vulnerability type category: `Runtime liveness and DoS via unsafe input/state handling`
- [1] Program/Payout mapping: Policy class: `Availability / Input Validation / Runtime Safety`; severity tier: `High`; target payout band: `$15k-$100k (program-cap dependent)`; recommended claim framing: exploitable security defect with deterministic proof artifact.
- [2] Affected scope (exact): Repo `axelar-core`; component/function `RetryFailedEvent requeues failed events without persistent status transition, causing deterministic end-block panic`; audit reference `reports/cat1_bridges/axelar-core/report.md`; reviewed commit hash: `f303a5aa961771b475b63bce433ed3b0e6cf3b1a`; fixed commit hash: `not provided`; affected release/version range: `TBD-pin-before-submission`.
- [3] Production exploitability verdict: Direct permissionless liveness DoS via unrestricted retry path on failed events.
- [4] Deterministic repro evidence: witness artifacts (`manual_go_test_retry_failed_event_blocked.txt`). Validation reference: `reports/cat1_bridges/<repo>/manual_audit.md` + listed witness files.
- [5] Mitigation gap proof: Input filters and operational guards are incomplete; panic-prone or unbounded paths remain reachable until converted to explicit error-handled flows.
- [6] Business impact quantification: Use the high loss range below with expected 2-48h incident handling and multi-team recovery costs.
- [7] Abuse narrative: Attacker repeatedly submits crafted inputs/state transitions that trigger panic/revert-heavy liveness failures.
- [8] Fix plan + cost: Patch plan: replace panic paths with explicit errors, add adversarial input tests, and bound liveness-sensitive loops. Estimated effort: 3-9 engineer-days + 1-3 QA days. Estimated remediation cost: ~$20k-$100k including retest.
- Direct exploitation status: Direct permissionless liveness DoS via unrestricted retry path on failed events.
- Mitigation status:
1. Contract-level: not fully mitigated in audited snapshot; witness remains reproducible in referenced artifacts.
2. Operational: compensating controls are partial unless invariant-enforced code changes are deployed and verified.
- Estimated attacker cost: low-to-medium (~$300-$25,000) depending role/timing requirements.
- Estimated loss range: high (~$1M-$250M) from control-plane abuse, halted flows, and restitution/recovery burden.
- Primary mitigation layer: `Input validation + panic-free runtime handling`
- Mitigation feasibility: `High`
- Residual risk if truly mitigated: `Low-Medium`
- Repo-specific manual check: Verify untrusted inputs fail gracefully (no panic/chain-halt) and liveness-sensitive loops remain bounded under adversarial sequences.
- Mitigation acceptance criteria: `Implemented` (fix exists at reviewed commit), `Enforced` (no bypass path exists), and `Demonstrated` (tests/witnesses show the same exploit path is blocked).
- Business impact:
1. Any unrestricted caller can trigger a deterministic end-block panic whenever at least one failed event exists.
2. This creates a consensus-liveness DoS lever on the retry endpoint.
3. Operational retry workflow for failed events is unsafe in current form.
- Preconditions:
1. Untrusted input/state can reach panic-prone or expensive runtime path.
2. Fail-fast behavior is panic/revert-heavy instead of explicit bounded error handling.
3. Attacker can repeatedly trigger the path with low-cost transactions/messages.
- Detailed execution:
1. Event `E` exists in store with status `EventFailed`.
2. Any account submits `RetryFailedEvent(E)` (request role is unrestricted).
3. Handler checks `EventFailed`, sets only local `event.Status = EventConfirmed`, enqueues `E`, and returns success.
4. Persistent store status for `E` remains `EventFailed`.
5. End-block dequeues retried `E` and processes it.
6. End-block then calls `SetEventCompleted(E)` on success path or `SetEventFailed(E)` on failure path.
7. Both setters require stored status `EventConfirmed`; both return error because store still has `EventFailed`.
- Post-exploit objective:
1. Any unrestricted caller can trigger a deterministic end-block panic whenever at least one failed event exists.
2. This creates a consensus-liveness DoS lever on the retry endpoint.
3. Operational retry workflow for failed events is unsafe in current form.

### LayerZero-v2 - LZ2 (`High`)
- Vulnerability type category: `Authorization/governance control compromise and stale-trust acceptance`
- [1] Program/Payout mapping: Policy class: `Access Control / Authorization Integrity / Governance Trust Boundary`; severity tier: `High`; target payout band: `$15k-$100k (program-cap dependent)`; recommended claim framing: exploitable security defect with deterministic proof artifact.
- [2] Affected scope (exact): Repo `LayerZero-v2`; component/function `Endpoint delegate privilege can persist after OApp ownership transfer and retain config control`; audit reference `reports/cat1_bridges/LayerZero-v2/report.md`; reviewed commit hash: `ab9b083410b9359285a5756807e1b6145d4711a7`; fixed commit hash: `not provided`; affected release/version range: `TBD-pin-before-submission`.
- [3] Production exploitability verdict: Role-contingent: exploitable by stale delegate key if ownership handoff does not rotate delegate authority.
- [4] Deterministic repro evidence: witness artifacts (`lz1_lz2_forge_test.txt`, `lz1_lz2_fuzz_5000_runs.txt`, `lz2_stale_delegate_formal_campaign_meta.json`, `lz2_stale_delegate_formal_echidna_30s.txt`). Validation reference: `reports/cat1_bridges/<repo>/manual_audit.md` + listed witness files.
- [5] Mitigation gap proof: Operational policy does not reliably enforce revocation/current-trust invariants; stale roles/replicas/keys can remain exploitable without contract-level invariant checks.
- [6] Business impact quantification: Use the high loss range below with expected 2-48h incident handling and multi-team recovery costs.
- [7] Abuse narrative: Attacker exploits stale or improperly revoked trust relationships to execute privileged calls that appear structurally valid.
- [8] Fix plan + cost: Patch plan: enforce current-trust checks, stale-role revocation invariants, and privileged-path authorization hardening. Estimated effort: 5-14 engineer-days + 2-4 QA days. Estimated remediation cost: ~$40k-$160k including retest.
- Direct exploitation status: Role-contingent: exploitable by stale delegate key if ownership handoff does not rotate delegate authority.
- Mitigation status:
1. Contract-level: not fully mitigated in audited snapshot; witness remains reproducible in referenced artifacts.
2. Operational: compensating controls are partial unless invariant-enforced code changes are deployed and verified.
- Estimated attacker cost: low-to-medium (~$300-$25,000) depending role/timing requirements.
- Estimated loss range: high (~$1M-$250M) from control-plane abuse, halted flows, and restitution/recovery burden.
- Primary mitigation layer: `Contract authorization/trust-boundary hardening`
- Mitigation feasibility: `Medium`
- Residual risk if truly mitigated: `Medium`
- Repo-specific manual check: Verify stale roles/replicas/keys are fully revoked and privileged paths enforce current-trust invariants.
- Mitigation acceptance criteria: `Implemented` (fix exists at reviewed commit), `Enforced` (no bypass path exists), and `Demonstrated` (tests/witnesses show the same exploit path is blocked).
- Business impact:
1. Stale key can keep mutating endpoint config after intended ownership handoff.
2. Can force message-path DoS or undesired library changes until delegate is explicitly rotated.
- Preconditions:
1. Stale or over-broad authorization state exists (replica/delegate/guardian/admin trust boundary).
2. Privileged path accepts that stale state as valid caller/proof source.
3. Attacker can invoke the affected call path without target-code modification.
- Detailed execution:
1. OApp is initialized with delegate `D` (same actor as initial owner).
2. Ownership is transferred to `N`.
3. Old delegate `D` still satisfies endpoint auth for that OApp.
4. `D` updates send-library configuration to blocked library for an endpoint id.
- Post-exploit objective:
1. Stale key can keep mutating endpoint config after intended ownership handoff.
2. Can force message-path DoS or undesired library changes until delegate is explicitly rotated.

### nomad-monorepo - F1 (`High`)
- Vulnerability type category: `Authorization/governance control compromise and stale-trust acceptance`
- [1] Program/Payout mapping: Policy class: `Access Control / Authorization Integrity / Governance Trust Boundary`; severity tier: `High`; target payout band: `$15k-$100k (program-cap dependent)`; recommended claim framing: exploitable security defect with deterministic proof artifact.
- [2] Affected scope (exact): Repo `nomad-monorepo`; component/function `Stale replicas remain authorized after domain re-enrollment (Auth boundary break)`; audit reference `reports/cat1_bridges/nomad-monorepo/report.md`; reviewed commit hash: `f326b402285e3255a654e5e44c919ce412c2bed0`; fixed commit hash: `not provided`; affected release/version range: `TBD-pin-before-submission`.
- [3] Production exploitability verdict: Direct once stale authorization or trust-boundary preconditions are present.
- [4] Deterministic repro evidence: witness artifacts (`f1_fuzz_5000_runs.txt`, `f1_medusa_failfast_30s.txt`, `f1_stale_replica_forge_test.txt`). Validation reference: `reports/cat1_bridges/<repo>/manual_audit.md` + listed witness files.
- [5] Mitigation gap proof: Operational policy does not reliably enforce revocation/current-trust invariants; stale roles/replicas/keys can remain exploitable without contract-level invariant checks.
- [6] Business impact quantification: Use the high loss range below with expected 2-48h incident handling and multi-team recovery costs.
- [7] Abuse narrative: Attacker exploits stale or improperly revoked trust relationships to execute privileged calls that appear structurally valid.
- [8] Fix plan + cost: Patch plan: enforce current-trust checks, stale-role revocation invariants, and privileged-path authorization hardening. Estimated effort: 5-14 engineer-days + 2-4 QA days. Estimated remediation cost: ~$40k-$160k including retest.
- Direct exploitation status: Direct once stale authorization or trust-boundary preconditions are present.
- Mitigation status:
1. Contract-level: not fully mitigated in audited snapshot; witness remains reproducible in referenced artifacts.
2. Operational: compensating controls are partial unless invariant-enforced code changes are deployed and verified.
- Estimated attacker cost: low-to-medium (~$300-$25,000) depending role/timing requirements.
- Estimated loss range: high (~$1M-$250M) from control-plane abuse, halted flows, and restitution/recovery burden.
- Primary mitigation layer: `Contract authorization/trust-boundary hardening`
- Mitigation feasibility: `Medium`
- Residual risk if truly mitigated: `Medium`
- Repo-specific manual check: Verify stale roles/replicas/keys are fully revoked and privileged paths enforce current-trust invariants.
- Mitigation acceptance criteria: `Implemented` (fix exists at reviewed commit), `Enforced` (no bypass path exists), and `Demonstrated` (tests/witnesses show the same exploit path is blocked).
- Business impact:
1. Attempted emergency rotation does not fully revoke previous replica authority.
2. If an old replica is compromised or otherwise untrusted, it can still pass `onlyReplica` gates in bridge and governance receivers.
3. This directly weakens the intended trust boundary during incident response.
- Preconditions:
1. Stale or over-broad authorization state exists (replica/delegate/guardian/admin trust boundary).
2. Privileged path accepts that stale state as valid caller/proof source.
3. Attacker can invoke the affected call path without target-code modification.
- Detailed execution:
1. Attacker identifies a reachable entrypoint for the affected component.
2. Attacker triggers the vulnerable state transition or accounting path described in the finding.
3. System reaches the invalid state while normal controls fail to prevent or roll back the action.
- Post-exploit objective:
1. Attempted emergency rotation does not fully revoke previous replica authority.
2. If an old replica is compromised or otherwise untrusted, it can still pass `onlyReplica` gates in bridge and governance receivers.
3. This directly weakens the intended trust boundary during incident response.

### nomad-monorepo - F3 (`High`)
- Vulnerability type category: `Authorization/governance control compromise and stale-trust acceptance`
- [1] Program/Payout mapping: Policy class: `Access Control / Authorization Integrity / Governance Trust Boundary`; severity tier: `High`; target payout band: `$15k-$100k (program-cap dependent)`; recommended claim framing: exploitable security defect with deterministic proof artifact.
- [2] Affected scope (exact): Repo `nomad-monorepo`; component/function `Retired replica can still pass sink auth (onlyReplica + onlyRemoteRouter) and execute handle`; audit reference `reports/cat1_bridges/nomad-monorepo/report.md`; reviewed commit hash: `f326b402285e3255a654e5e44c919ce412c2bed0`; fixed commit hash: `not provided`; affected release/version range: `TBD-pin-before-submission`.
- [3] Production exploitability verdict: Direct once stale authorization or trust-boundary preconditions are present.
- [4] Deterministic repro evidence: witness artifacts (`f3_echidna_sink_auth_30s.txt`, `f3_medusa_sink_auth_30s.txt`). Validation reference: `reports/cat1_bridges/<repo>/manual_audit.md` + listed witness files.
- [5] Mitigation gap proof: Operational policy does not reliably enforce revocation/current-trust invariants; stale roles/replicas/keys can remain exploitable without contract-level invariant checks.
- [6] Business impact quantification: Use the high loss range below with expected 2-48h incident handling and multi-team recovery costs.
- [7] Abuse narrative: Attacker exploits stale or improperly revoked trust relationships to execute privileged calls that appear structurally valid.
- [8] Fix plan + cost: Patch plan: enforce current-trust checks, stale-role revocation invariants, and privileged-path authorization hardening. Estimated effort: 5-14 engineer-days + 2-4 QA days. Estimated remediation cost: ~$40k-$160k including retest.
- Direct exploitation status: Direct once stale authorization or trust-boundary preconditions are present.
- Mitigation status:
1. Contract-level: not fully mitigated in audited snapshot; witness remains reproducible in referenced artifacts.
2. Operational: compensating controls are partial unless invariant-enforced code changes are deployed and verified.
- Estimated attacker cost: low-to-medium (~$300-$25,000) depending role/timing requirements.
- Estimated loss range: high (~$1M-$250M) from control-plane abuse, halted flows, and restitution/recovery burden.
- Primary mitigation layer: `Contract authorization/trust-boundary hardening`
- Mitigation feasibility: `Medium`
- Residual risk if truly mitigated: `Medium`
- Repo-specific manual check: Verify stale roles/replicas/keys are fully revoked and privileged paths enforce current-trust invariants.
- Mitigation acceptance criteria: `Implemented` (fix exists at reviewed commit), `Enforced` (no bypass path exists), and `Demonstrated` (tests/witnesses show the same exploit path is blocked).
- Business impact:
1. Rotation does not actually revoke stale replicas at sink boundaries.
2. Any retired replica that can still transact can keep delivering authenticated-looking xApp messages.
3. This upgrades F1 from mapping inconsistency to direct sink reachability.
- Preconditions:
1. Stale or over-broad authorization state exists (replica/delegate/guardian/admin trust boundary).
2. Privileged path accepts that stale state as valid caller/proof source.
3. Attacker can invoke the affected call path without target-code modification.
- Detailed execution:
1. Attacker identifies a reachable entrypoint for the affected component.
2. Attacker triggers the vulnerable state transition or accounting path described in the finding.
3. System reaches the invalid state while normal controls fail to prevent or roll back the action.
- Post-exploit objective:
1. Rotation does not actually revoke stale replicas at sink boundaries.
2. Any retired replica that can still transact can keep delivering authenticated-looking xApp messages.
3. This upgrades F1 from mapping inconsistency to direct sink reachability.

### nomad-monorepo - F6 (`High`)
- Vulnerability type category: `Authorization/governance control compromise and stale-trust acceptance`
- [1] Program/Payout mapping: Policy class: `Access Control / Authorization Integrity / Governance Trust Boundary`; severity tier: `High`; target payout band: `$15k-$100k (program-cap dependent)`; recommended claim framing: exploitable security defect with deterministic proof artifact.
- [2] Affected scope (exact): Repo `nomad-monorepo`; component/function `Bootstrap committed root is immediately acceptable (optimistic timeout bypass at initialization boundary)`; audit reference `reports/cat1_bridges/nomad-monorepo/report.md`; reviewed commit hash: `f326b402285e3255a654e5e44c919ce412c2bed0`; fixed commit hash: `not provided`; affected release/version range: `TBD-pin-before-submission`.
- [3] Production exploitability verdict: Direct once stale authorization or trust-boundary preconditions are present.
- [4] Deterministic repro evidence: witness artifacts (`f6_bootstrap_timeout_forge_test.txt`, `f6_bootstrap_timeout_formal_campaign_meta.json`, `f6_bootstrap_timeout_formal_echidna_30s.txt`, `f6_bootstrap_timeout_formal_medusa_30s.txt`). Validation reference: `reports/cat1_bridges/<repo>/manual_audit.md` + listed witness files.
- [5] Mitigation gap proof: Operational policy does not reliably enforce revocation/current-trust invariants; stale roles/replicas/keys can remain exploitable without contract-level invariant checks.
- [6] Business impact quantification: Use the high loss range below with expected 2-48h incident handling and multi-team recovery costs.
- [7] Abuse narrative: Attacker exploits stale or improperly revoked trust relationships to execute privileged calls that appear structurally valid.
- [8] Fix plan + cost: Patch plan: enforce current-trust checks, stale-role revocation invariants, and privileged-path authorization hardening. Estimated effort: 5-14 engineer-days + 2-4 QA days. Estimated remediation cost: ~$40k-$160k including retest.
- Direct exploitation status: Direct once stale authorization or trust-boundary preconditions are present.
- Mitigation status:
1. Contract-level: not fully mitigated in audited snapshot; witness remains reproducible in referenced artifacts.
2. Operational: compensating controls are partial unless invariant-enforced code changes are deployed and verified.
- Estimated attacker cost: low-to-medium (~$300-$25,000) depending role/timing requirements.
- Estimated loss range: high (~$1M-$250M) from control-plane abuse, halted flows, and restitution/recovery burden.
- Primary mitigation layer: `Contract authorization/trust-boundary hardening`
- Mitigation feasibility: `Medium`
- Residual risk if truly mitigated: `Medium`
- Repo-specific manual check: Verify stale roles/replicas/keys are fully revoked and privileged paths enforce current-trust invariants.
- Mitigation acceptance criteria: `Implemented` (fix exists at reviewed commit), `Enforced` (no bypass path exists), and `Demonstrated` (tests/witnesses show the same exploit path is blocked).
- Business impact:
1. Optimistic delay does not protect the bootstrap root path.
2. Safety of initial root acceptance is fully delegated to deployment-time correctness.
3. If bootstrap root wiring is unsafe (wrong/placeholder root), invalid-message acceptance can occur immediately.
- Preconditions:
1. Stale or over-broad authorization state exists (replica/delegate/guardian/admin trust boundary).
2. Privileged path accepts that stale state as valid caller/proof source.
3. Attacker can invoke the affected call path without target-code modification.
- Detailed execution:
1. Initialize bootstrap root and set non-zero `optimisticSeconds`.
2. Immediately call `prove(...)` for a leaf/branch that resolves to the committed root.
3. Proof is accepted before the optimistic timeout window elapses.
4. Fixed control model (`confirmAt[root] = block.timestamp + optimisticSeconds`) rejects the same proof pre-timeout and accepts only post-timeout.
- Post-exploit objective:
1. Optimistic delay does not protect the bootstrap root path.
2. Safety of initial root acceptance is fully delegated to deployment-time correctness.
3. If bootstrap root wiring is unsafe (wrong/placeholder root), invalid-message acceptance can occur immediately.

### synapse-contracts - F2 (`High`)
- Vulnerability type category: `Authorization/governance control compromise and stale-trust acceptance`
- [1] Program/Payout mapping: Policy class: `Access Control / Authorization Integrity / Governance Trust Boundary`; severity tier: `High`; target payout band: `$15k-$100k (program-cap dependent)`; recommended claim framing: exploitable security defect with deterministic proof artifact.
- [2] Affected scope (exact): Repo `synapse-contracts`; component/function `DEFAULT_ADMIN_ROLE compromise can escalate into NODEGROUP_ROLE settlement authority and drain bridge collateral`; audit reference `reports/cat1_bridges/synapse-contracts/report.md`; reviewed commit hash: `60f1c25cf2f115911e11255f515e1450fe96100c`; fixed commit hash: `not provided`; affected release/version range: `TBD-pin-before-submission`.
- [3] Production exploitability verdict: Compromise-contingent: requires prior DEFAULT_ADMIN_ROLE compromise.
- [4] Deterministic repro evidence: witness artifacts (`f2_f3_role_and_minout_forge_test.txt`, `f2_f3_role_and_minout_fuzz_5000_runs.txt`, `f2_role_escalation_blast_radius_formal_campaign_meta.json`, `f2_role_escalation_blast_radius_formal_echidna_30s.txt`). Validation reference: `reports/cat1_bridges/<repo>/manual_audit.md` + listed witness files.
- [5] Mitigation gap proof: Operational policy does not reliably enforce revocation/current-trust invariants; stale roles/replicas/keys can remain exploitable without contract-level invariant checks.
- [6] Business impact quantification: Use the high loss range below with expected 2-48h incident handling and multi-team recovery costs.
- [7] Abuse narrative: Attacker exploits stale or improperly revoked trust relationships to execute privileged calls that appear structurally valid.
- [8] Fix plan + cost: Patch plan: enforce current-trust checks, stale-role revocation invariants, and privileged-path authorization hardening. Estimated effort: 5-14 engineer-days + 2-4 QA days. Estimated remediation cost: ~$40k-$160k including retest.
- Direct exploitation status: Compromise-contingent: requires prior DEFAULT_ADMIN_ROLE compromise.
- Mitigation status:
1. Contract-level: not fully mitigated in audited snapshot; witness remains reproducible in referenced artifacts.
2. Operational: compensating controls are partial unless invariant-enforced code changes are deployed and verified.
- Estimated attacker cost: high (~$50k-$2M+) due prerequisite admin-key compromise or equivalent privileged access acquisition.
- Estimated loss range: high (~$1M-$250M) from control-plane abuse, halted flows, and restitution/recovery burden.
- Primary mitigation layer: `Contract authorization/trust-boundary hardening`
- Mitigation feasibility: `Medium`
- Residual risk if truly mitigated: `Medium`
- Repo-specific manual check: Verify stale roles/replicas/keys are fully revoked and privileged paths enforce current-trust invariants.
- Mitigation acceptance criteria: `Implemented` (fix exists at reviewed commit), `Enforced` (no bypass path exists), and `Demonstrated` (tests/witnesses show the same exploit path is blocked).
- Business impact:
1. Admin-key compromise has direct path to settlement execution capability.
2. This collapses intended separation between administrative control and settlement custody.
- Preconditions:
1. Stale or over-broad authorization state exists (replica/delegate/guardian/admin trust boundary).
2. Privileged path accepts that stale state as valid caller/proof source.
3. Attacker can invoke the affected call path without target-code modification.
- Detailed execution:
1. Attacker obtains default-admin control.
2. Attacker grants settlement role to attacker-controlled account.
3. Attacker executes settlement withdraw path and drains modeled collateral.
4. Fixed control requiring distinct governance actor for node-role grants blocks the same admin-only path.
- Post-exploit objective:
1. Admin-key compromise has direct path to settlement execution capability.
2. This collapses intended separation between administrative control and settlement custody.

### telepathy-contracts - F1 (`High`)
- Vulnerability type category: `Initialization/upgrade first-caller takeover windows`
- [1] Program/Payout mapping: Policy class: `Access Control / Unsafe Initialization / Upgrade Integrity`; severity tier: `High`; target payout band: `$15k-$100k (program-cap dependent)`; recommended claim framing: exploitable security defect with deterministic proof artifact.
- [2] Affected scope (exact): Repo `telepathy-contracts`; component/function `Uninitialized-proxy first-caller initialization can seize bridge control plane and enable forged message execution`; audit reference `reports/cat1_bridges/telepathy-contracts/report.md`; reviewed commit hash: `0f3c6812d6bda96dde6ab7bdd8f8391c47bf5d0b`; fixed commit hash: `not provided`; affected release/version range: `TBD-pin-before-submission`.
- [3] Production exploitability verdict: Conditional-direct in non-atomic deployment/initialization flows.
- [4] Deterministic repro evidence: witness artifacts (`f1_uninitialized_init_hijack_forge_test.txt`, `f1_uninitialized_init_hijack_fuzz_5000_runs.txt`). Validation reference: `reports/cat1_bridges/<repo>/manual_audit.md` + listed witness files.
- [5] Mitigation gap proof: Runbook-only controls are brittle: any split deploy/upgrade path can reopen first-caller capture unless atomic init and contract-side caller guards are both enforced.
- [6] Business impact quantification: Use the high loss range below with expected 2-48h incident handling and multi-team recovery costs.
- [7] Abuse narrative: Attacker monitors deployment/governance activity, races initialization, captures privileged control, then monetizes through control-plane abuse.
- [8] Fix plan + cost: Patch plan: enforce atomic upgradeAndCall/deploy+init and add initializer caller restrictions. Estimated effort: 3-8 engineer-days + 1-2 QA days. Estimated remediation cost: ~$20k-$90k including retest.
- Direct exploitation status: Conditional-direct in non-atomic deployment/initialization flows.
- Mitigation status:
1. Contract-level: not fully mitigated in audited snapshot; witness remains reproducible in referenced artifacts.
2. Operational: compensating controls are partial unless invariant-enforced code changes are deployed and verified.
- Estimated attacker cost: low-to-medium (~$300-$25,000) depending role/timing requirements.
- Estimated loss range: high (~$1M-$250M) from control-plane abuse, halted flows, and restitution/recovery burden.
- Primary mitigation layer: `Deployment pipeline + contract init guard`
- Mitigation feasibility: `High`
- Residual risk if truly mitigated: `Medium (ops-only), Low (contract + ops guardrails)`
- Repo-specific manual check: Verify every deploy/upgrade path is atomic (upgradeAndCall/constructor init) and no split init path remains reachable.
- Mitigation acceptance criteria: `Implemented` (fix exists at reviewed commit), `Enforced` (no bypass path exists), and `Demonstrated` (tests/witnesses show the same exploit path is blocked).
- Business impact:
1. Control-plane takeover of verifier and relayer policy.
2. Forged-message acceptance in execution path under attacker-controlled verifier configuration.
3. Legitimate governance permanently excluded from initialization.
- Preconditions:
1. Deployment/upgrade flow allows split upgrade then initialize (non-atomic) execution.
2. Initializer assigns privileged role/owner from first successful call.
3. Attacker can monitor and submit prioritized transactions during upgrade windows.
- Detailed execution:
1. Router proxy-equivalent model is left uninitialized.
2. Attacker initializes first, setting `timelock=attacker` and `guardian=attacker`.
3. Legitimate deployer initialization attempt fails (already initialized).
4. Attacker sets default verifier to an always-true verifier.
5. Attacker executes a forged message; destination handler processes attacker-chosen source metadata.
- Post-exploit objective:
1. Control-plane takeover of verifier and relayer policy.
2. Forged-message acceptance in execution path under attacker-controlled verifier configuration.
3. Legitimate governance permanently excluded from initialization.

### wormhole - W2 (`High`)
- Vulnerability type category: `Authorization/governance control compromise and stale-trust acceptance`
- [1] Program/Payout mapping: Policy class: `Access Control / Authorization Integrity / Governance Trust Boundary`; severity tier: `High`; target payout band: `$15k-$100k (program-cap dependent)`; recommended claim framing: exploitable security defect with deterministic proof artifact.
- [2] Affected scope (exact): Repo `wormhole`; component/function `Token-bridge governance accepts stale guardian sets during expiry window`; audit reference `reports/cat1_bridges/wormhole/report.md`; reviewed commit hash: `e11926a849391e8a035c69fc52f4efb3205258fd`; fixed commit hash: `not provided`; affected release/version range: `TBD-pin-before-submission`.
- [3] Production exploitability verdict: Conditional-direct: requires compromised stale guardian keys during guardian-set expiry window.
- [4] Deterministic repro evidence: witness artifacts (`w2_stale_guardian_governance_forge_test.txt`, `w2_stale_guardian_governance_formal_campaign_meta.json`, `w2_stale_guardian_governance_formal_echidna_30s.txt`, `w2_stale_guardian_governance_formal_medusa_30s.txt`). Validation reference: `reports/cat1_bridges/<repo>/manual_audit.md` + listed witness files.
- [5] Mitigation gap proof: Operational policy does not reliably enforce revocation/current-trust invariants; stale roles/replicas/keys can remain exploitable without contract-level invariant checks.
- [6] Business impact quantification: Use the high loss range below with expected 2-48h incident handling and multi-team recovery costs.
- [7] Abuse narrative: Attacker exploits stale or improperly revoked trust relationships to execute privileged calls that appear structurally valid.
- [8] Fix plan + cost: Patch plan: enforce current-trust checks, stale-role revocation invariants, and privileged-path authorization hardening. Estimated effort: 5-14 engineer-days + 2-4 QA days. Estimated remediation cost: ~$40k-$160k including retest.
- Direct exploitation status: Conditional-direct: requires compromised stale guardian keys during guardian-set expiry window.
- Mitigation status:
1. Contract-level: not fully mitigated in audited snapshot; witness remains reproducible in referenced artifacts.
2. Operational: compensating controls are partial unless invariant-enforced code changes are deployed and verified.
- Estimated attacker cost: high (~$100k-$5M+) due requirement for stale guardian-key compromise and timing execution inside expiry window.
- Estimated loss range: high (~$1M-$250M) from control-plane abuse, halted flows, and restitution/recovery burden.
- Primary mitigation layer: `Contract authorization/trust-boundary hardening`
- Mitigation feasibility: `Medium`
- Residual risk if truly mitigated: `Medium`
- Repo-specific manual check: Verify stale roles/replicas/keys are fully revoked and privileged paths enforce current-trust invariants.
- Mitigation acceptance criteria: `Implemented` (fix exists at reviewed commit), `Enforced` (no bypass path exists), and `Demonstrated` (tests/witnesses show the same exploit path is blocked).
- Business impact:
1. If stale guardian keys are compromised during the expiry window (default 24h), attacker-signed governance VAAs can be accepted by token bridge governance.
2. This can authorize high-impact governance actions (for example bridge upgrade), creating a temporary stale-signer takeover window not present in core governance checks.
- Preconditions:
1. Stale or over-broad authorization state exists (replica/delegate/guardian/admin trust boundary).
2. Privileged path accepts that stale state as valid caller/proof source.
3. Attacker can invoke the affected call path without target-code modification.
- Detailed execution:
1. Configure guardian set `N-1` as stale but not expired, and set current guardian set to `N`.
2. Construct a governance VM signed by stale set `N-1` from the correct governance emitter chain/address.
3. Execute bridge-governance upgrade path.
4. VM passes Wormhole verification (stale set still in expiry window).
5. Bridge governance action succeeds despite stale signer set.
6. Equivalent core governance path rejects the same VM because current-set enforcement is present.
- Post-exploit objective:
1. If stale guardian keys are compromised during the expiry window (default 24h), attacker-signed governance VAAs can be accepted by token bridge governance.
2. This can authorize high-impact governance actions (for example bridge upgrade), creating a temporary stale-signer takeover window not present in core governance checks.

### axelar-core - A1 (`Medium`)
- Vulnerability type category: `Runtime liveness and DoS via unsafe input/state handling`
- [1] Program/Payout mapping: Policy class: `Availability / Input Validation / Runtime Safety`; severity tier: `Medium`; target payout band: `$5k-$30k (program-cap dependent)`; recommended claim framing: exploitable security defect with deterministic proof artifact.
- [2] Affected scope (exact): Repo `axelar-core`; component/function `Uppercase receiver filter in AxelarNet IBC path can panic on malformed uppercase receiver strings`; audit reference `reports/cat1_bridges/axelar-core/report.md`; reviewed commit hash: `f303a5aa961771b475b63bce433ed3b0e6cf3b1a`; fixed commit hash: `not provided`; affected release/version range: `TBD-pin-before-submission`.
- [3] Production exploitability verdict: Direct permissionless DoS via crafted packet receiver input.
- [4] Deterministic repro evidence: witness artifacts (`manual_go_test_axelarnet_blocked.txt`). Validation reference: `reports/cat1_bridges/<repo>/manual_audit.md` + listed witness files.
- [5] Mitigation gap proof: Input filters and operational guards are incomplete; panic-prone or unbounded paths remain reachable until converted to explicit error-handled flows.
- [6] Business impact quantification: Use the medium loss range below with expected 1-24h disruption, reconciliation, and support overhead.
- [7] Abuse narrative: Attacker repeatedly submits crafted inputs/state transitions that trigger panic/revert-heavy liveness failures.
- [8] Fix plan + cost: Patch plan: replace panic paths with explicit errors, add adversarial input tests, and bound liveness-sensitive loops. Estimated effort: 3-9 engineer-days + 1-3 QA days. Estimated remediation cost: ~$20k-$100k including retest.
- Direct exploitation status: Direct permissionless DoS via crafted packet receiver input.
- Mitigation status:
1. Contract-level: not fully mitigated in audited snapshot; witness remains reproducible in referenced artifacts.
2. Operational: compensating controls are partial unless invariant-enforced code changes are deployed and verified.
- Estimated attacker cost: low (~$100-$10,000) for scripted call sequences in affected deployments.
- Estimated loss range: medium-to-high (~$100k-$50M) from token-specific insolvency, leakage, or service degradation.
- Primary mitigation layer: `Input validation + panic-free runtime handling`
- Mitigation feasibility: `High`
- Residual risk if truly mitigated: `Low-Medium`
- Repo-specific manual check: Verify untrusted inputs fail gracefully (no panic/chain-halt) and liveness-sensitive loops remain bounded under adversarial sequences.
- Mitigation acceptance criteria: `Implemented` (fix exists at reviewed commit), `Enforced` (no bypass path exists), and `Demonstrated` (tests/witnesses show the same exploit path is blocked).
- Business impact:
1. Untrusted packet data can deterministically trigger a panic in the receive handler path.
2. Depending on panic-recovery and relaying behavior, this can suppress immediate error-ack handling and degrade IBC packet liveness (stuck/retry-until-timeout behavior).
- Preconditions:
1. Untrusted input/state can reach panic-prone or expensive runtime path.
2. Fail-fast behavior is panic/revert-heavy instead of explicit bounded error handling.
3. Attacker can repeatedly trigger the path with low-cost transactions/messages.
- Detailed execution:
1. Attacker sends ICS20 packet with non-empty uppercase receiver string that is not valid bech32 (for example `ABCDEF`).
2. Packet passes ICS20 basic validation because receiver format is not bech32-validated (only non-empty check).
3. AxelarNet `OnRecvMessage(...)` invokes `validateReceiver(...)`.
4. Uppercase branch executes and calls `sdk.AccAddressFromBech32(receiver)` via `funcs.Must(...)`.
5. Bech32 parse fails; `funcs.Must(...)` panics.
6. Handler panics instead of returning a normal `ErrorAcknowledgement`, enabling packet-level griefing/liveness degradation.
- Post-exploit objective:
1. Untrusted packet data can deterministically trigger a panic in the receive handler path.
2. Depending on panic-recovery and relaying behavior, this can suppress immediate error-ack handling and degrade IBC packet liveness (stuck/retry-until-timeout behavior).

### connext-monorepo - F1 (`Medium`)
- Vulnerability type category: `Collateral/accounting insolvency and economic leakage`
- [1] Program/Payout mapping: Policy class: `Business Logic / Accounting Integrity / Value Conservation`; severity tier: `Medium`; target payout band: `$5k-$30k (program-cap dependent)`; recommended claim framing: exploitable security defect with deterministic proof artifact.
- [2] Affected scope (exact): Repo `connext-monorepo`; component/function `Router liquidity withdrawal can undercollateralize remaining router balances under sender-tax payout token behavior`; audit reference `reports/cat1_bridges/connext-monorepo/report.md`; reviewed commit hash: `7758e62037bba281b8844c37831bde0b838edd36`; fixed commit hash: `not provided`; affected release/version range: `TBD-pin-before-submission`.
- [3] Production exploitability verdict: Direct on deployments supporting affected token behavior or residual-balance conditions.
- [4] Deterministic repro evidence: witness artifacts (`f1_router_sender_tax_forge_test.txt`, `f1_router_sender_tax_formal_campaign_meta.json`, `f1_router_sender_tax_formal_echidna_30s.txt`, `f1_router_sender_tax_formal_medusa_30s.txt`). Validation reference: `reports/cat1_bridges/<repo>/manual_audit.md` + listed witness files.
- [5] Mitigation gap proof: Token allowlists or ad-hoc controls do not enforce value-conservation invariants; accounting remains exploitable unless balance-delta-safe logic is applied at each boundary.
- [6] Business impact quantification: Use the medium loss range below with expected 1-24h disruption, reconciliation, and support overhead.
- [7] Abuse narrative: Attacker routes value through accounting paths that over-credit liabilities or leak reserves, extracting value while drift accumulates.
- [8] Fix plan + cost: Patch plan: move to balance-delta accounting, enforce conservation invariants, and add token-behavior safety constraints. Estimated effort: 5-12 engineer-days + 2-4 QA days. Estimated remediation cost: ~$35k-$140k including retest.
- Direct exploitation status: Direct on deployments supporting affected token behavior or residual-balance conditions.
- Mitigation status:
1. Contract-level: not fully mitigated in audited snapshot; witness remains reproducible in referenced artifacts.
2. Operational: compensating controls are partial unless invariant-enforced code changes are deployed and verified.
- Estimated attacker cost: low (~$100-$10,000) for scripted call sequences in affected deployments.
- Estimated loss range: medium-to-high (~$100k-$50M) from token-specific insolvency, leakage, or service degradation.
- Primary mitigation layer: `Accounting logic patch + token policy constraints`
- Mitigation feasibility: `High`
- Residual risk if truly mitigated: `Medium`
- Repo-specific manual check: Verify collateral >= liability invariants across taxed/fee-on-transfer/residual-balance scenarios with deterministic + fuzz witnesses.
- Mitigation acceptance criteria: `Implemented` (fix exists at reviewed commit), `Enforced` (no bypass path exists), and `Demonstrated` (tests/witnesses show the same exploit path is blocked).
- Business impact:
1. Remaining router balances can become undercollateralized for affected token classes.
2. This creates token-specific solvency/liveness risk for router withdrawals and settlement assumptions.
- Preconditions:
1. Deployment supports affected token behavior (sender-tax, fee-on-transfer, or residual-balance accounting path).
2. Accounting path credits liabilities or refunds based on intent-level values rather than strict balance deltas.
3. Attacker can execute the bridge action sequence in normal protocol flow.
- Detailed execution:
1. Add two routers with `100_000` local asset each (`totalRouterBalances = 200_000`).
2. Configure sender-tax behavior for transfers where Connext contract is sender (5% extra debit).
3. Remove router A liquidity by `100_000`.
4. Router balances drop to `100_000`, but contract collateral drops to `95_000`.
5. Post-state violates coverage invariant (`collateral < totalRouterBalances`).
- Post-exploit objective:
1. Remaining router balances can become undercollateralized for affected token classes.
2. This creates token-specific solvency/liveness risk for router withdrawals and settlement assumptions.

### connext-monorepo - F2 (`Medium`)
- Vulnerability type category: `Collateral/accounting insolvency and economic leakage`
- [1] Program/Payout mapping: Policy class: `Business Logic / Accounting Integrity / Value Conservation`; severity tier: `Medium`; target payout band: `$5k-$30k (program-cap dependent)`; recommended claim framing: exploitable security defect with deterministic proof artifact.
- [2] Affected scope (exact): Repo `connext-monorepo`; component/function `Canonical-domain execute payout can desynchronize custodied from real collateral under sender-tax token behavior`; audit reference `reports/cat1_bridges/connext-monorepo/report.md`; reviewed commit hash: `7758e62037bba281b8844c37831bde0b838edd36`; fixed commit hash: `not provided`; affected release/version range: `TBD-pin-before-submission`.
- [3] Production exploitability verdict: Direct on deployments supporting affected token behavior or residual-balance conditions.
- [4] Deterministic repro evidence: witness artifacts (`f2_execute_custodied_sender_tax_forge_test.txt`, `f2_execute_custodied_sender_tax_formal_campaign_meta.json`, `f2_execute_custodied_sender_tax_formal_echidna_30s.txt`, `f2_execute_custodied_sender_tax_formal_medusa_30s.txt`). Validation reference: `reports/cat1_bridges/<repo>/manual_audit.md` + listed witness files.
- [5] Mitigation gap proof: Token allowlists or ad-hoc controls do not enforce value-conservation invariants; accounting remains exploitable unless balance-delta-safe logic is applied at each boundary.
- [6] Business impact quantification: Use the medium loss range below with expected 1-24h disruption, reconciliation, and support overhead.
- [7] Abuse narrative: Attacker routes value through accounting paths that over-credit liabilities or leak reserves, extracting value while drift accumulates.
- [8] Fix plan + cost: Patch plan: move to balance-delta accounting, enforce conservation invariants, and add token-behavior safety constraints. Estimated effort: 5-12 engineer-days + 2-4 QA days. Estimated remediation cost: ~$35k-$140k including retest.
- Direct exploitation status: Direct on deployments supporting affected token behavior or residual-balance conditions.
- Mitigation status:
1. Contract-level: not fully mitigated in audited snapshot; witness remains reproducible in referenced artifacts.
2. Operational: compensating controls are partial unless invariant-enforced code changes are deployed and verified.
- Estimated attacker cost: low (~$100-$10,000) for scripted call sequences in affected deployments.
- Estimated loss range: medium-to-high (~$100k-$50M) from token-specific insolvency, leakage, or service degradation.
- Primary mitigation layer: `Accounting logic patch + token policy constraints`
- Mitigation feasibility: `High`
- Residual risk if truly mitigated: `Medium`
- Repo-specific manual check: Verify collateral >= liability invariants across taxed/fee-on-transfer/residual-balance scenarios with deterministic + fuzz witnesses.
- Mitigation acceptance criteria: `Implemented` (fix exists at reviewed commit), `Enforced` (no bypass path exists), and `Demonstrated` (tests/witnesses show the same exploit path is blocked).
- Business impact:
1. Cap-tracked accounting can overstate retrievable collateral for affected token classes.
2. Subsequent destination payouts can fail earlier than accounting implies, creating token-specific liveness/solvency stress.
3. Cap-related operational decisions can be made on drifted custody data.
- Preconditions:
1. Deployment supports affected token behavior (sender-tax, fee-on-transfer, or residual-balance accounting path).
2. Accounting path credits liabilities or refunds based on intent-level values rather than strict balance deltas.
3. Attacker can execute the bridge action sequence in normal protocol flow.
- Detailed execution:
1. Seed canonical custody with `200_000` (tracked `custodied = 200_000`).
2. Configure sender-tax behavior for transfers where Connext contract is sender (5% extra debit).
3. Execute payout of `100_000`.
4. `custodied` decreases to `100_000` by intent-level accounting.
5. Actual token balance decreases to `95_000` due sender-tax extra debit.
6. Post-state violates coverage invariant (`collateral < custodied`).
- Post-exploit objective:
1. Cap-tracked accounting can overstate retrievable collateral for affected token classes.
2. Subsequent destination payouts can fail earlier than accounting implies, creating token-specific liveness/solvency stress.
3. Cap-related operational decisions can be made on drifted custody data.

### connext-monorepo - F3 (`Medium`)
- Vulnerability type category: `Collateral/accounting insolvency and economic leakage`
- [1] Program/Payout mapping: Policy class: `Business Logic / Accounting Integrity / Value Conservation`; severity tier: `Medium`; target payout band: `$5k-$30k (program-cap dependent)`; recommended claim framing: exploitable security defect with deterministic proof artifact.
- [2] Affected scope (exact): Repo `connext-monorepo`; component/function `ERC20 bumpTransfer fee forwarding can consume bridge collateral under sender-tax payout token behavior`; audit reference `reports/cat1_bridges/connext-monorepo/report.md`; reviewed commit hash: `7758e62037bba281b8844c37831bde0b838edd36`; fixed commit hash: `not provided`; affected release/version range: `TBD-pin-before-submission`.
- [3] Production exploitability verdict: Direct on deployments supporting affected token behavior or residual-balance conditions.
- [4] Deterministic repro evidence: witness artifacts (`f3_bump_transfer_sender_tax_forge_test.txt`, `f3_bump_transfer_sender_tax_formal_campaign_meta.json`, `f3_bump_transfer_sender_tax_formal_echidna_30s.txt`, `f3_bump_transfer_sender_tax_formal_medusa_30s.txt`). Validation reference: `reports/cat1_bridges/<repo>/manual_audit.md` + listed witness files.
- [5] Mitigation gap proof: Token allowlists or ad-hoc controls do not enforce value-conservation invariants; accounting remains exploitable unless balance-delta-safe logic is applied at each boundary.
- [6] Business impact quantification: Use the medium loss range below with expected 1-24h disruption, reconciliation, and support overhead.
- [7] Abuse narrative: Attacker routes value through accounting paths that over-credit liabilities or leak reserves, extracting value while drift accumulates.
- [8] Fix plan + cost: Patch plan: move to balance-delta accounting, enforce conservation invariants, and add token-behavior safety constraints. Estimated effort: 5-12 engineer-days + 2-4 QA days. Estimated remediation cost: ~$35k-$140k including retest.
- Direct exploitation status: Direct on deployments supporting affected token behavior or residual-balance conditions.
- Mitigation status:
1. Contract-level: not fully mitigated in audited snapshot; witness remains reproducible in referenced artifacts.
2. Operational: compensating controls are partial unless invariant-enforced code changes are deployed and verified.
- Estimated attacker cost: low (~$100-$10,000) for scripted call sequences in affected deployments.
- Estimated loss range: medium-to-high (~$100k-$50M) from token-specific insolvency, leakage, or service degradation.
- Primary mitigation layer: `Accounting logic patch + token policy constraints`
- Mitigation feasibility: `High`
- Residual risk if truly mitigated: `Medium`
- Repo-specific manual check: Verify collateral >= liability invariants across taxed/fee-on-transfer/residual-balance scenarios with deterministic + fuzz witnesses.
- Mitigation acceptance criteria: `Implemented` (fix exists at reviewed commit), `Enforced` (no bypass path exists), and `Demonstrated` (tests/witnesses show the same exploit path is blocked).
- Business impact:
1. Repeated bump-fee operations can drain bridge-side collateral for affected token classes.
2. This can undercollateralize outstanding router liabilities and stress liquidity/settlement liveness.
3. Drift is created on a path expected to be accounting-neutral.
- Preconditions:
1. Deployment supports affected token behavior (sender-tax, fee-on-transfer, or residual-balance accounting path).
2. Accounting path credits liabilities or refunds based on intent-level values rather than strict balance deltas.
3. Attacker can execute the bridge action sequence in normal protocol flow.
- Detailed execution:
1. Seed bridge with router liabilities: add `100_000` for router A and `100_000` for router B (`totalRouterBalances = 200_000`).
2. Configure sender-tax behavior for transfers where Connext contract is sender (5% extra debit).
3. Call ERC20 bump-fee path with `relayerFee = 100_000`.
4. Incoming leg credits exactly `100_000` into contract.
5. Outgoing fee transfer debits `105_000` from contract.
6. Post-state: collateral `195_000` while router liabilities remain `200_000`; invariant fails (`collateral < totalRouterBalances`).
- Post-exploit objective:
1. Repeated bump-fee operations can drain bridge-side collateral for affected token classes.
2. This can undercollateralize outstanding router liabilities and stress liquidity/settlement liveness.
3. Drift is created on a path expected to be accounting-neutral.

### hyperlane-monorepo - H1 (`Medium`)
- Vulnerability type category: `Collateral/accounting insolvency and economic leakage`
- [1] Program/Payout mapping: Policy class: `Business Logic / Accounting Integrity / Value Conservation`; severity tier: `Medium`; target payout band: `$5k-$30k (program-cap dependent)`; recommended claim framing: exploitable security defect with deterministic proof artifact.
- [2] Affected scope (exact): Repo `hyperlane-monorepo`; component/function `HypERC20Collateral + TokenRouter intent-level accounting can create collateral deficits with inbound-fee tokens`; audit reference `reports/cat1_bridges/hyperlane-monorepo/report.md`; reviewed commit hash: `5302a89c830c5eb43b8d3f53fc65e0733f4d6bd1`; fixed commit hash: `not provided`; affected release/version range: `TBD-pin-before-submission`.
- [3] Production exploitability verdict: Direct on deployments supporting affected token behavior or residual-balance conditions.
- [4] Deterministic repro evidence: witness artifacts (`h1_collateral_fee_on_transfer_forge_test.txt`, `h1_collateral_fee_on_transfer_formal_campaign_meta.json`, `h1_collateral_fee_on_transfer_formal_echidna_30s.txt`, `h1_collateral_fee_on_transfer_formal_medusa_30s.txt`). Validation reference: `reports/cat1_bridges/<repo>/manual_audit.md` + listed witness files.
- [5] Mitigation gap proof: Token allowlists or ad-hoc controls do not enforce value-conservation invariants; accounting remains exploitable unless balance-delta-safe logic is applied at each boundary.
- [6] Business impact quantification: Use the medium loss range below with expected 1-24h disruption, reconciliation, and support overhead.
- [7] Abuse narrative: Attacker routes value through accounting paths that over-credit liabilities or leak reserves, extracting value while drift accumulates.
- [8] Fix plan + cost: Patch plan: move to balance-delta accounting, enforce conservation invariants, and add token-behavior safety constraints. Estimated effort: 5-12 engineer-days + 2-4 QA days. Estimated remediation cost: ~$35k-$140k including retest.
- Direct exploitation status: Direct on deployments supporting affected token behavior or residual-balance conditions.
- Mitigation status:
1. Contract-level: not fully mitigated in audited snapshot; witness remains reproducible in referenced artifacts.
2. Operational: compensating controls are partial unless invariant-enforced code changes are deployed and verified.
- Estimated attacker cost: low (~$100-$10,000) for scripted call sequences in affected deployments.
- Estimated loss range: medium-to-high (~$100k-$50M) from token-specific insolvency, leakage, or service degradation.
- Primary mitigation layer: `Accounting logic patch + token policy constraints`
- Mitigation feasibility: `High`
- Residual risk if truly mitigated: `Medium`
- Repo-specific manual check: Verify collateral >= liability invariants across taxed/fee-on-transfer/residual-balance scenarios with deterministic + fuzz witnesses.
- Mitigation acceptance criteria: `Implemented` (fix exists at reviewed commit), `Enforced` (no bypass path exists), and `Demonstrated` (tests/witnesses show the same exploit path is blocked).
- Business impact:
1. Affected token classes can over-credit remote-side transfer liabilities relative to source-side collateral.
2. This creates token-specific insolvency / redemption shortfall risk.
- Preconditions:
1. Deployment supports affected token behavior (sender-tax, fee-on-transfer, or residual-balance accounting path).
2. Accounting path credits liabilities or refunds based on intent-level values rather than strict balance deltas.
3. Attacker can execute the bridge action sequence in normal protocol flow.
- Detailed execution:
1. Configure inbound-fee token behavior (5% haircut when router is transfer target).
2. Call bug-model `transferRemote(100_000, 100_000)`.
3. Router collateral increases by `95_000`.
4. Remote liability is credited as `100_000`.
5. Post-state violates coverage invariant (`collateral < remoteLiability`).
- Post-exploit objective:
1. Affected token classes can over-credit remote-side transfer liabilities relative to source-side collateral.
2. This creates token-specific insolvency / redemption shortfall risk.

### hyperlane-monorepo - H2 (`Medium`)
- Vulnerability type category: `Collateral/accounting insolvency and economic leakage`
- [1] Program/Payout mapping: Policy class: `Business Logic / Accounting Integrity / Value Conservation`; severity tier: `Medium`; target payout band: `$5k-$30k (program-cap dependent)`; recommended claim framing: exploitable security defect with deterministic proof artifact.
- [2] Affected scope (exact): Repo `hyperlane-monorepo`; component/function `LpCollateralRouter can overstate lpAssets vs real collateral under inbound-fee collateral tokens`; audit reference `reports/cat1_bridges/hyperlane-monorepo/report.md`; reviewed commit hash: `5302a89c830c5eb43b8d3f53fc65e0733f4d6bd1`; fixed commit hash: `not provided`; affected release/version range: `TBD-pin-before-submission`.
- [3] Production exploitability verdict: Direct on deployments supporting affected token behavior or residual-balance conditions.
- [4] Deterministic repro evidence: witness artifacts (`h2_h3_lp_and_fee_forge_test.txt`, `h2_h3_lp_and_fee_fuzz_5000_runs.txt`, `h2_lp_assets_overstatement_formal_campaign_meta.json`, `h2_lp_assets_overstatement_formal_echidna_30s.txt`). Validation reference: `reports/cat1_bridges/<repo>/manual_audit.md` + listed witness files.
- [5] Mitigation gap proof: Token allowlists or ad-hoc controls do not enforce value-conservation invariants; accounting remains exploitable unless balance-delta-safe logic is applied at each boundary.
- [6] Business impact quantification: Use the medium loss range below with expected 1-24h disruption, reconciliation, and support overhead.
- [7] Abuse narrative: Attacker routes value through accounting paths that over-credit liabilities or leak reserves, extracting value while drift accumulates.
- [8] Fix plan + cost: Patch plan: move to balance-delta accounting, enforce conservation invariants, and add token-behavior safety constraints. Estimated effort: 5-12 engineer-days + 2-4 QA days. Estimated remediation cost: ~$35k-$140k including retest.
- Direct exploitation status: Direct on deployments supporting affected token behavior or residual-balance conditions.
- Mitigation status:
1. Contract-level: not fully mitigated in audited snapshot; witness remains reproducible in referenced artifacts.
2. Operational: compensating controls are partial unless invariant-enforced code changes are deployed and verified.
- Estimated attacker cost: low (~$100-$10,000) for scripted call sequences in affected deployments.
- Estimated loss range: medium-to-high (~$100k-$50M) from token-specific insolvency, leakage, or service degradation.
- Primary mitigation layer: `Accounting logic patch + token policy constraints`
- Mitigation feasibility: `High`
- Residual risk if truly mitigated: `Medium`
- Repo-specific manual check: Verify collateral >= liability invariants across taxed/fee-on-transfer/residual-balance scenarios with deterministic + fuzz witnesses.
- Mitigation acceptance criteria: `Implemented` (fix exists at reviewed commit), `Enforced` (no bypass path exists), and `Demonstrated` (tests/witnesses show the same exploit path is blocked).
- Business impact:
1. LP accounting can report more assets than physically held collateral.
2. Withdraw/redeem liveness can fail for affected token classes.
3. Produces token-specific insolvency/shortfall behavior at LP accounting boundary.
- Preconditions:
1. Deployment supports affected token behavior (sender-tax, fee-on-transfer, or residual-balance accounting path).
2. Accounting path credits liabilities or refunds based on intent-level values rather than strict balance deltas.
3. Attacker can execute the bridge action sequence in normal protocol flow.
- Detailed execution:
1. Configure inbound-fee token behavior (5% haircut when LP router is transfer target).
2. Deposit `100_000`.
3. Router receives `95_000` real collateral.
4. `lpAssets` increases by `100_000`.
5. Full withdraw/redeem of intent-level amount can revert due collateral shortfall.
- Post-exploit objective:
1. LP accounting can report more assets than physically held collateral.
2. Withdraw/redeem liveness can fail for affected token classes.
3. Produces token-specific insolvency/shortfall behavior at LP accounting boundary.

### hyperlane-monorepo - H3 (`Medium`)
- Vulnerability type category: `Collateral/accounting insolvency and economic leakage`
- [1] Program/Payout mapping: Policy class: `Business Logic / Accounting Integrity / Value Conservation`; severity tier: `Medium`; target payout band: `$5k-$30k (program-cap dependent)`; recommended claim framing: exploitable security defect with deterministic proof artifact.
- [2] Affected scope (exact): Repo `hyperlane-monorepo`; component/function `TokenRouter fee transfer path can undercollateralize router accounting with sender-tax token behavior`; audit reference `reports/cat1_bridges/hyperlane-monorepo/report.md`; reviewed commit hash: `5302a89c830c5eb43b8d3f53fc65e0733f4d6bd1`; fixed commit hash: `not provided`; affected release/version range: `TBD-pin-before-submission`.
- [3] Production exploitability verdict: Direct on deployments supporting affected token behavior or residual-balance conditions.
- [4] Deterministic repro evidence: witness artifacts (`h2_h3_lp_and_fee_forge_test.txt`, `h2_h3_lp_and_fee_fuzz_5000_runs.txt`, `h3_fee_transfer_sender_tax_formal_campaign_meta.json`, `h3_fee_transfer_sender_tax_formal_echidna_30s.txt`). Validation reference: `reports/cat1_bridges/<repo>/manual_audit.md` + listed witness files.
- [5] Mitigation gap proof: Token allowlists or ad-hoc controls do not enforce value-conservation invariants; accounting remains exploitable unless balance-delta-safe logic is applied at each boundary.
- [6] Business impact quantification: Use the medium loss range below with expected 1-24h disruption, reconciliation, and support overhead.
- [7] Abuse narrative: Attacker routes value through accounting paths that over-credit liabilities or leak reserves, extracting value while drift accumulates.
- [8] Fix plan + cost: Patch plan: move to balance-delta accounting, enforce conservation invariants, and add token-behavior safety constraints. Estimated effort: 5-12 engineer-days + 2-4 QA days. Estimated remediation cost: ~$35k-$140k including retest.
- Direct exploitation status: Direct on deployments supporting affected token behavior or residual-balance conditions.
- Mitigation status:
1. Contract-level: not fully mitigated in audited snapshot; witness remains reproducible in referenced artifacts.
2. Operational: compensating controls are partial unless invariant-enforced code changes are deployed and verified.
- Estimated attacker cost: low (~$100-$10,000) for scripted call sequences in affected deployments.
- Estimated loss range: medium-to-high (~$100k-$50M) from token-specific insolvency, leakage, or service degradation.
- Primary mitigation layer: `Accounting logic patch + token policy constraints`
- Mitigation feasibility: `High`
- Residual risk if truly mitigated: `Medium`
- Repo-specific manual check: Verify collateral >= liability invariants across taxed/fee-on-transfer/residual-balance scenarios with deterministic + fuzz witnesses.
- Mitigation acceptance criteria: `Implemented` (fix exists at reviewed commit), `Enforced` (no bypass path exists), and `Demonstrated` (tests/witnesses show the same exploit path is blocked).
- Business impact:
1. Token-specific accounting deficit in routers using fee transfers with sender-tax token behavior.
2. Can cause undercollateralization and future redemption shortfall behavior for affected token classes.
- Preconditions:
1. Deployment supports affected token behavior (sender-tax, fee-on-transfer, or residual-balance accounting path).
2. Accounting path credits liabilities or refunds based on intent-level values rather than strict balance deltas.
3. Attacker can execute the bridge action sequence in normal protocol flow.
- Detailed execution:
1. Configure sender-tax behavior that charges extra debit when router is sender.
2. Execute `transferRemote`-equivalent path with `amount=100_000`, `fee=10_000`.
3. Router receives `110_000` at charge step.
4. Fee transfer debits `10_000 + extraTax`.
5. Router collateral falls below credited remote liability (`collateral < remoteLiability`).
- Post-exploit objective:
1. Token-specific accounting deficit in routers using fee transfers with sender-tax token behavior.
2. Can cause undercollateralization and future redemption shortfall behavior for affected token classes.

### LayerZero-v2 - LZ1 (`Medium`)
- Vulnerability type category: `Collateral/accounting insolvency and economic leakage`
- [1] Program/Payout mapping: Policy class: `Business Logic / Accounting Integrity / Value Conservation`; severity tier: `Medium`; target payout band: `$5k-$30k (program-cap dependent)`; recommended claim framing: exploitable security defect with deterministic proof artifact.
- [2] Affected scope (exact): Repo `LayerZero-v2`; component/function `OFTAdapter lossless-transfer assumption can create collateral deficit with inbound-fee tokens`; audit reference `reports/cat1_bridges/LayerZero-v2/report.md`; reviewed commit hash: `ab9b083410b9359285a5756807e1b6145d4711a7`; fixed commit hash: `not provided`; affected release/version range: `TBD-pin-before-submission`.
- [3] Production exploitability verdict: Direct on deployments supporting affected token behavior or residual-balance conditions.
- [4] Deterministic repro evidence: witness artifacts (`lz1_lz2_forge_test.txt`, `lz1_lz2_fuzz_5000_runs.txt`, `lz1_oft_lossless_formal_campaign_meta.json`, `lz1_oft_lossless_formal_echidna_30s.txt`). Validation reference: `reports/cat1_bridges/<repo>/manual_audit.md` + listed witness files.
- [5] Mitigation gap proof: Token allowlists or ad-hoc controls do not enforce value-conservation invariants; accounting remains exploitable unless balance-delta-safe logic is applied at each boundary.
- [6] Business impact quantification: Use the medium loss range below with expected 1-24h disruption, reconciliation, and support overhead.
- [7] Abuse narrative: Attacker routes value through accounting paths that over-credit liabilities or leak reserves, extracting value while drift accumulates.
- [8] Fix plan + cost: Patch plan: move to balance-delta accounting, enforce conservation invariants, and add token-behavior safety constraints. Estimated effort: 5-12 engineer-days + 2-4 QA days. Estimated remediation cost: ~$35k-$140k including retest.
- Direct exploitation status: Direct on deployments supporting affected token behavior or residual-balance conditions.
- Mitigation status:
1. Contract-level: not fully mitigated in audited snapshot; witness remains reproducible in referenced artifacts.
2. Operational: compensating controls are partial unless invariant-enforced code changes are deployed and verified.
- Estimated attacker cost: low (~$100-$10,000) for scripted call sequences in affected deployments.
- Estimated loss range: medium-to-high (~$100k-$50M) from token-specific insolvency, leakage, or service degradation.
- Primary mitigation layer: `Accounting logic patch + token policy constraints`
- Mitigation feasibility: `High`
- Residual risk if truly mitigated: `Medium`
- Repo-specific manual check: Verify collateral >= liability invariants across taxed/fee-on-transfer/residual-balance scenarios with deterministic + fuzz witnesses.
- Mitigation acceptance criteria: `Implemented` (fix exists at reviewed commit), `Enforced` (no bypass path exists), and `Demonstrated` (tests/witnesses show the same exploit path is blocked).
- Business impact:
1. For non-lossless tokens, OFT mesh accounting can over-credit remote side versus locked source collateral.
2. This can produce token-specific insolvency / redemption shortfall behavior.
- Preconditions:
1. Deployment supports affected token behavior (sender-tax, fee-on-transfer, or residual-balance accounting path).
2. Accounting path credits liabilities or refunds based on intent-level values rather than strict balance deltas.
3. Attacker can execute the bridge action sequence in normal protocol flow.
- Detailed execution:
1. Configure inbound-fee token (5%) for adapter lock step.
2. Call adapter send for `100_000` units with strict min of `100_000`.
3. Adapter accepts and records remote liability of `100_000`.
4. Actual adapter collateral increases by only `95_000`.
5. Post-state violates `collateral >= remote_liability`.
- Post-exploit objective:
1. For non-lossless tokens, OFT mesh accounting can over-credit remote side versus locked source collateral.
2. This can produce token-specific insolvency / redemption shortfall behavior.

### LayerZero-v2 - LZ3 (`Medium`)
- Vulnerability type category: `Collateral/accounting insolvency and economic leakage`
- [1] Program/Payout mapping: Policy class: `Business Logic / Accounting Integrity / Value Conservation`; severity tier: `Medium`; target payout band: `$5k-$30k (program-cap dependent)`; recommended claim framing: exploitable security defect with deterministic proof artifact.
- [2] Affected scope (exact): Repo `LayerZero-v2`; component/function `Endpoint payInLzToken path can sweep preloaded residual lzToken balance to caller-selected refund address`; audit reference `reports/cat1_bridges/LayerZero-v2/report.md`; reviewed commit hash: `ab9b083410b9359285a5756807e1b6145d4711a7`; fixed commit hash: `not provided`; affected release/version range: `TBD-pin-before-submission`.
- [3] Production exploitability verdict: Direct on deployments supporting affected token behavior or residual-balance conditions.
- [4] Deterministic repro evidence: witness artifacts (`lz3_residual_sweep_forge_test.txt`, `lz3_residual_sweep_formal_campaign_meta.json`, `lz3_residual_sweep_formal_echidna_30s.txt`, `lz3_residual_sweep_formal_medusa_30s.txt`). Validation reference: `reports/cat1_bridges/<repo>/manual_audit.md` + listed witness files.
- [5] Mitigation gap proof: Token allowlists or ad-hoc controls do not enforce value-conservation invariants; accounting remains exploitable unless balance-delta-safe logic is applied at each boundary.
- [6] Business impact quantification: Use the medium loss range below with expected 1-24h disruption, reconciliation, and support overhead.
- [7] Abuse narrative: Attacker routes value through accounting paths that over-credit liabilities or leak reserves, extracting value while drift accumulates.
- [8] Fix plan + cost: Patch plan: move to balance-delta accounting, enforce conservation invariants, and add token-behavior safety constraints. Estimated effort: 5-12 engineer-days + 2-4 QA days. Estimated remediation cost: ~$35k-$140k including retest.
- Direct exploitation status: Direct on deployments supporting affected token behavior or residual-balance conditions.
- Mitigation status:
1. Contract-level: not fully mitigated in audited snapshot; witness remains reproducible in referenced artifacts.
2. Operational: compensating controls are partial unless invariant-enforced code changes are deployed and verified.
- Estimated attacker cost: low (~$100-$10,000) for scripted call sequences in affected deployments.
- Estimated loss range: medium-to-high (~$100k-$50M) from token-specific insolvency, leakage, or service degradation.
- Primary mitigation layer: `Accounting logic patch + token policy constraints`
- Mitigation feasibility: `High`
- Residual risk if truly mitigated: `Medium`
- Repo-specific manual check: Verify collateral >= liability invariants across taxed/fee-on-transfer/residual-balance scenarios with deterministic + fuzz witnesses.
- Mitigation acceptance criteria: `Implemented` (fix exists at reviewed commit), `Enforced` (no bypass path exists), and `Demonstrated` (tests/witnesses show the same exploit path is blocked).
- Business impact:
1. Any stranded/preloaded endpoint `lzToken` becomes permissionlessly sweepable by arbitrary send caller.
2. Converts operational residual balances into publicly extractable value.
- Preconditions:
1. Deployment supports affected token behavior (sender-tax, fee-on-transfer, or residual-balance accounting path).
2. Accounting path credits liabilities or refunds based on intent-level values rather than strict balance deltas.
3. Attacker can execute the bridge action sequence in normal protocol flow.
- Detailed execution:
1. Configure endpoint `lzToken` and send library with nonzero `lzToken` fee.
2. Preload endpoint with residual `1_000` `lzToken`.
3. Arbitrary caller invokes `send(payInLzToken=true, refundAddress=attacker)` with no additional `lzToken` transfer.
4. Endpoint computes supplied fee from existing residual balance.
5. Endpoint pays required fee (`99`) to send library and refunds remaining residual (`901`) to attacker address.
- Post-exploit objective:
1. Any stranded/preloaded endpoint `lzToken` becomes permissionlessly sweepable by arbitrary send caller.
2. Converts operational residual balances into publicly extractable value.

### LayerZero-v2 - LZ4 (`Medium`)
- Vulnerability type category: `Collateral/accounting insolvency and economic leakage`
- [1] Program/Payout mapping: Policy class: `Business Logic / Accounting Integrity / Value Conservation`; severity tier: `Medium`; target payout band: `$5k-$30k (program-cap dependent)`; recommended claim framing: exploitable security defect with deterministic proof artifact.
- [2] Affected scope (exact): Repo `LayerZero-v2`; component/function `EndpointV2Alt native-fee path can sweep preloaded residual nativeErc20 balance to caller-selected refund address`; audit reference `reports/cat1_bridges/LayerZero-v2/report.md`; reviewed commit hash: `ab9b083410b9359285a5756807e1b6145d4711a7`; fixed commit hash: `not provided`; affected release/version range: `TBD-pin-before-submission`.
- [3] Production exploitability verdict: Direct on deployments supporting affected token behavior or residual-balance conditions.
- [4] Deterministic repro evidence: witness artifacts (`h1_fullsource_parity_oft_adapter_forge_test.txt`, `h2_fullsource_parity_delegate_stale_forge_test.txt`, `h3_fullsource_lztoken_residual_sweep_forge_test.txt`, `h4_fullsource_alt_native_residual_sweep_forge_test.txt`). Validation reference: `reports/cat1_bridges/<repo>/manual_audit.md` + listed witness files.
- [5] Mitigation gap proof: Token allowlists or ad-hoc controls do not enforce value-conservation invariants; accounting remains exploitable unless balance-delta-safe logic is applied at each boundary.
- [6] Business impact quantification: Use the medium loss range below with expected 1-24h disruption, reconciliation, and support overhead.
- [7] Abuse narrative: Attacker routes value through accounting paths that over-credit liabilities or leak reserves, extracting value while drift accumulates.
- [8] Fix plan + cost: Patch plan: move to balance-delta accounting, enforce conservation invariants, and add token-behavior safety constraints. Estimated effort: 5-12 engineer-days + 2-4 QA days. Estimated remediation cost: ~$35k-$140k including retest.
- Direct exploitation status: Direct on deployments supporting affected token behavior or residual-balance conditions.
- Mitigation status:
1. Contract-level: not fully mitigated in audited snapshot; witness remains reproducible in referenced artifacts.
2. Operational: compensating controls are partial unless invariant-enforced code changes are deployed and verified.
- Estimated attacker cost: low (~$100-$10,000) for scripted call sequences in affected deployments.
- Estimated loss range: medium-to-high (~$100k-$50M) from token-specific insolvency, leakage, or service degradation.
- Primary mitigation layer: `Accounting logic patch + token policy constraints`
- Mitigation feasibility: `High`
- Residual risk if truly mitigated: `Medium`
- Repo-specific manual check: Verify collateral >= liability invariants across taxed/fee-on-transfer/residual-balance scenarios with deterministic + fuzz witnesses.
- Mitigation acceptance criteria: `Implemented` (fix exists at reviewed commit), `Enforced` (no bypass path exists), and `Demonstrated` (tests/witnesses show the same exploit path is blocked).
- Business impact:
1. Any stranded/preloaded `nativeErc20` balance in EndpointV2Alt becomes permissionlessly sweepable by arbitrary send caller.
2. Mirrors LZ3 residual-sweep behavior on alternate endpoint native-fee path.
- Preconditions:
1. Deployment supports affected token behavior (sender-tax, fee-on-transfer, or residual-balance accounting path).
2. Accounting path credits liabilities or refunds based on intent-level values rather than strict balance deltas.
3. Attacker can execute the bridge action sequence in normal protocol flow.
- Detailed execution:
1. Deploy `EndpointV2Alt` with `nativeErc20` token and configure send/receive libraries.
2. Configure message library fee to require nonzero native fee (`77`) and zero `lzToken` fee.
3. Preload endpoint with residual `nativeErc20` balance (`1_000`).
4. Arbitrary caller invokes `send(payInLzToken=false, refundAddress=attacker)` with no additional token contribution.
5. Endpoint pays required fee (`77`) to message library and refunds remaining residual (`923`) to attacker.
- Post-exploit objective:
1. Any stranded/preloaded `nativeErc20` balance in EndpointV2Alt becomes permissionlessly sweepable by arbitrary send caller.
2. Mirrors LZ3 residual-sweep behavior on alternate endpoint native-fee path.

### nomad-monorepo - F10 (`Medium`)
- Vulnerability type category: `Token identity/migration integrity breaks`
- [1] Program/Payout mapping: Policy class: `Business Logic / Asset Identity / State Consistency`; severity tier: `Medium`; target payout band: `$5k-$30k (program-cap dependent)`; recommended claim framing: exploitable security defect with deterministic proof artifact.
- [2] Affected scope (exact): Repo `nomad-monorepo`; component/function `migrate can convert canonical asset identity after representation alias overwrite`; audit reference `reports/cat1_bridges/nomad-monorepo/report.md`; reviewed commit hash: `f326b402285e3255a654e5e44c919ce412c2bed0`; fixed commit hash: `not provided`; affected release/version range: `TBD-pin-before-submission`.
- [3] Production exploitability verdict: Direct after mapping/configuration drift; exploitable once inconsistent identity state exists.
- [4] Deterministic repro evidence: witness artifacts (`f10_migrate_alias_forge_test.txt`, `f10_migrate_alias_formal_campaign_meta.json`, `f10_migrate_alias_formal_echidna_30s.txt`, `f10_migrate_alias_formal_medusa_30s.txt`). Validation reference: `reports/cat1_bridges/<repo>/manual_audit.md` + listed witness files.
- [5] Mitigation gap proof: Process controls alone cannot maintain one-to-one asset identity invariants; mapping/migration constraints must be enforced in contract logic.
- [6] Business impact quantification: Use the medium loss range below with expected 1-24h disruption, reconciliation, and support overhead.
- [7] Abuse narrative: Attacker leverages identity mapping drift to remap asset semantics, enabling cross-asset confusion or conversion.
- [8] Fix plan + cost: Patch plan: enforce one-to-one mapping invariants, add migration guards, and implement identity-consistency property tests. Estimated effort: 4-10 engineer-days + 2-3 QA days. Estimated remediation cost: ~$30k-$120k including retest.
- Direct exploitation status: Direct after mapping/configuration drift; exploitable once inconsistent identity state exists.
- Mitigation status:
1. Contract-level: not fully mitigated in audited snapshot; witness remains reproducible in referenced artifacts.
2. Operational: compensating controls are partial unless invariant-enforced code changes are deployed and verified.
- Estimated attacker cost: low (~$100-$10,000) for scripted call sequences in affected deployments.
- Estimated loss range: medium-to-high (~$100k-$50M) from token-specific insolvency, leakage, or service degradation.
- Primary mitigation layer: `Mapping invariant enforcement + migration guards`
- Mitigation feasibility: `Medium`
- Residual risk if truly mitigated: `Medium`
- Repo-specific manual check: Verify one-to-one canonical/representation mapping and migration identity invariants across all enrollment/update paths.
- Mitigation acceptance criteria: `Implemented` (fix exists at reviewed commit), `Enforced` (no bypass path exists), and `Demonstrated` (tests/witnesses show the same exploit path is blocked).
- Business impact:
1. Users can convert canonical `A` exposure into canonical `B` settlement path using migrate-assisted flow.
2. Breaks migration assumption that old/new representation upgrades preserve canonical asset identity.
3. Expands F8 impact from send/handle remapping to local opt-in migration conversion.
- Preconditions:
1. Canonical-to-representation mapping can be reconfigured without strict one-to-one invariant enforcement.
2. Migration/conversion logic trusts mutable mapping state as canonical truth.
3. Attacker (or misconfiguration) can create mapping drift before conversion/migration execution.
- Detailed execution:
1. User receives legacy representation `R_A_old` from canonical token `A`.
2. Governance enrolls `R_A_old` as custom representation for canonical `B`.
3. Governance rotates canonical `B` to a new current representation `R_B_new`.
4. User sends `R_B_new` through bridge and receives canonical token `B` remotely.
- Post-exploit objective:
1. Users can convert canonical `A` exposure into canonical `B` settlement path using migrate-assisted flow.
2. Breaks migration assumption that old/new representation upgrades preserve canonical asset identity.
3. Expands F8 impact from send/handle remapping to local opt-in migration conversion.

### nomad-monorepo - F2 (`Medium`)
- Vulnerability type category: `Authorization/governance control compromise and stale-trust acceptance`
- [1] Program/Payout mapping: Policy class: `Access Control / Authorization Integrity / Governance Trust Boundary`; severity tier: `Medium`; target payout band: `$5k-$30k (program-cap dependent)`; recommended claim framing: exploitable security defect with deterministic proof artifact.
- [2] Affected scope (exact): Repo `nomad-monorepo`; component/function `Unenrolling stale replica can desync forward/reverse mappings`; audit reference `reports/cat1_bridges/nomad-monorepo/report.md`; reviewed commit hash: `f326b402285e3255a654e5e44c919ce412c2bed0`; fixed commit hash: `not provided`; affected release/version range: `TBD-pin-before-submission`.
- [3] Production exploitability verdict: Direct once stale authorization or trust-boundary preconditions are present.
- [4] Deterministic repro evidence: witness artifacts (`f1_fuzz_5000_runs.txt`). Validation reference: `reports/cat1_bridges/<repo>/manual_audit.md` + listed witness files.
- [5] Mitigation gap proof: Operational policy does not reliably enforce revocation/current-trust invariants; stale roles/replicas/keys can remain exploitable without contract-level invariant checks.
- [6] Business impact quantification: Use the medium loss range below with expected 1-24h disruption, reconciliation, and support overhead.
- [7] Abuse narrative: Attacker exploits stale or improperly revoked trust relationships to execute privileged calls that appear structurally valid.
- [8] Fix plan + cost: Patch plan: enforce current-trust checks, stale-role revocation invariants, and privileged-path authorization hardening. Estimated effort: 5-14 engineer-days + 2-4 QA days. Estimated remediation cost: ~$40k-$160k including retest.
- Direct exploitation status: Direct once stale authorization or trust-boundary preconditions are present.
- Mitigation status:
1. Contract-level: not fully mitigated in audited snapshot; witness remains reproducible in referenced artifacts.
2. Operational: compensating controls are partial unless invariant-enforced code changes are deployed and verified.
- Estimated attacker cost: low (~$100-$10,000) for scripted call sequences in affected deployments.
- Estimated loss range: medium-to-high (~$100k-$50M) from token-specific insolvency, leakage, or service degradation.
- Primary mitigation layer: `Contract authorization/trust-boundary hardening`
- Mitigation feasibility: `Medium`
- Residual risk if truly mitigated: `Medium`
- Repo-specific manual check: Verify stale roles/replicas/keys are fully revoked and privileged paths enforce current-trust invariants.
- Mitigation acceptance criteria: `Implemented` (fix exists at reviewed commit), `Enforced` (no bypass path exists), and `Demonstrated` (tests/witnesses show the same exploit path is blocked).
- Business impact:
1. Split-brain control state:
2. domain lookup says "no replica"
3. authorization lookup still says active replica is valid
- Preconditions:
1. Stale or over-broad authorization state exists (replica/delegate/guardian/admin trust boundary).
2. Privileged path accepts that stale state as valid caller/proof source.
3. Attacker can invoke the affected call path without target-code modification.
- Detailed execution:
1. `ownerEnrollReplica(R1, D)`
2. `ownerEnrollReplica(R2, D)` (creates stale `replicaToDomain[R1] = D`)
3. `ownerUnenrollReplica(R1)`
- Post-exploit objective:
1. Split-brain control state:
2. domain lookup says "no replica"
3. authorization lookup still says active replica is valid

### nomad-monorepo - F7 (`Medium`)
- Vulnerability type category: `Collateral/accounting insolvency and economic leakage`
- [1] Program/Payout mapping: Policy class: `Business Logic / Accounting Integrity / Value Conservation`; severity tier: `Medium`; target payout band: `$5k-$30k (program-cap dependent)`; recommended claim framing: exploitable security defect with deterministic proof artifact.
- [2] Affected scope (exact): Repo `nomad-monorepo`; component/function `Forged preFill can drain dust pool without providing liquidity`; audit reference `reports/cat1_bridges/nomad-monorepo/report.md`; reviewed commit hash: `f326b402285e3255a654e5e44c919ce412c2bed0`; fixed commit hash: `not provided`; affected release/version range: `TBD-pin-before-submission`.
- [3] Production exploitability verdict: Direct on deployments supporting affected token behavior or residual-balance conditions.
- [4] Deterministic repro evidence: witness artifacts (`f7_prefill_dust_forge_test.txt`, `f7_prefill_dust_formal_campaign_meta.json`, `f7_prefill_dust_formal_echidna_30s.txt`, `f7_prefill_dust_formal_medusa_30s.txt`). Validation reference: `reports/cat1_bridges/<repo>/manual_audit.md` + listed witness files.
- [5] Mitigation gap proof: Token allowlists or ad-hoc controls do not enforce value-conservation invariants; accounting remains exploitable unless balance-delta-safe logic is applied at each boundary.
- [6] Business impact quantification: Use the medium loss range below with expected 1-24h disruption, reconciliation, and support overhead.
- [7] Abuse narrative: Attacker routes value through accounting paths that over-credit liabilities or leak reserves, extracting value while drift accumulates.
- [8] Fix plan + cost: Patch plan: move to balance-delta accounting, enforce conservation invariants, and add token-behavior safety constraints. Estimated effort: 5-12 engineer-days + 2-4 QA days. Estimated remediation cost: ~$35k-$140k including retest.
- Direct exploitation status: Direct on deployments supporting affected token behavior or residual-balance conditions.
- Mitigation status:
1. Contract-level: not fully mitigated in audited snapshot; witness remains reproducible in referenced artifacts.
2. Operational: compensating controls are partial unless invariant-enforced code changes are deployed and verified.
- Estimated attacker cost: low (~$100-$10,000) for scripted call sequences in affected deployments.
- Estimated loss range: medium-to-high (~$100k-$50M) from token-specific insolvency, leakage, or service degradation.
- Primary mitigation layer: `Accounting logic patch + token policy constraints`
- Mitigation feasibility: `High`
- Residual risk if truly mitigated: `Medium`
- Repo-specific manual check: Verify collateral >= liability invariants across taxed/fee-on-transfer/residual-balance scenarios with deterministic + fuzz witnesses.
- Mitigation acceptance criteria: `Implemented` (fix exists at reviewed commit), `Enforced` (no bypass path exists), and `Demonstrated` (tests/witnesses show the same exploit path is blocked).
- Business impact:
1. Native-asset dust reserves can be drained at near-zero token cost.
2. Intended gas-bootstrapping for legitimate bridge recipients can be griefed/denied.
3. Attack can be repeated permissionlessly while dust reserves remain.
- Preconditions:
1. Deployment supports affected token behavior (sender-tax, fee-on-transfer, or residual-balance accounting path).
2. Accounting path credits liabilities or refunds based on intent-level values rather than strict balance deltas.
3. Attacker can execute the bridge action sequence in normal protocol flow.
- Detailed execution:
1. Attacker chooses a valid local token ID and a fresh `(origin, nonce)` pair.
2. Attacker calls `preFill(...)` with forged fast-transfer parameters and `_amount = 0`.
3. `liquidityProvider[id]` is recorded and `transferFrom(msg.sender, recipient, 0)` succeeds with no liquidity provision.
4. `_dust(recipient)` credits/sends `DUST_AMOUNT`.
5. Repeat with new nonce and new low-balance recipients to drain the dust pool.
- Post-exploit objective:
1. Native-asset dust reserves can be drained at near-zero token cost.
2. Intended gas-bootstrapping for legitimate bridge recipients can be griefed/denied.
3. Attack can be repeated permissionlessly while dust reserves remain.

### nomad-monorepo - F8 (`Medium`)
- Vulnerability type category: `Token identity/migration integrity breaks`
- [1] Program/Payout mapping: Policy class: `Business Logic / Asset Identity / State Consistency`; severity tier: `Medium`; target payout band: `$5k-$30k (program-cap dependent)`; recommended claim framing: exploitable security defect with deterministic proof artifact.
- [2] Affected scope (exact): Repo `nomad-monorepo`; component/function `enrollCustom allows representation aliasing across canonical IDs, enabling cross-asset remapping`; audit reference `reports/cat1_bridges/nomad-monorepo/report.md`; reviewed commit hash: `f326b402285e3255a654e5e44c919ce412c2bed0`; fixed commit hash: `not provided`; affected release/version range: `TBD-pin-before-submission`.
- [3] Production exploitability verdict: Direct after mapping/configuration drift; exploitable once inconsistent identity state exists.
- [4] Deterministic repro evidence: witness artifacts (`f8_alias_swap_forge_test.txt`, `f8_alias_swap_formal_campaign_meta.json`, `f8_alias_swap_formal_echidna_30s.txt`, `f8_alias_swap_formal_medusa_30s.txt`). Validation reference: `reports/cat1_bridges/<repo>/manual_audit.md` + listed witness files.
- [5] Mitigation gap proof: Process controls alone cannot maintain one-to-one asset identity invariants; mapping/migration constraints must be enforced in contract logic.
- [6] Business impact quantification: Use the medium loss range below with expected 1-24h disruption, reconciliation, and support overhead.
- [7] Abuse narrative: Attacker leverages identity mapping drift to remap asset semantics, enabling cross-asset confusion or conversion.
- [8] Fix plan + cost: Patch plan: enforce one-to-one mapping invariants, add migration guards, and implement identity-consistency property tests. Estimated effort: 4-10 engineer-days + 2-3 QA days. Estimated remediation cost: ~$30k-$120k including retest.
- Direct exploitation status: Direct after mapping/configuration drift; exploitable once inconsistent identity state exists.
- Mitigation status:
1. Contract-level: not fully mitigated in audited snapshot; witness remains reproducible in referenced artifacts.
2. Operational: compensating controls are partial unless invariant-enforced code changes are deployed and verified.
- Estimated attacker cost: low (~$100-$10,000) for scripted call sequences in affected deployments.
- Estimated loss range: medium-to-high (~$100k-$50M) from token-specific insolvency, leakage, or service degradation.
- Primary mitigation layer: `Mapping invariant enforcement + migration guards`
- Mitigation feasibility: `Medium`
- Residual risk if truly mitigated: `Medium`
- Repo-specific manual check: Verify one-to-one canonical/representation mapping and migration identity invariants across all enrollment/update paths.
- Mitigation acceptance criteria: `Implemented` (fix exists at reviewed commit), `Enforced` (no bypass path exists), and `Demonstrated` (tests/witnesses show the same exploit path is blocked).
- Business impact:
1. Cross-asset remapping becomes possible after a single configuration mistake.
2. Users can effectively convert canonical `A` exposure into canonical `B` settlement path.
3. Breaks token identity/conservation assumptions across chains until governance correction.
- Preconditions:
1. Canonical-to-representation mapping can be reconfigured without strict one-to-one invariant enforcement.
2. Migration/conversion logic trusts mutable mapping state as canonical truth.
3. Attacker (or misconfiguration) can create mapping drift before conversion/migration execution.
- Detailed execution:
1. Enroll custom representation `X` for canonical token `A`.
2. Enroll the same `X` again for canonical token `B`.
3. Incoming transfer for `A` mints `X` locally.
4. User sends `X` back through bridge.
5. `getTokenId(X)` resolves to `B`, so remote settlement releases/mints `B`, not `A`.
- Post-exploit objective:
1. Cross-asset remapping becomes possible after a single configuration mistake.
2. Users can effectively convert canonical `A` exposure into canonical `B` settlement path.
3. Breaks token identity/conservation assumptions across chains until governance correction.

### nomad-monorepo - F9 (`Medium`)
- Vulnerability type category: `Runtime liveness and DoS via unsafe input/state handling`
- [1] Program/Payout mapping: Policy class: `Availability / Input Validation / Runtime Safety`; severity tier: `Medium`; target payout band: `$5k-$30k (program-cap dependent)`; recommended claim framing: exploitable security defect with deterministic proof artifact.
- [2] Affected scope (exact): Repo `nomad-monorepo`; component/function `Governance domain-list churn inflates global dispatch scans (liveness/gas degradation)`; audit reference `reports/cat1_bridges/nomad-monorepo/report.md`; reviewed commit hash: `f326b402285e3255a654e5e44c919ce412c2bed0`; fixed commit hash: `not provided`; affected release/version range: `TBD-pin-before-submission`.
- [3] Production exploitability verdict: Direct low-cost liveness degradation via repeated governance domain churn.
- [4] Deterministic repro evidence: witness artifacts (`f9_domain_churn_forge_test.txt`, `f9_domain_churn_formal_campaign_meta.json`, `f9_domain_churn_formal_echidna_30s.txt`, `f9_domain_churn_formal_medusa_30s.txt`). Validation reference: `reports/cat1_bridges/<repo>/manual_audit.md` + listed witness files.
- [5] Mitigation gap proof: Input filters and operational guards are incomplete; panic-prone or unbounded paths remain reachable until converted to explicit error-handled flows.
- [6] Business impact quantification: Use the medium loss range below with expected 1-24h disruption, reconciliation, and support overhead.
- [7] Abuse narrative: Attacker repeatedly submits crafted inputs/state transitions that trigger panic/revert-heavy liveness failures.
- [8] Fix plan + cost: Patch plan: replace panic paths with explicit errors, add adversarial input tests, and bound liveness-sensitive loops. Estimated effort: 3-9 engineer-days + 1-3 QA days. Estimated remediation cost: ~$20k-$100k including retest.
- Direct exploitation status: Direct low-cost liveness degradation via repeated governance domain churn.
- Mitigation status:
1. Contract-level: not fully mitigated in audited snapshot; witness remains reproducible in referenced artifacts.
2. Operational: compensating controls are partial unless invariant-enforced code changes are deployed and verified.
- Estimated attacker cost: low (~$100-$10,000) for scripted call sequences in affected deployments.
- Estimated loss range: medium-to-high (~$100k-$50M) from token-specific insolvency, leakage, or service degradation.
- Primary mitigation layer: `Input validation + panic-free runtime handling`
- Mitigation feasibility: `High`
- Residual risk if truly mitigated: `Low-Medium`
- Repo-specific manual check: Verify untrusted inputs fail gracefully (no panic/chain-halt) and liveness-sensitive loops remain bounded under adversarial sequences.
- Mitigation acceptance criteria: `Implemented` (fix exists at reviewed commit), `Enforced` (no bypass path exists), and `Demonstrated` (tests/witnesses show the same exploit path is blocked).
- Business impact:
1. Governance broadcast operations can become progressively more expensive despite unchanged active topology.
2. Sustained churn can push global dispatches toward practical gas/liveness limits.
3. Operational safety margins degrade over time unless state is compacted.
- Preconditions:
1. Untrusted input/state can reach panic-prone or expensive runtime path.
2. Fail-fast behavior is panic/revert-heavy instead of explicit bounded error handling.
3. Attacker can repeatedly trigger the path with low-cost transactions/messages.
- Detailed execution:
1. Configure a single remote domain `D` with a router.
2. Repeat churn cycle `N` times: remove `D`, then re-add `D`.
3. Dispatch a global governance action (modeled `dispatchAll()` in the harness).
- Post-exploit objective:
1. Governance broadcast operations can become progressively more expensive despite unchanged active topology.
2. Sustained churn can push global dispatches toward practical gas/liveness limits.
3. Operational safety margins degrade over time unless state is compacted.

### synapse-contracts - F1 (`Medium`)
- Vulnerability type category: `Collateral/accounting insolvency and economic leakage`
- [1] Program/Payout mapping: Policy class: `Business Logic / Accounting Integrity / Value Conservation`; severity tier: `Medium`; target payout band: `$5k-$30k (program-cap dependent)`; recommended claim framing: exploitable security defect with deterministic proof artifact.
- [2] Affected scope (exact): Repo `synapse-contracts`; component/function `deposit / depositAndSwap intent-level amount handling can over-credit cross-chain liabilities for fee-on-transfer tokens`; audit reference `reports/cat1_bridges/synapse-contracts/report.md`; reviewed commit hash: `60f1c25cf2f115911e11255f515e1450fe96100c`; fixed commit hash: `not provided`; affected release/version range: `TBD-pin-before-submission`.
- [3] Production exploitability verdict: Direct on deployments supporting affected token behavior or residual-balance conditions.
- [4] Deterministic repro evidence: witness artifacts (`f1_deposit_fee_on_transfer_forge_test.txt`, `f1_deposit_fee_on_transfer_formal_campaign_meta.json`, `f1_deposit_fee_on_transfer_formal_echidna_30s.txt`, `f1_deposit_fee_on_transfer_formal_medusa_30s.txt`). Validation reference: `reports/cat1_bridges/<repo>/manual_audit.md` + listed witness files.
- [5] Mitigation gap proof: Token allowlists or ad-hoc controls do not enforce value-conservation invariants; accounting remains exploitable unless balance-delta-safe logic is applied at each boundary.
- [6] Business impact quantification: Use the medium loss range below with expected 1-24h disruption, reconciliation, and support overhead.
- [7] Abuse narrative: Attacker routes value through accounting paths that over-credit liabilities or leak reserves, extracting value while drift accumulates.
- [8] Fix plan + cost: Patch plan: move to balance-delta accounting, enforce conservation invariants, and add token-behavior safety constraints. Estimated effort: 5-12 engineer-days + 2-4 QA days. Estimated remediation cost: ~$35k-$140k including retest.
- Direct exploitation status: Direct on deployments supporting affected token behavior or residual-balance conditions.
- Mitigation status:
1. Contract-level: not fully mitigated in audited snapshot; witness remains reproducible in referenced artifacts.
2. Operational: compensating controls are partial unless invariant-enforced code changes are deployed and verified.
- Estimated attacker cost: low (~$100-$10,000) for scripted call sequences in affected deployments.
- Estimated loss range: medium-to-high (~$100k-$50M) from token-specific insolvency, leakage, or service degradation.
- Primary mitigation layer: `Accounting logic patch + token policy constraints`
- Mitigation feasibility: `High`
- Residual risk if truly mitigated: `Medium`
- Repo-specific manual check: Verify collateral >= liability invariants across taxed/fee-on-transfer/residual-balance scenarios with deterministic + fuzz witnesses.
- Mitigation acceptance criteria: `Implemented` (fix exists at reviewed commit), `Enforced` (no bypass path exists), and `Demonstrated` (tests/witnesses show the same exploit path is blocked).
- Business impact:
1. For affected tokens, source-chain collateral can be lower than destination-side credited amount.
2. This creates token-specific shortfall/insolvency behavior on settlement paths.
- Preconditions:
1. Deployment supports affected token behavior (sender-tax, fee-on-transfer, or residual-balance accounting path).
2. Accounting path credits liabilities or refunds based on intent-level values rather than strict balance deltas.
3. Attacker can execute the bridge action sequence in normal protocol flow.
- Detailed execution:
1. Configure fee-on-transfer token behavior (5% haircut when bridge contract is recipient).
2. Call `deposit(100_000)` (or `depositAndSwap(100_000)`).
3. Bridge contract receives only `95_000` collateral.
4. Cross-chain liability/credit intent remains `100_000`.
5. Post-state violates coverage invariant (`collateral < remoteLiability`).
- Post-exploit objective:
1. For affected tokens, source-chain collateral can be lower than destination-side credited amount.
2. This creates token-specific shortfall/insolvency behavior on settlement paths.

### synapse-contracts - F3 (`Medium`)
- Vulnerability type category: `Collateral/accounting insolvency and economic leakage`
- [1] Program/Payout mapping: Policy class: `Business Logic / Accounting Integrity / Value Conservation`; severity tier: `Medium`; target payout band: `$5k-$30k (program-cap dependent)`; recommended claim framing: exploitable security defect with deterministic proof artifact.
- [2] Affected scope (exact): Repo `synapse-contracts`; component/function `Destination min-out can be violated on actual user receipt when payout token transfer applies sender-side tax`; audit reference `reports/cat1_bridges/synapse-contracts/report.md`; reviewed commit hash: `60f1c25cf2f115911e11255f515e1450fe96100c`; fixed commit hash: `not provided`; affected release/version range: `TBD-pin-before-submission`.
- [3] Production exploitability verdict: Direct on deployments supporting affected token behavior or residual-balance conditions.
- [4] Deterministic repro evidence: witness artifacts (`f2_f3_role_and_minout_forge_test.txt`, `f2_f3_role_and_minout_fuzz_5000_runs.txt`, `f3_min_out_receipt_mismatch_formal_campaign_meta.json`, `f3_min_out_receipt_mismatch_formal_echidna_30s.txt`). Validation reference: `reports/cat1_bridges/<repo>/manual_audit.md` + listed witness files.
- [5] Mitigation gap proof: Token allowlists or ad-hoc controls do not enforce value-conservation invariants; accounting remains exploitable unless balance-delta-safe logic is applied at each boundary.
- [6] Business impact quantification: Use the medium loss range below with expected 1-24h disruption, reconciliation, and support overhead.
- [7] Abuse narrative: Attacker routes value through accounting paths that over-credit liabilities or leak reserves, extracting value while drift accumulates.
- [8] Fix plan + cost: Patch plan: move to balance-delta accounting, enforce conservation invariants, and add token-behavior safety constraints. Estimated effort: 5-12 engineer-days + 2-4 QA days. Estimated remediation cost: ~$35k-$140k including retest.
- Direct exploitation status: Direct on deployments supporting affected token behavior or residual-balance conditions.
- Mitigation status:
1. Contract-level: not fully mitigated in audited snapshot; witness remains reproducible in referenced artifacts.
2. Operational: compensating controls are partial unless invariant-enforced code changes are deployed and verified.
- Estimated attacker cost: low (~$100-$10,000) for scripted call sequences in affected deployments.
- Estimated loss range: medium-to-high (~$100k-$50M) from token-specific insolvency, leakage, or service degradation.
- Primary mitigation layer: `Accounting logic patch + token policy constraints`
- Mitigation feasibility: `High`
- Residual risk if truly mitigated: `Medium`
- Repo-specific manual check: Verify collateral >= liability invariants across taxed/fee-on-transfer/residual-balance scenarios with deterministic + fuzz witnesses.
- Mitigation acceptance criteria: `Implemented` (fix exists at reviewed commit), `Enforced` (no bypass path exists), and `Demonstrated` (tests/witnesses show the same exploit path is blocked).
- Business impact:
1. User-facing min-out guarantees can be violated for affected token classes.
2. Quote-to-execution safety assumptions can break under taxed/deflationary destination payout assets.
- Preconditions:
1. Deployment supports affected token behavior (sender-tax, fee-on-transfer, or residual-balance accounting path).
2. Accounting path credits liabilities or refunds based on intent-level values rather than strict balance deltas.
3. Attacker can execute the bridge action sequence in normal protocol flow.
- Detailed execution:
1. Configure payout token behavior with 5% sender-side transfer tax when bridge contract sends.
2. Execute modeled destination settlement with `quotedOut=100_000`, `minOut=98_000`.
3. Pre-transfer checks pass; transfer succeeds.
4. Recipient receives `95_000` (< `98_000`), violating min-out guarantee on actual receipt.
5. Fixed control reverts when `actualReceived < minOut`.
- Post-exploit objective:
1. User-facing min-out guarantees can be violated for affected token classes.
2. Quote-to-execution safety assumptions can break under taxed/deflationary destination payout assets.

### wormhole - W3 (`Medium`)
- Vulnerability type category: `Collateral/accounting insolvency and economic leakage`
- [1] Program/Payout mapping: Policy class: `Business Logic / Accounting Integrity / Value Conservation`; severity tier: `Medium`; target payout band: `$5k-$30k (program-cap dependent)`; recommended claim framing: exploitable security defect with deterministic proof artifact.
- [2] Affected scope (exact): Repo `wormhole`; component/function `Outbound sender-tax tokens can break bridge token solvency accounting`; audit reference `reports/cat1_bridges/wormhole/report.md`; reviewed commit hash: `e11926a849391e8a035c69fc52f4efb3205258fd`; fixed commit hash: `not provided`; affected release/version range: `TBD-pin-before-submission`.
- [3] Production exploitability verdict: Direct on deployments supporting affected token behavior or residual-balance conditions.
- [4] Deterministic repro evidence: witness artifacts (`w3_outbound_sender_tax_forge_test.txt`, `w3_outbound_sender_tax_formal_campaign_meta.json`, `w3_outbound_sender_tax_formal_echidna_30s.txt`, `w3_outbound_sender_tax_formal_medusa_30s.txt`). Validation reference: `reports/cat1_bridges/<repo>/manual_audit.md` + listed witness files.
- [5] Mitigation gap proof: Token allowlists or ad-hoc controls do not enforce value-conservation invariants; accounting remains exploitable unless balance-delta-safe logic is applied at each boundary.
- [6] Business impact quantification: Use the medium loss range below with expected 1-24h disruption, reconciliation, and support overhead.
- [7] Abuse narrative: Attacker routes value through accounting paths that over-credit liabilities or leak reserves, extracting value while drift accumulates.
- [8] Fix plan + cost: Patch plan: move to balance-delta accounting, enforce conservation invariants, and add token-behavior safety constraints. Estimated effort: 5-12 engineer-days + 2-4 QA days. Estimated remediation cost: ~$35k-$140k including retest.
- Direct exploitation status: Direct on deployments supporting affected token behavior or residual-balance conditions.
- Mitigation status:
1. Contract-level: not fully mitigated in audited snapshot; witness remains reproducible in referenced artifacts.
2. Operational: compensating controls are partial unless invariant-enforced code changes are deployed and verified.
- Estimated attacker cost: low (~$100-$10,000) for scripted call sequences in affected deployments.
- Estimated loss range: medium-to-high (~$100k-$50M) from token-specific insolvency, leakage, or service degradation.
- Primary mitigation layer: `Accounting logic patch + token policy constraints`
- Mitigation feasibility: `High`
- Residual risk if truly mitigated: `Medium`
- Repo-specific manual check: Verify collateral >= liability invariants across taxed/fee-on-transfer/residual-balance scenarios with deterministic + fuzz witnesses.
- Mitigation acceptance criteria: `Implemented` (fix exists at reviewed commit), `Enforced` (no bypass path exists), and `Demonstrated` (tests/witnesses show the same exploit path is blocked).
- Business impact:
1. For affected token classes, redemption can drive bridge accounting insolvent for that token.
2. Result is token-specific fund shortfall/stuck redemption risk (not cross-token theft), but still a concrete bridge-side accounting break for listed token behavior.
- Preconditions:
1. Deployment supports affected token behavior (sender-tax, fee-on-transfer, or residual-balance accounting path).
2. Accounting path credits liabilities or refunds based on intent-level values rather than strict balance deltas.
3. Attacker can execute the bridge action sequence in normal protocol flow.
- Detailed execution:
1. Seed bridge collateral/outstanding for a token via inbound path.
2. Redeem an outbound transfer for the same token.
3. Token applies sender-tax only when bridge is sender, debiting bridge by more than redeemed amount.
4. Bridge reduces `outstanding` only by redeemed amount.
5. Post-transfer state violates collateral coverage (`collateral < outstanding`), causing token-specific insolvency / future redemption failures.
- Post-exploit objective:
1. For affected token classes, redemption can drive bridge accounting insolvent for that token.
2. Result is token-specific fund shortfall/stuck redemption risk (not cross-token theft), but still a concrete bridge-side accounting break for listed token behavior.

### wormhole - W1 (`Low`)
- Vulnerability type category: `Runtime liveness and DoS via unsafe input/state handling`
- [1] Program/Payout mapping: Policy class: `Availability / Input Validation / Runtime Safety`; severity tier: `Low`; target payout band: `$1k-$10k (program-cap dependent)`; recommended claim framing: exploitable security defect with deterministic proof artifact.
- [2] Affected scope (exact): Repo `wormhole`; component/function `Metadata-method assumptions in attestToken / _transferTokens cause deterministic token-specific DoS`; audit reference `reports/cat1_bridges/wormhole/report.md`; reviewed commit hash: `e11926a849391e8a035c69fc52f4efb3205258fd`; fixed commit hash: `not provided`; affected release/version range: `TBD-pin-before-submission`.
- [3] Production exploitability verdict: Direct token-specific DoS for metadata-incompatible assets.
- [4] Deterministic repro evidence: witness artifacts (`w1_metadata_dos_forge_test.txt`, `w1_metadata_dos_formal_campaign_meta.json`, `w1_metadata_dos_formal_echidna_30s.txt`, `w1_metadata_dos_formal_medusa_30s.txt`). Validation reference: `reports/cat1_bridges/<repo>/manual_audit.md` + listed witness files.
- [5] Mitigation gap proof: Input filters and operational guards are incomplete; panic-prone or unbounded paths remain reachable until converted to explicit error-handled flows.
- [6] Business impact quantification: Use the lower loss range below while accounting for persistent reliability/support and partner-dispute costs.
- [7] Abuse narrative: Attacker repeatedly submits crafted inputs/state transitions that trigger panic/revert-heavy liveness failures.
- [8] Fix plan + cost: Patch plan: replace panic paths with explicit errors, add adversarial input tests, and bound liveness-sensitive loops. Estimated effort: 3-9 engineer-days + 1-3 QA days. Estimated remediation cost: ~$20k-$100k including retest.
- Direct exploitation status: Direct token-specific DoS for metadata-incompatible assets.
- Mitigation status:
1. Contract-level: not fully mitigated in audited snapshot; witness remains reproducible in referenced artifacts.
2. Operational: compensating controls are partial unless invariant-enforced code changes are deployed and verified.
- Estimated attacker cost: very low (~$0-$2,000) for repeated crafted calls.
- Estimated loss range: low-to-medium (~$10k-$5M) mainly from service disruption, support burden, and integration fallout.
- Primary mitigation layer: `Input validation + panic-free runtime handling`
- Mitigation feasibility: `High`
- Residual risk if truly mitigated: `Low-Medium`
- Repo-specific manual check: Verify untrusted inputs fail gracefully (no panic/chain-halt) and liveness-sensitive loops remain bounded under adversarial sequences.
- Mitigation acceptance criteria: `Implemented` (fix exists at reviewed commit), `Enforced` (no bypass path exists), and `Demonstrated` (tests/witnesses show the same exploit path is blocked).
- Business impact:
1. Affected tokens cannot be attested/bridged via this bridge path.
2. Impact is token-specific DoS (no cross-token theft), but behavior contradicts the in-code support claim.
- Preconditions:
1. Untrusted input/state can reach panic-prone or expensive runtime path.
2. Fail-fast behavior is panic/revert-heavy instead of explicit bounded error handling.
3. Attacker can repeatedly trigger the path with low-cost transactions/messages.
- Detailed execution:
1. Call attestation path with a token that omits metadata methods.
2. `staticcall` fails/returns empty bytes.
3. `abi.decode` reverts, blocking attestation.
4. Same metadata assumption in transfer path blocks bridging for the same token class.
- Post-exploit objective:
1. Affected tokens cannot be attested/bridged via this bridge path.
2. Impact is token-specific DoS (no cross-token theft), but behavior contradicts the in-code support claim.

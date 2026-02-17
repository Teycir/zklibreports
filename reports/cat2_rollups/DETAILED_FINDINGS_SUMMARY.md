## Grouped by Vulnerability Type

1. `Initialization/upgrade first-caller takeover`
Covers `zkevm-contracts` (`F-ZKEVMC-01`), `scroll-contracts` (`F-SCROLL-01`), `linea-contracts` (`F-LINEA-03`), `era-contracts` (`F-ERAC-01`), `base-contracts` (`F-BASE-01`), `optimism` (`F-OPT-01`), `linea-contracts` (`F-LINEA-02`), `taiko-contracts` (`F-TAIKO-02`), `taiko-mono` (`F-TAIKOMONO-02`).
Shared business impact is unauthorized control capture during non-atomic deploy/upgrade windows, enabling fund diversion, state tampering, forged records, and liveness outages.
2. `Privilege and settlement-logic integrity flaws`
Covers `linea-contracts` (`F-LINEA-01`), `mantle` (`F-MAN-01`), `mantle` (`F-MAN-04`), `mantle` (`F-MAN-02`), `mantle` (`F-MAN-03`).
Shared business impact is unfair/disputed settlement outcomes, unjust slashing or deadlocked disputes, and higher governance/incident-response cost.
3. `Prover reliability and crashable execution paths`
Covers `era-boojum` (`F-ERA-01`), `zkevm-circuits` (`F-ZKEVM-01`), `zkevm-circuits` (`F-ZKEVM-02`).
Shared business impact is prover instability, delayed finality, SLA breaches, and sustained infrastructure spend.
4. `Integration-facing data validity flaws`
Covers `taiko-contracts` (`F-TAIKO-01`), `taiko-mono` (`F-TAIKOMONO-01`).
Shared business impact is unauthorized reward/access claims and false denials that create direct campaign losses, support burden, and trust damage.

### zkevm-contracts - F-ZKEVMC-01 (`Critical`)
- Vulnerability type category: `Initialization/upgrade first-caller takeover`
- Repository activity flag (9-month rule): Active (latest commit: 2025-10-22; cutoff: 2025-05-17).
- [1] Program/Payout mapping: Policy class: `Access Control / Unsafe Initialization / Upgrade Integrity`; severity tier: `Critical`; target payout band: `$50k-$250k+ (program-cap dependent)`; recommended claim framing: exploitable security defect with deterministic proof artifact.
- [2] Affected scope (exact): Repo `zkevm-contracts`; component/function `AggLayerGateway.initialize(...)`; audit reference `reports/cat2_rollups/zkevm-contracts/report.md`; reviewed commit hash: `TBD-pin-before-submission`; fixed commit hash: `not provided`; affected release/version range: `TBD-pin-before-submission`.
- [3] Production exploitability verdict: Conditional-direct in production: exploitable whenever a non-atomic deploy/upgrade path is used.
- [4] Deterministic repro evidence: Forge counterexample (`f_zkevmc_01_agglayer_gateway_init_hijack_forge_test.txt`). Validation reference: `reports/cat2_rollups/PROVEN_SUMMARY.md`.
- [5] Mitigation gap proof: Current controls are brittle to process variance: a single non-atomic path (manual/emergency/non-canonical script) reopens first-caller capture. Mitigation is incomplete unless atomicity is enforced on every upgrade/deploy path plus contract-side caller guard.
- [6] Business impact quantification: Use the loss range above as primary financial anchor; include likely 4-72h emergency-response window, partner escalation, and potential governance/bridge operations freeze externalities.
- [7] Abuse narrative: Attacker monitors deployment/governance activity, races first-call initialization, captures privileged control, then monetizes via fund routing, unauthorized mint/state writes, or liveness extortion.
- [8] Fix plan + cost: Patch plan: enforce atomic `upgradeAndCall`/deploy+init in all scripts + add contract-side initializer caller restriction. Estimated effort: 3-8 engineer-days + 1-2 QA days. Estimated remediation cost: ~$20k-$90k including retest.
- Direct exploitation status: conditional-direct. Exploitable as soon as a non-atomic proxy deploy/upgrade window exists.
- Mitigation status:
1. Contract-level: not mitigated (`initialize(...)` remains first-caller).
2. Operational: partial. Atomic `upgradeAndCall`/constructor init can remove the window, but any non-atomic path reintroduces risk.
- Estimated attacker cost: low-to-medium (`~$500-$25,000`) for monitoring, prioritized tx inclusion, and follow-on role actions.
- Estimated loss range: very high (`~$25M-$1B+`) per major incident, depending on bridged TVL exposure and incident duration.
- Primary mitigation layer: Contract + deployment pipeline
- Mitigation feasibility: High
- Residual risk if truly mitigated: Medium (if only ops), Low (if contract guard + atomic flow)
- Repo-specific manual check: Verify every gateway upgrade path uses atomic init; reject any plain `upgrade` path; review runbooks and executed upgrade tx patterns.
- Mitigation acceptance criteria: `Implemented` (fix exists at reviewed commit), `Enforced` (no bypass path exists), and `Demonstrated` (tests/witnesses show the same exploit path is blocked).
- Business impact:
1. Invalid-proof acceptance or valid-proof rejection can break settlement integrity and put bridged funds/TVL at risk.
2. Emergency governance response can pause bridge flows, causing withdrawal delays and protocol revenue loss.
3. Control-plane compromise materially damages partner and user trust in rollup security.
- Preconditions:
1. `AggLayerGateway` proxy is deployed/upgraded with a non-atomic flow (`upgrade` without immediate `initialize`).
2. Attacker can monitor pending governance transactions and submit prioritized transactions.
3. Role recipient addresses in initializer arguments are caller-controlled.
- Detailed execution:
1. Attacker runs a watcher for `ProxyAdmin.upgrade` transactions targeting the ALGateway proxy.
2. As soon as the upgrade transaction is observed/confirmed, attacker prepares `initialize(...)` calldata with attacker-controlled admin and route-role addresses.
3. Attacker submits `initialize(...)` with higher priority fee to land before operations' initializer call.
4. Contract grants `DEFAULT_ADMIN_ROLE`, route management roles, and default vkey roles to attacker addresses.
5. Legitimate initializer fails because initializer version is consumed.
6. Attacker adds a permissive verifier route or freezes legitimate routes.
7. Dependent verification calls execute through attacker-controlled governance state.
- Post-exploit objective:
1. Accept invalid proofs or block valid proofs.
2. Hold liveness hostage and pressure governance under incident conditions.
3. Convert trust failure into financial gain or extortion leverage.

### scroll-contracts - F-SCROLL-01 (`Critical`)
- Vulnerability type category: `Initialization/upgrade first-caller takeover`
- Repository activity flag (9-month rule): Active (latest commit: 2026-02-11; cutoff: 2025-05-17).
- [1] Program/Payout mapping: Policy class: `Access Control / Unsafe Initialization / Upgrade Integrity`; severity tier: `Critical`; target payout band: `$50k-$250k+ (program-cap dependent)`; recommended claim framing: exploitable security defect with deterministic proof artifact.
- [2] Affected scope (exact): Repo `scroll-contracts`; component/function `ScrollChain.initialize(...)`; audit reference `reports/cat2_rollups/scroll-contracts/report.md`; reviewed commit hash: `TBD-pin-before-submission`; fixed commit hash: `not provided`; affected release/version range: `TBD-pin-before-submission`.
- [3] Production exploitability verdict: Conditional-direct in production: exploitable on split upgrade-then-initialize execution.
- [4] Deterministic repro evidence: Forge + Medusa + Echidna + Halmos counterexamples (`f_scroll_01_scrollchain_init_hijack_forge_test.txt`, `f_scroll_01_medusa_failfast_30s.txt`, `f_scroll_01_echidna_30s.txt`, `f_scroll_01_halmos.txt`). Validation reference: `reports/cat2_rollups/PROVEN_SUMMARY.md`.
- [5] Mitigation gap proof: Current controls are brittle to process variance: a single non-atomic path (manual/emergency/non-canonical script) reopens first-caller capture. Mitigation is incomplete unless atomicity is enforced on every upgrade/deploy path plus contract-side caller guard.
- [6] Business impact quantification: Use the loss range above as primary financial anchor; include likely 4-72h emergency-response window, partner escalation, and potential governance/bridge operations freeze externalities.
- [7] Abuse narrative: Attacker monitors deployment/governance activity, races first-call initialization, captures privileged control, then monetizes via fund routing, unauthorized mint/state writes, or liveness extortion.
- [8] Fix plan + cost: Patch plan: enforce atomic `upgradeAndCall`/deploy+init in all scripts + add contract-side initializer caller restriction. Estimated effort: 3-8 engineer-days + 1-2 QA days. Estimated remediation cost: ~$20k-$90k including retest.
- Direct exploitation status: conditional-direct. Exploitable in upgrade-then-initialize flows.
- Mitigation status:
1. Contract-level: not mitigated (`initialize(...)` is first-caller).
2. Operational: weak in cited flow (script uses separate `upgrade` then `initialize`); atomic init in same tx is the primary mitigation.
- Estimated attacker cost: low-to-medium (`~$300-$15,000`) for mempool monitoring plus one or two priority transactions.
- Estimated loss range: very high (`~$10M-$500M+`) from control-plane takeover, halted operations, and potential asset trust failure.
- Primary mitigation layer: Deployment scripts + contract hardening
- Mitigation feasibility: High
- Residual risk if truly mitigated: Medium (ops-only), Low (with contract-level caller guard)
- Repo-specific manual check: Confirm `InitializeL1BridgeContracts` style split flow is removed or blocked; verify all env scripts produce same-tx init.
- Mitigation acceptance criteria: `Implemented` (fix exists at reviewed commit), `Enforced` (no bypass path exists), and `Demonstrated` (tests/witnesses show the same exploit path is blocked).
- Business impact:
1. Unauthorized owner control over sequencer/prover configuration can cause censorship or halt production.
2. Bridge/message finalization delays can trap user funds and create liquidity stress across venues.
3. Forced incident upgrades and recovery increase operational cost and reputational damage.
- Preconditions:
1. Operations use separate `upgrade` then `initialize` transactions for `ScrollChain`.
2. Owner role after init is derived from first initializer caller.
3. Attacker has mempool monitoring and rapid tx submission capability.
- Detailed execution:
1. Attacker tracks pending txs from deployment/governance addresses that call proxy `upgrade` for `ScrollChain`.
2. After upgrade lands, attacker immediately calls `initialize(...)` before the intended operator.
3. `OwnableUpgradeable` initializes owner as attacker-controlled caller context.
4. Intended initializer transaction reverts due consumed initializer state.
5. Attacker uses owner privileges to modify sequencer/prover sets and pause controls.
6. Attacker sequences censorship, liveness outages, or forced governance response.
- Post-exploit objective:
1. Operational chain takeover in practice.
2. Liveness disruption during high-value market windows.
3. Governance coercion through prolonged service interruption.

### linea-contracts - F-LINEA-01 (`Critical`)
- Vulnerability type category: `Privilege and settlement-logic integrity flaws`
- Repository activity flag (9-month rule): Inactive (latest commit: 2024-09-11; cutoff: 2025-05-17).
- [1] Program/Payout mapping: Policy class: `Protocol Integrity / Privilege Logic / Settlement Correctness`; severity tier: `Critical`; target payout band: `$50k-$250k+ (program-cap dependent)`; recommended claim framing: exploitable security defect with deterministic proof artifact.
- [2] Affected scope (exact): Repo `linea-contracts`; component/function `LineaRollup.initializeParentShnarfsAndFinalizedState(...)`; audit reference `reports/cat2_rollups/linea-contracts/report.md`; reviewed commit hash: `TBD-pin-before-submission`; fixed commit hash: `not provided`; affected release/version range: `TBD-pin-before-submission`.
- [3] Production exploitability verdict: Direct (permissionless) while `reinitializer(5)` remains callable.
- [4] Deterministic repro evidence: Forge + Medusa + Echidna + Halmos counterexamples (`f_linea_01_reinitializer_dos_forge_test.txt`, `f_linea_01_medusa_failfast_30s.txt`, `f_linea_01_echidna_30s.txt`, `f_linea_01_halmos.txt`). Validation reference: `reports/cat2_rollups/PROVEN_SUMMARY.md`.
- [5] Mitigation gap proof: Runbook-only controls do not close logic defects. Without invariant-enforced code changes, authorized actors can still trigger unfair settlement or liveness break conditions.
- [6] Business impact quantification: Use the loss range above as primary financial anchor; include likely 4-72h emergency-response window, partner escalation, and potential governance/bridge operations freeze externalities.
- [7] Abuse narrative: Attacker/operator leverages flawed settlement or authorization invariants to force unfair outcomes, suppress challengers, or deadlock dispute progression under apparently valid calls.
- [8] Fix plan + cost: Patch plan: redesign vulnerable branch/invariant logic, add property tests for settlement/challenge lifecycle, and run adversarial regression suite. Estimated effort: 6-15 engineer-days + 2-4 QA days. Estimated remediation cost: ~$50k-$180k including retest.
- Direct exploitation status: direct-permissionless (while `reinitializer(5)` is callable).
- Mitigation status:
1. Contract-level: not mitigated (no role guard on privileged reinitializer path).
2. Operational: limited. Requires emergency governance/upgrade response after compromise.
- Estimated attacker cost: low (`~$100-$5,000`) because a single permissionless tx can trigger the state-poisoning condition.
- Estimated loss range: high (`~$2M-$100M`) from prolonged liveness outage, emergency upgrades, and delayed user fund mobility.
- Primary mitigation layer: Contract access control redesign
- Mitigation feasibility: Medium
- Residual risk if truly mitigated: Low-Medium
- Repo-specific manual check: Verify privileged `reinitializer(5)` is role-guarded or removed; confirm governance recovery path cannot be attacker-consumed first.
- Mitigation acceptance criteria: `Implemented` (fix exists at reviewed commit), `Enforced` (no bypass path exists), and `Demonstrated` (tests/witnesses show the same exploit path is blocked).
- Business impact:
1. Poisoned finalized-state continuity can halt submission/finality and delay deposits/withdrawals.
2. Emergency governance intervention introduces downtime and high cross-team coordination cost.
3. Reliability incidents can trigger partner SLA breaches and user churn.
- Preconditions:
1. Rollup contract is already at a state where `reinitializer(5)` remains callable.
2. Function is externally callable with no role restriction.
3. Attacker can choose parent shnarf and final block values.
- Detailed execution:
1. Attacker identifies canonical parent shnarf used by submission path.
2. Attacker calls `initializeParentShnarfsAndFinalizedState(...)` with poisoned final-block data (e.g., max value for wrap/continuity break).
3. Storage mapping for parent-final-block continuity is overwritten with attacker-supplied value.
4. Subsequent normal submission attempts fail continuity checks.
5. Admin cannot replay the same reinitializer because version is consumed.
6. Recovery requires privileged upgrade/governance path rather than normal migration flow.
- Post-exploit objective:
1. Halt submission/finality path.
2. Create visible reliability incident and confidence shock.
3. Force expensive emergency operations.

### mantle - F-MAN-01 (`Critical`)
- Vulnerability type category: `Privilege and settlement-logic integrity flaws`
- Repository activity flag (9-month rule): Inactive (latest commit: 2023-08-16; cutoff: 2025-05-17).
- [1] Program/Payout mapping: Policy class: `Protocol Integrity / Privilege Logic / Settlement Correctness`; severity tier: `Critical`; target payout band: `$50k-$250k+ (program-cap dependent)`; recommended claim framing: exploitable security defect with deterministic proof artifact.
- [2] Affected scope (exact): Repo `mantle`; component/function `Challenge.completeChallenge(bool)`; audit reference `reports/cat2_rollups/mantle/report.md`; reviewed commit hash: `TBD-pin-before-submission`; fixed commit hash: `not provided`; affected release/version range: `TBD-pin-before-submission`.
- [3] Production exploitability verdict: Direct but role-constrained: requires defender control in active challenge settlement path.
- [4] Deterministic repro evidence: Echidna + Halmos counterexamples (`f_man_01_echidna_30s.txt`, `f_man_01_halmos.txt`). Validation reference: `reports/cat2_rollups/PROVEN_SUMMARY.md`.
- [5] Mitigation gap proof: Runbook-only controls do not close logic defects. Without invariant-enforced code changes, authorized actors can still trigger unfair settlement or liveness break conditions.
- [6] Business impact quantification: Use the loss range above as primary financial anchor; include likely 4-72h emergency-response window, partner escalation, and potential governance/bridge operations freeze externalities.
- [7] Abuse narrative: Attacker/operator leverages flawed settlement or authorization invariants to force unfair outcomes, suppress challengers, or deadlock dispute progression under apparently valid calls.
- [8] Fix plan + cost: Patch plan: redesign vulnerable branch/invariant logic, add property tests for settlement/challenge lifecycle, and run adversarial regression suite. Estimated effort: 6-15 engineer-days + 2-4 QA days. Estimated remediation cost: ~$50k-$180k including retest.
- Direct exploitation status: direct but role-constrained (requires defender position in live challenge context).
- Mitigation status:
1. Contract-level: not mitigated (defender-controlled boolean can rewrite winner).
2. Operational: none reliable; must patch settlement logic to remove winner rewrite branch.
- Estimated attacker cost: medium-to-high (`~$10,000-$1,000,000+`) due role/stake positioning requirements; transaction cost itself is low.
- Estimated loss range: high (`~$1M-$100M`) from misallocated stake outcomes, dispute manipulation, and confidence-driven capital flight.
- Primary mitigation layer: Protocol logic patch
- Mitigation feasibility: Medium
- Residual risk if truly mitigated: Medium
- Repo-specific manual check: Review settlement branch semantics to prove winner cannot be rewritten post-decision; re-run challenge lifecycle tests.
- Mitigation acceptance criteria: `Implemented` (fix exists at reviewed commit), `Enforced` (no bypass path exists), and `Demonstrated` (tests/witnesses show the same exploit path is blocked).
- Business impact:
1. Winner rewrite can misallocate slashing/stake outcomes and reward dishonest behavior.
2. Honest challenger incentives weaken, reducing long-term security participation.
3. Perceived unfair dispute outcomes damage protocol credibility with users and integrators.
- Preconditions:
1. Defender controls call to `completeChallenge(bool)` in active challenge context.
2. Challenge winner is already `challenger` before settlement call.
3. No additional guard prevents defender-side winner rewrite branch.
- Detailed execution:
1. Defender allows challenge state to progress to challenger-winning branch.
2. Defender calls `completeChallenge(false)`.
3. Contract enters `winner == challenger` branch and flips `winner = defender`.
4. Callback to rollup settlement executes with defender as winner.
5. Economic outcome and bookkeeping reflect reversed result.
- Post-exploit objective:
1. Avoid losing challenge consequences.
2. Preserve/steal stake outcome by rewriting winner at settlement edge.
3. Discourage honest challenger participation over time.

### linea-contracts - F-LINEA-03 (`High`)
- Vulnerability type category: `Initialization/upgrade first-caller takeover`
- Repository activity flag (9-month rule): Inactive (latest commit: 2024-09-11; cutoff: 2025-05-17).
- [1] Program/Payout mapping: Policy class: `Access Control / Unsafe Initialization / Upgrade Integrity`; severity tier: `High`; target payout band: `$15k-$100k (program-cap dependent)`; recommended claim framing: exploitable security defect with deterministic proof artifact.
- [2] Affected scope (exact): Repo `linea-contracts`; component/function `CustomBridgedToken.initializeV2(...)`; audit reference `reports/cat2_rollups/linea-contracts/report.md`; reviewed commit hash: `TBD-pin-before-submission`; fixed commit hash: `not provided`; affected release/version range: `TBD-pin-before-submission`.
- [3] Production exploitability verdict: Conditional-direct in production during non-atomic token upgrade windows.
- [4] Deterministic repro evidence: Forge + Medusa + Echidna + Halmos counterexamples (`f_linea_03_custombridgedtoken_initv2_takeover_forge_test.txt`, `f_linea_03_medusa_failfast_30s.txt`, `f_linea_03_echidna_30s.txt`, `f_linea_03_halmos.txt`). Validation reference: `reports/cat2_rollups/PROVEN_SUMMARY.md`.
- [5] Mitigation gap proof: Current controls are brittle to process variance: a single non-atomic path (manual/emergency/non-canonical script) reopens first-caller capture. Mitigation is incomplete unless atomicity is enforced on every upgrade/deploy path plus contract-side caller guard.
- [6] Business impact quantification: Use the loss range above with expected 2-24h incident handling and potential multi-day reconciliation/recovery overhead if exploitation is sustained.
- [7] Abuse narrative: Attacker monitors deployment/governance activity, races first-call initialization, captures privileged control, then monetizes via fund routing, unauthorized mint/state writes, or liveness extortion.
- [8] Fix plan + cost: Patch plan: enforce atomic `upgradeAndCall`/deploy+init in all scripts + add contract-side initializer caller restriction. Estimated effort: 3-8 engineer-days + 1-2 QA days. Estimated remediation cost: ~$20k-$90k including retest.
- Direct exploitation status: conditional-direct in non-atomic upgrade windows.
- Mitigation status:
1. Contract-level: not mitigated (`initializeV2` first-caller sets bridge authority).
2. Operational: partial. Atomic init removes window; first deployment script is atomic, but upgrade flows can still be non-atomic.
- Estimated attacker cost: low-to-medium (`~$500-$25,000`) for upgrade-window capture and follow-on mint/distribution transactions.
- Estimated loss range: very high (`~$10M-$500M+`) if unauthorized minting leads to unbacked asset circulation and downstream liquidations.
- Primary mitigation layer: Deployment upgrade discipline + contract guard
- Mitigation feasibility: High
- Residual risk if truly mitigated: Medium (ops-only), Low (with explicit auth)
- Repo-specific manual check: Audit all token proxy upgrade scripts for `upgradeAndCall` guarantees; ensure no generic non-atomic proxy upgrade utility remains.
- Mitigation acceptance criteria: `Implemented` (fix exists at reviewed commit), `Enforced` (no bypass path exists), and `Demonstrated` (tests/witnesses show the same exploit path is blocked).
- Business impact:
1. Bridge-authority capture enables unauthorized minting and potential circulation of unbacked assets.
2. Asset integrity failure can drive direct financial losses for users, LPs, and downstream protocols.
3. Exchanges/integrators may suspend impacted assets, creating liquidity shocks and trust erosion.
- Preconditions:
1. Token proxy is upgraded to `CustomBridgedToken` without atomic `initializeV2`.
2. `initializeV2` can set bridge authority and is first-caller.
3. Mint path is `onlyBridge`.
- Detailed execution:
1. Attacker detects upgrade to `CustomBridgedToken` implementation.
2. Attacker front-runs `initializeV2(..., attackerBridge)`.
3. Bridge authority in storage is reassigned to attacker-controlled address.
4. Legitimate bridge loses mint rights and intended initializer cannot run.
5. Attacker bridge mints arbitrary balances to mule accounts.
6. Attacker distributes or liquidates minted assets across venues.
- Post-exploit objective:
1. Monetary extraction via unauthorized mint.
2. Collateral distortion in downstream DeFi integrations.
3. Forced emergency token/governance response.

### era-contracts - F-ERAC-01 (`High`)
- Vulnerability type category: `Initialization/upgrade first-caller takeover`
- Repository activity flag (9-month rule): Active (latest commit: 2026-02-10; cutoff: 2025-05-17).
- [1] Program/Payout mapping: Policy class: `Access Control / Unsafe Initialization / Upgrade Integrity`; severity tier: `High`; target payout band: `$15k-$100k (program-cap dependent)`; recommended claim framing: exploitable security defect with deterministic proof artifact.
- [2] Affected scope (exact): Repo `era-contracts`; component/function `ChainRegistrar.initialize(...)`; audit reference `reports/cat2_rollups/era-contracts/report.md`; reviewed commit hash: `TBD-pin-before-submission`; fixed commit hash: `not provided`; affected release/version range: `TBD-pin-before-submission`.
- [3] Production exploitability verdict: Conditional-direct when `ChainRegistrar` proxy can be observed uninitialized.
- [4] Deterministic repro evidence: Forge + Medusa + Echidna + Halmos counterexamples (`f_erac_01_chain_registrar_init_hijack_forge_test.txt`, `f_erac_01_medusa_failfast_30s.txt`, `f_erac_01_echidna_30s.txt`, `f_erac_01_halmos.txt`). Validation reference: `reports/cat2_rollups/PROVEN_SUMMARY.md`.
- [5] Mitigation gap proof: Current controls are brittle to process variance: a single non-atomic path (manual/emergency/non-canonical script) reopens first-caller capture. Mitigation is incomplete unless atomicity is enforced on every upgrade/deploy path plus contract-side caller guard.
- [6] Business impact quantification: Use the loss range above with expected 2-24h incident handling and potential multi-day reconciliation/recovery overhead if exploitation is sustained.
- [7] Abuse narrative: Attacker monitors deployment/governance activity, races first-call initialization, captures privileged control, then monetizes via fund routing, unauthorized mint/state writes, or liveness extortion.
- [8] Fix plan + cost: Patch plan: enforce atomic `upgradeAndCall`/deploy+init in all scripts + add contract-side initializer caller restriction. Estimated effort: 3-8 engineer-days + 1-2 QA days. Estimated remediation cost: ~$20k-$90k including retest.
- Direct exploitation status: conditional-direct when proxy is exposed uninitialized.
- Mitigation status:
1. Contract-level: not mitigated (`initialize(...)` first-caller ownership capture).
2. Operational: partial/incomplete. Atomic helper exists in ecosystem, but this path is not consistently enforced for `ChainRegistrar`.
- Estimated attacker cost: low-to-medium (`~$300-$20,000`) for initialization takeover and admin updates; upside scales with diverted proposer flows.
- Estimated loss range: medium-to-high (`~$250k-$25M`) from diverted top-up flows, onboarding disruption, and operator restitution.
- Primary mitigation layer: Deployment wiring + contract auth
- Mitigation feasibility: High
- Residual risk if truly mitigated: Medium
- Repo-specific manual check: Confirm `ChainRegistrar` is always initialized atomically in deployment helper wiring or caller-restricted in contract.
- Mitigation acceptance criteria: `Implemented` (fix exists at reviewed commit), `Enforced` (no bypass path exists), and `Demonstrated` (tests/witnesses show the same exploit path is blocked).
- Business impact:
1. Registration top-up funds can be diverted, causing direct treasury/operator loss.
2. Proposer onboarding disruption can reduce decentralization and throughput growth.
3. Ownership recovery and migration work create measurable operational and engineering cost.
- Preconditions:
1. `ChainRegistrar` proxy is live but uninitialized.
2. Initializer sets owner from first call.
3. Owner can change deployer/top-up destination.
- Detailed execution:
1. Attacker initializes registrar first and becomes owner.
2. Attacker points deployer endpoint to attacker-controlled receiver.
3. Victim operators submit non-ETH registration proposals with required top-ups.
4. Contract transfers top-up tokens to attacker-controlled deployer address.
5. Legitimate owner initialization path is permanently blocked.
- Post-exploit objective:
1. Steal proposer top-up funds.
2. Delay or sabotage third-party chain registration.
3. Maintain long-lived control until governance replacement.

### base-contracts - F-BASE-01 (`High`)
- Vulnerability type category: `Initialization/upgrade first-caller takeover`
- Repository activity flag (9-month rule): Active (latest commit: 2026-01-30; cutoff: 2025-05-17).
- [1] Program/Payout mapping: Policy class: `Access Control / Unsafe Initialization / Upgrade Integrity`; severity tier: `High`; target payout band: `$15k-$100k (program-cap dependent)`; recommended claim framing: exploitable security defect with deterministic proof artifact.
- [2] Affected scope (exact): Repo `base-contracts`; component/function `BalanceTracker.initialize(...)`; audit reference `reports/cat2_rollups/base-contracts/report.md`; reviewed commit hash: `TBD-pin-before-submission`; fixed commit hash: `not provided`; affected release/version range: `TBD-pin-before-submission`.
- [3] Production exploitability verdict: Conditional-direct during non-atomic `BalanceTracker` upgrade initialization windows.
- [4] Deterministic repro evidence: Forge + Medusa + Echidna + Halmos counterexamples (`f_base_01_initializer_hijack_forge_test.txt`, `f_base_01_medusa_failfast_30s.txt`, `f_base_01_echidna_30s.txt`, `f_base_01_halmos.txt`). Validation reference: `reports/cat2_rollups/PROVEN_SUMMARY.md`.
- [5] Mitigation gap proof: Current controls are brittle to process variance: a single non-atomic path (manual/emergency/non-canonical script) reopens first-caller capture. Mitigation is incomplete unless atomicity is enforced on every upgrade/deploy path plus contract-side caller guard.
- [6] Business impact quantification: Use the loss range above with expected 2-24h incident handling and potential multi-day reconciliation/recovery overhead if exploitation is sustained.
- [7] Abuse narrative: Attacker monitors deployment/governance activity, races first-call initialization, captures privileged control, then monetizes via fund routing, unauthorized mint/state writes, or liveness extortion.
- [8] Fix plan + cost: Patch plan: enforce atomic `upgradeAndCall`/deploy+init in all scripts + add contract-side initializer caller restriction. Estimated effort: 3-8 engineer-days + 1-2 QA days. Estimated remediation cost: ~$20k-$90k including retest.
- Direct exploitation status: conditional-direct in non-atomic upgrade window.
- Mitigation status:
1. Contract-level: not mitigated (`initialize(...)` first-caller controls routing).
2. Operational: partial. Atomic upgrade+init mitigates, but any split flow remains exploitable.
- Estimated attacker cost: low (`~$200-$10,000`) to capture init window and run fee-processing transactions.
- Estimated loss range: medium-to-high (`~$500k-$50M`) from sustained fee siphoning, accounting distortion, and reconciliation cost.
- Primary mitigation layer: Upgrade pipeline discipline
- Mitigation feasibility: High
- Residual risk if truly mitigated: Medium
- Repo-specific manual check: Validate all `BalanceTracker` upgrades are atomic; verify no emergency/manual path can leave proxy uninitialized.
- Mitigation acceptance criteria: `Implemented` (fix exists at reviewed commit), `Enforced` (no bypass path exists), and `Demonstrated` (tests/witnesses show the same exploit path is blocked).
- Business impact:
1. Fee-routing capture can siphon protocol/system revenue over time.
2. Corrupted fee accounting distorts settlements, partner payouts, and financial reporting.
3. Undetected leakage increases forensic, legal, and restitution burden.
- Preconditions:
1. Proxy upgrade and `BalanceTracker.initialize` are not atomic.
2. Initializer accepts caller-supplied system-address routing.
3. Public fee processing can be triggered after capture.
- Detailed execution:
1. Attacker detects proxy upgrade transaction to `BalanceTracker` implementation.
2. Before legitimate initializer, attacker calls `initialize([attacker], [high-share])`.
3. Initializer version is consumed and routing config is attacker-owned.
4. As fees accrue, attacker (or anyone) triggers `processFees()`.
5. Contract routes designated fee share to attacker address.
6. Legitimate operators cannot reinitialize and must perform emergency upgrade/repair.
- Post-exploit objective:
1. Ongoing treasury revenue diversion.
2. Low-noise incremental drain strategy.
3. Trigger governance overhead and accounting disruption.

### optimism - F-OPT-01 (`High`)
- Vulnerability type category: `Initialization/upgrade first-caller takeover`
- Repository activity flag (9-month rule): Active (latest commit: 2026-02-17; cutoff: 2025-05-17).
- [1] Program/Payout mapping: Policy class: `Access Control / Unsafe Initialization / Upgrade Integrity`; severity tier: `High`; target payout band: `$15k-$100k (program-cap dependent)`; recommended claim framing: exploitable security defect with deterministic proof artifact.
- [2] Affected scope (exact): Repo `optimism`; component/function `ProtocolVersions.initialize(...)`; audit reference `reports/cat2_rollups/optimism/report.md`; reviewed commit hash: `TBD-pin-before-submission`; fixed commit hash: `not provided`; affected release/version range: `TBD-pin-before-submission`.
- [3] Production exploitability verdict: Conditional-direct during non-atomic proxy upgrade to `ProtocolVersions`.
- [4] Deterministic repro evidence: Forge + Medusa + Echidna + Halmos counterexamples (`f_opt_01_protocol_versions_init_hijack_forge_test.txt`, `f_opt_01_medusa_failfast_30s.txt`, `f_opt_01_echidna_30s.txt`, `f_opt_01_halmos.txt`). Validation reference: `reports/cat2_rollups/PROVEN_SUMMARY.md`.
- [5] Mitigation gap proof: Current controls are brittle to process variance: a single non-atomic path (manual/emergency/non-canonical script) reopens first-caller capture. Mitigation is incomplete unless atomicity is enforced on every upgrade/deploy path plus contract-side caller guard.
- [6] Business impact quantification: Use the loss range above with expected 2-24h incident handling and potential multi-day reconciliation/recovery overhead if exploitation is sustained.
- [7] Abuse narrative: Attacker monitors deployment/governance activity, races first-call initialization, captures privileged control, then monetizes via fund routing, unauthorized mint/state writes, or liveness extortion.
- [8] Fix plan + cost: Patch plan: enforce atomic `upgradeAndCall`/deploy+init in all scripts + add contract-side initializer caller restriction. Estimated effort: 3-8 engineer-days + 1-2 QA days. Estimated remediation cost: ~$20k-$90k including retest.
- Direct exploitation status: conditional-direct in non-atomic upgrade flow.
- Mitigation status:
1. Contract-level: not mitigated (`initialize(...)` caller can set owner).
2. Operational: stronger than many repos in canonical deployment (`upgradeAndCall` used), but risk remains for non-canonical/non-atomic executions.
- Estimated attacker cost: low-to-medium (`~$300-$15,000`) dominated by mempool race and follow-on owner transactions.
- Estimated loss range: medium-to-high (`~$1M-$75M`) from client desynchronization, outage windows, and unsafe coordinated upgrades.
- Primary mitigation layer: Existing atomic pattern enforcement
- Mitigation feasibility: High
- Residual risk if truly mitigated: Low-Medium
- Repo-specific manual check: Canonical script already uses `upgradeAndCall`; verify all non-canonical and emergency paths follow same constraint.
- Mitigation acceptance criteria: `Implemented` (fix exists at reviewed commit), `Enforced` (no bypass path exists), and `Demonstrated` (tests/witnesses show the same exploit path is blocked).
- Business impact:
1. Manipulated version signals can split operators and degrade network coordination.
2. Version confusion can trigger liveness incidents or unsafe client rollout decisions.
3. Trust in governance-driven upgrade signaling weakens, increasing operational overhead.
- Preconditions:
1. `ProtocolVersions` proxy is upgraded without atomic initialize call.
2. Initializer sets owner from untrusted caller input.
3. Owner controls required/recommended version signals.
- Detailed execution:
1. Attacker monitors deployment/governance txs for proxy upgrade to `ProtocolVersions`.
2. Attacker calls `initialize(attackerOwner, ...)` before official initializer.
3. Attacker becomes owner and consumes initializer.
4. Attacker updates required/recommended versions to attacker-chosen values.
5. Node operators and tooling consuming version signals are pushed into incorrect coordination states.
- Post-exploit objective:
1. Governance signal hijack.
2. Operational confusion across infra operators.
3. Reputational and coordination damage.

### linea-contracts - F-LINEA-02 (`High`)
- Vulnerability type category: `Initialization/upgrade first-caller takeover`
- Repository activity flag (9-month rule): Inactive (latest commit: 2024-09-11; cutoff: 2025-05-17).
- [1] Program/Payout mapping: Policy class: `Access Control / Unsafe Initialization / Upgrade Integrity`; severity tier: `High`; target payout band: `$15k-$100k (program-cap dependent)`; recommended claim framing: exploitable security defect with deterministic proof artifact.
- [2] Affected scope (exact): Repo `linea-contracts`; component/function `LineaRollupInit.initializeV2(...)`; audit reference `reports/cat2_rollups/linea-contracts/report.md`; reviewed commit hash: `TBD-pin-before-submission`; fixed commit hash: `not provided`; affected release/version range: `TBD-pin-before-submission`.
- [3] Production exploitability verdict: Conditional-direct in plain `upgrade` paths without same-tx reinitializer call.
- [4] Deterministic repro evidence: Forge + Medusa + Echidna + Halmos counterexamples (`f_linea_02_rollupinit_initv2_upgrade_gap_forge_test.txt`, `f_linea_02_medusa_failfast_30s.txt`, `f_linea_02_echidna_30s.txt`, `f_linea_02_halmos.txt`). Validation reference: `reports/cat2_rollups/PROVEN_SUMMARY.md`.
- [5] Mitigation gap proof: Current controls are brittle to process variance: a single non-atomic path (manual/emergency/non-canonical script) reopens first-caller capture. Mitigation is incomplete unless atomicity is enforced on every upgrade/deploy path plus contract-side caller guard.
- [6] Business impact quantification: Use the loss range above with expected 2-24h incident handling and potential multi-day reconciliation/recovery overhead if exploitation is sustained.
- [7] Abuse narrative: Attacker monitors deployment/governance activity, races first-call initialization, captures privileged control, then monetizes via fund routing, unauthorized mint/state writes, or liveness extortion.
- [8] Fix plan + cost: Patch plan: enforce atomic `upgradeAndCall`/deploy+init in all scripts + add contract-side initializer caller restriction. Estimated effort: 3-8 engineer-days + 1-2 QA days. Estimated remediation cost: ~$20k-$90k including retest.
- Direct exploitation status: conditional-direct in plain `upgrade` without same-tx reinit.
- Mitigation status:
1. Contract-level: not mitigated (`initializeV2` first-caller migration anchor control).
2. Operational: partial. Safe script path with atomic reinit exists, but non-atomic path is also available and exploitable.
- Estimated attacker cost: low-to-medium (`~$300-$20,000`) for upgrade-window race plus migration-state capture tx.
- Estimated loss range: high (`~$2M-$150M`) if migration poisoning stalls releases and forces high-risk emergency recovery.
- Primary mitigation layer: Script policy + contract auth
- Mitigation feasibility: High
- Residual risk if truly mitigated: Medium
- Repo-specific manual check: Verify unsafe `no_reinitialisation` path is removed/blocked in production policy; prove all upgrades call reinitializer atomically.
- Mitigation acceptance criteria: `Implemented` (fix exists at reviewed commit), `Enforced` (no bypass path exists), and `Demonstrated` (tests/witnesses show the same exploit path is blocked).
- Business impact:
1. Migration-anchor poisoning can break continuity guarantees during sensitive upgrade windows.
2. Failed migration can delay releases and user-facing roadmap commitments.
3. Repeated recovery operations increase risk exposure and partner confidence loss.
- Preconditions:
1. Upgrade to `LineaRollupInit` occurs via plain `upgrade` without same-tx reinit.
2. `initializeV2` is externally callable first-caller path.
3. Migration anchor values are security-sensitive.
- Detailed execution:
1. Attacker tracks upgrade transaction to `LineaRollupInit`.
2. Immediately submits `initializeV2(attackerBlock, attackerRoot)` with priority fee.
3. Contract records attacker-chosen migration state and consumes `reinitializer(3)`.
4. Legitimate migration initializer call fails.
5. Governance must execute additional privileged recovery path.
- Post-exploit objective:
1. Compromise migration trust assumptions.
2. Delay migration rollout and force emergency operations.
3. Create audit trail ambiguity around canonical migration anchor.

### mantle - F-MAN-04 (`High`)
- Vulnerability type category: `Privilege and settlement-logic integrity flaws`
- Repository activity flag (9-month rule): Inactive (latest commit: 2023-08-16; cutoff: 2025-05-17).
- [1] Program/Payout mapping: Policy class: `Protocol Integrity / Privilege Logic / Settlement Correctness`; severity tier: `High`; target payout band: `$15k-$100k (program-cap dependent)`; recommended claim framing: exploitable security defect with deterministic proof artifact.
- [2] Affected scope (exact): Repo `mantle`; component/function `Rollup.challengeAssertion(...)`; audit reference `reports/cat2_rollups/mantle/report.md`; reviewed commit hash: `TBD-pin-before-submission`; fixed commit hash: `not provided`; affected release/version range: `TBD-pin-before-submission`.
- [3] Production exploitability verdict: Direct for griefing by valid operator/staker class; slash impact depends on settlement reachability.
- [4] Deterministic repro evidence: Forge + Medusa + Echidna + Halmos counterexamples (`f_man_04_challenge_binding_forge_test.txt`, `f_man_04_medusa_failfast_30s.txt`, `f_man_04_echidna_30s.txt`, `f_man_04_halmos.txt`). Validation reference: `reports/cat2_rollups/PROVEN_SUMMARY.md`.
- [5] Mitigation gap proof: Runbook-only controls do not close logic defects. Without invariant-enforced code changes, authorized actors can still trigger unfair settlement or liveness break conditions.
- [6] Business impact quantification: Use the loss range above with expected 2-24h incident handling and potential multi-day reconciliation/recovery overhead if exploitation is sustained.
- [7] Abuse narrative: Attacker/operator leverages flawed settlement or authorization invariants to force unfair outcomes, suppress challengers, or deadlock dispute progression under apparently valid calls.
- [8] Fix plan + cost: Patch plan: redesign vulnerable branch/invariant logic, add property tests for settlement/challenge lifecycle, and run adversarial regression suite. Estimated effort: 6-15 engineer-days + 2-4 QA days. Estimated remediation cost: ~$50k-$180k including retest.
- Direct exploitation status: direct for griefing by valid operator/staker; direct slash impact depends on settlement path enablement.
- Mitigation status:
1. Contract-level: not mitigated (no player-to-assertion binding checks).
2. Operational: weak. Extra operator-registration gates can change severity but do not fix core binding flaw.
- Estimated attacker cost: medium-to-high (`~$5,000-$500,000+`) due required operator/staker position and potential stake exposure.
- Estimated loss range: high (`~$1M-$80M`) from targeted operator damage, unjust slashing, and dispute-system abuse.
- Primary mitigation layer: Protocol logic redesign
- Mitigation feasibility: Medium
- Residual risk if truly mitigated: Medium
- Repo-specific manual check: Add and verify staker/assertion binding invariants; confirm settlement cannot slash unrelated staker paths.
- Mitigation acceptance criteria: `Implemented` (fix exists at reviewed commit), `Enforced` (no bypass path exists), and `Demonstrated` (tests/witnesses show the same exploit path is blocked).
- Business impact:
1. Missing binding checks enable targeted operator griefing and possible unjust slashing.
2. Perceived stake unfairness discourages honest operator participation.
3. Abuse of dispute mechanics increases operational and legal risk around penalties.
- Preconditions:
1. Attacker can call `challengeAssertion` as valid operator/staker.
2. Contract does not verify player stakers are bound to supplied assertion IDs.
3. Settlement path can be made reachable with challenge-operator registration workaround.
- Detailed execution:
1. Attacker selects victim operator and unrelated sibling assertion IDs.
2. Calls `challengeAssertion(victim, attacker, assertionIDs)` with mismatched bindings.
3. Contract accepts challenge and sets victim `currentChallenge`.
4. Victim is forced into dispute state and liveness is impacted.
5. If settlement path is enabled, attacker drives settlement to slash/delete victim staker despite mismatch.
- Post-exploit objective:
1. Targeted griefing against specific operators.
2. Potential economic harm via unrelated slashing.
3. Competitive suppression of honest challengers.

### mantle - F-MAN-02 (`High`)
- Vulnerability type category: `Privilege and settlement-logic integrity flaws`
- Repository activity flag (9-month rule): Inactive (latest commit: 2023-08-16; cutoff: 2025-05-17).
- [1] Program/Payout mapping: Policy class: `Protocol Integrity / Privilege Logic / Settlement Correctness`; severity tier: `High`; target payout band: `$15k-$100k (program-cap dependent)`; recommended claim framing: exploitable security defect with deterministic proof artifact.
- [2] Affected scope (exact): Repo `mantle`; component/function `Rollup.createAssertion(...)`; audit reference `reports/cat2_rollups/mantle/report.md`; reviewed commit hash: `TBD-pin-before-submission`; fixed commit hash: `not provided`; affected release/version range: `TBD-pin-before-submission`.
- [3] Production exploitability verdict: Direct for authorized operator class due create+confirm path coupling.
- [4] Deterministic repro evidence: Forge + Medusa + Echidna + Halmos counterexamples (`f_man_02_assertion_autoconfirm_forge_test.txt`, `f_man_02_medusa_failfast_30s.txt`, `f_man_02_echidna_30s.txt`, `f_man_02_halmos.txt`). Validation reference: `reports/cat2_rollups/PROVEN_SUMMARY.md`.
- [5] Mitigation gap proof: Runbook-only controls do not close logic defects. Without invariant-enforced code changes, authorized actors can still trigger unfair settlement or liveness break conditions.
- [6] Business impact quantification: Use the loss range above with expected 2-24h incident handling and potential multi-day reconciliation/recovery overhead if exploitation is sustained.
- [7] Abuse narrative: Attacker/operator leverages flawed settlement or authorization invariants to force unfair outcomes, suppress challengers, or deadlock dispute progression under apparently valid calls.
- [8] Fix plan + cost: Patch plan: redesign vulnerable branch/invariant logic, add property tests for settlement/challenge lifecycle, and run adversarial regression suite. Estimated effort: 6-15 engineer-days + 2-4 QA days. Estimated remediation cost: ~$50k-$180k including retest.
- Direct exploitation status: direct by authorized operator class (not necessarily permissionless public attacker).
- Mitigation status:
1. Contract-level: not mitigated (no enforced separation between creation and confirmation).
2. Operational: limited; monitoring does not restore missing dispute-stage separation.
- Estimated attacker cost: medium-to-high (`~$5,000-$500,000+`) driven by operator access and stake participation, not raw gas cost.
- Estimated loss range: very high (`~$5M-$250M`) if invalid assertions finalize before challenge response can execute.
- Primary mitigation layer: Protocol finality model redesign
- Mitigation feasibility: Low-Medium
- Residual risk if truly mitigated: Medium
- Repo-specific manual check: Confirm assertion creation and confirmation are separated with enforceable dispute window semantics.
- Mitigation acceptance criteria: `Implemented` (fix exists at reviewed commit), `Enforced` (no bypass path exists), and `Demonstrated` (tests/witnesses show the same exploit path is blocked).
- Business impact:
1. Same-transaction create+confirm collapses practical dispute windows.
2. Unsafe assertions may finalize before independent review, risking invalid state acceptance.
3. Security posture drifts toward trusted-operator assumptions, weakening decentralization claims.
- Preconditions:
1. Attacker or colluding operator can create assertions.
2. `createAssertion` immediately confirms new assertions.
3. Monitoring/challenge operations are not instantaneous.
- Detailed execution:
1. Operator submits assertion with contentious/unsafe state transition.
2. Within same transaction, assertion is marked resolved/confirmed.
3. Downstream logic sees confirmation without distinct dispute window transition.
4. Challengers have reduced practical response window.
- Post-exploit objective:
1. Fast-track assertion finality under operator control.
2. Reduce effective dispute guarantees.
3. Push protocol behavior toward trusted-operator model.

### mantle - F-MAN-03 (`High`)
- Vulnerability type category: `Privilege and settlement-logic integrity flaws`
- Repository activity flag (9-month rule): Inactive (latest commit: 2023-08-16; cutoff: 2025-05-17).
- [1] Program/Payout mapping: Policy class: `Protocol Integrity / Privilege Logic / Settlement Correctness`; severity tier: `High`; target payout band: `$15k-$100k (program-cap dependent)`; recommended claim framing: exploitable security defect with deterministic proof artifact.
- [2] Affected scope (exact): Repo `mantle`; component/function `Rollup.completeChallenge(...)`; audit reference `reports/cat2_rollups/mantle/report.md`; reviewed commit hash: `TBD-pin-before-submission`; fixed commit hash: `not provided`; affected release/version range: `TBD-pin-before-submission`.
- [3] Production exploitability verdict: Direct liveness-failure trigger when hidden challenge-operator registration dependency is unmet.
- [4] Deterministic repro evidence: Medusa + Echidna + Halmos counterexamples (`f_man_03_medusa_failfast_30s.txt`, `f_man_03_echidna_30s.txt`, `f_man_03_halmos.txt`). Validation reference: `reports/cat2_rollups/PROVEN_SUMMARY.md`.
- [5] Mitigation gap proof: Runbook-only controls do not close logic defects. Without invariant-enforced code changes, authorized actors can still trigger unfair settlement or liveness break conditions.
- [6] Business impact quantification: Use the loss range above with expected 2-24h incident handling and potential multi-day reconciliation/recovery overhead if exploitation is sustained.
- [7] Abuse narrative: Attacker/operator leverages flawed settlement or authorization invariants to force unfair outcomes, suppress challengers, or deadlock dispute progression under apparently valid calls.
- [8] Fix plan + cost: Patch plan: redesign vulnerable branch/invariant logic, add property tests for settlement/challenge lifecycle, and run adversarial regression suite. Estimated effort: 6-15 engineer-days + 2-4 QA days. Estimated remediation cost: ~$50k-$180k including retest.
- Direct exploitation status: direct liveness failure, but configuration-sensitive (manifests when hidden registration dependency is unmet).
- Mitigation status:
1. Contract-level: partially mitigated only by manual challenge-operator registration; hidden dependency remains.
2. Operational: runbook registration can restore liveness, but failure mode persists and can recur.
- Estimated attacker cost: medium (`~$2,000-$100,000+`) depending on ability to force/engage challenge lifecycle states.
- Estimated loss range: medium-to-high (`~$1M-$60M`) from deadlocked disputes, delayed progression, and confidence/revenue impact.
- Primary mitigation layer: Auth model simplification
- Mitigation feasibility: Medium
- Residual risk if truly mitigated: Low-Medium
- Repo-specific manual check: Remove hidden challenge-operator dependency or enforce deterministic registration; verify no deadlock path remains.
- Mitigation acceptance criteria: `Implemented` (fix exists at reviewed commit), `Enforced` (no bypass path exists), and `Demonstrated` (tests/witnesses show the same exploit path is blocked).
- Business impact:
1. Hidden registration dependency can deadlock challenge settlement and stall progression.
2. Stalled disputes lock capital paths and prolong incident windows.
3. Manual runbook dependence raises recurrence probability and human-error risk.
- Preconditions:
1. Challenge contract address is not registered as operator.
2. Settlement callback requires both `operatorOnly` and `msg.sender == challenge`.
3. Active disputes depend on this settlement path.
- Detailed execution:
1. Challenge reaches completion callback phase.
2. Challenge contract calls `Rollup.completeChallenge`.
3. Call reverts with `NotOperator` due missing hidden registration.
4. Dispute state remains unresolved and funds progression stalls.
5. Manual/governance action is required to register challenge contract and retry.
- Post-exploit objective:
1. Repeated liveness disruption without direct privilege theft.
2. Operational burden and incident fatigue.
3. Strategic timing to freeze disputes during critical windows.

### era-boojum - F-ERA-01 (`High`)
- Vulnerability type category: `Prover reliability and crashable execution paths`
- Repository activity flag (9-month rule): Inactive (latest commit: 2024-08-15; cutoff: 2025-05-17).
- [1] Program/Payout mapping: Policy class: `Denial of Service / Reliability / Input Validation`; severity tier: `High`; target payout band: `$15k-$100k (program-cap dependent)`; recommended claim framing: exploitable security defect with deterministic proof artifact.
- [2] Affected scope (exact): Repo `era-boojum`; component/function `resolver_box allocator reservation/commit logic`; audit reference `reports/cat2_rollups/era-boojum/report.md`; reviewed commit hash: `TBD-pin-before-submission`; fixed commit hash: `not provided`; affected release/version range: `TBD-pin-before-submission`.
- [3] Production exploitability verdict: Direct if oversized reservation inputs are attacker-reachable; otherwise latent but high-impact.
- [4] Deterministic repro evidence: Deterministic Rust harness witness (`f_era_01_resolver_page_overflow_cargo_test.txt`). Validation reference: `reports/cat2_rollups/PROVEN_SUMMARY.md`.
- [5] Mitigation gap proof: Ingress filtering is compensating-only. Panic/bounds defects remain exploitable whenever malformed workloads bypass or precede validation checks.
- [6] Business impact quantification: Use the loss range above with expected 2-24h incident handling and potential multi-day reconciliation/recovery overhead if exploitation is sustained.
- [7] Abuse narrative: Attacker repeatedly submits malformed workloads that trigger panic/corruption paths, sustaining prover instability and delaying finality until mitigations are enforced.
- [8] Fix plan + cost: Patch plan: replace panic/unsafe assumptions with recoverable errors and strict bounds prevalidation, then fuzz malformed inputs. Estimated effort: 3-7 engineer-days + 1-3 QA days. Estimated remediation cost: ~$20k-$80k including retest.
- Direct exploitation status: direct if oversized reservation input is attacker-reachable; otherwise latent high-risk bug.
- Mitigation status:
1. Contract/code-level: not mitigated (missing bounds check after page rollover).
2. Operational: upstream input limits can reduce exposure but do not remove allocator invariant flaw.
- Estimated attacker cost: low-to-medium (`~$500-$50,000`) depending on whether oversized input injection is publicly reachable or gated.
- Estimated loss range: medium (`~$500k-$30M`) from prover downtime, SLA penalties, and delayed finality-driven user losses.
- Primary mitigation layer: Localized allocator bounds fix
- Mitigation feasibility: High
- Residual risk if truly mitigated: Low
- Repo-specific manual check: Add post-rollover `size <= page_size` guard; run regression/fuzz on allocator paths.
- Mitigation acceptance criteria: `Implemented` (fix exists at reviewed commit), `Enforced` (no bypass path exists), and `Demonstrated` (tests/witnesses show the same exploit path is blocked).
- Business impact:
1. Allocator corruption/crash paths can halt prover throughput and delay proof delivery.
2. Repeated worker failures increase infrastructure spend and SLA pressure.
3. Prolonged instability cascades to slower finality/withdrawal timelines for users.
- Preconditions:
1. Attacker-controlled or malformed workload can influence reservation sizes.
2. Allocator path is reachable under production proving workload.
3. Page size is bounded while reservation request can exceed it.
- Detailed execution:
1. Attacker feeds oversized reservation request (`size > page_size`).
2. Allocator rolls to new page but does not enforce size bound.
3. Commit counter advances beyond allocation length.
4. Subsequent writes rely on invalid bounds state.
5. Process hits crash/corruption behavior depending on path and protections.
- Post-exploit objective:
1. Crash proving service.
2. Induce invalid/unsafe memory behavior.
3. Degrade throughput and reliability under sustained malformed load.

### zkevm-circuits - F-ZKEVM-01 (`High`)
- Vulnerability type category: `Prover reliability and crashable execution paths`
- Repository activity flag (9-month rule): Inactive (latest commit: 2025-04-18; cutoff: 2025-05-17).
- [1] Program/Payout mapping: Policy class: `Denial of Service / Reliability / Input Validation`; severity tier: `High`; target payout band: `$15k-$100k (program-cap dependent)`; recommended claim framing: exploitable security defect with deterministic proof artifact.
- [2] Affected scope (exact): Repo `zkevm-circuits`; component/function `aggregator::decode_bytes`; audit reference `reports/cat2_rollups/zkevm-circuits/report.md`; reviewed commit hash: `TBD-pin-before-submission`; fixed commit hash: `not provided`; affected release/version range: `TBD-pin-before-submission`.
- [3] Production exploitability verdict: Direct crash path if malformed payloads can reach proving queue ingress.
- [4] Deterministic repro evidence: Deterministic Rust harness witness (`f_zkevm_01_decode_bytes_panic_cargo_test.txt`). Validation reference: `reports/cat2_rollups/PROVEN_SUMMARY.md`.
- [5] Mitigation gap proof: Ingress filtering is compensating-only. Panic/bounds defects remain exploitable whenever malformed workloads bypass or precede validation checks.
- [6] Business impact quantification: Use the loss range above with expected 2-24h incident handling and potential multi-day reconciliation/recovery overhead if exploitation is sustained.
- [7] Abuse narrative: Attacker repeatedly submits malformed workloads that trigger panic/corruption paths, sustaining prover instability and delaying finality until mitigations are enforced.
- [8] Fix plan + cost: Patch plan: replace panic/unsafe assumptions with recoverable errors and strict bounds prevalidation, then fuzz malformed inputs. Estimated effort: 3-7 engineer-days + 1-3 QA days. Estimated remediation cost: ~$20k-$80k including retest.
- Direct exploitation status: direct crash path if malformed payloads can reach proving queue.
- Mitigation status:
1. Code-level: not mitigated (`panic` behavior instead of recoverable error handling).
2. Operational: queue auth/validation can reduce reachability but does not fix panic path in core decoder.
- Estimated attacker cost: low-to-medium (`~$500-$30,000`) if queue ingress is reachable; higher if auth bypass is needed.
- Estimated loss range: medium-to-high (`~$500k-$40M`) under repeated crash cycles and sustained proving throughput degradation.
- Primary mitigation layer: Decoder error-handling patch
- Mitigation feasibility: High
- Residual risk if truly mitigated: Low-Medium
- Repo-specific manual check: Replace panic primitives with recoverable errors and validate queue ingress controls.
- Mitigation acceptance criteria: `Implemented` (fix exists at reviewed commit), `Enforced` (no bypass path exists), and `Demonstrated` (tests/witnesses show the same exploit path is blocked).
- Business impact:
1. Panic-based decoder crashes can produce repeatable proving outages.
2. Restart churn and throughput degradation raise infra cost and delivery risk.
3. Persistent instability undermines partner confidence in proving reliability.
- Preconditions:
1. Malformed `blob_bytes` can enter proving queue from upstream interface.
2. Decoder panic is not isolated by recoverable error boundary.
3. Worker restart policy allows repeated crash cycling.
- Detailed execution:
1. Attacker submits malformed payloads (empty or underflow-triggering encoding).
2. `decode_bytes` executes panic-prone operations.
3. Panic bypasses expected `Result`-based error handling path.
4. Worker/process terminates task abruptly.
5. Attacker repeats malformed inputs to maintain instability.
- Post-exploit objective:
1. Availability attack on proving pipeline.
2. Delay finality-dependent operations.
3. Raise operational cost via continuous incident response.

### zkevm-circuits - F-ZKEVM-02 (`Medium`)
- Vulnerability type category: `Prover reliability and crashable execution paths`
- Repository activity flag (9-month rule): Inactive (latest commit: 2025-04-18; cutoff: 2025-05-17).
- [1] Program/Payout mapping: Policy class: `Denial of Service / Reliability / Input Validation`; severity tier: `Medium`; target payout band: `$5k-$30k (program-cap dependent)`; recommended claim framing: exploitable security defect with deterministic proof artifact.
- [2] Affected scope (exact): Repo `zkevm-circuits`; component/function `BatchProvingTask/BundleProvingTask identifier()`; audit reference `reports/cat2_rollups/zkevm-circuits/report.md`; reviewed commit hash: `TBD-pin-before-submission`; fixed commit hash: `not provided`; affected release/version range: `TBD-pin-before-submission`.
- [3] Production exploitability verdict: Direct crash path if malformed empty tasks can reach identifier path.
- [4] Deterministic repro evidence: Deterministic Rust harness witness (`f_zkevm_02_empty_task_identifier_panic_cargo_test.txt`). Validation reference: `reports/cat2_rollups/PROVEN_SUMMARY.md`.
- [5] Mitigation gap proof: Ingress filtering is compensating-only. Panic/bounds defects remain exploitable whenever malformed workloads bypass or precede validation checks.
- [6] Business impact quantification: Use the loss range above with expected lower direct protocol-loss but measurable support, reconciliation, and partner-dispute costs.
- [7] Abuse narrative: Attacker repeatedly submits malformed workloads that trigger panic/corruption paths, sustaining prover instability and delaying finality until mitigations are enforced.
- [8] Fix plan + cost: Patch plan: replace panic/unsafe assumptions with recoverable errors and strict bounds prevalidation, then fuzz malformed inputs. Estimated effort: 3-7 engineer-days + 1-3 QA days. Estimated remediation cost: ~$20k-$80k including retest.
- Direct exploitation status: direct crash path if empty malformed tasks can be submitted.
- Mitigation status:
1. Code-level: not mitigated (`.last().unwrap()` on empty vectors).
2. Operational: input validation at task ingress is compensating control only.
- Estimated attacker cost: low-to-medium (`~$300-$20,000`) for malformed task spam where ingress access exists.
- Estimated loss range: medium (`~$250k-$20M`) from low-cost queue abuse causing recurring DoS and operational load.
- Primary mitigation layer: Prevalidation + safe identifier handling
- Mitigation feasibility: High
- Residual risk if truly mitigated: Low
- Repo-specific manual check: Remove `.unwrap()` assumptions for empty vectors; test malformed task handling end-to-end.
- Mitigation acceptance criteria: `Implemented` (fix exists at reviewed commit), `Enforced` (no bypass path exists), and `Demonstrated` (tests/witnesses show the same exploit path is blocked).
- Business impact:
1. Low-cost malformed tasks can trigger denial-of-service behavior in workers.
2. Backlog growth delays batch processing and downstream finality expectations.
3. Operations incur sustained triage/restart burden under repeated abuse.
- Preconditions:
1. Queue accepts malformed empty proving tasks.
2. Identifier path runs before validation in relevant execution flow.
3. Panic handling does not fully isolate worker impact.
- Detailed execution:
1. Attacker submits task with empty `chunk_proofs` or `batch_proofs`.
2. Identifier generation invokes `.last().unwrap()`.
3. Runtime panics before clean validation error is emitted.
4. Worker fails and retry/restart path is triggered.
5. Repeated malformed tasks amplify instability.
- Post-exploit objective:
1. Low-cost denial of service by panic spam.
2. Throughput degradation rather than direct theft.
3. Incident-noise generation that masks other activity.

### taiko-contracts - F-TAIKO-02 (`Medium`)
- Vulnerability type category: `Initialization/upgrade first-caller takeover`
- Repository activity flag (9-month rule): Active (latest commit: 2026-02-16; cutoff: 2025-05-17).
- [1] Program/Payout mapping: Policy class: `Access Control / Unsafe Initialization / Upgrade Integrity`; severity tier: `Medium`; target payout band: `$5k-$30k (program-cap dependent)`; recommended claim framing: exploitable security defect with deterministic proof artifact.
- [2] Affected scope (exact): Repo `taiko-contracts`; component/function `EventRegister.initialize()`; audit reference `reports/cat2_rollups/taiko-contracts/report.md`; reviewed commit hash: `TBD-pin-before-submission`; fixed commit hash: `not provided`; affected release/version range: `TBD-pin-before-submission`.
- [3] Production exploitability verdict: Conditional-direct in deploy/init race windows on exposed deployment flows.
- [4] Deterministic repro evidence: Forge witness (`f_taiko_02_eventregister_init_hijack_forge_test.txt`). Validation reference: `reports/cat2_rollups/PROVEN_SUMMARY.md`.
- [5] Mitigation gap proof: Current controls are brittle to process variance: a single non-atomic path (manual/emergency/non-canonical script) reopens first-caller capture. Mitigation is incomplete unless atomicity is enforced on every upgrade/deploy path plus contract-side caller guard.
- [6] Business impact quantification: Use the loss range above with expected lower direct protocol-loss but measurable support, reconciliation, and partner-dispute costs.
- [7] Abuse narrative: Attacker monitors deployment/governance activity, races first-call initialization, captures privileged control, then monetizes via fund routing, unauthorized mint/state writes, or liveness extortion.
- [8] Fix plan + cost: Patch plan: enforce atomic `upgradeAndCall`/deploy+init in all scripts + add contract-side initializer caller restriction. Estimated effort: 3-8 engineer-days + 1-2 QA days. Estimated remediation cost: ~$20k-$90k including retest.
- Direct exploitation status: conditional-direct in deploy/init race windows.
- Mitigation status:
1. Contract-level: not mitigated (`initialize()` first-caller assigns privileged roles).
2. Operational: partial. Atomic deploy+init can close the window; split scripts remain exploitable.
- Estimated attacker cost: low (`~$100-$5,000`) with deployment watcher infrastructure plus one priority initialization tx.
- Estimated loss range: low-to-medium (`~$100k-$15M`) from forged event-driven payouts, campaign abuse, and remediation overhead.
- Primary mitigation layer: Deployment script hardening
- Mitigation feasibility: High
- Residual risk if truly mitigated: Medium
- Repo-specific manual check: Ensure deploy and init are atomic in all deployment scripts; verify no split-init scripts remain in use.
- Mitigation acceptance criteria: `Implemented` (fix exists at reviewed commit), `Enforced` (no bypass path exists), and `Demonstrated` (tests/witnesses show the same exploit path is blocked).
- Business impact:
1. Event registry takeover enables attacker-authored records consumed by business workflows.
2. Forged event data can drive unauthorized rewards, allowlisting, or campaign abuse.
3. Cleanup/reconciliation and user disputes create support cost and brand damage.
- Preconditions:
1. `EventRegister` deployment and initialize occur in separate calls.
2. `initialize()` grants owner + event manager to caller.
3. Attacker can monitor deployment tx stream.
- Detailed execution:
1. Attacker monitors chain for `EventRegister` contract creation.
2. Immediately calls `initialize()` before intended deployer call.
3. Captures owner and manager roles.
4. Writes attacker-defined events via `createEvent(...)`.
5. Intended initializer call reverts; attacker-inserted events remain onchain.
- Post-exploit objective:
1. Poison event-driven eligibility/reward logic.
2. Force governance/admin cleanup workflows.
3. Preserve malicious historical records even after role revocation.

### taiko-mono - F-TAIKOMONO-02 (`Medium`)
- Vulnerability type category: `Initialization/upgrade first-caller takeover`
- Repository activity flag (9-month rule): Active (latest commit: 2026-02-16; cutoff: 2025-05-17).
- [1] Program/Payout mapping: Policy class: `Access Control / Unsafe Initialization / Upgrade Integrity`; severity tier: `Medium`; target payout band: `$5k-$30k (program-cap dependent)`; recommended claim framing: exploitable security defect with deterministic proof artifact.
- [2] Affected scope (exact): Repo `taiko-mono`; component/function `EventRegister.initialize()`; audit reference `reports/cat2_rollups/taiko-mono/report.md`; reviewed commit hash: `TBD-pin-before-submission`; fixed commit hash: `not provided`; affected release/version range: `TBD-pin-before-submission`.
- [3] Production exploitability verdict: Conditional-direct in mono deploy/init race windows where split flow exists.
- [4] Deterministic repro evidence: Forge witness (`f_taikomono_02_eventregister_init_hijack_forge_test.txt`). Validation reference: `reports/cat2_rollups/PROVEN_SUMMARY.md`.
- [5] Mitigation gap proof: Current controls are brittle to process variance: a single non-atomic path (manual/emergency/non-canonical script) reopens first-caller capture. Mitigation is incomplete unless atomicity is enforced on every upgrade/deploy path plus contract-side caller guard.
- [6] Business impact quantification: Use the loss range above with expected lower direct protocol-loss but measurable support, reconciliation, and partner-dispute costs.
- [7] Abuse narrative: Attacker monitors deployment/governance activity, races first-call initialization, captures privileged control, then monetizes via fund routing, unauthorized mint/state writes, or liveness extortion.
- [8] Fix plan + cost: Patch plan: enforce atomic `upgradeAndCall`/deploy+init in all scripts + add contract-side initializer caller restriction. Estimated effort: 3-8 engineer-days + 1-2 QA days. Estimated remediation cost: ~$20k-$90k including retest.
- Direct exploitation status: conditional-direct in deploy/init race windows.
- Mitigation status:
1. Contract-level: not mitigated (same first-caller init role assignment pattern).
2. Operational: partial. Atomic init mitigates only where consistently enforced.
- Estimated attacker cost: low (`~$100-$5,000`) under the same race-window assumptions as `taiko-contracts` (`F-TAIKO-02`).
- Estimated loss range: low-to-medium (`~$100k-$15M`) with similar cross-environment event-data poisoning impact.
- Primary mitigation layer: Deployment script hardening
- Mitigation feasibility: High
- Residual risk if truly mitigated: Medium
- Repo-specific manual check: Same manual verification as `taiko-contracts` (`F-TAIKO-02`) across mono release/deploy pipelines.
- Mitigation acceptance criteria: `Implemented` (fix exists at reviewed commit), `Enforced` (no bypass path exists), and `Demonstrated` (tests/witnesses show the same exploit path is blocked).
- Business impact:
1. Mono deployment surface inherits registry takeover risk and cross-environment data poisoning.
2. Offchain consumers may issue benefits based on attacker-crafted event records.
3. Recurring contamination erodes trust in event-driven products and partner integrations.
- Preconditions:
1. Same split deploy/init pattern exists in mono deployment surface.
2. Attacker can automate immediate post-deploy tx submission.
3. Offchain systems consume onchain event registry as source of truth.
- Detailed execution:
1. Watch for new `EventRegister` deployments.
2. Front-run `initialize()` as first caller.
3. Acquire owner/event-manager privileges.
4. Insert crafted event records benefiting attacker identities.
5. Let legitimate initializer fail and force delayed recovery.
- Post-exploit objective:
1. Reward/eligibility manipulation.
2. Persistent data contamination.
3. Repeated exploitation across fresh environments.

### taiko-contracts - F-TAIKO-01 (`Medium`)
- Vulnerability type category: `Integration-facing data validity flaws`
- Repository activity flag (9-month rule): Active (latest commit: 2026-02-16; cutoff: 2025-05-17).
- [1] Program/Payout mapping: Policy class: `Business Logic / Data Validation / Offchain Trust Boundary`; severity tier: `Medium`; target payout band: `$5k-$30k (program-cap dependent)`; recommended claim framing: exploitable security defect with deterministic proof artifact.
- [2] Affected scope (exact): Repo `taiko-contracts`; component/function `TrailblazersBadgesS2.getBadge(uint256)`; audit reference `reports/cat2_rollups/taiko-contracts/report.md`; reviewed commit hash: `TBD-pin-before-submission`; fixed commit hash: `not provided`; affected release/version range: `TBD-pin-before-submission`.
- [3] Production exploitability verdict: Indirect/business-logic exploitation via offchain consumer misuse of `getBadge` semantics.
- [4] Deterministic repro evidence: Forge + Medusa + Echidna + Halmos counterexamples (`f_taiko_01_getbadge_boundary_forge_test.txt`, `f_taiko_01_medusa_failfast_30s.txt`, `f_taiko_01_echidna_30s.txt`, `f_taiko_01_halmos.txt`). Validation reference: `reports/cat2_rollups/PROVEN_SUMMARY.md`.
- [5] Mitigation gap proof: Integrator-side checks are inconsistent across consumers; defect remains monetizable unless contract boundary is fixed and integrator migration is enforced.
- [6] Business impact quantification: Use the loss range above with expected lower direct protocol-loss but measurable support, reconciliation, and partner-dispute costs.
- [7] Abuse narrative: Attacker feeds crafted identifiers/data that pass weak consumer checks, then repeatedly claims unauthorized rewards/access while legitimate users face false denials.
- [8] Fix plan + cost: Patch plan: correct boundary condition in contract/API semantics, publish integrator migration guidance, and run compatibility tests. Estimated effort: 2-6 engineer-days + 1-2 QA days. Estimated remediation cost: ~$15k-$60k including retest.
- Direct exploitation status: indirect/business-logic exploitation (usually no direct onchain fund theft from contract state alone).
- Mitigation status:
1. Contract-level: not mitigated (inverted existence boundary remains).
2. Operational/integration: strong compensating controls exist (`ownerOf`/mint event checks), but many integrators omit them.
- Estimated attacker cost: very low (`~$0-$2,000`) because exploitation is mostly API/integration abuse and scripting.
- Estimated loss range: low-to-medium (`~$50k-$5M`) mainly from offchain reward/access abuse, support burden, and partner disputes.
- Primary mitigation layer: Contract boundary patch + integration updates
- Mitigation feasibility: High
- Residual risk if truly mitigated: Low-Medium
- Repo-specific manual check: Fix condition and validate integrators use canonical existence checks (`ownerOf`/mint state) where needed.
- Mitigation acceptance criteria: `Implemented` (fix exists at reviewed commit), `Enforced` (no bypass path exists), and `Demonstrated` (tests/witnesses show the same exploit path is blocked).
- Business impact:
1. Nonexistent badge acceptance can enable unauthorized access, rewards, or gating bypass.
2. False negatives for legitimate users increase support escalations and compensation risk.
3. Campaign analytics and partner settlement workflows become less reliable.
- Preconditions:
1. Integrators interpret successful `getBadge` call as proof of token existence.
2. Integrators do not cross-check with `ownerOf` or mint events.
3. Reward or gating logic depends on `getBadge` output.
- Detailed execution:
1. Attacker queries nonexistent token ID where `getBadge` returns success with zeroed struct.
2. Offchain app treats response as valid badge record.
3. Attacker claims access/reward path tied to that response.
4. Legitimate users with actual minted lower IDs may be rejected due inverse revert logic.
- Post-exploit objective:
1. Unauthorized benefit claims.
2. Eligibility confusion causing support and trust damage.
3. Business process disruption for badge-based campaigns.

### taiko-mono - F-TAIKOMONO-01 (`Medium`)
- Vulnerability type category: `Integration-facing data validity flaws`
- Repository activity flag (9-month rule): Active (latest commit: 2026-02-16; cutoff: 2025-05-17).
- [1] Program/Payout mapping: Policy class: `Business Logic / Data Validation / Offchain Trust Boundary`; severity tier: `Medium`; target payout band: `$5k-$30k (program-cap dependent)`; recommended claim framing: exploitable security defect with deterministic proof artifact.
- [2] Affected scope (exact): Repo `taiko-mono`; component/function `TrailblazersBadgesS2.getBadge(uint256)`; audit reference `reports/cat2_rollups/taiko-mono/report.md`; reviewed commit hash: `TBD-pin-before-submission`; fixed commit hash: `not provided`; affected release/version range: `TBD-pin-before-submission`.
- [3] Production exploitability verdict: Indirect/business-logic exploitation via mono integration misuse of `getBadge` semantics.
- [4] Deterministic repro evidence: Forge + Medusa + Echidna + Halmos counterexamples (`f_taikomono_01_getbadge_boundary_forge_test.txt`, `f_taikomono_01_medusa_failfast_30s.txt`, `f_taikomono_01_echidna_30s.txt`, `f_taikomono_01_halmos.txt`). Validation reference: `reports/cat2_rollups/PROVEN_SUMMARY.md`.
- [5] Mitigation gap proof: Integrator-side checks are inconsistent across consumers; defect remains monetizable unless contract boundary is fixed and integrator migration is enforced.
- [6] Business impact quantification: Use the loss range above with expected lower direct protocol-loss but measurable support, reconciliation, and partner-dispute costs.
- [7] Abuse narrative: Attacker feeds crafted identifiers/data that pass weak consumer checks, then repeatedly claims unauthorized rewards/access while legitimate users face false denials.
- [8] Fix plan + cost: Patch plan: correct boundary condition in contract/API semantics, publish integrator migration guidance, and run compatibility tests. Estimated effort: 2-6 engineer-days + 1-2 QA days. Estimated remediation cost: ~$15k-$60k including retest.
- Direct exploitation status: indirect/business-logic exploitation (integration abuse more than direct contract-state takeover).
- Mitigation status:
1. Contract-level: not mitigated (same inverted boundary bug).
2. Operational/integration: compensating checks can reduce abuse but require disciplined integrator implementation.
- Estimated attacker cost: very low (`~$0-$2,000`) for automation against weak integration logic.
- Estimated loss range: low-to-medium (`~$50k-$5M`) from repeated eligibility abuse and customer compensation/reconciliation costs.
- Primary mitigation layer: Contract boundary patch + integration updates
- Mitigation feasibility: High
- Residual risk if truly mitigated: Low-Medium
- Repo-specific manual check: Same verification pattern as `taiko-contracts` (`F-TAIKO-01`) for mono consumers and downstream tooling.
- Mitigation acceptance criteria: `Implemented` (fix exists at reviewed commit), `Enforced` (no bypass path exists), and `Demonstrated` (tests/witnesses show the same exploit path is blocked).
- Business impact:
1. Mono-integrated badge checks can be abused for unauthorized claim/eligibility paths.
2. Legitimate-user rejection risk creates churn and remediation overhead.
3. Partner-facing verification trust degrades when eligibility outcomes appear inconsistent.
- Preconditions:
1. Same `getBadge` inversion exists in mono code path.
2. Offchain consumers rely on call success semantics.
3. No independent existence validation is performed.
- Detailed execution:
1. Attacker submits nonexistent token IDs to integrator workflows.
2. Workflow reads successful `getBadge` and classifies attacker as eligible.
3. Legitimate users encounter false-negative outcomes on valid IDs.
4. Dispute load and manual reconciliation increase.
- Post-exploit objective:
1. Gain unauthorized campaign/reward access.
2. Trigger denial of rightful user claims.
3. Erode trust in badge verification tooling.




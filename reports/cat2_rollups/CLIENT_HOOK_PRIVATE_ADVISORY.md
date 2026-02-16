# Private Client Advisory (Teaser)

Date: `2026-02-16`  
Coverage: `cat2_rollups`  
Status: `Private / No public disclosure`

## Purpose

This document is the initial, non-weaponized advisory to validate that exploitable issues were identified.  
Detailed exploit paths, full PoCs, and remediation implementation details are intentionally withheld at this stage and provided only under paid engagement.

## What Is Safe To Share Initially

1. Exact affected repository and vulnerable function/component.
2. Severity and exploitability verdict (`Direct` / `Conditional-direct` / `Indirect`).
3. Business impact range and risk framing.
4. Proof existence (`Forge`, `Echidna`, `Halmos`, `Medusa`, `Rust harness`) without full reproduction steps.

## Portfolio Snapshot

1. Total validated findings: `19`
2. Critical: `4`
3. High: `10`
4. Medium: `5`
5. Repos with validated findings: `11`

## Initial Evidence Matrix (Non-Weaponized)

| Repo | ID | Severity | Vulnerable Surface | Exploitability | Business Impact (summary) | Proof Exists |
|---|---|---|---|---|---|---|
| `zkevm-contracts` | `F-ZKEVMC-01` | `Critical` | `AggLayerGateway.initialize(...)` | Conditional-direct | Validation-plane control takeover risk; high TVL trust impact | Forge witness |
| `scroll-contracts` | `F-SCROLL-01` | `Critical` | `ScrollChain.initialize(...)` | Conditional-direct | Owner capture in upgrade window; censorship/liveness impact | Forge + Medusa + Echidna + Halmos |
| `linea-contracts` | `F-LINEA-01` | `Critical` | `initializeParentShnarfsAndFinalizedState(...)` | Direct | Submission/finality DoS and emergency governance burden | Forge + Medusa + Echidna + Halmos |
| `mantle` | `F-MAN-01` | `Critical` | `Challenge.completeChallenge(bool)` | Direct (role-constrained) | Settlement winner rewrite and dispute fairness failure | Echidna + Halmos |
| `linea-contracts` | `F-LINEA-03` | `High` | `CustomBridgedToken.initializeV2(...)` | Conditional-direct | Bridge-authority capture and unauthorized mint risk | Forge + Medusa + Echidna + Halmos |
| `era-contracts` | `F-ERAC-01` | `High` | `ChainRegistrar.initialize(...)` | Conditional-direct | Ownership capture and proposer top-up diversion risk | Forge + Medusa + Echidna + Halmos |
| `base-contracts` | `F-BASE-01` | `High` | `BalanceTracker.initialize(...)` | Conditional-direct | Fee-routing capture and accounting integrity impact | Forge + Medusa + Echidna + Halmos |
| `optimism` | `F-OPT-01` | `High` | `ProtocolVersions.initialize(...)` | Conditional-direct | Version-signal hijack and operator desync risk | Forge + Medusa + Echidna + Halmos |
| `linea-contracts` | `F-LINEA-02` | `High` | `LineaRollupInit.initializeV2(...)` | Conditional-direct | Migration-anchor poisoning and recovery risk | Forge + Medusa + Echidna + Halmos |
| `mantle` | `F-MAN-04` | `High` | `Rollup.challengeAssertion(...)` | Direct (operator/staker class) | Unrelated victim griefing/slashing pathway | Forge + Medusa + Echidna + Halmos |
| `mantle` | `F-MAN-02` | `High` | `Rollup.createAssertion(...)` | Direct (authorized class) | Practical dispute-window collapse | Forge + Medusa + Echidna + Halmos |
| `mantle` | `F-MAN-03` | `High` | `Rollup.completeChallenge(...)` | Direct config-triggered | Challenge settlement deadlock/liveness failure | Medusa + Echidna + Halmos |
| `era-boojum` | `F-ERA-01` | `High` | Allocator reservation/commit logic | Direct/latent | Prover instability and throughput/finality degradation | Rust harness |
| `zkevm-circuits` | `F-ZKEVM-01` | `High` | `aggregator::decode_bytes` | Direct (ingress-dependent) | Panic-driven prover crash and outage risk | Rust harness |
| `zkevm-circuits` | `F-ZKEVM-02` | `Medium` | `identifier()` unwrap path | Direct (ingress-dependent) | Low-cost malformed-task DoS | Rust harness |
| `taiko-contracts` | `F-TAIKO-02` | `Medium` | `EventRegister.initialize()` | Conditional-direct | Event-manager takeover and data poisoning | Forge witness |
| `taiko-mono` | `F-TAIKOMONO-02` | `Medium` | `EventRegister.initialize()` | Conditional-direct | Same takeover pattern on mono surface | Forge witness |
| `taiko-contracts` | `F-TAIKO-01` | `Medium` | `TrailblazersBadgesS2.getBadge(uint256)` | Indirect | Eligibility/reward abuse via boundary bug | Forge + Medusa + Echidna + Halmos |
| `taiko-mono` | `F-TAIKOMONO-01` | `Medium` | `TrailblazersBadgesS2.getBadge(uint256)` | Indirect | Same integration-facing abuse pattern | Forge + Medusa + Echidna + Halmos |

## What Is Paid/Unlocked After Engagement

1. Full technical report per finding:
   - exact vulnerable code path and line references
   - preconditions and real attack path
   - exploit chain and blast radius
2. Deterministic PoC package:
   - reproducible commands
   - execution logs and traces
   - failure/success assertions
3. Remediation package:
   - patch design options (minimal and hardened)
   - rollout sequencing and guardrails
   - regression tests and closure criteria

## Commercial Structure (Direct, No Third Party)

1. `Package A`: Full report bundle (all findings)
2. `Package B`: Full report + PoC bundle
3. `Package C`: Full report + PoC + remediation support + retest sign-off

## Outreach Language (Safe)

Use this exact short text in first contact:

> We identified multiple exploitable security issues in your rollup stack (including critical control-plane and initialization weaknesses) and validated them with deterministic test evidence.  
> We are sharing a private non-weaponized advisory first. If useful, we can provide the full technical report, reproducible PoCs, and a remediation + retest package under NDA.

## Guardrails

1. No public disclosure commitment unless mutually agreed in writing.
2. No weaponized details in pre-engagement communications.
3. Coordinated private remediation workflow only.

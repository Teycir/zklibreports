# Private Client Advisory (Teaser)

Date: `2026-02-16`  
Coverage: `cat1_bridges`  
Status: `Private / No public disclosure`

## Purpose

This document is the initial, non-weaponized advisory to validate that exploitable issues were identified.  
Detailed exploit paths, full PoCs, and remediation implementation details are intentionally withheld at this stage and provided only under paid engagement.

## What Is Safe To Share Initially

1. Exact affected repository and vulnerable function/component.
2. Severity and exploitability verdict (`Direct` / `Conditional-direct` / `Indirect`).
3. Business impact range and risk framing.
4. Proof existence (`Forge`, `Echidna`, `Halmos`, `Medusa`, `Fuzz`, static witness) without full reproduction steps.

## Portfolio Snapshot

1. Total validated findings: `29`
2. Critical: `2`
3. High: `8`
4. Medium: `18`
5. Low: `1`
6. Repos with validated findings: `8`

## Initial Evidence Matrix (Non-Weaponized)

| Repo | ID | Severity | Vulnerable Surface | Exploitability | Business Impact (summary) | Proof Exists |
|---|---|---|---|---|---|---|
| `nomad-monorepo` | `F4` | `Critical` | `Retired replica can forge TransferGovernor handling and seize local governor privileges` | Direct | Local governance privilege takeover on affected chains. | Forge + Medusa + Echidna + Fuzz |
| `nomad-monorepo` | `F5` | `Critical` | `Retired replica can inject forged governance batch and execute privileged calls via executeCallBatch` | Direct | Direct arbitrary governance-call execution path without requiring explicit `governor` transfer first. | Forge + Medusa + Fuzz |
| `axelar-core` | `A2` | `High` | `RetryFailedEvent requeues failed events without persistent status transition, causing deterministic end-block panic` | Direct | Any unrestricted caller can trigger a deterministic end-block panic whenever at least one failed event exists. | Static witness + blocked runtime test |
| `LayerZero-v2` | `LZ2` | `High` | `Endpoint delegate privilege can persist after OApp ownership transfer and retain config control` | Conditional-direct (role-constrained) | Stale key can keep mutating endpoint config after intended ownership handoff. | Forge + Echidna + Fuzz |
| `nomad-monorepo` | `F1` | `High` | `Stale replicas remain authorized after domain re-enrollment (Auth boundary break)` | Direct | Attempted emergency rotation does not fully revoke previous replica authority. | Forge + Medusa + Fuzz |
| `nomad-monorepo` | `F3` | `High` | `Retired replica can still pass sink auth (onlyReplica + onlyRemoteRouter) and execute handle` | Direct | Rotation does not actually revoke stale replicas at sink boundaries. | Medusa + Echidna |
| `nomad-monorepo` | `F6` | `High` | `Bootstrap committed root is immediately acceptable (optimistic timeout bypass at initialization boundary)` | Direct | Optimistic delay does not protect the bootstrap root path. | Forge + Medusa + Echidna |
| `synapse-contracts` | `F2` | `High` | `DEFAULT_ADMIN_ROLE compromise can escalate into NODEGROUP_ROLE settlement authority and drain bridge collateral` | Conditional-direct (role-constrained) | Admin-key compromise has direct path to settlement execution capability. | Forge + Echidna + Fuzz |
| `telepathy-contracts` | `F1` | `High` | `Uninitialized-proxy first-caller initialization can seize bridge control plane and enable forged message execution` | Conditional-direct | Control-plane takeover of verifier and relayer policy. | Forge + Fuzz |
| `wormhole` | `W2` | `High` | `Token-bridge governance accepts stale guardian sets during expiry window` | Conditional-direct | If stale guardian keys are compromised during the expiry window (default 24h), attacker-signed governance VAAs can be accepted by token bridge governance. | Forge + Medusa + Echidna |
| `axelar-core` | `A1` | `Medium` | `Uppercase receiver filter in AxelarNet IBC path can panic on malformed uppercase receiver strings` | Direct | Untrusted packet data can deterministically trigger a panic in the receive handler path. | Static witness + blocked runtime test |
| `connext-monorepo` | `F1` | `Medium` | `Router liquidity withdrawal can undercollateralize remaining router balances under sender-tax payout token behavior` | Direct | Remaining router balances can become undercollateralized for affected token classes. | Forge + Medusa + Echidna |
| `connext-monorepo` | `F2` | `Medium` | `Canonical-domain execute payout can desynchronize custodied from real collateral under sender-tax token behavior` | Direct | Cap-tracked accounting can overstate retrievable collateral for affected token classes. | Forge + Medusa + Echidna |
| `connext-monorepo` | `F3` | `Medium` | `ERC20 bumpTransfer fee forwarding can consume bridge collateral under sender-tax payout token behavior` | Direct | Repeated bump-fee operations can drain bridge-side collateral for affected token classes. | Forge + Medusa + Echidna |
| `hyperlane-monorepo` | `H1` | `Medium` | `HypERC20Collateral + TokenRouter intent-level accounting can create collateral deficits with inbound-fee tokens` | Direct | Affected token classes can over-credit remote-side transfer liabilities relative to source-side collateral. | Forge + Medusa + Echidna |
| `hyperlane-monorepo` | `H2` | `Medium` | `LpCollateralRouter can overstate lpAssets vs real collateral under inbound-fee collateral tokens` | Direct | LP accounting can report more assets than physically held collateral. | Forge + Echidna + Fuzz |
| `hyperlane-monorepo` | `H3` | `Medium` | `TokenRouter fee transfer path can undercollateralize router accounting with sender-tax token behavior` | Direct | Token-specific accounting deficit in routers using fee transfers with sender-tax token behavior. | Forge + Echidna + Fuzz |
| `LayerZero-v2` | `LZ1` | `Medium` | `OFTAdapter lossless-transfer assumption can create collateral deficit with inbound-fee tokens` | Direct | For non-lossless tokens, OFT mesh accounting can over-credit remote side versus locked source collateral. | Forge + Echidna + Fuzz |
| `LayerZero-v2` | `LZ3` | `Medium` | `Endpoint payInLzToken path can sweep preloaded residual lzToken balance to caller-selected refund address` | Direct | Any stranded/preloaded endpoint `lzToken` becomes permissionlessly sweepable by arbitrary send caller. | Forge + Medusa + Echidna |
| `LayerZero-v2` | `LZ4` | `Medium` | `EndpointV2Alt native-fee path can sweep preloaded residual nativeErc20 balance to caller-selected refund address` | Direct | Any stranded/preloaded `nativeErc20` balance in EndpointV2Alt becomes permissionlessly sweepable by arbitrary send caller. | Forge |
| `nomad-monorepo` | `F10` | `Medium` | `migrate can convert canonical asset identity after representation alias overwrite` | Direct | Users can convert canonical `A` exposure into canonical `B` settlement path using migrate-assisted flow. | Forge + Medusa + Echidna |
| `nomad-monorepo` | `F2` | `Medium` | `Unenrolling stale replica can desync forward/reverse mappings` | Direct | domain lookup says "no replica" | Fuzz |
| `nomad-monorepo` | `F7` | `Medium` | `Forged preFill can drain dust pool without providing liquidity` | Direct | Native-asset dust reserves can be drained at near-zero token cost. | Forge + Medusa + Echidna |
| `nomad-monorepo` | `F8` | `Medium` | `enrollCustom allows representation aliasing across canonical IDs, enabling cross-asset remapping` | Direct | Cross-asset remapping becomes possible after a single configuration mistake. | Forge + Medusa + Echidna |
| `nomad-monorepo` | `F9` | `Medium` | `Governance domain-list churn inflates global dispatch scans (liveness/gas degradation)` | Direct | Governance broadcast operations can become progressively more expensive despite unchanged active topology. | Forge + Medusa + Echidna |
| `synapse-contracts` | `F1` | `Medium` | `deposit / depositAndSwap intent-level amount handling can over-credit cross-chain liabilities for fee-on-transfer tokens` | Direct | For affected tokens, source-chain collateral can be lower than destination-side credited amount. | Forge + Medusa + Echidna |
| `synapse-contracts` | `F3` | `Medium` | `Destination min-out can be violated on actual user receipt when payout token transfer applies sender-side tax` | Direct | User-facing min-out guarantees can be violated for affected token classes. | Forge + Echidna + Fuzz |
| `wormhole` | `W3` | `Medium` | `Outbound sender-tax tokens can break bridge token solvency accounting` | Direct | For affected token classes, redemption can drive bridge accounting insolvent for that token. | Forge + Medusa + Echidna |
| `wormhole` | `W1` | `Low` | `Metadata-method assumptions in attestToken / _transferTokens cause deterministic token-specific DoS` | Direct | Affected tokens cannot be attested/bridged via this bridge path. | Forge + Medusa + Echidna |

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

> We identified multiple exploitable security issues in your bridge stack (including critical trust-boundary and accounting weaknesses) and validated them with deterministic test evidence.  
> We are sharing a private non-weaponized advisory first. If useful, we can provide the full technical report, reproducible PoCs, and a remediation + retest package under NDA.

## Guardrails

1. No public disclosure commitment unless mutually agreed in writing.
2. No weaponized details in pre-engagement communications.
3. Coordinated private remediation workflow only.

# cat2_rollups Manual Audit Roadmap

This roadmap is for **manual** audits first, then **tool-backed validation** to prove or falsify each hypothesis with a witness.

## Global Rules

- No vulnerability claim without a witness: PoC, failing test, concrete tx sequence, symbolic counterexample, or reachability trace.
- Baseline tool output is triage input only.
- Prioritize on-chain critical paths (bridge, proof verification, settlement, upgrade control) before peripheral services.

## Common Deliverables (Per Repo)

Create `reports/cat2_rollups/<repo>/manual_audit.md` including:
- Architecture map (L1 <-> L2 trust boundaries and message flow)
- Attack surface inventory (contracts, privileged roles, upgrade/admin paths, external dependencies)
- Top invariants (auth, replay protection, state-root/proof integrity, withdrawal safety, accounting)
- Ranked hypotheses and validation plan
- Validation artifacts tied to each hypothesis

## Highest Priority Order

### 1) mantle

Why first:
- Highest combined count (`osv=1567`, `gitleaks=87`)
- Multi-stack surface (`go,node,solidity`)

Focus:
- Canonical bridge/deposit-withdraw lifecycle and replay invariants
- Sequencer/prover/admin roles, emergency controls, and upgrade safety
- Cross-domain messenger assumptions and message authenticity

Validation:
- Slither + role/config diff review
- Property/invariant tests for withdrawal finalization and replay rules

### 2) optimism

Why second:
- Very high `osv` signal (`1008`) plus Rust audit findings
- Baseline coverage gap (`gitleaks` + `osv` timeout on current run)

Focus:
- Fault/dispute game and finalization assumptions
- Inbox/outbox messaging and forced inclusion properties
- Privileged upgrade/config paths across contracts and services

Validation:
- Re-run targeted `gitleaks`/`osv` with longer timeout and narrowed scope
- Manual review of high-risk dependency paths from `osv` output

### 3) era-contracts

Why third:
- Highest secrets signal in this category (`gitleaks=376`)
- Mixed `node,rust,solidity` with non-trivial dependency surface

Focus:
- Bridge verifier/finality logic, privileged functions, and replay protection
- Token/accounting invariants under asynchronous cross-domain execution

Validation:
- Secret triage with provenance checks
- Solidity static review + targeted invariant tests

### 4) zkevm-circuits

Why fourth:
- High secrets signal (`231`) plus substantial `osv` and Rust findings

Focus:
- Circuit/prover boundary assumptions and verifier contract coupling
- Constraint completeness and witness integrity invariants

Validation:
- Circuit-level property checks and negative witness tests
- Contract/circuit interface consistency checks

### 5) taiko-mono and taiko-contracts

Why fifth:
- Elevated `osv` and `cargo-audit` counts in both repos
- Similar commit SHA in current scan; treat as potentially overlapping risk surface

Focus:
- L1/L2 bridge lifecycle, forced inclusion, challenge/finality logic
- Upgradeability and role separation across contracts/services

Validation:
- Deduplicate repo overlap first, then triage dependency and Rust advisory leads

## Secondary Queue

- `zkevm-contracts`
- `scroll-contracts`
- `linea-contracts`
- `base-contracts`
- `era-boojum`
- `arbitrum`
- `stone-prover`

## Immediate Remediation for Scan Quality

- Improve Go scanning to run `govulncheck` per discovered `go.mod` root (current root-level invocation misses multi-module layouts).
- Add targeted retry path for timeout-prone repos (`optimism`) without rerunning all tools.
- Keep `gitleaks` redaction enabled and verify no raw secrets are persisted in logs.


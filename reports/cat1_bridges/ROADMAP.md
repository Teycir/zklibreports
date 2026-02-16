# cat1_bridges Manual Audit Roadmap

This roadmap is for **manual** audits first, then **tool-backed validation** (prove or falsify each hypothesis with a witness).

## Global Rules

- No vulnerability claim without a witness: PoC / failing test / concrete transaction sequence / symbolic counterexample / reachability trace.
- Tool output is triage input only.
- Start with on-chain critical paths; expand to off-chain agents/relayers only when an on-chain hypothesis depends on them.

## Common Deliverables (Per Repo)

Each repo gets: `reports/cat1_bridges/<repo>/manual_audit.md` containing:
- Architecture map (message flow + trust assumptions)
- Attack surface inventory (contracts, roles, upgrade paths, admin keys, external calls)
- Top invariants (replay protection, domain separation, auth, nonce/sequence, upgrade safety, pausing, fee accounting)
- Hypotheses (ranked) with validation plan
- Validation artifacts (tool runs and/or minimal repros) tied to each hypothesis

## Tool Set (Validation)

Already available on this host:
- `slither` (Solidity static analysis)
- `halmos` (EVM symbolic testing; best with Foundry-style tests)
- `solc` (Solidity compiler)
- `gitleaks` (secrets; always redacted)
- `osv-scanner` (dependency vuln leads)
- `govulncheck`, `gosec` (Go)
- `cargo audit` (Rust lockfile vulns)

Planned installs if needed for proof-grade validation:
- Foundry (`forge`) to run invariants and drive Halmos on Solidity-heavy repos.
- Echidna (fuzz/invariants) for high-signal bug reproduction when properties are clear.

## Order (1 to 5)

### 1) wormhole

Scope (phase order):
- Contracts: core + token bridge + governance/guardian verification path + upgrade hooks.
- Then: relayer / SDK only if needed to validate an on-chain exploit chain.

Manual focus:
- Guardian signature verification, domain separation, replay protection, emitter/address normalization, message parsing.
- Upgradeability and admin controls; pause/emergency flows; fee and refund logic.
- Cross-chain consistency assumptions (chainId/domain mapping and uniqueness).

Validation:
- Slither pass on core Solidity/EVM components.
- Targeted Halmos invariants on message verification + replay protection once Foundry harness exists.

### 2) nomad-monorepo

Scope:
- Core bridge contracts (home/replica/message handling), upgradability, access control.

Manual focus:
- Message root/commitment verification, optimistic verification assumptions, fraud window, replay protection.
- Initialization and upgrade sequencing; role separation (owner/updater/watcher).

Validation:
- Slither + targeted symbolic checks for “accept invalid message” style properties.

### 3) LayerZero-v2

Scope:
- Endpoint/message delivery contracts + any verification/fee modules.

Manual focus:
- Nonce / sequence rules, executor/validator trust model, fee accounting, reentrancy/external call patterns.
- Config surfaces that can downgrade security.

Validation:
- Slither; property tests for nonce/sequence monotonicity and config constraints.

### 4) hyperlane-monorepo

Scope:
- On-chain messaging + any interchain security modules used by default.

Manual focus:
- Validator set handling, signature aggregation/threshold logic, domain separation.
- Upgrade and module configuration safety.

Validation:
- Slither for Solidity; Rust/Go tool validation where on-chain logic depends on off-chain components.

### 5) synapse-contracts

Scope:
- Synapse bridge/router contracts, swap/AMM interactions if in-path.

Manual focus:
- External protocol integration assumptions, slippage checks, accounting and rounding, reentrancy.
- Role/admin paths; upgrade safety; allowlists.

Validation:
- Slither + targeted invariant tests for accounting and role safety.

## Next Step

Start with `wormhole` and produce the first `manual_audit.md` with a minimal architecture map + 10–20 ranked hypotheses, then validate top 3–5 with tools.


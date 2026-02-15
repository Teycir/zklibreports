# Tools

This is a quick reference for the tools we run and what “proof” typically looks like for each one.

## Secrets

- `gitleaks`: searches repo history and working tree for secrets.
  - Proof: a real credential in reachable code/config. Output should be **redacted** in stored artifacts.

## Dependency Vulnerabilities

- `osv-scanner`: dependency matching against OSV/Deps.dev data.
  - Proof: show an in-repo dependency edge that pulls the vulnerable version *and* a reachability path to the vulnerable code (call trace, import path, or a minimal repro).

## Go

- `govulncheck`: reports known vulns with optional symbol-level traces.
  - Proof: a `symbol`-level report (or a repro) that shows the vulnerable symbol is reachable from the codebase.
- `gosec`: static analyzer for common Go security issues.
  - Proof: a minimized repro (or clear dataflow path) demonstrating real impact and exploitability.

## Rust

- `cargo audit`: checks `Cargo.lock` against RustSec advisories.
  - Proof: reachability evidence from in-repo code to vulnerable crate APIs under the actual feature set.
- `cargo deny`: policy checks (licenses, bans, advisories, sources).
  - Proof: typically policy, not “vuln”; treat as compliance issues unless it maps to a concrete exploit.

## Node / TypeScript

- `npm audit`: lockfile vulnerability scan.
  - Proof: reachability in the shipped/runtime path; many findings are dev-only or unreachable in production.
  - Host note: on this Windows host, use `cmd /c npm.cmd ...` instead of `npm` in PowerShell due to script policy.

## Solidity / EVM

- `halmos`: symbolic testing for EVM smart contracts, commonly run against Foundry-style tests (invariants / stateful sequences).
  - Proof: a Halmos counterexample trace/model violating a stated invariant (plus a minimized transaction sequence if possible).
  - Install: `python -m pip install halmos`
  - Run (example): `halmos --root <repo> --match-contract <TestContractRegex> --match-test <InvariantRegex>`

Other common follow-ups (optional, project-dependent): Slither, Echidna, Foundry invariant tests, custom fuzzers, formal specs.


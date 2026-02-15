# zklibreports

This repo is a working log + artifact store for auditing ZK libraries and ZK-adjacent infrastructure (including bridges).

## What We Mean By “Provable Vulns”

We are not interested in “tool says scary thing” findings unless we can produce a witness:
- A minimal repro (test, PoC, transaction sequence, input file) that triggers the bad behavior.
- A trace/counterexample (e.g. `govulncheck` symbol trace, Halmos counterexample model, sanitizer crash, etc.).
- A clear reachability path from in-repo code to a vulnerable dependency.

Tool output is treated as *leads* until proven.

More detail: `docs/PROOF_BAR.md`

## Layout

- `reports/cat8_libs/`: category-8 library audits (reports + artifacts).
- `reports/cat1_bridges/`: category-1 bridge audits (per-repo reports + artifacts).
- `scripts/`: automation to generate reports.
- `artifacts/`: shared tool outputs and formal-analysis artifacts.

## Tooling

We use different tools depending on language surface:
- Secrets: `gitleaks`
- Dependency vulns: `osv-scanner` (+ language-specific reachability where safe)
- Go: `govulncheck`, `gosec`
- Rust: `cargo audit`, `cargo deny`
- Node: `npm audit` (note: on this host use `cmd /c npm.cmd ...` due to PowerShell script policy)
- Solidity/EVM: `halmos` (symbolic / invariant testing; usually driven from Foundry tests)

Details + “what counts as proof” per tool: `docs/TOOLS.md`


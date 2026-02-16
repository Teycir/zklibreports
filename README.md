# zklibreports

This repo is a working log and artifact store for auditing ZK libraries and ZK-adjacent infrastructure (including bridges and rollups).

## What We Mean By Provable Vulnerabilities

We do not treat "tool says scary thing" output as a vulnerability claim unless there is a witness.

Accepted witness types:
- Minimal repro (test, PoC, transaction sequence, or crafted input) that triggers the behavior.
- Counterexample trace/model (symbolic or fuzzing).
- Deterministic crash or assertion evidence.
- Clear in-repo reachability path to vulnerable dependency code.

Tool output is treated as a lead until proven.

References:
- `docs/PROOF_BAR.md`
- `docs/METHODOLOGY.md`

## Layout

- `reports/cat8_libs/`: category-8 library audits (reports and artifacts).
- `reports/cat1_bridges/`: category-1 bridge audits (reports and artifacts).
- `reports/cat2_rollups/`: category-2 rollup audits (reports and artifacts).
- `scripts/`: automation and tool wrappers.
- `artifacts/`: shared tool outputs and analysis artifacts.
- `proof_harness/`: executable witness harnesses.

## Tooling

Primary tool map and proof expectations:
- `docs/TOOLS.md`

Formal operating process:
- `docs/METHODOLOGY.md`


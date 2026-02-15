# Proof Bar (Vulnerabilities)

This repo uses a high confidence bar for vulnerability claims. The default stance is: **tool output is a lead**, not a vuln.

## What Counts As “Proven”

Any of the following can be sufficient if it is reproducible and clearly scoped:
- **Executable repro**: unit/integration test or minimal program that triggers the issue.
- **Concrete exploit path**: transaction sequence or script that demonstrates impact (loss of funds, auth bypass, replay, etc.).
- **Symbolic counterexample**: a solver-produced model/trace that violates a stated property.
- **Crash/UB evidence**: sanitizer report, assertion failure, or deterministic crash with a minimized input.
- **Reachability proof to a vulnerable dependency**: evidence that in-repo code reaches the vulnerable function(s) under realistic build/runtime configuration.

## What Does Not Count By Itself

- “Package X has CVE Y” without reachability evidence.
- Static-analysis findings without a reproducer or an unambiguous trace to an exploit condition.
- “Looks scary” patterns without demonstrating an actual violation.

## Suggested Labels

- **FORMALLY CONFIRMED**: proof is a formal counterexample (or equivalent) plus clear impact statement.
- **CONFIRMED**: strong reproducible proof (PoC/test/trace) and clear impact.
- **LIKELY**: strong lead, but missing one of: repro, reachability, or impact clarity.
- **NOT CONFIRMED**: tool hint only.


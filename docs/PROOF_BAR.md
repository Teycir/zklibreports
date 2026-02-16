# Proof Bar (Vulnerabilities)

This repo uses a high-confidence bar for vulnerability claims.
Default stance: tool output is a lead, not a vulnerability.

## What Counts As Proven

Any of the following can be sufficient if it is reproducible and clearly scoped:
- Executable repro: unit/integration test or minimal program that triggers the issue.
- Concrete exploit path: transaction sequence or script showing impact (auth bypass, asset loss, replay, governance abuse).
- Symbolic counterexample: a solver-produced model/trace that violates a stated property.
- Crash/UB evidence: sanitizer report, assertion failure, or deterministic crash with minimized input.
- Dependency reachability proof: evidence that in-repo code reaches vulnerable dependency functions in realistic runtime/build config.

## What Does Not Count By Itself

- "Package X has CVE Y" without reachability evidence.
- Static-analysis findings without a repro or unambiguous exploit trace.
- "Looks risky" patterns without demonstrated invariant break.

## Suggested Labels

- FORMALLY CONFIRMED: formal counterexample (or equivalent) plus clear impact.
- CONFIRMED: strong reproducible proof and clear impact.
- LIKELY: strong lead, missing one of repro, reachability, or impact clarity.
- NOT CONFIRMED: tool hint only.


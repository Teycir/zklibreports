# hop (Manual Audit, Step 2/5)

Scope: `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\hop`

HEAD: `3ae90badbed5708d72cec46d0efeb004a4d0c587`

Pass status: Blocked for native-fuzz confirmation in this pass (no in-repo fuzz harness/entrypoints; third-party tooling probe unresolved).

Primary scope (this pass):
- Bridge-critical logic in `packages/hop-node`, `packages/v2-hop-node`, `packages/sdk`, `packages/v2-sdk`.

Non-goals (this pass):
- Target-code modifications to add new fuzz harnesses in this pass.

## Protocol Snapshot (Off-chain / Node-SDK Plane)

- Repo is TS/JS-heavy monorepo (no Solidity contracts in this snapshot).
- Operational bridge logic appears to live in node/indexer/SDK packages.

## Critical Invariants (Planned)

- Message provenance and destination-chain consistency across node/sdk routing.
- Nonce/transfer-id monotonicity and replay resistance in off-chain processing.
- Fee/amount normalization consistency across chain adapters.

## Tool Triage Summary

- Baseline leads from:
  - `reports/cat1_bridges/hop/artifacts/gitleaks.json` (1280 findings)
  - `reports/cat1_bridges/hop/artifacts/osv.json` (158 vulnerabilities)
- These are triage inputs only; no vulnerability promoted without witness.

## Native-Fuzz Confirmation Blocker

Evidence artifacts:
- `reports/cat1_bridges/hop/manual_artifacts/fuzzer_applicability_blocker.txt`
- `reports/cat1_bridges/hop/manual_artifacts/jazzerjs_core_probe.txt`
- `reports/cat1_bridges/hop/manual_artifacts/native_fuzz_surface_discovery.txt`

Key facts:
- `*.sol` files: `0`
- `foundry.toml` files: `0`
- Repo-wide source scan found no in-repo JS/TS fuzz/property-framework markers in source files.
- `cmd /c npx.cmd --yes "@jazzer.js/core" --help` is runnable on this host, but Jazzer.js requires a fuzz target module exporting `fuzz(Buffer)`; no such in-repo harness entrypoint was found.

Conclusion:
- Non-EVM fuzz tooling was attempted.
- This repo snapshot does not expose an in-repo native fuzz harness/entrypoint surface for witness-grade campaigns without adding target fuzz code.

## Outcome

- No findings promoted in this pass.
- Blocker recorded; moved to next cat1 target per process.

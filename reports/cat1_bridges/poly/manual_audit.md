# poly (Manual Audit, Step 2/5)

Scope: `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\poly`

HEAD: `eb4489eeedd17f7904e6ba73810bd2ef799cde82`

Pass status: Blocked for native-fuzz confirmation in this pass (no in-repo Go fuzz harness/entrypoints).

Primary scope (this pass):
- Bridge-critical logic in `native`, `core`, `consensus`, `http`, and validator/tx processing paths.

Non-goals (this pass):
- Target-code modifications to add new fuzz harnesses in this pass.

## Protocol Snapshot (Go Runtime Plane)

- Repo is Go-only in this snapshot (`go` runtime + native modules), with no Solidity contracts.
- Bridge behavior is implemented in Go execution/state modules.

## Critical Invariants (Planned)

- Cross-chain proof/message verification must be deterministic and non-bypassable.
- State-transition ordering for lock/mint/burn/execute paths must preserve conservation.
- Validator/consensus acceptance conditions must not allow malformed cross-chain state updates.

## Tool Triage Summary

- Baseline leads from:
  - `reports/cat1_bridges/poly/artifacts/gitleaks.json` (68 findings)
  - `reports/cat1_bridges/poly/artifacts/osv.json` (228 vulnerabilities)
  - `reports/cat1_bridges/poly/artifacts/govulncheck.json`
  - `reports/cat1_bridges/poly/artifacts/gosec.json`
- These are triage inputs only; no vulnerability promoted without witness.

## Native-Fuzz Confirmation Blocker

Evidence artifacts:
- `reports/cat1_bridges/poly/manual_artifacts/fuzzer_applicability_blocker.txt`
- `reports/cat1_bridges/poly/manual_artifacts/go_native_fuzz_attempt.txt`
- `reports/cat1_bridges/poly/manual_artifacts/go_native_fuzz_discovery.txt`
- `reports/cat1_bridges/poly/manual_artifacts/native_fuzz_surface_discovery.txt`

Key facts:
- `*.sol` files: `0`
- `foundry.toml` files: `0`
- `go test ./... -run=^$ -fuzz=Fuzz -fuzztime=30s` cannot run with multiple packages (`go test` fuzz restriction).
- Package-by-package discovery across `137` packages found no `func Fuzz*` entrypoints.
- Source scan found no in-repo `testing/fuzz` integration or common Go fuzz-framework markers.

Conclusion:
- Non-EVM Go-native fuzz workflow was attempted.
- This repo snapshot does not expose runnable in-repo fuzz entrypoints for witness-grade campaigns without adding target fuzz code.

## Outcome

- No findings promoted in this pass.
- Blocker recorded; moved to next cat1 target per process.

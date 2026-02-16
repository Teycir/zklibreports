# poly (Manual Audit, Step 2/5)

Scope: `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\poly`

HEAD: `eb4489eeedd17f7904e6ba73810bd2ef799cde82`

Pass status: Blocked for specialist-fuzzer phase in this pass (no in-repo Solidity/Foundry target surface).

Primary scope (this pass):
- Bridge-critical logic in `native`, `core`, `consensus`, `http`, and validator/tx processing paths.

Non-goals (this pass):
- Any EVM fuzz campaign requiring local Solidity contracts/harnesses (Foundry/Medusa/Halmos/Echidna), because this repo snapshot has no Solidity source surface.

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

## Specialist-Fuzzer Applicability Blocker

Evidence artifact:
- `reports/cat1_bridges/poly/manual_artifacts/fuzzer_applicability_blocker.txt`

Key facts:
- `*.sol` files: `0`
- `foundry.toml` files: `0`

Conclusion:
- Foundry/Medusa/Halmos/Echidna workflow is not applicable for this target snapshot.

## Outcome

- No findings promoted in this pass.
- Blocker recorded; moved to next cat1 target per process.

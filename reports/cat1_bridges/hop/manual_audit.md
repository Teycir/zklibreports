# hop (Manual Audit, Step 2/5)

Scope: `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges\hop`

HEAD: `3ae90badbed5708d72cec46d0efeb004a4d0c587`

Pass status: Blocked for specialist-fuzzer phase in this pass (no in-repo Solidity/Foundry target surface).

Primary scope (this pass):
- Bridge-critical logic in `packages/hop-node`, `packages/v2-hop-node`, `packages/sdk`, `packages/v2-sdk`.

Non-goals (this pass):
- Any EVM fuzz campaign requiring local Solidity contracts/harnesses (Foundry/Medusa/Halmos/Echidna), because this repo snapshot has no Solidity source surface.

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

## Specialist-Fuzzer Applicability Blocker

Evidence artifact:
- `reports/cat1_bridges/hop/manual_artifacts/fuzzer_applicability_blocker.txt`

Key facts:
- `*.sol` files: `0`
- `foundry.toml` files: `0`

Conclusion:
- Foundry/Medusa/Halmos/Echidna workflow is not applicable for this target snapshot.

## Outcome

- No findings promoted in this pass.
- Blocker recorded; moved to next cat1 target per process.

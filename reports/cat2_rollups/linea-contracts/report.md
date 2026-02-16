# linea-contracts

> Exhaustion status: closed at commit `b64fe259195f00e840d1e2a3f08b8e95e7c90918`. See `reports/cat2_rollups/linea-contracts/manual_audit.md` and `reports/cat2_rollups/linea-contracts/EXHAUSTION_ADDENDUM.md`.

- Source: `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\linea-contracts`
- HEAD: `b64fe259195f00e840d1e2a3f08b8e95e7c90918`
- origin: `https://github.com/Consensys/linea-contracts`
- Stacks: `node`, `solidity`

## Manual Verdict

- `CONFIRMED`: 1
- `LIKELY`: 0
- `NOT CONFIRMED`: baseline scanner leads that did not reach unprivileged exploit threshold after triage

## Proven Findings

## F-LINEA-01: Unprotected `reinitializer(5)` allows permissionless `shnarf` poisoning and rollup submission DoS

Severity: `Critical`

Status: `CONFIRMED`

Affected code:
- `contracts/LineaRollup.sol:129` - `initializeParentShnarfsAndFinalizedState(...)` is `external reinitializer(5)` with no role guard
- `contracts/LineaRollup.sol:138` - function directly writes attacker-supplied values into `shnarfFinalBlockNumbers`
- `contracts/LineaRollup.sol:281` - submission path trusts `shnarfFinalBlockNumbers[_parentShnarf]` for parent continuity
- `contracts/LineaRollup.sol:326` - continuity check enforces `_parentFinalBlockNumber + 1 == firstBlockInData` (unchecked arithmetic)
- `contracts/LineaRollup.sol:331` - submission also requires `firstBlockInData > currentL2BlockNumber`

Root cause:
- A privileged migration/recovery reinitializer is externally callable by any address, so initialization version consumption and critical state rewrites are first-caller controlled.

Witness sequence:
1. Proxy is initialized normally (`initialize(...)` at version `1`).
2. Any external attacker calls `initializeParentShnarfsAndFinalizedState([GENESIS_SHNARF], [type(uint256).max])`.
3. Parent continuity for the canonical genesis parent becomes unsatisfiable for normal next-block submission (`+1` wraps to `0`, then fails finalized-block ordering checks).
4. Because `reinitializer(5)` is now consumed by attacker, admin cannot replay the same function to repair via intended path.

Business implication (non-technical):
- A single public transaction can halt the rollup's data submission/finalization pipeline.
- User-facing effects include delayed state finality and bridge/withdrawal operations appearing stuck until emergency intervention.
- Recovery shifts to emergency governance/upgrade operations, increasing downtime, operational risk, and trust impact.

Deterministic witness:
- Harness: `proof_harness/cat2_linea_f1_reinitializer_dos/src/LineaF1ReinitializerDosHarness.sol`
- Test: `proof_harness/cat2_linea_f1_reinitializer_dos/test/LineaF1ReinitializerDos.t.sol`
- Run: `forge test --match-path test/LineaF1ReinitializerDos.t.sol -vv`
- Artifact: `reports/cat2_rollups/linea-contracts/manual_artifacts/f_linea_01_reinitializer_dos_forge_test.txt`
- Result: 2/2 tests passed (permissionless DoS + admin lockout after attacker consumes reinitializer version).

Specialist fuzz witness:
- Medusa harness: `proof_harness/cat2_linea_f1_reinitializer_dos/src/MedusaLineaF1ReinitializerDosHarness.sol`
- Medusa run: `medusa fuzz --config medusa.json --workers 4 --timeout 30`
- Medusa artifact: `reports/cat2_rollups/linea-contracts/manual_artifacts/f_linea_01_medusa_failfast_30s.txt`
- Medusa counterexample (minimized): `action_attacker_poison_genesis()` falsifies `property_genesis_submission_path_remains_valid()`.
- Echidna harness: `proof_harness/cat2_linea_f1_reinitializer_dos/src/EchidnaLineaF1ReinitializerDosHarness.sol`
- Echidna run: `echidna src/EchidnaLineaF1ReinitializerDosHarness.sol --contract EchidnaLineaF1ReinitializerDosHarness --format text --workers 4 --timeout 30 --test-limit 20000 --corpus-dir echidna-corpus-f-linea-01`
- Echidna artifact: `reports/cat2_rollups/linea-contracts/manual_artifacts/f_linea_01_echidna_30s.txt`
- Echidna counterexample (minimized): `action_attacker_poison_genesis()` falsifies `echidna_genesis_submission_path_remains_valid()`.
- Halmos harness: `proof_harness/cat2_linea_f1_reinitializer_dos/test/HalmosLineaF1ReinitializerDos.t.sol`
- Halmos run: `halmos --contract HalmosLineaF1ReinitializerDos --function check_attacker_cannot_brick_genesis_submission --json-output reports/cat2_rollups/linea-contracts/manual_artifacts/f_linea_01_halmos.json`
- Halmos artifacts:
- `reports/cat2_rollups/linea-contracts/manual_artifacts/f_linea_01_halmos.txt`
- `reports/cat2_rollups/linea-contracts/manual_artifacts/f_linea_01_halmos.json`
- Halmos result: counterexample found for `check_attacker_cannot_brick_genesis_submission()`.

Primary source snippets:
- `reports/cat2_rollups/linea-contracts/manual_artifacts/f_linea_01_key_snippets.txt`

## Tool Outputs (Baseline)

- `gitleaks`: `artifacts/gitleaks.json` (exit=1, findings=28)
- `osv-scanner`: `artifacts/osv.json` (exit=1, vulns=70)

## Exhaustive Lead Artifacts

- `reports/cat2_rollups/linea-contracts/manual_artifacts/lead_counts.txt`
- `reports/cat2_rollups/linea-contracts/manual_artifacts/prodcore_lead_counts.txt`
- `reports/cat2_rollups/linea-contracts/manual_artifacts/prodcore_reinitializers.txt`

## Notes

- `contracts/LineaRollupInit.sol:18` and `contracts/tokenBridge/CustomBridgedToken.sol:16` expose additional unguarded `reinitializer(...)` entrypoints; these are tracked as unresolved high-risk design leads pending deployment-context confirmation and dedicated exploit promotion.

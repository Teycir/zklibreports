# linea-contracts

> Exhaustion status: closed at commit `b64fe259195f00e840d1e2a3f08b8e95e7c90918`. See `reports/cat2_rollups/linea-contracts/manual_audit.md` and `reports/cat2_rollups/linea-contracts/EXHAUSTION_ADDENDUM.md`.

- Source: `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\linea-contracts`
- HEAD: `b64fe259195f00e840d1e2a3f08b8e95e7c90918`
- origin: `https://github.com/Consensys/linea-contracts`
- Stacks: `node`, `solidity`

## Manual Verdict

- `CONFIRMED`: 3
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

## F-LINEA-02: `LineaRollupInit.initializeV2(...)` is first-caller in non-atomic upgrade flow, allowing migration-state takeover

Severity: `High`

Status: `CONFIRMED`

Affected code and upgrade context:
- `contracts/LineaRollupInit.sol:18` - `initializeV2(uint256,bytes32)` is `external reinitializer(3)` with no role guard
- `scripts/upgrades/upgradeLineaRollup_no_reinitialisation.ts:31` - plain `upgradeProxy(..., { kind: "transparent" })` path (no init call)
- `scripts/upgrades/upgradeLineaRollup_with_reinitialisation.ts:30` - safe path calls `initializeV2` during upgrade transaction
- `scripts/gnosis/encodingTX.ts:30` and `scripts/gnosis/encodingTX.ts:57` - both direct `upgrade` and `upgradeAndCall` encodings are produced

Root cause:
- A security-critical migration reinitializer is externally callable; when governance/admin uses a non-atomic upgrade path, the first external caller can set migration state and consume reinitializer versioning before intended initialization.

Witness sequence:
1. Proxy starts on V1 implementation and is initialized (`version=1`).
2. Admin upgrades proxy to `LineaRollupInit` implementation using plain upgrade (no call data).
3. Any attacker front-runs with `initializeV2(attackerBlock, attackerRoot)`.
4. Migration state is attacker-controlled and `reinitializer(3)` is consumed, blocking intended admin `initializeV2`.

Business implication (non-technical):
- During upgrade windows, a single external transaction can seize one-time migration initialization and force an attacker-chosen migration anchor.
- Recovery requires another privileged emergency upgrade rather than normal migration flow.

Deterministic witness:
- Harness: `proof_harness/cat2_linea_f2_initv2_upgrade_gap/src/LineaF2InitV2UpgradeGapHarness.sol`
- Test: `proof_harness/cat2_linea_f2_initv2_upgrade_gap/test/LineaF2InitV2UpgradeGap.t.sol`
- Run: `forge test --match-path test/LineaF2InitV2UpgradeGap.t.sol -vv`
- Artifact: `reports/cat2_rollups/linea-contracts/manual_artifacts/f_linea_02_rollupinit_initv2_upgrade_gap_forge_test.txt`
- Result: 2/2 tests passed (front-run exploit witness + immediate-init mitigation check).

Specialist fuzz witness:
- Medusa harness: `proof_harness/cat2_linea_f2_initv2_upgrade_gap/src/MedusaLineaF2InitV2UpgradeGapHarness.sol`
- Medusa run: `medusa fuzz --config medusa.json --workers 4 --timeout 30`
- Medusa artifact: `reports/cat2_rollups/linea-contracts/manual_artifacts/f_linea_02_medusa_failfast_30s.txt`
- Medusa counterexample (minimized): `action_attacker_front_run_initializeV2()` falsifies `property_migration_anchor_remains_admin_controlled()`.
- Echidna harness: `proof_harness/cat2_linea_f2_initv2_upgrade_gap/src/EchidnaLineaF2InitV2UpgradeGapHarness.sol`
- Echidna run: `echidna src/EchidnaLineaF2InitV2UpgradeGapHarness.sol --contract EchidnaLineaF2InitV2UpgradeGapHarness --format text --workers 4 --timeout 30 --test-limit 20000 --corpus-dir echidna-corpus-f-linea-02`
- Echidna artifact: `reports/cat2_rollups/linea-contracts/manual_artifacts/f_linea_02_echidna_30s.txt`
- Echidna counterexample (minimized): `action_attacker_front_run_initializeV2()` falsifies `echidna_migration_anchor_remains_admin_controlled()`.
- Halmos harness: `proof_harness/cat2_linea_f2_initv2_upgrade_gap/test/HalmosLineaF2InitV2UpgradeGap.t.sol`
- Halmos run: `halmos --contract HalmosLineaF2InitV2UpgradeGap --function check_attacker_cannot_takeover_initv2 --json-output reports/cat2_rollups/linea-contracts/manual_artifacts/f_linea_02_halmos.json`
- Halmos artifacts:
- `reports/cat2_rollups/linea-contracts/manual_artifacts/f_linea_02_halmos.txt`
- `reports/cat2_rollups/linea-contracts/manual_artifacts/f_linea_02_halmos.json`
- Halmos result: counterexample found for `check_attacker_cannot_takeover_initv2()`.

Primary source snippets:
- `reports/cat2_rollups/linea-contracts/manual_artifacts/f_linea_02_key_snippets.txt`

## F-LINEA-03: `CustomBridgedToken.initializeV2(...)` first-caller takeover can seize `bridge` and mint authority after non-atomic upgrade

Severity: `High`

Status: `CONFIRMED`

Affected code and upgrade context:
- `contracts/tokenBridge/CustomBridgedToken.sol:16` - `initializeV2(...)` is `public reinitializer(2)` with no role guard
- `contracts/tokenBridge/CustomBridgedToken.sol:19` - reinitializer writes attacker-supplied `_bridge`
- `contracts/tokenBridge/BridgedToken.sol:38` - `onlyBridge` gates privileged token controls
- `contracts/tokenBridge/BridgedToken.sol:48` - `mint(...)` is `external onlyBridge`
- `scripts/upgrades/upgradeL2MessageService.ts:24` - generic `upgradeProxy(..., { kind: "transparent" })` path with `PROXY_ADDRESS` and no post-upgrade call
- `contracts/proxies/ProxyAdmin.sol:1085` and `contracts/proxies/ProxyAdmin.sol:1097` - both non-atomic `upgrade` and atomic `upgradeAndCall` admin paths exist

Root cause:
- A bridge-authority reinitializer is externally callable. If a proxy upgrade to `CustomBridgedToken` is executed without same-tx init call, any external caller can consume `reinitializer(2)`, set `bridge` to attacker, and lock out intended reinitialization recovery.

Witness sequence:
1. Proxy starts on `BridgedToken` and is initialized by legitimate bridge (`bridge = tokenBridge`).
2. Admin upgrades proxy to `CustomBridgedToken` implementation using non-atomic upgrade path.
3. Attacker calls `initializeV2(..., attackerBridge)` first, consuming `reinitializer(2)`.
4. Attacker-controlled bridge mints arbitrary supply; original bridge loses mint authority; admin cannot re-run `initializeV2`.

Business implication (non-technical):
- A single transaction in upgrade windows can transfer token mint authority from canonical bridge operations to attacker-controlled infrastructure.
- User balances and bridged-asset integrity can be impacted until emergency governance intervention.

Deterministic witness:
- Harness: `proof_harness/cat2_linea_f3_custombridgedtoken_initv2_takeover/src/LineaF3CustomBridgedTokenInitV2TakeoverHarness.sol`
- Test: `proof_harness/cat2_linea_f3_custombridgedtoken_initv2_takeover/test/LineaF3CustomBridgedTokenInitV2Takeover.t.sol`
- Run: `forge test --match-path test/LineaF3CustomBridgedTokenInitV2Takeover.t.sol -vv`
- Artifact: `reports/cat2_rollups/linea-contracts/manual_artifacts/f_linea_03_custombridgedtoken_initv2_takeover_forge_test.txt`
- Result: 2/2 tests passed (bridge-role takeover + immediate-init mitigation check).

Specialist fuzz witness:
- Medusa harness: `proof_harness/cat2_linea_f3_custombridgedtoken_initv2_takeover/src/MedusaLineaF3CustomBridgedTokenInitV2TakeoverHarness.sol`
- Medusa run: `medusa fuzz --config medusa.json --workers 4 --timeout 30`
- Medusa artifact: `reports/cat2_rollups/linea-contracts/manual_artifacts/f_linea_03_medusa_failfast_30s.txt`
- Medusa counterexample (minimized): `action_attacker_seize_bridge_and_mint()` falsifies `property_bridge_control_remains_legitimate()`.
- Echidna harness: `proof_harness/cat2_linea_f3_custombridgedtoken_initv2_takeover/src/EchidnaLineaF3CustomBridgedTokenInitV2TakeoverHarness.sol`
- Echidna run: `echidna src/EchidnaLineaF3CustomBridgedTokenInitV2TakeoverHarness.sol --contract EchidnaLineaF3CustomBridgedTokenInitV2TakeoverHarness --format text --workers 4 --timeout 30 --test-limit 20000 --corpus-dir echidna-corpus-f-linea-03`
- Echidna artifact: `reports/cat2_rollups/linea-contracts/manual_artifacts/f_linea_03_echidna_30s.txt`
- Echidna counterexample (minimized): `action_attacker_seize_bridge_and_mint()` falsifies `echidna_bridge_control_remains_legitimate()`.
- Halmos harness: `proof_harness/cat2_linea_f3_custombridgedtoken_initv2_takeover/test/HalmosLineaF3CustomBridgedTokenInitV2Takeover.t.sol`
- Halmos run: `halmos --contract HalmosLineaF3CustomBridgedTokenInitV2Takeover --function check_attacker_cannot_takeover_bridge_role --json-output reports/cat2_rollups/linea-contracts/manual_artifacts/f_linea_03_halmos.json`
- Halmos artifacts:
- `reports/cat2_rollups/linea-contracts/manual_artifacts/f_linea_03_halmos.txt`
- `reports/cat2_rollups/linea-contracts/manual_artifacts/f_linea_03_halmos.json`
- Halmos result: counterexample found for `check_attacker_cannot_takeover_bridge_role()`.

Primary source snippets:
- `reports/cat2_rollups/linea-contracts/manual_artifacts/f_linea_03_key_snippets.txt`

## Tool Outputs (Baseline)

- `gitleaks`: `artifacts/gitleaks.json` (exit=1, findings=28)
- `osv-scanner`: `artifacts/osv.json` (exit=1, vulns=70)

## Exhaustive Lead Artifacts

- `reports/cat2_rollups/linea-contracts/manual_artifacts/lead_counts.txt`
- `reports/cat2_rollups/linea-contracts/manual_artifacts/prodcore_lead_counts.txt`
- `reports/cat2_rollups/linea-contracts/manual_artifacts/prodcore_reinitializers.txt`

## Notes

- `deploy/11_deploy_CustomBridgedToken.ts` uses atomic proxy deployment+init for first deployment, but this does not remove non-atomic upgrade-window risk demonstrated for subsequent proxy upgrades.

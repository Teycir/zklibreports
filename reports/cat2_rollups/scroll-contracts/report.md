# scroll-contracts

> Exhaustion status: closed at commit `db16a98dbbebbff453aa5869bf5a827b64b3689f`. See `reports/cat2_rollups/scroll-contracts/manual_audit.md` and `reports/cat2_rollups/scroll-contracts/EXHAUSTION_ADDENDUM.md`.

- Source: `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\scroll-contracts`
- HEAD: `db16a98dbbebbff453aa5869bf5a827b64b3689f`
- origin: `https://github.com/scroll-tech/scroll-contracts`
- Stacks: `node`, `solidity`

## Manual Verdict

- `CONFIRMED`: 1
- `LIKELY`: 0
- `NOT CONFIRMED`: several upgrade-context leads that did not reach promotion threshold in this pass

## Proven Findings

## F-SCROLL-01: `ScrollChain.initialize(...)` first-caller ownership takeover in non-atomic upgrade flow

Severity: `Critical`

Status: `CONFIRMED`

Affected code:
- `src/L1/rollup/ScrollChain.sol:250` - `initialize(...)` is `external initializer`
- `src/L1/rollup/ScrollChain.sol:255` - initializer calls `OwnableUpgradeable.__Ownable_init()` (owner becomes first caller)
- `src/L1/rollup/ScrollChain.sol:458` - owner can `addSequencer(...)`
- `src/L1/rollup/ScrollChain.sol:478` - owner can `addProver(...)`
- `src/L1/rollup/ScrollChain.sol:497` - owner can `setPause(...)`
- `scripts/foundry/InitializeL1BridgeContracts.s.sol:90` - deployment script explicitly uses non-atomic `upgrade(...)` then `initialize(...)`
- `scripts/foundry/InitializeL1BridgeContracts.s.sol:114` and `scripts/foundry/InitializeL1BridgeContracts.s.sol:119` - separate `upgrade` and `initialize` calls for `ScrollChain`

Root cause:
- Initialization authority is implicit (first caller) while deployment flow exposes an upgrade-to-initialization window.

Witness sequence:
1. Proxy admin upgrades proxy to `ScrollChain` implementation.
2. Before the legitimate `initialize(...)` transaction, attacker calls `initialize(...)`.
3. Attacker becomes owner.
4. Attacker can execute owner-only controls (pause, sequencer/prover administration).
5. Legitimate initializer is permanently locked out.

Business implication (non-technical):
- A public frontrun during rollout can hand operational control of the rollup to an attacker.
- Attacker can halt critical functions or alter privileged actor sets, disrupting block production/finalization operations.
- Recovery requires emergency governance intervention and can cause visible service interruption.

Deterministic witness:
- Harness: `proof_harness/cat2_scroll_f1_scrollchain_init_hijack/src/ScrollF1ScrollChainInitHijackHarness.sol`
- Test: `proof_harness/cat2_scroll_f1_scrollchain_init_hijack/test/ScrollF1ScrollChainInitHijack.t.sol`
- Run: `forge test --match-path test/ScrollF1ScrollChainInitHijack.t.sol -vv`
- Artifact: `reports/cat2_rollups/scroll-contracts/manual_artifacts/f_scroll_01_scrollchain_init_hijack_forge_test.txt`
- Result: 3/3 exploit-path tests passed (owner capture, privileged action after takeover, legitimate lockout).

Specialist fuzz witness:
- Medusa harness: `proof_harness/cat2_scroll_f1_scrollchain_init_hijack/src/MedusaScrollF1ScrollChainInitHijackHarness.sol`
- Medusa run: `medusa fuzz --config medusa.json --workers 4 --timeout 30`
- Medusa artifact: `reports/cat2_rollups/scroll-contracts/manual_artifacts/f_scroll_01_medusa_failfast_30s.txt`
- Medusa counterexample (minimized): `action_attacker_initialize()` falsifies `property_non_admin_cannot_take_scrollchain_owner()`.
- Echidna harness: `proof_harness/cat2_scroll_f1_scrollchain_init_hijack/src/EchidnaScrollF1ScrollChainInitHijackHarness.sol`
- Echidna run: `echidna src/EchidnaScrollF1ScrollChainInitHijackHarness.sol --contract EchidnaScrollF1ScrollChainInitHijackHarness --format text --workers 4 --timeout 30 --test-limit 20000 --corpus-dir echidna-corpus-f-scroll-01`
- Echidna artifact: `reports/cat2_rollups/scroll-contracts/manual_artifacts/f_scroll_01_echidna_30s.txt`
- Echidna counterexample (minimized): `action_attacker_initialize()` falsifies `echidna_non_admin_cannot_take_scrollchain_owner()`.
- Halmos harness: `proof_harness/cat2_scroll_f1_scrollchain_init_hijack/test/HalmosScrollF1ScrollChainInitHijack.t.sol`
- Halmos run: `halmos --contract HalmosScrollF1ScrollChainInitHijack --function check_non_admin_cannot_take_scrollchain_owner --json-output reports/cat2_rollups/scroll-contracts/manual_artifacts/f_scroll_01_halmos.json`
- Halmos artifacts:
- `reports/cat2_rollups/scroll-contracts/manual_artifacts/f_scroll_01_halmos.txt`
- `reports/cat2_rollups/scroll-contracts/manual_artifacts/f_scroll_01_halmos.json`
- Halmos result: counterexample found for `check_non_admin_cannot_take_scrollchain_owner()`.

Primary source snippets:
- `reports/cat2_rollups/scroll-contracts/manual_artifacts/f_scroll_01_key_snippets.txt`

## Tool Outputs (Baseline)

- `gitleaks`: `artifacts/gitleaks.json` (exit=1, findings=7)
- `osv-scanner`: `artifacts/osv.json` (exit=1, vulns=102)

## Exhaustive Lead Artifacts

- `reports/cat2_rollups/scroll-contracts/manual_artifacts/lead_counts.txt`
- `reports/cat2_rollups/scroll-contracts/manual_artifacts/exhaustive_map_initialize_functions.txt`
- `reports/cat2_rollups/scroll-contracts/manual_artifacts/exhaustive_map_reinitializers.txt`
- `reports/cat2_rollups/scroll-contracts/manual_artifacts/lido_upgrade_refs.txt`

## Notes

- Additional unguarded `reinitializer(...)` entrypoints exist in `ScrollChain.initializeV2`, `L1MessageQueueV1WithGasPriceOracle` (deprecated), and Lido gateway contracts. These were triaged in this pass; no second path was promoted above the evidence threshold.

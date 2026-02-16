# optimism

- Source: `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\optimism`
- HEAD: `6c24c04393a5b22ddde1c03e99958e1ad5b4f8d1`
- origin: `https://github.com/ethereum-optimism/optimism`
- Stacks: `go`, `node`, `rust`, `solidity`

## Manual Verdict

- `CONFIRMED`: 1
- `LIKELY`: 0
- `NOT CONFIRMED`: privileged trust-model and governance concentration leads without unprivileged exploit witness

## Proven Findings

## F-OPT-01: ProtocolVersions initializer can be first-called to seize owner rights in non-atomic upgrade flow

Severity: `High`

Status: `CONFIRMED`

Affected code:
- `workdir/optimism_contracts-bedrock/src/L1/ProtocolVersions.sol:16` - `@custom:proxied true`
- `workdir/optimism_contracts-bedrock/src/L1/ProtocolVersions.sol:49` - implementation constructor calls `_disableInitializers()`
- `workdir/optimism_contracts-bedrock/src/L1/ProtocolVersions.sol:56` - `initialize(...)` is external and lacks caller authorization guard
- `workdir/optimism_contracts-bedrock/src/L1/ProtocolVersions.sol:58` - initializer sets owner from caller-provided `_owner`
- `workdir/optimism_contracts-bedrock/src/L1/ProtocolVersions.sol:71` - owner-controlled `setRequired(...)`
- `workdir/optimism_contracts-bedrock/src/L1/ProtocolVersions.sol:92` - owner-controlled `setRecommended(...)`

Root cause:
- Initialization authority is implicit (first caller) instead of explicitly constrained to proxy admin / trusted deployer at contract level.

Witness sequence:
1. Proxy is upgraded to `ProtocolVersions` implementation.
2. Before legitimate initializer transaction, attacker calls `initialize(attacker, required, recommended)`.
3. Attacker becomes owner and can mutate required/recommended protocol versions.
4. Legitimate initializer is locked out because initializer state is consumed.

Impact:
- Governance-critical protocol version controls can be captured by unintended actor during exposed initialization windows.
- Attacker-controlled version signaling can disrupt operator/client behavior that relies on required/recommended version channels.

Deterministic witness:
- Harness: `proof_harness/cat2_optimism_f1_protocol_versions_init_hijack/src/OptimismF1ProtocolVersionsInitHijackHarness.sol`
- Test: `proof_harness/cat2_optimism_f1_protocol_versions_init_hijack/test/OptimismF1ProtocolVersionsInitHijack.t.sol`
- Run: `forge test --match-path test/OptimismF1ProtocolVersionsInitHijack.t.sol`
- Artifact: `reports/cat2_rollups/optimism/manual_artifacts/f_opt_01_protocol_versions_init_hijack_forge_test.txt`
- Result: 3/3 exploit-path tests passed (ownership capture, post-capture mutation, legitimate-owner lockout).

Specialist fuzz witness:
- Medusa harness: `proof_harness/cat2_optimism_f1_protocol_versions_init_hijack/src/MedusaOptimismF1ProtocolVersionsInitHijackHarness.sol`
- Medusa run: `medusa.exe fuzz --compilation-target . --target-contracts MedusaOptimismF1ProtocolVersionsInitHijackHarness --seq-len 8 --workers 4 --timeout 30 --fail-fast --no-color --log-level info`
- Medusa artifact: `reports/cat2_rollups/optimism/manual_artifacts/f_opt_01_medusa_failfast_30s.txt`
- Medusa counterexample (minimized): `action_attacker_initialize()` falsifies `property_non_admin_cannot_take_protocol_owner()`.
- Echidna harness: `proof_harness/cat2_optimism_f1_protocol_versions_init_hijack/src/EchidnaOptimismF1ProtocolVersionsInitHijackHarness.sol`
- Echidna run: `echidna.exe src\EchidnaOptimismF1ProtocolVersionsInitHijackHarness.sol --contract EchidnaOptimismF1ProtocolVersionsInitHijackHarness --test-mode property --seq-len 10 --test-limit 20000 --timeout 30 --format text --corpus-dir echidna-corpus-f-opt-01`
- Echidna artifact: `reports/cat2_rollups/optimism/manual_artifacts/f_opt_01_echidna_30s.txt`
- Echidna counterexample (minimized): `action_attacker_initialize()` falsifies `echidna_non_admin_cannot_take_protocol_owner()`.
- Halmos harness: `proof_harness/cat2_optimism_f1_protocol_versions_init_hijack/test/HalmosOptimismF1ProtocolVersionsInitHijack.t.sol`
- Halmos run: `halmos --contract HalmosOptimismF1ProtocolVersionsInitHijack --early-exit --print-failed-states --json-output reports/cat2_rollups/optimism/manual_artifacts/f_opt_01_halmos.json`
- Halmos artifacts:
- `reports/cat2_rollups/optimism/manual_artifacts/f_opt_01_halmos.txt`
- `reports/cat2_rollups/optimism/manual_artifacts/f_opt_01_halmos.json`
- Halmos result: counterexample found for `check_non_admin_cannot_take_protocol_owner()`.

Deployment note:
- The canonical deployment script uses atomic `upgradeAndCall(...)` for `ProtocolVersions` initialization:
- `workdir/optimism_contracts-bedrock/scripts/deploy/DeploySuperchain.s.sol:173`
- This reduces practical risk in that flow, but the contract itself does not enforce caller-level authorization on `initialize(...)`.

## Tool Outputs (Baseline)

- `gitleaks`: `artifacts/gitleaks.json` (exit=124, findings=0)
- `osv-scanner`: `artifacts/osv.json` (exit=124, vulns=1008)
- `govulncheck(json)`: `artifacts/govulncheck.json` (exit=1)
- `govulncheck(text)`: `artifacts/govulncheck.txt` (exit=1, includes traces)
- `gosec`: `artifacts/gosec.json` (exit=1)
- `npm audit`: `artifacts/npm-audit_kona_docs_package-lock.json.json` (lockfile=`kona/docs/package-lock.json`, exit=1)
- `npm audit summary`: `vuln_count=0`
- `cargo-audit summary`: `vuln_count=12`

## Notes

- Privileged design-risk items from `manual_audit_intermediary.md` remain important but are tracked separately from unprivileged exploit witnesses.

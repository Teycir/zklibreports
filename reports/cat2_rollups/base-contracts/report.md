# base-contracts

> Exhaustion status: closed at commit `f87cacbfbba6d11dc29e11c60d8956610011edcc`. See `reports/cat2_rollups/base-contracts/manual_audit.md` and `reports/cat2_rollups/base-contracts/EXHAUSTION_ADDENDUM.md`.

- Source: `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\base-contracts`
- HEAD: `f87cacbfbba6d11dc29e11c60d8956610011edcc`
- origin: `https://github.com/base-org/contracts`
- Stacks: `go`, `solidity`

## Manual Verdict

- `CONFIRMED`: 1
- `LIKELY`: 0
- `NOT CONFIRMED`: scanner-only dependency/secrets leads without exploit witness

## Proven Findings

## F-BASE-01: BalanceTracker initializer can be hijacked in proxy upgrade window to redirect fee flow

Severity: `High`

Status: `CONFIRMED`

Affected code:
- `tmp/base-contracts/src/revenue-share/BalanceTracker.sol:74` - implementation constructor calls `_disableInitializers()`
- `tmp/base-contracts/src/revenue-share/BalanceTracker.sol:91` - `initialize(...)` is `external`
- `tmp/base-contracts/src/revenue-share/BalanceTracker.sol:93` - `reinitializer(2)` gating without caller authorization
- `tmp/base-contracts/src/revenue-share/BalanceTracker.sol:113` - caller-controlled `systemAddresses` persisted
- `tmp/base-contracts/src/revenue-share/BalanceTracker.sol:120` - public `processFees()`
- `tmp/base-contracts/src/revenue-share/BalanceTracker.sol:125` - funds routed to configured `systemAddresses`
- `tmp/base-contracts/src/revenue-share/BalanceTracker.sol:133` - only residual balance sent to `PROFIT_WALLET`
- `tmp/base-contracts/test/revenue-share/BalanceTracker.t.sol:41` - proxy upgrade occurs before initialization in test flow

Root cause:
- The upgradeable initializer is open to any first caller. If proxy upgrade and initialize are not atomic, an attacker can initialize first and set fee-routing recipients.

Witness sequence:
1. Admin upgrades proxy to `BalanceTracker` implementation.
2. Before legitimate initializer call, attacker invokes `initialize([attacker], [MAX_UINT])`.
3. Fees accumulate in proxy balance.
4. `processFees()` routes available balance to attacker-controlled system address; profit wallet receives nothing.
5. Legitimate initializer is locked out because reinitializer version is consumed.

Impact:
- Direct financial diversion of routed ETH fees during the exposed window.
- Persistent misconfiguration until governance/admin intervention via upgrade.
- Revenue routing can be captured by first external caller, not intended operator.

Deterministic witness:
- Harness: `proof_harness/cat2_base_f1_initializer_hijack/src/BaseF1InitializerHijackHarness.sol`
- Test: `proof_harness/cat2_base_f1_initializer_hijack/test/BaseF1InitializerHijack.t.sol`
- Run: `forge test --match-path test/BaseF1InitializerHijack.t.sol`
- Artifact: `reports/cat2_rollups/base-contracts/manual_artifacts/f_base_01_initializer_hijack_forge_test.txt`
- Result: 2/2 tests passed (`attacker capture` and `admin lockout` witness paths).

Specialist fuzz witness:
- Medusa harness: `proof_harness/cat2_base_f1_initializer_hijack/src/MedusaBaseF1InitializerHijackHarness.sol`
- Medusa run: `medusa.exe fuzz --compilation-target . --target-contracts MedusaBaseF1InitializerHijackHarness --seq-len 8 --workers 4 --timeout 30 --fail-fast --no-color --log-level info`
- Medusa artifact: `reports/cat2_rollups/base-contracts/manual_artifacts/f_base_01_medusa_failfast_30s.txt`
- Medusa counterexample (minimized): `action_attacker_initialize()` falsifies `property_non_admin_cannot_take_first_system_address()`.
- Echidna harness: `proof_harness/cat2_base_f1_initializer_hijack/src/EchidnaBaseF1InitializerHijackHarness.sol`
- Echidna run: `echidna.exe src\EchidnaBaseF1InitializerHijackHarness.sol --contract EchidnaBaseF1InitializerHijackHarness --test-mode property --seq-len 10 --test-limit 20000 --timeout 30 --format text --corpus-dir echidna-corpus-f-base-01`
- Echidna artifact: `reports/cat2_rollups/base-contracts/manual_artifacts/f_base_01_echidna_30s.txt`
- Echidna counterexample (minimized): `action_attacker_initialize()` falsifies `echidna_non_admin_cannot_take_first_system_address()`.
- Halmos harness: `proof_harness/cat2_base_f1_initializer_hijack/test/HalmosBaseF1InitializerHijack.t.sol`
- Halmos run: `halmos --contract HalmosBaseF1InitializerHijack --early-exit --print-failed-states --json-output reports/cat2_rollups/base-contracts/manual_artifacts/f_base_01_halmos.json`
- Halmos artifacts:
- `reports/cat2_rollups/base-contracts/manual_artifacts/f_base_01_halmos.txt`
- `reports/cat2_rollups/base-contracts/manual_artifacts/f_base_01_halmos.json`
- Halmos result: counterexample found for `check_non_admin_cannot_hijack_initialize()`.

## Tool Outputs (Baseline)

- `gitleaks`: `artifacts/gitleaks.json` (exit=0, findings=0)
- `osv-scanner`: `artifacts/osv.json` (exit=1, vulns=32)
- `govulncheck(json)`: `artifacts/govulncheck.json` (exit=1)
- `govulncheck(text)`: `artifacts/govulncheck.txt` (exit=1, includes traces)
- `gosec`: `artifacts/gosec.json` (exit=1)

## Notes

- Baseline scanner counts remain triage-only unless tied to exploitability/reachability witnesses.

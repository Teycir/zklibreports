# mantle

> Exhaustion status: closed at commit `5cda5f811f73d9f331e6168617f87d3e19e6db6b`. See `reports/cat2_rollups/mantle/manual_audit.md` and `reports/cat2_rollups/mantle/EXHAUSTION_ADDENDUM.md`.

- Source: `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\mantle`
- HEAD: `5cda5f811f73d9f331e6168617f87d3e19e6db6b`
- origin: `https://github.com/mantlenetworkio/mantle`
- Stacks: `go`, `node`, `solidity`

## Manual Verdict

- `CONFIRMED`: 4
- `LIKELY`: 0
- `NOT CONFIRMED`: scanner-only dependency/secrets leads without exploit witness

## Proven Findings

## F-MAN-01: Defender can rewrite a challenger win during challenge settlement

Severity: `Critical`

Affected code:
- `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\mantle\packages\contracts\contracts\L1\fraud-proof\challenge\Challenge.sol:118` - `onlyDefender`
- `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\mantle\packages\contracts\contracts\L1\fraud-proof\challenge\Challenge.sol:289` - `completeChallenge(bool)`
- `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\mantle\packages\contracts\contracts\L1\fraud-proof\challenge\Challenge.sol:297` - `winner = defender`

Root cause:
- The settlement function accepts defender-controlled boolean input and allows winner reassignment from `challenger` to `defender` after the winner has already been set.

Attacker preconditions:
- Attacker controls the `defender` address in an active challenge.
- Challenge state has already set `winner == challenger`.

Witness sequence:
1. A challenge reaches a state where `winner` is assigned to `challenger` (for example via timeout or one-step proof path).
2. Defender calls `completeChallenge(false)`; function is authorized by `onlyDefender`.
3. The branch at `winner == challenger` executes, then `winner = defender` is assigned.
4. Callback executes `IRollup(resultReceiver).completeChallenge(defender, challenger)`, reversing the recorded winner.

Impact:
- Challenge outcome integrity is broken: a losing defender can convert a challenger victory into a defender victory.
- Fraud-proof security assumptions can be invalidated by a single privileged actor in the challenge.

Deterministic witness:
- Type: source-level transaction trace witness.
- Artifact: `reports/cat2_rollups/mantle/manual_audit_intermediary.md`

Specialist fuzz witness:
- Echidna harness: `proof_harness/cat2_mantle_f3_operator_gate/src/EchidnaMantleHarnesses.sol` (`EchidnaF1WinnerFlipHarness`)
- Echidna run: `C:\echidna\echidna.exe src\EchidnaMantleHarnesses.sol --contract EchidnaF1WinnerFlipHarness --test-mode property --seq-len 10 --test-limit 20000 --timeout 30 --format text --corpus-dir echidna-corpus-f-man-01`
- Echidna artifact: `reports/cat2_rollups/mantle/manual_artifacts/f_man_01_echidna_30s.txt`
- Echidna counterexample (minimized): `action_defender_settles_false()` falsifies `echidna_challenger_win_cannot_be_rewritten()`.
- Halmos harness: `proof_harness/cat2_mantle_f3_operator_gate/test/HalmosF1WinnerFlip.t.sol`
- Halmos run: `halmos --contract HalmosF1WinnerFlip --early-exit --print-failed-states --json-output reports/cat2_rollups/mantle/manual_artifacts/f_man_01_halmos.json`
- Halmos artifact: `reports/cat2_rollups/mantle/manual_artifacts/f_man_01_halmos.txt`
- Halmos counterexample model: `defenderResult = false` (`0x00`) falsifies `check_challenger_win_cannot_be_rewritten(bool)`.

## F-MAN-02: Assertions are auto-confirmed in the same transaction as creation

Severity: `High`

Affected code:
- `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\mantle\packages\contracts\contracts\L1\fraud-proof\Rollup.sol:264` - `createAssertion`
- `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\mantle\packages\contracts\contracts\L1\fraud-proof\Rollup.sol:287` - `lastResolvedAssertionID++`
- `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\mantle\packages\contracts\contracts\L1\fraud-proof\Rollup.sol:288` - `lastConfirmedAssertionID = lastResolvedAssertionID`
- `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\mantle\packages\contracts\contracts\L1\fraud-proof\Rollup.sol:289` - `emit AssertionConfirmed(...)`

Root cause:
- `createAssertion` performs immediate state progression to confirmed status instead of leaving the new assertion unresolved for challenge settlement.

Attacker preconditions:
- Caller is a registered operator (`operatorOnly`).

Witness sequence:
1. Operator calls `createAssertion(vmHash, inboxSize)`.
2. Function appends the assertion and advances stake to it.
3. Same function increments `lastResolvedAssertionID` and sets `lastConfirmedAssertionID` immediately.
4. Assertion becomes confirmed in the creation transaction, removing practical dispute delay at this stage.

Impact:
- Challenge window semantics are effectively bypassed for newly created assertions in this flow.
- Security model collapses toward trusted-operator behavior for assertion finality.

Deterministic witness:
- Type: source-level transaction trace witness.
- Artifact: `reports/cat2_rollups/mantle/manual_audit_intermediary.md`

## F-MAN-03: Challenge completion path requires non-default operator registration of challenge contract

Severity: `High`

Status: `CONFIRMED`

Evidence:
- `Rollup.completeChallenge` is `operatorOnly` and also requires `msg.sender == challenge`:
- `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\mantle\packages\contracts\contracts\L1\fraud-proof\Rollup.sol:82`
- `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\mantle\packages\contracts\contracts\L1\fraud-proof\Rollup.sol:497`
- `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\mantle\packages\contracts\contracts\L1\fraud-proof\Rollup.sol:503`

Root cause:
- Rollup challenge completion requires caller to be both a registered operator and exactly the active challenge contract address, creating a hidden registration dependency.

Witness sequence:
1. Register defender/challenger operators and pair both stakers to the active challenge.
2. Trigger challenge callback path from `Challenge.completeChallenge(...)`.
3. Callback into `Rollup.completeChallenge(...)` reverts with `NotOperator` when challenge contract is not in operator registry.
4. Re-run with explicit synthetic registration of the challenge address as an operator; callback succeeds.

Impact:
- Settlement path can deadlock unless governance/operator tooling performs additional non-obvious operator registration for challenge contracts.
- Staked funds and dispute progression can remain blocked in default-looking configurations.

Deterministic witness:
- Harness: `proof_harness/cat2_mantle_f3_operator_gate/src/MantleF3Harness.sol`
- Test: `proof_harness/cat2_mantle_f3_operator_gate/test/MantleF3OperatorGate.t.sol`
- Run: `C:\Users\vboxuser\.foundry\versions\stable\forge.exe test -vv`
- Artifact: `reports/cat2_rollups/mantle/manual_artifacts/f_man_03_operator_gate_forge_test.txt`

Specialist fuzz witness:
- Medusa harness: `proof_harness/cat2_mantle_f3_operator_gate/src/MedusaF3OperatorGateHarness.sol`
- Medusa run: `C:\Users\vboxuser\go\bin\medusa.exe fuzz --compilation-target . --target-contracts MedusaF3OperatorGateHarness --seq-len 8 --workers 4 --timeout 30 --fail-fast --no-color --log-level info`
- Medusa artifact: `reports/cat2_rollups/mantle/manual_artifacts/f_man_03_medusa_failfast_30s.txt`
- Medusa counterexample (minimized): `action_setup()` -> `action_attempt_settlement(true)` -> property falsified with `RollupOperatorGateHarness.completeChallenge` reverting `NotOperator`.
- Echidna harness: `proof_harness/cat2_mantle_f3_operator_gate/src/EchidnaMantleHarnesses.sol` (`EchidnaF3OperatorGateHarness`)
- Echidna run: `C:\echidna\echidna.exe src\EchidnaMantleHarnesses.sol --contract EchidnaF3OperatorGateHarness --test-mode property --seq-len 10 --test-limit 20000 --timeout 30 --format text --corpus-dir echidna-corpus-f-man-03`
- Echidna artifact: `reports/cat2_rollups/mantle/manual_artifacts/f_man_03_echidna_30s.txt`
- Echidna counterexample (minimized): `action_attempt_settlement(false)` falsifies `echidna_settlement_progresses_without_hidden_registration()`.
- Halmos harness: `proof_harness/cat2_mantle_f3_operator_gate/test/HalmosF3OperatorGate.t.sol`
- Halmos run: `halmos --contract HalmosF3OperatorGate --early-exit --print-failed-states --json-output reports/cat2_rollups/mantle/manual_artifacts/f_man_03_halmos.json`
- Halmos artifact: `reports/cat2_rollups/mantle/manual_artifacts/f_man_03_halmos.txt`
- Halmos counterexample model: `defenderResult = true` (`0x01`) falsifies `check_settlement_progresses_without_hidden_registration(bool)`.

## F-MAN-04: Challenge creation does not bind selected players to the challenged assertion IDs

Severity: `High`

Status: `CONFIRMED`

Affected code:
- `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\mantle\packages\contracts\contracts\L1\fraud-proof\Rollup.sol:318` - attacker-supplied `assertionIDs`
- `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\mantle\packages\contracts\contracts\L1\fraud-proof\Rollup.sol:339` - `defenderStaker = registers[defender]`
- `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\mantle\packages\contracts\contracts\L1\fraud-proof\Rollup.sol:340` - `challengerStaker = registers[challenger]`
- `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\mantle\packages\contracts\contracts\L1\fraud-proof\Rollup.sol:349` - staker challenge assignment
- `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\mantle\packages\contracts\contracts\L1\fraud-proof\Rollup.sol:497` - settlement entrypoint
- `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\mantle\packages\contracts\contracts\L1\fraud-proof\Rollup.sol:523` - loser staker deletion/slash path

Root cause:
- `challengeAssertion` validates structural properties of `assertionIDs` but never enforces that `defender`/`challenger` stakers are actually staked on those assertion IDs.

Witness sequence:
1. Victim and attacker are valid stakers/operators but currently staked on unrelated assertions.
2. Attacker opens challenge with victim as defender and attacker as challenger while supplying different sibling `assertionIDs`.
3. Contract accepts and forcibly sets victim `currentChallenge` to active challenge address.
4. If challenge address is operator-registered (the required `F-MAN-03` workaround), settlement can slash/delete victim staker despite victim not being on the supplied defender assertion.

Impact:
- Immediate liveness/griefing: unrelated victim staker can be forced into challenge and blocked from normal progression.
- Financial impact under enabled settlement path: unrelated victim stake can be slashed.

Deterministic witness:
- Harness: `proof_harness/cat2_mantle_f4_challenge_binding/src/MantleF4ChallengeBindingHarness.sol`
- Test: `proof_harness/cat2_mantle_f4_challenge_binding/test/MantleF4ChallengeBinding.t.sol`
- Run: `C:\Users\vboxuser\.foundry\versions\stable\forge.exe test -vv`
- Artifact: `reports/cat2_rollups/mantle/manual_artifacts/f_man_04_challenge_binding_forge_test.txt`

Specialist fuzz witness:
- Medusa harness: `proof_harness/cat2_mantle_f4_challenge_binding/src/MedusaF4ChallengeBindingHarness.sol`
- Medusa run: `C:\Users\vboxuser\go\bin\medusa.exe fuzz --compilation-target . --target-contracts MedusaF4ChallengeBindingHarness --seq-len 8 --workers 4 --timeout 30 --fail-fast --no-color --log-level info`
- Medusa artifact: `reports/cat2_rollups/mantle/manual_artifacts/f_man_04_medusa_failfast_30s.txt`
- Medusa counterexample (minimized): `action_open_mismatched_challenge()` falsifies `property_victim_not_forced_into_unrelated_challenge()`.
- Echidna harness: `proof_harness/cat2_mantle_f4_challenge_binding/src/EchidnaF4ChallengeBindingHarness.sol`
- Echidna run: `C:\echidna\echidna.exe src\EchidnaF4ChallengeBindingHarness.sol --contract EchidnaF4ChallengeBindingHarness --test-mode property --seq-len 10 --test-limit 20000 --timeout 30 --format text --corpus-dir echidna-corpus-f-man-04`
- Echidna artifact: `reports/cat2_rollups/mantle/manual_artifacts/f_man_04_echidna_30s.txt`
- Echidna counterexamples (minimized):
- `action_open_mismatched_challenge()` falsifies `echidna_victim_not_forced_into_unrelated_challenge()`.
- `action_open_mismatched_challenge()` -> `action_register_challenge_operator()` -> `action_settle()` falsifies `echidna_victim_not_slashed_by_unrelated_assertions()`.
- Halmos harness: `proof_harness/cat2_mantle_f4_challenge_binding/test/HalmosF4ChallengeBinding.t.sol`
- Halmos run: `halmos --contract HalmosF4ChallengeBinding --early-exit --print-failed-states --json-output reports/cat2_rollups/mantle/manual_artifacts/f_man_04_halmos.json`
- Halmos artifact: `reports/cat2_rollups/mantle/manual_artifacts/f_man_04_halmos.txt`
- Halmos result: counterexample found for `check_victim_cannot_be_forced_into_unrelated_challenge()`.

## Tool Outputs (Baseline)

- `gitleaks`: `artifacts/gitleaks.json` (exit=1, findings=87)
- `osv-scanner`: `artifacts/osv.json` (exit=1, vulns=1567)
- `govulncheck(json)`: `artifacts/govulncheck.json` (exit=1)
- `govulncheck(text)`: `artifacts/govulncheck.txt` (exit=1, includes traces)
- `gosec`: `artifacts/gosec.json` (exit=1)

## Notes

- Baseline scanner counts remain triage-only unless tied to exploitability/reachability witnesses.

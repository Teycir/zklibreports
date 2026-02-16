# mantle Manual Audit

- Repo: `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\mantle`
- Commit: `5cda5f811f73d9f331e6168617f87d3e19e6db6b`
- Date: `2026-02-16`

## Scope

- L1 fraud-proof challenge and rollup settlement flows, with emphasis on challenge integrity, operator gating, assertion lifecycle, and player/assertion binding invariants.

## Confirmed

- `F-MAN-01` (`Critical`): defender can rewrite challenger win in `Challenge.completeChallenge(bool)`.
- `F-MAN-02` (`High`): `Rollup.createAssertion` auto-confirms assertions in the same transaction.
- `F-MAN-03` (`High`): `Rollup.completeChallenge` deadlocks unless challenge address is explicitly operator-registered.
- `F-MAN-04` (`High`): `Rollup.challengeAssertion` does not bind players to supplied assertion IDs, enabling unrelated victim challenge/griefing (and slashing when settlement path is enabled).

Witness artifacts:

- `reports/cat2_rollups/mantle/manual_artifacts/f_man_01_echidna_30s.txt`
- `reports/cat2_rollups/mantle/manual_artifacts/f_man_01_halmos.txt`
- `reports/cat2_rollups/mantle/manual_artifacts/f_man_03_operator_gate_forge_test.txt`
- `reports/cat2_rollups/mantle/manual_artifacts/f_man_03_medusa_failfast_30s.txt`
- `reports/cat2_rollups/mantle/manual_artifacts/f_man_03_echidna_30s.txt`
- `reports/cat2_rollups/mantle/manual_artifacts/f_man_03_halmos.txt`
- `reports/cat2_rollups/mantle/manual_artifacts/f_man_04_challenge_binding_forge_test.txt`
- `reports/cat2_rollups/mantle/manual_artifacts/f_man_04_medusa_failfast_30s.txt`
- `reports/cat2_rollups/mantle/manual_artifacts/f_man_04_echidna_30s.txt`
- `reports/cat2_rollups/mantle/manual_artifacts/f_man_04_halmos.txt`
- `reports/cat2_rollups/mantle/manual_audit_intermediary.md`

## Not Promoted

- Scanner-only dependency/secrets leads without exploit witness.

## Conclusion

- Manual audit confirms four witness-backed vulnerabilities (`F-MAN-01`..`F-MAN-04`) at audited commit.

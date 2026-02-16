# taiko-mono

> Exhaustion status: closed at commit `ce8c3e96c6374564ed338e494bd0ad8a6da5a54b`. See `reports/cat2_rollups/taiko-mono/manual_audit.md` and `reports/cat2_rollups/taiko-mono/EXHAUSTION_ADDENDUM.md`.

- Source: `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\taiko-mono`
- HEAD: `ce8c3e96c6374564ed338e494bd0ad8a6da5a54b`
- origin: `https://github.com/taikoxyz/taiko-mono`
- Stacks: `go`, `node`, `rust`, `solidity`

## Manual Verdict

- `CONFIRMED`: 1
- `LIKELY`: 0
- `NOT CONFIRMED`: baseline and manual leads that did not reach unprivileged exploit witness threshold

## Proven Findings

## F-TAIKOMONO-01: `TrailblazersBadgesS2.getBadge` has inverted existence check (nonexistent token accepted, existing token rejected)

Severity: `Medium`

Status: `CONFIRMED`

Affected code:
- `packages/nfts/contracts/trailblazers-season-2/TrailblazersBadgesS2.sol:169` - `uri(uint256)` uses `if (_tokenId > totalSupply()) revert`, which matches intended existence behavior.
- `packages/nfts/contracts/trailblazers-season-2/TrailblazersBadgesS2.sol:180` - `getBadge(uint256)` uses `if (_tokenId < totalSupply()) revert`, inverting the expected boundary.

Root cause:
- Boundary condition inversion in `getBadge` causes contradictory token existence semantics in the same contract.

Witness sequence:
1. Mint badges `#1` and `#2`.
2. `getBadge(1)` reverts `TOKEN_NOT_MINTED` despite token existing.
3. `getBadge(999)` succeeds and returns zero-initialized struct despite token not existing.

Business implication (non-technical):
- Badge-gating integrators can accept invalid token IDs as if they exist, enabling false eligibility decisions.
- Legitimate users with valid token IDs can be denied by the same endpoint.
- This creates campaign and trust risk for any distribution or rewards flow using this read path as an authority signal.

Deterministic witness:
- Harness: `proof_harness/cat2_taiko_f1_getbadge_boundary/src/TaikoF1GetBadgeBoundaryHarness.sol`
- Test: `proof_harness/cat2_taiko_f1_getbadge_boundary/test/TaikoF1GetBadgeBoundary.t.sol`
- Run: `forge test --root proof_harness/cat2_taiko_f1_getbadge_boundary`
- Artifact: `reports/cat2_rollups/taiko-mono/manual_artifacts/f_taikomono_01_getbadge_boundary_forge_test.txt`
- Result: 2/2 tests passed (both incorrect boundary behaviors witnessed).

Specialist fuzz witness:
- Medusa harness: `proof_harness/cat2_taiko_f1_getbadge_boundary/src/MedusaTaikoF1GetBadgeBoundaryHarness.sol`
- Medusa artifact: `reports/cat2_rollups/taiko-mono/manual_artifacts/f_taikomono_01_medusa_failfast_30s.txt`
- Medusa counterexample: after one mint, `property_unminted_token_must_revert()` fails because `getBadge(totalSupply+1)` returns success.
- Echidna harness: `proof_harness/cat2_taiko_f1_getbadge_boundary/src/EchidnaTaikoF1GetBadgeBoundaryHarness.sol`
- Echidna artifact: `reports/cat2_rollups/taiko-mono/manual_artifacts/f_taikomono_01_echidna_30s.txt`
- Echidna counterexamples: falsified `echidna_unminted_token_must_revert` and `echidna_first_minted_token_must_be_readable`.
- Halmos harness: `proof_harness/cat2_taiko_f1_getbadge_boundary/test/HalmosTaikoF1GetBadgeBoundary.t.sol`
- Halmos artifacts:
- `reports/cat2_rollups/taiko-mono/manual_artifacts/f_taikomono_01_halmos.txt`
- `reports/cat2_rollups/taiko-mono/manual_artifacts/f_taikomono_01_halmos.json`
- Halmos result: counterexamples found for both safety expectations.

Primary source snippets:
- `reports/cat2_rollups/taiko-mono/manual_artifacts/f_taikomono_01_key_snippets.txt`

## Tool Outputs (Baseline)

- `gitleaks`: `artifacts/gitleaks.json` (exit=1, findings=61)
- `osv-scanner`: `artifacts/osv.json` (exit=1, vulns=205)
- `govulncheck(json)`: `artifacts/govulncheck.json` (exit=1)
- `govulncheck(text)`: `artifacts/govulncheck.txt` (exit=1)
- `gosec`: `artifacts/gosec.stdout.log` + `artifacts/gosec.stderr.log` (exit=1)

## Exhaustive Lead Artifacts

- `reports/cat2_rollups/taiko-mono/manual_artifacts/prod_lead_counts.txt`
- `reports/cat2_rollups/taiko-mono/manual_artifacts/exhaustive_map_initializers_reinitializers.txt`
- `reports/cat2_rollups/taiko-mono/manual_artifacts/prod_initialization.txt`
- `reports/cat2_rollups/taiko-mono/manual_artifacts/prod_auth_controls.txt`
- `reports/cat2_rollups/taiko-mono/manual_artifacts/prod_raw_calls.txt`
- `reports/cat2_rollups/taiko-mono/manual_artifacts/prod_signature_paths.txt`
- `reports/cat2_rollups/taiko-mono/manual_artifacts/prod_unchecked.txt`

## Notes

- `taiko-mono` and `taiko-contracts` mirror the same vulnerable source for this path at this commit; parity evidence is recorded in `f_taikomono_01_key_snippets.txt` via file hash comparison.
- Remaining leads were triaged and not promoted without unprivileged exploit witness quality under CAT2 criteria.

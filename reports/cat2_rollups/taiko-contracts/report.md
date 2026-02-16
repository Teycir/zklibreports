# taiko-contracts

> Exhaustion status: closed at commit `ce8c3e96c6374564ed338e494bd0ad8a6da5a54b`. See `reports/cat2_rollups/taiko-contracts/manual_audit.md` and `reports/cat2_rollups/taiko-contracts/EXHAUSTION_ADDENDUM.md`.

- Source: `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\taiko-contracts`
- HEAD: `ce8c3e96c6374564ed338e494bd0ad8a6da5a54b`
- origin: `https://github.com/taikoxyz/taiko-mono`
- Stacks: `go`, `node`, `rust`, `solidity`

## Manual Verdict

- `CONFIRMED`: 1
- `LIKELY`: 0
- `NOT CONFIRMED`: baseline and manual leads that did not reach an unprivileged exploit witness threshold

## Proven Findings

## F-TAIKO-01: `TrailblazersBadgesS2.getBadge` has inverted existence check (nonexistent token accepted, existing token rejected)

Severity: `Medium`

Status: `CONFIRMED`

Affected code:
- `packages/nfts/contracts/trailblazers-season-2/TrailblazersBadgesS2.sol:169` - `uri(uint256)` uses `if (_tokenId > totalSupply()) revert`, which is the expected existence check direction.
- `packages/nfts/contracts/trailblazers-season-2/TrailblazersBadgesS2.sol:180` - `getBadge(uint256)` uses `if (_tokenId < totalSupply()) revert`, inverting the intended boundary.

Root cause:
- A strict inequality was reversed in `getBadge`, so token existence semantics diverge from the rest of the contract and from expected ERC token lookup behavior.

Witness sequence:
1. Mint two badges (token IDs `1`, `2`).
2. Call `getBadge(1)` (a minted token): call reverts with `TOKEN_NOT_MINTED`.
3. Call `getBadge(999)` (nonexistent token): call succeeds and returns a zero-initialized `Badge` struct.

Business implication (non-technical):
- Any integration that treats `getBadge` success as proof that an NFT exists can be fooled by nonexistent token IDs.
- At the same time, legitimate holders of earlier minted IDs can be rejected by the same API.
- This creates real campaign/compliance risk: fraudulent eligibility outcomes and avoidable customer support incidents in badge-gated flows.

Deterministic witness:
- Harness: `proof_harness/cat2_taiko_f1_getbadge_boundary/src/TaikoF1GetBadgeBoundaryHarness.sol`
- Test: `proof_harness/cat2_taiko_f1_getbadge_boundary/test/TaikoF1GetBadgeBoundary.t.sol`
- Run: `forge test --root proof_harness/cat2_taiko_f1_getbadge_boundary`
- Artifact: `reports/cat2_rollups/taiko-contracts/manual_artifacts/f_taiko_01_getbadge_boundary_forge_test.txt`
- Result: 2/2 tests passed (explicit witness of both boundary violations).

Specialist fuzz witness:
- Medusa harness: `proof_harness/cat2_taiko_f1_getbadge_boundary/src/MedusaTaikoF1GetBadgeBoundaryHarness.sol`
- Medusa artifact: `reports/cat2_rollups/taiko-contracts/manual_artifacts/f_taiko_01_medusa_failfast_30s.txt`
- Medusa counterexample: one mint followed by `property_unminted_token_must_revert()` falsification via `getBadge(totalSupply+1)` success.
- Echidna harness: `proof_harness/cat2_taiko_f1_getbadge_boundary/src/EchidnaTaikoF1GetBadgeBoundaryHarness.sol`
- Echidna artifact: `reports/cat2_rollups/taiko-contracts/manual_artifacts/f_taiko_01_echidna_30s.txt`
- Echidna counterexamples: falsified `echidna_unminted_token_must_revert` and `echidna_first_minted_token_must_be_readable`.
- Halmos harness: `proof_harness/cat2_taiko_f1_getbadge_boundary/test/HalmosTaikoF1GetBadgeBoundary.t.sol`
- Halmos artifacts:
- `reports/cat2_rollups/taiko-contracts/manual_artifacts/f_taiko_01_halmos.txt`
- `reports/cat2_rollups/taiko-contracts/manual_artifacts/f_taiko_01_halmos.json`
- Halmos result: counterexamples found for both expected-safety checks.

Primary source snippets:
- `reports/cat2_rollups/taiko-contracts/manual_artifacts/f_taiko_01_key_snippets.txt`

## Tool Outputs (Baseline)

- `gitleaks`: `artifacts/gitleaks.json` (exit=1, findings=61)
- `osv-scanner`: `artifacts/osv.json` (exit=1, vulns=205)
- `govulncheck(json)`: `artifacts/govulncheck.json` (exit=1)
- `govulncheck(text)`: `artifacts/govulncheck.txt` (exit=1)
- `gosec`: `artifacts/gosec.stdout.log` + `artifacts/gosec.stderr.log` (exit=1)

## Exhaustive Lead Artifacts

- `reports/cat2_rollups/taiko-contracts/manual_artifacts/prod_lead_counts.txt`
- `reports/cat2_rollups/taiko-contracts/manual_artifacts/exhaustive_map_initializers_reinitializers.txt`
- `reports/cat2_rollups/taiko-contracts/manual_artifacts/prod_auth_controls.txt`
- `reports/cat2_rollups/taiko-contracts/manual_artifacts/prod_raw_calls.txt`
- `reports/cat2_rollups/taiko-contracts/manual_artifacts/prod_signature_paths.txt`
- `reports/cat2_rollups/taiko-contracts/manual_artifacts/prod_unchecked.txt`

## Notes

- Core protocol deployment scripts reviewed in depth (`packages/protocol/script/**`): proxy initialization paths are predominantly atomic (`ERC1967Proxy` constructor calldata), reducing first-caller init takeover exposure in the reviewed paths.
- Remaining protocol leads were triaged and not promoted due missing unprivileged exploit witness under CAT2 criteria.

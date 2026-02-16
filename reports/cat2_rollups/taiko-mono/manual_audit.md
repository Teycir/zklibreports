# taiko-mono manual audit

Date: `2026-02-16`

## Scope and method

- Source audited: `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\taiko-mono` @ `ce8c3e96c6374564ed338e494bd0ad8a6da5a54b`
- Primary in-scope surfaces:
- `packages/protocol/contracts/**` and `packages/protocol/script/**`
- `packages/nfts/contracts/**` and `packages/nfts/script/**`
- Approach:
- Baseline tool output triage (`gitleaks`, `osv-scanner`, `govulncheck`, `gosec`, `cargo-audit`, `npm-audit`)
- Production-contract lead extraction (initialization/auth/raw-call/assembly/signature/unchecked)
- Manual path validation for privilege and state consistency issues
- Specialist witness generation with forge + medusa + echidna + halmos

## Lead generation artifacts

- `manual_artifacts_all_sol_files.txt` (`sol_files=309`)
- `manual_artifacts/prod_lead_counts.txt`
- `manual_artifacts/exhaustive_map_initializers_reinitializers.txt`
- `manual_artifacts/prod_initialization.txt`
- `manual_artifacts/prod_auth_controls.txt`
- `manual_artifacts/prod_raw_calls.txt`
- `manual_artifacts/prod_signature_paths.txt`
- `manual_artifacts/prod_unchecked.txt`
- `manual_artifacts/prod_assembly.txt`

## Promoted finding

- `F-TAIKOMONO-01` (`Medium`): `TrailblazersBadgesS2.getBadge` inverted token boundary check.
- `F-TAIKOMONO-02` (`Medium`): `EventRegister` deploy/init split enables first-caller role takeover before intended initialization.
- Proof artifacts:
- `manual_artifacts/f_taikomono_01_getbadge_boundary_forge_test.txt`
- `manual_artifacts/f_taikomono_01_medusa_failfast_30s.txt`
- `manual_artifacts/f_taikomono_01_echidna_30s.txt`
- `manual_artifacts/f_taikomono_01_halmos.txt`
- `manual_artifacts/f_taikomono_01_halmos.json`
- `manual_artifacts/f_taikomono_02_eventregister_init_hijack_forge_test.txt`
- `manual_artifacts/f_taikomono_02_key_snippets.txt`

## Non-promoted leads

- Core protocol initialization and upgrade surfaces were reviewed; no additional first-caller takeover or privilege break witness was reproduced beyond `F-TAIKOMONO-02` under CAT2 constraints.
- Remaining static leads did not cross the witness threshold for promotion.

## Manual verdict

- `CONFIRMED`: 2
- `LIKELY`: 0
- `NOT CONFIRMED`: all other triaged leads

# taiko-contracts manual audit

Date: `2026-02-16`

## Scope and method

- Source audited: `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\taiko-contracts` @ `ce8c3e96c6374564ed338e494bd0ad8a6da5a54b`
- Primary in-scope surfaces:
- `packages/protocol/contracts/**` and `packages/protocol/script/**`
- `packages/nfts/contracts/**` and `packages/nfts/script/**`
- Approach:
- Baseline tool output triage (`gitleaks`, `osv-scanner`, `govulncheck`, `gosec`, `cargo-audit`, `npm-audit`)
- Production-contract lead extraction (initialization/auth/raw-call/assembly/signature/unchecked)
- Manual path validation for exploitable privilege boundaries and state transitions
- Specialist witness generation with forge + medusa + echidna + halmos for promotable findings

## Lead generation artifacts

- `manual_artifacts_all_sol_files.txt` (`sol_files=309`)
- `manual_artifacts/prod_lead_counts.txt`
- `manual_artifacts/exhaustive_map_initializers_reinitializers.txt`
- `manual_artifacts/prod_contracts.txt`
- `manual_artifacts/prod_initialization.txt`
- `manual_artifacts/prod_auth_controls.txt`
- `manual_artifacts/prod_raw_calls.txt`
- `manual_artifacts/prod_signature_paths.txt`
- `manual_artifacts/prod_unchecked.txt`
- `manual_artifacts/prod_assembly.txt`

## Promoted finding

- `F-TAIKO-01` (`Medium`): `TrailblazersBadgesS2.getBadge` uses inverted boundary check and breaks token-existence semantics.
- `F-TAIKO-02` (`Medium`): `EventRegister` deploy/init split enables first-caller role takeover before intended initialization.
- Proof artifacts:
- `manual_artifacts/f_taiko_01_getbadge_boundary_forge_test.txt`
- `manual_artifacts/f_taiko_01_medusa_failfast_30s.txt`
- `manual_artifacts/f_taiko_01_echidna_30s.txt`
- `manual_artifacts/f_taiko_01_halmos.txt`
- `manual_artifacts/f_taiko_01_halmos.json`
- `manual_artifacts/f_taiko_02_eventregister_init_hijack_forge_test.txt`
- `manual_artifacts/f_taiko_02_key_snippets.txt`

## Non-promoted leads

- Core protocol `initializer/reinitializer` paths in deployment scripts were reviewed against real deployment flows; reviewed paths were mostly atomic proxy init call-data and did not yield a first-caller takeover witness beyond `F-TAIKO-02`.
- Remaining static leads (auth/call/assembly/signature/unchecked) did not produce a reproducible unprivileged exploit witness under CAT2 promotion criteria.

## Manual verdict

- `CONFIRMED`: 2
- `LIKELY`: 0
- `NOT CONFIRMED`: all other triaged leads

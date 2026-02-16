# arbitrum

> Exhaustion status: closed at commit `ba665e9a1fa061058ca04997a6176f25a29bf7d9`. See `reports/cat2_rollups/arbitrum/manual_audit.md` and `reports/cat2_rollups/arbitrum/EXHAUSTION_ADDENDUM.md`.

- Source: `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\arbitrum`
- HEAD: `ba665e9a1fa061058ca04997a6176f25a29bf7d9`
- origin: `https://github.com/OffchainLabs/arbitrum`

## Manual Verdict

- `CONFIRMED`: 0
- `LIKELY`: 0
- `NOT CONFIRMED`: 1 (`index repository only, no in-repo protocol code`)

## Reasoning Summary

- Repository contains only `README.md` at audited commit and functions as an index to other Arbitrum repositories.
- No Solidity/Rust/Go in-repo implementation attack surface exists here for Cat2 exploit promotion.
- Baseline scanners also report no dependency/secret findings (`gitleaks=0`, `osv=0`).

## Tool Outputs (Baseline)

- `gitleaks`: `artifacts/gitleaks.json` (exit=0, findings=0)
- `osv-scanner`: `artifacts/osv.json` (exit=0, vulns=0)

## Exhaustive Lead Artifacts

- `reports/cat2_rollups/arbitrum/manual_artifacts/lead_counts.txt`
- `reports/cat2_rollups/arbitrum/manual_artifacts/f_arbitrum_00_repo_scope_snippets.txt`

## Notes

- The README points to external repositories (`nitro`, `nitro-contracts`) where actual rollup code lives; those are separate audit targets.

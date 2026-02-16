# stone-prover

> Exhaustion status: closed at commit `1414a545e4fb38a85391289abe91dd4467d268e1`. See `reports/cat2_rollups/stone-prover/manual_audit.md` and `reports/cat2_rollups/stone-prover/EXHAUSTION_ADDENDUM.md`.

- Source: `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\stone-prover`
- HEAD: `1414a545e4fb38a85391289abe91dd4467d268e1`
- origin: `https://github.com/starkware-libs/stone-prover`

## Manual Verdict

- `CONFIRMED`: 0
- `LIKELY`: 0
- `NOT CONFIRMED`: 1 (`no Cat2 exploit witness`)

## Reasoning Summary

- Repository is primarily native prover/verifier implementation (`.cc/.h/.inl`) rather than onchain rollup contract logic.
- Baseline scanners reported no direct dependency or secret findings (`gitleaks=0`, `osv=0`).
- Manual lead sweeps (unsafe memory, deserialization, file I/O, syscall/network/randomness) produced no concrete exploit chain matching Cat2 criteria.
- No externally exposed transaction/state control path analogous to proxy initialization or onchain authorization bypass was identified in-repo.

## Tool Outputs (Baseline)

- `gitleaks`: `artifacts/gitleaks.json` (exit=0, findings=0)
- `osv-scanner`: `artifacts/osv.json` (exit=0, vulns=0)

## Exhaustive Lead Artifacts

- `reports/cat2_rollups/stone-prover/manual_artifacts/lead_counts.txt`
- `reports/cat2_rollups/stone-prover/manual_artifacts/lead_unsafe_mem.txt`
- `reports/cat2_rollups/stone-prover/manual_artifacts/lead_deserialization.txt`
- `reports/cat2_rollups/stone-prover/manual_artifacts/lead_file_io.txt`
- `reports/cat2_rollups/stone-prover/manual_artifacts/lead_randomness.txt`

## Notes

- The README explicitly states verifier scope limits for proof-file public input validation (`README.md`), which is an integration responsibility note rather than a standalone in-repo exploit witness.

# zkevm-contracts Cat2 Exhaustion Addendum

- Commit exhausted: `e468f9b0967334403069aa650d9f1164b1731ebb`
- Date: `2026-02-16`

Result:

- Confirmed vulnerabilities: `1` (`F-ZKEVMC-01`).
- Promoted finding has deterministic witness and manual artifact linkage.
- Remaining leads (dependency/secrets scanners, test/mock-only paths) were not promoted without production-path exploit witness.

Primary evidence:

- `reports/cat2_rollups/zkevm-contracts/report.md`
- `reports/cat2_rollups/zkevm-contracts/manual_audit.md`
- `reports/cat2_rollups/zkevm-contracts/manual_artifacts/f_zkevmc_01_agglayer_gateway_init_hijack_forge_test.txt`
- `reports/cat2_rollups/zkevm-contracts/manual_artifacts/f_zkevmc_01_key_snippets.txt`


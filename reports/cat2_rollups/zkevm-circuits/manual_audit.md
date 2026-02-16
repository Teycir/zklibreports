# zkevm-circuits Manual Audit

- Repo: `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\zkevm-circuits`
- Commit: `18f5bc268ca11988690c7cf59fc4615372ce99f2`
- Date: `2026-02-16`

## Scope

- Production Rust crates in this repository, with emphasis on:
- prover task ingestion and sanity paths
- blob decoding and batch consistency code
- unsafe and panic-prone logic on externally supplied bytes

## Lead Inventory

From `reports/cat2_rollups/zkevm-circuits/manual_artifacts/lead_counts.txt`:

- `rs_files=486`
- `go_files=4`
- `sol_files=3`
- `unsafe_memory=6`
- `deserialization=1283`
- `process_exec=10`
- `file_io=736`
- `crypto_randomness=2825`
- `panics_asserts=3300`
- `networking=885`

## Confirmed

- `F-ZKEVM-01` (`High`): panic-based DoS in `aggregator::decode_bytes` with malformed `blob_bytes`, reachable through batch proving sanity path.

Witness artifacts:

- `reports/cat2_rollups/zkevm-circuits/manual_artifacts/f_zkevm_01_decode_bytes_panic_cargo_test.txt`
- `reports/cat2_rollups/zkevm-circuits/manual_artifacts/f_zkevm_01_key_snippets.txt`
- `proof_harness/cat2_zkevm_circuits_f1_decode_bytes_panic/src/lib.rs`

## Not Promoted

- Dependency scanner output and broad static leads without repository-local exploit witness.
- Test-only or tooling-only code paths without production impact evidence in CAT2 scope.

## Conclusion

- Manual audit is closed for this repository at this commit with one confirmed, deterministic witness-grade vulnerability.

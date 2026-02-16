# era-boojum Manual Audit

- Repo: `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\era-boojum`
- Commit: `5a8c4035a9e10beacb1bf28ec453fe5fb01323ad`
- Date: `2026-02-16`

## Scope

- Rust resolver allocation and memory-safety critical paths (`resolver_box`), including oversized reservation behavior.

## Confirmed

- `F-ERA-01` (`High`): page reservation logic can commit beyond page allocation when oversized reservations are requested, violating allocator safety invariants.

Witness artifacts:

- `reports/cat2_rollups/era-boojum/manual_artifacts/f_era_01_resolver_page_overflow_cargo_test.txt`
- `proof_harness/cat2_era_boojum_f1_resolver_page_overflow/src/lib.rs`

## Not Promoted

- Dependency advisory leads without in-repo exploit-path witness.

## Conclusion

- Manual audit confirms one deterministic, witness-backed vulnerability (`F-ERA-01`) at audited commit.

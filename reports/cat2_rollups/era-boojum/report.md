# era-boojum

- Source: `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\era-boojum`
- HEAD: `5a8c4035a9e10beacb1bf28ec453fe5fb01323ad`
- origin: `https://github.com/matter-labs/era-boojum`
- Stacks: `rust`

## Manual Verdict

- `CONFIRMED`: 1
- `LIKELY`: 0
- `NOT CONFIRMED`: dependency advisory leads without in-repo exploit path witness

## Proven Findings

## F-ERA-01: Resolver page allocator allows oversized reservation beyond page bounds (memory safety risk)

Severity: `High`

Status: `CONFIRMED`

Affected code:
- `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\era-boojum\src\dag\resolver_box.rs:69` - caller reserves `ctor.size()` bytes from container
- `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\era-boojum\src\dag\resolver_box.rs:132` - safety comment assumes new page is always large enough
- `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\era-boojum\src\dag\resolver_box.rs:143` - calls `page.reserve(size)` after possible page rollover
- `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\era-boojum\src\dag\resolver_box.rs:193` - `commited += size` without explicit bounds check
- `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\era-boojum\src\dag\resolver_box.rs:275` - caller writes resolver payload into reserved region

Root cause:
- The allocator checks whether the current page fits `size`, but when it rolls to a fresh page it does not enforce `size <= page_size` before committing bytes. This can produce `commited > allocation.len()` and break write-safety assumptions.

Witness sequence:
1. Container is configured with fixed page size `P`.
2. Reservation request arrives with `size > P`.
3. Current page does not fit, so allocator rolls to a new page of size `P`.
4. New page reservation is performed without validating `size <= P`, and `commited` exceeds allocation length.
5. Subsequent resolver writes rely on this reservation and can exceed page allocation bounds.

Impact:
- Memory-safety invariant break in allocator bookkeeping.
- Potential out-of-bounds writes / undefined behavior on oversized resolver reservations.
- Practical outcomes include crashes, corrupted state, or incorrect proving behavior under oversized inputs.

Deterministic witness:
- Harness: `proof_harness/cat2_era_boojum_f1_resolver_page_overflow/src/lib.rs`
- Run: `cargo test --quiet`
- Artifact: `reports/cat2_rollups/era-boojum/manual_artifacts/f_era_01_resolver_page_overflow_cargo_test.txt`
- Result: `oversized_reservation_breaks_page_commit_invariant` passes, proving `commited > allocation.len()` is reachable.

## Tool Outputs (Baseline)

- `gitleaks`: `artifacts/gitleaks.json` (exit=0, findings=0)
- `osv-scanner`: `artifacts/osv.json` (exit=1, vulns=5)
- `cargo-audit`: `artifacts/cargo-audit_profiling-target_Cargo.lock.json` (exit=1)
- `cargo-audit summary`: `vuln_count=1`

## Notes

- `RUSTSEC-2026-0007` (`bytes`) currently appears in `profiling-target/Cargo.lock`; this remains dependency-triage only unless an in-repo reachable path is demonstrated.

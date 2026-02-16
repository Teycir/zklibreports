# zkevm-circuits

> Exhaustion status: closed at commit `18f5bc268ca11988690c7cf59fc4615372ce99f2`. See `reports/cat2_rollups/zkevm-circuits/manual_audit.md` and `reports/cat2_rollups/zkevm-circuits/EXHAUSTION_ADDENDUM.md`.

- Source: `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\zkevm-circuits`
- HEAD: `18f5bc268ca11988690c7cf59fc4615372ce99f2`
- origin: `https://github.com/scroll-tech/zkevm-circuits`
- Stacks: `go`, `rust`, `solidity`

## Manual Verdict

- `CONFIRMED`: 2
- `LIKELY`: 0
- `NOT CONFIRMED`: scanner-only dependency/secrets leads and non-production/test-only paths without exploit witness

## Proven Findings

## F-ZKEVM-01: `decode_bytes` panics on malformed blob bytes, crashing batch proving sanity path

Severity: `High`

Status: `CONFIRMED`

Affected code:
- `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\zkevm-circuits\aggregator\src\aggregation\decoder.rs:5443` - `decode_bytes(bytes: &[u8]) -> Result<Vec<u8>>`
- `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\zkevm-circuits\aggregator\src\aggregation\decoder.rs:5444` - direct `bytes[0]` access (empty input panic)
- `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\zkevm-circuits\aggregator\src\aggregation\decoder.rs:5467` - unchecked `encoded_len -= 1` (underflow panic)
- `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\zkevm-circuits\prover\src\aggregator\prover.rs:352` - caller expects recoverable `Result` via `map_err(...)`, but panic bypasses error handling

Root cause:
- `decode_bytes` returns `Result` but uses panic-prone operations on malformed input (`bytes[0]` and unchecked decrement), violating the function's recoverable-error contract.

Attacker preconditions:
- Attacker can inject malformed `blob_bytes` into the proving task ingestion path (for example via compromised/abused upstream task producer, queue, or bridge between services).

Witness sequence:
1. Call `decode_bytes(&[])`.
2. Function panics at `bytes[0]` with index-out-of-bounds.
3. Call `decode_bytes(&[1])`.
4. Function enters encoded branch with zero payload and panics at `encoded_len -= 1`.
5. In `BatchProver` sanity path, this panic escapes instead of returning `BatchProverError`, terminating the worker path.

Business implication (non-technical):
- A single malformed proving task can crash batch proving workers instead of being rejected cleanly.
- Repeated malformed tasks can keep proving capacity unstable or offline, delaying proof production and downstream finality/withdrawal operations.
- This creates service reliability risk and operational incident risk for rollup operations.

Deterministic witness:
- Harness: `proof_harness/cat2_zkevm_circuits_f1_decode_bytes_panic/src/lib.rs`
- Run: `RUSTC_BOOTSTRAP=1 cargo test -- --nocapture`
- Artifact: `reports/cat2_rollups/zkevm-circuits/manual_artifacts/f_zkevm_01_decode_bytes_panic_cargo_test.txt`
- Result: panic traces from upstream source lines for both malformed inputs (`decoder.rs:5444` and `decoder.rs:5467`) with harness tests passing via `catch_unwind` witness assertions.

Primary source snippets:
- `reports/cat2_rollups/zkevm-circuits/manual_artifacts/f_zkevm_01_key_snippets.txt`

## F-ZKEVM-02: Empty batch/bundle proving tasks panic in identifier path before validation

Severity: `Medium`

Status: `CONFIRMED`

Affected code:
- `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\zkevm-circuits\prover\src\types.rs:82` - `BatchProvingTask::identifier()` calls `.last().unwrap()` on `chunk_proofs`.
- `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\zkevm-circuits\prover\src\types.rs:106` - `BundleProvingTask::identifier()` calls `.last().unwrap()` on `batch_proofs`.
- `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\zkevm-circuits\prover\src\aggregator\prover.rs:135` - `gen_batch_proof(...)` derives `name` via `batch.identifier()` before any batch-content checks.
- `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\zkevm-circuits\prover\src\aggregator\prover.rs:196` - `gen_bundle_proof(...)` derives `name` via `bundle.identifier()` before validation.

Root cause:
- Identifier helpers assume non-empty vectors and use `unwrap()` instead of returning a recoverable error for malformed empty tasks.

Attacker preconditions:
- Ability to submit or inject malformed proving tasks with empty `chunk_proofs` or `batch_proofs` to the prover service interface/queue.

Witness sequence:
1. Build `BatchProvingTask` with `chunk_proofs = []`.
2. Call `gen_batch_proof(..., name=None, ...)` name-derivation path.
3. `batch.identifier()` panics on `.last().unwrap()`.
4. Similarly, `BundleProvingTask` with `batch_proofs = []` panics in `gen_bundle_proof(..., name=None, ...)`.

Business implication (non-technical):
- A malformed empty proving task can crash prover worker execution before the task is cleanly rejected.
- Repeated malformed tasks can cause avoidable worker instability and processing disruption.
- This is an availability and reliability risk in proving orchestration pipelines.

Deterministic witness:
- Harness: `proof_harness/cat2_zkevm_circuits_f2_empty_task_identifier_panic/src/lib.rs`
- Run: `cargo test --manifest-path proof_harness/cat2_zkevm_circuits_f2_empty_task_identifier_panic/Cargo.toml -- --nocapture`
- Artifact: `reports/cat2_rollups/zkevm-circuits/manual_artifacts/f_zkevm_02_empty_task_identifier_panic_cargo_test.txt`
- Result: 3/3 tests passed; two panic traces (`Option::unwrap()` on `None`) observed for empty batch/bundle task paths.

Primary source snippets:
- `reports/cat2_rollups/zkevm-circuits/manual_artifacts/f_zkevm_02_key_snippets.txt`

## Tool Outputs (Baseline)

- `gitleaks`: `artifacts/gitleaks.json` (exit=1, findings=231)
- `osv-scanner`: `artifacts/osv.json` (exit=1, vulns=119)
- `govulncheck(json)`: `artifacts/govulncheck.json` (exit=1)
- `govulncheck(text)`: `artifacts/govulncheck.txt` (exit=1, includes traces)
- `gosec`: `artifacts/gosec.json` (exit=1)
- `cargo-audit`: `artifacts/cargo` (lockfile=`Cargo.lock`, exit=1)
- `cargo-audit summary`: `vuln_count=10`

## Exhaustive Lead Artifacts

- `reports/cat2_rollups/zkevm-circuits/manual_artifacts/lead_counts.txt`
- `reports/cat2_rollups/zkevm-circuits/manual_artifacts/lead_unsafe_memory.txt`
- `reports/cat2_rollups/zkevm-circuits/manual_artifacts/lead_deserialization.txt`
- `reports/cat2_rollups/zkevm-circuits/manual_artifacts/lead_process_exec.txt`
- `reports/cat2_rollups/zkevm-circuits/manual_artifacts/lead_file_io.txt`
- `reports/cat2_rollups/zkevm-circuits/manual_artifacts/lead_crypto_randomness.txt`
- `reports/cat2_rollups/zkevm-circuits/manual_artifacts/lead_panics_asserts.txt`
- `reports/cat2_rollups/zkevm-circuits/manual_artifacts/lead_networking.txt`

## Notes

- Solidity files in this repo are integration-test contracts only; no production contract attack surface was promoted for CAT2 from this repository.
- Remaining Rust/Go leads were reviewed and not promoted without stronger unprivileged exploit witnesses.

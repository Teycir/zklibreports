# zkevm-circuits

> Exhaustion status: closed at commit `18f5bc268ca11988690c7cf59fc4615372ce99f2`. See `reports/cat2_rollups/zkevm-circuits/manual_audit.md` and `reports/cat2_rollups/zkevm-circuits/EXHAUSTION_ADDENDUM.md`.

- Source: `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\zkevm-circuits`
- HEAD: `18f5bc268ca11988690c7cf59fc4615372ce99f2`
- origin: `https://github.com/scroll-tech/zkevm-circuits`
- Stacks: `go`, `rust`, `solidity`

## Manual Verdict

- `CONFIRMED`: 1
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

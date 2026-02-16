# Stone Prover Cat2 Exhaustion Audit (Final)

## Scope Locked

- Repository: `stone-prover`
- Source commit audited: `1414a545e4fb38a85391289abe91dd4467d268e1`
- Audit target classes:
  - native prover/verifier sources under `src/starkware/**`
  - interfaces and utilities that could expose exploitable trust-boundary breaks

## Objective

Determine whether this repository contains a provable Cat2 vulnerability with a reproducible exploit witness.

## Lead Generation and Coverage

Lead outputs generated under:

- `reports/cat2_rollups/stone-prover/manual_artifacts/lead_counts.txt`
- `reports/cat2_rollups/stone-prover/manual_artifacts/lead_unsafe_mem.txt`
- `reports/cat2_rollups/stone-prover/manual_artifacts/lead_asserts.txt`
- `reports/cat2_rollups/stone-prover/manual_artifacts/lead_deserialization.txt`
- `reports/cat2_rollups/stone-prover/manual_artifacts/lead_crypto_verify.txt`
- `reports/cat2_rollups/stone-prover/manual_artifacts/lead_syscalls.txt`
- `reports/cat2_rollups/stone-prover/manual_artifacts/lead_file_io.txt`
- `reports/cat2_rollups/stone-prover/manual_artifacts/lead_network.txt`
- `reports/cat2_rollups/stone-prover/manual_artifacts/lead_randomness.txt`
- `reports/cat2_rollups/stone-prover/manual_artifacts/lead_integer_casts.txt`
- `reports/cat2_rollups/stone-prover/manual_artifacts/lead_todo_fixme.txt`

Observed high-level counts:

- `lead_unsafe_mem=6`
- `lead_deserialization=41`
- `lead_file_io=11`
- `lead_syscalls=1` (false positive text match, no syscall use)
- `lead_network=0`

## Triage Outcome

- Unsafe memory hits were bounded cryptographic/local buffer operations with fixed-size copying and no exploitable user-controlled overflow witness.
- Deserialization/read paths are present for proof/trace/memory files, but no concrete memory corruption or auth-bypass exploit witness was derived from reviewed callsites.
- No in-repo onchain governance/proxy/authorization surface comparable to other Cat2 rollup contract repos was identified.
- README notes verifier public-input semantics as an integration responsibility; this is documented behavior, not a standalone exploit witness.

## Conclusion

- Promoted vulnerabilities: `0`
- Status: `NOT CONFIRMED` for Cat2 at this commit.
- Evidence threshold for a proven exploit path was not met.


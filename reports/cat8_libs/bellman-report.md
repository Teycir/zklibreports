# Custom Vulnerability Report: bellman

## Scope
- Audit time (UTC): 2026-02-15 18:17:00
- Repository path: \\VBOXSVR\elements\Repos\zk0d\cat_8_libs\bellman
- Language profile: Rust
- Git branch: main
- Git commit: 3a1c43b
- Upstream: origin/main
- Upstream delta: behind=0 ahead=0
- Remote: https://github.com/zkcrypto/bellman.git

## Method
- Fast skimmer triage over executable paths (tests/docs excluded from pattern scans).
- Dependency advisory scan when lockfile/tooling was available.
- Phase 2 dependency reachability and dependency-edge validation.
- No issue is marked CONFIRMED unless reproducible witness evidence exists.

## Tooling Results
- cargo-audit: vulnerabilities=0, unmaintained=1, unsound=1, yanked=1
- cargo tree -i atty: `atty -> criterion` under `[dev-dependencies]`

## Classification Summary
- FORMALLY CONFIRMED: 0
- CONFIRMED: 0
- LIKELY: 0
- NOT CONFIRMED (skimmer hints): 239 matches across 1 pattern classes

## Phase 2 Reachability Analysis
- The only `atty` path in lock analysis is attached to benchmark/test stack (`criterion`) under `dev-dependencies`.
- No runtime production dependency path from library functionality to `atty` was evidenced.
- Result: `RUSTSEC-2021-0145` is NOT CONFIRMED for production usage in this repo context.

## Likely Findings
- None in this pass.

## Not Confirmed Notes
- [NOT CONFIRMED] `RUSTSEC-2021-0145` in `atty`: dependency path is dev-only (`criterion`) in this repository.
- [NOT CONFIRMED] `RUSTSEC-2024-0375` in `atty`: unmaintained dependency signal in dev path; no direct exploit witness.

## Skimmer Hints (Not Confirmed)
### panic/unwrap/expect usage
- Match count: 239
- Sample evidence:
```text
\\VBOXSVR\elements\Repos\zk0d\cat_8_libs\bellman\benches\slow.rs:40:                        .unwrap();
\\VBOXSVR\elements\Repos\zk0d\cat_8_libs\bellman\groth16\benches\batch.rs:37:            generate_random_parameters::<Bls12, _, _>(c, &mut rng).unwrap()
\\VBOXSVR\elements\Repos\zk0d\cat_8_libs\bellman\groth16\benches\batch.rs:59:                let proof = create_random_proof(c, &params, &mut rng).unwrap();
```

## Reproduction Commands
- cargo audit --json --file \\VBOXSVR\elements\Repos\zk0d\cat_8_libs\bellman\Cargo.lock
- cargo tree --manifest-path \\VBOXSVR\elements\Repos\zk0d\cat_8_libs\bellman\Cargo.toml --locked -i atty

## External Tool Deep Scan (2026-02-15 20:36 UTC)

### Tooling Results
- gitleaks: 0 findings.
- cargo deny advisories: errors=1 (`unmaintained`), warnings=1 (`yanked`).
- cargo audit: vulnerabilities=0, unmaintained=1, unsound=1, yanked=1.
- Advisory IDs: `RUSTSEC-2024-0375` (`atty` unmaintained), `RUSTSEC-2021-0145` (`atty` unsound on Windows).

### Deep Assessment
- [NOT CONFIRMED] No direct RustSec vulnerability entry was reported in `vulnerabilities.list`; findings are unmaintained/unsound/yanked dependency risks.
- [NOT CONFIRMED] `atty` path is present through `criterion` (dev dependency path in cargo-deny output).

### Artifacts
- `C:\Users\vboxuser\Desktop\Repos\zklibreports\artifacts\cargo-deny\bellman.txt`
- `C:\Users\vboxuser\Desktop\Repos\zklibreports\artifacts\cargo-audit\bellman.json`
- `C:\Users\vboxuser\Desktop\Repos\zklibreports\artifacts\gitleaks\bellman.json`

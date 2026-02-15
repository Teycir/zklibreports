# Custom Vulnerability Report: arkworks-groth16

## Scope
- Audit time (UTC): 2026-02-15 18:09:29
- Repository path: \\VBOXSVR\elements\Repos\zk0d\cat_8_libs\arkworks-groth16
- Language profile: Rust
- Git branch: master
- Git commit: b3b4a15
- Upstream: origin/master
- Upstream delta: behind=0 ahead=0
- Remote: https://github.com/arkworks-rs/groth16.git

## Method
- Fast skimmer triage over executable paths (tests/docs excluded from pattern scans).
- Dependency advisory scan when lockfile/tooling was available.
- No issue is marked CONFIRMED unless reproducible witness evidence exists.

## Tooling Results
- cargo-audit skipped: Cargo.lock not present (library crate)

## Classification Summary
- FORMALLY CONFIRMED: 0
- CONFIRMED: 0
- LIKELY: 0
- NOT CONFIRMED (skimmer hints): 51 matches across 1 pattern classes

## Likely Findings
- None in this pass.

## Not Confirmed Notes
- None in this pass.

## Skimmer Hints (Not Confirmed)
### panic/unwrap/expect usage
- Match count: 51
- Sample evidence:
```text
\\VBOXSVR\elements\Repos\zk0d\cat_8_libs\arkworks-groth16\benches\bench.rs:76:        let (pk, _) = Groth16::<$bench_pairing_engine>::circuit_specific_setup(c, rng).unwrap();
\\VBOXSVR\elements\Repos\zk0d\cat_8_libs\arkworks-groth16\benches\bench.rs:81:            let _ = Groth16::<$bench_pairing_engine>::prove(&pk, c.clone(), rng).unwrap();
\\VBOXSVR\elements\Repos\zk0d\cat_8_libs\arkworks-groth16\benches\bench.rs:107:        let (pk, vk) = Groth16::<$bench_pairing_engine>::circuit_specific_setup(c, rng).unwrap();
\\VBOXSVR\elements\Repos\zk0d\cat_8_libs\arkworks-groth16\benches\bench.rs:108:        let proof = Groth16::<$bench_pairing_engine>::prove(&pk, c.clone(), rng).unwrap();
\\VBOXSVR\elements\Repos\zk0d\cat_8_libs\arkworks-groth16\benches\bench.rs:110:        let v = c.a.unwrap() * c.b.unwrap();
\\VBOXSVR\elements\Repos\zk0d\cat_8_libs\arkworks-groth16\benches\bench.rs:115:            let _ = Groth16::<$bench_pairing_engine>::verify(&vk, &vec![v], &proof).unwrap();
```

## Reproduction Commands
- rg -n -S --hidden --glob !**/.git/** -- <PATTERN> \\VBOXSVR\elements\Repos\zk0d\cat_8_libs\arkworks-groth16

## External Tool Deep Scan (2026-02-15 20:36 UTC)

### Tooling Results
- gitleaks: 0 findings.
- cargo deny advisories: errors=1 (`unmaintained`), warnings=0.
- cargo audit: vulnerabilities=0, unmaintained=1, unsound=0, yanked=0.
- Advisory IDs: `RUSTSEC-2024-0388` (`derivative@2.2.0`).

### Deep Assessment
- [NOT CONFIRMED] `derivative` is flagged as unmaintained; no direct exploitable vulnerability advisory was produced for this repo in this pass.

### Artifacts
- `C:\Users\vboxuser\Desktop\Repos\zklibreports\artifacts\cargo-deny\arkworks-groth16.txt`
- `C:\Users\vboxuser\Desktop\Repos\zklibreports\artifacts\cargo-audit\arkworks-groth16.json`
- `C:\Users\vboxuser\Desktop\Repos\zklibreports\artifacts\gitleaks\arkworks-groth16.json`

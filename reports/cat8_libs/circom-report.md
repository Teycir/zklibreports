# Custom Vulnerability Report: circom

## Scope
- Audit time (UTC): 2026-02-15 18:17:00
- Repository path: \\VBOXSVR\elements\Repos\zk0d\cat_8_libs\circom
- Language profile: Rust
- Git branch: master
- Git commit: 3997b4a
- Upstream: origin/master
- Upstream delta: behind=0 ahead=0
- Remote: https://github.com/iden3/circom.git

## Method
- Fast skimmer triage over executable paths (tests/docs excluded from pattern scans).
- Dependency advisory scan when lockfile/tooling was available.
- Phase 2 dependency reachability and precondition analysis.
- No issue is marked CONFIRMED unless reproducible witness evidence exists.

## Tooling Results
- cargo-audit: vulnerabilities=0, unmaintained=3, unsound=1, yanked=6
- cargo tree -i atty: `atty -> clap -> circom`
- cargo-audit advisory `RUSTSEC-2021-0145` requires Windows plus custom global allocator precondition
- Repository scan for `#[global_allocator]` / `GlobalAlloc`: no matches found

## Classification Summary
- FORMALLY CONFIRMED: 0
- CONFIRMED: 0
- LIKELY: 0
- NOT CONFIRMED (skimmer hints): 691 matches across 1 pattern classes

## Phase 2 Reachability Analysis
- `atty` is reachable in the CLI dependency chain, but the unsound advisory itself states practical trigger requires a custom global allocator on Windows.
- No custom global allocator configuration was found in this repository.
- No reproducible witness was produced that violates a runtime invariant in this target configuration.
- Result: `RUSTSEC-2021-0145` remains NOT CONFIRMED for this repo context.

## Likely Findings
- None in this pass.

## Not Confirmed Notes
- [NOT CONFIRMED] `RUSTSEC-2021-0145` in `atty`: advisory precondition (custom global allocator on Windows) not evidenced in repository configuration.
- [NOT CONFIRMED] `RUSTSEC-2021-0139` in `ansi_term`: unmaintained dependency signal; no direct exploit witness.
- [NOT CONFIRMED] `RUSTSEC-2024-0375` in `atty`: unmaintained dependency signal; no direct exploit witness.
- [NOT CONFIRMED] `RUSTSEC-2022-0081` in `json`: unmaintained dependency signal; no direct exploit witness.

## Skimmer Hints (Not Confirmed)
### panic/unwrap/expect usage
- Match count: 691
- Sample evidence:
```text
\\VBOXSVR\elements\Repos\zk0d\cat_8_libs\circom\circom_algebra\src\simplification_utils.rs:18:        ret = ret && (i.to_i32().unwrap() > prev);
\\VBOXSVR\elements\Repos\zk0d\cat_8_libs\circom\circom_algebra\src\simplification_utils.rs:19:        prev = i.to_i32().unwrap();
\\VBOXSVR\elements\Repos\zk0d\cat_8_libs\circom\circom_algebra\src\simplification_utils.rs:88:                uniques.insert(*k, *signal_to_rep.get(k).unwrap());
```

## Reproduction Commands
- cargo audit --json --file \\VBOXSVR\elements\Repos\zk0d\cat_8_libs\circom\Cargo.lock
- cargo tree --manifest-path \\VBOXSVR\elements\Repos\zk0d\cat_8_libs\circom\Cargo.toml --locked -i atty
- rg -n -S --hidden --glob !**/.git/** '#\\[global_allocator\\]|GlobalAlloc' \\VBOXSVR\elements\Repos\zk0d\cat_8_libs\circom

## External Tool Deep Scan (2026-02-15 20:36 UTC)

### Tooling Results
- gitleaks: 0 findings.
- cargo deny advisories: errors=3 (`unmaintained`), warnings=6 (`yanked`).
- cargo audit: vulnerabilities=0, unmaintained=3, unsound=1, yanked=6.
- Advisory IDs: `RUSTSEC-2021-0139`, `RUSTSEC-2022-0081`, `RUSTSEC-2024-0375`, `RUSTSEC-2021-0145`.

### Deep Assessment
- [NOT CONFIRMED] No direct exploitable vulnerability entry was reported in `vulnerabilities.list`; findings are dependency lifecycle and yanked-version risks.
- [NOT CONFIRMED] Unsound advisory (`atty`) is present but no exploit witness path was produced in this pass.

### Artifacts
- `C:\Users\vboxuser\Desktop\Repos\zklibreports\artifacts\cargo-deny\circom.txt`
- `C:\Users\vboxuser\Desktop\Repos\zklibreports\artifacts\cargo-audit\circom.json`
- `C:\Users\vboxuser\Desktop\Repos\zklibreports\artifacts\gitleaks\circom.json`

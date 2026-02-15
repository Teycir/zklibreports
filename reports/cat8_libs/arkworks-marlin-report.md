# Custom Vulnerability Report: arkworks-marlin

## Scope
- Audit time (UTC): 2026-02-15 18:09:30
- Repository path: \\VBOXSVR\elements\Repos\zk0d\cat_8_libs\arkworks-marlin
- Language profile: Rust
- Git branch: master
- Git commit: 026b73c
- Upstream: origin/master
- Upstream delta: behind=0 ahead=0
- Remote: https://github.com/arkworks-rs/marlin.git

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
- NOT CONFIRMED (skimmer hints): 76 matches across 2 pattern classes

## Likely Findings
- None in this pass.

## Not Confirmed Notes
- None in this pass.

## Skimmer Hints (Not Confirmed)
### Security-related TODO or FIXME
- Match count: 1
- Sample evidence:
```text
\\VBOXSVR\elements\Repos\zk0d\cat_8_libs\arkworks-marlin\src\lib.rs:106:        // TODO: Add check that c is in the correct mode.
```

### panic/unwrap/expect usage
- Match count: 75
- Sample evidence:
```text
\\VBOXSVR\elements\Repos\zk0d\cat_8_libs\arkworks-marlin\benches\bench.rs:84:        .unwrap();
\\VBOXSVR\elements\Repos\zk0d\cat_8_libs\arkworks-marlin\benches\bench.rs:90:        .unwrap();
\\VBOXSVR\elements\Repos\zk0d\cat_8_libs\arkworks-marlin\benches\bench.rs:100:            .unwrap();
\\VBOXSVR\elements\Repos\zk0d\cat_8_libs\arkworks-marlin\benches\bench.rs:126:        .unwrap();
\\VBOXSVR\elements\Repos\zk0d\cat_8_libs\arkworks-marlin\benches\bench.rs:132:        .unwrap();
\\VBOXSVR\elements\Repos\zk0d\cat_8_libs\arkworks-marlin\benches\bench.rs:138:        .unwrap();
```

## Reproduction Commands
- rg -n -S --hidden --glob !**/.git/** -- <PATTERN> \\VBOXSVR\elements\Repos\zk0d\cat_8_libs\arkworks-marlin

## External Tool Deep Scan (2026-02-15 20:36 UTC)

### Tooling Results
- gitleaks: 0 findings.
- cargo deny advisories: errors=3 (`unmaintained=2`, `vulnerability=1`), warnings=0.
- cargo audit: vulnerabilities=1, unmaintained=2, unsound=0, yanked=0.
- Vulnerability advisory: `RUSTSEC-2025-0055` on `tracing-subscriber@0.2.25` (fix `>=0.3.20`).
- Additional advisory IDs: `RUSTSEC-2024-0388`, `RUSTSEC-2024-0436`.

### Deep Assessment
- [NOT CONFIRMED] `RUSTSEC-2025-0055` advisory is present in dependency resolution (`cargo tree --all-features`). Standalone harness reproduction confirms the vulnerable behavior exists for `tracing-subscriber@0.2.25`, but no reproducible in-repo exploit witness was produced in executable repo paths.
- [NOT CONFIRMED] Code-path proof attempt found no direct `tracing_subscriber` setup or logging macro callsites in repo source; dependency usage evidence remains advisory-level only.
- [NOT CONFIRMED] Unmaintained crate advisories remain dependency-hygiene findings in this pass.

### Artifacts
- `C:\Users\vboxuser\Desktop\Repos\zklibreports\artifacts\cargo-deny\arkworks-marlin.txt`
- `C:\Users\vboxuser\Desktop\Repos\zklibreports\artifacts\cargo-audit\arkworks-marlin.json`
- `C:\Users\vboxuser\Desktop\Repos\zklibreports\artifacts\gitleaks\arkworks-marlin.json`
- `C:\Users\vboxuser\Desktop\Repos\zklibreports\artifacts\proof\arkworks-marlin-rustsec-2025-0055-proof.txt`

## External PoC Validation (2026-02-15 22:06 UTC)

### Tooling Results
- Standalone Rust harness created outside audited repos with identical payload and subscriber config:
  - vulnerable: `tracing-subscriber = 0.2.25`
  - patched: `tracing-subscriber = 0.3.22`
- Output byte checks:
  - vulnerable output: `ESC(0x1b)=5`, `BEL(0x07)=1`
  - patched output: `ESC(0x1b)=4`, `BEL(0x07)=0`

### Deep Assessment
- [EXTERNAL PROOF] `RUSTSEC-2025-0055` behavior difference is reproduced under controlled external conditions.
- [NOT CONFIRMED - repo specific] No in-repo trigger path was proven in `arkworks-marlin`; classification for this repo remains NOT CONFIRMED.

### Artifacts
- `C:\Users\vboxuser\Desktop\Repos\zklibreports\proof_harness\rustsec-2025-0055\vuln_0_2_25\Cargo.toml`
- `C:\Users\vboxuser\Desktop\Repos\zklibreports\proof_harness\rustsec-2025-0055\vuln_0_2_25\src\main.rs`
- `C:\Users\vboxuser\Desktop\Repos\zklibreports\proof_harness\rustsec-2025-0055\patched_0_3_22\Cargo.toml`
- `C:\Users\vboxuser\Desktop\Repos\zklibreports\proof_harness\rustsec-2025-0055\patched_0_3_22\src\main.rs`
- `C:\Users\vboxuser\Desktop\Repos\zklibreports\artifacts\proof\rustsec-2025-0055-vuln-output-clean.txt`
- `C:\Users\vboxuser\Desktop\Repos\zklibreports\artifacts\proof\rustsec-2025-0055-patched-output-clean.txt`

# Custom Vulnerability Report: arkworks-curves

## Scope
- Audit time (UTC): 2026-02-15 18:09:28
- Repository path: \\VBOXSVR\elements\Repos\zk0d\cat_8_libs\arkworks-curves
- Language profile: Rust
- Git branch: master
- Git commit: e2d16a2
- Upstream: origin/master
- Upstream delta: behind=0 ahead=0
- Remote: https://github.com/arkworks-rs/curves.git

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
- NOT CONFIRMED (skimmer hints): 271 matches across 1 pattern classes

## Likely Findings
- None in this pass.

## Not Confirmed Notes
- None in this pass.

## Skimmer Hints (Not Confirmed)
### panic/unwrap/expect usage
- Match count: 271
- Sample evidence:
```text
\\VBOXSVR\elements\Repos\zk0d\cat_8_libs\arkworks-curves\ed_on_bn254\src\fields\tests.rs:19:    .unwrap();
\\VBOXSVR\elements\Repos\zk0d\cat_8_libs\arkworks-curves\ed_on_bn254\src\fields\tests.rs:23:    .unwrap();
\\VBOXSVR\elements\Repos\zk0d\cat_8_libs\arkworks-curves\ed_on_bn254\src\fields\tests.rs:27:    .unwrap();
\\VBOXSVR\elements\Repos\zk0d\cat_8_libs\arkworks-curves\ed_on_bn254\src\fields\tests.rs:39:    .unwrap();
\\VBOXSVR\elements\Repos\zk0d\cat_8_libs\arkworks-curves\ed_on_bn254\src\fields\tests.rs:43:    .unwrap();
\\VBOXSVR\elements\Repos\zk0d\cat_8_libs\arkworks-curves\ed_on_bn254\src\fields\tests.rs:54:    .unwrap();
```

## Reproduction Commands
- rg -n -S --hidden --glob !**/.git/** -- <PATTERN> \\VBOXSVR\elements\Repos\zk0d\cat_8_libs\arkworks-curves

## External Tool Deep Scan (2026-02-15 20:36 UTC)

### Tooling Results
- gitleaks: 0 findings.
- cargo deny advisories: errors=3 (`unmaintained`), warnings=0.
- cargo audit: vulnerabilities=1, unmaintained=3, unsound=1, yanked=0.
- Vulnerability advisory: `RUSTSEC-2025-0055` on `tracing-subscriber@0.2.25` (fix `>=0.3.20`).
- Additional advisory IDs: `RUSTSEC-2024-0375`, `RUSTSEC-2024-0388`, `RUSTSEC-2024-0436`, `RUSTSEC-2021-0145`.

### Deep Assessment
- [NOT CONFIRMED] `RUSTSEC-2025-0055` advisory is present in dependency resolution (`cargo tree --all-features`). Standalone harness reproduction confirms the vulnerable behavior exists for `tracing-subscriber@0.2.25`, but no reproducible in-repo exploit witness was produced in executable repo paths.
- [NOT CONFIRMED] Code-path proof attempt found no direct `tracing_subscriber` setup or logging macro callsites in repo source; dependency usage evidence remains advisory-level only.
- [NOT CONFIRMED] Unmaintained/unsound advisories are dependency-hygiene risks in this pass; no exploit witness was produced.

### Artifacts
- `C:\Users\vboxuser\Desktop\Repos\zklibreports\artifacts\cargo-deny\arkworks-curves.txt`
- `C:\Users\vboxuser\Desktop\Repos\zklibreports\artifacts\cargo-audit\arkworks-curves.json`
- `C:\Users\vboxuser\Desktop\Repos\zklibreports\artifacts\gitleaks\arkworks-curves.json`
- `C:\Users\vboxuser\Desktop\Repos\zklibreports\artifacts\proof\arkworks-curves-rustsec-2025-0055-proof.txt`

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
- [NOT CONFIRMED - repo specific] No in-repo trigger path was proven in `arkworks-curves`; classification for this repo remains NOT CONFIRMED.

### Artifacts
- `C:\Users\vboxuser\Desktop\Repos\zklibreports\proof_harness\rustsec-2025-0055\vuln_0_2_25\Cargo.toml`
- `C:\Users\vboxuser\Desktop\Repos\zklibreports\proof_harness\rustsec-2025-0055\vuln_0_2_25\src\main.rs`
- `C:\Users\vboxuser\Desktop\Repos\zklibreports\proof_harness\rustsec-2025-0055\patched_0_3_22\Cargo.toml`
- `C:\Users\vboxuser\Desktop\Repos\zklibreports\proof_harness\rustsec-2025-0055\patched_0_3_22\src\main.rs`
- `C:\Users\vboxuser\Desktop\Repos\zklibreports\artifacts\proof\rustsec-2025-0055-vuln-output-clean.txt`
- `C:\Users\vboxuser\Desktop\Repos\zklibreports\artifacts\proof\rustsec-2025-0055-patched-output-clean.txt`

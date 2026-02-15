# Custom Vulnerability Report: gnark

## Scope
- Audit time (UTC): 2026-02-15 18:37:23
- Repository path: \\VBOXSVR\elements\Repos\zk0d\cat_8_libs\gnark
- Language profile: Go
- Git branch: master
- Git commit: 147ac718
- Upstream: origin/master
- Upstream delta: behind=0 ahead=0
- Remote: https://github.com/ConsenSys/gnark.git

## Method
- Fast skimmer triage over executable paths (tests/docs excluded from pattern scans).
- Dependency advisory scan with `govulncheck` after toolchain install.
- No issue is marked CONFIRMED unless reproducible witness evidence exists.

## Tooling Results
- govulncheck scanner: `v1.1.4`, DB last modified `2026-02-05`
- Scan mode: `source`, level: `symbol`
- Findings: `0`
- Artifact: `C:\Users\vboxuser\Desktop\Repos\zklibreports\\reports\\cat8_libs\\gnark-govulncheck.json`

## Classification Summary
- FORMALLY CONFIRMED: 0
- CONFIRMED: 0
- LIKELY: 0
- NOT CONFIRMED (skimmer hints): 1175 matches across 4 pattern classes

## Phase 2 Reachability Analysis
- Full-module `govulncheck` completed successfully against `./...`.
- No vulnerable call-path findings were produced by the Go vulnerability database.
- Result: no advisory-backed likely findings for this pass.

## Likely Findings
- None in this pass.

## Not Confirmed Notes
- None in this pass.

## Skimmer Hints (Not Confirmed)
### Security-related TODO or FIXME
- Match count: 22
- Sample evidence:
```text
\\VBOXSVR\elements\Repos\zk0d\cat_8_libs\gnark\constraint\tinyfield\solver.go:159:// TODO @gbotrel check t.IsConstant on the caller side when necessary
\\VBOXSVR\elements\Repos\zk0d\cat_8_libs\gnark\constraint\tinyfield\marshal.go:70: // TODO @gbotrel validate version, duplicate logic with core.go CheckSerializationHeader
\\VBOXSVR\elements\Repos\zk0d\cat_8_libs\gnark\constraint\r1cs.go:57:// ... TODO @gbotrel check that
```

### Command execution usage
- Match count: 8
- Sample evidence:
```text
\\VBOXSVR\elements\Repos\zk0d\cat_8_libs\gnark\version_test.go:16: cmd := exec.Command("git", ...)
\\VBOXSVR\elements\Repos\zk0d\cat_8_libs\gnark\backend\accelerated\icicle\internal\generator\main.go:74: cmd := exec.Command(name, arg...)
\\VBOXSVR\elements\Repos\zk0d\cat_8_libs\gnark\backend\accelerated\icicle\internal\generator\main.go:84: cmd := exec.Command("go", "tool", "goimports", "-w", "../../groth16")
```

### Unsafe package usage
- Match count: 178

### panic usage
- Match count: 967

## Reproduction Commands
- `$env:Path='C:\Program Files\Go\bin;'+$env:Path; Push-Location \\VBOXSVR\elements\Repos\zk0d\cat_8_libs\gnark; & $env:USERPROFILE\\go\\bin\\govulncheck.exe -json ./...`
- `rg -n -S --hidden --glob !**/.git/** -- <PATTERN> \\VBOXSVR\elements\Repos\zk0d\cat_8_libs\gnark`

## External Tool Deep Scan (2026-02-15 20:36 UTC)

### Tooling Results
- gitleaks: 1 finding (`generic-api-key`) in `examples/serialization/main.go:34`.
- govulncheck (scanner `v1.1.4`, db modified `2026-02-05`): no vulnerability findings.
- gosec focused pass (`severity>=medium`, excluded noisy `G104,G115,G602`): 0 issues.

### Deep Assessment
- [NOT CONFIRMED] gitleaks hit is a false positive on a comment/example line, not a credential.
- [NOT CONFIRMED] No vulnerable call path was reported by govulncheck; focused gosec also produced zero actionable medium/high findings.

### Artifacts
- `C:\Users\vboxuser\Desktop\Repos\zklibreports\artifacts\gitleaks\gnark.json`
- `C:\Users\vboxuser\Desktop\Repos\zklibreports\artifacts\govulncheck\gnark.json`
- `C:\Users\vboxuser\Desktop\Repos\zklibreports\artifacts\gosec\gnark-gosec-focused.json`
- `C:\Users\vboxuser\Desktop\Repos\zklibreports\artifacts\gosec\gnark-gosec.json`



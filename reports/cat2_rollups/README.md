# cat2_rollups

Inputs live at `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups` (13 git repos).

Goal: identify **provable** vulnerabilities (repro, trace, counterexample), not just tool output.

Manual audit plan: `reports/cat2_rollups/ROADMAP.md`

Baseline scan script:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/audit_cat2_rollups.ps1
```

Host note: this Windows host uses a restrictive PowerShell execution policy; use `-ExecutionPolicy Bypass` for `scripts/*.ps1`.

Outputs:
- `reports/cat2_rollups/INDEX.md` summary table.
- Per-repo: `reports/cat2_rollups/<repo>/report.md` + `reports/cat2_rollups/<repo>/artifacts/*`.
- Tool versions: `reports/cat2_rollups/tool_versions.json`.
- Proven findings rollup: `reports/cat2_rollups/PROVEN_SUMMARY.md`.

## Scan Snapshot (2026-02-16 02:58:58 UTC)

- Repos scanned: `13`
- Total `gitleaks` findings: `934`
- Total `osv-scanner` vulns: `3549`
- Total `npm audit` vulns: `0`
- Total `cargo audit` vulns: `65`

Top concentration:
- `mantle`: `1654` combined findings (`osv=1567`, `gitleaks=87`)
- `optimism`: `1020` combined findings (`osv=1008`, `cargo=12`) with tool timeout caveats
- `era-contracts`: `513` combined findings (`gitleaks=376`, `osv=125`, `cargo=12`)
- `zkevm-circuits`: `360` combined findings (`gitleaks=231`, `osv=119`, `cargo=10`)

## Coverage Caveats

- `optimism` had timeouts:
  - `gitleaks` exit `124` (`context deadline exceeded`)
  - `osv-scanner` exit `124`
- `govulncheck` exits with code `1` in several repos due module/root or compile issues:
  - `base-contracts`, `mantle`, `zkevm-circuits`: no `go.mod` at scanned root
  - `optimism`: package load/type error in `op-preimage/filechan.go`
  - `taiko-contracts`, `taiko-mono`: dependency compile/type failures in `blst`/`prysm` chain

These are baseline leads, not confirmed exploitable vulnerabilities.

## Tools In Use

Baseline automation (`scripts/audit_cat2_rollups.ps1`) runs:
- `gitleaks` (secrets; redaction enabled)
- `osv-scanner` (dependency vulnerability leads)
- `govulncheck` + `gosec` for Go repos
- `cargo audit` for Rust repos (existing `Cargo.lock` only)
- `npm audit --package-lock-only` for Node repos with `package-lock.json`

For proof-grade validation workflows:
- `slither`, `halmos`, `solc`
- Foundry via `scripts/forge.ps1`, `scripts/cast.ps1`, `scripts/anvil.ps1`
- `echidna` via `scripts/echidna.ps1`
- `medusa` via `scripts/medusa.ps1`
- `semgrep` via `scripts/semgrep.ps1`

Reference docs:
- `docs/TOOLS.md`
- `docs/PROOF_BAR.md`

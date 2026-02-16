# cat1_bridges

Inputs live at `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges` (10 git repos).

Goal: identify **provable** vulnerabilities (repro or trace), not just tool noise.

Manual audit plan: `reports/cat1_bridges/ROADMAP.md`

Baseline scan script:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/audit_cat1_bridges.ps1
```

Outputs:
- `reports/cat1_bridges/INDEX.md` summary table.
- Per-repo: `reports/cat1_bridges/<repo>/report.md` + `reports/cat1_bridges/<repo>/artifacts/*`.

## Tools In Use

Baseline automation (`scripts/audit_cat1_bridges.ps1`) currently runs:
- `gitleaks` (with redaction enabled)
- `osv-scanner` (dependency vuln leads)
- `npm audit --package-lock-only` for Node repos (when `package-lock.json` exists)
- `govulncheck` + `gosec` for Go repos
- `cargo audit` for Rust repos (only if `Cargo.lock` exists; no lockfile generation)

For Solidity/EVM deep analysis we also use:
- `halmos` (symbolic invariant testing; typically driven from Foundry tests)
- `slither` (static analyzer; run in a controlled mode because it may invoke compilation/build steps)
- `aderyn` (additional Solidity analyzer; treat output as leads until you have a repro)
- Foundry (harness + fuzzing): `scripts/forge.ps1`, `scripts/cast.ps1`, `scripts/anvil.ps1`
- Echidna (stateful fuzzing): `scripts/echidna.ps1`
- Medusa (stateful fuzzing): `scripts/medusa.ps1`

For TS/JS and general codebase lead generation:
- `semgrep` via `scripts/semgrep.ps1` (kept in a venv to avoid Python dependency conflicts with Halmos)
- Optional deep dataflow: CodeQL via `scripts/codeql.ps1` (not in baseline scans)

For ZK/circuit fuzzing workstreams (when a target contains circuits):
- `zkfuzz` via `scripts/zkfuzz.ps1` (local build)
- Circom + SnarkJS are available for witness/proof verification (not baseline scans): `circom`, `scripts/snarkjs.ps1`

More detailed tool notes: `docs/TOOLS.md`

## Provable Vulns

Vulnerability claims in reports should have a witness (repro, trace, counterexample, or reachability proof).

Definition and labels: `docs/PROOF_BAR.md`

## Safety Note

The baseline scan intentionally avoids executing repo build scripts by default. Solidity toolchains often invoke compilation and custom build steps; run those in a controlled mode after review.

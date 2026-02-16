# Tools

This is a quick reference for the tools we run and what "proof" typically looks like for each one.

## Secrets

- `gitleaks`: searches repo history and working tree for secrets.
  - Proof: a real credential in reachable code/config. Output should be **redacted** in stored artifacts.

## Dependency Vulnerabilities

- `osv-scanner`: dependency matching against OSV/Deps.dev data.
  - Proof: show an in-repo dependency edge that pulls the vulnerable version *and* a reachability path to the vulnerable code (call trace, import path, or a minimal repro).

## Go

- `govulncheck`: reports known vulns with optional symbol-level traces.
  - Proof: a `symbol`-level report (or a repro) that shows the vulnerable symbol is reachable from the codebase.
- `gosec`: static analyzer for common Go security issues.
  - Proof: a minimized repro (or clear dataflow path) demonstrating real impact and exploitability.
- `staticcheck`: high-signal Go linter (bug patterns, suspicious code, etc.).
  - Proof: a concrete misuse reachable in the codebase (or a minimal repro), not just a style warning.

## Rust

- `cargo audit`: checks `Cargo.lock` against RustSec advisories.
  - Proof: reachability evidence from in-repo code to vulnerable crate APIs under the actual feature set.
- `cargo deny`: policy checks (licenses, bans, advisories, sources).
  - Proof: typically policy, not "vuln"; treat as compliance issues unless it maps to a concrete exploit.
- `cargo-fuzz`: libFuzzer harness runner for Rust (`cargo fuzz`).
  - Proof: a deterministic crashing input plus a minimized corpus entry and (ideally) a root-cause patch.
  - Version on this host: `cargo-fuzz 0.13.1`.
- `bolero`: Rust property-based testing/fuzzing library (crate).
  - Proof: a minimized failing seed or shrinking counterexample, plus a clear property/invariant statement.
  - Add to `Cargo.toml` (example):

```toml
[dev-dependencies]
bolero = "0.11"
```

## Node / TypeScript

- `npm audit`: lockfile vulnerability scan.
  - Proof: reachability in the shipped/runtime path; many findings are dev-only or unreachable in production.
  - Host note: on this Windows host, use `cmd /c npm.cmd ...` instead of `npm` in PowerShell due to script policy.
- `semgrep`: general static analysis for TS/JS/Go/etc (use it as "lead generation", not as proof).
  - Proof: a confirmed dataflow path, exploit, or minimized repro in the specific target code.
  - Host note: Semgrep conflicts with Halmos deps when installed in the global Python env, so we run it from a venv:
    - `tools/venv/semgrep/Scripts/semgrep.exe`
  - Run (example): `powershell -NoProfile -File scripts/semgrep.ps1 scan --config auto .`

## Solidity / EVM

- `halmos`: symbolic testing for EVM smart contracts, commonly run against Foundry-style tests (invariants / stateful sequences).
  - Proof: a Halmos counterexample trace/model violating a stated invariant (plus a minimized transaction sequence if possible).
  - Install: `python -m pip install halmos`
  - Run (example): `halmos --root <repo> --match-contract <TestContractRegex> --match-test <InvariantRegex>`

- `slither`: static analyzer for Solidity.
  - Proof: usually needs a minimized contract/testcase or an exploit sequence; treat default output as leads.
  - Run (example): `slither . --exclude-dependencies --filter-paths node_modules`

- `aderyn`: Rust-based Solidity analyzer (detector registry + auditor mode).
  - Proof: still needs a witness; treat findings as leads until you can write a minimal test/PoC.
  - Note: on this Windows host, Aderyn may crash on some large Foundry projects; if that happens, rerun on Linux/WSL or pin/upgrade Aderyn.
  - Run (example): `aderyn . --src contracts --no-snippets`

- Foundry (local harness + fuzzing):
  - `C:\\Tools\\foundry\\bin\\forge.exe` is installed on this host (not on `PATH` by default).
  - Proof: a failing test/invariant with a minimized transaction sequence; ideally paired with a root-cause fix.
  - Run (examples): `powershell -NoProfile -File scripts/forge.ps1 test` and `powershell -NoProfile -File scripts/anvil.ps1`

## ZK / Circuits

- `zkfuzz` (ZK circuit fuzzer): available as a local repo build.
  - Version on this host: `zkfuzz 2.2.1` (Cargo package name: `zkfuzz`).
  - Binary location:
    - `C:\\Users\\vboxuser\\Desktop\\Repos\\smartcontractpatternfinder\\zkFuzz\\target\\release\\zkfuzz.exe`
  - Run (example): `powershell -NoProfile -File scripts/zkfuzz.ps1 --help`
  - Proof: a minimized failing witness (input + circuit/config) plus backend verification that the failure is real (not a tooling artifact).

Other common follow-ups (optional, project-dependent): Echidna/Medusa (EVM stateful fuzzing), bytecode-level symbolic tools, Kani (Rust model checking), and chain-level integration testbeds.

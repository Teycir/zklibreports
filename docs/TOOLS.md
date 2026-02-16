# Tools

This is a quick reference for the tools we run and what "proof" typically looks like for each one.
Formal process reference: `docs/METHODOLOGY.md`.

## Secrets

- `gitleaks`: searches repo history and working tree for secrets.
  - Proof: a real credential in reachable code/config. Output should be **redacted** in stored artifacts.

## Dependency Vulnerabilities

- `osv-scanner`: dependency matching against OSV/Deps.dev data.
  - Proof: show an in-repo dependency edge that pulls the vulnerable version *and* a reachability path to the vulnerable code (call trace, import path, or a minimal repro).
- `syft` (SBOM): generate an SBOM to understand what is actually shipped (useful on monorepos and polyglot repos).
  - Proof: not a vuln by itself; use it to support reachability and inventory claims.
  - Run (example): `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/syft.ps1 dir:<repo> -o json > sbom.json`
- `grype` (vuln scan): scans an SBOM or filesystem image for known vulns.
  - Proof: same as other dependency scanners: show the vulnerable package version is present *and* reachable/used in the target runtime path.
  - Run (example): `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/grype.ps1 dir:<repo> -o json > grype.json`

## Go

- `govulncheck`: reports known vulns with optional symbol-level traces.
  - Proof: a `symbol`-level report (or a repro) that shows the vulnerable symbol is reachable from the codebase.
- `gosec`: static analyzer for common Go security issues.
  - Proof: a minimized repro (or clear dataflow path) demonstrating real impact and exploitability.
- `staticcheck`: high-signal Go linter (bug patterns, suspicious code, etc.).
  - Proof: a concrete misuse reachable in the codebase (or a minimal repro), not just a style warning.
- `codeql` (optional, deep dataflow): heavy but excellent for taint/reachability questions in Go/TS monorepos.
  - Proof: a concrete CodeQL path to a sink, then a manual confirmation (call graph / repro / failing test).
  - Run (example): `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/codeql.ps1 version`

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
  - Run (example): `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/semgrep.ps1 scan --config auto .`

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
  - Run (examples): `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/forge.ps1 test` and `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/anvil.ps1`

 - Echidna (stateful fuzzing / invariants):
   - Proof: a minimized transaction sequence (or corpus) that breaks an invariant, plus a manual confirmation and root cause in code.
   - Host note: installed at `C:\\echidna\\echidna.exe` (not on `PATH` by default).
   - Run (example): `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/echidna.ps1 --version`

- Medusa (stateful fuzzing / invariants):
  - Proof: a minimized transaction sequence/corpus that violates a property, plus a manual confirmation and root cause in code.
  - Host note: installed at `C:\\Users\\vboxuser\\go\\bin\\medusa.exe` (Go toolchain install).
  - Run (example): `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/medusa.ps1 --version`

### Specialist Fuzzer Playbook (EVM)

Use this when you want a reproducible, witness-grade stateful fuzz run (not just static leads).

1) Build a stateful harness:
- Add mutating action functions (`action_*`) and invariants (`property_*`) in a dedicated harness contract.

2) Initialize Medusa config in the harness directory:
- `powershell -NoProfile -ExecutionPolicy Bypass -File ..\\..\\scripts\\medusa.ps1 init`

3) Run a bounded fail-fast campaign:
- `powershell -NoProfile -ExecutionPolicy Bypass -File ..\\..\\scripts\\medusa.ps1 fuzz --compilation-target . --target-contracts <HarnessContract> --seq-len 8 --workers 4 --timeout 30 --fail-fast --no-color --log-level info`

3b) Optional Echidna cross-check on the same harness:
- `powershell -NoProfile -ExecutionPolicy Bypass -File ..\\..\\scripts\\echidna.ps1 src/<Harness>.sol --contract <HarnessContract> --test-mode property --seq-len 10 --test-limit 20000 --timeout 30 --format text --corpus-dir echidna-corpus-<finding>`

4) Interpret results correctly:
- Medusa exits non-zero when a property fails; that is expected for a successful vulnerability witness.
- Echidna exits non-zero when a property is falsified; that is also expected for a successful vulnerability witness.
- Preserve the minimized call sequence and execution trace as an artifact.

5) Capture output to artifacts:
- `powershell -NoProfile -ExecutionPolicy Bypass -File ..\\..\\scripts\\medusa.ps1 fuzz ... *>&1 | Tee-Object -FilePath reports/<category>/<repo>/manual_artifacts/<name>.txt`

6) Preferred standardized runner:
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/evm_specialist_campaign.ps1 -HarnessDir <harness_dir> -HarnessContract <contract> -HarnessSource src/<harness>.sol -ArtifactDir reports/<category>/<repo>/manual_artifacts -ArtifactPrefix <finding_prefix> -EchidnaCorpusDir echidna-corpus-<finding>`
- This writes:
- Medusa output
- Echidna output
- campaign metadata JSON (commands, timestamps, exit codes)

Concrete in-repo example (Category 1 / Nomad):
- Harness: `proof_harness/cat1_nomad_f1_stale_replica/src/MedusaXcmF1Harness.sol`
- Run output artifact: `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f1_medusa_failfast_30s.txt`
- Governance escalation harness: `proof_harness/cat1_nomad_f1_stale_replica/src/MedusaGovernanceTakeoverHarness.sol`
- Governance run output artifact: `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f4_medusa_governance_takeover_30s.txt`
- Governance batch injection harness: `proof_harness/cat1_nomad_f1_stale_replica/src/MedusaGovernanceBatchInjectionHarness.sol`
- Governance batch run output artifact: `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f5_medusa_batch_injection_30s.txt`
- Forged prefill dust-drain harness: `proof_harness/cat1_nomad_f1_stale_replica/src/MedusaBridgePrefillDustHarness.sol`
- Forged prefill run output artifact: `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f7_prefill_dust_formal_medusa_30s.txt`
- Representation alias swap harness: `proof_harness/cat1_nomad_f1_stale_replica/src/MedusaTokenRegistryAliasHarness.sol`
- Representation alias run output artifact: `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f8_alias_swap_formal_medusa_30s.txt`
- Governance domain-churn harness: `proof_harness/cat1_nomad_f1_stale_replica/src/MedusaGovernanceDomainChurnHarness.sol`
- Governance domain-churn run output artifact: `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f9_domain_churn_formal_medusa_30s.txt`
- Governance domain-churn gas profile artifact: `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f9_domain_churn_gas_profile_forge_test.txt`
- Migrate-alias harness: `proof_harness/cat1_nomad_f1_stale_replica/src/MedusaTokenRegistryMigrateHarness.sol`
- Migrate-alias run output artifact: `reports/cat1_bridges/nomad-monorepo/manual_artifacts/f10_migrate_alias_formal_medusa_30s.txt`
- Wormhole metadata-method DoS harness: `proof_harness/cat1_wormhole_f1_metadata_dos/src/MedusaBridgeMetadataCompatHarness.sol`
- Wormhole metadata-method DoS run output artifact: `reports/cat1_bridges/wormhole/manual_artifacts/w1_metadata_dos_formal_medusa_30s.txt`
- Wormhole stale-guardian governance harness: `proof_harness/cat1_wormhole_f2_stale_guardian_governance/src/MedusaStaleGuardianGovernanceHarness.sol`
- Wormhole stale-guardian governance run output artifact: `reports/cat1_bridges/wormhole/manual_artifacts/w2_stale_guardian_governance_formal_medusa_30s.txt`
- Wormhole outbound sender-tax harness: `proof_harness/cat1_wormhole_f3_outbound_sender_tax_insolvency/src/MedusaOutboundSenderTaxHarness.sol`
- Wormhole outbound sender-tax run output artifact: `reports/cat1_bridges/wormhole/manual_artifacts/w3_outbound_sender_tax_formal_medusa_30s.txt`
- Wormhole reentrancy replay-guard harness: `proof_harness/cat1_wormhole_h2_reentrancy_replay_guard/src/MedusaReentrancyReplayHarness.sol`
- Wormhole reentrancy replay-guard run output artifact: `reports/cat1_bridges/wormhole/manual_artifacts/h2_reentrancy_replay_guard_formal_medusa_30s.txt`
- Nomad full-source parity harness: `proof_harness/cat1_nomad_parity_fullsource/test/NomadFullSourceParity.t.sol`
- Nomad full-source parity run artifacts: `reports/cat1_bridges/nomad-monorepo/manual_artifacts/h1_fullsource_parity_forge_test.txt`, `reports/cat1_bridges/nomad-monorepo/manual_artifacts/h2_fullsource_parity_forge_test.txt`
- LayerZero-v2 OFT lossless-assumption harness: `proof_harness/cat1_layerzero_v2_f1_oft_delegate/src/MedusaLz1OFTAdapterHarness.sol`
- LayerZero-v2 OFT lossless-assumption run artifact: `reports/cat1_bridges/LayerZero-v2/manual_artifacts/lz1_oft_lossless_formal_medusa_30s.txt`
- LayerZero-v2 stale-delegate persistence harness: `proof_harness/cat1_layerzero_v2_f1_oft_delegate/src/MedusaLz2DelegateHarness.sol`
- LayerZero-v2 stale-delegate persistence run artifact: `reports/cat1_bridges/LayerZero-v2/manual_artifacts/lz2_stale_delegate_formal_medusa_30s.txt`
- LayerZero-v2 residual-lzToken sweep harness: `proof_harness/cat1_layerzero_v2_f1_oft_delegate/src/MedusaLz3ResidualSweepHarness.sol`
- LayerZero-v2 residual-lzToken sweep run artifact: `reports/cat1_bridges/LayerZero-v2/manual_artifacts/lz3_residual_sweep_formal_medusa_30s.txt`
- LayerZero-v2 full-source parity harness: `proof_harness/cat1_layerzero_v2_parity_fullsource/test/LayerZeroV2FullSourceParity.t.sol`
- LayerZero-v2 full-source parity run artifacts: `reports/cat1_bridges/LayerZero-v2/manual_artifacts/h1_fullsource_parity_oft_adapter_forge_test.txt`, `reports/cat1_bridges/LayerZero-v2/manual_artifacts/h2_fullsource_parity_delegate_stale_forge_test.txt`, `reports/cat1_bridges/LayerZero-v2/manual_artifacts/h3_fullsource_lztoken_residual_sweep_forge_test.txt`
- Hyperlane fee-on-transfer collateral harness: `proof_harness/cat1_hyperlane_f1_collateral_fee_on_transfer/src/MedusaHyperlaneCollateralFeeHarness.sol`
- Hyperlane fee-on-transfer collateral run artifact: `reports/cat1_bridges/hyperlane-monorepo/manual_artifacts/h1_collateral_fee_on_transfer_formal_medusa_30s.txt`
- Hyperlane LP-asset overstatement harness: `proof_harness/cat1_hyperlane_f1_collateral_fee_on_transfer/src/MedusaHyperlaneLpAssetsHarness.sol`
- Hyperlane LP-asset overstatement run artifact: `reports/cat1_bridges/hyperlane-monorepo/manual_artifacts/h2_lp_assets_overstatement_formal_medusa_30s.txt`
- Hyperlane fee-transfer sender-tax harness: `proof_harness/cat1_hyperlane_f1_collateral_fee_on_transfer/src/MedusaHyperlaneFeeTransferHarness.sol`
- Hyperlane fee-transfer sender-tax run artifact: `reports/cat1_bridges/hyperlane-monorepo/manual_artifacts/h3_fee_transfer_sender_tax_formal_medusa_30s.txt`
- Synapse deposit fee-on-transfer harness: `proof_harness/cat1_synapse_f1_deposit_fee_on_transfer/src/MedusaSynapseDepositFeeHarness.sol`
- Synapse deposit fee-on-transfer run artifact: `reports/cat1_bridges/synapse-contracts/manual_artifacts/f1_deposit_fee_on_transfer_formal_medusa_30s.txt`
- Synapse role-escalation blast-radius harness: `proof_harness/cat1_synapse_f2_f3_role_minout/src/MedusaSynapseRoleEscalationHarness.sol`
- Synapse role-escalation blast-radius run artifact: `reports/cat1_bridges/synapse-contracts/manual_artifacts/f2_role_escalation_blast_radius_formal_medusa_30s.txt`
- Synapse min-out receipt-mismatch harness: `proof_harness/cat1_synapse_f2_f3_role_minout/src/MedusaSynapseMinOutHarness.sol`
- Synapse min-out receipt-mismatch run artifact: `reports/cat1_bridges/synapse-contracts/manual_artifacts/f3_min_out_receipt_mismatch_formal_medusa_30s.txt`
- Connext router sender-tax harness: `proof_harness/cat1_connext_f1_router_sender_tax/src/MedusaConnextRouterSenderTaxHarness.sol`
- Connext router sender-tax run artifact: `reports/cat1_bridges/connext-monorepo/manual_artifacts/f1_router_sender_tax_formal_medusa_30s.txt`

## ZK / Circom

- `circom`: circuit compiler.
  - Proof: not a vuln tool; used to produce artifacts for witness/proof verification and to reproduce circuit issues.
  - Version on this host: `v2.2.3`.
- `snarkjs`: proof generation/verification CLI (Groth16/Plonk tooling).
  - Proof: not a vuln tool; used to validate that a witness/proof is valid/invalid as claimed.
  - Version on this host: `v0.7.6`.
  - Run (example): `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/snarkjs.ps1 --help`

## ZK / Circuits

- `zkfuzz` (ZK circuit fuzzer): available as a local repo build.
  - Version on this host: `zkfuzz 2.2.1` (Cargo package name: `zkfuzz`).
  - Binary location:
    - `C:\\Users\\vboxuser\\Desktop\\Repos\\smartcontractpatternfinder\\zkFuzz\\target\\release\\zkfuzz.exe`
  - Run (example): `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/zkfuzz.ps1 --help`
  - Proof: a minimized failing witness (input + circuit/config) plus backend verification that the failure is real (not a tooling artifact).

- `Picus`: ZK circuit analysis tool.
  - Version on this host: `Latest`.
  - Proof: analysis results showing circuit vulnerabilities or verification properties.

- `Halo2`: ZK proof system library.
  - Version on this host: `v0.3.2` (library).
  - Proof: not a vuln tool; used for circuit development and proof generation/verification.

## C/C++ Verification (Optional)

- `cbmc` (bounded model checking):
  - Proof: a concrete counterexample trace for a property (assertion) in a harness you can explain and reproduce.
  - Run (example): `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/cbmc.ps1 --version`
- `z3` (SMT solver):
  - Proof: a model/counterexample; typically used indirectly (CBMC, custom SMT encodings).
  - Run (example): `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/z3.ps1 -version`

Other common follow-ups (optional, project-dependent): Echidna/Medusa (EVM stateful fuzzing), bytecode-level symbolic tools, Kani (Rust model checking), and chain-level integration testbeds.

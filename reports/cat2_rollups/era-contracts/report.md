# era-contracts

- Source: `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\era-contracts`
- HEAD: `920501207baed3f33c66914039409c49f2dea1bb`
- origin: `https://github.com/matter-labs/era-contracts`
- Stacks: `node`, `rust`, `solidity`

## Manual Verdict

- `CONFIRMED`: 1
- `LIKELY`: 0
- `NOT CONFIRMED`: scanner-only dependency/secrets leads without exploit witness

## Proven Findings

## F-ERAC-01: ChainRegistrar initializer first-caller takeover can redirect proposer token top-ups

Severity: `High`

Status: `CONFIRMED`

Affected code:
- `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\era-contracts\l1-contracts\contracts\chain-registrar\ChainRegistrar.sol:104` - implementation constructor disables initializers (`_disableInitializers()`).
- `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\era-contracts\l1-contracts\contracts\chain-registrar\ChainRegistrar.sol:112` - `initialize(address,address,address)` is external and first-caller gated only (`initializer`) with no caller authorization.
- `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\era-contracts\l1-contracts\contracts\chain-registrar\ChainRegistrar.sol:182` - `changeDeployer(...)` is `onlyOwner`.
- `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\era-contracts\l1-contracts\contracts\chain-registrar\ChainRegistrar.sol:173` - non-ETH proposer flow transfers ERC20 top-up to `l2Deployer`.

Root cause:
- Initialization authority is implicit (first external caller) instead of explicitly constrained to trusted deployment authority at contract level.

Witness sequence:
1. Proxy points to `ChainRegistrar` implementation while still uninitialized.
2. Attacker calls `initialize(bridgehub, seededL2Deployer, attackerOwner)` first and becomes owner.
3. Attacker calls `changeDeployer(attackerCollector)` through owner authority.
4. A victim submits non-ETH `proposeChainRegistration(...)`; ERC20 top-up transfer goes to attacker-controlled `l2Deployer`.
5. Legitimate initializer call is rejected because initializer state is already consumed.

Impact:
- Direct token diversion from chain proposers in non-ETH registration flow.
- Persistent configuration capture of registrar deployer endpoint until governance/admin intervention.
- Operational risk: attacker can blackhole or grief chain registration deposits by repointing deployer.

Deterministic witness:
- Harness: `proof_harness/cat2_era_contracts_f1_chain_registrar_init_hijack/src/EraContractsF1ChainRegistrarInitHijackHarness.sol`
- Test: `proof_harness/cat2_era_contracts_f1_chain_registrar_init_hijack/test/EraContractsF1ChainRegistrarInitHijack.t.sol`
- Run: `forge test --match-path test/EraContractsF1ChainRegistrarInitHijack.t.sol`
- Artifact: `reports/cat2_rollups/era-contracts/manual_artifacts/f_erac_01_chain_registrar_init_hijack_forge_test.txt`
- Result: 3/3 tests passed (ownership capture, deployer repoint, proposer top-up diversion, initializer lockout).

Specialist fuzz witness:
- Medusa harness: `proof_harness/cat2_era_contracts_f1_chain_registrar_init_hijack/src/MedusaEraContractsF1ChainRegistrarInitHijackHarness.sol`
- Medusa init artifact: `reports/cat2_rollups/era-contracts/manual_artifacts/f_erac_01_medusa_init.txt`
- Medusa run: `medusa.exe fuzz --compilation-target . --target-contracts MedusaEraContractsF1ChainRegistrarInitHijackHarness --seq-len 8 --workers 4 --timeout 30 --fail-fast --no-color --log-level info`
- Medusa artifact: `reports/cat2_rollups/era-contracts/manual_artifacts/f_erac_01_medusa_failfast_30s.txt`
- Medusa counterexample (minimized): `action_attacker_initialize()` -> `action_attacker_change_deployer()` -> `action_victim_propose_non_eth()` falsifies `property_attacker_cannot_receive_proposer_topup()`.
- Echidna harness: `proof_harness/cat2_era_contracts_f1_chain_registrar_init_hijack/src/EchidnaEraContractsF1ChainRegistrarInitHijackHarness.sol`
- Echidna run: `echidna.exe src\EchidnaEraContractsF1ChainRegistrarInitHijackHarness.sol --contract EchidnaEraContractsF1ChainRegistrarInitHijackHarness --test-mode property --seq-len 10 --test-limit 20000 --timeout 30 --format text --corpus-dir echidna-corpus-f-erac-01`
- Echidna artifact: `reports/cat2_rollups/era-contracts/manual_artifacts/f_erac_01_echidna_30s.txt`
- Echidna counterexample (minimized): `action_attacker_initialize()` -> `action_attacker_change_deployer()` -> `action_victim_propose_non_eth()` falsifies `echidna_attacker_cannot_receive_proposer_topup()`.
- Halmos harness: `proof_harness/cat2_era_contracts_f1_chain_registrar_init_hijack/test/HalmosEraContractsF1ChainRegistrarInitHijack.t.sol`
- Halmos run: `halmos --contract HalmosEraContractsF1ChainRegistrarInitHijack --early-exit --print-failed-states --json-output reports/cat2_rollups/era-contracts/manual_artifacts/f_erac_01_halmos.json`
- Halmos artifacts:
- `reports/cat2_rollups/era-contracts/manual_artifacts/f_erac_01_halmos.txt`
- `reports/cat2_rollups/era-contracts/manual_artifacts/f_erac_01_halmos.json`
- Halmos result: counterexample found for `check_attacker_cannot_drain_proposer_topups_via_initialize_hijack()`.

Deployment note:
- The canonical helper deployer (`DeployL1HelperScript.deployTuppWithContractAndProxyAdmin`) performs atomic constructor-time proxy initialization for contracts that are wired in `getInitializeCalldata(...)`.
- `ChainRegistrar` is not wired in that initializer switch, and downstream scripts consume `chain_registrar` as a pre-supplied address (`ProposeChainRegistration.s.sol`), so safety relies on external deployment discipline rather than contract-level caller authorization.

## Tool Outputs (Baseline)

- `gitleaks`: `artifacts/gitleaks.json` (exit=1, findings=376)
- `osv-scanner`: `artifacts/osv.json` (exit=1, vulns=125)
- `cargo-audit`: `artifacts/cargo` (lockfile=`system-contracts\bootloader\test_infra\Cargo.lock`, exit=1)
- `cargo-audit`: `artifacts/cargo` (lockfile=`tools\Cargo.lock`, exit=1)
- `cargo-audit summary`: `vuln_count=12`

## Notes

- Baseline scanner counts remain triage-only unless tied to exploitability/reachability witnesses.
> Exhaustion status: closed at commit `920501207baed3f33c66914039409c49f2dea1bb`. See `reports/cat2_rollups/era-contracts/manual_audit.md` and `reports/cat2_rollups/era-contracts/EXHAUSTION_ADDENDUM.md`.

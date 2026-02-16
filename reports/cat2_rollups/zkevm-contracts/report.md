# zkevm-contracts

- Source: `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\zkevm-contracts`
- HEAD: `e468f9b0967334403069aa650d9f1164b1731ebb`
- origin: `https://github.com/0xPolygonHermez/zkevm-contracts`
- Stacks: `node`, `solidity`

## Manual Verdict

- `CONFIRMED`: 1
- `LIKELY`: 0
- `NOT CONFIRMED`: scanner-only dependency/secrets leads and test/mock-only paths without production exploit witness

## Proven Findings

## F-ZKEVMC-01: `AggLayerGateway.initialize(...)` first-caller takeover can seize verifier-route governance and poison ALGateway proof validation

Severity: `Critical`

Status: `CONFIRMED`

Affected code:
- `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\zkevm-contracts\contracts\v2\AggLayerGateway.sol:82` - `initialize(...)` is `external initializer` without caller auth
- `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\zkevm-contracts\contracts\v2\AggLayerGateway.sol:100` - grants `DEFAULT_ADMIN_ROLE` from caller-supplied address
- `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\zkevm-contracts\contracts\v2\AggLayerGateway.sol:101` - grants `AGGCHAIN_DEFAULT_VKEY_ROLE` from caller-supplied address
- `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\zkevm-contracts\contracts\v2\AggLayerGateway.sol:102` - grants `AL_ADD_PP_ROUTE_ROLE` from caller-supplied address
- `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\zkevm-contracts\contracts\v2\AggLayerGateway.sol:103` - grants `AL_FREEZE_PP_ROUTE_ROLE` from caller-supplied address
- `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\zkevm-contracts\contracts\v2\AggLayerGateway.sol:105` - seeds initial verifier route (`selector`, `verifier`, `vKey`) from caller-controlled args
- `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\zkevm-contracts\contracts\v2\AggLayerGateway.sol:142` - proof validation delegates to route-selected verifier
- `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\zkevm-contracts\contracts\v2\PolygonRollupManager.sol:1355` - ALGateway rollups depend on `aggLayerGateway.verifyPessimisticProof(...)`

Root cause:
- Privileged bootstrapping is embedded in a public `initializer` entrypoint, and there is no role/caller restriction for the first call. In any non-atomic proxy deployment or upgrade flow, first-caller controls admin/route governance.

Attacker preconditions:
- Proxy for `AggLayerGateway` is deployed or upgraded without atomically executing `initialize(...)` in the same transaction.

Witness sequence:
1. Proxy admin points a proxy to `AggLayerGateway` implementation without init calldata.
2. External attacker calls `initialize(...)` first, assigning all governance roles to attacker.
3. Attacker seeds or later adds malicious verifier routes that accept arbitrary proof bytes, or freezes routes to block verification.
4. Legitimate initializer call is permanently locked out by consumed initialization version.

Business implication (non-technical):
- A single missed atomic init in ops can hand over proof-route governance to an attacker.
- For ALGateway chains, this enables verifier-route poisoning (accepting attacker-selected proof logic) or route freeze DoS, threatening both integrity and liveness of rollup verification/finality paths.

Deterministic witness:
- Harness: `proof_harness/cat2_zkevm_contracts_f1_agglayer_gateway_init_hijack/src/ZkEvmContractsF1AggLayerGatewayInitHijackHarness.sol`
- Test: `proof_harness/cat2_zkevm_contracts_f1_agglayer_gateway_init_hijack/test/ZkEvmContractsF1AggLayerGatewayInitHijack.t.sol`
- Run: `forge test --match-path test/ZkEvmContractsF1AggLayerGatewayInitHijack.t.sol -vv`
- Artifact: `reports/cat2_rollups/zkevm-contracts/manual_artifacts/f_zkevmc_01_agglayer_gateway_init_hijack_forge_test.txt`
- Result: 3/3 tests passed, proving first-caller role takeover, malicious proof-route control, and legitimate initializer lockout.

Primary source snippets:
- `reports/cat2_rollups/zkevm-contracts/manual_artifacts/f_zkevmc_01_key_snippets.txt`

## Tool Outputs (Baseline)

- `gitleaks`: `artifacts/gitleaks.json` (exit=1, findings=83)
- `osv-scanner`: `artifacts/osv.json` (exit=1, vulns=111)
- `npm audit`: `artifacts/npm-audit_package-lock.json.json` (lockfile=`package-lock.json`, exit=1)
- `npm audit summary`: `vuln_count=0`

## Exhaustive Lead Artifacts

- `reports/cat2_rollups/zkevm-contracts/manual_artifacts/lead_counts.txt`
- `reports/cat2_rollups/zkevm-contracts/manual_artifacts/all_sol_files.txt`
- `reports/cat2_rollups/zkevm-contracts/manual_artifacts/lead_initialization.txt`
- `reports/cat2_rollups/zkevm-contracts/manual_artifacts/lead_auth_controls.txt`
- `reports/cat2_rollups/zkevm-contracts/manual_artifacts/lead_raw_calls.txt`
- `reports/cat2_rollups/zkevm-contracts/manual_artifacts/lead_txorigin.txt`
- `reports/cat2_rollups/zkevm-contracts/manual_artifacts/lead_assembly.txt`
- `reports/cat2_rollups/zkevm-contracts/manual_artifacts/lead_signatures.txt`
- `reports/cat2_rollups/zkevm-contracts/manual_artifacts/lead_unchecked.txt`
- `reports/cat2_rollups/zkevm-contracts/manual_artifacts/lead_selfdestruct.txt`

## Notes

- Deployment scripts often use atomic proxy initialization helpers, but this does not remove the contract-level first-caller hazard for non-atomic execution paths.
- Manual audit summary is tracked in `reports/cat2_rollups/zkevm-contracts/manual_audit.md`.

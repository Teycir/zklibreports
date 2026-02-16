# zkevm-contracts Manual Audit

- Repo: `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\zkevm-contracts`
- Commit: `e468f9b0967334403069aa650d9f1164b1731ebb`
- Date: `2026-02-16`

## Scope

- Production Solidity contracts, with emphasis on:
- `contracts/v2` control plane and proof-verification boundaries
- initializer/reinitializer entrypoints on upgradeable components
- verifier-route authority paths consumed by rollup state transition verification

## Lead Inventory

From `reports/cat2_rollups/zkevm-contracts/manual_artifacts/lead_counts.txt`:

- `sol_files=116`
- `initialization=124`
- `auth_controls=630`
- `raw_calls=80`
- `txorigin=4`
- `selfdestruct=0`
- `assembly=18`
- `signatures=219`
- `unchecked=13`

## Confirmed

- `F-ZKEVMC-01` (`Critical`): `AggLayerGateway.initialize(...)` is externally callable as `initializer` and bootstraps all privileged route/admin roles from caller-controlled arguments, enabling first-caller takeover in non-atomic proxy deployment/upgrade flows.

Witness artifacts:

- `reports/cat2_rollups/zkevm-contracts/manual_artifacts/f_zkevmc_01_agglayer_gateway_init_hijack_forge_test.txt`
- `reports/cat2_rollups/zkevm-contracts/manual_artifacts/f_zkevmc_01_key_snippets.txt`
- `proof_harness/cat2_zkevm_contracts_f1_agglayer_gateway_init_hijack/src/ZkEvmContractsF1AggLayerGatewayInitHijackHarness.sol`
- `proof_harness/cat2_zkevm_contracts_f1_agglayer_gateway_init_hijack/test/ZkEvmContractsF1AggLayerGatewayInitHijack.t.sol`

## Not Promoted

- Baseline dependency/secret scanner output without repository-local exploit witness.
- Test-only or mock-only findings (`contracts/mocks/**`, `contracts/v2/newDeployments/**`) unless tied to a production-reachable control path.

## Conclusion

- Manual audit confirms one deterministic, witness-backed vulnerability with direct proof-route integrity and liveness impact for ALGateway-verified rollups.

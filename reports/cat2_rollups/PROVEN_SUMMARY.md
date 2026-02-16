# CAT2 Proven Vulnerability Summary

Date: `2026-02-16`  
Category: `cat2_rollups`

## Repo-by-Repo Outcome

1. `arbitrum`: `NOT CONFIRMED` (index repo only, no in-repo protocol code).
2. `base-contracts`: `CONFIRMED` (1 finding). See `reports/cat2_rollups/base-contracts/report.md`.
3. `era-boojum`: `CONFIRMED` (1 finding). See `reports/cat2_rollups/era-boojum/report.md`.
4. `era-contracts`: `CONFIRMED` (1 finding). See `reports/cat2_rollups/era-contracts/report.md`.
5. `linea-contracts`: `CONFIRMED` (1 finding). See `reports/cat2_rollups/linea-contracts/report.md`.
6. `mantle`: `CONFIRMED` (4 findings), `LIKELY` (0 findings). See `reports/cat2_rollups/mantle/report.md`.
7. `optimism`: `CONFIRMED` (1 finding). See `reports/cat2_rollups/optimism/report.md`.
8. `scroll-contracts`: `CONFIRMED` (1 finding). See `reports/cat2_rollups/scroll-contracts/report.md`.
9. `stone-prover`: `NOT CONFIRMED` (no baseline findings; no exploit witness).
10. `taiko-contracts`: `CONFIRMED` (1 finding). See `reports/cat2_rollups/taiko-contracts/report.md`.
11. `taiko-mono`: `CONFIRMED` (2 findings). See `reports/cat2_rollups/taiko-mono/report.md`.
12. `zkevm-circuits`: `CONFIRMED` (1 finding). See `reports/cat2_rollups/zkevm-circuits/report.md`.
13. `zkevm-contracts`: `CONFIRMED` (1 finding). See `reports/cat2_rollups/zkevm-contracts/report.md`.

## Confirmed Findings

- `F-BASE-01` (`High`): `BalanceTracker.initialize(...)` can be first-called by an attacker in the proxy upgrade window, allowing attacker-controlled fee routing and locking out legitimate initialization.
- `F-ERA-01` (`High`): `resolver_box` page reservation logic can commit beyond page allocation for oversized reservations, creating memory safety risk.
- `F-ERAC-01` (`High`): `ChainRegistrar.initialize(...)` first-caller takeover can capture owner rights and redirect non-ETH proposer top-up transfers to attacker-controlled deployer.
- `F-LINEA-01` (`Critical`): `LineaRollup.initializeParentShnarfsAndFinalizedState(...)` is externally callable as `reinitializer(5)`, enabling permissionless `shnarfFinalBlockNumbers` poisoning and rollup submission DoS.
- `F-SCROLL-01` (`Critical`): `ScrollChain.initialize(...)` can be first-called by an attacker in non-atomic upgrade flow, enabling owner capture and privileged rollup control actions.
- `F-TAIKO-01` (`Medium`): `TrailblazersBadgesS2.getBadge(uint256)` uses an inverted existence boundary check, allowing nonexistent token IDs to be returned as zero-value structs while reverting for valid older minted IDs.
- `F-TAIKOMONO-01` (`Medium`): `TrailblazersBadgesS2.getBadge(uint256)` uses the same inverted existence boundary check in `taiko-mono`, allowing nonexistent token IDs to appear valid while valid older IDs can revert.
- `F-TAIKOMONO-02` (`Medium`): `EventRegister.initialize()` is first-caller in a non-atomic deploy-then-initialize flow, allowing attacker `EVENT_MANAGER_ROLE`/owner capture and persistent attacker-created event-state injection before recovery.
- `F-ZKEVM-01` (`High`): `aggregator::decode_bytes` panics on malformed `blob_bytes`, allowing malformed proving-task payloads to crash batch proving sanity path instead of returning a recoverable error.
- `F-ZKEVMC-01` (`Critical`): `AggLayerGateway.initialize(...)` can be first-called by an attacker in a non-atomic proxy deployment/upgrade flow, allowing attacker-controlled admin and verifier-route role capture over ALGateway proof validation paths.
- `F-OPT-01` (`High`): `ProtocolVersions.initialize(...)` can be first-called by an attacker in a non-atomic proxy upgrade flow, enabling owner capture and protocol-version control.
- `F-MAN-01` (`Critical`): Defender can rewrite challenger win in `Challenge.completeChallenge(bool)`.
- `F-MAN-02` (`High`): `Rollup.createAssertion` auto-confirms assertions in the same transaction.
- `F-MAN-03` (`High`): `Rollup.completeChallenge` deadlocks unless challenge address is explicitly operator-registered.
- `F-MAN-04` (`High`): `Rollup.challengeAssertion` does not bind players to supplied assertion IDs, enabling unrelated victim challenge/griefing (and slashing when settlement path is enabled).
- Independent specialist fuzz proofs now attached:
- `F-BASE-01`: Forge + Medusa + Echidna + Halmos counterexamples (`f_base_01_initializer_hijack_forge_test.txt`, `f_base_01_medusa_failfast_30s.txt`, `f_base_01_echidna_30s.txt`, `f_base_01_halmos.txt`).
- `F-ERA-01`: Deterministic Rust harness witness (`f_era_01_resolver_page_overflow_cargo_test.txt`).
- `F-ZKEVM-01`: Deterministic Rust harness witness (`f_zkevm_01_decode_bytes_panic_cargo_test.txt`).
- `F-ZKEVMC-01`: Forge counterexample (`f_zkevmc_01_agglayer_gateway_init_hijack_forge_test.txt`).
- `F-ERAC-01`: Forge + Medusa + Echidna + Halmos counterexamples (`f_erac_01_chain_registrar_init_hijack_forge_test.txt`, `f_erac_01_medusa_failfast_30s.txt`, `f_erac_01_echidna_30s.txt`, `f_erac_01_halmos.txt`).
- `F-LINEA-01`: Forge + Medusa + Echidna + Halmos counterexamples (`f_linea_01_reinitializer_dos_forge_test.txt`, `f_linea_01_medusa_failfast_30s.txt`, `f_linea_01_echidna_30s.txt`, `f_linea_01_halmos.txt`).
- `F-SCROLL-01`: Forge + Medusa + Echidna + Halmos counterexamples (`f_scroll_01_scrollchain_init_hijack_forge_test.txt`, `f_scroll_01_medusa_failfast_30s.txt`, `f_scroll_01_echidna_30s.txt`, `f_scroll_01_halmos.txt`).
- `F-TAIKO-01`: Forge + Medusa + Echidna + Halmos counterexamples (`f_taiko_01_getbadge_boundary_forge_test.txt`, `f_taiko_01_medusa_failfast_30s.txt`, `f_taiko_01_echidna_30s.txt`, `f_taiko_01_halmos.txt`).
- `F-TAIKOMONO-01`: Forge + Medusa + Echidna + Halmos counterexamples (`f_taikomono_01_getbadge_boundary_forge_test.txt`, `f_taikomono_01_medusa_failfast_30s.txt`, `f_taikomono_01_echidna_30s.txt`, `f_taikomono_01_halmos.txt`).
- `F-TAIKOMONO-02`: Forge witness (`f_taikomono_02_eventregister_init_hijack_forge_test.txt`).
- `F-OPT-01`: Forge + Medusa + Echidna + Halmos counterexamples (`f_opt_01_protocol_versions_init_hijack_forge_test.txt`, `f_opt_01_medusa_failfast_30s.txt`, `f_opt_01_echidna_30s.txt`, `f_opt_01_halmos.txt`).
- `F-MAN-01`: Echidna + Halmos counterexamples (`f_man_01_echidna_30s.txt`, `f_man_01_halmos.txt`).
- `F-MAN-03`: Medusa + Echidna + Halmos counterexamples (`f_man_03_medusa_failfast_30s.txt`, `f_man_03_echidna_30s.txt`, `f_man_03_halmos.txt`).
- `F-MAN-04`: Forge + Medusa + Echidna + Halmos counterexamples (`f_man_04_challenge_binding_forge_test.txt`, `f_man_04_medusa_failfast_30s.txt`, `f_man_04_echidna_30s.txt`, `f_man_04_halmos.txt`).

Primary reports:
- `reports/cat2_rollups/base-contracts/report.md`
- `reports/cat2_rollups/era-boojum/report.md`
- `reports/cat2_rollups/era-contracts/report.md`
- `reports/cat2_rollups/linea-contracts/report.md`
- `reports/cat2_rollups/mantle/report.md`
- `reports/cat2_rollups/optimism/report.md`
- `reports/cat2_rollups/scroll-contracts/report.md`
- `reports/cat2_rollups/taiko-contracts/report.md`
- `reports/cat2_rollups/taiko-mono/report.md`
- `reports/cat2_rollups/zkevm-circuits/report.md`
- `reports/cat2_rollups/zkevm-contracts/report.md`

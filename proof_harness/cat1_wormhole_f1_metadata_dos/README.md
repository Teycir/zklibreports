# Wormhole W1 Proof Harness (`metadata-method DoS`)

This harness reproduces `W1` in:

- `reports/cat1_bridges/wormhole/manual_audit.md`

## What it proves

- Bug model mirrors Wormhole metadata reads (`staticcall` + unchecked `abi.decode`).
- Tokens omitting metadata methods (`decimals/symbol/name`) deterministically revert in attestation and transfer metadata paths.
- Fixed model demonstrates one safe strategy: success/length checks with fallback defaults.

## Layout

- `src/BridgeMetadataCompatHarness.sol`
  - `BridgeMetadataBugModel`
  - `BridgeMetadataFixedModel`
  - `MockNoMetadataTokenW`
  - `MockMetadataTokenW`
- `src/MedusaBridgeMetadataCompatHarness.sol`
  - Stateful specialist-fuzz harness for bug/fix properties.
- `test/BridgeMetadataCompat.t.sol`
  - Deterministic witness + fuzz witness.

## Run

```powershell
cd proof_harness/cat1_wormhole_f1_metadata_dos
forge test -vv --match-path test/BridgeMetadataCompat.t.sol
forge test -vv --match-path test/BridgeMetadataCompat.t.sol --fuzz-runs 5000
```

Expected:
- bug path reverts for no-metadata token
- fixed path tolerates no-metadata token

## Medusa run

```powershell
cd proof_harness/cat1_wormhole_f1_metadata_dos
powershell -NoProfile -ExecutionPolicy Bypass -File ..\..\scripts\medusa.ps1 init
powershell -NoProfile -ExecutionPolicy Bypass -File ..\..\scripts\medusa.ps1 fuzz --compilation-target . --target-contracts MedusaBridgeMetadataCompatHarness --seq-len 10 --workers 4 --timeout 30 --fail-fast --no-color --log-level info
```

Expected:
- `property_nonstandard_token_attest_should_not_fail` fails
- `property_nonstandard_token_transfer_should_not_fail` fails
- `property_fixed_model_tolerates_missing_metadata` passes

## Echidna cross-check

```powershell
cd proof_harness/cat1_wormhole_f1_metadata_dos
powershell -NoProfile -ExecutionPolicy Bypass -File ..\..\scripts\echidna.ps1 src/MedusaBridgeMetadataCompatHarness.sol --contract MedusaBridgeMetadataCompatHarness --test-mode property --seq-len 10 --test-limit 20000 --timeout 30 --format text --corpus-dir echidna-corpus-w1-formal
```

Expected:
- `echidna_nonstandard_token_attest_should_not_fail` fails quickly.


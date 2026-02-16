# Exhaustion Addendum — taiko-contracts

This addendum records why the CAT2 pass on `taiko-contracts` is considered exhausted for the current methodology.

## Exhaustion criteria used

- Enumerated Solidity production contracts and deployment scripts.
- Built high-signal lead maps for:
- initialization / reinitialization / upgrade boundaries
- auth gates and privileged state transitions
- raw external/delegate/static calls
- signature verification surfaces
- unchecked math / assembly hot spots
- Promoted only findings with deterministic witness and specialist fuzz/symbolic support.

## What was exhaustively checked

- Protocol core paths:
- `Bridge`, vault family, `SignalService`, `Inbox`, preconf modules, L2 anchor/router surfaces.
- Deployment/upgrade flows:
- `packages/protocol/script/**` checked for non-atomic proxy init and first-caller windows.
- NFT package paths:
- high-privilege and initialization-sensitive contracts (`trailblazers`, `party-ticket`, `taikoon`, `snaefell`, `profile`, `eventRegister`).

## Result

- One finding reached proof threshold:
- `F-TAIKO-01` (`Medium`), proven with forge + medusa + echidna + halmos.
- No additional leads reached unprivileged exploit witness quality after triage.

## Artifact index

- Lead maps/counts: `reports/cat2_rollups/taiko-contracts/manual_artifacts/`
- Finding proof outputs: `reports/cat2_rollups/taiko-contracts/manual_artifacts/f_taiko_01_*`
- Harness: `proof_harness/cat2_taiko_f1_getbadge_boundary/`

## Closeout statement

For CAT2 scope and the available source/deployment evidence, this repo is closed as exhausted with one confirmed finding.

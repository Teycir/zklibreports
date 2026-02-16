# Exhaustion Addendum — taiko-mono

This addendum records why the CAT2 pass on `taiko-mono` is considered exhausted for the current methodology.

## Exhaustion criteria used

- Enumerated Solidity production contracts and deployment scripts.
- Built lead maps for:
- initialization / reinitialization / upgrade boundaries
- auth-gated and owner/operator-sensitive operations
- low-level call surfaces
- signature recovery / authorization paths
- unchecked / assembly regions
- Promoted only findings with deterministic witness and specialist fuzz/symbolic support.

## What was exhaustively checked

- Protocol core paths under `packages/protocol/contracts/**`.
- Deployment and governance scripts under `packages/protocol/script/**`.
- NFT and campaign contracts under `packages/nfts/contracts/**`.

## Result

- One finding reached proof threshold:
- `F-TAIKOMONO-01` (`Medium`), proven with forge + medusa + echidna + halmos.
- No additional leads reached unprivileged exploit witness quality after triage.

## Artifact index

- Lead maps/counts: `reports/cat2_rollups/taiko-mono/manual_artifacts/`
- Finding proof outputs: `reports/cat2_rollups/taiko-mono/manual_artifacts/f_taikomono_01_*`
- Harness: `proof_harness/cat2_taiko_f1_getbadge_boundary/`

## Closeout statement

For CAT2 scope and available source/deployment evidence, this repo is closed as exhausted with one confirmed finding.

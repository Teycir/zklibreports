# Audit Methodology (Formal)

This is the default operating method for vulnerability work in this repo.

## Objective

Produce only witness-backed findings. Tool output is lead generation, not proof.

## Definitions

- `Lead`: a suspicious pattern from static scan, dependency scan, or manual review.
- `Hypothesis`: a concrete claim we try to prove or falsify.
- `Witness`: reproducible evidence (test, exploit trace, counterexample, crash, or formal model).
- `Finding`: a hypothesis promoted after witness validation and impact confirmation.

## Workflow

1. Scope lock:
- Record exact target path and commit hash.
- Record in-scope contracts/modules and explicit non-goals.

2. Invariant extraction:
- Write 3-10 security invariants for auth, value conservation, and state consistency.
- Rank hypotheses by impact and probability.

3. Harness design:
- Build minimal harnesses that isolate one invariant each.
- Prefer stateful action-based harness APIs (`action_*`, `property_*`).

4. Multi-engine proving:
- Run deterministic tests (Foundry/Hardhat) first.
- Run specialist stateful fuzzing (Medusa).
- Run independent cross-check (Echidna) on the same property.

5. Artifact capture:
- Capture every run with commands and raw outputs into `manual_artifacts`.
- Store command, timeout, and exit code metadata.

6. Promotion gate:
- Promote to finding only when impact and exploit path are explicit.
- If witness exists but impact is unclear, keep as `LIKELY` until clarified.

## Proof Classes

- `FORMALLY CONFIRMED`: solver or formal counterexample plus concrete impact.
- `CONFIRMED`: deterministic repro and clear exploit path.
- `LIKELY`: strong evidence, missing one of reproducibility, reachability, or impact clarity.
- `NOT CONFIRMED`: lead without witness.

## Required Evidence Per Finding

- Affected files/functions.
- Root cause in one sentence.
- Step-by-step witness sequence.
- Deterministic test command and output artifact.
- Specialist fuzz artifact (Medusa).
- Independent cross-check artifact (Echidna or equivalent), when feasible.
- Clear impact statement and realistic attacker preconditions.

## Artifact Contract

- Location:
- `reports/<category>/<repo>/manual_artifacts/`

- Naming:
- `<finding_id>_<campaign>_<engine>_<window>.txt`
- Examples:
- `f4_governance_takeover_forge_test.txt`
- `f4_medusa_governance_takeover_30s.txt`

- Metadata:
- For specialist fuzz campaigns, include command and exit status metadata JSON.

## Specialist Fuzz Standard (EVM)

- Harness requirements:
- At least one mutating action.
- At least one negative property invariant.

- Campaign defaults:
- `seq-len=10`
- `workers=4`
- `timeout=30`
- Medusa with `--fail-fast`.
- Echidna with `--test-mode property`.
- Use isolated Echidna corpus dirs per finding (for example `echidna-corpus-f6`) to avoid cross-campaign replay noise.

- Runner:
- `scripts/evm_specialist_campaign.ps1`
- Prefer `-EchidnaCorpusDir echidna-corpus-<finding>` when using the runner.

## Reporting Standard

- Manual report must contain:
- protocol snapshot
- trust assumptions
- critical invariants
- proven findings
- open hypotheses
- immediate next actions

- Every finding section should follow `docs/templates/FINDING_TEMPLATE.md`.

## Stop Conditions

Do not claim a vulnerability when any of these are missing:
- reproducible witness
- exploit path
- impact statement

If a run fails due tooling instability, log it explicitly and rerun with bounded fallback settings.

## Repo Exhaustion And Handoff

- Stay on the current repo until it is `exhausted` by evidence, not by time.
- `Exhausted` means all currently ranked high/medium hypotheses are either:
- promoted to findings with witness artifacts, or
- explicitly falsified/not confirmed with witness artifacts.
- Once exhausted, move immediately to the next repo in that category roadmap order.
- Record handoff in the current repo's `manual_audit.md` next-actions section.

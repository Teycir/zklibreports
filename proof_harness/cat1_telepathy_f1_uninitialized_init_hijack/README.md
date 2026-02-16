# Telepathy F1 Proof Harness (`uninitialized init hijack`)

This harness validates a deployment-time trust boundary for `TelepathyRouterV2`-style initialization:

- If a UUPS proxy is deployed uninitialized (`_data = ""`) and `initialize(...)` is sent later, the first caller can seize `timelock`/`guardian` roles.
- Role capture lets the attacker set verifier routing and execute forged messages in the model.
- Fixed controls are:
  - trusted first initialization (no attacker first-call window), and
  - preserving timelock ownership over default verifier configuration.

## Layout

- `src/TelepathyInitHijackHarness.sol`
  - `TelepathyRouterV2Model`
  - `AlwaysTrueVerifier`
  - `AlwaysFalseVerifier`
  - `MinimalHandler`
- `test/TelepathyInitHijack.t.sol`
  - deterministic and fuzz witnesses for bug/fixed models.

## Forge witness run

```powershell
cd proof_harness/cat1_telepathy_f1_uninitialized_init_hijack
forge test -vv --match-path test/TelepathyInitHijack.t.sol
```

## Forge deeper fuzz run

```powershell
cd proof_harness/cat1_telepathy_f1_uninitialized_init_hijack
forge test -vv --match-path test/TelepathyInitHijack.t.sol --fuzz-runs 5000
```

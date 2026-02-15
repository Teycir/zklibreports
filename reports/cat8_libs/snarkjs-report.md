# Custom Vulnerability Report: snarkjs

## Scope
- Audit time (UTC): 2026-02-15 18:17:00
- Repository path: \\VBOXSVR\elements\Repos\zk0d\cat_8_libs\snarkjs
- Language profile: Node.js
- Git branch: master
- Git commit: 9a8f1c0
- Upstream: origin/master
- Upstream delta: behind=0 ahead=0
- Remote: https://github.com/iden3/snarkjs.git

## Method
- Fast skimmer triage over executable paths (tests/docs excluded from pattern scans).
- Dependency advisory scan when lockfile/tooling was available.
- Phase 2 reachability analysis for advisory paths.
- External formal circuit checks using `circom --inspect` and `circomspect`.
- No issue is marked CONFIRMED unless reproducible witness evidence exists.

## Tooling Results
- npm audit --omit=dev: total=2, high=1, moderate=0, low=1
- npm ls jsonpath --omit=dev --all: empty installed tree
- npm ls brace-expansion --omit=dev --all: empty installed tree

## Classification Summary
- FORMALLY CONFIRMED: 0
- CONFIRMED: 0
- LIKELY: 0
- NOT CONFIRMED (skimmer hints): 15 matches across 2 pattern classes

## Phase 2 Reachability Analysis
- Lockfile shows `jsonpath` enters through `bfj` and `brace-expansion` enters through `ejs -> jake -> minimatch`.
- `snarkjs` source uses `bfj.write` only (`cli.js`); no `bfj.match`/`jsonpath` call sites were found.
- `bfj` source for `write` imports `streamify` and does not import `jsonpath`; `jsonpath` is used in `bfj/src/match.js`.
- No executable evidence path was found showing attacker-controlled JSONPath or glob pattern evaluation in `snarkjs`.
- Result: advisory presence is real, but exploitability in audited runtime paths is NOT CONFIRMED.

## Likely Findings
- None in this pass.

## Not Confirmed Notes
- [NOT CONFIRMED] npm `jsonpath` advisory chain (GHSA-6c59-mwgh-r2x6 / GHSA-87r5-mp6g-5w5j): present in lockfile via `bfj`, but no reachable `bfj.match` usage was found in executable `snarkjs` paths.
- [NOT CONFIRMED] npm `brace-expansion` advisory (GHSA-v6h2-p8h4-qcjw): present transitively, but no reachable unsafe glob handling path was evidenced in audited runtime code.

## Skimmer Hints (Not Confirmed)
### Security-related TODO or FIXME
- Match count: 12
- Sample evidence:
```text
\\VBOXSVR\elements\Repos\zk0d\cat_8_libs\snarkjs\build\snarkjs.js:45442:        //TODO check!!!!
\\VBOXSVR\elements\Repos\zk0d\cat_8_libs\snarkjs\build\snarkjs.js:47212:        // TODO ??? Compute wr^3 and check if it matches with w
\\VBOXSVR\elements\Repos\zk0d\cat_8_libs\snarkjs\cli.js:785:    // TODO Verify
```

### Weak randomness usage
- Match count: 3
- Sample evidence:
```text
\\VBOXSVR\elements\Repos\zk0d\cat_8_libs\snarkjs\build\snarkjs.js:607:                    array[i] = (Math.random()*4294967296)>>>0;
\\VBOXSVR\elements\Repos\zk0d\cat_8_libs\snarkjs\build\snarkjs.js:22968:                    array[i] = (Math.random()*4294967296)>>>0;
\\VBOXSVR\elements\Repos\zk0d\cat_8_libs\snarkjs\smart_contract_tests\package-lock.json:6589:      "deprecated": "Please upgrade to version 7 or higher ..."
```

## Reproduction Commands
- cmd /c pushd \\VBOXSVR\elements\Repos\zk0d\cat_8_libs\snarkjs && npm audit --json --omit=dev
- cmd /c pushd \\VBOXSVR\elements\Repos\zk0d\cat_8_libs\snarkjs && npm ls jsonpath --omit=dev --all
- cmd /c pushd \\VBOXSVR\elements\Repos\zk0d\cat_8_libs\snarkjs && npm ls brace-expansion --omit=dev --all
- rg -n -S --hidden --glob !**/.git/** --glob !**/node_modules/** --glob !**/build/** bfj \\VBOXSVR\elements\Repos\zk0d\cat_8_libs\snarkjs

## External Tool Deep Scan (2026-02-15 20:36 UTC)

### Tooling Results
- gitleaks: 5 findings, all `generic-api-key` rule hits in `src/fflonk_setup.js` and mirrored build outputs.
- npm audit (`--omit=dev`): total=2 (`high=1` `jsonpath`, `low=1` `brace-expansion`).
- npm audit (full): total=4 (`high=1`, `moderate=1`, `low=2`) across `jsonpath`, `js-yaml`, `brace-expansion`, `diff`.
- All npm findings are transitive (`isDirect=false`).

### Deep Assessment
- [NOT CONFIRMED] gitleaks hits are false positives on constant identifiers and generated build mirrors, not secrets.
- [NOT CONFIRMED] Previous reachability pass still applies for `jsonpath` chain: advisory presence exists, but no executable `bfj.match` path was evidenced in audited runtime paths.

### Artifacts
- `C:\Users\vboxuser\Desktop\Repos\zklibreports\artifacts\gitleaks\snarkjs.json`
- `C:\Users\vboxuser\Desktop\Repos\zklibreports\artifacts\npm-audit\snarkjs-omit-dev.json`
- `C:\Users\vboxuser\Desktop\Repos\zklibreports\artifacts\npm-audit\snarkjs-full.json`

## External Formal Circuit Validation (2026-02-15 22:04 UTC)

### Tooling Results
- `circom --inspect` over 5 `.circom` test circuits: compile success=3, parse failure=2 (legacy `signal private input` syntax under circom2 parser).
- `circomspect` over same 5 circuits: notes only (`CS0003`/`CS0004`) on arithmetic/comparison semantics; no exploit witness produced.

### Deep Assessment
- [NOT CONFIRMED] `test/circuit/circuit.circom` and `test/plonk_circuit/circuit.circom` fail parsing under circom2 syntax rules, so no formal exploit claim can be made from these files in this pass.
- [NOT CONFIRMED] `test/circuit2`, `test/fflonk`, and `test/groth16` compile, but `circomspect` outputs are analysis notes (field overflow/comparison semantics) without proof of an exploitable runtime security issue in `snarkjs`.
- Classification unchanged: no CONFIRMED vulnerability.

### Artifacts
- `C:\Users\vboxuser\Desktop\Repos\zklibreports\artifacts\formal_clean\circuit-circuit\circom-inspect.txt`
- `C:\Users\vboxuser\Desktop\Repos\zklibreports\artifacts\formal_clean\circuit-circuit\circomspect.txt`
- `C:\Users\vboxuser\Desktop\Repos\zklibreports\artifacts\formal_clean\plonk_circuit-circuit\circom-inspect.txt`
- `C:\Users\vboxuser\Desktop\Repos\zklibreports\artifacts\formal_clean\plonk_circuit-circuit\circomspect.txt`
- `C:\Users\vboxuser\Desktop\Repos\zklibreports\artifacts\formal_clean\circuit2-circuit\circom-inspect.txt`
- `C:\Users\vboxuser\Desktop\Repos\zklibreports\artifacts\formal_clean\circuit2-circuit\circomspect.txt`
- `C:\Users\vboxuser\Desktop\Repos\zklibreports\artifacts\formal_clean\fflonk-circuit\circom-inspect.txt`
- `C:\Users\vboxuser\Desktop\Repos\zklibreports\artifacts\formal_clean\fflonk-circuit\circomspect.txt`
- `C:\Users\vboxuser\Desktop\Repos\zklibreports\artifacts\formal_clean\groth16-circuit\circom-inspect.txt`
- `C:\Users\vboxuser\Desktop\Repos\zklibreports\artifacts\formal_clean\groth16-circuit\circomspect.txt`

## External Formal Weak-Safety / Uniqueness Proofs (2026-02-15 22:35 UTC)

### Tooling Results
- CIVER (`civer_circom --check_safety`) on `.circom` sources:
  - `test/fflonk/circuit.circom`: weak-safety **proven** (`verified=1 failed=0 timeout=0`) with `--verification_timeout 60000`.
  - `test/circuit2/circuit.circom`: **timeout** (`verified=0 failed=0 timeout=1`) even at `--verification_timeout 300000`.
  - `test/groth16/circuit.circom`: **timeout** (`verified=0 failed=0 timeout=1`) at `--verification_timeout 60000`.
  - `test/circuit/circuit.circom` and `test/plonk_circuit/circuit.circom`: **parse errors** under CIVER circom `2.1.6` parser (legacy syntax).
- Picus (`picus-dpvl-uniqueness.rkt --weak --solver cvc5`) on generated R1CS (from `circom 2.2.3` build artifacts):
  - `circuit2-circuit`: weak uniqueness `safe`
  - `fflonk-circuit`: weak uniqueness `safe`
  - `groth16-circuit`: weak uniqueness `safe`

### Deep Assessment
- [NOT CONFIRMED] CIVER timeouts are not failures; they do not constitute a proof of unsafety. For the timed-out cases, Picus (independent solver stack + R1CS) produced a `safe` result under weak-uniqueness on the compiled constraint system.
- [CONFIRMED - circuit property only] `fflonk` test circuit weak-safety is formally proven under CIVER (subject to CIVER model and timeout parameters).
- No repo-level security vulnerability is claimed from these proofs; these are circuit-level determinism/uniqueness validations on test circuits.

### Artifacts
- `C:\Users\vboxuser\Desktop\Repos\zklibreports\artifacts\civer_clean\snarkjs-circuits\fflonk-circuit.txt`
- `C:\Users\vboxuser\Desktop\Repos\zklibreports\artifacts\civer_clean\snarkjs-circuits\circuit2-circuit.txt`
- `C:\Users\vboxuser\Desktop\Repos\zklibreports\artifacts\civer_clean\snarkjs-circuits\groth16-circuit.txt`
- `C:\Users\vboxuser\Desktop\Repos\zklibreports\artifacts\civer_clean\snarkjs-circuits\circuit-circuit.txt`
- `C:\Users\vboxuser\Desktop\Repos\zklibreports\artifacts\civer_clean\snarkjs-circuits\plonk_circuit-circuit.txt`
- `C:\Users\vboxuser\Desktop\Repos\zklibreports\artifacts\picus\snarkjs-r1cs\circuit2-circuit-cvc5.txt`
- `C:\Users\vboxuser\Desktop\Repos\zklibreports\artifacts\picus\snarkjs-r1cs\fflonk-circuit-cvc5.txt`
- `C:\Users\vboxuser\Desktop\Repos\zklibreports\artifacts\picus\snarkjs-r1cs\groth16-circuit-cvc5.txt`

# ZK Library Audit Roadmap

- Scope root: \\VBOXSVR\elements\Repos\zk0d\cat8_libs
- Session start (UTC): 2026-02-15 18:09:08
- Last update (UTC): 2026-02-15 22:41:52
- Method: Fast skimmer baseline + external-tool deep scans (gitleaks, cargo-deny, cargo-audit, npm audit, govulncheck, gosec, cppcheck, circom, circomspect, civer, picus, z3, cvc5, cbmc) with proof gate (no vulnerability claim without witness + repro).
- Classification: FORMALLY CONFIRMED / CONFIRMED / LIKELY / NOT CONFIRMED.

## Repo Status
| Repo | Status | Report |
|---|---|---|
| arkworks-algebra | Completed + External Deep Scan (confirmed=0, likely=0, hints=671) | [arkworks-algebra-report.md](reports/cat8_libs/arkworks-algebra-report.md) |
| arkworks-curves | Completed + External Deep Scan (confirmed=0, likely=0, hints=271) | [arkworks-curves-report.md](reports/cat8_libs/arkworks-curves-report.md) |
| arkworks-groth16 | Completed + External Deep Scan (confirmed=0, likely=0, hints=51) | [arkworks-groth16-report.md](reports/cat8_libs/arkworks-groth16-report.md) |
| arkworks-marlin | Completed + External Deep Scan (confirmed=0, likely=0, hints=76) | [arkworks-marlin-report.md](reports/cat8_libs/arkworks-marlin-report.md) |
| bellman | Completed + External Deep Scan (confirmed=0, likely=0, hints=239) | [bellman-report.md](reports/cat8_libs/bellman-report.md) |
| circom | Completed + External Deep Scan (confirmed=0, likely=0, hints=691) | [circom-report.md](reports/cat8_libs/circom-report.md) |
| gnark | Completed + External Deep Scan (confirmed=0, likely=0, hints=1175) | [gnark-report.md](reports/cat8_libs/gnark-report.md) |
| libsnark | Completed + External Deep Scan (confirmed=0, likely=0, hints=9) | [libsnark-report.md](reports/cat8_libs/libsnark-report.md) |
| snarkjs | Completed + External Deep Scan (confirmed=0, likely=0, hints=15) | [snarkjs-report.md](reports/cat8_libs/snarkjs-report.md) |

## Progress Log
- 2026-02-15 18:09:20 UTC | arkworks-algebra | Completed (confirmed=0, likely=0, hints=671)
- 2026-02-15 18:09:28 UTC | arkworks-curves | Completed (confirmed=0, likely=0, hints=271)
- 2026-02-15 18:09:29 UTC | arkworks-groth16 | Completed (confirmed=0, likely=0, hints=51)
- 2026-02-15 18:09:30 UTC | arkworks-marlin | Completed (confirmed=0, likely=0, hints=76)
- 2026-02-15 18:09:34 UTC | bellman | Completed (confirmed=0, likely=1, hints=239)
- 2026-02-15 18:09:41 UTC | circom | Completed (confirmed=0, likely=1, hints=691)
- 2026-02-15 18:09:52 UTC | gnark | Completed (confirmed=0, likely=0, hints=1175)
- 2026-02-15 18:09:57 UTC | libsnark | Completed (confirmed=0, likely=0, hints=9)
- 2026-02-15 18:09:59 UTC | snarkjs | Completed (confirmed=0, likely=2, hints=15)
- 2026-02-15 18:17:00 UTC | snarkjs | Phase2 reachability complete (confirmed=0, likely=0)
- 2026-02-15 18:17:00 UTC | circom | Phase2 dependency precondition check complete (confirmed=0, likely=0)
- 2026-02-15 18:17:00 UTC | bellman | Phase2 dependency-edge check complete (confirmed=0, likely=0)
- 2026-02-15 18:37:23 UTC | toolchain | Installed Go, CMake, Cppcheck, LLVM; configured govulncheck
- 2026-02-15 18:37:23 UTC | gnark | Phase2 govulncheck completed (findings=0)
- 2026-02-15 18:37:23 UTC | libsnark | Phase2 cppcheck completed (no confirmed vulnerabilities)
- 2026-02-15 18:47:25 UTC | zk-fuzzer build check | Toolchain issue resolved; build now fails on repo source state (`crates/zk-backends/src/lib.rs` missing modules `util` and `fixture`)
- 2026-02-15 19:25:11 UTC | toolchain | Added side-by-side portable CMake 3.31.8 at `C:\Tools\cmake-3.31.8`
- 2026-02-15 19:25:11 UTC | zk-fuzzer clean profile | Forced Cargo to CMake 3.31.8 (`CMAKE` + PATH), `cargo clean -p z3-sys` succeeded, build again reaches source-level module errors only
- 2026-02-15 20:06:03 UTC | repo sync | Fetched all remotes; all 9 repos at ahead=0/behind=0. Local pre-existing dirty files remain in `arkworks-algebra` and `arkworks-curves` (license files).
- 2026-02-15 20:16:39 UTC | toolchain | Installed `osv-scanner` v2.3.3 for external dependency scanning.
- 2026-02-15 20:36:43 UTC | arkworks-algebra | External deep scan complete (cargo-deny/cargo-audit/gitleaks): likely=0
- 2026-02-15 20:36:43 UTC | arkworks-curves | External deep scan complete (cargo-deny/cargo-audit/gitleaks): likely=1 (`RUSTSEC-2025-0055`)
- 2026-02-15 20:36:43 UTC | arkworks-groth16 | External deep scan complete (cargo-deny/cargo-audit/gitleaks): likely=0
- 2026-02-15 20:36:43 UTC | arkworks-marlin | External deep scan complete (cargo-deny/cargo-audit/gitleaks): likely=1 (`RUSTSEC-2025-0055`)
- 2026-02-15 20:36:43 UTC | bellman | External deep scan complete (cargo-deny/cargo-audit/gitleaks): likely=0
- 2026-02-15 20:36:43 UTC | circom | External deep scan complete (cargo-deny/cargo-audit/gitleaks): likely=0
- 2026-02-15 20:36:43 UTC | gnark | External deep scan complete (govulncheck/gosec/gitleaks): likely=0
- 2026-02-15 20:36:43 UTC | libsnark | External deep scan complete (cppcheck/gitleaks): likely=0
- 2026-02-15 20:36:43 UTC | snarkjs | External deep scan complete (npm audit/gitleaks + reachability recheck): likely=0
- 2026-02-15 20:39:20 UTC | cleanup | Removed transient `Cargo.lock` files generated during scanning in non-lockfile rust repos (`arkworks-algebra`, `arkworks-curves`, `arkworks-groth16`, `arkworks-marlin`).
- 2026-02-15 20:50:05 UTC | proof gate | Enforced evidence-only classification: downgraded `arkworks-curves` and `arkworks-marlin` `RUSTSEC-2025-0055` from likely to NOT CONFIRMED (no exploit witness/repro path).
- 2026-02-15 20:50:58 UTC | cleanup | Removed transient `Cargo.lock` files regenerated by proof-path commands in `arkworks-curves` and `arkworks-marlin`.
- 2026-02-15 22:00:00 UTC | toolchain | Installed external analysis stack outside audited repos: `snarkjs@0.7.6`, `circom 2.2.3`, `circomspect`, `z3 4.15.8`, `cvc5 1.3.2`.
- 2026-02-15 22:04:00 UTC | snarkjs | Formal circuit pass on 5 `.circom` targets completed (`circom --inspect`: success=3, parser-legacy failures=2; `circomspect`: notes only, no exploit witness).
- 2026-02-15 22:06:00 UTC | proof harness | Standalone repro confirmed `RUSTSEC-2025-0055` behavior delta (`tracing-subscriber 0.2.25` emits raw OSC/BEL control bytes; `0.3.22` escapes payload). Repo-level status for `arkworks-curves`/`arkworks-marlin` remains NOT CONFIRMED due to no in-repo trigger path.
- 2026-02-15 22:23:00 UTC | toolchain | Installed and built `civer_circom` (`v2.1.6`) at `C:\Tools\circom_civer\target\release\civer_circom.exe` (resolved build blockers: CMake PATH + Python `setuptools/distutils`).
- 2026-02-15 22:35:00 UTC | snarkjs | CIVER + Picus deep validation complete: `fflonk` weak-safety formally proven by CIVER; `circuit2` and `groth16` timed out in CIVER but `Picus(cvc5)` returned weak-uniqueness `safe`; `circuit` and `plonk_circuit` remain parser-legacy failures.
- 2026-02-15 22:39:00 UTC | toolchain | Verified CBMC toolchain availability at `C:\Program Files\cbmc\bin` (`cbmc 5.95.1`, `goto-analyzer 5.95.1`, `goto-instrument 5.95.1`, `jbmc 5.95.1`).



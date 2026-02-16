# Tool Rules and Status

This document lists currently approved tools and baseline usage rules.

## Current Tool Status

| Tool | Status | Version | Category |
|------|--------|---------|----------|
| Circom | APPROVED | v2.2.3 | ZK/Circom |
| snarkjs | APPROVED | v0.7.6 | ZK/Circom |
| zkFuzz | APPROVED | v2.2.1 | ZK/Circuits |
| Picus | APPROVED | Latest | ZK/Circuits |
| Halo2 | APPROVED | v0.3.2 (library) | ZK/Circuits |
| Medusa | APPROVED | host-installed | Solidity/EVM fuzzing |
| Echidna | APPROVED | host-installed | Solidity/EVM fuzzing |

## Status Definitions

- `APPROVED`: default tool for production audits.
- `LIMITED`: usable only in constrained scenarios.
- `DEPRECATED`: do not use for new audit work.

## Usage Rules

- Use `docs/TOOLS.md` for per-tool proof expectations.
- Use `docs/METHODOLOGY.md` for end-to-end audit process.
- Record version deviations in report metadata.
- Treat non-zero exit codes carefully: many security tools use them to indicate findings, not runtime failure.


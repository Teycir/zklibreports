# cat1_nomad_parity_fullsource

Purpose:
- Execute parity checks directly on full-source Nomad Solidity contracts for:
  - F10 migrate-alias flow (`BridgeRouter` + `TokenRegistry`)
  - F9 governance domain-churn gas slope (`GovernanceRouter`)

## Layout

- `src/external/nomad-core` (copied from mounted source)
- `src/external/nomad-xapps` (copied from mounted source)
- `src/ParitySupport.sol`
- `test/NomadFullSourceParity.t.sol`

## Setup

Install dependencies from harness directory (pinned):

```powershell
git clone --depth 1 --branch v3.4.2 https://github.com/OpenZeppelin/openzeppelin-contracts.git lib/openzeppelin-contracts
git clone --depth 1 --branch v3.4.2 https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable.git lib/openzeppelin-contracts-upgradeable
git clone --depth 1 --branch v2.0.0 https://github.com/summa-tx/memview-sol.git lib/memview-sol
```

## Run

```powershell
forge test -vv --match-path test/NomadFullSourceParity.t.sol
forge test -vv --match-path test/NomadFullSourceParity.t.sol --fuzz-runs 2000
```

# Optimism Cat2 Manual Audit (Intermediary)

Date: 2026-02-16  
Repo: `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\optimism`  
Commit: `6c24c04393a5b22ddde1c03e99958e1ad5b4f8d1`

## Scope (current pass)

- Dispute/finality core:
  - `packages/contracts-bedrock/src/L1/OptimismPortal2.sol`
  - `packages/contracts-bedrock/src/dispute/AnchorStateRegistry.sol`
  - `packages/contracts-bedrock/src/dispute/DisputeGameFactory.sol`
  - `packages/contracts-bedrock/src/dispute/FaultDisputeGame.sol`
- Pause/guardian/config control:
  - `packages/contracts-bedrock/src/L1/SystemConfig.sol`
  - `packages/contracts-bedrock/src/L1/SuperchainConfig.sol`
- Bond custody:
  - `packages/contracts-bedrock/src/dispute/DelayedWETH.sol`
- Permissioned dispute variants:
  - `packages/contracts-bedrock/src/dispute/PermissionedDisputeGame.sol`
  - `packages/contracts-bedrock/src/dispute/SuperPermissionedDisputeGame.sol`

## Findings (manual)

### 1) Critical (trust model): privileged control can redefine dispute validity and withdrawal safety

- Location: `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\optimism\packages\contracts-bedrock\src\dispute\DisputeGameFactory.sol:304`
- Location: `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\optimism\packages\contracts-bedrock\src\dispute\DisputeGameFactory.sol:314`
- Location: `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\optimism\packages\contracts-bedrock\src\dispute\DisputeGameFactory.sol:326`
- Location: `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\optimism\packages\contracts-bedrock\src\L1\SystemConfig.sol:555`
- Location: `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\optimism\packages\contracts-bedrock\src\L1\SystemConfig.sol:557`
- Summary:
  - Dispute game implementation and init bonds are owner-settable in `DisputeGameFactory`.
  - Feature flags in `SystemConfig` are settable by ProxyAdmin or ProxyAdmin owner.
- Risk:
  - Compromise/misuse of privileged control can alter dispute game behavior and protocol gating assumptions.
  - Withdrawal security is tightly coupled to governance key integrity and operational process.
- Status: `Design-risk` (privileged control, not a permissionless exploit).

### 2) High (custody): `DelayedWETH` admin can seize user funds and dispute bonds

- Location: `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\optimism\packages\contracts-bedrock\src\dispute\DelayedWETH.sol:108`
- Location: `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\optimism\packages\contracts-bedrock\src\dispute\DelayedWETH.sol:117`
- Location: `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\optimism\packages\contracts-bedrock\src\dispute\DelayedWETH.sol:124`
- Summary:
  - `recover` and `hold` allow `proxyAdminOwner()` to pull ETH/WETH, including from specific user accounts.
- Risk:
  - If privileged keys are compromised, challengers/participants can lose bonded assets.
  - Dispute incentive model becomes dependent on centralized key safety.
- Status: `Design-risk` (explicitly privileged function set).

### 3) High (liveness/governance): guardian can force dispute invalidation and prolonged pause windows

- Location: `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\optimism\packages\contracts-bedrock\src\dispute\AnchorStateRegistry.sol:150`
- Location: `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\optimism\packages\contracts-bedrock\src\dispute\AnchorStateRegistry.sol:161`
- Location: `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\optimism\packages\contracts-bedrock\src\dispute\AnchorStateRegistry.sol:227`
- Location: `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\optimism\packages\contracts-bedrock\src\L1\SuperchainConfig.sol:85`
- Location: `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\optimism\packages\contracts-bedrock\src\L1\SuperchainConfig.sol:113`
- Summary:
  - Guardian can update retirement timestamp and blacklist games, directly affecting `isGameProper` / claim validity.
  - Guardian can pause and repeatedly extend pause windows.
- Risk:
  - Withdrawal finalization and game acceptance can be halted or invalidated by guardian action.
  - Compromised/misused guardian path can create broad liveness failures.
- Status: `Design-risk` (governance authority concentration).

### 4) Medium: `tx.origin` authorization in permissioned dispute game initialization

- Location: `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\optimism\packages\contracts-bedrock\src\dispute\PermissionedDisputeGame.sol:75`
- Location: `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\optimism\packages\contracts-bedrock\src\dispute\SuperPermissionedDisputeGame.sol:76`
- Summary:
  - `initialize()` in permissioned dispute variants enforces `tx.origin == proposer()`.
- Risk:
  - Operational incompatibility with smart-account/multisig flows for proposer role.
  - `tx.origin` auth increases dependency on EOA-only flow and known anti-pattern semantics.
- Status: `Unproven impact` beyond design intent; requires deployment-mode confirmation.

### 5) Medium (operational): pause state can be dropped on upgrade in `SuperchainConfig`

- Location: `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\optimism\packages\contracts-bedrock\src\L1\SuperchainConfig.sol:13`
- Location: `\\VBOXSVR\elements\Repos\zk0d\cat2_rollups\optimism\packages\contracts-bedrock\src\L1\SuperchainConfig.sol:16`
- Summary:
  - Contract-level warning states active pause state can be lost across upgrades.
- Risk:
  - During incident response, an upgrade mistake could unexpectedly clear pause protection.
- Status: `Documented operational risk`.

## Tool Validation (pending)

Planned validation artifacts for this intermediary pass:

- `reports/cat2_rollups/optimism/artifacts/slither_optimismportal2.json`
- `reports/cat2_rollups/optimism/artifacts/slither_anchorstateregistry.json`
- `reports/cat2_rollups/optimism/artifacts/slither_disputegamefactory.json`
- `reports/cat2_rollups/optimism/artifacts/slither_delayedweth.json`
- `reports/cat2_rollups/optimism/artifacts/slither_permissioneddisputegame.json`
- `reports/cat2_rollups/optimism/artifacts/semgrep_optimism_logic_checks.json`
- `reports/cat2_rollups/optimism/artifacts/tool_validation_summary.txt`

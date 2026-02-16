# hyperlane-monorepo

- Source: \\VBOXSVR\elements\Repos\zk0d\cat1_bridges\hyperlane-monorepo
- HEAD: 5302a89c830c5eb43b8d3f53fc65e0733f4d6bd1
- origin: https://github.com/hyperlane-xyz/hyperlane-monorepo
- Stacks: node, rust, solidity

## Tool Outputs
- gitleaks: artifacts/gitleaks.json (exit=1, findings=204)
- osv-scanner: artifacts/osv.json (exit=1, vulns=163)
- cargo-audit: artifacts/cargo (lockfile=rust\main\Cargo.lock, exit=1)
- cargo-audit: artifacts/cargo (lockfile=rust\sealevel\Cargo.lock, exit=1)
- cargo-audit summary: vuln_count=30

## Notes
- This is an automated baseline (no repo build steps executed). Treat findings as leads until reproduced.
- Many security tools use non-zero exit codes to indicate findings; see raw JSON for details.

## Manual Audit Progress
- Manual report: `reports/cat1_bridges/hyperlane-monorepo/manual_audit.md`
- Pass status: exhausted for this pass (`H1/H2/H3` evidence-closed).
- Proven (model + fuzz + specialist):
  - H1 `HypERC20Collateral`/`TokenRouter` intent-level accounting can over-credit remote liabilities for inbound-fee collateral tokens.
  - H2 `LpCollateralRouter` can overstate `lpAssets` vs real collateral for inbound-fee token classes.
  - H3 `TokenRouter` fee transfer path can undercollateralize router collateral under sender-tax token behavior.

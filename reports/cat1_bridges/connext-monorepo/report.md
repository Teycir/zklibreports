# connext-monorepo

- Source: \\VBOXSVR\elements\Repos\zk0d\cat1_bridges\connext-monorepo
- HEAD: 7758e62037bba281b8844c37831bde0b838edd36
- origin: https://github.com/connext/monorepo
- Stacks: node, solidity

## Tool Outputs
- gitleaks: artifacts/gitleaks.json (exit=1, findings=73)
- osv-scanner: artifacts/osv.json (exit=1, vulns=240)

## Notes
- This is an automated baseline (no repo build steps executed). Treat findings as leads until reproduced.
- Many security tools use non-zero exit codes to indicate findings; see raw JSON for details.

## Manual Audit Progress
- Manual report: `reports/cat1_bridges/connext-monorepo/manual_audit.md`
- Pass status: exhausted for this pass.
- Proven (model + fuzz + specialist):
  - F1 router liquidity withdrawal can undercollateralize remaining router balances under sender-tax payout token behavior.
  - F2 canonical-domain execute payout can desynchronize `custodied` from real collateral under sender-tax token behavior.
  - F3 ERC20 `bumpTransfer` fee forwarding can consume bridge collateral under sender-tax payout token behavior.
- Falsified (not promoted):
  - F4 fast-liquidity execute trust-boundary auth-bypass hypothesis (strict-receiver fast-path auth bypass not reproducible in tested model).

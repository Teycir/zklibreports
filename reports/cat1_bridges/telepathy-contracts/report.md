# telepathy-contracts

- Source: \\VBOXSVR\elements\Repos\zk0d\cat1_bridges\telepathy-contracts
- HEAD: 0f3c6812d6bda96dde6ab7bdd8f8391c47bf5d0b
- origin: https://github.com/succinctlabs/telepathy-contracts
- Stacks: node, solidity

## Tool Outputs
- gitleaks: artifacts/gitleaks.json (exit=1, findings=1)
- osv-scanner: artifacts/osv.json (exit=0, vulns=0)

## Notes
- This is an automated baseline (no repo build steps executed). Treat findings as leads until reproduced.
- Many security tools use non-zero exit codes to indicate findings; see raw JSON for details.

## Manual Audit Progress
- Manual report: `reports/cat1_bridges/telepathy-contracts/manual_audit.md`
- Pass status: exhausted for this pass (`F1` proven; `F2/F3` evidence-closed and not promoted).
- Proven in this pass:
  - F1: uninitialized-proxy first-caller init hijack can seize telepathy router control plane and enable forged execution under attacker-controlled verifier config.
- Not promoted after witness validation:
  - F2: destination `verifierType()` path is an explicit destination-cooperation trust boundary in tested model.
  - F3: attestation `currentResponse()` coupling did not yield forge/replay bypass in tested model.

# LayerZero-v2

- Source: \\VBOXSVR\elements\Repos\zk0d\cat1_bridges\LayerZero-v2
- HEAD: ab9b083410b9359285a5756807e1b6145d4711a7
- origin: https://github.com/LayerZero-Labs/LayerZero-v2
- Stacks: node, rust

## Tool Outputs
- gitleaks: artifacts/gitleaks.json (exit=1, findings=12)
- osv-scanner: artifacts/osv.json (exit=1, vulns=132)
- cargo-audit: artifacts/cargo (lockfile=packages\layerzero-v2\solana\anchor-latest\Cargo.lock, exit=0)
- cargo-audit: artifacts/cargo (lockfile=packages\layerzero-v2\solana\programs\Cargo.lock, exit=1)
- cargo-audit summary: vuln_count=3

## Notes
- This is an automated baseline (no repo build steps executed). Treat findings as leads until reproduced.
- Many security tools use non-zero exit codes to indicate findings; see raw JSON for details.
- Manual witness-backed audit (current pass): `reports/cat1_bridges/LayerZero-v2/manual_audit.md`.
- Full-source parity witness artifacts captured for `H1/H2/H3` in `reports/cat1_bridges/LayerZero-v2/manual_artifacts/`.
- Specialist-fuzzer + fuzz artifacts for `LZ3` residual-sweep path captured in `reports/cat1_bridges/LayerZero-v2/manual_artifacts/`.

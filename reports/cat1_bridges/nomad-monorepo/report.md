# nomad-monorepo

- Source: \\VBOXSVR\elements\Repos\zk0d\cat1_bridges\nomad-monorepo
- HEAD: f326b402285e3255a654e5e44c919ce412c2bed0
- origin: https://github.com/nomad-xyz/nomad-monorepo
- Stacks: node, rust, solidity

## Tool Outputs
- gitleaks: artifacts/gitleaks.json (exit=1, findings=62)
- osv-scanner: artifacts/osv.json (exit=1, vulns=1217)
- npm audit: artifacts/npm-audit_package-lock.json.json (lockfile=package-lock.json, exit=1)
- npm audit: artifacts/npm-audit_examples_counter-xapp_package-lock.json.json (lockfile=examples\counter-xapp\package-lock.json, exit=1)
- npm audit: artifacts/npm-audit_examples_example-ui_package-lock.json.json (lockfile=examples\example-ui\package-lock.json, exit=1)
- npm audit: artifacts/npm-audit_solidity_nomad-core_package-lock.json.json (lockfile=solidity\nomad-core\package-lock.json, exit=1)
- npm audit: artifacts/npm-audit_solidity_nomad-xapps_package-lock.json.json (lockfile=solidity\nomad-xapps\package-lock.json, exit=1)
- npm audit: artifacts/npm-audit_tools_local-environment_package-lock.json.json (lockfile=tools\local-environment\package-lock.json, exit=1)
- npm audit: artifacts/npm-audit_tools_local-environment_hardhat_package-lock.json.json (lockfile=tools\local-environment\hardhat\package-lock.json, exit=1)
- npm audit: artifacts/npm-audit_typescript_nomad-deploy_package-lock.json.json (lockfile=typescript\nomad-deploy\package-lock.json, exit=1)
- npm audit: artifacts/npm-audit_typescript_nomad-monitor_package-lock.json.json (lockfile=typescript\nomad-monitor\package-lock.json, exit=1)
- npm audit: artifacts/npm-audit_typescript_nomad-sdk_package-lock.json.json (lockfile=typescript\nomad-sdk\package-lock.json, exit=1)
- npm audit: artifacts/npm-audit_typescript_nomad-tests_package-lock.json.json (lockfile=typescript\nomad-tests\package-lock.json, exit=1)
- npm audit: artifacts/npm-audit_typescript_typechain_package-lock.json.json (lockfile=typescript\typechain\package-lock.json, exit=1)
- npm audit summary: vuln_count=0
- cargo-audit: artifacts/cargo (lockfile=rust\Cargo.lock, exit=1)
- cargo-audit summary: vuln_count=26

## Notes
- This is an automated baseline (no repo build steps executed). Treat findings as leads until reproduced.
- Many security tools use non-zero exit codes to indicate findings; see raw JSON for details.

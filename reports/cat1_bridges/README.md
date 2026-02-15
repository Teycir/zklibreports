# cat1_bridges

Inputs live at `\\VBOXSVR\elements\Repos\zk0d\cat1_bridges` (10 git repos).

Baseline scan script:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/audit_cat1_bridges.ps1
```

Outputs:
- `reports/cat1_bridges/INDEX.md` summary table.
- Per-repo: `reports/cat1_bridges/<repo>/report.md` + `reports/cat1_bridges/<repo>/artifacts/*`.

Current baseline intentionally avoids executing repo build scripts. For Solidity deep analysis (e.g. Slither/Foundry), run those in a controlled mode after review because many toolchains invoke project build steps.

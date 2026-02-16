param(
  [Parameter(Mandatory = $false)]
  [string]$Root = "\\VBOXSVR\elements\Repos\zk0d\cat1_bridges",

  [Parameter(Mandatory = $false)]
  [string]$OutRoot = "reports/cat1_bridges",

  [Parameter(Mandatory = $false)]
  [string[]]$RepoNames = @(),

  [Parameter(Mandatory = $false)]
  [switch]$SkipGitleaks,

  [Parameter(Mandatory = $false)]
  [switch]$SkipOsv,

  [Parameter(Mandatory = $false)]
  [switch]$SkipGo,

  [Parameter(Mandatory = $false)]
  [switch]$SkipRust,

  [Parameter(Mandatory = $false)]
  [switch]$SkipNpmAudit,

  [Parameter(Mandatory = $false)]
  [int]$GitleaksTimeoutSec = 600,

  [Parameter(Mandatory = $false)]
  [int]$OsvTimeoutSec = 600,

  [Parameter(Mandatory = $false)]
  [int]$GovulncheckTimeoutSec = 600,

  [Parameter(Mandatory = $false)]
  [int]$GosecTimeoutSec = 600,

  [Parameter(Mandatory = $false)]
  [int]$CargoAuditTimeoutSec = 600,

  [Parameter(Mandatory = $false)]
  [int]$NpmAuditTimeoutSec = 600
)

$ErrorActionPreference = "Stop"

function _CmdExists([string]$cmd) {
  $null -ne (Get-Command $cmd -ErrorAction SilentlyContinue)
}

function _SafeName([string]$s) {
  # Keep file names stable across nested lockfiles.
  return ($s -replace '[^A-Za-z0-9_.-]+', '_').Trim('_')
}

function _RedactUrl([string]$url) {
  if (!$url) { return $url }
  # Strip embedded credentials/tokens in URLs like:
  # https://TOKEN@github.com/org/repo or https://user:pass@host/path
  return ($url -replace '^(https?://)([^/@]+@)', '$1')
}

function _RunProcess(
  [string]$name,
  [string]$filePath,
  [string[]]$argv,
  [string]$cwd,
  [int]$timeoutSec,
  [string]$stdoutFile,
  [string]$stderrFile
) {
  function _QuoteArg([string]$a) {
    if ($null -eq $a) { return '""' }
    if ($a -match '[\s"]') {
      return '"' + ($a -replace '"', '\\"') + '"'
    }
    return $a
  }

  function _JoinArgs([string[]]$a) {
    if ($null -eq $a -or $a.Count -eq 0) { return "" }
    return (($a | ForEach-Object { _QuoteArg $_ }) -join ' ')
  }

  $result = [ordered]@{
    name = $name
    file = $filePath
    args = $argv
    arg_string = $null
    runner = "cmd.exe"
    runner_args = $null
    cwd = $cwd
    start_utc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss 'UTC'")
    end_utc = $null
    duration_sec = $null
    timed_out = $false
    exit_code = $null
    stdout = $stdoutFile
    stderr = $stderrFile
  }

  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  try {
    $argsString = _JoinArgs $argv
    $result.arg_string = $argsString

    $outDir = Split-Path -Parent $stdoutFile
    if ($outDir -and !(Test-Path $outDir)) { New-Item -ItemType Directory -Force $outDir | Out-Null }
    $errDir = Split-Path -Parent $stderrFile
    if ($errDir -and !(Test-Path $errDir)) { New-Item -ItemType Directory -Force $errDir | Out-Null }

    $cmdExe = "cmd.exe"
    $exeQuoted = _QuoteArg $filePath
    $stdoutQuoted = _QuoteArg $stdoutFile
    $stderrQuoted = _QuoteArg $stderrFile
    $full = ($exeQuoted + " " + $argsString).Trim()
    $fullRedirected = ($full + " 1> " + $stdoutQuoted + " 2> " + $stderrQuoted)
    $runnerArgs = @("/d", "/s", "/c", $fullRedirected)
    $result.runner_args = $runnerArgs

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $cmdExe
    $psi.Arguments = _JoinArgs $runnerArgs
    $psi.WorkingDirectory = $cwd
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true

    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $psi

    $null = $p.Start()

    $done = $p.WaitForExit($timeoutSec * 1000)
    if (!$done) {
      $result.timed_out = $true
      try { $p.Kill() } catch {}
      try { $p.WaitForExit() } catch {}
      $result.exit_code = 124
    } else {
      $result.exit_code = $p.ExitCode
    }
  } catch {
    $result.exit_code = 1
  } finally {
    $sw.Stop()
    $result.duration_sec = [int][Math]::Round($sw.Elapsed.TotalSeconds)
    $result.end_utc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss 'UTC'")
  }

  return $result
}

function _WriteJson([string]$path, $obj) {
  $dir = Split-Path -Parent $path
  if ($dir -and !(Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
  ($obj | ConvertTo-Json -Depth 20) | Set-Content -Encoding UTF8 $path
}

function _TryReadJsonCount([string]$path, [scriptblock]$countFn) {
  if (!(Test-Path $path)) { return $null }
  try {
    $raw = Get-Content -Raw -Encoding UTF8 $path
    if (!$raw) { return 0 }
    $j = $raw | ConvertFrom-Json
    return & $countFn $j
  } catch {
    return $null
  }
}

if (!(Test-Path $Root)) {
  throw "Root not accessible: $Root"
}

if (!(Test-Path $OutRoot)) {
  New-Item -ItemType Directory -Force $OutRoot | Out-Null
}

$OutRootAbs = (Resolve-Path $OutRoot).Path

$toolVersions = [ordered]@{
  timestamp_utc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss 'UTC'")
  host = $env:COMPUTERNAME
  root = $Root
  tools = [ordered]@{}
}

if (_CmdExists "git") { $toolVersions.tools.git = ((git --version) -join "`n") }
if (_CmdExists "gitleaks") { $toolVersions.tools.gitleaks = ((gitleaks version) -join "`n") }
if (_CmdExists "osv-scanner") { $toolVersions.tools.osv_scanner = ((osv-scanner --version) -join "`n") }
if (_CmdExists "go") { $toolVersions.tools.go = ((go version) -join "`n") }
if (_CmdExists "govulncheck") { $toolVersions.tools.govulncheck = ((govulncheck -version) -join "`n") }
if (_CmdExists "gosec") { $toolVersions.tools.gosec = ((gosec -version) -join "`n") }
if (_CmdExists "cargo") { $toolVersions.tools.rustc = ((rustc --version) -join "`n") ; $toolVersions.tools.cargo = ((cargo --version) -join "`n") }
if (_CmdExists "cargo") {
  try { $toolVersions.tools.cargo_audit = ((cargo audit -V) -join "`n") } catch {}
}
if (_CmdExists "halmos") { $toolVersions.tools.halmos = ((halmos --version) -join "`n") }
if (_CmdExists "slither") { $toolVersions.tools.slither = ((slither --version) -join "`n") }
if (_CmdExists "solc") { $toolVersions.tools.solc = ((solc --version) -join "`n") }
try {
  $npmCmd = Get-Command npm.cmd -ErrorAction SilentlyContinue
  if ($npmCmd) { $toolVersions.tools.npm = (& cmd.exe /c "npm.cmd --version") -join "`n" }
} catch {}

_WriteJson (Join-Path $OutRootAbs "tool_versions.json") $toolVersions

$repos = Get-ChildItem -Force $Root -Directory | Where-Object { Test-Path (Join-Path $_.FullName ".git") }
if ($RepoNames.Count -gt 0) {
  $want = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
  foreach ($n in $RepoNames) { [void]$want.Add($n) }
  $repos = $repos | Where-Object { $want.Contains($_.Name) }
}

$indexRows = New-Object System.Collections.Generic.List[object]

foreach ($repo in ($repos | Sort-Object Name)) {
  $name = $repo.Name
  $src = $repo.FullName
  $outDir = Join-Path $OutRootAbs $name
  $artDir = Join-Path $outDir "artifacts"
  New-Item -ItemType Directory -Force $artDir | Out-Null
  $logFile = Join-Path $outDir "progress.log"

  $meta = [ordered]@{
    name = $name
    source_path = $src
    scanned_at_utc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss 'UTC'")
    git = [ordered]@{}
    stacks = @()
    outputs = [ordered]@{}
  }

  # Start a fresh progress log each run (avoid unbounded growth across reruns).
  ("[{0}] start" -f $meta.scanned_at_utc) | Set-Content -Encoding UTF8 $logFile

  if (_CmdExists "git") {
    try { $meta.git.head = (git -C $src rev-parse HEAD).Trim() } catch {}
    try { $meta.git.branch = (git -C $src rev-parse --abbrev-ref HEAD).Trim() } catch {}
    try { $meta.git.remote_origin = _RedactUrl (git -C $src remote get-url origin).Trim() } catch {}
  }

  $hasGo = $null -ne (Get-ChildItem -Path $src -Recurse -File -Depth 4 -Filter go.mod -ErrorAction SilentlyContinue | Select-Object -First 1)
  $hasNode = $null -ne (Get-ChildItem -Path $src -Recurse -File -Depth 4 -Filter package.json -ErrorAction SilentlyContinue | Select-Object -First 1)
  $hasRust = $null -ne (Get-ChildItem -Path $src -Recurse -File -Depth 4 -Filter Cargo.toml -ErrorAction SilentlyContinue | Select-Object -First 1)
  $hasSol = $null -ne (Get-ChildItem -Path $src -Recurse -File -Depth 4 -Filter '*.sol' -ErrorAction SilentlyContinue | Select-Object -First 1)
  if ($hasGo) { $meta.stacks += "go" }
  if ($hasNode) { $meta.stacks += "node" }
  if ($hasRust) { $meta.stacks += "rust" }
  if ($hasSol) { $meta.stacks += "solidity" }

  # gitleaks (secrets in history + working tree)
  if (!$SkipGitleaks -and (_CmdExists "gitleaks")) {
    $gitleaksOut = Join-Path $artDir "gitleaks.json"
    $stdout = Join-Path $artDir "gitleaks.stdout.log"
    $stderr = Join-Path $artDir "gitleaks.stderr.log"
    # Always redact secrets in output; exit code 1 means "leaks found".
    $argv = @("detect", "--source", $src, "--report-format", "json", "--report-path", $gitleaksOut, "--redact", "--no-banner", "--log-level", "error", "--timeout", "$GitleaksTimeoutSec")
    ("[{0}] gitleaks start" -f (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss 'UTC'")) | Add-Content -Encoding UTF8 $logFile
    $run = _RunProcess "gitleaks" "gitleaks" $argv $src $GitleaksTimeoutSec $stdout $stderr
    ("[{0}] gitleaks end exit={1} timeout={2} dur={3}s" -f $run.end_utc, $run.exit_code, $run.timed_out, $run.duration_sec) | Add-Content -Encoding UTF8 $logFile
    $meta.outputs.gitleaks = $run
    $meta.outputs.gitleaks.report = $gitleaksOut
  }

  # osv-scanner (dependency vulns; manifest/lockfile driven)
  if (!$SkipOsv -and (_CmdExists "osv-scanner")) {
    $osvOut = Join-Path $artDir "osv.json"
    $stdout = Join-Path $artDir "osv.stdout.log"
    $stderr = Join-Path $artDir "osv.stderr.log"
    # Exclude big build caches; osv-scanner still inspects manifests/lockfiles.
    $argv = @(
      "scan", "source", "-r", $src,
      "-f", "json", "--output", $osvOut,
      "--allow-no-lockfiles",
      "--verbosity", "warn",
      "--experimental-exclude", "g:**/node_modules",
      "--experimental-exclude", "g:**/target",
      "--experimental-exclude", "g:**/.git",
      "--experimental-exclude", "g:**/dist",
      "--experimental-exclude", "g:**/build",
      "--experimental-exclude", "g:**/out"
    )
    ("[{0}] osv-scanner start" -f (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss 'UTC'")) | Add-Content -Encoding UTF8 $logFile
    $run = _RunProcess "osv-scanner" "osv-scanner" $argv $src $OsvTimeoutSec $stdout $stderr
    ("[{0}] osv-scanner end exit={1} timeout={2} dur={3}s" -f $run.end_utc, $run.exit_code, $run.timed_out, $run.duration_sec) | Add-Content -Encoding UTF8 $logFile
    $meta.outputs.osv = $run
    $meta.outputs.osv.report = $osvOut
  }

  # Go: govulncheck + gosec
  if (!$SkipGo -and $hasGo -and (_CmdExists "govulncheck")) {
    $meta.outputs.govulncheck = [ordered]@{}

    $govJsonOut = Join-Path $artDir "govulncheck.json"
    $govJsonErr = Join-Path $artDir "govulncheck.json.stderr.log"
    ("[{0}] govulncheck(json) start" -f (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss 'UTC'")) | Add-Content -Encoding UTF8 $logFile
    $argv = @("-C", $src, "-format", "json", "./...")
    $runJson = _RunProcess "govulncheck(json)" "govulncheck" $argv $src $GovulncheckTimeoutSec $govJsonOut $govJsonErr
    ("[{0}] govulncheck(json) end exit={1} timeout={2} dur={3}s" -f $runJson.end_utc, $runJson.exit_code, $runJson.timed_out, $runJson.duration_sec) | Add-Content -Encoding UTF8 $logFile
    $meta.outputs.govulncheck.json = $runJson

    $govTxtOut = Join-Path $artDir "govulncheck.txt"
    $govTxtErr = Join-Path $artDir "govulncheck.txt.stderr.log"
    ("[{0}] govulncheck(text) start" -f (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss 'UTC'")) | Add-Content -Encoding UTF8 $logFile
    $argv = @("-C", $src, "-format", "text", "-show", "traces", "./...")
    $runTxt = _RunProcess "govulncheck(text)" "govulncheck" $argv $src $GovulncheckTimeoutSec $govTxtOut $govTxtErr
    ("[{0}] govulncheck(text) end exit={1} timeout={2} dur={3}s" -f $runTxt.end_utc, $runTxt.exit_code, $runTxt.timed_out, $runTxt.duration_sec) | Add-Content -Encoding UTF8 $logFile
    $meta.outputs.govulncheck.text = $runTxt
  }

  if (!$SkipGo -and $hasGo -and (_CmdExists "gosec")) {
    $gosecOut = Join-Path $artDir "gosec.json"
    $stdout = Join-Path $artDir "gosec.stdout.log"
    $stderr = Join-Path $artDir "gosec.stderr.log"
    ("[{0}] gosec start" -f (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss 'UTC'")) | Add-Content -Encoding UTF8 $logFile
    $argv = @("-fmt=json", "-out=$gosecOut", "-confidence=high", "-severity=medium", "-exclude-generated", "-quiet", "./...")
    $run = _RunProcess "gosec" "gosec" $argv $src $GosecTimeoutSec $stdout $stderr
    ("[{0}] gosec end exit={1} timeout={2} dur={3}s" -f $run.end_utc, $run.exit_code, $run.timed_out, $run.duration_sec) | Add-Content -Encoding UTF8 $logFile
    $meta.outputs.gosec = $run
  }

  # Rust: cargo audit for every existing Cargo.lock (no lockfile generation)
  if (!$SkipRust -and $hasRust -and (_CmdExists "cargo")) {
    $locks = Get-ChildItem -Path $src -Recurse -File -Depth 4 -Filter Cargo.lock -ErrorAction SilentlyContinue
    $hasCargoAudit = $false
    try { & cargo audit -V | Out-Null; if ($LASTEXITCODE -eq 0) { $hasCargoAudit = $true } } catch {}
    if ($locks.Count -gt 0 -and $hasCargoAudit) {
      $meta.outputs.cargo_audit = @()
      foreach ($l in $locks) {
        $rel = $l.FullName.Substring($src.Length).TrimStart('\','/')
        $stem = _SafeName $rel
        $out = Join-Path $artDir ("cargo-audit_" + $stem + ".json")
        $stderr = Join-Path $artDir ("cargo-audit_" + $stem + ".stderr.log")
        ("[{0}] cargo-audit start lock={1}" -f (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss 'UTC'"), $rel) | Add-Content -Encoding UTF8 $logFile
        $argv = @("audit", "--json", "--file", $l.FullName)
        $run = _RunProcess "cargo-audit" "cargo" $argv $src $CargoAuditTimeoutSec $out $stderr
        ("[{0}] cargo-audit end lock={1} exit={2} timeout={3} dur={4}s" -f $run.end_utc, $rel, $run.exit_code, $run.timed_out, $run.duration_sec) | Add-Content -Encoding UTF8 $logFile
        $run.lockfile = $rel
        $meta.outputs.cargo_audit += $run
      }
    }
  }

  # Node: npm audit (lockfile-only)
  if (!$SkipNpmAudit -and $hasNode) {
    $npmCmd = $null
    try { $npmCmd = (Get-Command npm.cmd -ErrorAction SilentlyContinue) } catch {}
    if ($npmCmd) {
      $locks = Get-ChildItem -Path $src -Recurse -File -Depth 4 -Filter package-lock.json -ErrorAction SilentlyContinue
      if ($locks.Count -gt 0) {
        $meta.outputs.npm_audit = @()
        foreach ($l in $locks) {
          $lockDir = Split-Path -Parent $l.FullName
          $rel = $l.FullName.Substring($src.Length).TrimStart('\','/')
          $stem = _SafeName $rel
          $out = Join-Path $artDir ("npm-audit_" + $stem + ".json")
          $stderr = Join-Path $artDir ("npm-audit_" + $stem + ".stderr.log")

          ("[{0}] npm-audit start lock={1}" -f (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss 'UTC'"), $rel) | Add-Content -Encoding UTF8 $logFile
          $argv = @("audit", "--package-lock-only", "--json")
          $run = _RunProcess "npm-audit" "npm.cmd" $argv $lockDir $NpmAuditTimeoutSec $out $stderr
          # npm audit prints JSON to stdout; Start-Process redirect should capture it.
          ("[{0}] npm-audit end lock={1} exit={2} timeout={3} dur={4}s" -f $run.end_utc, $rel, $run.exit_code, $run.timed_out, $run.duration_sec) | Add-Content -Encoding UTF8 $logFile
          $run.lockfile = $rel
          $meta.outputs.npm_audit += $run
        }
      }
    }
  }

  $gitleaksCount = _TryReadJsonCount (Join-Path $artDir "gitleaks.json") { param($j) if ($null -eq $j) { 0 } elseif ($j -is [System.Array]) { $j.Count } else { 0 } }
  $osvCount = _TryReadJsonCount (Join-Path $artDir "osv.json") {
    param($j)
    $c = 0
    if ($null -eq $j) { return 0 }
    if ($j.results) {
      foreach ($r in $j.results) {
        if ($r.packages) {
          foreach ($p in $r.packages) {
            if ($p.vulnerabilities) { $c += $p.vulnerabilities.Count }
          }
        }
      }
    }
    return $c
  }

  $npmCount = $null
  $npmFiles = Get-ChildItem -Path $artDir -File -Filter "npm-audit_*.json" -ErrorAction SilentlyContinue
  if ($npmFiles.Count -gt 0) {
    $npmCount = 0
    foreach ($f in $npmFiles) {
      $n = _TryReadJsonCount $f.FullName {
        param($j)
        if ($j.metadata -and $j.metadata.vulnerabilities) {
          $m = $j.metadata.vulnerabilities
          $sum = 0
          foreach ($k in @("info","low","moderate","high","critical")) {
            if ($m.$k -ne $null) { $sum += [int]$m.$k }
          }
          return $sum
        }
        return 0
      }
      if ($null -ne $n) { $npmCount += $n }
    }
  }

  $cargoCount = $null
  $cargoFiles = Get-ChildItem -Path $artDir -File -Filter "cargo-audit_*.json" -ErrorAction SilentlyContinue
  if ($cargoFiles.Count -gt 0) {
    $cargoCount = 0
    foreach ($f in $cargoFiles) {
      $n = _TryReadJsonCount $f.FullName {
        param($j)
        if ($j.vulnerabilities -and $j.vulnerabilities.list) { return $j.vulnerabilities.list.Count }
        return 0
      }
      if ($null -ne $n) { $cargoCount += $n }
    }
  }

  $meta.summary = [ordered]@{
    gitleaks_findings = $gitleaksCount
    osv_vulns = $osvCount
    npm_audit_vulns = $npmCount
    cargo_audit_vulns = $cargoCount
  }

  _WriteJson (Join-Path $outDir "meta.json") $meta

  $report = @()
  $report += "# $name"
  $report += ""
  $report += "- Source: $src"
  if ($meta.git.head) { $report += "- HEAD: $($meta.git.head)" }
  if ($meta.git.remote_origin) { $report += "- origin: $($meta.git.remote_origin)" }
  if ($meta.stacks.Count -gt 0) { $report += "- Stacks: $($meta.stacks -join ', ')" }
  $report += ""
  $report += "## Tool Outputs"
  if ($meta.outputs.gitleaks) {
    $report += "- gitleaks: artifacts/gitleaks.json (exit=$($meta.outputs.gitleaks.exit_code), findings=$gitleaksCount)"
  }
  if ($meta.outputs.osv) {
    $report += "- osv-scanner: artifacts/osv.json (exit=$($meta.outputs.osv.exit_code), vulns=$osvCount)"
  }
  if ($meta.outputs.govulncheck) {
    if ($meta.outputs.govulncheck.json) {
      $report += "- govulncheck(json): artifacts/govulncheck.json (exit=$($meta.outputs.govulncheck.json.exit_code))"
    }
    if ($meta.outputs.govulncheck.text) {
      $report += "- govulncheck(text): artifacts/govulncheck.txt (exit=$($meta.outputs.govulncheck.text.exit_code), includes traces)"
    }
  }
  if ($meta.outputs.gosec) {
    $report += "- gosec: artifacts/gosec.json (exit=$($meta.outputs.gosec.exit_code))"
  }
  if ($meta.outputs.npm_audit) {
    foreach ($entry in $meta.outputs.npm_audit) {
      $relLock = $entry.lockfile
      $relOut = Split-Path -Leaf $entry.stdout
      # stdout is the JSON report path.
      $report += "- npm audit: artifacts/$relOut (lockfile=$relLock, exit=$($entry.exit_code))"
    }
    $report += "- npm audit summary: vuln_count=$npmCount"
  }
  if ($meta.outputs.cargo_audit) {
    foreach ($entry in $meta.outputs.cargo_audit) {
      $relLock = $entry.lockfile
      $relOut = Split-Path -Leaf $entry.file
      $report += "- cargo-audit: artifacts/$relOut (lockfile=$relLock, exit=$($entry.exit_code))"
    }
    $report += "- cargo-audit summary: vuln_count=$cargoCount"
  }
  $report += ""
  $report += "## Notes"
  $report += "- This is an automated baseline (no repo build steps executed). Treat findings as leads until reproduced."
  $report += "- Many security tools use non-zero exit codes to indicate findings; see raw JSON for details."

  ($report -join "`r`n") | Set-Content -Encoding UTF8 (Join-Path $outDir "report.md")

  $indexRows.Add([pscustomobject]@{
    name = $name
    head = $meta.git.head
    stacks = ($meta.stacks -join ",")
    gitleaks_findings = $gitleaksCount
    osv_vulns = $osvCount
    cargo_audit_vulns = $cargoCount
    npm_audit_vulns = $npmCount
    report = ("./" + $name + "/report.md")
  }) | Out-Null
}

$indexRows = New-Object System.Collections.Generic.List[object]
foreach ($d in (Get-ChildItem -Directory $OutRoot -Force -ErrorAction SilentlyContinue | Where-Object { Test-Path (Join-Path $_.FullName "meta.json") } | Sort-Object Name)) {
  try {
    $metaPath = Join-Path $d.FullName "meta.json"
    $m = (Get-Content -Raw -Encoding UTF8 $metaPath) | ConvertFrom-Json
    $indexRows.Add([pscustomobject]@{
      name = $m.name
      head = $m.git.head
      stacks = (($m.stacks | ForEach-Object { $_ }) -join ",")
      gitleaks_findings = $m.summary.gitleaks_findings
      osv_vulns = $m.summary.osv_vulns
      npm_audit_vulns = $m.summary.npm_audit_vulns
      cargo_audit_vulns = $m.summary.cargo_audit_vulns
      report = ("./" + $m.name + "/report.md")
    }) | Out-Null
  } catch {
    # ignore broken meta.json
  }
}

$idx = @()
$idx += "# cat1_bridges index"
$idx += ""
$idx += "Scanned: $($toolVersions.timestamp_utc)"
$idx += ""
$idx += "| Repo | HEAD | Stacks | gitleaks | osv | npm-audit | cargo-audit | Report |"
$idx += "|---|---|---|---:|---:|---:|---:|---|"
foreach ($r in $indexRows) {
  $idx += "| $($r.name) | $($r.head) | $($r.stacks) | $($r.gitleaks_findings) | $($r.osv_vulns) | $($r.npm_audit_vulns) | $($r.cargo_audit_vulns) | [$($r.name)]($($r.report)) |"
}

($idx -join "`r`n") | Set-Content -Encoding UTF8 (Join-Path $OutRootAbs "INDEX.md")

Write-Host ("Wrote reports to " + $OutRootAbs)

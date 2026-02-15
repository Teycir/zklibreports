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
  [switch]$SkipRust
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

_WriteJson (Join-Path $OutRoot "tool_versions.json") $toolVersions

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
  $outDir = Join-Path $OutRoot $name
  $artDir = Join-Path $outDir "artifacts"
  New-Item -ItemType Directory -Force $artDir | Out-Null

  $meta = [ordered]@{
    name = $name
    source_path = $src
    scanned_at_utc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss 'UTC'")
    git = [ordered]@{}
    stacks = @()
    outputs = [ordered]@{}
  }

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
    # Always redact secrets in output; findings are still useful for triage.
    $args = @("detect", "--source", $src, "--report-format", "json", "--report-path", $gitleaksOut, "--redact", "--no-banner")
    $exit = 0
    try {
      & gitleaks @args | Out-Null
      $exit = $LASTEXITCODE
    } catch {
      $exit = 1
    }
    $meta.outputs.gitleaks = [ordered]@{ file = $gitleaksOut; exit_code = $exit }
  }

  # osv-scanner (dependency vulns; manifest/lockfile driven)
  if (!$SkipOsv -and (_CmdExists "osv-scanner")) {
    $osvOut = Join-Path $artDir "osv.json"
    $args = @("scan", "source", "-r", $src, "-f", "json", "--output", $osvOut, "--allow-no-lockfiles", "--verbosity", "warn")
    $exit = 0
    try {
      & osv-scanner @args | Out-Null
      $exit = $LASTEXITCODE
    } catch {
      $exit = 1
    }
    $meta.outputs.osv = [ordered]@{ file = $osvOut; exit_code = $exit }
  }

  # Go: govulncheck + gosec
  if (!$SkipGo -and $hasGo -and (_CmdExists "govulncheck")) {
    $govOut = Join-Path $artDir "govulncheck.json"
    $exit = 0
    try {
      & govulncheck -C $src -format json ./... 2>$null | Set-Content -Encoding UTF8 $govOut
      $exit = $LASTEXITCODE
    } catch {
      $exit = 1
    }
    $meta.outputs.govulncheck = [ordered]@{ file = $govOut; exit_code = $exit }
  }

  if (!$SkipGo -and $hasGo -and (_CmdExists "gosec")) {
    $gosecOut = Join-Path $artDir "gosec.json"
    $exit = 0
    try {
      Push-Location $src
      & gosec -fmt=json -out=$gosecOut -confidence=high -severity=medium -exclude-generated -quiet ./... | Out-Null
      $exit = $LASTEXITCODE
    } catch {
      $exit = 1
    } finally {
      Pop-Location
    }
    $meta.outputs.gosec = [ordered]@{ file = $gosecOut; exit_code = $exit }
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
        $exit = 0
        try {
          & cargo audit --json --file $l.FullName | Set-Content -Encoding UTF8 $out
          $exit = $LASTEXITCODE
        } catch {
          $exit = 1
        }
        $meta.outputs.cargo_audit += [ordered]@{ lockfile = $rel; file = $out; exit_code = $exit }
      }
    }
  }

  _WriteJson (Join-Path $outDir "meta.json") $meta

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

  $govCount = _TryReadJsonCount (Join-Path $artDir "govulncheck.json") {
    param($j)
    # govulncheck JSON is a stream of JSON objects, not a single JSON document.
    return $null
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
    $report += "- govulncheck: artifacts/govulncheck.json (exit=$($meta.outputs.govulncheck.exit_code))"
  }
  if ($meta.outputs.gosec) {
    $report += "- gosec: artifacts/gosec.json (exit=$($meta.outputs.gosec.exit_code))"
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

  ($report -join "`r`n") | Set-Content -Encoding UTF8 (Join-Path $outDir "report.md")

  $indexRows.Add([pscustomobject]@{
    name = $name
    head = $meta.git.head
    stacks = ($meta.stacks -join ",")
    gitleaks_findings = $gitleaksCount
    osv_vulns = $osvCount
    cargo_audit_vulns = $cargoCount
    report = ("./" + $name + "/report.md")
  }) | Out-Null
}

$idx = @()
$idx += "# cat1_bridges index"
$idx += ""
$idx += "Scanned: $($toolVersions.timestamp_utc)"
$idx += ""
$idx += "| Repo | HEAD | Stacks | gitleaks | osv | cargo-audit | Report |"
$idx += "|---|---|---|---:|---:|---:|---|"
foreach ($r in $indexRows) {
  $idx += "| $($r.name) | $($r.head) | $($r.stacks) | $($r.gitleaks_findings) | $($r.osv_vulns) | $($r.cargo_audit_vulns) | [$($r.name)]($($r.report)) |"
}

($idx -join "`r`n") | Set-Content -Encoding UTF8 (Join-Path $OutRoot "INDEX.md")

Write-Host ("Wrote reports to " + (Resolve-Path $OutRoot))

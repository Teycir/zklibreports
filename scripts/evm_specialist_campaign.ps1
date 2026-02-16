param(
  [Parameter(Mandatory = $true)]
  [string]$HarnessDir,

  [Parameter(Mandatory = $true)]
  [string]$HarnessContract,

  [Parameter(Mandatory = $true)]
  [string]$HarnessSource,

  [Parameter(Mandatory = $true)]
  [string]$ArtifactDir,

  [Parameter(Mandatory = $true)]
  [string]$ArtifactPrefix,

  [Parameter(Mandatory = $false)]
  [int]$SeqLen = 10,

  [Parameter(Mandatory = $false)]
  [int]$Workers = 4,

  [Parameter(Mandatory = $false)]
  [int]$TimeoutSec = 30,

  [Parameter(Mandatory = $false)]
  [int]$EchidnaTestLimit = 20000,

  [Parameter(Mandatory = $false)]
  [string]$EchidnaCorpusDir = "echidna-corpus",

  [Parameter(Mandatory = $false)]
  [switch]$SkipEchidna
)

$ErrorActionPreference = "Stop"

function _UtcNow() {
  return (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss 'UTC'")
}

function _EnsureDir([string]$path) {
  if (!(Test-Path $path)) {
    New-Item -ItemType Directory -Force $path | Out-Null
  }
}

function _RunToFile([string]$command, [string]$outfile) {
  $result = [ordered]@{
    command = $command
    outfile = $outfile
    start_utc = _UtcNow
    end_utc = $null
    exit_code = $null
  }

  try {
    $null = & powershell -NoProfile -Command "$command 2>&1 | Tee-Object -FilePath `"$outfile`""
    $result.exit_code = $LASTEXITCODE
  } catch {
    $result.exit_code = 1
  } finally {
    $result.end_utc = _UtcNow
  }

  return $result
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$harnessDirAbs = (Resolve-Path $HarnessDir).Path
$artifactDirAbs = if ([System.IO.Path]::IsPathRooted($ArtifactDir)) {
  $ArtifactDir
} else {
  Join-Path $repoRoot $ArtifactDir
}

_EnsureDir $artifactDirAbs

$medusaOut = Join-Path $artifactDirAbs ("{0}_medusa_{1}s.txt" -f $ArtifactPrefix, $TimeoutSec)
$echidnaOut = Join-Path $artifactDirAbs ("{0}_echidna_{1}s.txt" -f $ArtifactPrefix, $TimeoutSec)
$metaOut = Join-Path $artifactDirAbs ("{0}_campaign_meta.json" -f $ArtifactPrefix)

$oldLocation = Get-Location
try {
  Set-Location $harnessDirAbs

  $medusaCmd = "powershell -NoProfile -ExecutionPolicy Bypass -File ..\..\scripts\medusa.ps1 fuzz --compilation-target . --target-contracts $HarnessContract --seq-len $SeqLen --workers $Workers --timeout $TimeoutSec --fail-fast --no-color --log-level info"
  $medusaRun = _RunToFile $medusaCmd $medusaOut

  $echidnaRun = $null
  if (!$SkipEchidna) {
    $echidnaCmd = "powershell -NoProfile -ExecutionPolicy Bypass -File ..\..\scripts\echidna.ps1 $HarnessSource --contract $HarnessContract --test-mode property --seq-len $SeqLen --test-limit $EchidnaTestLimit --timeout $TimeoutSec --format text --corpus-dir $EchidnaCorpusDir"
    $echidnaRun = _RunToFile $echidnaCmd $echidnaOut
  }

  $meta = [ordered]@{
    generated_at_utc = _UtcNow
    repo_root = $repoRoot
    harness_dir = $harnessDirAbs
    harness_contract = $HarnessContract
    harness_source = $HarnessSource
    seq_len = $SeqLen
    workers = $Workers
    timeout_sec = $TimeoutSec
    echidna_test_limit = $EchidnaTestLimit
    echidna_corpus_dir = $EchidnaCorpusDir
    medusa = $medusaRun
    echidna = $echidnaRun
    note = "Non-zero exits can be expected when properties are falsified."
  }

  ($meta | ConvertTo-Json -Depth 8) | Set-Content -Encoding UTF8 $metaOut
} finally {
  Set-Location $oldLocation
}

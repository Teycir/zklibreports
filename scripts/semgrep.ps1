param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$Args
)

$ErrorActionPreference = "Stop"

$semgrep = Join-Path $PSScriptRoot "..\\tools\\venv\\semgrep\\Scripts\\semgrep.exe"
$semgrep = (Resolve-Path $semgrep).Path
if (!(Test-Path $semgrep)) {
  throw "semgrep.exe not found at: $semgrep"
}

& $semgrep @Args
exit $LASTEXITCODE


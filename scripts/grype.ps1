param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$Args
)

$ErrorActionPreference = "Stop"

$grype = "C:\\grype\\grype.exe"
if (!(Test-Path $grype)) {
  throw "grype.exe not found at: $grype"
}

& $grype @Args
exit $LASTEXITCODE


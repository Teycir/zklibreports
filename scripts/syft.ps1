param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$Args
)

$ErrorActionPreference = "Stop"

$syft = "C:\\syft\\syft.exe"
if (!(Test-Path $syft)) {
  throw "syft.exe not found at: $syft"
}

& $syft @Args
exit $LASTEXITCODE


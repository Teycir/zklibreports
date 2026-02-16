param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$Args
)

$ErrorActionPreference = "Stop"

$forge = "C:\\Tools\\foundry\\bin\\forge.exe"
if (!(Test-Path $forge)) {
  throw "forge.exe not found at: $forge"
}

& $forge @Args
exit $LASTEXITCODE


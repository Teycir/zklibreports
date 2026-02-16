param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$Args
)

$ErrorActionPreference = "Stop"

$anvil = "C:\\Tools\\foundry\\bin\\anvil.exe"
if (!(Test-Path $anvil)) {
  throw "anvil.exe not found at: $anvil"
}

& $anvil @Args
exit $LASTEXITCODE


param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$Args
)

$ErrorActionPreference = "Stop"

$chisel = "C:\\Tools\\foundry\\bin\\chisel.exe"
if (!(Test-Path $chisel)) {
  throw "chisel.exe not found at: $chisel"
}

& $chisel @Args
exit $LASTEXITCODE


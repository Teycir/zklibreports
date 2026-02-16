param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$Args
)

$ErrorActionPreference = "Stop"

$cbmc = "C:\\Program Files\\cbmc\\bin\\cbmc.exe"
if (!(Test-Path $cbmc)) {
  throw "cbmc.exe not found at: $cbmc"
}

& $cbmc @Args
exit $LASTEXITCODE


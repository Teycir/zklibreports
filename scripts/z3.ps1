param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$Args
)

$ErrorActionPreference = "Stop"

$z3 = "C:\\z3\\bin\\z3.exe"
if (!(Test-Path $z3)) {
  throw "z3.exe not found at: $z3"
}

& $z3 @Args
exit $LASTEXITCODE


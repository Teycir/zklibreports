param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$Args
)

$ErrorActionPreference = "Stop"

$cast = "C:\\Tools\\foundry\\bin\\cast.exe"
if (!(Test-Path $cast)) {
  throw "cast.exe not found at: $cast"
}

& $cast @Args
exit $LASTEXITCODE


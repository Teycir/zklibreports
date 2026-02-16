param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$Args
)

$ErrorActionPreference = "Stop"

$codeql = "C:\\codeql\\codeql.exe"
if (!(Test-Path $codeql)) {
  throw "codeql.exe not found at: $codeql"
}

& $codeql @Args
exit $LASTEXITCODE


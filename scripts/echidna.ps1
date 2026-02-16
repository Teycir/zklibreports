param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$Args
)

$ErrorActionPreference = "Stop"

# On this host Echidna is installed as a standalone Windows binary (not on PATH by default).
$echidna = "C:\\echidna\\echidna.exe"
if (!(Test-Path $echidna)) {
  throw "echidna.exe not found at: $echidna"
}

& $echidna @Args
exit $LASTEXITCODE


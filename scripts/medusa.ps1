param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$Args
)

$ErrorActionPreference = "Stop"

# Medusa is installed via `go install` on this host.
$medusa = "C:\\Users\\vboxuser\\go\\bin\\medusa.exe"
if (!(Test-Path $medusa)) {
  throw "medusa.exe not found at: $medusa"
}

& $medusa @Args
exit $LASTEXITCODE


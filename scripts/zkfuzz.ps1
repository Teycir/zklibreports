param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$Args
)

$ErrorActionPreference = "Stop"

$zkfuzz = "C:\\Users\\vboxuser\\Desktop\\Repos\\smartcontractpatternfinder\\zkFuzz\\target\\release\\zkfuzz.exe"
if (!(Test-Path $zkfuzz)) {
  throw "zkfuzz.exe not found at: $zkfuzz"
}

& $zkfuzz @Args
exit $LASTEXITCODE


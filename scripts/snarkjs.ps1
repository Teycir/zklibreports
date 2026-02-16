param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$Args
)

$ErrorActionPreference = "Stop"

# snarkjs is installed via npm on this host. PowerShell invocation is reliable via cmd.exe.
$argv = @("snarkjs.cmd") + $Args
& cmd.exe /c @argv
exit $LASTEXITCODE


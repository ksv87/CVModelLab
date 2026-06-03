# Run the CV Model Lab server (Windows PowerShell).
param(
    [string]$Config = "",
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ExtraArgs
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ServerDir = Resolve-Path (Join-Path $ScriptDir "..\server")

if ([string]::IsNullOrEmpty($Config)) {
    $Config = Join-Path $ServerDir "server.yaml"
}

Push-Location $ServerDir
try {
    uv run python -m cvmlab_server.main --config $Config @ExtraArgs
}
finally {
    Pop-Location
}

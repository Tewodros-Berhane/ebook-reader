param(
  [string]$Device = "windows",
  [switch]$Release,
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$ExtraArgs
)

$ErrorActionPreference = "Stop"
$repoRoot = $PSScriptRoot
$appRoot = Join-Path $repoRoot "helium_reader"
$connFile = Join-Path $repoRoot "credentials\connection-string.txt"

if (-not (Test-Path $connFile)) {
  throw "Missing connection string file: $connFile"
}

$mysqlUri = (Get-Content $connFile -Raw).Trim()
if ([string]::IsNullOrWhiteSpace($mysqlUri)) {
  throw "Connection string file is empty: $connFile"
}

$cmd = @("run", "-d", $Device, "--dart-define=MYSQL_CONNECTION_URI=$mysqlUri")
if ($Release) {
  $cmd += "--release"
}
if ($ExtraArgs) {
  $cmd += $ExtraArgs
}

Push-Location $appRoot
try {
  flutter @cmd
} finally {
  Pop-Location
}

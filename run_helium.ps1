param(
  [string]$Device = "windows",
  [switch]$Release,
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$ExtraArgs
)

$ErrorActionPreference = "Stop"
$repoRoot = $PSScriptRoot
$appRoot = Join-Path $repoRoot "helium_reader"

$cmd = @("run", "-d", $Device)
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

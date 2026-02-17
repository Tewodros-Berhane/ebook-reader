param(
  [string]$Device = "windows",
  [switch]$Release,
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$ExtraArgs
)

Write-Host "[deprecated] run_with_mysql.ps1 was renamed to run_helium.ps1."
& (Join-Path $PSScriptRoot "run_helium.ps1") -Device $Device -Release:$Release @ExtraArgs

param(
  [switch]$Android,
  [switch]$IOS
)

$ErrorActionPreference = "Stop"
$repoRoot = $PSScriptRoot
$credDir = Join-Path $repoRoot "credentials"
$appRoot = Join-Path $repoRoot "helium_reader"

if (-not (Test-Path $credDir)) {
  throw "Missing credentials folder: $credDir"
}

if (-not $Android -and -not $IOS) {
  $Android = $true
  $IOS = $true
}

if ($Android) {
  $androidSource = Join-Path $credDir "apps__mobile__android__app__google-services.json"
  if (-not (Test-Path $androidSource)) {
    $androidSource = Join-Path $credDir "google-services.json"
  }

  if (Test-Path $androidSource) {
    $androidTarget = Join-Path $appRoot "android\app\google-services.json"
    Copy-Item -Force $androidSource $androidTarget
    Write-Host "Copied Android credential file to $androidTarget"
  } else {
    Write-Warning "No Android google-services.json found in credentials folder."
  }
}

if ($IOS) {
  $iosSource = Join-Path $credDir "GoogleService-Info.plist"
  if (Test-Path $iosSource) {
    $iosTarget = Join-Path $appRoot "ios\Runner\GoogleService-Info.plist"
    Copy-Item -Force $iosSource $iosTarget
    Write-Host "Copied iOS credential file to $iosTarget"
  } else {
    Write-Warning "No GoogleService-Info.plist found in credentials folder."
  }
}


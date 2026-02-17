param(
  [switch]$AndroidOnly,
  [switch]$WindowsOnly
)

$ErrorActionPreference = "Stop"

$repoRoot = $PSScriptRoot
$appRoot = Join-Path $repoRoot "helium_reader"


function Invoke-Checked {
  param(
    [Parameter(Mandatory = $true)][string]$Command,
    [string[]]$Arguments = @()
  )

  & $Command @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "Command failed with exit code $($LASTEXITCODE): $Command $($Arguments -join ' ')"
  }
}


function Parse-EnvFile {
  param([Parameter(Mandatory = $true)][string]$Path)

  $map = @{}
  if (-not (Test-Path $Path)) {
    return $map
  }

  foreach ($lineRaw in Get-Content $Path) {
    $line = $lineRaw.Trim()
    if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith("#")) {
      continue
    }

    $idx = $line.IndexOf("=")
    if ($idx -lt 1) {
      continue
    }

    $key = $line.Substring(0, $idx).Trim()
    $value = $line.Substring($idx + 1).Trim()
    $map[$key] = $value
  }

  return $map
}

$desktopEnv = Parse-EnvFile -Path (Join-Path $repoRoot "credentials\apps__desktop__.env.local")
$mobileEnv = Parse-EnvFile -Path (Join-Path $repoRoot "credentials\apps__mobile__.env.local")

$googleClientId = $desktopEnv["NEXT_PUBLIC_DESKTOP_CLIENT_ID"]
$googleClientSecret = $desktopEnv["LUMINA_DESKTOP_CLIENT_SECRET"]
$googleServerClientId = $mobileEnv["NEXT_PUBLIC_MOBILE_WEB_CLIENT_ID"]

if ([string]::IsNullOrWhiteSpace($googleClientId)) {
  throw "Missing NEXT_PUBLIC_DESKTOP_CLIENT_ID in credentials/apps__desktop__.env.local"
}
if ([string]::IsNullOrWhiteSpace($googleClientSecret)) {
  throw "Missing LUMINA_DESKTOP_CLIENT_SECRET in credentials/apps__desktop__.env.local"
}
if ([string]::IsNullOrWhiteSpace($googleServerClientId)) {
  throw "Missing NEXT_PUBLIC_MOBILE_WEB_CLIENT_ID in credentials/apps__mobile__.env.local"
}
$defines = @(
  "--dart-define=GOOGLE_CLIENT_ID=$googleClientId",
  "--dart-define=GOOGLE_SERVER_CLIENT_ID=$googleServerClientId",
  "--dart-define=GOOGLE_CLIENT_SECRET=$googleClientSecret"
)

$buildAndroid = -not $WindowsOnly
$buildWindows = -not $AndroidOnly

Push-Location $appRoot
try {
  if ($buildAndroid) {
    Invoke-Checked -Command "flutter" -Arguments (@("build", "apk", "--release") + $defines)
  }

  if ($buildWindows) {
    Invoke-Checked -Command "flutter" -Arguments (@("build", "windows", "--release") + $defines)

    $isccCandidates = @(
      "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe",
      "$env:ProgramFiles(x86)\Inno Setup 6\ISCC.exe",
      "$env:ProgramFiles\Inno Setup 6\ISCC.exe"
    )

    $isccPath = $isccCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $isccPath) {
      throw "Inno Setup compiler not found. Install Inno Setup 6 and rerun."
    }

    Invoke-Checked -Command $isccPath -Arguments @("windows\installer\helium_reader.iss")
  }
}
finally {
  Pop-Location
}

Write-Host "Build complete."
if ($buildAndroid) {
  Write-Host "APK: $appRoot\build\app\outputs\flutter-apk\app-release.apk"
}
if ($buildWindows) {
  Write-Host "Portable EXE: $appRoot\build\windows\x64\runner\Release\helium_reader.exe"
  Write-Host "Installer EXE: $appRoot\build\installer\HeliumReaderSetup.exe"
}

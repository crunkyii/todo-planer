# Baut die Windows-App und ihren Installer.
#
#   pwsh tool/release/build-windows.ps1
#
# Ergebnis: build/dist/todo-planer-<Version>-setup.exe (Installer ohne Admin-Rechte). Braucht Inno Setup 6.
# Ein ganzes Release (Installer, APK und signierte latest.json) baut tool/release/build-release.ps1.
$ErrorActionPreference = 'Stop'
Set-Location (Resolve-Path "$PSScriptRoot/../..")

$line = Select-String -Path pubspec.yaml -Pattern '^version:\s*(\d+\.\d+\.\d+)' | Select-Object -First 1
if (-not $line) { throw 'Keine Version in pubspec.yaml gefunden.' }
$version = $line.Matches[0].Groups[1].Value

$iscc = @(
  "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe",
  "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
  "$env:ProgramFiles\Inno Setup 6\ISCC.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $iscc) { throw 'Inno Setup 6 nicht gefunden (winget install JRSoftware.InnoSetup).' }

function Invoke-Step([string]$what, [scriptblock]$run) {
  Write-Host "== $what"
  & $run
  if ($LASTEXITCODE -ne 0) { throw "$what fehlgeschlagen." }
}

Invoke-Step 'App bauen' { flutter build windows --release }

$source = Resolve-Path 'build/windows/x64/runner/Release'
$dist = New-Item -ItemType Directory -Force 'build/dist'
Invoke-Step 'Installer bauen' {
  & $iscc /Qp "/DAppVersion=$version" "/DSourceDir=$source" "/DOutputDir=$($dist.FullName)" tool\release\installer.iss
}

Write-Host "Fertig: $(Join-Path $dist.FullName "todo-planer-$version-setup.exe")"

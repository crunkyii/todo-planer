# Baut das Windows-Release: App, Installer und die signierte latest.json fürs Auto-Update.
#
#   pwsh tool/release/build-windows.ps1
#
# Ergebnis in build/dist/:
#   todo-planer-<Version>-setup.exe   Installer (ohne Admin-Rechte)
#   latest.json                       zeigt auf den Installer, mit Signatur
#
# Braucht Inno Setup 6 und den privaten Signier-Schlüssel (einmalig: dart run tool/release/sign.dart keygen).
# Beide Dateien gehören an das GitHub-Release mit dem Tag v<Version>.
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

$installer = Join-Path $dist.FullName "todo-planer-$version-setup.exe"
Invoke-Step 'Signieren' { dart run tool/release/sign.dart sign $installer $version }

Write-Host "Fertig: $installer"

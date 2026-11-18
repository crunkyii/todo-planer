# Baut ein ganzes Release: Windows-Installer, Android-APK und die signierte latest.json fürs Auto-Update.
#
#   pwsh tool/release/build-release.ps1
#
# Ergebnis in build/dist/ – alle drei Dateien gehören an das GitHub-Release mit dem Tag v<Version>:
#   todo-planer-<Version>-setup.exe   Windows-Installer
#   todo-planer-<Version>.apk         Android-App
#   latest.json                       zeigt auf beide, mit je einer Signatur
#
# Braucht Inno Setup 6, android/key.properties (Release-Schlüssel der APK) und den privaten
# Signier-Schlüssel fürs Update (einmalig: dart run tool/release/sign.dart keygen).
#
# Der Ordner, in dem gebaut wird, steht in den fertigen Dateien. Deshalb aus einem neutralen Ordner
# bauen (z. B. C:\src\todo-planer), nicht aus dem eigenen Benutzerordner.
param(
  # Trotzdem im Benutzerordner bauen (nur zum Ausprobieren, nicht für ein echtes Release).
  [switch]$AllowUserPath
)
$ErrorActionPreference = 'Stop'
Set-Location (Resolve-Path "$PSScriptRoot/../..")

if (-not $AllowUserPath -and $env:USERPROFILE -and
    (Get-Location).Path.StartsWith($env:USERPROFILE, [StringComparison]::OrdinalIgnoreCase)) {
  throw 'Dieser Ordner liegt im Benutzerordner – sein Pfad stünde in den Release-Dateien. Aus einem neutralen Ordner bauen (z. B. C:\src\todo-planer).'
}

$line = Select-String -Path pubspec.yaml -Pattern '^version:\s*(\d+\.\d+\.\d+)' | Select-Object -First 1
if (-not $line) { throw 'Keine Version in pubspec.yaml gefunden.' }
$version = $line.Matches[0].Groups[1].Value

function Invoke-Step([string]$what, [scriptblock]$run) {
  Write-Host "== $what"
  & $run
  if ($LASTEXITCODE -ne 0) { throw "$what fehlgeschlagen." }
}

Invoke-Step 'Windows' { & "$PSScriptRoot/build-windows.ps1" }
Invoke-Step 'Android-APK bauen' { flutter build apk --release }

$dist = (Resolve-Path 'build/dist').Path
$installer = Join-Path $dist "todo-planer-$version-setup.exe"
$apk = Join-Path $dist "todo-planer-$version.apk"
Copy-Item 'build/app/outputs/flutter-apk/app-release.apk' $apk -Force

# Die App aktualisiert sich nur, wenn sie mit dem Release-Schlüssel signiert ist – und Android nimmt
# nur eine APK mit derselben Signatur an. Eine anders signierte APK darf also nie ins Release.
$expected = (Select-String -Path lib/services/update_manifest.dart -Pattern "releaseCertSha256 = '([0-9a-f]{64})'").Matches[0].Groups[1].Value
$sdk = @($env:ANDROID_HOME, $env:ANDROID_SDK_ROOT, "$env:LOCALAPPDATA\Android\Sdk") |
  Where-Object { $_ -and (Test-Path "$_\build-tools") } | Select-Object -First 1
$apksigner = if ($sdk) {
  Get-ChildItem "$sdk\build-tools\*\apksigner.bat" | Sort-Object { [version]($_.Directory.Name -replace '[^\d.]') } |
    Select-Object -Last 1
}
if (-not $apksigner) { throw 'apksigner nicht gefunden (Android SDK Build-Tools).' }
$certs = & $apksigner.FullName verify --print-certs $apk
if ($LASTEXITCODE -ne 0) { throw 'Die APK hat keine gültige Signatur.' }
$digests = @($certs | Select-String 'certificate SHA-256 digest: ([0-9a-f]{64})' | ForEach-Object { $_.Matches[0].Groups[1].Value })
if ($digests.Count -ne 1 -or $digests[0] -ne $expected) {
  throw 'Die APK ist nicht mit dem Release-Schlüssel signiert (releaseCertSha256 in lib/services/update_manifest.dart).'
}

Invoke-Step 'Signieren' { dart run tool/release/sign.dart sign $installer $version $apk }

Write-Host "Fertig – an das Release v$version hängen:"
Write-Host "  $installer"
Write-Host "  $apk"
Write-Host "  $(Join-Path $dist 'latest.json')"

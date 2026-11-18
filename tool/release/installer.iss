; Windows-Installer für den ToDo Planer (Inno Setup 6).
;
; Installiert nur für den angemeldeten Benutzer nach %LOCALAPPDATA%\Programs – ohne Admin-Rechte
; und ohne UAC-Abfrage. Gebaut wird er über tool/release/build-windows.ps1:
;
;   ISCC /DAppVersion=1.1.0 /DSourceDir=<Release-Ordner> /DOutputDir=<Ziel> tool\release\installer.iss

#ifndef AppVersion
  #error AppVersion fehlt (/DAppVersion=1.2.3)
#endif
#ifndef SourceDir
  #define SourceDir "..\..\build\windows\x64\runner\Release"
#endif
#ifndef OutputDir
  #define OutputDir "..\..\build\dist"
#endif

#define AppName "ToDo Planer"
#define AppExe "todo_planer.exe"

[Setup]
; Diese Kennung nie ändern – daran erkennt Windows, dass ein Update dieselbe App ist.
AppId={{05A26CFA-8F63-4FF5-B1B1-464B5AAC30F1}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher=crunkyii
AppPublisherURL=https://github.com/crunkyii/todo-planer
AppSupportURL=https://github.com/crunkyii/todo-planer/issues
AppUpdatesURL=https://github.com/crunkyii/todo-planer/releases
VersionInfoVersion={#AppVersion}
PrivilegesRequired=lowest
DefaultDirName={localappdata}\Programs\{#AppName}
DisableDirPage=yes
DisableProgramGroupPage=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
WizardStyle=modern
SetupIconFile=..\..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExe}
UninstallDisplayName={#AppName}
LicenseFile=..\..\LICENSE
Compression=lzma2
SolidCompression=yes
OutputDir={#OutputDir}
OutputBaseFilename=todo-planer-{#AppVersion}-setup
; Läuft die App noch (Update aus der App heraus), wird sie geschlossen statt mit einem Fehler abzubrechen.
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "de"; MessagesFile: "compiler:Languages\German.isl"
Name: "en"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
; Nach der Installation starten – auch beim stillen Update, damit die App gleich wieder da ist.
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall

[InstallDelete]
; Vor einem Update die Dateien der alten Version entfernen, die es in der neuen nicht mehr gibt
; (nur Programmdateien – die Aufgaben liegen nicht im Programmordner).
Type: filesandordirs; Name: "{app}\data"
; Bis Version 1.1.0 hieß die App „Todo-Planer“ und das Programm todo_liste.exe.
Type: files; Name: "{app}\todo_liste.exe"
Type: files; Name: "{autoprograms}\Todo-Planer.lnk"
Type: files; Name: "{autodesktop}\Todo-Planer.lnk"

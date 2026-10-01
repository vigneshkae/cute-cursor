#ifndef AppVersion
  #error AppVersion must be supplied by build-windows-installer.ps1
#endif

[Setup]
AppId={{8B13D535-4DF2-47CB-8DE3-F70882D2A737}
AppName=Cute Cursor
AppVersion={#AppVersion}
AppPublisher=Vignesh Kumar
AppPublisherURL=https://github.com/vigneshkae/cute-cursor
AppSupportURL=https://github.com/vigneshkae/cute-cursor/issues
DefaultDirName={localappdata}\Programs\Cute Cursor
DefaultGroupName=Cute Cursor
DisableDirPage=yes
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible or arm64
ArchitecturesInstallIn64BitMode=x64compatible or arm64
MinVersion=10.0.22000
AppMutex=Local\CuteCursor.Windows
CloseApplications=no
RestartApplications=no
UninstallDisplayIcon={app}\CuteCursor.exe
SetupIconFile=..\CuteCursor.Windows\Assets\CuteCursorBloom.ico
LicenseFile=..\..\LICENSE
OutputDir=..\..\dist
OutputBaseFilename=Cute-Cursor-Setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern

[Messages]
SetupAppRunningError=%1 is still running.%n%nChoose Exit Cute Cursor from its system-tray icon first so your original cursors are restored. Then click OK to continue, or Cancel to exit.
UninstallAppRunningError=%1 is still running.%n%nChoose Exit Cute Cursor from its system-tray icon first so your original cursors are restored. Then click OK to continue, or Cancel to exit.

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; Flags: unchecked

[Files]
Source: "..\..\dist\windows\win-x64\CuteCursor.exe"; DestDir: "{app}"; Flags: ignoreversion; Check: not IsArm64
Source: "..\..\dist\windows\win-arm64\CuteCursor.exe"; DestDir: "{app}"; Flags: ignoreversion; Check: IsArm64
Source: "..\..\LICENSE"; DestDir: "{app}"; DestName: "LICENSE.txt"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\Cute Cursor"; Filename: "{app}\CuteCursor.exe"
Name: "{autodesktop}\Cute Cursor"; Filename: "{app}\CuteCursor.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\CuteCursor.exe"; Description: "Open Cute Cursor"; Flags: nowait postinstall skipifsilent

; The library lives in LocalAppData\CuteCursor, outside the installation folder.
; Do not add UninstallDelete rules: users keep their cursors when uninstalling.

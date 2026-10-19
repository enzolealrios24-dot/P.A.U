; Instalador Windows do C.R.I.S (Inno Setup)
#define AppVersion GetEnv("APP_VERSION")
[Setup]
AppId={{7C1E9A3B-5F0D-4C9E-9C47-2B8C1D0A6E11}
AppName=C.R.I.S
AppVersion={#AppVersion}
DefaultDirName={localappdata}\CRIS
DefaultGroupName=C.R.I.S
PrivilegesRequired=lowest
OutputDir=..\dist
OutputBaseFilename=CRIS-Instalador-Windows
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\cris_ficha.exe

[Languages]
Name: "brazilianportuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"

[Tasks]
Name: "desktopicon"; Description: "Criar atalho na área de trabalho"; GroupDescription: "Atalhos:"

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\C.R.I.S"; Filename: "{app}\cris_ficha.exe"
Name: "{autodesktop}\C.R.I.S"; Filename: "{app}\cris_ficha.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\cris_ficha.exe"; Description: "Abrir o C.R.I.S"; Flags: nowait postinstall skipifsilent

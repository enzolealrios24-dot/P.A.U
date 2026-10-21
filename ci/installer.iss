; Instalador Windows do P.A.U (Inno Setup)
; O AppId continua o mesmo: instala por cima da versão que ainda se chamava C.R.I.S.
#define AppVersion GetEnv("APP_VERSION")
[Setup]
AppId={{7C1E9A3B-5F0D-4C9E-9C47-2B8C1D0A6E11}
AppName=P.A.U
AppVersion={#AppVersion}
DefaultDirName={localappdata}\CRIS
DefaultGroupName=P.A.U
UsePreviousGroup=no
PrivilegesRequired=lowest
OutputDir=..\dist
OutputBaseFilename=PAU-Instalador-Windows
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

[InstallDelete]
; atalhos do nome antigo
Type: files; Name: "{autodesktop}\C.R.I.S.lnk"
Type: filesandordirs; Name: "{autoprograms}\C.R.I.S"

[Icons]
Name: "{group}\P.A.U"; Filename: "{app}\cris_ficha.exe"
Name: "{autodesktop}\P.A.U"; Filename: "{app}\cris_ficha.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\cris_ficha.exe"; Description: "Abrir o P.A.U"; Flags: nowait postinstall skipifsilent

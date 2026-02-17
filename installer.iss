; SideKick_PS Inno Setup Installer Script
; Compile with Inno Setup 6.x: https://jrsoftware.org/isinfo.php
;
; FULLY SELF-CONTAINED - All EXE files, no source scripts

#define MyAppName "SideKick_PS"
#define MyAppVersion "2.5.9"
#define MyAppPublisher "Zoom Photography"
#define MyAppEmail "guy@zoom-photo.co.uk"
#define MyAppExeName "SideKick_PS.exe"
#define MyAppDescription "ProSelect Automation & GHL Integration"

[Setup]
; Application info
AppId={{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppSupportURL=mailto:{#MyAppEmail}
AppUpdatesURL=https://github.com/GuyMayer/SideKick_PS/releases
AppComments={#MyAppDescription}
AppCopyright=Copyright (C) 2026 Zoom Photography

; Install location
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes

; Output settings
OutputDir=Releases\\latest
OutputBaseFilename=SideKick_PS_Setup
; SetupIconFile - use icon from Release folder (copied during build)
SetupIconFile=Release\SideKick_PS.ico
Compression=lzma2/ultra64
SolidCompression=yes
LZMAUseSeparateProcess=yes

; Privileges (user-level install, no admin needed)
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog

; UI
WizardStyle=modern
WizardSizePercent=100

; License Agreement - REQUIRED acceptance before install
LicenseFile=LICENSE.txt

; Uninstall
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName}
CreateUninstallRegKey=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"
Name: "startupicon"; Description: "Start with Windows"; GroupDescription: "Startup:"; Flags: unchecked

[Files]
; Main executable (compiled AHK)
Source: "Release\SideKick_PS.exe"; DestDir: "{app}"; Flags: ignoreversion

; App icon
Source: "Release\SideKick_PS.ico"; DestDir: "{app}"; Flags: ignoreversion

; Phosphor Thin - bundled icon font (MIT licensed, thin outline style)
; Installs to user fonts folder (no admin required)
Source: "Release\fonts\Phosphor-Thin.ttf"; DestDir: "{autofonts}"; FontInstall: "Phosphor Thin"; Flags: onlyifdoesntexist uninsneveruninstall

; Font Awesome 6 Free Solid - fallback icon font (OFL licensed)
Source: "Release\fonts\fa-solid-900.ttf"; DestDir: "{autofonts}"; FontInstall: "Font Awesome 6 Free Solid"; Flags: onlyifdoesntexist uninsneveruninstall

; Logo images for Settings GUI
Source: "Release\SideKick_Logo_2025_Dark.png"; DestDir: "{app}"; Flags: ignoreversion
Source: "Release\SideKick_Logo_2025_Light.png"; DestDir: "{app}"; Flags: ignoreversion

; Python executables (compiled with cryptic names - NO Python install needed)
Source: "Release\_vlk.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "Release\_sps.exe"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist
Source: "Release\_upm.exe"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist
Source: "Release\_ccs.exe"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist
Source: "Release\_fgc.exe"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist
Source: "Release\_ugc.exe"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist

; License and version info
Source: "Release\LICENSE.txt"; DestDir: "{app}"; Flags: ignoreversion
Source: "Release\version.json"; DestDir: "{app}"; Flags: ignoreversion

; Media files (icons, sounds)
Source: "Release\media\*"; DestDir: "{app}\media"; Flags: ignoreversion recursesubdirs createallsubdirs skipifsourcedoesntexist

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon
Name: "{userstartup}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: startupicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Code]
var
  IniBackupPath: String;

// Backup INI file before installation starts
procedure CurStepChanged(CurStep: TSetupStep);
var
  IniSourcePath, IniAppDataFolder, IniAppDataPath: String;
begin
  if CurStep = ssInstall then
  begin
    // Backup existing INI file before install overwrites anything
    // Check both old location (app folder) and new location (AppData)
    IniSourcePath := ExpandConstant('{app}\SideKick_PS.ini');
    IniAppDataPath := ExpandConstant('{userappdata}\SideKick_PS\SideKick_PS.ini');
    IniBackupPath := ExpandConstant('{tmp}\SideKick_PS.ini.backup');
    
    // Prefer AppData version (newer), fall back to app folder (older installs)
    if FileExists(IniAppDataPath) then
    begin
      FileCopy(IniAppDataPath, IniBackupPath, False);
    end
    else if FileExists(IniSourcePath) then
    begin
      FileCopy(IniSourcePath, IniBackupPath, False);
    end;
  end
  else if CurStep = ssPostInstall then
  begin
    // Restore INI file to BOTH locations for compatibility
    IniSourcePath := ExpandConstant('{app}\SideKick_PS.ini');
    IniAppDataFolder := ExpandConstant('{userappdata}\SideKick_PS');
    IniAppDataPath := ExpandConstant('{userappdata}\SideKick_PS\SideKick_PS.ini');
    
    if FileExists(IniBackupPath) then
    begin
      // Create AppData folder if it doesn't exist
      if not DirExists(IniAppDataFolder) then
        CreateDir(IniAppDataFolder);
      
      // Restore to both locations
      FileCopy(IniBackupPath, IniSourcePath, False);
      FileCopy(IniBackupPath, IniAppDataPath, False);
      DeleteFile(IniBackupPath);
    end;
  end;
end;





















































































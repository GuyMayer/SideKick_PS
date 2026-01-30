; SideKick_PS Inno Setup Installer Script
; Compile with Inno Setup 6.x: https://jrsoftware.org/isinfo.php
;
; FULLY SELF-CONTAINED - All EXE files, no source scripts

#define MyAppName "SideKick_PS"
#define MyAppVersion "2.4.16"
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

; Python executables (compiled - NO Python install needed)
Source: "Release\validate_license.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "Release\fetch_ghl_contact.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "Release\update_ghl_contact.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "Release\sync_ps_invoice_v2.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "Release\upload_ghl_media.exe"; DestDir: "{app}"; Flags: ignoreversion

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
// Update version in .iss file dynamically
procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    // Could add post-install tasks here
  end;
end;















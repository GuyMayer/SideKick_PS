# build_and_archive.ps1 - Build SideKick_PS and archive to Releases folder
# 
# This script:
# 1. Compiles SideKick_PS.ahk to .exe
# 2. Copies all required files to Release folder
# 3. Archives a copy to Releases\vX.X.X folder
# 4. Creates a ZIP for uploading to GitHub

param(
    [Parameter(Mandatory=$true)]
    [string]$Version
)

$ErrorActionPreference = "Stop"

# Paths
$ScriptDir = $PSScriptRoot
$SourceDir = "C:\Stash"
$ReleaseDir = "$ScriptDir\Release"
$ArchiveDir = "$ScriptDir\Releases\v$Version"

# AHK Compiler path
$Ahk2Exe = "C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe"
if (!(Test-Path $Ahk2Exe)) {
    $Ahk2Exe = "${env:ProgramFiles}\AutoHotkey\Compiler\Ahk2Exe.exe"
}
if (!(Test-Path $Ahk2Exe)) {
    $Ahk2Exe = "${env:LOCALAPPDATA}\Programs\AutoHotkey\Compiler\Ahk2Exe.exe"
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " SideKick_PS Build & Archive v$Version" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Clean up Release folder
Write-Host "`n[1/6] Cleaning Release folder..." -ForegroundColor Yellow
if (Test-Path $ReleaseDir) { Remove-Item $ReleaseDir -Recurse -Force }
New-Item -ItemType Directory -Path $ReleaseDir -Force | Out-Null
New-Item -ItemType Directory -Path "$ReleaseDir\Lib" -Force | Out-Null

# Create archive folder
Write-Host "`n[2/6] Creating archive folder..." -ForegroundColor Yellow
if (Test-Path $ArchiveDir) { 
    Write-Host "  Archive v$Version already exists. Removing..." -ForegroundColor Yellow
    Remove-Item $ArchiveDir -Recurse -Force 
}
New-Item -ItemType Directory -Path $ArchiveDir -Force | Out-Null

# Compile AHK to EXE
Write-Host "`n[3/6] Compiling SideKick_PS.ahk to EXE..." -ForegroundColor Yellow
if (Test-Path $Ahk2Exe) {
    $ahkSource = "$SourceDir\SideKick_PS.ahk"
    $exeOutput = "$ReleaseDir\SideKick_PS.exe"
    
    # Compile with icon if available
    $iconPath = "$SourceDir\SideKick_PS\media\SideKick_PS.ico"
    if (!(Test-Path $iconPath)) { $iconPath = "$SourceDir\SideKick_PS.ico" }
    
    if (Test-Path $iconPath) {
        & $Ahk2Exe /in $ahkSource /out $exeOutput /icon $iconPath
    } else {
        & $Ahk2Exe /in $ahkSource /out $exeOutput
    }
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Compilation failed!" -ForegroundColor Red
        exit 1
    }
    Write-Host "  Compiled: SideKick_PS.exe" -ForegroundColor Green
} else {
    Write-Host "  ERROR: Ahk2Exe not found!" -ForegroundColor Red
    exit 1
}

# Copy Python scripts
Write-Host "`n[4/6] Copying Python scripts..." -ForegroundColor Yellow
$pythonFiles = @(
    "validate_license.py",
    "check_updates.py",
    "fetch_ghl_contact.py",
    "update_ghl_contact.py",
    "sync_ps_invoice_v2.py",
    "upload_ghl_media.py"
)

foreach ($file in $pythonFiles) {
    $src = "$SourceDir\$file"
    if (Test-Path $src) {
        Copy-Item $src "$ReleaseDir\$file"
        Write-Host "  Copied: $file" -ForegroundColor Gray
    }
}

# Copy Lib folder
Write-Host "`n[5/6] Copying Lib files..." -ForegroundColor Yellow
$libFiles = @("Acc.ahk", "Chrome.ahk", "Notes.ahk")
foreach ($file in $libFiles) {
    $src = "$SourceDir\Lib\$file"
    if (Test-Path $src) {
        Copy-Item $src "$ReleaseDir\Lib\$file"
        Write-Host "  Copied: Lib\$file" -ForegroundColor Gray
    }
}

# Copy INI template
$iniTemplate = "$SourceDir\SideKick_PS.ini"
if (Test-Path $iniTemplate) {
    Copy-Item $iniTemplate "$ReleaseDir\SideKick_PS.ini.template"
}

# Create version info file
@"
{
    "version": "$Version",
    "build_date": "$(Get-Date -Format 'yyyy-MM-dd')",
    "download_url": "https://github.com/GuyMayer/SideKick_PS/releases/latest"
}
"@ | Out-File "$ReleaseDir\version.json" -Encoding UTF8

# Archive release
Write-Host "`n[6/6] Archiving to Releases\v$Version..." -ForegroundColor Yellow
Copy-Item "$ReleaseDir\*" $ArchiveDir -Recurse -Force

# Create ZIP
$zipPath = "$ArchiveDir\SideKick_PS_v$Version.zip"
Compress-Archive -Path "$ReleaseDir\*" -DestinationPath $zipPath -Force
Write-Host "  Created: SideKick_PS_v$Version.zip" -ForegroundColor Green

Write-Host "`n========================================" -ForegroundColor Green
Write-Host " Build Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host " Release folder: $ReleaseDir" -ForegroundColor Cyan
Write-Host " Archive folder: $ArchiveDir" -ForegroundColor Cyan
Write-Host " ZIP file:       $zipPath" -ForegroundColor Cyan
Write-Host ""
Write-Host " Next steps:" -ForegroundColor Yellow
Write-Host " 1. Go to https://github.com/GuyMayer/SideKick_PS/releases" -ForegroundColor White
Write-Host " 2. Click 'Create a new release'" -ForegroundColor White
Write-Host " 3. Tag: v$Version" -ForegroundColor White
Write-Host " 4. Upload: $zipPath" -ForegroundColor White
Write-Host " 5. Publish!" -ForegroundColor White
Write-Host ""

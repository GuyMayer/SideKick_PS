# build_and_archive.ps1 - Build SideKick_PS Release (EXE only - no scripts)
# 
# This script:
# 1. Compiles SideKick_PS.ahk to .exe
# 2. Compiles all Python scripts to .exe using PyInstaller
# 3. Archives a copy to Releases\vX.X.X folder
# 4. Creates a ZIP for uploading to GitHub
#
# IMPORTANT: Only .exe files are distributed - NO source scripts!

param(
    [Parameter(Mandatory=$true)]
    [string]$Version,
    
    [switch]$SkipPythonCompile = $false
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
Write-Host " SideKick_PS Build v$Version" -ForegroundColor Cyan
Write-Host " (EXE only - no source scripts)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Clean up Release folder
Write-Host "`n[1/8] Cleaning Release folder..." -ForegroundColor Yellow
if (Test-Path $ReleaseDir) { Remove-Item $ReleaseDir -Recurse -Force }
New-Item -ItemType Directory -Path $ReleaseDir -Force | Out-Null

# Create archive folder
Write-Host "`n[2/8] Creating archive folder..." -ForegroundColor Yellow
if (Test-Path $ArchiveDir) { 
    Write-Host "  Archive v$Version already exists. Removing..." -ForegroundColor Yellow
    Remove-Item $ArchiveDir -Recurse -Force 
}
New-Item -ItemType Directory -Path $ArchiveDir -Force | Out-Null

# Compile AHK to EXE
Write-Host "`n[3/8] Compiling SideKick_PS.ahk to EXE..." -ForegroundColor Yellow
if (Test-Path $Ahk2Exe) {
    $ahkSource = "$SourceDir\SideKick_PS.ahk"
    $exeOutput = "$ReleaseDir\SideKick_PS.exe"
    
    # Compile with icon if available
    $iconPath = "$ScriptDir\media\SideKick_PS.ico"
    if (!(Test-Path $iconPath)) { $iconPath = "$SourceDir\SideKick_PS.ico" }
    
    if (Test-Path $iconPath) {
        & $Ahk2Exe /in $ahkSource /out $exeOutput /icon $iconPath 2>&1 | Out-Null
    } else {
        & $Ahk2Exe /in $ahkSource /out $exeOutput 2>&1 | Out-Null
    }
    
    # Check if EXE was created (more reliable than exit code)
    Start-Sleep -Milliseconds 500
    if (!(Test-Path $exeOutput)) {
        Write-Host "  ERROR: Compilation failed - EXE not created!" -ForegroundColor Red
        exit 1
    }
    Write-Host "  ✓ Compiled: SideKick_PS.exe" -ForegroundColor Green
} else {
    Write-Host "  ERROR: Ahk2Exe not found!" -ForegroundColor Red
    exit 1
}

# Compile Python scripts to EXE using PyInstaller
Write-Host "`n[4/8] Compiling Python scripts to EXE..." -ForegroundColor Yellow
$pythonFiles = @(
    "validate_license",
    "fetch_ghl_contact",
    "update_ghl_contact",
    "sync_ps_invoice_v2",
    "upload_ghl_media"
)

if (!$SkipPythonCompile) {
    # Check if PyInstaller is installed
    $pyinstallerCheck = & pip show pyinstaller 2>$null
    if (!$pyinstallerCheck) {
        Write-Host "  PyInstaller not found. Installing..." -ForegroundColor Yellow
        & pip install pyinstaller
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  ERROR: Failed to install PyInstaller!" -ForegroundColor Red
            exit 1
        }
        Write-Host "  ✓ PyInstaller installed" -ForegroundColor Green
    } else {
        Write-Host "  PyInstaller already installed" -ForegroundColor Gray
    }
    
    foreach ($script in $pythonFiles) {
        $pyFile = "$SourceDir\$script.py"
        if (Test-Path $pyFile) {
            Write-Host "  Compiling: $script.py" -ForegroundColor Gray
            
            # PyInstaller - single file, no console
            $result = pyinstaller --onefile --noconsole --clean --distpath $ReleaseDir --workpath "$env:TEMP\pyinstaller_work" --specpath "$env:TEMP\pyinstaller_spec" --name $script $pyFile 2>&1
            
            if (Test-Path "$ReleaseDir\$script.exe") {
                Write-Host "    ✓ $script.exe" -ForegroundColor Green
            } else {
                Write-Host "    ✗ Failed: $script.py" -ForegroundColor Red
            }
        }
    }
} else {
    Write-Host "  Skipped (--SkipPythonCompile flag)" -ForegroundColor Gray
}

# Copy media files
Write-Host "`n[5/8] Copying media files..." -ForegroundColor Yellow
$mediaDir = "$ScriptDir\media"
if (Test-Path $mediaDir) {
    New-Item -ItemType Directory -Path "$ReleaseDir\media" -Force | Out-Null
    Copy-Item "$mediaDir\*" "$ReleaseDir\media\" -Recurse -Force
    Write-Host "  Copied media folder" -ForegroundColor Gray
}

# Copy EULA/License
Write-Host "`n[6/8] Copying license files..." -ForegroundColor Yellow
$eulaFile = "$ScriptDir\LICENSE.txt"
if (Test-Path $eulaFile) {
    Copy-Item $eulaFile "$ReleaseDir\LICENSE.txt"
    Write-Host "  Copied LICENSE.txt" -ForegroundColor Gray
} else {
    Write-Host "  WARNING: LICENSE.txt not found!" -ForegroundColor Yellow
}

# Verify no source scripts in release (EXE ONLY!)
Write-Host "`n[7/8] Verifying no source scripts..." -ForegroundColor Yellow
$sourceFiles = Get-ChildItem $ReleaseDir -Include "*.py","*.ahk" -Recurse -ErrorAction SilentlyContinue
if ($sourceFiles) {
    Write-Host "  Removing source scripts from release..." -ForegroundColor Yellow
    $sourceFiles | Remove-Item -Force
}
Write-Host "  ✓ Release contains EXE files only" -ForegroundColor Green

# Create version info file
@"
{
    "version": "$Version",
    "build_date": "$(Get-Date -Format 'yyyy-MM-dd')",
    "download_url": "https://github.com/GuyMayer/SideKick_PS/releases/latest"
}
"@ | Out-File "$ReleaseDir\version.json" -Encoding UTF8

# Archive release - only keep ZIP in archive (not individual files)
Write-Host "`n[6/6] Creating distribution ZIP..." -ForegroundColor Yellow
New-Item -ItemType Directory -Path $ArchiveDir -Force | Out-Null

# Create ZIP only
$zipPath = "$ArchiveDir\SideKick_PS_v$Version.zip"
Compress-Archive -Path "$ReleaseDir\*" -DestinationPath $zipPath -Force
Write-Host "  Created: SideKick_PS_v$Version.zip" -ForegroundColor Green

# Calculate ZIP size
$zipSize = (Get-Item $zipPath).Length / 1MB
Write-Host "  Size: $([math]::Round($zipSize, 2)) MB" -ForegroundColor Gray

Write-Host "`n========================================" -ForegroundColor Green
Write-Host " Build Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host " ZIP file: $zipPath" -ForegroundColor Cyan
Write-Host ""
Write-Host " The ZIP contains:" -ForegroundColor Yellow
Get-ChildItem $ReleaseDir -Name | ForEach-Object { Write-Host "   - $_" -ForegroundColor Gray }
Write-Host ""
Write-Host " Ready for GitHub release!" -ForegroundColor Green
Write-Host ""

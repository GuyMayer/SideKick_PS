# build_and_archive.ps1 - Build SideKick_PS Release (EXE only - no scripts)
# 
# This script:
# 1. Compiles SideKick_PS.ahk to .exe
# 2. Compiles all Python scripts to .exe using PyInstaller
# 3. Archives a copy to Releases\vX.X.X folder
# 4. Creates a ZIP for uploading to GitHub
#
# IMPORTANT: Only .exe files are distributed - NO source scripts!
# OPTIMIZATION: Caching disabled - always recompile for reliability

param(
    [Parameter(Mandatory=$true)]
    [string]$Version,
    
    [switch]$SkipPythonCompile = $false,
    [switch]$ForceRebuild = $true
)

$ErrorActionPreference = "Stop"

# Paths
$ScriptDir = $PSScriptRoot
$SourceDir = $ScriptDir
$ReleaseDir = "$ScriptDir\Release"
$ArchiveDir = "$ScriptDir\Releases\latest"
$CacheDir = "$ScriptDir\.build_cache"
$HashFile = "$CacheDir\file_hashes.json"

# Create cache directory
if (!(Test-Path $CacheDir)) {
    New-Item -ItemType Directory -Path $CacheDir -Force | Out-Null
}

# Load cached hashes
$cachedHashes = @{}
if (Test-Path $HashFile) {
    try {
        $jsonContent = Get-Content $HashFile -Raw | ConvertFrom-Json
        # Convert PSObject to hashtable
        $jsonContent.PSObject.Properties | ForEach-Object {
            $cachedHashes[$_.Name] = $_.Value
        }
        Write-Host "  Loaded cache with $($cachedHashes.Count) entries" -ForegroundColor Gray
    } catch {
        Write-Host "  Cache file invalid, starting fresh" -ForegroundColor Yellow
        $cachedHashes = @{}
    }
}

# Function to get file hash
function Get-FileHashMD5($path) {
    if (Test-Path $path) {
        return (Get-FileHash -Path $path -Algorithm MD5).Hash
    }
    return $null
}

# Function to check if file needs recompile
function Test-NeedsRecompile($sourceFile, $exeName) {
    if ($ForceRebuild) { return $true }
    
    $currentHash = Get-FileHashMD5 $sourceFile
    $cachedExe = "$CacheDir\$exeName"
    
    if (!(Test-Path $cachedExe)) { return $true }
    if (!$cachedHashes.ContainsKey($sourceFile)) { return $true }
    if ($cachedHashes[$sourceFile] -ne $currentHash) { return $true }
    
    return $false
}

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
if ($ForceRebuild) {
    Write-Host " [FORCE REBUILD - ignoring cache]" -ForegroundColor Yellow
}
Write-Host "========================================" -ForegroundColor Cyan

# Clean up Release folder
Write-Host "`n[1/8] Cleaning Release folder..." -ForegroundColor Yellow
if (Test-Path $ReleaseDir) { Remove-Item $ReleaseDir -Recurse -Force }
New-Item -ItemType Directory -Path $ReleaseDir -Force | Out-Null

# Create archive folder
Write-Host "`n[2/8] Creating archive folder..." -ForegroundColor Yellow
if (Test-Path $ArchiveDir) { 
    Write-Host "  Archive folder exists. Cleaning..." -ForegroundColor Yellow
    Remove-Item $ArchiveDir -Recurse -Force 
}
New-Item -ItemType Directory -Path $ArchiveDir -Force | Out-Null

# Compile AHK to EXE (always recompile - it's fast and version changes each time)
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
    Write-Host "  [OK] Compiled: SideKick_PS.exe" -ForegroundColor Green
} else {
    Write-Host "  ERROR: Ahk2Exe not found!" -ForegroundColor Red
    exit 1
}

# Compile Python scripts to EXE using PyInstaller (with caching)
Write-Host "`n[4/8] Compiling Python scripts to EXE..." -ForegroundColor Yellow
$pythonFiles = @(
    "validate_license",
    "fetch_ghl_contact",
    "update_ghl_contact",
    "sync_ps_invoice",
    "upload_ghl_media"
)

$compiledCount = 0
$cachedCount = 0

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
        Write-Host "  [OK] PyInstaller installed" -ForegroundColor Green
    }
    
    # Find PyInstaller executable (check multiple locations)
    $pyinstallerExe = "pyinstaller"
    $userScriptsPath = "$env:APPDATA\Python\Python314\Scripts\pyinstaller.exe"
    $userScriptsPath2 = "$env:APPDATA\Python\Python313\Scripts\pyinstaller.exe"
    $userScriptsPath3 = "$env:APPDATA\Python\Python312\Scripts\pyinstaller.exe"
    $venvPath = "C:\Stash\.venv\Scripts\pyinstaller.exe"
    
    if (Test-Path $venvPath) {
        $pyinstallerExe = $venvPath
    } elseif (Test-Path $userScriptsPath) {
        $pyinstallerExe = $userScriptsPath
    } elseif (Test-Path $userScriptsPath2) {
        $pyinstallerExe = $userScriptsPath2
    } elseif (Test-Path $userScriptsPath3) {
        $pyinstallerExe = $userScriptsPath3
    }
    
    foreach ($script in $pythonFiles) {
        $pyFile = "$SourceDir\$script.py"
        $exeName = "$script.exe"
        $cachedExe = "$CacheDir\$exeName"
        
        if (Test-Path $pyFile) {
            # Check if we can use cached version
            if (!(Test-NeedsRecompile $pyFile $exeName)) {
                # Use cached EXE
                Copy-Item $cachedExe "$ReleaseDir\$exeName" -Force
                Write-Host "  [CACHED] $script.exe" -ForegroundColor Cyan
                $cachedCount++
            } else {
                # Need to recompile
                Write-Host "  Compiling: $script.py" -ForegroundColor Gray
                
                # PyInstaller - single file, no console (suppress stderr output)
                $ErrorActionPreference = "SilentlyContinue"
                & $pyinstallerExe --onefile --noconsole --clean --distpath $ReleaseDir --workpath "$env:TEMP\pyinstaller_work" --specpath "$env:TEMP\pyinstaller_spec" --name $script $pyFile 2>$null | Out-Null
                $ErrorActionPreference = "Stop"
                
                if (Test-Path "$ReleaseDir\$exeName") {
                    Write-Host "    [OK] $script.exe" -ForegroundColor Green
                    $compiledCount++
                    
                    # Cache the compiled EXE and update hash
                    Copy-Item "$ReleaseDir\$exeName" $cachedExe -Force
                    $cachedHashes[$pyFile] = Get-FileHashMD5 $pyFile
                } else {
                    Write-Host "    [X] Failed: $script.py" -ForegroundColor Red
                }
            }
        }
    }
    
    # Save updated hashes
    $cachedHashes | ConvertTo-Json | Set-Content $HashFile -Force
    
    Write-Host "  Summary: $compiledCount compiled, $cachedCount from cache" -ForegroundColor Gray
} else {
    Write-Host '  Skipped (-SkipPythonCompile flag)' -ForegroundColor Gray
}

# Copy media files
Write-Host "`n[5/8] Copying media files..." -ForegroundColor Yellow
$mediaDir = "$ScriptDir\media"
if (Test-Path $mediaDir) {
    New-Item -ItemType Directory -Path "$ReleaseDir\media" -Force | Out-Null
    Copy-Item "$mediaDir\*" "$ReleaseDir\media\" -Recurse -Force
    Write-Host "  Copied media folder" -ForegroundColor Gray
}

# Copy icon file for installer
$iconPath = "$SourceDir\Images\SideKick_PS.ico"
if (!(Test-Path $iconPath)) { $iconPath = "$SourceDir\SideKick_PS.ico" }
if (Test-Path $iconPath) {
    Copy-Item $iconPath "$ReleaseDir\SideKick_PS.ico"
    Write-Host "  Copied SideKick_PS.ico" -ForegroundColor Gray
}

# Copy logo PNG files for Settings GUI
$logoDark = "$SourceDir\SideKick_Logo_2025_Dark.png"
$logoLight = "$SourceDir\SideKick_Logo_2025_Light.png"
if (!(Test-Path $logoDark)) { $logoDark = "$SourceDir\Media\SideKick_Logo_2025_Dark.png" }
if (!(Test-Path $logoLight)) { $logoLight = "$SourceDir\Media\SideKick_Logo_2025_Light.png" }
if (Test-Path $logoDark) {
    Copy-Item $logoDark "$ReleaseDir\SideKick_Logo_2025_Dark.png"
    Write-Host "  Copied SideKick_Logo_2025_Dark.png" -ForegroundColor Gray
}
if (Test-Path $logoLight) {
    Copy-Item $logoLight "$ReleaseDir\SideKick_Logo_2025_Light.png"
    Write-Host "  Copied SideKick_Logo_2025_Light.png" -ForegroundColor Gray
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
Write-Host "`n[7/9] Verifying no source scripts..." -ForegroundColor Yellow
$sourceFiles = Get-ChildItem $ReleaseDir -Include "*.py","*.ahk" -Recurse -ErrorAction SilentlyContinue
if ($sourceFiles) {
    Write-Host "  Removing source scripts from release..." -ForegroundColor Yellow
    $sourceFiles | Remove-Item -Force
}
Write-Host "  [OK] Release contains EXE files only" -ForegroundColor Green

# Create version info file
@"
{
    "version": "$Version",
    "build_date": "$(Get-Date -Format 'yyyy-MM-dd')",
    "download_url": "https://github.com/GuyMayer/SideKick_PS/releases/latest"
}
"@ | Out-File "$ReleaseDir\version.json" -Encoding UTF8

# Update installer.iss version
Write-Host "`n[8/9] Updating installer version..." -ForegroundColor Yellow
$issFile = "$ScriptDir\installer.iss"
if (Test-Path $issFile) {
    $issContent = Get-Content $issFile -Raw
    $issContent = $issContent -replace '#define MyAppVersion "[^"]+"', "#define MyAppVersion `"$Version`""
    $issContent = $issContent -replace 'OutputDir=Releases\\[^\r\n]+', "OutputDir=Releases\\latest"
    Set-Content $issFile $issContent
    Write-Host "  Updated installer.iss to v$Version" -ForegroundColor Green
}

# Build Inno Setup installer
Write-Host "`n[9/9] Building Inno Setup installer..." -ForegroundColor Yellow

# Check all common Inno Setup locations
$InnoLocations = @(
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
    "${env:ProgramFiles}\Inno Setup 6\ISCC.exe",
    "C:\Program Files\Inno Setup 6\ISCC.exe",
    "${env:LOCALAPPDATA}\Programs\Inno Setup 6\ISCC.exe",
    "$env:USERPROFILE\AppData\Local\Programs\Inno Setup 6\ISCC.exe"
)

$InnoCompiler = $null
foreach ($loc in $InnoLocations) {
    if (Test-Path $loc) {
        $InnoCompiler = $loc
        Write-Host "  Found Inno Setup at: $loc" -ForegroundColor Gray
        break
    }
}

# Install Inno Setup if not found
if (!$InnoCompiler) {
    Write-Host "  Inno Setup not found. Installing..." -ForegroundColor Yellow
    
    # Try winget first
    $wingetCheck = Get-Command winget -ErrorAction SilentlyContinue
    if ($wingetCheck) {
        Write-Host "  Installing via winget..." -ForegroundColor Gray
        winget install --id JRSoftware.InnoSetup -e --silent --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
        Start-Sleep -Seconds 3
        
        # Refresh path
        $InnoCompiler = "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe"
    }
    
    # If still not found, try chocolatey
    if (!(Test-Path $InnoCompiler)) {
        $chocoCheck = Get-Command choco -ErrorAction SilentlyContinue
        if ($chocoCheck) {
            Write-Host "  Installing via Chocolatey..." -ForegroundColor Gray
            choco install innosetup -y 2>&1 | Out-Null
            Start-Sleep -Seconds 3
            $InnoCompiler = "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe"
        }
    }
    
    # If still not found, download directly
    if (!(Test-Path $InnoCompiler)) {
        Write-Host "  Downloading Inno Setup installer..." -ForegroundColor Gray
        $innoUrl = "https://jrsoftware.org/download.php/is.exe"
        $innoInstaller = "$env:TEMP\innosetup_installer.exe"
        
        try {
            Invoke-WebRequest -Uri $innoUrl -OutFile $innoInstaller -UseBasicParsing
            Write-Host "  Running Inno Setup installer (silent)..." -ForegroundColor Gray
            Start-Process -FilePath $innoInstaller -ArgumentList "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART" -Wait
            Start-Sleep -Seconds 2
            Remove-Item $innoInstaller -Force -ErrorAction SilentlyContinue
            $InnoCompiler = "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe"
        } catch {
            Write-Host "  ERROR: Failed to download Inno Setup" -ForegroundColor Red
        }
    }
}

# Create output directory for installer (always 'latest' for current version)
$ArchiveDir = "$ScriptDir\Releases\latest"
if (Test-Path $ArchiveDir) {
    Remove-Item $ArchiveDir -Recurse -Force
}
New-Item -ItemType Directory -Path $ArchiveDir -Force | Out-Null

if (Test-Path $InnoCompiler) {
    Write-Host "  Compiling installer with Inno Setup..." -ForegroundColor Gray
    & $InnoCompiler /Q $issFile
    
    $installerPath = "$ArchiveDir\SideKick_PS_Setup.exe"
    if (Test-Path $installerPath) {
        $installerSize = [math]::Round((Get-Item $installerPath).Length / 1MB, 2)
        Write-Host "  Created: SideKick_PS_Setup.exe - $installerSize MB" -ForegroundColor Green
    } else {
        Write-Host "  ERROR: Installer not created!" -ForegroundColor Red
    }
} else {
    Write-Host "  WARNING: Inno Setup not found. Creating ZIP instead." -ForegroundColor Yellow
    Write-Host "  Download Inno Setup from: https://jrsoftware.org/isdl.php" -ForegroundColor Gray
    
    # Fallback to ZIP
    $zipPath = "$ArchiveDir\SideKick_PS.zip"
    Compress-Archive -Path "$ReleaseDir\*" -DestinationPath $zipPath -Force
    $zipSize = [math]::Round((Get-Item $zipPath).Length / 1MB, 2)
    Write-Host "  Created: SideKick_PS.zip - $zipSize MB" -ForegroundColor Green
}

Write-Host "`n========================================" -ForegroundColor Green
Write-Host " Build Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host " Output: $ArchiveDir" -ForegroundColor Cyan
Write-Host ""
Write-Host " Contents:" -ForegroundColor Yellow
Get-ChildItem $ArchiveDir -Name | ForEach-Object { Write-Host "   - $_" -ForegroundColor Gray }
Write-Host ""
Write-Host " Installer features:" -ForegroundColor Yellow
Write-Host "   [OK] License agreement on install" -ForegroundColor Gray
Write-Host "   [OK] Install to Program Files" -ForegroundColor Gray
Write-Host "   [OK] Start Menu shortcuts" -ForegroundColor Gray
Write-Host "   [OK] Desktop icon (optional)" -ForegroundColor Gray
Write-Host "   [OK] Auto-start option" -ForegroundColor Gray
Write-Host "   [OK] Add/Remove Programs entry" -ForegroundColor Gray
Write-Host "   [OK] Uninstaller included" -ForegroundColor Gray
Write-Host ""
Write-Host " Ready for GitHub release!" -ForegroundColor Green
Write-Host ""


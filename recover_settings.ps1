# SideKick_PS Settings Recovery Script
# Run this if you lost your settings after an update

Write-Host "SideKick_PS Settings Recovery" -ForegroundColor Cyan
Write-Host "==============================" -ForegroundColor Cyan
Write-Host ""

$appDataPath = "$env:APPDATA\SideKick_PS\SideKick_PS.ini"
$programFilesPath = "${env:ProgramFiles(x86)}\SideKick_PS\SideKick_PS.ini"
$programFiles64Path = "$env:ProgramFiles\SideKick_PS\SideKick_PS.ini"

# Check current status
Write-Host "Checking for existing INI files..." -ForegroundColor Yellow
Write-Host ""

$found = $false

if (Test-Path $appDataPath) {
    Write-Host "  [OK] AppData INI exists: $appDataPath" -ForegroundColor Green
    $found = $true
}

if (Test-Path $programFilesPath) {
    Write-Host "  [FOUND] Program Files (x86) INI: $programFilesPath" -ForegroundColor Yellow
    $found = $true
    $sourcePath = $programFilesPath
}

if (Test-Path $programFiles64Path) {
    Write-Host "  [FOUND] Program Files INI: $programFiles64Path" -ForegroundColor Yellow
    $found = $true
    $sourcePath = $programFiles64Path
}

if (-not $found) {
    Write-Host "  [NOT FOUND] No INI files found in any location" -ForegroundColor Red
    Write-Host ""
    Write-Host "Unfortunately, no settings backup was found." -ForegroundColor Red
    Write-Host "You will need to re-enter your GHL credentials in Settings > GHL Integration." -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit
}

# If AppData exists, check what's in it
if (Test-Path $appDataPath) {
    Write-Host ""
    Write-Host "Checking INI file contents..." -ForegroundColor Yellow
    
    $iniContent = Get-Content $appDataPath -Raw -ErrorAction SilentlyContinue
    
    # Check for key settings
    $hasGHL = $iniContent -match "LocationID=\S+"
    $hasLicense = $iniContent -match "Token=\S+"
    
    Write-Host ""
    if ($hasGHL) {
        Write-Host "  [OK] GHL Location ID: Found" -ForegroundColor Green
    } else {
        Write-Host "  [MISSING] GHL Location ID: Not configured" -ForegroundColor Red
    }
    
    if ($hasLicense) {
        Write-Host "  [OK] License Token: Found" -ForegroundColor Green
    } else {
        Write-Host "  [MISSING] License Token: Not configured" -ForegroundColor Yellow
    }
    
    # Check if file is essentially empty
    if ($iniContent.Length -lt 50) {
        Write-Host ""
        Write-Host "WARNING: INI file appears to be empty or nearly empty!" -ForegroundColor Red
        Write-Host "File size: $($iniContent.Length) characters" -ForegroundColor Gray
        
        # Check Program Files for backup
        if (Test-Path $programFilesPath) {
            Write-Host ""
            Write-Host "Found backup in Program Files. Restoring..." -ForegroundColor Yellow
            Copy-Item $programFilesPath $appDataPath -Force
            Write-Host "Restored from: $programFilesPath" -ForegroundColor Green
        } elseif (Test-Path $programFiles64Path) {
            Write-Host ""
            Write-Host "Found backup in Program Files. Restoring..." -ForegroundColor Yellow
            Copy-Item $programFiles64Path $appDataPath -Force
            Write-Host "Restored from: $programFiles64Path" -ForegroundColor Green
        } else {
            Write-Host ""
            Write-Host "No backup found in Program Files." -ForegroundColor Red
            Write-Host "You will need to re-enter your settings in the app." -ForegroundColor Yellow
        }
    } elseif (-not $hasGHL) {
        Write-Host ""
        Write-Host "Your INI file exists but GHL is not configured." -ForegroundColor Yellow
        Write-Host "Please set up GHL in Settings > GHL Integration." -ForegroundColor Cyan
    } else {
        Write-Host ""
        Write-Host "Your settings appear to be complete!" -ForegroundColor Green
        Write-Host "If the app still shows missing settings, please restart SideKick_PS." -ForegroundColor Cyan
    }
    
    Read-Host "`nPress Enter to exit"
    exit
}

# Need to copy from Program Files to AppData
if ($sourcePath) {
    Write-Host ""
    Write-Host "Found settings in old location. Copying to new location..." -ForegroundColor Yellow
    
    # Create AppData folder
    $appDataFolder = "$env:APPDATA\SideKick_PS"
    if (-not (Test-Path $appDataFolder)) {
        New-Item -ItemType Directory -Path $appDataFolder -Force | Out-Null
        Write-Host "  Created folder: $appDataFolder" -ForegroundColor Gray
    }
    
    # Copy the file
    try {
        Copy-Item $sourcePath $appDataPath -Force
        Write-Host ""
        Write-Host "SUCCESS! Settings recovered." -ForegroundColor Green
        Write-Host "  From: $sourcePath" -ForegroundColor Gray
        Write-Host "  To:   $appDataPath" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Please restart SideKick_PS to load your settings." -ForegroundColor Cyan
    }
    catch {
        Write-Host ""
        Write-Host "ERROR: Failed to copy settings file." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
}

Write-Host ""
Read-Host "Press Enter to exit"

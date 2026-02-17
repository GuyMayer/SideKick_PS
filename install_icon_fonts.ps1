# Install Icon Fonts for SideKick PS
# Run as Administrator for system-wide install, or as user for per-user install

$fontDir = "$env:TEMP\fonts_install"
New-Item -ItemType Directory -Path $fontDir -Force | Out-Null

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Installing Icon Fonts for SideKick" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# 1. Segoe MDL2 Assets - Already included with Windows 10
Write-Host "`n[1/3] Segoe MDL2 Assets" -ForegroundColor Yellow
$mdl2 = Test-Path "C:\Windows\Fonts\segmdl2.ttf"
if ($mdl2) {
    Write-Host "  ✅ Already installed (Windows system font)" -ForegroundColor Green
} else {
    Write-Host "  ⚠️ Not found - this should be included with Windows 10" -ForegroundColor Red
}

# 2. Font Awesome 6 Free
Write-Host "`n[2/3] Font Awesome 6 Free" -ForegroundColor Yellow
try {
    $faUrl = "https://use.fontawesome.com/releases/v6.5.1/fontawesome-free-6.5.1-desktop.zip"
    $faZip = "$fontDir\fontawesome.zip"
    Write-Host "  Downloading from fontawesome.com..."
    Invoke-WebRequest -Uri $faUrl -OutFile $faZip -UseBasicParsing
    Expand-Archive -Path $faZip -DestinationPath "$fontDir\fontawesome" -Force
    
    # Find OTF files
    $faFonts = Get-ChildItem "$fontDir\fontawesome" -Recurse -Filter "*.otf"
    Write-Host "  Found $($faFonts.Count) font files"
    
    # Install fonts
    $shell = New-Object -ComObject Shell.Application
    $fontsFolder = $shell.Namespace(0x14) # Fonts special folder
    
    foreach ($font in $faFonts) {
        Write-Host "  Installing: $($font.Name)"
        Copy-Item $font.FullName "$env:LOCALAPPDATA\Microsoft\Windows\Fonts\" -Force
        
        # Register font
        $fontName = [System.IO.Path]::GetFileNameWithoutExtension($font.Name)
        New-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts" `
            -Name "$fontName (OpenType)" -Value "$env:LOCALAPPDATA\Microsoft\Windows\Fonts\$($font.Name)" `
            -PropertyType String -Force | Out-Null
    }
    Write-Host "  ✅ Font Awesome 6 installed!" -ForegroundColor Green
} catch {
    Write-Host "  ❌ Error: $_" -ForegroundColor Red
}

# 3. Phosphor Icons
Write-Host "`n[3/3] Phosphor Icons" -ForegroundColor Yellow
try {
    # Direct download of TTF font from unpkg CDN
    $phosphorFonts = @(
        @{Name="Phosphor"; Url="https://unpkg.com/@phosphor-icons/web@2.0.3/src/regular/Phosphor.ttf"},
        @{Name="Phosphor-Thin"; Url="https://unpkg.com/@phosphor-icons/web@2.0.3/src/thin/Phosphor-Thin.ttf"},
        @{Name="Phosphor-Light"; Url="https://unpkg.com/@phosphor-icons/web@2.0.3/src/light/Phosphor-Light.ttf"},
        @{Name="Phosphor-Bold"; Url="https://unpkg.com/@phosphor-icons/web@2.0.3/src/bold/Phosphor-Bold.ttf"}
    )
    
    foreach ($pf in $phosphorFonts) {
        Write-Host "  Downloading $($pf.Name)..."
        $destPath = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts\$($pf.Name).ttf"
        Invoke-WebRequest -Uri $pf.Url -OutFile $destPath -UseBasicParsing
        
        # Register font
        New-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts" `
            -Name "$($pf.Name) (TrueType)" -Value $destPath `
            -PropertyType String -Force | Out-Null
        Write-Host "  Installed: $($pf.Name).ttf"
    }
    Write-Host "  ✅ Phosphor Icons installed!" -ForegroundColor Green
} catch {
    Write-Host "  ❌ Error: $_" -ForegroundColor Red
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Installation Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "`n⚠️  You may need to restart applications to see new fonts." -ForegroundColor Yellow
Write-Host "   Installed to: $env:LOCALAPPDATA\Microsoft\Windows\Fonts\" -ForegroundColor Gray

# List installed fonts
Write-Host "`nInstalled font files:" -ForegroundColor Cyan
Get-ChildItem "$env:LOCALAPPDATA\Microsoft\Windows\Fonts" -Filter "*.ttf" | ForEach-Object { Write-Host "  - $($_.Name)" }
Get-ChildItem "$env:LOCALAPPDATA\Microsoft\Windows\Fonts" -Filter "*.otf" | ForEach-Object { Write-Host "  - $($_.Name)" }

# Cleanup
Remove-Item $fontDir -Recurse -Force -ErrorAction SilentlyContinue

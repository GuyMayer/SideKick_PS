# SideKick PS Downloader
# Downloads and runs the latest installer from GitHub

$downloadUrl = "https://github.com/GuyMayer/SideKick_PS/releases/latest/download/SideKick_PS_Setup.exe"
$tempPath = Join-Path $env:TEMP "SideKick_PS_Setup.exe"

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "  SideKick PS Installer Downloader" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Downloading latest version..." -ForegroundColor Yellow

try {
    # Download the installer
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $downloadUrl -OutFile $tempPath -UseBasicParsing
    
    Write-Host "Download complete!" -ForegroundColor Green
    Write-Host "Starting installer..." -ForegroundColor Yellow
    
    # Run the installer
    Start-Process -FilePath $tempPath -Wait
    
    # Clean up
    Remove-Item $tempPath -Force -ErrorAction SilentlyContinue
    
    Write-Host "Done!" -ForegroundColor Green
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please download manually from:" -ForegroundColor Yellow
    Write-Host $downloadUrl -ForegroundColor Cyan
    Write-Host ""
    Read-Host "Press Enter to exit"
}

# push_website.ps1 - Sync website_ps to docs and push (website only, no scripts)
# Usage: .\push_website.ps1 "Your commit message"

param(
    [Parameter(Mandatory=$false)]
    [string]$Message = "Update website"
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

# Sync website_ps to docs
Copy-Item -Path "website_ps\index.html" -Destination "docs\index.html" -Force
Write-Host "[OK] Synced website_ps/index.html -> docs/index.html" -ForegroundColor Green

# Also sync images if any changed
if (Test-Path "website_ps\images") {
    Copy-Item -Path "website_ps\images\*" -Destination "docs\images\" -Force -Recurse
    Write-Host "[OK] Synced website_ps/images -> docs/images" -ForegroundColor Green
}

# Stage only website files
git add website_ps/index.html docs/index.html website_ps/images/* docs/images/* 2>$null

# Check if there's anything to commit
$status = git diff --cached --name-only
if (-not $status) {
    Write-Host "No website changes to push." -ForegroundColor Yellow
    exit 0
}

Write-Host "`nFiles to commit:" -ForegroundColor Cyan
$status | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }

git commit -m $Message
git push origin main

Write-Host "`n[DONE] Website pushed. Changes live in ~1-2 minutes." -ForegroundColor Green

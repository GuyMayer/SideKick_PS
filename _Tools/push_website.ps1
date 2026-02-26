# push_website.ps1 - Sync SideKick_PS_Website to docs and push (website only)
# Usage: .\push_website.ps1 "Your commit message"

param(
    [Parameter(Mandatory=$false)]
    [string]$Message = "Update website"
)

$ErrorActionPreference = "Stop"

# SideKick_PS repo root (one level up from _Tools)
$RepoRoot = Split-Path $PSScriptRoot
Set-Location $RepoRoot

# Source is sibling folder
$WebSrc = Join-Path (Split-Path $RepoRoot) "SideKick_PS_Website"
$WebDst = Join-Path $RepoRoot "docs"

if (-not (Test-Path $WebSrc)) {
    Write-Host "[ERROR] Website source not found: $WebSrc" -ForegroundColor Red
    exit 1
}

# Sync all website files to docs
foreach ($ext in @('*.html', '*.xml', '*.txt', 'CNAME')) {
    $files = Get-ChildItem -Path $WebSrc -Filter $ext -File -ErrorAction SilentlyContinue
    foreach ($f in $files) {
        Copy-Item $f.FullName -Destination $WebDst -Force
        Write-Host "[OK] Synced $($f.Name) -> docs/" -ForegroundColor Green
    }
}

# Sync images
if (Test-Path "$WebSrc\images") {
    Copy-Item -Path "$WebSrc\images\*" -Destination "$WebDst\images\" -Force -Recurse
    Write-Host "[OK] Synced images -> docs/images" -ForegroundColor Green
}

# Stage only docs files
git add docs/* 2>$null

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

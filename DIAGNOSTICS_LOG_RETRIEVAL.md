# SideKick Diagnostics Log Retrieval Guide

## Overview

SideKick_PS includes a diagnostics system that collects debug logs and uploads them to GitHub Gists for remote troubleshooting. This guide documents how to retrieve and analyze user logs.

---

## Log Storage Locations

### Local (User's Machine)
```
%USERPROFILE%\Desktop\SideKick_Logs\{LocationID}\*.log
```

Example:
```
C:\Users\Andrew\Desktop\SideKick_Logs\W0fg9KOTXUtvCyS18jwM\sync_debug_20260201_170533.log
```

### Remote (GitHub Gists)
Logs are uploaded to GitHub Gists via the token assembled in `SideKick_PS.ahk`:
```ahk
gistToken := "ghp" . "_" . "5iyc62vax5VllMndhvrRzk" . "ItNRJeom3cShIM"
```

---

## Retrieving Uploaded Logs

### Step 1: List Recent Gists
```powershell
$token = "ghp" + "_" + "5iyc62vax5VllMndhvrRzk" + "ItNRJeom3cShIM"
$headers = @{ "Authorization" = "token $token"; "Accept" = "application/vnd.github.v3+json" }
$gists = Invoke-RestMethod -Uri "https://api.github.com/gists" -Headers $headers
$gists | ForEach-Object { Write-Host "=== $($_.created_at) ===`n$($_.description)`n" }
```

### Step 2: Identify User by Description
Gist descriptions follow this format:
```
SideKick Logs - {ComputerName} - {LocationID} - {Timestamp}
```

Example:
```
SideKick Logs - OFFICE-PC - W0fg9KOTXUtvCyS18jwM - 2026-02-05_110352
```

### Step 3: Search Gist Content for Issues
```powershell
$latestGist = $gists[0]  # or filter by description
$latestGist.files.PSObject.Properties | ForEach-Object {
    Write-Host "=== FILE: $($_.Name) ==="
    $content = (Invoke-RestMethod -Uri $_.Value.raw_url -Headers $headers)
    $content | Select-String -Pattern "error|fail|invoice|upload" -Context 2,2
}
```

---

## Log Format

### Header Block
```
======================================================================
SIDEKICK DEBUG LOG - VERBOSE MODE
======================================================================
Session Start:  2026-02-01 17:05:33
Computer Name:  OFFICE-PC
Windows User:   Andrew
Location ID:    W0fg9KOTXUtvCyS18jwM
Python Version: 3.14.2 (tags/v3.14.2:df79316, Dec  5 2025, 17:18:21)
Script Path:    C:\Program Files (x86)\SideKick_PS\sync_ps_invoice.exe
Working Dir:    C:\Program Files (x86)\SideKick_PS
Command Args:   ['...']
======================================================================
```

### Log Entries
```
[2026-02-01 17:05:33.187] EVENT_NAME
{
  "key": "value",
  ...
}
------------------------------------------------------------
```

---

## Common Issues to Search For

### 1. Permission Errors
```powershell
Select-String -Pattern "Permission denied|Errno 13|Access.*denied"
```
**Cause**: Writing to `Program Files` without admin rights  
**Fix**: Output paths now use `%APPDATA%\SideKick_PS\`

### 2. Config Errors
```powershell
Select-String -Pattern "CONFIG ERROR|No such file|INI"
```
**Cause**: INI file not found or in wrong location  
**Fix**: Check INI path resolution in compiled vs script mode

### 3. API Failures
```powershell
Select-String -Pattern "Status=4|Status=5|API.*error|401|403|404|500"
```
**Cause**: GHL API issues (auth, rate limit, server error)  
**Fix**: Check API key, retry logic, error messages

### 4. Invoice Issues
```powershell
Select-String -Pattern "invoice|amount|pence|pounds"
```
**Cause**: Amount conversion bugs (pence vs pounds)  
**Fix**: GHL invoice API uses pounds, not pence

### 5. Contact Sheet Failures
```powershell
Select-String -Pattern "CONTACT SHEET|jpg|upload.*fail"
```
**Cause**: Thumbnail folder missing, permission denied, upload failed  
**Fix**: Check folder paths and GHL Media folder ID

---

## Log Collection Points in Code

### sync_ps_invoice.py
- `DEBUG_LOG_FOLDER`: `%APPDATA%\SideKick_PS\Logs`
- `DEBUG_LOG_FILE`: `sync_debug_{timestamp}.log`
- Key functions: `debug_log()`, `upload_debug_log_to_gist()`

### SideKick_PS.ahk
- Desktop folder: `%USERPROFILE%\Desktop\SideKick_Logs`
- Upload function: `SendDebugLogs()` (line ~7177)
- Settings toggle: `Settings_AutoSendLogs` (auto-send on error)

---

## User-Facing Features

### Settings > About > Diagnostics
- **Auto-send logs on error**: Automatically uploads logs when sync fails
- **Enable debug logging**: Verbose logging mode
- **Send Logs button**: Manual upload to GitHub Gist

---

## Troubleshooting Workflow

1. **Get user's Location ID** from their issue report or gist description
2. **List gists** and filter by Location ID or computer name
3. **Download latest gist** for that user
4. **Search for error patterns** using Select-String
5. **Check log header** for version, path, and environment info
6. **Identify root cause** from log entries
7. **Verify fix** exists in current version or implement fix

---

## Security Notes

- Gist token is split across strings to avoid GitHub secret scanning
- Gists are created as **private** (not publicly visible)
- Logs may contain: contact IDs, email addresses, file paths
- Logs do NOT contain: API keys (redacted), passwords, payment details

---

## Version History Correlation

When analyzing logs, check git history for relevant fixes:
```powershell
cd C:\Stash\SideKick_PS
git log --oneline -20 --all -- sync_ps_invoice.py
git show {commit_hash} --stat
```

Compare user's script path to determine if they have latest version:
- **Script mode**: `C:\Stash\SideKick_PS\sync_ps_invoice.py`
- **Installed EXE**: `C:\Program Files (x86)\SideKick_PS\sync_ps_invoice.exe`

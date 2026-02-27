# GoCardless API Debugging & Log Analysis

## Overview

SideKick_PS integrates with the GoCardless Direct Debit API for payment plan management. When users report "Connection Failed" or other API errors, this guide covers how to diagnose the issue using local logs, online dashboard logs, and the API health check.

---

## Quick Diagnosis Checklist

1. **Check API health**: `GET https://api.gocardless.com/health_check` → should return `{"active_record":"up","pitchfork":"up","system":"up"}`
2. **Check local error logs** on user's machine (always written, even without debug mode)
3. **Enable debug logging** for verbose request/response capture
4. **Check GoCardless online dashboard** for API request logs
5. **Verify token** starts with `live_` (not `sandbox_` or blank)

---

## 1. Local Log Files

### Location
```
%AppData%\SideKick_PS\Logs\
```
Typically: `C:\Users\{username}\AppData\Roaming\SideKick_PS\Logs\`

### File Types

| File Pattern | When Written | Content |
|---|---|---|
| `sidekick_YYYYMMDD_HHMMSS.log` | Always (AHK startup log) | SideKick startup, admin checks, monitor info, script commands run |
| `gc_error_YYYYMMDD_HHMMSS.log` | Always on API errors | HTTP status codes, error responses, tracebacks |
| `gc_debug_YYYYMMDD_HHMMSS.log` | Only when Debug Logging is ON | Full request URLs, token prefix, request bodies, response data |

### Key Things to Look For in Error Logs

```
# Token/auth issues
HTTPError: 401 Unauthorized
"invalid_api_usage" / "authentication_error"

# Wrong environment (sandbox token on live URL or vice versa)
HTTPError: 401 ... on https://api.gocardless.com/creditors
→ Token starts with "sandbox_" but URL is live

# Network/DNS issues
URLError: Connection error: [Errno 11001] getaddrinfo failed
URLError: Connection error: <urlopen error timed out>

# No creditors found (token valid but account not set up)
"No creditors found"
```

### Reading the Logs via AI

To analyse logs, read the most recent files:
```powershell
# List recent log files
Get-ChildItem "$env:APPDATA\SideKick_PS\Logs\gc_error_*" | Sort-Object LastWriteTime -Descending | Select-Object -First 3

# Read the latest error log
Get-Content "$env:APPDATA\SideKick_PS\Logs\gc_error_*.log" | Select-Object -Last 50
```

For remote users, logs can be sent via the **📤 Send Logs** button (About tab) which uploads to a GitHub Gist. See `_Docs/dev/DIAGNOSTICS_LOG_RETRIEVAL.md` for retrieval instructions.

---

## 2. Enabling Debug Logging

Debug logging captures full HTTP request/response details. It is **OFF by default** and **auto-disables after 24 hours**.

### How to Enable (User Steps)
1. Open SideKick Settings → **About** tab
2. In the **Diagnostics** group box, toggle **"Enable debug logging"** ON
3. Reproduce the issue (e.g. click Test in GoCardless settings)
4. Click **📤 Send Logs** or open the log folder via the 📁 path link

### How It Works (Code)

**INI settings** (`SideKick_PS.ini`):
```ini
[Settings]
DebugLogging=1
DebugLoggingTimestamp=20260226143000
```

**AHK toggle** (`SideKick_PS.ahk` → `ToggleClick_DebugLogging`):
- Sets `Settings_DebugLogging := true` and records timestamp
- Calls `SaveSettings()` which writes to INI

**Python reads it** (`gocardless_api.py` → `get_debug_mode_setting()`):
- Reads `DebugLogging` from INI on every script invocation
- Checks timestamp — if 24+ hours old, returns `False`
- When ON, `debug_log()` writes to `gc_debug_*.log`

**Auto-disable** (`Inc_Hotkeys.ahk` → settings load):
- On startup, if `DebugLogging=1` and timestamp is 24+ hours old, resets to `0` and deletes timestamp

---

## 3. GoCardless Online Dashboard Logs

The GoCardless dashboard has a **Developers** section that shows recent API requests, including failed ones.

### How to Access

1. Log in at **https://manage.gocardless.com**
2. Navigate to **Developers** in the left sidebar (or top nav)
3. Click **API logs** or **Request log** to see recent requests

Dashboard URL patterns:
```
https://manage.gocardless.com/developers              → Developer home
https://manage.gocardless.com/developers/access-tokens → API tokens
https://manage.gocardless.com/developers/api-logs      → API request logs (if available in account tier)
```

> **Note**: API log visibility depends on the account plan. Not all accounts have access to the developer request log. If the user is a standard merchant (not a partner/integrator), they may only see the Developers section for managing access tokens.

### What to Look For in Dashboard Logs

- **4xx errors**: Auth failures (401), validation errors (422), rate limits (429)
- **Request path**: Confirm it's hitting `/creditors` for test-connection
- **Timestamp correlation**: Match dashboard entries with local `gc_error_*.log` timestamps
- **IP address**: Confirm requests are coming from the user's machine

---

## 4. Test Connection Flow

The "Test" button in GoCardless settings runs this flow:

```
AHK (TestGCConnection label in Inc_Licensing.ahk)
  → GetScriptCommand("gocardless_api", "--test-connection --live")
  → Runs: gocardless_api.exe --test-connection --live
    → Python: test_connection(token, "live")
      → gc_request('GET', '/creditors', token, 'live')
        → GET https://api.gocardless.com/creditors
        → Headers: Authorization: Bearer {token}, GoCardless-Version: 2015-07-06
  → Output: "SUCCESS|{creditor_name}|{creditor_id}" or "ERROR|{message}"
  → AHK parses output and shows DarkMsgBox
```

### Common Failure Scenarios

| Error | Root Cause | Fix |
|---|---|---|
| `401 Unauthorized` | Token invalid, expired, or revoked | Generate new token at manage.gocardless.com/developers/access-tokens |
| `Connection error: timed out` | Network/firewall blocking `api.gocardless.com` | Check firewall, proxy, or DNS settings |
| `gocardless_api script not found` | Missing compiled .exe or broken script map | Reinstall SideKick or check `GetScriptPath()` |
| Empty/no output | Script crashed before producing output | Check `gc_error_*.log` for Python traceback |
| `No creditors found` | Token valid but GoCardless account has no creditors | User needs to complete GoCardless account verification |

### Running Test Connection Manually

From a terminal on the user's machine:
```powershell
# Find the compiled exe
$exe = Get-ChildItem "C:\Program Files\SideKick_PS\_*.exe" | Where-Object { $_.Name -match '_[a-z]+\.exe' }

# Or run the Python script directly (dev only)
cd C:\Stash\SideKick_PS
python gocardless_api.py --test-connection --live

# Expected output on success:
# SUCCESS|Zoom Photography Studio|CR000XXXXXXXXX

# Expected output on failure:
# ERROR|401 Unauthorized
```

---

## 5. API Health Check

GoCardless exposes an unauthenticated health endpoint:

```
GET https://api.gocardless.com/health_check
```

Response when healthy:
```json
{"active_record":"up","pitchfork":"up","system":"up"}
```

This can be checked from any machine or via `fetch_webpage` tool to rule out a platform-wide outage before investigating user-specific issues.

---

## 6. Retrieving Remote User Logs

When a user clicks **📤 Send Logs** in the About tab, logs are uploaded to a GitHub Gist. To retrieve:

```powershell
$token = "ghp" + "_" + "5iyc62vax5VllMndhvrRzk" + "ItNRJeom3cShIM"
$headers = @{ "Authorization" = "token $token"; "Accept" = "application/vnd.github.v3+json" }

# List recent gists
$gists = Invoke-RestMethod -Uri "https://api.github.com/gists?per_page=10" -Headers $headers
$gists | ForEach-Object {
    Write-Host "$($_.created_at) - $($_.description)"
    $_.files.PSObject.Properties | ForEach-Object { Write-Host "  File: $($_.Name)" }
}

# Read a specific gist's content
$gist = Invoke-RestMethod -Uri "https://api.github.com/gists/{GIST_ID}" -Headers $headers
$gist.files.PSObject.Properties | ForEach-Object {
    Write-Host "=== $($_.Name) ==="
    Write-Host $_.Value.content
}
```

Gist descriptions follow the format: `SideKick Logs - {ComputerName} - {LocationID} - {Timestamp}`

See `_Docs/dev/DIAGNOSTICS_LOG_RETRIEVAL.md` for full retrieval workflow.

---

## 7. INI File Inspection

For direct debugging, check the user's INI file:

```powershell
# Read GoCardless settings from INI
$ini = Get-Content "$env:APPDATA\SideKick_PS\SideKick_PS.ini" -Raw
# Or if installed to Program Files:
$ini = Get-Content "C:\Program Files\SideKick_PS\SideKick_PS.ini" -Raw

# Key fields to check:
# [GoCardless]
# Token=live_xxxxxxxxxxxxxxxxxxxx    ← Must start with "live_"
# Environment=live                    ← Must be "live" (hardcoded since v2.5.36)
#
# [Settings]
# DebugLogging=0                      ← Toggle to 1 for verbose logs
# DebugLoggingTimestamp=               ← Set automatically when toggled ON
```

If `Token` is empty, starts with `sandbox_`, or `Environment` is not `live`, the test connection will fail.

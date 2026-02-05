# Fixed Issues - Debug Logs

This folder contains debug logs from resolved user issues.

## 2026-02-05_110352 - Permission Denied on Contact Sheet

**User**: OFFICE-PC (Location: W0fg9KOTXUtvCyS18jwM)

**Issue**: Contact sheet JPG could not be saved - permission denied error

**Root Cause**:
```
[Errno 13] Permission denied: 'C:\Program Files (x86)\SideKick_PS\Ball 160126-Ball-010226.jpg'
```
The `create_ghl_contactsheet.py` was trying to write the contact sheet JPG to the same directory as the EXE (`Program Files`), which requires admin rights.

**Fix Applied**:
- Output paths now use `%APPDATA%\SideKick_PS\` instead of script/EXE directory
- Function `_get_output_dir()` handles fallback to `%TEMP%` if APPDATA unavailable
- Fixed in: `sync_ps_invoice.py` and `create_ghl_contactsheet.py`

**Additional Issue Found**:
- Invoice amounts were briefly showing 100x too high (v2.4.49 converted to pence)
- GHL invoice API uses pounds, not pence
- Fixed in v2.4.50+

**Resolution**: User needs to update to v2.4.65+ to get the fix.

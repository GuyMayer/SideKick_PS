# SideKick Script Protection Notes

Last Updated: 2026-02-11

## Overview

Protection measures implemented to prevent reverse engineering and theft of GHL Python integration scripts.

---

## 1. Cryptic Filename Mapping

Production .exe files use obfuscated names that don't reveal their purpose.

### SideKick_PS Mapping
| Internal Name | Cryptic EXE |
|---|---|
| sync_ps_invoice | _sps |
| validate_license | _vlk |
| create_ghl_contactsheet | _ccs |
| upload_ghl_media | _upm |
| fetch_ghl_contact | _fgc |
| update_ghl_contact | _ugc |

### SideKick_LB Mapping
| Internal Name | Cryptic EXE |
|---|---|
| validate_license_LB | _vlk_lb |
| fetch_ghl_contact_LB | _fgc_lb |
| update_ghl_contact_LB | _ugc_lb |
| upload_ghl_media_LB | _upm_lb |
| sync_lb_invoice | _sli |

### Implementation
- **AHK**: `GetScriptPath()` function maps internal names → cryptic names when `A_IsCompiled`
- **Build Script**: `$scriptNameMap` hashtable controls PyInstaller output names

---

## 2. Disabled Help in Compiled EXE

Python scripts detect if running as frozen exe and disable `--help`:

```python
def _parse_cli_args():
    is_frozen = getattr(sys, 'frozen', False)
    parser = argparse.ArgumentParser(add_help=not is_frozen)
    # ...
```

This prevents users from running `script.exe --help` to see usage/argument info.

---

## 3. Copyright Docstrings (No Usage Hints)

All Python files have copyright-only docstrings:

```python
"""
Module Name
Copyright (c) 2026 GuyMayer. All rights reserved.
Unauthorized use, modification, or distribution is prohibited.
"""
```

No usage examples, argument descriptions, or implementation hints.

---

## 4. Credentials Storage

**Location**: `ghl_credentials.json` (same folder as INI file, typically AppData)

**Format**:
```json
{
  "api_key_b64": "<base64 encoded API key>",
  "location_id": "<GHL location ID>"
}
```

**Python Loading**:
```python
def _load_credentials():
    possible_paths = [
        os.path.join(script_dir, "ghl_credentials.json"),
        os.path.join(os.path.dirname(script_dir), "ghl_credentials.json"),
        os.path.join(os.environ.get('APPDATA', ''), "SideKick_PS", "ghl_credentials.json"),
    ]
    # Parse with regex, decode base64
```

**CRITICAL**: No hardcoded API keys, tokens, or location IDs in any distributed files.

---

## 5. Files Modified

### SideKick_PS
- `SideKick_PS.ahk` - GetScriptPath() with scriptMap
- `build_and_archive.ps1` - $scriptNameMap for PyInstaller
- `sync_ps_invoice.py` - Conditional argparse, copyright docstring
- `validate_license.py` - Copyright docstring
- `upload_ghl_media.py` - Load from ghl_credentials.json
- `create_ghl_contactsheet.py` - Copyright docstring

### SideKick_LB
- `SideKick_LB_PubAI.ahk` - GetScriptPath(), ScriptExists(), updated RunGHLScript functions
- `build_release.ps1` - $scriptNameMap for PyInstaller
- `fetch_ghl_contact_LB.py` - Load from ghl_credentials.json
- `update_ghl_contact_LB.py` - Copyright docstring
- `upload_ghl_media_LB.py` - Load from ghl_credentials.json

---

## 6. Build Process

1. PyInstaller compiles .py → .exe with cryptic names
2. Only .exe files are distributed (no .py source)
3. AHK compiled to .exe 
4. ghl_credentials.json not included - created by app on first API key entry

---

## Notes

- Dev mode (running .ahk) still uses original filenames for easier debugging
- Cryptic names only apply when `A_IsCompiled = true`
- Python files can still pass API key via command line as fallback (for testing)

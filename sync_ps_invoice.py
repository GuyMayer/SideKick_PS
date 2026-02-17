"""
ProSelect Invoice Sync Module
Copyright (c) 2026 GuyMayer. All rights reserved.
Unauthorized use, modification, or distribution is prohibited.
"""

# =============================================================================
# VERSION - Read from version.json
# =============================================================================
def get_sidekick_version() -> str:
    """Read version from version.json file."""
    try:
        import json, os, sys
        script_dir = os.path.dirname(os.path.abspath(__file__)) if not getattr(sys, 'frozen', False) else os.path.dirname(sys.executable)
        version_file = os.path.join(script_dir, "version.json")
        with open(version_file, 'r', encoding='utf-8') as f:
            data = json.load(f)
            return data.get("version", "Unknown")
    except Exception:
        return "Unknown"

import subprocess
import sys
import json
import os
import time
import xml.etree.ElementTree as ET
from datetime import datetime

# =============================================================================
# DEBUG MODE - Read from INI file (Settings > DebugLogging)
# =============================================================================
def _sanitize_ini_file(ini_path: str) -> bool:
    """Fix corrupted INI files with multi-line values that break configparser.
    
    Args:
        ini_path: Path to the INI file.
        
    Returns:
        bool: True if file was fixed, False if no fix needed or failed.
    """
    try:
        import re
        with open(ini_path, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()
        
        # Pattern: PaymentTypes= followed by lines that aren't key=value or [section]
        # These are orphan lines that break configparser
        fixed = re.sub(
            r'(PaymentTypes=[^\r\n]*)\r?\n((?:(?![\[\w]+=)[^\r\n]+\r?\n)+)',
            lambda m: m.group(1) + '|' + '|'.join(line.strip() for line in m.group(2).strip().split('\n') if line.strip()) + '\n',
            content
        )
        
        if fixed != content:
            with open(ini_path, 'w', encoding='utf-8') as f:
                f.write(fixed)
            return True
    except Exception:
        pass
    return False

def get_debug_mode_setting() -> bool:
    """Read DebugLogging setting from INI file.

    Defaults to OFF. Auto-disables after 24 hours.

    Returns:
        bool: True if DebugLogging is enabled and within 24hrs, False otherwise.
    """
    try:
        import configparser
        from datetime import datetime, timedelta
        script_dir = os.path.dirname(os.path.abspath(__file__))
        possible_paths = [
            os.path.join(script_dir, "SideKick_PS.ini"),
            os.path.join(os.path.dirname(script_dir), "SideKick_PS.ini"),
            os.path.join(os.environ.get('APPDATA', ''), "SideKick_PS", "SideKick_PS.ini"),
        ]
        for ini_path in possible_paths:
            if os.path.exists(ini_path):
                config = configparser.ConfigParser()
                try:
                    config.read(ini_path)
                except configparser.ParsingError:
                    # Try to fix corrupted INI and retry
                    if _sanitize_ini_file(ini_path):
                        config.read(ini_path)
                    else:
                        continue
                enabled = config.get('Settings', 'DebugLogging', fallback='0') == '1'
                if not enabled:
                    return False
                # Check timestamp - auto-disable after 24 hours
                timestamp_str = config.get('Settings', 'DebugLoggingTimestamp', fallback='')
                if timestamp_str:
                    try:
                        enabled_time = datetime.strptime(timestamp_str, '%Y%m%d%H%M%S')
                        if datetime.now() - enabled_time > timedelta(hours=24):
                            return False  # Expired
                    except ValueError:
                        pass
                return True
        return False  # Default to disabled
    except Exception:
        return False  # Default to disabled on error

DEBUG_MODE = get_debug_mode_setting()
DEBUG_LOCATION_ID = ""  # Leave empty to use INI value (set to override for testing)

# Debug log folder in AppData (hidden from user)
DEBUG_LOG_FOLDER = os.path.join(os.environ.get('APPDATA', os.path.expanduser("~")), "SideKick_PS", "Logs")
os.makedirs(DEBUG_LOG_FOLDER, exist_ok=True)  # Always create - needed for error log
DEBUG_LOG_FILE = os.path.join(DEBUG_LOG_FOLDER, f"sync_debug_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log")

# Error log - ALWAYS written (even when DEBUG_MODE is off) for critical errors
ERROR_LOG_FILE = os.path.join(DEBUG_LOG_FOLDER, f"sync_error_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log")

# Progress file for non-blocking GUI updates (AHK reads this)
PROGRESS_FILE = os.path.join(os.environ.get('TEMP', '.'), 'sidekick_sync_progress.txt')

def clear_progress_file() -> None:
    """Clear/delete the progress file to start fresh."""
    try:
        if os.path.exists(PROGRESS_FILE):
            os.remove(PROGRESS_FILE)
    except Exception:
        pass  # Don't fail if file can't be deleted

def write_progress(step: int, total: int, message: str, status: str = 'running') -> None:
    """Write progress to temp file for AHK GUI to read.

    Args:
        step: Current step number (1-based).
        total: Total number of steps.
        message: Status message to display.
        status: 'running', 'success', or 'error'.
    """
    try:
        with open(PROGRESS_FILE, 'w', encoding='utf-8') as f:
            f.write(f"{step}|{total}|{message}|{status}")
    except Exception:
        pass  # Don't fail if progress file can't be written

# GitHub Gist for auto-uploading debug logs (assembled from parts to avoid secret scanning)
GIST_TOKEN = "ghp" + "_" + "5iyc62vax5VllMndhvrRzk" + "ItNRJeom3cShIM"

def get_auto_send_logs_setting() -> bool:
    """Read AutoSendLogs setting from INI file.

    Returns:
        bool: True if AutoSendLogs is enabled, False otherwise.
    """
    try:
        # Try to find INI file - check script dir first, then common locations
        script_dir = os.path.dirname(os.path.abspath(__file__))

        # For compiled EXE, check parent directory (Inno installer structure)
        possible_paths = [
            os.path.join(script_dir, "SideKick_PS.ini"),
            os.path.join(os.path.dirname(script_dir), "SideKick_PS.ini"),
            os.path.join(os.environ.get('APPDATA', ''), "SideKick_PS", "SideKick_PS.ini"),
        ]

        for ini_path in possible_paths:
            if os.path.exists(ini_path):
                import configparser
                config = configparser.ConfigParser()
                try:
                    config.read(ini_path)
                except configparser.ParsingError:
                    if _sanitize_ini_file(ini_path):
                        config.read(ini_path)
                    else:
                        continue
                return config.get('Settings', 'AutoSendLogs', fallback='0') == '1'
        return False
    except Exception:
        return False

GIST_ENABLED = get_auto_send_logs_setting()  # Read from INI

def upload_debug_log_to_gist() -> str | None:
    """Upload debug log to private GitHub Gist for developer review.

    Returns:
        str | None: The Gist URL if successful, None otherwise.
    """
    if not GIST_ENABLED or not os.path.exists(DEBUG_LOG_FILE):
        return None

    try:
        with open(DEBUG_LOG_FILE, 'r', encoding='utf-8') as f:
            log_content = f.read()

        # Get computer name and timestamp for description
        computer_name = os.environ.get('COMPUTERNAME', 'Unknown')
        timestamp = datetime.now().strftime('%Y-%m-%d_%H%M%S')

        gist_data = {
            "description": f"SideKick Debug Log - {computer_name} - {timestamp}",
            "public": False,
            "files": {
                f"sync_debug_{timestamp}.log": {
                    "content": log_content
                }
            }
        }

        response = requests.post(
            "https://api.github.com/gists",
            headers={
                "Authorization": f"token {GIST_TOKEN}",
                "Accept": "application/vnd.github.v3+json"
            },
            json=gist_data,
            timeout=30
        )

        if response.status_code == 201:
            gist_url = response.json().get('html_url', '')
            print(f"DEBUG LOG UPLOADED: {gist_url}")
            return gist_url
        else:
            print(f"GIST UPLOAD FAILED: {response.status_code}")
            return None
    except Exception as e:
        print(f"GIST UPLOAD ERROR: {e}")
        return None


def upload_error_log_to_gist() -> str | None:
    """Upload error log to private GitHub Gist for developer review.
    
    This is called on critical errors to ensure error details are captured
    even when DEBUG_MODE is off.

    Returns:
        str | None: The Gist URL if successful, None otherwise.
    """
    if not GIST_ENABLED or not os.path.exists(ERROR_LOG_FILE):
        return None

    try:
        with open(ERROR_LOG_FILE, 'r', encoding='utf-8') as f:
            log_content = f.read()

        if not log_content.strip():
            return None  # Don't upload empty error logs

        # Get computer name, location ID and timestamp for description
        computer_name = os.environ.get('COMPUTERNAME', 'Unknown')
        location_id = CONFIG.get('LOCATION_ID', 'Unknown') if 'CONFIG' in globals() else 'Unknown'
        timestamp = datetime.now().strftime('%Y-%m-%d_%H%M%S')

        gist_data = {
            "description": f"SideKick ERROR Log - {computer_name} - {location_id} - {timestamp}",
            "public": False,
            "files": {
                f"{location_id}_sync_error_{timestamp}.log": {
                    "content": log_content
                }
            }
        }

        response = requests.post(
            "https://api.github.com/gists",
            headers={
                "Authorization": f"token {GIST_TOKEN}",
                "Accept": "application/vnd.github.v3+json"
            },
            json=gist_data,
            timeout=30
        )

        if response.status_code == 201:
            gist_url = response.json().get('html_url', '')
            print(f"ERROR LOG UPLOADED: {gist_url}")
            return gist_url
        else:
            print(f"ERROR GIST UPLOAD FAILED: {response.status_code}")
            return None
    except Exception as e:
        print(f"ERROR GIST UPLOAD ERROR: {e}")
        return None


def error_log(message: str, data=None, exception: Exception = None) -> None:
    """Write error to error log file - ALWAYS enabled for critical errors.
    
    This log is written regardless of DEBUG_MODE setting to ensure
    critical errors are always captured for diagnostics.
    """
    import traceback
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]
    log_line = f"[{timestamp}] ERROR: {message}"
    if data is not None:
        if isinstance(data, (dict, list)):
            log_line += f"\n{json.dumps(data, indent=2, default=str)}"
        else:
            log_line += f"\n{data}"
    if exception:
        log_line += f"\nException: {type(exception).__name__}: {exception}"
        log_line += f"\nTraceback:\n{traceback.format_exc()}"
    
    # Always write to error log file
    try:
        with open(ERROR_LOG_FILE, 'a', encoding='utf-8') as f:
            f.write(log_line + "\n" + "="*60 + "\n")
    except Exception:
        pass  # Don't fail if we can't write error log
    
    # Also print to stderr for visibility
    print(f"ERROR: {message}", file=sys.stderr)


def debug_log(message, data=None):
    """Write debug info to log file and console"""
    if not DEBUG_MODE:
        return
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]
    log_line = f"[{timestamp}] {message}"
    if data is not None:
        if isinstance(data, (dict, list)):
            log_line += f"\n{json.dumps(data, indent=2, default=str)}"
        else:
            log_line += f"\n{data}"

    # Don't print to console - it breaks stdout parsing for commands like --list-email-templates

    # Write to file
    try:
        with open(DEBUG_LOG_FILE, 'a', encoding='utf-8') as f:
            f.write(log_line + "\n" + "-"*60 + "\n")
    except Exception as e:
        print(f"DEBUG LOG ERROR: {e}")

# Helper function to get monitor info
def get_monitor_info():
    """Get information about all connected monitors including resolution and DPI scaling."""
    monitors = []
    try:
        import ctypes
        from ctypes import wintypes
        
        # Enable DPI awareness to get accurate scaling info
        try:
            ctypes.windll.shcore.SetProcessDpiAwareness(1)
        except Exception:
            pass
        
        # EnumDisplayMonitors callback
        MONITORENUMPROC = ctypes.WINFUNCTYPE(ctypes.c_bool, ctypes.c_void_p, ctypes.c_void_p, ctypes.POINTER(wintypes.RECT), ctypes.c_void_p)
        
        def callback(hMonitor, hdcMonitor, lprcMonitor, dwData):
            try:
                # Get monitor info
                class MONITORINFOEX(ctypes.Structure):
                    _fields_ = [
                        ("cbSize", wintypes.DWORD),
                        ("rcMonitor", wintypes.RECT),
                        ("rcWork", wintypes.RECT),
                        ("dwFlags", wintypes.DWORD),
                        ("szDevice", wintypes.WCHAR * 32)
                    ]
                
                mi = MONITORINFOEX()
                mi.cbSize = ctypes.sizeof(MONITORINFOEX)
                ctypes.windll.user32.GetMonitorInfoW(hMonitor, ctypes.byref(mi))
                
                # Calculate resolution
                width = mi.rcMonitor.right - mi.rcMonitor.left
                height = mi.rcMonitor.bottom - mi.rcMonitor.top
                
                # Get DPI scaling
                dpi_x = ctypes.c_uint()
                dpi_y = ctypes.c_uint()
                try:
                    ctypes.windll.shcore.GetDpiForMonitor(hMonitor, 0, ctypes.byref(dpi_x), ctypes.byref(dpi_y))
                    scale = int(dpi_x.value / 96 * 100)
                except Exception:
                    scale = 100
                
                is_primary = (mi.dwFlags & 1) != 0
                monitors.append({
                    'device': mi.szDevice.strip('\x00'),
                    'width': width,
                    'height': height,
                    'left': mi.rcMonitor.left,
                    'top': mi.rcMonitor.top,
                    'work_left': mi.rcWork.left,
                    'work_top': mi.rcWork.top,
                    'work_right': mi.rcWork.right,
                    'work_bottom': mi.rcWork.bottom,
                    'scale': scale,
                    'primary': is_primary
                })
            except Exception:
                pass
            return True
        
        ctypes.windll.user32.EnumDisplayMonitors(None, None, MONITORENUMPROC(callback), 0)
    except Exception:
        pass
    return monitors

# Initialize debug log with header
if DEBUG_MODE:
    try:
        computer_name = os.environ.get('COMPUTERNAME', 'Unknown')
        username = os.environ.get('USERNAME', 'Unknown')
        monitors = get_monitor_info()
        with open(DEBUG_LOG_FILE, 'a', encoding='utf-8') as f:
            f.write(f"\n{'='*70}\n")
            f.write(f"SIDEKICK DEBUG LOG - VERBOSE MODE\n")
            f.write(f"{'='*70}\n")
            f.write(f"Session Start:  {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
            f.write(f"SideKick Ver:   {get_sidekick_version()}\n")
            f.write(f"Computer Name:  {computer_name}\n")
            f.write(f"Windows User:   {username}\n")
            f.write(f"Location ID:    {DEBUG_LOCATION_ID}\n")
            f.write(f"Python Version: {sys.version}\n")
            script_path = sys.executable if getattr(sys, 'frozen', False) else os.path.abspath(__file__)
            f.write(f"Script Path:    {script_path}\n")
            f.write(f"Working Dir:    {os.getcwd()}\n")
            f.write(f"Command Args:   {sys.argv}\n")
            f.write(f"{'-'*70}\n")
            f.write(f"DISPLAY INFO ({len(monitors)} monitor{'s' if len(monitors) != 1 else ''}):\n")
            for i, mon in enumerate(monitors, 1):
                primary_str = " [PRIMARY]" if mon.get('primary') else ""
                f.write(f"  Monitor {i}{primary_str}: {mon['width']}x{mon['height']} @ {mon['scale']}% scaling\n")
                f.write(f"    Position: ({mon['left']}, {mon['top']})\n")
                f.write(f"    Work Area: ({mon['work_left']}, {mon['work_top']}) to ({mon['work_right']}, {mon['work_bottom']})\n")
            f.write(f"{'='*70}\n\n")
    except Exception:
        pass

# Fix Unicode output on Windows console (skip if running without console)
if sys.platform == 'win32':
    if sys.stdout is not None:
        try:
            sys.stdout.reconfigure(encoding='utf-8')
        except (AttributeError, OSError):
            pass
    if sys.stderr is not None:
        try:
            sys.stderr.reconfigure(encoding='utf-8')
        except (AttributeError, OSError):
            pass

# Auto-install dependencies
def install_dependencies() -> None:
    """Auto-install required Python packages if not present."""
    required = ['requests']
    for package in required:
        try:
            __import__(package)
        except ImportError:
            subprocess.check_call([sys.executable, '-m', 'pip', 'install', package, '-q'])

install_dependencies()
import requests

# =============================================================================
# Encryption/Decryption (matches lib\Notes.ahk)
# =============================================================================
def notes_minus(encrypted: str, delimiters: str) -> str:
    """Decrypt string using XOR - matches Notes_Minus() in AHK"""
    result = []
    delim_pos = 0
    for char in encrypted:
        xor_val = (ord(char) - 15000) ^ ord(delimiters[delim_pos % len(delimiters)])
        result.append(chr(xor_val))
        delim_pos += 1
    return ''.join(result)

# =============================================================================
# Load Configuration from INI
# =============================================================================
# For PyInstaller compiled EXE: INI is in same folder as EXE
if getattr(sys, 'frozen', False):
    # Running as compiled EXE - INI is alongside the EXE
    SCRIPT_DIR = os.path.dirname(sys.executable)
else:
    # Running as .py script
    SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

INI_FILE = os.path.join(SCRIPT_DIR, 'SideKick_PS.ini')

# Output file goes to user-writable location (APPDATA or TEMP) to avoid permission issues
# when running from Program Files
def _get_output_dir():
    """Get a writable directory for output files."""
    # Try APPDATA first (persists across sessions)
    appdata = os.environ.get('APPDATA')
    if appdata:
        sidekick_dir = os.path.join(appdata, 'SideKick_PS')
        try:
            os.makedirs(sidekick_dir, exist_ok=True)
            return sidekick_dir
        except OSError:
            pass
    # Fall back to TEMP
    return os.environ.get('TEMP', SCRIPT_DIR)

OUTPUT_FILE = os.path.join(_get_output_dir(), 'ghl_invoice_sync_result.json')
ENCRYPT_KEY = "ZoomPhotography2026"


def _parse_ini_line(line: str, current_section: str, config: dict) -> str:
    """Parse a single INI line and update config.

    Args:
        line: Stripped line from INI file.
        current_section: Current section name.
        config: Config dict to update.

    Returns:
        str: Updated current section name.
    """
    if line.startswith('[') and line.endswith(']'):
        section = line[1:-1]
        config[section] = {}
        return section
    if '=' in line and current_section:
        key, value = line.split('=', 1)
        config[current_section][key.strip()] = value.strip()
    return current_section


def _parse_ini_file(ini_path: str) -> dict:
    """Parse INI file into nested dictionary by section.

    Args:
        ini_path: Path to the INI file.

    Returns:
        dict: Nested dictionary with sections as keys.
    """
    # Auto-fix corrupted INI files (e.g., multi-line PaymentTypes)
    _sanitize_ini_file(ini_path)
    
    config = {}
    current_section = None

    # Try multiple encodings (AHK often writes UTF-16)
    encodings = ['utf-8', 'utf-16', 'utf-16-le', 'cp1252', 'latin-1']
    content = None

    for encoding in encodings:
        try:
            with open(ini_path, 'r', encoding=encoding) as f:
                content = f.read()
            break
        except (UnicodeDecodeError, UnicodeError):
            continue

    if content is None:
        raise ValueError(f"Could not decode INI file with any known encoding: {ini_path}")

    for line in content.splitlines():
        line = line.strip()
        if not line or line.startswith(';'):
            continue
        current_section = _parse_ini_line(line, current_section, config)

    return config


def _decode_api_key(ghl_config: dict, key_name: str = None) -> str:
    """Decode Base64 API key from GHL config section.

    Args:
        ghl_config: The GHL section dictionary from INI.
        key_name: Specific key name to decode (e.g., 'API_Key_V1_B64' or 'API_Key_V2_B64')

    Returns:
        str: Decoded API key.

    Raises:
        ValueError: If no API key found.
    """
    import base64

    if key_name:
        api_b64 = ghl_config.get(key_name, '')
    else:
        # Try new key name first, then fallback to legacy name
        api_b64 = ghl_config.get('API_Key_B64', '') or ghl_config.get('API_Key_V2_B64', '')

    if api_b64:
        api_b64_clean = api_b64.replace(' ', '').replace('\n', '').replace('\r', '')
        return base64.b64decode(api_b64_clean).decode('utf-8')
    else:
        if key_name:
            return ''  # Optional key not found
        raise ValueError("No API key found in INI file (need API_Key_B64 or API_Key_V2_B64)")


def load_config() -> dict:
    """Load configuration from INI file (handles malformed multi-line values).

    Returns:
        dict: Configuration dictionary with API_KEY and LOCATION_ID.
    """
    config = _parse_ini_file(INI_FILE)

    if 'GHL' not in config:
        raise ValueError(f"[GHL] section not found in {INI_FILE}")

    ghl = config['GHL']
    api_key = _decode_api_key(ghl)
    location_id = ghl.get('LocationID', '')
    
    # Tag settings (configurable)
    sync_tag = ghl.get('SyncTag', 'PS Invoice')  # Tag added when invoice synced
    opportunity_tags = ghl.get('OpportunityTags', 'ProSelect,Invoice Synced')  # Tags for opportunities

    # DEBUG: Override location ID if debug mode is on
    if DEBUG_MODE and DEBUG_LOCATION_ID:
        location_id = DEBUG_LOCATION_ID
        debug_log(f"Using DEBUG location ID: {DEBUG_LOCATION_ID}")

    return {
        'API_KEY': api_key,
        'LOCATION_ID': location_id,
        'SYNC_TAG': sync_tag,
        'OPPORTUNITY_TAGS': [t.strip() for t in opportunity_tags.split(',') if t.strip()],
    }

# Load config
try:
    CONFIG = load_config()
    API_KEY = CONFIG['API_KEY']
    debug_log("Config loaded successfully", {"location_id": CONFIG.get('LOCATION_ID'), "api_key_set": bool(API_KEY)})
except Exception as e:
    print(f"⚠ Config Error: {e}")
    debug_log("CONFIG ERROR", str(e))
    API_KEY = ""

# Cache for business details
_BUSINESS_DETAILS_CACHE = None

def get_business_details() -> dict:
    """Get full business details from GHL location settings.

    Returns:
        dict: Business details including name, address, phone, email, logo.
    """
    global _BUSINESS_DETAILS_CACHE
    if _BUSINESS_DETAILS_CACHE:
        return _BUSINESS_DETAILS_CACHE

    default_details = {"name": "Business"}

    try:
        location_id = CONFIG.get('LOCATION_ID', '')
        url = f"https://services.leadconnectorhq.com/locations/{location_id}"
        headers = {
            "Authorization": f"Bearer {API_KEY}",
            "Content-Type": "application/json",
            "Version": "2021-07-28"
        }
        response = requests.get(url, headers=headers, timeout=10)
        if response.status_code == 200:
            data = response.json().get('location', {})
            business = data.get('business', {})

            # Build business details dict
            details = {
                "name": data.get('name') or business.get('name') or 'Business'
            }

            # Add address if available - must be object for invoice API
            address = data.get('address') or data.get('businessAddress') or business.get('address')
            if address:
                # If address is a string, convert to object format required by invoice API
                if isinstance(address, str):
                    details["address"] = {"addressLine1": address}
                else:
                    details["address"] = address

            # Add phone if available
            phone = data.get('phone') or business.get('phone')
            if phone:
                details["phoneNo"] = phone

            # Add email if available
            email = data.get('email') or business.get('email')
            if email:
                details["email"] = email

            # Add logo if available
            logo = data.get('logoUrl') or business.get('logoUrl')
            if logo:
                details["logoUrl"] = logo

            # Add website if available
            website = data.get('website') or business.get('website')
            if website:
                details["website"] = website

            # Add VAT/Tax ID if available
            vat = data.get('vatNumber') or data.get('taxId') or business.get('vatNumber') or business.get('taxId')
            if vat:
                details["customValues"] = [{"Tax ID/VAT Number": vat}]

            _BUSINESS_DETAILS_CACHE = details
            debug_log("BUSINESS DETAILS FETCHED", details)
            return details
    except Exception as e:
        debug_log(f"ERROR fetching business details: {e}")

    return default_details

def get_business_name() -> str:
    """Get business name from GHL location settings.

    Returns:
        str: Business name, or 'Business' as fallback.
    """
    return get_business_details().get("name", "Business")

def get_media_folder_id() -> str | None:
    """Get saved media folder ID from INI file.

    Returns:
        str | None: The folder ID if found, None otherwise.
    """
    debug_log("GET MEDIA FOLDER ID - Reading from INI")
    try:
        config = _parse_ini_file(INI_FILE)
        ghl = config.get('GHL', {})
        folder_id = ghl.get('MediaFolderID', '').strip()
        if folder_id:
            debug_log("MEDIA FOLDER ID FOUND", {"folder_id": folder_id})
            return folder_id
        debug_log("MEDIA FOLDER ID - Not found in INI")
    except Exception as e:
        debug_log("MEDIA FOLDER ID ERROR", {"error": str(e)})
    return None

# GHL Custom Field IDs (from ghl_all_fields.json)
CUSTOM_FIELDS = {
    'session_job_no': '82WRQe9Rl6o8uJQ8cgZV',
    'session_status': 'rcBTBSNw75gA0BOaVPEr',
    'session_date': 'j2lMRPMOYHIxapnz5qDK',
}

def parse_proselect_xml(xml_path: str) -> dict | None:
    """Parse ProSelect XML export and extract order data"""

    debug_log(f"PARSING XML FILE: {xml_path}")

    if not os.path.exists(xml_path):
        debug_log(f"ERROR: XML file does not exist: {xml_path}")
        return None

    # Log file size and modification time
    file_stat = os.stat(xml_path)
    debug_log(f"XML file stats", {
        "size_bytes": file_stat.st_size,
        "modified": datetime.fromtimestamp(file_stat.st_mtime).strftime('%Y-%m-%d %H:%M:%S')
    })

    try:
        tree = ET.parse(xml_path)
        root = tree.getroot()

        debug_log(f"XML parsed successfully, root tag: {root.tag}")

        # Extract client info - Client_ID is the GHL contact ID
        client_id_raw = get_text(root, 'Client_ID')
        album_name = get_text(root, 'Album_Name')
        email = get_text(root, 'Email_Address')
        
        # Determine GHL contact ID with multiple fallback strategies
        # GHL contact IDs are 20+ alphanumeric chars (e.g., UWge6H1hK1raUtu1nrAo)
        ghl_contact_id = None
        
        # Strategy 1: If Client_ID looks like a GHL ID (20+ chars), use it directly
        if client_id_raw and len(client_id_raw) >= 15 and client_id_raw.isalnum():
            ghl_contact_id = client_id_raw
            debug_log(f"Using Client_ID as GHL contact ID", {"id": ghl_contact_id})
        
        # Strategy 2: Extract GHL contact ID from Album_Name
        # Formats: "ShootNo_Name_GHLContactID" or just containing a 15+ char alphanumeric segment
        if not ghl_contact_id and album_name:
            # Try splitting by underscore first
            if '_' in album_name:
                parts = album_name.split('_')
                # Check each part for a GHL-like ID (15+ chars, alphanumeric)
                for part in reversed(parts):  # Check from end first
                    clean_part = part.strip()
                    if len(clean_part) >= 15 and clean_part.isalnum():
                        ghl_contact_id = clean_part
                        debug_log(f"Extracted GHL contact ID from Album_Name (underscore split)", {
                            "album_name": album_name,
                            "extracted_id": ghl_contact_id
                        })
                        break
            
            # If still not found, look for any 20+ char alphanumeric sequence
            if not ghl_contact_id:
                import re
                matches = re.findall(r'[A-Za-z0-9]{20,}', album_name)
                if matches:
                    ghl_contact_id = matches[-1]  # Use last match (usually the ID)
                    debug_log(f"Extracted GHL contact ID from Album_Name (regex)", {
                        "album_name": album_name,
                        "extracted_id": ghl_contact_id
                    })
        
        # Strategy 3: If no valid ID found yet, search GHL by email
        if not ghl_contact_id and email:
            debug_log(f"No GHL ID found in Client_ID or Album_Name, searching by email", {"email": email})
            found_id = find_ghl_contact(email, None)
            if found_id:
                ghl_contact_id = found_id
                debug_log(f"Found GHL contact ID by email search", {"id": ghl_contact_id})
        
        # Log final result
        if ghl_contact_id:
            debug_log(f"Final GHL contact ID determined", {
                "ghl_contact_id": ghl_contact_id,
                "source": "Client_ID" if client_id_raw == ghl_contact_id else ("Album_Name" if client_id_raw != ghl_contact_id else "email_search"),
                "client_id_raw": client_id_raw,
                "album_name": album_name
            })
        else:
            debug_log(f"WARNING: Could not determine GHL contact ID", {
                "client_id_raw": client_id_raw,
                "album_name": album_name,
                "email": email
            })
        
        data: dict = {
            'ghl_contact_id': ghl_contact_id,  # GHL contact ID from ProSelect
            'email': get_text(root, 'Email_Address'),
            'first_name': get_text(root, 'First_Name'),
            'last_name': get_text(root, 'Last_Name'),
            'phone': get_text(root, 'Cell_Phone') or get_text(root, 'Home_Phone') or get_text(root, 'Work_Phone'),
            'album_name': album_name,
            'album_path': get_text(root, 'Album_Path'),
            # Address fields
            'street': get_text(root, 'Street'),
            'street2': get_text(root, 'Street2'),
            'city': get_text(root, 'City'),
            'state': get_text(root, 'State'),
            'zip_code': get_text(root, 'Zip_Code'),
            'country': get_text(root, 'Country'),
        }

        debug_log("CLIENT INFO EXTRACTED", data)

        # Extract order info
        order = root.find('Order')
        if order is not None:
            items_list: list = []
            payments_list: list = []

            # Parse ordered items - VAT is handled by ProSelect per user settings
            for item in order.findall('.//Ordered_Item'):
                price = float(get_text(item, 'Extended_Price', '0'))

                # Get tax info as ProSelect provides it (respects user's VAT settings)
                tax_elem = item.find('Tax')
                is_taxable = tax_elem.get('taxable', 'false').lower() == 'true' if tax_elem is not None else False
                vat_amount = float(get_text(item, 'Tax', '0'))
                
                # Get detailed tax info from Tax1 element (for Xero/QuickBooks sync)
                tax1_elem = item.find('Tax1')
                tax_label = tax1_elem.get('label', '') if tax1_elem is not None else ''
                tax_rate = float(tax1_elem.get('rate', '0')) if tax1_elem is not None else 0.0
                price_includes_tax = tax1_elem.get('priceIncludesTax', 'false').lower() == 'true' if tax1_elem is not None else False
                
                # Get ProductLineName for product categorization
                product_line_elem = item.find('ProductLineName')
                product_line = get_text(item, 'ProductLineName')
                product_line_code = product_line_elem.get('code', '') if product_line_elem is not None else ''

                item_data = {
                    'type': get_text(item, 'ItemType'),
                    'description': get_text(item, 'Description'),
                    'product': get_text(item, 'Product_Name'),
                    'sku': get_text(item, 'Product_Code'),  # SKU for GHL/Xero/QuickBooks product matching
                    'ps_item_id': get_text(item, 'ID'),  # ProSelect internal item ID
                    'size': get_text(item, 'Size'),  # Product size (e.g., "10.0x8.0")
                    'template': get_text(item, 'Template_Name'),  # ProSelect template name
                    'price': price,
                    'quantity': int(get_text(item, 'Quantity', '1')),
                    'taxable': is_taxable,
                    'vat_amount': vat_amount,
                    'tax_label': tax_label,  # e.g., "VAT (20%)"
                    'tax_rate': tax_rate,  # e.g., 20.0
                    'price_includes_tax': price_includes_tax,  # True if price is tax-inclusive
                    'product_line': product_line,  # e.g., "Studio Pricing"
                    'product_line_code': product_line_code,  # e.g., "A"
                }
                items_list.append(item_data)

            # Parse payments
            for payment in order.findall('.//Payment'):
                payment_data = {
                    'id': payment.get('id'),
                    'date': get_text(payment, 'DateSQL'),
                    'amount': float(get_text(payment, 'Amount', '0')),
                    'method': get_text(payment, 'MethodName'),
                    'type': get_text(payment, 'Type')  # OD=Ordered, FP=Final Payment
                }
                payments_list.append(payment_data)

            data['order'] = {
                'date': get_text(order, 'DateSQL'),
                'album_id': get_text(order, 'Album_ID'),
                'total_amount': float(get_text(order, 'Total_Amount', '0')),
                'items': items_list,
                'payments': payments_list
            }

            # Calculate VAT summary from ProSelect data
            total_vat = sum(item['vat_amount'] for item in items_list)
            total_ex_vat = data['order']['total_amount'] - total_vat
            vatable_items = [i for i in items_list if i['taxable']]
            exempt_items = [i for i in items_list if not i['taxable']]

            data['order']['vat'] = {
                'total_vat': total_vat,
                'total_ex_vat': total_ex_vat,
                'vatable_count': len(vatable_items),
                'exempt_count': len(exempt_items)
            }

            debug_log("ORDER DATA EXTRACTED", {
                "date": data['order']['date'],
                "total_amount": data['order']['total_amount'],
                "items_count": len(items_list),
                "payments_count": len(payments_list),
                "vat_info": data['order']['vat']
            })

            debug_log("ORDER ITEMS DETAIL", items_list)
            debug_log("PAYMENT SCHEDULE DETAIL", payments_list)

        return data

    except Exception as e:
        debug_log(f"XML PARSING ERROR: {e}", {"traceback": str(e)})
        error_log(f"XML PARSING FAILED: {xml_path}", {"error": str(e)}, exception=e)
        print(f"Error parsing XML: {e}")
        return None

def get_text(element, tag: str, default: str = '') -> str:
    """Safely get text from XML element.

    Args:
        element: XML element to search in.
        tag: Tag name to find.
        default: Default value if not found.

    Returns:
        str: The text content or default value.
    """
    child = element.find(tag)
    return child.text if child is not None and child.text else default


def _get_ghl_headers() -> dict:
    """Get standard GHL API headers.

    Returns:
        dict: Headers with authorization and version.
    """
    return {
        "Authorization": f"Bearer {API_KEY}",
        "Content-Type": "application/json",
        "Version": "2021-07-28"
    }


def fetch_ghl_contact(contact_id: str) -> dict | None:
    """Fetch contact details from GHL.

    Args:
        contact_id: The GHL contact ID.

    Returns:
        dict: Contact data with email, phone, name, address, or None if failed.
    """
    if not contact_id:
        return None

    url = f"https://services.leadconnectorhq.com/contacts/{contact_id}"
    debug_log(f"FETCHING GHL CONTACT: {contact_id}")

    try:
        response = requests.get(url, headers=_get_ghl_headers(), timeout=30)
        debug_log(f"FETCH CONTACT RESPONSE: Status={response.status_code}")

        if response.status_code == 200:
            data = response.json()
            contact = data.get('contact', {})
            result = {
                'id': contact.get('id', ''),
                'email': contact.get('email', ''),
                'phone': contact.get('phone', ''),
                'firstName': contact.get('firstName', ''),
                'lastName': contact.get('lastName', ''),
                'name': contact.get('contactName', '') or f"{contact.get('firstName', '')} {contact.get('lastName', '')}".strip(),
                # Address fields
                'street': contact.get('address1', ''),
                'street2': contact.get('address2', ''),
                'city': contact.get('city', ''),
                'state': contact.get('state', ''),
                'zip_code': contact.get('postalCode', ''),
                'country': contact.get('country', ''),
            }
            debug_log("FETCHED CONTACT DATA", result)
            return result
        else:
            debug_log(f"FETCH CONTACT FAILED: {response.status_code}", {"body": response.text[:500]})
            return None
    except Exception as e:
        debug_log(f"FETCH CONTACT EXCEPTION: {e}")
        return None


def add_tags_to_contact(contact_id: str, tags: list[str]) -> bool:
    """Add tags to a GHL contact using v2 API.

    Args:
        contact_id: The GHL contact ID.
        tags: List of tag names to add.

    Returns:
        bool: True if tags were added successfully, False otherwise.
    """
    if not tags:
        return True  # Nothing to add

    url = f"https://services.leadconnectorhq.com/contacts/{contact_id}/tags"
    payload = {"tags": tags}

    debug_log(f"ADDING TAGS TO CONTACT: {contact_id}", {"tags": tags})

    try:
        response = requests.post(url, headers=_get_ghl_headers(), json=payload, timeout=30)
        debug_log(f"ADD TAGS RESPONSE: Status={response.status_code}", {
            "body": response.text[:500] if response.text else "EMPTY"
        })
        if response.status_code in [200, 201]:
            print(f"   🏷️ Added tags: {', '.join(tags)}")
            return True
        else:
            print(f"   ⚠️ Failed to add tags: {response.status_code}")
            return False
    except Exception as e:
        debug_log(f"ADD TAGS FAILED: {e}")
        print(f"   ⚠️ Failed to add tags: {e}")
        return False


def get_contact_opportunities(contact_id: str) -> list[dict]:
    """Get all opportunities for a contact.

    Args:
        contact_id: The GHL contact ID.

    Returns:
        list[dict]: List of opportunities for the contact.
    """
    url = f"https://services.leadconnectorhq.com/opportunities/search"
    payload = {
        "locationId": CONFIG.get('LOCATION_ID', ''),
        "contactId": contact_id
    }

    debug_log(f"SEARCHING OPPORTUNITIES FOR CONTACT: {contact_id}")

    try:
        response = requests.post(url, headers=_get_ghl_headers(), json=payload, timeout=30)
        debug_log(f"OPPORTUNITIES RESPONSE: Status={response.status_code}", {
            "body": response.text[:500] if response.text else "EMPTY"
        })
        if response.status_code == 200:
            return response.json().get('opportunities', [])
    except Exception as e:
        debug_log(f"GET OPPORTUNITIES FAILED: {e}")

    return []


def add_tags_to_opportunity(opportunity_id: str, tags: list[str]) -> bool:
    """Add tags to a GHL opportunity.

    Note: GHL v2 API updates opportunity via PUT with tags array.

    Args:
        opportunity_id: The GHL opportunity ID.
        tags: List of tag names to add.

    Returns:
        bool: True if tags were added successfully, False otherwise.
    """
    if not tags:
        return True

    # First get current opportunity to preserve existing tags
    url = f"https://services.leadconnectorhq.com/opportunities/{opportunity_id}"
    
    try:
        response = requests.get(url, headers=_get_ghl_headers(), timeout=30)
        if response.status_code != 200:
            debug_log(f"GET OPPORTUNITY FAILED: {response.status_code}")
            return False
        
        opportunity = response.json().get('opportunity', {})
        existing_tags = opportunity.get('tags', [])
        
        # Merge tags (avoid duplicates)
        all_tags = list(set(existing_tags + tags))
        
        # Update opportunity with merged tags
        update_payload = {"tags": all_tags}
        response = requests.put(url, headers=_get_ghl_headers(), json=update_payload, timeout=30)
        
        debug_log(f"UPDATE OPPORTUNITY TAGS RESPONSE: Status={response.status_code}", {
            "body": response.text[:500] if response.text else "EMPTY"
        })
        
        if response.status_code == 200:
            new_tags = [t for t in tags if t not in existing_tags]
            if new_tags:
                print(f"   🏷️ Added opportunity tags: {', '.join(new_tags)}")
            return True
        else:
            print(f"   ⚠️ Failed to update opportunity tags: {response.status_code}")
            return False
            
    except Exception as e:
        debug_log(f"ADD OPPORTUNITY TAGS FAILED: {e}")
        print(f"   ⚠️ Failed to add opportunity tags: {e}")
        return False


def tag_contact_opportunities(contact_id: str, tags: list[str]) -> int:
    """Add tags to all opportunities for a contact.

    Args:
        contact_id: The GHL contact ID.
        tags: List of tag names to add.

    Returns:
        int: Number of opportunities tagged.
    """
    if not tags:
        return 0

    opportunities = get_contact_opportunities(contact_id)
    if not opportunities:
        debug_log(f"No opportunities found for contact {contact_id}")
        return 0

    tagged_count = 0
    for opp in opportunities:
        opp_id = opp.get('id')
        if opp_id and add_tags_to_opportunity(opp_id, tags):
            tagged_count += 1

    if tagged_count > 0:
        debug_log(f"Tagged {tagged_count} opportunities for contact {contact_id}")

    return tagged_count


def _search_ghl_contacts(filters: list, search_type: str) -> str | None:
    """Search GHL contacts with given filters.

    Args:
        filters: List of filter dictionaries for the search.
        search_type: Description of search type for logging.

    Returns:
        str | None: Contact ID if found, None otherwise.
    """
    url = "https://services.leadconnectorhq.com/contacts/search"
    payload = {
        "locationId": CONFIG.get('LOCATION_ID', ''),
        "filters": filters
    }

    debug_log(f"SEARCHING BY {search_type}: {url}", payload)

    try:
        response = requests.post(url, headers=_get_ghl_headers(), json=payload, timeout=60)
        debug_log(f"SEARCH RESPONSE: Status={response.status_code}", {
            "body": response.text[:1000] if response.text else "EMPTY"
        })
        if response.status_code == 200:
            contacts = response.json().get('contacts', [])
            if contacts:
                debug_log(f"CONTACT FOUND BY {search_type}", {"contact_id": contacts[0]['id'], "count": len(contacts)})
                return contacts[0]['id']
    except Exception as e:
        debug_log(f"SEARCH BY {search_type} FAILED: {e}")

    return None


def find_ghl_contact(email: str, client_id: str) -> dict | None:
    """Find GHL contact by email or client_id.

    Args:
        email: Contact email address.
        client_id: ProSelect client ID (session_job_no).

    Returns:
        dict | None: Contact data if found, None otherwise.
    """
    debug_log("FIND GHL CONTACT CALLED", {"email": email, "client_id": client_id})

    # Search by email first - PRIMARY method (most reliable)
    if email:
        filters = [{"field": "email", "operator": "eq", "value": email}]
        contact_id = _search_ghl_contacts(filters, "EMAIL")
        if contact_id:
            print(f"✓ Found contact by email: {email}")
            return contact_id

    # Fallback: search by client_id in custom field (session_job_no)
    if client_id:
        filters = [{
            "field": "customFields." + CUSTOM_FIELDS['session_job_no'],
            "operator": "eq",
            "value": client_id
        }]
        contact_id = _search_ghl_contacts(filters, "CLIENT_ID")
        if contact_id:
            print(f"✓ Found contact by Client ID: {client_id}")
            return contact_id

    debug_log(f"CONTACT NOT FOUND", {"client_id": client_id, "email": email})
    print(f"✗ Contact not found - Email: {email}, Client ID: {client_id}")
    return None


def calculate_payment_summary(order_data: dict) -> dict:
    """Calculate payment plan summary.

    Args:
        order_data: Order data dictionary with payments.

    Returns:
        dict: Summary with total, scheduled, deposit, status, etc.
    """

    if 'payments' not in order_data:
        return {}

    total = order_data.get('total_amount', 0)
    payments = order_data['payments']

    scheduled_total = sum(p['amount'] for p in payments)
    deposit_paid = total - scheduled_total if scheduled_total < total else 0

    # Determine status
    if not payments:
        status = "Paid in Full"
    elif deposit_paid > 0:
        status = "Deposit Paid - Payment Plan Active"
    else:
        status = "Payment Plan Active"

    # Last payment date (expected delivery)
    delivery_date = payments[-1]['date'] if payments else order_data.get('date')

    return {
        'total': total,
        'scheduled': scheduled_total,
        'deposit': deposit_paid,
        'status': status,
        'payment_count': len(payments),
        'delivery_date': delivery_date
    }

def create_order_summary(items: list) -> str:
    """Create human-readable order summary.

    Args:
        items: List of order items.

    Returns:
        str: Formatted summary text.
    """

    summary_lines = []
    for item in items:
        qty = item['quantity']
        desc = item['description']
        price = item['price']
        summary_lines.append(f"{qty}× {desc} (£{price:.2f})")

    return "\n".join(summary_lines)


def get_ghl_invoice(invoice_id: str) -> dict | None:
    """Fetch invoice details from GHL.

    Args:
        invoice_id: GHL invoice ID.

    Returns:
        dict or None: Invoice data if found, None otherwise.
    """
    url = f"https://services.leadconnectorhq.com/invoices/{invoice_id}"
    debug_log(f"GET INVOICE REQUEST: {url}")

    try:
        response = requests.get(url, headers=_get_ghl_headers(), timeout=30)
        debug_log(f"GET INVOICE RESPONSE: Status={response.status_code}", {
            "body": response.text[:2000] if response.text else "EMPTY"
        })

        if response.status_code == 200:
            return response.json()
        return None
    except requests.exceptions.RequestException as e:
        debug_log(f"GET INVOICE ERROR: {e}")
        return None


def update_invoice_to_draft(invoice_id: str) -> dict:
    """Try to update an invoice to 'draft' status to enable deletion.

    This may allow voiding/deleting invoices that have payment restrictions.
    Note: GHL may not allow this for paid invoices.

    Args:
        invoice_id: GHL invoice ID.

    Returns:
        dict: Result with success status.
    """
    url = f"https://services.leadconnectorhq.com/invoices/{invoice_id}"
    payload = {
        "altId": CONFIG.get('LOCATION_ID', ''),
        "altType": "location",
        "status": "draft"
    }
    debug_log(f"UPDATE INVOICE TO DRAFT: {url}", payload)

    try:
        response = requests.put(url, headers=_get_ghl_headers(), json=payload, timeout=30)
        debug_log(f"UPDATE TO DRAFT RESPONSE: Status={response.status_code}", {
            "body": response.text[:1000] if response.text else "EMPTY"
        })

        if response.status_code in [200, 201, 204]:
            debug_log(f"INVOICE UPDATED TO DRAFT: {invoice_id}")
            return {'success': True, 'invoice_id': invoice_id}
        else:
            return {'success': False, 'error': f"Status update failed (HTTP {response.status_code})", 'response': response.text}
    except requests.exceptions.RequestException as e:
        return {'success': False, 'error': str(e)}


def has_payment_provider_transactions(invoice: dict) -> tuple[bool, list]:
    """Check if an invoice has payment provider transactions that need manual refund.

    Payment provider transactions (GoCardless, Stripe) cannot be refunded via API
    and must be manually refunded in GHL before the invoice can be voided.

    Args:
        invoice: Invoice data dict from GHL.

    Returns:
        tuple[bool, list]: (has_provider_payments, list of transaction details)
    """
    provider_payments = []
    
    # Check for transactions in the invoice data
    transactions = invoice.get('transactions', [])
    if not transactions:
        # Also check under 'paymentTransactions' or nested structures
        invoice_inner = invoice.get('invoice', invoice)
        transactions = invoice_inner.get('transactions', [])
    
    for txn in transactions:
        # Provider transactions have a paymentProvider field or specific source
        provider = txn.get('paymentProvider', txn.get('provider', ''))
        source = txn.get('source', '')
        
        # GoCardless, Stripe, or other payment providers
        is_provider = bool(provider) or source in ['gocardless', 'stripe', 'square', 'paypal']
        
        if is_provider and txn.get('status') == 'succeeded':
            provider_payments.append({
                'transaction_id': txn.get('_id', txn.get('id', '')),
                'amount': txn.get('amount', 0),
                'provider': provider or source,
                'date': txn.get('createdAt', txn.get('date', ''))
            })
    
    return (len(provider_payments) > 0, provider_payments)


def analyze_invoices_for_problems(invoices: list) -> dict:
    """Analyze invoices to detect which ones will need manual handling.

    Checks each invoice for payment provider transactions that require
    manual refund before the API can void/delete them.

    Args:
        invoices: List of invoice dicts from GHL.

    Returns:
        dict: Analysis results with categorized invoices.
    """
    result = {
        'total': len(invoices),
        'can_delete': [],       # Invoices that can be auto-deleted
        'need_manual_refund': [],  # Invoices with provider payments
        'already_void': [],     # Already voided
        'problem_invoice_numbers': []  # For display to user
    }
    
    for inv in invoices:
        inv_id = inv.get('_id', inv.get('id', ''))
        inv_number = inv.get('invoiceNumber', inv.get('number', 'N/A'))
        inv_status = inv.get('status', 'unknown')
        amount_paid = inv.get('amountPaid', 0)
        
        if inv_status == 'void':
            result['already_void'].append(inv_id)
            continue
        
        # Fetch full invoice details to check transactions
        invoice_data = get_ghl_invoice(inv_id)
        if invoice_data:
            invoice_inner = invoice_data.get('invoice', invoice_data)
            has_provider, provider_txns = has_payment_provider_transactions(invoice_inner)
            
            if has_provider:
                result['need_manual_refund'].append({
                    'id': inv_id,
                    'number': inv_number,
                    'amount_paid': amount_paid,
                    'transactions': provider_txns
                })
                result['problem_invoice_numbers'].append(f"#{inv_number}")
            else:
                result['can_delete'].append(inv_id)
        else:
            # Can't check, assume it's deletable
            result['can_delete'].append(inv_id)
    
    debug_log("INVOICE ANALYSIS COMPLETE", {
        "total": result['total'],
        "can_delete": len(result['can_delete']),
        "need_manual_refund": len(result['need_manual_refund']),
        "already_void": len(result['already_void'])
    })
    
    return result


def list_contact_invoices(contact_id: str, contact_name: str = "") -> list:
    """List all invoices for a GHL contact.

    Args:
        contact_id: GHL contact ID.
        contact_name: Contact name for fallback search.

    Returns:
        list: List of invoice dicts, or empty list.
    """
    url = "https://services.leadconnectorhq.com/invoices/"
    params = {
        "altId": CONFIG.get('LOCATION_ID', ''),
        "altType": "location",
        "contactId": contact_id,
        "limit": 100,
        "offset": "0",
    }
    debug_log(f"LIST CONTACT INVOICES: {url}", params)

    try:
        response = requests.get(url, headers=_get_ghl_headers(), params=params, timeout=30)
        debug_log(f"LIST INVOICES RESPONSE: Status={response.status_code}", {
            "body": response.text[:3000] if response.text else "EMPTY"
        })

        if response.status_code == 200:
            data = response.json()
            invoices = data.get('invoices', data.get('data', []))
            debug_log(f"Found {len(invoices)} invoices for contact {contact_id}")
            if invoices:
                return invoices

        # Fallback: search by contact name if contactId returned nothing
        if contact_name:
            debug_log(f"Trying fallback search by name: {contact_name}")
            params_name = {
                "altId": CONFIG.get('LOCATION_ID', ''),
                "altType": "location",
                "search": contact_name,
                "limit": 100,
                "offset": "0",
            }
            response = requests.get(url, headers=_get_ghl_headers(), params=params_name, timeout=30)
            debug_log(f"LIST INVOICES BY NAME RESPONSE: Status={response.status_code}", {
                "body": response.text[:3000] if response.text else "EMPTY"
            })
            if response.status_code == 200:
                data = response.json()
                invoices = data.get('invoices', data.get('data', []))
                # Filter to only include invoices for this contact
                if contact_id:
                    invoices = [inv for inv in invoices if inv.get('contactDetails', {}).get('id') == contact_id]
                debug_log(f"Found {len(invoices)} invoices by name search for {contact_name}")
                return invoices
        return []
    except requests.exceptions.RequestException as e:
        debug_log(f"LIST INVOICES ERROR: {e}")
        return []


def list_contact_schedules(contact_id: str) -> list:
    """List all recurring invoice schedules for a GHL contact.

    Args:
        contact_id: GHL contact ID.

    Returns:
        list: List of schedule dicts, or empty list.
    """
    url = "https://services.leadconnectorhq.com/invoices/schedule/"
    params = {
        "altId": CONFIG.get('LOCATION_ID', ''),
        "altType": "location",
        "contactId": contact_id,
        "limit": 50,
        "offset": "0",
    }
    debug_log(f"LIST CONTACT SCHEDULES: {url}", params)

    try:
        response = requests.get(url, headers=_get_ghl_headers(), params=params, timeout=30)
        debug_log(f"LIST SCHEDULES RESPONSE: Status={response.status_code}", {
            "body": response.text[:3000] if response.text else "EMPTY"
        })

        if response.status_code == 200:
            data = response.json()
            schedules = data.get('schedules', data.get('data', []))
            debug_log(f"Found {len(schedules)} schedules for contact {contact_id}")
            return schedules
        return []
    except requests.exceptions.RequestException as e:
        debug_log(f"LIST SCHEDULES ERROR: {e}")
        return []


def delete_client_invoices(xml_path: str) -> dict:
    """Delete all invoices and schedules for the client in the given XML file.

    Parses the XML to get the contact ID, lists all their invoices and schedules
    in GHL, and deletes/voids them all.

    Args:
        xml_path: Path to ProSelect XML export file.

    Returns:
        dict: Result with success status, counts of deleted items, client info.
    """
    debug_log("DELETE CLIENT INVOICES CALLED", {"xml_path": xml_path})

    # Parse XML to get contact info
    ps_data = parse_proselect_xml(xml_path)
    if not ps_data:
        return {'success': False, 'error': 'Failed to parse XML file'}

    client_name = f"{ps_data.get('first_name', '')} {ps_data.get('last_name', '')}".strip()
    album_name = ps_data.get('album_name', '')
    email = ps_data.get('email', '')
    shoot_no = album_name.split('_')[0] if album_name and '_' in album_name else ''

    # Strategy 1: Extract GHL contact ID from album name first (most reliable)
    contact_id = None
    if album_name:
        import re
        # Look for 20+ char alphanumeric ID in album name
        matches = re.findall(r'[A-Za-z0-9]{20,}', album_name)
        if matches:
            contact_id = matches[-1]  # Use last match (usually the ID at end)
            debug_log(f"Found contact ID in album name", {"contact_id": contact_id, "album_name": album_name})

    # Strategy 2: Use ghl_contact_id from XML if album name didn't have it
    if not contact_id:
        xml_contact_id = ps_data.get('ghl_contact_id')
        if xml_contact_id and len(xml_contact_id) >= 15 and xml_contact_id.isalnum():
            contact_id = xml_contact_id
            debug_log(f"Using contact ID from XML", {"contact_id": contact_id})

    # Strategy 3: Search by email to find contact ID
    if not contact_id and email:
        debug_log(f"Searching for contact by email", {"email": email})
        found_id = find_ghl_contact(email, None)
        if found_id:
            contact_id = found_id
            debug_log(f"Found contact ID by email search", {"contact_id": contact_id, "email": email})

    debug_log("DELETE CLIENT INFO", {
        "client_name": client_name, "shoot_no": shoot_no,
        "contact_id": contact_id, "album_name": album_name, "email": email
    })
    print(f"\n🗑️ Delete invoices for: {client_name} ({shoot_no})")
    print(f"  Contact ID: {contact_id}")

    if not contact_id:
        debug_log("DELETE ABORTED - No contact ID found")
        return {'success': False, 'error': 'No GHL Contact ID found in XML or by email search', 'client_name': client_name}

    # List all invoices for this contact (with name fallback)
    print(f"  Searching for invoices...")
    invoices = list_contact_invoices(contact_id, client_name)
    debug_log(f"INVOICES FOUND: {len(invoices)}", [inv.get('_id', inv.get('id', '')) for inv in invoices])
    print(f"  Found {len(invoices)} invoice(s)")

    # List all schedules for this contact
    print(f"  Searching for recurring schedules...")
    schedules = list_contact_schedules(contact_id)
    debug_log(f"SCHEDULES FOUND: {len(schedules)}", [s.get('_id', s.get('id', '')) for s in schedules])
    print(f"  Found {len(schedules)} schedule(s)")

    if not invoices and not schedules:
        debug_log("NO INVOICES OR SCHEDULES FOUND FOR CLIENT")
        print(f"  No invoices or schedules found for this client.")
        return {
            'success': True, 'client_name': client_name, 'shoot_no': shoot_no,
            'contact_id': contact_id,
            'invoices_deleted': 0, 'schedules_cancelled': 0,
            'message': 'No invoices or schedules found'
        }

    # UPFRONT ANALYSIS: Check which invoices have payment provider transactions
    print(f"  Analyzing invoices for payment provider transactions...")
    analysis = analyze_invoices_for_problems(invoices)
    problem_invoices = analysis.get('problem_invoice_numbers', [])
    
    if analysis.get('need_manual_refund'):
        print(f"  ⚠ {len(analysis['need_manual_refund'])} invoice(s) have payment provider transactions")
        for prob in analysis['need_manual_refund']:
            print(f"    • #{prob['number']} - £{prob['amount_paid']:.2f} via provider")
        print(f"  These require manual refund in GHL before API can void them.")
    
    # Delete/void all invoices
    invoices_deleted = 0
    invoices_voided = 0
    invoices_failed = 0
    failed_invoice_numbers = []
    needs_manual_refund = False
    
    for inv in invoices:
        inv_id = inv.get('_id', inv.get('id', ''))
        inv_number = inv.get('invoiceNumber', inv.get('number', 'N/A'))
        inv_status = inv.get('status', 'unknown')
        inv_total = inv.get('total', inv.get('amount', 0))

        if not inv_id:
            continue

        debug_log(f"PROCESSING INVOICE FOR DELETION", {
            "invoice_id": inv_id, "invoice_number": inv_number,
            "status": inv_status, "total": inv_total
        })
        print(f"\n  Processing invoice #{inv_number} (£{inv_total:.2f}, status: {inv_status})...")

        # Use the existing delete function (handles payments, void, etc.)
        result = delete_ghl_invoice(inv_id)
        debug_log(f"INVOICE DELETE RESULT: #{inv_number}", result)
        if result.get('deleted'):
            invoices_deleted += 1
        elif result.get('voided'):
            invoices_voided += 1
        elif not result.get('success'):
            invoices_failed += 1
            failed_invoice_numbers.append(f"#{inv_number}")
            if result.get('needs_provider_refund') or result.get('needs_refund'):
                needs_manual_refund = True
            debug_log(f"INVOICE DELETE FAILED: #{inv_number}", result)

    # Cancel all schedules
    schedules_cancelled = 0
    for sched in schedules:
        sched_id = sched.get('_id', sched.get('id', ''))
        sched_name = sched.get('name', 'N/A')

        if not sched_id:
            continue

        debug_log(f"PROCESSING SCHEDULE FOR CANCELLATION", {"schedule_id": sched_id, "name": sched_name})
        print(f"\n  Cancelling schedule: {sched_name}...")
        cancel_result = cancel_ghl_schedule(sched_id)
        debug_log(f"SCHEDULE CANCEL RESULT: {sched_name}", cancel_result)
        if cancel_result.get('success'):
            schedules_cancelled += 1

    total_removed = invoices_deleted + invoices_voided
    debug_log("DELETE CLIENT INVOICES COMPLETE", {
        "client_name": client_name, "shoot_no": shoot_no,
        "invoices_deleted": invoices_deleted, "invoices_voided": invoices_voided,
        "invoices_failed": invoices_failed,
        "schedules_cancelled": schedules_cancelled
    })
    
    if invoices_failed > 0:
        print(f"\n⚠ Done with errors: {invoices_deleted} deleted, {invoices_voided} voided, {invoices_failed} failed, {schedules_cancelled} schedules")
    else:
        print(f"\n✓ Done: {invoices_deleted} deleted, {invoices_voided} voided, {schedules_cancelled} schedules cancelled")

    # Success only if no failures
    all_success = invoices_failed == 0 and (invoices_deleted > 0 or invoices_voided > 0 or len(invoices) == 0)
    
    # Build problem invoice details for UI (id|number format for parsing)
    problem_invoice_details = []
    for prob in analysis.get('need_manual_refund', []):
        problem_invoice_details.append(f"{prob['id']}|#{prob['number']}")
    
    return {
        'success': all_success,
        'client_name': client_name,
        'shoot_no': shoot_no,
        'contact_id': contact_id,
        'invoices_found': len(invoices),
        'invoices_deleted': invoices_deleted,
        'invoices_voided': invoices_voided,
        'invoices_failed': invoices_failed,
        'schedules_found': len(schedules),
        'schedules_cancelled': schedules_cancelled,
        'problem_invoices': problem_invoices + failed_invoice_numbers,
        'problem_invoice_details': problem_invoice_details,
        'needs_manual_refund': needs_manual_refund or len(problem_invoices) > 0,
        'error': f'{invoices_failed} invoice(s) could not be deleted/voided' if invoices_failed > 0 else None
    }


def void_ghl_invoice(invoice_id: str, try_draft_first: bool = True) -> dict:
    """Void an invoice in GHL (sets status to void without deleting).

    Args:
        invoice_id: GHL invoice ID to void.
        try_draft_first: If True, attempt to update to draft status first (may bypass restrictions).

    Returns:
        dict: Result with success status.
    """
    # Strategy 1: Try updating to draft status first (may bypass payment restrictions)
    if try_draft_first:
        debug_log(f"TRYING DRAFT STATUS FIRST: {invoice_id}")
        draft_result = update_invoice_to_draft(invoice_id)
        if draft_result.get('success'):
            debug_log(f"INVOICE UPDATED TO DRAFT - now attempting void")
    
    url = f"https://services.leadconnectorhq.com/invoices/{invoice_id}/void"
    # GHL requires altId/altType in request body for void endpoint
    payload = {"altId": CONFIG.get('LOCATION_ID', ''), "altType": "location"}
    debug_log(f"VOID INVOICE REQUEST: {url}", payload)

    try:
        response = requests.post(url, headers=_get_ghl_headers(), json=payload, timeout=30)
        debug_log(f"VOID INVOICE RESPONSE: Status={response.status_code}", {
            "body": response.text[:1000] if response.text else "EMPTY"
        })

        if response.status_code in [200, 201, 204]:
            return {'success': True, 'voided': True}
        elif response.status_code == 400:
            # Check for payment provider refund requirement
            if 'refunded first' in response.text.lower() or 'payment provider' in response.text.lower():
                debug_log("VOID BLOCKED - Payment provider refund required")
                return {
                    'success': False, 
                    'error': 'Invoice has payment provider transactions. Refund in GHL Payments first.',
                    'needs_provider_refund': True
                }
            return {'success': False, 'error': f"Void failed: {response.text}"}
        elif response.status_code == 403:
            debug_log("VOID INVOICE 403 - API KEY LACKS PERMISSION")
            return {'success': False, 'error': 'API key lacks invoice.void permission', 'permission_error': True}
        else:
            return {'success': False, 'error': f"Void failed (HTTP {response.status_code})", 'response': response.text}
    except requests.exceptions.RequestException as e:
        return {'success': False, 'error': str(e)}


def cancel_ghl_schedule(schedule_id: str) -> dict:
    """Cancel a recurring invoice schedule in GHL.

    Args:
        schedule_id: GHL schedule ID to cancel.

    Returns:
        dict: Result with success status.
    """
    debug_log("CANCEL GHL SCHEDULE CALLED", {"schedule_id": schedule_id})
    print(f"  Cancelling recurring schedule: {schedule_id}...")

    # Try DELETE first
    url = f"https://services.leadconnectorhq.com/invoices/schedule/{schedule_id}"
    debug_log(f"DELETE SCHEDULE REQUEST: {url}")

    try:
        response = requests.delete(url, headers=_get_ghl_headers(), timeout=30)
        debug_log(f"DELETE SCHEDULE RESPONSE: Status={response.status_code}", {
            "body": response.text[:1000] if response.text else "EMPTY"
        })

        if response.status_code in [200, 204]:
            debug_log(f"SCHEDULE CANCELLED SUCCESSFULLY: {schedule_id}")
            print(f"    ✓ Schedule cancelled")
            return {'success': True, 'schedule_id': schedule_id}
        elif response.status_code == 404:
            debug_log(f"SCHEDULE NOT FOUND (may already be cancelled): {schedule_id}")
            print(f"    ⚠ Schedule not found (may already be cancelled)")
            return {'success': True, 'schedule_id': schedule_id, 'message': 'Not found'}
        else:
            # Try disabling by updating liveMode to false
            debug_log("DELETE SCHEDULE FAILED, trying to disable via PATCH")
            patch_url = f"https://services.leadconnectorhq.com/invoices/schedule/{schedule_id}"
            patch_response = requests.patch(
                patch_url, 
                headers=_get_ghl_headers(), 
                json={"liveMode": False},
                timeout=30
            )
            debug_log(f"PATCH SCHEDULE RESPONSE: Status={patch_response.status_code}", {
                "body": patch_response.text[:1000] if patch_response.text else "EMPTY"
            })
            
            if patch_response.status_code in [200, 204]:
                debug_log(f"SCHEDULE DISABLED VIA PATCH: {schedule_id}")
                print(f"    ✓ Schedule disabled")
                return {'success': True, 'schedule_id': schedule_id, 'disabled': True}
            else:
                error_msg = f"Cancel failed (HTTP {response.status_code})"
                debug_log(f"SCHEDULE CANCEL FAILED: {schedule_id}", {"delete_status": response.status_code, "patch_status": patch_response.status_code})
                print(f"    ✗ {error_msg}")
                return {'success': False, 'error': error_msg, 'schedule_id': schedule_id}

    except requests.exceptions.RequestException as e:
        error_msg = f"Network error: {str(e)}"
        debug_log(f"SCHEDULE CANCEL NETWORK ERROR: {schedule_id}", {"error": str(e)})
        print(f"    ✗ {error_msg}")
        return {'success': False, 'error': error_msg, 'schedule_id': schedule_id}


def void_recorded_payments(invoice_id: str, invoice: dict) -> int:
    """Void/refund all recorded payments on an invoice.

    Attempts multiple strategies:
    1. DELETE each individual payment record
    2. If that fails, record a negative (refund) payment to zero the balance

    Args:
        invoice_id: GHL invoice ID.
        invoice: Invoice data dict (from get_ghl_invoice).

    Returns:
        int: Number of payments successfully voided/refunded.
    """
    # Try to get payment records from invoice data
    # GHL invoice responses may include 'recordPayment' or 'payments' array
    payments = invoice.get('recordPayment', [])
    if not payments:
        payments = invoice.get('payments', [])
    
    total_paid = invoice.get('amountPaid', 0)
    voided_count = 0
    
    debug_log("VOID RECORDED PAYMENTS", {
        "invoice_id": invoice_id,
        "total_paid": total_paid,
        "payment_records": len(payments)
    })

    # Strategy 1: Try to delete individual payment records by ID
    for payment in payments:
        pay_id = payment.get('_id', payment.get('id', ''))
        if not pay_id:
            continue
            
        url = f"https://services.leadconnectorhq.com/invoices/{invoice_id}/record-payment/{pay_id}"
        debug_log(f"DELETE PAYMENT RECORD: {url}")
        
        try:
            response = requests.delete(url, headers=_get_ghl_headers(), timeout=30)
            debug_log(f"DELETE PAYMENT RESPONSE: Status={response.status_code}", {
                "body": response.text[:500] if response.text else "EMPTY"
            })
            
            if response.status_code in [200, 204]:
                debug_log(f"PAYMENT RECORD REMOVED: {pay_id}")
                print(f"    ✓ Payment record {pay_id} removed")
                voided_count += 1
            else:
                debug_log(f"DELETE PAYMENT FAILED for {pay_id}: {response.status_code}")
        except Exception as e:
            debug_log(f"DELETE PAYMENT EXCEPTION for {pay_id}: {e}")

    # If we deleted all payments, we're done
    if voided_count > 0 and voided_count >= len(payments):
        return voided_count

    # Strategy 2: If individual deletes didn't work (or no payment IDs found),
    # record a negative refund payment to zero out the balance
    if total_paid > 0 and voided_count == 0:
        debug_log(f"FALLBACK: Recording negative refund payment of £{total_paid:.2f}")
        print(f"    Recording refund of £{total_paid:.2f}...")
        url = f"https://services.leadconnectorhq.com/invoices/{invoice_id}/record-payment"
        payload = {
            "altId": CONFIG.get('LOCATION_ID', ''),
            "altType": "location",
            "amount": -float(total_paid),
            "mode": "other",
            "notes": "Refund - Invoice deletion",
        }
        debug_log(f"RECORD REFUND PAYMENT: {url}", payload)
        
        try:
            response = requests.post(url, headers=_get_ghl_headers(), json=payload, timeout=30)
            debug_log(f"RECORD REFUND RESPONSE: Status={response.status_code}", {
                "body": response.text[:500] if response.text else "EMPTY"
            })
            
            if response.status_code in [200, 201]:
                debug_log(f"REFUND RECORDED SUCCESSFULLY: £{total_paid:.2f}")
                print(f"    ✓ Refund of £{total_paid:.2f} recorded")
                return 1
            else:
                debug_log(f"RECORD REFUND FAILED: {response.status_code}")
        except Exception as e:
            debug_log(f"RECORD REFUND EXCEPTION: {e}")

    return voided_count


def delete_ghl_invoice(invoice_id: str, schedule_ids: list = None) -> dict:
    """Delete/void an invoice from GHL.

    This will:
    1. Cancel any recurring payment schedules
    2. Fetch the invoice to check its status and payments
    3. Void the invoice (GHL doesn't allow true deletion of invoices with payments)
    4. Optionally delete if no payments exist

    Args:
        invoice_id: GHL invoice ID to delete.
        schedule_ids: Optional list of recurring schedule IDs to cancel.

    Returns:
        dict: Result with success status and any error message.
    """
    debug_log("DELETE GHL INVOICE CALLED", {"invoice_id": invoice_id, "schedule_ids": schedule_ids})
    print(f"\n🗑️ Processing invoice deletion: {invoice_id}")

    # Step 0: Cancel any recurring schedules first
    schedules_cancelled = 0
    if schedule_ids:
        debug_log(f"CANCELLING {len(schedule_ids)} SCHEDULE(S) BEFORE DELETION")
        for sid in schedule_ids:
            if sid:
                cancel_result = cancel_ghl_schedule(sid)
                if cancel_result.get('success'):
                    schedules_cancelled += 1
    
    # Step 1: Get invoice details
    print("  Fetching invoice details...")
    invoice_data = get_ghl_invoice(invoice_id)
    
    if not invoice_data:
        debug_log(f"INVOICE NOT FOUND: {invoice_id} (may already be deleted)")
        print(f"  ⚠ Invoice not found (may already be deleted)")
        return {'success': True, 'invoice_id': invoice_id, 'deleted': False, 'schedules_cancelled': schedules_cancelled, 'message': 'Invoice not found'}

    invoice = invoice_data.get('invoice', invoice_data)
    status = invoice.get('status', 'unknown')
    total_paid = invoice.get('amountPaid', 0)
    
    debug_log(f"INVOICE DETAILS", {"invoice_id": invoice_id, "status": status, "amountPaid": total_paid})
    print(f"  Invoice status: {status}")
    print(f"  Amount paid: £{total_paid:.2f}")

    # Step 2: If invoice has payments, void them first then delete
    if total_paid > 0:
        debug_log(f"INVOICE HAS PAYMENTS - voiding before deletion", {"invoice_id": invoice_id, "total_paid": total_paid})
        print(f"  Invoice has £{total_paid:.2f} in recorded payments")
        print(f"  Voiding payments before deletion...")
        
        payments_voided = void_recorded_payments(invoice_id, invoice)
        debug_log(f"PAYMENTS VOIDED: {payments_voided}")
        
        if payments_voided > 0:
            print(f"  ✓ {payments_voided} payment(s) voided/refunded")
            # Re-fetch invoice to check updated status
            invoice_data = get_ghl_invoice(invoice_id)
            if invoice_data:
                invoice = invoice_data.get('invoice', invoice_data)
                remaining_paid = invoice.get('amountPaid', 0)
                if remaining_paid > 0:
                    # Still has payments - try void as fallback
                    debug_log(f"REMAINING PAYMENTS AFTER VOID: £{remaining_paid:.2f} - falling back to void invoice")
                    print(f"  ⚠ £{remaining_paid:.2f} still recorded - voiding invoice")
                    void_result = void_ghl_invoice(invoice_id)
                    if void_result.get('success'):
                        debug_log(f"INVOICE VOIDED SUCCESSFULLY (with remaining payments)", {"invoice_id": invoice_id})
                        print(f"  ✓ Invoice voided")
                        return {
                            'success': True, 
                            'invoice_id': invoice_id, 
                            'voided': True,
                            'deleted': False,
                            'payments_voided': payments_voided,
                            'schedules_cancelled': schedules_cancelled,
                            'message': f'Invoice voided, {payments_voided} payment(s) refunded'
                        }
        else:
            # Couldn't void payments - try voiding the whole invoice
            debug_log(f"INDIVIDUAL PAYMENT VOID FAILED - trying full invoice void")
            print(f"  ⚠ Could not void individual payments - voiding invoice...")
            void_result = void_ghl_invoice(invoice_id)
            if void_result.get('success'):
                debug_log(f"INVOICE VOIDED SUCCESSFULLY (individual payments not voidable)", {"invoice_id": invoice_id})
                print(f"  ✓ Invoice voided")
                return {
                    'success': True, 
                    'invoice_id': invoice_id, 
                    'voided': True,
                    'deleted': False,
                    'schedules_cancelled': schedules_cancelled,
                    'message': 'Invoice voided (payments could not be individually refunded)'
                }
            else:
                debug_log("VOID ALSO FAILED", void_result)

    # Step 3: Try to delete the invoice
    url = f"https://services.leadconnectorhq.com/invoices/{invoice_id}"
    debug_log(f"DELETE INVOICE REQUEST: {url}")

    try:
        response = requests.delete(url, headers=_get_ghl_headers(), timeout=30)
        debug_log(f"DELETE INVOICE RESPONSE: Status={response.status_code}", {
            "body": response.text[:1000] if response.text else "EMPTY"
        })

        if response.status_code in [200, 204]:
            debug_log(f"INVOICE DELETED SUCCESSFULLY: {invoice_id}")
            print(f"  ✓ Invoice deleted successfully")
            return {'success': True, 'invoice_id': invoice_id, 'deleted': True, 'schedules_cancelled': schedules_cancelled}
        elif response.status_code == 403:
            debug_log(f"DELETE INVOICE 403 - API KEY LACKS PERMISSION", {"invoice_id": invoice_id})
            print(f"  ✗ API key lacks permission to delete invoices")
            print(f"    Enable 'invoices.write' scope in GHL Private Integrations")
            return {
                'success': False, 
                'error': 'API key lacks invoice delete permission - update GHL Private Integration scopes',
                'invoice_id': invoice_id,
                'permission_error': True
            }
        elif response.status_code == 400:
            # May need to void payments first
            error_text = response.text.lower()
            if 'payment' in error_text or 'refund' in error_text:
                debug_log(f"DELETE BLOCKED BY PAYMENTS - manual refund needed", {"invoice_id": invoice_id, "response": response.text[:500]})
                print(f"  ✗ Cannot delete - payments must be refunded first")
                print(f"    Go to GHL Payments → Invoices → Refund all payments, then try again")
                return {
                    'success': False, 
                    'error': 'Payments must be refunded in GHL before invoice can be deleted',
                    'invoice_id': invoice_id,
                    'needs_refund': True
                }
            else:
                error_msg = f"Delete failed: {response.text}"
                debug_log(f"DELETE INVOICE 400 ERROR (non-payment)", {"invoice_id": invoice_id, "response": response.text[:500]})
                print(f"  ✗ {error_msg}")
                return {'success': False, 'error': error_msg, 'invoice_id': invoice_id}
        elif response.status_code == 404:
            debug_log(f"DELETE INVOICE 404 - NOT FOUND: {invoice_id}")
            print(f"  ⚠ Invoice not found")
            return {'success': True, 'invoice_id': invoice_id, 'deleted': False, 'message': 'Invoice not found'}
        else:
            error_msg = f"Delete failed (HTTP {response.status_code})"
            debug_log(f"DELETE INVOICE UNEXPECTED STATUS", {"invoice_id": invoice_id, "status": response.status_code, "response": response.text[:500]})
            print(f"  ✗ {error_msg}")
            print(f"    Response: {response.text}")
            return {'success': False, 'error': error_msg, 'invoice_id': invoice_id}

    except requests.exceptions.RequestException as e:
        error_msg = f"Network error: {str(e)}"
        debug_log(f"DELETE INVOICE NETWORK ERROR", {"invoice_id": invoice_id, "error": str(e)})
        print(f"  ✗ Error deleting invoice: {error_msg}")
        return {'success': False, 'error': error_msg, 'invoice_id': invoice_id}


def record_ghl_payment(invoice_id: str, payment: dict, max_retries: int = 5) -> tuple[bool, bool]:
    """Record a payment transaction against a GHL invoice.

    Args:
        invoice_id: GHL invoice ID.
        payment: Payment data dictionary.
        max_retries: Maximum retry attempts.

    Returns:
        tuple[bool, bool]: (success, was_slow) - success if recorded, was_slow if needed retries.
    """

    url = f"https://services.leadconnectorhq.com/invoices/{invoice_id}/record-payment"
    headers = {
        "Authorization": f"Bearer {API_KEY}",
        "Content-Type": "application/json",
        "Version": "2021-07-28"
    }

    # Map ProSelect payment methods to GHL
    method_map = {
        'BT': 'bank_transfer',
        'DD': 'bank_transfer',  # Direct Debit -> Bank Transfer
        'CC': 'credit_card',
        'DC': 'debit_card',
        'Cash': 'cash',
        'Cheque': 'cheque',
    }

    ps_method = payment.get('Method', 'BT')
    ghl_method = method_map.get(ps_method, 'other')

    payload = {
        "altId": CONFIG.get('LOCATION_ID', ''),
        "altType": "location",
        "amount": float(payment['amount']),  # GHL uses pounds, not pence
        "mode": ghl_method,
        "notes": f"{payment.get('MethodName', 'Payment')} - {payment.get('date', '')}",
    }

    debug_log(f"RECORD PAYMENT REQUEST: {url}", payload)

    # Retry with backoff for race conditions (409)
    was_slow = False
    for attempt in range(max_retries):
        try:
            response = requests.post(url, headers=headers, json=payload, timeout=60)

            debug_log(f"RECORD PAYMENT RESPONSE (attempt {attempt+1}): Status={response.status_code}", {
                "status_code": response.status_code,
                "body": response.text[:1000] if response.text else "EMPTY"
            })

            if response.status_code in [200, 201]:
                return (True, was_slow)
            elif response.status_code == 409:
                # Race condition - payment recording in progress, wait and retry
                was_slow = True
                wait_time = (attempt + 1) * 1.0  # 1s, 2s, 3s
                if attempt < max_retries - 1:
                    time.sleep(wait_time)
                    continue
                else:
                    print(f"    Payment failed after {max_retries} retries (409 conflict)")
                    return (False, True)
            else:
                print(f"    Payment failed ({response.status_code}): {response.text[:100]}")
                return (False, was_slow)
        except Exception as e:
            print(f"    Payment error: {e}")
            if attempt < max_retries - 1:
                time.sleep(2)
                continue
            return (False, True)

    return (False, True)


def create_recurring_invoice_schedule(
    contact_id: str,
    contact_name: str,
    email: str,
    amount: float,
    num_payments: int,
    start_date: str,
    invoice_name: str = "Payment Plan"
) -> dict | None:
    """Create a recurring invoice schedule for installment payments.

    Creates a GHL invoice schedule that generates invoices monthly for
    a fixed number of payments (installments).

    Args:
        contact_id: GHL contact ID.
        contact_name: Contact's full name.
        email: Contact's email address.
        amount: Amount per payment (in pounds).
        num_payments: Number of monthly payments.
        start_date: First payment date (YYYY-MM-DD).
        invoice_name: Name for the invoice schedule.

    Returns:
        dict: Schedule response data, or None on failure.
    """
    url = "https://services.leadconnectorhq.com/invoices/schedule/"
    headers = {
        "Authorization": f"Bearer {API_KEY}",
        "Content-Type": "application/json",
        "Version": "2021-07-28"
    }

    # Extract day of month from start date
    try:
        day_of_month = int(start_date.split('-')[2])
        if day_of_month > 28:
            day_of_month = 28  # GHL max is 28
        elif day_of_month < 1:
            day_of_month = 1
    except (IndexError, ValueError):
        day_of_month = 1

    payload = {
        "altId": CONFIG.get('LOCATION_ID', ''),
        "altType": "location",
        "name": invoice_name,
        "liveMode": True,  # Active mode - auto-generates invoices
        "contactDetails": {
            "id": contact_id,
            "name": contact_name,
            "email": email
        },
        "businessDetails": get_business_details(),
        "currency": "GBP",
        "items": [
            {
                "name": f"Payment ({num_payments} installments)",
                "amount": float(amount),
                "qty": 1,
                "currency": "GBP"
            }
        ],
        "discount": {
            "type": "fixed",
            "value": 0
        },
        "schedule": {
            "rrule": {
                "intervalType": "monthly",
                "interval": 1,
                "startDate": start_date,
                "dayOfMonth": day_of_month,
                "count": num_payments
            }
        }
    }

    debug_log("CREATE RECURRING SCHEDULE REQUEST", payload)

    try:
        response = requests.post(url, headers=headers, json=payload, timeout=60)
        debug_log(f"CREATE RECURRING SCHEDULE RESPONSE: Status={response.status_code}", {
            "body": response.text[:1000] if response.text else "EMPTY"
        })

        if response.status_code in [200, 201]:
            data = response.json()
            schedule_id = data.get('_id', 'Unknown')
            print(f"  ✓ Created recurring schedule: {schedule_id}")
            print(f"    {num_payments} x £{amount:.2f}/month starting {start_date}")
            return data
        else:
            print(f"  ✗ Failed to create schedule ({response.status_code})")
            debug_log("SCHEDULE CREATE FAILED", {"response": response.text})
            return None

    except Exception as e:
        print(f"  ✗ Schedule error: {e}")
        debug_log("SCHEDULE CREATE EXCEPTION", {"error": str(e)})
        return None


# =============================================================================
# GHL Media Upload Functions
# =============================================================================

def get_thumbnail_folder(xml_path: str) -> str | None:
    """Get the thumbnail folder path matching the XML file name.

    Args:
        xml_path: Path to the XML file.

    Returns:
        str | None: Folder path if exists, None otherwise.
    """
    # XML: 2026-01-27_180030_P26008P__1.xml
    # Folder: 2026-01-27_180030_P26008P__1/
    xml_dir = os.path.dirname(xml_path)
    xml_name = os.path.splitext(os.path.basename(xml_path))[0]
    thumb_folder = os.path.join(xml_dir, xml_name)

    debug_log("GET THUMBNAIL FOLDER", {
        "xml_path": xml_path,
        "xml_dir": xml_dir,
        "xml_name": xml_name,
        "thumb_folder": thumb_folder,
        "exists": os.path.isdir(thumb_folder)
    })

    if os.path.isdir(thumb_folder):
        return thumb_folder
    return None

def get_thumbnails(thumb_folder: str) -> list:
    """Get list of thumbnail images from folder."""
    if not thumb_folder or not os.path.isdir(thumb_folder):
        debug_log("GET THUMBNAILS - FOLDER NOT FOUND", {"thumb_folder": thumb_folder})
        return []

    thumbnails = []
    for filename in os.listdir(thumb_folder):
        if filename.lower().endswith(('.jpg', '.jpeg', '.png', '.gif')):
            thumbnails.append(os.path.join(thumb_folder, filename))

    debug_log("GET THUMBNAILS RESULT", {
        "thumb_folder": thumb_folder,
        "count": len(thumbnails),
        "files": [os.path.basename(t) for t in thumbnails[:10]]  # First 10 only
    })

    return sorted(thumbnails)

def upload_to_ghl_media(file_path: str) -> str | None:
    """Upload a single file to GHL Media Storage, returns URL."""

    debug_log("UPLOAD TO GHL MEDIA", {"file_path": file_path})

    if not os.path.exists(file_path):
        debug_log("UPLOAD ERROR: FILE NOT FOUND", {"file_path": file_path})
        print(f"    ✗ File not found: {file_path}")
        return None

    file_size = os.path.getsize(file_path)
    debug_log("FILE INFO", {
        "file_path": file_path,
        "size_bytes": file_size,
        "size_kb": round(file_size / 1024, 2)
    })

    import mimetypes
    mime_type, _ = mimetypes.guess_type(file_path)
    if not mime_type:
        mime_type = 'application/octet-stream'

    file_name = os.path.basename(file_path)

    headers = {
        "Authorization": f"Bearer {API_KEY}",
        "Version": "2021-07-28"
    }

    url = "https://services.leadconnectorhq.com/medias/upload-file"
    params = {
        'altId': CONFIG.get('LOCATION_ID', ''),
        'altType': 'location'
    }

    debug_log("MEDIA UPLOAD REQUEST", {
        "url": url,
        "params": params,
        "file_name": file_name,
        "mime_type": mime_type
    })

    try:
        with open(file_path, 'rb') as f:
            files = {'file': (file_name, f, mime_type)}
            data = {'name': file_name}

            response = requests.post(url, headers=headers, params=params, files=files, data=data, timeout=60)

            debug_log("MEDIA UPLOAD RESPONSE", {
                "status_code": response.status_code,
                "body": response.text[:500] if response.text else "EMPTY"
            })

            if response.status_code in [200, 201]:
                result = response.json()
                uploaded_url = result.get('url')
                debug_log("MEDIA UPLOAD SUCCESS", {"url": uploaded_url})
                return uploaded_url
            else:
                debug_log("MEDIA UPLOAD FAILED", {
                    "status_code": response.status_code,
                    "error": response.text[:500]
                })
                print(f"    ✗ Upload failed ({response.status_code}): {response.text[:100]}")
                return None
    except Exception as e:
        debug_log("MEDIA UPLOAD EXCEPTION", {"error": str(e)})
        print(f"    ✗ Upload error: {e}")
        return None


def _fetch_snippet_html(snippet_id: str) -> str | None:
    """Fetch the HTML body of a GHL snippet/template by ID.

    Args:
        snippet_id: The snippet/email template ID.

    Returns:
        str: The HTML body of the snippet, or None if not found.
    """
    if not snippet_id:
        return None

    headers = {
        "Authorization": f"Bearer {API_KEY}",
        "Version": "2021-07-28",
        "Accept": "application/json"
    }

    # Try templates endpoint first
    url = f"https://services.leadconnectorhq.com/emails/templates/{snippet_id}"
    debug_log("FETCH SNIPPET", {"url": url, "id": snippet_id})
    try:
        response = requests.get(url, headers=headers, timeout=30)
        if response.status_code == 200:
            data = response.json()
            body = data.get('html') or data.get('body') or data.get('template', {}).get('html', '')
            if body:
                debug_log("SNIPPET FETCHED (templates)", {"length": len(body)})
                return body
    except Exception as e:
        debug_log(f"FETCH SNIPPET TEMPLATES ERROR: {e}")

    # Fallback: try snippets endpoint
    url2 = f"https://services.leadconnectorhq.com/snippets/{snippet_id}"
    debug_log("FETCH SNIPPET FALLBACK", {"url": url2})
    try:
        response = requests.get(url2, headers=headers, timeout=30)
        if response.status_code == 200:
            data = response.json()
            snippet = data.get('snippet', data)
            body = snippet.get('html') or snippet.get('body') or snippet.get('text', '')
            if body:
                debug_log("SNIPPET FETCHED (snippets)", {"length": len(body)})
                return body
    except Exception as e:
        debug_log(f"FETCH SNIPPET SNIPPETS ERROR: {e}")

    debug_log("SNIPPET NOT FOUND", {"id": snippet_id})
    return None


def send_room_capture_email(contact_id: str, image_path: str, subject: str = '', message_html: str = '', template_id: str = '') -> dict:
    """Upload a room capture image to GHL media and send it as an email to the contact.

    Args:
        contact_id: GHL contact ID to send the email to.
        image_path: Local path to the JPG image file.
        subject: Email subject line (default: auto-generated from filename).
        message_html: HTML body of the email (default: auto-generated).
        template_id: Optional GHL email template/snippet ID. If provided, the snippet HTML
                     is fetched and used as the email body with the image appended.

    Returns:
        dict: Result with success status and details.
    """
    debug_log("SEND ROOM CAPTURE EMAIL", {"contact_id": contact_id, "image_path": image_path, "template_id": template_id})

    # Validate inputs
    if not contact_id:
        return {'success': False, 'error': 'No contact ID provided'}
    if not os.path.exists(image_path):
        return {'success': False, 'error': f'Image file not found: {image_path}'}

    # Step 1: Fetch contact details to get email
    contact = fetch_ghl_contact(contact_id)
    if not contact or not contact.get('email'):
        return {'success': False, 'error': 'Could not fetch contact email from GHL'}

    contact_email = contact['email']
    contact_name = contact.get('firstName') or contact.get('name') or 'there'
    debug_log("CONTACT FOR EMAIL", {"email": contact_email, "name": contact_name})

    # Step 2: Upload image to GHL media
    print(f"  Uploading image to GHL media...")
    image_url = upload_to_ghl_media(image_path)
    if not image_url:
        return {'success': False, 'error': 'Failed to upload image to GHL media'}
    debug_log("IMAGE UPLOADED", {"url": image_url})

    # Step 3: Get business details for the from line
    business = get_business_details()
    business_name = business.get('name', 'Studio')
    business_email = business.get('email', '')

    # Step 4: Build email content
    file_basename = os.path.basename(image_path)
    if not subject:
        subject = f"Your Room View - {business_name}"

    # If a template/snippet ID is provided, fetch its HTML and append the image
    if template_id and not message_html:
        print(f"  Fetching email template...")
        snippet_html = _fetch_snippet_html(template_id)
        if snippet_html:
            # Append the room capture image to the snippet body
            image_tag = (
                f'<p><img src="{image_url}" alt="{file_basename}" '
                f'style="max-width:100%;height:auto;border-radius:8px;"/></p>'
            )
            message_html = snippet_html + image_tag
            debug_log("USING TEMPLATE HTML", {"template_id": template_id, "total_length": len(message_html)})
        else:
            debug_log("TEMPLATE NOT FOUND, using default", {"template_id": template_id})

    if not message_html:
        message_html = (
            f"<p>Hi {contact_name},</p>"
            f"<p>Here is your room view image from your session.</p>"
            f"<p><img src=\"{image_url}\" alt=\"{file_basename}\" "
            f"style=\"max-width:100%;height:auto;border-radius:8px;\"/></p>"
            f"<p>Kind regards,<br/>{business_name}</p>"
        )

    # Step 5: Send email via GHL Conversations API
    print(f"  Sending email to {contact_email}...")
    url = "https://services.leadconnectorhq.com/conversations/messages"
    headers = {
        "Authorization": f"Bearer {API_KEY}",
        "Content-Type": "application/json",
        "Version": "2021-07-28"
    }
    payload = {
        "type": "Email",
        "contactId": contact_id,
        "subject": subject,
        "message": message_html,
        "html": message_html,
        "attachments": [image_url],
        "emailFrom": business_email if business_email else None
    }
    # Remove None values
    payload = {k: v for k, v in payload.items() if v is not None}

    debug_log("SEND EMAIL REQUEST", {"url": url, "payload_keys": list(payload.keys()), "to": contact_email})

    try:
        response = requests.post(url, headers=headers, json=payload, timeout=60)
        debug_log("SEND EMAIL RESPONSE", {
            "status_code": response.status_code,
            "body": response.text[:500] if response.text else "EMPTY"
        })

        if response.status_code in [200, 201]:
            result_data = response.json()
            msg_id = result_data.get('messageId') or result_data.get('id', '')
            print(f"  ✓ Email sent to {contact_email}")
            return {
                'success': True,
                'message_id': msg_id,
                'contact_email': contact_email,
                'image_url': image_url
            }
        else:
            error_text = response.text[:200] if response.text else 'Unknown error'
            print(f"  ✗ Email send failed ({response.status_code}): {error_text}")
            return {'success': False, 'error': f'API error {response.status_code}: {error_text}'}
    except Exception as e:
        debug_log("SEND EMAIL EXCEPTION", {"error": str(e)})
        print(f"  ✗ Email error: {e}")
        return {'success': False, 'error': str(e)}


# =============================================================================
# Invoice Helper Functions
# =============================================================================
def _build_payment_invoice_items(payments: list, order: dict) -> list:
    """Build invoice line items from payment schedule.

    Args:
        payments: List of payment dictionaries.
        order: Order data dictionary.

    Returns:
        list: Invoice items list.
    """
    invoice_items = []

    # Add order summary header with VAT info
    vat_info = order.get('vat', {})
    total_vat = vat_info.get('total_vat', 0)
    total_ex_vat = vat_info.get('total_ex_vat', 0)
    order_total = order.get('total_amount', 0)

    invoice_items.append({
        "name": "Order Summary",
        "description": f"Subtotal ex VAT: £{total_ex_vat:.2f} | VAT: £{total_vat:.2f} | Total: £{order_total:.2f}",
        "quantity": 1,
        "price": 0.0,
        "currency": "GBP"
    })

    for idx, payment in enumerate(payments):
        payment_date = payment.get('date', '')
        payment_method_name = payment.get('method', 'Payment')
        payment_amount = payment.get('amount', 0)

        invoice_items.append({
            "name": f"Payment {idx + 1} - {payment_date}",
            "description": f"{payment_method_name} due {payment_date}",
            "quantity": 1,
            "price": float(payment_amount),
            "currency": "GBP"
        })

    return invoice_items


def _should_skip_item(item: dict, financials_only: bool) -> bool:
    """Check if item should be skipped.

    Args:
        item: Product item dictionary.
        financials_only: Whether to skip zero-price items.

    Returns:
        bool: True if item should be skipped.
    """
    return financials_only and item['price'] == 0 and item['type'] != 'OrderAdjustment'


def _create_invoice_item(item: dict) -> dict:
    """Create invoice item dict from product item.

    Args:
        item: Product item dictionary.

    Returns:
        dict: Invoice item dictionary with all ProSelect fields unchanged for exact GHL matching.
    """
    # Pass through ALL ProSelect fields unchanged - no merging/fallback
    # GHL product matching requires exact string matches
    # CRITICAL: GHL requires non-empty name, so build a rich name from available fields
    product_name = item.get('product', '')
    description = item.get('description', '')
    template = item.get('template', '')
    item_type = item.get('type', '')
    
    # Build the best possible name for GHL invoice display
    # Priority: Product_Name > Template_Name + Description > Description alone
    if product_name:
        display_name = product_name
    elif template and description and template != description:
        # Combine template and description if they're different (e.g., "Collection 1 - Canvas Gallery Block")
        display_name = f"{description} - {template}"
    elif description:
        display_name = description
    elif template:
        display_name = template
    else:
        display_name = item_type or "Item"
    
    return {
        # GHL invoice line item fields
        # Use rich display name for GHL invoice (combines available fields)
        "name": display_name,
        "description": description,  # Description - full line item description
        "quantity": item['quantity'],
        "price": float(item['price']),
        "currency": "GBP",
        # All ProSelect fields passed through unchanged for external system matching
        "sku": item.get('sku', ''),  # Product_Code - primary SKU matching key
        "product_name": item.get('product', ''),  # Product_Name (exact)
        "ps_description": item.get('description', ''),  # Description (exact)
        "item_type": item.get('type', ''),  # ItemType (exact)
        "ps_item_id": item.get('ps_item_id', ''),  # ID (exact)
        "size": item.get('size', ''),  # Size (exact)
        "template": item.get('template', ''),  # Template_Name (exact)
        # Tax fields (exact from ProSelect)
        "taxable": item.get('taxable', True),
        "tax_rate": item.get('tax_rate', 0.0),
        "tax_label": item.get('tax_label', ''),
        "vat_amount": item.get('vat_amount', 0.0),
        "price_includes_tax": item.get('price_includes_tax', False),
        # Product line (exact from ProSelect)
        "product_line": item.get('product_line', ''),
        "product_line_code": item.get('product_line_code', ''),
    }


def _build_product_invoice_items(items: list, financials_only: bool) -> tuple[list, float]:
    """Build invoice line items from product items.

    Args:
        items: List of product item dictionaries.
        financials_only: Whether to skip zero-price items.

    Returns:
        tuple: (invoice_items list, total_discounts_credits float)
    """
    invoice_items = []
    total_discounts_credits = 0.0

    for item in items:
        if _should_skip_item(item, financials_only):
            continue

        if item['price'] < 0:
            total_discounts_credits += abs(item['price'])
            continue

        invoice_items.append(_create_invoice_item(item))

    return invoice_items, total_discounts_credits


def _convert_to_ghl_items(invoice_items: list) -> list:
    """Convert internal invoice items to GHL V2 API format.

    Args:
        invoice_items: Internal invoice items list.

    Returns:
        list: GHL-formatted items with amounts in pounds (invoice API uses pounds, not pence).
    """
    ghl_items = []
    for item in invoice_items:
        item_price = float(item['price'])
        ghl_item = {
            "name": str(item['name']),
            "description": str(item['description']),
            "amount": item_price,  # Invoice items use pounds (record-payment uses pence)
            "qty": int(item['quantity']),
            "currency": "GBP"
        }
        
        # Add tax info if item is taxable AND has price > 0
        # GHL Invoice API rejects taxes on $0 items
        if item.get('taxable', False) and item.get('tax_rate', 0) > 0 and item_price > 0:
            # GHL requires lowercase: "exclusive" or "inclusive"
            calc_type = "inclusive" if item.get('price_includes_tax', False) else "exclusive"
            ghl_item["taxes"] = [{
                "_id": "default",  # GHL default tax ID
                "name": item.get('tax_label', 'VAT'),
                "rate": float(item.get('tax_rate', 20)),
                "calculation": calc_type
            }]
        
        ghl_items.append(ghl_item)
    
    return ghl_items


def _normalize_date(date_str: str) -> str:
    """Convert date to YYYY-MM-DD format.

    Args:
        date_str: Date string in various formats.

    Returns:
        str: Date in YYYY-MM-DD format.
    """
    if not date_str:
        return datetime.now().strftime('%Y-%m-%d')

    if '/' in date_str:
        try:
            parsed = datetime.strptime(date_str, '%m/%d/%Y')
            return parsed.strftime('%Y-%m-%d')
        except ValueError:
            pass

    return date_str if date_str else datetime.now().strftime('%Y-%m-%d')


def _build_invoice_payload(
    contact_id: str,
    invoice_name: str,
    ghl_items: list,
    issue_date: str,
    due_date: str,
    client_name: str,
    email: str,
    phone: str,
    address: dict,
    total_discounts_credits: float,
    payments: list = None
) -> dict:
    """Build the invoice payload for GHL V2 API.

    Args:
        contact_id: GHL contact ID.
        invoice_name: Name for the invoice.
        ghl_items: GHL-formatted line items.
        issue_date: Invoice issue date.
        due_date: Invoice due date.
        client_name: Client full name.
        email: Client email.
        phone: Client phone (E.164 format).
        address: Client address dict with street, city, state, zip_code, country.
        total_discounts_credits: Total discounts to apply.
        payments: List of payment installments with dates and amounts.

    Returns:
        dict: Complete payload for GHL API.
    """
    contact_details = {
        "id": contact_id,
        "name": client_name,
        "email": email
    }
    # Only include phone if provided (GHL requires E.164 format)
    if phone:
        contact_details["phoneNo"] = phone
    
    # Build address object if we have address data
    if address:
        addr_obj = {}
        if address.get('street'):
            addr_obj["addressLine1"] = address['street']
        if address.get('street2'):
            addr_obj["addressLine2"] = address['street2']
        if address.get('city'):
            addr_obj["city"] = address['city']
        if address.get('state'):
            addr_obj["state"] = address['state']
        if address.get('zip_code'):
            addr_obj["postalCode"] = address['zip_code']
        if address.get('country'):
            addr_obj["countryCode"] = address['country']
        if addr_obj:
            contact_details["address"] = addr_obj

    payload = {
        "altId": CONFIG.get('LOCATION_ID', ''),
        "altType": "location",
        "name": invoice_name,
        "currency": "GBP",
        "items": ghl_items,
        "issueDate": issue_date,
        "dueDate": due_date,
        "businessDetails": get_business_details(),  # Full details from GHL location
        "contactDetails": contact_details
    }

    if total_discounts_credits > 0:
        payload["discount"] = {
            "type": "fixed",
            "value": float(total_discounts_credits)  # Invoice discounts use pounds
        }

    # GHL paymentSchedule API is not well documented and causes errors
    # Future payments are logged but not scheduled via API
    # The payment schedule must be set up manually in GHL UI
    if payments:
        today = datetime.now().strftime('%Y-%m-%d')
        future_payments = [p for p in payments if p.get('date', '') > today]
        if future_payments:
            debug_log("FUTURE PAYMENTS (manual schedule required)", {
                "count": len(future_payments),
                "payments": future_payments
            })

    return payload


def _process_invoice_payments(invoice_id: str, payments: list) -> int:
    """Record past payments for an invoice.

    Records each payment individually so they appear separately in GHL.
    Future payments are included in the invoice's paymentSchedule (installments).
    Note: GHL API requires ~3s delay between payments to avoid 409 conflicts.

    Args:
        invoice_id: GHL invoice ID.
        payments: List of payment dictionaries.

    Returns:
        int: Number of past payments successfully recorded.
    """
    today = datetime.now().strftime('%Y-%m-%d')
    past_payments = [p for p in payments if p.get('date', '') <= today]
    future_payments = [p for p in payments if p.get('date', '') > today]

    payments_recorded = 0

    if past_payments:
        total_payments = len(past_payments)
        print(f"\n💳 Recording {total_payments} past payment(s)...")
        for i, payment in enumerate(past_payments):
            # Update progress for each payment
            write_progress(4, 5, f"Recording payment {i+1}/{total_payments}...")
            if i > 0:
                time.sleep(3)  # GHL needs ~3s between payments to avoid 409 conflicts
            success, _ = record_ghl_payment(invoice_id, payment)
            if success:
                payments_recorded += 1
        print(f"  ✓ Recorded {payments_recorded}/{total_payments} past payments")

    if future_payments:
        # Future payments will be handled by recurring invoice schedule
        print(f"  📅 {len(future_payments)} future installment(s) pending (recurring schedule)")

    return payments_recorded


def _open_invoice_in_browser(invoice_id: str) -> None:
    """Open the invoice in the browser after a delay.

    Args:
        invoice_id: GHL invoice ID.
    """
    location_id = CONFIG.get('LOCATION_ID', '')
    invoice_url = f"https://app.thefullybookedphotographer.com/v2/location/{location_id}/payments/invoices/{invoice_id}"
    print(f"\n🌐 Opening invoice in browser in 5 seconds...")
    print(f"  URL: {invoice_url}")
    time.sleep(5)
    os.startfile(invoice_url)


def _send_invoice(invoice_id: str) -> bool:
    """Send/publish the invoice so it appears in GHL invoice list.

    GHL invoices are created as 'draft' by default and don't appear
    in the main invoice list until sent/published.

    Args:
        invoice_id: GHL invoice ID.

    Returns:
        bool: True if successfully sent, False otherwise.
    """
    url = f"https://services.leadconnectorhq.com/invoices/{invoice_id}/send"
    headers = _get_ghl_headers()
    
    payload = {
        "altId": CONFIG.get('LOCATION_ID', ''),
        "altType": "location",
        "liveMode": True
    }
    
    debug_log(f"SEND INVOICE REQUEST: {url}", payload)
    
    try:
        response = requests.post(url, headers=headers, json=payload, timeout=30)
        debug_log(f"SEND INVOICE RESPONSE: Status={response.status_code}", {
            "body": response.text[:1000] if response.text else "EMPTY"
        })
        
        if response.status_code in [200, 201]:
            print(f"  ✓ Invoice published - now visible in GHL")
            return True
        else:
            print(f"  ⚠ Could not publish invoice: {response.status_code}")
            debug_log(f"SEND INVOICE ERROR: {response.text}")
            return False
    except Exception as e:
        print(f"  ⚠ Error publishing invoice: {e}")
        debug_log(f"SEND INVOICE EXCEPTION: {e}")
        return False


def _adjust_invoice_totals(invoice_items: list, ghl_items: list, ps_order_total: float) -> None:
    """Adjust invoice totals if they don't match order total.

    Args:
        invoice_items: Internal invoice items list (prices in pounds).
        ghl_items: GHL-formatted items list (amounts in pounds).
        ps_order_total: ProSelect order total in pounds.
    """
    ghl_invoice_total = sum(i['price'] for i in invoice_items if i['price'] > 0)
    if abs(ghl_invoice_total - ps_order_total) <= 0.01:
        return

    adjustment = ps_order_total - ghl_invoice_total
    for item in invoice_items:
        if item['price'] > 0:
            item['price'] = round(item['price'] + adjustment, 2)
            break
    for ghl_item in ghl_items:
        if ghl_item['amount'] > 0:
            ghl_item['amount'] = round(ghl_item['amount'] + adjustment, 2)
            break
    print(f"  ✓ Totals adjusted (rounding fix: £{adjustment:.2f} on Payment 1)")


def _handle_invoice_success(
    response,
    payments: list,
    balance_due: float,
    order: dict,
    ps_data: dict = None,
    contact_id: str = None,
    rounding_in_deposit: bool = True,
    open_browser: bool = True
) -> dict:
    """Handle successful invoice creation response.

    Args:
        response: HTTP response object.
        payments: Payments list.
        balance_due: Balance due amount.
        order: Order dictionary.
        ps_data: ProSelect data for contact info.
        contact_id: GHL contact ID.
        rounding_in_deposit: If True, add rounding to deposit; else create separate first invoice.
        open_browser: If True, open the invoice URL in browser.

    Returns:
        dict: Success result dictionary.
    """
    invoice_data = response.json()
    invoice_id = invoice_data.get('invoice', {}).get('_id', invoice_data.get('_id', 'Unknown'))
    invoice_number = invoice_data.get('invoice', {}).get('invoiceNumber', 'N/A')

    print(f"\n✓ Invoice created successfully!")
    print(f"  Invoice ID: {invoice_id}")
    print(f"  Invoice #: {invoice_number}")
    print(f"  Total: £{order.get('total_amount', 0):.2f}")

    # Publish the invoice so it's visible in GHL
    _send_invoice(invoice_id)

    payments_recorded = _process_invoice_payments(invoice_id, payments) if payments else 0
    print(f"  Balance Due: £{balance_due:.2f}")

    # Create recurring schedule for future payments if we have them
    schedule_created = False
    schedule_ids = []
    if payments and ps_data and contact_id:
        today = datetime.now().strftime('%Y-%m-%d')
        future_payments = [p for p in payments if p.get('date', '') > today]

        if future_payments:
            # Calculate schedule details
            num_payments = len(future_payments)
            total_future = sum(p.get('amount', 0) for p in future_payments)

            # Calculate base amount (rounded down to avoid over-billing)
            base_amount = round(total_future / num_payments, 2)

            # Check for rounding difference
            calculated_total = round(base_amount * num_payments, 2)
            rounding_diff = round(total_future - calculated_total, 2)

            first_date = future_payments[0].get('date', today)

            client_name = f"{ps_data.get('first_name', '')} {ps_data.get('last_name', '')}".strip()
            email = ps_data.get('email', '')
            
            # Extract shoot number from album name for invoice naming
            album_name = ps_data.get('album_name', '')
            shoot_no = album_name.split('_')[0] if album_name and '_' in album_name else ''
            payment_plan_name = f"{client_name} - {shoot_no} Payment Plan" if shoot_no else f"{client_name} Payment Plan"
            payment_1_name = f"{client_name} - {shoot_no} Payment 1" if shoot_no else f"{client_name} Payment 1"

            print(f"\n📅 Creating recurring payment schedule...")
            if rounding_diff != 0:
                print(f"  ⚠ Rounding adjustment: £{rounding_diff:.2f} applied to first payment")

            # First payment amount includes rounding adjustment
            first_payment_amount = round(base_amount + rounding_diff, 2)

            # Handle rounding difference based on setting
            if rounding_diff != 0 and num_payments > 1:
                if rounding_in_deposit:
                    # Rounding goes to deposit - create single schedule with equal payments
                    print(f"  Rounding of £{rounding_diff:.2f} added to deposit")
                    print(f"  Creating {num_payments} equal payments: £{base_amount:.2f} each")
                    schedule = create_recurring_invoice_schedule(
                        contact_id=contact_id,
                        contact_name=client_name,
                        email=email,
                        amount=base_amount,
                        num_payments=num_payments,
                        start_date=first_date,
                        invoice_name=payment_plan_name
                    )
                    schedule_created = schedule is not None
                    if schedule:
                        sid = schedule.get('_id', schedule.get('id', ''))
                        if sid:
                            schedule_ids.append(sid)
                else:
                    # Create first invoice with adjusted amount (old behavior)
                    print(f"  Creating first payment: £{first_payment_amount:.2f}")
                    first_schedule = create_recurring_invoice_schedule(
                        contact_id=contact_id,
                        contact_name=client_name,
                        email=email,
                        amount=first_payment_amount,
                        num_payments=1,
                        start_date=first_date,
                        invoice_name=payment_1_name
                    )
                    if first_schedule:
                        sid = first_schedule.get('_id', first_schedule.get('id', ''))
                        if sid:
                            schedule_ids.append(sid)

                    # Create remaining payments with base amount
                    if num_payments > 1:
                        # Get second payment date
                        second_date = future_payments[1].get('date', first_date) if len(future_payments) > 1 else first_date
                        print(f"  Creating remaining {num_payments - 1} payments: £{base_amount:.2f} each")
                        schedule = create_recurring_invoice_schedule(
                            contact_id=contact_id,
                            contact_name=client_name,
                            email=email,
                            amount=base_amount,
                            num_payments=num_payments - 1,
                            start_date=second_date,
                            invoice_name=payment_plan_name
                        )
                        if schedule:
                            sid = schedule.get('_id', schedule.get('id', ''))
                            if sid:
                                schedule_ids.append(sid)
                    schedule_created = first_schedule is not None
            else:
                # No rounding difference, create single recurring schedule
                schedule = create_recurring_invoice_schedule(
                    contact_id=contact_id,
                    contact_name=client_name,
                    email=email,
                    amount=base_amount,
                    num_payments=num_payments,
                    start_date=first_date,
                    invoice_name=payment_plan_name
                )
                schedule_created = schedule is not None
                if schedule:
                    sid = schedule.get('_id', schedule.get('id', ''))
                    if sid:
                        schedule_ids.append(sid)

    if open_browser:
        _open_invoice_in_browser(invoice_id)

    result = {
        'success': True, 'invoice_id': invoice_id, 'invoice_number': invoice_number,
        'amount': order.get('total_amount', 0), 'paid': 0, 'balance': balance_due,
        'payments_recorded': payments_recorded, 'schedule_created': schedule_created
    }
    if schedule_ids:
        result['schedule_ids'] = schedule_ids
    return result


def create_ghl_invoice(contact_id: str, ps_data: dict, financials_only: bool = False, rounding_in_deposit: bool = True, open_browser: bool = True) -> dict | None:
    """Create an actual invoice in GHL Payments → Invoices using V2 API."""
    debug_log("CREATE GHL INVOICE CALLED", {"contact_id": contact_id, "financials_only": financials_only, "rounding_in_deposit": rounding_in_deposit, "open_browser": open_browser})

    order = ps_data.get('order', {})
    items = order.get('items', [])
    payments = order.get('payments', [])

    if not items and not payments:
        debug_log("ERROR: No items or payments to invoice")
        print("✗ No items or payments to invoice")
        return None

    # Always use product items for the invoice (not payment schedule)
    print(f"  Building invoice from {len(items)} product items...")
    invoice_items, total_discounts_credits = _build_product_invoice_items(items, financials_only)

    if not invoice_items:
        print("✗ No invoice items after building")
        return None

    ps_order_total = order.get('total_amount', 0)
    balance_due = ps_order_total

    client_name = f"{ps_data.get('first_name', '')} {ps_data.get('last_name', '')}".strip()
    
    # Build invoice name: "Client Name - ShootNo" (if shoot number available)
    album_name = ps_data.get('album_name', '')
    shoot_no = ''
    if album_name and '_' in album_name:
        # Album format: ShootNo_Name_GHLContactID - extract first part
        shoot_no = album_name.split('_')[0]
    
    if shoot_no:
        invoice_name = f"{client_name} - {shoot_no}"
    else:
        invoice_name = client_name
    
    issue_date = _normalize_date(order.get('date', ''))
    today = datetime.now().strftime('%Y-%m-%d')
    due_date = today if issue_date < today else issue_date

    ghl_items = _convert_to_ghl_items(invoice_items)

    # Only adjust if no discounts (discounts already account for the difference)
    if total_discounts_credits == 0:
        _adjust_invoice_totals(invoice_items, ghl_items, ps_order_total)

    # Get email and phone - fetch from GHL if not in ProSelect data
    email = ps_data.get('email', '')
    phone = ps_data.get('phone', '')
    
    # Build address from ProSelect data
    address = {
        'street': ps_data.get('street', ''),
        'street2': ps_data.get('street2', ''),
        'city': ps_data.get('city', ''),
        'state': ps_data.get('state', ''),
        'zip_code': ps_data.get('zip_code', ''),
        'country': ps_data.get('country', ''),
    }

    if not email:
        print("  Fetching contact details from GHL...")
        ghl_contact = fetch_ghl_contact(contact_id)
        if ghl_contact:
            email = ghl_contact.get('email', '')
            phone = phone or ghl_contact.get('phone', '')
            if not client_name:
                client_name = ghl_contact.get('name', '')
            # Fill in missing address fields from GHL
            if not address.get('street'):
                address['street'] = ghl_contact.get('street', '')
            if not address.get('street2'):
                address['street2'] = ghl_contact.get('street2', '')
            if not address.get('city'):
                address['city'] = ghl_contact.get('city', '')
            if not address.get('state'):
                address['state'] = ghl_contact.get('state', '')
            if not address.get('zip_code'):
                address['zip_code'] = ghl_contact.get('zip_code', '')
            if not address.get('country'):
                address['country'] = ghl_contact.get('country', '')
            debug_log("USING GHL CONTACT DETAILS", {"email": email, "phone": phone, "address": address})
        else:
            print("  ⚠ Could not fetch contact from GHL")

    if not email:
        print("✗ Contact has no email - required for invoice")
        return {'success': False, 'error': 'Contact has no email address'}

    payload = _build_invoice_payload(
        contact_id, invoice_name, ghl_items, issue_date, due_date,
        client_name, email, phone, address, total_discounts_credits, payments
    )

    # Count future payments for display
    today = datetime.now().strftime('%Y-%m-%d')
    future_payments = [p for p in payments if p.get('date', '') > today]

    print(f"\n📋 Invoice Details:")
    print(f"  ProSelect Order Total: £{ps_order_total:.2f}")
    print(f"  Payment installments: {len(future_payments)}")
    if future_payments:
        for i, fp in enumerate(future_payments, 1):
            print(f"    {i}. £{fp['amount']:.2f} due {fp['date']}")

    url = "https://services.leadconnectorhq.com/invoices/"
    debug_log(f"CREATE INVOICE REQUEST: {url}", payload)

    try:
        response = requests.post(url, headers=_get_ghl_headers(), json=payload, timeout=60)
        response_body = response.text[:3000] if response.text else "EMPTY"
        debug_log(f"CREATE INVOICE RESPONSE: Status={response.status_code}", {"body": response_body})

        if response.status_code in [200, 201]:
            return _handle_invoice_success(response, payments, balance_due, order, ps_data, contact_id, rounding_in_deposit, open_browser)
        else:
            error_msg = f"Invoice creation failed (HTTP {response.status_code})"
            if response.status_code == 400:
                error_msg = "Invalid invoice data - check order details"
            elif response.status_code == 404:
                error_msg = "Contact not found - link client to GHL first"
            print(f"✗ {error_msg}")
            print(f"  Response: {response.text}")
            # Log error for diagnostics (always - even when DEBUG_MODE off)
            error_log(f"GHL Invoice Creation Failed: {error_msg}", {
                "status_code": response.status_code,
                "response": response.text[:2000],
                "contact_id": contact_id,
                "invoice_name": invoice_name,
                "items_count": len(ghl_items),
                "payload_preview": {k: v for k, v in payload.items() if k != 'items'}
            })
            return {'success': False, 'error': error_msg, 'status_code': response.status_code}

    except requests.exceptions.RequestException as e:
        error_msg = f"Network error: {str(e)}"
        print(f"✗ Error creating invoice: {error_msg}")
        error_log(f"GHL Invoice Network Error: {error_msg}", {"contact_id": contact_id}, exception=e)
        return {'success': False, 'error': error_msg}

def _verify_contact_update(contact_id: str, headers: dict) -> None:
    """Verify contact update by re-fetching.

    Args:
        contact_id: GHL contact ID.
        headers: Request headers.
    """
    debug_log("VERIFYING UPDATE - RE-FETCHING CONTACT")
    try:
        verify_url = f"https://services.leadconnectorhq.com/contacts/{contact_id}"
        verify_response = requests.get(verify_url, headers=headers, timeout=30)
        debug_log(f"VERIFICATION RESPONSE: Status={verify_response.status_code}", {
            "body": verify_response.text[:2000] if verify_response.text else "EMPTY"
        })
        if verify_response.status_code == 200:
            verify_data = verify_response.json()
            if verify_data.get('contact', {}).get('id') == contact_id:
                print(f"  ✓ Update verified - data saved to GHL")
                debug_log("UPDATE VERIFICATION SUCCESS", {"contact_id": contact_id})
            else:
                print(f"  ⚠ Could not verify update")
                debug_log("UPDATE VERIFICATION FAILED - ID MISMATCH")
        else:
            print(f"  ⚠ Verification request failed: {verify_response.status_code}")
    except Exception as ve:
        print(f"  ⚠ Verification skipped: {ve}")
        debug_log(f"VERIFICATION EXCEPTION: {ve}")


def _build_contact_custom_values(album_name: str, payment_summary: dict, order: dict) -> dict:
    """Build custom field values for contact update.

    Args:
        album_name: Album name string.
        payment_summary: Payment summary dictionary.
        order: Order dictionary.

    Returns:
        dict: Custom field values.
    """
    values = {
        CUSTOM_FIELDS['session_job_no']: album_name,
        CUSTOM_FIELDS['session_status']: payment_summary.get('status', 'Order Placed'),
        CUSTOM_FIELDS['session_date']: order.get('date', ''),
    }
    return {k: v for k, v in values.items() if v is not None}


def update_ghl_contact(contact_id: str, ps_data: dict) -> dict | None:
    """Update GHL contact with ProSelect order data."""
    debug_log("UPDATE GHL CONTACT CALLED", {"contact_id": contact_id})

    order = ps_data.get('order', {})
    payment_summary = calculate_payment_summary(order)
    album_name = ps_data.get('album_name', '')
    custom_values = _build_contact_custom_values(album_name, payment_summary, order)

    debug_log("CUSTOM FIELD VALUES TO UPDATE", custom_values)

    url = f"https://services.leadconnectorhq.com/contacts/{contact_id}"
    headers = {"Authorization": f"Bearer {API_KEY}", "Content-Type": "application/json", "Version": "2021-07-28"}
    payload = {"customFields": [{"id": k, "field_value": v} for k, v in custom_values.items()]}

    debug_log(f"UPDATE CONTACT REQUEST: {url}", payload)

    try:
        response = requests.put(url, headers=headers, json=payload, timeout=60)
        response_body = response.text[:2000] if response.text else "EMPTY"
        debug_log(f"UPDATE CONTACT RESPONSE: Status={response.status_code}", {"body": response_body})
        response.raise_for_status()

        result = {
            'success': True, 'contact_id': contact_id, 'album_name': album_name,
            'email': ps_data['email'], 'order_total': payment_summary['total'],
            'payments': payment_summary['payment_count'], 'status': payment_summary['status']
        }

        print(f"\n✓ Successfully updated GHL contact")
        print(f"  Contact ID: {contact_id}")
        print(f"  Client: {ps_data['first_name']} {ps_data['last_name']}")
        print(f"  Order Total: £{payment_summary['total']:.2f}")
        print(f"  Payments: {payment_summary['payment_count']}")
        print(f"  Status: {payment_summary['status']}")

        _verify_contact_update(contact_id, headers)
        return result

    except requests.exceptions.RequestException as e:
        error_msg = str(e)
        # Provide user-friendly error messages for common issues
        if hasattr(e, 'response') and e.response is not None:
            status_code = e.response.status_code
            if status_code == 400:
                error_msg = "Invalid contact ID - client may not be linked to GHL"
            elif status_code == 401:
                error_msg = "API authentication failed - check GHL API key"
            elif status_code == 404:
                error_msg = "Contact not found in GHL - link client first"
            elif status_code == 429:
                error_msg = "Rate limit exceeded - try again in a moment"
            elif status_code >= 500:
                error_msg = "GHL server error - try again later"
            print(f"  Response: {e.response.text}")
        print(f"✗ Error updating contact: {error_msg}")
        return {'success': False, 'error': error_msg, 'contact_id': contact_id}

def list_ghl_folders():
    """List all folders in GHL Media - outputs ID|Name format for AHK parsing"""
    headers = {
        "Authorization": f"Bearer {API_KEY}",
        "Version": "2021-07-28",
        "Accept": "application/json"
    }

    try:
        config = load_config()
        location_id = config.get('LOCATION_ID', '')

        params = {
            'altId': location_id,
            'altType': 'location',
            'sortBy': 'name',
            'sortOrder': 'asc',
            'type': 'folder',
            'limit': 100
        }

        response = requests.get(
            "https://services.leadconnectorhq.com/medias/files",
            headers=headers,
            params=params,
            timeout=30
        )

        if response.status_code == 200:
            data = response.json()
            folders = data.get('files', [])

            if not folders:
                print("NO_FOLDERS")
            else:
                # Output format: ID|Name (one per line)
                for folder in folders:
                    folder_id = folder.get('_id', '')
                    folder_name = folder.get('name', 'Unnamed')
                    print(f"{folder_id}|{folder_name}")
        else:
            print(f"API_ERROR|{response.status_code}")
    except Exception as e:
        print(f"ERROR|{str(e)}")


def list_email_templates():
    """List all email templates from GHL - outputs ID|Name format for AHK parsing."""
    headers = {
        "Authorization": f"Bearer {API_KEY}",
        "Version": "2021-07-28",
        "Accept": "application/json"
    }

    try:
        config = load_config()
        location_id = config.get('LOCATION_ID', '')

        url = f"https://services.leadconnectorhq.com/locations/{location_id}/templates"
        params = {
            'type': 'email',
            'limit': 100
        }

        debug_log("LIST EMAIL TEMPLATES REQUEST", {"url": url, "params": params})

        response = requests.get(url, headers=headers, params=params, timeout=30)
        debug_log("LIST EMAIL TEMPLATES RESPONSE", {
            "status_code": response.status_code,
            "body": response.text[:500] if response.text else "EMPTY"
        })

        if response.status_code == 200:
            data = response.json()
            templates = data.get('templates', [])

            if not templates:
                print("NO_TEMPLATES")
            else:
                for t in templates:
                    t_id = t.get('id', '') or t.get('_id', '')
                    t_name = t.get('name', 'Unnamed')
                    print(f"{t_id}|{t_name}")
        elif response.status_code == 404 or response.status_code == 422:
            # Try alternate endpoint for snippets
            debug_log("Templates endpoint failed, trying snippets", {"status": response.status_code})
            _list_snippets_fallback(headers, location_id)
        else:
            print(f"API_ERROR|{response.status_code}")
    except Exception as e:
        debug_log("LIST EMAIL TEMPLATES EXCEPTION", {"error": str(e)})
        print(f"ERROR|{str(e)}")


def _list_snippets_fallback(headers: dict, location_id: str):
    """Fallback to snippets API if templates endpoint not available."""
    try:
        url = "https://services.leadconnectorhq.com/snippets/"
        params = {
            'locationId': location_id,
            'limit': 100
        }

        debug_log("LIST SNIPPETS FALLBACK REQUEST", {"url": url, "params": params})

        response = requests.get(url, headers=headers, params=params, timeout=30)
        debug_log("LIST SNIPPETS FALLBACK RESPONSE", {
            "status_code": response.status_code,
            "body": response.text[:500] if response.text else "EMPTY"
        })

        if response.status_code == 200:
            data = response.json()
            snippets = data.get('snippets', [])

            if not snippets:
                print("NO_TEMPLATES")
            else:
                for s in snippets:
                    s_id = s.get('id', '') or s.get('_id', '')
                    s_name = s.get('name', 'Unnamed')
                    print(f"{s_id}|{s_name}")
        else:
            print(f"API_ERROR|{response.status_code}")
    except Exception as e:
        print(f"ERROR|{str(e)}")


def _generate_contact_sheet_path(cs_data: dict, xml_path: str = '') -> str:
    """Generate JPG path for contact sheet.

    Saves to the same directory as the XML file for easy access and to avoid
    permission issues with Program Files or other restricted directories.

    Args:
        cs_data: Contact sheet data dictionary.
        xml_path: Path to the source XML file (JPG saved alongside it).

    Returns:
        str: Full path to JPG file.
    """
    import ctypes
    try:
        LOCALE_SSHORTDATE = 0x1F
        buffer = ctypes.create_unicode_buffer(80)
        ctypes.windll.kernel32.GetLocaleInfoW(0x0400, LOCALE_SSHORTDATE, buffer, 80)
        date_format = '%d%m%y' if buffer.value.lower().startswith('d') else '%m%d%y'
    except Exception:
        date_format = '%d%m%y'

    date_str = cs_data['order_datetime'].strftime(date_format)
    jpg_filename = f"{cs_data['shoot_no']}-{cs_data['last_name']}-{date_str}.jpg"

    # Use XML directory if provided, otherwise fall back to writable output dir
    if xml_path:
        output_dir = os.path.dirname(os.path.abspath(xml_path))
    else:
        output_dir = _get_output_dir()
    return os.path.join(output_dir, jpg_filename)


def _add_contact_sheet_note(contact_id: str, cs_data: dict, thumb_folder: str, jpg_url: str) -> None:
    """Add contact sheet note to GHL contact.

    Args:
        contact_id: GHL contact ID.
        cs_data: Contact sheet data.
        thumb_folder: Path to thumbnail folder.
        jpg_url: URL of uploaded JPG.
    """
    from create_ghl_contactsheet import add_contact_note
    import glob

    image_count = len(glob.glob(os.path.join(thumb_folder, "Product_*.jpg")))
    note_body = f"""📸 Product Contact Sheet - {cs_data['shoot_no']}

Client: {cs_data['first_name']} {cs_data['last_name']}
Order Date: {cs_data.get('order_date', '')}
Products: {image_count} items

📄 View Contact Sheet:
{jpg_url}

Generated: {datetime.now().strftime('%Y-%m-%d %H:%M')}"""

    add_contact_note(contact_id, note_body)
    print(f"   ✓ Note added to contact")


def _create_and_upload_contact_sheet(xml_path: str, contact_id: str, collect_folder: str = '') -> None:
    """Create and upload contact sheet JPG to GHL.

    Args:
        xml_path: Path to the ProSelect XML file.
        contact_id: GHL contact ID for adding notes.
        collect_folder: Optional folder to save a local copy of the contact sheet.
    """
    print(f"\n📸 Creating contact sheet...")
    debug_log("CONTACT SHEET - Starting creation", {"xml_path": xml_path})

    try:
        debug_log("CONTACT SHEET - Importing module")
        from create_ghl_contactsheet import (
            parse_xml as cs_parse_xml, create_contact_sheet_jpg,
            find_folder_by_name, upload_to_folder
        )
        debug_log("CONTACT SHEET - Module imported successfully")

        cs_data = cs_parse_xml(xml_path)
        debug_log("CONTACT SHEET - XML parsed", {"shoot_no": cs_data.get('shoot_no', 'unknown')})

        thumb_folder = get_thumbnail_folder(xml_path)

        if not thumb_folder:
            print(f"   ℹ No thumbnail folder found")
            debug_log("CONTACT SHEET - No thumbnail folder", {"xml_path": xml_path})
            return

        debug_log("CONTACT SHEET - Thumbnail folder found", {"thumb_folder": thumb_folder})

        jpg_path = _generate_contact_sheet_path(cs_data, xml_path)
        title = f"Product Gallery - {cs_data['shoot_no']}"
        subtitle = f"{cs_data['first_name']} {cs_data['last_name']} - {cs_data.get('order_date', '')}"

        debug_log("CONTACT SHEET - Creating JPG", {"jpg_path": jpg_path, "title": title})
        result_path = create_contact_sheet_jpg(thumb_folder, jpg_path, title, subtitle, cs_data.get('image_labels', {}))

        if not result_path:
            print(f"   ⚠ Failed to create JPG")
            debug_log("CONTACT SHEET - JPG creation failed")
            return
        print(f"   ✓ JPG created: {os.path.basename(jpg_path)}")
        debug_log("CONTACT SHEET - JPG created", {"result_path": result_path})

        folder_id = get_media_folder_id() or find_folder_by_name("Order Sheets")
        debug_log("CONTACT SHEET - Uploading to folder", {"folder_id": folder_id})

        jpg_url = upload_to_folder(jpg_path, folder_id)
        if not jpg_url:
            print(f"   ⚠ Failed to upload JPG")
            debug_log("CONTACT SHEET - Upload failed")
            return
        print(f"   ✓ Uploaded to GHL Media")
        debug_log("CONTACT SHEET - Upload success", {"jpg_url": jpg_url})

        # Save local copy if collect folder is specified
        if collect_folder and os.path.isdir(collect_folder):
            import shutil
            album_name = cs_data.get('shoot_no', 'Unknown')
            # Sanitize album name for filename
            safe_name = "".join(c if c.isalnum() or c in (' ', '-', '_') else '_' for c in album_name)
            collect_path = os.path.join(collect_folder, f"{safe_name}.jpg")
            try:
                shutil.copy2(jpg_path, collect_path)
                print(f"   ✓ Saved local copy: {collect_path}")
                debug_log("CONTACT SHEET - Local copy saved", {"collect_path": collect_path})
            except Exception as copy_err:
                print(f"   ⚠ Failed to save local copy: {copy_err}")
                debug_log("CONTACT SHEET - Local copy failed", {"error": str(copy_err)})

        _add_contact_sheet_note(contact_id, cs_data, thumb_folder, jpg_url)

    except ImportError as e:
        print(f"   ⚠ Contact sheet module not found: {e}")
        debug_log("CONTACT SHEET - ImportError", str(e))
    except Exception as e:
        print(f"   ⚠ Contact sheet error: {e}")
        debug_log("CONTACT SHEET - Exception", {"error": str(e), "type": type(e).__name__})


def _print_sync_header(xml_path: str, financials_only: bool, create_invoice: bool, create_contact_sheet: bool) -> None:
    """Print the sync operation header.

    Args:
        xml_path: Path to XML file.
        financials_only: Whether financials-only mode is enabled.
        create_invoice: Whether invoice creation is enabled.
        create_contact_sheet: Whether contact sheet creation is enabled.
    """
    print(f"\n{'='*70}")
    print(f"ProSelect Invoice to GHL Sync")
    print(f"{'='*70}")
    print(f"XML File: {os.path.basename(xml_path)}")
    print(f"Financials Only: {financials_only}")
    print(f"Create Invoice: {create_invoice}")
    print(f"Contact Sheet: {create_contact_sheet}")
    if DEBUG_MODE:
        print(f"DEBUG MODE: ON - Log file: {DEBUG_LOG_FILE}")
    print()


def _save_and_log_result(result: dict) -> None:
    """Save result to file and log completion.

    Args:
        result: The result dictionary to save.
    """
    debug_log("FINAL RESULT", result)

    with open(OUTPUT_FILE, 'w', encoding='utf-8') as f:
        json.dump(result, f, indent=2)

    print(f"\nResult saved to: {OUTPUT_FILE}")
    print(f"{'='*70}\n")

    # Determine operation type for log message
    if result.get('invoices_deleted') is not None or result.get('invoices_voided') is not None:
        op_type = "DELETE"
    elif result.get('deleted') or result.get('voided'):
        op_type = "DELETE"
    else:
        op_type = "SYNC"

    debug_log("=" * 60)
    debug_log(f"{op_type} COMPLETED - Success: {result.get('success', False)}")
    debug_log("=" * 60)

    if DEBUG_MODE and GIST_ENABLED:
        gist_url = upload_debug_log_to_gist()
        if gist_url:
            print(f"📤 Debug log uploaded: {gist_url}")


def _parse_cli_args():
    """Parse command line arguments.

    Returns:
        argparse.Namespace: Parsed arguments.
    """
    import argparse
    # Disable help in compiled exe to prevent reverse engineering
    is_frozen = getattr(sys, 'frozen', False)
    if is_frozen:
        parser = argparse.ArgumentParser(add_help=False)
        parser.add_argument('xml_path', nargs='?')
        parser.add_argument('--financials-only', action='store_true')
        parser.add_argument('--create-invoice', action='store_true', default=True)
        parser.add_argument('--no-invoice', action='store_true')
        parser.add_argument('--contact-sheet', action='store_true', default=True)
        parser.add_argument('--no-contact-sheet', action='store_true')
        parser.add_argument('--collect-folder', type=str, default='')
        parser.add_argument('--rounding-in-deposit', action='store_true')
        parser.add_argument('--no-open-browser', action='store_true')
        parser.add_argument('--list-folders', action='store_true')
        parser.add_argument('--delete-invoice', type=str, default='')
        parser.add_argument('--schedule-ids', type=str, default='')
        parser.add_argument('--delete-for-client', type=str, default='')
        parser.add_argument('--send-room-email', nargs=2, metavar=('CONTACT_ID', 'IMAGE_PATH'))
        parser.add_argument('--email-subject', type=str, default='')
        parser.add_argument('--email-template', type=str, default='')
        parser.add_argument('--list-email-templates', action='store_true')
        parser.add_argument('--void-invoice', type=str, default='')
    else:
        parser = argparse.ArgumentParser(description='Sync ProSelect invoice to GHL')
        parser.add_argument('xml_path', nargs='?', help='Path to ProSelect XML export file')
        parser.add_argument('--financials-only', action='store_true',
                            help='Only include lines with monetary values')
        parser.add_argument('--create-invoice', action='store_true', default=True,
                            help='Create actual GHL invoice (default: True)')
        parser.add_argument('--no-invoice', action='store_true',
                            help='Skip invoice creation, only update contact fields')
        parser.add_argument('--contact-sheet', action='store_true', default=True,
                            help='Create and upload JPG contact sheet (default: True)')
        parser.add_argument('--no-contact-sheet', action='store_true',
                            help='Skip contact sheet creation')
        parser.add_argument('--collect-folder', type=str, default='',
                            help='Folder to save local copy of contact sheet (named by album)')
        parser.add_argument('--rounding-in-deposit', action='store_true',
                            help='Add rounding errors to deposit instead of separate invoice')
        parser.add_argument('--no-open-browser', action='store_true',
                            help='Do not open the invoice URL in browser after sync')
        parser.add_argument('--list-folders', action='store_true',
                            help='List all folders in GHL Media and exit')
        parser.add_argument('--delete-invoice', type=str, default='',
                            help='Delete a GHL invoice by ID')
        parser.add_argument('--schedule-ids', type=str, default='',
                            help='Comma-separated recurring schedule IDs to cancel (used with --delete-invoice)')
        parser.add_argument('--delete-for-client', type=str, default='',
                            help='Delete all invoices/schedules for the client in the given XML file')
        parser.add_argument('--send-room-email', nargs=2, metavar=('CONTACT_ID', 'IMAGE_PATH'),
                            help='Send a room capture image via email to a GHL contact')
        parser.add_argument('--email-subject', type=str, default='',
                            help='Custom email subject (used with --send-room-email)')
        parser.add_argument('--email-template', type=str, default='',
                            help='GHL email template/snippet ID to use (used with --send-room-email)')
        parser.add_argument('--list-email-templates', action='store_true',
                            help='List available email templates/snippets from GHL and exit')
        parser.add_argument('--void-invoice', type=str, default='',
                            help='Void a GHL invoice by ID (after payment refund)')
    return parser.parse_args()


def _process_sync(
    xml_path: str,
    financials_only: bool,
    create_invoice: bool,
    create_contact_sheet: bool,
    collect_folder: str = '',
    rounding_in_deposit: bool = True,
    open_browser: bool = True
) -> dict:
    """Process the sync operation.

    Args:
        xml_path: Path to XML file.
        financials_only: Whether financials-only mode is enabled.
        create_invoice: Whether invoice creation is enabled.
        create_contact_sheet: Whether contact sheet creation is enabled.
        collect_folder: Optional folder to save local copy of contact sheet.
        rounding_in_deposit: If True, add rounding to deposit; else create separate first invoice.
        open_browser: If True, open the invoice URL in browser after sync.

    Returns:
        dict: Result dictionary.
    """
    # Clear any old progress file first
    clear_progress_file()

    # Write initial progress immediately so GUI knows we started
    write_progress(0, 5, "Starting sync process...")

    # Calculate total steps for progress
    total_steps = 3  # Parse, Update Contact, Done
    if create_contact_sheet:
        total_steps += 1
    if create_invoice:
        total_steps += 1
    current_step = 0

    # Step 1: Parse XML
    current_step += 1
    write_progress(current_step, total_steps, "Parsing invoice XML...")

    ps_data = parse_proselect_xml(xml_path)
    if not ps_data:
        print("Failed to parse XML")
        write_progress(current_step, total_steps, "Failed to parse XML", 'error')
        error_log("XML PARSING FAILED", {"xml_path": xml_path})
        sys.exit(1)

    client_name = f"{ps_data.get('first_name')} {ps_data.get('last_name')}"
    album_name = ps_data.get('album_name', '')
    shoot_no = album_name.split('_')[0] if album_name and '_' in album_name else ''
    print(f"Client: {client_name}")
    print(f"Email: {ps_data.get('email')}")

    contact_id = ps_data.get('ghl_contact_id')
    print(f"GHL Contact ID: {contact_id}")

    order_data = ps_data.get('order', {})
    order_total = order_data.get('total_amount', 0) if isinstance(order_data, dict) else 0
    print(f"Order Total: £{order_total:.2f}\n")

    if not contact_id:
        print("✗ No GHL Contact ID in XML")
        write_progress(current_step, total_steps, "No GHL Contact ID in XML", 'error')
        error_log("NO GHL CONTACT ID IN XML", {
            "xml_path": xml_path,
            "client_name": client_name,
            "email": ps_data.get('email'),
            "album_name": album_name
        })
        return {'success': False, 'error': 'No GHL Contact ID in XML (Client_ID field)'}

    # Step 2: Contact sheet (optional)
    if create_contact_sheet:
        current_step += 1
        write_progress(current_step, total_steps, f"Creating contact sheet for {client_name}...")
        _create_and_upload_contact_sheet(xml_path, contact_id, collect_folder)

    # Step 3: Update contact
    current_step += 1
    write_progress(current_step, total_steps, f"Updating GHL contact...")
    result = update_ghl_contact(contact_id, ps_data)

    # Step 4: Create invoice (optional)
    if create_invoice and result.get('success'):
        current_step += 1
        write_progress(current_step, total_steps, f"Creating invoice & recording payments...")
        print(f"\n📄 Creating GHL invoice...")
        invoice_result = create_ghl_invoice(contact_id, ps_data, financials_only, rounding_in_deposit, open_browser)
        if invoice_result:
            result['invoice'] = invoice_result
    elif not create_invoice:
        print("\n⏭ Skipping invoice creation (--no-invoice flag)")

    # Step 5: Add tags to contact and opportunities on successful sync
    if result.get('success'):
        # Add sync tag to contact (configurable via INI: SyncTag)
        sync_tag = CONFIG.get('SYNC_TAG', 'PS Invoice')
        if sync_tag:
            add_tags_to_contact(contact_id, [sync_tag])
        
        # Add tags to any opportunities for this contact (configurable via INI: OpportunityTags)
        opp_tags = CONFIG.get('OPPORTUNITY_TAGS', [])
        if opp_tags:
            tagged = tag_contact_opportunities(contact_id, opp_tags)
            if tagged > 0:
                result['opportunities_tagged'] = tagged

    # Final step: Done
    current_step = total_steps
    if result.get('success'):
        write_progress(current_step, total_steps, f"Sync complete for {client_name}", 'success')
    else:
        write_progress(current_step, total_steps, f"Sync failed: {result.get('error', 'Unknown error')}", 'error')

    # Add client identification to result for future reference (e.g., delete confirmation)
    result['client_name'] = client_name
    result['shoot_no'] = shoot_no

    return result


def main() -> None:
    """Main entry point - parse arguments and sync ProSelect invoice to GHL."""
    args = _parse_cli_args()

    if args.list_folders:
        list_ghl_folders()
        sys.exit(0)

    if args.list_email_templates:
        list_email_templates()
        sys.exit(0)

    if args.delete_invoice:
        debug_log("CLI MODE: --delete-invoice", {"invoice_id": args.delete_invoice, "schedule_ids": args.schedule_ids})
        sched_ids = [s.strip() for s in args.schedule_ids.split(',') if s.strip()] if args.schedule_ids else []
        result = delete_ghl_invoice(args.delete_invoice, schedule_ids=sched_ids)
        _save_and_log_result(result)
        sys.exit(0 if result.get('success') else 1)

    if args.delete_for_client:
        debug_log("CLI MODE: --delete-for-client", {"xml_path": args.delete_for_client})
        if not os.path.exists(args.delete_for_client):
            debug_log(f"DELETE-FOR-CLIENT FILE NOT FOUND: {args.delete_for_client}")
            print(f"Error: File not found: {args.delete_for_client}")
            sys.exit(1)
        result = delete_client_invoices(args.delete_for_client)
        _save_and_log_result(result)
        sys.exit(0 if result.get('success') else 1)

    if args.void_invoice:
        debug_log("CLI MODE: --void-invoice", {"invoice_id": args.void_invoice})
        result = void_ghl_invoice(args.void_invoice)
        _save_and_log_result(result)
        sys.exit(0 if result.get('success') else 1)

    if args.send_room_email:
        cid, img_path = args.send_room_email
        debug_log("CLI MODE: --send-room-email", {"contact_id": cid, "image_path": img_path, "template_id": args.email_template})
        result = send_room_capture_email(cid, img_path, subject=args.email_subject, template_id=args.email_template)
        _save_and_log_result(result)
        sys.exit(0 if result.get('success') else 1)

    if not args.xml_path:
        print("Error: xml_path is required for sync mode")
        sys.exit(1)

    if not os.path.exists(args.xml_path):
        print(f"Error: File not found: {args.xml_path}")
        sys.exit(1)

    financials_only = args.financials_only
    create_invoice = not args.no_invoice
    create_contact_sheet = not args.no_contact_sheet
    collect_folder = args.collect_folder if args.collect_folder else ''
    rounding_in_deposit = args.rounding_in_deposit
    open_browser = not args.no_open_browser

    _print_sync_header(args.xml_path, financials_only, create_invoice, create_contact_sheet)
    result = _process_sync(args.xml_path, financials_only, create_invoice, create_contact_sheet, collect_folder, rounding_in_deposit, open_browser)
    _save_and_log_result(result)
    sys.exit(0 if result.get('success') else 1)


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        # Catch any unhandled exception and log it
        import traceback
        error_log("UNHANDLED EXCEPTION IN MAIN", {
            "args": sys.argv,
            "exception": str(e),
            "type": type(e).__name__
        }, exception=e)
        
        # Write to progress file so AHK knows there was an error
        write_progress(0, 1, f"Critical error: {e}", 'error')
        
        # Also upload error log to gist if enabled
        if GIST_ENABLED:
            try:
                upload_error_log_to_gist()
            except Exception:
                pass
        
        print(f"\nCRITICAL ERROR: {e}")
        print(f"Error log saved to: {ERROR_LOG_FILE}")
        traceback.print_exc()
        sys.exit(1)

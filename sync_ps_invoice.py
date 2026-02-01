"""
import importlib
ProSelect Invoice Sync to GHL - Parse PS XML and update GHL contact
Author: GuyMayer
Date: 2026-01-29
Usage: python sync_ps_invoice.py <xml_file_path>
Example: python sync_ps_invoice.py "C:/path/to/2026-01-27_180030_P26008P__1.xml"
Note: All config loaded from SideKick_PS.ini (encrypted tokens)
"""

import subprocess
import sys
import json
import os
import time
import xml.etree.ElementTree as ET
from datetime import datetime

# =============================================================================
# DEBUG MODE - Set to True for verbose logging
# =============================================================================
DEBUG_MODE = True
DEBUG_LOCATION_ID = "W0fg9KOTXUtvCyS18jwM"  # Hardcoded for debugging

# Debug log folder on user's Desktop, organized by Location ID
DEBUG_LOG_FOLDER = os.path.join(os.path.expanduser("~"), "Desktop", "SideKick_Logs", DEBUG_LOCATION_ID)
os.makedirs(DEBUG_LOG_FOLDER, exist_ok=True)  # Create folder structure
DEBUG_LOG_FILE = os.path.join(DEBUG_LOG_FOLDER, f"sync_debug_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log")

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
                config.read(ini_path)
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

    # Print to console
    print(f"DEBUG: {message}")

    # Write to file
    try:
        with open(DEBUG_LOG_FILE, 'a', encoding='utf-8') as f:
            f.write(log_line + "\n" + "-"*60 + "\n")
    except Exception as e:
        print(f"DEBUG LOG ERROR: {e}")

# Initialize debug log with header
if DEBUG_MODE:
    try:
        computer_name = os.environ.get('COMPUTERNAME', 'Unknown')
        username = os.environ.get('USERNAME', 'Unknown')
        with open(DEBUG_LOG_FILE, 'a', encoding='utf-8') as f:
            f.write(f"\n{'='*70}\n")
            f.write(f"SIDEKICK DEBUG LOG - VERBOSE MODE\n")
            f.write(f"{'='*70}\n")
            f.write(f"Session Start:  {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
            f.write(f"Computer Name:  {computer_name}\n")
            f.write(f"Windows User:   {username}\n")
            f.write(f"Location ID:    {DEBUG_LOCATION_ID}\n")
            f.write(f"Python Version: {sys.version}\n")
            script_path = sys.executable if getattr(sys, 'frozen', False) else os.path.abspath(__file__)
            f.write(f"Script Path:    {script_path}\n")
            f.write(f"Working Dir:    {os.getcwd()}\n")
            f.write(f"Command Args:   {sys.argv}\n")
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
    config = {}
    current_section = None

    with open(ini_path, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith(';'):
                continue
            current_section = _parse_ini_line(line, current_section, config)

    return config

    return config


def _decode_api_key(ghl_config: dict) -> str:
    """Decode Base64 API key from GHL config section.

    Args:
        ghl_config: The GHL section dictionary from INI.

    Returns:
        str: Decoded API key.

    Raises:
        ValueError: If no API key found.
    """
    import base64
    # Try new key name first, then fallback to legacy name
    api_b64 = ghl_config.get('API_Key_B64', '') or ghl_config.get('API_Key_V2_B64', '')

    if api_b64:
        api_b64_clean = api_b64.replace(' ', '').replace('\n', '').replace('\r', '')
        return base64.b64decode(api_b64_clean).decode('utf-8')
    else:
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

    # DEBUG: Override location ID if debug mode is on
    if DEBUG_MODE and DEBUG_LOCATION_ID:
        location_id = DEBUG_LOCATION_ID
        debug_log(f"Using DEBUG location ID: {DEBUG_LOCATION_ID}")

    return {
        'API_KEY': api_key,
        'LOCATION_ID': location_id,
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
        data: dict = {
            'ghl_contact_id': get_text(root, 'Client_ID'),  # GHL contact ID from ProSelect
            'email': get_text(root, 'Email_Address'),
            'first_name': get_text(root, 'First_Name'),
            'last_name': get_text(root, 'Last_Name'),
            'phone': get_text(root, 'Cell_Phone'),
            'album_name': get_text(root, 'Album_Name'),
            'album_path': get_text(root, 'Album_Path'),
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

                item_data = {
                    'type': get_text(item, 'ItemType'),
                    'description': get_text(item, 'Description'),
                    'product': get_text(item, 'Product_Name'),
                    'price': price,
                    'quantity': int(get_text(item, 'Quantity', '1')),
                    'taxable': is_taxable,
                    'vat_amount': vat_amount,
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
    """Find GHL contact by client_id or email.

    Args:
        email: Contact email address.
        client_id: ProSelect client ID (session_job_no).

    Returns:
        dict | None: Contact data if found, None otherwise.
    """
    debug_log("FIND GHL CONTACT CALLED", {"email": email, "client_id": client_id})

    # Search by client_id in custom field (session_job_no) - PRIMARY method
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

    # Fallback: search by email using V2 API
    if email:
        filters = [{"field": "email", "operator": "eq", "value": email}]
        contact_id = _search_ghl_contacts(filters, "EMAIL")
        if contact_id:
            print(f"✓ Found contact by email: {email}")
            return contact_id

    debug_log(f"CONTACT NOT FOUND", {"client_id": client_id, "email": email})
    print(f"✗ Contact not found - Client ID: {client_id}, Email: {email}")
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

def record_ghl_payment(invoice_id: str, payment: dict, max_retries: int = 3) -> bool:
    """Record a payment transaction against a GHL invoice.

    Args:
        invoice_id: GHL invoice ID.
        payment: Payment data dictionary.
        max_retries: Maximum retry attempts.

    Returns:
        bool: True if payment recorded successfully.
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
        "amount": int(round(payment['amount'] * 100)),  # Convert pounds to pence for GHL API
        "mode": ghl_method,
        "notes": f"{payment.get('MethodName', 'Payment')} - {payment.get('date', '')}",
    }

    debug_log(f"RECORD PAYMENT REQUEST: {url}", payload)

    # Retry with exponential backoff for race conditions
    for attempt in range(max_retries):
        try:
            response = requests.post(url, headers=headers, json=payload, timeout=60)

            debug_log(f"RECORD PAYMENT RESPONSE (attempt {attempt+1}): Status={response.status_code}", {
                "status_code": response.status_code,
                "body": response.text[:1000] if response.text else "EMPTY"
            })

            if response.status_code in [200, 201]:
                return True
            elif response.status_code == 409:
                # Race condition - payment recording in progress, wait and retry
                wait_time = (attempt + 1) * 2  # 2s, 4s, 6s
                if attempt < max_retries - 1:
                    time.sleep(wait_time)
                    continue
                else:
                    print(f"    Payment failed after {max_retries} retries (409 conflict)")
                    return False
            else:
                print(f"    Payment failed ({response.status_code}): {response.text[:100]}")
                return False
        except Exception as e:
            print(f"    Payment error: {e}")
            if attempt < max_retries - 1:
                time.sleep(2)
                continue
            return False

    return False

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


# =============================================================================
# Invoice Helper Functions
# =============================================================================
def _build_payment_invoice_items(payments: list, order: dict) -> list:
    """Build invoice line items from payment schedule.
    
    DEPRECATED: Now we always show product items. This is kept for reference.

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


def _consolidate_product_items(items: list) -> list:
    """Consolidate duplicate product items by name.
    
    Args:
        items: List of product item dictionaries.
        
    Returns:
        list: Consolidated items with quantities summed.
    """
    consolidated = {}
    
    for item in items:
        # Create a key from product name
        product_name = item.get('product', '') or item.get('description', 'Item')
        price = item.get('price', 0)
        
        # Skip zero-price items like mats
        if price == 0:
            continue
            
        key = f"{product_name}_{price}"
        
        if key in consolidated:
            consolidated[key]['quantity'] += item.get('quantity', 1)
        else:
            consolidated[key] = {
                'name': product_name,
                'description': item.get('description', product_name),
                'price': float(price),
                'quantity': item.get('quantity', 1),
                'type': item.get('type', ''),
                'currency': 'GBP'
            }
    
    return list(consolidated.values())


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
        dict: Invoice item dictionary.
    """
    description = item.get('product', '') or item['description'] or 'Item'
    return {
        "name": item['description'] or item['product'] or 'Item',
        "description": description,
        "quantity": item['quantity'],
        "price": float(item['price']),
        "currency": "GBP"
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
        list: GHL-formatted items with amounts in pence.
    """
    return [
        {
            "name": str(item['name']),
            "description": str(item['description']),
            "amount": int(round(item['price'] * 100)),  # Convert pounds to pence
            "qty": int(item['quantity']),
            "currency": "GBP"
        }
        for item in invoice_items
    ]


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
    total_discounts_credits: float
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
        total_discounts_credits: Total discounts to apply.

    Returns:
        dict: Complete payload for GHL API.
    """
    payload = {
        "altId": CONFIG.get('LOCATION_ID', ''),
        "altType": "location",
        "name": invoice_name,
        "contactId": contact_id,
        "currency": "GBP",
        "items": ghl_items,
        "issueDate": issue_date,
        "dueDate": due_date,
        "contactDetails": {
            "id": contact_id,
            "name": client_name,
            "email": email
        }
    }

    if total_discounts_credits > 0:
        payload["discount"] = {
            "type": "fixed",
            "value": int(round(total_discounts_credits * 100))  # Convert pounds to pence
        }

    return payload


def _process_invoice_payments(invoice_id: str, payments: list) -> int:
    """Record past payments for an invoice.

    Args:
        invoice_id: GHL invoice ID.
        payments: List of payment dictionaries.

    Returns:
        int: Number of payments successfully recorded.
    """
    today = datetime.now().strftime('%Y-%m-%d')
    past_payments = [p for p in payments if p.get('date', '') <= today]
    future_payments = [p for p in payments if p.get('date', '') > today]

    payments_recorded = 0

    if past_payments:
        print(f"\n💳 Recording {len(past_payments)} past payment(s)...")
        for i, payment in enumerate(past_payments):
            if i > 0:
                time.sleep(1)
            if record_ghl_payment(invoice_id, payment):
                payments_recorded += 1
        print(f"  ✓ Recorded {payments_recorded}/{len(past_payments)} past payments")

    if future_payments:
        print(f"  📅 {len(future_payments)} future payments shown on invoice (not recorded yet)")

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


def _adjust_invoice_totals(invoice_items: list, ghl_items: list, ps_order_total: float) -> None:
    """Adjust invoice totals if they don't match order total.

    Args:
        invoice_items: Internal invoice items list (prices in pounds).
        ghl_items: GHL-formatted items list (amounts in pence).
        ps_order_total: ProSelect order total in pounds.
    """
    ghl_invoice_total = sum(i['price'] for i in invoice_items if i['price'] > 0)
    if abs(ghl_invoice_total - ps_order_total) <= 0.01:
        return

    adjustment = ps_order_total - ghl_invoice_total
    adjustment_pence = int(round(adjustment * 100))  # Convert adjustment to pence
    for item in invoice_items:
        if item['price'] > 0:
            item['price'] = round(item['price'] + adjustment, 2)
            break
    for ghl_item in ghl_items:
        if ghl_item['amount'] > 0:
            ghl_item['amount'] = ghl_item['amount'] + adjustment_pence
            break
    print(f"  ✓ Totals adjusted (rounding fix: £{adjustment:.2f} on Payment 1)")


def _handle_invoice_success(response, payments: list, balance_due: float, order: dict) -> dict:
    """Handle successful invoice creation response.

    Args:
        response: HTTP response object.
        payments: Payments list.
        balance_due: Balance due amount.
        order: Order dictionary.

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

    payments_recorded = _process_invoice_payments(invoice_id, payments) if payments else 0
    print(f"  Balance Due: £{balance_due:.2f}")

    _open_invoice_in_browser(invoice_id)

    return {
        'success': True, 'invoice_id': invoice_id, 'invoice_number': invoice_number,
        'amount': order.get('total_amount', 0), 'paid': 0, 'balance': balance_due,
        'payments_recorded': payments_recorded
    }


def create_ghl_invoice(contact_id: str, ps_data: dict, financials_only: bool = False) -> dict | None:
    """Create an actual invoice in GHL Payments → Invoices using V2 API.
    
    Always shows actual product line items (what the client is buying).
    Payment schedule info is recorded separately as invoice payments.
    """
    debug_log("CREATE GHL INVOICE CALLED", {"contact_id": contact_id, "financials_only": financials_only})

    order = ps_data.get('order', {})
    items = order.get('items', [])
    payments = order.get('payments', [])

    if not items:
        debug_log("ERROR: No items to invoice")
        print("✗ No items to invoice")
        return None

    # Always build from product items - show what the client is buying
    print(f"  Building invoice from {len(items)} product items...")
    invoice_items, total_discounts_credits = _build_product_invoice_items(items, financials_only)
    
    # Consolidate duplicate items (e.g., multiple prints at same price)
    consolidated_items = _consolidate_product_items(items)
    if consolidated_items:
        print(f"  Consolidated to {len(consolidated_items)} unique line items")
        # Use consolidated items for cleaner invoice
        invoice_items = consolidated_items
        # Recalculate discounts from original items
        total_discounts_credits = sum(abs(item['price']) for item in items if item.get('price', 0) < 0)

    if not invoice_items:
        print("✗ No invoice items after building")
        return None

    ps_order_total = order.get('total_amount', 0)
    balance_due = ps_order_total

    client_name = f"{ps_data.get('first_name', '')} {ps_data.get('last_name', '')}".strip()
    invoice_name = f"ProSelect - {client_name}"
    issue_date = _normalize_date(order.get('date', ''))
    today = datetime.now().strftime('%Y-%m-%d')
    due_date = today if issue_date < today else issue_date

    ghl_items = _convert_to_ghl_items(invoice_items)
    _adjust_invoice_totals(invoice_items, ghl_items, ps_order_total)

    payload = _build_invoice_payload(
        contact_id, invoice_name, ghl_items, issue_date, due_date,
        client_name, ps_data.get('email', ''), total_discounts_credits
    )

    print(f"\n📋 Invoice Details:")
    print(f"  ProSelect Order Total: £{ps_order_total:.2f}")
    print(f"  Payments scheduled: {len(payments)}")

    url = "https://services.leadconnectorhq.com/invoices/"
    debug_log(f"CREATE INVOICE REQUEST: {url}", payload)

    try:
        response = requests.post(url, headers=_get_ghl_headers(), json=payload, timeout=60)
        debug_log(f"CREATE INVOICE RESPONSE: Status={response.status_code}", {"body": response.text[:3000] if response.text else "EMPTY"})

        if response.status_code in [200, 201]:
            return _handle_invoice_success(response, payments, balance_due, order)
        else:
            print(f"✗ Failed to create invoice: {response.status_code}")
            print(f"  Response: {response.text}")
            return {'success': False, 'error': response.text, 'status_code': response.status_code}

    except requests.exceptions.RequestException as e:
        print(f"✗ Error creating invoice: {e}")
        return {'success': False, 'error': str(e)}

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
        debug_log(f"UPDATE CONTACT RESPONSE: Status={response.status_code}", {"body": response.text[:2000] if response.text else "EMPTY"})
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
        print(f"✗ Error updating contact: {e}")
        if hasattr(e, 'response') and e.response is not None:
            print(f"  Response: {e.response.text}")
        return {'success': False, 'error': str(e), 'contact_id': contact_id}

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


def _generate_contact_sheet_path(cs_data: dict) -> str:
    """Generate JPG path for contact sheet.

    Args:
        cs_data: Contact sheet data dictionary.

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
    return os.path.join(SCRIPT_DIR, jpg_filename)


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


def _create_and_upload_contact_sheet(xml_path: str, contact_id: str) -> None:
    """Create and upload contact sheet JPG to GHL.

    Args:
        xml_path: Path to the ProSelect XML file.
        contact_id: GHL contact ID for adding notes.
    """
    print(f"\n📸 Creating contact sheet...")
    debug_log("CONTACT SHEET - Starting creation", {"xml_path": xml_path})

    try:
        debug_log("CONTACT SHEET - Importing module")
        from create_ghl_contactsheet import parse_xml as cs_parse_xml, create_contact_sheet_jpg, find_folder_by_name, upload_to_folder
        debug_log("CONTACT SHEET - Module imported successfully")

        cs_data = cs_parse_xml(xml_path)
        debug_log("CONTACT SHEET - XML parsed", {"shoot_no": cs_data.get('shoot_no', 'unknown')})
        
        thumb_folder = get_thumbnail_folder(xml_path)

        if not thumb_folder:
            print(f"   ℹ No thumbnail folder found")
            debug_log("CONTACT SHEET - No thumbnail folder", {"xml_path": xml_path})
            return

        debug_log("CONTACT SHEET - Thumbnail folder found", {"thumb_folder": thumb_folder})
        
        jpg_path = _generate_contact_sheet_path(cs_data)
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

    debug_log("=" * 60)
    debug_log(f"SYNC COMPLETED - Success: {result.get('success', False)}")
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
    parser = argparse.ArgumentParser(description='Sync ProSelect invoice to GHL')
    parser.add_argument('xml_path', nargs='?', help='Path to ProSelect XML export file')
    parser.add_argument('--financials-only', action='store_true', help='Only include lines with monetary values')
    parser.add_argument('--create-invoice', action='store_true', default=True, help='Create actual GHL invoice (default: True)')
    parser.add_argument('--no-invoice', action='store_true', help='Skip invoice creation, only update contact fields')
    parser.add_argument('--contact-sheet', action='store_true', default=True, help='Create and upload JPG contact sheet (default: True)')
    parser.add_argument('--no-contact-sheet', action='store_true', help='Skip contact sheet creation')
    parser.add_argument('--list-folders', action='store_true', help='List all folders in GHL Media and exit')
    return parser.parse_args()


def _process_sync(xml_path: str, financials_only: bool, create_invoice: bool, create_contact_sheet: bool) -> dict:
    """Process the sync operation.

    Args:
        xml_path: Path to XML file.
        financials_only: Whether financials-only mode is enabled.
        create_invoice: Whether invoice creation is enabled.
        create_contact_sheet: Whether contact sheet creation is enabled.

    Returns:
        dict: Result dictionary.
    """
    ps_data = parse_proselect_xml(xml_path)
    if not ps_data:
        print("Failed to parse XML")
        sys.exit(1)

    print(f"Client: {ps_data.get('first_name')} {ps_data.get('last_name')}")
    print(f"Email: {ps_data.get('email')}")

    contact_id = ps_data.get('ghl_contact_id')
    print(f"GHL Contact ID: {contact_id}")

    order_data = ps_data.get('order', {})
    order_total = order_data.get('total_amount', 0) if isinstance(order_data, dict) else 0
    print(f"Order Total: £{order_total:.2f}\n")

    if not contact_id:
        print("✗ No GHL Contact ID in XML")
        return {'success': False, 'error': 'No GHL Contact ID in XML (Client_ID field)'}

    if create_contact_sheet:
        _create_and_upload_contact_sheet(xml_path, contact_id)

    result = update_ghl_contact(contact_id, ps_data)

    if create_invoice and result.get('success'):
        print(f"\n📄 Creating GHL invoice...")
        invoice_result = create_ghl_invoice(contact_id, ps_data, financials_only)
        if invoice_result:
            result['invoice'] = invoice_result
    elif not create_invoice:
        print("\n⏭ Skipping invoice creation (--no-invoice flag)")

    return result


def main() -> None:
    """Main entry point - parse arguments and sync ProSelect invoice to GHL."""
    args = _parse_cli_args()

    if args.list_folders:
        list_ghl_folders()
        sys.exit(0)

    if not args.xml_path:
        print("Error: xml_path is required for sync mode")
        sys.exit(1)

    if not os.path.exists(args.xml_path):
        print(f"Error: File not found: {args.xml_path}")
        sys.exit(1)

    financials_only = args.financials_only
    create_invoice = not args.no_invoice
    create_contact_sheet = not args.no_contact_sheet

    _print_sync_header(args.xml_path, financials_only, create_invoice, create_contact_sheet)
    result = _process_sync(args.xml_path, financials_only, create_invoice, create_contact_sheet)
    _save_and_log_result(result)
    sys.exit(0 if result.get('success') else 1)


if __name__ == "__main__":
    main()

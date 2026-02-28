"""
GoCardless API Module for SideKick
Copyright (c) 2026 GuyMayer. All rights reserved.
Unauthorized use, modification, or distribution is prohibited.

CLI Usage:
  --check-mandate <email>           Check if customer has active mandate
  --create-billing-request <json>   Create billing request flow for mandate setup
  --test-connection                 Test API connection and return creditor info

Output format: STATUS|field1|field2|...
"""

import sys
import os
import json
import base64
import argparse
import configparser
from datetime import datetime, timedelta
from urllib.parse import quote
from typing import Optional, Dict, Any, List

# =============================================================================
# SCRIPT DIRECTORY - Handle both script and frozen exe
# =============================================================================
if getattr(sys, 'frozen', False):
    SCRIPT_DIR = os.path.dirname(sys.executable)
else:
    SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

# =============================================================================
# DEBUG LOGGING SYSTEM
# =============================================================================

def get_debug_mode_setting() -> bool:
    """Read DebugLogging setting from INI file.

    Defaults to OFF. Auto-disables after 24 hours.
    """
    try:
        possible_paths = [
            os.path.join(SCRIPT_DIR, "SideKick_PS.ini"),
            os.path.join(os.path.dirname(SCRIPT_DIR), "SideKick_PS.ini"),
            os.path.join(os.environ.get('APPDATA', ''), "SideKick_PS", "SideKick_PS.ini"),
            os.path.join(SCRIPT_DIR, "SideKick_LB.ini"),
            os.path.join(os.path.dirname(SCRIPT_DIR), "SideKick_LB.ini"),
            os.path.join(os.environ.get('APPDATA', ''), "SideKick_LB", "SideKick_LB.ini"),
        ]
        for ini_path in possible_paths:
            if os.path.exists(ini_path):
                config = configparser.ConfigParser()
                config.read(ini_path, encoding='utf-8')
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
        return False
    except Exception:
        return False


DEBUG_MODE = get_debug_mode_setting()

# Debug log folder in AppData
DEBUG_LOG_FOLDER = os.path.join(
    os.environ.get('APPDATA', os.path.expanduser("~")), "SideKick_PS", "Logs"
)
os.makedirs(DEBUG_LOG_FOLDER, exist_ok=True)
DEBUG_LOG_FILE = os.path.join(
    DEBUG_LOG_FOLDER, f"gc_debug_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"
)
ERROR_LOG_FILE = os.path.join(
    DEBUG_LOG_FOLDER, f"gc_error_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"
)


def debug_log(message: str, data=None) -> None:
    """Write debug info to log file (only when DEBUG_MODE is on)."""
    if not DEBUG_MODE:
        return
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]
    log_line = f"[{timestamp}] {message}"
    if data is not None:
        if isinstance(data, (dict, list)):
            log_line += f"\n{json.dumps(data, indent=2, default=str)}"
        else:
            log_line += f"\n{data}"
    try:
        with open(DEBUG_LOG_FILE, 'a', encoding='utf-8') as f:
            f.write(log_line + "\n" + "-"*60 + "\n")
    except Exception:
        pass


def error_log(message: str, data=None, exception: Optional[Exception] = None) -> None:
    """Write error to error log file - ALWAYS enabled for critical errors."""
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
    try:
        with open(ERROR_LOG_FILE, 'a', encoding='utf-8') as f:
            f.write(log_line + "\n" + "="*60 + "\n")
    except Exception:
        pass


# =============================================================================
# CONFIGURATION LOADING
# =============================================================================

def _find_ini_file() -> str:
    """Find the SideKick INI file."""
    possible_paths = [
        os.path.join(SCRIPT_DIR, "SideKick_PS.ini"),
        os.path.join(os.path.dirname(SCRIPT_DIR), "SideKick_PS.ini"),
        os.path.join(os.environ.get('APPDATA', ''), "SideKick_PS", "SideKick_PS.ini"),
        # Also check for LB version
        os.path.join(SCRIPT_DIR, "SideKick_LB.ini"),
        os.path.join(os.path.dirname(SCRIPT_DIR), "SideKick_LB.ini"),
        os.path.join(os.environ.get('APPDATA', ''), "SideKick_LB", "SideKick_LB.ini"),
    ]
    for path in possible_paths:
        if os.path.exists(path):
            return path
    raise FileNotFoundError("Could not find SideKick INI file")


def load_config() -> Dict[str, Any]:
    """Load GoCardless configuration from credentials.json and INI file.

    Returns:
        dict: Configuration with gc_token, environment, ghl_api_key, location_id
    """
    debug_log("load_config() called")
    debug_log(f"SCRIPT_DIR: {SCRIPT_DIR}")

    gc_token = ""
    environment = "live"
    ghl_api_key = ""
    location_id = ""

    # Load from credentials.json (primary source for tokens)
    credentials_paths = [
        os.path.join(SCRIPT_DIR, "credentials.json"),
        os.path.join(os.environ.get('APPDATA', ''), "SideKick_PS", "credentials.json"),
        os.path.join(os.environ.get('APPDATA', ''), "SideKick_LB", "credentials.json"),
    ]

    debug_log("Searching for credentials.json in paths:", credentials_paths)

    for cred_path in credentials_paths:
        debug_log(f"Checking path: {cred_path}")
        if os.path.exists(cred_path):
            debug_log(f"Found credentials file: {cred_path}")
            try:
                with open(cred_path, 'r', encoding='utf-8-sig') as f:
                    creds = json.load(f)

                debug_log("Credentials file loaded", {
                    'has_gc_token_b64': bool(creds.get('gc_token_b64')),
                    'has_api_key_b64': bool(creds.get('api_key_b64')),
                    'has_location_id': bool(creds.get('location_id')),
                })

                # GoCardless token
                gc_token_b64 = creds.get('gc_token_b64', '')
                if gc_token_b64:
                    gc_token = base64.b64decode(gc_token_b64).decode('utf-8')
                    debug_log(f"GC token loaded (length: {len(gc_token)})")

                # GHL credentials (for sending emails/SMS)
                api_key_b64 = creds.get('api_key_b64', '')
                if api_key_b64:
                    ghl_api_key = base64.b64decode(api_key_b64).decode('utf-8')

                location_id = creds.get('location_id', '')
                break
            except Exception as e:
                error_log(f"Failed to load credentials from {cred_path}", exception=e)
        else:
            debug_log(f"Path does not exist: {cred_path}")

    # Load environment from INI file
    try:
        ini_path = _find_ini_file()
        debug_log(f"Found INI file: {ini_path}")
        config = configparser.ConfigParser()
        config.read(ini_path, encoding='utf-8')

        if config.has_section('GoCardless'):
            environment = config.get('GoCardless', 'Environment', fallback='live')
            debug_log(f"GC environment from INI: {environment}")
    except Exception as e:
        debug_log(f"INI file error: {e}")

    if not gc_token:
        error_log("No GoCardless token found in any credentials.json")
        raise ValueError("No GoCardless token found in credentials.json")

    debug_log("Config loaded successfully", {
        'environment': environment,
        'has_gc_token': bool(gc_token),
        'has_ghl_api_key': bool(ghl_api_key),
        'location_id': location_id,
    })

    return {
        'gc_token': gc_token,
        'environment': environment,
        'ghl_api_key': ghl_api_key,
        'location_id': location_id,
    }


def get_api_url(environment: str) -> str:
    """Get GoCardless API URL based on environment."""
    if environment == "live":
        return "https://api.gocardless.com"
    return "https://api-sandbox.gocardless.com"


# =============================================================================
# HTTP REQUESTS
# =============================================================================

def gc_request(method: str, endpoint: str, token: str, environment: str,
               data: Optional[dict] = None, timeout: int = 30) -> Dict[str, Any]:
    """Make a request to GoCardless API.

    Args:
        method: HTTP method (GET, POST, etc.)
        endpoint: API endpoint path
        token: GoCardless API token
        environment: "sandbox" or "live"
        data: JSON body for POST requests
        timeout: Request timeout in seconds

    Returns:
        dict: Response JSON or error dict
    """
    import urllib.request
    import urllib.error

    url = get_api_url(environment) + endpoint
    headers = {
        'Authorization': f'Bearer {token}',
        'GoCardless-Version': '2015-07-06',
        'Content-Type': 'application/json',
    }

    debug_log(f"gc_request: {method} {url}")
    debug_log(f"Token (first 20 chars): {token[:20]}..." if len(token) > 20 else f"Token: {token}")
    if data:
        debug_log("Request body:", data)

    body = json.dumps(data).encode('utf-8') if data else None

    try:
        req = urllib.request.Request(url, data=body, headers=headers, method=method)
        debug_log("Sending request...")
        with urllib.request.urlopen(req, timeout=timeout) as response:
            response_data = response.read().decode('utf-8')
            debug_log(f"Response status: {response.status}")
            result = json.loads(response_data)
            debug_log("Response data:", result)
            return result
    except urllib.error.HTTPError as e:
        error_body = ""
        try:
            error_body = e.read().decode('utf-8')
            error_data = json.loads(error_body)
            error_msg = error_data.get('error', {}).get('message', str(e))
        except Exception:
            error_msg = f"{e.code} {e.reason}: {error_body[:200]}" if error_body else f"{e.code} {e.reason}"
        error_log(f"HTTPError: {method} {url}", {
            'status_code': e.code,
            'reason': e.reason,
            'body': error_body[:500] if error_body else None,
        })
        return {'error': error_msg, 'status_code': e.code}
    except urllib.error.URLError as e:
        error_log(f"URLError: {method} {url}", {'reason': str(e.reason)})
        return {'error': f"Connection error: {e.reason}"}
    except Exception as e:
        error_log(f"Exception in gc_request: {method} {url}", exception=e)
        return {'error': str(e)}


# =============================================================================
# GOCARDLESS API FUNCTIONS
# =============================================================================

def test_connection(token: str, environment: str) -> Dict[str, Any]:
    """Test GoCardless API connection.

    Returns:
        dict: {success: bool, creditor_name: str, creditor_id: str, error: str}
    """
    result = gc_request('GET', '/creditors', token, environment)

    if 'error' in result:
        return {'success': False, 'error': result['error']}

    creditors = result.get('creditors', [])
    if not creditors:
        return {'success': False, 'error': 'No creditors found'}

    creditor = creditors[0]
    return {
        'success': True,
        'creditor_name': creditor.get('name', 'Unknown'),
        'creditor_id': creditor.get('id', ''),
    }


def check_customer_mandate(email: str, token: str, environment: str) -> Dict[str, Any]:
    """Check if a customer has an active mandate.

    Args:
        email: Customer email address
        token: GoCardless API token
        environment: "sandbox" or "live"

    Returns:
        dict: {has_mandate: bool, mandate_id: str, mandate_status: str,
               bank_name: str, customer_id: str, error: str}
    """
    debug_log(f"check_customer_mandate called for email: {email}")

    result = {
        'has_mandate': False,
        'mandate_id': '',
        'mandate_status': '',
        'bank_name': '',
        'customer_id': '',
        'error': '',
    }

    # Step 1: Find customer by email (fetch all and filter locally - API doesn't support email filter)
    debug_log(f"Step 1: Finding customer by email: {email}")
    customers_resp = gc_request('GET', '/customers', token, environment)

    if 'error' in customers_resp:
        error_log(f"Failed to get customers: {customers_resp['error']}")
        result['error'] = customers_resp['error']
        return result

    all_customers = customers_resp.get('customers', [])
    debug_log(f"Total customers in GoCardless: {len(all_customers)}")

    # Filter locally by email (case-insensitive)
    customers = [c for c in all_customers if c.get('email', '').lower() == email.lower()]
    debug_log(f"Found {len(customers)} customer(s) matching email")

    if not customers:
        debug_log("No customer found with this email")
        return result

    customer_id = customers[0].get('id', '')
    result['customer_id'] = customer_id
    debug_log(f"Customer ID: {customer_id}")

    # Step 2: Get mandates for this customer
    debug_log(f"Step 2: Getting mandates for customer {customer_id}")
    mandates_resp = gc_request('GET', f'/mandates?customer={customer_id}', token, environment)

    if 'error' in mandates_resp:
        error_log(f"Failed to get mandates: {mandates_resp['error']}")
        result['error'] = mandates_resp['error']
        return result

    mandates = mandates_resp.get('mandates', [])
    debug_log(f"Found {len(mandates)} mandate(s)")
    if not mandates:
        debug_log("Customer exists but has no mandates")
        return result

    # Step 3: Find active mandate
    debug_log("Step 3: Looking for active mandate")
    active_statuses = ['active', 'pending_submission', 'submitted']
    for mandate in mandates:
        mandate_status = mandate.get('status')
        debug_log(f"Mandate {mandate.get('id')}: status={mandate_status}")
        if mandate_status in active_statuses:
            result['has_mandate'] = True
            result['mandate_id'] = mandate.get('id', '')
            result['mandate_status'] = mandate_status

            # Try to get bank account name
            bank_account_id = mandate.get('links', {}).get('customer_bank_account', '')
            if bank_account_id:
                debug_log(f"Getting bank account details: {bank_account_id}")
                bank_resp = gc_request('GET', f'/customer_bank_accounts/{bank_account_id}',
                                       token, environment, timeout=10)
                if 'error' not in bank_resp:
                    bank_accounts = bank_resp.get('customer_bank_accounts', {})
                    # Handle both list and single object response
                    if isinstance(bank_accounts, list) and bank_accounts:
                        result['bank_name'] = bank_accounts[0].get('bank_name', 'Bank account')
                    elif isinstance(bank_accounts, dict):
                        result['bank_name'] = bank_accounts.get('bank_name', 'Bank account')
                    else:
                        result['bank_name'] = 'Bank account'

            return result

    # No active mandate found
    return result


def check_customer_mandate_by_name(name: str, token: str, environment: str) -> Dict[str, Any]:
    """Check if a customer has an active mandate by searching by name.

    Args:
        name: Customer name to search for (partial match)
        token: GoCardless API token
        environment: "sandbox" or "live"

    Returns:
        dict: {has_mandate: bool, mandate_id: str, mandate_status: str,
               bank_name: str, customer_id: str, customer_name: str, error: str}
    """
    debug_log(f"check_customer_mandate_by_name called for name: {name}")

    result = {
        'has_mandate': False,
        'mandate_id': '',
        'mandate_status': '',
        'bank_name': '',
        'customer_id': '',
        'customer_name': '',
        'customer_email': '',
        'error': '',
    }

    # Fetch all customers
    debug_log(f"Fetching all customers to search for name: {name}")
    customers_resp = gc_request('GET', '/customers', token, environment)

    if 'error' in customers_resp:
        error_log(f"Failed to get customers: {customers_resp['error']}")
        result['error'] = customers_resp['error']
        return result

    all_customers = customers_resp.get('customers', [])
    debug_log(f"Total customers in GoCardless: {len(all_customers)}")

    # Search by name (case-insensitive partial match)
    search_lower = name.lower()
    matching_customers = []
    for c in all_customers:
        full_name = f"{c.get('given_name', '')} {c.get('family_name', '')}".strip()
        if search_lower in full_name.lower():
            matching_customers.append(c)
            debug_log(f"Match found: {full_name} ({c.get('email', 'no email')})")

    if not matching_customers:
        debug_log("No customer found matching name")
        return result

    # Use first match
    customer = matching_customers[0]
    customer_id = customer.get('id', '')
    result['customer_id'] = customer_id
    result['customer_name'] = f"{customer.get('given_name', '')} {customer.get('family_name', '')}".strip()
    result['customer_email'] = customer.get('email', '')
    debug_log(f"Using customer: {result['customer_name']} (ID: {customer_id})")

    # Get mandates for this customer
    debug_log(f"Getting mandates for customer {customer_id}")
    mandates_resp = gc_request('GET', f'/mandates?customer={customer_id}', token, environment)

    if 'error' in mandates_resp:
        error_log(f"Failed to get mandates: {mandates_resp['error']}")
        result['error'] = mandates_resp['error']
        return result

    mandates = mandates_resp.get('mandates', [])
    debug_log(f"Found {len(mandates)} mandate(s)")
    if not mandates:
        debug_log("Customer exists but has no mandates")
        return result

    # Find active mandate
    active_statuses = ['active', 'pending_submission', 'submitted']
    for mandate in mandates:
        mandate_status = mandate.get('status')
        debug_log(f"Mandate {mandate.get('id')}: status={mandate_status}")
        if mandate_status in active_statuses:
            result['has_mandate'] = True
            result['mandate_id'] = mandate.get('id', '')
            result['mandate_status'] = mandate_status

            # Try to get bank account name
            bank_account_id = mandate.get('links', {}).get('customer_bank_account', '')
            if bank_account_id:
                debug_log(f"Getting bank account details: {bank_account_id}")
                bank_resp = gc_request('GET', f'/customer_bank_accounts/{bank_account_id}',
                                       token, environment, timeout=10)
                if 'error' not in bank_resp:
                    bank_accounts = bank_resp.get('customer_bank_accounts', {})
                    if isinstance(bank_accounts, list) and bank_accounts:
                        result['bank_name'] = bank_accounts[0].get('bank_name', 'Bank account')
                    elif isinstance(bank_accounts, dict):
                        result['bank_name'] = bank_accounts.get('bank_name', 'Bank account')
                    else:
                        result['bank_name'] = 'Bank account'

            return result

    # No active mandate found
    return result


def create_billing_request_flow(contact_data: dict, token: str, environment: str,
                                ghl_api_key: str = '', location_id: str = '') -> Dict[str, Any]:
    """Create a billing request flow for mandate setup.

    Args:
        contact_data: {email, first_name, last_name, phone, contact_id}
        token: GoCardless API token
        environment: "sandbox" or "live"
        ghl_api_key: GHL API key for sending notifications
        location_id: GHL location ID

    Returns:
        dict: {success: bool, flow_url: str, billing_request_id: str, error: str}
    """
    result = {
        'success': False,
        'flow_url': '',
        'billing_request_id': '',
        'error': '',
    }

    email = contact_data.get('email', '')
    first_name = contact_data.get('first_name', '')
    last_name = contact_data.get('last_name', '')

    if not email:
        result['error'] = 'No email address provided'
        return result

    # Step 1: Create billing request
    # Don't specify scheme - let GoCardless auto-detect based on customer's bank country
    # This enables international support: BACS (UK), BECS (AU), SEPA (EU), ACH (US), PAD (CA)
    billing_request_data = {
        'billing_requests': {
            'mandate_request': {},  # Auto-detect scheme from customer's bank
        }
    }

    br_resp = gc_request('POST', '/billing_requests', token, environment, billing_request_data)

    if 'error' in br_resp:
        result['error'] = f"Failed to create billing request: {br_resp['error']}"
        return result

    billing_request = br_resp.get('billing_requests', {})
    billing_request_id = billing_request.get('id', '')

    if not billing_request_id:
        result['error'] = 'No billing request ID returned'
        return result

    result['billing_request_id'] = billing_request_id

    # Step 2: Create billing request flow
    flow_data = {
        'billing_request_flows': {
            'redirect_uri': 'https://example.com/mandate-complete',
            'exit_uri': 'https://example.com/mandate-exit',
            'links': {
                'billing_request': billing_request_id,
            },
            'prefilled_customer': {
                'email': email,
                'given_name': first_name,
                'family_name': last_name,
            },
        }
    }

    flow_resp = gc_request('POST', '/billing_request_flows', token, environment, flow_data)

    if 'error' in flow_resp:
        result['error'] = f"Failed to create flow: {flow_resp['error']}"
        return result

    flow = flow_resp.get('billing_request_flows', {})
    flow_url = flow.get('authorisation_url', '')

    if not flow_url:
        result['error'] = 'No authorisation URL returned'
        return result

    result['success'] = True
    result['flow_url'] = flow_url

    return result


def list_mandates_without_plans(token: str, environment: str, progress_file: Optional[str] = None) -> List[Dict[str, Any]]:
    """List all active mandates that have NEVER had any payment plans.

    This excludes mandates that have any subscriptions/plans (even finished ones),
    to find mandates where no payment arrangement was ever set up.

    Args:
        token: GoCardless API token
        environment: "sandbox" or "live"
        progress_file: Optional path to write progress updates for GUI polling

    Returns:
        list: List of mandate dicts with {mandate_id, customer_name, email, created_at, bank_name}
    """
    debug_log("list_mandates_without_plans called")

    def write_progress(current: int, total: int, message: str = ""):
        """Write progress to file for GUI to poll."""
        if progress_file:
            try:
                with open(progress_file, 'w', encoding='utf-8') as f:
                    f.write(f"{current}|{total}|{message}")
            except Exception:
                pass

    results = []

    write_progress(0, 100, "Fetching mandates...")

    # Get all active mandates
    mandates_resp = gc_request('GET', '/mandates?status=active', token, environment, timeout=30)
    if 'error' in mandates_resp:
        error_log(f"Failed to get mandates: {mandates_resp['error']}")
        return results

    mandates = mandates_resp.get('mandates', [])
    total = len(mandates)
    debug_log(f"Found {total} active mandates")

    write_progress(0, total, f"Checking {total} mandates...")

    # Cache customer info to avoid repeated lookups
    customer_cache = {}

    for idx, mandate in enumerate(mandates):
        mandate_id = mandate.get('id', '')
        customer_id = mandate.get('links', {}).get('customer', '')
        bank_account_id = mandate.get('links', {}).get('customer_bank_account', '')

        write_progress(idx + 1, total, f"Checking {idx + 1}/{total}...")

        # Check if this mandate has EVER had any plans (including finished/cancelled)
        plans = list_mandate_subscriptions(mandate_id, token, environment)

        # Exclude if ANY subscription/plan exists (even finished ones)
        # We only want mandates where NO payment arrangement was ever set up
        if len(plans) > 0:
            debug_log(f"Mandate {mandate_id} has {len(plans)} plans (any status) - skipping")
            continue

        # Get customer info
        if customer_id not in customer_cache:
            cust_resp = gc_request('GET', f'/customers/{customer_id}', token, environment, timeout=10)
            if 'error' not in cust_resp:
                cust = cust_resp.get('customers', {})
                customer_cache[customer_id] = {
                    'name': f"{cust.get('given_name', '')} {cust.get('family_name', '')}".strip(),
                    'email': cust.get('email', ''),
                }
            else:
                customer_cache[customer_id] = {'name': 'Unknown', 'email': ''}

        customer = customer_cache[customer_id]

        # Get bank name
        bank_name = ''
        if bank_account_id:
            bank_resp = gc_request('GET', f'/customer_bank_accounts/{bank_account_id}', token, environment, timeout=10)
            if 'error' not in bank_resp:
                bank = bank_resp.get('customer_bank_accounts', {})
                bank_name = bank.get('bank_name', '')

        results.append({
            'mandate_id': mandate_id,
            'customer_id': customer_id,
            'customer_name': customer['name'],
            'email': customer['email'],
            'created_at': mandate.get('created_at', '')[:10],  # Just date part
            'bank_name': bank_name,
        })

        debug_log(f"Mandate {mandate_id} ({customer['name']}) has no plans")

    debug_log(f"Found {len(results)} mandates without plans")
    return results


def list_mandate_subscriptions(mandate_id: str, token: str, environment: str) -> List[Dict[str, Any]]:
    """List all subscriptions, instalment schedules, AND one-off payments for a mandate.

    Args:
        mandate_id: GoCardless mandate ID
        token: GoCardless API token
        environment: "sandbox" or "live"

    Returns:
        list: List of subscription/schedule/payment dicts with {id, name, status, amount, type}
    """
    debug_log(f"list_mandate_subscriptions called for mandate: {mandate_id}")

    results = []

    # Query subscriptions
    resp = gc_request('GET', f'/subscriptions?mandate={mandate_id}', token, environment, timeout=15)
    if 'error' not in resp:
        subs_list = resp.get('subscriptions', [])
        for sub in subs_list:
            results.append({
                'id': sub.get('id', ''),
                'name': sub.get('name', ''),
                'status': sub.get('status', ''),
                'amount': sub.get('amount', 0),
                'type': 'subscription',
            })
        debug_log(f"Found {len(subs_list)} subscriptions")

    # Query instalment schedules (payment plans)
    resp2 = gc_request('GET', f'/instalment_schedules?mandate={mandate_id}', token, environment, timeout=15)
    if 'error' not in resp2:
        schedules = resp2.get('instalment_schedules', [])
        for sched in schedules:
            results.append({
                'id': sched.get('id', ''),
                'name': sched.get('name', ''),
                'status': sched.get('status', ''),
                'amount': sched.get('total_amount', 0),
                'type': 'instalment',
            })
        debug_log(f"Found {len(schedules)} instalment schedules")

    # Query one-off payments (those not linked to subscription or instalment schedule)
    resp3 = gc_request('GET', f'/payments?mandate={mandate_id}', token, environment, timeout=15)
    if 'error' not in resp3:
        payments = resp3.get('payments', [])
        # Track IDs we've already seen from other sources
        seen_payment_ids = set()
        for payment in payments:
            links = payment.get('links', {})
            # Skip if linked to a subscription or instalment schedule (already counted)
            if links.get('subscription') or links.get('instalment_schedule'):
                continue
            payment_id = payment.get('id', '')
            if payment_id in seen_payment_ids:
                continue
            seen_payment_ids.add(payment_id)
            results.append({
                'id': payment_id,
                'name': payment.get('description', '') or payment.get('reference', '') or payment_id,
                'status': payment.get('status', ''),
                'amount': payment.get('amount', 0),
                'type': 'one-off',
            })
        debug_log(f"Found {len(seen_payment_ids)} one-off payments")

    debug_log(f"Total items found: {len(results)}")
    return results


def get_unique_plan_name(base_name: str, mandate_id: str, token: str, environment: str) -> str:
    """Get a unique plan name by adding suffix if needed.

    If "P26001-Smith" exists, returns "P26001-Smith-1", then "-2", etc.

    Args:
        base_name: The desired plan name
        mandate_id: GoCardless mandate ID
        token: GoCardless API token
        environment: "sandbox" or "live"

    Returns:
        str: Unique plan name (base_name or base_name-N)
    """
    existing = list_mandate_subscriptions(mandate_id, token, environment)
    existing_names = [s['name'] for s in existing]

    # Check if base name is available
    if base_name not in existing_names:
        return base_name

    # Find next available suffix
    suffix = 1
    while True:
        candidate = f"{base_name}-{suffix}"
        if candidate not in existing_names:
            debug_log(f"Name '{base_name}' exists, using '{candidate}'")
            return candidate
        suffix += 1
        if suffix > 100:  # Safety limit
            break

    return f"{base_name}-{suffix}"


def create_instalment_schedule(schedule_data: dict, token: str, environment: str) -> Dict[str, Any]:
    """Create an instalment schedule (payment plan) against an existing mandate.

    Args:
        schedule_data: {
            mandate_id: str,           # Required: GoCardless mandate ID
            total_amount: int,         # Total amount for all payments in pence (preferred)
            amount: int,               # Amount per payment in pence (legacy - used to calculate total)
            currency: str,             # Currency code (default: GBP)
            name: str,                 # Name for the schedule
            day_of_month: int,         # 1-28 or -1 for last day
            count: int,                # Number of payments
            metadata: dict,            # Optional metadata
        }
        token: GoCardless API token
        environment: "sandbox" or "live"

    Returns:
        dict: {success: bool, schedule_id: str, error: str, payments: list, name: str}

    Note: GoCardless automatically handles rounding - it will adjust the first payment
    to account for any rounding differences when dividing total_amount by count.
    """
    debug_log("create_instalment_schedule called", schedule_data)

    result = {
        'success': False,
        'schedule_id': '',
        'name': '',
        'error': '',
        'payments': [],
    }

    mandate_id = schedule_data.get('mandate_id', '')
    name = schedule_data.get('name', 'Payment Plan')
    count = schedule_data.get('count', 1)
    day_of_month = schedule_data.get('day_of_month', 15)

    # Support both total_amount (preferred) and amount (legacy per-payment)
    total_amount = schedule_data.get('total_amount', 0)
    if not total_amount:
        amount_per_payment = schedule_data.get('amount', 0)
        if amount_per_payment > 0:
            total_amount = amount_per_payment * count

    if not mandate_id:
        result['error'] = 'No mandate ID provided'
        return result

    if not total_amount or total_amount <= 0:
        result['error'] = 'Invalid amount'
        return result

    if count < 1:
        result['error'] = 'Count must be at least 1'
        return result

    # Get unique name (adds -1, -2 suffix if name already exists)
    unique_name = get_unique_plan_name(name, mandate_id, token, environment)
    if unique_name != name:
        debug_log(f"Plan name '{name}' already exists, using '{unique_name}'")

    # Calculate payment dates (GoCardless will calculate the amounts)
    from datetime import date, timedelta
    import calendar

    today = date.today()
    payment_dates = []

    # Start from next month
    year = today.year
    month = today.month + 1
    if month > 12:
        month = 1
        year += 1

    for i in range(count):
        # Handle day_of_month = -1 (last day of month)
        if day_of_month == -1:
            last_day = calendar.monthrange(year, month)[1]
            charge_day = last_day
        else:
            # Ensure day doesn't exceed month length
            last_day = calendar.monthrange(year, month)[1]
            charge_day = min(day_of_month, last_day)

        charge_date = date(year, month, charge_day)
        payment_dates.append(charge_date.isoformat())

        # Move to next month
        month += 1
        if month > 12:
            month = 1
            year += 1

    # Calculate amount per instalment with rounding
    # Put any remainder on the first payment
    amount_per_payment = total_amount // count
    remainder = total_amount - (amount_per_payment * count)

    # Build instalments array with amounts
    instalments = []
    for i, d in enumerate(payment_dates):
        # First payment gets the remainder to ensure total matches exactly
        amount = amount_per_payment + remainder if i == 0 else amount_per_payment
        instalments.append({'charge_date': d, 'amount': amount})

    # Build instalment schedule request
    schedule_request = {
        'instalment_schedules': {
            'name': unique_name,
            'total_amount': total_amount,  # Integer in pence
            'currency': schedule_data.get('currency', 'GBP'),
            'instalments': instalments,
            'links': {
                'mandate': mandate_id,
            },
        }
    }

    if schedule_data.get('metadata'):
        schedule_request['instalment_schedules']['metadata'] = schedule_data['metadata']

    debug_log("Creating instalment schedule", schedule_request)

    resp = gc_request('POST', '/instalment_schedules', token, environment, schedule_request)

    if 'error' in resp:
        error_log(f"Failed to create instalment schedule: {resp['error']}")
        result['error'] = resp['error']
        return result

    schedule = resp.get('instalment_schedules', {})
    schedule_id = schedule.get('id', '')

    if not schedule_id:
        result['error'] = 'No schedule ID returned'
        return result

    result['success'] = True
    result['schedule_id'] = schedule_id
    result['name'] = unique_name
    result['payments'] = instalments  # Use the instalments we already built

    debug_log("Instalment schedule created successfully", result)
    return result


def create_payment(payment_data: dict, token: str, environment: str) -> Dict[str, Any]:
    """Create a single payment against an existing mandate.

    Args:
        payment_data: {
            mandate_id: str,           # Required: GoCardless mandate ID
            amount: int,               # Amount in pence (e.g., 5000 = £50.00)
            currency: str,             # Currency code (default: GBP)
            description: str,          # Description for the payment
            charge_date: str,          # ISO date for payment (YYYY-MM-DD)
            metadata: dict,            # Optional metadata
        }
        token: GoCardless API token
        environment: "sandbox" or "live"

    Returns:
        dict: {success: bool, payment_id: str, charge_date: str, error: str}
    """
    debug_log("create_payment called", payment_data)

    result = {
        'success': False,
        'payment_id': '',
        'charge_date': '',
        'error': '',
    }

    mandate_id = payment_data.get('mandate_id', '')
    amount = payment_data.get('amount', 0)

    if not mandate_id:
        result['error'] = 'No mandate ID provided'
        return result

    if not amount or amount <= 0:
        result['error'] = 'Invalid amount'
        return result

    # Build payment request
    pay_data = {
        'payments': {
            'amount': str(amount),
            'currency': payment_data.get('currency', 'GBP'),
            'links': {
                'mandate': mandate_id,
            },
        }
    }

    if payment_data.get('description'):
        pay_data['payments']['description'] = payment_data['description']

    if payment_data.get('charge_date'):
        pay_data['payments']['charge_date'] = payment_data['charge_date']

    if payment_data.get('metadata'):
        pay_data['payments']['metadata'] = payment_data['metadata']

    debug_log("Creating payment", pay_data)

    pay_resp = gc_request('POST', '/payments', token, environment, pay_data)

    if 'error' in pay_resp:
        error_log(f"Failed to create payment: {pay_resp['error']}")
        result['error'] = pay_resp['error']
        return result

    payment = pay_resp.get('payments', {})
    payment_id = payment.get('id', '')

    if not payment_id:
        result['error'] = 'No payment ID returned'
        return result

    result['success'] = True
    result['payment_id'] = payment_id
    result['charge_date'] = payment.get('charge_date', '')

    debug_log("Payment created successfully", result)
    return result


def create_payment_plan(plan_data: dict, token: str, environment: str) -> Dict[str, Any]:
    """Create a payment plan with optional single payments + recurring subscription.

    Args:
        plan_data: {
            mandate_id: str,               # Required
            name: str,                     # Plan name
            single_payments: [             # Optional: list of single payments
                {amount: int, charge_date: str, description: str},
                ...
            ],
            subscription: {                # Optional: recurring payments
                amount: int,
                count: int,
                day_of_month: int,
            }
        }

    Returns:
        dict: {success: bool, payment_ids: list, subscription_id: str, error: str, summary: str}
    """
    debug_log("create_payment_plan called", plan_data)

    result = {
        'success': False,
        'payment_ids': [],
        'subscription_id': '',
        'error': '',
        'summary': '',
    }

    mandate_id = plan_data.get('mandate_id', '')
    name = plan_data.get('name', 'Payment Plan')

    if not mandate_id:
        result['error'] = 'No mandate ID provided'
        return result

    created_payments = []
    subscription_info = None

    # Create single payments first
    single_payments = plan_data.get('single_payments', [])
    for i, sp in enumerate(single_payments):
        pay_result = create_payment({
            'mandate_id': mandate_id,
            'amount': sp.get('amount', 0),
            'charge_date': sp.get('charge_date', ''),
            'description': sp.get('description', f"{name} - Payment {i+1}"),
        }, token, environment)

        if pay_result['error']:
            result['error'] = f"Failed on payment {i+1}: {pay_result['error']}"
            # Return what we created before failure
            result['payment_ids'] = created_payments
            return result

        created_payments.append({
            'id': pay_result['payment_id'],
            'date': pay_result['charge_date'],
            'amount': sp.get('amount', 0),
        })

    result['payment_ids'] = created_payments

    # Create instalment schedule if specified
    schedule_data = plan_data.get('subscription', {}) or plan_data.get('instalment', {})
    # Check for amount OR total_amount (new preferred method)
    has_schedule = schedule_data and (schedule_data.get('amount', 0) > 0 or schedule_data.get('total_amount', 0) > 0)
    if has_schedule:
        schedule_result = create_instalment_schedule({
            'mandate_id': mandate_id,
            'amount': schedule_data.get('amount', 0),
            'total_amount': schedule_data.get('total_amount', 0),
            'name': name,
            'count': schedule_data.get('count'),
            'day_of_month': schedule_data.get('day_of_month', 15),
        }, token, environment)

        if schedule_result['error']:
            result['error'] = f"Single payments created, but instalment schedule failed: {schedule_result['error']}"
            return result

        result['schedule_id'] = schedule_result['schedule_id']
        subscription_info = {
            'id': schedule_result['schedule_id'],
            'payments': schedule_result.get('payments', []),
        }

    # Build summary
    summary_parts = []
    if created_payments:
        total_single = sum(p['amount'] for p in created_payments)
        summary_parts.append(f"{len(created_payments)} single payment(s): £{total_single/100:.2f}")
    if subscription_info:
        sub_count = len(subscription_info['payments'])
        summary_parts.append(f"Subscription: {sub_count} recurring payment(s)")

    result['success'] = True
    result['summary'] = " + ".join(summary_parts) if summary_parts else "No payments created"

    debug_log("Payment plan created successfully", result)
    return result


# =============================================================================
# CLI INTERFACE
# =============================================================================

def main() -> None:
    """Main CLI entry point."""
    is_frozen = getattr(sys, 'frozen', False)

    if is_frozen:
        parser = argparse.ArgumentParser(add_help=False)
    else:
        parser = argparse.ArgumentParser(
            description='GoCardless API integration for SideKick',
            formatter_class=argparse.RawDescriptionHelpFormatter,
            epilog="""
Examples:
  %(prog)s --test-connection
  %(prog)s --check-mandate user@example.com
  %(prog)s --create-billing-request '{"email": "user@example.com", "first_name": "John"}'
            """
        )

    parser.add_argument('--test-connection', action='store_true',
                        help='Test API connection and return creditor info')
    parser.add_argument('--check-mandate', type=str, metavar='EMAIL',
                        help='Check if customer has active mandate')
    parser.add_argument('--check-mandate-by-name', type=str, metavar='NAME',
                        help='Check if customer has active mandate by searching name')
    parser.add_argument('--create-billing-request', type=str, metavar='JSON',
                        help='Create billing request flow (JSON: email, first_name, last_name)')
    parser.add_argument('--create-instalment', type=str, metavar='JSON',
                        help='Create instalment schedule (JSON: mandate_id, amount, name, count, day_of_month)')
    parser.add_argument('--create-instalment-file', type=str, metavar='FILE',
                        help='Create instalment schedule from JSON file')
    parser.add_argument('--create-payment', type=str, metavar='JSON',
                        help='Create single payment (JSON: mandate_id, amount, charge_date, description)')
    parser.add_argument('--create-payment-plan', type=str, metavar='JSON',
                        help='Create mixed plan with single payments + instalment schedule')
    parser.add_argument('--create-payment-plan-file', type=str, metavar='FILE',
                        help='Create mixed plan from JSON file')
    parser.add_argument('--list-plans', type=str, metavar='MANDATE_ID',
                        help='List active instalment schedules for a mandate')
    parser.add_argument('--list-empty-mandates', action='store_true',
                        help='List all active mandates with no payment plans')
    parser.add_argument('--progress-file', type=str, metavar='PATH',
                        help='File path for progress updates (GUI polling)')
    parser.add_argument('--live', action='store_true',
                        help='Use live environment instead of sandbox')

    args = parser.parse_args()

    debug_log(f"gocardless_api.py started - DEBUG_MODE={DEBUG_MODE}")
    debug_log(f"Command line args: {sys.argv}")
    debug_log(f"Parsed args: test_connection={args.test_connection}, "
              f"check_mandate={args.check_mandate}, "
              f"create_billing_request={args.create_billing_request}")

    # Load configuration
    try:
        config = load_config()
    except Exception as e:
        error_log(f"Failed to load config: {e}", exception=e)
        print(f"ERROR|{e}")
        sys.exit(1)

    gc_token = config['gc_token']
    environment = config['environment']

    # Override environment if --live flag is passed
    if args.live:
        environment = 'live'
        debug_log("Environment overridden to 'live' via --live flag")

    debug_log(f"Using environment: {environment}")

    # Handle commands
    if args.test_connection:
        debug_log("Executing --test-connection")
        result = test_connection(gc_token, environment)
        debug_log("test_connection result:", result)
        if result['success']:
            print(f"SUCCESS|{result['creditor_name']}|{result['creditor_id']}")
        else:
            print(f"ERROR|{result['error']}")

    elif args.check_mandate:
        debug_log(f"Executing --check-mandate for: {args.check_mandate}")
        result = check_customer_mandate(args.check_mandate, gc_token, environment)
        debug_log("check_customer_mandate result:", result)
        if result['error']:
            print(f"ERROR|{result['error']}")
        elif result['has_mandate']:
            # Also fetch existing subscriptions/schedules/payments for this mandate
            subs = list_mandate_subscriptions(result['mandate_id'], gc_token, environment)
            # Show all meaningful plans: active, pending, completed, and relevant payment states
            # Exclude: cancelled, errored (failed setup), failed payments
            valid_statuses = ('active', 'pending', 'completed', 'finished',
                              'pending_submission', 'submitted', 'confirmed', 'paid_out')
            active_subs = [s for s in subs if s['status'] in valid_statuses]
            sub_info = ""
            if active_subs:
                type_labels = {'subscription': 'Sub', 'instalment': 'Plan', 'one-off': '1x'}
                sub_names = [f"{type_labels.get(s['type'], s['type'])}: {s['name']} (£{int(s['amount'])/100:.2f})" for s in active_subs]
                sub_info = "; ".join(sub_names)
            print(f"MANDATE_FOUND|{result['customer_id']}|{result['mandate_id']}|"
                  f"{result['mandate_status']}|{result['bank_name']}|{sub_info}")
        elif result['customer_id']:
            print(f"NO_MANDATE|{result['customer_id']}")
        else:
            print("NO_CUSTOMER")

    elif getattr(args, 'check_mandate_by_name', None):
        debug_log(f"Executing --check-mandate-by-name for: {args.check_mandate_by_name}")
        result = check_customer_mandate_by_name(args.check_mandate_by_name, gc_token, environment)
        debug_log("check_customer_mandate_by_name result:", result)
        if result['error']:
            print(f"ERROR|{result['error']}")
        elif result['has_mandate']:
            # Also fetch existing subscriptions/schedules/payments for this mandate
            subs = list_mandate_subscriptions(result['mandate_id'], gc_token, environment)
            valid_statuses = ('active', 'pending', 'completed', 'finished',
                              'pending_submission', 'submitted', 'confirmed', 'paid_out')
            active_subs = [s for s in subs if s['status'] in valid_statuses]
            sub_info = ""
            if active_subs:
                type_labels = {'subscription': 'Sub', 'instalment': 'Plan', 'one-off': '1x'}
                sub_names = [f"{type_labels.get(s['type'], s['type'])}: {s['name']} (£{int(s['amount'])/100:.2f})" for s in active_subs]
                sub_info = "; ".join(sub_names)
            # Include customer name and email in the response for name-based searches
            print(f"MANDATE_FOUND|{result['customer_id']}|{result['mandate_id']}|"
                  f"{result['mandate_status']}|{result['bank_name']}|{sub_info}|"
                  f"{result['customer_name']}|{result['customer_email']}")
        elif result['customer_id']:
            print(f"NO_MANDATE|{result['customer_id']}|{result['customer_name']}|{result['customer_email']}")
        else:
            print("NO_CUSTOMER")

    elif args.list_plans:
        debug_log(f"Executing --list-plans for mandate: {args.list_plans}")
        plans = list_mandate_subscriptions(args.list_plans, gc_token, environment)
        if not plans:
            print("NO_PLANS")
        else:
            for p in plans:
                # Format: id|name|status|amount_pence|type
                print(f"{p['id']}|{p['name']}|{p['status']}|{p['amount']}|{p['type']}")

    elif args.list_empty_mandates:
        debug_log("Executing --list-empty-mandates")
        mandates = list_mandates_without_plans(gc_token, environment, args.progress_file)
        if not mandates:
            print("NO_EMPTY_MANDATES")
        else:
            for m in mandates:
                # Format: mandate_id|customer_id|customer_name|email|created_at|bank_name
                print(f"{m['mandate_id']}|{m['customer_id']}|{m['customer_name']}|{m['email']}|{m['created_at']}|{m['bank_name']}")

    elif args.create_billing_request:
        debug_log(f"Executing --create-billing-request")
        try:
            contact_data = json.loads(args.create_billing_request)
            debug_log("Parsed contact data:", contact_data)
        except json.JSONDecodeError as e:
            error_log(f"Invalid JSON in --create-billing-request: {e}")
            print(f"ERROR|Invalid JSON: {e}")
            sys.exit(1)

        result = create_billing_request_flow(
            contact_data, gc_token, environment,
            config.get('ghl_api_key', ''), config.get('location_id', '')
        )
        debug_log("create_billing_request_flow result:", result)

        if result['success']:
            print(f"SUCCESS|{result['billing_request_id']}|{result['flow_url']}")
        else:
            print(f"ERROR|{result['error']}")

    elif args.create_instalment or args.create_instalment_file:
        debug_log("Executing --create-instalment")
        try:
            if args.create_instalment_file:
                with open(args.create_instalment_file, 'r', encoding='utf-8') as f:
                    json_str = f.read()
                schedule_data = json.loads(json_str)
            else:
                schedule_data = json.loads(args.create_instalment)
            debug_log("Parsed schedule data:", schedule_data)
        except json.JSONDecodeError as e:
            error_log(f"Invalid JSON in --create-instalment: {e}")
            print(f"ERROR|Invalid JSON: {e}")
            sys.exit(1)
        except FileNotFoundError as e:
            error_log(f"JSON file not found: {e}")
            print(f"ERROR|File not found: {e}")
            sys.exit(1)

        result = create_instalment_schedule(schedule_data, gc_token, environment)
        debug_log("create_instalment_schedule result:", result)

        if result['success']:
            # Format: SUCCESS|schedule_id|name|payment_count|first_date|last_date
            payments = result.get('payments', [])
            first_date = payments[0]['charge_date'] if payments else ''
            last_date = payments[-1]['charge_date'] if payments else ''
            plan_name = result.get('name', '')
            print(f"SUCCESS|{result['schedule_id']}|{plan_name}|{len(payments)}|{first_date}|{last_date}")
        else:
            print(f"ERROR|{result['error']}")

    elif args.create_payment:
        debug_log("Executing --create-payment")
        try:
            payment_data = json.loads(args.create_payment)
            debug_log("Parsed payment data:", payment_data)
        except json.JSONDecodeError as e:
            error_log(f"Invalid JSON in --create-payment: {e}")
            print(f"ERROR|Invalid JSON: {e}")
            sys.exit(1)

        result = create_payment(payment_data, gc_token, environment)
        debug_log("create_payment result:", result)

        if result['success']:
            print(f"SUCCESS|{result['payment_id']}|{result['charge_date']}")
        else:
            print(f"ERROR|{result['error']}")

    elif args.create_payment_plan or args.create_payment_plan_file:
        debug_log("Executing --create-payment-plan")
        try:
            if args.create_payment_plan_file:
                with open(args.create_payment_plan_file, 'r', encoding='utf-8') as f:
                    json_str = f.read()
                plan_data = json.loads(json_str)
            else:
                plan_data = json.loads(args.create_payment_plan)
            debug_log("Parsed plan data:", plan_data)
        except json.JSONDecodeError as e:
            error_log(f"Invalid JSON in --create-payment-plan: {e}")
            print(f"ERROR|Invalid JSON: {e}")
            sys.exit(1)
        except FileNotFoundError as e:
            error_log(f"JSON file not found: {e}")
            print(f"ERROR|File not found: {e}")
            sys.exit(1)

        result = create_payment_plan(plan_data, gc_token, environment)
        debug_log("create_payment_plan result:", result)

        if result['success']:
            payment_ids = ",".join([p['id'] for p in result.get('payment_ids', [])])
            schedule_id = result.get('schedule_id', '')
            print(f"SUCCESS|{payment_ids}|{schedule_id}|{result['summary']}")
        else:
            print(f"ERROR|{result['error']}")

    else:
        parser.print_help()
        sys.exit(1)

    debug_log("gocardless_api.py completed")


if __name__ == '__main__':
    try:
        main()
    except SystemExit:
        raise
    except Exception as e:
        # Last-resort crash handler - ensures SOME output reaches AHK
        try:
            error_log(f"FATAL unhandled exception in main(): {e}", exception=e)
        except Exception:
            pass
        print(f"ERROR|Unexpected error: {e}")
        sys.exit(1)

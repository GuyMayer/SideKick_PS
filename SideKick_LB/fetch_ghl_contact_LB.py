"""
GHL Contact Fetcher Module
Copyright (c) 2026 GuyMayer. All rights reserved.
Unauthorized use, modification, or distribution is prohibited.
"""

import subprocess
import sys
import json
import re
import os
import traceback
import base64
from datetime import datetime

# Auto-install dependencies
def install_dependencies():
    required = ['requests']
    for package in required:
        try:
            __import__(package)
        except ImportError:
            subprocess.check_call([sys.executable, '-m', 'pip', 'install', package, '-q'])

install_dependencies()
import requests

ERROR_LOG_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'ghl_error_log.txt')
MAX_LOG_SIZE_KB = 500  # Rotate log if it exceeds this size

def _get_script_dir():
    """Get script directory (handles both .py and compiled .exe)."""
    if getattr(sys, 'frozen', False):
        return os.path.dirname(sys.executable)
    return os.path.dirname(os.path.abspath(__file__))

def _decode_api_key(encoded: str) -> str:
    """Decode base64-encoded API key."""
    try:
        cleaned = encoded.strip().replace('\n', '').replace('\r', '').replace(' ', '')
        return base64.b64decode(cleaned).decode('utf-8')
    except Exception:
        return ""

def _load_api_key() -> str:
    """Load API_KEY from ghl_credentials.json."""
    script_dir = _get_script_dir()
    possible_paths = [
        os.path.join(script_dir, "ghl_credentials.json"),
        os.path.join(os.path.dirname(script_dir), "ghl_credentials.json"),
        os.path.join(os.environ.get('APPDATA', ''), "SideKick_LB", "ghl_credentials.json"),
    ]
    
    for cred_path in possible_paths:
        if os.path.exists(cred_path):
            try:
                with open(cred_path, 'r', encoding='utf-8') as f:
                    content = f.read()
                api_match = re.search(r'"api_key_b64"\s*:\s*"([^"]+)"', content)
                if api_match:
                    return _decode_api_key(api_match.group(1))
            except Exception:
                continue
    return ''


def log_error(operation: str, error_msg: str, context: dict = None, response=None):
    """
    Log errors to a persistent file for client troubleshooting.
    
    Args:
        operation: What action was being attempted (e.g., 'fetch_contact')
        error_msg: The error message
        context: Dict with relevant context (contact_id, etc.)
        response: Optional requests.Response object for API errors
    """
    try:
        # Build log entry
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        log_entry = []
        log_entry.append(f"\n{'='*60}")
        log_entry.append(f"[{timestamp}] ERROR: {operation}")
        log_entry.append(f"Message: {error_msg}")
        
        if context:
            # Mask API key if present
            safe_context = context.copy()
            if 'api_key' in safe_context:
                safe_context['api_key'] = safe_context['api_key'][:10] + '...' if safe_context['api_key'] else ''
            log_entry.append(f"Context: {json.dumps(safe_context, indent=2)}")
        
        if response is not None:
            log_entry.append(f"HTTP Status: {response.status_code}")
            log_entry.append(f"Response: {response.text[:500]}")
        
        # Add stack trace for exceptions
        exc_info = sys.exc_info()
        if exc_info[0] is not None:
            log_entry.append("Stack Trace:")
            log_entry.append(traceback.format_exc())
        
        log_entry.append(f"{'='*60}\n")
        
        # Rotate log if too large
        if os.path.exists(ERROR_LOG_FILE):
            file_size_kb = os.path.getsize(ERROR_LOG_FILE) / 1024
            if file_size_kb > MAX_LOG_SIZE_KB:
                # Keep last half of log
                with open(ERROR_LOG_FILE, 'r', encoding='utf-8') as f:
                    content = f.read()
                with open(ERROR_LOG_FILE, 'w', encoding='utf-8') as f:
                    f.write(content[len(content)//2:])
        
        # Append to log
        with open(ERROR_LOG_FILE, 'a', encoding='utf-8') as f:
            f.write('\n'.join(log_entry))
            
    except Exception:
        pass  # Don't let logging errors break the main flow


# API key can be passed as second parameter, otherwise load from credentials
_cred_api_key = _load_api_key()
API_KEY = sys.argv[2] if len(sys.argv) > 2 else _cred_api_key

def format_uk_postcode(postcode):
    """Format UK postcode to proper format (e.g., 'SW1A 1AA')"""
    if not postcode:
        return ''
    
    # Remove all spaces and convert to uppercase
    postcode = re.sub(r'\s+', '', postcode).upper()
    
    # UK postcode patterns
    # Format: AA9A 9AA, A9A 9AA, A9 9AA, A99 9AA, AA9 9AA, AA99 9AA
    patterns = [
        (r'^([A-Z]{1,2})(\d{1,2})([A-Z])(\d[A-Z]{2})$', r'\1\2\3 \4'),  # SW1A1AA -> SW1A 1AA
        (r'^([A-Z]{1,2})(\d{1,2})(\d[A-Z]{2})$', r'\1\2 \3'),            # SW1A1AA -> SW1A 1AA
    ]
    
    for pattern, replacement in patterns:
        if re.match(pattern, postcode):
            return re.sub(pattern, replacement, postcode)
    
    # If no pattern matches but looks like a postcode, add space before last 3 chars
    if len(postcode) >= 5 and re.match(r'^[A-Z0-9]+$', postcode):
        return f"{postcode[:-3]} {postcode[-3:]}"
    
    return postcode

def capitalize_name(name):
    """Properly capitalize names (handles Mc, Mac, O', etc.)"""
    if not name:
        return ''
    
    # Basic title case
    name = name.strip().title()
    
    # Handle special prefixes
    name = re.sub(r"\bMc([a-z])", lambda m: f"Mc{m.group(1).upper()}", name)
    name = re.sub(r"\bMac([a-z])", lambda m: f"Mac{m.group(1).upper()}", name)
    name = re.sub(r"\bO'([a-z])", lambda m: f"O'{m.group(1).upper()}", name)
    
    return name

def format_address(address):
    """Format address with proper capitalization"""
    if not address:
        return ''
    
    # Title case for address
    address = address.strip().title()
    
    # Keep common abbreviations uppercase
    replacements = {
        'Uk': 'UK',
        'Usa': 'USA',
        'Po Box': 'PO Box',
        'P.o. Box': 'PO Box',
    }
    
    for old, new in replacements.items():
        address = re.sub(rf'\b{old}\b', new, address, flags=re.IGNORECASE)
    
    return address

def extract_contact_id(url_or_id):
    """Extract contact ID from URL or return ID directly"""
    if not url_or_id:
        return None
    
    # If it's already just an ID (alphanumeric string)
    if re.match(r'^[A-Za-z0-9]{20,}$', url_or_id):
        return url_or_id
    
    # Extract from full URL
    match = re.search(r'/contacts/detail/([A-Za-z0-9]+)', url_or_id)
    if match:
        return match.group(1)
    
    # Extract from any string containing the ID pattern
    match = re.search(r'([A-Za-z0-9]{20,})', url_or_id)
    if match:
        return match.group(1)
    
    return None

def fetch_contact(contact_id):
    """Fetch contact data from GHL API"""
    url = f"https://rest.gohighlevel.com/v1/contacts/{contact_id}"
    headers = {
        "Authorization": f"Bearer {API_KEY}",
        "Content-Type": "application/json",
        "Version": "2021-07-28"
    }
    
    try:
        response = requests.get(url, headers=headers, timeout=10)
        
        if response.status_code == 200:
            data = response.json()
            contact = data.get('contact', data)
            
            # Extract and format fields
            first_name = capitalize_name(contact.get('firstName', ''))
            last_name = capitalize_name(contact.get('lastName', ''))
            full_name = contact.get('name') or f"{first_name} {last_name}".strip()
            full_name = capitalize_name(full_name)
            
            # Extract fields needed for ProSelect
            result = {
                'success': True,
                'name': full_name,
                'firstName': first_name,
                'lastName': last_name,
                'email': contact.get('email', '').lower().strip(),
                'phone': contact.get('phone', '').strip(),
                'address1': format_address(contact.get('address1', '')),
                'city': capitalize_name(contact.get('city', '')),
                'state': contact.get('state', '').strip(),
                'postalCode': format_uk_postcode(contact.get('postalCode', '')),
                'country': contact.get('country', '').strip(),
                'dateOfBirth': contact.get('dateOfBirth', ''),
                'source': contact.get('source', ''),
                'tags': contact.get('tags', []),
                'customFields': {}
            }
            
            # Parse custom fields into readable format
            for field in contact.get('customField', []):
                field_id = field.get('id')
                field_value = field.get('value')
                result['customFields'][field_id] = field_value
            
            return result
        else:
            log_error('fetch_contact', f"API returned status {response.status_code}", 
                      {'contact_id': contact_id}, response)
            return {
                'success': False,
                'error': f"API returned status {response.status_code}",
                'message': response.text[:200]
            }
            
    except Exception as e:
        log_error('fetch_contact', str(e), {'contact_id': contact_id})
        return {
            'success': False,
            'error': str(e)
        }

def main():
    if len(sys.argv) < 2:
        print(json.dumps({
            'success': False,
            'error': 'No contact ID provided',
            'usage': 'python fetch_ghl_contact_LB.py <contact_id_or_url>'
        }))
        sys.exit(1)
    
    input_param = sys.argv[1]
    contact_id = extract_contact_id(input_param)
    
    if not contact_id:
        print(json.dumps({
            'success': False,
            'error': 'Could not extract contact ID from input',
            'input': input_param
        }))
        sys.exit(1)
    
    result = fetch_contact(contact_id)
    
    # Output JSON for AHK to parse
    print(json.dumps(result, indent=2))
    
    # Also save to file for backup
    output_file = "ghl_contact_data.json"
    with open(output_file, 'w') as f:
        json.dump(result, f, indent=2)
    
    sys.exit(0 if result['success'] else 1)

if __name__ == "__main__":
    main()

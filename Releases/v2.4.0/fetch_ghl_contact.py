"""
GHL Contact Fetcher - Standalone utility for AutoHotkey integration
Author: GuyMayer
Date: 2025-12-01
Usage: python fetch_ghl_contact.py <contact_id>
"""

import subprocess
import sys
import json
import re

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

# API key can be passed as second parameter, otherwise use default
API_KEY = sys.argv[2] if len(sys.argv) > 2 else "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJsb2NhdGlvbl9pZCI6IjhJV3hrNU0wUHZiTmYxdzNucFFVIiwiY29tcGFueV9pZCI6IkpKQWJIa2lBaFRxNVBaQ3J1OXpOIiwidmVyc2lvbiI6MSwiaWF0IjoxNjgxMzk0NDQwMjg3LCJzdWIiOiJ6YXBpZXIifQ.t0hyU-M2PNLyBuo1dYTQmkmZHBKLiacNt8kZbeprZms"

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
            return {
                'success': False,
                'error': f"API returned status {response.status_code}",
                'message': response.text[:200]
            }
            
    except Exception as e:
        return {
            'success': False,
            'error': str(e)
        }

def main():
    if len(sys.argv) < 2:
        print(json.dumps({
            'success': False,
            'error': 'No contact ID provided',
            'usage': 'python fetch_ghl_contact.py <contact_id_or_url>'
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

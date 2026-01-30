"""
ProSelect Invoice Sync to GHL v2 - Create native GHL invoices from PS XML exports
Author: GuyMayer  
Date: 2026-01-29
Usage: python sync_ps_invoice_v2.py <xml_file_path>
Example: python sync_ps_invoice_v2.py "C:/Users/guy/OneDrive/Documents/Proselect Order Exports/2026-01-27_180030_P26008P__1.xml"

Features:
- Creates native GHL invoices (not just custom fields)
- Parses ProSelect XML order exports
- Links invoice to GHL contact by email
- Supports payment schedules from ProSelect
- Full analytics via GHL reporting
- All config loaded from SideKick_PS.ini (encrypted tokens)
"""

import subprocess
import sys
import json
import os
import xml.etree.ElementTree as ET
from datetime import datetime, timedelta

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

def notes_plus(string: str, delimiters: str) -> str:
    """Encrypt string using XOR - matches Notes_Plus() in AHK"""
    result = []
    delim_pos = 0
    for char in string:
        xor_val = ord(char) ^ ord(delimiters[delim_pos % len(delimiters)])
        result.append(chr(xor_val + 15000))
        delim_pos += 1
    return ''.join(result)

# =============================================================================
# Load Configuration from INI
# =============================================================================
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
INI_FILE = os.path.join(SCRIPT_DIR, 'SideKick_PS.ini')
OUTPUT_FILE = os.path.join(SCRIPT_DIR, 'ghl_invoice_sync_result.json')

# Encryption key (same as Client_Notes in AHK)
ENCRYPT_KEY = "ZoomPhotography2026"

def load_config():
    """Load configuration from INI file (handles malformed multi-line values)"""
    config = {}
    current_section = None
    
    with open(INI_FILE, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith(';'):
                continue
            if line.startswith('[') and line.endswith(']'):
                current_section = line[1:-1]
                config[current_section] = {}
            elif '=' in line and current_section:
                key, value = line.split('=', 1)
                config[current_section][key.strip()] = value.strip()
    
    if 'GHL' not in config:
        raise ValueError(f"[GHL] section not found in {INI_FILE}")
    
    ghl = config['GHL']
    
    # Decrypt API keys
    v1_enc = ghl.get('API_Key_V1_Enc', '')
    v2_enc = ghl.get('API_Key_V2_Enc', '')
    
    if not v1_enc or not v2_enc:
        raise ValueError("Encrypted API keys not found in INI file")
    
    return {
        'API_KEY_V1': notes_minus(v1_enc, ENCRYPT_KEY),
        'API_KEY_V2': notes_minus(v2_enc, ENCRYPT_KEY),
        'LOCATION_ID': ghl.get('LocationID', ''),
        'ENABLED': ghl.get('Enabled', '1') == '1',
        'AUTO_FETCH': ghl.get('AutoFetch', '0') == '1',
    }

# Load config on import
try:
    CONFIG = load_config()
    API_KEY_V1 = CONFIG['API_KEY_V1']
    API_KEY_V2 = CONFIG['API_KEY_V2']
    LOCATION_ID = CONFIG['LOCATION_ID']
except Exception as e:
    print(f"⚠ Config Error: {e}")
    print(f"  Ensure {INI_FILE} exists with [GHL] section and encrypted keys")
    API_KEY_V1 = ""
    API_KEY_V2 = ""
    LOCATION_ID = ""

BASE_URL_V2 = "https://services.leadconnectorhq.com"
BASE_URL_V1 = "https://rest.gohighlevel.com/v1"

# Custom Field IDs (loaded from INI or defaults)
CUSTOM_FIELDS = {
    'session_job_no': '82WRQe9Rl6o8uJQ8cgZV',
    'session_status': 'rcBTBSNw75gA0BOaVPEr',
    'session_date': 'j2lMRPMOYHIxapnz5qDK',
}


def get_headers_v2():
    """Get headers for GHL v2 API"""
    return {
        "Authorization": f"Bearer {API_KEY_V2}",
        "Content-Type": "application/json",
        "Version": "2021-07-28"
    }


def get_headers_v1():
    """Get headers for GHL v1 API"""
    return {
        "Authorization": f"Bearer {API_KEY_V1}",
        "Content-Type": "application/json"
    }


def parse_proselect_xml(xml_path: str) -> dict | None:
    """Parse ProSelect XML export and extract order data"""
    
    try:
        tree = ET.parse(xml_path)
        root = tree.getroot()
        
        # Extract client info
        data: dict = {
            'client_id': get_text(root, 'Client_ID'),
            'email': get_text(root, 'Email_Address'),
            'first_name': get_text(root, 'First_Name'),
            'last_name': get_text(root, 'Last_Name'),
            'phone': get_text(root, 'Cell_Phone'),
            'album_name': get_text(root, 'Album_Name'),
            'album_path': get_text(root, 'Album_Path'),
            'address': {
                'line1': get_text(root, 'Address_Line_1'),
                'line2': get_text(root, 'Address_Line_2'),
                'city': get_text(root, 'City'),
                'state': get_text(root, 'State'),
                'postal_code': get_text(root, 'Postal_Code'),
                'country': get_text(root, 'Country') or 'GB'
            }
        }
        
        # Extract order info
        order = root.find('Order')
        if order is not None:
            items_list: list = []
            payments_list: list = []
            
            # Parse ordered items - VAT handled by ProSelect
            for item in order.findall('.//Ordered_Item'):
                price = float(get_text(item, 'Extended_Price', '0'))
                
                # Get tax info as ProSelect provides it
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
            
            # Parse payments/payment schedule
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
            
            # Calculate VAT summary
            total_vat = sum(item['vat_amount'] for item in items_list)
            total_ex_vat = data['order']['total_amount'] - total_vat
            
            data['order']['vat'] = {
                'total_vat': total_vat,
                'total_ex_vat': total_ex_vat,
            }
        
        return data
        
    except Exception as e:
        print(f"✗ Error parsing XML: {e}")
        return None


def get_text(element, tag, default=''):
    """Safely get text from XML element"""
    child = element.find(tag)
    return child.text if child is not None and child.text else default


def find_ghl_contact(email: str | None, phone: str | None = None) -> dict | None:
    """Find GHL contact by email using v2 API, fallback to v1"""
    
    if not email:
        return None
    
    # Try v2 API first
    try:
        url = f"{BASE_URL_V2}/contacts/search"
        params = {
            "locationId": LOCATION_ID,
            "query": email
        }
        response = requests.get(url, headers=get_headers_v2(), params=params)
        
        if response.status_code == 200:
            contacts = response.json().get('contacts', [])
            if contacts:
                print(f"✓ Found contact via v2 API: {email}")
                return contacts[0]
    except Exception as e:
        print(f"  v2 search failed: {e}")
    
    # Fallback to v1 API
    try:
        url = f"{BASE_URL_V1}/contacts/"
        params = {"email": email}
        response = requests.get(url, headers=get_headers_v1(), params=params)
        
        if response.status_code == 200:
            contacts = response.json().get('contacts', [])
            if contacts:
                print(f"✓ Found contact via v1 API: {email}")
                return contacts[0]
    except Exception as e:
        print(f"  v1 search failed: {e}")
    
    print(f"✗ Contact not found: {email}")
    return None


def create_ghl_invoice(contact: dict, ps_data: dict) -> dict | None:
    """Create a native GHL invoice from ProSelect order data"""
    
    order = ps_data.get('order', {})
    items = order.get('items', [])
    
    if not items:
        print("✗ No items in order")
        return None
    
    # Build invoice items for GHL
    invoice_items = []
    for item in items:
        ghl_item = {
            "name": item['description'] or item['product'] or "Product",
            "amount": item['price'],
            "qty": item['quantity'],
            "currency": "GBP",
            "taxInclusive": item['taxable'],  # VAT already in price if taxable
        }
        
        # Add tax if applicable
        if item['vat_amount'] > 0:
            ghl_item["taxes"] = [{
                "name": "VAT",
                "rate": 20,  # UK VAT rate
                "amount": item['vat_amount']
            }]
        
        invoice_items.append(ghl_item)
    
    # Calculate due date (last payment date or 30 days from now)
    payments = order.get('payments', [])
    if payments:
        due_date = payments[-1].get('date', '')
        if due_date:
            due_date = f"{due_date}T23:59:59.999Z"
        else:
            due_date = (datetime.now() + timedelta(days=30)).strftime("%Y-%m-%dT23:59:59.999Z")
    else:
        due_date = (datetime.now() + timedelta(days=30)).strftime("%Y-%m-%dT23:59:59.999Z")
    
    issue_date = order.get('date', datetime.now().strftime("%Y-%m-%d"))
    if issue_date and 'T' not in issue_date:
        issue_date = f"{issue_date}T00:00:00.000Z"
    
    # Build invoice payload
    invoice_payload = {
        "altId": LOCATION_ID,
        "altType": "location",
        "name": f"ProSelect Order - {ps_data['first_name']} {ps_data['last_name']}",
        "contactDetails": {
            "id": contact.get('id'),
            "name": f"{ps_data['first_name']} {ps_data['last_name']}",
            "email": ps_data['email'],
            "phoneNo": ps_data.get('phone', ''),
            "address": {
                "addressLine1": ps_data['address'].get('line1', ''),
                "city": ps_data['address'].get('city', ''),
                "state": ps_data['address'].get('state', ''),
                "postalCode": ps_data['address'].get('postal_code', ''),
                "countryCode": ps_data['address'].get('country', 'GB')
            }
        },
        "currency": "GBP",
        "issueDate": issue_date,
        "dueDate": due_date,
        "invoiceItems": invoice_items,
        "termsNotes": f"ProSelect Order ID: {ps_data['client_id']}\nAlbum: {ps_data.get('album_name', 'N/A')}",
        "title": "INVOICE"
    }
    
    # Create invoice via v2 API
    try:
        url = f"{BASE_URL_V2}/invoices/"
        response = requests.post(url, headers=get_headers_v2(), json=invoice_payload)
        
        if response.status_code in [200, 201]:
            invoice = response.json().get('invoice', response.json())
            print(f"✓ Created GHL invoice: {invoice.get('invoiceNumber', 'N/A')}")
            return invoice
        else:
            print(f"✗ Failed to create invoice: {response.status_code}")
            print(f"  Response: {response.text[:500]}")
            return None
            
    except Exception as e:
        print(f"✗ Error creating invoice: {e}")
        return None


def record_deposit_payment(invoice_id: str, deposit_amount: float) -> bool:
    """Record deposit payment on invoice"""
    
    if deposit_amount <= 0:
        return True
    
    try:
        url = f"{BASE_URL_V2}/invoices/{invoice_id}/record-payment"
        payload = {
            "altId": LOCATION_ID,
            "altType": "location",
            "amount": deposit_amount,
            "mode": "cash",  # External payment from ProSelect
            "notes": "Deposit paid via ProSelect"
        }
        
        response = requests.post(url, headers=get_headers_v2(), json=payload)
        
        if response.status_code in [200, 201]:
            print(f"✓ Recorded deposit payment: £{deposit_amount:.2f}")
            return True
        else:
            print(f"✗ Failed to record payment: {response.status_code}")
            return False
            
    except Exception as e:
        print(f"✗ Error recording payment: {e}")
        return False


def send_invoice(invoice_id: str, email: str) -> bool:
    """Send invoice to client via email"""
    
    try:
        url = f"{BASE_URL_V2}/invoices/{invoice_id}/send"
        payload = {
            "altId": LOCATION_ID,
            "altType": "location",
            "sendTo": {
                "email": [email]
            }
        }
        
        response = requests.post(url, headers=get_headers_v2(), json=payload)
        
        if response.status_code in [200, 201]:
            print(f"✓ Invoice sent to: {email}")
            return True
        else:
            print(f"✗ Failed to send invoice: {response.status_code}")
            print(f"  Response: {response.text[:300]}")
            return False
            
    except Exception as e:
        print(f"✗ Error sending invoice: {e}")
        return False


def update_contact_status(contact_id: str, ps_data: dict, invoice: dict):
    """Update contact custom fields with order status"""
    
    order = ps_data.get('order', {})
    payments = order.get('payments', [])
    total = order.get('total_amount', 0)
    
    # Determine status
    if not payments:
        status = "Paid in Full"
    else:
        scheduled = sum(p['amount'] for p in payments)
        deposit = total - scheduled
        if deposit > 0:
            status = "Deposit Paid - Awaiting Balance"
        else:
            status = "Payment Plan Active"
    
    # Update via v1 API (custom fields)
    try:
        url = f"{BASE_URL_V1}/contacts/{contact_id}"
        payload = {
            "customFields": [
                {"id": CUSTOM_FIELDS['session_job_no'], "value": ps_data['client_id']},
                {"id": CUSTOM_FIELDS['session_status'], "value": status},
                {"id": CUSTOM_FIELDS['session_date'], "value": order.get('date', '')},
            ]
        }
        
        response = requests.put(url, headers=get_headers_v1(), json=payload)
        
        if response.status_code == 200:
            print(f"✓ Updated contact status: {status}")
        else:
            print(f"✗ Failed to update contact: {response.status_code}")
            
    except Exception as e:
        print(f"✗ Error updating contact: {e}")


def is_image_number_line(item: dict) -> bool:
    """
    Check if an item is just an image number line (not financial).
    Returns True for lines like "001", "002", "IMG_1234", etc.
    that have no monetary value and are just image references.
    """
    description = item.get('description', '') or ''
    product = item.get('product', '') or ''
    price = item.get('price', 0)
    
    # If it has a price > 0, it's a financial line
    if price > 0:
        return False
    
    # Check description for pure numeric patterns (image numbers)
    # Matches: "001", "002", "123", "1234", etc. (3+ digits)
    import re
    text = description.strip() or product.strip()
    
    # Pure numeric string of 3+ digits = image number
    if re.match(r'^\d{3,}$', text):
        return True
    
    # IMG_### pattern
    if re.match(r'^IMG[_-]?\d+$', text, re.IGNORECASE):
        return True
    
    # DSC_### pattern (camera naming)
    if re.match(r'^DSC[_-]?\d+$', text, re.IGNORECASE):
        return True
    
    # If empty text with no price, skip it
    if not text and price == 0:
        return True
    
    # Otherwise it's likely a comment or valid line
    return False


def filter_items_financials_only(items: list) -> list:
    """
    Filter items to include only:
    - Lines with monetary value (price > 0)
    - Comment/text lines (non-numeric descriptions)
    Excludes image number lines.
    """
    filtered = []
    for item in items:
        if not is_image_number_line(item):
            filtered.append(item)
    return filtered


def main():
    if len(sys.argv) < 2:
        print("Usage: python sync_ps_invoice_v2.py <xml_file_path> [contact_id] [--financials-only]")
        print("Example: python sync_ps_invoice_v2.py \"C:/path/to/order.xml\"")
        print("         python sync_ps_invoice_v2.py \"C:/path/to/order.xml\" --financials-only")
        sys.exit(1)
    
    # Parse arguments
    xml_path = sys.argv[1]
    financials_only = '--financials-only' in sys.argv
    
    # Optional contact_id override (for when called from GHL page)
    contact_id_override = None
    for arg in sys.argv[2:]:
        if not arg.startswith('--') and len(arg) > 10:
            contact_id_override = arg
    
    if not os.path.exists(xml_path):
        print(f"Error: File not found: {xml_path}")
        sys.exit(1)
    
    print(f"\n{'='*70}")
    print(f"ProSelect Invoice → GHL v2 Native Invoice Sync")
    print(f"{'='*70}")
    print(f"XML File: {os.path.basename(xml_path)}\n")
    
    # Step 1: Parse XML
    ps_data = parse_proselect_xml(xml_path)
    if not ps_data:
        print("Failed to parse XML")
        sys.exit(1)
    
    order = ps_data.get('order', {})
    original_items = order.get('items', [])
    
    # Apply financials-only filter if enabled
    if financials_only:
        filtered_items = filter_items_financials_only(original_items)
        order['items'] = filtered_items
        print(f"Financials Only Mode: Filtered {len(original_items)} → {len(filtered_items)} items")
    
    order_total = order.get('total_amount', 0)
    
    print(f"Client: {ps_data.get('first_name')} {ps_data.get('last_name')}")
    print(f"Email: {ps_data.get('email')}")
    print(f"Client ID: {ps_data.get('client_id')}")
    print(f"Order Total: £{order_total:.2f}")
    print(f"Items: {len(order.get('items', []))}")
    print(f"Payments Scheduled: {len(order.get('payments', []))}\n")
    
    # Step 2: Find GHL contact
    contact = find_ghl_contact(ps_data.get('email'), ps_data.get('phone'))
    if not contact:
        result = {
            'success': False, 
            'error': 'Contact not found in GHL',
            'email': ps_data.get('email')
        }
    else:
        contact_id = contact.get('id')
        if not contact_id:
            result = {'success': False, 'error': 'Contact ID not found'}
        else:
            # Step 3: Create GHL Invoice
            invoice = create_ghl_invoice(contact, ps_data)
            
            if invoice:
                invoice_id = invoice.get('_id')
                
                # Step 4: Record deposit if any (total - scheduled payments)
                payments = order.get('payments', [])
                if payments and invoice_id:
                    scheduled_total = sum(p['amount'] for p in payments)
                    deposit = order_total - scheduled_total
                    if deposit > 0:
                        record_deposit_payment(invoice_id, deposit)
                
                # Step 5: Update contact status
                update_contact_status(contact_id, ps_data, invoice)
                
                # Step 6: Optionally send invoice (commented out - enable if wanted)
                # send_invoice(invoice_id, ps_data.get('email'))
                
                result = {
                    'success': True,
                    'contact_id': contact_id,
                    'invoice_id': invoice_id,
                    'invoice_number': invoice.get('invoiceNumber'),
                    'client_id': ps_data['client_id'],
                    'email': ps_data['email'],
                    'order_total': order_total,
                    'items_count': len(order.get('items', [])),
                    'payments_scheduled': len(payments),
                    'status': 'Invoice Created'
                }
                
                print(f"\n{'='*70}")
                print(f"✓ SUCCESS - Invoice #{invoice.get('invoiceNumber')} created")
                print(f"  Invoice ID: {invoice_id}")
                print(f"  Total: £{order_total:.2f}")
                print(f"  Amount Due: £{invoice.get('amountDue', order_total):.2f}")
            else:
                result = {
                    'success': False,
                    'error': 'Failed to create invoice',
                    'contact_id': contact_id
                }
    
    # Save result
    with open(OUTPUT_FILE, 'w', encoding='utf-8') as f:
        json.dump(result, f, indent=2)
    
    print(f"\nResult saved to: {OUTPUT_FILE}")
    print(f"{'='*70}\n")
    
    sys.exit(0 if result.get('success') else 1)


if __name__ == "__main__":
    main()

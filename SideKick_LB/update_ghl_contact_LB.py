"""
GHL Contact Updater - Push shoot data from Light Blue to GHL
Author: AI Assistant
Date: 2026-01-20
Usage: python update_ghl_contact_LB.py <contact_id> <api_key> <status> <notes> [shoot_no]

Updates GHL contact custom fields with Light Blue shoot data.
"""

import subprocess
import sys
import json
import os
import traceback
from datetime import datetime
from typing import Any

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

OUTPUT_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'ghl_update_result.json')
ERROR_LOG_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'ghl_error_log.txt')
MAX_LOG_SIZE_KB = 500  # Rotate log if it exceeds this size


def log_error(operation: str, error_msg: str, context: dict = None, response=None):
    """
    Log errors to a persistent file for client troubleshooting.
    
    Args:
        operation: What action was being attempted (e.g., 'update_contact', 'update_photo')
        error_msg: The error message
        context: Dict with relevant context (contact_id, fields being updated, etc.)
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

# GHL Custom Field IDs - Mapped from GHL account
CUSTOM_FIELDS = {
    'session_status': 'rcBTBSNw75gA0BOaVPEr',   # Session Status
    'session_date': 'j2lMRPMOYHIxapnz5qDK',     # Session Date
    'session_time': '2dqbEITXitttBHAA34xF',     # Session Time
    'appointment_datetime': 'w3VFlvpZdhXjoXJgrQwa',  # Appointment Date Time
    'session_job_no': '82WRQe9Rl6o8uJQ8cgZV',   # Session Job No
    'session_story': 'OWAex2i3JCVDty7ZHTDz',    # Session Story / Notes
    'lb_service': 'kMrAeqwPzZOyDiya4HKn',       # LB Service
    'job_numbers': 'n2tZIF2N3d7bLbBlBeZ6',      # All Job Numbers
    'contact_photo_link': 'FvzCW7qdPl6Dsy1LIgCs' # Contact Photo Link
}

def update_contact(contact_id, api_key, status, notes, shoot_no="", session_date="", session_time="", email="", phone="", address1="", city="", postal_code=""):
    """Update GHL contact with shoot data"""
    
    url = f"https://rest.gohighlevel.com/v1/contacts/{contact_id}"
    
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
        "Version": "2021-07-28"
    }
    
    # Build update payload
    # Note: Custom fields in GHL API v1 are updated via customField array
    # Email, phone, and address are top-level contact fields
    from datetime import datetime
    
    update_data: dict[str, Any] = {
        "customField": {}
    }
    
    # Add email if provided (top-level field, not custom field)
    if email:
        update_data["email"] = email
    
    # Add phone if provided (top-level field, not custom field)
    if phone:
        update_data["phone"] = phone
    
    # Add address fields if provided (top-level fields)
    if address1:
        update_data["address1"] = address1
    if city:
        update_data["city"] = city
    if postal_code:
        update_data["postalCode"] = postal_code
    
    # Add session status
    if status:
        update_data["customField"][CUSTOM_FIELDS['session_status']] = status
    
    # Add session notes/story
    if notes:
        update_data["customField"][CUSTOM_FIELDS['session_story']] = notes
    
    # Add shoot/job number
    if shoot_no:
        update_data["customField"][CUSTOM_FIELDS['session_job_no']] = shoot_no
    
    # Add session date
    if session_date:
        update_data["customField"][CUSTOM_FIELDS['session_date']] = session_date
        # Also update combined datetime if we have both
        if session_time:
            update_data["customField"][CUSTOM_FIELDS['appointment_datetime']] = f"{session_date} {session_time}"
    
    # Add session time
    if session_time:
        update_data["customField"][CUSTOM_FIELDS['session_time']] = session_time
    
    try:
        response = requests.put(url, headers=headers, json=update_data, timeout=15)
        
        if response.status_code == 200:
            return {
                'success': True,
                'message': 'Contact updated successfully',
                'contact_id': contact_id,
                'updated_fields': {
                    'status': status,
                    'notes': notes[:100] + '...' if len(notes) > 100 else notes,
                    'shoot_no': shoot_no,
                    'session_date': session_date,
                    'session_time': session_time,
                    'email': email,
                    'phone': phone
                }
            }
        else:
            log_error('update_contact', f"API returned status {response.status_code}", 
                      {'contact_id': contact_id, 'status': status, 'shoot_no': shoot_no}, response)
            return {
                'success': False,
                'error': f"API returned status {response.status_code}",
                'message': response.text[:300],
                'contact_id': contact_id
            }
            
    except requests.exceptions.Timeout:
        log_error('update_contact', 'Request timed out', {'contact_id': contact_id, 'status': status})
        return {
            'success': False,
            'error': 'Request timed out',
            'contact_id': contact_id
        }
    except Exception as e:
        log_error('update_contact', str(e), {'contact_id': contact_id, 'status': status})
        return {
            'success': False,
            'error': str(e),
            'contact_id': contact_id
        }


def update_photo_link(contact_id, api_key, photo_url, field_id=None):
    """Update GHL contact's photo link field only"""
    
    # Use provided field_id or fall back to default
    if not field_id:
        field_id = CUSTOM_FIELDS.get('contact_photo_link', 'FvzCW7qdPl6Dsy1LIgCs')
    
    url = f"https://rest.gohighlevel.com/v1/contacts/{contact_id}"
    
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
        "Version": "2021-07-28"
    }
    
    update_data = {
        "customField": {
            field_id: photo_url
        }
    }
    
    try:
        response = requests.put(url, headers=headers, json=update_data, timeout=15)
        
        if response.status_code == 200:
            return {
                'success': True,
                'message': 'Photo link updated successfully',
                'contact_id': contact_id,
                'photo_url': photo_url,
                'field_id': field_id
            }
        else:
            log_error('update_photo_link', f"API returned status {response.status_code}",
                      {'contact_id': contact_id, 'photo_url': photo_url[:50] + '...' if len(photo_url) > 50 else photo_url}, response)
            return {
                'success': False,
                'error': f"API returned status {response.status_code}",
                'message': response.text[:300],
                'contact_id': contact_id
            }
            
    except Exception as e:
        log_error('update_photo_link', str(e), {'contact_id': contact_id})
        return {
            'success': False,
            'error': str(e),
            'contact_id': contact_id
        }


def get_custom_field_ids(api_key):
    """Helper function to list all custom fields in your GHL account"""
    url = "https://rest.gohighlevel.com/v1/custom-fields/"
    
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
        "Version": "2021-07-28"
    }
    
    try:
        response = requests.get(url, headers=headers, timeout=10)
        if response.status_code == 200:
            data = response.json()
            fields = data.get('customFields', [])
            return {
                'success': True,
                'fields': [{'id': f.get('id'), 'name': f.get('name'), 'fieldKey': f.get('fieldKey')} for f in fields]
            }
        else:
            log_error('get_custom_field_ids', f"API returned status {response.status_code}", None, response)
            return {
                'success': False,
                'error': f"API returned status {response.status_code}"
            }
    except Exception as e:
        log_error('get_custom_field_ids', str(e))
        return {
            'success': False,
            'error': str(e)
        }


def main():
    result = {
        'success': False,
        'error': None
    }
    
    # Check for --list-fields flag
    if len(sys.argv) >= 3 and sys.argv[1] == '--list-fields':
        api_key = sys.argv[2]
        result = get_custom_field_ids(api_key)
        print(json.dumps(result, indent=2))
        with open(OUTPUT_FILE, 'w') as f:
            json.dump(result, f, indent=2)
        sys.exit(0 if result['success'] else 1)
    
    # Check for --update-photo flag
    if len(sys.argv) >= 5 and sys.argv[1] == '--update-photo':
        contact_id = sys.argv[2]
        api_key = sys.argv[3]
        photo_url = sys.argv[4]
        field_id = sys.argv[5] if len(sys.argv) > 5 else None
        result = update_photo_link(contact_id, api_key, photo_url, field_id)
        print(json.dumps(result, indent=2))
        with open(OUTPUT_FILE, 'w') as f:
            json.dump(result, f, indent=2)
        sys.exit(0 if result['success'] else 1)
    
    # Normal update operation
    if len(sys.argv) < 5:
        result['error'] = 'Usage: python update_ghl_contact_LB.py <contact_id> <api_key> <status> <notes> [shoot_no] [session_date] [session_time] [email] [phone] [address1] [city] [postal_code]'
        print(json.dumps(result, indent=2))
        with open(OUTPUT_FILE, 'w') as f:
            json.dump(result, f, indent=2)
        sys.exit(1)
    
    contact_id = sys.argv[1]
    api_key = sys.argv[2]
    status = sys.argv[3]
    notes = sys.argv[4]
    shoot_no = sys.argv[5] if len(sys.argv) > 5 else ""
    session_date = sys.argv[6] if len(sys.argv) > 6 else ""
    session_time = sys.argv[7] if len(sys.argv) > 7 else ""
    email = sys.argv[8] if len(sys.argv) > 8 else ""
    phone = sys.argv[9] if len(sys.argv) > 9 else ""
    address1 = sys.argv[10] if len(sys.argv) > 10 else ""
    city = sys.argv[11] if len(sys.argv) > 11 else ""
    postal_code = sys.argv[12] if len(sys.argv) > 12 else ""
    
    # Validate contact ID
    if not contact_id or len(contact_id) < 10:
        result['error'] = f'Invalid contact ID: {contact_id}'
        print(json.dumps(result, indent=2))
        with open(OUTPUT_FILE, 'w') as f:
            json.dump(result, f, indent=2)
        sys.exit(1)
    
    result = update_contact(contact_id, api_key, status, notes, shoot_no, session_date, session_time, email, phone, address1, city, postal_code)
    
    print(json.dumps(result, indent=2))
    
    with open(OUTPUT_FILE, 'w') as f:
        json.dump(result, f, indent=2)
    
    sys.exit(0 if result['success'] else 1)


if __name__ == "__main__":
    main()

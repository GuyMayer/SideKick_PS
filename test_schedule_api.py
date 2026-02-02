"""Test GHL invoice schedule API for installment payments."""
import requests
import os
import sys

# Add parent to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sync_ps_invoice import CONFIG, API_KEY, get_business_name

headers = {
    'Authorization': f'Bearer {API_KEY}',
    'Content-Type': 'application/json',
    'Version': '2021-07-28'
}

location_id = CONFIG.get('LOCATION_ID', '')
contact_id = 'qatlAMlMrQQmZvLb71pj'  # Test contact

print("=" * 60)
print("Test: Monthly recurring with dayOfMonth")
print("=" * 60)

payload = {
    'altId': location_id,
    'altType': 'location',
    'name': 'Test 3-Month Payment Plan',
    'liveMode': False,
    'contactDetails': {
        'id': contact_id,
        'name': 'Jo Test',
        'email': 'jotest@example.com'
    },
    'businessDetails': {
        'name': get_business_name()
    },
    'currency': 'GBP',
    'items': [
        {
            'name': 'Monthly Payment',
            'amount': 100.00,
            'qty': 1,
            'currency': 'GBP'
        }
    ],
    'discount': {
        'type': 'fixed',
        'value': 0
    },
    'schedule': {
        'rrule': {
            'intervalType': 'monthly',
            'interval': 1,
            'startDate': '2026-03-01',
            'dayOfMonth': 1,  # 1st of each month
            'count': 3  # 3 installments
        }
    }
}

print(f"Payload: {payload}")
response = requests.post(
    'https://services.leadconnectorhq.com/invoices/schedule/',
    headers=headers,
    json=payload,
    timeout=30
)
print(f"Status: {response.status_code}")
print(f"Response: {response.text[:1500]}")

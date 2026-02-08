import sync_ps_invoice as s
import requests
import json

invoice_id = '6987e08861b80475de242e7a'
txn_id = '6987e0885286bde5b94627bc'
location_id = s.CONFIG.get('LOCATION_ID', '')
headers = s._get_ghl_headers()

# List all transactions for this invoice
print("=== Transactions for this invoice ===")
url = 'https://services.leadconnectorhq.com/payments/transactions'
params = {'altId': location_id, 'altType': 'location', 'entityId': invoice_id, 'limit': 50}
resp = requests.get(url, headers=headers, params=params, timeout=30)
print(f"Status: {resp.status_code}")
if resp.status_code == 200:
    data = resp.json()
    txns = data.get('data', [])
    print(f"Found {len(txns)} transactions")
    for t in txns:
        print(f"  - {t.get('_id')} | £{t.get('amount')} | {t.get('status')} | providers:{t.get('paymentProviders', [])}")

# Try PATCH on transaction to change status
print("\n=== PATCH transaction to void ===")
url = f'https://services.leadconnectorhq.com/payments/transactions/{txn_id}'
payload = {'status': 'voided'}
resp = requests.patch(url, headers=headers, json=payload, params={'altId': location_id, 'altType': 'location'}, timeout=30)
print(f"PATCH status=voided: {resp.status_code}")
print(f"Response: {resp.text[:300]}")

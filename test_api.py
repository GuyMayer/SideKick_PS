import requests
import sync_ps_invoice as s

# Get location ID
location_id = s.CONFIG.get('LOCATION_ID', '')
print(f"Location ID: {location_id}")

# List invoices for this contact - we know this works
contact_id = 'frCls10iEt42JWLAPWIJ'
invoices = s.list_contact_invoices(contact_id, 'Tara Ford')
print(f"Found {len(invoices)} invoices")

if invoices:
    inv = invoices[0]
    inv_id = inv.get('_id')
    print(f"Invoice ID: {inv_id}")
    
    headers = {'Authorization': f'Bearer {s.API_KEY}', 'Version': '2021-07-28', 'Content-Type': 'application/json'}
    
    # Try GET with altId params
    url = f"https://services.leadconnectorhq.com/invoices/{inv_id}"
    params = {'altId': location_id, 'altType': 'location'}
    resp = requests.get(url, headers=headers, params=params, timeout=30)
    print(f"GET with params: {resp.status_code}")
    if resp.status_code == 200:
        print(f"Success! {resp.text[:300]}")
    else:
        print(f"Response: {resp.text}")
    
    # Try DELETE with params
    resp = requests.delete(url, headers=headers, params=params, timeout=30)
    print(f"DELETE with params: {resp.status_code}")
    print(f"Response: {resp.text[:300]}")

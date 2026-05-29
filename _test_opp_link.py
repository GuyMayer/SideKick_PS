"""Test whether GHL invoice API accepts opportunityId in the payload."""
import sys
sys.path.insert(0, 'SideKick_PS')
import sync_ps_invoice as s
import requests

inv_id = '69e8ab704fd5e4eb53221436'
contact_id = 'EIoa55OlI2XhzDwaNR8Y'
headers = s._get_ghl_headers()
location_id = s.CONFIG.get('LOCATION_ID', '')

# Find the opportunity for this contact
opp_url = 'https://services.leadconnectorhq.com/opportunities/search'
opp_resp = requests.get(opp_url, headers=headers, params={
    'contact_id': contact_id,
    'location_id': location_id
}, timeout=30)
print(f'Opp search status: {opp_resp.status_code}')

opp_id = None
if opp_resp.ok:
    data = opp_resp.json()
    opps = data.get('opportunities', [])
    if opps:
        opp_id = opps[0].get('id')
        name = opps[0].get('name') or opps[0].get('opportunityTitle', '')
        print(f'Found opp: {opp_id} - {name}')
    else:
        print('No opportunities found for contact')
else:
    print('Error:', opp_resp.text[:300])

if not opp_id:
    print('Cannot test without opportunity ID')
    sys.exit(1)

# Fetch invoice via list endpoint (GET by ID returns 403)
put_url = f'https://services.leadconnectorhq.com/invoices/{inv_id}'
invs = s.list_contact_invoices(contact_id, 'Louise Martin')
inv = next((i for i in invs if i.get('_id') == inv_id), None)
if not inv:
    print('Cannot find invoice in list')
    sys.exit(1)
print('Current invoice keys:', list(inv.keys()))

# Build PUT payload from the existing invoice, adding opportunityId
payload = {
    'altId': location_id,
    'altType': 'location',
    'name': inv['name'],
    'currency': inv['currency'],
    'businessDetails': inv['businessDetails'],
    'contactDetails': inv['contactDetails'],
    'issueDate': inv['issueDate'][:10],
    'dueDate': inv['dueDate'][:10],
    'invoiceItems': [{k: v for k, v in item.items() if k != '_id'} for item in inv['invoiceItems']],
    'opportunityId': opp_id,
}
if inv.get('discount'):
    payload['discount'] = inv['discount']

put_resp = requests.put(put_url, headers=headers, json=payload, timeout=30)
print(f'PUT with opportunityId status: {put_resp.status_code}')
print('Response:', put_resp.text[:800])

# If accepted, fetch again and check for opportunityId
if put_resp.status_code in (200, 201):
    check_resp = requests.get(put_url, headers=headers, timeout=30)
    if check_resp.ok:
        updated = check_resp.json()
        print('Updated invoice keys:', list(updated.keys()))
        for k, v in updated.items():
            if 'opp' in k.lower() or 'opportun' in k.lower():
                print(f'  OPPORTUNITY FIELD: {k}: {v}')
        print('opportunityId in response?', 'opportunityId' in updated)

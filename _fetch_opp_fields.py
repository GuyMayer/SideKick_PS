"""Fetch Helen's opportunity to see opportunity-level custom field structure and IDs."""
import sys, requests
sys.path.insert(0, r'C:\Stash\SideKick_PS')
import sync_ps_invoice as s

headers = s._get_ghl_headers()
location_id = s.LOCATION_ID

resp = requests.get(
    f'https://services.leadconnectorhq.com/locations/{location_id}/customFields',
    headers=headers,
    timeout=30
)
print(f'Status: {resp.status_code}')
fields = resp.json().get('customFields', [])
print(f'Total fields: {len(fields)}\n')

keywords = {'job', 'invoice', 'payment', 'production', 'ordered', 'products', 'notes', 'hold', 'return', 'shoot', 'album', 'session'}
print('--- Relevant fields ---')
for f in sorted(fields, key=lambda x: x.get('name', '')):
    name = f.get('name', '')
    fid = f.get('id', '')
    key = f.get('fieldKey', '')
    ftype = f.get('dataType', f.get('type', ''))
    if any(k in name.lower() or k in key.lower() for k in keywords):
        print(f'  {name!r:40} id={fid}  key={key}  type={ftype}')

print('\n--- All fields ---')
for f in sorted(fields, key=lambda x: x.get('name', '')):
    print(f'  {f.get("name","")!r:40} id={f.get("id","")}  key={f.get("fieldKey","")}  type={f.get("dataType","")}')

import sys, requests
sys.path.insert(0, r'C:\Stash\SideKick_PS')
import sync_ps_invoice as s

h = s._get_ghl_headers()
loc = s.LOCATION_ID

for model in ['opportunity', 'opportunities']:
    r = requests.get(
        f'https://services.leadconnectorhq.com/locations/{loc}/customFields',
        headers=h,
        params={'model': model},
        timeout=30
    )
    fields = r.json().get('customFields', [])
    print(f'model={model}  status={r.status_code}  fields={len(fields)}')
    for f in fields:
        name = f.get('name', '')
        fid = f.get('id', '')
        key = f.get('fieldKey', '')
        ftype = f.get('dataType', '')
        print(f'  {name!r:40} id={fid}  key={key}  type={ftype}')

"""Test SKU lookup against Andrew's GHL account."""
import requests

API_KEY = 'pit-e257dc58-813b-4ee5-b787-22d9f328e33a'
LOCATION_ID = 'W0fg9KOTXUtvCyS18jwM'

headers = {'Authorization': f'Bearer {API_KEY}', 'Version': '2021-07-28'}
products_map = {}

# Fetch products
url = 'https://services.leadconnectorhq.com/products/'
params = {'locationId': LOCATION_ID, 'limit': 100}
r = requests.get(url, headers=headers, params=params, timeout=30)
products = r.json().get('products', [])
print(f'Fetched {len(products)} products')

# Fetch prices for ALL products to find SKUs
for i, product in enumerate(products):
    product_id = product.get('_id', '')
    product_name = product.get('name', '')
    prices_url = f'https://services.leadconnectorhq.com/products/{product_id}/price'
    prices_params = {'locationId': LOCATION_ID}
    pr = requests.get(prices_url, headers=headers, params=prices_params, timeout=15)
    if pr.status_code == 200:
        for price in pr.json().get('prices', []):
            sku = price.get('sku', '')
            if sku:
                print(f'Found SKU: "{sku}" -> "{product_name}"')
                products_map[sku.lower()] = {'name': product_name}

print(f'\n=== Total SKUs found: {len(products_map)} ===')
print(f'SKU keys: {list(products_map.keys())}')
print(f'\nLooking for "com1a"...')
result = products_map.get('com1a')
if result:
    print(f'FOUND: {result}')
else:
    print('NOT FOUND')

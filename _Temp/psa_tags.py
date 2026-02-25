"""Dump all XML tags from PSA OrderList to find address fields."""
import sqlite3, sys, re

psa = sys.argv[1]
db = sqlite3.connect(psa)
c = db.cursor()
c.execute("SELECT buffer FROM BigStrings WHERE buffCode='OrderList'")
row = c.fetchone()
if not row:
    print("No OrderList found")
    sys.exit(1)

data = row[0] if isinstance(row[0], str) else row[0].decode('utf-8', errors='replace')

# Find ALL unique XML tags with their values
tags = re.findall(r'<(\w+)>([^<]*)</\1>', data)
seen = set()
for tag, val in tags:
    if tag not in seen:
        seen.add(tag)
        print(f"  {tag}: {val[:100]}")

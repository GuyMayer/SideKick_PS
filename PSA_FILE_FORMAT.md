# ProSelect Album (.psa) File Format

## Overview

ProSelect `.psa` album files are **SQLite databases** with a renamed extension. This allows them to be read and manipulated using any SQLite library.

## File Identification

- **Magic bytes:** `53 51 4C 69 74 65 20 66 6F 72 6D 61 74 20 33` ("SQLite format 3")
- **Extension:** `.psa`
- **Format:** SQLite 3 database

## Database Schema

### Tables

| Table | Description |
|-------|-------------|
| `Config` | Album configuration key-value pairs |
| `BigStrings` | Large XML data blobs (orders, images, templates, etc.) |
| `BigImages` | Full resolution image data |
| `Thumbnails` | Image thumbnails (various types) |
| `ResourceImages` | Resource images with extension info |
| `Frames` | Frame definitions (name, dimensions, pricing) |
| `AlbumResources` | Album resource data |
| `AutoBackUpStrings` | Auto-backup data |
| `sqlite_sequence` | SQLite internal sequence tracking |

### Config Table

| Column | Type | Description |
|--------|------|-------------|
| `id` | INTEGER | Primary key |
| `cnfKey` | TEXT | Configuration key name |
| `cnfValue` | TEXT | Configuration value |

**Common Config Keys:**
- `Version` - Album format version
- `OwnerName` - User who created/owns the album
- `OwnerMachine` - Computer name
- `SavedBy` - Last user to save
- `SavedOn` - Last machine saved on
- `SavedAt` - Last save timestamp
- `LastAutoBackup` - Last auto-backup timestamp
- `IsProduction` - Production status
- `IsHDPI` - High DPI flag

### BigStrings Table

| Column | Type | Description |
|--------|------|-------------|
| `id` | INTEGER | Primary key |
| `buffCode` | TEXT | Buffer identifier |
| `buffer` | BLOB/TEXT | XML or data content |

**Buffer Codes:**
- `ImageList` - List of all images in album
- `BookPages` - Book/album page layouts
- `UsedTemplateList` - Templates used in album
- `OrderList` - **Orders, payments, and customer data**
- `ResourceData` - Resource definitions
- `ArrangementData` - Image arrangements
- `SlideshowData` - Slideshow configuration
- `AlbumResourceData` - Album resources
- `AlbumRoomsData` - Room view data

## OrderList XML Structure

The `OrderList` buffer contains customer and payment information:

```xml
<OrderList OutputPath="..." ExportOption1="false" lastOrderID="26">
    <CurrentPriceList>Studio Pricing</CurrentPriceList>
    <OrderGroups31>
        <Group id="1" taxRate="20.0" taxIncInPrice="Yes" NextPaymentID="15">
            <firstName>John</firstName>
            <lastName>Smith</lastName>
            <address1>123 Main St</address1>
            <city>London</city>
            <state>Greater London</state>
            <country>GB</country>
            <zip>SW1A 1AA</zip>
            <phone1>+447123456789</phone1>
            <email>john@example.com</email>
            <clientCode>ABC123XYZ</clientCode>
            <payments>
                <payment value="1000" methodID="2" methodName="Credit Card" 
                         jdate="2025-11-18 18:05:04" id="2" />
                <payment value="200" methodID="12" methodName="GoCardless DD" 
                         jdate="2026-03-01 12:41:33" id="10" />
            </payments>
        </Group>
    </OrderGroups31>
    <Orders sorted="true">
        <item version="1" groupID="1" OrderID="2" name="-" type="0" qty="1">
            <Price price="0" supplierCost="0" tax="false" productCode=""/>
        </item>
    </Orders>
</OrderList>
```

### Payment Fields

| Attribute | Description |
|-----------|-------------|
| `value` | Amount in pence (1000 = £10.00) |
| `methodID` | Payment method ID |
| `methodName` | Human-readable method name |
| `jdate` | Payment date (YYYY-MM-DD HH:MM:SS) |
| `id` | Unique payment ID |
| `exported` | Export status ("Yes"/"No") |
| `status` | Payment status code |

### Common Payment Methods

| methodID | methodName |
|----------|------------|
| 2 | Credit Card |
| 12 | GoCardless DD |

## Reading a .psa File with Python

```python
import sqlite3

# Connect to the .psa file
conn = sqlite3.connect('album.psa')
cursor = conn.cursor()

# List all tables
cursor.execute('SELECT name FROM sqlite_master WHERE type="table"')
tables = cursor.fetchall()
print('Tables:', [t[0] for t in tables])

# Read config values
cursor.execute('SELECT cnfKey, cnfValue FROM Config')
for key, value in cursor.fetchall():
    print(f'{key}: {value}')

# Read OrderList XML
cursor.execute('SELECT buffer FROM BigStrings WHERE buffCode="OrderList"')
order_data = cursor.fetchone()[0]
print(order_data)

conn.close()
```

## Reading with PowerShell

```powershell
# Check file header (should show "SQLite format 3")
$bytes = [System.IO.File]::ReadAllBytes("album.psa")
[System.Text.Encoding]::ASCII.GetString($bytes[0..15])
```

## Notes

- Data in `BigStrings.buffer` may be stored as TEXT or BLOB depending on content
- Payment values are stored in **whole currency units** (e.g., 200 = £200.00)
- Dates use format `YYYY-MM-DD HH:MM:SS`
- The `clientCode` field often contains GHL contact IDs
- Images in `BigImages` and `Thumbnails` are stored as binary blobs

## Discovered

- **Date:** 2026-02-19
- **Method:** Hex dump of file header revealed SQLite magic bytes
- **Sample file:** `P25098P_Wesley_VKIXpJNp1wLzc5o59qDm.psa`

# ProSelect Album (.psa) File Format — Specification Sheet

> **Purpose:** Reference document for AI assistants and developers working with ProSelect `.psa` album files in the SideKick_PS project.  
> **Created:** 2026-02-25  
> **Last verified against:** ProSelect album version 9, sample `P25098P_Wesley_VKIXpJNp1wLzc5o59qDm.psa` (16.4 MB)

---

## 1. File Identity

| Property | Value |
|----------|-------|
| **Extension** | `.psa` |
| **Format** | SQLite 3 database (renamed extension) |
| **Magic bytes** | `53 51 4C 69 74 65 20 66 6F 72 6D 61 74 20 33` → `"SQLite format 3"` |
| **Python opener** | `sqlite3.connect("album.psa")` |
| **Typical size** | 5–50 MB (depends on image count and thumbnail resolution) |

Any SQLite client (Python `sqlite3`, DB Browser, etc.) can open `.psa` files directly — no decryption or decompression needed.

---

## 2. Database Schema

### 2.1 Tables Overview

| Table | Purpose | Typical rows |
|-------|---------|-------------|
| **Config** | Key-value album settings | 15–20 |
| **BigStrings** | Large XML data blobs (orders, images, templates, etc.) | 9 |
| **BigImages** | Full-resolution album images (BLOB) | Matches image count |
| **Thumbnails** | Image thumbnails at multiple sizes (BLOB) | ~2.5× image count |
| **Frames** | Frame definitions (name, width, pricing) | 0+ |
| **ResourceImages** | Resource image data with extension info | 0+ |
| **AlbumResources** | Album resource blobs | 0+ |
| **AutoBackUpStrings** | Auto-backup XML data (same schema as BigStrings) | 0 (populated on backup) |
| **sqlite_sequence** | SQLite internal autoincrement tracking | 3 |

---

### 2.2 Config Table

```sql
CREATE TABLE Config (
    id       INTEGER PRIMARY KEY AUTOINCREMENT,
    cnfKey   VARCHAR(100),
    cnfValue VARCHAR(255)
);
```

**Known Config Keys (observed):**

| cnfKey | Example Value | Description |
|--------|---------------|-------------|
| `Version` | `9` | Album format version |
| `OwnerName` | `guy` | User who created the album |
| `OwnerMachine` | `STUDIOPC2` | Computer name |
| `SavedBy` | `guy` | Last user to save |
| `SavedOn` | `STUDIOPC2` | Last machine saved on |
| `SavedAt` | `2026-02-19 13:04:58` | Last save timestamp |
| `LastAutoBackup` | `2026-02-19 12:39:44` | Last auto-backup timestamp |
| `IsProduction` | `No` | Whether album is in production |
| `IsHDPI` | `Yes` | High-DPI flag |
| `DupThumbCheck` | `true` | Duplicate thumbnail check done |
| `ImageFlippedCheckDone` | `true` | Image flip check completed |
| `BookPageTypeResetDone` | `true` | Book page type reset done |
| `TempHoleRotateCheckDone` | `true` | Temp hole rotation checked |
| `OpenSetsOnLoad` | `False` | Open sets on album load |
| `AlbumRestoreUID` | `RUID_3202621912272557` | Restore unique ID |
| `DebugID` | `0` | Debug identifier |
| `CUST_SM_Event_ID` | *(empty)* | ShootMojo event ID (custom field) |
| `CUST_SM_Event_NAME` | `Unknown` | ShootMojo event name (custom field) |

**Query:**
```sql
SELECT cnfKey, cnfValue FROM Config ORDER BY cnfKey;
```

---

### 2.3 BigStrings Table

```sql
CREATE TABLE BigStrings (
    id       INTEGER PRIMARY KEY AUTOINCREMENT,
    buffCode VARCHAR(100),
    buffer   TEXT
);
```

**Buffer Codes (always present in this order):**

| id | buffCode | Typical Size | Description |
|----|----------|-------------|-------------|
| 1 | `ImageList` | 40 KB | All images, source folders, sets, crop data |
| 2 | `BookPages` | 3 KB | Book/album page layout definitions |
| 3 | `UsedTemplateList` | 58 KB | Templates used in the album |
| 4 | **`OrderList`** | 16 KB | **Orders, payments, customer data, clientCode** |
| 5 | `ResourceData` | <1 KB | Resource definitions |
| 6 | `ArrangementData` | 1 KB | Image arrangement data |
| 7 | `SlideshowData` | 14 KB | Slideshow configuration |
| 8 | `AlbumResourceData` | <1 KB | Album resource references |
| 9 | `AlbumRoomsData` | <1 KB | Room view configuration |

**Query:**
```sql
SELECT id, buffCode, LENGTH(buffer) FROM BigStrings ORDER BY id;
```

> **Note:** Buffer data may be stored as TEXT or BLOB. Always handle both:
> ```python
> data = row[0]
> if isinstance(data, bytes):
>     data = data.decode('utf-8', errors='replace')
> ```

---

### 2.4 BigImages Table

```sql
CREATE TABLE BigImages (
    id        INTEGER PRIMARY KEY AUTOINCREMENT,
    imageData BLOB
);
```

- One row per album image
- `id` corresponds to `<albumimage id="N">` in the ImageList XML
- Contains the full-resolution image as a binary blob

---

### 2.5 Thumbnails Table

```sql
CREATE TABLE Thumbnails (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    imageID       INTEGER,          -- References BigImages.id / albumimage id
    thumbnailType INTEGER,          -- 1, 2, or 3
    imageData     BLOB,             -- JPEG image data
    autoDirty     INTEGER           -- Whether thumbnail needs regeneration
);
```

**Thumbnail Types:**

| thumbnailType | Purpose | Avg Size | Count per Image |
|---------------|---------|----------|----------------|
| 1 | Main thumbnail (used for UI display) | ~22 KB | 1 per image |
| 2 | Larger preview thumbnail | ~26 KB | 1 per image |
| 3 | Small/cropped thumbnail (book pages etc.) | ~3 KB | Varies (not all images) |

- JPEG format — data starts with `FF D8` (validate before writing)
- `imageID` maps to `<albumimage id="N">` in ImageList XML

**Query all type-1 thumbnails:**
```sql
SELECT id, imageID, imageData
FROM Thumbnails
WHERE thumbnailType = 1 AND imageData IS NOT NULL;
```

---

### 2.6 Frames Table

```sql
CREATE TABLE Frames (
    id               VARCHAR(255) PRIMARY KEY,
    name             VARCHAR(100),
    rebate           REAL,
    noFlip           VARCHAR(1),
    widthMM          REAL,
    segment          BLOB,
    priceGroupID     INTEGER,
    supplierCode     VARCHAR(32),
    supplierPrice    REAL,
    supplierModel    INTEGER,
    supplierProdCode VARCHAR(32),
    GUID             VARCHAR(32)
);
```

Contains frame definitions used in the album. Often empty if no frames are applied.

---

### 2.7 ResourceImages Table

```sql
CREATE TABLE ResourceImages (
    id        INTEGER PRIMARY KEY AUTOINCREMENT,
    imageData BLOB,
    ext       VARCHAR(5)    -- File extension, e.g. "png", "jpg"
);
```

---

### 2.8 AlbumResources Table

```sql
CREATE TABLE AlbumResources (
    id     INTEGER PRIMARY KEY AUTOINCREMENT,
    code   VARCHAR(255),
    type   INTEGER,
    format INTEGER,
    data   BLOB
);
```

---

### 2.9 AutoBackUpStrings Table

Same schema as BigStrings. Populated when ProSelect creates an auto-backup.

```sql
CREATE TABLE AutoBackUpStrings (
    id       INTEGER PRIMARY KEY AUTOINCREMENT,
    buffCode VARCHAR(100),
    buffer   TEXT
);
```

---

## 3. OrderList XML Structure (Key for SideKick)

The `OrderList` buffer is the most important for SideKick_PS. It contains customer info, payment history, and the **GHL Contact ID** (`clientCode`).

**Query:**
```sql
SELECT buffer FROM BigStrings WHERE buffCode='OrderList';
```

### 3.1 Full XML Structure

```xml
<OrderList OutputPath="..." ExportOption1="false" wgSet="0" lastOrderID="26">
    <CurrentPriceList>Studio Pricing</CurrentPriceList>
    <OrderGroups31>
        <Group id="1" WGOrderID="0" WGReceipt="0"
               taxATSI="Yes" taxLTTID="0" taxRate="20.0" taxRUp="No"
               taxIncInPrice="Yes" taxSubIncTax="Yes"
               lastChanged="2025-11-18 18:06:59"
               lastOrderChanged="2026-02-19 12:41:00"
               lastPaymentsChanged="2026-02-19 12:42:15"
               NextPaymentID="15">

            <!-- ═══ CUSTOMER INFO ═══ -->
            <firstName>Louise</firstName>
            <lastName>Wesley</lastName>
            <address1>61A Bishopstone Road</address1>
            <city>Stone</city>
            <state>Buckinghamshire</state>
            <country>GB</country>
            <zip>HP17 8RX</zip>
            <phone1>+447508352583</phone1>
            <email>lhywesley@yahoo.co.uk</email>
            <clientCode>VKIXpJNp1wLzc5o59qDm</clientCode>
            <taxID>4</taxID>
            <taxName>VAT 20%</taxName>
            <taxRDesc>VAT 20%</taxRDesc>

            <!-- ═══ PAYMENTS ═══ -->
            <payments>
                <payment value="1000" exported="No" methodID="2"
                         SCEntryID="" methodName="Credit Card" status="0"
                         jdate="2025-11-18 18:05:04" id="2" />
                <payment value="200" exported="No" methodID="12"
                         SCEntryID="" methodName="GoCardless DD" status="0"
                         jdate="2026-03-01 12:41:33" id="10" />
            </payments>
        </Group>
    </OrderGroups31>

    <!-- ═══ ORDER ITEMS ═══ -->
    <Orders sorted="true">
        <item version="1" groupID="1" OrderID="2" name="-" type="0" qty="1">
            <Price price="0" supplierCost="0" tax="false" productCode=""/>
        </item>
    </Orders>
</OrderList>
```

### 3.2 Customer Fields

| XML Element | Description | Example |
|-------------|-------------|---------|
| `<firstName>` | First name | `Louise` |
| `<lastName>` | Last name | `Wesley` |
| `<address1>` | Address line 1 | `61A Bishopstone Road` |
| `<city>` | City | `Stone` |
| `<state>` | County/State | `Buckinghamshire` |
| `<country>` | Country code | `GB` |
| `<zip>` | Postcode | `HP17 8RX` |
| `<phone1>` | Phone number | `+447508352583` |
| `<email>` | Email address | `lhywesley@yahoo.co.uk` |
| **`<clientCode>`** | **"Acnt. Code" in ProSelect UI** — may contain a GHL Contact ID (20+ alphanum, e.g. `VKIXpJNp1wLzc5o59qDm`) **or** a shoot number (e.g. `P26020P`). Must check format to determine type. | `VKIXpJNp1wLzc5o59qDm` or `P26020P` |
| `<taxID>` | Tax rate ID | `4` |
| `<taxName>` | Tax name | `VAT 20%` |

### 3.3 Payment Fields

| Attribute | Type | Description | Example |
|-----------|------|-------------|---------|
| `value` | decimal | Amount in **whole currency units** (£) | `200` = £200.00 |
| `methodID` | integer | Payment method ID | `2`, `12` |
| `methodName` | string | Human-readable payment method | `Credit Card`, `GoCardless DD` |
| `jdate` | datetime | Payment date `YYYY-MM-DD HH:MM:SS` | `2026-03-01 12:41:33` |
| `id` | integer | Unique payment ID within album | `10` |
| `exported` | string | Export status | `Yes` / `No` |
| `status` | string | Payment status code | `0` |
| `SCEntryID` | string | External entry ID (if linked) | *(often empty)* |

### 3.4 Known Payment Methods

| methodID | methodName |
|----------|------------|
| 2 | Credit Card |
| 12 | GoCardless DD |

---

## 4. ImageList XML Structure

**Query:**
```sql
SELECT buffer FROM BigStrings WHERE buffCode='ImageList';
```

### 4.1 Root Element

```xml
<album version="7" nextimageid="48" nextsourceid="48"
       imagesperfolder="0" albumID="PRO_32025111816482441"
       lastLoadedPath="...##2##E:\\Shoot Archive\\P25098P_Wesley_...\\Unprocessed\\">
```

| Attribute | Description |
|-----------|-------------|
| `version` | ImageList format version |
| `nextimageid` | Next auto-assigned image ID |
| `albumID` | Unique album identifier |
| `lastLoadedPath` | Encoded path to source images (extract with regex `##2##(.+?)\\\\?"`) |

### 4.2 Image Elements

```xml
<image name="P25098P0003.jpg" nameOrg="P25098P0003.jpg"
       sourceFoldIndex="1" width="5464" height="8192"
       created="2460997.699769" modified="2460997.694861"
       EXIFRotation="0" ProdStatus="0"
       frameID="" HotSpotX="0.5" HotSpotY="0.33"
       Favourite="No" Rating="0">
    <effects rotation="0" isFlipped="No"
             cropTopRatio="0.0830729" cropLeftRatio="0"
             cropWidthRatio="1" cropHeightRatio="0.8338542" />
    <albumimage id="2" srcID="2" srcIDOrg="2"
                width="1281" height="1920" tilt="0"
                HiDef="false" shared="false" />
</image>
```

| Element/Attribute | Description |
|----------|-------------|
| `image/@name` | Current filename |
| `image/@nameOrg` | Original filename |
| `image/@width`, `@height` | Original image dimensions (px) |
| `image/@Favourite` | Favourited status (`Yes`/`No`) |
| `image/@Rating` | Star rating (0-5) |
| `image/@ProdStatus` | Production status |
| `effects/@rotation` | Rotation in degrees |
| `effects/@isFlipped` | Horizontal flip |
| `effects/@crop*Ratio` | Crop rectangle as ratios (0.0–1.0) |
| `albumimage/@id` | **Album image ID** — maps to `BigImages.id` and `Thumbnails.imageID` |
| `albumimage/@width`, `@height` | Thumbnail/display dimensions |

### 4.3 Set Groups

```xml
<SetGroupImages>
    <group name="Set Group 1">
        <Set name="Set 1"/>
        <Set name="Set 2"/>
    </group>
</SetGroupImages>
```

### 4.4 Source Folders

```xml
<sourceFolders>
    <folder sourceFoldIndex="1"
            saveInfo="##RAL####...##2##E:\\Shoot Archive\\...\\Unprocessed\\" />
</sourceFolders>
```

---

## 5. Filename Convention

PSA files follow the naming pattern:
```
{ShootNumber}_{ClientLastName}_{GHL_ContactID}.psa
```

**Examples:**
- `P25098P_Wesley_VKIXpJNp1wLzc5o59qDm.psa`
- `P21127P_Walters.psa` *(older format, no GHL ID)*
- `P26005P_Smith_abc123XYZ456def789gh.psa`

The **GHL Contact ID** (20+ alphanumeric chars) may appear:
1. In the filename after the last underscore
2. In `OrderList` XML → `<clientCode>` element (but verify — this field is ProSelect's "Acnt. Code" and may instead hold the shoot number like `P26020P`)
3. In the ProSelect window title: `ProSelect - C:\path\to\album.psa`

**Detecting GHL ID vs shoot number in `<clientCode>`:**
- GHL ID pattern: `^[A-Za-z0-9]{20,}$` (20+ alphanumeric, no special chars)
- Shoot number pattern: `^P\d+P$` (e.g. `P26020P`)
- If it matches the shoot number pattern, it is NOT a GHL ID

---

## 6. Common Access Patterns in SideKick_PS

### 6.1 Extract GHL Contact ID (Python one-liner from AHK)

```python
import sqlite3, re, sys
conn = sqlite3.connect(sys.argv[1])
c = conn.cursor()
c.execute('SELECT buffer FROM BigStrings WHERE buffCode="OrderList"')
r = c.fetchone()
conn.close()
m = re.search(r'<clientCode>([^<]+)</clientCode>', str(r[0])) if r else None
open(sys.argv[2], 'w').write(m.group(1) if m else '')
```

> **AHK-side validation after reading the result:**
> The value must pass both checks before being used as a GHL Contact ID:
> 1. `RegExMatch(value, "^[A-Za-z0-9]{20,}$")` — 20+ alphanumeric chars
> 2. `!RegExMatch(value, "^P\d+P$")` — NOT a shoot number like `P26020P`

### 6.2 Extract Payment Data (read_psa_payments.py)

```python
cursor.execute('SELECT buffer FROM BigStrings WHERE buffCode="OrderList"')
# Parse <payment value="200" methodID="12" methodName="GoCardless DD" jdate="2026-03-01 12:41:33" id="10" />
```

**Output format:** `PAYMENTS|count|day,month,year,amount,methodName,methodID|...`

### 6.3 Extract Image List & Thumbnails (read_psa_images.py)

```python
# Get image names
cursor.execute('SELECT buffer FROM BigStrings WHERE buffCode="ImageList"')
# Parse <image name="P25098P0003.jpg"> ... <albumimage id="2"/>

# Extract thumbnails
cursor.execute('SELECT id, imageID, imageData FROM Thumbnails WHERE thumbnailType = 1')
# Write imageData as .jpg (verify FF D8 header first)
```

### 6.4 Find PSA File from AHK

```autohotkey
; ProSelect title: "ProSelect - C:\path\to\albumname.psa"
RegExMatch(psTitle, "^ProSelect - (.+)", albumMatch)
psaPath := albumMatch1

; Or search folder for .psa files
Loop, Files, %folderPath%\*.psa
    psaPath := A_LoopFileLongPath
```

---

## 7. Key Relationships

```
BigStrings (buffCode="ImageList")
    └─ <image> elements
        └─ <albumimage id="N">
            ├─ BigImages (id=N)          ← full resolution image
            └─ Thumbnails (imageID=N)    ← type 1, 2, 3 thumbnails

BigStrings (buffCode="OrderList")
    └─ <OrderGroups31>
        └─ <Group>
            ├─ Customer info (firstName, lastName, clientCode, etc.)
            └─ <payments>
                └─ <payment> elements (value, methodName, jdate, etc.)

Config
    └─ Key-value pairs (Version, OwnerName, SavedAt, etc.)
```

---

## 8. Important Notes

1. **Not pence, whole units:** Payment `value` is in whole currency units (e.g., `200` = £200.00), though decimal values like `91.7` are also possible.
2. **clientCode ≠ always GHL ID:** The `<clientCode>` element maps to ProSelect's **"Acnt. Code"** field. It may contain a GHL Contact ID (20+ alphanumeric chars like `VKIXpJNp1wLzc5o59qDm`) **or** just the shoot number (e.g. `P26020P`). To identify a GHL ID, match the pattern `^[A-Za-z0-9]{20,}$` and ensure it doesn't look like a shoot number (`P\d+P`).
3. **UTF-8 handling:** Buffer data may be TEXT or BLOB. Always check `isinstance(data, bytes)` and decode with `errors='replace'`.
4. **File locking:** ProSelect may lock the `.psa` file while open. Use read-only connections where possible: `sqlite3.connect('file:album.psa?mode=ro', uri=True)`.
5. **No external dependencies:** Standard Python `sqlite3` module works — no need for a separate SQLite CLI tool.
6. **Dates:** Two formats in use:
   - Config/payment dates: `YYYY-MM-DD HH:MM:SS`
   - Image dates: Julian day numbers (e.g., `2460997.699769`)
7. **Album version:** Current format version is `9` (Config key `Version`). ImageList album version is `7`.

---

## 9. Related Project Files

| File | Purpose |
|------|---------|
| `SideKick_PS.ahk` | Main AHK app — reads PSA for Cardly contact lookup, invoice sync |
| `read_psa_images.py` | Extracts image list and thumbnails from PSA |
| `read_psa_payments.py` | Extracts payment data from PSA |
| `sync_ps_invoice.py` | Invoice sync — uses PSA for thumbnails and album data |

---

## 10. Discovery History

- **Date discovered:** 2026-02-19
- **Method:** Hex dump of `.psa` file header revealed SQLite magic bytes
- **Original sample:** `P25098P_Wesley_VKIXpJNp1wLzc5o59qDm.psa`
- **Spec created:** 2026-02-25 (consolidated from original discovery notes + live schema query)

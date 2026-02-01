# SideKick_PS Evolution Roadmap

## Vision: GHL + ProSelect = Complete Studio Management

Replace Light Blue with a streamlined GHL → ProSelect workflow. SideKick_PS becomes the central automation hub for:
- Client data (from GHL)
- Photo file management (card downloads, archiving)
- Album production (ProSelect)
- Client communication (via GHL)

---

## Current State

### SideKick_PS.ahk (3,416 lines) - Updated January 2026
- ✅ Payment plan calculator
- ✅ ProSelect automation (2022/2025)
- ✅ GHL V2 API integration (Private Integration Token)
- ✅ GHL client lookup (simplified Chrome URL detection)
- ✅ Update ProSelect from GHL data
- ✅ Settings GUI with General, Calculator, GHL Integration tabs
- ✅ Floating toolbar (docked to ProSelect window)
- ✅ Invoice folder monitoring and auto-sync
- ✅ Chrome tab search option for finding GHL contact URLs
- ✅ Desktop shortcut creation from Settings
- ✅ Base64 API key encryption
- ✅ Python scripts: `fetch_ghl_contact.py`, `update_ghl_contact.py`, `upload_ghl_media.py`, `sync_ps_invoice_v2.py`

### SideKick_LB_PubAI.ahk (10,131 lines) - To Migrate
- Card download workflow
- File renaming/numbering
- Archive folder management
- QR code generation
- LB→GHL sync

---

## Phase 1: File Management (Week 1-2)

### 1.1 SD Card Download Module
**Port from LB: Lines 2563-2750**

```
New Label: SDCardDownload
- Detect inserted SD cards
- GUI to select download destination
- Progress indicator during copy
- Multi-card support
```

**New functions:**
- `DetectSDCard()` - Find DCIM folder on removable drives
- `CopyWithProgress(source, dest)` - File copy with progress bar
- `GenerateShootNo()` - Auto-increment shoot number

### 1.2 Archive Folder Structure
**Port from LB: Lines 2810-2870, 3018-3128**

```
Archive Path: K:\Archive\{Year}\{ShootPrefix}{ShootNo}{ShootSuffix}
Download Path: K:\Downloads\{ShootPrefix}{ShootNo}{ShootSuffix}
```

**Settings to add:**
- `ArchivePath` - Base archive folder
- `DownloadPath` - Temp download folder  
- `ShootPrefix` - e.g., "ZP"
- `ShootSuffix` - e.g., ""
- `ShootNumberDigits` - e.g., 5 (for 00001)

### 1.3 File Renaming
**Port from LB: Lines 2756-2810**

```
Rename pattern: {ShootNo}_{OriginalName}.{ext}
Or: {Date}_{Counter}.{ext}
```

**Options:**
- Rename by date taken (EXIF)
- Rename by sequence number
- Preserve original filename

---

## Phase 2: GHL as Shoot Database (Week 2-3)

### 2.1 GHL Custom Fields Schema

| Field | GHL Custom Field | Type | Source |
|-------|------------------|------|--------|
| Shoot Number | `session_job_no` | Text | Manual/Auto |
| Shoot Date | `session_date` | Date | GHL Calendar |
| Shoot Type | `lb_service` | Dropdown | GHL |
| Shoot Status | `session_status` | Dropdown | Auto |
| Archive Path | `archive_path` (NEW) | Text | SideKick |
| Album Path | `proselect_album` (NEW) | Text | SideKick |
| **Order Total** | `order_total` (NEW) | Currency | PS XML |
| **Balance Due** | `balance_due` (NEW) | Currency | PS XML |
| **Deposit Paid** | `deposit_paid` (NEW) | Currency | PS XML |
| **Order Date** | `order_date` (NEW) | Date | PS XML |
| **Order Summary** | `order_summary` (NEW) | Text | PS XML |
| Order Status | `order_status` (NEW) | Dropdown | PS XML/Manual |
| Delivery Date | `delivery_date` (NEW) | Date | Manual |

### 2.2 GHL Opportunity Pipeline

```
Stages:
1. Lead → 2. Booked → 3. Shoot Complete → 4. Editing → 5. Proofing → 6. Ordered → 7. Delivered
```

### 2.3 GHL → ProSelect Workflow

**New Label: GHL2PS**
```
1. Fetch contact from GHL (by ID or search)
2. Get shoot details from opportunity/custom fields
3. Determine archive path from shoot number
4. Create/open ProSelect album
5. Populate PS fields from GHL data
6. Update GHL with album path
```

---

## Phase 3: Unified GUI (Week 3-4)

### 3.1 Main Dashboard

```
┌─────────────────────────────────────────────┐
│  SideKick Studio Manager                    │
├─────────────────────────────────────────────┤
│  [📥 Download Card] [📁 Open Archive]       │
│  [👤 GHL Lookup]    [📷 New Album]          │
├─────────────────────────────────────────────┤
│  Recent Shoots:                             │
│  ┌─────────────────────────────────────┐   │
│  │ ZP00142 - Smith Family - 2026-01-28 │   │
│  │ ZP00141 - Jones Wedding - 2026-01-25│   │
│  └─────────────────────────────────────┘   │
├─────────────────────────────────────────────┤
│  Today's Schedule (from GHL):              │
│  • 10:00 - Portrait - Johnson Family        │
│  • 14:00 - Newborn - Williams Baby          │
└─────────────────────────────────────────────┘
```

### 3.2 Card Download Dialog

```
┌─────────────────────────────────────────────┐
│  Download SD Card                           │
├─────────────────────────────────────────────┤
│  Card: E:\ (32GB, 847 photos)               │
│                                             │
│  Shoot No: [ZP00143    ] (auto-increment)   │
│  Client:   [_____________] ← GHL lookup     │
│  Date:     [2026-01-29]                     │
│                                             │
│  ☑ Rename files by date                     │
│  ☑ Create ProSelect album after             │
│  ☐ Open in editor after                     │
│                                             │
│  [Download]  [Multi-Card]  [Cancel]         │
└─────────────────────────────────────────────┘
```

### 3.3 GHL Client Selector

```
┌─────────────────────────────────────────────┐
│  Select Client from GHL                     │
├─────────────────────────────────────────────┤
│  Search: [_______________] [🔍]             │
│                                             │
│  ┌─────────────────────────────────────┐   │
│  │ 📅 Today's Appointments:            │   │
│  │   10:00 - Johnson, Sarah (Portrait) │ ◀ │
│  │   14:00 - Williams, Mike (Newborn)  │   │
│  ├─────────────────────────────────────┤   │
│  │ 🔍 Search Results:                  │   │
│  │   Smith, John - j.smith@email.com   │   │
│  │   Smith, Jane - jane.smith@test.com │   │
│  └─────────────────────────────────────┘   │
│                                             │
│  [Select]  [New Contact]  [Cancel]          │
└─────────────────────────────────────────────┘
```

---

## Phase 4: ProSelect Integration (Week 4-5)

### 4.1 Album Creation from GHL

**Enhance existing PsConsole integration:**

```
PsConsole Commands:
- CreateAlbum <path>
- OpenAlbum <path>
- SetClientName <name>
- SetClientEmail <email>
- SetClientPhone <phone>
- AddImages <folder>
- SetOrderNo <order_no>
```

### 4.2 Album Status Sync

After ProSelect session:
1. Read order total from PS
2. Update GHL opportunity value
3. Update GHL pipeline stage
4. Create follow-up task in GHL

### 4.3 Invoice/Order XML Watcher (NEW)

**ProSelect exports XML to watched folder → Parse → Update GHL**

```
Watch Folder: C:\Users\guy\OneDrive\Documents\Proselect Order Exports\
Trigger: New .xml file detected
```

**ProSelect XML Structure (Actual):**
```xml
<Client format="xmlstd" proselectversion="25.1.2">
  <Album_Name>P26008P_Louise</Album_Name>
  <Client_ID>P26008P</Client_ID>
  <Email_Address>claire.atkins4@live.com</Email_Address>
  <First_Name>Claire</First_Name>
  <Last_Name>Steadman</Last_Name>
  <Cell_Phone>+447590591223</Cell_Phone>
  <Street>441 Barnacres Road</Street>
  <City>Hemel Hempstead</City>
  <Zip_Code>HP3 8JS</Zip_Code>
  <Album_Path>D:\Shoot_Archive\...\P26008P_Louise.psa</Album_Path>
  <Order>
    <Date>01/27/2026</Date>
    <DateSQL>2026-01-27</DateSQL>
    <Album_ID>P26008P_Louise-1</Album_ID>
    <Total_Amount>540.00</Total_Amount>
    <Ordered_Items>
      <Ordered_Item>
        <ItemType>Print</ItemType>
        <Description>14.0 x 11.0in Custom Print</Description>
        <Extended_Price>185.00</Extended_Price>
        <Quantity>1</Quantity>
      </Ordered_Item>
      ...
    </Ordered_Items>
    <Payments>
      <Payment id="1">
        <DateSQL>2026-02-07</DateSQL>
        <Amount>54.00</Amount>
        <MethodName>GoCardless DD</MethodName>
        <Type>OD</Type>  <!-- OD=Ordered, FP=Final Payment -->
      </Payment>
      ...
    </Payments>
  </Order>
</Client>
```

**XML → GHL Field Mapping:**

| PS XML Path | GHL Custom Field | Notes |
|-------------|------------------|-------|
| `Client_ID` | Match by `session_job_no` | Find existing contact |
| `Email_Address` | Match by email | Fallback lookup |
| `Order/Total_Amount` | `order_total` | e.g., £540.00 |
| `Order/DateSQL` | `order_date` | 2026-01-27 |
| `Album_Path` | `proselect_album` | Path to .psa file |
| Sum of Payments where Type=OD | `balance_due` | Scheduled payments |
| Total - Balance | `deposit_paid` | Already paid |
| Ordered_Items summary | `order_summary` | "4x Custom Print, 2x Credits" |
| Derived from payments | `order_status` | "Payment Plan Active" |
| Last Payment DateSQL | `delivery_date` | Expected completion |

**Payment Status Logic:**
```python
total_scheduled = sum(p.Amount for p in Payments)
if total_scheduled == 0:
    status = "Paid in Full"
elif total_scheduled < Total_Amount:
    status = "Deposit Paid"
else:
    status = "Payment Plan Active"
```

**Implementation:**

```python
# sync_ps_invoice.py - Parse ProSelect XML → Update GHL
import xml.etree.ElementTree as ET
import requests
import sys

def parse_proselect_xml(xml_path):
    tree = ET.parse(xml_path)
    root = tree.getroot()
    
    data = {
        'client_id': root.find('Client_ID').text,
        'email': root.find('Email_Address').text,
        'name': f"{root.find('First_Name').text} {root.find('Last_Name').text}",
        'phone': root.find('Cell_Phone').text,
        'album_path': root.find('Album_Path').text,
        'order_date': root.find('Order/DateSQL').text,
        'order_total': float(root.find('Order/Total_Amount').text),
        'items': [],
        'payments': []
    }
    
    # Parse ordered items
    for item in root.findall('.//Ordered_Item'):
        data['items'].append({
            'type': item.find('ItemType').text,
            'description': item.find('Description').text,
            'price': float(item.find('Extended_Price').text),
            'qty': int(item.find('Quantity').text)
        })
    
    # Parse scheduled payments
    for payment in root.findall('.//Payment'):
        data['payments'].append({
            'date': payment.find('DateSQL').text,
            'amount': float(payment.find('Amount').text),
            'method': payment.find('MethodName').text
        })
    
    return data

def find_ghl_contact(email, client_id, api_key):
    # Search by email first, then by client_id in custom field
    ...

def update_ghl_contact(contact_id, order_data, api_key):
    # Update custom fields with order data
    ...
```

**AHK Integration:**
```ahk
; Settings
global PSExportPath := "C:\Users\guy\OneDrive\Documents\Proselect Order Exports"

; Timer to check every 30 seconds
SetTimer, CheckPSExportFolder, 30000

CheckPSExportFolder:
  Loop, Files, %PSExportPath%\*.xml
  {
    ; Run Python to process and sync to GHL
    RunWait, python.exe "%A_ScriptDir%\sync_ps_invoice.py" "%A_LoopFileFullPath%"
    
    ; Move to processed folder
    FileCreateDir, %PSExportPath%\Processed
    FileMove, %A_LoopFileFullPath%, %PSExportPath%\Processed\
    
    ; Notification
    TrayTip, SideKick, Order synced to GHL: %A_LoopFileName%, 5
  }
Return
```

### 4.4 Image Delivery Automation

When album marked "Delivered":
1. Generate delivery gallery link (or upload to GHL)
2. Send delivery notification via GHL
3. Update GHL status
4. Archive album

---

## Phase 5: Licensing & Monetization (Week 5)

### 5.1 LemonSqueezy Setup

**Account Setup:**
1. ✅ Store: zoomphoto.lemonsqueezy.com
2. ✅ Product created: SideKick PS - Studio Automation
3. ✅ Checkout URL: https://zoomphoto.lemonsqueezy.com/checkout/buy/234060d4-063d-4e6f-b91b-744c254c0e7c

**Product Configuration:**
| Setting | Value |
|---------|-------|
| Product Type | Software License |
| Pricing Model | One-time or Subscription |
| License Key | Auto-generate on purchase |
| Activation Limit | 2 machines per license |
| Product ID | 234060d4-063d-4e6f-b91b-744c254c0e7c |

**API Credentials:**
```ini
[LemonSqueezy]
StoreURL=https://zoomphoto.lemonsqueezy.com
ProductID=234060d4-063d-4e6f-b91b-744c254c0e7c
APIKey=[Settings → API → Create Key]
WebhookSecret=[Settings → Webhooks]
```

### 5.2 License Validation in AHK

**Settings to add to INI:**
```ini
[License]
LicenseKey=
MachineId=
ActivatedDate=
LicenseStatus=trial|active|expired
TrialDaysRemaining=14
```

**New Python script: `validate_license.py`**
```python
import requests
import hashlib
import platform
import uuid
import sys
import json

LEMON_API_URL = "https://api.lemonsqueezy.com/v1"

def get_machine_id():
    """Generate unique machine fingerprint"""
    info = f"{platform.node()}-{platform.machine()}-{uuid.getnode()}"
    return hashlib.sha256(info.encode()).hexdigest()[:32]

def validate_license(license_key, api_key):
    """Validate license key with LemonSqueezy"""
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json"
    }
    
    # Validate the license key
    response = requests.post(
        f"{LEMON_API_URL}/licenses/validate",
        headers=headers,
        json={
            "license_key": license_key,
            "instance_name": get_machine_id()
        }
    )
    
    return response.json()

def activate_license(license_key, api_key):
    """Activate license on this machine"""
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json"
    }
    
    response = requests.post(
        f"{LEMON_API_URL}/licenses/activate",
        headers=headers,
        json={
            "license_key": license_key,
            "instance_name": get_machine_id()
        }
    )
    
    return response.json()

if __name__ == "__main__":
    action = sys.argv[1]  # validate or activate
    license_key = sys.argv[2]
    api_key = sys.argv[3]
    
    if action == "validate":
        result = validate_license(license_key, api_key)
    elif action == "activate":
        result = activate_license(license_key, api_key)
    
    print(json.dumps(result))
```

### 5.3 AHK License Integration

**New Label: CheckLicense**
```ahk
CheckLicense:
  ; Read license from INI
  IniRead, LicenseKey, %IniFile%, License, LicenseKey, 
  IniRead, LicenseStatus, %IniFile%, License, LicenseStatus, trial
  IniRead, TrialDaysRemaining, %IniFile%, License, TrialDaysRemaining, 14
  
  if (LicenseKey = "") {
    ; Trial mode
    if (TrialDaysRemaining <= 0) {
      MsgBox, 48, Trial Expired, Your trial has expired. Please purchase a license.
      Gosub, ShowLicenseDialog
      return
    }
    ; Decrement trial days (once per day)
    ; ...
  } else {
    ; Validate existing license
    RunWait, python.exe "%A_ScriptDir%\validate_license.py" "validate" "%LicenseKey%" "%LemonAPIKey%"
    ; Parse result and update status
  }
Return
```

**New Label: ShowLicenseDialog**
```ahk
; License entry GUI
Gui, License:New, +Owner
Gui, Add, Text,, Enter your license key:
Gui, Add, Edit, vLicenseKeyInput w300
Gui, Add, Button, gActivateLicense w100, Activate
Gui, Add, Button, gBuyLicense x+10 w100, Buy License
Gui, Add, Text,, Or purchase online:
Gui, Add, Link,, <a href="https://zoomphoto.lemonsqueezy.com/checkout/buy/234060d4-063d-4e6f-b91b-744c254c0e7c">Buy SideKick_PS</a>
Gui, Show,, SideKick PS - License
Return

BuyLicense:
  Run, https://zoomphoto.lemonsqueezy.com/checkout/buy/234060d4-063d-4e6f-b91b-744c254c0e7c
Return
```

### 5.4 Settings GUI - License Tab

**Add to Settings GUI:**
```
┌─────────────────────────────────────────────┐
│  License                                    │
├─────────────────────────────────────────────┤
│  Status: ● Active (or Trial: 12 days left) │
│                                             │
│  License Key: [XXXX-XXXX-XXXX-XXXX    ]    │
│  Machine ID:  a1b2c3d4e5f6...              │
│  Activated:   2026-01-29                    │
│                                             │
│  [Activate]  [Deactivate]  [Buy License]   │
│                                             │
│  ─────────────────────────────────────────  │
│  Licensed to: John Smith                    │
│  Email: john@studio.com                     │
│  Expires: Never (Lifetime) / 2027-01-29     │
└─────────────────────────────────────────────┘
```

### 5.5 Pricing Tiers (Suggested)

| Tier | Price | Features |
|------|-------|----------|
| **Trial** | Free | 14 days full access |
| **Personal** | £49 one-time | 1 machine, basic features |
| **Studio** | £99 one-time | 2 machines, all features, updates 1 year |
| **Studio+** | £149 one-time | 2 machines, lifetime updates |
| **Subscription** | £9.99/mo | 2 machines, always latest, priority support |

---

## Phase 6: Automation & Polish (Week 6)

### 6.1 Event-Driven Triggers

| Trigger | Action |
|---------|--------|
| SD Card inserted | Prompt to download |
| GHL appointment today | Show in dashboard |
| ProSelect order saved | Sync to GHL |
| Delivery date reached | Remind to deliver |

### 6.2 Hotkeys

| Hotkey | Action |
|--------|--------|
| `Ctrl+Shift+D` | Download SD card |
| `Ctrl+Shift+G` | GHL client lookup (exists) |
| `Ctrl+Shift+N` | New shoot (GHL→download→PS) |
| `Ctrl+Shift+A` | Open archive folder |
| `Ctrl+Shift+P` | Payment plan (exists) |

### 6.3 Toolbar (Like LB Toolbar)

Floating toolbar when ProSelect is active:
- GHL Client button
- Archive folder button
- Payment plan button
- Sync to GHL button

---

## Migration Strategy

### What to Port from SideKick_LB_PubAI.ahk

| Feature | LB Lines | Priority | Effort |
|---------|----------|----------|--------|
| SD Card Download | 2563-2750 | HIGH | Medium |
| File Renaming | 2756-2870 | HIGH | Low |
| Archive Management | 3018-3128 | HIGH | Low |
| QR Code Generator | 1880-2130 | LOW | Medium |
| Floating Toolbar | 4187-4400 | MEDIUM | Medium |
| Progress GUI | 3844-3940 | HIGH | Low |

### What Stays in LB (Until Deprecated)

- LB-specific ACC scraping
- LB window detection
- LB diary reading
- LB→GHL sync (replaced by GHL-native)

---

## File Structure After Migration

```
C:\Stash\
├── SideKick_PS.ahk              # Main script (~5000+ lines)
├── SideKick_PS.ini              # Settings
├── lib\
│   ├── SK_FileManager.ahk       # Card download, file ops
│   ├── SK_GHL_API.ahk           # GHL integration functions
│   ├── SK_GUI_Dashboard.ahk     # Main dashboard GUI
│   ├── SK_GUI_Settings.ahk      # Settings GUI
│   ├── SK_Progress.ahk          # Progress indicators
│   └── SK_InvoiceWatcher.ahk    # PS XML folder watcher
├── fetch_ghl_contact.py         # GHL API - fetch
├── update_ghl_contact.py        # GHL API - update
├── upload_ghl_media.py          # GHL API - media
├── search_ghl_contacts.py       # GHL API - search (NEW)
└── sync_ps_invoice.py           # Parse PS XML → GHL (NEW)
```

---

## Implementation Order

### Sprint 1 (Days 1-3): Foundation
1. ☐ Create `lib\SK_FileManager.ahk` module
2. ☐ Port SD card detection from LB
3. ☐ Port file copy with progress from LB
4. ☐ Add File Management settings tab

### Sprint 2 (Days 4-6): Card Download
5. ☐ Create Card Download GUI
6. ☐ Implement auto-increment shoot number
7. ☐ Port file renaming options
8. ☐ Test end-to-end card download

### Sprint 3 (Days 7-9): GHL Enhancement
9. ☐ Create `search_ghl_contacts.py`
10. ☐ Add today's appointments feature
11. ☐ Link card download to GHL contact
12. ☐ Add new GHL custom fields

### Sprint 4 (Days 10-12): ProSelect Flow
13. ☐ Create GHL→PS album workflow
14. ☐ Update GHL with album path after creation
15. ☐ Add hotkeys for new functions
16. ☐ Testing and polish

---

## Success Metrics

After implementation:
- [ ] Can download SD card and create numbered shoot folder
- [ ] Can link shoot to GHL contact
- [ ] Can create ProSelect album from GHL data
- [ ] Can see today's GHL appointments in dashboard
- [ ] No dependency on Light Blue for new shoots

---

## Notes

- Keep SideKick_LB running alongside during transition
- Maintain backward compatibility with existing archive structure
- Use same shoot numbering scheme as LB for continuity
- GHL becomes single source of truth for client data

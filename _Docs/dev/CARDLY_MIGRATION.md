# Cardly Migration Plan: SideKick_LB → SideKick_PS

> Internal development document — Cardly postcard feature migration from SideKick_LB to SideKick_PS

## Overview

Port the Cardly greeting card / postcard functionality from SideKick_LB into SideKick_PS, reusing the same GHL integration pattern and Cardly API v2 workflow. PS already has the GHL media upload and contact update pipelines — this migration adds the Cardly-specific preview GUI, card sending, and settings.

---

## Image Source Strategy

The preview GUI will have a **source dropdown** with 3 options:

| Source | Default | Description |
|--------|---------|-------------|
| **Order Images** | ✅ Yes | Finds the latest XML export in the watch folder, parses `<Image_Name>` to identify ordered images, then cross-references with the PSA file's `Thumbnails` table (SQLite) to extract medium-quality JPGs of just the ordered images. Falls back to `<Original_Image>` hi-res TIF paths if available. |
| **Album Folder** | | Uses `GetAlbumFolder()` to get the current ProSelect album's image directory (all images, not just ordered) |
| **Browse...** | | File picker to manually choose any folder |

### PSA File as Image Source

The `.psa` album file is a **SQLite database** containing:

| Table | Content |
|-------|---------|
| `BigStrings` (`ImageList`) | XML list of ALL album images with `<image name="...">` and `<albumimage id="N" />` |
| `BigStrings` (`OrderList`) | Customer info, payments, order items (minimal image refs — just type/qty/price) |
| `Thumbnails` | JPEG thumbnails keyed by `imageID` (type 1 = main thumbnails, `FFD8` JPEG blobs) |
| `BigImages` | Full-resolution image blobs |

### Order Images Resolution Chain

To get **only the ordered images** (not the entire album), we need both the XML export and the PSA:

```
1. XML Export → parse <Image_Name> entries → identifies WHICH images were ordered
2. PSA Thumbnails → extract ALL album thumbnails by albumimage ID  
3. Cross-reference → filter thumbnails to only the ordered image names
4. Present filtered set in filmstrip
```

Alternatively, the XML provides `<Original_Image>` hi-res TIF paths (e.g. `D:\Shoot_Archive\...\P25073P0160.tif`) which can be used directly if available on disk.

### Export Folder Structure
```
Proselect Order Exports/
  2026-02-19_131910_P25073P__1.xml      ← Order data + <Image_Name> + <Original_Image> paths
  2026-02-19_131910_P25073P__1/         ← Low-res export images (Product_Print_*.jpg, ~38-80 KB)
```

### Image Quality Hierarchy
| Source | Quality | Format |
|--------|---------|--------|
| `<Original_Image>` paths from XML | **Hi-res original** | TIF |
| PSA `Thumbnails` table | **Medium** (embedded JPG) | JPEG |
| Export folder `Product_Print_*.jpg` | **Low-res preview** | JPEG |

---

## Files to Create (3)

### 1. `cardly_preview_gui.py`
- **Source:** Copy from `SideKick_LB/cardly_preview_gui.py` (1,128 lines)
- **Compiled name:** `_cpg.exe`
- **Changes needed:**
  - AppData path: `SideKick_LB` → `SideKick_PS`
  - Add `*.tif` to image scan patterns (for hi-res originals from `<Original_Image>`)
  - Add PSA thumbnail extraction mode: accept `--psa <path>` + `--xml <path>` args to extract ordered images from PSA SQLite `Thumbnails` table, filtered by XML `<Image_Name>` entries
  - Remove LB-specific "For Printing" folder navigation logic
  - Add image source dropdown: Order Images (default) / Album Folder / Browse
  - Update credential file path to `%AppData%\SideKick_PS\credentials.json`

### 2. `cardly_send_card.py`
- **Source:** Copy from `SideKick_LB/cardly_send_card_LB.py` (964 lines)
- **Compiled name:** Hidden import of `_cpg.exe`
- **Changes needed:**
  - Drop `_LB` suffix from filename
  - Update credential path to `SideKick_PS`
  - Same Cardly API v2 logic (image processing, artwork upload, order placement)

### 3. `stickers/` folder
- **Source:** Copy from `SideKick_LB/stickers/`
- **Contents:** PNG overlay files for card customization
- **No changes needed**

---

## Files to Modify (6)

### 4. `SideKick_PS.ahk` — Main Script
| Area | Changes |
|------|---------|
| **Globals** | Add `Cardly_*` variables (ApiKey, MediaID, MediaName, etc.) |
| **INI Read** | Add `[Cardly]` section reading in settings load |
| **`scriptMap`** | Add `"cardly_preview_gui": "_cpg"` entry |
| **Toolbar** | Add Cardly/Postcard button (conditional on `TB_Cardly_Enabled`) |
| **`SendCardlyCard` label** | New label: determine image source (order/album/browse), gather contact ID + first name, read message from GHL custom field, launch `_cpg.exe` with args |
| **Order image source** | Find latest export folder in watch folder, scan for `Product_Print_*.jpg`, optionally parse XML for `<Original_Image>` hi-res paths |

### 5. `Lib/SK_GUI_Settings.ahk` — Settings GUI
| Area | Changes |
|------|---------|
| **Sidebar** | Add "Cardly" nav button to `NavBtns` array |
| **Cardly panel** | New panel with: Cardly Dashboard URL, API Key (masked), Template MediaID + MediaName, Default message (multi-line), Postcard save folder, GHL Media folder ID/Name, Photo Link custom field, Card dimensions, AutoSend toggle |
| **Save handler** | Write `[Cardly]` values back to INI |
| **Show/Hide** | Add Cardly panel to tab switching logic |

### 6. `SideKick_PS.ini` — INI Config
Add new `[Cardly]` section:
```ini
[Cardly]
DashboardURL=
MessageField=Message
AutoSend=1
MediaID=
MediaName=
DefaultMessage=
PostcardFolder=
CardWidth=2913
CardHeight=2125
GHLMediaFolderID=
GHLMediaFolderName=Client Photos
PhotoLinkField=Contact Photo Link
```

### 7. `build_and_archive.ps1` — Build Script
| Area | Changes |
|------|---------|
| `$scriptNameMap` | Add `"cardly_preview_gui" = "_cpg"` |
| `$hiddenImports` | Add `"cardly_preview_gui" = @("cardly_send_card")` |
| File copy | Add `stickers\` folder copy to `Release\stickers\` |

### 8. `installer.iss` — Inno Setup Installer
| Area | Changes |
|------|---------|
| `[Files]` | Add `_cpg.exe` entry with `skipifsourcedoesntexist` |
| `[Files]` | Add `stickers\*` folder entry with `recursesubdirs` |

### 9. `SideKick_PS_Documentation.md` — Documentation
| Area | Changes |
|------|---------|
| New section | "Cardly Postcard Integration" — feature description, workflow, settings reference |
| INI reference | Document `[Cardly]` keys |
| Toolbar reference | Add Cardly button description |

---

## Files Already Supporting Cardly (No Changes)

| File | Compiled | Purpose |
|------|----------|---------|
| `upload_ghl_media.py` | `_upm.exe` | Post-send: uploads clean JPG to GHL Media folder ✅ |
| `update_ghl_contact.py` | `_ugc.exe` | Post-send: writes photo URL to GHL contact field ✅ |
| `fetch_ghl_contact.py` | `_fgc.exe` | Fetches contact data (name, address, custom fields) ✅ |
| `GetScriptPath()` | — | EXE/PY detection + path resolution ✅ |
| `credentials.json` | — | Existing credential storage infrastructure ✅ |

---

## Implementation Order

| Step | Task | Dependencies |
|------|------|-------------|
| 1 | Copy & adapt `cardly_preview_gui.py` | — |
| 2 | Copy & adapt `cardly_send_card.py` | — |
| 3 | Copy `stickers/` folder | — |
| 4 | Add `[Cardly]` INI section + defaults | — |
| 5 | Add Cardly settings GUI tab | Step 4 |
| 6 | Add Cardly toolbar button + `SendCardlyCard` AHK logic | Steps 1-4 |
| 7 | Update build script + installer | Steps 1-3 |
| 8 | Update documentation | Steps 5-6 |
| 9 | Sync to Release & test build | All above |

---

## Key Design Decisions

1. **Image source default = Order Images** — scans latest export folder in watch folder for `Product_Print_*.jpg` (individual images, not composites). Falls back to browse if no exports found.
2. **Album folder** — available as secondary option, uses existing `GetAlbumFolder()` from ProSelect.
3. **Browse** — manual override for any folder.
4. **Credentials** — stored in `%AppData%\SideKick_PS\credentials.json` (existing pattern), adds `cardly_api_key_b64` field.
5. **Sticker overlays** — same PNG stickers as LB, shared artwork.
6. **Post-send workflow** — identical to LB: save clean JPG → upload to GHL Media → update contact Photo Link field.

---

## Cardly API Reference

- **API:** `https://api.card.ly/v2`
- **Auth:** Base64-encoded API key in `Authorization: Basic {key}` header
- **Artwork:** PNG only, sRGB, under 1 MB, 2913×2125 px (185×135 mm + 5 mm bleed)
- **Print spec:** 400 dpi, 320 gsm uncoated FSC-certified stock
- **Shipping:** From AU, UK, US, or Canada depending on destination

---

*Last updated: 2026-02-25*
    
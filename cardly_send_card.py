"""
Cardly Card Sending Module
Copyright (c) 2026 GuyMayer. All rights reserved.
Sends personalized greeting cards via Cardly API with custom artwork.

Usage:
  python cardly_send_card.py <image_path> <contact_id> <message> [crop_x] [crop_y] [zoom] [--debug]

The script will:
1. Resize/convert image to Cardly Landscape Card specs:
   - Full size: 2913x2125px (185x135mm with 5mm bleed)
   - Safe area: 2755x1968px (175x125mm trimmed)
   - Format: PNG or JPEG, sRGB colour, under 1MB
2. Upload image to GHL contact's Photos field
3. Create custom artwork on Cardly
4. Place order to send the card

Crop parameters (all 0-100 percentages):
  crop_x: Horizontal position (0=left, 50=center, 100=right)
  crop_y: Vertical position (0=top, 50=center, 100=bottom)
  zoom: Zoom level (100=fit card, 200=2x zoom)

Cardly prints at 400dpi on 320gsm uncoated FSC-certified card stock.

Requires: credentials.json with cardly_api_key_b64 and cardly_media_id
"""

import subprocess
import sys
import json
import os
import io
import base64
import re
from pathlib import Path

# Auto-install dependencies
def install_dependencies() -> None:
    """Auto-install required Python packages if not present."""
    required = ['requests', 'pillow']
    for package in required:
        try:
            __import__(package if package != 'pillow' else 'PIL')
        except ImportError:
            subprocess.check_call([sys.executable, '-m', 'pip', 'install', package, '-q'])

install_dependencies()

import requests
from PIL import Image, ImageCms
from PIL.ExifTags import Base as ExifBase

# sRGB ICC profile for colour-accurate output
_SRGB_PROFILE = ImageCms.createProfile('sRGB')

# =============================================================================
# Configuration
# =============================================================================

def _get_script_dir():
    """Get script directory (handles both .py and compiled .exe)."""
    if getattr(sys, 'frozen', False):
        return os.path.dirname(sys.executable)
    return os.path.dirname(os.path.abspath(__file__))

def _decode_api_key(encoded: str) -> str:
    """Decode base64-encoded API key."""
    try:
        cleaned = encoded.strip().replace('\n', '').replace('\r', '').replace(' ', '')
        return base64.b64decode(cleaned).decode('utf-8')
    except Exception:
        return ""

def _load_cardly_credentials():
    """Load Cardly API credentials from credentials.json (shared with GHL/Cloudflare)."""
    script_dir = _get_script_dir()
    possible_paths = [
        os.path.join(script_dir, "credentials.json"),
        os.path.join(os.path.dirname(script_dir), "credentials.json"),
        os.path.join(os.environ.get('APPDATA', ''), "SideKick_PS", "credentials.json"),
        # Legacy fallback
        os.path.join(script_dir, "cardly_credentials.json"),
    ]

    for cred_path in possible_paths:
        if os.path.exists(cred_path):
            try:
                with open(cred_path, 'r', encoding='utf-8') as f:
                    content = f.read()

                # Try new format (base64 encoded in shared credentials.json)
                cardly_key_match = re.search(r'"cardly_api_key_b64"\s*:\s*"([^"]*)"', content)
                if cardly_key_match:
                    api_key = _decode_api_key(cardly_key_match.group(1)) if cardly_key_match.group(1) else ''
                    media_match = re.search(r'"cardly_media_id"\s*:\s*"([^"]*)"', content)
                    media_id = media_match.group(1) if media_match else ''
                    dash_match = re.search(r'"cardly_dashboard_url"\s*:\s*"([^"]*)"', content)
                    dashboard_url = dash_match.group(1) if dash_match else ''
                    if api_key:
                        return api_key, media_id, {'dashboard_url': dashboard_url}

                # Legacy format (plain api_key in cardly_credentials.json)
                data = json.loads(content)
                api_key = data.get('api_key', '')
                if api_key.startswith('live_') or api_key.startswith('test_'):
                    return api_key, data.get('media_id', ''), data
                elif api_key:
                    return _decode_api_key(api_key), data.get('media_id', ''), data

            except Exception as e:
                print(f"[WARN] Error loading {cred_path}: {e}")
                continue
    return '', '', {}

def _load_ghl_credentials():
    """Load GHL API credentials from ghl_credentials.json."""
    script_dir = _get_script_dir()
    possible_paths = [
        os.path.join(script_dir, "ghl_credentials.json"),
        os.path.join(os.path.dirname(script_dir), "ghl_credentials.json"),
        os.path.join(os.environ.get('APPDATA', ''), "SideKick_PS", "ghl_credentials.json"),
        os.path.join(os.environ.get('APPDATA', ''), "SideKick_PS", "credentials.json"),
    ]

    for cred_path in possible_paths:
        if os.path.exists(cred_path):
            try:
                with open(cred_path, 'r', encoding='utf-8') as f:
                    content = f.read()
                api_match = re.search(r'"api_key_b64"\s*:\s*"([^"]+)"', content)
                api_key = _decode_api_key(api_match.group(1)) if api_match else ''
                loc_match = re.search(r'"location_id"\s*:\s*"([^"]+)"', content)
                location_id = loc_match.group(1) if loc_match else ''
                if api_key:
                    return api_key, location_id
            except Exception:
                continue
    return '', ''

# Load credentials
CARDLY_API_KEY, CARDLY_MEDIA_ID, CARDLY_CONFIG = _load_cardly_credentials()
GHL_API_KEY, GHL_LOCATION_ID = _load_ghl_credentials()

DEBUG = "--debug" in sys.argv

# Cardly Landscape Card specifications (from official PDF)
# Full size with 5mm bleed on all sides
CARDLY_WIDTH = 2913           # 185mm at 400dpi
CARDLY_HEIGHT = 2125          # 135mm at 400dpi
# Trimmed/safe area (key content should be within this)
CARDLY_SAFE_WIDTH = 2755      # 175mm trimmed
CARDLY_SAFE_HEIGHT = 1968     # 125mm trimmed
# Bleed margin in pixels (5mm at 400dpi = ~79px)
CARDLY_BLEED_PX = 79
CARDLY_MAX_SIZE_MB = 5.0

# API endpoints
CARDLY_BASE_URL = "https://api.card.ly/v2"
GHL_BASE_URL = "https://services.leadconnectorhq.com"

# Cache for GHL custom field IDs (address2/address3 are custom fields in GHL)
_ghl_address_field_ids = {}  # e.g. {"address2": "9ZaP...", "address3": "LtIw..."}

def _get_ghl_address_field_ids() -> dict:
    """Fetch and cache GHL custom field IDs for Address2 and Address3.

    GHL stores address2/address3 as custom fields (fieldKey: contact.address2,
    contact.address3) rather than standard contact fields. This function calls
    the custom fields API once per session to look up their IDs.
    """
    global _ghl_address_field_ids
    if _ghl_address_field_ids:
        return _ghl_address_field_ids

    if not GHL_API_KEY or not GHL_LOCATION_ID:
        return {}

    try:
        headers = {
            "Authorization": f"Bearer {GHL_API_KEY}",
            "Version": "2021-07-28"
        }
        url = f"{GHL_BASE_URL}/locations/{GHL_LOCATION_ID}/customFields"
        resp = requests.get(url, headers=headers, timeout=10)
        if resp.status_code == 200:
            for cf in resp.json().get('customFields', []):
                fk = cf.get('fieldKey', '')
                if fk == 'contact.address2':
                    _ghl_address_field_ids['address2'] = cf['id']
                elif fk == 'contact.address3':
                    _ghl_address_field_ids['address3'] = cf['id']
    except Exception:
        pass  # Silently fail — address2/3 won't be available but core works

    return _ghl_address_field_ids

def _enrich_contact_address(contact: dict) -> None:
    """Populate address2/address3 from GHL customFields array.

    Modifies the contact dict in place, setting 'address2' and 'address3'
    from the customFields entries if present.
    """
    custom_fields = contact.get('customFields', [])
    if not custom_fields:
        return

    field_ids = _get_ghl_address_field_ids()
    if not field_ids:
        return

    cf_lookup = {cf['id']: cf.get('value', '') for cf in custom_fields if 'id' in cf}
    for field_name, field_id in field_ids.items():
        if field_id in cf_lookup and cf_lookup[field_id]:
            contact[field_name] = cf_lookup[field_id]

def _get_output_dir():
    """Get a writable directory for output files."""
    appdata = os.environ.get('APPDATA')
    if appdata:
        sidekick_dir = os.path.join(appdata, 'SideKick_PS')
        try:
            os.makedirs(sidekick_dir, exist_ok=True)
            return sidekick_dir
        except OSError:
            pass
    return os.environ.get('TEMP', os.getcwd())

def debug_print(msg):
    """Print debug message if debug mode is enabled."""
    if DEBUG:
        print(f"[DEBUG] {msg}")

# =============================================================================
# Image Processing
# =============================================================================

def resize_image_for_cardly(image_path: str, output_path: str = None,
                            crop_x: int = 50, crop_y: int = 50, zoom: int = 100,
                            sticker_path: str = None, sticker_x: int = 75, sticker_y: int = 75,
                            sticker_zoom: int = 50,
                            card_width: int = None, card_height: int = None,
                            skip_icc: bool = False) -> str:
    """
    Resize and convert image to Cardly card requirements.

    Card dimensions are passed from the template selection (API art.px.width/height).
    Falls back to Landscape Card defaults (2913x2125) if not specified.

    Crop parameters:
    - crop_x: 0-100, horizontal position (0=left, 50=center, 100=right)
    - crop_y: 0-100, vertical position (0=top, 50=center, 100=bottom)
    - zoom: 100-200, zoom level (100=fill card, 200=2x zoom in)

    Sticker parameters:
    - sticker_path: Path to PNG sticker file (None = no sticker)
    - sticker_x: 0-100, horizontal position (0=left, 100=right)
    - sticker_y: 0-100, vertical position (0=top, 100=bottom)

    Card dimensions:
    - card_width: Target width in pixels (from Cardly API art.px.width)
    - card_height: Target height in pixels (from Cardly API art.px.height)

    Returns path to processed image.
    """
    if output_path is None:
        output_dir = _get_output_dir()
        output_path = os.path.join(output_dir, "cardly_processed.png")

    debug_print(f"Processing image: {image_path}")
    debug_print(f"Crop settings: x={crop_x}%, y={crop_y}%, zoom={zoom}%")

    # Use supplied dimensions or fall back to module defaults
    target_w = int(card_width) if card_width else CARDLY_WIDTH
    target_h = int(card_height) if card_height else CARDLY_HEIGHT
    debug_print(f"Target card size: {target_w}x{target_h}px")

    with Image.open(image_path) as img:
        # ── Auto-orient from EXIF ("Don't rotate any images") ──
        # Apply EXIF orientation so the image is upright before processing.
        # Cardly says: "provide them in the same orientation as you would view them."
        try:
            from PIL import ImageOps
            img = ImageOps.exif_transpose(img)
        except Exception:
            pass  # no EXIF or unsupported – carry on

        # ── Colour-space conversion to RGB / sRGB ──
        # Cardly requires RGB colour, not CMYK.  We use ICC-aware transforms
        # when the source image embeds a colour profile for accurate conversion.
        src_icc = img.info.get('icc_profile')

        if img.mode == 'CMYK':
            # CMYK must always be converted to RGB (ICC-aware when possible)
            if src_icc and not skip_icc:
                try:
                    src_prof = ImageCms.ImageCmsProfile(io.BytesIO(src_icc))
                    img = ImageCms.profileToProfile(
                        img, src_prof, _SRGB_PROFILE,
                        renderingIntent=ImageCms.Intent.PERCEPTUAL,
                        outputMode='RGB'
                    )
                    debug_print("CMYK → sRGB via embedded ICC profile")
                except Exception as e:
                    debug_print(f"[WARN] ICC transform failed, falling back to naive convert: {e}")
                    img = img.convert('RGB')
            else:
                debug_print("CMYK image – naive convert to RGB (skip_icc={})" .format(skip_icc))
                img = img.convert('RGB')

        elif img.mode in ('RGBA', 'LA', 'P'):
            # Flatten transparency onto white (Cardly prints on white stock)
            background = Image.new('RGB', img.size, (255, 255, 255))
            if img.mode == 'P':
                img = img.convert('RGBA')
            background.paste(img, mask=img.split()[-1] if img.mode in ('RGBA', 'LA') else None)
            img = background
            debug_print(f"Flattened transparency onto white background")

        elif img.mode != 'RGB':
            # L, I, F, etc.
            img = img.convert('RGB')
            debug_print(f"Converted {img.mode} → RGB")

        # ── Convert non-sRGB RGB images (e.g. Adobe RGB) → sRGB ──
        # ProSelect may export in Adobe RGB (1998) which has a wider gamut.
        # A direct pass-through would cause washed-out / shifted colours on
        # Cardly's sRGB print pipeline, so we do an ICC-aware transform.
        if not skip_icc and img.mode == 'RGB' and src_icc:
            try:
                src_prof = ImageCms.ImageCmsProfile(io.BytesIO(src_icc))
                prof_desc = ImageCms.getProfileDescription(src_prof).strip()
                # Only transform if the profile is NOT already sRGB
                if prof_desc and 'srgb' not in prof_desc.lower():
                    img = ImageCms.profileToProfile(
                        img, src_prof, _SRGB_PROFILE,
                        renderingIntent=ImageCms.Intent.PERCEPTUAL,
                        outputMode='RGB'
                    )
                    debug_print(f"Converted '{prof_desc}' → sRGB via ICC transform")
                else:
                    debug_print(f"Source already sRGB ('{prof_desc}') – no conversion needed")
            except Exception as e:
                debug_print(f"[WARN] ICC profile read/transform failed, using as-is: {e}")
        elif skip_icc:
            debug_print("Skipping ICC profile conversion (skip_icc=True)")

        # Strip any leftover ICC profile – we embed sRGB on save instead
        if 'icc_profile' in img.info:
            del img.info['icc_profile']

        orig_w, orig_h = img.size
        target_ratio = target_w / target_h

        # Calculate zoom-adjusted crop area
        # At zoom=100, we take the largest area that matches card ratio
        # At zoom=200, we take half that area (2x zoom in)
        zoom_factor = zoom / 100.0

        # Determine the crop area size based on source image orientation
        orig_ratio = orig_w / orig_h

        if orig_ratio >= target_ratio:
            # Image is wider than card ratio - constrain by height
            base_crop_h = orig_h
            base_crop_w = base_crop_h * target_ratio
        else:
            # Image is taller than card ratio - constrain by width
            base_crop_w = orig_w
            base_crop_h = base_crop_w / target_ratio

        # Apply zoom (zoom in = smaller crop area)
        crop_w = base_crop_w / zoom_factor
        crop_h = base_crop_h / zoom_factor

        # Calculate crop position based on crop_x and crop_y percentages
        # crop_x/y: 0=left/top edge, 50=center, 100=right/bottom edge
        max_offset_x = orig_w - crop_w
        max_offset_y = orig_h - crop_h

        # Clamp crop_x and crop_y to 0-100
        crop_x = max(0, min(100, crop_x))
        crop_y = max(0, min(100, crop_y))

        crop_left = max_offset_x * (crop_x / 100.0)
        crop_top = max_offset_y * (crop_y / 100.0)

        debug_print(f"Original: {orig_w}x{orig_h}, Crop area: {crop_w:.0f}x{crop_h:.0f}")
        debug_print(f"Crop position: left={crop_left:.0f}, top={crop_top:.0f}")

        # Crop the selected region
        img = img.crop((
            int(crop_left),
            int(crop_top),
            int(crop_left + crop_w),
            int(crop_top + crop_h)
        ))

        # Resize cropped area to target dimensions
        img = img.resize((target_w, target_h), Image.Resampling.LANCZOS)

        debug_print(f"Final size: {img.size}")

        # Composite sticker overlay if provided
        _sticker_applied = False
        if sticker_path and os.path.exists(sticker_path):
            print(f"[Sticker] Applying: {os.path.basename(sticker_path)} "
                  f"pos=({sticker_x}%, {sticker_y}%) zoom={sticker_zoom}%")
            try:
                with Image.open(sticker_path) as sticker:
                    # Ensure sticker has alpha channel for transparency
                    if sticker.mode != 'RGBA':
                        sticker = sticker.convert('RGBA')

                    # Scale sticker based on sticker_zoom (percentage of card width)
                    sticker_pct = sticker_zoom / 100.0
                    max_sticker_size = int(target_w * sticker_pct)
                    sticker_w, sticker_h = sticker.size

                    # Scale proportionally
                    scale = min(max_sticker_size / sticker_w, max_sticker_size / sticker_h)
                    new_sticker_w = int(sticker_w * scale)
                    new_sticker_h = int(sticker_h * scale)
                    sticker = sticker.resize((new_sticker_w, new_sticker_h), Image.Resampling.LANCZOS)

                    # Calculate sticker position (percentage of card dimensions)
                    # Position is center of sticker, clamped to keep sticker mostly on card
                    pos_x = int((target_w - new_sticker_w) * (sticker_x / 100.0))
                    pos_y = int((target_h - new_sticker_h) * (sticker_y / 100.0))

                    # Convert img to RGBA for compositing, then back to RGB
                    img = img.convert('RGBA')
                    img.paste(sticker, (pos_x, pos_y), sticker)
                    img = img.convert('RGB')
                    _sticker_applied = True

                    print(f"[Sticker] Composited OK: {new_sticker_w}x{new_sticker_h} "
                          f"at pixel ({pos_x}, {pos_y})")
            except Exception as e:
                print(f"[Sticker] ** FAILED to apply sticker: {e} **")
        elif sticker_path:
            print(f"[Sticker] ** Path not found: {sticker_path} **")
        else:
            print("[Sticker] No sticker requested for this image")

        # ── Embed sRGB ICC profile for colour-accurate printing ──
        if skip_icc:
            srgb_bytes = None
        else:
            srgb_bytes = ImageCms.ImageCmsProfile(_SRGB_PROFILE).tobytes()

        # Cardly only accepts PNG artwork – save as optimised PNG.
        save_kwargs = {'optimize': True}
        if srgb_bytes:
            save_kwargs['icc_profile'] = srgb_bytes
        img.save(output_path, 'PNG', **save_kwargs)
        file_size_mb = os.path.getsize(output_path) / (1024 * 1024)
        debug_print(f"PNG size: {file_size_mb:.2f} MB{' (sRGB embedded)' if srgb_bytes else ' (no ICC)'}")

        if file_size_mb > CARDLY_MAX_SIZE_MB:
            # Re-save with maximum PNG compression (zlib level 9)
            img.save(output_path, 'PNG', compress_level=9, **save_kwargs)
            file_size_mb = os.path.getsize(output_path) / (1024 * 1024)
            debug_print(f"PNG (compress_level=9): {file_size_mb:.2f} MB")

        if file_size_mb > CARDLY_MAX_SIZE_MB:
            print(f"[WARN] PNG is {file_size_mb:.2f} MB – exceeds {CARDLY_MAX_SIZE_MB} MB limit")

        return output_path

def image_to_base64(image_path: str) -> str:
    """Convert image file to base64 string."""
    with open(image_path, 'rb') as f:
        return base64.b64encode(f.read()).decode('utf-8')

# =============================================================================
# GHL Integration
# =============================================================================

def upload_to_ghl_photos(image_path: str, contact_id: str, folder_id: str = None) -> dict:
    """
    Upload image to GHL Media Storage, optionally into a specific folder.
    Uses parentId to target a folder (matching GHL API convention).
    Returns upload result with URL.
    """
    if not GHL_API_KEY:
        return {"success": False, "error": "GHL API key not configured"}

    debug_print(f"Uploading to GHL contact {contact_id}, folder {folder_id}")

    headers = {
        "Authorization": f"Bearer {GHL_API_KEY}",
        "Version": "2021-07-28"
    }

    try:
        url = f"{GHL_BASE_URL}/medias/upload-file"

        filename = os.path.basename(image_path)
        import mimetypes as _mt
        mime_type, _ = _mt.guess_type(image_path)
        if not mime_type:
            mime_type = "image/png" if image_path.endswith('.png') else "image/jpeg"

        # Query params: location context (required by GHL media API)
        params = {
            'altId': GHL_LOCATION_ID,
            'altType': 'location'
        }

        with open(image_path, 'rb') as f:
            files = {
                'file': (filename, f, mime_type)
            }
            data = {
                'name': filename
            }
            # parentId places the file inside a folder
            if folder_id:
                data['parentId'] = folder_id

            response = requests.post(url, headers=headers, params=params, files=files, data=data, timeout=120)
            response.raise_for_status()
            result = response.json()

            debug_print(f"GHL upload result: {result}")

            # Normalise the URL to the public CDN domain.
            # GHL's upload API often returns a Google Cloud Storage URL
            # (storage.googleapis.com/msgsndr/…) but the public/stable URL
            # used in the GHL UI is assets.cdn.filesafe.space/…
            raw_url = result.get('url', '')
            if raw_url and 'storage.googleapis.com/msgsndr/' in raw_url:
                raw_url = raw_url.replace(
                    'storage.googleapis.com/msgsndr/',
                    'assets.cdn.filesafe.space/'
                )
                debug_print(f"Normalised GHL URL: {raw_url}")

            return {"success": True, "data": result, "url": raw_url}

    except Exception as e:
        return {"success": False, "error": str(e)}

def update_ghl_contact_field(contact_id: str, field_key: str, value: str) -> dict:
    """Update a custom field on a GHL contact."""
    if not GHL_API_KEY:
        return {"success": False, "error": "GHL API key not configured"}

    headers = {
        "Authorization": f"Bearer {GHL_API_KEY}",
        "Content-Type": "application/json",
        "Version": "2021-07-28"
    }

    try:
        url = f"{GHL_BASE_URL}/contacts/{contact_id}"
        payload = {
            "customFields": [
                {"key": field_key, "value": value}
            ]
        }

        response = requests.put(url, headers=headers, json=payload)
        response.raise_for_status()
        return {"success": True, "data": response.json()}

    except Exception as e:
        return {"success": False, "error": str(e)}

# =============================================================================
# Cardly Integration
# =============================================================================

def get_template_media_id(template_id: str) -> str:
    """
    Fetch a template's underlying media ID.
    Templates are built on base media (e.g., Landscape Card), we need that ID for artwork.

    Returns the media ID, or None if not found.
    """
    if not CARDLY_API_KEY:
        return None

    headers = {"API-Key": CARDLY_API_KEY}

    try:
        url = f"{CARDLY_BASE_URL}/templates/{template_id}"
        response = requests.get(url, headers=headers)
        if response.status_code == 200:
            data = response.json()
            # Template has nested media object with its ID
            media = data.get('data', {}).get('media', {})
            return media.get('id')
    except Exception:
        pass
    return None

def create_cardly_artwork(image_path: str, name: str = "Custom Card", media_id_override: str = None) -> dict:
    """
    Create custom artwork on Cardly with the provided image.

    Reads the PNG file at *image_path*, base64-encodes it with the
    required ``data:image/png;base64,`` prefix, and uploads via the
    Cardly ``POST /art`` endpoint.

    Args:
        image_path: Path to the processed PNG image file
        name: Name for the artwork
        media_id_override: Optional specific media ID to use (for templates)

    Returns:
        dict with artwork_id on success, or error details
    """
    if not CARDLY_API_KEY:
        return {"success": False, "error": "Cardly API key not configured"}

    if not CARDLY_MEDIA_ID:
        return {"success": False, "error": "Cardly Media ID not configured"}

    # Check if using test key
    if CARDLY_API_KEY.startswith('test_'):
        print("[WARN] Using TEST API key - artwork creation requires LIVE key!")
        return {"success": False, "error": "Artwork creation requires LIVE API key, not test key"}

    # ── Read and encode the image file ──
    if not os.path.exists(image_path):
        return {"success": False, "error": f"Image file not found: {image_path}"}

    # Re-save PNG without embedded ICC profile – Cardly rejects PNGs
    # that contain ICC/iCCP chunks as "invalid format".
    _buf = io.BytesIO()
    with Image.open(image_path) as _img:
        _clean = _img.convert('RGB')   # new image object, no inherited info
        _clean.info.clear()            # belt-and-braces: drop all metadata
        _clean.save(_buf, 'PNG', optimize=True)
    raw_b64 = base64.b64encode(_buf.getvalue()).decode('utf-8')
    # Cardly API expects raw base64, NOT a data URI prefix
    debug_print(f"Encoded PNG (no ICC): {len(raw_b64)} base64 chars from {image_path}")

    # Determine which media ID to use for artwork
    # If CARDLY_MEDIA_ID is a template, we need the template's underlying media
    actual_media_id = media_id_override
    if not actual_media_id:
        if is_template_id(CARDLY_MEDIA_ID):
            # Fetch the template's base media ID
            actual_media_id = get_template_media_id(CARDLY_MEDIA_ID)
            if not actual_media_id:
                return {"success": False, "error": "Could not get template's base media ID"}
            debug_print(f"Template detected, using base media: {actual_media_id}")
        else:
            actual_media_id = CARDLY_MEDIA_ID

    headers = {
        "API-Key": CARDLY_API_KEY,
        "Content-Type": "text/json"
    }

    # Cardly expects the artwork array with page number and raw base64 image
    payload = {
        "media": actual_media_id,
        "name": name,
        "artwork": [
            {
                "page": 1,
                "image": raw_b64
            }
        ]
    }

    debug_print(f"Creating artwork with media_id: {actual_media_id}")
    debug_print(f"Image base64 length: {len(raw_b64)}")
    debug_print(f"Payload keys: {list(payload.keys())}")

    try:
        url = f"{CARDLY_BASE_URL}/art"
        response = requests.post(url, headers=headers, data=json.dumps(payload))

        debug_print(f"Response status: {response.status_code}")
        debug_print(f"Response body: {response.text[:500]}")

        if response.status_code == 201 or response.status_code == 200:
            resp_data = response.json()
            # Cardly wraps responses in {"state": ..., "data": {"id": ...}}
            inner = resp_data.get('data', resp_data)
            artwork_id = inner.get('id') or inner.get('artwork_id') or resp_data.get('id')
            debug_print(f"Extracted artwork_id: {artwork_id}")
            return {"success": True, "artwork_id": artwork_id, "data": resp_data}
        else:
            return {"success": False, "error": response.text, "status": response.status_code}

    except Exception as e:
        return {"success": False, "error": str(e)}

def is_template_id(media_id: str) -> bool:
    """
    Check if the given ID is a template ID (from /templates) vs media ID (from /media).
    Media IDs contain '-ae1c-11ea-' pattern, template IDs don't.
    """
    return media_id and '-ae1c-11ea-' not in media_id and '-ae1c-' not in media_id

def place_cardly_order(artwork_id: str, recipient: dict, message: str = "",
                       first_name: str = "", template_id: str = None) -> dict:
    """
    Place an order to send a card via Cardly.

    Supports two modes:
    1. Artwork-only: For basic media types (Landscape Card, etc.)
    2. Template-based: For custom templates with variables (Thankyou Photocard L)

    Args:
        artwork_id: The artwork ID from create_cardly_artwork (image on front)
        recipient: Dict with name, address1, address2, city, state, postcode, country
        message: Message to include in the card
        first_name: Recipient's first name (for template variables)
        template_id: Optional template ID - if provided, uses template mode

    Returns:
        dict with order details on success
    """
    if not CARDLY_API_KEY:
        return {"success": False, "error": "Cardly API key not configured"}

    headers = {
        "API-Key": CARDLY_API_KEY,
        "Content-Type": "text/json"
    }

    # ── Map internal recipient field names to Cardly API field names ──
    # Our code uses: name, address1, address2, city, state, postcode, country
    # Cardly API expects: firstName, lastName, address, address2, city, region, postcode, country
    full_name = recipient.get('name', '').strip()
    name_parts = full_name.split(None, 1) if full_name else [first_name or '']
    cardly_recipient = {
        "firstName": name_parts[0] if name_parts else (first_name or ''),
        "lastName": name_parts[1] if len(name_parts) > 1 else '',
        "address": recipient.get('address1', '') or recipient.get('address', ''),
        "address2": recipient.get('address2', ''),
        "city": recipient.get('city', ''),
        "region": recipient.get('state', '') or recipient.get('region', ''),
        "postcode": recipient.get('postcode', ''),
        "country": recipient.get('country', 'AU')
    }

    # Determine if using template mode
    use_template = template_id and is_template_id(template_id)

    if use_template:
        # Template-based order: Uses template with variables + artwork for front
        line_item = {
            "template": template_id,
            "artwork": artwork_id,
            "recipient": cardly_recipient,
            "variables": {
                "fName": first_name or cardly_recipient.get("firstName", ""),
                "message": message
            }
        }
        debug_print(f"Placing TEMPLATE order: {template_id}")
    else:
        # Artwork-only order: Simple card with just the artwork
        line_item = {
            "artwork": artwork_id,
            "recipient": cardly_recipient,
        }
        # Pass message via messages.pages (page 3 = inner right for cards)
        if message:
            line_item["messages"] = {
                "pages": [
                    {"page": 3, "text": message}
                ]
            }
        debug_print(f"Placing ARTWORK order: {artwork_id}")

    # Build the top-level payload with required 'lines' array
    payload = {
        "lines": [line_item]
    }

    # Add any additional order options from config
    if 'return_address' in CARDLY_CONFIG:
        payload['returnAddress'] = CARDLY_CONFIG['return_address']

    debug_print(f"Recipient: [redacted for privacy]")
    debug_print(f"Payload: [redacted for privacy]")

    try:
        url = f"{CARDLY_BASE_URL}/orders/place"
        response = requests.post(url, headers=headers, data=json.dumps(payload))

        debug_print(f"Order response: {response.status_code} - {response.text[:500]}")

        if response.status_code in (200, 201):
            return {"success": True, "data": response.json()}
        else:
            return {"success": False, "error": response.text, "status": response.status_code}

    except Exception as e:
        return {"success": False, "error": str(e)}

def get_ghl_contact(contact_id: str) -> dict:
    """Fetch contact details from GHL.

    Enriches the contact data with address2/address3 from GHL custom fields.
    """
    if not GHL_API_KEY:
        return {"success": False, "error": "GHL API key not configured"}

    headers = {
        "Authorization": f"Bearer {GHL_API_KEY}",
        "Version": "2021-07-28"
    }

    try:
        url = f"{GHL_BASE_URL}/contacts/{contact_id}"
        response = requests.get(url, headers=headers)
        response.raise_for_status()
        data = response.json()
        # Enrich address2/address3 from customFields
        contact = data.get('contact', data)
        _enrich_contact_address(contact)
        return {"success": True, "data": data}
    except Exception as e:
        return {"success": False, "error": str(e)}

def save_to_album_folder(processed_image: str, original_image: str, album_folder: str) -> dict:
    """
    Save a copy of the processed postcard image to the album folder.

    Args:
        processed_image: Path to the processed/resized image
        original_image: Path to the original image (for extracting filename)
        album_folder: Destination folder path

    Returns:
        dict with success status and saved file path
    """
    if not album_folder or not os.path.exists(album_folder):
        return {"success": False, "error": "Album folder not specified or does not exist"}

    try:
        from datetime import datetime
        
        # Get original filename without extension
        original_name = os.path.splitext(os.path.basename(original_image))[0]
        
        # Generate filename: {filename}-Postcard-{date-sent}.jpg
        date_str = datetime.now().strftime("%Y-%m-%d")
        output_filename = f"{original_name}-Postcard-{date_str}.jpg"
        output_path = os.path.join(album_folder, output_filename)
        
        # Open processed image and save to album folder at 80% quality
        with Image.open(processed_image) as img:
            # Convert to RGB if necessary (in case it's RGBA or other format)
            if img.mode != 'RGB':
                img = img.convert('RGB')
            
            # Save with 80% quality
            img.save(output_path, 'JPEG', quality=80, optimize=True)
        
        debug_print(f"Saved postcard copy to: {output_path}")
        return {"success": True, "path": output_path}
        
    except Exception as e:
        return {"success": False, "error": str(e)}

# =============================================================================
# Main Workflow
# =============================================================================

def send_card(image_path: str, contact_id: str, message: str = "",
              crop_x: int = 50, crop_y: int = 50, zoom: int = 100,
              sticker_path: str = None, sticker_x: int = 75, sticker_y: int = 75,
              save_to_album: bool = False, album_folder: str = None) -> dict:
    """
    Complete workflow to send a personalized card.

    1. Resize/convert image to Cardly requirements (with crop settings)
    2. Composite sticker overlay (if provided)
    3. Upload to GHL (optional)
    4. Create artwork on Cardly
    5. Place order with recipient from GHL contact
    6. Save copy to album folder (if enabled)

    Crop parameters:
    - crop_x: 0-100, horizontal position (0=left, 50=center, 100=right)
    - crop_y: 0-100, vertical position (0=top, 50=center, 100=bottom)
    - zoom: 100-200, zoom level (100=fill card, 200=2x zoom in)

    Sticker parameters:
    - sticker_path: Path to PNG sticker file (None = no sticker)
    - sticker_x: 0-100, horizontal position (0=left, 100=right)
    - sticker_y: 0-100, vertical position (0=top, 100=bottom)

    Album save parameters:
    - save_to_album: Whether to save a copy to the album folder
    - album_folder: Path to album folder for saving copy

    Returns dict with success status and details.
    """
    result = {
        "success": False,
        "steps": {}
    }

    # Validate inputs
    if not os.path.exists(image_path):
        result["error"] = f"Image not found: {image_path}"
        return result

    print(f"[INFO] Processing card for contact: {contact_id}")
    print(f"[INFO] Crop settings: x={crop_x}%, y={crop_y}%, zoom={zoom}%")
    if sticker_path:
        print(f"[INFO] Sticker: {sticker_path} at ({sticker_x}%, {sticker_y}%)")

    # Step 1: Process image with crop settings
    print("[STEP 1] Processing image...")
    try:
        processed_image = resize_image_for_cardly(
            image_path, crop_x=crop_x, crop_y=crop_y, zoom=zoom,
            sticker_path=sticker_path, sticker_x=sticker_x, sticker_y=sticker_y
        )
        result["steps"]["image_processing"] = {"success": True, "path": processed_image}
        print(f"[OK] Image processed: {processed_image}")
    except Exception as e:
        result["steps"]["image_processing"] = {"success": False, "error": str(e)}
        result["error"] = f"Image processing failed: {e}"
        return result

    # Step 2: Get contact details from GHL
    print("[STEP 2] Fetching contact from GHL...")
    contact_result = get_ghl_contact(contact_id)
    if not contact_result["success"]:
        result["steps"]["ghl_contact"] = contact_result
        result["error"] = f"Failed to get contact: {contact_result.get('error')}"
        return result

    contact_data = contact_result["data"].get("contact", {})
    result["steps"]["ghl_contact"] = {"success": True, "name": contact_data.get("name", "Unknown")}
    print(f"[OK] Contact: {contact_data.get('name', 'Unknown')}")

    # Build recipient from GHL contact
    recipient = {
        "name": contact_data.get("name", ""),
        "address1": contact_data.get("address1", ""),
        "address2": contact_data.get("address2", ""),
        "city": contact_data.get("city", ""),
        "state": contact_data.get("state", ""),
        "postcode": contact_data.get("postalCode", ""),
        "country": contact_data.get("country", "GB")  # Default to UK
    }

    # Validate address
    if not recipient["address1"] or not recipient["postcode"]:
        result["error"] = "Contact missing address or postcode"
        result["steps"]["recipient_validation"] = {"success": False, "error": "Missing address"}
        return result

    result["steps"]["recipient_validation"] = {"success": True, "recipient": recipient}

    # Step 3: Convert image to base64
    print("[STEP 3] Encoding image...")
    base64_image = image_to_base64(processed_image)
    print(f"[OK] Base64 length: {len(base64_image)}")

    # Step 4: Create artwork on Cardly
    print("[STEP 4] Creating Cardly artwork...")
    artwork_result = create_cardly_artwork(
        base64_image,
        name=f"Card for {contact_data.get('name', 'Client')}"
    )
    result["steps"]["cardly_artwork"] = artwork_result

    if not artwork_result["success"]:
        result["error"] = f"Artwork creation failed: {artwork_result.get('error')}"
        return result

    artwork_id = artwork_result["artwork_id"]
    print(f"[OK] Artwork created: {artwork_id}")

    # Step 5: Place order (detect if using template or plain media)
    print("[STEP 5] Placing order...")
    first_name = contact_data.get("firstName", "") or contact_data.get("name", "").split()[0]

    # CARDLY_MEDIA_ID could be a template ID or media ID
    # Templates support variables (fName, message), media is just artwork
    order_result = place_cardly_order(
        artwork_id=artwork_id,
        recipient=recipient,
        message=message,
        first_name=first_name,
        template_id=CARDLY_MEDIA_ID  # Will auto-detect if it's a template
    )
    result["steps"]["cardly_order"] = order_result

    if not order_result["success"]:
        result["error"] = f"Order failed: {order_result.get('error')}"
        return result

    print("[OK] Order placed successfully!")
    result["success"] = True
    result["order"] = order_result.get("data", {})

    # Step 6: Save to album folder (if enabled)
    if save_to_album and album_folder:
        print("[STEP 6] Saving copy to album folder...")
        save_result = save_to_album_folder(processed_image, image_path, album_folder)
        result["steps"]["album_save"] = save_result
        if save_result["success"]:
            print(f"[OK] Saved to: {save_result['path']}")
        else:
            print(f"[WARN] Album save failed: {save_result.get('error')}")

    # Cleanup processed image
    try:
        if processed_image != image_path:
            os.remove(processed_image)
    except (IOError, OSError):
        pass

    return result

def test_connection() -> dict:
    """Test Cardly API connection."""
    if not CARDLY_API_KEY:
        return {"success": False, "error": "Cardly API key not configured"}

    headers = {
        "API-Key": CARDLY_API_KEY
    }

    try:
        # Try to get media list
        url = f"{CARDLY_BASE_URL}/media"
        response = requests.get(url, headers=headers)

        if response.status_code == 200:
            return {
                "success": True,
                "mode": "LIVE" if CARDLY_API_KEY.startswith('live_') else "TEST",
                "media_count": len(response.json().get('data', []))
            }
        else:
            return {"success": False, "error": response.text, "status": response.status_code}
    except Exception as e:
        return {"success": False, "error": str(e)}

# =============================================================================
# CLI Interface
# =============================================================================

def print_usage() -> None:
    """Print CLI usage instructions and examples."""
    print("""
Cardly Card Sending Tool

Usage:
  cardly_send_card.py <image_path> <contact_id> [message] [crop_x] [crop_y] [zoom] [sticker] [sticker_x] [sticker_y] [album_folder] [--debug]
  cardly_send_card.py --test                    Test API connection
  cardly_send_card.py --process <image_path>   Process image only

Arguments:
  image_path    Path to source image
  contact_id    GHL contact ID
  message       Card message text (optional)
  crop_x        Crop X position 0-100 (0=left, 50=center, 100=right)
  crop_y        Crop Y position 0-100 (0=top, 50=center, 100=bottom)
  zoom          Zoom level 100-200 (100=fit card, 200=2x zoom)
  sticker       Path to sticker PNG file (or "none")
  sticker_x     Sticker X position 0-100
  sticker_y     Sticker Y position 0-100
  album_folder  Album folder path to save copy (or "none")

Examples:
  cardly_send_card.py "C:\\Photos\\hero.jpg" "abc123" "Thank you!"
  cardly_send_card.py "C:\\Photos\\hero.jpg" "abc123" "Thanks!" 50 30 150
  cardly_send_card.py "C:\\Photos\\hero.jpg" "abc123" "Thanks!" 50 30 150 none 75 75 "C:\\Photos"
  cardly_send_card.py --test
  cardly_send_card.py --process "C:\\Photos\\hero.jpg"

Configuration:
  Create cardly_credentials.json with:
  {
    "api_key": "live_xxxxx",      // MUST be live key for artwork
    "media_id": "8c36cba2-..."    // Card template media ID
  }
""")

def main() -> int:
    """Parse CLI arguments and execute the requested Cardly operation."""
    args = [a for a in sys.argv[1:] if not a.startswith('--')]

    if '--test' in sys.argv:
        print("Testing Cardly connection...")
        result = test_connection()
        print(json.dumps(result, indent=2))
        return 0 if result["success"] else 1

    if '--process' in sys.argv and len(args) >= 1:
        print(f"Processing image: {args[0]}")
        try:
            # Parse optional crop parameters for --process mode
            crop_x = int(args[1]) if len(args) > 1 else 50
            crop_y = int(args[2]) if len(args) > 2 else 50
            zoom = int(args[3]) if len(args) > 3 else 100
            output = resize_image_for_cardly(args[0], crop_x=crop_x, crop_y=crop_y, zoom=zoom)
            print(f"Processed image saved to: {output}")
            return 0
        except Exception as e:
            print(f"Error: {e}")
            return 1

    if len(args) < 2:
        print_usage()
        return 1

    image_path = args[0]
    contact_id = args[1]
    message = args[2] if len(args) > 2 else ""

    # Parse crop parameters (with defaults)
    crop_x = int(args[3]) if len(args) > 3 else 50
    crop_y = int(args[4]) if len(args) > 4 else 50
    zoom = int(args[5]) if len(args) > 5 else 100

    # Parse sticker parameters
    sticker_path = args[6] if len(args) > 6 and args[6].lower() != "none" else None
    sticker_x = int(args[7]) if len(args) > 7 else 75
    sticker_y = int(args[8]) if len(args) > 8 else 75
    
    # Parse album save parameters
    album_folder = args[9] if len(args) > 9 and args[9].lower() != "none" else None
    save_to_album = bool(album_folder)  # Only save if folder is provided

    result = send_card(image_path, contact_id, message, crop_x=crop_x, crop_y=crop_y, zoom=zoom,
                       sticker_path=sticker_path, sticker_x=sticker_x, sticker_y=sticker_y,
                       save_to_album=save_to_album, album_folder=album_folder)

    # Write result to file for AHK to read
    output_dir = _get_output_dir()
    output_file = os.path.join(output_dir, "cardly_result.json")
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(result, f, indent=2)

    print(f"\nResult saved to: {output_file}")
    print(json.dumps(result, indent=2))

    return 0 if result["success"] else 1

if __name__ == "__main__":
    sys.exit(main())

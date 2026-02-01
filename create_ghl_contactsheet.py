"""
Create JPG Contact Sheet from ProSelect XML Export
Generates a visual image gallery and uploads to GHL Media "Order Sheets" folder
The JPG displays directly in GHL notes without needing to click to open

Usage: python create_ghl_contactsheet.py <xml_file_path>
Example: python create_ghl_contactsheet.py "C:/path/to/2026-01-31_P26005P__1.xml"

Note: Create a folder named "Order Sheets" in GHL Media before running.
"""

import subprocess
import sys
import json
import os
import glob
import base64
import ctypes
import xml.etree.ElementTree as ET
from datetime import datetime

# Auto-install dependencies
def install_dependencies() -> None:
    """Auto-install required Python packages if not present."""
    required = ['requests', 'Pillow']
    for package in required:
        try:
            if package == 'Pillow':
                __import__('PIL')
            else:
                __import__(package)
        except ImportError:
            print(f"Installing {package}...")
            subprocess.check_call([sys.executable, '-m', 'pip', 'install', package, '-q'])

install_dependencies()

import requests
from PIL import Image, ImageDraw, ImageFont

# =============================================================================
# Configuration
# =============================================================================
# For PyInstaller compiled EXE: INI is in same folder as EXE
if getattr(sys, 'frozen', False):
    SCRIPT_DIR = os.path.dirname(sys.executable)
else:
    SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

INI_FILE = os.path.join(SCRIPT_DIR, 'SideKick_PS.ini')
ORDER_SHEETS_FOLDER = "Order Sheets"  # Folder name in GHL Media


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
    return os.environ.get('TEMP', SCRIPT_DIR)


def _parse_ini_line(line: str, current_section: str, config: dict) -> str:
    """Parse a single INI line and update config.

    Args:
        line: Stripped line from INI file.
        current_section: Current section name.
        config: Config dict to update.

    Returns:
        str: Updated current section name.
    """
    if line.startswith('[') and line.endswith(']'):
        section = line[1:-1]
        config[section] = {}
        return section
    if '=' in line and current_section:
        key, value = line.split('=', 1)
        config[current_section][key.strip()] = value.strip()
    return current_section


def _parse_ini_sections(file_path: str) -> dict:
    """Parse INI file into nested dictionary by section.

    Args:
        file_path: Path to the INI file.

    Returns:
        dict: Nested dictionary with sections as keys.
    """
    config = {}
    current_section = None

    with open(file_path, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith(';'):
                continue
            current_section = _parse_ini_line(line, current_section, config)

    return config


def load_config() -> dict:
    """Load configuration from INI file."""
    config = _parse_ini_sections(INI_FILE)
    ghl = config.get('GHL', {})

    v2_b64 = ghl.get('API_Key_V2_B64', '')
    if not v2_b64:
        raise ValueError("No V2 API key found in INI file")

    v2_b64_clean = v2_b64.replace(' ', '').replace('\n', '').replace('\r', '')
    api_key = base64.b64decode(v2_b64_clean).decode('utf-8')

    return {
        'API_KEY': api_key,
        'LOCATION_ID': ghl.get('LocationID', ''),
    }


CONFIG = load_config()
API_KEY = CONFIG['API_KEY']
LOCATION_ID = CONFIG['LOCATION_ID']
BASE_URL = "https://services.leadconnectorhq.com"

def get_headers() -> dict:
    """Get authorization headers for GHL API requests."""
    return {
        "Authorization": f"Bearer {API_KEY}",
        "Version": "2021-07-28"
    }

# =============================================================================
# System Date Format Detection (Windows)
# =============================================================================
def get_system_date_format() -> tuple:
    """Get the system's short date format from Windows locale settings."""
    try:
        LOCALE_SSHORTDATE = 0x1F
        buffer = ctypes.create_unicode_buffer(80)
        ctypes.windll.kernel32.GetLocaleInfoW(0x0400, LOCALE_SSHORTDATE, buffer, 80)
        win_format = buffer.value

        # For filename, use compact format without separators
        compact = win_format.lower()
        if compact.startswith('d'):
            return '%d%m%y', 'uk'  # UK: ddmmyy
        else:
            return '%m%d%y', 'us'  # US: mmddyy
    except Exception:
        return '%d%m%y', 'uk'  # Default to UK

# =============================================================================
# XML Parsing Helpers
# =============================================================================
def _get_xml_text(elem, path: str, default: str = '') -> str:
    """Get text content from XML element.

    Args:
        elem: Parent XML element.
        path: Path to child element.
        default: Default value if not found.

    Returns:
        str: Text content or default.
    """
    el = elem.find(path) if elem is not None else None
    return el.text.strip() if el is not None and el.text else default


def _extract_image_number(filename: str) -> str:
    """Extract trailing digits from filename.

    Args:
        filename: Image filename like 'P26005P00055.tif'.

    Returns:
        str: Extracted number like '55'.
    """
    import re
    name = os.path.splitext(filename)[0]
    match = re.search(r'(\d+)$', name)
    if match:
        return match.group(1).lstrip('0') or '0'
    return name


def _parse_order_date(date_str: str) -> datetime:
    """Parse order date from various formats.

    Args:
        date_str: Date string in various formats.

    Returns:
        datetime: Parsed datetime or current datetime.
    """
    if not date_str:
        return datetime.now()

    for fmt in ['%m/%d/%Y', '%d/%m/%Y', '%Y-%m-%d']:
        try:
            return datetime.strptime(date_str, fmt)
        except ValueError:
            continue

    return datetime.now()


def _process_layout_images(item, description: str, get_text_fn, image_labels: dict) -> None:
    """Process Layout_Image elements from an ordered item.

    Args:
        item: Ordered_Item XML element.
        description: Item description.
        get_text_fn: Function to get text from XML.
        image_labels: Dict to update with labels.
    """
    for layout_img in item.findall('.//Layout_Image'):
        ordered_img = get_text_fn(layout_img, 'Ordered_Image')
        image_name = get_text_fn(layout_img, 'Image_Name')

        if ordered_img and image_name:
            img_num = _extract_image_number(image_name)
            label = f"{img_num}-{description}" if description else img_num
            image_labels[ordered_img] = label


def _process_regular_images(item, description: str, image_labels: dict) -> None:
    """Process regular Images elements from an ordered item.

    Args:
        item: Ordered_Item XML element.
        description: Item description.
        image_labels: Dict to update with labels.
    """
    images_elem = item.find('Images')
    if images_elem is None:
        return

    ordered_imgs = images_elem.findall('Ordered_Image')
    image_names = images_elem.findall('Image_Name')

    for oi, iname in zip(ordered_imgs, image_names):
        ordered_img = oi.text.strip() if oi.text else ''
        image_name = iname.text.strip() if iname.text else ''

        if ordered_img and image_name:
            img_num = _extract_image_number(image_name)
            label = f"{img_num}-{description}" if description else img_num
            image_labels[ordered_img] = label


def _build_image_labels(order, get_text_fn) -> dict:
    """Build image labels mapping from order items.

    Args:
        order: Order XML element.
        get_text_fn: Function to get text from XML.

    Returns:
        dict: Mapping of thumbnail filename to label.
    """
    image_labels = {}

    if order is None:
        return image_labels

    for item in order.findall('.//Ordered_Item'):
        description = get_text_fn(item, 'Description')

        _process_layout_images(item, description, get_text_fn, image_labels)
        _process_regular_images(item, description, image_labels)

        # Handle layout thumbnail
        ordered_layout = get_text_fn(item, './/Ordered_Layout')
        if ordered_layout:
            image_labels[ordered_layout] = description if description else 'Layout'

    return image_labels


def parse_xml(xml_path: str) -> dict:
    """Parse ProSelect XML and extract order details."""
    tree = ET.parse(xml_path)
    root = tree.getroot()

    def get_text(elem, path, default='') -> str:
        """Get text from XML element, wrapper for _get_xml_text."""
        return _get_xml_text(elem, path, default)

    data: dict = {
        'contact_id': get_text(root, 'Client_ID'),
        'first_name': get_text(root, 'First_Name'),
        'last_name': get_text(root, 'Last_Name'),
        'album_name': get_text(root, 'Album_Name'),
        'album_path': get_text(root, 'Album_Path'),
    }

    order = root.find('Order')
    data['order_date'] = get_text(order, 'Info/Date') if order is not None else ''

    album = data['album_name']
    data['shoot_no'] = album.split('_')[0] if '_' in album else album

    data['order_datetime'] = _parse_order_date(data['order_date'])
    data['image_labels'] = _build_image_labels(order, get_text)

    return data

# =============================================================================
# GHL Media Folder Functions
# =============================================================================
def find_folder_by_name(folder_name: str) -> str | None:
    """Find a folder ID by name in GHL Media."""
    headers = get_headers()

    params = {
        'altId': LOCATION_ID,
        'altType': 'location',
        'sortBy': 'createdAt',
        'sortOrder': 'desc',
        'type': 'folder'
    }

    try:
        response = requests.get(
            f"{BASE_URL}/medias/files",
            headers=headers,
            params=params,
            timeout=30
        )

        if response.status_code == 200:
            data = response.json()
            for item in data.get('files', []):
                if item.get('name', '').lower() == folder_name.lower():
                    return item.get('_id')  # GHL uses _id not id
        return None
    except Exception as e:
        print(f"Error searching for folder: {e}")
        return None

def create_folder(folder_name: str) -> str | None:
    """Create a folder in GHL Media and return its ID."""
    headers = get_headers()

    params = {
        'altId': LOCATION_ID,
        'altType': 'location'
    }

    data = {
        'name': folder_name,
        'type': 'folder'
    }

    try:
        response = requests.post(
            f"{BASE_URL}/medias/files",
            headers=headers,
            params=params,
            json=data,
            timeout=30
        )

        if response.status_code in [200, 201]:
            result = response.json()
            return result.get('_id') or result.get('id')
        else:
            print(f"Failed to create folder ({response.status_code}): {response.text[:200]}")
            return None
    except Exception as e:
        print(f"Error creating folder: {e}")
        return None

def find_or_create_folder(folder_name: str) -> str | None:
    """Find a folder by name, or create it if it doesn't exist."""
    folder_id = find_folder_by_name(folder_name)
    if folder_id:
        return folder_id

    print(f"   Creating '{folder_name}' folder...")
    folder_id = create_folder(folder_name)
    if folder_id:
        print(f"   ✓ Created folder ID: {folder_id}")
    return folder_id

def upload_to_folder(file_path: str, folder_id: str | None = None) -> str | None:
    """Upload a file to GHL Media, optionally to a specific folder."""
    import mimetypes

    mime_type, _ = mimetypes.guess_type(file_path)
    if not mime_type:
        mime_type = 'image/jpeg'

    file_name = os.path.basename(file_path)

    headers = get_headers()
    params = {
        'altId': LOCATION_ID,
        'altType': 'location'
    }

    try:
        with open(file_path, 'rb') as f:
            files = {'file': (file_name, f, mime_type)}
            data = {'name': file_name}

            if folder_id:
                data['parentId'] = folder_id  # Use parentId not folderId

            response = requests.post(
                f"{BASE_URL}/medias/upload-file",
                headers=headers,
                params=params,
                files=files,
                data=data,
                timeout=120
            )

            if response.status_code in [200, 201]:
                result = response.json()
                return result.get('url', '')
            else:
                print(f"Upload failed ({response.status_code}): {response.text[:200]}")
                return None

    except Exception as e:
        print(f"Upload error: {e}")
        return None

# =============================================================================
# JPG Contact Sheet Generation Helpers
# =============================================================================
def _load_fonts() -> tuple:
    """Load fonts for contact sheet, fallback to default.

    Returns:
        tuple: (title_font, subtitle_font, label_font, credit_font)
    """
    try:
        title_font = ImageFont.truetype("arial.ttf", 24)
        subtitle_font = ImageFont.truetype("arial.ttf", 14)
        label_font = ImageFont.truetype("arial.ttf", 10)
        credit_font = ImageFont.truetype("arial.ttf", 10)
    except Exception:
        title_font = ImageFont.load_default()
        subtitle_font = ImageFont.load_default()
        label_font = ImageFont.load_default()
        credit_font = ImageFont.load_default()
    return title_font, subtitle_font, label_font, credit_font


def _draw_logo(canvas_img: Image.Image, canvas_width: int, padding: int) -> None:
    """Draw SideKick logo in top-right corner.

    Args:
        canvas_img: PIL Image canvas.
        canvas_width: Canvas width in pixels.
        padding: Padding in pixels.
    """
    logo_path = os.path.join(SCRIPT_DIR, 'SideKick_Logo_2025_Light.png')
    if not os.path.exists(logo_path):
        return

    try:
        with Image.open(logo_path) as logo:
            logo_height = 40
            aspect = logo.width / logo.height
            logo_width = int(logo_height * aspect)
            logo_resized = logo.resize((logo_width, logo_height), Image.Resampling.LANCZOS)

            if logo_resized.mode == 'RGBA':
                bg = Image.new('RGB', logo_resized.size, (255, 255, 255))
                bg.paste(logo_resized, mask=logo_resized.split()[3])
                logo_resized = bg

            logo_x = canvas_width - logo_width - padding
            canvas_img.paste(logo_resized, (logo_x, padding))
    except Exception as e:
        print(f"  Warning: Could not add logo: {e}")


def _draw_thumbnail(
    canvas_img: Image.Image,
    draw: ImageDraw.Draw,
    img_path: str,
    x: int,
    y: int,
    thumb_size: int,
    label_font,
    image_labels: dict
) -> None:
    """Draw a single thumbnail with label on the canvas.

    Args:
        canvas_img: PIL Image canvas.
        draw: ImageDraw object.
        img_path: Path to thumbnail image.
        x: X position.
        y: Y position.
        thumb_size: Thumbnail size in pixels.
        label_font: Font for label.
        image_labels: Dict mapping filename to label.
    """
    try:
        with Image.open(img_path) as thumb:
            thumb.thumbnail((thumb_size, thumb_size), Image.Resampling.LANCZOS)
            thumb_x = x + (thumb_size - thumb.width) // 2
            thumb_y = y + (thumb_size - thumb.height) // 2
            canvas_img.paste(thumb, (thumb_x, thumb_y))

        draw.rectangle([x, y, x + thumb_size, y + thumb_size], outline=(200, 200, 200))

        img_filename = os.path.basename(img_path)
        label = image_labels.get(img_filename, img_filename.replace('.jpg', ''))
        if len(label) > 25:
            label = label[:22] + "..."
        draw.text((x + 2, y + thumb_size + 2), label, fill=(100, 100, 100), font=label_font)
    except Exception as e:
        print(f"  Warning: Could not add {os.path.basename(img_path)}: {e}")


# =============================================================================
# JPG Contact Sheet Generation
# =============================================================================
def create_contact_sheet_jpg(
    image_folder: str,
    output_path: str,
    title: str = "Product Contact Sheet",
    subtitle: str = "",
    image_labels: dict | None = None
) -> str:
    """Create a JPG contact sheet from thumbnail images.

    Args:
        image_folder: Path to folder containing Product_*.jpg files
        output_path: Output JPG file path
        title: Title text for the contact sheet
        subtitle: Subtitle text
        image_labels: Dict mapping filename (e.g. 'Product_Print_1.jpg') to label (e.g. '55-Book Image')
    """
    if image_labels is None:
        image_labels = {}

    images = sorted(glob.glob(os.path.join(image_folder, "Product_*.jpg")))
    if not images:
        print("No images found!")
        return None

    print(f"  Creating JPG from {len(images)} images...")

    # Layout settings
    cols = 5
    thumb_size = 200
    padding = 10
    header_height = 80
    label_height = 20
    rows = (len(images) + cols - 1) // cols

    canvas_width = cols * thumb_size + (cols + 1) * padding
    canvas_height = header_height + rows * (thumb_size + label_height + padding) + padding

    canvas_img = Image.new('RGB', (canvas_width, canvas_height), (255, 255, 255))
    draw = ImageDraw.Draw(canvas_img)

    title_font, subtitle_font, label_font, credit_font = _load_fonts()
    _draw_logo(canvas_img, canvas_width, padding)

    # Draw header
    draw.text((padding, padding), title, fill=(0, 0, 0), font=title_font)
    if subtitle:
        draw.text((padding, padding + 30), subtitle, fill=(80, 80, 80), font=subtitle_font)
    info_text = f"Total Items: {len(images)}  |  Generated: {datetime.now().strftime('%Y-%m-%d %H:%M')}"
    draw.text((padding, padding + 50), info_text, fill=(120, 120, 120), font=label_font)

    # Draw thumbnails
    for idx, img_path in enumerate(images):
        col = idx % cols
        row = idx // cols
        x = padding + col * (thumb_size + padding)
        y = header_height + row * (thumb_size + label_height + padding)
        _draw_thumbnail(canvas_img, draw, img_path, x, y, thumb_size, label_font, image_labels)

    # Add credit at bottom right
    credit_text = "Created by SideKick_PS"
    try:
        bbox = draw.textbbox((0, 0), credit_text, font=credit_font)
        credit_width = bbox[2] - bbox[0]
    except Exception:
        credit_width = len(credit_text) * 6
    draw.text((canvas_width - credit_width - padding, canvas_height - 18), credit_text, fill=(150, 150, 150), font=credit_font)

    canvas_img.save(output_path, 'JPEG', quality=90, optimize=True)
    return output_path

# =============================================================================
# Contact Note
# =============================================================================
def add_contact_note(contact_id: str, note_body: str) -> bool:
    """Add a note to a contact."""
    headers = get_headers()
    headers["Content-Type"] = "application/json"

    payload = {
        "body": note_body,
        "userId": LOCATION_ID
    }

    response = requests.post(
        f"{BASE_URL}/contacts/{contact_id}/notes",
        headers=headers,
        json=payload,
        timeout=30
    )

    return response.status_code in [200, 201]

# =============================================================================
# Main
# =============================================================================
def main() -> None:
    """Main entry point for contact sheet generation."""
    if len(sys.argv) < 2:
        print("Usage: python create_ghl_contactsheet.py <xml_file_path>")
        print("Example: python create_ghl_contactsheet.py \"C:/path/to/order.xml\"")
        sys.exit(1)

    xml_path = sys.argv[1]

    if not os.path.exists(xml_path):
        print(f"Error: XML file not found: {xml_path}")
        sys.exit(1)

    print("=" * 60)
    print("GHL Contact Sheet Generator")
    print("=" * 60)

    # Parse XML
    print("\n1. Parsing XML...")
    data = parse_xml(xml_path)
    print(f"   Shoot No: {data['shoot_no']}")
    print(f"   Client: {data['first_name']} {data['last_name']}")
    print(f"   Order Date: {data['order_date']}")
    print(f"   Contact ID: {data['contact_id']}")

    if not data['contact_id']:
        print("Error: No GHL Contact ID found in XML (Client_ID field)")
        sys.exit(1)

    # Find thumbnail folder
    xml_basename = os.path.splitext(os.path.basename(xml_path))[0]
    thumb_folder = os.path.join(os.path.dirname(xml_path), xml_basename)

    if not os.path.exists(thumb_folder):
        thumb_folder = os.path.join(SCRIPT_DIR, xml_basename)

    if not os.path.exists(thumb_folder):
        print(f"Error: Thumbnail folder not found: {xml_basename}")
        sys.exit(1)

    print(f"   Thumbnails: {thumb_folder}")

    # Get system date format
    date_format, locale_type = get_system_date_format()
    date_str = data['order_datetime'].strftime(date_format)

    # Generate filename: ShootNo-Surname-ShootDate.jpg
    jpg_filename = f"{data['shoot_no']}-{data['last_name']}-{date_str}.jpg"
    jpg_path = os.path.join(SCRIPT_DIR, jpg_filename)

    print(f"\n2. Creating JPG: {jpg_filename}")

    # Create JPG
    title = f"Product Gallery - {data['shoot_no']}"
    subtitle = f"{data['first_name']} {data['last_name']} - {data['order_date']}"

    result = create_contact_sheet_jpg(thumb_folder, jpg_path, title, subtitle, data.get('image_labels', {}))
    if not result:
        print("Error: Failed to create JPG")
        sys.exit(1)
    print(f"   ✓ JPG created")

    # Find Order Sheets folder
    print(f"\n3. Finding '{ORDER_SHEETS_FOLDER}' folder in GHL Media...")
    folder_id = find_folder_by_name(ORDER_SHEETS_FOLDER)

    if folder_id:
        print(f"   ✓ Found folder ID: {folder_id}")
    else:
        print(f"   ⚠ Folder '{ORDER_SHEETS_FOLDER}' not found!")
        print(f"   Please create a folder named '{ORDER_SHEETS_FOLDER}' in GHL Media.")
        print(f"   Uploading to root instead...")

    # Upload JPG
    print(f"\n4. Uploading JPG to GHL Media...")
    jpg_url = upload_to_folder(jpg_path, folder_id)

    if not jpg_url:
        print("Error: Failed to upload JPG")
        sys.exit(1)
    print(f"   ✓ Uploaded: {jpg_url[:60]}...")

    # Add contact note with embedded image
    print(f"\n5. Adding note to contact...")
    image_count = len(glob.glob(os.path.join(thumb_folder, "Product_*.jpg")))

    # Note with the image URL - GHL will display it as a link that shows the image
    note_body = f"""📸 Product Contact Sheet - {data['shoot_no']}

Client: {data['first_name']} {data['last_name']}
Order Date: {data['order_date']}
Products: {image_count} items

{jpg_url}

Generated: {datetime.now().strftime('%Y-%m-%d %H:%M')}"""

    if add_contact_note(data['contact_id'], note_body):
        print(f"   ✓ Note added")
    else:
        print(f"   ⚠ Failed to add note")

    print("\n" + "=" * 60)
    print("✓ SUCCESS!")
    print(f"  JPG: {jpg_filename}")
    print(f"  Images: {image_count}")
    print(f"  Contact: {data['first_name']} {data['last_name']}")
    print("=" * 60)

    # Save result
    with open(os.path.join(_get_output_dir(), "ghl_contactsheet_result.json"), 'w', encoding='utf-8') as f:
        json.dump({
            'success': True,
            'jpg_filename': jpg_filename,
            'jpg_url': jpg_url,
            'folder_id': folder_id,
            'contact_id': data['contact_id'],
            'shoot_no': data['shoot_no'],
            'client': f"{data['first_name']} {data['last_name']}",
            'image_count': image_count
        }, f, indent=2)

if __name__ == "__main__":
    main()

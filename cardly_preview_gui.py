"""
Cardly Card Preview GUI
Copyright (c) 2026 GuyMayer. All rights reserved.

A tkinter-based GUI for previewing and sending Cardly greeting cards.
Replaces the AHK-based CardPreview GUI for better image handling.

Usage:
  python cardly_preview_gui.py <image_folder> <contact_id> <first_name> <message> [--template-id ID] [--sticker-folder PATH] [--card-width W] [--card-height H] [--media-name NAME] [--postcard-folder PATH] [--ghl-media-folder-id ID] [--photo-link-field FIELD] [--psa PATH] [--xml PATH] [--alt-template-id ID] [--alt-card-width W] [--alt-card-height H]

Image source modes:
  Default: Scans <image_folder> for JPG/PNG/TIF files
  --psa + --xml: Extracts ordered images from PSA thumbnails filtered by XML order data

Returns exit code:
  0 = Card sent successfully
  1 = User cancelled
  2 = Error occurred
"""

import subprocess
import sys
import os
import json
import math
import re as _re
import calendar as _calendar
import locale as _locale
import xml.etree.ElementTree as ET
import tkinter as tk
from tkinter import ttk, messagebox
from pathlib import Path
import atexit
import ctypes
import threading
import queue as _queue

# Activate system locale for date formatting (e.g. DD/MM/YYYY in UK, MM/DD/YYYY in US)
try:
    _locale.setlocale(_locale.LC_TIME, '')
except _locale.Error:
    pass

# Set Windows AppUserModelID so the taskbar shows our icon, not Python's
try:
    ctypes.windll.shell32.SetCurrentProcessExplicitAppUserModelID('GuyMayer.SideKick.CardlyPreview.1')
except Exception:
    pass

# Enable DPI awareness so window positioning matches physical pixel coordinates
# (consistent with AHK's SetThreadDpiAwarenessContext SYSTEM_AWARE)
try:
    ctypes.windll.shcore.SetProcessDpiAwareness(1)  # PROCESS_SYSTEM_DPI_AWARE
except Exception:
    pass

# === WINDOW ICON HELPER ===
_icon_path_cache = None

def _set_window_icon(win):
    """Set the SideKick icon on any Tk or Toplevel window."""
    global _icon_path_cache
    try:
        if _icon_path_cache is None:
            if getattr(sys, 'frozen', False):
                _d = os.path.dirname(sys.executable)
            else:
                _d = os.path.dirname(os.path.abspath(__file__))
            _p = os.path.join(_d, 'SideKick_PS.ico')
            _icon_path_cache = _p if os.path.isfile(_p) else ''
        if _icon_path_cache:
            win.iconbitmap(_icon_path_cache)
    except Exception:
        pass


# === TOOLTIP ===
class ToolTip:
    """Simple tooltip class for tkinter widgets.
    Shows after a 2-second hover delay so tooltips don't get in the way.
    """
    DELAY_MS = 2000  # milliseconds before tooltip appears

    def __init__(self, widget, text: str):
        self.widget = widget
        self.text = text
        self.tooltip = None
        self._after_id = None
        widget.bind('<Enter>', self._schedule)
        widget.bind('<Leave>', self.hide)

    def _schedule(self, event=None):
        """Schedule the tooltip to appear after DELAY_MS."""
        self._cancel()
        self._after_id = self.widget.after(self.DELAY_MS, self._show)

    def _cancel(self):
        """Cancel any pending tooltip display."""
        if self._after_id:
            self.widget.after_cancel(self._after_id)
            self._after_id = None

    def _show(self):
        """Display the tooltip near the widget."""
        self._after_id = None
        bbox = self.widget.bbox('insert') if hasattr(self.widget, 'bbox') else None
        x, y = (bbox[0], bbox[1]) if bbox else (0, 0)
        x += self.widget.winfo_rootx() + 25
        y += self.widget.winfo_rooty() + 25

        self.tooltip = tk.Toplevel(self.widget)
        self.tooltip.wm_overrideredirect(True)
        self.tooltip.wm_geometry(f"+{x}+{y}")

        label = tk.Label(self.tooltip, text=self.text, background='#ffffe0',
                        relief='solid', borderwidth=1, font=('Segoe UI', 9))
        label.pack()

    def hide(self, event=None):
        """Hide and destroy the tooltip, cancel any pending show."""
        self._cancel()
        if self.tooltip:
            self.tooltip.destroy()
            self.tooltip = None


# === SINGLETON PROTECTION ===
LOCK_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), '.cardly_preview.lock')

def get_pid_from_lock() -> int | None:
    """Read PID from lock file."""
    try:
        if os.path.exists(LOCK_FILE):
            with open(LOCK_FILE, 'r', encoding='utf-8') as f:
                return int(f.read().strip())
    except (IOError, ValueError):
        pass
    return None

def is_process_running(pid: int | None) -> bool:
    """Check if a process with given PID is running."""
    if pid is None:
        return False
    try:
        # Windows-specific check using kernel32
        PROCESS_QUERY_LIMITED_INFORMATION = 0x1000
        STILL_ACTIVE = 259

        kernel32 = ctypes.windll.kernel32
        handle = kernel32.OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, False, pid)
        if handle:
            exit_code = ctypes.c_ulong()
            if kernel32.GetExitCodeProcess(handle, ctypes.byref(exit_code)):
                kernel32.CloseHandle(handle)
                return exit_code.value == STILL_ACTIVE
            kernel32.CloseHandle(handle)
        return False
    except Exception:
        # Fallback: try to check via os
        try:
            os.kill(pid, 0)
            return True
        except OSError:
            return False

def bring_existing_to_front(pid: int) -> bool:
    """Try to bring existing instance window to front."""
    try:
        from ctypes import wintypes

        user32 = ctypes.windll.user32

        # Callback to find window by PID
        EnumWindowsProc = ctypes.WINFUNCTYPE(ctypes.c_bool, wintypes.HWND, wintypes.LPARAM)

        found_hwnd = [None]

        def callback(hwnd, lparam) -> bool:
            """Window enumeration callback."""
            pid_out = wintypes.DWORD()
            user32.GetWindowThreadProcessId(hwnd, ctypes.byref(pid_out))
            if pid_out.value == pid:
                if user32.IsWindowVisible(hwnd):
                    found_hwnd[0] = hwnd
                    return False  # Stop enumeration
            return True

        user32.EnumWindows(EnumWindowsProc(callback), 0)

        if found_hwnd[0]:
            # Restore if minimized
            SW_RESTORE = 9
            user32.ShowWindow(found_hwnd[0], SW_RESTORE)
            # Bring to front
            user32.SetForegroundWindow(found_hwnd[0])
            return True
    except Exception as e:
        print(f"Could not bring window to front: {e}")
    return False

def acquire_lock() -> bool:
    """Try to acquire singleton lock. Returns True if acquired."""
    existing_pid = get_pid_from_lock()

    if existing_pid and is_process_running(existing_pid):
        # Another instance is running - try to bring it to front
        print(f"Another instance is already running (PID: {existing_pid})")
        bring_existing_to_front(existing_pid)
        return False

    # Create/update lock file with our PID
    try:
        with open(LOCK_FILE, 'w', encoding='utf-8') as f:
            f.write(str(os.getpid()))
        return True
    except Exception as e:
        print(f"Could not create lock file: {e}")
        return True  # Continue anyway if lock file fails

def release_lock() -> None:
    """Release singleton lock on exit."""
    try:
        if os.path.exists(LOCK_FILE):
            # Only remove if it's our lock
            existing_pid = get_pid_from_lock()
            if existing_pid == os.getpid():
                os.remove(LOCK_FILE)
    except (IOError, OSError):
        pass

# Register cleanup
atexit.register(release_lock)

# Check singleton immediately
if not acquire_lock():
    sys.exit(1)  # Exit if another instance is running

# Auto-install dependencies
def install_dependencies() -> None:
    """Auto-install required packages if missing."""
    required = ['pillow', 'requests']
    for package in required:
        try:
            __import__(package if package != 'pillow' else 'PIL')
        except ImportError:
            subprocess.check_call([sys.executable, '-m', 'pip', 'install', package, '-q'])

install_dependencies()

import io as _io
from PIL import Image, ImageTk, ImageCms
import requests

# sRGB profile for display colour management
_SRGB_PROFILE = ImageCms.createProfile('sRGB')

# Import from existing cardly module
script_dir = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, script_dir)

try:
    from cardly_send_card import (
        resize_image_for_cardly, create_cardly_artwork, place_cardly_order,
        get_ghl_contact, upload_to_ghl_photos, update_ghl_contact_field,
        _enrich_contact_address, save_to_album_folder, list_recent_orders,
        sanitize_recipient,
        CARDLY_API_KEY, CARDLY_MEDIA_ID, GHL_API_KEY,
        CARDLY_WIDTH, CARDLY_HEIGHT, debug_print, DEBUG
    )
except ImportError as e:
    print(f"Error importing cardly module: {e}")
    sys.exit(2)

# Card aspect ratio (defaults, may be overridden by __init__ args)
CARD_RATIO = CARDLY_WIDTH / CARDLY_HEIGHT  # ~1.371

class CardPreviewGUI:
    def __init__(self, image_folder, contact_id, first_name, message, template_id=None, sticker_folder=None, card_width=None, card_height=None, media_name=None, postcard_folder=None, ghl_media_folder_id=None, photo_link_field=None, psa_path=None, xml_path=None, album_name=None, test_mode=False, preselect_image=None, save_to_album=False, album_folder=None, alt_template_id=None, alt_card_width=None, alt_card_height=None, ps_geometry=None):
        # ProSelect window geometry for centering (x, y, w, h) or None
        self.ps_geometry = ps_geometry

        self.image_folder = image_folder
        self.contact_id = contact_id
        self.first_name = first_name
        self.message = message.replace('\\n', '\n') if message else ''
        self.template_id = template_id or CARDLY_MEDIA_ID
        self.sticker_folder = sticker_folder
        self.postcard_folder = postcard_folder
        self.ghl_media_folder_id = ghl_media_folder_id
        self.photo_link_field = photo_link_field
        self.psa_path = psa_path
        self.xml_path = xml_path
        self.album_name = album_name
        self.test_mode = test_mode
        self.preselect_image = preselect_image  # Filename to pre-select in filmstrip
        self.save_to_album = save_to_album  # Whether to save copy to album folder
        self.album_folder = album_folder  # Album folder path

        # Card dimensions from template selection (override module defaults)
        self.card_width = int(card_width) if card_width else CARDLY_WIDTH
        self.card_height = int(card_height) if card_height else CARDLY_HEIGHT
        self.card_ratio = self.card_width / self.card_height
        self.media_name = media_name or "Landscape Card"

        # Alternate orientation template (for rotate/swap button)
        self.alt_template_id = alt_template_id
        self.alt_card_width = int(alt_card_width) if alt_card_width else None
        self.alt_card_height = int(alt_card_height) if alt_card_height else None
        self.has_alt_orientation = (self.alt_template_id is not None
                                    and self.alt_card_width is not None
                                    and self.alt_card_height is not None)

        # Image list
        self.images = []
        self.current_index = 0
        self.current_image = None
        self.current_photo = None

        # Crop parameters (percentages)
        self.crop_x = 50
        self.crop_y = 50
        self.zoom = 100
        self.rotation = 0  # Degrees, -45 to +45

        # Sticker
        self.sticker_path = None
        self.sticker_image = None
        self.sticker_photo = None
        self.sticker_x = 75  # Position as percentage within crop area
        self.sticker_y = 75
        self.sticker_zoom = 50  # Sticker size as percentage (50 = 50% of crop width)
        self.sticker_name = "None"  # Remembered sticker filename

        # Load saved sticker preferences
        self._load_sticker_prefs()

        # Sticker drag state
        self.sticker_dragging = False
        self.sticker_drag_offset_x = 0
        self.sticker_drag_offset_y = 0

        # Drag state
        self.dragging = False
        self.drag_start_x = 0
        self.drag_start_y = 0
        self.drag_start_crop_x = 0
        self.drag_start_crop_y = 0

        # Result
        self.result = 1  # Default to cancelled
        self.image_source = ""  # Track which source loaded images

        # Load images
        self.load_images()

        # Check PSA is available (required for client data)
        if not self.psa_path or not os.path.exists(self.psa_path):
            import tkinter.messagebox as _mb
            _root = tk.Tk()
            _set_window_icon(_root)
            _root.withdraw()
            _mb.showwarning(
                "No Album Found",
                "Could not find a saved ProSelect album (.psa) for this shoot.\n\n"
                "Please save the album in ProSelect first, then try again.\n\n"
                "The album is needed for client details and images."
            )
            _root.destroy()
            self.result = 1
            return

        # Create GUI
        self.root = tk.Tk()
        self.root.withdraw()  # Hide until fully built
        # Set window/taskbar icon
        _set_window_icon(self.root)
        # Build window title with successful image source only
        title = "SideKick - Send Greeting Card"
        if self.image_source:
            title += f"  ({self.image_source})"
        self.root.title(title)
        self.root.configure(bg='#1a1a1a')
        self.root.resizable(False, False)

        # Show a dark splash with spinning animation while building the GUI
        self._splash = tk.Toplevel()
        self._splash.overrideredirect(True)
        self._splash.configure(bg='#1a1a1a')
        self._splash.attributes('-topmost', True)
        sw, sh = 280, 120
        sx, sy = self._center_on_ps(self._splash, sw, sh)
        self._splash.geometry(f'{sw}x{sh}+{sx}+{sy}')
        _set_window_icon(self._splash)
        self._splash_canvas = tk.Canvas(self._splash, width=sw, height=sh,
                                        bg='#1a1a1a', highlightthickness=0)
        self._splash_canvas.pack()
        self._splash_canvas.create_text(sw // 2, sh // 2 + 25,
                                        text='Loading...', fill='#888888',
                                        font=('Segoe UI', 10))
        self._splash_angle = 0
        self._draw_spinner()
        self._splash.update()

        # Dark theme for ttk widgets
        style = ttk.Style(self.root)
        style.theme_use('clam')
        style.configure('TCombobox',
                        fieldbackground='#2a2a2a', background='#333333',
                        foreground='white', arrowcolor='white',
                        selectbackground='#444444', selectforeground='white')
        style.map('TCombobox',
                  fieldbackground=[('readonly', '#2a2a2a')],
                  foreground=[('readonly', 'white')],
                  selectbackground=[('readonly', '#444444')],
                  selectforeground=[('readonly', 'white')])
        style.configure('Horizontal.TScale',
                        background='#1a1a1a', troughcolor='#333333')
        self.root.option_add('*TCombobox*Listbox.background', '#2a2a2a')
        self.root.option_add('*TCombobox*Listbox.foreground', 'white')
        self.root.option_add('*TCombobox*Listbox.selectBackground', '#444444')
        self.root.option_add('*TCombobox*Listbox.selectForeground', 'white')

        # Resolve recipient address for display in the GUI
        self._pump_splash()
        self._resolve_recipient()

        self._pump_splash()
        self.create_widgets()

        # Pre-select image from ProSelect if specified
        self._pump_splash()
        if self.preselect_image:
            self._preselect_filmstrip_image()
        else:
            # Auto-swap orientation for the first image
            self.select_image(0)

    def _resolve_recipient(self):
        """Resolve recipient details from PSA/XML/GHL for display."""
        self.recipient = None
        self.recipient_source = ""
        self.ghl_date_fields = {}  # {display_label: 'YYYY-MM-DD'}
        self.requested_arrival = None  # None = ASAP
        self._ghl_birthday = None  # raw DOB string from GHL contact
        for label_src, fn in [("PSA", self._extract_client_from_psa),
                              ("XML", self._extract_client_from_xml),
                              ("GHL", self._get_ghl_recipient)]:
            try:
                self._pump_splash()
                result_data = fn()
                if result_data and result_data.get('name', '').strip():
                    self.recipient = result_data
                    self.recipient_source = label_src
                    break
            except Exception:
                pass

        # Fill missing address fields from fallback sources
        if self.recipient:
            for fallback_fn in (self._extract_client_from_xml, self._get_ghl_recipient):
                missing_keys = [k for k in ('address1', 'address2', 'city', 'state', 'postcode')
                                if not self.recipient.get(k, '').strip()]
                if not missing_keys:
                    break
                try:
                    fallback = fallback_fn()
                    if fallback:
                        for k in missing_keys:
                            if fallback.get(k, '').strip():
                                self.recipient[k] = fallback[k]
                except Exception:
                    pass
            sanitize_recipient(self.recipient)

    def _draw_spinner(self):
        """Draw one frame of a spinning arc on the splash screen."""
        if not hasattr(self, '_splash') or self._splash is None:
            return
        try:
            c = self._splash_canvas
            sw = int(c['width'])
            sh = int(c['height'])
            cx, cy, r = sw // 2, sh // 2 - 5, 20
            c.delete('spinner')
            # Draw 8 dots in a circle, brightest at the current angle
            for i in range(8):
                a = math.radians(self._splash_angle + i * 45)
                x = cx + r * math.cos(a)
                y = cy - r * math.sin(a)
                brightness = max(0x33, 0xFF - i * 0x1C)
                colour = f'#{brightness:02x}{brightness:02x}{brightness:02x}'
                dot_r = 4 if i == 0 else 3
                c.create_oval(x - dot_r, y - dot_r, x + dot_r, y + dot_r,
                              fill=colour, outline='', tags='spinner')
            self._splash_angle = (self._splash_angle - 30) % 360
            self._splash.after(80, self._draw_spinner)
        except tk.TclError:
            pass  # splash already destroyed

    def _preselect_filmstrip_image(self):
        """Pre-select the image matching self.preselect_image in the filmstrip.
        Matches by filename stem (without extension) to handle PSA thumbnails (.jpg)
        vs original files (.tif etc)."""
        target_stem = os.path.splitext(self.preselect_image)[0].lower()
        for i, img_path in enumerate(self.images):
            img_stem = os.path.splitext(os.path.basename(img_path))[0].lower()
            if img_stem == target_stem:
                self.select_image(i)
                # Scroll filmstrip to show the selected thumbnail
                if hasattr(self, 'film_canvas') and self.thumb_labels:
                    total = len(self.thumb_labels)
                    if total > 1:
                        fraction = max(0.0, (i - 1) / total)
                        self.film_canvas.xview_moveto(fraction)
                return

    def _get_prefs_path(self):
        """Get path to sticker prefs JSON file."""
        appdata = os.environ.get('APPDATA', '')
        if appdata:
            prefs_dir = os.path.join(appdata, 'SideKick_PS')
            os.makedirs(prefs_dir, exist_ok=True)
            return os.path.join(prefs_dir, 'cardly_sticker_prefs.json')
        return os.path.join(os.path.dirname(os.path.abspath(__file__)), 'cardly_sticker_prefs.json')

    def _load_sticker_prefs(self):
        """Load sticker name, zoom and position from prefs file."""
        try:
            prefs_path = self._get_prefs_path()
            if os.path.exists(prefs_path):
                with open(prefs_path, 'r', encoding='utf-8') as f:
                    prefs = json.load(f)
                self.sticker_name = prefs.get('sticker_name', 'None')
                self.sticker_x = prefs.get('sticker_x', 75)
                self.sticker_y = prefs.get('sticker_y', 75)
                self.sticker_zoom = prefs.get('sticker_zoom', 50)
                # Validate sticker file still exists
                if self.sticker_name != 'None' and self.sticker_folder:
                    spath = os.path.join(self.sticker_folder, self.sticker_name)
                    if os.path.exists(spath):
                        self.sticker_path = spath
                        self.sticker_image = Image.open(spath)
                    else:
                        self.sticker_name = 'None'
        except Exception:
            pass

    def _save_sticker_prefs(self):
        """Save sticker name, zoom and position to prefs file."""
        try:
            prefs = {
                'sticker_name': self.sticker_name,
                'sticker_x': self.sticker_x,
                'sticker_y': self.sticker_y,
                'sticker_zoom': self.sticker_zoom
            }
            with open(self._get_prefs_path(), 'w', encoding='utf-8') as f:
                json.dump(prefs, f, indent=2)
        except Exception:
            pass

    def _pump_splash(self):
        """Process pending splash events so the spinner keeps animating."""
        if hasattr(self, '_splash') and self._splash is not None:
            try:
                self._splash.update()
            except tk.TclError:
                pass

    def _center_on_ps(self, win, w, h):
        """Return (x, y) to center a window of size w×h on the ProSelect window.

        Falls back to screen-center if no ProSelect geometry was provided.
        """
        if self.ps_geometry:
            ps_x, ps_y, ps_w, ps_h = self.ps_geometry
            x = ps_x + (ps_w - w) // 2
            y = ps_y + (ps_h - h) // 2
        else:
            x = (win.winfo_screenwidth() - w) // 2
            y = (win.winfo_screenheight() - h) // 2
        return x, y

    def load_images(self):
        """Load images from folder, PSA ordered images, or browse.

        Image source priority:
        1. PSA all thumbnails: Always available when PSA exists.
        2. PSA + XML: Ordered images only (if XML export matches album).
        3. Folder scan: Load JPG/PNG/TIF files from image_folder.
        """
        # Mode 1: PSA - extract all thumbnails (always available)
        if self.psa_path and os.path.exists(self.psa_path):
            self._load_psa_all_thumbnails()
            if self.images:
                self.image_source = f"PSA: {os.path.basename(self.psa_path)}"
                return

        # Mode 2: PSA + XML ordered images (filtered subset)
        if self.psa_path and self.xml_path and os.path.exists(self.psa_path):
            self._load_psa_ordered_images()
            if self.images:
                self.image_source = f"PSA+XML: {os.path.basename(self.psa_path)}"
                return

        # Mode 3: Folder scan (fallback)
        folder = Path(self.image_folder)
        if not folder.exists():
            return

        # Try multiple patterns including TIF for hi-res originals
        patterns = ['*.jpg', '*.jpeg', '*.png', '*.tif', '*.tiff']
        for pattern in patterns:
            for img_path in folder.glob(pattern):
                if 'LOGO' not in img_path.name.upper() and 'Product_1' not in img_path.name:
                    self.images.append(str(img_path))

        self.images.sort()
        if self.images:
            self.image_source = f"Folder: {folder.name}"

    def _load_psa_ordered_images(self):
        """Extract ordered images from PSA file using XML order data.

        Parses the XML export for <Image_Name> entries to identify which
        images were ordered, then extracts matching thumbnails from the
        PSA SQLite database's Thumbnails table.
        """
        import sqlite3
        import tempfile

        # Parse XML for ordered image names
        ordered_names = set()
        try:
            tree = ET.parse(self.xml_path)
            xml_root = tree.getroot()
            for el in xml_root.iter('Image_Name'):
                if el.text:
                    ordered_names.add(el.text.strip())
            # Also collect Original_Image paths for hi-res fallback
            # Image_Name and Original_Image are siblings inside the same parent element
            self._original_image_paths = {}
            for parent in xml_root.iter():
                img_el = parent.find('Image_Name')
                orig_el = parent.find('Original_Image')
                if img_el is not None and orig_el is not None and img_el.text and orig_el.text:
                    self._original_image_paths[img_el.text.strip()] = orig_el.text.strip().replace('\\\\', '\\')
        except Exception as e:
            print(f"Error parsing XML: {e}")
            return

        if not ordered_names:
            print("No ordered images found in XML")
            return

        # Extract thumbnails from PSA
        try:
            conn = sqlite3.connect(self.psa_path)
            cursor = conn.cursor()

            # Get ImageList to map albumimage IDs to filenames
            cursor.execute('SELECT buffer FROM BigStrings WHERE buffCode="ImageList"')
            row = cursor.fetchone()
            if not row:
                conn.close()
                return

            image_data = row[0]
            if isinstance(image_data, bytes):
                image_data = image_data.decode('utf-8', errors='replace')

            # Build ID → name mapping using ElementTree
            image_ids = {}
            img_root = ET.fromstring(image_data)
            ordered_stems = {os.path.splitext(n)[0] for n in ordered_names}
            for img_el in img_root.iter('image'):
                name = img_el.get('name')
                if not name:
                    continue
                ai_el = img_el.find('albumimage')
                if ai_el is None or ai_el.get('id') is None:
                    continue
                album_id = int(ai_el.get('id'))
                if name in ordered_names or os.path.splitext(name)[0] in ordered_stems:
                    image_ids[album_id] = name

            # Extract matching thumbnails to temp folder
            temp_dir = os.path.join(tempfile.gettempdir(), 'sidekick_ps_cardly')
            os.makedirs(temp_dir, exist_ok=True)
            self._temp_thumb_dir = temp_dir

            cursor.execute('''
                SELECT imageID, imageData
                FROM Thumbnails
                WHERE thumbnailType = 1 AND imageData IS NOT NULL
            ''')

            for image_id, data in cursor.fetchall():
                if not data or data[:2] != b'\xff\xd8':
                    continue
                if image_id not in image_ids:
                    continue

                name = image_ids[image_id]
                base_name = os.path.splitext(name)[0]
                thumb_path = os.path.join(temp_dir, f"{base_name}.jpg")

                with open(thumb_path, 'wb') as f:
                    f.write(data)

                # Check for hi-res original and prefer it if available
                if name in self._original_image_paths:
                    orig_path = self._original_image_paths[name]
                    if os.path.exists(orig_path):
                        self.images.append(orig_path)
                        continue

                self.images.append(thumb_path)

            conn.close()
            self.images.sort()
            print(f"Loaded {len(self.images)} ordered images from PSA")

        except Exception as e:
            print(f"Error extracting PSA thumbnails: {e}")

    def _extract_client_from_psa(self) -> dict | None:
        """Extract client details from PSA OrderList XML.

        Returns a Cardly-ready recipient dict, or None if unavailable.
        Available fields in PSA OrderList: firstName, lastName, address1,
        city, state, zip, country, phone1, email.
        """

        if not self.psa_path or not os.path.exists(self.psa_path):
            return None

        try:
            conn = sqlite3.connect(self.psa_path)
            cursor = conn.cursor()
            cursor.execute("SELECT buffer FROM BigStrings WHERE buffCode='OrderList'")
            row = cursor.fetchone()
            conn.close()
            if not row:
                return None

            data = row[0] if isinstance(row[0], str) else row[0].decode('utf-8', errors='replace')
            root = ET.fromstring(data)
            grp = root.find('.//Group')
            if grp is None:
                return None

            def _tag(tag: str) -> str:
                return (grp.findtext(tag) or '').strip()

            first = _tag('firstName')
            last = _tag('lastName')
            if not first and not last:
                return None

            return {
                "name": f"{first} {last}".strip(),
                "address1": _tag('address1'),
                "address2": _tag('address2'),
                "city": _tag('city'),
                "state": _tag('state'),
                "postcode": _tag('zip'),
                "country": _tag('country') or 'GB',
                "email": _tag('email'),
                "phone": _tag('phone1') or _tag('phone') or _tag('mobile'),
                "_source": "PSA"
            }
        except Exception as e:
            print(f"Error extracting client from PSA: {e}")
            return None

    def _extract_client_from_xml(self) -> dict | None:
        """Extract client details from ProSelect order export XML.

        Returns a Cardly-ready recipient dict, or None if unavailable.
        XML root is <Client> with children: First_Name, Last_Name, Street,
        Street2, City, State, Zip_Code, Email_Address, Home_Phone, etc.
        """
        if not self.xml_path or not os.path.exists(self.xml_path):
            return None

        try:
            tree = ET.parse(self.xml_path)
            root = tree.getroot()

            def _el(tag: str) -> str:
                el = root.find(tag)
                return (el.text or '').strip() if el is not None else ''

            first = _el('First_Name')
            last = _el('Last_Name')
            if not first and not last:
                return None

            street = _el('Street')
            street2 = _el('Street2')

            return {
                "name": f"{first} {last}".strip(),
                "address1": street,
                "address2": street2,
                "city": _el('City'),
                "state": _el('State'),
                "postcode": _el('Zip_Code'),
                "country": _el('Country') or 'GB',
                "email": _el('Email_Address'),
                "phone": _el('Home_Phone') or _el('Cell_Phone'),
                "_source": "XML"
            }
        except Exception as e:
            print(f"Error extracting client from XML: {e}")
            return None

    def _get_ghl_recipient(self) -> dict | None:
        """Fetch client details from GHL contact API.

        Used as a fallback to fill missing address fields when PSA/XML
        don't have the full postal address.
        """
        if not self.contact_id:
            return None
        try:
            contact_result = get_ghl_contact(self.contact_id)
            if not contact_result.get('success'):
                return None
            ghl_data = contact_result.get('data', {})
            contact = ghl_data.get('contact', ghl_data)
            # Store birthday for the Receiving Date dropdown
            if not hasattr(self, '_ghl_birthday') or self._ghl_birthday is None:
                self._ghl_birthday = contact.get('dateOfBirth') or None
            # Enrich with custom address fields (GHL stores address2/3 as custom fields)
            _enrich_contact_address(contact)
            # Combine address2 + address3 into a single address2 for Cardly
            # GHL may return None for these fields; use 'or' to default to ''
            addr2 = contact.get('address2') or ''
            addr3 = contact.get('address3') or ''
            address2 = f"{addr2}, {addr3}" if addr2 and addr3 else addr2 or addr3
            return {
                "name": f"{contact.get('firstName', '')} {contact.get('lastName', '')}".strip(),
                "address1": contact.get('address1', ''),
                "address2": address2,
                "city": contact.get('city', ''),
                "state": contact.get('state', ''),
                "postcode": contact.get('postalCode', ''),
                "country": contact.get('country', 'GB'),
                "_source": "GHL"
            }
        except Exception as e:
            print(f"GHL recipient lookup failed (see debug log)")
            return None

    def _load_psa_all_thumbnails(self):
        """Extract ALL thumbnails from PSA file (no XML filter).

        Used when no order export XML is available. Extracts every
        type-1 thumbnail from the PSA database.
        Also builds _psa_source_paths mapping image names to original
        full-resolution files on disk (parsed from ImageList sourceFolders).
        """

        try:
            conn = sqlite3.connect(self.psa_path)
            cursor = conn.cursor()

            # Get ImageList to map albumimage IDs to filenames
            cursor.execute('SELECT buffer FROM BigStrings WHERE buffCode="ImageList"')
            row = cursor.fetchone()
            if not row:
                conn.close()
                return

            image_data = row[0]
            if isinstance(image_data, bytes):
                image_data = image_data.decode('utf-8', errors='replace')

            # Build ID → name mapping (all images) and name → sourceFoldIndex
            image_ids = {}
            image_folder_idx = {}  # name → sourceFoldIndex
            img_root = ET.fromstring(image_data)
            for img_el in img_root.iter('image'):
                name = img_el.get('name')
                fold_idx = img_el.get('sourceFoldIndex')
                ai_el = img_el.find('albumimage')
                if not name or ai_el is None or ai_el.get('id') is None:
                    continue
                album_id = int(ai_el.get('id'))
                image_ids[album_id] = name
                if fold_idx:
                    image_folder_idx[name] = fold_idx

            # Parse sourceFolders to get folder index → path mapping
            # The saveInfo attribute encodes paths after a ##2## marker
            # e.g. ##2##E:\\Shoot Archive\\P25064P_Mashiri\\Unprocessed\\
            source_folders = {}  # index → path
            for folder_el in img_root.iter('folder'):
                idx = folder_el.get('sourceFoldIndex')
                save_info = folder_el.get('saveInfo', '')
                if not idx or '##2##' not in save_info:
                    continue
                raw_path = save_info.split('##2##', 1)[1]
                # Normalise: replace double-escaped backslashes, strip trailing slashes
                raw_path = raw_path.replace('\\\\', '\\').rstrip('\\')
                source_folders[idx] = raw_path

            # Build name → original file path, resolving drive-letter mismatches
            self._psa_source_paths = {}
            psa_dir = os.path.dirname(self.psa_path) if self.psa_path else ''
            for name, idx in image_folder_idx.items():
                if idx not in source_folders:
                    continue
                folder_path = source_folders[idx]
                candidate = os.path.join(folder_path, name)
                resolved = self._resolve_source_path(candidate, psa_dir, name)
                if resolved:
                    self._psa_source_paths[name] = resolved

            if self._psa_source_paths:
                print(f"Mapped {len(self._psa_source_paths)} images to original files on disk")

            # Extract all type-1 thumbnails to temp folder
            temp_dir = os.path.join(tempfile.gettempdir(), 'sidekick_ps_cardly')
            os.makedirs(temp_dir, exist_ok=True)
            self._temp_thumb_dir = temp_dir

            cursor.execute('''
                SELECT imageID, imageData
                FROM Thumbnails
                WHERE thumbnailType = 1 AND imageData IS NOT NULL
            ''')

            for image_id, data in cursor.fetchall():
                if not data or data[:2] != b'\xff\xd8':
                    continue

                if image_id in image_ids:
                    base_name = os.path.splitext(image_ids[image_id])[0]
                    filename = f"{base_name}.jpg"
                else:
                    filename = f"thumb_{image_id:04d}.jpg"

                thumb_path = os.path.join(temp_dir, filename)
                with open(thumb_path, 'wb') as f:
                    f.write(data)
                self.images.append(thumb_path)

            conn.close()
            self.images.sort()
            print(f"Loaded {len(self.images)} thumbnails from PSA (all images)")

        except Exception as e:
            print(f"Error extracting PSA all thumbnails: {e}")

    def _resolve_source_path(self, candidate: str, psa_dir: str, filename: str) -> str | None:
        """Resolve an image source path from the PSA, handling drive-letter
        and folder-name mismatches.

        Strategy:
        1. Try the path exactly as stored in the PSA.
        2. Try replacing the drive letter with common alternatives.
        3. Try the PSA's own directory (originals often sit beside it).
        4. Try the archive root with a fuzzy folder name match
           (e.g. "P25064P_Mashiri_29082025_1311" vs
                 "P25064P_Mashiri_29082025_1311_NO_DISPLAY").

        Returns the first path that exists, or None.
        """
        # 1. Exact path
        if os.path.exists(candidate):
            return candidate

        # 2. Different drive letters
        if len(candidate) >= 2 and candidate[1] == ':':
            tail = candidate[2:]  # everything after drive letter
            for drive in ('D', 'E', 'C', 'F'):
                alt = f"{drive}:{tail}"
                if os.path.exists(alt):
                    return alt
                # Also try common spelling variants (space vs underscore)
                alt2 = f"{drive}:{tail.replace(' ', '_')}"
                if alt2 != alt and os.path.exists(alt2):
                    return alt2
                alt3 = f"{drive}:{tail.replace('_', ' ')}"
                if alt3 != alt and os.path.exists(alt3):
                    return alt3

        # 3. Same directory as the PSA file
        if psa_dir:
            beside = os.path.join(psa_dir, filename)
            if os.path.exists(beside):
                return beside

        # 4. Fuzzy match in archive root
        # Extract the shoot folder name from the path and search for it
        # under D:\Shoot_Archive (with possible suffix differences)
        shoot_match = _re.search(r'(P\d{5}P[^\\]*)', candidate)
        if shoot_match:
            shoot_prefix = shoot_match.group(1).split('_')[0]  # e.g. "P25064P"
            for root in (r'D:\Shoot_Archive', r'E:\Shoot Archive'):
                if not os.path.exists(root):
                    continue
                try:
                    for sub in os.listdir(root):
                        if sub.startswith(shoot_prefix):
                            # Check inside Unprocessed subfolder too
                            for subdir in ('Unprocessed', ''):
                                test = os.path.join(root, sub, subdir, filename) if subdir else os.path.join(root, sub, filename)
                                if os.path.exists(test):
                                    return test
                    # Also try one level deeper (e.g. "1 Ready to Archive")
                    for mid in os.listdir(root):
                        mid_path = os.path.join(root, mid)
                        if not os.path.isdir(mid_path):
                            continue
                        for sub in os.listdir(mid_path):
                            if sub.startswith(shoot_prefix):
                                for subdir in ('Unprocessed', ''):
                                    test = os.path.join(mid_path, sub, subdir, filename) if subdir else os.path.join(mid_path, sub, filename)
                                    if os.path.exists(test):
                                        return test
                except OSError:
                    continue

        return None

    def create_widgets(self):
        """Create all GUI widgets."""
        # Main container
        main_frame = tk.Frame(self.root, bg='#1a1a1a')
        main_frame.pack(padx=20, pady=10)

        # Title row (single line with instructions)
        title_frame = tk.Frame(main_frame, bg='#1a1a1a')
        title_frame.pack(anchor='w', pady=(0, 5))

        tk.Label(title_frame, text="Send Greeting Card",
                font=('Segoe UI', 12, 'bold'), fg='#FFB347', bg='#1a1a1a').pack(side='left')
        tk.Label(title_frame, text="  -  Select image below, zoom to crop, drag to position",
                font=('Segoe UI', 9), fg='silver', bg='#1a1a1a').pack(side='left')

        # Filmstrip
        self.create_filmstrip(main_frame)

        # Content area (preview + controls + recipient)
        content_frame = tk.Frame(main_frame, bg='#1a1a1a')
        content_frame.pack(fill='x', pady=(15, 0))

        # Preview area (left)
        self.create_preview(content_frame)

        # Controls (middle)
        self.create_controls(content_frame)

        # Recipient panel (right)
        self.create_recipient_panel(content_frame)

        # Message section
        self.create_message_section(main_frame)

        # Buttons
        self.create_buttons(main_frame)

    def create_filmstrip(self, parent):
        """Create horizontal filmstrip of thumbnails."""
        film_frame = tk.Frame(parent, bg='#1a1a1a')
        film_frame.pack(fill='x')

        # Scrollable filmstrip (no separate label - instructions in title)
        strip_container = tk.Frame(film_frame, bg='#000000', highlightthickness=1,
                                   highlightbackground='#333333')
        strip_container.pack(fill='x', pady=5)

        # Canvas with scrollbar - taller filmstrip
        self.film_canvas = tk.Canvas(strip_container, bg='#000000', height=115,
                                     highlightthickness=0)
        scrollbar = ttk.Scrollbar(strip_container, orient='horizontal',
                                  command=self.film_canvas.xview)

        self.film_canvas.configure(xscrollcommand=scrollbar.set)
        scrollbar.pack(side='bottom', fill='x')
        self.film_canvas.pack(side='top', fill='x')

        # Inner frame for thumbnails
        self.film_inner = tk.Frame(self.film_canvas, bg='#000000')
        self.film_canvas.create_window((0, 0), window=self.film_inner, anchor='nw')

        # Load thumbnails
        self.thumb_images = []  # Keep references
        self.thumb_labels = []

        for i, img_path in enumerate(self.images):
            try:
                img = Image.open(img_path)
                # Scale to fit height of 100px (taller filmstrip)
                ratio = 100 / img.height
                new_w = int(img.width * ratio)
                img = img.resize((new_w, 100), Image.Resampling.LANCZOS)
                photo = ImageTk.PhotoImage(img)
                self.thumb_images.append(photo)

                lbl = tk.Label(self.film_inner, image=photo, bg='#000000',
                              cursor='hand2', borderwidth=2, relief='flat')
                lbl.pack(side='left', padx=3, pady=5)
                lbl.bind('<Button-1>', lambda e, idx=i: self.select_image(idx))
                self.thumb_labels.append(lbl)
                # Keep splash spinner alive while loading thumbnails
                if i % 3 == 0:
                    self._pump_splash()
            except Exception as e:
                print(f"Error loading thumbnail {img_path}: {e}")

        # Update scroll region
        self.film_inner.update_idletasks()
        self.film_canvas.configure(scrollregion=self.film_canvas.bbox('all'))

        # Mouse wheel scrolling
        self.film_canvas.bind('<MouseWheel>', lambda e: self.film_canvas.xview_scroll(
            int(-1 * (e.delta / 120)), 'units'))

        ToolTip(self.film_canvas, "Click a thumbnail to select the photo for your card.\nScroll left/right to browse all available images.")

    def create_preview(self, parent):
        """Create main preview area with crop rectangle."""
        preview_frame = tk.Frame(parent, bg='#1a1a1a')
        preview_frame.pack(side='left')

        # Preview dimensions
        self.preview_w = 680
        self.preview_h = 430

        # Canvas for preview
        self.preview_canvas = tk.Canvas(preview_frame, width=self.preview_w,
                                        height=self.preview_h, bg='#000000',
                                        highlightthickness=1, highlightbackground='#333333')
        self.preview_canvas.pack()

        # Bind mouse events for dragging
        self.preview_canvas.bind('<Button-1>', self.on_mouse_down)
        self.preview_canvas.bind('<B1-Motion>', self.on_mouse_drag)
        self.preview_canvas.bind('<ButtonRelease-1>', self.on_mouse_up)

        ToolTip(self.preview_canvas, "Drag the white rectangle to reposition the crop area.\nThe card will use the portion inside the bounding box.")

    def create_controls(self, parent):
        """Create control panel on right side."""
        ctrl_frame = tk.Frame(parent, bg='#1a1a1a', width=280)
        ctrl_frame.pack(side='left', fill='both', padx=(20, 0))

        # Crop Controls header with rotate button
        crop_header_frame = tk.Frame(ctrl_frame, bg='#1a1a1a')
        crop_header_frame.pack(fill='x')

        tk.Label(crop_header_frame, text="Crop Controls", font=('Segoe UI', 10, 'bold'),
                fg='#FFB347', bg='#1a1a1a').pack(side='left')

        # Pixel-based square button helper (tkinter measures width/height in chars, not px)
        _btn_px = tk.PhotoImage(width=1, height=1)  # 1x1 transparent pixel for compound sizing

        # Rotate / swap orientation button (only active when alt template exists)
        self.rotate_btn = tk.Button(crop_header_frame, text="\u21C4",
                                    image=_btn_px, compound='center',
                                    font=('Segoe UI', 16), width=32, height=32,
                                    command=self.swap_orientation,
                                    relief='flat', cursor='hand2',
                                    bg='#333333', fg='#FFB347',
                                    activebackground='#444444', activeforeground='#FFB347')
        self.rotate_btn._btn_px = _btn_px  # prevent GC
        self.rotate_btn.pack(side='right', padx=(5, 0))

        # Browse / open image from disc button
        self.browse_btn = tk.Button(crop_header_frame, text="\U0001F4C2",
                                    image=_btn_px, compound='center',
                                    font=('Segoe UI', 16), width=32, height=32,
                                    command=self.browse_image,
                                    relief='flat', cursor='hand2',
                                    bg='#333333', fg='#FFB347',
                                    activebackground='#444444', activeforeground='#FFB347')
        self.browse_btn._btn_px = _btn_px
        self.browse_btn.pack(side='right', padx=(5, 0))
        ToolTip(self.browse_btn, "Browse for an image file from disc.\nOpens at the album folder location.")

        # Reset sliders button (next to folder icon)
        self.reset_btn = tk.Button(crop_header_frame, text="\u21BA",
                                   image=_btn_px, compound='center',
                                   font=('Segoe UI', 16), width=32, height=32,
                                   command=self._reset_sliders,
                                   relief='flat', cursor='hand2',
                                   bg='#333333', fg='#FFB347',
                                   activebackground='#444444', activeforeground='#FFB347')
        self.reset_btn._btn_px = _btn_px
        self.reset_btn.pack(side='right', padx=(5, 0))
        ToolTip(self.reset_btn, "Reset zoom and rotation to defaults.")

        if self.has_alt_orientation:
            ToolTip(self.rotate_btn, "Swap between Landscape and Portrait crop.\nSwitches to the matching template orientation.")
        else:
            self.rotate_btn.configure(state='disabled', fg='#555555', cursor='arrow')
            ToolTip(self.rotate_btn, "No alternate orientation template available.\nUpload both Landscape and Portrait versions\nwith the same base name to enable this.")

        # Zoom slider
        tk.Label(ctrl_frame, text="Zoom", font=('Segoe UI', 8),
                fg='#888888', bg='#1a1a1a').pack(anchor='w', pady=(10, 0))

        zoom_frame = tk.Frame(ctrl_frame, bg='#1a1a1a')
        zoom_frame.pack(fill='x')

        self.zoom_var = tk.IntVar(value=100)
        self.zoom_slider = ttk.Scale(zoom_frame, from_=100, to=200,
                                     variable=self.zoom_var, orient='horizontal',
                                     command=self.on_zoom_change)
        self.zoom_slider.pack(fill='x', expand=True)

        ToolTip(self.zoom_slider, "Zoom into the image to crop a tighter area.\n100% = full image, 200% = maximum zoom.\nCombine with drag to fine-tune the crop.")

        # Rotation slider
        tk.Label(ctrl_frame, text="Rotate", font=('Segoe UI', 8),
                fg='#888888', bg='#1a1a1a').pack(anchor='w', pady=(10, 0))

        rotate_frame = tk.Frame(ctrl_frame, bg='#1a1a1a')
        rotate_frame.pack(fill='x')

        self.rotation_var = tk.IntVar(value=0)
        self.rotation_slider = ttk.Scale(rotate_frame, from_=-45, to=45,
                                         variable=self.rotation_var, orient='horizontal',
                                         command=self.on_rotation_change)
        self.rotation_slider.pack(fill='x', expand=True)
        self.rotation_slider.bind('<Double-Button-1>', lambda e: self._reset_rotation())

        ToolTip(self.rotation_slider, "Rotate the image within the crop border.\n-45° to +45°. Double-click to reset to 0°.")

        # Sticker Overlay
        tk.Label(ctrl_frame, text="Sticker Overlay", font=('Segoe UI', 10, 'bold'),
                fg='#FFB347', bg='#1a1a1a').pack(anchor='w')

        self.sticker_var = tk.StringVar(value=self.sticker_name)
        sticker_options = ["None"]

        if self.sticker_folder and os.path.exists(self.sticker_folder):
            for f in sorted(os.listdir(self.sticker_folder)):
                if f.lower().endswith('.png'):
                    sticker_options.append(f)

        sticker_options.append("Open Folder...")

        self.sticker_combo = ttk.Combobox(ctrl_frame, textvariable=self.sticker_var,
                                          values=sticker_options, state='readonly', width=25)
        self.sticker_combo.pack(anchor='e', pady=(5, 0))
        self.sticker_combo.bind('<<ComboboxSelected>>', self.on_sticker_change)

        ToolTip(self.sticker_combo, "Choose a PNG sticker to overlay on the card.\nSelect 'None' to remove the sticker.\nSticker position and choice are remembered between sessions.")

        # Sticker size slider (same layout as Zoom above)
        tk.Label(ctrl_frame, text="Size", font=('Segoe UI', 8),
                fg='#888888', bg='#1a1a1a').pack(anchor='w', pady=(10, 0))

        sticker_size_frame = tk.Frame(ctrl_frame, bg='#1a1a1a')
        sticker_size_frame.pack(fill='x')

        self.sticker_zoom_var = tk.IntVar(value=self.sticker_zoom)
        self.sticker_zoom_slider = ttk.Scale(sticker_size_frame, from_=10, to=100,
                                             variable=self.sticker_zoom_var, orient='horizontal',
                                             command=self.on_sticker_zoom_change)
        self.sticker_zoom_slider.pack(fill='x', expand=True)

        ToolTip(self.sticker_zoom_slider, "Resize the sticker overlay.\n10 = tiny, 100 = full size.\nDrag the sticker on the preview to reposition it.")

        # Message section (moved to right column)
        tk.Label(ctrl_frame, text=f"Dear {self.first_name},", font=('Segoe UI', 10, 'bold'),
                fg='#FFB347', bg='#1a1a1a').pack(anchor='w', pady=(15, 0))

        self.message_text = tk.Text(ctrl_frame, height=8, width=30,
                                    font=('Segoe UI', 9), wrap='word',
                                    bg='#2a2a2a', fg='white',
                                    insertbackground='white',
                                    selectbackground='#444444',
                                    selectforeground='white',
                                    relief='flat', highlightthickness=1,
                                    highlightbackground='#444444',
                                    highlightcolor='#FFB347')
        self.message_text.pack(fill='x', pady=(5, 0))
        self.message_text.insert('1.0', self.message)

        ToolTip(self.message_text, "Edit the personal message printed inside the card.\nThis text will appear on the back of the postcard.")

    def create_message_section(self, parent):
        """Create message edit section - now integrated into controls."""
        pass  # Moved to create_controls

    def create_buttons(self, parent):
        """Create action buttons - now integrated into controls."""
        pass  # Moved to create_controls

    def create_recipient_panel(self, parent):
        """Create recipient details panel (3rd column)."""
        recip_frame = tk.Frame(parent, bg='#2a2a2a', width=250, padx=15, pady=15)
        recip_frame.pack(side='left', fill='both', padx=(20, 0))
        recip_frame.pack_propagate(False)

        # Header
        tk.Label(recip_frame, text="Recipient", font=('Segoe UI', 10, 'bold'),
                fg='#FFB347', bg='#2a2a2a').pack(anchor='w')

        tk.Frame(recip_frame, bg='#444444', height=1).pack(fill='x', pady=(5, 10))

        # Recipient name
        recip_name = self.recipient.get('name', self.first_name) if self.recipient else self.first_name
        self.recip_name_label = tk.Label(recip_frame, text=recip_name,
                font=('Segoe UI', 10, 'bold'), fg='white', bg='#2a2a2a',
                anchor='w', justify='left')
        self.recip_name_label.pack(fill='x')

        # Address — compact: address1, city+postcode on one line, country
        if self.recipient:
            addr_parts = []
            a1 = self.recipient.get('address1', '').strip()
            if a1:
                addr_parts.append(a1)
            # City, postcode on one line
            city_pc = ', '.join(filter(None, [
                self.recipient.get('city', '').strip(),
                self.recipient.get('postcode', '').strip()
            ]))
            if city_pc:
                addr_parts.append(city_pc)
            country = self.recipient.get('country', '').strip()
            if country:
                addr_parts.append(country)
            addr_text = '\n'.join(addr_parts) if addr_parts else '(no address found)'
        else:
            addr_text = '(recipient details unavailable)'

        self.recip_addr_label = tk.Label(recip_frame, text=addr_text,
                font=('Segoe UI', 8), fg='silver', bg='#2a2a2a',
                anchor='w', justify='left', wraplength=220)
        self.recip_addr_label.pack(fill='x', pady=(2, 0))

        # Separator
        tk.Frame(recip_frame, bg='#444444', height=1).pack(fill='x', pady=(8, 5))

        # Card Details (moved here from controls)
        tk.Label(recip_frame, text="Card Details", font=('Segoe UI', 10, 'bold'),
                fg='#FFB347', bg='#2a2a2a').pack(anchor='w')

        self.template_name_label = tk.Label(recip_frame, text=f"Template: {self.media_name}",
                font=('Segoe UI', 9), fg='silver', bg='#2a2a2a')
        self.template_name_label.pack(anchor='w', pady=(5, 0))
        orient = "Landscape" if self.card_width > self.card_height else "Portrait"
        self.card_size_label = tk.Label(recip_frame, text=f"Size: {self.card_width}x{self.card_height}px ({orient})",
                font=('Segoe UI', 9), fg='silver', bg='#2a2a2a')
        self.card_size_label.pack(anchor='w')

        # Separator before Receiving Date
        tk.Frame(recip_frame, bg='#444444', height=1).pack(fill='x', pady=(15, 10))

        # Receiving Date section
        date_header_frame = tk.Frame(recip_frame, bg='#2a2a2a')
        date_header_frame.pack(fill='x')
        tk.Label(date_header_frame, text="Receiving Date", font=('Segoe UI', 10, 'bold'),
                fg='#FFB347', bg='#2a2a2a').pack(side='left')

        # Refresh button to fetch GHL date fields
        self._date_refresh_btn = tk.Button(date_header_frame, text="\u21bb",
                font=('Segoe UI', 10), width=2,
                bg='#444444', fg='white', activebackground='#555555',
                relief='flat', cursor='hand2',
                command=self._refresh_ghl_dates)
        self._date_refresh_btn.pack(side='right')
        ToolTip(self._date_refresh_btn, "Fetch date fields from this client's\nGHL contact record (e.g. session date,\nbirthday, anniversary).")

        # Pending card indicator (alarm clock) — starts disabled, checked in background
        self._pending_orders = []  # populated by background check
        self._pending_btn = tk.Button(date_header_frame, text="\u23F0",
                font=('Segoe UI', 10), width=2,
                bg='#444444', fg='#666666',
                relief='flat', state='disabled')
        self._pending_btn.pack(side='right', padx=(0, 4))
        ToolTip(self._pending_btn, "Checking for pending cards...")

        # Calendar button to pick a custom date
        self._date_cal_btn = tk.Button(date_header_frame, text="\U0001F4C5",
                font=('Segoe UI', 10), width=2,
                bg='#444444', fg='white', activebackground='#555555',
                relief='flat', cursor='hand2',
                command=self._pick_custom_date)
        self._date_cal_btn.pack(side='right', padx=(0, 4))
        ToolTip(self._date_cal_btn, "Choose a custom receiving date\nfrom a calendar.")

        # Dropdown
        self._date_var = tk.StringVar(value="ASAP")
        self._date_options = ["ASAP"]
        # Pre-populate with session anniversary if we can derive it
        self._populate_initial_dates()
        self._date_combo = ttk.Combobox(recip_frame, textvariable=self._date_var,
                values=self._date_options, state='readonly', width=28,
                font=('Segoe UI', 9), height=6)
        self._date_combo.pack(fill='x', pady=(5, 0))
        self._date_combo.bind('<<ComboboxSelected>>', self._on_date_selected)

        # Style the combobox for dark theme
        style = ttk.Style()
        style.configure('TCombobox', fieldbackground='#333333', background='#444444',
                        foreground='white', arrowcolor='white')

        self._date_info_label = tk.Label(recip_frame, text="Card will be dispatched immediately",
                font=('Segoe UI', 8), fg='#888888', bg='#2a2a2a', anchor='w')
        self._date_info_label.pack(fill='x', pady=(3, 0))

        # Missing address warning
        if self.recipient:
            missing = [k for k in ('address1', 'city', 'postcode')
                       if not self.recipient.get(k, '').strip()]
            if missing:
                tk.Frame(recip_frame, bg='#444444', height=1).pack(fill='x', pady=(15, 10))
                tk.Label(recip_frame, text="\u26a0 Incomplete Address",
                        font=('Segoe UI', 9, 'bold'), fg='#FF6B6B', bg='#2a2a2a',
                        anchor='w').pack(fill='x')
                tk.Label(recip_frame, text=f"Missing: {', '.join(missing)}",
                        font=('Segoe UI', 8), fg='#FF6B6B', bg='#2a2a2a',
                        anchor='w').pack(fill='x')
        elif not self.recipient:
            tk.Frame(recip_frame, bg='#444444', height=1).pack(fill='x', pady=(15, 10))
            tk.Label(recip_frame, text="\u26a0 No recipient found",
                    font=('Segoe UI', 9, 'bold'), fg='#FF6B6B', bg='#2a2a2a',
                    anchor='w').pack(fill='x')

        # Buttons at bottom of recipient panel
        btn_frame = tk.Frame(recip_frame, bg='#2a2a2a')
        btn_frame.pack(side='bottom', fill='x', pady=(10, 0))

        self.post_btn = tk.Button(btn_frame, text="Send Card",
                                  command=self.post_card, font=('Segoe UI', 11, 'bold'),
                                  bg='#4CAF50', fg='white', activebackground='#5CBF60',
                                  activeforeground='white', relief='flat', cursor='hand2')
        self.post_btn.pack(side='left', fill='both', expand=True, padx=(0, 4), ipady=8)

        cancel_btn = tk.Button(btn_frame, text="Cancel",
                              command=self.cancel, font=('Segoe UI', 10),
                              bg='#444444', fg='white', activebackground='#555555',
                              relief='flat', cursor='hand2')
        cancel_btn.pack(side='left', fill='both', expand=True, padx=(4, 0), ipady=8)

        ToolTip(self.post_btn, "Send this card via Cardly now.\nThe selected image will be cropped, resized,\nand submitted with your message to the recipient.")
        ToolTip(cancel_btn, "Close without sending.\nNo card will be created or charged.")

    # === Receiving Date helpers ===

    @staticmethod
    def _format_local_date(d):
        """Format a date object using the system's short date locale (e.g. 05/03/2026 for UK)."""
        try:
            return d.strftime('%x')
        except Exception:
            return d.strftime('%Y-%m-%d')

    @staticmethod
    def _parse_local_date(s):
        """Parse a locale-formatted date string back to a date object.
        Tries locale short format first, then common fallbacks."""
        from datetime import datetime
        for fmt in ('%x', '%Y-%m-%d', '%d/%m/%Y', '%m/%d/%Y', '%d.%m.%Y'):
            try:
                return datetime.strptime(s.strip(), fmt).date()
            except (ValueError, TypeError):
                continue
        return None

    def _populate_initial_dates(self):
        """Pre-populate date dropdown with Birthday (always shown) and any derivable dates."""
        from datetime import datetime, date
        # Always show Birthday — with date or Unknown
        dob = getattr(self, '_ghl_birthday', None)
        if dob:
            for fmt in ('%Y-%m-%dT%H:%M:%S.%fZ', '%Y-%m-%dT%H:%M:%SZ',
                        '%Y-%m-%dT%H:%M:%S', '%Y-%m-%d'):
                try:
                    d = datetime.strptime(dob, fmt).date()
                    self._date_options.append(f"Birthday \u2014 {self._format_local_date(d)}")
                    break
                except (ValueError, TypeError):
                    continue
            else:
                self._date_options.append("Birthday \u2014 Unknown")
        else:
            self._date_options.append("Birthday \u2014 Unknown")

    def _on_date_selected(self, event=None):
        """Handle receiving date selection change."""
        from datetime import datetime, date
        selection = self._date_var.get()
        if selection == "ASAP" or selection.endswith("Unknown"):
            self.requested_arrival = None
            if selection.endswith("Unknown"):
                self._date_info_label.config(text="No date on file \u2014 sending ASAP")
            else:
                self._date_info_label.config(text="Card will be dispatched immediately")
        else:
            # Extract date from selection (format: "Label — <locale date>")
            parts = selection.rsplit(' \u2014 ', 1)
            if len(parts) == 2:
                d = self._parse_local_date(parts[1])
                try:
                    if d is None:
                        raise ValueError('unparseable date')
                    today = date.today()
                    if d <= today:
                        # Date is in the past — bump to next year's anniversary
                        try:
                            d = d.replace(year=today.year)
                            if d <= today:
                                d = d.replace(year=today.year + 1)
                        except ValueError:
                            # Feb 29 edge case
                            d = d.replace(month=3, day=1, year=today.year + 1)
                    self.requested_arrival = d.strftime('%Y-%m-%d')
                    self._date_info_label.config(
                        text=f"Arrive by {self._format_local_date(d)} (Cardly sets dispatch)")
                except ValueError:
                    self.requested_arrival = None
                    self._date_info_label.config(text="Invalid date — sending ASAP")
            else:
                self.requested_arrival = None
                self._date_info_label.config(text="Card will be dispatched immediately")

    def _refresh_ghl_dates(self):
        """Fetch date-type custom fields from GHL contact and add to dropdown."""
        from datetime import datetime, date
        if not self.contact_id:
            messagebox.showinfo("No Contact", "No GHL contact ID available.")
            return

        self._date_refresh_btn.config(state='disabled', text="...")
        self.root.update_idletasks()

        try:
            contact_result = get_ghl_contact(self.contact_id)
            if not contact_result.get('success'):
                messagebox.showwarning("GHL Error",
                    f"Could not fetch contact: {contact_result.get('error', 'Unknown')}")
                return

            ghl_data = contact_result.get('data', {})
            contact = ghl_data.get('contact', ghl_data)

            # Collect date fields from customFields
            found_dates = {}
            custom_fields = contact.get('customFields', [])

            # Also fetch field definitions to get human-readable names
            field_names = {}
            try:
                from cardly_send_card import GHL_BASE_URL, GHL_LOCATION_ID
                if GHL_API_KEY and GHL_LOCATION_ID:
                    headers = {
                        "Authorization": f"Bearer {GHL_API_KEY}",
                        "Version": "2021-07-28"
                    }
                    url = f"{GHL_BASE_URL}/locations/{GHL_LOCATION_ID}/customFields"
                    resp = requests.get(url, headers=headers, timeout=10)
                    if resp.status_code == 200:
                        for cf in resp.json().get('customFields', []):
                            field_names[cf['id']] = cf.get('name', cf.get('fieldKey', ''))
            except Exception as e:
                print(f"Could not fetch field names: {e}")

            for cf in custom_fields:
                cf_id = cf.get('id', '')
                cf_val = cf.get('value', '')
                if not cf_val:
                    continue
                # Try to parse as date (GHL stores dates as ISO strings or YYYY-MM-DD)
                for fmt in ('%Y-%m-%dT%H:%M:%S.%fZ', '%Y-%m-%dT%H:%M:%SZ',
                            '%Y-%m-%dT%H:%M:%S', '%Y-%m-%d'):
                    try:
                        d = datetime.strptime(cf_val, fmt).date()
                        label = field_names.get(cf_id, cf_id)
                        # Clean up label
                        label = label.replace('contact.', '').replace('_', ' ').title()
                        # Abbreviate & adjust known date types
                        low = label.lower()
                        if 'session' in low or 'shoot' in low:
                            label = 'Shoot Anniversary'
                            try:
                                d = d.replace(year=d.year + 1)
                            except ValueError:
                                d = d.replace(month=3, day=1, year=d.year + 1)
                        elif 'wedding' in low:
                            label = label.lower().replace('wedding', 'WD').title()
                        found_dates[label] = self._format_local_date(d)
                        break
                    except (ValueError, TypeError):
                        continue

            # Also check standard contact date fields
            for key, label in [('dateOfBirth', 'Birthday'),
                               ('dateAdded', 'Date Added')]:
                val = contact.get(key)
                if val:
                    for fmt in ('%Y-%m-%dT%H:%M:%S.%fZ', '%Y-%m-%dT%H:%M:%SZ',
                                '%Y-%m-%dT%H:%M:%S', '%Y-%m-%d'):
                        try:
                            d = datetime.strptime(val, fmt).date()
                            found_dates[label] = self._format_local_date(d)
                            break
                        except (ValueError, TypeError):
                            continue

            self.ghl_date_fields = found_dates

            # Rebuild dropdown options — Birthday is always present
            self._date_options = ["ASAP"]
            # Ensure Birthday is always first (with date or Unknown)
            bday_str = found_dates.pop('Birthday', None)
            if bday_str:
                self._date_options.append(f"Birthday \u2014 {bday_str}")
            else:
                self._date_options.append("Birthday \u2014 Unknown")
            # Add remaining date fields
            for label, date_str in sorted(found_dates.items()):
                self._date_options.append(f"{label} \u2014 {date_str}")

            self._date_combo['values'] = self._date_options

            if found_dates:
                count = len(found_dates)
                self._date_info_label.config(
                    text=f"Found {count} date field{'s' if count != 1 else ''} from GHL")
            else:
                self._date_info_label.config(text="No date fields found on this contact")

        except Exception as e:
            messagebox.showwarning("Error", f"Failed to fetch dates: {e}")
        finally:
            self._date_refresh_btn.config(state='normal', text="\u21bb")

    # ── Pending card check ─────────────────────────────────────────────────

    def _check_pending_cards_bg(self):
        """Check Cardly for existing orders for this recipient (runs in background thread)."""
        import threading

        recip_name = ""
        if self.recipient:
            recip_name = self.recipient.get('name', self.first_name)
        else:
            recip_name = self.first_name
        if not recip_name:
            return

        def _worker():
            try:
                result = list_recent_orders(recipient_name=recip_name)
                if result.get('success'):
                    orders = result.get('orders', [])
                    self._pending_orders = orders
                    self.root.after(0, lambda: self._update_pending_btn(orders))
            except Exception as e:
                debug_print(f"Pending card check failed: {e}")

        t = threading.Thread(target=_worker, daemon=True)
        t.start()

    def _update_pending_btn(self, orders):
        """Update the alarm clock button state based on pending orders found."""
        if orders:
            self._pending_btn.config(
                state='normal', fg='#FFB347', cursor='hand2',
                activebackground='#555555', activeforeground='#FFB347',
                command=self._show_pending_cards)
            count = len(orders)
            ToolTip(self._pending_btn,
                    f"{count} existing card{'s' if count != 1 else ''} found\nfor this client. Click for details.")
        else:
            self._pending_btn.config(state='disabled', fg='#666666')
            ToolTip(self._pending_btn, "No pending cards found\nfor this client.")

    def _show_pending_cards(self):
        """Show a popup with details of pending/sent cards for this recipient."""
        orders = self._pending_orders
        if not orders:
            return

        popup = tk.Toplevel(self.root)
        popup.title("Existing Cards")
        popup.configure(bg='#2a2a2a')
        popup.resizable(False, False)
        popup.grab_set()
        _set_window_icon(popup)

        popup.update_idletasks()
        px = self.root.winfo_rootx() + (self.root.winfo_width() // 2) - 180
        py = self.root.winfo_rooty() + (self.root.winfo_height() // 2) - 100
        popup.geometry(f'+{px}+{py}')

        tk.Label(popup, text=f"\u23F0  {len(orders)} Card{'s' if len(orders) != 1 else ''} Found",
                font=('Segoe UI', 11, 'bold'), fg='#FFB347', bg='#2a2a2a'
                ).pack(padx=16, pady=(12, 8))

        list_frame = tk.Frame(popup, bg='#2a2a2a')
        list_frame.pack(fill='both', expand=True, padx=16, pady=(0, 8))

        for i, o in enumerate(orders[:10]):  # show at most 10
            created = (o.get('created') or '')[:10]
            status = o.get('order_status', '?')
            shipped = o.get('shipped')
            est_arr = (o.get('est_max_arrival') or '')[:10]
            label_text = o.get('label', 'Card')

            if shipped:
                state_str = f"Shipped {shipped[:10]}"
                state_fg = '#66BB6A'
            elif est_arr:
                state_str = f"ETA {est_arr}"
                state_fg = '#FFB347'
            else:
                state_str = status.capitalize()
                state_fg = '#888888'

            row = tk.Frame(list_frame, bg='#333333')
            row.pack(fill='x', pady=2)
            tk.Label(row, text=f"{created}  {label_text}",
                    font=('Segoe UI', 9), fg='white', bg='#333333',
                    anchor='w').pack(side='left', padx=8, pady=4)
            tk.Label(row, text=state_str,
                    font=('Segoe UI', 9, 'bold'), fg=state_fg, bg='#333333',
                    anchor='e').pack(side='right', padx=8, pady=4)

        if len(orders) > 10:
            tk.Label(list_frame, text=f"... and {len(orders) - 10} more",
                    font=('Segoe UI', 8), fg='#888888', bg='#2a2a2a'
                    ).pack(pady=(4, 0))

        tk.Button(popup, text="Close", width=10,
                font=('Segoe UI', 9), bg='#444444', fg='white',
                activebackground='#555555', relief='flat', cursor='hand2',
                command=popup.destroy).pack(pady=(4, 12))

    # ── Custom date picker ───────────────────────────────────────────────

    def _pick_custom_date(self):
        """Open a mini calendar popup for the user to pick a custom date."""
        from datetime import date as _date_type

        today = _date_type.today()
        state = {'year': today.year, 'month': today.month}

        popup = tk.Toplevel(self.root)
        popup.title("Pick a Date")
        popup.configure(bg='#2a2a2a')
        popup.resizable(False, False)
        popup.grab_set()
        _set_window_icon(popup)

        # Centre on parent
        popup.update_idletasks()
        px = self.root.winfo_rootx() + (self.root.winfo_width() // 2) - 140
        py = self.root.winfo_rooty() + (self.root.winfo_height() // 2) - 120
        popup.geometry(f'+{px}+{py}')

        header = tk.Frame(popup, bg='#2a2a2a')
        header.pack(fill='x', padx=8, pady=(8, 0))

        month_label = tk.Label(header, text='', font=('Segoe UI', 10, 'bold'),
                               fg='#FFB347', bg='#2a2a2a')
        month_label.pack(side='left', expand=True)

        btn_prev = tk.Button(header, text='\u25C0', font=('Segoe UI', 9), width=3,
                             bg='#444444', fg='white', activebackground='#555555',
                             relief='flat', cursor='hand2')
        btn_prev.pack(side='left')
        btn_next = tk.Button(header, text='\u25B6', font=('Segoe UI', 9), width=3,
                             bg='#444444', fg='white', activebackground='#555555',
                             relief='flat', cursor='hand2')
        btn_next.pack(side='left', padx=(4, 0))

        grid_frame = tk.Frame(popup, bg='#2a2a2a')
        grid_frame.pack(padx=8, pady=8)

        # Day-of-week headers
        for col, day_name in enumerate(['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su']):
            tk.Label(grid_frame, text=day_name, font=('Segoe UI', 8, 'bold'),
                     fg='#888888', bg='#2a2a2a', width=4).grid(row=0, column=col)

        day_btns = []

        def _render_month():
            for b in day_btns:
                b.destroy()
            day_btns.clear()
            y, m = state['year'], state['month']
            month_label.config(text=f"{_calendar.month_name[m]} {y}")
            first_weekday, num_days = _calendar.monthrange(y, m)
            row = 1
            col = first_weekday  # 0=Monday
            for d in range(1, num_days + 1):
                day_val = d
                is_today = (y == today.year and m == today.month and d == today.day)
                fg_color = '#FFB347' if is_today else 'white'
                btn = tk.Button(grid_frame, text=str(d), font=('Segoe UI', 9),
                                width=4, bg='#333333', fg=fg_color,
                                activebackground='#555555', activeforeground='white',
                                relief='flat', cursor='hand2',
                                command=lambda dv=day_val: _on_pick(dv))
                btn.grid(row=row, column=col, padx=1, pady=1)
                day_btns.append(btn)
                col += 1
                if col > 6:
                    col = 0
                    row += 1

        def _prev_month():
            state['month'] -= 1
            if state['month'] < 1:
                state['month'] = 12
                state['year'] -= 1
            _render_month()

        def _next_month():
            state['month'] += 1
            if state['month'] > 12:
                state['month'] = 1
                state['year'] += 1
            _render_month()

        def _on_pick(day):
            picked = _date_type(state['year'], state['month'], day)
            date_str = self._format_local_date(picked)
            label = f"Custom \u2014 {date_str}"
            # Remove any previous Custom entry
            self._date_options = [o for o in self._date_options
                                  if not o.startswith('Custom \u2014')]
            self._date_options.append(label)
            self._date_combo['values'] = self._date_options
            self._date_var.set(label)
            self._on_date_selected()
            popup.destroy()

        btn_prev.config(command=_prev_month)
        btn_next.config(command=_next_month)
        _render_month()

    def select_image(self, index):
        """Select image from filmstrip."""
        if 0 <= index < len(self.images):
            # Update border on thumbnails
            for i, lbl in enumerate(self.thumb_labels):
                if i == index:
                    lbl.configure(highlightthickness=2, highlightbackground='#FFB347')
                else:
                    lbl.configure(highlightthickness=0)

            self.current_index = index
            # Reset crop and rotation on image change
            self.crop_x = 50
            self.crop_y = 50
            self.rotation = 0
            if hasattr(self, 'rotation_var'):
                self.rotation_var.set(0)

            # Auto-swap orientation to match image if alt template available
            if self.has_alt_orientation:
                try:
                    img = Image.open(self.images[index])
                    img_w, img_h = img.size
                    img.close()
                    img_is_portrait = img_h > img_w
                    card_is_portrait = self.card_height > self.card_width
                    if img_is_portrait != card_is_portrait:
                        self.swap_orientation()
                        return  # swap_orientation calls update_preview
                except Exception:
                    pass

            self.update_preview()

    def _icc_to_srgb(self, img):
        """Convert image from embedded ICC profile to sRGB for display.
        If no profile is embedded, assume sRGB (no conversion needed)."""
        src_icc = img.info.get('icc_profile')
        if not src_icc or img.mode not in ('RGB', 'CMYK'):
            return img
        try:
            src_prof = ImageCms.ImageCmsProfile(_io.BytesIO(src_icc))
            if img.mode == 'CMYK':
                img = ImageCms.profileToProfile(
                    img, src_prof, _SRGB_PROFILE,
                    renderingIntent=ImageCms.Intent.PERCEPTUAL,
                    outputMode='RGB'
                )
            else:
                prof_desc = ImageCms.getProfileDescription(src_prof).strip()
                if prof_desc and 'srgb' not in prof_desc.lower():
                    img = ImageCms.profileToProfile(
                        img, src_prof, _SRGB_PROFILE,
                        renderingIntent=ImageCms.Intent.PERCEPTUAL,
                        outputMode='RGB'
                    )
        except Exception:
            pass  # on failure, display as-is
        return img

    def update_preview(self):
        """Update the preview canvas with current image and crop."""
        if not self.images:
            return

        try:
            # Load current image (never rotated — rotation is applied to the crop border)
            img_path = self.images[self.current_index]
            img = Image.open(img_path)

            # Store original dimensions
            orig_w, orig_h = img.size

            # Calculate display scaling to fit preview area
            display_scale = min(self.preview_w / orig_w, self.preview_h / orig_h)
            display_w = int(orig_w * display_scale)
            display_h = int(orig_h * display_scale)

            # Center image in preview
            self.img_x = (self.preview_w - display_w) // 2
            self.img_y = (self.preview_h - display_h) // 2
            self.img_display_w = display_w
            self.img_display_h = display_h
            self.display_scale = display_scale

            # Resize for display
            display_img = img.resize((display_w, display_h), Image.Resampling.LANCZOS)
            self.current_photo = ImageTk.PhotoImage(display_img)

            # Clear canvas
            self.preview_canvas.delete('all')

            # Draw image
            self.preview_canvas.create_image(self.img_x, self.img_y,
                                            anchor='nw', image=self.current_photo)

            # Calculate crop rectangle
            zoom_factor = self.zoom / 100.0

            # Base crop size at zoom=100 (largest area matching card ratio)
            orig_ratio = orig_w / orig_h
            if orig_ratio >= self.card_ratio:
                # Image wider than card - constrain by height
                base_crop_h = orig_h
                base_crop_w = base_crop_h * self.card_ratio
            else:
                # Image taller than card - constrain by width
                base_crop_w = orig_w
                base_crop_h = base_crop_w / self.card_ratio

            # Apply zoom
            crop_w = base_crop_w / zoom_factor
            crop_h = base_crop_h / zoom_factor

            # Calculate position
            max_offset_x = orig_w - crop_w
            max_offset_y = orig_h - crop_h
            crop_left = max_offset_x * (self.crop_x / 100.0)
            crop_top = max_offset_y * (self.crop_y / 100.0)

            # ── Rotation: shrink crop so the rotated border stays inside the image ──
            if self.rotation != 0:
                angle_rad = math.radians(abs(self.rotation))
                cos_a = math.cos(angle_rad)
                sin_a = math.sin(angle_rad)

                # Crop centre in image coordinates
                crop_cx = crop_left + crop_w / 2
                crop_cy = crop_top + crop_h / 2

                # Half-dimensions of the (unscaled) rotated crop bounding box
                hw = crop_w / 2
                hh = crop_h / 2
                bbox_hw = hw * cos_a + hh * sin_a
                bbox_hh = hw * sin_a + hh * cos_a

                # Space available from centre to each image edge
                space_x = min(crop_cx, orig_w - crop_cx)
                space_y = min(crop_cy, orig_h - crop_cy)

                # Scale down so the rotated bounding box fits
                rot_scale = 1.0
                if bbox_hw > 0:
                    rot_scale = min(rot_scale, space_x / bbox_hw)
                if bbox_hh > 0:
                    rot_scale = min(rot_scale, space_y / bbox_hh)

                crop_w *= rot_scale
                crop_h *= rot_scale
                # Keep centre unchanged
                crop_left = crop_cx - crop_w / 2
                crop_top = crop_cy - crop_h / 2

            # Convert to display coordinates
            rect_x1 = self.img_x + int(crop_left * display_scale)
            rect_y1 = self.img_y + int(crop_top * display_scale)
            rect_x2 = rect_x1 + int(crop_w * display_scale)
            rect_y2 = rect_y1 + int(crop_h * display_scale)

            # Store crop rect for hit testing (axis-aligned bounding box)
            self.crop_rect = (rect_x1, rect_y1, rect_x2, rect_y2)

            # Draw crop border (rotated polygon when rotation is active)
            if self.rotation != 0:
                cx_d = (rect_x1 + rect_x2) / 2
                cy_d = (rect_y1 + rect_y2) / 2
                dhw = (rect_x2 - rect_x1) / 2
                dhh = (rect_y2 - rect_y1) / 2
                r = math.radians(self.rotation)
                cos_r = math.cos(r)
                sin_r = math.sin(r)
                corners = [
                    (cx_d - dhw * cos_r + dhh * sin_r, cy_d - dhw * sin_r - dhh * cos_r),
                    (cx_d + dhw * cos_r + dhh * sin_r, cy_d + dhw * sin_r - dhh * cos_r),
                    (cx_d + dhw * cos_r - dhh * sin_r, cy_d + dhw * sin_r + dhh * cos_r),
                    (cx_d - dhw * cos_r - dhh * sin_r, cy_d - dhw * sin_r + dhh * cos_r),
                ]
                self.preview_canvas.create_polygon(
                    *[c for pt in corners for c in pt],
                    outline='white', fill='', width=3)
            else:
                self.preview_canvas.create_rectangle(rect_x1, rect_y1, rect_x2, rect_y2,
                                                     outline='white', width=3)

            # Draw sticker if selected
            self.sticker_rect = None
            if self.sticker_image:
                crop_display_w = rect_x2 - rect_x1
                crop_display_h = rect_y2 - rect_y1

                # Scale sticker based on sticker_zoom (percentage of crop width)
                sticker_w = int(crop_display_w * self.sticker_zoom / 100)
                # Maintain aspect ratio
                sticker_ratio = self.sticker_image.width / self.sticker_image.height
                sticker_h = int(sticker_w / sticker_ratio)

                # Sticker position in card-relative coords (centre of sticker area)
                rel_sx = (self.sticker_x / 100.0)
                rel_sy = (self.sticker_y / 100.0)
                max_sx = crop_display_w - sticker_w
                max_sy = crop_display_h - sticker_h

                if self.rotation != 0:
                    # Position sticker inside the rotated crop frame
                    # Offset from crop centre in card (de-rotated) space
                    off_x = -crop_display_w / 2 + sticker_w / 2 + max_sx * rel_sx
                    off_y = -crop_display_h / 2 + sticker_h / 2 + max_sy * rel_sy
                    # Rotate offset into canvas space
                    r = math.radians(self.rotation)
                    cos_r = math.cos(r)
                    sin_r = math.sin(r)
                    cx_d = (rect_x1 + rect_x2) / 2
                    cy_d = (rect_y1 + rect_y2) / 2
                    sticker_px = int(cx_d + off_x * cos_r - off_y * sin_r - sticker_w / 2)
                    sticker_py = int(cy_d + off_x * sin_r + off_y * cos_r - sticker_h / 2)

                    # Rotate sticker image to match crop rotation
                    resized_sticker = self.sticker_image.resize((sticker_w, sticker_h), Image.Resampling.LANCZOS)
                    rotated_stk = resized_sticker.rotate(-self.rotation,
                                                         resample=Image.Resampling.BICUBIC,
                                                         expand=True)
                    # Adjust anchor for expanded size
                    sticker_px -= (rotated_stk.width - sticker_w) // 2
                    sticker_py -= (rotated_stk.height - sticker_h) // 2
                    self.sticker_photo = ImageTk.PhotoImage(rotated_stk)
                    self.preview_canvas.create_image(sticker_px, sticker_py,
                                                    anchor='nw', image=self.sticker_photo)
                    self.sticker_rect = (rect_x1, rect_y1, rect_x2, rect_y2)  # use crop rect for hit
                else:
                    sticker_px = rect_x1 + int(max_sx * rel_sx)
                    sticker_py = rect_y1 + int(max_sy * rel_sy)

                    # Resize and draw sticker
                    resized_sticker = self.sticker_image.resize((sticker_w, sticker_h), Image.Resampling.LANCZOS)
                    self.sticker_photo = ImageTk.PhotoImage(resized_sticker)
                    self.preview_canvas.create_image(sticker_px, sticker_py,
                                                    anchor='nw', image=self.sticker_photo)
                    self.sticker_rect = (sticker_px, sticker_py,
                                         sticker_px + sticker_w, sticker_py + sticker_h)

        except Exception as e:
            print(f"Error updating preview: {e}")

    def on_zoom_change(self, value):
        """Handle zoom slider change."""
        self.zoom = int(float(value))
        self.update_preview()

    def on_rotation_change(self, value):
        """Handle rotation slider change."""
        self.rotation = int(float(value))
        self.update_preview()

    def _reset_rotation(self):
        """Reset rotation to 0 degrees."""
        self.rotation = 0
        self.rotation_var.set(0)
        self.update_preview()

    def _reset_sliders(self):
        """Reset zoom and rotation sliders to defaults."""
        self.zoom = 100
        self.zoom_var.set(100)
        self.rotation = 0
        self.rotation_var.set(0)
        self.crop_x = 50
        self.crop_y = 50
        self.update_preview()

    def browse_image(self):
        """Open a file dialog to select an image from disc, add it to the filmstrip, and display it."""
        from tkinter import filedialog

        # Determine initial directory: album folder, then PSA parent dir, then image_folder
        initial_dir = ''
        if self.album_folder and os.path.isdir(self.album_folder):
            initial_dir = self.album_folder
        elif self.psa_path and os.path.isdir(os.path.dirname(self.psa_path)):
            initial_dir = os.path.dirname(self.psa_path)
        elif self.image_folder and os.path.isdir(self.image_folder):
            initial_dir = self.image_folder

        file_path = filedialog.askopenfilename(
            parent=self.root,
            title="Select Image",
            initialdir=initial_dir,
            filetypes=[
                ("Image files", "*.jpg *.jpeg *.png *.tif *.tiff *.bmp"),
                ("JPEG", "*.jpg *.jpeg"),
                ("PNG", "*.png"),
                ("TIFF", "*.tif *.tiff"),
                ("All files", "*.*")
            ]
        )

        if not file_path:
            return  # User cancelled

        file_path = os.path.normpath(file_path)

        # Check if this image is already in the filmstrip
        for i, existing in enumerate(self.images):
            if os.path.normpath(existing) == file_path:
                self.select_image(i)
                # Scroll filmstrip to show selected thumbnail
                if self.thumb_labels:
                    total = len(self.thumb_labels)
                    if total > 1:
                        fraction = max(0.0, (i - 1) / total)
                        self.film_canvas.xview_moveto(fraction)
                return

        # Add new image to the list and filmstrip
        try:
            img = Image.open(file_path)
            ratio = 100 / img.height
            new_w = int(img.width * ratio)
            thumb = img.resize((new_w, 100), Image.Resampling.LANCZOS)
            photo = ImageTk.PhotoImage(thumb)
            self.thumb_images.append(photo)

            new_index = len(self.images)
            self.images.append(file_path)

            lbl = tk.Label(self.film_inner, image=photo, bg='#000000',
                          cursor='hand2', borderwidth=2, relief='flat')
            lbl.pack(side='left', padx=3, pady=5)
            lbl.bind('<Button-1>', lambda e, idx=new_index: self.select_image(idx))
            self.thumb_labels.append(lbl)

            # Update scroll region and scroll to end
            self.film_inner.update_idletasks()
            self.film_canvas.configure(scrollregion=self.film_canvas.bbox('all'))
            self.film_canvas.xview_moveto(1.0)

            # Select the newly added image
            self.select_image(new_index)
        except Exception as e:
            from tkinter import messagebox
            messagebox.showerror("Error", f"Could not load image:\n{e}", parent=self.root)

    def swap_orientation(self):
        """Swap between landscape and portrait crop orientation using the alternate template."""
        if not self.has_alt_orientation:
            return

        # Swap primary and alternate template/dimensions
        self.template_id, self.alt_template_id = self.alt_template_id, self.template_id
        self.card_width, self.alt_card_width = self.alt_card_width, self.card_width
        self.card_height, self.alt_card_height = self.alt_card_height, self.card_height
        self.card_ratio = self.card_width / self.card_height

        # Update the Card Details labels in the recipient panel
        orient = "Landscape" if self.card_width > self.card_height else "Portrait"
        if hasattr(self, 'card_size_label'):
            self.card_size_label.configure(text=f"Size: {self.card_width}x{self.card_height}px ({orient})")
        # Update template name to reflect the swapped orientation
        if hasattr(self, 'template_name_label'):
            # Derive name: swap Landscape<->Portrait in the media name
            name = self.media_name
            if orient == "Portrait" and "Landscape" in name:
                name = name.replace("Landscape", "Portrait")
            elif orient == "Landscape" and "Portrait" in name:
                name = name.replace("Portrait", "Landscape")
            # Update dimensions in parentheses if present, e.g. (2913x2125px)
            name = _re.sub(r'\(\d+x\d+px\)', f'({self.card_width}x{self.card_height}px)', name)
            self.template_name_label.configure(text=f"Template: {name}")

        # Reset crop position on orientation change for a clean view
        self.crop_x = 50
        self.crop_y = 50
        self.update_preview()

    def on_sticker_change(self, event):
        """Handle sticker selection change."""
        selection = self.sticker_var.get()
        if selection == "Open Folder...":
            # Revert dropdown to previous value
            self.sticker_var.set(self.sticker_name)
            if self.sticker_folder and os.path.exists(self.sticker_folder):
                subprocess.Popen(['explorer', self.sticker_folder])
            return
        self.sticker_name = selection
        if selection == "None":
            self.sticker_path = None
            self.sticker_image = None
        else:
            self.sticker_path = os.path.join(self.sticker_folder, selection)
            try:
                self.sticker_image = Image.open(self.sticker_path)
            except Exception as e:
                print(f"Error loading sticker: {e}")
                self.sticker_image = None
        self._save_sticker_prefs()
        self.update_preview()

    def on_sticker_zoom_change(self, value):
        """Handle sticker size slider change."""
        self.sticker_zoom = int(float(value))
        self._save_sticker_prefs()
        self.update_preview()

    def on_mouse_down(self, event):
        """Handle mouse button press."""
        # Check if click is on sticker first (sticker takes priority)
        if hasattr(self, 'sticker_rect') and self.sticker_rect:
            sx1, sy1, sx2, sy2 = self.sticker_rect
            if sx1 <= event.x <= sx2 and sy1 <= event.y <= sy2:
                self.sticker_dragging = True
                self.sticker_drag_offset_x = event.x - sx1
                self.sticker_drag_offset_y = event.y - sy1
                return

        # Check if click is inside crop rectangle
        if hasattr(self, 'crop_rect'):
            x1, y1, x2, y2 = self.crop_rect
            if x1 <= event.x <= x2 and y1 <= event.y <= y2:
                self.dragging = True
                self.drag_start_x = event.x
                self.drag_start_y = event.y
                self.drag_start_crop_x = self.crop_x
                self.drag_start_crop_y = self.crop_y

    def on_mouse_drag(self, event):
        """Handle mouse drag."""
        # Handle sticker drag
        if self.sticker_dragging and hasattr(self, 'crop_rect'):
            x1, y1, x2, y2 = self.crop_rect
            crop_w = x2 - x1
            crop_h = y2 - y1

            # Calculate new sticker position
            new_x = event.x - self.sticker_drag_offset_x
            new_y = event.y - self.sticker_drag_offset_y

            # Get sticker size
            if self.sticker_rect:
                sticker_w = self.sticker_rect[2] - self.sticker_rect[0]
                sticker_h = self.sticker_rect[3] - self.sticker_rect[1]

                # Convert to percentage within crop area
                max_x = crop_w - sticker_w
                max_y = crop_h - sticker_h
                if max_x > 0:
                    self.sticker_x = max(0, min(100, ((new_x - x1) / max_x) * 100))
                if max_y > 0:
                    self.sticker_y = max(0, min(100, ((new_y - y1) / max_y) * 100))

                self.update_preview()
            return

        if self.dragging:
            # Calculate delta in pixels
            dx = event.x - self.drag_start_x
            dy = event.y - self.drag_start_y

            # Convert to percentage change (invert for natural feel)
            # Approximate: moving mouse across display should move crop across image
            pct_x = (dx / self.img_display_w) * 100 * (self.zoom / 100)
            pct_y = (dy / self.img_display_h) * 100 * (self.zoom / 100)

            # Update crop position (clamp to 0-100)
            self.crop_x = max(0, min(100, self.drag_start_crop_x + pct_x))
            self.crop_y = max(0, min(100, self.drag_start_crop_y + pct_y))

            self.update_preview()

    def on_mouse_up(self, event):
        """Handle mouse button release."""
        if self.sticker_dragging:
            self._save_sticker_prefs()
        self.dragging = False
        self.sticker_dragging = False

    def get_hires_image_path(self, display_path: str) -> str:
        """Get high-res version of the image for card printing.

        Resolution priority:
        1. PSA source paths — original full-res files on disk (from ImageList sourceFolders).
        2. XML Original_Image paths — from order export XML.
        3. TIF version in the same folder.
        4. BigImages from PSA — ProSelect's embedded ~1280px working images.
        5. Fall back to the thumbnail already being displayed.
        """
        filename = os.path.basename(display_path)
        base_name = os.path.splitext(filename)[0]

        # 1. Check PSA source paths (originals on disk, resolved with drive-letter handling)
        if hasattr(self, '_psa_source_paths') and self._psa_source_paths:
            for name, orig_path in self._psa_source_paths.items():
                orig_base = os.path.splitext(name)[0]
                if orig_base == base_name:
                    return orig_path

        # 2. Check XML original image paths (from PSA+XML extraction mode)
        if hasattr(self, '_original_image_paths'):
            for name, orig_path in self._original_image_paths.items():
                orig_base = os.path.splitext(name)[0]
                if orig_base == base_name and os.path.exists(orig_path):
                    return orig_path

        # 3. Check if there's a TIF version in the same folder
        folder = Path(display_path).parent
        for ext in ['.tif', '.tiff']:
            tif_path = folder / (base_name + ext)
            if tif_path.exists():
                return str(tif_path)

        # 4. Try BigImages from PSA (~300KB working images, much better than 21KB thumbs)
        big_path = self._extract_bigimage_for(base_name)
        if big_path:
            return big_path

        # 5. Fall back to the displayed thumbnail
        return display_path

    def _extract_bigimage_for(self, base_name: str) -> str | None:
        """Extract a single image from BigImages table as a fallback.

        BigImages contains ProSelect's working-resolution images (~1280px),
        much higher quality than the 21KB type-1 thumbnails.
        Returns path to extracted file, or None.
        """

        if not self.psa_path or not os.path.exists(self.psa_path):
            return None

        try:
            conn = sqlite3.connect(self.psa_path)
            cursor = conn.cursor()

            # Get ImageList to find album_id for this base_name
            cursor.execute('SELECT buffer FROM BigStrings WHERE buffCode="ImageList"')
            row = cursor.fetchone()
            if not row:
                conn.close()
                return None

            image_data = row[0]
            if isinstance(image_data, bytes):
                image_data = image_data.decode('utf-8', errors='replace')

            album_id = None
            img_root = ET.fromstring(image_data)
            for img_el in img_root.iter('image'):
                name = img_el.get('name')
                if not name:
                    continue
                if os.path.splitext(name)[0] == base_name:
                    ai_el = img_el.find('albumimage')
                    if ai_el is not None and ai_el.get('id') is not None:
                        album_id = int(ai_el.get('id'))
                        break

            if album_id is None:
                conn.close()
                return None

            cursor.execute('SELECT imageData FROM BigImages WHERE id = ?', (album_id,))
            img_row = cursor.fetchone()
            conn.close()

            if not img_row or not img_row[0]:
                return None

            # Write to temp dir
            temp_dir = os.path.join(tempfile.gettempdir(), 'sidekick_ps_cardly_hires')
            os.makedirs(temp_dir, exist_ok=True)
            out_path = os.path.join(temp_dir, f"{base_name}.jpg")
            with open(out_path, 'wb') as f:
                f.write(img_row[0])
            print(f"Extracted BigImage for {base_name} ({len(img_row[0]) // 1024}KB)")
            return out_path

        except Exception as e:
            print(f"Error extracting BigImage for {base_name}: {e}")
            return None

    def show_progress(self, title: str = "Processing...", message: str = "Please wait...") -> tk.Toplevel:
        """Show a progress dialog with a spinning animation."""
        import math

        progress_win = tk.Toplevel(self.root)
        _set_window_icon(progress_win)
        progress_win.title(title)
        progress_win.configure(bg='#1a1a1a')
        progress_win.resizable(False, False)
        progress_win.overrideredirect(False)

        # Disable close button
        progress_win.protocol("WM_DELETE_WINDOW", lambda: None)

        tk.Label(progress_win, text=message, font=('Segoe UI', 11),
                fg='white', bg='#1a1a1a').pack(padx=30, pady=(20, 10))

        # Spinning dots animation on canvas
        canvas_size = 40
        spinner = tk.Canvas(progress_win, width=canvas_size, height=canvas_size,
                           bg='#1a1a1a', highlightthickness=0)
        spinner.pack(pady=(0, 5))

        num_dots = 8
        radius = 14
        dot_radius_max = 4
        cx, cy = canvas_size // 2, canvas_size // 2
        spinner._dots = []
        spinner._step = 0
        spinner._running = True

        for i in range(num_dots):
            angle = 2 * math.pi * i / num_dots - math.pi / 2
            x = cx + radius * math.cos(angle)
            y = cy + radius * math.sin(angle)
            dot = spinner.create_oval(x - 2, y - 2, x + 2, y + 2, fill='#555555', outline='')
            spinner._dots.append((dot, x, y))

        def animate():
            if not spinner._running:
                return
            step = spinner._step % num_dots
            for i, (dot, x, y) in enumerate(spinner._dots):
                offset = (step - i) % num_dots
                if offset < 3:
                    brightness = max(80, 255 - offset * 80)
                    r = dot_radius_max - offset * 0.5
                else:
                    brightness = 80
                    r = 2
                color = f'#{brightness:02x}{brightness:02x}{brightness:02x}'
                spinner.coords(dot, x - r, y - r, x + r, y + r)
                spinner.itemconfig(dot, fill=color)
            spinner._step += 1
            spinner.after(100, animate)

        animate()

        self.progress_label = tk.Label(progress_win, text="", font=('Segoe UI', 9),
                                       fg='silver', bg='#1a1a1a')
        self.progress_label.pack(pady=(0, 20))

        # Center window on ProSelect
        progress_win.update_idletasks()
        w = progress_win.winfo_width()
        h = progress_win.winfo_height()
        x, y = self._center_on_ps(progress_win, w, h)
        progress_win.geometry(f"+{x}+{y}")

        progress_win.update()
        progress_win._spinner = spinner  # keep reference
        return progress_win

    def update_progress(self, progress_win, message):
        """Update progress dialog message."""
        if hasattr(self, 'progress_label'):
            self.progress_label.config(text=message)
        progress_win.update()

    def close_progress(self, progress_win):
        """Stop spinner animation and destroy progress window."""
        if hasattr(progress_win, '_spinner') and hasattr(progress_win._spinner, '_running'):
            progress_win._spinner._running = False
        try:
            progress_win.destroy()
        except Exception:
            pass

    def post_card(self):
        """Send the card via Cardly API (threaded to keep spinner alive)."""
        if not self.images:
            messagebox.showerror("Error", "No image selected")
            return

        # Get message (must read from main thread)
        message = self.message_text.get('1.0', 'end-1c').strip()

        # Disable button and show progress popup
        self.post_btn.config(state='disabled')
        progress_win = self.show_progress("Sending Card...", "Preparing image...")

        # --- Pre-validation on main thread (needs user interaction) ---
        try:
            display_path = self.images[self.current_index]
            hires_path = self.get_hires_image_path(display_path)

            if hires_path != display_path:
                print(f"Using hi-res image: {hires_path}")
            else:
                print(f"Using original image (hi-res not found): {display_path}")

            # Check source image dimensions vs Cardly requirements
            try:
                with Image.open(hires_path) as src_img:
                    src_w, src_h = src_img.size
                self._source_dimensions = (src_w, src_h)
                print(f"Source image: {src_w}x{src_h}, Card target: {self.card_width}x{self.card_height}")
                w_pct = (src_w / self.card_width * 100) if self.card_width else 100
                h_pct = (src_h / self.card_height * 100) if self.card_height else 100
                min_pct = min(w_pct, h_pct)
                if min_pct < 70:
                    warn_msg = (
                        f"\u26a0\ufe0f  LOW RESOLUTION WARNING\n\n"
                        f"Source image: {src_w} x {src_h} pixels\n"
                        f"Card requires: {self.card_width} x {self.card_height} pixels\n"
                        f"Coverage: {min_pct:.0f}%\n\n"
                        f"The source image is less than 70% of the required\n"
                        f"card dimensions. The printed card may appear\n"
                        f"pixelated or blurry.\n\n"
                        f"Continue anyway?"
                    )
                    if not messagebox.askyesno("Low Resolution", warn_msg, icon='warning'):
                        self.close_progress(progress_win)
                        self.post_btn.config(state='normal', text="Send Card")
                        return
            except Exception as e:
                print(f"Could not check source dimensions: {e}")
                self._source_dimensions = None

            # Validate recipient before starting background work
            recipient = dict(self.recipient) if self.recipient else None
            recipient_source = self.recipient_source

            if not recipient or not recipient.get('name', '').strip():
                raise Exception(
                    "No client details found in the album.\n\n"
                    "Please enter the client's name and address in ProSelect\n"
                    "(Client Setup) and save the album, then try again.\n\n"
                    "A greeting card is a physical postcard \u2014 a postal address is required!"
                )

            # Remove internal tracking keys
            recipient.pop('_source', None)
            recipient.pop('email', None)
            recipient.pop('phone', None)

            # Validate required address fields
            missing = [k for k in ('name', 'address1', 'city', 'postcode')
                       if not recipient.get(k, '').strip()]
            if missing:
                raise Exception(
                    f"Recipient address is incomplete (source: {recipient_source}).\n\n"
                    f"Missing: {', '.join(missing)}\n\n"
                    f"A greeting card is a physical postcard \u2014 a full postal address is required!\n"
                    f"Please update the client's address in ProSelect (Client Setup) and save."
                )

        except Exception as e:
            self.close_progress(progress_win)
            self.post_btn.config(state='normal', text="Send Card")
            messagebox.showerror("Error", str(e))
            return

        # --- Launch background thread for all blocking work ---
        self._post_queue = _queue.Queue()
        self._post_progress_win = progress_win
        worker = threading.Thread(
            target=self._post_card_worker,
            args=(hires_path, display_path, message, recipient, recipient_source),
            daemon=True
        )
        worker.start()
        self.root.after(50, self._poll_post_card)

    def _post_card_worker(self, hires_path, display_path, message, recipient, recipient_source):
        """Background worker for post_card — does all blocking I/O."""
        q = self._post_queue
        try:
            q.put(('status', 'Processing image...'))

            # Log sticker parameters
            print(f"[Cardly Send] sticker_path = {self.sticker_path}")
            print(f"[Cardly Send] sticker_x={self.sticker_x}  sticker_y={self.sticker_y}  "
                  f"sticker_zoom={self.sticker_zoom}")

            processed_path = resize_image_for_cardly(
                hires_path,
                crop_x=int(self.crop_x),
                crop_y=int(self.crop_y),
                zoom=self.zoom,
                sticker_path=self.sticker_path,
                sticker_x=int(self.sticker_x),
                sticker_y=int(self.sticker_y),
                sticker_zoom=self.sticker_zoom,
                card_width=self.card_width,
                card_height=self.card_height,
                rotation=self.rotation
            )

            # Save a proof copy
            if processed_path and os.path.exists(processed_path) and self.postcard_folder:
                try:
                    proof_dir = os.path.join(self.postcard_folder, "_proof")
                    os.makedirs(proof_dir, exist_ok=True)
                    proof_name = os.path.splitext(os.path.basename(display_path))[0]
                    proof_path = os.path.join(proof_dir, f"{proof_name}_cardly_artwork.png")
                    import shutil
                    shutil.copy2(processed_path, proof_path)
                    print(f"[Cardly Send] Proof saved: {proof_path}")
                except Exception as e:
                    print(f"[Cardly Send] Could not save proof copy: {e}")

            q.put(('status', 'Preparing to send...'))

            print(f"Using recipient from {recipient_source}: [redacted]")

            # Create artwork — pass current template_id as media override
            # (after orientation swap, self.template_id holds the alternate template)
            q.put(('status', 'Uploading artwork to Cardly...'))
            artwork_result = create_cardly_artwork(processed_path, media_id_override=self.template_id)
            if not artwork_result.get('success'):
                raise Exception(f"Failed to create artwork: {artwork_result.get('error')}")

            artwork_id = artwork_result.get('artwork_id')

            # Place order (skip in test mode)
            if self.test_mode:
                q.put(('status', 'TEST MODE \u2014 skipping order...'))
            else:
                q.put(('status', 'Placing order...'))
                order_result = place_cardly_order(
                    artwork_id,
                    recipient,
                    message=message,
                    first_name=self.first_name,
                    template_id=self.template_id,
                    requested_arrival=self.requested_arrival
                )
                if not order_result.get('success'):
                    raise Exception(f"Failed to place order: {order_result.get('error')}")

            # --- Post-send: save JPG to postcard folder & upload to GHL ---
            q.put(('status', 'Saving postcard...'))
            try:
                clean_path = resize_image_for_cardly(
                    hires_path,
                    crop_x=int(self.crop_x),
                    crop_y=int(self.crop_y),
                    zoom=self.zoom,
                    sticker_path=None,
                    sticker_x=0,
                    sticker_y=0,
                    sticker_zoom=0,
                    card_width=self.card_width,
                    card_height=self.card_height,
                    rotation=self.rotation
                )

                from PIL import Image as _PILImg
                clean_img = _PILImg.open(clean_path)
                orig_name = os.path.splitext(os.path.basename(display_path))[0]
                jpg_path = os.path.join(os.path.dirname(clean_path), f"{orig_name}_postcard.jpg")
                clean_img.convert('RGB').save(jpg_path, 'JPEG', quality=95, optimize=True)

                if self.postcard_folder and os.path.isdir(self.postcard_folder):
                    dest = os.path.join(self.postcard_folder, f"{orig_name}_postcard.jpg")
                    shutil.copy2(jpg_path, dest)
                    print(f"Postcard JPG saved to: {dest}")

                if self.save_to_album and self.album_folder:
                    album_save_result = save_to_album_folder(
                        clean_path,
                        display_path,
                        self.album_folder
                    )
                    if album_save_result.get('success'):
                        print(f"Postcard copy saved to album: {album_save_result.get('path')}")
                    else:
                        print(f"Album save warning: {album_save_result.get('error')}")

                if self.ghl_media_folder_id:
                    q.put(('status', 'Uploading to GHL...'))
                    ghl_result = upload_to_ghl_photos(jpg_path, self.contact_id, self.ghl_media_folder_id)
                    if ghl_result.get('success'):
                        uploaded_url = ghl_result.get('url', '')
                        print(f"Uploaded postcard to GHL media: {uploaded_url}")
                        if uploaded_url and self.photo_link_field:
                            field_result = update_ghl_contact_field(
                                self.contact_id, self.photo_link_field, uploaded_url
                            )
                            if field_result.get('success'):
                                print(f"Updated contact field '{self.photo_link_field}' with photo URL")
                            else:
                                print(f"Field update warning: {field_result.get('error')}")
                    else:
                        print(f"GHL upload warning: {ghl_result.get('error')}")
            except Exception as post_err:
                print(f"Post-send save/upload warning: {post_err}")

            # Signal success
            q.put(('done', None))

        except Exception as e:
            q.put(('error', str(e)))

    def _poll_post_card(self):
        """Poll the background worker queue to update progress UI."""
        try:
            while True:
                msg_type, msg_data = self._post_queue.get_nowait()
                if msg_type == 'status':
                    if hasattr(self, 'progress_label'):
                        self.progress_label.config(text=msg_data)
                elif msg_type == 'done':
                    self.close_progress(self._post_progress_win)
                    self.result = 0
                    self._show_success_dialog()
                    return
                elif msg_type == 'error':
                    self.close_progress(self._post_progress_win)
                    self.post_btn.config(state='normal', text="Send Card")
                    messagebox.showerror("Error", msg_data)
                    return
        except _queue.Empty:
            pass
        # Keep polling
        self.root.after(50, self._poll_post_card)

    def _show_success_dialog(self):
        """Show dark-themed success dialog after card is sent."""
        success_win = tk.Toplevel(self.root)
        _set_window_icon(success_win)
        success_win.title("Success")
        success_win.configure(bg='#1a1a1a')
        success_win.resizable(False, False)
        success_win.protocol("WM_DELETE_WINDOW", lambda: None)
        tk.Label(success_win, text="\u2705", font=('Segoe UI', 32),
                fg='#4CAF50', bg='#1a1a1a').pack(pady=(20, 5))
        success_msg = (f"TEST MODE \u2014 artwork uploaded for {self.first_name}\n(order not placed)"
                      if self.test_mode
                      else f"Card sent successfully to {self.first_name}!")
        tk.Label(success_win, text=success_msg,
                font=('Segoe UI', 11), fg='white', bg='#1a1a1a').pack(padx=30, pady=(0, 15))
        tk.Button(success_win, text="OK", width=10, font=('Segoe UI', 10),
                 bg='#4CAF50', fg='white', activebackground='#5CBF60',
                 relief='flat', cursor='hand2',
                 command=success_win.destroy).pack(pady=(0, 20))
        success_win.update_idletasks()
        w = success_win.winfo_width()
        h = success_win.winfo_height()
        x, y = self._center_on_ps(success_win, w, h)
        success_win.geometry(f"+{x}+{y}")
        success_win.grab_set()
        success_win.wait_window()
        self.root.destroy()

    def cancel(self) -> None:
        """Cancel and close dialog."""
        self.result = 1
        self.root.destroy()

    def run(self) -> int:
        """Run the GUI main loop."""
        if not hasattr(self, 'root') or self.root is None:
            return self.result  # PSA not found — already warned user

        # Destroy splash and reveal the fully-built main window
        if hasattr(self, '_splash') and self._splash is not None:
            try:
                self._splash.destroy()
            except tk.TclError:
                pass
            self._splash = None

        # Center window on ProSelect
        self.root.update_idletasks()
        w = self.root.winfo_width()
        h = self.root.winfo_height()
        x, y = self._center_on_ps(self.root, w, h)
        self.root.geometry(f"+{x}+{y}")

        self.root.deiconify()  # Show the fully-built window

        # Check for pending cards on Cardly in background
        self._check_pending_cards_bg()

        # Highlight first thumbnail
        if self.thumb_labels:
            self.thumb_labels[0].configure(highlightthickness=2, highlightbackground='#FFB347')

        self.root.mainloop()
        return self.result


def main() -> None:
    """Main entry point for the GUI application."""
    import argparse

    parser = argparse.ArgumentParser(description="Cardly Preview GUI for SideKick_PS")
    parser.add_argument("image_folder", help="Path to image folder")
    parser.add_argument("contact_id", help="GHL contact ID")
    parser.add_argument("first_name", help="Client first name")
    parser.add_argument("message", help="Card message text")
    parser.add_argument("--template-id", default=None, help="Cardly template ID")
    parser.add_argument("--sticker-folder", default=None, help="Path to stickers folder")
    parser.add_argument("--card-width", default=None, help="Card width in pixels")
    parser.add_argument("--card-height", default=None, help="Card height in pixels")
    parser.add_argument("--media-name", default=None, help="GHL media name")
    parser.add_argument("--postcard-folder", default=None, help="Path to save postcard output")
    parser.add_argument("--ghl-media-folder-id", default=None, help="GHL media folder ID")
    parser.add_argument("--photo-link-field", default=None, help="GHL custom field for photo link")
    parser.add_argument("--psa", default=None, help="Path to .psa file (ProSelect album)")
    parser.add_argument("--xml", default=None, help="Path to ProSelect order export XML")
    parser.add_argument("--album-name", default=None, help="Album/shoot name for display")
    parser.add_argument("--test-mode", action="store_true", help="Test mode: upload artwork but skip placing order")
    parser.add_argument("--preselect-image", default=None, help="Filename of image to pre-select in filmstrip (from PSConsole getSelectedImageData)")
    parser.add_argument("--save-to-album", action="store_true", help="Save a copy of the postcard to the album folder")
    parser.add_argument("--album-folder", default=None, help="Album folder path to save postcard copy")
    parser.add_argument("--alt-template-id", default=None, help="Alternate orientation template ID (L\u2194P pair)")
    parser.add_argument("--alt-card-width", default=None, help="Alternate template card width in pixels")
    parser.add_argument("--alt-card-height", default=None, help="Alternate template card height in pixels")
    parser.add_argument("--ps-geometry", default=None, help="ProSelect window geometry as x,y,w,h for centering")

    args = parser.parse_args()

    # Parse ProSelect geometry if provided
    ps_geometry = None
    if args.ps_geometry:
        try:
            parts = [int(v) for v in args.ps_geometry.split(',')]
            if len(parts) == 4:
                ps_geometry = tuple(parts)
        except ValueError:
            pass

    if not os.path.exists(args.image_folder):
        print(f"Error: Image folder not found: {args.image_folder}")
        sys.exit(2)

    gui = CardPreviewGUI(
        args.image_folder, args.contact_id, args.first_name, args.message,
        args.template_id, args.sticker_folder, args.card_width, args.card_height,
        args.media_name, args.postcard_folder, args.ghl_media_folder_id,
        args.photo_link_field, psa_path=args.psa, xml_path=args.xml,
        album_name=args.album_name, test_mode=args.test_mode,
        preselect_image=args.preselect_image,
        save_to_album=args.save_to_album, album_folder=args.album_folder,
        alt_template_id=args.alt_template_id,
        alt_card_width=args.alt_card_width, alt_card_height=args.alt_card_height,
        ps_geometry=ps_geometry
    )
    result = gui.run()
    sys.exit(result)


if __name__ == "__main__":
    main()

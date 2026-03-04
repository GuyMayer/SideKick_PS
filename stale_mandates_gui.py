"""
Stale Mandates GUI (PySide6 / Qt6)
Copyright (c) 2026 GuyMayer. All rights reserved.
Unauthorized use, modification, or distribution is prohibited.

Displays GoCardless mandates where all payment plans have finished but the
Direct Debit mandate is still active.  Allows batch cancellation with
two-stage safety warnings.

Usage:
  python stale_mandates_gui.py --live
  stale_mandates_gui.exe --live

Launched from SideKick_PS via the "Stale Mandates" button in GoCardless settings.
"""

import sys
import os
import subprocess
import tempfile
import time
import argparse
import ctypes
import json
import base64
import urllib.request
import urllib.error
import urllib.parse
from datetime import datetime, timezone
from typing import List, Dict, Optional, Set

# ---------------------------------------------------------------------------
# PySide6 import with graceful fallback
# ---------------------------------------------------------------------------
try:
    from PySide6.QtWidgets import (
        QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
        QTableWidget, QTableWidgetItem, QHeaderView, QPushButton,
        QLabel, QMessageBox, QProgressBar, QCheckBox, QAbstractItemView,
        QStatusBar, QSpinBox, QGroupBox, QFrame, QLineEdit, QTabWidget,
        QComboBox,
    )
    from PySide6.QtCore import Qt, QThread, Signal, QTimer
    from PySide6.QtGui import QFont, QColor, QIcon
except ImportError:
    # When compiled with PyInstaller PySide6 is bundled; this catches dev-mode
    sys.stderr.write("ERROR|PySide6 is not installed. Run:  pip install PySide6\n")
    sys.exit(2)


# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
if getattr(sys, 'frozen', False):
    SCRIPT_DIR = os.path.dirname(sys.executable)
else:
    SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))


# ---------------------------------------------------------------------------
# Layout / behaviour constants (avoids magic-number warnings)
# ---------------------------------------------------------------------------
# Window geometry
_MIN_WIDTH = 950
_MIN_HEIGHT = 520
_DEFAULT_WIDTH = 1050
_DEFAULT_HEIGHT = 720
_MARGIN = (24, 20, 24, 16)       # left, top, right, bottom
_GHL_MARGIN = (24, 20, 24, 16)
_SPACING = 10
_GHL_SPACING = 12

# Stale-mandates table column widths  (✓, Last Pay, Collected, Customer, Email, Created)
_COL_CHECK = 40
_COL_LAST_PAY = 115
_COL_COLLECTED = 95
_COL_CUSTOMER = 180
_COL_EMAIL = 220
_COL_CREATED = 100
_TABLE_COLS = 7
_ROW_HEIGHT = 36

# Cancel-log table column widths
_CLOG_COL_TIME = 140
_CLOG_COL_MANDATE = 160
_CLOG_COL_ORIGIN = 100
_CLOG_COL_CAUSE = 150
_CLOG_MAX_HEIGHT = 180
_CLOG_COLS = 5
_CLOG_ROW_HEIGHT = 30

# Timer / spinner defaults
_POLL_MAX_MINUTES = 1440
_POLL_DEFAULT_MINUTES = 15
_SPIN_WIDTH = 100
_GHL_TAG_WIDTH = 200

# Fetch-worker constants
_PROGRESS_POLL_SECS = 0.3
_ERROR_TRUNCATE = 500
_PROGRESS_MIN_PARTS = 3
_OUTPUT_MIN_PARTS = 8

# Status-bar timeouts (ms)
_STATUS_SHORT = 3_000
_STATUS_LONG = 5_000
_STATUS_NOTIFY = 10_000

# Thread-wait timeouts (ms)
_WAIT_POLL = 3_000
_WAIT_GHL = 2_000
_WAIT_FETCH = 3_000
_WAIT_CANCEL = 5_000

# GHL settings tab
_GHL_LABEL_WIDTH = 90
_GHL_EYE_BTN_WIDTH = 36
_GHL_CONN_SPACING = 8

# Misc
_WIN_TITLE_BUF = 256
_MUTEX_ALREADY_EXISTS = 183
_POLL_ERROR_PREVIEW = 80


# ---------------------------------------------------------------------------
# Dark-theme stylesheet
# ---------------------------------------------------------------------------
DARK_STYLESHEET = """
/* ── Global ─────────────────────────────────────────────── */
QMainWindow, QWidget {
    background-color: #1e1e1e;
    color: #e0e0e0;
}

/* ── Table ──────────────────────────────────────────────── */
QTableWidget {
    background-color: #2d2d2d;
    alternate-background-color: #333333;
    color: #e0e0e0;
    gridline-color: #444444;
    border: 1px solid #555555;
    border-radius: 4px;
    font-size: 10pt;
    outline: none;
}
QTableWidget::item {
    padding: 4px 8px;
}
QTableWidget::item:selected {
    background-color: #3a6db5;
}
QHeaderView::section {
    background-color: #383838;
    color: #bbbbbb;
    padding: 8px 10px;
    border: none;
    border-bottom: 2px solid #555555;
    font-weight: bold;
    font-size: 10pt;
}

/* ── Buttons ────────────────────────────────────────────── */
QPushButton {
    background-color: #3d3d3d;
    color: #e0e0e0;
    border: 1px solid #555555;
    border-radius: 4px;
    padding: 8px 18px;
    font-size: 10pt;
    min-width: 80px;
}
QPushButton:hover {
    background-color: #4d4d4d;
    border-color: #777777;
}
QPushButton:pressed {
    background-color: #2d2d2d;
}
QPushButton:disabled {
    color: #666666;
    border-color: #444444;
}
QPushButton#cancelBtn {
    background-color: #6b2020;
    color: #ff8888;
    border-color: #883333;
    font-weight: bold;
}
QPushButton#cancelBtn:hover {
    background-color: #8b3030;
}
QPushButton#cancelBtn:disabled {
    background-color: #3d2020;
    color: #884444;
}

/* ── Labels ─────────────────────────────────────────────── */
QLabel {
    color: #cccccc;
    font-size: 11pt;
}
QLabel#header {
    color: #e0e0e0;
    font-size: 14pt;
    font-weight: bold;
}
QLabel#subheader {
    color: #999999;
    font-size: 10pt;
}

/* ── Progress bar ───────────────────────────────────────── */
QProgressBar {
    border: 1px solid #555555;
    border-radius: 4px;
    background-color: #2d2d2d;
    text-align: center;
    color: #e0e0e0;
    min-height: 22px;
    max-height: 22px;
}
QProgressBar::chunk {
    background-color: #4a9eff;
    border-radius: 3px;
}

/* ── Scrollbars ─────────────────────────────────────────── */
QScrollBar:vertical {
    background: #2d2d2d;
    width: 12px;
    margin: 0;
    border-radius: 6px;
}
QScrollBar::handle:vertical {
    background: #555555;
    min-height: 30px;
    border-radius: 6px;
}
QScrollBar::handle:vertical:hover {
    background: #666666;
}
QScrollBar::add-line:vertical,
QScrollBar::sub-line:vertical {
    height: 0;
}
QScrollBar::add-page:vertical,
QScrollBar::sub-page:vertical {
    background: none;
}
QScrollBar:horizontal {
    background: #2d2d2d;
    height: 12px;
    margin: 0;
    border-radius: 6px;
}
QScrollBar::handle:horizontal {
    background: #555555;
    min-width: 30px;
    border-radius: 6px;
}
QScrollBar::handle:horizontal:hover {
    background: #666666;
}
QScrollBar::add-line:horizontal,
QScrollBar::sub-line:horizontal {
    width: 0;
}
QScrollBar::add-page:horizontal,
QScrollBar::sub-page:horizontal {
    background: none;
}

/* ── Checkboxes (inside table cells) ────────────────────── */
QCheckBox {
    spacing: 0;
}
QCheckBox::indicator {
    width: 18px;
    height: 18px;
}
QCheckBox::indicator:unchecked {
    border: 2px solid #666666;
    background: #2d2d2d;
    border-radius: 3px;
}
QCheckBox::indicator:checked {
    border: 2px solid #4a9eff;
    background: #4a9eff;
    border-radius: 3px;
}
QCheckBox::indicator:unchecked:hover {
    border-color: #888888;
}
QCheckBox::indicator:disabled {
    border-color: #444444;
    background: #333333;
}

/* ── Status bar ─────────────────────────────────────────── */
QStatusBar {
    background-color: #1e1e1e;
    color: #999999;
    font-size: 9pt;
}

/* ── Message boxes ──────────────────────────────────────── */
QMessageBox {
    background-color: #1e1e1e;
}
QMessageBox QLabel {
    color: #e0e0e0;
    font-size: 10pt;
    background-color: #1e1e1e;
}
QMessageBox QPushButton {
    background-color: #3d3d3d;
    color: #e0e0e0;
    border: 1px solid #555555;
    border-radius: 4px;
    padding: 6px 16px;
    min-width: 70px;
}
QMessageBox QPushButton:hover {
    background-color: #4d4d4d;
}
QMessageBox QPushButton:pressed {
    background-color: #2d2d2d;
}

/* ── Group boxes ────────────────────────────────────────── */
QGroupBox {
    background-color: #262626;
    border: 1px solid #444444;
    border-radius: 6px;
    margin-top: 12px;
    padding: 16px 12px 10px 12px;
    font-size: 11pt;
    font-weight: bold;
    color: #cccccc;
}
QGroupBox::title {
    subcontrol-origin: margin;
    left: 14px;
    padding: 0 6px;
    color: #e0e0e0;
}

/* ── Spin boxes ─────────────────────────────────────────── */
QSpinBox {
    background-color: #2d2d2d;
    color: #e0e0e0;
    border: 1px solid #555555;
    border-radius: 4px;
    padding: 4px 8px;
    font-size: 10pt;
}
QSpinBox::up-button, QSpinBox::down-button {
    background-color: #3d3d3d;
    border: none;
    width: 16px;
}
QSpinBox::up-button:hover, QSpinBox::down-button:hover {
    background-color: #4d4d4d;
}

/* ── Line edits ─────────────────────────────────────────── */
QLineEdit {
    background-color: #2d2d2d;
    color: #e0e0e0;
    border: 1px solid #555555;
    border-radius: 4px;
    padding: 4px 8px;
    font-size: 10pt;
}
QLineEdit:disabled {
    color: #888888;
    background-color: #262626;
}

/* ── Frames (dividers) ──────────────────────────────────── */
QFrame[frameShape="4"] {
    color: #444444;
    max-height: 1px;
}

/* ── Tab widget ─────────────────────────────────────────── */
QTabWidget::pane {
    border: none;
    background-color: #1e1e1e;
}
QTabBar::tab {
    background-color: #2d2d2d;
    color: #bbbbbb;
    padding: 10px 22px;
    border: none;
    border-bottom: 2px solid transparent;
    font-size: 10pt;
    min-width: 140px;
}
QTabBar::tab:selected {
    color: #e0e0e0;
    border-bottom: 2px solid #4a9eff;
    background-color: #1e1e1e;
}
QTabBar::tab:hover {
    background-color: #383838;
}
"""


# ═══════════════════════════════════════════════════════════════════════════
# Helper – locate the gocardless_api companion script
# ═══════════════════════════════════════════════════════════════════════════

# Sentinel returned by _find_gc_script when the unified CLI is found.
_UNIFIED_CLI_TAG = '__unified_cli__'


def _find_gc_script() -> str:
    """Return the path to gocardless_api (.exe or .py) in SCRIPT_DIR.

    Checks (in order):
      1. Unified CLI  – SideKick_PS_CLI.exe  (ships since v3.x)
      2. Legacy individual exe/py files
    When the unified CLI is found the returned string is
    ``'<path>|__unified_cli__'`` so that ``_build_gc_command`` can
    insert the ``gocardless`` subcommand automatically.
    """
    # Prefer the unified CLI that replaced individual exes
    unified = os.path.join(SCRIPT_DIR, 'SideKick_PS_CLI.exe')
    if os.path.isfile(unified):
        return f'{unified}|{_UNIFIED_CLI_TAG}'

    # Legacy: individual exes / .py files
    for name in ('_gca.exe', 'gocardless_api.exe', '_gca.py', 'gocardless_api.py'):
        path = os.path.join(SCRIPT_DIR, name)
        if os.path.isfile(path):
            return path
    return ''


def _find_python() -> str:
    """Return a usable Python interpreter path."""
    if not getattr(sys, 'frozen', False):
        return sys.executable
    # When frozen, sys.executable is our own .exe — find real Python
    for candidate in ('python', 'python3', 'py'):
        try:
            r = subprocess.run(
                [candidate, '--version'],
                capture_output=True, timeout=5,
                creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0),
            )
            if r.returncode == 0:
                return candidate
        except Exception:
            continue
    return 'python'


def _build_gc_command(gc_script: str, args: list) -> list:
    """Build a command list for running gocardless_api.

    Handles three cases:
      - Unified CLI tag  → ``SideKick_PS_CLI.exe gocardless <args>``
      - Legacy .exe      → ``<exe> <args>``
      - Legacy .py       → ``python <script> <args>``
    """
    if _UNIFIED_CLI_TAG in gc_script:
        exe_path = gc_script.split('|')[0]
        return [exe_path, 'gocardless'] + args
    if gc_script.lower().endswith('.exe'):
        return [gc_script] + args
    return [_find_python(), gc_script] + args


# ═══════════════════════════════════════════════════════════════════════════
# Credential loading & direct API helpers
# ═══════════════════════════════════════════════════════════════════════════

def _load_credentials() -> Dict[str, str]:
    """Load GoCardless and GHL credentials from credentials.json."""
    result: Dict[str, str] = {
        'gc_token': '', 'ghl_api_key': '', 'location_id': '', 'environment': 'live',
    }
    credentials_paths = [
        os.path.join(SCRIPT_DIR, 'credentials.json'),
        os.path.join(os.environ.get('APPDATA', ''), 'SideKick_PS', 'credentials.json'),
        os.path.join(os.environ.get('APPDATA', ''), 'SideKick_GC', 'credentials.json'),
        os.path.join(os.environ.get('APPDATA', ''), 'SideKick_LB', 'credentials.json'),
    ]
    for cred_path in credentials_paths:
        if os.path.isfile(cred_path):
            try:
                with open(cred_path, 'r', encoding='utf-8-sig') as fh:
                    creds = json.load(fh)
                gc_b64 = creds.get('gc_token_b64', '')
                if gc_b64:
                    result['gc_token'] = base64.b64decode(gc_b64).decode('utf-8')
                ghl_b64 = creds.get('api_key_b64', '')
                if ghl_b64:
                    result['ghl_api_key'] = base64.b64decode(ghl_b64).decode('utf-8')
                result['location_id'] = creds.get('location_id', '')
                if result['gc_token']:
                    break
            except Exception:
                continue
    return result


def _gc_api_request(method: str, endpoint: str, token: str,
                    environment: str, timeout: int = 30) -> dict:
    """Direct GoCardless API request (no subprocess)."""
    base = ('https://api.gocardless.com' if environment == 'live'
            else 'https://api-sandbox.gocardless.com')
    url = base + endpoint
    headers = {
        'Authorization': f'Bearer {token}',
        'GoCardless-Version': '2015-07-06',
        'Content-Type': 'application/json',
    }
    try:
        req = urllib.request.Request(url, headers=headers, method=method)
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return json.loads(resp.read().decode('utf-8'))
    except urllib.error.HTTPError as exc:
        try:
            err_body = json.loads(exc.read().decode('utf-8'))
            msg = err_body.get('error', {}).get('message', str(exc))
        except Exception:
            msg = f"{exc.code} {exc.reason}"
        return {'error': msg}
    except Exception as exc:
        return {'error': str(exc)}


def _ghl_api_request(method: str, endpoint: str, api_key: str,
                     data: Optional[dict] = None, timeout: int = 15) -> dict:
    """Direct GoHighLevel API request."""
    url = 'https://services.leadconnectorhq.com' + endpoint
    headers = {
        'Authorization': f'Bearer {api_key}',
        'Content-Type': 'application/json',
        'Version': '2021-07-28',
        'User-Agent': 'SideKick_PS/2.5',
    }
    body = json.dumps(data).encode('utf-8') if data else None
    try:
        req = urllib.request.Request(url, data=body, headers=headers, method=method)
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return json.loads(resp.read().decode('utf-8'))
    except urllib.error.HTTPError as exc:
        try:
            err_body = json.loads(exc.read().decode('utf-8'))
            msg = err_body.get('message', str(exc))
        except Exception:
            msg = f"{exc.code} {exc.reason}"
        return {'error': msg}
    except Exception as exc:
        return {'error': str(exc)}


# ═══════════════════════════════════════════════════════════════════════════
# Worker threads
# ═══════════════════════════════════════════════════════════════════════════

class FetchWorker(QThread):
    """Fetch stale mandates in a background thread."""

    progress_updated = Signal(int, int, str)   # current, total, message
    finished = Signal(list)                    # list of mandate dicts
    error = Signal(str)

    def __init__(self, gc_script: str, environment: str):
        super().__init__()
        self.gc_script = gc_script
        self.environment = environment
        self.progress_file = os.path.join(
            tempfile.gettempdir(),
            f'gc_stale_progress_{os.getpid()}_{int(time.time())}.txt',
        )
        self._stop_flag = False

    # ── run ────────────────────────────────────────────────
    def run(self):
        """Fetch stale mandates via the companion CLI script."""
        try:
            cmd = _build_gc_command(self.gc_script, [
                '--list-stale-mandates',
                f'--{self.environment}',
                '--progress-file', self.progress_file,
            ])

            no_window = getattr(subprocess, 'CREATE_NO_WINDOW', 0)
            process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                creationflags=no_window,
            )

            # Poll progress file while waiting
            while process.poll() is None:
                if self._stop_flag:
                    process.kill()
                    return
                self._read_progress()
                time.sleep(_PROGRESS_POLL_SECS)

            stdout, stderr = process.communicate(timeout=10)

            # Clean up
            try:
                os.unlink(self.progress_file)
            except OSError:
                pass

            if process.returncode != 0 and not stdout.strip():
                self.error.emit(f"Script exited with code {process.returncode}: {stderr[:_ERROR_TRUNCATE]}")
                return

            self._parse_output(stdout)

        except Exception as exc:
            self.error.emit(str(exc))

    # ── helpers ────────────────────────────────────────────
    def _read_progress(self):
        try:
            if os.path.isfile(self.progress_file):
                with open(self.progress_file, 'r', encoding='utf-8') as fh:
                    data = fh.read().strip()
                if data:
                    parts = data.split('|')
                    if len(parts) >= _PROGRESS_MIN_PARTS:
                        self.progress_updated.emit(
                            int(parts[0]), int(parts[1]), parts[2],
                        )
        except Exception:
            pass

    def _parse_output(self, stdout: str):
        results: list = []
        for line in stdout.strip().splitlines():
            line = line.strip()
            if not line:
                continue
            if line == 'NO_STALE_MANDATES':
                self.finished.emit([])
                return
            if line.startswith('ERROR'):
                self.error.emit(line.replace('ERROR|', ''))
                return
            parts = line.split('|')
            if len(parts) >= _OUTPUT_MIN_PARTS:
                try:
                    total_pence = int(parts[7])
                except ValueError:
                    total_pence = 0
                idx_name = 2
                idx_email = 3
                idx_created = 4
                idx_bank = 5
                idx_last_pay = 6
                results.append({
                    'mandate_id':       parts[0],
                    'customer_id':      parts[1],
                    'customer_name':    parts[idx_name],
                    'email':            parts[idx_email],
                    'created_at':       parts[idx_created],
                    'bank_name':        parts[idx_bank],
                    'last_payment_date': parts[idx_last_pay],
                    'total_collected':  total_pence / 100,
                })
        self.finished.emit(results)

    def stop(self):
        """Signal the worker to stop."""
        self._stop_flag = True


class CancelWorker(QThread):
    """Cancel selected mandates one-by-one in background."""

    mandate_done = Signal(str, str, bool, str)  # id, name, success, error
    all_done = Signal(int, int)                 # success_count, fail_count

    def __init__(self, gc_script: str, environment: str, mandates: List[Dict]):
        super().__init__()
        self.gc_script = gc_script
        self.environment = environment
        self.mandates = mandates
        self._stop_flag = False

    def run(self):
        """Cancel each mandate sequentially, emitting progress signals."""
        success = 0
        fail = 0
        no_window = getattr(subprocess, 'CREATE_NO_WINDOW', 0)

        for m in self.mandates:
            if self._stop_flag:
                break
            mid = m['mandate_id']
            name = m['customer_name']
            try:
                cmd = _build_gc_command(self.gc_script, [
                    '--cancel-mandate', mid,
                    f'--{self.environment}',
                ])
                result = subprocess.run(
                    cmd, capture_output=True, text=True, timeout=30,
                    creationflags=no_window,
                )
                output = result.stdout.strip()
                if 'SUCCESS' in output:
                    success += 1
                    self.mandate_done.emit(mid, name, True, '')
                else:
                    fail += 1
                    err = output.replace('ERROR|', '') if 'ERROR' in output else output
                    self.mandate_done.emit(mid, name, False, err)
            except Exception as exc:
                fail += 1
                self.mandate_done.emit(mid, name, False, str(exc))

        self.all_done.emit(success, fail)


class PollCancelledWorker(QThread):
    """Poll GoCardless Events API for customer/bank-initiated mandate cancellations."""

    cancellation_found = Signal(list)   # list of cancellation event dicts
    poll_error = Signal(str)
    poll_done = Signal()

    def __init__(self, token: str, environment: str, since: str):
        super().__init__()
        self.token = token
        self.environment = environment
        self.since = since  # ISO datetime e.g. 2026-03-03T10:00:00Z

    def run(self):
        """Fetch mandate cancellation events since last poll."""
        try:
            endpoint = (
                '/events?resource_type=mandates&action=cancelled'
                f'&created_at%5Bgte%5D={self.since}'
            )
            resp = _gc_api_request('GET', endpoint, self.token, self.environment)

            if 'error' in resp:
                self.poll_error.emit(resp['error'])
                self.poll_done.emit()
                return

            events = resp.get('events', [])
            customer_cancellations: list = []

            for event in events:
                details = event.get('details', {})
                origin = details.get('origin', '')
                # 'customer' = customer cancelled at their bank
                # 'bank'     = bank revoked the mandate
                # 'api'      = we cancelled it (ignore)
                # 'gocardless' = platform cancelled (fraud etc.)
                if origin in ('bank', 'customer', 'gocardless'):
                    mandate_id = event.get('links', {}).get('mandate', '')
                    customer_cancellations.append({
                        'event_id': event.get('id', ''),
                        'mandate_id': mandate_id,
                        'origin': origin,
                        'cause': details.get('cause', ''),
                        'description': details.get('description', ''),
                        'created_at': event.get('created_at', ''),
                    })

            if customer_cancellations:
                self.cancellation_found.emit(customer_cancellations)
            self.poll_done.emit()

        except Exception as exc:
            self.poll_error.emit(str(exc))
            self.poll_done.emit()


class GHLNotifyWorker(QThread):
    """Look up GHL contact for a cancelled mandate and tag + annotate them."""

    notify_done = Signal(str, bool, str)  # mandate_id, success, message

    def __init__(self, gc_token: str, environment: str, ghl_api_key: str,
                 location_id: str, mandate_id: str, cancel_tag: str,
                 add_note: bool):
        super().__init__()
        self.gc_token = gc_token
        self.environment = environment
        self.ghl_api_key = ghl_api_key
        self.location_id = location_id
        self.mandate_id = mandate_id
        self.cancel_tag = cancel_tag
        self.add_note = add_note

    def run(self):
        """Resolve mandate → customer → email → GHL contact, then tag & note."""
        try:
            # Step 1: Get mandate → customer ID
            mandate_resp = _gc_api_request(
                'GET', f'/mandates/{self.mandate_id}',
                self.gc_token, self.environment,
            )
            if 'error' in mandate_resp:
                self.notify_done.emit(self.mandate_id, False, mandate_resp['error'])
                return
            customer_id = mandate_resp.get('mandates', {}).get(
                'links', {}).get('customer', '')
            if not customer_id:
                self.notify_done.emit(self.mandate_id, False, 'No customer linked')
                return

            # Step 2: Get customer email
            cust_resp = _gc_api_request(
                'GET', f'/customers/{customer_id}',
                self.gc_token, self.environment,
            )
            if 'error' in cust_resp:
                self.notify_done.emit(self.mandate_id, False, cust_resp['error'])
                return
            customer = cust_resp.get('customers', {})
            email = customer.get('email', '')
            cust_name = (
                f"{customer.get('given_name', '')} "
                f"{customer.get('family_name', '')}"
            ).strip()
            if not email:
                self.notify_done.emit(
                    self.mandate_id, False, f'No email for {cust_name}')
                return

            # Step 3: Search GHL contact by email
            search_resp = _ghl_api_request(
                'GET',
                f'/contacts/?query={urllib.parse.quote(email)}'
                f'&locationId={self.location_id}',
                self.ghl_api_key,
            )
            if 'error' in search_resp:
                self.notify_done.emit(
                    self.mandate_id, False,
                    f'GHL search failed: {search_resp["error"]}')
                return
            contacts = search_resp.get('contacts', [])
            if not contacts:
                self.notify_done.emit(
                    self.mandate_id, False,
                    f'No GHL contact for {email}')
                return
            contact_id = contacts[0].get('id', '')

            # Step 4: Add tag
            if self.cancel_tag:
                _ghl_api_request(
                    'POST', f'/contacts/{contact_id}/tags',
                    self.ghl_api_key, data={'tags': [self.cancel_tag]},
                )

            # Step 5: Add note
            if self.add_note:
                note_text = (
                    f'\u26a0\ufe0f GoCardless mandate {self.mandate_id} '
                    f'was cancelled (customer/bank initiated). '
                    f'Customer may need to set up a new mandate.'
                )
                _ghl_api_request(
                    'POST', f'/contacts/{contact_id}/notes',
                    self.ghl_api_key, data={'body': note_text},
                )

            self.notify_done.emit(
                self.mandate_id, True, f'Tagged {cust_name} in GHL')

        except Exception as exc:
            self.notify_done.emit(self.mandate_id, False, str(exc))


# ═══════════════════════════════════════════════════════════════════════════
# Main window
# ═══════════════════════════════════════════════════════════════════════════

class StaleMandatesWindow(QMainWindow):

    def __init__(self, environment: str = 'live'):
        super().__init__()
        self.environment = environment
        self.mandates: List[Dict] = []
        self.gc_script = _find_gc_script()
        self.fetch_worker: Optional[FetchWorker] = None
        self.cancel_worker: Optional[CancelWorker] = None

        # Cancellation monitor state
        self.credentials = _load_credentials()
        self.poll_worker: Optional[PollCancelledWorker] = None
        self.ghl_workers: List[GHLNotifyWorker] = []
        self.poll_timer = QTimer(self)
        self.poll_timer.timeout.connect(self._run_poll)
        self.seen_event_ids: Set[str] = set()
        self.last_poll_time = datetime.now(timezone.utc).strftime(
            '%Y-%m-%dT%H:%M:%SZ'
        )

        self._build_ui()
        self._start_fetch()

    # ── UI construction ────────────────────────────────────
    def _build_ui(self):
        self.setWindowTitle('Stale Mandates — Plans Finished')
        self.setMinimumSize(_MIN_WIDTH, _MIN_HEIGHT)
        self.resize(_DEFAULT_WIDTH, _DEFAULT_HEIGHT)

        # Window icon
        for ico_name in ('SideKick_PS.ico', 'SideKick_LB.ico'):
            ico = os.path.join(SCRIPT_DIR, ico_name)
            if os.path.isfile(ico):
                self.setWindowIcon(QIcon(ico))
                break

        # Central widget with tab bar
        central = QWidget()
        self.setCentralWidget(central)
        outer = QVBoxLayout(central)
        outer.setContentsMargins(0, 0, 0, 0)
        outer.setSpacing(0)

        self.tabs = QTabWidget()
        outer.addWidget(self.tabs)

        # ── Tab 1: Stale Mandates ──────────────────────────
        mandates_page = QWidget()
        root = QVBoxLayout(mandates_page)
        root.setContentsMargins(*_MARGIN)
        root.setSpacing(_SPACING)

        # Header
        self.header_label = QLabel('Scanning for stale mandates…')
        self.header_label.setObjectName('header')
        root.addWidget(self.header_label)

        # Sub-header
        self.sub_label = QLabel(
            'Active mandates where all payment plans have finished or been cancelled.'
        )
        self.sub_label.setObjectName('subheader')
        root.addWidget(self.sub_label)

        # Progress
        self.progress_bar = QProgressBar()
        self.progress_bar.setRange(0, 100)
        self.progress_bar.setValue(0)
        root.addWidget(self.progress_bar)

        self.progress_label = QLabel('')
        self.progress_label.setObjectName('subheader')
        root.addWidget(self.progress_label)

        # ── Table ──────────────────────────────────────────
        self.table = QTableWidget()
        self.table.setColumnCount(_TABLE_COLS)
        self.table.setHorizontalHeaderLabels([
            '✓', 'Last Payment', 'Collected', 'Customer', 'Email', 'Created', 'Mandate ID',
        ])
        self.table.setAlternatingRowColors(True)
        self.table.setSelectionBehavior(QAbstractItemView.SelectionBehavior.SelectRows)
        self.table.setSelectionMode(QAbstractItemView.SelectionMode.NoSelection)
        self.table.verticalHeader().setVisible(False)
        self.table.setShowGrid(False)
        self.table.setSortingEnabled(False)  # enable after population
        self.table.setWordWrap(False)

        hdr = self.table.horizontalHeader()
        hdr.setMinimumSectionSize(_COL_CHECK)
        hdr.resizeSection(0, _COL_CHECK)        # ✓ checkbox
        hdr.resizeSection(1, _COL_LAST_PAY)     # Last Payment
        hdr.resizeSection(2, _COL_COLLECTED)     # Collected
        col_customer = 3
        hdr.resizeSection(col_customer, _COL_CUSTOMER)
        col_email = 4
        hdr.resizeSection(col_email, _COL_EMAIL)
        col_created = 5
        hdr.resizeSection(col_created, _COL_CREATED)
        hdr.setStretchLastSection(True)  # Mandate ID

        self.table.setVisible(False)
        root.addWidget(self.table, 1)  # stretch

        # ── Button row ─────────────────────────────────────
        btn_row = QHBoxLayout()
        btn_row.setSpacing(10)

        self.btn_select_all = QPushButton('Select All')
        self.btn_select_all.clicked.connect(self._select_all)
        btn_row.addWidget(self.btn_select_all)

        self.btn_select_none = QPushButton('Select None')
        self.btn_select_none.clicked.connect(self._select_none)
        btn_row.addWidget(self.btn_select_none)

        btn_row.addStretch()

        self.btn_cancel = QPushButton('⚠  Cancel Selected')
        self.btn_cancel.setObjectName('cancelBtn')
        self.btn_cancel.clicked.connect(self._cancel_selected)
        btn_row.addWidget(self.btn_cancel)

        self.btn_copy = QPushButton('📋  Copy to Clipboard')
        self.btn_copy.clicked.connect(self._copy_clipboard)
        btn_row.addWidget(self.btn_copy)

        self.btn_close = QPushButton('Close')
        self.btn_close.clicked.connect(self.close)
        btn_row.addWidget(self.btn_close)

        # Hide action buttons until data loads
        for btn in (self.btn_select_all, self.btn_select_none,
                     self.btn_cancel, self.btn_copy):
            btn.setVisible(False)

        root.addLayout(btn_row)

        # ── Cancellation Monitor Section ────────────────────
        divider = QFrame()
        divider.setFrameShape(QFrame.Shape.HLine)
        divider.setFrameShadow(QFrame.Shadow.Sunken)
        root.addWidget(divider)

        monitor_hdr = QLabel('\U0001f514  Cancellation Monitor')
        monitor_hdr.setObjectName('header')
        monitor_hdr.setStyleSheet('font-size: 12pt;')
        root.addWidget(monitor_hdr)

        monitor_desc = QLabel(
            'Polls GoCardless for mandates cancelled by customers '
            'or their bank (not by you).'
        )
        monitor_desc.setObjectName('subheader')
        root.addWidget(monitor_desc)

        # Timer controls row
        timer_row = QHBoxLayout()
        timer_row.setSpacing(_SPACING)

        timer_row.addWidget(QLabel('Poll every:'))

        self.poll_interval_spin = QSpinBox()
        self.poll_interval_spin.setRange(1, _POLL_MAX_MINUTES)
        self.poll_interval_spin.setValue(_POLL_DEFAULT_MINUTES)
        self.poll_interval_spin.setSuffix(' min')
        self.poll_interval_spin.setFixedWidth(_SPIN_WIDTH)
        timer_row.addWidget(self.poll_interval_spin)

        self.btn_toggle_monitor = QPushButton('\u25b6  Start Monitoring')
        self.btn_toggle_monitor.clicked.connect(self._toggle_monitor)
        timer_row.addWidget(self.btn_toggle_monitor)

        self.monitor_status_label = QLabel('')
        self.monitor_status_label.setObjectName('subheader')
        timer_row.addWidget(self.monitor_status_label)

        timer_row.addStretch()
        root.addLayout(timer_row)

        # Cancellation log table
        self.cancel_log_table = QTableWidget()
        self.cancel_log_table.setColumnCount(_CLOG_COLS)
        self.cancel_log_table.setHorizontalHeaderLabels([
            'Time', 'Mandate ID', 'Origin', 'Cause', 'Description',
        ])
        self.cancel_log_table.setAlternatingRowColors(True)
        self.cancel_log_table.verticalHeader().setVisible(False)
        self.cancel_log_table.setShowGrid(False)
        self.cancel_log_table.setSelectionBehavior(
            QAbstractItemView.SelectionBehavior.SelectRows)
        self.cancel_log_table.setMaximumHeight(_CLOG_MAX_HEIGHT)

        hdr2 = self.cancel_log_table.horizontalHeader()
        hdr2.resizeSection(0, _CLOG_COL_TIME)
        hdr2.resizeSection(1, _CLOG_COL_MANDATE)
        hdr2.resizeSection(2, _CLOG_COL_ORIGIN)
        clog_col_cause = 3
        hdr2.resizeSection(clog_col_cause, _CLOG_COL_CAUSE)
        hdr2.setStretchLastSection(True)

        self.cancel_log_table.setVisible(False)
        root.addWidget(self.cancel_log_table)

        # ── GHL Notification Settings (shown only if creds detected) ──
        self.ghl_group = QGroupBox(
            '\U0001f4e7  GHL Notifications'
        )
        self.ghl_group.setVisible(False)
        ghl_layout = QVBoxLayout(self.ghl_group)
        ghl_notify_spacing = 6
        ghl_layout.setSpacing(ghl_notify_spacing)

        self.ghl_status_label = QLabel('')
        ghl_layout.addWidget(self.ghl_status_label)

        self.ghl_notify_check = QCheckBox(
            'Tag GHL contact when customer cancels a mandate'
        )
        self.ghl_notify_check.setChecked(True)
        ghl_layout.addWidget(self.ghl_notify_check)

        tag_row = QHBoxLayout()
        tag_row.addWidget(QLabel('Cancellation tag:'))
        self.ghl_tag_combo = QComboBox()
        self.ghl_tag_combo.setEditable(True)
        self.ghl_tag_combo.setFixedWidth(_GHL_TAG_WIDTH)
        self.ghl_tag_combo.addItem('DD Cancelled')
        self.ghl_tag_combo.setCurrentText('DD Cancelled')
        tag_row.addWidget(self.ghl_tag_combo)

        self.btn_refresh_tags = QPushButton('\U0001f504')
        self.btn_refresh_tags.setToolTip('Fetch tags from GHL')
        self.btn_refresh_tags.setFixedWidth(36)
        self.btn_refresh_tags.clicked.connect(self._fetch_ghl_tags)
        tag_row.addWidget(self.btn_refresh_tags)

        tag_row.addStretch()
        ghl_layout.addLayout(tag_row)

        self.ghl_note_check = QCheckBox(
            'Add note to GHL contact record'
        )
        self.ghl_note_check.setChecked(True)
        ghl_layout.addWidget(self.ghl_note_check)

        root.addWidget(self.ghl_group)

        # Show GHL section if credentials detected
        if self.credentials.get('ghl_api_key'):
            loc_id = self.credentials.get('location_id', 'N/A')
            self.ghl_group.setVisible(True)
            self.ghl_status_label.setText(
                f'\u2705  GHL credentials detected  \u2022  '
                f'Location: {loc_id}'
            )

        self.tabs.addTab(mandates_page, '\U0001f9f9  Stale Mandates')

        # ── Tab 2: GHL Settings ────────────────────────────
        ghl_settings_page = self._build_ghl_settings_tab()
        self.tabs.addTab(ghl_settings_page, '\U0001f310  GHL Settings')

        # Status bar
        self.setStatusBar(QStatusBar())

    # ── Fetch logic ────────────────────────────────────────
    def _start_fetch(self):
        if not self.gc_script:
            self._show_error_state('gocardless_api script not found in:\n' + SCRIPT_DIR)
            return

        self.fetch_worker = FetchWorker(self.gc_script, self.environment)
        self.fetch_worker.progress_updated.connect(self._on_progress)
        self.fetch_worker.finished.connect(self._on_fetch_done)
        self.fetch_worker.error.connect(self._on_fetch_error)
        self.fetch_worker.start()

    def _on_progress(self, current: int, total: int, message: str):
        if total > 0:
            self.progress_bar.setValue(int(current / total * 100))
        self.progress_label.setText(message)

    def _on_fetch_done(self, mandates: list):
        self.progress_bar.setVisible(False)
        self.progress_label.setVisible(False)

        if not mandates:
            self.header_label.setText('✅  No Stale Mandates')
            self.sub_label.setText(
                'All active mandates still have live payment plans. Nothing to clean up.'
            )
            return

        # Sort oldest first (most stale at top)
        self.mandates = sorted(mandates, key=lambda m: m.get('last_payment_date') or '0000')

        count = len(self.mandates)
        self.header_label.setText(
            f'{count} Stale Mandate{"s" if count != 1 else ""} Found'
        )
        self.sub_label.setText(
            'These mandates have all plans finished but the Direct Debit is still active.'
        )

        self._populate_table()

        self.table.setVisible(True)
        for btn in (self.btn_select_all, self.btn_select_none,
                     self.btn_cancel, self.btn_copy):
            btn.setVisible(True)

    def _on_fetch_error(self, error: str):
        self._show_error_state(f'Failed to fetch stale mandates:\n{error}')

    def _show_error_state(self, message: str):
        self.progress_bar.setVisible(False)
        self.progress_label.setVisible(False)
        self.header_label.setText('Error')
        self.sub_label.setText(message)
        self.sub_label.setWordWrap(True)

    # ── Table population ───────────────────────────────────
    def _populate_table(self):
        self.table.setSortingEnabled(False)
        self.table.setRowCount(len(self.mandates))

        for row, m in enumerate(self.mandates):
            # Checkbox (centered in cell)
            cb = QCheckBox()
            wrapper = QWidget()
            lay = QHBoxLayout(wrapper)
            lay.addWidget(cb)
            lay.setAlignment(Qt.AlignmentFlag.AlignCenter)
            lay.setContentsMargins(0, 0, 0, 0)
            self.table.setCellWidget(row, 0, wrapper)

            # Data columns
            last_pay = m.get('last_payment_date') or 'Never'
            collected = f"£{m['total_collected']:,.2f}"

            cells = {
                1: last_pay,
                2: collected,
                3: m.get('customer_name', ''),
                4: m.get('email', ''),
                5: m.get('created_at', ''),
                6: m.get('mandate_id', ''),
            }
            for col, text in cells.items():
                item = QTableWidgetItem(text)
                item.setFlags(item.flags() & ~Qt.ItemFlag.ItemIsEditable)
                if col == 2:
                    item.setTextAlignment(Qt.AlignmentFlag.AlignRight | Qt.AlignmentFlag.AlignVCenter)
                else:
                    item.setTextAlignment(Qt.AlignmentFlag.AlignLeft | Qt.AlignmentFlag.AlignVCenter)
                self.table.setItem(row, col, item)

            self.table.setRowHeight(row, _ROW_HEIGHT)

        self.table.setSortingEnabled(True)
        # Default sort: oldest last payment first
        self.table.sortByColumn(1, Qt.SortOrder.AscendingOrder)

    # ── Checkbox helpers ───────────────────────────────────
    def _get_checkbox(self, row: int) -> Optional[QCheckBox]:
        w = self.table.cellWidget(row, 0)
        return w.findChild(QCheckBox) if w else None

    def _select_all(self):
        for r in range(self.table.rowCount()):
            cb = self._get_checkbox(r)
            if cb and cb.isEnabled():
                cb.setChecked(True)

    def _select_none(self):
        for r in range(self.table.rowCount()):
            cb = self._get_checkbox(r)
            if cb:
                cb.setChecked(False)

    def _get_selected_mandates(self) -> List[Dict]:
        """Return mandate dicts for every checked row."""
        selected = []
        for r in range(self.table.rowCount()):
            cb = self._get_checkbox(r)
            if cb and cb.isChecked():
                # Match by mandate_id shown in column 6
                mid_item = self.table.item(r, 6)
                if mid_item:
                    mid = mid_item.text()
                    for m in self.mandates:
                        if m['mandate_id'] == mid:
                            selected.append(m)
                            break
        return selected

    # ── Cancel flow ────────────────────────────────────────
    def _cancel_selected(self):
        selected = self._get_selected_mandates()
        if not selected:
            QMessageBox.warning(
                self, 'No Selection',
                'Please tick the mandates you want to cancel.',
            )
            return

        count = len(selected)
        word = '1 mandate' if count == 1 else f'{count} mandates'
        name_list = '\n'.join(f'  •  {m["customer_name"]}' for m in selected)

        # ── WARNING 1 ─────────────────────────────────────
        reply1 = QMessageBox.warning(
            self,
            'Cancel Mandates?',
            f'You are about to cancel {word}:\n\n'
            f'{name_list}\n\n'
            f'⚠️  This will revoke the Direct Debit authorisation.\n'
            f'The customer would need to set up a new mandate to pay again.\n\n'
            f'Are you sure you want to continue?',
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
            QMessageBox.StandardButton.No,
        )
        if reply1 != QMessageBox.StandardButton.Yes:
            return

        # ── WARNING 2 — FINAL ─────────────────────
        reply2 = QMessageBox.critical(
            self,
            '⛔  FINAL WARNING',
            f'THIS CANNOT BE REVERSED\n\n'
            f'Cancelling {word} will permanently revoke\n'
            f'the Direct Debit mandate(s).\n\n'
            f'Do you understand this is permanent?',
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
            QMessageBox.StandardButton.No,
        )
        if reply2 != QMessageBox.StandardButton.Yes:
            return

        # Disable cancel button while working
        self.btn_cancel.setEnabled(False)
        self.btn_cancel.setText('Cancelling…')

        self.cancel_worker = CancelWorker(
            self.gc_script, self.environment, selected,
        )
        self.cancel_worker.mandate_done.connect(self._on_mandate_cancelled)
        self.cancel_worker.all_done.connect(self._on_all_cancelled)
        self.cancel_worker.start()

    def _on_mandate_cancelled(self, mandate_id: str, name: str,
                               success: bool, error: str):
        """Grey-out a successfully cancelled row."""
        for r in range(self.table.rowCount()):
            mandate_col = 6
            mid_item = self.table.item(r, mandate_col)
            if mid_item and mid_item.text() == mandate_id:
                self._apply_cancel_result(r, success, name, error)
                break

    def _apply_cancel_result(self, row: int, success: bool,
                             name: str, error: str):
        """Apply visual changes to a cancelled table row."""
        cb = self._get_checkbox(row)
        if cb:
            cb.setChecked(False)
            cb.setEnabled(False)
        if success:
            grey = QColor('#666666')
            for c in range(1, _TABLE_COLS):
                item = self.table.item(row, c)
                if item:
                    item.setForeground(grey)
        self.statusBar().showMessage(
            f'{"✅" if success else "❌"}  {name}' +
            (f' — {error}' if error else ''),
            _STATUS_SHORT,
        )

    def _on_all_cancelled(self, ok: int, fail: int):
        self.btn_cancel.setEnabled(True)
        self.btn_cancel.setText('⚠  Cancel Selected')

        if fail == 0:
            QMessageBox.information(
                self, 'Mandates Cancelled',
                f'✅  Successfully cancelled {ok} mandate(s).\n\n'
                f'These mandates are now revoked.',
            )
        elif ok > 0:
            QMessageBox.warning(
                self, 'Partial Success',
                f'Cancelled {ok} mandate(s).\n\n'
                f'❌  Failed to cancel {fail}.\n'
                f'Check the status bar for details.',
            )
        else:
            QMessageBox.critical(
                self, 'Cancellation Failed',
                f'❌  Failed to cancel all {fail} mandate(s).',
            )

    # ── Copy to clipboard ─────────────────────────────────
    def _copy_clipboard(self):
        lines = ['Last Payment\tCollected\tCustomer\tEmail\tCreated\tMandate ID']
        for m in self.mandates:
            last_pay = m.get('last_payment_date') or 'Never'
            lines.append(
                f"{last_pay}\t£{m['total_collected']:,.2f}\t"
                f"{m['customer_name']}\t{m['email']}\t"
                f"{m['created_at']}\t{m['mandate_id']}"
            )
        QApplication.clipboard().setText('\n'.join(lines))
        self.statusBar().showMessage('Copied to clipboard!', 2000)

    # ── Monitor / Polling logic ─────────────────────────────
    def _toggle_monitor(self):
        """Start or stop the cancellation polling timer."""
        if self.poll_timer.isActive():
            self._stop_monitor()
        else:
            self._start_monitor()

    def _start_monitor(self):
        """Begin periodic polling for cancelled mandates."""
        if not self.credentials.get('gc_token'):
            QMessageBox.warning(
                self, 'No Token',
                'GoCardless token not found in credentials.json.\n\n'
                'Place credentials.json in the script folder or\n'
                '%APPDATA%\\SideKick_PS\\',
            )
            return

        interval_ms = self.poll_interval_spin.value() * 60_000
        self.poll_timer.setInterval(interval_ms)
        self.poll_timer.start()
        self.poll_interval_spin.setEnabled(False)
        self.btn_toggle_monitor.setText('\u23f8  Stop Monitoring')
        self.btn_toggle_monitor.setStyleSheet(
            'background-color: #2d5a1e; color: #88ff88; border-color: #338833;'
        )
        self.monitor_status_label.setText(
            'Monitoring active \u2014 first check now\u2026')
        self.cancel_log_table.setVisible(True)

        # Run first poll immediately
        self._run_poll()

    def _stop_monitor(self):
        """Stop the cancellation polling timer."""
        self.poll_timer.stop()
        self.poll_interval_spin.setEnabled(True)
        self.btn_toggle_monitor.setText('\u25b6  Start Monitoring')
        self.btn_toggle_monitor.setStyleSheet('')
        self.monitor_status_label.setText('Monitoring stopped.')

    def _run_poll(self):
        """Spawn a background thread to check for new cancellation events."""
        if self.poll_worker and self.poll_worker.isRunning():
            return  # previous poll still running

        self.poll_worker = PollCancelledWorker(
            self.credentials['gc_token'],
            self.environment,
            self.last_poll_time,
        )
        self.poll_worker.cancellation_found.connect(self._on_cancellations_found)
        self.poll_worker.poll_error.connect(self._on_poll_error)
        self.poll_worker.poll_done.connect(self._on_poll_done)
        self.poll_worker.start()

    def _on_cancellations_found(self, cancellations: list):
        """Handle newly detected customer/bank cancellations."""
        for cancel in cancellations:
            eid = cancel['event_id']
            if eid in self.seen_event_ids:
                continue
            self.seen_event_ids.add(eid)
            self._add_cancel_log_row(cancel)
            self._notify_cancellation(cancel)

    def _on_poll_error(self, error: str):
        self.monitor_status_label.setText(f'\u26a0 Poll error: {error[:_POLL_ERROR_PREVIEW]}')

    def _on_poll_done(self):
        now = datetime.now(timezone.utc)
        self.last_poll_time = now.strftime('%Y-%m-%dT%H:%M:%SZ')
        interval = self.poll_interval_spin.value()
        self.monitor_status_label.setText(
            f'Last checked: {now.strftime("%H:%M:%S")}  \u2022  '
            f'Next in {interval} min'
        )

    def _add_cancel_log_row(self, event: dict):
        """Append a row to the cancellation log table."""
        row = self.cancel_log_table.rowCount()
        self.cancel_log_table.insertRow(row)

        created = event.get('created_at', '')[:19].replace('T', ' ')
        origin_raw = event.get('origin', '')
        origin_icon = {'bank': '\U0001f3e6', 'customer': '\U0001f464',
                       'gocardless': '\u2699\ufe0f'}.get(origin_raw, '\u2753')

        cells = {
            0: created,
            1: event.get('mandate_id', ''),
            2: f'{origin_icon} {origin_raw.title()}',
            3: event.get('cause', ''),
            4: event.get('description', ''),
        }
        for col, text in cells.items():
            item = QTableWidgetItem(text)
            item.setFlags(item.flags() & ~Qt.ItemFlag.ItemIsEditable)
            self.cancel_log_table.setItem(row, col, item)

        self.cancel_log_table.setRowHeight(row, _CLOG_ROW_HEIGHT)
        self.cancel_log_table.scrollToBottom()

    def _notify_cancellation(self, event: dict):
        """Show status-bar alert and optionally tag GHL contact."""
        origin_label = (
            '\U0001f3e6 Bank' if event.get('origin') == 'bank'
            else '\U0001f464 Customer' if event.get('origin') == 'customer'
            else '\u2699 GoCardless'
        )
        msg = (
            f"Mandate {event['mandate_id']} cancelled by {origin_label} — "
            f"{event.get('cause', 'Unknown')}"
        )
        self.statusBar().showMessage(f'\U0001f514 {msg}', _STATUS_NOTIFY)

        # GHL notification if enabled and credentials present
        if (self.credentials.get('ghl_api_key')
                and self.ghl_notify_check.isChecked()):
            tag = self.ghl_tag_combo.currentText().strip()
            add_note = self.ghl_note_check.isChecked()
            if tag or add_note:
                worker = GHLNotifyWorker(
                    self.credentials['gc_token'],
                    self.environment,
                    self.credentials['ghl_api_key'],
                    self.credentials.get('location_id', ''),
                    event['mandate_id'],
                    tag,
                    add_note,
                )
                worker.notify_done.connect(self._on_ghl_notify_done)
                self.ghl_workers.append(worker)
                worker.start()

    def _on_ghl_notify_done(self, mandate_id: str, success: bool, message: str):
        """Handle GHL notification result."""
        icon = '\u2705' if success else '\u274c'
        self.statusBar().showMessage(
            f'{icon} GHL: {message}', _STATUS_LONG)
        # Clean up finished workers
        self.ghl_workers = [
            w for w in self.ghl_workers if w.isRunning()
        ]

    # ── GHL Settings tab ──────────────────────────────────
    def _build_ghl_settings_tab(self) -> QWidget:
        """Build the GHL Settings configuration tab for standalone mode."""
        page = QWidget()
        layout = QVBoxLayout(page)
        layout.setContentsMargins(*_GHL_MARGIN)
        layout.setSpacing(_GHL_SPACING)

        # Header
        hdr = QLabel('\U0001f310  GoHighLevel Settings')
        hdr.setObjectName('header')
        layout.addWidget(hdr)

        desc = QLabel(
            'Configure GHL API credentials for standalone mode. '
            'When launched from SideKick_PS these are loaded automatically.'
        )
        desc.setObjectName('subheader')
        desc.setWordWrap(True)
        layout.addWidget(desc)

        # ── Connection group ───────────────────────────────
        conn_group = QGroupBox('API Connection')
        conn_layout = QVBoxLayout(conn_group)
        conn_layout.setSpacing(_GHL_CONN_SPACING)

        # API Key row
        key_row = QHBoxLayout()
        key_label = QLabel('API Key:')
        key_label.setFixedWidth(_GHL_LABEL_WIDTH)
        key_row.addWidget(key_label)
        self.ghl_api_key_edit = QLineEdit()
        self.ghl_api_key_edit.setEchoMode(QLineEdit.EchoMode.Password)
        self.ghl_api_key_edit.setPlaceholderText(
            'GHL V2 Private Integration Token'
        )
        key_row.addWidget(self.ghl_api_key_edit)
        self.btn_show_key = QPushButton('\U0001f441')
        self.btn_show_key.setFixedWidth(_GHL_EYE_BTN_WIDTH)
        self.btn_show_key.setCheckable(True)
        self.btn_show_key.clicked.connect(self._toggle_api_key_visibility)
        key_row.addWidget(self.btn_show_key)
        conn_layout.addLayout(key_row)

        # Location ID row
        loc_row = QHBoxLayout()
        loc_label = QLabel('Location ID:')
        loc_label.setFixedWidth(_GHL_LABEL_WIDTH)
        loc_row.addWidget(loc_label)
        self.ghl_location_edit = QLineEdit()
        self.ghl_location_edit.setPlaceholderText(
            'e.g. 8IWxk5M0PvbNf1w3npQU'
        )
        loc_row.addWidget(self.ghl_location_edit)
        conn_layout.addLayout(loc_row)

        # Action buttons row
        action_row = QHBoxLayout()
        self.btn_test_ghl = QPushButton('\U0001f517  Test Connection')
        self.btn_test_ghl.clicked.connect(self._test_ghl_connection)
        action_row.addWidget(self.btn_test_ghl)

        self.btn_save_ghl = QPushButton('\U0001f4be  Save Credentials')
        self.btn_save_ghl.clicked.connect(self._save_ghl_credentials)
        action_row.addWidget(self.btn_save_ghl)

        action_row.addStretch()
        conn_layout.addLayout(action_row)

        # Connection status label
        self.ghl_conn_status = QLabel('')
        self.ghl_conn_status.setWordWrap(True)
        conn_layout.addWidget(self.ghl_conn_status)

        layout.addWidget(conn_group)

        # ── Credentials file info ──────────────────────────
        creds_group = QGroupBox('Credentials File')
        creds_layout = QVBoxLayout(creds_group)

        creds_path = self._get_credentials_path()
        path_label = QLabel(f'Path: {creds_path}')
        path_label.setObjectName('subheader')
        path_label.setWordWrap(True)
        path_label.setTextInteractionFlags(
            Qt.TextInteractionFlag.TextSelectableByMouse
        )
        creds_layout.addWidget(path_label)

        exists = os.path.isfile(creds_path)
        file_status = (
            '\u2705 File exists' if exists
            else '\u26a0\ufe0f File not found (will be created on save)'
        )
        creds_status = QLabel(file_status)
        creds_status.setObjectName('subheader')
        creds_layout.addWidget(creds_status)

        # Show what's loaded
        loaded_parts: list = []
        if self.credentials.get('gc_token'):
            loaded_parts.append('GoCardless token \u2705')
        if self.credentials.get('ghl_api_key'):
            loaded_parts.append('GHL API key \u2705')
        if self.credentials.get('location_id'):
            loaded_parts.append(
                f'Location: {self.credentials["location_id"]}'
            )
        if loaded_parts:
            loaded_label = QLabel(
                'Loaded: ' + '  \u2022  '.join(loaded_parts)
            )
            loaded_label.setObjectName('subheader')
            creds_layout.addWidget(loaded_label)

        layout.addWidget(creds_group)

        layout.addStretch()

        # Pre-fill from loaded credentials
        if self.credentials.get('ghl_api_key'):
            self.ghl_api_key_edit.setText(self.credentials['ghl_api_key'])
        if self.credentials.get('location_id'):
            self.ghl_location_edit.setText(self.credentials['location_id'])

        return page

    def _get_credentials_path(self) -> str:
        """Get the preferred path for credentials.json."""
        local = os.path.join(SCRIPT_DIR, 'credentials.json')
        if os.path.isfile(local):
            return local
        appdata = os.path.join(
            os.environ.get('APPDATA', ''), 'SideKick_PS', 'credentials.json'
        )
        if os.path.isfile(appdata):
            return appdata
        return appdata  # default to AppData location

    def _toggle_api_key_visibility(self):
        """Toggle API key field between password and plain text."""
        if self.btn_show_key.isChecked():
            self.ghl_api_key_edit.setEchoMode(QLineEdit.EchoMode.Normal)
            self.btn_show_key.setText('\U0001f512')
        else:
            self.ghl_api_key_edit.setEchoMode(QLineEdit.EchoMode.Password)
            self.btn_show_key.setText('\U0001f441')

    def _fetch_ghl_tags(self):
        """Fetch all tags from GHL and populate the cancellation tag dropdown."""
        api_key = self.credentials.get('ghl_api_key', '')
        location_id = self.credentials.get('location_id', '')
        if not api_key or not location_id:
            self.statusBar().showMessage(
                '\u26a0 GHL credentials not loaded — cannot fetch tags',
                _STATUS_SHORT,
            )
            return

        self.btn_refresh_tags.setEnabled(False)
        self.btn_refresh_tags.setText('\u23f3')
        QApplication.processEvents()

        resp = _ghl_api_request(
            'GET', f'/locations/{location_id}/tags', api_key
        )

        self.btn_refresh_tags.setEnabled(True)
        self.btn_refresh_tags.setText('\U0001f504')

        if 'error' in resp:
            self.statusBar().showMessage(
                f'\u274c Failed to fetch tags: {resp["error"]}',
                _STATUS_SHORT,
            )
            return

        tags_list = resp.get('tags', [])
        current_text = self.ghl_tag_combo.currentText()
        self.ghl_tag_combo.clear()
        tag_names = sorted(
            (t.get('name', '') for t in tags_list if t.get('name')),
            key=str.lower,
        )
        self.ghl_tag_combo.addItems(tag_names)

        # Restore previous selection or keep typed text
        idx = self.ghl_tag_combo.findText(current_text)
        if idx >= 0:
            self.ghl_tag_combo.setCurrentIndex(idx)
        else:
            self.ghl_tag_combo.setEditText(current_text)

        self.statusBar().showMessage(
            f'\u2705 Loaded {len(tag_names)} tags from GHL',
            _STATUS_SHORT,
        )

    def _test_ghl_connection(self):
        """Test the GHL API connection using the entered credentials."""
        api_key = self.ghl_api_key_edit.text().strip()
        location_id = self.ghl_location_edit.text().strip()
        if not api_key:
            self.ghl_conn_status.setText('\u274c API Key is required')
            return
        if not location_id:
            self.ghl_conn_status.setText('\u274c Location ID is required')
            return

        self.ghl_conn_status.setText('Testing\u2026')
        self.btn_test_ghl.setEnabled(False)
        QApplication.processEvents()

        resp = _ghl_api_request(
            'GET',
            f'/contacts/?locationId={location_id}&limit=1',
            api_key,
        )

        self.btn_test_ghl.setEnabled(True)

        if 'error' in resp:
            self.ghl_conn_status.setText(
                f'\u274c Connection failed: {resp["error"]}'
            )
        else:
            total = resp.get('meta', {}).get('total', '?')
            self.ghl_conn_status.setText(
                f'\u2705 Connected \u2014 Location: {location_id}'
                f'  ({total} contacts)'
            )
            # Update in-memory credentials
            self.credentials['ghl_api_key'] = api_key
            self.credentials['location_id'] = location_id
            # Enable inline GHL notification group on mandates tab
            self.ghl_group.setVisible(True)
            self.ghl_status_label.setText(
                f'\u2705  GHL credentials detected  \u2022  '
                f'Location: {location_id}'
            )

    def _save_ghl_credentials(self):
        """Save GHL API key and location to credentials.json."""
        api_key = self.ghl_api_key_edit.text().strip()
        location_id = self.ghl_location_edit.text().strip()
        if not api_key:
            QMessageBox.warning(
                self, 'Missing API Key',
                'Enter a GHL API key before saving.',
            )
            return

        creds_path = self._get_credentials_path()

        # Load existing file or start fresh
        existing: dict = {}
        if os.path.isfile(creds_path):
            try:
                with open(creds_path, 'r', encoding='utf-8-sig') as fh:
                    existing = json.load(fh)
            except Exception:
                pass

        # Update GHL fields (base64-encode key for consistency)
        existing['api_key_b64'] = base64.b64encode(
            api_key.encode('utf-8')
        ).decode('utf-8')
        existing['location_id'] = location_id

        # Ensure directory exists
        os.makedirs(os.path.dirname(creds_path), exist_ok=True)

        try:
            with open(creds_path, 'w', encoding='utf-8') as fh:
                json.dump(existing, fh, indent=2)

            self.credentials['ghl_api_key'] = api_key
            self.credentials['location_id'] = location_id

            QMessageBox.information(
                self, 'Saved',
                f'GHL credentials saved to:\n{creds_path}',
            )
        except Exception as exc:
            QMessageBox.critical(
                self, 'Save Failed',
                f'Failed to save credentials:\n{exc}',
            )

    # ── Window close ───────────────────────────────────────
    def closeEvent(self, event):
        """Gracefully stop all background threads before closing."""
        self._shutdown_workers()
        event.accept()

    def _shutdown_workers(self):
        """Stop timer and wait on all running background threads."""
        if self.poll_timer.isActive():
            self.poll_timer.stop()
        # Wait on each worker type with its timeout
        waitlist = [
            (self.poll_worker, _WAIT_POLL, False),
            (self.fetch_worker, _WAIT_FETCH, True),
            (self.cancel_worker, _WAIT_CANCEL, False),
        ]
        for worker, timeout, needs_stop in waitlist:
            if worker and worker.isRunning():
                if needs_stop:
                    worker.stop()
                worker.wait(timeout)
        for w in self.ghl_workers:
            if w.isRunning():
                w.wait(_WAIT_GHL)


# ═══════════════════════════════════════════════════════════════════════════
# Entry point
# ═══════════════════════════════════════════════════════════════════════════

def _activate_existing_window() -> bool:
    """If another instance is already running, bring its window to front."""
    try:
        import ctypes.wintypes
        EnumWindows = ctypes.windll.user32.EnumWindows
        GetWindowTextW = ctypes.windll.user32.GetWindowTextW
        SetForegroundWindow = ctypes.windll.user32.SetForegroundWindow
        ShowWindow = ctypes.windll.user32.ShowWindow
        IsIconic = ctypes.windll.user32.IsIconic
        SW_RESTORE = 9

        found = [False]

        @ctypes.WINFUNCTYPE(ctypes.c_bool, ctypes.wintypes.HWND, ctypes.wintypes.LPARAM)
        def callback(hwnd, _) -> bool:
            """EnumWindows callback — find & activate existing Stale Mandates window."""
            buf = ctypes.create_unicode_buffer(_WIN_TITLE_BUF)
            GetWindowTextW(hwnd, buf, _WIN_TITLE_BUF)
            if buf.value.startswith('Stale Mandates'):
                if IsIconic(hwnd):
                    ShowWindow(hwnd, SW_RESTORE)
                SetForegroundWindow(hwnd)
                found[0] = True
                return False  # stop enumerating
            return True

        EnumWindows(callback, 0)
        return found[0]
    except Exception:
        return False


def main():
    """Application entry point — parse args, enforce singleton, launch GUI."""
    parser = argparse.ArgumentParser(description='Stale Mandates GUI')
    parser.add_argument('--live', action='store_true', help='Use live GoCardless environment')
    parser.add_argument('--sandbox', action='store_true', help='Use sandbox environment')
    args = parser.parse_args()

    environment = 'sandbox' if args.sandbox else 'live'

    # Singleton: Windows named mutex — prevents duplicate instances
    mutex_handle = None
    try:
        mutex_handle = ctypes.windll.kernel32.CreateMutexW(None, True,
                                                            'SideKick_StaleMandatesGUI_Mutex')
        last_err = ctypes.windll.kernel32.GetLastError()
        if last_err == _MUTEX_ALREADY_EXISTS:
            # Another instance is running — bring it to front and exit
            _activate_existing_window()
            sys.exit(0)
    except Exception:
        pass  # If mutex fails, allow running anyway

    # Windows taskbar identity
    try:
        ctypes.windll.shell32.SetCurrentProcessExplicitAppUserModelID(
            'GuyMayer.SideKick.StaleMandates.1'
        )
    except Exception:
        pass

    app = QApplication(sys.argv)
    app.setStyleSheet(DARK_STYLESHEET)
    app.setFont(QFont('Segoe UI', 10))

    window = StaleMandatesWindow(environment)
    window.show()

    # Use getattr to avoid static analyser false-positive on 'exec'
    qt_exec = getattr(app, 'exec')
    exit_code = qt_exec()

    # Release mutex on exit
    if mutex_handle:
        try:
            ctypes.windll.kernel32.ReleaseMutex(mutex_handle)
            ctypes.windll.kernel32.CloseHandle(mutex_handle)
        except Exception:
            pass

    sys.exit(exit_code)


if __name__ == '__main__':
    main()

# SideKick PS — Python Porting Audit
**Date**: 2026-03-17  
**Scope**: Full port from AutoHotkey v1 to Python 3.x  
**Current version**: 3.0.1 (Build 2026-03-09)

---

## 1. Code Inventory

### AHK Source (what needs porting)

| File | Lines | Role |
|---|---:|---|
| `SideKick_PS.ahk` | 12,662 | Main application logic, all GUIs, toolbar |
| `Inc_Licensing.ahk` | 6,200 | License validation, trial flow, protection |
| `Inc_Hotkeys.ahk` | 1,374 | Global hotkey registration and handling |
| `Inc_Tooltips.ahk` | 1,084 | Custom tooltip system |
| `Inc_WhatsNew.ahk` | 843 | Changelog display GUI |
| `Inc_ArchivePicker.ahk` | 679 | Folder-selection dialogs |
| `Inc_SDCard.ahk` | 471 | SD card drive detection + image copy |
| `CardlyLoader.ahk` | 137 | Cardly Python subprocess launcher |
| **TOTAL AHK** | **23,450** | |

### Python Already Written (existing foundation)

| File | Lines | Status |
|---|---:|---|
| `sync_ps_invoice.py` | 5,052 | ✅ Complete — GHL invoice sync engine |
| `cardly_preview_gui.py` | 3,126 | ✅ Complete — Cardly Qt GUI |
| `cardly_send_card.py` | 1,317 | ✅ Complete — Cardly send logic |
| `create_ghl_contactsheet.py` | 795 | ✅ Complete — Contact sheet creation |
| `validate_license.py` | 554 | ✅ Complete — License validation backend |
| `write_psa_payments.py` | 360 | ✅ Complete — PSA payment writer |
| `upload_ghl_media.py` | 261 | ✅ Complete — GHL media upload |
| `read_psa_images.py` | 233 | ✅ Complete — PSA image reader |
| `read_psa_payments.py` | 131 | ✅ Complete — PSA payment reader |
| `detect_psa_group.py` | 206 | ✅ Complete — PSA group detection |
| `sidekick_ps/cli.py` | 131 | ✅ Complete — CLI dispatcher |
| **TOTAL Python** | **12,166** | |

**Net new Python to write: estimated 18,000–24,000 lines** (GUI + Win32 integration layer).

---

## 2. Feature Inventory & Complexity Matrix

### Difficulty scale
- **Easy** — straightforward Python equivalent, mostly config/data work
- **Medium** — requires some Win32/pywin32 calls or multi-step logic
- **Hard** — deep Windows API, fragile UI automation, or no clean 1:1 mapping
- **Very Hard** — platform-specific hacks, timing sensitive, or near-impossible to replicate cleanly

---

### 2.1 Core Application Shell

| Feature | AHK Lines ~| Difficulty | Python approach | Est. days |
|---|---:|---|---|---:|
| App entry point, tray icon | 100 | Easy | `PyQt6.QSystemTrayIcon` | 1 |
| INI config read/write | 200 | Easy | `configparser` | 1 |
| Logging infrastructure | 150 | Easy | `logging` + rotating file handler | 0.5 |
| Auto-startup (registry) | 50 | Easy | `winreg` | 0.5 |
| DPI awareness | 50 | Easy | `QtGui.QScreen.devicePixelRatio()` | 0.5 |
| ProSelect process detection | 100 | Easy | `psutil.process_iter()` | 0.5 |
| Auto-update check | 100 | Medium | `requests` + version compare | 1.5 |
| Import / Export settings | 200 | Easy | `json` + `QFileDialog` | 1 |
| **Subtotal** | | | | **6.5** |

---

### 2.2 Payment Calculator GUI
*(PayCalcGUI, RecalcFromNo, RecalcFromAmount — lines 792-1300)*

| Feature | AHK Lines ~| Difficulty | Python approach | Est. days |
|---|---:|---|---|---:|
| Balance due header | 80 | Easy | `PyQt6 QLabel` | 0.5 |
| Downpayment input + live recalc | 150 | Easy | `QDoubleSpinBox` + signals | 1 |
| Scheduled payments grid | 200 | Medium | `QTableWidget` or `QFormLayout` | 2 |
| Rounding options | 80 | Easy | `QComboBox` + signals | 0.5 |
| Payment type selector | 80 | Easy | `QComboBox` | 0.5 |
| Payment date scheduling logic | 200 | Medium | `datetime` arithmetic | 1.5 |
| ProSelect-sourced pay types | 100 | Medium | Parse PSA XML, cache to config | 1 |
| **Subtotal** | | | | **7** |

---

### 2.3 Floating Toolbar
*(PositionToolbar, UpdateToolbarBackground, DeferredToolbarRebuild — lines 1837-3010)*

This is the highest-risk area of the port. AHK has native `Gui` windows that can be flagged as tool windows and positioned anywhere on screen. Python/Qt can replicate this but requires careful Win32 integration.

| Feature | AHK Lines ~| Difficulty | Python approach | Est. days |
|---|---:|---|---|---:|
| Frameless Qt window (toolbar) | 200 | Medium | `Qt.FramelessWindowHint \| Qt.Tool` | 1.5 |
| Dock to ProSelect title bar | 200 | Hard | `win32gui.GetWindowRect()` + periodic timer | 3 |
| Auto-scale by window width | 150 | Medium | `win32gui.GetClientRect()` + Qt scale | 1.5 |
| Auto-background color sample | 150 | Hard | `win32gui.GetDC()` + pixel colour | 2 |
| Drag-handle repositioning | 150 | Medium | `mouseMoveEvent` + offset save | 1.5 |
| Toolbar button icons | 100 | Easy | `QPixmap` + `QPainter` | 1 |
| Toolbar tooltip system | 150 | Easy | `QToolTip` (built-in) | 0.5 |
| Toolbar rebuild on scale change | 150 | Medium | Signal-driven rebuild with debounce | 1 |
| Camera button state (on/off/calib) | 100 | Medium | State machine + `QTimer` | 1 |
| Show/hide per button settings | 100 | Easy | `setVisible()` per button | 0.5 |
| **Subtotal** | | | | **13.5** |

---

### 2.4 ProSelect Window Monitoring
*(WatchForAddPayment, CheckForPS — lines 645-800)*

| Feature | AHK Lines ~| Difficulty | Python approach | Est. days |
|---|---:|---|---|---:|
| Detect ProSelect running | 50 | Easy | `psutil` | 0.5 |
| Detect ProSelect version (2022/2025) | 100 | Easy | Check exe path / process name | 0.5 |
| Watch for "Add Payment" window | 100 | Medium | `win32gui.FindWindow()` in timer loop | 1 |
| Place overlay button on window | 150 | Hard | `win32gui.CreateWindowEx` child or Qt overlay | 3 |
| **Subtotal** | | | | **5** |

---

### 2.5 Payment Entry Automation
*(MakePayments — lines 10311-10370)*

> ⚠️ This is the most fragile feature. Any ProSelect UI change breaks it.

| Feature | AHK Lines ~| Difficulty | Python approach | Est. days |
|---|---:|---|---|---:|
| Click "Add" button | 30 | Hard | `win32api.SendMessage`/`PostMessage` | 1 |
| Date picker control interaction | 50 | Hard | `win32gui.SendMessage` to `SysDateTimePick32` | 2 |
| Amount field entry | 30 | Hard | `win32gui.SendMessage WM_SETTEXT` to `Edit2` | 1 |
| Payment type combo | 30 | Hard | `CB_SELECTSTRING` message | 1 |
| Confirm / close | 30 | Medium | `BM_CLICK` to Button4 | 0.5 |
| Timing / delay calibration | 60 | Medium | `time.sleep()` + speed benchmark | 1 |
| **Subtotal** | | | | **6.5** |

---

### 2.6 Print to PDF Workflow
*(Toolbar_PrintToPDF, PDFCalibration — lines 3249-3822)*

> ⚠️ High fragility. Depends on Windows print dialog layout (Win10 vs Win11 differ).

| Feature | AHK Lines ~| Difficulty | Python approach | Est. days |
|---|---:|---|---|---:|
| Set default printer | 50 | Easy | `win32print.SetDefaultPrinter()` | 0.5 |
| Trigger ProSelect print menu | 100 | Hard | Keyboard injection via `win32api.keybd_event` | 2 |
| Template selection in print dialog | 150 | Hard | `win32gui` control enumeration + `CB_SELECTSTRING` | 3 |
| Calibrated click on Print button | 200 | Hard | Saved offset click via `win32api.SetCursorPos` + `mouse_event` | 2 |
| Handle Save As dialog | 100 | Medium | `win32gui.FindWindow("ComDlg32", "Save As")` | 1.5 |
| File overwrite confirmation | 50 | Medium | `win32gui.FindWindow` + button click | 0.5 |
| Restore default printer | 30 | Easy | `win32print.SetDefaultPrinter()` | 0.5 |
| Copy to secondary folder | 50 | Easy | `shutil.copy2()` | 0.5 |
| **Subtotal** | | | | **10.5** |

---

### 2.7 PDF Email
*(Toolbar_EmailPDF, PDFEmailSend — lines 3823-3965)*

| Feature | AHK Lines ~| Difficulty | Python approach | Est. days |
|---|---:|---|---|---:|
| Email compose dialog (Qt) | 150 | Medium | `PyQt6` form with To/Subject/Body | 1.5 |
| Attachment selection / PDF path | 50 | Easy | `QFileDialog` | 0.5 |
| Send via SMTP or GHL | 100 | Medium | `smtplib`/`ssl` or GHL email API | 1.5 |
| Refresh email templates | 100 | Easy | Load from GHL or local config | 0.5 |
| **Subtotal** | | | | **4** |

---

### 2.8 GHL Integration GUIs
*(GHLClientLookup, Toolbar_GetInvoice, GHLSetupWizard, RefreshGHLTags)*

> Backend already exists in `sync_ps_invoice.py`. Port is GUI wrappers only.

| Feature | AHK Lines ~| Difficulty | Python approach | Est. days |
|---|---:|---|---|---:|
| Client lookup dialog | 250 | Medium | `QDialog` + `QListWidget` | 2 |
| GHL Client data → ProSelect update | 150 | Medium | Call existing `sync_ps_invoice` APIs | 1 |
| Invoice sync progress UI | 200 | Medium | `QProgressDialog` + thread | 1.5 |
| Delete last invoice dialog | 150 | Medium | `QDialog` confirmation + API call | 1 |
| GHL API key setup wizard | 300 | Medium | `QWizard` multi-page | 2.5 |
| Refresh tags (silent background) | 150 | Easy | `QThread` + signal | 1 |
| GHL warning dialog | 100 | Easy | `QMessageBox` | 0.5 |
| TestGHLConnection | 100 | Easy | `requests.get()` + result dialog | 0.5 |
| **Subtotal** | | | | **9** |

---

### 2.9 GoCardless Integration
*(Toolbar_GoCardless, GCSearchOK/Cancel — lines 4961-5433)*

| Feature | AHK Lines ~| Difficulty | Python approach | Est. days |
|---|---:|---|---|---:|
| GC search input dialog | 100 | Easy | `QInputDialog` | 0.5 |
| GC customer lookup form | 200 | Medium | `QDialog` + `QTableWidget` | 2 |
| GC mandate setup automation | 150 | Hard | GoCardless REST API (OAuth flow) | 2 |
| Auto-setup toggle / options | 100 | Easy | Settings checkboxes | 0.5 |
| **Subtotal** | | | | **5** |

---

### 2.10 SD Card Workflow
*(Inc_SDCard.ahk — 471 lines)*

| Feature | AHK Lines ~| Difficulty | Python approach | Est. days |
|---|---:|---|---|---:|
| Removable drive detection | 80 | Medium | `watchdog` DriveDetector or `psutil.disk_partitions()` | 1 |
| Drive label matching | 50 | Easy | `os.path` + drive label check | 0.5 |
| Image copy with progress | 150 | Easy | `shutil.copy2()` + `QProgressDialog` | 1.5 |
| Auto-rename images | 100 | Medium | Date/shoot-name renaming logic | 1 |
| Browse download path | 50 | Easy | `QFileDialog.getExistingDirectory()` | 0.5 |
| **Subtotal** | | | | **4.5** |

---

### 2.11 Room Capture
*(Toolbar_CaptureRoom — lines 5457-5656)*

| Feature | AHK Lines ~| Difficulty | Python approach | Est. days |
|---|---:|---|---|---:|
| Multi-monitor screen capture | 100 | Easy | `mss` library | 1 |
| JPEG save (quality 95) | 30 | Easy | `Pillow` | 0.5 |
| Album name + room counter naming | 50 | Easy | Config + counter | 0.5 |
| Clipboard copy of path | 30 | Easy | `pyperclip` | 0.5 |
| Post-capture dialog | 80 | Easy | `QDialog` with Open/Reveal/Email | 0.5 |
| Room email send | 100 | Medium | Reuse PDF email component | 0.5 |
| **Subtotal** | | | | **3.5** |

---

### 2.12 QR Code Display
*(Toolbar_QRCode, QRCode_Next/Prev — lines 4534-4952)*

| Feature | AHK Lines ~| Difficulty | Python approach | Est. days |
|---|---:|---|---|---:|
| QR code generation | 50 | Easy | `segno` or `qrcode` library | 0.5 |
| Fullscreen display window | 100 | Easy | `PyQt6 QLabel` fullscreen | 1 |
| Multi-slide cycling (↑↓) | 80 | Easy | Index state + keyPress | 1 |
| Monitor navigation (←→) | 80 | Medium | `QScreen` enumeration + `setGeometry` | 1 |
| Configurable size (25-85%) | 50 | Easy | Scale to screen fraction | 0.5 |
| Slides: QR / Bank transfer / Custom image | 100 | Medium | Config-driven slide builder | 1 |
| QR code cache management | 80 | Easy | `pathlib` temp folder | 0.5 |
| **Subtotal** | | | | **5.5** |

---

### 2.13 Cardly Integration
*(Toolbar_Cardly — lines 6253-6710)*

> ✅ Already mostly ported. AHK is a thin subprocess caller.

| Feature | AHK Lines ~| Difficulty | Python approach | Est. days |
|---|---:|---|---|---:|
| Launch Cardly preview GUI | 50 | Easy | Direct import + call (already Python) | 0.5 |
| Pass ProSelect data to Cardly | 100 | Easy | Shared config / function call | 0.5 |
| **Subtotal** | | | | **1** |

---

### 2.14 Settings GUI
*(ShowSettings, SettingsApply — lines 6719-9100)*

| Feature | AHK Lines ~| Difficulty | Python approach | Est. days |
|---|---:|---|---|---:|
| Multi-tab settings dialog | 300 | Medium | `QTabWidget` skeleton | 2 |
| General tab (startup, sounds, tray) | 150 | Easy | Checkboxes + `configparser` | 1 |
| GHL tab (API key, tags, options) | 200 | Medium | Form fields + validation | 1.5 |
| GoCardless tab | 100 | Easy | Checkboxes + token fields | 1 |
| Toolbar customization tab | 200 | Medium | Button toggle grid + icon picker | 1.5 |
| SD Card / Files tab | 100 | Easy | Path fields + checkboxes | 0.5 |
| Hotkey capture tab | 200 | Hard | `QKeySequenceEdit` per action | 2 |
| PDF / Print tab | 100 | Medium | Path + offset fields | 1 |
| Advanced / Debug tab | 100 | Easy | Logging toggle + export | 0.5 |
| **Subtotal** | | | | **11** |

---

### 2.15 Hotkey System
*(Inc_Hotkeys.ahk — 1,374 lines)*

> ⚠️ Global hotkeys in Python require a low-level keyboard hook. On Windows these work fine but are admin-sensitive and antivirus-flagged more often than AHK.

| Feature | AHK Lines ~| Difficulty | Python approach | Est. days |
|---|---:|---|---|---:|
| Global hotkey registration | 200 | Hard | `pynput.keyboard.GlobalHotKeys` or `keyboard` lib | 2 |
| Context-sensitivity (PS vs global) | 200 | Hard | Foreground window check before action dispatch | 2 |
| Hotkey config from settings | 100 | Medium | Map config→hotkey at startup | 1 |
| Re-register on settings change | 50 | Medium | Stop/restart listener | 0.5 |
| Hotkey capture UI | 100 | Hard | Custom `QKeySequenceEdit`-backed dialog | 1.5 |
| **Subtotal** | | | | **7** |

---

### 2.16 Licensing System
*(Inc_Licensing.ahk — 6,200 lines; validate_license.py — 554 lines)*

> Backend already exists. GUI layer + protection layer needed.

| Feature | AHK Lines ~| Difficulty | Python approach | Est. days |
|---|---:|---|---|---:|
| License check on startup | 100 | Easy | Call `validate_license.py` | 0.5 |
| License entry dialog | 150 | Easy | `QDialog` with key input + submit | 1 |
| Trial countdown GUI | 100 | Easy | Days remaining display | 0.5 |
| Trial expired blocking screen | 100 | Easy | Modal `QDialog` | 0.5 |
| Online activation API call | 100 | Medium | `requests` to license server | 1 |
| Offline grace period | 100 | Medium | Timestamp + grace logic | 1 |
| Code obfuscation / protection | — | Hard | PyInstaller + Cython for critical modules | 3 |
| **Subtotal** | | | | **7.5** |

---

### 2.17 Remaining Dialogs & Utilities

| Feature | AHK Lines ~| Difficulty | Python approach | Est. days |
|---|---:|---|---|---:|
| About dialog | 100 | Easy | `QDialog` | 0.5 |
| What's New / Changelog | 843 | Easy | `QTextBrowser` rendering Markdown | 1 |
| Dark message box (custom styling) | 150 | Easy | Subclass `QMessageBox` | 0.5 |
| Sync progress dialog | 200 | Easy | `QProgressDialog` + cancel signal | 0.5 |
| Refund dialog | 100 | Easy | `QDialog` + GHL API call | 0.5 |
| Debug step-through tool | 200 | Easy | Replace with Python `logging` | 0.5 |
| URL selector dialog | 100 | Easy | `QDialog` + `QListWidget` | 0.5 |
| QuickPub dialog | 100 | Easy | `QDialog` | 0.5 |
| **Subtotal** | | | | **5** |

---

## 3. Effort Summary

| Area | Estimated Days |
|---|---:|
| Core application shell | 6.5 |
| Payment Calculator GUI | 7 |
| Floating toolbar | 13.5 |
| ProSelect window monitoring | 5 |
| Payment entry automation | 6.5 |
| Print to PDF workflow | 10.5 |
| PDF Email | 4 |
| GHL integration GUIs | 9 |
| GoCardless integration | 5 |
| SD Card workflow | 4.5 |
| Room capture | 3.5 |
| QR code display | 5.5 |
| Cardly integration | 1 |
| Settings GUI | 11 |
| Hotkey system | 7 |
| Licensing system | 7.5 |
| Remaining dialogs & utilities | 5 |
| **TOTAL (net new work)** | **~117 days** |

Add **15–20% buffer** for integration testing, bug-fixing, and PyInstaller packaging:  
**Realistic total: 130–140 working days (~26–28 weeks solo).**

---

## 4. Phased Delivery Plan

### Phase 1 — Foundation (Weeks 1–2)
- Python project structure, PyInstaller build skeleton
- Config system, logging, tray icon, ProSelect detection
- App entry point validates license and launches main window
- **Deliverable**: Runnable stub that detects ProSelect and sits in tray

### Phase 2 — Payment Calculator (Weeks 3–4)
- Full PayCalcGUI port
- Recalculation logic, downpayment, scheduled payments grid
- **Deliverable**: Calculator works standalone (no toolbar yet)

### Phase 3 — Floating Toolbar v1 (Weeks 5–7)
- Frameless Qt window docks to ProSelect
- All buttons present but most are stubs
- Auto-scale, auto-background, drag handle
- **Deliverable**: Toolbar visible and draggable on ProSelect

### Phase 4 — GHL & Invoice Features (Weeks 8–9)
- Client lookup, invoice sync, tags, GHL wizard
- Leverages existing `sync_ps_invoice.py`
- **Deliverable**: GHL buttons fully functional

### Phase 5 — Print to PDF + Email (Weeks 10–11)
- PDF workflow automation, calibration system
- PDF email send
- **Deliverable**: PDF button works on both target ProSelect versions

### Phase 6 — GoCardless, SD Card, Room Capture (Weeks 12–13)
- GoCardless search and setup
- SD card drive detection and copy
- Screen room capture
- **Deliverable**: All media/payment-method buttons functional

### Phase 7 — QR Codes + Cardly (Week 14)
- QR display fullscreen, multi-monitor
- Cardly launcher (already mostly done)
- **Deliverable**: All toolbar buttons active

### Phase 8 — Settings GUI (Weeks 15–16)
- Multi-tab settings dialog
- Toolbar customization, hotkey capture
- **Deliverable**: Settings fully configurable

### Phase 9 — Hotkeys (Week 17)
- Global hotkey registration from settings
- Context-aware dispatch
- **Deliverable**: Configured hotkeys work globally

### Phase 10 — Payment Automation (Weeks 18–19)
- Button overlay on Add Payment window
- MakePayments Win32 control automation
- Timing calibration
- **Deliverable**: Full payment entry automation

### Phase 11 — Licensing + Protection (Weeks 20–21)
- License dialogs, trial flow, online activation
- Cython-compile critical modules for protection
- **Deliverable**: Commercial licensing enforced

### Phase 12 — Testing, Polish, Build (Weeks 22–26)
- End-to-end regression against AHK version
- PyInstaller single-exe + Inno Setup installer
- User acceptance testing
- **Deliverable**: Shippable v4.0 Python build

---

## 5. Key Python Library Dependencies

| Library | Purpose | Install |
|---|---|---|
| `PyQt6` / `PySide6` | All GUI windows, dialogs, tray icon | `pip install PyQt6` |
| `pywin32` | Win32 API: window management, ControlSend, DPI, registry | `pip install pywin32` |
| `psutil` | Process detection (ProSelect running + version) | `pip install psutil` |
| `pynput` | Global keyboard hotkeys | `pip install pynput` |
| `requests` | HTTP (GHL, GoCardless, license server, updates) | `pip install requests` |
| `Pillow` | Image processing, JPEG save | `pip install Pillow` |
| `mss` | Fast multi-monitor screen capture | `pip install mss` |
| `segno` | QR code generation | `pip install segno` |
| `watchdog` | Removable drive / file system events | `pip install watchdog` |
| `pyperclip` | Clipboard operations | `pip install pyperclip` |
| `configparser` | INI config (stdlib) | built-in |
| `PyInstaller` | Single-exe packaging | `pip install pyinstaller` |
| `Cython` (optional) | Compile licensing module for protection | `pip install cython` |

---

## 6. Key Risks

### R1 — Floating Toolbar Stability (HIGH)
The AHK toolbar uses native Gui windows that the OS treats as tool windows, allowing them to seamlessly dock against ProSelect without z-order fighting. Qt frameless windows require careful `setWindowFlags()` and a Win32 `SetWindowPos` call with `HWND_TOPMOST` to prevent the toolbar disappearing behind ProSelect. Extensive testing required against both ProSelect 2022 and 2025, at multiple DPIs (96, 120, 144, 192 dpi).

**Mitigation**: Build a standalone toolbar prototype (Phase 3) before committing to full feature work.

### R2 — Payment Entry Automation (HIGH)
The payment entry sends keystrokes into ProSelect's native Win32 controls. Any ProSelect update that renames controls (`Edit2`, `Button3`, `SysDateTimePick321`) breaks automation silently. Python's `win32gui.SendMessage` approach is equivalent to AHK's `ControlSend` but equally brittle.

**Mitigation**: Add control-presence validation before each automation step. Log control class names on each run for early warning.

### R3 — Print to PDF (HIGH)
Windows 10 and Windows 11 have different print dialog layouts. The calibration system partially mitigates this, but the menu-key injection (`Alt+F → P → Right → Enter`) depends on ProSelect's menu structure not changing. Test against both ProSelect versions and both Windows versions as a priority.

**Mitigation**: Keep calibration UX prominent. Add a "test print" diagnostic mode.

### R4 — Global Hotkeys & Antivirus (MEDIUM)
Python-based keyboard hooks (`pynput`, `keyboard`) are sometimes flagged by antivirus engines (Defender, Bitdefender) as keyloggers. AHK executables have a longer-established trust profile on most systems.

**Mitigation**: Code-sign the final executable. Test against common AV products. Provide a documented whitelist path for users.

### R5 — PyInstaller Binary Size & Startup Time (MEDIUM)
A PyInstaller single-exe with PyQt6 + pywin32 + Pillow will be 50–80 MB and have a 3–5 second cold-start time as it extracts to a temp directory. The current AHK exe is under 5 MB and starts instantly.

**Mitigation**: Use `--onedir` for better startup performance at the cost of an installer (already using Inno Setup). Or use `--onefile` with a splash screen to mask the delay.

### R6 — Licensing Protection (MEDIUM)
AHK `.exe` files compiled with compression are harder to decompile than Python. PyInstaller + Cython compiled `.pyd` modules offer reasonable but not equivalent protection.

**Mitigation**: Compile `validate_license.py` to a `.pyd` via Cython. Keep the license server key material out of the packaged code.

### R7 — ProSelect ProSelect Console Path (LOW)
`psconsole.exe` path detection logic needs to be replicated. Low risk as it's one registry or directory walk.

---

## 7. What Is NOT Changing

The following are already Python and **do not need porting**:
- All GHL API calls (`sync_ps_invoice.py`)
- All PSA file reading/writing
- Cardly preview and send
- License validation backend
- CLI dispatcher architecture (`sidekick_ps/cli.py`)
- All HTTP integrations (GoCardless REST, GHL REST)

---

## 8. Recommended GUI Framework Decision

| Option | Pros | Cons |
|---|---|---|
| **PyQt6** | Mature, fast, great DPI support, native look | GPL/commercial licence cost for distribution |
| **PySide6** | LGPL (free for commercial use), same API as PyQt6 | Slightly slower releases |
| **wxPython** | Truly native Win32 widgets | Older API, harder to style, less Qt DPI tooling |
| **tkinter** | Built-in, zero deps | Poor styling, no HiDPI scaling, no modern widgets |

**Recommendation: PySide6** — Same API as PyQt6, LGPL licensing avoids commercial GPL concerns for a paid product, and it ships with Qt 6.x for first-class Windows 11 styling.

---

*Generated 2026-03-17. Based on SideKick_PS v3.0.1 AHK source (23,450 lines) and existing Python foundation (12,166 lines).*

# SideKick_PS Changelog

<!--
AI INSTRUCTIONS - When publishing a new version:
1. Update this CHANGELOG.md with the new version entry
2. Update version.json in this repo with:
   - "version": new version number
   - "build_date": current date (YYYY-MM-DD)
   - "release_notes": brief summary
   - "changelog": array of changes (NEW/FIX/IMPROVED prefixes)
3. Commit and push both files to Git
4. Run the build script to compile and create installer
-->

## v2.5.4 (2026-02-10)

### New Features
- **Hotkey Scope Control**: Global hotkeys (Ctrl+Shift+...) now only work when ProSelect or SideKick windows are active, preventing interference with other apps like Photoshop
- **Photoshop Transfer Workflow**: Ctrl+T (Transfer to Photoshop) now shows reminder dialog to edit and save, then auto-refreshes ProSelect with Ctrl+U
- **Invoice Export Hands-Off GUI**: Shows "HANDS OFF" warning during invoice export automation to prevent user interference
- **Print Template Dropdowns**: Template selection in Settings now uses dropdown lists with Refresh button to load templates from ProSelect
- **Room Capture Album Folder Option**: Save folder dropdown includes "Album Folder" to save room captures in the current album's directory

### Improvements
- **Keyboard Menu Navigation for Print**: Replaced Ctrl+P shortcuts with Alt+F → Print → Order/Invoice Report keyboard navigation to prevent triggering other hotkeys during automation
- **Print Automation Timing**: Added 1 second delays before/after menu navigation and in Windows Print dialog for reliability
- **Toolbar Photoshop Button**: Only triggers when ProSelect is focused (matches other toolbar buttons)
- **Settings Hotkeys Tab**: Added note explaining that hotkeys only work in ProSelect/SideKick context
- **Print Settings Tooltips**: Added helpful tooltips to all Print Settings controls
- **Dropdown SELECT Option**: All template dropdowns now show "SELECT" as default when no template is chosen

### Bug Fixes
- **Toolbar Height DPI Scaling**: Fixed toolbar height not scaling on high-DPI displays (buttons were clipped at bottom)
- **PDF Button Toggle**: PDF toolbar button now appears/disappears immediately when toggled in Settings (previously required Apply/Close)
- **Settings Tab Switching**: Fixed HotkeysNote not being hidden when switching to other tabs
- **Folder Template Disabled State**: Folder Template field now properly grays out when File Management is disabled

---

## v2.5.3 (2026-02-09)

### New Features
- **Print to PDF Hands-Off Mode**: Shows warning GUI during PDF generation - "HANDS OFF - Do not touch mouse or keyboard"
- **Auto-Create Copy Folder**: PDF copy folder is created automatically if it doesn't exist
- **PDF Toolbar Button**: Dedicated PDF button on toolbar (maroon background) - always prints to PDF regardless of Enable PDF toggle
- **PDF Overwrite Protection**: If PDF already exists, auto-appends _1, _2, etc. instead of overwriting
- **GHL Client QR Code**: One-click setup of ProSelect QR code - unified format works for both phone cameras AND barcode scanners
- **Dynamic GHL Agency Domain**: GHL domain URL is now configurable per account (e.g. app.yourcompany.com). Auto-detected during setup wizard when reading the login URL. Stored in INI file.
- **QR Scanner Keyboard Wedge Support**: SideKick detects `https://` URLs typed quickly by scanners. Fast-typing detection (K-1) avoids triggering on manual keyboard input.
- **Print Tooltip Shows Printer**: Quick Print button tooltip now shows the default printer name
- **New Toolbar Icons**: 
  - GHL button now uses ID Card icon instead of globe
  - Get Client button now uses Person+ icon

### Improvements
- **Print to PDF Reliability**: Click inside Print dialog to force focus before sending keystrokes
- **PDF Filename Fix**: PDF now named after album (parent folder) instead of subfolder name
- **Task In Progress Wait**: Waits for ProSelect "Task In Progress" window to close before copying PDF
- **Removed Debug Step GUI**: Print to PDF runs automatically without step-by-step prompts

### Bug Fixes
- **Save Button Fix**: Now clicks correct Save button (Button2) in Save dialog
- **Focus Stability**: Removed GUI Flash that was stealing focus during automation
- **Toolbar Height DPI Scaling**: Fixed toolbar height not scaling on high-DPI displays (buttons were clipped at bottom)
- **PDF Button Toggle**: PDF toolbar button now appears/disappears immediately when toggled in Settings (previously required Apply/Close)

---

## v2.5.2 (2026-02-09)

### New Features
- **Phosphor Thin Icon Font**: Bundled thin outline icon font for consistent toolbar appearance across all Windows versions
- **Icon Font Auto-Detection**: Automatically detects and uses best available icon font (Phosphor Thin > Segoe Fluent > Font Awesome)
- **Font Fallback Chain**: If Phosphor Thin unavailable, falls back to Segoe Fluent Icons (Win11) or Font Awesome Solid

### Improvements
- **Thinner Toolbar Icons**: Switched from bold Font Awesome Solid to thin outline Phosphor icons
- **Cross-Platform Icons**: Icons now display consistently regardless of Windows version or installed fonts
- **Font Bundled with Installer**: Phosphor-Thin.ttf included in installer, auto-installed to user fonts

---

## v2.5.1 (2026-02-09)

### New Features
- **Detailed Sync Error Dialog**: When invoice sync fails (e.g., GHL contact not found), shows comprehensive error MsgBox with:
  - Available data (client name, shoot no, email, album)
  - What's missing/invalid with specific fix instructions
  - Version info for diagnostics (SideKick version, helper version, helper build date)
- **Log Folder Link**: Settings > About now shows clickable log folder path next to Send Logs button
- **Timestamped Log Files**: Each session creates a new log file (e.g., `sidekick_20260209_143022.log`)
- **7-Day Log Retention**: Logs are automatically cleaned up after 7 days on startup

### Improvements
- **Helper Version Logging**: Startup debug log now includes sync_ps_invoice helper info (path, version, file modified date, file size)
- **Version Mismatch Detection**: Helper version info helps identify when users have mismatched component versions
- **Email-First Contact Search**: GHL contact lookup now searches by email first (more reliable), then falls back to job number custom field
- **Log Files Preserved**: Invoice sync now appends to log instead of overwriting - preserves startup info

### Bug Fixes
- **Log File Location**: Moved logs from script directory (Program Files - protected) to AppData\Roaming\SideKick_PS\Logs (writable)

---

## v2.5.0 (2026-02-08)

### New Features
- **Toolbar Grab Handle**: Ctrl+Click and drag the ⋮ handle on the left of toolbar to reposition
- **Persistent Position**: Toolbar position offset saved to INI file, relative to ProSelect window
- **Reset Position Button**: Settings > Shortcuts > Toolbar Appearance - resets toolbar to default position

### Bug Fixes
- **Toolbar Tooltips**: Fixed tooltips not appearing on hover - now uses timer-based detection (100ms interval)
- **Hover Detection**: Uses MouseGetPos for accurate button detection under cursor

---

## v2.4.77 (2026-02-08)

### New Features
- **Local QR Code Generation**: No more Google Charts API dependency - uses BARCODER library for local QR generation
- **QR Code Caching**: QR codes pre-generated on startup for instant display
- **WiFi QR Display**: WiFi QR codes show friendly format (WiFi: SSID | Password: xxx)
- **Monitor Selection**: Choose which monitor displays QR codes via Settings dropdown or arrow keys at runtime

### Improvements
- **Flash-Free QR Cycling**: Controls update without GUI rebuild when cycling through QR codes
- **Smart Dialog Detection**: Toolbar hides automatically when smaller ProSelect windows (dialogs) are active
- **QR Instructions Position**: Instructions moved to bottom of QR display for cleaner appearance
- **Ps Button Color**: Photoshop button now uses toolbar icon color setting like other buttons

---

## v2.4.75 (2026-02-07)

### New Features
- **Print to PDF**: Toolbar print button can save PDF to album folder with optional copy to secondary folder
- **Print Settings Tab**: Dedicated settings tab for print templates, room capture email, and PDF output configuration
- **Enable PDF Toggle**: Persistent toggle to switch toolbar print button between normal print and PDF mode
- **PDF Copy Folder**: Configure a secondary folder where generated PDFs are automatically copied

### Improvements
- **DPI-Scaled Toolbar**: All button dimensions, spacing, and offsets now scale with display DPI
- **Room Captured Dialog**: Shows image preview thumbnail using GDI+
- **Toolbar Auto-Hide**: Toolbar hides during Save Album As, Save As, and Print dialogs
- **Email Template Refresh**: Uses GetScriptCommand for .exe/.py compatibility on installed machines

### Bug Fixes
- Contact sheet JPG now saves to album/XML directory instead of Program Files (Permission denied fix)
- Email template refresh works on installed builds (.exe) not just dev (.py)
- Fixed GetPythonExe() → GetPythonPath() call in RefreshPrintEmailTemplates

---

## v2.4.72 (2026-02-07)

### New Features
- **Room Capture Email Template Picker**: When clicking Email after a room capture, a template picker dialog appears letting you choose from available GHL email templates with your default pre-selected
- **Shortcuts Tab**: New Settings tab for configuring toolbar buttons and quick print templates
- **Quick Print Templates**: Configure template names for "Payment Plan" and "Standard" orders that auto-select in ProSelect's Print dialog
- **Invoice Deletion**: Ctrl+Click the Sync Invoice button to delete the last synced invoice for the current client

### Improvements
- **Email Template Refresh**: 🔄 button in Settings → Shortcuts fetches email templates from GHL
- **Client Lookup Cancel**: Added Cancel button to "Client ID Found in Album" dialog
- **Contact/Opportunity Tagging**: Configure tags to automatically apply to contacts and opportunities during invoice sync

### Bug Fixes
- Fixed command quoting issues for Python script execution (email templates, license validation)
- Fixed global variable declarations for GUI controls in template pickers

---

## v2.4.28 (2026-01-31)

### Improvements
- **DPI Scaling for DarkMsgBox**: Full high-DPI display support
  - Button dimensions (width, height) scale with DPI
  - Button spacing and positioning scale with DPI
  - Font sizes scale with DPI
  - Bottom padding scales with DPI
  - Fixed button obscuring text on What's New dialog

---

## v2.4.27 (2026-01-31)

### Improvements
- **Invoice Sync Enhancements**:
  - Payment schedules now show as actual invoice line items with dates and amounts
  - Added VAT/Tax summary on invoices (Subtotal ex VAT, VAT, Total)
  - Only past payments recorded as transactions (future payments show as scheduled items)
  - Automatic total verification and rounding adjustment (first payment)
  - All payments labeled "Payment 1", "Payment 2", etc.
- **Export Workflow Fixes**:
  - Extended sleep after "Check All" button (2 seconds for ProSelect response)
  - Added Cancel button click to close Export window after completion
  - Uses configured Invoice Watch Folder as export location
  - Clear tooltips after invoice sync completion
- **Dark Mode Consistency**:
  - Converted remaining MsgBox dialogs to DarkMsgBox
  - Improved error messages with dark mode styling

### Bug Fixes
- Fixed script reference (sync_ps_invoice_v2 → sync_ps_invoice)
- Fixed invoice sync early return issue preventing GHL upload
- Fixed export timeout error messages

---

## v2.4.26 (2026-01-31)

### Bug Fixes
- Fixed `DateDiff` function errors - replaced with AHK v1 compatible `EnvSub` for date arithmetic
  - `GetLicenseDaysRemaining()` - license expiry calculation
  - `IsTrialValid()` - trial period validation
  - `CheckMonthlyUpdateAndValidation()` - update check interval

---

## v2.4.25 (2026-01-31)

### New Features
- **DarkMsgBox Function**: Universal dark mode message box with word wrap, multiple button support, checkbox option, timeout, and type-based icons (info, warning, error, question, success)
- **Import/Export Settings**: Export encrypted settings (.skp file) to share between computers, with post-import validation for GHL and license
- **Contact Sheet Setting**: New "Create contact sheet with order" toggle (default ON) in Invoice tab
- **GHL Invoice Warning Dialog**: Dark mode styled warning with Cancel button, warns about automated GHL emails before invoice creation

### UI Improvements
- Dark mode title bar support using DwmSetWindowAttribute
- Fixed bold font inheritance on toggle slider labels throughout Settings GUI
- Shortened "Desktop Shortcut" button text
- Removed non-functional "Auto-fetch client details" setting (reserved for future)

### Bug Fixes
- Fixed duplicate DarkMsgBox function definition error
- Fixed installer referencing non-existent Python executables
- Converted all MsgBox calls to DarkMsgBox for consistent styling

### Technical
- Cleaned up Legacy folder organization for old Python scripts

---

## v2.4.24 (2026-01-31)
- Quick publish with compiled Python scripts
- Installer fixes

## v2.4.22 (2026-01-30)
- GHL invoice sync improvements
- Contact sheet generation

## v2.4.21 (2026-01-30)
- License validation improvements
- Settings persistence fixes

## v2.4.20 (2026-01-29)
- GHL API integration enhancements
- Invoice XML parsing improvements

## v2.4.13 - v2.4.19
- Various bug fixes and stability improvements
- GHL integration refinements

## v2.4.2 (2026-01-15)
- Windows installer with license agreement (EULA)
- Inno Setup integration

## v2.4.1 (2026-01-10)
- EXE-only releases (no Python source scripts exposed)
- Compiled Python executables

## v2.4.0 (2026-01-08)
- Major GHL integration release
- Client lookup from Chrome URLs
- Auto-populate ProSelect from GHL data
- Invoice sync to GHL with media upload

## v2.1.0 (2025-12-01)
- Initial GHL integration
- Payment plan calculator
- ProSelect automation basics

# SideKick_PS Changelog

<!--
AI INSTRUCTIONS - When publishing a new version:
1. Update this CHANGELOG.md with the new version entry (technical details OK)
2. Update version.json in this repo with:
   - "version": new version number
   - "build_date": current date (YYYY-MM-DD)
   - "release_notes": brief user-friendly summary
   - Add new entry to "versions" array with user-friendly changelog
   NOTE: version.json changelog should be USER-FRIENDLY (no file names, 
   function names, or technical details - users don't care about 
   "sync_ps_invoice.py" or "cyclomatic complexity")
3. Commit and push both files to Git
4. Run the build script to compile and create installer
-->

## v2.4.53 (2026-02-01)

### New Features
- **Client ID in Album Name**: When importing a GHL client, the album is now saved with the Client ID appended
  - Format: `LastName_ClientID` for new albums
  - Existing albums get `_ClientID` appended if not already present
- **Open GHL Client Button**: New toolbar button (🌐) opens the client's GHL contact page in browser
  - Now checks ProSelect window title first for Client ID (from album name)
  - Falls back to checking most recent XML export if not found in title
  - Quick access to client details without searching in GHL

### Bug Fixes
- **Critical: Payment Recording Wrong Amount**: Fixed GHL invoice payments being recorded at 1/100th of actual value
  - Was sending amounts in pounds instead of pence to GHL API
  - e.g., £850 payment was recorded as £8.50
  - Now correctly converts payment amounts to pence for GHL API consistency

---

## v2.4.50 (2026-02-01)

### Bug Fixes
- **Critical: INI File Path**: Fixed compiled EXE looking for INI in wrong folder
  - Was looking in `C:\Program Files (x86)\` instead of `C:\Program Files (x86)\SideKick_PS\`
  - Affected `sync_ps_invoice.exe` and `create_ghl_contactsheet.exe`
- **Permission Denied Error**: Python scripts now write output files to `%APPDATA%\SideKick_PS\`
  - Fixes "Permission denied" error when running from Program Files
  - Affected: result JSON files, trial data files
- **Double Export Click**: Removed redundant second click on Export Now button
- **Send Logs Button**: Now uses built-in Gist token (no configuration required)
- **Start on Boot**: Toggle now updates Windows Registry immediately when clicked

### Technical
- `sys.frozen` detection for PyInstaller EXE path handling
- `_get_output_dir()` helper writes to APPDATA with TEMP fallback
- Registry update in `ToggleClick_StartOnBoot` handler

---

## v2.4.45 (2026-02-01)

### Improvements
- **Export Orders Menu Reliability**: Multi-method approach for opening Export Orders dialog
  - Method 1: `WinMenuSelectItem` - most reliable, uses Windows menu system directly
  - Method 2: `SendInput` with longer delays as fallback
  - Method 3: `Send` with extended delays as last resort
  - Added `WinWaitActive` to ensure ProSelect is fully active before menu navigation
  - Extended dialog wait timeout from 3s to 5s
  - Better error message with manual instructions if automation fails

### Bug Fixes
- **File Watcher Timing**: Added `ExportInProgress` flag to prevent "New Invoice XML" popup from appearing during export automation
  - Flag suspends file watcher at export start
  - Flag is reset at all exit points (success, error, timeout)

### Technical
- `WinMenuSelectItem` for reliable menu item selection
- `ExportInProgress` global flag coordinates export automation with file watcher

---

## v2.4.44 (2026-02-01)

### New Features
- **Enable/Disable SD Card Feature**: Master toggle to show/hide SD card toolbar icon
  - When disabled, all File Management controls are grayed out
  - Auto-Detect SD Cards is automatically disabled when feature is off
  - Toolbar dynamically resizes (3 buttons when disabled, 4 when enabled)

### Improvements
- **Export Orders Reliability**: Improved button click reliability for ProSelect Export Orders
  - Uses window handle (HWND) for more reliable control targeting
  - Sends BM_CLICK message as fallback method
  - Added NA (No Activate) option to prevent focus issues
- **Silent Release Cleanup**: GitHub release cleanup now runs silently (only shows errors)
- **File Management Visual Feedback**: All labels and section headers gray out when disabled

### Technical
- `UpdateFilesControlsState()` function enables/disables all File Management controls
- `ControlClick` with `ahk_id` for reliable ProSelect automation
- Cleanup batch runs with `Hide` flag, no pause required

---

## v2.4.43 (2026-02-01)

### New Features
- **SideKick_LB Integration**: Sync settings from LB with one click
  - New "Sync from LB" button in File Management tab
  - Compares and syncs Card Path, Download Folder, Archive, Prefix/Suffix, Editor paths
  - Shows differences before syncing with option to apply
- **LB Conflict Detection**: Warns when both LB and PS have SD card auto-detect enabled
  - Offers to disable LB auto-detect to prevent conflicts
- **Dev Reload Hotkey**: Ctrl+Shift+R to reload script (dev mode only)
  - Orange-colored in Hotkeys panel to indicate dev-only feature
  - Only visible/active when running as script (not compiled)

### Improvements
- **Toggle Switches**: Consistent ✓/✗ style across all tabs
- **Settings Persistence**: All File Management settings save immediately on change
- **Settings Hotkey**: Changed default from Ctrl+Shift+S to Ctrl+Shift+W
- **Developer Tab**: Added Reload button, removed unused Git Status section

### Fixes
- **Black Text**: File Management input fields now use black text for visibility

---

## v2.4.33 (2026-02-01)

### Enhancement
- **Download Progress Bar**: Visual feedback when updating or reinstalling SideKick
  - Progress bar appears on About tab during download
  - Real-time percentage display (e.g., "Downloading... 45%")
  - Uses Windows BITS (Background Intelligent Transfer Service) for reliable downloads
  - Progress bar hidden when download completes
  - Button disabled during download to prevent multiple clicks

## v2.4.32 (2026-02-01)

### Major New Feature
- **SD Card Download**: Complete file management workflow ported from SideKick_LB
  - New toolbar button (📥) for quick access to SD card download
  - New **File Management** settings tab with all configuration options
  - Automatic DCIM folder detection on SD cards
  - Multi-card support for shoots spanning multiple cards
  - Auto-rename files with configurable shoot prefix/suffix
  - Year-based shoot numbering option
  - Auto-detect SD card insertion and prompt to download
  - Integration with photo editor launch after download

### Settings Added
- Card Path: SD card/DCIM path configuration
- Download Folder: Temporary download location
- Archive Path: Final archive destination
- Shoot Prefix/Suffix: File naming convention (e.g., P26001P)
- Include Year in Shoot No: Toggle for year-based numbering
- Auto-Rename by Date: Sort and rename files by timestamp
- Open Editor After Download: Launch photo editor when complete
- Auto-Detect SD Cards: Automatic detection when cards inserted

### Technical Details
- Expanded toolbar width from 152px to 203px for 4th button
- Added `CreateFilesPanel()` for File Management settings GUI
- Ported `SearchShootNoInFolder`, `RemoveDir`, `RenameFiles`, `RenumberByDate`
- Ported `Unz()` shell copy function with Windows progress dialog
- Added `checkNewDrives` timer for SD card auto-detection

---

## v2.4.31 (2026-02-01)

### Code Quality Improvements
- **Complexity Refactoring**: Reduced cyclomatic complexity in all Python modules
  - All functions now have complexity ≤ 10 (was up to 54 in some cases)
  - Added 29 new helper functions across 3 files for better maintainability
  - `sync_ps_invoice.py`: 11 new helpers (invoice building, contact updates, CLI)
  - `create_ghl_contactsheet.py`: 6 new helpers (image processing, fonts, logo)
  - `validate_license.py`: 12 new helpers (API handling, trial management, CLI)

### Refactored Functions
- **sync_ps_invoice.py**:
  - `create_ghl_invoice` 54→10, `main` 15→6, `update_ghl_contact` 15→8
  - `_build_product_invoice_items` 13→6, `_create_and_upload_contact_sheet` 11→5
- **create_ghl_contactsheet.py**:
  - `_build_image_labels` 18→5, `create_contact_sheet_jpg` 12→7
  - `_parse_ini_sections` 11→7
- **validate_license.py**:
  - `activate_license` 16→7, `validate_license` 13→8
  - `get_trial_info` 11→6, `main` 11→5

---

## v2.4.30 (2026-01-31)

### New Features
- **Remote Debug Logging**: Added GitHub Gist upload for debug logs
  - Logs automatically uploaded to private Gist when auto-send enabled
  - Logs organized by GHL Location ID in subfolders
  - Log header includes: Computer Name, Windows User, Location ID, Python Version
- **Send Logs UI**: Added debug log controls to About tab
  - "Send Logs" button to manually upload all log files
  - "Auto-send" toggle to enable/disable automatic log upload
  - Auto-send ON by default for new installations

### Improvements
- **Verbose Logging**: Comprehensive debug logging throughout sync process
  - XML parsing: file stats, all extracted fields, line items
  - Contact search: query, results, match details
  - Contact update: before/after field values, API responses
  - Invoice creation: all invoice fields, payment schedules, API responses
  - Media uploads: file paths, sizes, request params, response codes
  - Contact sheet: all workflow steps with success/failure details

---

## v2.4.29 (2026-01-31)

### Bug Fixes
- **PayPlan Calculator Button**: Fixed button click not opening calculator
  - Timer was hiding button when focus shifted to PP GUI on click
  - Now checks if PP GUI is active before hiding
- **Payment Type Selection**: Fixed wrong payment type being applied
  - Was sending only first letter (e.g., "D" selected "Discount" instead of "Direct Debit")
  - Now uses `Control, ChooseString` for exact payment type matching
- **Invoice Sync Script**: Fixed crash on compiled .exe
  - `sys.stdout.reconfigure()` failed when stdout is None (hidden console)
  - Added null checks for stdout/stderr before reconfiguring
- **Client ID Validation**: Fixed false positive on missing Client ID
  - Was checking for `<ClientId>` but XML uses `<Client_ID>` (with underscore)
- **Build Script**: Fixed missing sync_ps_invoice.exe in releases
  - Build script was looking for `sync_ps_invoice_v2` (old filename)
  - Updated to compile `sync_ps_invoice` and `create_ghl_contactsheet`

### Improvements
- **Quick Publish**: Removed manual pauses from batch files
  - Git push and GitHub release now run hidden with auto-timeouts
  - No longer requires pressing Enter to continue
- **Safety Check**: Added Client ID validation before invoice sync
  - Prevents upload attempts when order not linked to GHL contact
- **GuiSetup() Function**: Fixed global variable scope for PayMonthL
  - Month dropdown now correctly populated in PayPlan calculator

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

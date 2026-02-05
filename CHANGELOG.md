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
4. ask developer to Run the build script to compile and create installer
-->

## v2.4.70 (2026-02-05)

### Improvements
- **Invoice Names Updated**: Invoice name now shows "Client Name - ShootNo" format
  - Removed "ProSelect" prefix for cleaner invoice appearance
  - Payment plan invoices also use the new naming format

- **Full Customer Details on Invoices**: Invoices now include complete customer information
  - Phone number included when available
  - Full address (street, city, state, zip, country) added to invoice
  - Auto-fetches missing contact details from GHL if not in ProSelect

- **Opportunity Tags Handling**: Loading tags now handles empty state gracefully
  - Shows helpful message when no opportunity tags exist yet
  - Fixed HTTP 201 being incorrectly treated as an error

### Bug Fixes
- **Toolbar Position Fixed**: Toolbar no longer follows Client Setup dialog
  - Toolbar stays on main ProSelect window when dialogs open

## v2.4.69 (2026-02-05)

### Bug Fixes
- **Invoice Creation Fixed**: Fixed GHL API error 422 when creating invoices
  - Business address format now matches GHL API requirements
  - Invoices should now create successfully on all accounts

- **Auto-Repair Corrupted Settings**: Script automatically fixes corrupted INI files
  - Fixes multi-line PaymentTypes issue that broke config parsing
  - No user action required - repairs automatically on next sync

### Improvements
- **Build Script Auto-Version**: Build script now auto-reads version from version.json
  - No longer requires manual `-Version` parameter when run from terminal

## v2.4.68 (2026-02-05)

### Improvements
- **Activity Logs on Every Sync**: Auto-send logs now uploads after every sync
  - Previously only sent on errors, now sends on success too
  - Helps track successful syncs and diagnose issues proactively
  - Renamed "Auto-send logs on error" to "Auto-send activity logs"

- **Quick Publish Force Rebuild**: Publish button now always recompiles Python scripts
  - Added -ForceRebuild flag to bypass caching
  - Ensures all code changes are included in new releases

## v2.4.66 (2026-02-05)

### Bug Fixes
- **Invoice Now Visible in GHL**: Fixed critical bug where invoices were created as drafts
  - Invoices were being created but not published, making them invisible in GHL
  - Added API call to send/publish invoice after creation
  - Invoices now appear in GHL Payments → Invoices immediately

### Improvements
- **Toolbar Icon Color Picker**: Added Windows color picker for custom icon colors
  - Pick any custom color instead of just White/Black/Yellow presets
  - Color preview swatch shows current selection
  - Custom colors saved to INI and persist across sessions

## v2.4.65 (2026-02-05)

### New Features
- **Room Capture Button**: New camera icon on toolbar captures the room view and saves as JPG
  - Automatically names file as `{albumname}-room1.jpg`, incrementing for multiple captures
  - Auto-copies image path to clipboard
  - Buttons to Open image or Reveal in Explorer
  - DPI-aware capture area calculation
  - Saves to Documents\ProSelect Room Captures folder

- **Payment Entry Progress Bar**: New visual progress indicator replaces tooltip warning
  - Shows "Payment X of Y" with percentage progress bar
  - Cancel button to stop payment entry mid-process
  - Yellow "HANDS OFF" warning integrated into progress window
  - Works for both ProSelect 2025 and 2022

### Improvements
- **Payment Entry Fix**: First payment now uses the already-open Payline window
  - Prevents extra empty window from remaining open after payment entry
  - Increased button click delays to 2000ms for reliability

- **DarkMsgBox Tooltips**: Added tooltip support to custom message box buttons

---

## v2.4.64 (2026-02-03)

### Improvements
- **Persistent Payment Calculator**: Calculator window no longer disappears when switching to another application
  - Window stays visible until explicitly closed or payments scheduled
  - Can switch between apps and return to continue editing
- **Smart Window Layering**: Calculator stays on top of ProSelect windows but goes behind other applications
  - No longer blocks other apps when multitasking
- **Rounding Option Tooltips**: Added detailed hover tooltip explaining rounding adjustment options
  - White text on radio buttons for better visibility

---

## v2.4.63 (2026-02-03)

### New Features
- **Rounding Option Radio Buttons**: Added radio buttons in Payment Calculator to choose where rounding errors are applied
  - "Downpayment" - adds rounding to the deposit amount
  - "1st Payment" - adds rounding to the first scheduled payment
  - Setting is persistent and syncs with Settings GUI toggle

---

## v2.4.62 (2026-02-03)

### Fixes
- **Payment Entry Window Cleanup**: Fixed issue where 2 payline windows remained open after completing payment entry in ProSelect 2025
  - Added loop to ensure all "Add Payment" windows are closed after payment entry completes
  - Increased delay to 1000ms between cancel clicks for reliability

---

## v2.4.61 (2026-02-03)

### New Features
- **Downpayment Section in PayPlan GUI**: Added dedicated downpayment/deposit fields to the Payment Calculator
  - Amount, Method (dropdown), and Date fields
  - Default method is Credit Card
  - Date picker with dd/MM/yy format
  - If amount entered, adds as first payment line before scheduled payments
  - If left blank, downpayment is skipped
  - Rounding info text shows guidance when there's a rounding difference

### Improvements
- **PayPlan GUI Redesign**: Complete visual overhaul to match Settings GUI style
  - Dark theme (2D2D2D background, orange headers, grey labels)
  - 50% larger window (600x420)
  - Two organized GroupBoxes: "Downpayment / Deposit" and "Scheduled Payments"
  - Start date now defaults to today's day of month (e.g., if today is 4th, defaults to "4th")
  - Buttons moved to right with ✓ and ✗ icons
  - Removed unnecessary labels for cleaner layout

- **DD 4-Day Setup Window**: When Direct Debit or GoCardless DD is selected as pay type, enforces minimum 4-day setup window
  - Automatically adjusts selected day if too soon
  - Flexible matching for any DD-related payment types

- **PayPlan Button Visibility Fix**: Button now properly hides when Add Payment window loses focus
  - Only shows when Add Payment dialog is active

- **Hands Off Warning**: Added tooltip warning during payment line entry
  - Shows "⚠️ HANDS OFF! Do not touch mouse or keyboard while payments are being entered..."
  - Automatically disappears when complete

### Technical
- Removed ToggleDownpayment handler (no checkbox needed)
- Uses `HasDownpayment := (DownpaymentAmount != "" && DownpaymentAmount > 0)` logic
- Added `GetDayNumber()` helper function for DD date validation
- Fixed window focus detection in `KeepPayPlanVisible` timer

---

## v2.4.60 (2026-02-02)

### New Features
- **Rounding in Downpayment Setting**: New toggle in GHL tab to control how rounding errors are handled
  - When ON (default): Rounding difference added to deposit for simpler invoicing
  - When OFF: Creates separate first invoice with adjusted amount
  - Tooltip explains the feature clearly

### Technical
- Added `--rounding-in-deposit` CLI argument to sync_ps_invoice.py
- Added `rounding_in_deposit` parameter through function chain
- Updated `_handle_invoice_success()` to respect the new setting

## v2.4.59 (2026-02-02)

### New Features
- **Recurring Payment Schedules**: Future payments now create automatic recurring invoice schedules in GHL
  - Monthly invoices generated for each future payment date
  - Uses GHL's native scheduling API with `rrule` configuration
  - Schedule count limited to exact number of future payments
  - Starts on first future payment date

### Improvements
- **Full Business Details on Invoices**: Invoices now include complete business information from GHL
  - Business name, address, phone, email
  - Logo URL and website
  - VAT/Tax ID number
  - All pulled automatically from GHL Location Settings

### Technical
- Added `get_business_details()` function to fetch full location data
- Added `create_recurring_invoice_schedule()` function using `/invoices/schedule/` endpoint
- Modified `_handle_invoice_success()` to create recurring schedules for future payments
- Business details cached to reduce API calls
- **Rounding fix**: First payment adjusted to absorb any rounding difference (matches GoCardless/ProSelect)
  - Creates separate schedule for first payment when rounding applies
  - Remaining payments use base equal amount

---

## v2.4.56 (2026-02-02)

### New Features
- **Collect Contact Sheets**: New feature to gather contact sheets into a single folder
  - Toggle in GHL Integration settings to enable/disable
  - Browse button to select destination folder
  - Automatically copies contact sheets to chosen location during invoice sync
  - Useful for batch printing or external delivery

### UI Improvements - Settings Panel Redesign
- **Consistent GroupBox Styling**: All Settings tabs now use professional GroupBox styling
  - General tab: Behavior, Payment Defaults, ProSelect sections
  - GHL Integration tab: Connection, API Configuration, Invoice Sync, Contact Sheet Collection
  - Hotkeys tab: Global Hotkeys, Actions, How to Set Hotkeys
  - File Management tab: SD Card Download, Archive Settings, File Naming, Photo Editor
  - License tab: Status, License Key, Activation Details, Actions
  - About tab: Application, Updates, Support, Diagnostics
  - Developer tab: Status, Build & Release, Quick Actions
- **Verbose Tooltips**: Added detailed tooltips to all interactive controls
  - Explains what each setting does and recommended values
  - Helpful for new users learning the interface
- **Font Normalization**: All fonts now use `s10 Norm` for consistent appearance
  - Removed bold styling that was causing visual inconsistency
- **Aligned Toggle Sliders**: All toggle sliders moved to x630 for uniform layout
- **Control Indentation**: Controls inside GroupBoxes indented to x210

### Technical
- Updated `ShowSettingsTab()` Hide/Show sections for new control names
- Replaced section headers with GroupBox labels for cleaner look
- Panel containers expanded to w510 h680 for consistency

---

## v2.4.55 (2026-02-02)

### New Features
- **Non-Blocking Invoice Sync Progress**: New progress GUI shows real-time sync status
  - Displays current step (Parsing, Creating Contact Sheet, Updating Contact, Creating Invoice)
  - Progress bar with percentage completion
  - Auto-closes after success or shows error message
  - User can continue working while sync runs in background
- **Debug Logging Toggle**: Added user setting in About panel to enable/disable debug logging
  - Logs saved to hidden folder (`%APPDATA%\SideKick_PS\Logs\`)
  - Auto-disables after 24 hours if left on
  - Tooltip explains the feature

### Improvements
- **Single Source of Truth Versioning**: Version now loaded from `version.json` at startup
  - No more manual editing of script version numbers
  - "Update Version" in Developer panel auto-updates both version and build date
  - Prompts to reload script after version change
- **User-Friendly Error Messages**: GHL API errors now show helpful messages instead of raw HTTP errors
  - "Invalid contact ID - client may not be linked to GHL"
  - "Contact not found in GHL - link client first"
  - "API authentication failed - check GHL API key"
  - "Rate limit exceeded - try again in a moment"
- **Progress File Cleanup**: Clears old progress data at start of each sync
- **Removed Folder Watcher Popups**: No more "New Invoice XML" confirmation dialogs
  - Users sync by clicking the toolbar icon when ready
  - Cleaner, less intrusive workflow

### Bug Fixes
- **Build Script Paths**: Fixed doubled folder paths in Developer tools
- **Python Execution**: Fixed background Python process not running via AHK
  - Now uses `start /b` for proper background execution
- **Trial Popup Removed**: Disabled internal trial check (LemonSqueezy handles licensing)

### Technical
- Workspace reorganized: SideKick_PS is now the main working folder
- Moved legacy files to `Legacy/`, `SideKick_LB/`, and `Utils/` folders
- Removed venv dependency for development

---

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

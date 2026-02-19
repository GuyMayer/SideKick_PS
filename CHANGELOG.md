# SideKick_PS Changelog
#Requires AutoHotkey v1.1+
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

## v2.5.31 (2026-02-19)

### New Features
- **Direct PSA File Reading**: Read payment data and thumbnails directly from ProSelect .psa album files (SQLite format)
- **PSA Payment Extraction**: GoCardless payment dialog now reads payments directly from .psa file instead of requiring XML export
- **PSA Thumbnail Extraction**: Contact sheet generation extracts thumbnails from .psa file directly
- **GC Past Payment Detection**: Payment dialog detects past due dates and offers to bump them to future dates
- **GC Dynamic Icon Color**: GoCardless toolbar icon now dynamically matches toolbar icon color scheme
- **Clipboard Helper Functions**: New `ClipboardSafeGet()`, `ClipboardSafeRestore()`, `ClipboardSafeCopy()` functions preserve user clipboard contents

### Bug Fixes
- **GHL Invoice Tax Error**: Fixed HTTP 422 "taxes allowed only on items with price greater than 0" - removed `taxInclusive` field from zero-price items
- **Build Script Missing Icons**: Fixed installer failing due to missing icon files (Icon_GC_32_White.png, etc.)
- **GetAlbumFolder Path**: Fixed Save As dialog returning breadcrumb display names instead of actual path (uses Alt+D trick)
- **Payment Regex Decimals**: Fixed regex to handle decimal payment values (e.g., £91.70 not just whole numbers)
- **GC Search Mandate Dialog**: InputBox now stays on top of other windows
- **GHL Settings Tab Visibility**: Auto-save XML toggle now properly hides when switching to other tabs

### Improvements
- **Weekly Update Checks**: Changed auto-update check frequency from monthly (30 days) to weekly (7 days) for faster bug fixes
- **GHL Settings Panel**: Added Auto-save XML toggle, moved Contact Sheet Collection box up

---

## v2.5.26 (2026-02-18)

### Bug Fixes
- **SMS Templates Argument**: Fixed `--list-sms-templates` missing from compiled exe (was only in development argparse branch)

---

## v2.5.25 (2026-02-18)

### Bug Fixes
- **GoCardless Instalment Amount**: Fixed "parameter incorrectly typed" error - now includes amount for each instalment payment
- **Error Dialog Truncation**: DarkMsgBox now auto-calculates height for long/wrapped messages
- **Toolbar Background Persistence**: Saves last known toolbar background color to INI for reload

### Improvements
- **Clickable Mandate List**: "Mandates Without Plans" now uses ListBox with clickable rows instead of selectable text
- **Album Search**: GC_FindAlbumFromList now searches using both job number AND surname for better matching
- **OpenPSAFolderInProSelect**: Fixed folder navigation using ControlSetText instead of F4 hotkey

---

## v2.5.24 (2026-02-18)

### New Features
- **Use Another Mandate**: When no mandate found, search by partner's name or email to find their mandate
- **Open GC Button**: Success dialog now has "Open GC" button to view customer in GoCardless dashboard

### Improvements
- **Dark No-Mandate Dialog**: "No mandate found" dialog now uses dark theme with Send Request/Use Another/Cancel buttons
- **Larger Payment Plan Dialog**: Taller window (545px) with more space for payment list and detected info
- **GoCardless Rounding**: Instalment schedules now send total_amount - GoCardless handles per-payment rounding

### Bug Fixes
- **JSON day_of_month Error**: Fixed invalid JSON when day had leading zero (e.g., 01 → 1)
- **Instalment Schedule Not Created**: Fixed detection of total_amount parameter in payment plan creation

---

## v2.5.23 (2026-02-18)

### New Features
- **GoCardless Setup Wizard**: Step-by-step guide for first-time GoCardless setup - walks through environment selection, token creation, and connection testing

### Security
- **CRITICAL: API Token Exposure Fix**: Removed GoCardless token fields from INI file - tokens now stored ONLY in `%APPDATA%\SideKick_PS\credentials.json`
- **Removed INI Fallback**: GoCardless tokens no longer read from INI file (prevents accidental exposure via git)
- **Updated .gitignore**: All `.ini` files now excluded from repository

### Improvements
- **No Plans List**: Now excludes mandates that EVER had subscriptions (including finished ones), not just active - finds mandates where no payment was ever set up
- **Real-time Progress Bar**: Mandate fetch progress now updates live during API calls (same pattern as update download)
- **Toolbar Background Fix**: Added forced redraw on first launch to fix background color rendering

### Bug Fixes
- **Progress Bar Not Updating**: Fixed progress bar freezing during mandate fetch (was blocking on RunWait)
- **Toolbar Background on Startup**: Added delayed background re-sample 2s after first show to fix color when ProSelect title bar isn't fully rendered during initial sample
- **Existing Plans Display**: Expanded status filter to include 'completed' and 'finished' plans so all historical payment plans show in mandate dialog

---

## v2.5.22 (2026-02-17)

### New Features
- **GoCardless Integration**: New toolbar button for Direct Debit mandate management
- **GoCardless Settings Tab**: Configure API token, environment, and notification templates
- **Mandate Checking**: Click GC button to check if client has existing mandate
- **Send Mandate Request**: Create billing request and send setup link via GHL email/SMS
- **Secure Token Storage**: GoCardless API token stored in credentials.json (base64 encoded)
- **Payment Plan Dialog**: Create GoCardless instalment schedules with pre-populated values from PayPlan
- **DD Payment Filtering**: Payment plan dialog auto-filters for DD payments only (GoCardless, Direct Debit, BACS) - skips Card, Cash, Cheque, etc.
- **Duplicate Plan Names**: Automatically adds -1, -2 suffix when creating multiple plans for the same shoot
- **SMS Template Refresh**: Separate SMS template fetch from GHL (email and SMS templates now independent)
- **Existing Plans Display**: Shows existing instalment schedules and one-off payments when checking mandate
- **One-Off Payments**: Lists one-off payments alongside instalment schedules for complete payment history
- **Single Payment Mode**: Payment dialog now supports creating individual one-off payments matching ProSelect PayPlan dates
- **List Empty Mandates**: New button in GC settings to list all mandates without payment plans (for follow-up)

### Improvements
- **Instalment Schedules**: Uses GoCardless instalment_schedules API (not subscriptions) for proper payment plan support
- **Persistent Templates**: Email/SMS template selections now save immediately on change
- **Room Capture Templates**: Email template selection now remembered across sessions
- **SELECT Option**: Template dropdowns include "SELECT" to skip that notification type
- **Duplicate Check**: Warns before creating plan with same name as existing schedule

### Bug Fixes
- **Live Environment Flag**: Fixed GoCardless API calls not passing --live flag (was always using sandbox)
- **SMS Template Cache**: Fixed SMS dropdown using email template cache instead of SMS templates
- **Template Dropdown Default**: Shows "SELECT" when no templates loaded
- **Template Persistence**: Fixed GC email/SMS templates being reset when Settings dialog opened

---

## v2.5.18 (2026-02-17)

### Bug Fixes
- **CRITICAL: GHL Product Lookup Crash**: Fixed `LOCATION_ID` undefined at module level - fetch_ghl_products() was failing silently
- **Config Not Loading API Key**: Now checks `credentials.json` in AppData first (was only checking INI files)
- **UTF-8 BOM Handling**: credentials.json now read with `utf-8-sig` encoding to handle Windows BOM
- **Duplicate Credentials Filenames**: Now supports both `credentials.json` and `ghl_credentials.json`
- **IniWrite Syntax Error**: Fixed empty first parameter in AHK IniWrite call

### Improvements
- **Clean Invoice Display**: Clear ProSelect description when GHL product found by SKU (prevents duplicate info)
- **Tax on Invoice Items**: Add taxes array to GHL line items when item has tax_rate > 0

---

## v2.5.15 (2026-02-17)

### Bug Fixes
- **GHL Product SKU Lookup**: Now fetches price-level SKUs (GHL stores SKUs on prices, not just product variants)

---

## v2.5.14 (2026-02-17)

### Bug Fixes
- **GHL Zero Quantity Items**: Skip bundled items with qty=0 (e.g., Mat/Frame included free with main product) - GHL API requires qty >= 0.1

---

## v2.5.13 (2026-02-17)

### New Features
- **GHL Product Lookup**: Invoice items with Product_Code (SKU) now look up product names from GHL, falls back to ProSelect description if not found

### Improvements
- **Toolbar Solid Buttons**: Buttons now fill toolbar completely - no transparent gaps blocking clicks
- **Auto-Blend Default ON**: Toolbar auto-blend background now enabled by default for new installs
- **Settings Toggle Style**: Auto-blend toggle now uses consistent ✓/✗ style

---

## v2.5.12 (2026-02-17)

### Bug Fixes
- **GHL Invoice Tax**: Use `taxInclusive` boolean flag per official GHL API docs (fixes mixed VAT rates)

---

## v2.5.11 (2026-02-17)

### Bug Fixes
- **CRITICAL: GHL Invoice Tax Error**: Fixed HTTP 422 - skip taxes on $0 items (fixes Andrew's Risbey invoice)

---

## v2.5.10 (2026-02-17)

### New Features
- **Auto-Blend Toolbar**: Toolbar samples screen behind it and matches background color for seamless integration
- **Auto-Blend Setting**: Enable/disable in Settings > Hotkeys > Toolbar Appearance
- **ESC to Cancel Export**: Press ESC during invoice export to cancel with confirmation dialog

### Bug Fixes
- **GHL Invoice Tax Error**: Fixed HTTP 422 error - skip taxes on $0 items (GHL API rejects taxes on zero-price items)
- **Toolbar Click-Through**: Fixed issue where clicking transparent parts of toolbar buttons didn't register (TransColor changed to 010101)

### Improvements
- **Seamless Integration**: Toolbar blends with ProSelect title bar when auto-blend enabled

---

## v2.5.9 (2026-02-17)

### Bug Fixes
- **GHL Invoice Creation**: Fixed failure when Product_Name was empty (Wall Groupings, Collections)
- **Rich Item Names**: Invoice items now combine Template + Description for better display

### New Features
- **Per-Line Tax**: Each invoice item now includes tax info (20% VAT with inclusive/exclusive flag)
- **Error Logging**: Always-on error logging (sync_error_*.log) for critical failures
- **Remote Diagnostics**: Error logs auto-upload to Gist for remote troubleshooting

### Improvements
- **Detailed Error Context**: Better error messages for GHL API failures, XML parsing, and missing contact ID

---

## v2.5.8 (2026-02-17)

### New Features
- **Setup Wizard Auto-Refresh**: Wizard now auto-loads GHL tags, opportunity tags, and email templates after setup
- **ProSelect Auto-Launch**: Wizard offers to launch ProSelect and waits up to 60 seconds for print template loading
- **Manual Button**: Added "📖 Manual" button in General Settings to open online documentation
- **Docs Button**: Added documentation button in About tab linking to field mapping docs
- **Website SEO**: Added sitemap.xml and robots.txt for search engine indexing
- **JSON-LD Schema**: Added SoftwareApplication and FAQPage schema for Google and AI search
- **Social Meta Tags**: Added Open Graph and Twitter Card meta tags for social sharing

### Improvements
- **App Settings Simplified**: Removed ProSelect version display from General Settings group box
- **Silent Refresh Functions**: Tags and templates load silently during wizard (no dialog interruptions)

---

## v2.5.7 (2026-02-17)

### New Features
- **SKU Field Extraction**: Product_Code extracted from ProSelect XML for product matching
- **Tax Details**: Full tax info extracted (tax_label, tax_rate, price_includes_tax)
- **Product Line Fields**: Product line code and name for categorization
- **Size/Template Fields**: Size and Template_Name for product identification
- **Item ID Tracking**: ProSelect item ID preserved for traceability

### Improvements
- **No String Merging**: All ProSelect fields passed through unchanged to GHL
- **Xero/QuickBooks Ready**: Invoice items include all fields needed for accounting sync

---

## v2.5.6 (2026-02-12)

### New Features
- **Print to PDF Calibration**: First-time calibration prompts user to click Print button, stores position relative to window edges
- **Recalibration Shortcut**: Ctrl+Shift+Click PDF icon to recalibrate Print button position
- **Transparent Toolbar**: Toolbar background now transparent, showing only colored buttons
- **Braille Grab Handle**: New ⣿ grab handle icon with solid dark background for easy dragging
- **Simple Toolbar Drag**: Click and drag grab handle to reposition (no Ctrl required)
- **Flexible Y Positioning**: Toolbar can now be positioned above title bar area (negative Y offset allowed)

### Improvements
- **Calibration Prompt**: Yellow centered GUI with clear instructions explaining why calibration is needed
- **PDF Filename Cleaning**: Removes "copy" text and replaces spaces with underscores
- **Copy Folder Validation**: Skips copy if destination drive unavailable instead of failing

### Bug Fixes
- **GHL API Compatibility**: Updated Python scripts to use new GHL API endpoint for PIT token support
- **Secure Credentials**: API keys removed from INI files, stored only in credentials.json

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

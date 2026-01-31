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

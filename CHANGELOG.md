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

NOTE: SideKick_PS now includes SideKick_GC (GoCardless) as a unified package.
SideKick_GC changes are tracked here alongside SideKick_PS from v2.5.53 onward.
SideKick_GC can also run independently — its own CHANGELOG.md covers standalone releases.
-->

## v3.0.9 (2026-03-19)

### Fixes
- **GoCardless / Cardly "No Client Found" when Mirror window is active**: `WinGetTitle, psTitle, ahk_exe ProSelect.exe` can return a ProSelect sub-window title (e.g. "Mirror") instead of the main album window title when that sub-window has focus. The regex extraction then finds no `_ID` segment and the contact-ID lookup fails entirely. Fixed by adding a fast PSA-filename extraction step (via `SplitPath` on the `GetAlbumPath()` result) as the primary fallback in both `Toolbar_GoCardless:` and `Toolbar_Cardly:` — the PSA filename already contains the GHL ID and does not depend on the ProSelect window title at all. The slow SQLite `<clientCode>` lookup is retained as a final fallback. Cardly now also logs `albumContactId from psaPath` to the debug log.

---

## v3.0.8 (2026-03-13)

### Fixes
- **Cardly PSA path resolved too late**: `psaPath` was only initialised in the image-folder block, but the client ID SQLite fallback (which runs earlier) had always checked `psaPath != ""` — that condition was never true, so albums without a GHL ID in their filename could never have their contact resolved from the PSA. `GetAlbumPath()` via PSConsole is now called before both the `albumContactId` block and the image-folder block
- **Cardly image folder \u2014 PSConsole promoted to primary source**: ProSelect's window title contains only a filename, not a full path, so `psaPath := albumMatch1` then `FileExist()` immediately failed. PSConsole `getAlbumData` is now the primary source; title parsing is kept as a fallback only
- **Cardly folder-browse default folder**: When no image folder is auto-detected the `FileSelectFolder` dialog now opens pre-navigated to the album directory (derived from PSA path or PSConsole) rather than the system root

### New Features
- **Cardly diagnostic logging**: Every Cardly button press now writes a structured trace to the SideKick debug log — ProSelect title, `GetAlbumPath()` result, `albumContactId`, `orderExportsDir`, shoot number, GHL ID, resolved `imageFolder`, and `noAlbumMode` flag

---

## v3.0.7 (2026-03-13)

### Fixes
- **GoCardless stale client data**: `Toolbar_GoCardless:` was reusing `GHL_ContactData` from a previous album session without checking whether it matched the current album — if you clicked the GoCardless button after switching clients, it either used the wrong mandate or threw "No Client Found". Now always resolves the client ID from the album title / PSA file first, and re-fetches from GHL if the cached contact doesn't match (mirrors the existing Cardly / print path behaviour)
- **GoCardless duplicate payment on delayed submission**: When a payment plan was set up in ProSelect but GoCardless submission was delayed by several days, the instalment schedule dates could fall inside the BACS lead-time window, causing a double-charge on the nearest valid date. The CLI now detects stale dates before creating any plan and emits `DATES_STALE` so SideKick_PS can offer the user a one-month date bump — same amounts, same day-of-month, just one month later (preserving client affordability)
- **`--bump-months N` CLI flag (SideKick_GC v1.2.2)**: After user confirms the date bump, SideKick_PS re-submits with shifted paylines and `--bump-months 1` to bypass the stale-date check on the retry

---

## v3.0.6 (2026-03-12)

### Fixes
- **Print-to-PDF printer not switching**: `Control, Choose` only updated the visual selection in the print dialog's printer list — replaced with `ControlSend {Home}/{Down}` keyboard navigation which triggers the dialog's internal WM_NOTIFY so the printer actually changes
- **PDF button printing to paper**: Caused by the above — printer was not switching to "Microsoft Print to PDF" before clicking Print
- **Print button wrong target**: `ControlClick, Button1` was hitting "Preferences" instead of Print — replaced with a loop that reads each button's text via `ControlGetText` and clicks the exact button labelled "&Print"
- **Save As filename wrong**: `SplitPath` was going up two levels from the album folder, picking up a year/date folder name — fixed to use the album folder name directly, with a known-subfolder guard for "Unprocessed" etc.
- **Save As text field not populating**: `ControlSetText` is unreliable in Windows file dialogs — switched to clipboard paste (`Ctrl+A`, `Ctrl+V`)
- **PDF email wrong template used**: `Settings_PDFEmailTemplateID` was unconditionally cleared to `""` in both Settings Apply handlers before re-matching against the cache — if the template cache was empty that session the ID was lost, causing the wrong (or no) template to be sent. Now only re-looked up when the cache is populated; existing saved ID is preserved otherwise

---

## v3.0.5 (2026-03-12)

### New Features
- **Selection-first image loading (Cardly)**: When images are selected in ProSelect, the Cardly preview loads only those selected images instead of the full album — significantly faster startup
- **Duplicate card warning (Cardly)**: Clicking Send now checks for cards sent to the same recipient in the last 7 days and shows a confirmation dialog with order details and a link to the Cardly orders page
- **GHL note on card send (Cardly)**: A note is automatically added to the GHL contact after a card is successfully sent, including the recipient name and message body

### Fixes
- **False "card sent" toast (Cardly)**: Cancelling the Cardly preview no longer shows a "card sent" system notification — replaced unreliable AHK exit code check with a signal file approach

---

## v3.0.4 (2026-03-11)

### New Features
- **Auto name-fallback for GoCardless**: When the client's email doesn't match a GoCardless customer, SideKick automatically retries by name. If a mandate is found under a different email, a "Same Client?" confirmation dialog shows both GHL and GoCardless details side-by-side — choose Yes to proceed, No to search manually, or Cancel
- **Single payment support**: GoCardless DD payments with only 1 payment now use a one-off `create_payment` instead of an instalment schedule with count=1

### Fixes
- **Name-fallback field trimming**: Pipe-delimited fields from the name-fallback CLI output are now trimmed — fixes empty/corrupted command arguments caused by trailing whitespace

### SideKick_GC v1.2.1
- **Single payment via `create_payment`**: Silent mode with 1 payline creates a one-off payment instead of an instalment schedule
- **`--check-mandate-by-name` output**: Includes customer name and email in the response for the name-fallback confirmation dialog

---

## v3.0.3 (2026-03-09)

### New Features
- **Email PDF toolbar button**: New toolbar button emails invoice PDF to client via GHL email template
- **Email PDF settings**: GHL email template selector in Print tab + toggle in Toolbar settings tab
- **Email PDF print-then-email flow**: Follows the same Print-to-PDF procedure (print → save → copy) then emails the generated PDF automatically

### Fixes
- **Email PDF template persistence**: Opening/closing Settings no longer wipes the saved PDF email template when the template cache is empty
- **Toolbar settings show/hide**: Email PDF toggle now properly hidden/shown when switching settings tabs

---

## v3.0.2 (2026-03-09)

### New Features
- **Silent GoCardless plan creation**: When all payment data is available (mandate + paylines from album), creates the GoCardless instalment schedule silently via CLI — no GUI window opened
- **Auto-detect silent mode**: `GC_ShowPayPlanDialog` reads payment data from the .psa file when PayPlanLine globals are empty (toolbar/search flow), and goes silent when mandate ID and DD paylines are both available
- **GoCardless plan cancellation on Replace**: Cancels active instalment schedules, subscriptions, and pending one-off payments on the mandate before creating a new plan
- **Replace PayPlan button**: Mandate dialogs show "Replace PayPlan" when existing plans are detected, "Add PayPlan" when none

### Fixes
- **PayPlan .psa injection newline bug**: JSON amount parser now stops at `\n`/`\r` and trims whitespace — fixes broken `write_psa_payments` args from pretty-printed result JSON
- **Pending deposit not cancelled**: `cancel_mandate_plans` now cancels pending one-off payments (deposits) alongside instalment schedules and subscriptions

### SideKick_GC v1.2.0
- **`--silent` CLI flag**: Create payment plans headlessly — requires `--mandate-id`, `--paylines`, `--plan-name`; writes result file and exits without GUI
- **`--cancel-plans` CLI command**: Cancel all active plans on a mandate (subscriptions, instalments, and pending one-off payments)
- **`cancel_mandate_plans()` API**: Iterates all plans on a mandate and cancels active ones
- **`cancel_payment()` API**: Cancel individual pending payments

---

## v3.0.1 (2026-03-09)

### New Features
- **Multi-client PayPlan group detection**: Automatically targets the correct client in multi-group ProSelect albums by matching the PayPlan balance against each group's order total
- **Ambiguous balance prompt**: When multiple groups share the same balance, a dialog lets the user pick the correct client by name
- **Existing PayPlan detection**: Checks for existing payments before writing — offers Replace (delete old + write new), Add (append), or Cancel
- **PayPlan success dialog**: Shows payment count on success, confirms old plan removal when Replace was used

### Fixes
- **Toolbar multi-monitor positioning**: Toolbar now tracks the last active ProSelect window instead of picking the largest — fixes wrong-monitor placement when multiple PS windows exist
- **Toolbar dialog hiding**: Toolbar hides when ProSelect dialogs (Client Setup, Print, etc.) are the active window
- **Toolbar drag persistence**: Deferred toolbar rebuild after drag prevents AHK v1 g-label thread blocking on subsequent drags
- **Toolbar background sampling**: Uses tracked ProSelect window for correct screen color sampling on multi-monitor setups

### Improvements
- **GoCardless prompt removed**: PayPlan flow now shows a success dialog instead of auto-launching SideKick_GC
- **write_psa_payments --clear**: Scoped to target group only in multi-client albums
- **read_psa_payments --group N**: Read payments from a specific client group

---

## v3.0.0 (2026-03-05)

### SideKick_GC v1.1.1 — Unified with SideKick_PS
SideKick_GC is now included in the SideKick_PS package. GC can still run as an independent
standalone application, but from this version onward all GC changes are also tracked here.

#### New Features
- **Close to Tray option**: "Close to system tray" checkbox in GC Settings — when enabled, X hides to system tray; when disabled (default), X minimises to taskbar
- **Toast on Mandate Cancellation**: "Show Windows notification on mandate cancellation" checkbox — displays a Windows toast when polling detects bank-cancelled mandates (enabled by default)
- **Exit Program button**: Red "⏻ Exit" button in GC Settings to fully quit the application, with a confirmation warning if notification polling is active
- **Polling-active exit warning**: Exiting via Settings or tray menu warns if polling is running — reminds that SideKick needs to stay in the background for polling to work

#### Improvements
- **X button behaviour**: Clicking X now minimises to taskbar (or hides to tray if enabled) — the app always stays running
- **Desktop Shortcut button**: Renamed with the SideKick_GC app icon instead of emoji
- **Smaller checkboxes & radio buttons**: Reduced indicator size and font for a cleaner, more compact look
- **Settings layout**: Bottom-justified Desktop Shortcut and Exit buttons on the same row with matching height

---

## v2.5.52 (2026-03-04)

### New Features
- **Cardly Receiving Date**: Schedule card arrival for a specific date — dropdown with ASAP (default), Birthday, Shoot Anniversary, and any date-type GHL custom fields. Cardly calculates dispatch backward from the requested arrival date.
- **Cardly no-album mode**: Launch Cardly without a ProSelect album open — skips album-dependent steps and shows a folder picker to select images manually. Requires a GHL client to be loaded first.
- **Receiving Date refresh button**: Fetches all date-type custom fields from the GHL contact record and adds them to the dropdown.
- **Birthday always visible**: Birthday entry always appears in the Receiving Date dropdown — shows the date from GHL or "Unknown" if not on file.
- **Shoot Anniversary**: Session date fields auto-calculate +1 year for the anniversary.

### Improvements
- **Wedding → WD**: Wedding abbreviated to WD in date labels for compact dropdown display.
- **Dropdown scroll**: Receiving Date dropdown limited to 6 visible rows with scrollbar for longer lists.

### Bug Fixes
- **Loader animation freeze**: Added `SetWinDelay, -1` to CardlyLoader — AHK's default 100ms delay on every `WinExist()` call was blocking the animation thread.
- **Loader timer collision**: Merged two separate timers (AnimateBar + CheckDone) into a single `Tick` timer with `Critical` flag — exit checks run every 6th tick to keep bar smooth.
- **Loader border & encoding**: Added 1px border to loading GUI, removed emoji from title text, saved with UTF-8 BOM for AHK v1 compatibility.

## v2.5.51 (2026-03-04)

### Bug Fixes
- **GoCardless RunCmdToFile migration**: All 6 `RunCaptureOutput` callers (mandate check, connection test, wizard test, billing request, create payment, list plans) switched to proven `RunCmdToFile` — eliminates the `RunCaptureOutput ERROR: 1` exception that caused empty output.
- **Cardly preview unified CLI**: Cardly button used `GetScriptPath` which returned the old individual `_cpg.exe` (missing in unified build). Now uses `GetScriptCommand` which routes through `SideKick_PS_CLI.exe cardly-preview`.
- **Write PSA payments unified CLI**: Payment Calculator used `GetScriptPath` + manual `cmd /c` for `write_psa_payments`. Now uses `GetScriptCommand` + `RunCmdToFile`.
- **DevUpdateVersion writes to source**: "Update Version" button was writing `version.json` to the install folder (`Program Files`) instead of the source repo (`C:\Stash`). Same fix applied to QuickPush's `SideKick_PS.ahk` and `version.json` updates.
- **Build --clean removed**: PyInstaller `--clean` flag caused a confirmation prompt that blocked automated builds waiting for keypress. Removed from both unified CLI and individual exe builds.

### New Features
- **Cardly loading GUI**: Animated dark-themed progress bar appears immediately on Cardly button press, with status updates at each preparation step (checking ProSelect, reading images, fetching client, loading message, finding exports, building preview, launching). Stays visible with pulsing animation until the PySide6 preview window appears.

### Improvements
- **No console flash**: Cardly preview exe launched with `Hide` flag and async polling instead of `RunWait` — eliminates the 2-second console window flash.
- **Seamless loading**: Single continuous loading experience from button press to preview window, replacing the old sequence of brief tooltip → console flash → frozen startup.

---

## v2.5.47 (2026-03-04)

### Bug Fixes
- **RunCaptureOutput rewritten**: Used temp `.cmd` file approach instead of `WScript.Shell.Exec(ComSpec /c ...)` — fixes empty stdout when the exe path contains spaces (e.g. `C:\Program Files (x86)\...`). Affected all GoCardless mandate checks, connection tests, and other `RunCaptureOutput` callers.
- **Helper detection for unified build**: Startup helper version check now looks for `SideKick_PS_CLI.exe` when individual `_sps.exe` is absent, eliminating the `WARNING: sync_ps_invoice helper not found!` log entry.
- **Update/resync error display**: Error dialog now shows client name, shoot number, email, album, and order total when an update or resync fails (was previously blank).
- **Invoice update draft pre-check**: When new total < amount already paid, attempts `update_invoice_to_draft()` first to bypass GHL payment restrictions. Error message now includes actual amounts.

### Improvements
- **Unified build priority**: Build script now compiles unified CLI exe first; if successful, skips all 13 individual Python exes (faster builds, smaller installer).
- **Validation error guidance**: Error dialog shows specific fix instructions when "total may be less than amount paid" — suggests Replace, refund in GHL, or re-export.

---

## v2.5.46 (2026-03-04)

### New Features
- **Invoice Update**: Update an existing GHL invoice's line items and amounts in place via `--update-invoice <id>`. Preserves recorded payments, records any new past payments not yet in GHL, and replaces future recurring schedules.
- **Invoice Resync**: Delete old invoice(s) for a shoot and create a fresh one in a single `--resync` operation. Aborts safely if provider payments (GoCardless/Stripe) need manual refund.
- **Payment-Aware Duplicate Prompt**: When a duplicate invoice is detected, a `DarkMsgBox` with four buttons replaces the old Yes/No MsgBox:
  - **Replace** — delete old invoice and resync (default when no payments)
  - **Update** — update items in place (default when payments exist)
  - **New** — create another invoice alongside existing
  - **Cancel** — do nothing
- **Shoot-Scoped Deletion**: New `delete_shoot_invoices()` function targets only invoices matching the shoot number, not all client invoices

### Improvements
- **Duplicate Check `amount_paid`**: `check_existing_invoice()` now returns `amount_paid` so AHK can show payment status and choose the right default action
- **Update Payment Diffing**: Compares XML past payment total vs GHL `amountPaid` and only records the difference — no duplicate payment records
- **Update Schedule Replacement**: Cancels existing recurring schedules matching the shoot, then creates new ones for remaining future payments (with rounding-in-deposit support)

---

## v2.5.45 (2026-03-04)

### Bug Fixes
- **Stale Mandates 'script not found'**: Fixed `gocardless_api script not found` error when Stale Mandates GUI is launched via the unified `SideKick_PS_CLI.exe`. The individual `_gca.exe` no longer ships — `_find_gc_script()` now discovers `SideKick_PS_CLI.exe` and routes GoCardless API calls through the `gocardless` subcommand automatically. Legacy standalone exe/py fallback preserved for backwards compatibility and dev mode.

---

## v2.5.44 (2026-03-04)

### New Features
- **SideKick_GC Payments Tab**: New "Payments" tab in SideKick_GC for creating single payments and recurring subscriptions — mirrors GoCardless dashboard functionality
- **Single Payments via GC**: Create one-off payments against an active mandate with amount, charge date, description, reference, and metadata
- **Subscriptions via GC**: Create recurring subscriptions with configurable frequency (weekly/monthly/yearly), interval, day-of-month, and end condition (indefinite / fixed count / end date)
- **Inline Name Prefix**: Plan name and subscription name inputs now show the Statement Label prefix inline as a non-editable label — user sees the full bank statement name but can only edit the suffix

### Improvements
- **SideKick_GC v1.1.0**: Subscription API (`create_subscription`, `cancel_subscription`), new worker threads, mandate ID forwarding to Payments tab
- **Python Package v1.1.0**: `sidekick_ps` package version bumped to 1.1.0

---

## v2.5.43 (2026-03-02)

### New Features
- **Stale Mandates Qt6 GUI**: New standalone PySide6 dark-themed window for finding and cancelling expired GoCardless mandates. Sortable table with checkboxes, last payment date, total collected, customer name, email, and mandate ID. Batch cancel with two-stage safety warnings (irreversible). Singleton — prevents duplicate windows.
- **Stale Mandates Button**: New button in GoCardless settings panel launches the Qt6 GUI
- **Toolbar Auto-Scale**: New checkbox in Toolbar settings auto-links toolbar size to ProSelect window width using `psW / (1920 × DPI_Scale)` with 5% quantization and 800ms cooldown
- **Toolbar Manual Scale**: New dropdown (50%–100%) for manually sizing the toolbar on smaller screens

### Improvements
- **cmd.exe Robustness**: `RunCmdToFile()` and `RunCmdToFileAsync()` helpers replace all 17+ vulnerable `%ComSpec% /c` call sites with temp `.cmd` file pattern — safe with spaces and quotes in paths
- **Build Pipeline**: PySide6 auto-installed at build time; `stale_mandates_gui` compiled to `_smg.exe` with `--noconsole`, code-signed, and included in Inno Setup installer

### Bug Fixes
- **GoCardless 'No Plans' Hang**: Fixed cmd.exe quoting issue with paths containing spaces causing the button to hang indefinitely

---

## v2.5.41 (2026-02-28)

### Bug Fixes
- **GoCardless Button No Output**: All CLI Python helper EXEs (`_gca.exe`, `_sps.exe`, `_fgc.exe`, `_ugc.exe`, etc.) were compiled with PyInstaller `--noconsole`, which disconnects stdout. On systems where AHK runs the EXE via `RunWait ... Hide` with no console allocated, `print()` output was silently discarded — causing the GoCardless button to always return "script returned no output". Fixed by compiling CLI scripts with `--console` instead. GUI scripts (`cardly_preview_gui`) remain `--noconsole`.
- **Build Script Console Flag**: `build_and_archive.ps1` now uses a `$guiScripts` list to apply `--noconsole` only to GUI scripts. All other scripts get `--console` so stdout piping works reliably.

---

## v2.5.40 (2026-02-28)

### New Features
- **Review Order Toolbar Button**: New button opens ProSelect Orders > Review Order via `Alt+O` menu keystrokes. Uses Receipt font glyph (U+E762) — no PNG, same icon system as all other buttons.
- **Review Order Settings Toggle**: Clickable icon in Toolbar settings tab (amber background) with INI persistence (`ShowBtn_ReviewOrder`)
- **EXE Code Signing**: All compiled `.exe` files in the Release folder (SideKick_PS.exe + all Python helpers) are now digitally signed before the installer is built
- **RFC 3161 Timestamping**: Signatures use SHA-256 with RFC 3161 timestamp — remains valid after certificate expiry
- **Timestamp Failover**: Tries 3 timestamp servers in sequence (Certum → DigiCert → Sectigo) for reliability
- **Cardly Browse Image Button**: New browse button (📂) in card preview crop controls — select any image from disc, adds to filmstrip and displays it. Opens at the album folder by default.
- **GoCardless Diagnostics**: New `gc_diagnose.bat` and `gc_fix_connection.bat` tools for troubleshooting GoCardless connectivity issues

### Improvements
- **Toolbar Button Position**: Review Order sits to the left of Camera in toolbar and settings tab
- **Settings GroupBox**: Enlarged to accommodate the additional Review Order row
- **Settings Hotkey Default**: Default Settings hotkey changed from `Ctrl+Shift+W` to `Ctrl+Shift+I` to avoid conflicts
- **Hotkey Passthrough**: When ProSelect/SideKick is not the active window, hotkeys are now passed through to the target application instead of being silently consumed
- **Cardly Rotate Button Sizing**: Orientation swap button now uses pixel-based sizing (32×32) for consistent appearance across systems
- **PII Redaction in Logs**: All `debug_log()` and `error_log()` calls now pass data through `_redact_pii()` before writing — emails, names, addresses, and phone numbers are automatically masked. Prevents personal data leaking into Gist-uploaded debug logs.
- **PII Redaction in Console Output**: Status `print()` messages no longer include client emails, names, or addresses — replaced with `[redacted]` or generic descriptions

---

## v2.5.39 (2026-02-27)

### New Features
- **File Browser Dropdown**: Replaced Editor Path text field with auto-detecting dropdown — automatically finds installed Adobe Bridge, Lightroom Classic, Photoshop, and Capture One. Browse button for manual selection.
- **Dynamic Toolbar Icons**: Open Folder toolbar button now shows the selected file browser's icon (Bridge, Lightroom, or Explorer) recolored to match the toolbar icon colour

### Improvements
- **Toolbar Icon Recoloring**: File browser icons use the same white-source → PowerShell recolor pipeline as Photoshop/GC/Cardly icons, updating automatically on toolbar colour change

### Bug Fixes
- **Cardly Orientation Swap API**: Fixed `create_cardly_artwork` using the wrong template ID after flipping between landscape/portrait — `template_id` was passed as `name` parameter instead of `media_id_override`, causing dimension mismatch errors
- **Open Folder Button Visibility**: Fixed Open Folder toolbar icon/label not hiding when switching away from Toolbar settings tab

---

## v2.5.38 (2026-02-27)

### New Features
- **Toolbar Section Separators**: Visual dividers between GHL, Shortcuts, and Services button groups on the floating toolbar — clearer button organisation at a glance
- **GoCardless Auto-Detect on Payment Entry**: After writing DD payments to an album, SideKick detects GoCardless/Direct Debit payment types and offers to create them in GoCardless immediately
- **Settings Export/Import: Sticker Support**: Cardly sticker overlay PNGs are now base64-encoded into the `.skp` export package and restored on import — stickers transfer seamlessly between machines

### Improvements
- **Toolbar Button Order**: Refresh button moved before Sort; buttons logically grouped into GHL → Shortcuts → Services sections
- **PayPlan Window Detection Simplified**: Payline watcher no longer requires the "Add Payment" list window — only the payline entry form ("Date" text) is needed, fixing detection on some ProSelect versions
- **PayPlan Silent Success**: Removed confirmation dialog after successful payment entry — success indicated by sound only, failures still show error dialog
- **Settings Export/Import Summary**: Confirmation dialogs now list toolbar button visibility, Cardly sticker overlays, and GoCardless settings in the package contents
- **Code Signing**: Installer and uninstaller are now digitally signed with Certum code signing certificate (Zoom Studios Ltd)

### Bug Fixes
- **PayPlan EnteringPaylines State**: Fixed `EnteringPaylines` flag not being reset after payment write — previously could block subsequent payment entries until script restart

---

## v2.5.37 (2026-02-27)

### New Features
- **Open Folder Toolbar Button**: New toolbar button opens the album's image source folder (where the original photos reside on disk) rather than the .psa file location
- **GetAlbumSourceFolder()**: Uses PSConsole `getImageData` to extract the actual `shellpath` from the first image element — no Python or SQLite needed

---

## v2.5.36 (2026-02-26)

### New Features
- **Cardly Template Orientation Swap**: Rotate button (⇄) in the card preview GUI switches crop between Landscape and Portrait, automatically using the matched template pair
- **Cardly Orientation Pair Detection**: RefreshCardlyTemplates auto-discovers L↔P template pairs by stripping orientation suffixes and performing case-insensitive base name matching
- **Lead Connector QR Toggle**: New checkbox in GHL settings switches QR code URL between white-label domain (opens browser) and `app.leadconnector.app` (opens LC mobile app)
- **Cardly Sign Up Button**: Added "Sign Up" button in Cardly settings next to Dashboard
- **Cardly Dashboard URL Configurable**: Dashboard URL now editable in Settings instead of hardcoded
- **Direct PSA Payment Writing**: New `write_psa_payments.py` script injects payments directly into .psa SQLite files
- **UpdatePS Payment Flow**: Save album → write payments to PSA → reload album (no XML export needed)

### Improvements
- **Cardly Sticker: Open Folder**: Added "Open Folder..." option to the sticker overlay dropdown — opens the sticker folder in Explorer for quick access to add/remove sticker PNGs
- **Cardly Orientation Pair: API ID Fallback**: Orientation swap now also matches template pairs by Cardly API ID (e.g. `thankyou-photocard-l` ↔ `thankyou-photocard-p`) when display name matching fails
- **GoCardless Always Live**: Removed environment selector from settings and setup wizard (was Sandbox/Live dropdown). Environment is now always "live" — simplifies setup and prevents accidental sandbox usage
- **GoCardless Wizard Simplified**: Reduced setup wizard from 5 steps to 4 by removing the environment selection step
- **Plan Naming: Order Date**: Added "Order Date" field option to GoCardless plan naming dropdown — reads the order date from the .psa album file
- **Plan Naming Format Applied**: Plan naming format from Settings is now used to auto-generate the default plan name in the payment dialog (previously just used the album name)
- **PSConsole saveAlbum**: Replaces Ctrl+S keyboard automation with direct API call (no blind 3-second sleep)
- **PSConsole openAlbum**: Replaces Ctrl+O with direct API call and smart single-PSA file detection
- **Cardly Message Box Height**: Doubled from 4 to 8 lines for longer personalised messages
- **Cardly Multiline Messages**: Full `\n` escape chain across INI → AHK → command line → Python preserves line breaks
- **Cardly Spinner Animation**: Replaced stalling ttk.Progressbar with canvas-based spinning dots animation
- **Card Details Orientation Label**: Size display now shows "Landscape" or "Portrait" next to dimensions
- **GoCardless Crash Handler**: Added top-level exception handler to gocardless_api.py — unhandled errors now print `ERROR|...` to stdout instead of producing silent empty output
- **GoCardless Empty Output Detection**: Test connection and mandate check now detect when the script returns no output and display a specific message about antivirus/exe blocking (previously showed blank error)
- **Cardly Orientation: Trailing Number Tolerance**: API ID matching now strips trailing numeric segments (e.g. `-11482`) before comparing orientation pairs — handles Cardly's version-suffixed template IDs
- **Cardly Preview Window Icon**: All Cardly preview GUI windows (main, progress, success) now show the SideKick icon in the title bar and taskbar instead of the default Python/Tk icon
- **Cardly Preview Threaded Send**: Card sending (image processing, artwork upload, order placement, GHL upload) now runs on a background thread — spinner animation stays smooth instead of freezing during network calls
- **Cardly Orders Button**: Added "Orders" button in Cardly settings tab — opens the Cardly order management page directly
- **PyInstaller Icon**: All compiled Python executables now include the SideKick icon (previously used generic PyInstaller icon)

### Bug Fixes
- **GoCardless Environment Default**: Hardcoded environment to "live" — fixes test connection failure for users with live API tokens (was defaulting to sandbox)
- **GHL Tag Sync**: Fixed INI key mismatch — `Tags` vs `SyncTag` and `OppTags` vs `OpportunityTags` now both supported with fallback
- **Cardly Address Validation**: State/county field no longer required (UK addresses don't have state)
- **Build: Missing Python Scripts**: Added `write_psa_payments`, `read_psa_payments`, `read_psa_images`, and `create_ghl_contactsheet` to build pipeline, installer, and AHK script map
- **Build: write_psa_payments Hardcoded Path**: Now uses `GetScriptPath()` instead of hardcoded `.py` reference — works correctly with compiled `.exe` in production

---

## v2.5.35 (2026-02-25)

### Bug Fixes
- **GHL Photo Link URL Mismatch**: Fixed contact Photo Link custom field storing the internal Google Storage URL instead of the public CDN URL (`assets.cdn.filesafe.space`). Upload response URL is now normalised to the correct public domain.
- **GoCardless API Token Rejected on Re-entry**: Fixed `Base64_Encode()` using `CRYPT_STRING_BASE64` flag which embeds `\r\n` every 76 characters — this broke the JSON credentials file when encoding long tokens (e.g., GoCardless live tokens). Now uses `CRYPT_STRING_NOCRLF` flag to produce single-line base64. Also added `Trim()` to the Edit Token input to strip accidental whitespace from pasted tokens.

### Documentation
- **Cardly Test Mode Documentation**: Added comprehensive test mode section to user manual and technical documentation explaining what test mode validates, what it skips, cost implications, and orphaned artwork behaviour
- **User Manual — Greeting Cards (Cardly)**: New full section covering workflow, test mode comparison table, image sources, and requirements

---

## v2.5.34 (2026-02-23)

### New Features
- **Graphical Toolbar Button Settings**: Toolbar Shortcuts panel now shows clickable icons instead of toggle sliders
- **Visual Toggle Feedback**: Icons change background color and labels gray out when disabled
- **Direct Toggle Updates**: Button visibility updates immediately on click (no need to wait for Apply)

### Improvements
- **Cleaner Settings UI**: Removed toggle slider controls in favor of more intuitive icon-based toggles
- **Consistent Styling**: Toolbar button icons in settings match actual toolbar appearance

---

## v2.5.33 (2026-02-22)

### New Features
- **Bank Transfer Display**: Added Bank Transfer Details section to Display tab with Bank Institution, Account Name, Sort Code, and Account Number fields
- **Slide Cycling System**: Display now cycles through QR codes, bank transfer details, and custom images as slides (↑↓ to navigate)
- **Scalable Bank Display**: Bank transfer slide text scales with Size slider (25-85%) same as QR codes
- **Sort Code Formatting**: Sort codes automatically formatted as ##-##-## on display

---

## v2.5.32 (2026-02-20)

### Documentation & Legal
- **Enhanced EULA**: Added Third-Party Services section (§9), expanded Disclaimer of Warranties and Limitation of Liability, added Indemnification clause
- **Terms of Service Pages**: Created comprehensive terms.html for docs/ and Website/ with full legal terms
- **Privacy Policy Updates**: Enhanced Section 3.2 with detailed warranty disclaimers, third-party service notices, liability limits, and indemnification
- **Manual Disclaimers**: Updated GHL and GoCardless sections with comprehensive "AS IS" disclaimers and user responsibility notices
- **GoCardless Auto-Detect**: Removed hardcoded 'bacs' scheme - GoCardless now auto-detects scheme based on customer's bank country

---

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

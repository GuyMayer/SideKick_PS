# SideKick_PS.ahk Documentation

## Overview

**SideKick_PS.ahk** is an AutoHotkey automation script designed to streamline payment plan creation and management for ProSelect photography software. It provides a user-friendly calculator interface that automatically schedules recurring payments and enters them into ProSelect, eliminating tedious manual data entry.

**Version:** 2.4.1  
**Build Date:** 2026-01-30  
**Author:** GuyMayer  
**Repository:** https://github.com/GuyMayer/SideKick_PS  
**License:** See repository

---

## File Locations

| File | Path | Purpose |
|------|------|---------|
| **Master Script** | `C:\Stash\SideKick_PS.ahk` | Primary production file (git-tracked) |
| **SideKick Copy** | `C:\Stash\SideKick\SideKick_PS.ahk` | Synchronized copy in SideKick folder |
| **Documentation** | `C:\Stash\SideKick_PS_Documentation.md` | This documentation file |
| **Legacy Files** | `C:\Stash\Legacy\` | Archived old/backup versions |
| **VS Code Config** | `C:\Stash\.vscode\` | Editor settings and debug configs |

---

## Table of Contents

1. [Primary Purpose](#primary-purpose)
2. [Key Features](#key-features)
3. [Installation & Setup](#installation--setup)
4. [Main Components](#main-components)
5. [Core Functions](#core-functions)
6. [Data Flow](#data-flow)
7. [Configuration](#configuration)
8. [Dependencies](#dependencies)
9. [Troubleshooting](#troubleshooting)

---

## Primary Purpose

This script automates payment plan creation for ProSelect photography software by:
- Calculating payment schedules based on balance and recurring periods
- Automatically entering payment data into ProSelect
- Generating multiple copies of order reports with different configurations
- Providing a persistent, easy-to-access payment calculator interface

---

## Key Features

✅ **Automatic Date Calculation** - Intelligently calculates payment dates for recurring schedules  
✅ **Rounding Error Correction** - First payment adjusted to ensure exact balance match  
✅ **Balance Splitting** - Evenly divides balances across payment installments  
✅ **INI File Persistence** - Saves payment plan data for future reference  
✅ **ProSelect UI Automation** - Uses ControlClick/ControlSend for reliable automation  
✅ **Always-On-Top Overlay** - Quick access button appears when ProSelect is active  
✅ **Multi-Copy Print Automation** - Generates 3 report copies with conditional formatting  
✅ **Flexible Recurring Periods** - Supports Weekly, Bi-Weekly, 4-Weekly, and Monthly payments  
✅ **Version Tracking** - Built-in version info, About dialog, and tray menu  
✅ **Admin Privilege Check** - Ensures proper permissions on startup  

---

## Installation & Setup

### Prerequisites
- AutoHotkey installed (v1.1+)
- ProSelect photography software
- Windows operating system

### Installation Steps

1. Clone or download the repository to `C:\Stash\` (or your preferred location)
2. Ensure the following files are present:
   - `SideKick_PS.ahk` (main script)
   - `Lib\Acc.ahk` (accessibility library)
   - `SideKick_PS.png` / `SideKick_PS.ico` (icons)
   - `KbdSpacebar.wav` (audio feedback)
3. Run `SideKick_PS.ahk` (right-click → Run as Administrator if needed)
4. Launch ProSelect - the payment button overlay will appear automatically

---

## Main Components

### 1. GUI and User Interface

#### AlwaysOnTop Payment Button (Lines 45-65)
Creates a small floating button overlay that appears when ProSelect is active:
- Positioned at screen coordinates (380, 720)
- 70x70 pixel transparent window
- Displays `SideKick_PS.png` icon
- Automatically shows/hides based on ProSelect window state

#### PayCalcGUI - Payment Calculator (Lines 121-180)
Main payment calculator interface featuring:
- **Balance Input** - Displays current balance from ProSelect
- **Number of Payments** - Selector with range 2-24 (UpDown control)
- **Payment Value Display** - Shows calculated per-payment amount
- **Recurring Period** - Dropdown: Monthly, Quarterly, Yearly
- **Payment Type** - Dropdown: Deposit, Print Payment, Final Payment
- **Date Selection** - Day (1-31), Month (current+1), Year dropdowns
- **Action Buttons** - Cancel and "Schedule Payments"

---

## Core Functions

### Date & Payment Calculation

#### `GetNextMonthIndex()` (Line 185)
```ahk
Returns: Integer (1-12)
```
Returns the next month number. Wraps from December (12) to January (1).

**Example:**
- Current month: November (11) → Returns: 12 (December)
- Current month: December (12) → Returns: 1 (January)

---

#### `GuiSetup()` (Lines 191-207)
```ahk
Returns: None
```
Populates the month dropdown with all 12 months and pre-selects next month.

**Behavior:**
- Creates DropDownList with January-December options
- Uses `GetNextMonthIndex()` to determine selection
- Called during GUI initialization

---

#### `GetNextMonthName()` (Lines 209-224)
```ahk
Returns: String (formatted as "Month Year")
```
Returns formatted month name with year, accounting for year rollover.

**Examples:**
- November 2025 → "December 2025"
- December 2025 → "January 2026"

---

#### `DateCalc(Date, Years, Months, Days)` (Lines 513-545)
```ahk
Parameters:
  - Date: YYYYMMDD format (default: A_Now)
  - Years: Integer offset
  - Months: Integer offset  
  - Days: Integer offset
Returns: YYYYMMDD date string
```
Advanced date calculation with automatic validation and adjustment for invalid dates (e.g., February 30 → February 28/29).

**Example Usage:**
```ahk
; Add 3 months to current date
NewDate := DateCalc(A_Now, 0, 3, 0)

; Add 1 year and 6 months
NewDate := DateCalc("20250101", 1, 6, 0)
```

---

#### `Recalc` Label (Lines 244-248)
```ahk
Trigger: PayNo change, recurring period change
```
Recalculates payment value by dividing balance by number of payments.

**Formula:**
```
Payment Value = Floor(Balance / Number of Payments, 2 decimal places)
```

---

### Data Management

#### `SaveData()` (Lines 292-314)
```ahk
Returns: None
Writes to: SideKick_PS.ini
```
Persists payment plan data to INI file with sections:
- `[Settings]` - PayDue, PayNo, PayValue, date fields, PayType, Recurring
- `[PaymentLines]` - Individual payment entries (Line1, Line2, etc.)

**INI File Structure:**
```ini
[Settings]
PayDue=5000.00
PayNo=6
PayValue=833.33
PayDay=15
PayMonth=12
PayYear=2025
PayType=Print Payment
Recurring=Monthly

[PaymentLines]
Line1=12/15/2025|833.33|Print Payment
Line2=01/15/2026|833.33|Print Payment
...
```

---

#### `ProcessData()` (Lines 316-335)
```ahk
Returns: None
```
Converts GUI dropdown selections to numeric format:
- Month names → Numbers (1-12)
- Day/Year strings → Integers

Called before `BuildPayPlanLines()` to prepare data.

---

#### `ReadData()` (Lines 264-290)
```ahk
Returns: None
```
Reads saved payment plan from `SideKick_PS.ini` and populates GUI fields.

**Use Case:** Restores previous session data when reopening calculator.

---

#### `BuildPayPlanLines()` (Lines 337-365)
```ahk
Returns: None
Global: PaymentLines[] array
```
Generates payment schedule array with calculated dates based on recurring period.

**Logic:**
1. Calls `ProcessData()` to convert GUI values
2. Calculates starting date from PayDay/PayMonth/PayYear
3. For each payment:
   - Uses `DateCalc()` to add recurring offset
   - Formats as "MM/DD/YYYY|Amount|Type"
   - Stores in `PaymentLines[]` array

**Example Output:**
```ahk
PaymentLines[1] := "12/15/2025|833.33|Print Payment"
PaymentLines[2] := "01/15/2026|833.33|Print Payment"
PaymentLines[3] := "02/15/2026|833.33|Print Payment"
```

---

### ProSelect Integration

#### `GetBalance()` (Lines 110-119)
```ahk
Returns: Numeric value
Requires: ProSelect "Add Payment" window active
```
Extracts current balance from ProSelect window using Accessibility library.

**Process:**
1. Searches for "Balance:" text element
2. Retrieves associated numeric value
3. Removes formatting characters (commas, dollar signs)
4. Returns clean numeric value

---

#### `UpdatePS()` (Lines 367-439)
```ahk
Returns: None
Automates: ProSelect payment entry
```
Core automation function that enters payment schedule into ProSelect.

**Step-by-Step Process:**

1. **Window Activation** (Lines 369-376)
   - Verifies ProSelect.exe is running
   - Activates main window
   - Waits for focus

2. **Initialize Add Payment** (Lines 378-385)
   - Clicks "Add Payment" button (coordinates: 383, 719)
   - Waits for dialog (5 second timeout)
   - Activates payment window

3. **For Each Payment** (Lines 386-428)
   - **Date Entry:**
     - Selects payment type dropdown
     - Navigates to date month dropdown
     - Enters date day (numeric keypad simulation)
     - Selects month from dropdown
     - Enters year value
   
   - **Amount Entry:**
     - Clicks amount field
     - Types payment value
     - Handles decimal point formatting
   
   - **Submit:**
     - Clicks "Apply & New" button
     - Plays audio feedback (`KbdSpacebar.wav`)
     - Waits for next payment dialog

4. **Final Payment** (Lines 429-437)
   - Enters last payment details
   - Clicks "Apply & Close" instead of "Apply & New"
   - Returns to main ProSelect window

**Error Handling:**
- Window existence checks before each action
- 5-second timeouts for window activation
- Sleep delays for UI responsiveness

---

### Print Automation

#### `PrintOrders` Label (Lines 575-635)
```ahk
Trigger: Manual hotkey or GUI button
Generates: 3 report copies
```
Automates printing of order reports with different configurations.

**Copy 1: Accounts Copy** (Lines 582-604)
- ✅ QR Code included
- ✅ Message appended
- Destination: Default printer
- Process:
  1. Opens Print Order Report (Ctrl+P)
  2. Checks "Append this Message"
  3. Checks "Include QR Code"
  4. Clicks "Print Report"
  5. Confirms print dialog
  6. Waits for completion

**Copy 2: Client Copy** (Lines 607-622)
- ❌ No QR Code
- ✅ Message appended
- Destination: Default printer
- Same process as Copy 1, but unchecks QR Code

**Copy 3: Production Copy** (Lines 626-635)
- ✅ QR Code included
- ❌ No message
- Destination: Default printer
- Unchecks "Append this Message", checks QR Code

**Audio Feedback:** Plays `KbdSpacebar.wav` after each print submission.

---

### Utility Functions

#### `FloorDecimal(Input, Decimals)` (Lines 441-457)
```ahk
Parameters:
  - Input: Number to round
  - Decimals: Number of decimal places
Returns: Rounded number
```
Rounds numbers to specified decimal places (always rounds down).

**Example:**
```ahk
FloorDecimal(833.3333, 2) → 833.33
FloorDecimal(15.999, 2) → 15.99
```

---

#### `JEE_StrReplaceChars(String, OldChars)` (Lines 459-471)
```ahk
Parameters:
  - String: Input text
  - OldChars: Characters to remove
Returns: Cleaned string
```
Removes specified characters from string.

**Example:**
```ahk
JEE_StrReplaceChars("$1,234.56", "$,") → "1234.56"
```

---

#### `ObjIndexOf(Object, Value)` (Lines 473-481)
```ahk
Parameters:
  - Object: Array to search
  - Value: Item to find
Returns: Index or 0 if not found
```
Searches array for value and returns index position.

---

#### `ParentByTitle(Title)` (Lines 483-509)
```ahk
Parameters:
  - Title: Window title to set as parent
Returns: None
```
Sets current GUI window parent to specified window by title.

**Use Case:** Makes overlay window appear within ProSelect main window boundaries.

---

## Data Flow

### Payment Plan Creation Workflow

```
┌─────────────────────────────────────────────────────────────┐
│ 1. USER LAUNCHES CALCULATOR                                 │
│    - Clicks overlay button or hotkey                        │
│    - PayCalcGUI displays with default values                │
└──────────────────────┬──────────────────────────────────────┘
                       ↓
┌─────────────────────────────────────────────────────────────┐
│ 2. BALANCE EXTRACTION (Optional)                            │
│    - GetBalance() reads ProSelect "Add Payment" window      │
│    - Extracts numeric value via Accessibility API           │
│    - Populates PayDue field                                 │
└──────────────────────┬──────────────────────────────────────┘
                       ↓
┌─────────────────────────────────────────────────────────────┐
│ 3. USER CONFIGURES PLAN                                     │
│    - Sets number of payments (2-24)                         │
│    - Selects payment type (Deposit/Print/Final)             │
│    - Chooses recurring period (Monthly/Quarterly/Yearly)    │
│    - Adjusts start date if needed                           │
│    - Payment value auto-calculates via Recalc               │
└──────────────────────┬──────────────────────────────────────┘
                       ↓
┌─────────────────────────────────────────────────────────────┐
│ 4. SCHEDULE GENERATION                                      │
│    - BuildPayPlanLines() creates payment array              │
│    - DateCalc() computes recurring dates                    │
│    - Handles month/year rollovers automatically             │
│    - Result: PaymentLines[] array populated                 │
└──────────────────────┬──────────────────────────────────────┘
                       ↓
┌─────────────────────────────────────────────────────────────┐
│ 5. DATA PERSISTENCE                                         │
│    - SaveData() writes to SideKick_PS.ini                   │
│    - Settings section stores configuration                  │
│    - PaymentLines section stores schedule                   │
└──────────────────────┬──────────────────────────────────────┘
                       ↓
┌─────────────────────────────────────────────────────────────┐
│ 6. PROSELECT AUTOMATION                                     │
│    - UpdatePS() enters all payments automatically           │
│    - For each payment:                                      │
│      • Opens Add Payment dialog                             │
│      • Enters date (day/month/year)                         │
│      • Enters amount                                        │
│      • Clicks Apply & New (or Apply & Close for last)       │
│    - Audio feedback after each entry                        │
└──────────────────────┬──────────────────────────────────────┘
                       ↓
┌─────────────────────────────────────────────────────────────┐
│ 7. PRINT WORKFLOW (Optional)                                │
│    - PrintOrders generates 3 copies:                        │
│      1. Accounts Copy (QR + Message)                        │
│      2. Client Copy (Message only)                          │
│      3. Production Copy (QR only)                           │
│    - Automated checkbox toggling                            │
│    - Audio feedback per copy                                │
└─────────────────────────────────────────────────────────────┘
```

---

## Configuration

### INI File: `SideKick_PS.ini`

The script uses an INI file for data persistence. Location: same directory as script.

#### Settings Section
```ini
[Settings]
PayDue=5000.00          ; Total balance due
PayNo=6                 ; Number of payments
PayValue=833.33         ; Per-payment amount
PayDay=15               ; Payment day of month
PayMonth=12             ; Payment month (1-12)
PayYear=2025            ; Payment year
PayType=Print Payment   ; Payment type
Recurring=Monthly       ; Recurring period
```

#### PaymentLines Section
```ini
[PaymentLines]
Line1=12/15/2025|833.33|Print Payment
Line2=01/15/2026|833.33|Print Payment
Line3=02/15/2026|833.33|Print Payment
Line4=03/15/2026|833.33|Print Payment
Line5=04/15/2026|833.33|Print Payment
Line6=05/15/2026|833.33|Print Payment
```

### Customization Options

#### Overlay Button Position (Lines 62-63)
```ahk
Gui, PP:Show, x380 y720 h70 w70, SideKick_PS
```
Change `x380 y720` to reposition overlay button.

#### Payment Type Options (Lines 99-100)
```ahk
PayTypeOptions := "Deposit|Print Payment|Final Payment"
```
Add/modify payment types by editing pipe-delimited list.

#### Recurring Period Options (Lines 96-97)
```ahk
RecurringOptions := "Monthly|Quarterly|Yearly"
```
Current periods supported: Monthly (1 month), Quarterly (3 months), Yearly (12 months).

#### Audio Feedback
Replace `KbdSpacebar.wav` with custom sound file for different audio cues.

---

## Dependencies

### Required Files

| File | Purpose | Location |
|------|---------|----------|
| `SideKick_PS.ahk` | Main script | `C:\Stash\` |
| `Lib\Acc.ahk` | Accessibility library for UI automation | `C:\Stash\Lib\` |
| `SideKick_PS.ini` | Payment plan data storage | `C:\Stash\` (auto-created) |
| `SideKick_PS.png` | Overlay button icon | `C:\Stash\` |
| `SideKick_PS.ico` | GUI window icon | `C:\Stash\` |
| `KbdSpacebar.wav` | Audio feedback sound | `C:\Stash\` |

### External Software

- **ProSelect.exe** - Photography software (must be installed and running)
- **AutoHotkey v1.1+** - Script interpreter
- **Windows OS** - Required for UI automation APIs

### AutoHotkey Libraries

#### Acc.ahk (Accessibility Library)
Used for extracting balance value from ProSelect windows. Provides:
- Element tree navigation
- Text retrieval from UI controls
- Accessibility API wrapper functions

**Source:** `Lib\Acc.ahk` (included in repository)

---

## Troubleshooting

### Common Issues

#### Issue: Overlay button doesn't appear
**Causes:**
- ProSelect not running
- Script not running with admin privileges
- Icon file missing (`SideKick_PS.png`)

**Solutions:**
1. Launch ProSelect first
2. Right-click script → "Run as Administrator"
3. Verify `SideKick_PS.png` exists in script directory

---

#### Issue: Balance extraction fails
**Causes:**
- ProSelect "Add Payment" window not active
- Acc.ahk library missing
- ProSelect UI structure changed (version mismatch)

**Solutions:**
1. Manually open "Add Payment" in ProSelect
2. Verify `Lib\Acc.ahk` exists
3. Check ProSelect version compatibility
4. Manually enter balance in calculator

---

#### Issue: Payment automation enters wrong dates
**Causes:**
- ProSelect window focus lost
- Sleep delays too short for slow systems
- Dropdown timing issues

**Solutions:**
1. Don't interact with computer during automation
2. Increase sleep delays in `UpdatePS()` function:
   ```ahk
   sleep, 100  →  sleep, 200
   ```
3. Ensure ProSelect is maximized and visible

---

#### Issue: Payments not saving to INI
**Causes:**
- Write permissions denied
- File path incorrect
- Disk space full

**Solutions:**
1. Run script as administrator
2. Verify `A_ScriptDir` points to correct location
3. Check available disk space
4. Manually create `SideKick_PS.ini` with proper permissions

---

#### Issue: Print automation fails
**Causes:**
- Print dialog timeout
- Printer not ready
- ProSelect version differences

**Solutions:**
1. Increase WinWaitActive timeout:
   ```ahk
   WinWaitActive, Print Order Report  →  WinWaitActive, Print Order Report, , 10
   ```
2. Ensure default printer is online
3. Test manual print first to verify dialog structure

---

### Debug Mode

To enable debugging, add this near top of script (after `#NoEnv`):

```ahk
#Warn  ; Enable warnings for debugging
SetBatchLines, -1  ; Run at full speed
ListLines, On  ; Enable line logging
```

View debug output:
1. Right-click script tray icon
2. Select "Open" or "ListVars"
3. Check variable values and execution flow

---

### Log File Creation

Add logging to troubleshoot automation issues:

```ahk
; Add at top of UpdatePS() function
FileAppend, % "Starting UpdatePS at " A_Now "`n", debug.log

; Add after each major step
FileAppend, % "Clicked Add Payment`n", debug.log
FileAppend, % "Entered payment " A_Index ": " PayValue "`n", debug.log
```

---

## Advanced Usage

### Custom Hotkeys

Add custom hotkeys to script (place near top, after `#NoEnv`):

```ahk
; Ctrl+Alt+P to open calculator
^!p::Gosub, PayCalcGUI

; Ctrl+Alt+B to print orders
^!b::Gosub, PrintOrders

; Ctrl+Alt+Q to reload script
^!q::Reload
```

### Multiple Payment Plans

To support multiple concurrent payment plans:

1. Modify `SaveData()` to use unique INI sections:
   ```ahk
   IniWrite, %PayDue%, %A_ScriptDir%\SideKick_PS.ini, Plan%PlanNumber%, PayDue
   ```

2. Add plan selector to GUI
3. Update `ReadData()` to load specific plan

---

## API Reference (Quick)

### Global Variables

| Variable | Type | Description |
|----------|------|-------------|
| `PayDue` | Float | Total balance due |
| `PayNo` | Integer | Number of payments (2-24) |
| `PayValue` | Float | Per-payment amount |
| `PayDay` | Integer | Payment day (1-31) |
| `PayMonth` | Integer | Payment month (1-12) |
| `PayYear` | Integer | Payment year |
| `PayType` | String | Payment type |
| `Recurring` | String | Recurring period |
| `PaymentLines[]` | Array | Generated payment schedule |

### Function Signatures

```ahk
GetNextMonthIndex() → Integer
GuiSetup() → None
GetNextMonthName() → String
DateCalc(Date="", Years=0, Months=0, Days=0) → String
FloorDecimal(Input, Decimals=2) → Float
JEE_StrReplaceChars(String, OldChars) → String
ObjIndexOf(Object, Value) → Integer
ParentByTitle(Title) → None
GetBalance() → Float
SaveData() → None
ReadData() → None
ProcessData() → None
BuildPayPlanLines() → None
UpdatePS() → None
```

---

## Version History

### Version 1.0 (November 2025)
- Initial release
- Payment calculator GUI
- ProSelect automation
- Print workflow automation
- INI file persistence
- Date calculation engine
- Accessibility integration

---

## License

See repository license file for terms and conditions.

---

## Building & Releasing

### IMPORTANT: EXE Only Distribution

**NO source scripts (.py, .ahk) are distributed to end users.**

All releases contain only compiled executables:
- `SideKick_PS.exe` - Compiled from AutoHotkey
- `validate_license.exe` - Compiled from Python
- `fetch_ghl_contact.exe` - Compiled from Python
- `update_ghl_contact.exe` - Compiled from Python
- `sync_ps_invoice_v2.exe` - Compiled from Python
- `upload_ghl_media.exe` - Compiled from Python

### Build a New Release

1. **Build and archive the release:**
   ```powershell
   cd C:\Stash\SideKick_PS
   .\build_and_archive.ps1 -Version "2.5.0"
   ```

   This will:
   - Compile `SideKick_PS.ahk` to `.exe` using Ahk2Exe
   - Compile all Python scripts to `.exe` using PyInstaller
   - Include `LICENSE.txt` (EULA) in the release
   - Verify NO source scripts in release (EXE only!)
   - Archive to `Releases\v2.5.0\` folder
   - Create `SideKick_PS_v2.5.0.zip`

2. **Publish to GitHub:**
   ```powershell
   gh release create v2.5.0 "Releases/v2.5.0/SideKick_PS_v2.5.0.zip" --title "SideKick_PS v2.5.0" --notes "Release notes here"
   ```

### Folder Structure

```
C:\Stash\SideKick_PS\
├── Release\              ← Current build (EXE ONLY)
│   ├── SideKick_PS.exe
│   ├── validate_license.exe
│   ├── fetch_ghl_contact.exe
│   ├── update_ghl_contact.exe
│   ├── sync_ps_invoice_v2.exe
│   ├── upload_ghl_media.exe
│   ├── LICENSE.txt
│   ├── media\
│   └── version.json
├── Releases\             ← Archive of all versions
│   ├── v2.4.0\
│   │   └── SideKick_PS_v2.4.0.zip
│   └── v2.5.0\
│       └── SideKick_PS_v2.5.0.zip
├── LICENSE.txt           ← EULA/License Agreement
├── build_and_archive.ps1
└── README.md
```

### License Agreement (EULA)

The `LICENSE.txt` file is included in every release and contains:
- Software license terms
- Subscription and trial information
- Usage restrictions
- Liability limitations
- Contact information

Users must accept the license when installing.

### Developer Tab - Quick Publish

The Developer tab in SideKick_PS Settings provides one-click publishing:

| Button | Action |
|--------|--------|
| **📦 Create Release** | Runs `build_and_archive.ps1` - compiles everything to EXE |
| **🔢 Update Version** | Updates version.json with new version number |
| **🚀 Push GitHub** | Opens PowerShell for manual git commands |
| **⚡ Quick Publish** | **One-click full workflow:** |

**Quick Publish does:**
1. Prompts for new version number (auto-increments patch)
2. Prompts for release notes
3. Updates version in main script
4. Runs full build (compiles AHK + Python to EXE)
5. Creates versioned archive in `Releases/vX.X.X/`
6. Commits and pushes to GitHub
7. Creates GitHub Release with ZIP attached

### GitHub Links

| Link | URL |
|------|-----|
| Repository | https://github.com/GuyMayer/SideKick_PS |
| Latest Release | https://github.com/GuyMayer/SideKick_PS/releases/latest |
| All Releases | https://github.com/GuyMayer/SideKick_PS/releases |

### LemonSqueezy Integration

- **Product Page:** https://zoomphoto.lemonsqueezy.com
- **Download Link (for customers):** https://github.com/GuyMayer/SideKick_PS/releases/latest

---

## Support & Contributing

**Repository:** https://github.com/GuyMayer/SideKick_PS  
**Issues:** Submit via GitHub Issues  
**Pull Requests:** Welcome for bug fixes and enhancements  

---

## Credits

- **AutoHotkey Community** - Acc.ahk accessibility library
- **ProSelect** - Photography software by TimeExposure
- **Developer:** GuyMayer

---

*Last Updated: January 30, 2026*

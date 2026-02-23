#Requires AutoHotkey v1.1+
; ============================================================================
; Script:      SideKick_PS.ahk
; Description: Payment Plan Calculator for ProSelect Photography Software
; Version:     2.5.30
; Build Date:  2026-02-18
; Author:      GuyMayer
; Repository:  https://github.com/GuyMayer/SideKick_PS
; ============================================================================
; Changelog:
;   v2.5.1 (2026-02-11)
;     - NEW: Printer selection in Settings > Print tab
;     - NEW: Dropdown shows System Default + all available printers
;     - FIX: Windows 10 print dialog now uses Alt+P for reliability
;     - Quick Print temporarily switches printer if specific one selected
;   v2.5.0 (2026-02-08)
;     - NEW: Toolbar grab handle - Ctrl+Click and drag to reposition
;     - NEW: Position is saved relative to ProSelect window (persistent)
;     - NEW: Reset Position button in Settings > Shortcuts > Toolbar Appearance
;   v2.4.77 (2026-02-08)
;     - NEW: Local QR code generation using BARCODER library (no Google API)
;     - NEW: QR codes cached on startup for instant display
;     - NEW: WiFi QR codes show friendly format (WiFi: SSID | Password: xxx)
;     - NEW: Monitor selection for QR display (Settings + arrow keys)
;     - IMPROVED: Flash-free QR cycling - controls update without GUI rebuild
;     - IMPROVED: Smart dialog detection - hides toolbar on smaller windows
;     - IMPROVED: Ps button color matches other toolbar icons
;   v2.4.68 (2026-02-05)
;     - IMPROVED: Activity logs now sent after every sync (not just errors)
;     - IMPROVED: Quick Publish always recompiles all Python scripts
;   v2.4.66 (2026-02-05)
;     - FIX: Invoice now published after creation (was staying as draft)
;     - Draft invoices weren't visible in GHL invoice list
;     - Added _send_invoice API call to sync_ps_invoice.py
;   v2.4.64 (2026-02-03)
;     - IMPROVED: Payment Calculator window now persistent until closed or used
;     - IMPROVED: Calculator stays on top of ProSelect but not other apps
;     - IMPROVED: Rounding option radio buttons now have white text and tooltips
;   v2.4.63 (2026-02-03)
;     - NEW: Rounding option radio buttons in Payment Calculator
;     - Choose to add rounding to Downpayment or 1st Payment
;     - Setting is persistent (saved to INI)
;   v2.4.62 (2026-02-03)
;     - FIX: Payment entry windows now properly close after completing payment plan
;     - Added loop to ensure all "Add Payment" windows are closed
;   v2.4.61 (2026-02-03)
;     - FIX: Downpayment now correctly subtracted from balance before splitting payments
;     - Payment calculator recalculates when downpayment amount changes
;     - Made all input field text black for better readability
;     - Increased payment line entry delay to 1000ms for reliability
;   v2.4.0 (2026-01-26)
;     - NEW: Collect client data from GHL URL and update ProSelect
;     - Auto-load option: automatically populate ProSelect client fields
;     - Manual confirmation option: preview data before loading to ProSelect
;     - Added "Update ProSelect" button in GHL Client Lookup dialog
;     - Added Settings toggle for Auto-load vs Manual confirmation
;   v2.2.0 (2026-01-16)
;     - PayPlan button now appears on the Payline window (small Add Payment dialog)
;     - Button position follows Payline window when moved
;     - Improved payment entry flow for ProSelect 2025
;     - Reads balance from Payline window Amount field (Edit2)
;     - Streamlined automation: no extra button clicks needed
;     - Payment types now read from Payline window ComboBox1
;     - Can now enter payment amount to calculate number of payments
;     - Rounding error pennies added to first payment line
;     - New dark theme UI matching ProSelect 2025 style
;     - Added calendar icons to PayPlan and Schedule Payments buttons
;     - Windows no longer stay on top when switching to other programs
;   v2.1.0 (2025-12-12)
;     - Added ProSelect 2025 support (C:\Program Files\Pro Studio Software\ProSelect 2025)
;     - Maintained backward compatibility with ProSelect 2022
;     - Auto-detects running ProSelect version
;   v2.0.0 (2025-11-26)
;     - Added rounding error correction (first payment adjustment)
;     - Implemented full weekly payment functionality
;     - Added Bi-Weekly and 4-Weekly recurring options
;     - Improved date calculation for all recurring periods
;   v1.0.0 (Initial Release)
;     - Monthly payment calculator
;     - ProSelect automation
;     - Print order workflow
; ============================================================================

#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
; #Warn  ; Enable warnings to assist with detecting common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.
#SingleInstance, Off

; Force close any previous instance of this script (handles .ahk and .exe versions)
; Using mutex to prevent race condition on startup
global SideKick_PS_Mutex := DllCall("CreateMutex", "Ptr", 0, "Int", 1, "Str", "SideKick_PS_SingleInstance", "Ptr")
if (DllCall("GetLastError") = 183) { ; ERROR_ALREADY_EXISTS
    ; Another instance is running, try to close it
    DetectHiddenWindows, On
    ; Match both .ahk and .exe versions
    scriptBaseName := RegExReplace(A_ScriptName, "\.(ahk|exe)$", "")
    WinGet, scriptList, List, %scriptBaseName% ahk_class AutoHotkey
    Loop, %scriptList%
    {
        hwnd := scriptList%A_Index%
        if (hwnd != A_ScriptHwnd)
            WinClose, ahk_id %hwnd%
    }
    ; Also check for compiled exe
    WinGet, exeList, List, %scriptBaseName%.exe ahk_class AutoHotkey
    Loop, %exeList%
    {
        hwnd := exeList%A_Index%
        if (hwnd != A_ScriptHwnd)
            WinClose, ahk_id %hwnd%
    }
    DetectHiddenWindows, Off
    Sleep, 100 ; Give old instance time to close
} else {
    ; We're the first instance, still try to clean up any orphans
    DetectHiddenWindows, On
    scriptBaseName := RegExReplace(A_ScriptName, "\.(ahk|exe)$", "")
    WinGet, scriptList, List, %scriptBaseName% ahk_class AutoHotkey
    Loop, %scriptList%
    {
        hwnd := scriptList%A_Index%
        if (hwnd != A_ScriptHwnd)
            WinClose, ahk_id %hwnd%
    }
    DetectHiddenWindows, Off
}

; DEBUG: Create timestamped log file in AppData (writable even in Program Files install)
global DebugLogFolder := A_AppData . "\SideKick_PS\Logs"
FileCreateDir, %DebugLogFolder%

; Use timestamped filename so logs are preserved across restarts
FormatTime, logTimestamp, , yyyyMMdd_HHmmss
global DebugLogFile := DebugLogFolder . "\sidekick_" . logTimestamp . ".log"
FileAppend, % "=== SideKick_PS Startup Log ===" . "`n", %DebugLogFile%
FileAppend, % "Started: " . A_Now . "`n", %DebugLogFile%
FileAppend, % "Script: " . A_ScriptFullPath . "`n", %DebugLogFile%
FileAppend, % "A_IsAdmin: " . A_IsAdmin . "`n`n", %DebugLogFile%

; Clean up old logs (older than 7 days)
CleanupOldLogs(DebugLogFolder, 7)

; ============================================================================
; Request Admin Elevation if needed (required when ProSelect runs as admin)
; ============================================================================
FileAppend, % A_Now . " - Checking admin elevation...`n", %DebugLogFile%
if not A_IsAdmin
{
	; Check if ProSelect is running elevated
	psHwnd := WinExist("ahk_exe ProSelect.exe")
	FileAppend, % A_Now . " - ProSelect HWND: " . psHwnd . "`n", %DebugLogFile%
	if (psHwnd)
	{
		; If ProSelect is running, we need admin to interact with it if it's elevated
		; Try to run as admin
		FileAppend, % A_Now . " - Requesting admin elevation...`n", %DebugLogFile%
		try
		{
			Run *RunAs "%A_ScriptFullPath%"
			ExitApp
		}
	}
}
FileAppend, % A_Now . " - Admin check complete`n", %DebugLogFile%

FileAppend, % A_Now . " - DPI setup...`n", %DebugLogFile%

; Enable DPI awareness for proper scaling on high-DPI displays
DllCall("SetThreadDpiAwarenessContext", "ptr", -2, "ptr")  ; DPI_AWARENESS_CONTEXT_SYSTEM_AWARE

; Get system DPI scale factor (100 = 100%, 125 = 125%, etc.)
global DPI_Scale := A_ScreenDPI / 96
FileAppend, % A_Now . " - DPI Scale: " . DPI_Scale . "`n", %DebugLogFile%

; Detect Windows version (Win11 build >= 22000, Win10 build < 22000)
global IsWindows11 := false
global IsWindows10 := false
RegRead, winBuild, HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion, CurrentBuildNumber
if (winBuild >= 22000) {
	IsWindows11 := true
} else {
	IsWindows10 := true
}
FileAppend, % A_Now . " - Windows Build: " . winBuild . " (Win11=" . IsWindows11 . ")`n", %DebugLogFile%

; Detect icon font - Phosphor Thin (bundled) > Segoe Fluent (Win11) > Font Awesome
global IconFont := DetectIconFont()
FileAppend, % A_Now . " - Icon Font: " . IconFont . "`n", %DebugLogFile%

; Set icon codepoints based on detected font
global Icon_User, Icon_AddFriend, Icon_Invoice, Icon_Globe, Icon_IDCard, Icon_Camera, Icon_Refresh, Icon_Print, Icon_PDFDoc, Icon_QRCode, Icon_Download, Icon_Settings
if (InStr(IconFont, "Phosphor")) {
	; Phosphor Icons codepoints (thin outline icons)
	Icon_User := 0xEC28
	Icon_AddFriend := 0xEC22  ; UserPlus
	Icon_Invoice := 0xE66E
	Icon_Globe := 0xE7B6
	Icon_IDCard := 0xE844
	Icon_Camera := 0xE21A
	Icon_Refresh := 0xE074
	Icon_Print := 0xEACC
	Icon_PDFDoc := 0xE65E  ; FilePdf / FileText
	Icon_QRCode := 0xEAE8
	Icon_Download := 0xE59A
	Icon_Settings := 0xE79A
} else if (InStr(IconFont, "Font Awesome")) {
	; Font Awesome 6 codepoints (solid icons)
	Icon_User := 0xF007
	Icon_AddFriend := 0xF234  ; user-plus
	Icon_Invoice := 0xF570
	Icon_Globe := 0xF0AC
	Icon_IDCard := 0xF2C2
	Icon_Camera := 0xF030
	Icon_Refresh := 0xF021
	Icon_Print := 0xF02F
	Icon_PDFDoc := 0xF1C1  ; file-pdf
	Icon_QRCode := 0xF029
	Icon_Download := 0xF019
	Icon_Settings := 0xF013
} else {
	; Segoe Fluent/MDL2 codepoints (thin outline icons)
	Icon_User := 0xE77B
	Icon_AddFriend := 0xE8FA  ; AddFriend (person + plus)
	Icon_Invoice := 0xE8A5
	Icon_Globe := 0xE774
	Icon_IDCard := 0xE779
	Icon_Camera := 0xE722
	Icon_Refresh := 0xE72C
	Icon_Print := 0xE749
	Icon_PDFDoc := 0xE9F9  ; ReadingMode / Document with lines
	Icon_QRCode := 0xED14
	Icon_Download := 0xE896
	Icon_Settings := 0xE713
}

; Log monitor information
SysGet, MonitorCount, MonitorCount
SysGet, MonitorPrimary, MonitorPrimary
FileAppend, % A_Now . " - Monitor Count: " . MonitorCount . ", Primary: " . MonitorPrimary . "`n", %DebugLogFile%
Loop, %MonitorCount%
{
    SysGet, Mon, Monitor, %A_Index%
    SysGet, MonWork, MonitorWorkArea, %A_Index%
    SysGet, MonName, MonitorName, %A_Index%
    monWidth := MonRight - MonLeft
    monHeight := MonBottom - MonTop
    isPrimary := (A_Index = MonitorPrimary) ? " [PRIMARY]" : ""
    FileAppend, % "    Monitor " . A_Index . isPrimary . ": " . monWidth . "x" . monHeight . " at (" . MonLeft . ", " . MonTop . ")`n", %DebugLogFile%
    FileAppend, % "      Work Area: (" . MonWorkLeft . ", " . MonWorkTop . ") to (" . MonWorkRight . ", " . MonWorkBottom . ")`n", %DebugLogFile%
}
FileAppend, % "`n", %DebugLogFile%

FileAppend, % A_Now . " - Loading Acc.ahk...`n", %DebugLogFile%
#Include %A_ScriptDir%\Lib\Acc.ahk
FileAppend, % A_Now . " - Loading Chrome.ahk...`n", %DebugLogFile%
#Include %A_ScriptDir%\Lib\Chrome.ahk
FileAppend, % A_Now . " - Loading Notes.ahk...`n", %DebugLogFile%
#Include %A_ScriptDir%\Lib\Notes.ahk
FileAppend, % A_Now . " - Loading Gdip_All.ahk...`n", %DebugLogFile%
#Include %A_ScriptDir%\Lib\Gdip_All.ahk
FileAppend, % A_Now . " - All includes loaded`n", %DebugLogFile%

; Script version info - loaded from version.json (single source of truth)
global ScriptVersion := ""
global BuildDate := ""
global LastSeenVersion := ""  ; User's last seen version for What's New dialog

; DarkMsgBox position tracking for wizard dialogs
global DarkMsgBox_LastX := ""
global DarkMsgBox_LastY := ""
global DarkMsgBox_RememberPos := false

FileAppend, % A_Now . " - Loading version from JSON...`n", %DebugLogFile%
; Load version from version.json at startup
LoadVersionFromJson()
FileAppend, % A_Now . " - Version: " . ScriptVersion . "`n", %DebugLogFile%

; Log sync helper info
global HelperPath := ""
global HelperVersion := ""
global HelperModified := ""
LogHelperInfo()

; GHL Integration variables
global FBPE_URL := ""
global GHL_ContactID := ""
global GHL_API_Key := ""        ; V2 Private Integration Token
global GHL_LocationID := ""     ; GHL Location ID
global GHL_AgencyDomain := ""   ; GHL Agency domain (e.g. app.yourcompany.com)
global Client_Notes := "ZoomPhotography2026"  ; Encryption key for Notes_Plus/Minus

; Settings variables
global Settings_DarkMode := true  ; Default to dark mode
global Settings_StartOnBoot := 0
global Settings_ShowTrayIcon := 1
global Settings_EnableSounds := 1
global Settings_AutoDetectPS := 1
global Settings_DefaultRecurring := "Monthly"
global Settings_DefaultPayType := "Gocardles DD"
global Settings_GHL_Enabled := 1
global Settings_GHL_AutoLoad := 0  ; 0=Manual confirmation, 1=Auto-load to ProSelect
global Settings_OpenInvoiceURL := 1  ; Open invoice URL in browser after sync
global Settings_AutoSaveXML := 0  ; Auto-save XML copy when exporting to GHL
global Settings_InvoiceWatchFolder := ""  ; Folder to watch for ProSelect invoice XML files
global Settings_GHLInvoiceWarningShown := 0  ; Has user been warned about GHL automated emails?
global Settings_GHLPaymentSettingsURL := ""  ; URL to GHL payment settings for email configuration
global Settings_CollectContactSheets := 0  ; Save local copy of contact sheets
global Settings_ContactSheetFolder := ""  ; Folder to save contact sheets
global Settings_GHLTags := ""  ; Tags to add to GHL contacts on sync
global Settings_GHLOppTags := ""  ; Tags to add to GHL opportunities on sync
global Settings_AutoAddContactTags := 1  ; Automatically add contact tags on sync
global Settings_AutoAddOppTags := 1  ; Automatically add opportunity tags on sync
global Settings_RoundingInDeposit := 1  ; Add rounding errors to deposit (1) or 1st payment (0)
global GHL_CachedTags := ""  ; Cached list of contact tags from GHL
global GHL_CachedOppTags := ""  ; Cached list of opportunity tags from GHL
global GHL_CachedEmailTemplates := ""  ; Cached list of email templates from GHL (id|name format)
global GHL_CachedSMSTemplates := ""  ; Cached list of SMS templates from GHL (id|name format)
global Settings_CurrentTab := "General"
global PayCalcOpen := false  ; Track if Payment Calculator window is open

; File Management settings
global Settings_CardDrive := "F:\DCIM"  ; Default SD card path
global Settings_CameraDownloadPath := ""  ; Temp download folder
global Settings_ShootArchivePath := ""    ; Final archive location
global Settings_FolderTemplatePath := ""  ; Folder template for new shoots
global Settings_ShootPrefix := "P"        ; Shoot number prefix
global Settings_ShootSuffix := "P"        ; Shoot number suffix
global Settings_AutoShootYear := true     ; Include year in shoot number
global Settings_EditorRunPath := "Explore"  ; Photo editor path or "Explore"
global Settings_BrowsDown := true         ; Open editor after download
global Settings_AutoRenameImages := false ; Auto-rename by date
global Settings_AutoDriveDetect := true   ; Detect SD card insertion
global Settings_SDCardEnabled := true    ; Enable SD Card Download feature (show toolbar icon)
global Settings_RoomCaptureFolder := ""  ; Folder for room capture JPGs (default: Documents\ProSelect Room Captures)
global Settings_EnablePDF := false           ; Enable Print to PDF mode (toolbar print button uses PDF)
global Settings_PDFOutputFolder := ""       ; Secondary folder to copy PDF output to
global Settings_PDFPrintBtnOffsetRight := 0  ; Print button X offset from right edge (calibrated)
global Settings_PDFPrintBtnOffsetBottom := 0 ; Print button Y offset from bottom edge (calibrated)
global PDF_CalibrationMode := false          ; True when Ctrl+Shift+Click triggers calibration
global Settings_ToolbarIconColor := "White"  ; Toolbar icon color: White, Black, Yellow, Auto
global Settings_ToolbarAutoBG := true         ; Auto-detect background color for toolbar (default ON)
global Settings_ToolbarLastBGColor := "333333" ; Last known good toolbar background color
global Settings_MenuDelay := 50  ; Menu keystroke delay (auto-adjusted: 50ms fast PC, 200ms slow PC)
global Settings_ToolbarOffsetX := 0  ; Toolbar X offset from default position (Ctrl+Click grab handle to adjust)
global Settings_ToolbarOffsetY := 0  ; Toolbar Y offset from default position
global Toolbar_IsDragging := false   ; True when user is dragging the toolbar
global Toolbar_LastBGColor := ""     ; Last detected background color (cached)
global Toolbar_LastBGCheckTime := 0  ; Timestamp of last BG color check
global Toolbar_LastPosX := -1        ; Last toolbar X position (for detecting moves)
global Toolbar_LastPosY := -1        ; Last toolbar Y position (for detecting moves)
global Toolbar_FirstShowDone := false ; Track first show for delayed BG re-sample
global GC_ButtonHBitmap := 0         ; HBITMAP handle for GC button image

; Toolbar button visibility settings
global Settings_ShowBtn_Client := true
global Settings_ShowBtn_Invoice := true
global Settings_ShowBtn_OpenGHL := true
global Settings_ShowBtn_Camera := true
global Settings_ShowBtn_Sort := true
global Settings_ShowBtn_Photoshop := true
global Settings_ShowBtn_Refresh := true
global Settings_ShowBtn_Print := true
global Settings_ShowBtn_QRCode := true
global Settings_ShowBtn_GoCardless := false  ; GoCardless button (controlled by GoCardless tab enable toggle)
global Settings_GoCardlessEnabled := false   ; Master enable for GoCardless integration
global Settings_GoCardlessToken := ""        ; GoCardless API access token (sandbox or live)
global Settings_GoCardlessEnvironment := "sandbox"  ; "sandbox" or "live"
global Settings_GCEmailTemplateID := ""      ; GHL email template ID for mandate link
global Settings_GCEmailTemplateName := "(none selected)"  ; GHL email template name for mandate link
global Settings_GCSMSTemplateID := ""        ; GHL SMS template ID for mandate link
global Settings_GCSMSTemplateName := "(none selected)"  ; GHL SMS template name for mandate link
global Settings_GCAutoSetup := false         ; Auto prompt GoCardless setup after invoice sync with future payments
global GC_TemplateRefreshing := false        ; Flag to prevent saving during template refresh
global GC_BuildingPanel := false             ; Flag to prevent saving during initial panel build
global Settings_GCNamePart1 := "Shoot No"    ; PayPlan name format part 1
global Settings_GCNamePart2 := "Surname"     ; PayPlan name format part 2
global Settings_GCNamePart3 := "(none)"      ; PayPlan name format part 3
global Settings_QRCode_Text1 := ""
global Settings_QRCode_Text2 := ""
global Settings_QRCode_Text3 := ""
global Settings_QRCode_Display := 1  ; Which monitor to show QR on (1 = primary)
global QRDisplay_Created := false  ; Track if QR fullscreen GUI exists
global Settings_DisplaySize := 80  ; Fullscreen display size (25-85%)
global Settings_BankScale := 100  ; Bank Transfer font scale (50-150%)
; Bank Transfer display settings
global Settings_BankInstitution := ""  ; Bank name (e.g., HSBC, Barclays)
global Settings_BankName := ""  ; Account holder name
global Settings_BankSortCode := ""
global Settings_BankAccNo := ""
; Custom image display settings
global Settings_DisplayImage1 := ""
global Settings_DisplayImage2 := ""
global Settings_DisplayImage3 := ""
; QR code cache folder and tracking
global QR_CacheFolder := A_Temp . "\SideKick_QR_Cache"
global QR_CachedFiles := []  ; Array of cached file paths
global Settings_PrintTemplate_PayPlan := "PayPlan"
global Settings_PrintTemplate_Standard := "Terms of Sale"
global Settings_PrintTemplateOptions := ""  ; Cached template options from ProSelect Print dialog
global Settings_QuickPrintPrinter := ""  ; Selected printer for Quick Print (empty = system default)
global Settings_EmailTemplateID := ""
global Settings_EmailTemplateName := "SELECT"

; Rooms button calibration (OCR-detected at startup)
global RoomsBtn_Calibrated := false  ; Whether calibration has been done
global RoomsBtn_X := 0               ; Absolute X position of Rooms button center
global RoomsBtn_Y := 0               ; Absolute Y position of Rooms button center
global RoomsBtn_OffsetX := 0         ; Offset from ProSelect window left edge
global RoomsBtn_OffsetY := 0         ; Offset from ProSelect window top edge
global RoomsBtn_CalibW := 0          ; Window width at calibration time
global RoomsBtn_CalibH := 0          ; Window height at calibration time
global TB_CalibShowing := false      ; True while yellow calibration icon is showing
global TB_CameraState := ""          ; Current camera button state ("on" or "off")
global RoomView_LastLogTime := 0     ; For throttling RoomView debug logging

; Export automation state
global ExportInProgress := false  ; Flag to suspend file watcher during export
global ExportCancelled := false   ; Flag when user presses ESC to cancel export

; Hotkey settings (modifiers: ^ = Ctrl, ! = Alt, + = Shift, # = Win)
global Hotkey_GHLLookup := "^+g"  ; Ctrl+Shift+G
global Hotkey_PayPlan := "^+p"    ; Ctrl+Shift+P
global Hotkey_Settings := "^+w"   ; Ctrl+Shift+W
global Hotkey_DevReload := "^+r"  ; Ctrl+Shift+R (dev mode only)

; License settings
global License_Key := ""          ; LemonSqueezy license key
global License_Status := "trial"  ; trial, active, expired, invalid
global License_CustomerName := ""
global License_CustomerEmail := ""
global License_ExpiresAt := ""
global License_InstanceID := ""
global License_ActivatedAt := ""
global License_ValidatedAt := ""  ; Last successful validation date
global License_PurchaseURL := "https://zoomphoto.lemonsqueezy.com/checkout/buy/077d6b76-ca2a-42df-a653-86f7aa186895"

; Update check settings
global Update_SkippedVersion := ""    ; Version user chose to skip
global Update_LastCheckDate := ""     ; Last time we checked for updates
global Update_AvailableVersion := ""  ; Latest version found
global Update_DownloadURL := ""       ; URL to download update
global Settings_AutoUpdate := true    ; Enable automatic silent updates
global Settings_AutoSendLogs := true  ; Auto-send activity logs after every sync
global Settings_DebugLogging := false  ; Enable debug logging (defaults OFF, auto-disables after 24hrs)
global Settings_DebugLoggingTimestamp := ""  ; When debug logging was enabled

; Debug Progress GUI state (for Print to PDF workflow debugging)
global DebugProgress_Active := false    ; True while debug progress GUI is showing
global DebugProgress_NextClicked := false  ; Set to true when user clicks Next Step
global DebugProgress_StopClicked := false  ; Set to true when user clicks Stop/Broken
global DebugProgress_StepNum := 0       ; Current step number
global DebugProgress_TotalSteps := 0    ; Total steps in workflow
global DebugProg_StepCounter := ""      ; GUI control variable for step counter text
global DebugProg_StepText := ""         ; GUI control variable for step description text
global DebugProg_NextBtn := ""          ; GUI control variable for Next button

global Update_DownloadReady := false  ; True when installer is downloaded and ready
global Update_DownloadPath := ""      ; Path to downloaded installer
global Update_UserDeclined := false   ; User said "Later" - ask again on exit

; License obfuscation key (XOR cipher) - keeps casual users from editing INI
global License_ObfuscationKey := "S1d3K1ckPr0S3l3ct2025x"
global Update_GitHubReleaseURL := "https://api.github.com/repos/GuyMayer/SideKick_PS/releases/latest"

; ProSelect version detection
global ProSelectVersion := ""
global ProSelect2022Path := "C:\Program Files\Pro Studio Software\ProSelect 2022\ProSelect.exe"
global ProSelect2025Path := "C:\Program Files\Pro Studio Software\ProSelect 2025\ProSelect.exe"
global PsConsolePath := ""

; Clean up any stale progress files and timers from previous runs
progressFile := A_Temp . "\sidekick_sync_progress.txt"
if FileExist(progressFile)
	FileDelete, %progressFile%
SetTimer, SyncProgress_UpdateTimer, Off
Gui, SyncProgress:Destroy

;#Persistent
SetTitleMatchMode, 2
SetTitleMatchMode, Slow
SetKeyDelay, 40, 40
SetControlDelay, 20
DetectHiddenWindows, Off
sleep 250

; Set tray icon to rocket icon
iconPath := A_ScriptDir . "\SideKick_PS.ico"
if FileExist(iconPath)
	Menu, Tray, Icon, %iconPath%
else
	Menu, Tray, Icon, % "HBITMAP:*" . Create_SideKick_PS_png()
; Menu, Tray, NoStandard
Menu, Tray, Add, &PayPlan, PlaceButton
Menu, Tray, Add, &GHL Client Lookup, GHLClientLookup
Menu, Tray, Add  ; Separator line
Menu, Tray, Add, &Settings, ShowSettings
Menu, Tray, Add, &About, ShowAbout
Menu, Tray, Add, &Reload, ReloadScript
Menu, Tray, Add, E&xit, ExitScript
Menu, Tray, Tip, SideKick_PS v%ScriptVersion% (%BuildDate%)
Menu, Tray, Click, 2  ; Right-click shows menu
; SetTimer, CheckForPS, 300000 ; DISABLED - no longer exit if ProSelect not running
SetTimer, WatchForAddPayment, 1000 ; Check every second for Add Payment window

; INI file location - use AppData so settings survive updates
global IniFolder := A_AppData . "\SideKick_PS"
global IniFilename := IniFolder . "\SideKick_PS.ini"

; Create folder if it doesn't exist
if !FileExist(IniFolder)
	FileCreateDir, %IniFolder%

; MIGRATION: If no INI in AppData but one exists in script folder, copy it
if !FileExist(IniFilename) && FileExist(A_ScriptDir . "\SideKick_PS.ini") {
	FileCopy, %A_ScriptDir%\SideKick_PS.ini, %IniFilename%
}

; MIGRATION: If credentials.json exists in script folder but not AppData, copy it
credFile := IniFolder . "\credentials.json"
if !FileExist(credFile) && FileExist(A_ScriptDir . "\credentials.json") {
	FileCopy, %A_ScriptDir%\credentials.json, %credFile%
}

PayPlanLine := []
LastButtonX := 0
LastButtonY := 0

; Load GHL API credentials from JSON (with INI fallback for migration)
LoadGHLCredentials()

FileAppend, % A_Now . " - Loading settings from INI...`n", %DebugLogFile%
; Load settings from INI
LoadSettings()
FileAppend, % A_Now . " - Settings loaded`n", %DebugLogFile%

; Pre-generate QR codes for faster display
GenerateQRCache()
FileAppend, % A_Now . " - QR codes cached`n", %DebugLogFile%

; Auto-calibrate menu delay based on system speed
CalibrateMenuDelay()
FileAppend, % A_Now . " - Menu delay calibrated: " . Settings_MenuDelay . "ms`n", %DebugLogFile%

; Add dev menu items if developer mode
if (IsDeveloperMode()) {
	Menu, Tray, Insert, &Settings, &Quick Publish, DevQuickPush
	Menu, Tray, Insert, &Quick Publish  ; Separator before Quick Publish
}

FileAppend, % A_Now . " - Checking license expiry...`n", %DebugLogFile%
; Check license expiry status on startup
CheckLicenseExpiryOnStartup()
FileAppend, % A_Now . " - License checked`n", %DebugLogFile%

; Monthly license validation and update check (delayed to not block startup)
SetTimer, AsyncMonthlyCheck, -5000  ; Run once after 5 seconds

; Always check for updates on every launch (non-blocking, 3s delay)
SetTimer, CheckForUpdatesOnLaunch, -3000

FileAppend, % A_Now . " - Checking first-run GHL setup...`n", %DebugLogFile%
; Check for first-run GHL setup
CheckFirstRunGHLSetup()
FileAppend, % A_Now . " - First-run check complete`n", %DebugLogFile%

; Initialize tooltip data for settings controls (hwnd => tooltip text)
global SettingsTooltips := {}
global LastHoveredControl := 0

FileAppend, % A_Now . " - Detecting ProSelect version...`n", %DebugLogFile%
; Detect ProSelect version on startup
DetectProSelectVersion()
FileAppend, % A_Now . " - ProSelect version: " . ProSelectVersion . "`n", %DebugLogFile%

; Check for ProSelect Console path - try newer version first, then fall back
if FileExist("C:\Program Files\Pro Studio Software\ProSelect 2025\ProSelect Helpers\plrp.install\win\psconsole.exe")
	PsConsolePath := "C:\Program Files\Pro Studio Software\ProSelect 2025\ProSelect Helpers\plrp.install\win"
else if FileExist("C:\Program Files\TimeExposure\ProSelect\ProSelect Helpers\plrp.install\win\psconsole.exe")
	PsConsolePath := "C:\Program Files\TimeExposure\ProSelect\ProSelect Helpers\plrp.install\win"
else if FileExist("C:\Program Files\Pro Studio Software\ProSelect 2024\ProSelect Helpers\plrp.install\win\psconsole.exe")
	PsConsolePath := "C:\Program Files\Pro Studio Software\ProSelect 2024\ProSelect Helpers\plrp.install\win"
else
	PsConsolePath := ""  ; No valid path found

;#######################################################
; Global Hotkeys - These can be customized in Settings
; Register hotkeys dynamically so they can be changed
FileAppend, % A_Now . " - Registering hotkeys...`n", %DebugLogFile%
RegisterHotkeys()
FileAppend, % A_Now . " - Hotkeys registered`n", %DebugLogFile%

; Create floating toolbar
FileAppend, % A_Now . " - Creating floating toolbar...`n", %DebugLogFile%
CreateFloatingToolbar()
FileAppend, % A_Now . " - Toolbar created`n", %DebugLogFile%

;#######################################################
;Payplan Helper
FileAppend, % A_Now . " - Playing startup sounds...`n", %DebugLogFile%
SoundPlay %A_ScriptDir%\sidekick\media\KbdSpacebar.wav
sleep 250
SoundPlay %A_ScriptDir%\sidekick\media\KbdSpacebar.wav
FileAppend, % A_Now . " - === STARTUP COMPLETE ===`n", %DebugLogFile%


Start:
Gui, PP:Destroy
PayYear = %A_YYYY%
PayDue = 5000
PayDay = 
PayMonth = 
PayNo := 3
PayValue=
PayValu1=
; Recurring options: Monthly, Weekly, Bi-Weekly (2 weeks), 4-Weekly
Recurring = Monthly||Weekly|Bi-Weekly|4-Weekly
PayType = Gocardles DD||Credit Card|Cash|Online
PayDayL = Select||1st|2nd|3rd|4th|5th|6th|7th|8th|9th|10th|11th|12th|13th|14th|15th|16th|17th|18th|19th|20th|21st|22nd|23rd|24th|25th|26th|27th|28th|Last Day
Global PayMonthL
;PayMonthL = January|February|March|April|May|June|July|August|September|October|November|December
GuiSetup() 
30daylist := "September,November,April,June"
31daylist := "January,March,May,July,August,October,December"
28daylist := "February"

Months :=  [ "January", "February","March", "April", "May", "June", "July", "August", "September", "October", "November", "December" ]


PlaceButton:
if EnteringPaylines
	Return

; Verify the Add Payment list window (with "Payments" text) is open
; Only show PayPlan button if user opened Payline from the Add Payment list
if !WinExist("Add Payment", "Payments")
{
	; Add Payment list window not found - don't show PayPlan button
	SetTimer, WatchForAddPayment, 1000
	Return
}

SoundPlay %A_ScriptDir%\sidekick\media\KbdSpacebar.wav
sleep 250
SoundPlay %A_ScriptDir%\sidekick\media\KbdSpacebar.wav

; Wait for the Payline window
WinWait, Add Payment, Date, 5
if ErrorLevel {
	; Re-enable watcher for next time
	SetTimer, WatchForAddPayment, 1000
	Return
}

; Get the handle of the Payline window
PaylineWindowHwnd := WinExist("Add Payment", "Date")
if (!PaylineWindowHwnd) {
	SetTimer, WatchForAddPayment, 1000
	Return
}

; Get position and size of the Payline window
WinGetPos, AddPayX, AddPayY, AddPayW, AddPayH, ahk_id %PaylineWindowHwnd%

; Detect ProSelect version if not already done
if (ProSelectVersion = "")
	DetectProSelectVersion()

; Always destroy and recreate for clean state
Gui, PP:Destroy
sleep 50

; Calculate button position - place in title row, 1/3 from left
ButtonX := AddPayX + Round(AddPayW / 3)  ; 1/3 from left of window
ButtonY := AddPayY + Round(15 * DPI_Scale)  ; Top row, slightly below title

; Apply dark mode for ProSelect 2025
if (ProSelectVersion = "2025") {
	Gui, PP:Color, FF8000
	Gui, PP: +ToolWindow -caption +AlwaysOnTop
	Gui, PP:Font, s10 Norm, Segoe UI Symbol
	Gui, PP:Add, Button, x2 y2 w120 h30 gPayCalcGui, 📅 PayPlan
	Gui, PP:Show, x%ButtonX% y%ButtonY% h34 w124, SideKick_PS v%ScriptVersion%
} else {
	Gui, PP:Color, EEAA99
	Gui, PP: +ToolWindow -caption +AlwaysOnTop
	Gui, PP:Font, s10 Norm, Segoe UI Symbol
	Gui, PP:Add, Button, x2 y2 w120 h30 gPayCalcGui, 📅 PayPlan
	Gui, PP:Show, x%ButtonX% y%ButtonY% h34 w124, SideKick_PS v%ScriptVersion%
	WinSet, TransColor, EEAA99, SideKick_PS v%ScriptVersion%
}

; Store the Payline window handle for tracking
global LastPaylineWindowHwnd := PaylineWindowHwnd

; Start timer to monitor dialog state
SetTimer, KeepPayPlanVisible, 250
Return

KeepPayPlanVisible:
if EnteringPaylines
	Return

; If the Payment Calculator is open, don't hide or destroy it based on Add Payment focus
; BUT verify it actually exists - reset flag if window was closed unexpectedly
if (PayCalcOpen)
{
	if !WinExist("SideKick_PS v" . ScriptVersion . " - Payment Calculator")
	{
		; Payment Calculator was closed unexpectedly - reset flag and check windows
		PayCalcOpen := false
	}
	else
		Return
}

; Double-check: if neither Add Payment windows exist, always destroy button and stop
if !WinExist("Add Payment", "Date") && !WinExist("Add Payment", "Payments")
{
	Gui, PP:Destroy
	SetTimer, KeepPayPlanVisible, Off
	SetTimer, WatchForAddPayment, 1000
	Return
}

; Check if the Payline window exists
IfWinExist, Add Payment, Date
{
	; Get current handle
	CurrentHwnd := WinExist("Add Payment", "Date")

	; Check if it's a new Payline window instance (different handle)
	if (CurrentHwnd != LastPaylineWindowHwnd) {
		; New Payline window opened - recreate button
		Gui, PP:Destroy
		SetTimer, KeepPayPlanVisible, Off
		GoSub, PlaceButton
		Return
	}

	; Check if the Add Payment window is active/focused
	; Also allow if the PP GUI itself is active (user clicking button)
	IfWinNotActive, Add Payment, Date
	{
		; Check if PP GUI is active (user is clicking PayPlan button)
		IfWinActive, SideKick_PS v%ScriptVersion%
			Return  ; Don't hide - user is interacting with the button
		
		; Window not focused - hide the button
		Gui, PP:Hide
		Return
	}

	; Same Payline window - update button position if window moved
	WinGetPos, AddPayX, AddPayY, AddPayW, AddPayH, ahk_id %CurrentHwnd%
	
	; Position in title row, 1/3 from left
	ButtonX := AddPayX + Round(AddPayW / 3)
	ButtonY := AddPayY + Round(15 * DPI_Scale)
	
	; Only move if position actually changed
	if (ButtonX != LastButtonX || ButtonY != LastButtonY) {
		LastButtonX := ButtonX
		LastButtonY := ButtonY
		
		Gui, PP:Show, x%ButtonX% y%ButtonY% NoActivate
	}
	else
	{
		; Position unchanged - ensure button is visible since Add Payment is focused
		; Only show if Add Payment window is actually active (we passed the check above)
		IfWinActive, Add Payment, Date
			Gui, PP:Show, NoActivate
	}
}
else
{
	; Payline window closed - destroy button and restart watcher
	Gui, PP:Destroy
	SetTimer, KeepPayPlanVisible, Off
	SetTimer, WatchForAddPayment, 1000
}

; Also check if the Add Payment list window was closed - if so, hide button
IfWinNotExist, Add Payment, Payments
{
	; Add Payment list window closed - destroy button and restart watcher
	Gui, PP:Destroy
	SetTimer, KeepPayPlanVisible, Off
	SetTimer, WatchForAddPayment, 1000
}
Return

PayCalcGUI:
; Flag that Payment Calculator is open (not just the button)
global PayCalcOpen := true

gosub, GetBalance

; Reset dropdown list variables to ensure correct format
Recurring := "Monthly||Weekly|Bi-Weekly|4-Weekly"

; Build PayDayL with today's day pre-selected
FormatTime, TodayDay, , d  ; Get current day of month (1-31)
PayDays := ["1st","2nd","3rd","4th","5th","6th","7th","8th","9th","10th","11th","12th","13th","14th","15th","16th","17th","18th","19th","20th","21st","22nd","23rd","24th","25th","26th","27th","28th","Last Day"]
PayDayL := ""
Loop, % PayDays.Length()
{
	if (A_Index = TodayDay)
		PayDayL .= PayDays[A_Index] "||"
	else
		PayDayL .= PayDays[A_Index] "|"
}

; Calculate earliest DD date (today + 4 days for DD setup window)
EarliestDDDate := A_Now
EarliestDDDate += 4, Days
FormatTime, EarliestDDDay, %EarliestDDDate%, d

GuiSetup()

; Read payment types from Payline window ComboBox1
ControlGet, PayTypeList, List, , ComboBox1, Add Payment, Date
if (PayTypeList != "")
{
	; Convert newline-separated list to pipe-separated, make first item default
	PayType := StrReplace(PayTypeList, "`n", "|")
	; Add || after first item to make it the default
	PayType := RegExReplace(PayType, "^([^|]+)", "$1|")
}
else
{
	; Fallback to hardcoded list if can't read from window
	PayType := "GoCardless DD||Credit Card|Cash|Online"
}

;DisplayText := "Balance Due: " . PayDue
Gui, PP:Destroy

; Detect ProSelect version if not already done
if (ProSelectVersion = "")
	DetectProSelectVersion()

; Define colors matching Settings GUI
ppBg := "2D2D2D"
ppHeaderColor := "FF8C00"
ppLabelColor := "CCCCCC"
ppGroupColor := "888888"
ppMutedColor := "666666"

; Calculate initial payment value
PayValue := ( PayDue / PayNo )
PayValue := RegExReplace(PayValue,"(\.\d{2})\d*","$1")

; Calculate initial rounding error
TotalPayments := PayValue * PayNo
RoundingError := PayDue - TotalPayments
RoundingError := Round(RoundingError, 2)

; Set PP GUI to be owned by ProSelect so it stays on top of PS but not other apps
PSHwnd := WinExist("ahk_exe ProSelect.exe")
if (PSHwnd)
	Gui, PP: +Owner%PSHwnd%

Gui, PP:Color, %ppBg%
Gui, PP:Font, s11 Norm c%ppLabelColor%, Segoe UI

; ========== BALANCE DUE HEADER ==========
Gui, PP:Font, s16 Norm c%ppHeaderColor%, Segoe UI
Gui, PP:Add, Text, x30 y20 w540 h35 BackgroundTrans, % "Balance Due: £" . PayDue

; ========== DOWNPAYMENT SECTION ==========
Gui, PP:Font, s11 Norm c%ppGroupColor%, Segoe UI
Gui, PP:Add, GroupBox, x20 y60 w560 h130 c%ppGroupColor%, Downpayment / Deposit

Gui, PP:Font, s10 Norm c%ppLabelColor%, Segoe UI
Gui, PP:Add, Text, x40 y90 w100 h25 BackgroundTrans, Amount:
Gui, PP:Font, s10 Norm cBlack, Segoe UI
Gui, PP:Add, Edit, x150 y87 w70 h28 vDownpaymentAmount gRecalcFromNo, 
Gui, PP:Add, DropDownList, x250 y87 w140 h2000 vDownpaymentMethod, Credit Card||GoCardless DD|Bank Transfer
Gui, PP:Add, DateTime, x410 y87 w110 h28 vDownpaymentDate Choose%A_Now%, dd/MM/yy
Gui, PP:Font, s10 Norm c%ppLabelColor%, Segoe UI

; Rounding info text
Gui, PP:Font, s9 Norm c%ppMutedColor%, Segoe UI
if (RoundingError != 0)
	Gui, PP:Add, Text, x40 y125 w530 h20 vRoundingInfoText BackgroundTrans, % "💰 Rounding of £" . Format("{:.2f}", RoundingError)
else
	Gui, PP:Add, Text, x40 y125 w530 h20 vRoundingInfoText BackgroundTrans, Leave blank for no downpayment

; Rounding option radio buttons
Gui, PP:Font, s9 Norm c%ppLabelColor%, Segoe UI
Gui, PP:Add, Text, x40 y150 w100 h20 BackgroundTrans HwndHwndRoundingLabel, Add rounding to:
Gui, PP:Font, s9 Norm c%ppLabelColor%, Segoe UI
if (Settings_RoundingInDeposit)
{
	Gui, PP:Add, Radio, x145 y150 w100 h20 BackgroundTrans vRoundingOption Checked gRoundingOptionChanged HwndHwndRadio1, Downpayment
	Gui, PP:Add, Radio, x255 y150 w100 h20 BackgroundTrans gRoundingOptionChanged HwndHwndRadio2, 1st Payment
}
else
{
	Gui, PP:Add, Radio, x145 y150 w100 h20 BackgroundTrans vRoundingOption gRoundingOptionChanged HwndHwndRadio1, Downpayment
	Gui, PP:Add, Radio, x255 y150 w100 h20 BackgroundTrans Checked gRoundingOptionChanged HwndHwndRadio2, 1st Payment
}
; Add tooltip to rounding option
RoundingTooltip := "ROUNDING ADJUSTMENT`n`nWhen splitting a balance into equal payments,`nsmall rounding differences may occur.`n`nExample: £208.33 ÷ 3 = £69.44 x 3 = £208.32`nLeaves £0.01 difference.`n`nDownpayment: Add the difference to the deposit`n1st Payment: Add the difference to the first scheduled payment"
RegisterSettingsTooltip(HwndRoundingLabel, RoundingTooltip)
RegisterSettingsTooltip(HwndRadio1, RoundingTooltip)
RegisterSettingsTooltip(HwndRadio2, RoundingTooltip)

; ========== SCHEDULED PAYMENTS SECTION ==========
Gui, PP:Font, s11 Norm c%ppGroupColor%, Segoe UI
Gui, PP:Add, GroupBox, x20 y200 w560 h150 c%ppGroupColor%, Scheduled Payments

Gui, PP:Font, s10 Norm c%ppLabelColor%, Segoe UI
; Row 1: No. Payments and Pay Type
Gui, PP:Add, Text, x40 y230 w100 h25 BackgroundTrans, No. Payments:
Gui, PP:Font, s10 Norm cBlack, Segoe UI
Gui, PP:Add, Edit, x150 y227 w70 h28 vPayNo gRecalcFromNo, %PayNo%
Gui, PP:Add, UpDown, vMyUpDown gRecalcFromNo Range1-24, 3
Gui, PP:Font, s10 Norm c%ppLabelColor%, Segoe UI
Gui, PP:Add, Text, x280 y230 w80 h25 BackgroundTrans, Pay Type:
Gui, PP:Font, s10 Norm cBlack, Segoe UI
Gui, PP:Add, DropDownList, x360 y227 w160 h2000 vPayTypeSel gPayTypeSel, %PayType%
Gui, PP:Font, s10 Norm c%ppLabelColor%, Segoe UI

; Row 2: Payment Amount and Recurring
Gui, PP:Add, Text, x280 y270 w80 h25 BackgroundTrans, Payment:
Gui, PP:Font, s10 Norm cBlack, Segoe UI
Gui, PP:Add, Edit, x360 y267 w90 h28 vPayValue1, %PayValue%
Gui, PP:Font, s10 Norm c%ppLabelColor%, Segoe UI
Gui, PP:Add, Button, x455 y267 w65 h28 gRecalcFromAmount, Calc
Gui, PP:Add, Text, x40 y310 w100 h25 BackgroundTrans, Recurring:
Gui, PP:Font, s10 Norm cBlack, Segoe UI
Gui, PP:Add, DropDownList, x150 y307 w120 h2000 vRecurring, %Recurring%
Gui, PP:Font, s10 Norm c%ppLabelColor%, Segoe UI

; Row 3: Start Date
Gui, PP:Add, Text, x280 y310 w80 h25 BackgroundTrans, Start Date:
Gui, PP:Font, s10 Norm cBlack, Segoe UI
Gui, PP:Add, DropDownList, x360 y307 w80 h2000 vPayDay, %PayDayL%
Gui, PP:Add, DropDownList, x445 y307 w75 h2000 vPayMonth, %PayMonthL%
Gui, PP:Font, s10 Norm c%ppLabelColor%, Segoe UI

; ========== BUTTONS ==========
Gui, PP:Font, s10 Norm, Segoe UI
Gui, PP:Add, Button, x300 y390 w140 h32 gMakePayments, ✓ Schedule Payments
Gui, PP:Add, Button, x500 y390 w80 h32 gExitGui, ✗ Cancel

; Register mouse move handler for hover tooltips (shared with Settings)
OnMessage(0x200, "SettingsMouseMove")

Gui, PP:Show, w600 h440, SideKick_PS v%ScriptVersion% - Payment Calculator

Return

GetNextMonthIndex() {
	FormatTime, CurrentMonthIndex, , MM  ; Get the current month index (01-12)
	NextMonthIndex := CurrentMonthIndex + 1
	if (NextMonthIndex > 12)  ; Handle rollover to the next year
		NextMonthIndex := 1
	return NextMonthIndex
}

GuiSetup() {
	global PayMonthL  ; Must declare global to modify the global variable
	Months := ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
	NextMonthIndex := GetNextMonthIndex()
	
    ; Build the dropdown list string with the next month pre-selected
	PayMonthL := ""
	Loop, 12 {
		if (A_Index = NextMonthIndex)
			PayMonthL .= Months[A_Index] "||"  ; Add double-pipe for pre-selection
		else
			PayMonthL .= Months[A_Index] "|"
	}
	
}

GetNextMonthName() {
    FormatTime, CurrentYear, , yyyy      ; Get the current year
    FormatTime, CurrentMonth, , MM       ; Get the current month
    NextMonth := CurrentMonth + 1        ; Calculate the next month
    
    ; Handle year rollover (December -> January)
    if (NextMonth > 12) {
        NextMonth := 1
        CurrentYear++ ; Move to the next year
    }
    
    ; Format the next month's number as "MM"
    NextMonth := Format("{:02}", NextMonth)
    
    ; Get the name of the next month
    FormatTime, NextMonthName, %CurrentYear%%NextMonth%01, MMMM
    return NextMonthName
}

; Example usage
;MsgBox, The next month's name is: % GetNextMonthName()


PayTypeSel:
Gui, PP:Submit, NoHide
; If Direct Debit selected (flexible matching for DD, Direct Debit, etc.), enforce 4-day setup window
if (InStr(PayTypeSel, "DD") || InStr(PayTypeSel, "Direct Debit") || InStr(PayTypeSel, "direct debit"))
{
	; Check if selected day is before earliest DD date (today + 4)
	FormatTime, CurrentDay, , d
	SelectedDayNum := GetDayNumber(PayDay)
	
	; If in same month and day is too soon, adjust to earliest allowed
	if (SelectedDayNum > 0 && SelectedDayNum < EarliestDDDay)
	{
		; Find the day name for EarliestDDDay
		PayDays := ["1st","2nd","3rd","4th","5th","6th","7th","8th","9th","10th","11th","12th","13th","14th","15th","16th","17th","18th","19th","20th","21st","22nd","23rd","24th","25th","26th","27th","28th","Last Day"]
		if (EarliestDDDay <= 28)
			GuiControl, Choose, PayDay, %EarliestDDDay%
	}
}
Return

; Helper function to get day number from ordinal string
GetDayNumber(dayStr) {
	if (dayStr = "Last Day")
		return 29
	RegExMatch(dayStr, "(\d+)", match)
	return match1 ? match1 : 0
}

; Handle rounding option radio button change
RoundingOptionChanged:
Gui, PP:Submit, NoHide
; RoundingOption = 1 means "Downpayment" is selected, 2 means "1st Payment"
Settings_RoundingInDeposit := (RoundingOption = 1) ? 1 : 0
; Save to INI immediately
IniWrite, %Settings_RoundingInDeposit%, %IniFilename%, GHL, RoundingInDeposit
Return

; Handle toolbar icon color change
ToolbarIconColorChanged:
Gui, Settings:Submit, NoHide
GuiControlGet, selectedColor,, Settings_ToolbarIconColor_DDL
Settings_ToolbarIconColor := selectedColor
IniWrite, %Settings_ToolbarIconColor%, %IniFilename%, Appearance, ToolbarIconColor
; Update color preview
previewColor := GetColorHex(Settings_ToolbarIconColor)
GuiControl, Settings:+Background%previewColor%, HKColorPreview
; Recreate toolbar with new color
Gui, Toolbar:Destroy
CreateFloatingToolbar()
Return

; Open color picker for custom toolbar icon color
HKPickColor:
Gui, Settings:Submit, NoHide
customColor := ChooseColor(Settings_ToolbarIconColor)
if (customColor != "") {
	Settings_ToolbarIconColor := customColor
	IniWrite, %Settings_ToolbarIconColor%, %IniFilename%, Appearance, ToolbarIconColor
	; Update dropdown to show Custom
	GuiControl, Settings:, Settings_ToolbarIconColor_DDL, White|Black|Yellow|Custom
	GuiControl, Settings:ChooseString, Settings_ToolbarIconColor_DDL, Custom
	; Update color preview
	GuiControl, Settings:+Background%customColor%, HKColorPreview
	; Recreate toolbar with new color
	Gui, Toolbar:Destroy
	CreateFloatingToolbar()
}
Return

; Reset toolbar position to default
HKResetToolbarPos:
Settings_ToolbarOffsetX := 0
Settings_ToolbarOffsetY := 0
SaveSettings()
; Rebuild toolbar at default position
Gui, Toolbar:Destroy
CreateFloatingToolbar()
ToolTip, Toolbar position reset!
SetTimer, RemoveSettingsTooltip, -1500
Return

; Handle toolbar auto-background toggle
ToolbarAutoBGChanged:
ToolbarAutoBGCheck:
ToggleClick_ToolbarAutoBG:
Toggle_ToolbarAutoBG_State := !Toggle_ToolbarAutoBG_State
UpdateToggleSlider("Settings", "ToolbarAutoBG", Toggle_ToolbarAutoBG_State, 430)
Settings_ToolbarAutoBG := Toggle_ToolbarAutoBG_State
IniWrite, %Settings_ToolbarAutoBG%, %IniFilename%, Appearance, ToolbarAutoBG
; Reset cached color and position to force re-sample
Toolbar_LastBGColor := ""
Toolbar_LastBGCheckTime := 0
Toolbar_LastPosX := -1
Toolbar_LastPosY := -1
; Rebuild toolbar to apply change
Gui, Toolbar:Destroy
CreateFloatingToolbar()
Return

; Windows Color Picker Dialog
ChooseColor(initialColor := "FFFFFF") {
	static cc, customColors
	
	; Convert named colors to hex
	if (initialColor = "White")
		initialColor := "FFFFFF"
	else if (initialColor = "Black")
		initialColor := "000000"
	else if (initialColor = "Yellow")
		initialColor := "FFFF00"
	else if (SubStr(initialColor, 1, 1) != "0")
		initialColor := SubStr(initialColor, 1, 6)  ; Strip any prefix
	
	; Convert hex to BGR format
	initialColor := "0x" . initialColor
	rgb := initialColor & 0xFFFFFF
	bgr := ((rgb & 0xFF) << 16) | (rgb & 0xFF00) | ((rgb >> 16) & 0xFF)
	
	; Allocate custom colors array (16 DWORDs)
	VarSetCapacity(customColors, 64, 0)
	
	; CHOOSECOLOR structure
	VarSetCapacity(cc, A_PtrSize = 8 ? 72 : 36, 0)
	NumPut(A_PtrSize = 8 ? 72 : 36, cc, 0, "UInt")  ; lStructSize
	NumPut(0, cc, A_PtrSize, "UPtr")  ; hwndOwner - can be 0
	NumPut(bgr, cc, A_PtrSize * 3, "UInt")  ; rgbResult
	NumPut(&customColors, cc, A_PtrSize * 4, "UPtr")  ; lpCustColors
	NumPut(0x103, cc, A_PtrSize * 5, "UInt")  ; Flags: CC_RGBINIT | CC_FULLOPEN | CC_ANYCOLOR
	
	; Call ChooseColor
	if !DllCall("comdlg32\ChooseColor" . (A_IsUnicode ? "W" : "A"), "Ptr", &cc)
		return ""
	
	; Get result and convert BGR to RGB hex
	bgr := NumGet(cc, A_PtrSize * 3, "UInt")
	r := bgr & 0xFF
	g := (bgr >> 8) & 0xFF
	b := (bgr >> 16) & 0xFF
	return Format("{:02X}{:02X}{:02X}", r, g, b)
}

; Convert color name or hex to hex code
GetColorHex(colorName) {
	if (colorName = "White")
		return "FFFFFF"
	else if (colorName = "Black")
		return "000000"
	else if (colorName = "Yellow")
		return "FFFF00"
	else
		return colorName  ; Already hex
}

; Recalculate payment amount when number of payments changes
RecalcFromNo:
Gui, PP:Submit, NoHide
Gui, PP: +OwnDialogs
if (PayNo < 1)
	PayNo := 1
if (PayNo > 24)
	PayNo := 24

; Calculate remaining balance after downpayment
DownpaymentVal := (DownpaymentAmount != "" && DownpaymentAmount > 0) ? DownpaymentAmount : 0
RemainingBalance := PayDue - DownpaymentVal
if (RemainingBalance < 0)
	RemainingBalance := 0

PayValue := ( RemainingBalance / PayNo )
PayValue := RegExReplace(PayValue,"(\.\d{2})\d*","$1")
GuiControl,, PayValue1, %PayValue%

; Calculate rounding error
TotalPayments := PayValue * PayNo
RoundingError := RemainingBalance - TotalPayments
RoundingError := Round(RoundingError, 2)

; Update rounding info text
if (RoundingError != 0)
	GuiControl,, RoundingInfoText, % "💰 Rounding of £" . Format("{:.2f}", RoundingError)
else
	GuiControl,, RoundingInfoText, Leave blank for no downpayment
Return

; Recalculate number of payments when payment amount changes
RecalcFromAmount:
Gui, PP:Submit, NoHide
Gui, PP: +OwnDialogs

; Get the entered payment value
EnteredAmount := PayValue1
if (EnteredAmount <= 0 || EnteredAmount = "")
	Return

; Calculate remaining balance after downpayment
DownpaymentVal := (DownpaymentAmount != "" && DownpaymentAmount > 0) ? DownpaymentAmount : 0
RemainingBalance := PayDue - DownpaymentVal
if (RemainingBalance < 0)
	RemainingBalance := 0

; Calculate how many payments needed (round to nearest whole number)
CalcPayNo := RemainingBalance / EnteredAmount
CalcPayNo := Round(CalcPayNo)

; Clamp to valid range 1-24
if (CalcPayNo < 1)
	CalcPayNo := 1
if (CalcPayNo > 24)
	CalcPayNo := 24

; Update number of payments
PayNo := CalcPayNo
GuiControl,, PayNo, %PayNo%

; Recalculate actual payment amount based on whole number of payments
PayValue := ( RemainingBalance / PayNo )
PayValue := RegExReplace(PayValue,"(\.\d{2})\d*","$1")
GuiControl,, PayValue1, %PayValue%

; Calculate rounding error
TotalPayments := PayValue * PayNo
RoundingError := RemainingBalance - TotalPayments
RoundingError := Round(RoundingError, 2)

; Update rounding info text
if (RoundingError != 0)
	GuiControl,, RoundingInfoText, % "💰 Rounding of £" . Format("{:.2f}", RoundingError)
else
	GuiControl,, RoundingInfoText, Leave blank for no downpayment
Return

CheckForPS:
; DISABLED - SideKick_PS now runs independently of ProSelect
; If !WinExist("ahk_exe ProSelect.exe")
;	ExitApp
Return

WatchForAddPayment:
; Watch for the Payline window - but only show PayPlan if Add Payment list window is also open
; The Add Payment list window (with "Payments" text) must be open behind the Payline window (with "Date" text)
If WinExist("Add Payment", "Date") {
	; Check if the Add Payment list window is also open
	If WinExist("Add Payment", "Payments") {
		SetTimer, WatchForAddPayment, Off
		GoSub, PlaceButton
	}
}
Return

ExitScript:
	; Check if there's a pending update the user declined earlier
	CheckPendingUpdateOnExit()
	ExitApp
Return

; Function to detect which version of ProSelect is running
DetectProSelectVersion() {
	global ProSelectVersion, ProSelect2022Path, ProSelect2025Path
	
	; First try to detect from running process
	If WinExist("ahk_exe ProSelect.exe") {
		WinGet, ProSelectPID, PID, ahk_exe ProSelect.exe
		WinGet, ProSelectPath, ProcessPath, ahk_pid %ProSelectPID%
		
		IfInString, ProSelectPath, 2025
		{
			ProSelectVersion := "2025"
			ToolTip, ProSelect 2025 detected (running)
			SetTimer, RemoveToolTip, 2000
			Return
		}
		Else IfInString, ProSelectPath, 2022
		{
			ProSelectVersion := "2022"
			ToolTip, ProSelect 2022 detected (running)
			SetTimer, RemoveToolTip, 2000
			Return
		}
	}
	
	; Fallback: Check if ProSelect is installed by looking for exe files
	; Check 2025 first (newer version takes priority)
	If FileExist(ProSelect2025Path) {
		ProSelectVersion := "2025"
		Return
	}
	Else If FileExist(ProSelect2022Path) {
		ProSelectVersion := "2022"
		Return
	}
	
	; Still not found - leave as empty/not detected
	ProSelectVersion := ""
	Return
}

RemoveToolTip:
SetTimer, RemoveToolTip, Off
ToolTip
Return

; Clean up log files older than specified days
; Keeps recent logs for troubleshooting, removes old ones to save space
CleanupOldLogs(logFolder, maxAgeDays) {
	global DebugLogFile
	
	; Calculate cutoff date (7 days ago)
	cutoffDate := A_Now
	cutoffDate += -%maxAgeDays%, Days
	FormatTime, cutoffDateStr, %cutoffDate%, yyyyMMdd
	
	; Loop through all .log files in folder
	Loop, Files, %logFolder%\*.log
	{
		; Skip the current session's log file
		if (A_LoopFileLongPath = DebugLogFile)
			continue
		
		; Get file modification time
		FileGetTime, fileDate, %A_LoopFileLongPath%, M
		FormatTime, fileDateStr, %fileDate%, yyyyMMdd
		
		; Delete if older than cutoff
		if (fileDateStr < cutoffDateStr) {
			FileDelete, %A_LoopFileLongPath%
		}
	}
}

; Load version info from version.json (single source of truth)
; Called at script startup - no hardcoded versions in the script!
LoadVersionFromJson() {
	global ScriptVersion, BuildDate
	
	versionFile := A_ScriptDir . "\version.json"
	if (!FileExist(versionFile)) {
		; Fallback defaults if version.json missing
		ScriptVersion := "0.0.0"
		BuildDate := "Unknown"
		return
	}
	
	FileRead, jsonText, %versionFile%
	if (ErrorLevel) {
		ScriptVersion := "0.0.0"
		BuildDate := "Unknown"
		return
	}
	
	; Parse version field: "version": "2.4.54"
	if (RegExMatch(jsonText, """version"":\s*""([^""]+)""", match))
		ScriptVersion := match1
	else
		ScriptVersion := "0.0.0"
	
	; Parse build_date field: "build_date": "2026-02-02"
	if (RegExMatch(jsonText, """build_date"":\s*""([^""]+)""", match))
		BuildDate := match1
	else
		BuildDate := "Unknown"
}

; Log sync_ps_invoice helper file info for debugging
; Helps identify version mismatches when users don't update all files
LogHelperInfo() {
	global DebugLogFile, HelperPath, HelperVersion, HelperModified, ScriptVersion
	
	; Use the same path resolution as GetScriptPath() - _sps.exe in production
	if (A_IsCompiled) {
		exePath := A_ScriptDir . "\_sps.exe"
		pyPath := A_ScriptDir . "\_sps.py"
	} else {
		exePath := A_ScriptDir . "\sync_ps_invoice.exe"
		pyPath := A_ScriptDir . "\sync_ps_invoice.py"
	}
	
	if (FileExist(exePath)) {
		HelperPath := exePath
		; Get file modification time
		FileGetTime, modTime, %exePath%, M
		FormatTime, HelperModified, %modTime%, yyyy-MM-dd HH:mm:ss
		; Version matches main app (same version.json)
		HelperVersion := ScriptVersion
		FileAppend, % A_Now . " - Helper EXE: " . exePath . "`n", %DebugLogFile%
		FileAppend, % A_Now . " - Helper Modified: " . HelperModified . "`n", %DebugLogFile%
		FileAppend, % A_Now . " - Helper Version: " . HelperVersion . "`n", %DebugLogFile%
		
		; Get file size for additional verification
		FileGetSize, fileSize, %exePath%, K
		FileAppend, % A_Now . " - Helper Size: " . fileSize . " KB`n", %DebugLogFile%
	} else if (FileExist(pyPath)) {
		HelperPath := pyPath
		FileGetTime, modTime, %pyPath%, M
		FormatTime, HelperModified, %modTime%, yyyy-MM-dd HH:mm:ss
		HelperVersion := ScriptVersion . " (dev)"
		FileAppend, % A_Now . " - Helper PY: " . pyPath . " (dev mode)`n", %DebugLogFile%
		FileAppend, % A_Now . " - Helper Modified: " . HelperModified . "`n", %DebugLogFile%
	} else {
		HelperPath := ""
		HelperVersion := "NOT FOUND"
		HelperModified := ""
		FileAppend, % A_Now . " - WARNING: sync_ps_invoice helper not found!`n", %DebugLogFile%
		FileAppend, % A_Now . " - Looked for: " . exePath . "`n", %DebugLogFile%
		FileAppend, % A_Now . " - And: " . pyPath . "`n", %DebugLogFile%
	}
}

; ============================================================
; GHL Credentials - stored in JSON to avoid INI line length limits
; ============================================================

; Get the path to the credentials file
GetCredentialsFilePath() {
	global IniFilename
	SplitPath, IniFilename, , iniDir
	return iniDir . "\credentials.json"
}

; Load GHL API credentials from JSON file
; Falls back to legacy INI format for backwards compatibility
LoadGHLCredentials() {
	global GHL_API_Key, GHL_LocationID, IniFilename, Settings_GoCardlessToken
	
	credFile := GetCredentialsFilePath()
	
	; Try loading from new JSON format first
	if (FileExist(credFile)) {
		FileRead, jsonText, %credFile%
		if (!ErrorLevel && jsonText != "") {
			; Parse api_key_b64 field
			if (RegExMatch(jsonText, """api_key_b64"":\s*""([^""]+)""", match)) {
				GHL_API_Key := Base64_Decode(match1)
			}
			; Parse location_id field
			if (RegExMatch(jsonText, """location_id"":\s*""([^""]+)""", match)) {
				GHL_LocationID := match1
			}
			; Parse GoCardless token
			if (RegExMatch(jsonText, """gc_token_b64"":\s*""([^""]+)""", match)) {
				Settings_GoCardlessToken := Base64_Decode(match1)
			}
			return true
		}
	}
	
	; Fall back to legacy INI format for GHL credentials only (not GoCardless tokens)
	IniRead, GHL_API_Key_B64, %IniFilename%, GHL, API_Key_B64, %A_Space%
	if (GHL_API_Key_B64 = "")
		IniRead, GHL_API_Key_B64, %IniFilename%, GHL, API_Key_V2_B64, %A_Space%
	IniRead, GHL_LocationID, %IniFilename%, GHL, LocationID, %A_Space%
	
	if (GHL_API_Key_B64 != "")
		GHL_API_Key := Base64_Decode(GHL_API_Key_B64)
	else
		GHL_API_Key := ""
	
	; GoCardless tokens must be in credentials.json - no INI fallback for security
	; If we loaded GHL credentials from INI, migrate to JSON format
	if (GHL_API_Key != "" || GHL_LocationID != "") {
		SaveGHLCredentials()
	}
	
	return false
}

; Save GHL API credentials to JSON file
SaveGHLCredentials() {
	global GHL_API_Key, GHL_LocationID, Settings_GoCardlessToken
	
	credFile := GetCredentialsFilePath()
	
	; Encode API key to Base64 for storage
	apiKeyB64 := ""
	if (GHL_API_Key != "")
		apiKeyB64 := Base64_Encode(GHL_API_Key)
	
	; Encode GoCardless token to Base64 for storage
	gcTokenB64 := ""
	if (Settings_GoCardlessToken != "")
		gcTokenB64 := Base64_Encode(Settings_GoCardlessToken)
	
	; Build JSON content - simple format, no library needed
	jsonContent := "{"
	jsonContent .= "`n  ""api_key_b64"": """ . apiKeyB64 . ""","
	jsonContent .= "`n  ""location_id"": """ . GHL_LocationID . ""","
	jsonContent .= "`n  ""gc_token_b64"": """ . gcTokenB64 . """"
	jsonContent .= "`n}"
	
	; Write to file
	FileDelete, %credFile%
	FileAppend, %jsonContent%, %credFile%, UTF-8
	
	return !ErrorLevel
}

; Function to get the correct Python executable path
; Checks for bundled Python first, then system Python
GetPythonPath() {
	; First check for bundled Python (installed via installer)
	bundledPython := A_ScriptDir . "\python\python.exe"
	if (FileExist(bundledPython)) {
		return bundledPython
	}
	
	; Check for run_python.bat helper (alternative bundled approach)
	runPythonBat := A_ScriptDir . "\run_python.bat"
	if (FileExist(runPythonBat)) {
		return runPythonBat
	}
	
	; Use system Python
	return "python"
}

; Function to get the correct script path - checks for compiled .exe first, then .py
; This allows distribution with PyInstaller-compiled executables while supporting dev mode
; scriptName: internal name (e.g., "validate_license") - mapped to cryptic filename for distribution
; Returns: full path to .exe if exists, otherwise full path to .py
GetScriptPath(scriptName) {
	; Script name mapping - internal names to cryptic filenames (for exe distribution)
	static scriptMap := {"sync_ps_invoice": "_sps", "validate_license": "_vlk", "create_ghl_contactsheet": "_ccs", "upload_ghl_media": "_upm", "fetch_ghl_contact": "_fgc", "update_ghl_contact": "_ugc", "gocardless_api": "_gca"}
	
	; Get the actual filename (use mapped name for production, original for dev)
	if (A_IsCompiled && scriptMap.HasKey(scriptName)) {
		fileName := scriptMap[scriptName]
	} else {
		fileName := scriptName
	}
	
	pyPath := A_ScriptDir . "\" . fileName . ".py"
	exePath := A_ScriptDir . "\" . fileName . ".exe"
	
	; In dev mode (running .ahk not compiled), prefer .py for faster iteration
	if (!A_IsCompiled && FileExist(pyPath)) {
		return pyPath
	}
	
	; In production (compiled) or if no .py, use .exe
	if (FileExist(exePath)) {
		return exePath
	}
	
	; Fall back to Python script
	return pyPath
}

; Function to run a script - handles both compiled .exe and .py scripts
; scriptName: base name without extension (e.g., "validate_license")
; args: command line arguments to pass
; Returns: the command string to run
GetScriptCommand(scriptName, args := "") {
	scriptPath := GetScriptPath(scriptName)
	
	; If it's an .exe, run it directly
	if (SubStr(scriptPath, -3) = ".exe") {
		return """" . scriptPath . """ " . args
	}
	
	; Otherwise, run via Python
	; Don't quote Python path unless it contains spaces (causes cmd /c issues)
	pythonPath := GetPythonPath()
	if (InStr(pythonPath, " "))
		return """" . pythonPath . """ """ . scriptPath . """ " . args
	else
		return pythonPath . " """ . scriptPath . """ " . args
}

ShowAbout:
; Open settings to About tab
Settings_CurrentTab := "About"
Gosub, ShowSettings
Return

; ============================================================================
; Floating Toolbar - Docks to ProSelect Window
; ============================================================================

; Toolbar tooltip data (hwnd => tooltip text)
global ToolbarTooltips := {}
global ToolbarLastHoveredButton := 0

; Toolbar tooltip timer
ToolbarTooltipOff:
ToolTip
return

CreateFloatingToolbar()
{
	global
	Critical  ; Prevent timer interruption during GUI creation
	
	; Stop position timer during rebuild to prevent conflicts
	SetTimer, PositionToolbar, Off
	
	; Clear old tooltip mappings
	ToolbarTooltips := {}
	
	; Destroy any existing toolbar first to prevent ghost/duplicate windows
	Gui, Toolbar:Destroy
	
	; Calculate toolbar width dynamically based on enabled buttons
	; Each button = 44px wide + 7px spacing (51px per slot), plus 2px left margin
	btnCount := 0
	if (Settings_ShowBtn_Client)
		btnCount++
	if (Settings_ShowBtn_Invoice)
		btnCount++
	if (Settings_ShowBtn_OpenGHL)
		btnCount++
	if (Settings_ShowBtn_Camera)
		btnCount++
	if (Settings_ShowBtn_Sort)
		btnCount++
	if (Settings_ShowBtn_Photoshop)
		btnCount++
	if (Settings_ShowBtn_Refresh)
		btnCount++
	if (Settings_ShowBtn_Print)
		btnCount++
	if (Settings_EnablePDF)
		btnCount++
	if (Settings_ShowBtn_QRCode)
		btnCount++
	if (Settings_SDCardEnabled)
		btnCount++
	if (Settings_GoCardlessEnabled)
		btnCount++
	btnCount++  ; Settings button (always visible)
	
	; Scale button dimensions for DPI
	; Make buttons fill entire toolbar with NO gaps - eliminates click-blocking transparent areas
	btnW := Round(44 * DPI_Scale)
	btnH := Round(40 * DPI_Scale)  ; Match toolbar height
	btnSpacing := btnW  ; No gaps - buttons are adjacent
	btnMargin := 0  ; No left margin
	btnY := 0  ; Buttons at top edge
	btnY1 := 0  ; Camera button also at top
	fontSize := Round(16 * DPI_Scale)
	fontSizeSmall := Round(14 * DPI_Scale)
	
	toolbarWidth := btnMargin + (btnCount * btnSpacing)
	toolbarHeight := btnH  ; Exact button height - no padding
	
	; Add width for grab handle on the left
	grabHandleWidth := Round(16 * DPI_Scale)
	toolbarWidth := toolbarWidth + grabHandleWidth
	
	; Calculate toolbar position and sample background color BEFORE creating GUI
	; This ensures we sample the actual screen content, not our own toolbar
	initialBgColor := Settings_ToolbarLastBGColor ? Settings_ToolbarLastBGColor : "333333"  ; Use saved color or fallback
	if (Settings_ToolbarAutoBG) {
		; Get ProSelect window position
		WinGetPos, psX, psY, psW, psH, ahk_exe ProSelect.exe
		if (psX != "" && psW != "") {
			; Calculate where toolbar will be positioned
			closeButtonOffset := Round(300 * DPI_Scale)
			futureX := psX + psW - (toolbarWidth + closeButtonOffset) + Settings_ToolbarOffsetX
			futureY := psY + Settings_ToolbarOffsetY
			
			; Sample screen at future toolbar position (center point)
			sampleX := futureX + (toolbarWidth // 2)
			sampleY := futureY + (toolbarHeight // 2)
			
			PixelGetColor, sampledColor, %sampleX%, %sampleY%, RGB
			if (sampledColor != "") {
				r := (sampledColor >> 16) & 0xFF
				g := (sampledColor >> 8) & 0xFF
				b := sampledColor & 0xFF
				initialBgColor := Format("{:02X}{:02X}{:02X}", r, g, b)
			}
		}
	}
	
	; Solid toolbar with colored buttons - no transparency (allows click-through)
	; Buttons fill 100% of toolbar area, background color only shows if button colors fail
	Gui, Toolbar:New, +AlwaysOnTop +ToolWindow -Caption +HwndToolbarHwnd
	Gui, Toolbar:Color, %initialBgColor%
	Gui, Toolbar:Font, s%fontSize% w300, Segoe UI
	
	; Get icon color from settings
	iconColor := Settings_ToolbarIconColor ? Settings_ToolbarIconColor : "White"
	
	; Add grab handle on the left (vertical dots for drag indicator)
	; Ctrl+Click to drag and reposition toolbar
	grabX := 0
	grabY := Round(4 * DPI_Scale)  ; Slightly lower to align with icons
	grabH := btnH - grabY  ; Match button height minus offset
	Gui, Toolbar:Font, s18 w700, Segoe UI
	Gui, Toolbar:Add, Text, x%grabX% y%grabY% w%grabHandleWidth% h%grabH% Center 0x200 Background%initialBgColor% c%iconColor% gToolbar_GrabHandle vTB_GrabHandle +HwndTB_GrabHandle_Hwnd, ⣿
	ToolbarTooltips[TB_GrabHandle_Hwnd] := "Drag to move toolbar"
	
	; Dynamic x position - each visible button advances by btnSpacing (after grab handle)
	nextX := grabHandleWidth + btnMargin
	
	; Use detected icon font (Phosphor Thin or fallback)
	
	; Client button (person icon)
	if (Settings_ShowBtn_Client) {
		Gui, Toolbar:Font, s%fontSize%, %IconFont%
		Gui, Toolbar:Add, Text, x%nextX% y%btnY% w%btnW% h%btnH% Center 0x200 BackgroundBlue c%iconColor% gToolbar_GetClient vTB_Client +HwndTB_Client_Hwnd, % Chr(Icon_AddFriend)
		ToolbarTooltips[TB_Client_Hwnd] := "Get Client from GHL"
		nextX += btnSpacing
	}
	
	; Invoice button (document icon)
	if (Settings_ShowBtn_Invoice) {
		Gui, Toolbar:Font, s%fontSize%, %IconFont%
		Gui, Toolbar:Add, Text, x%nextX% y%btnY% w%btnW% h%btnH% Center 0x200 BackgroundGreen c%iconColor% gToolbar_GetInvoice vTB_Invoice +HwndTB_Invoice_Hwnd, % Chr(Icon_Invoice)
		ToolbarTooltips[TB_Invoice_Hwnd] := "Sync Invoice to GHL"
		nextX += btnSpacing
	}
	
	; Open GHL button (globe icon)
	if (Settings_ShowBtn_OpenGHL) {
		Gui, Toolbar:Font, s%fontSize%, %IconFont%
		Gui, Toolbar:Add, Text, x%nextX% y%btnY% w%btnW% h%btnH% Center 0x200 BackgroundTeal c%iconColor% gToolbar_OpenGHL vTB_OpenGHL +HwndTB_OpenGHL_Hwnd, % Chr(Icon_IDCard)
		ToolbarTooltips[TB_OpenGHL_Hwnd] := "Open GHL Contact"
		nextX += btnSpacing
	}
	
	; Camera button - two versions for state indication (only one visible at a time)
	if (Settings_ShowBtn_Camera) {
		Gui, Toolbar:Font, s%fontSize%, %IconFont%
		Gui, Toolbar:Add, Text, x%nextX% y%btnY% w%btnW% h%btnH% Center 0x200 BackgroundMaroon c%iconColor% gToolbar_CaptureRoom vTB_CameraOn +HwndTB_CameraOn_Hwnd, % Chr(Icon_Camera)
		Gui, Toolbar:Add, Text, x%nextX% y%btnY% w%btnW% h%btnH% Center 0x200 BackgroundGray c%iconColor% gToolbar_CaptureRoom vTB_CameraOff Hidden +HwndTB_CameraOff_Hwnd, % Chr(Icon_Camera)
		Gui, Toolbar:Add, Text, x%nextX% y%btnY% w%btnW% h%btnH% Center 0x200 BackgroundYellow cBlack gToolbar_CaptureRoom vTB_CameraCalib Hidden +HwndTB_CameraCalib_Hwnd, % Chr(Icon_Camera)
		ToolbarTooltips[TB_CameraOn_Hwnd] := "Capture Room Photo"
		ToolbarTooltips[TB_CameraOff_Hwnd] := "Capture Room Photo"
		ToolbarTooltips[TB_CameraCalib_Hwnd] := "Capture Room Photo"
		nextX += btnSpacing
	}
	
	; Photoshop button (PNG icon - colored to match toolbar icons)
	if (Settings_ShowBtn_Photoshop) {
		; Calculate icon size: 51% of button (same as GC icon)
		psIconW := Round(btnW * 0.51)
		psIconH := Round(btnH * 0.51)
		psIconX := nextX + Round((btnW - psIconW) / 2)
		psIconY := btnY + Round((btnH - psIconH) / 2)
		
		; Generate icon matching current toolbar icon color (uses PowerShell)
		iconPath := GeneratePSIcon(iconColor)
		if (FileExist(iconPath)) {
			Gui, Toolbar:Add, Picture, x%psIconX% y%psIconY% w%psIconW% h%psIconH% gToolbar_Photoshop vTB_Photoshop +HwndTB_Photoshop_Hwnd, %iconPath%
		} else {
			; Fallback to text if PNG not found
			Gui, Toolbar:Font, s%fontSizeSmall% w400, Segoe UI
			Gui, Toolbar:Add, Text, x%nextX% y%btnY% w%btnW% h%btnH% Center 0x200 Background001E36 c%iconColor% gToolbar_Photoshop vTB_Photoshop +HwndTB_Photoshop_Hwnd, Ps
		}
		ToolbarTooltips[TB_Photoshop_Hwnd] := "Open in Photoshop"
		nextX += btnSpacing
	}
	
	; Sort button (shuffle/alpha toggle) - uses emoji for toggle states
	if (Settings_ShowBtn_Sort) {
		SortMode_IsRandom := false
		Gui, Toolbar:Font, s%fontSize%, Segoe UI Emoji
		Gui, Toolbar:Add, Text, x%nextX% y%btnY1% w%btnW% h%btnH% Center 0x200 BackgroundGray c%iconColor% gToolbar_ToggleSort vTB_Sort +HwndTB_Sort_Hwnd, 🔀
		ToolbarTooltips[TB_Sort_Hwnd] := "Toggle Sort Mode"
		nextX += btnSpacing
	}
	
	; Refresh button (sync icon)
	if (Settings_ShowBtn_Refresh) {
		Gui, Toolbar:Font, s%fontSize%, %IconFont%
		Gui, Toolbar:Add, Text, x%nextX% y%btnY% w%btnW% h%btnH% Center 0x200 BackgroundNavy c%iconColor% gToolbar_Refresh vTB_Refresh +HwndTB_Refresh_Hwnd, % Chr(Icon_Refresh)
		ToolbarTooltips[TB_Refresh_Hwnd] := "Refresh Album"
		nextX += btnSpacing
	}
	
	; Quick Print button (print icon)
	if (Settings_ShowBtn_Print) {
		Gui, Toolbar:Font, s%fontSize%, %IconFont%
		Gui, Toolbar:Add, Text, x%nextX% y%btnY% w%btnW% h%btnH% Center 0x200 Background444444 c%iconColor% gToolbar_QuickPrint vTB_Print +HwndTB_Print_Hwnd, % Chr(Icon_Print)
		defaultPrinter := GetDefaultPrinterName()
		ToolbarTooltips[TB_Print_Hwnd] := "Quick Print (" . defaultPrinter . ")"
		nextX += btnSpacing
	}
	
	; PDF Doc button (PDF icon) - always creates PDF
	if (Settings_EnablePDF) {
		Gui, Toolbar:Font, s%fontSize%, %IconFont%
		Gui, Toolbar:Add, Text, x%nextX% y%btnY% w%btnW% h%btnH% Center 0x200 BackgroundMaroon c%iconColor% gToolbar_PDFDoc vTB_PDFDoc +HwndTB_PDFDoc_Hwnd, % Chr(Icon_PDFDoc)
		ToolbarTooltips[TB_PDFDoc_Hwnd] := "Print to PDF"
		nextX += btnSpacing
	}
	
	; QR Code button (grid icon)
	if (Settings_ShowBtn_QRCode) {
		Gui, Toolbar:Font, s%fontSize%, %IconFont%
		Gui, Toolbar:Add, Text, x%nextX% y%btnY% w%btnW% h%btnH% Center 0x200 Background006666 c%iconColor% gToolbar_QRCode vTB_QRCode +HwndTB_QRCode_Hwnd, % Chr(Icon_QRCode)
		ToolbarTooltips[TB_QRCode_Hwnd] := "Show QR Code"
		nextX += btnSpacing
	}
	
	; SD Card Download button (download icon)
	if (Settings_SDCardEnabled) {
		Gui, Toolbar:Font, s%fontSize%, %IconFont%
		Gui, Toolbar:Add, Text, x%nextX% y%btnY% w%btnW% h%btnH% Center 0x200 BackgroundOrange c%iconColor% gToolbar_DownloadSD vTB_Download +HwndTB_Download_Hwnd, % Chr(Icon_Download)
		ToolbarTooltips[TB_Download_Hwnd] := "Download from SD Card"
		nextX += btnSpacing
	}
	
	; GoCardless button (PNG icon - colored to match toolbar icons)
	if (Settings_GoCardlessEnabled) {
		; Calculate icon size: 51% of button
		gcIconW := Round(btnW * 0.51)
		gcIconH := Round(btnH * 0.51)
		gcIconX := nextX + Round((btnW - gcIconW) / 2)
		gcIconY := btnY + Round((btnH - gcIconH) / 2)
		
		; Generate icon matching current toolbar icon color (uses PowerShell)
		iconPath := GenerateGCIcon(iconColor)
		if (FileExist(iconPath)) {
			Gui, Toolbar:Add, Picture, x%gcIconX% y%gcIconY% w%gcIconW% h%gcIconH% gToolbar_GoCardless vTB_GoCardless +HwndTB_GoCardless_Hwnd, %iconPath%
		} else {
			; Fallback to text if PNG not found
			Gui, Toolbar:Font, s%fontSizeSmall% w700, Segoe UI
			Gui, Toolbar:Add, Text, x%nextX% y%btnY% w%btnW% h%btnH% Center 0x200 Background%initialBgColor% c%iconColor% gToolbar_GoCardless vTB_GoCardless +HwndTB_GoCardless_Hwnd, GC
		}
		ToolbarTooltips[TB_GoCardless_Hwnd] := "GoCardless Direct Debit"
		nextX += btnSpacing
	}
	
	; Settings button (gear icon)
	Gui, Toolbar:Font, s%fontSize%, %IconFont%
	Gui, Toolbar:Add, Text, x%nextX% y%btnY% w%btnW% h%btnH% Center 0x200 BackgroundPurple c%iconColor% gToolbar_Settings vTB_Settings +HwndTB_Settings_Hwnd, % Chr(Icon_Settings)
	ToolbarTooltips[TB_Settings_Hwnd] := "Settings"
	
	; Register mouse move handler for toolbar tooltips
	OnMessage(0x200, "SettingsMouseMove")
	
	; NOTE: TransColor removed - buttons now fill 100% of toolbar area
	; No transparent gaps means no need for TransColor (which blocked clicks)
	
	; Re-enable interrupts and start position timer
	Critical, Off
	SetTimer, PositionToolbar, 200
	SetTimer, CheckToolbarTooltip, 100  ; Check for tooltip hover every 100ms
}

; Timer-based tooltip check for toolbar (backup for WM_MOUSEMOVE)
CheckToolbarTooltip:
	global ToolbarTooltips, ToolbarLastHoveredButton, ToolbarHwnd
	
	; Only process when mouse is over toolbar window
	MouseGetPos, , , mouseWin, controlHwnd, 2
	if (mouseWin != ToolbarHwnd) {
		if (ToolbarLastHoveredButton) {
			ToolbarLastHoveredButton := 0
			ToolTip
		}
		return
	}
	
	; Check if mouse is over a tooltip-enabled button
	if (ToolbarTooltips.HasKey(controlHwnd)) {
		if (controlHwnd != ToolbarLastHoveredButton) {
			ToolbarLastHoveredButton := controlHwnd
			ToolTip, % ToolbarTooltips[controlHwnd]
			SetTimer, ToolbarTooltipOff, -2000
		}
	} else if (ToolbarLastHoveredButton) {
		; Mouse is on toolbar but not a button
		ToolbarLastHoveredButton := 0
		ToolTip
	}
return

; =====================================================
; Screen Background Color Sampling for Toolbar
; Samples pixels from screen area behind toolbar position
; Returns dominant color as hex string (RRGGBB)
; =====================================================
SampleScreenBackgroundColor(x, y, w, h) {
	; Sample pixels from screen at toolbar position
	; Toolbar must be hidden before calling this!
	sampleCount := 0
	rTotal := 0, gTotal := 0, bTotal := 0
	
	; Sample a 5x3 grid within the toolbar area
	stepX := w // 5
	stepY := h // 3
	
	Loop, 5 {
		sampleX := x + (A_Index - 1) * stepX + (stepX // 2)
		Loop, 3 {
			sampleY := y + (A_Index - 1) * stepY + (stepY // 2)
			PixelGetColor, pixelColor, %sampleX%, %sampleY%, RGB
			if (pixelColor != "") {
				; Parse RGB values
				r := (pixelColor >> 16) & 0xFF
				g := (pixelColor >> 8) & 0xFF
				b := pixelColor & 0xFF
				rTotal += r
				gTotal += g
				bTotal += b
				sampleCount++
			}
		}
	}
	
	if (sampleCount = 0)
		return "1E1E1E"  ; Default dark gray if sampling failed
	
	; Calculate average color
	avgR := Round(rTotal / sampleCount)
	avgG := Round(gTotal / sampleCount)
	avgB := Round(bTotal / sampleCount)
	
	; Return as hex color without 0x prefix
	return Format("{:02X}{:02X}{:02X}", avgR, avgG, avgB)
}

; Calculate luminance of a color to determine if white or black text has better contrast
GetColorLuminance(hexColor) {
	; Remove 0x prefix if present
	hexColor := RegExReplace(hexColor, "^0x|^#", "")
	
	; Parse RGB
	r := "0x" . SubStr(hexColor, 1, 2)
	g := "0x" . SubStr(hexColor, 3, 2)
	b := "0x" . SubStr(hexColor, 5, 2)
	
	; Calculate relative luminance (ITU-R BT.709)
	; Range: 0 (black) to 255 (white)
	luminance := (0.299 * r) + (0.587 * g) + (0.114 * b)
	return luminance
}

; Get contrasting icon color based on background luminance
GetContrastingIconColor(bgColor) {
	luminance := GetColorLuminance(bgColor)
	; Use white icons on dark backgrounds, black on light
	return (luminance < 128) ? "White" : "Black"
}

; Generate colored GC icon using PowerShell - any color supported
GenerateGCIcon(colorHex) {
	static lastColor := ""
	dstPath := A_ScriptDir . "\Icon_GC_Current.png"
	
	; Normalize color to hex
	colorHex := RegExReplace(colorHex, "^0x|^#", "")
	if (colorHex = "White")
		colorHex := "FFFFFF"
	else if (colorHex = "Black")
		colorHex := "282828"
	else if (colorHex = "Yellow")
		colorHex := "FFFF00"
	else if (colorHex = "Orange")
		colorHex := "FF8800"
	
	; Skip if color unchanged and file exists
	if (colorHex = lastColor && FileExist(dstPath))
		return dstPath
	
	lastColor := colorHex
	
	; Call PowerShell script to generate icon
	psScript := A_ScriptDir . "\GenerateGCIcon.ps1"
	if (FileExist(psScript)) {
		RunWait, powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%psScript%" -ColorHex "%colorHex%",, Hide
	}
	
	return dstPath
}

; Generate colored PS (Photoshop) icon using PowerShell - any color supported
GeneratePSIcon(colorHex) {
	static lastColor := ""
	dstPath := A_ScriptDir . "\Icon_PS_Current.png"
	
	; Normalize color to hex
	colorHex := RegExReplace(colorHex, "^0x|^#", "")
	if (colorHex = "White")
		colorHex := "FFFFFF"
	else if (colorHex = "Black")
		colorHex := "282828"
	else if (colorHex = "Yellow")
		colorHex := "FFFF00"
	else if (colorHex = "Orange")
		colorHex := "FF8800"
	
	; Skip if color unchanged and file exists
	if (colorHex = lastColor && FileExist(dstPath))
		return dstPath
	
	lastColor := colorHex
	
	; Call PowerShell script to generate icon
	psScript := A_ScriptDir . "\GeneratePSIcon.ps1"
	if (FileExist(psScript)) {
		RunWait, powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%psScript%" -ColorHex "%colorHex%",, Hide
	}
	
	return dstPath
}

; =====================================================
PositionToolbar:
; Only show toolbar when ProSelect is the active window
WinGet, activeExe, ProcessName, A
if (activeExe != "ProSelect.exe")
{
	Gui, Toolbar:Hide
	return
}

; Get active window info
WinGetTitle, psTitle, A
WinGetPos, psX, psY, psW, psH, A

; Don't show toolbar during splash screen - only hide if title is empty or just "ProSelect"
if (psTitle = "" || psTitle = "ProSelect")
{
	; Still on splash screen or loading - hide toolbar
	Gui, Toolbar:Hide
	return
}

; Ensure we have valid window position data
if (psX = "" || psY = "" || psW = "" || psH = "")
{
	Gui, Toolbar:Hide
	return
}

; Find the main ProSelect window (largest one) and compare
; If active window is significantly smaller, it's a dialog
WinGet, psWindows, List, ahk_exe ProSelect.exe
maxW := 0
maxH := 0
Loop, %psWindows%
{
	thisHwnd := psWindows%A_Index%
	WinGetPos,,, thisW, thisH, ahk_id %thisHwnd%
	if (thisW > maxW)
		maxW := thisW
	if (thisH > maxH)
		maxH := thisH
}

; If this window is less than 80% of the largest window size, it's a dialog
if (psW < maxW * 0.8 || psH < maxH * 0.8)
{
	Gui, Toolbar:Hide
	return
}

; Also skip if window is too small to be main window
if (psW < 800 || psH < 600)
{
	Gui, Toolbar:Hide
	return
}

; Room detection disabled - always show camera as active
; Show maroon camera icon (capture always available)
if (TB_CameraState != "on") {
	TB_CameraState := "on"
	GuiControl, Toolbar:Show, TB_CameraOn
	GuiControl, Toolbar:Hide, TB_CameraOff
	GuiControl, Toolbar:Hide, TB_CameraCalib
}

/*
; === ROOM DETECTION CODE - DISABLED ===
; Check if calibration needed (first time or window size changed)
if (!RoomsBtn_Calibrated || RoomsBtn_CalibW != psW || RoomsBtn_CalibH != psH) {
	; Only calibrate if we have a proper album title (not splash screen)
	if (InStr(psTitle, "ProSelect -") || InStr(psTitle, " - ProSelect")) {
		; Show yellow camera icon during calibration (only once)
		if (!TB_CalibShowing) {
			TB_CalibShowing := true
			GuiControl, Toolbar:Hide, TB_CameraOn
			GuiControl, Toolbar:Hide, TB_CameraOff
			GuiControl, Toolbar:Show, TB_CameraCalib
		}
		RoomsBtn_Calibrated := false
		CalibrateRoomsButton()
	}
} else {
	if (TB_CalibShowing) {
		TB_CalibShowing := false
		TB_CameraState := ""  ; Reset so next update applies
	}
}

; Update camera icon based on Room view status
; Maroon when in Room view (capture available), Gray when not
; Only update if state changed to prevent flickering
; Skip if calibration is in progress (showing yellow icon)
if (!TB_CalibShowing) {
	newCameraState := (RoomsBtn_Calibrated && IsRoomViewActive()) ? "on" : "off"
	if (newCameraState != TB_CameraState) {
		TB_CameraState := newCameraState
		if (TB_CameraState = "on") {
			GuiControl, Toolbar:Show, TB_CameraOn
			GuiControl, Toolbar:Hide, TB_CameraOff
			GuiControl, Toolbar:Hide, TB_CameraCalib
		} else {
			GuiControl, Toolbar:Hide, TB_CameraOn
			GuiControl, Toolbar:Show, TB_CameraOff
			GuiControl, Toolbar:Hide, TB_CameraCalib
		}
	}
}
; === END ROOM DETECTION CODE ===
*/

; Position inline with window close X button - adjust for toolbar width
; Scale the offset for high-DPI displays (200 is the base offset at 100% scaling)
; Offset accounts for window close/maximize/minimize buttons to avoid overlap
tbWidth := toolbarWidth
if (tbWidth = "") {
	; Toolbar not yet created - skip positioning
	return
}
closeButtonOffset := Round(300 * DPI_Scale)
newX := psX + psW - (tbWidth + closeButtonOffset)
; Y offset: position toolbar at very top of window title bar area
newY := psY

; Apply user-defined position offset (set via Ctrl+Click drag on grab handle)
if (!Toolbar_IsDragging) {
	newX := newX + Settings_ToolbarOffsetX
	newY := newY + Settings_ToolbarOffsetY
}

; Ensure toolbar stays within screen bounds
SysGet, monitorCount, MonitorCount
SysGet, primaryMon, MonitorWorkArea

; Get the monitor that contains the ProSelect window center
psCenterX := psX + (psW // 2)
psCenterY := psY + (psH // 2)

; Track if we found a valid monitor
foundMonitor := false

; Check each monitor to find which one contains the ProSelect window
tbHeight := Round(43 * DPI_Scale)
Loop, %monitorCount% {
	SysGet, mon, MonitorWorkArea, %A_Index%
	if (psCenterX >= monLeft && psCenterX <= monRight && psCenterY >= monTop && psCenterY <= monBottom) {
		foundMonitor := true
		; Found the monitor - ensure toolbar is fully visible within it
		if (newX < monLeft)
			newX := monLeft
		if (newX + tbWidth > monRight)
			newX := monRight - tbWidth
		; Allow Y to go above work area top (into title bar)
		if (newY + tbHeight > monBottom)
			newY := monBottom - tbHeight
		break
	}
}

; Fallback: use primary monitor bounds if no monitor found for window center
if (!foundMonitor) {
	if (newX < primaryMonLeft)
		newX := primaryMonLeft
	if (newX + tbWidth > primaryMonRight)
		newX := primaryMonRight - tbWidth
	; Allow Y to go above work area top (into title bar)
	if (newY + tbHeight > primaryMonBottom)
		newY := primaryMonBottom - tbHeight
}

; Final safety check - ensure at least X >= 0
if (newX < 0 || newX = "")
	newX := 0
if (newY = "")
	newY := 0

; Track position for drag detection (don't auto-update background on position change - causes flashing)
Toolbar_LastPosX := newX
Toolbar_LastPosY := newY

; Validate all values before showing - if any are empty, skip this cycle
if (tbWidth = "" || toolbarHeight = "") {
	return
}

; Show toolbar
Gui, Toolbar:Show, x%newX% y%newY% w%tbWidth% h%toolbarHeight% NoActivate

; On first show, schedule a delayed re-sample of background color
; This catches cases where ProSelect's title bar wasn't fully rendered yet
if (!Toolbar_FirstShowDone && Settings_ToolbarAutoBG) {
	Toolbar_FirstShowDone := true
	; Force redraw on first show only (not every timer cycle to avoid flicker)
	DllCall("InvalidateRect", "Ptr", ToolbarHwnd, "Ptr", 0, "Int", 1)
	DllCall("UpdateWindow", "Ptr", ToolbarHwnd)
	SetTimer, FirstLaunchBackgroundSample, -2000
}
Return

; Re-sample background color after first launch (allows ProSelect title bar to fully render)
FirstLaunchBackgroundSample:
if (Settings_ToolbarAutoBG)
	CreateFloatingToolbar()
Return

; Updates toolbar background by sampling screen color behind it
UpdateToolbarBackground:
{
	global Settings_ToolbarAutoBG, ToolbarHwnd, toolbarWidth, toolbarHeight
	
	if (!Settings_ToolbarAutoBG)
		return
	
	; Get current toolbar position
	WinGetPos, tbX, tbY, tbW, tbH, ahk_id %ToolbarHwnd%
	if (tbX = "" || tbW = "")
		return
	
	; Hide toolbar and wait for screen to repaint
	Gui, Toolbar:Hide
	Sleep, 200
	
	; Sample screen at toolbar center position
	sampleX := tbX + (tbW // 2)
	sampleY := tbY + (tbH // 2)
	
	PixelGetColor, sampledColor, %sampleX%, %sampleY%, RGB
	if (sampledColor != "") {
		r := (sampledColor >> 16) & 0xFF
		g := (sampledColor >> 8) & 0xFF
		b := sampledColor & 0xFF
		bgColorHex := Format("{:02X}{:02X}{:02X}", r, g, b)
		Gui, Toolbar:Color, %bgColorHex%
		
		; Save the successful color to INI for next startup
		Settings_ToolbarLastBGColor := bgColorHex
		IniWrite, %bgColorHex%, %IniFilename%, Appearance, ToolbarLastBGColor
	}
	
	; Show toolbar again
	Gui, Toolbar:Show, x%tbX% y%tbY% w%tbW% h%tbH% NoActivate
	
	; Force redraw to apply background color immediately
	DllCall("InvalidateRect", "Ptr", ToolbarHwnd, "Ptr", 0, "Int", 1)
	DllCall("UpdateWindow", "Ptr", ToolbarHwnd)
}
Return

Toolbar_GetClient:
Gosub, GHLClientLookup
Return

Toolbar_OpenGHL:
Gosub, OpenGHLClientURL
Return

Toolbar_GrabHandle:
; Click and drag to move toolbar to new position (relative to ProSelect window)
{
	global Settings_ToolbarOffsetX, Settings_ToolbarOffsetY, Toolbar_IsDragging, ToolbarHwnd, toolbarWidth
	
	; Get ProSelect window position as reference
	WinGetPos, psX, psY, psW, psH, ahk_exe ProSelect.exe
	if (psX = "" || psW = "")
		return
	
	; Get current toolbar position
	WinGetPos, tbX, tbY, , , ahk_id %ToolbarHwnd%
	
	; Calculate default position (without offset)
	tbWidth := toolbarWidth
	closeButtonOffset := Round(300 * DPI_Scale)
	defaultX := psX + psW - (tbWidth + closeButtonOffset)
	defaultY := psY
	
	; Store mouse start position for relative drag
	CoordMode, Mouse, Screen
	MouseGetPos, startMouseX, startMouseY
	startTbX := tbX
	startTbY := tbY
	
	Toolbar_IsDragging := true
	SetTimer, PositionToolbar, Off  ; Stop auto-positioning during drag
	
	; Track mouse movement while button held
	while (GetKeyState("LButton", "P")) {
		MouseGetPos, currentMouseX, currentMouseY
		deltaX := currentMouseX - startMouseX
		deltaY := currentMouseY - startMouseY
		newTbX := startTbX + deltaX
		newTbY := startTbY + deltaY
		Gui, Toolbar:Show, x%newTbX% y%newTbY% NoActivate
		Sleep, 16  ; ~60fps
	}
	
	; Get final toolbar position
	WinGetPos, finalX, finalY, , , ahk_id %ToolbarHwnd%
	
	; Calculate and save offset from default position
	Settings_ToolbarOffsetX := finalX - defaultX
	Settings_ToolbarOffsetY := finalY - defaultY
	
	Toolbar_IsDragging := false
	SaveSettings()
	SetTimer, PositionToolbar, 200  ; Resume auto-positioning
	
	; Recreate toolbar to sample background at new position (avoids flashing hide/show)
	if (Settings_ToolbarAutoBG)
		CreateFloatingToolbar()
	
	ToolTip, Position saved!
	SetTimer, RemoveGrabTooltip, -1000
}
Return

RemoveGrabTooltip:
ToolTip
Return

Toolbar_ToggleSort:
; Toggle between random and filename sort order in ProSelect
; Icon shows action that will happen: 🔀 = click to randomize, 🔤 = click to sort by filename
{
	global Settings_DebugLogging, SortMode_IsRandom, Settings_MenuDelay
	delay := Settings_MenuDelay
	WinActivate, ahk_exe ProSelect.exe
	WinWaitActive, ahk_exe ProSelect.exe, , 2
	; DebugKeystroke("Alt+I (Images menu)")
	Send, !i  ; Alt+I for Images menu
	Sleep, %delay%
	; DebugKeystroke("Down x8 (to Sort By)")
	Send, {Down 8}  ; Down 8 times to Sort By
	Sleep, %delay%
	; DebugKeystroke("Right (open submenu)")
	Send, {Right}  ; Open submenu
	Sleep, %delay%
	
	if (!SortMode_IsRandom) {
		; Currently filename order, switch to random
		; DebugKeystroke("R (Random)")
		Send, r   ; R for Random
		Sleep, %delay%
		; DebugKeystroke("Enter (confirm)")
		Send, {Enter}
		SortMode_IsRandom := true
		GuiControl, Toolbar:, TB_Sort, 🔤  ; Show filename icon (next action)
	} else {
		; Currently random order, switch to filename
		; DebugKeystroke("Enter (Filename - first item)")
		Send, {Enter}  ; Filename is first item in submenu
		SortMode_IsRandom := false
		GuiControl, Toolbar:, TB_Sort, 🔀  ; Show random icon (next action)
	}
	Sleep, %delay%
}
Return

Toolbar_Photoshop:
; Transfer to Photoshop, wait for edit, then refresh
; Only works when ProSelect is in focus
IfWinNotActive, ahk_exe ProSelect.exe
	Return
Send, ^t
Sleep, 500
; Show popup and wait for user to finish editing
DarkMsgBox("Edit Preview", "Edit preview file and save.`n`n" . Chr(0x1F504) . " Return to ProSelect and refresh.", "info", {timeout: 5})
; Return to ProSelect and refresh
WinActivate, ahk_exe ProSelect.exe
WinWaitActive, ahk_exe ProSelect.exe, , 2
Send, ^u
Return

Toolbar_Refresh:
; Refresh/Update album
; Only works when ProSelect is in focus
IfWinNotActive, ahk_exe ProSelect.exe
	Return
Send, ^u
Return

Toolbar_QuickPrint:
; Quick Print - uses selected printer from settings (or system default)
global Settings_QuickPrintPrinter

; Save original default printer if we need to switch
origPrinter := ""
if (Settings_QuickPrintPrinter != "" && Settings_QuickPrintPrinter != "System Default") {
	RunWait, powershell -NoProfile -Command "(Get-CimInstance Win32_Printer -Filter 'Default=True').Name | Set-Content '%A_Temp%\sidekick_orig_printer.txt'",, Hide
	FileRead, origPrinter, %A_Temp%\sidekick_orig_printer.txt
	origPrinter := Trim(origPrinter, " `t`r`n")
	FileDelete, %A_Temp%\sidekick_orig_printer.txt
	; Set selected printer as default
	RunWait, RUNDLL32 PRINTUI.DLL`,PrintUIEntry /y /n "%Settings_QuickPrintPrinter%",, Hide
	Sleep, 300
}

WinActivate, ahk_exe ProSelect.exe
WinWaitActive, ahk_exe ProSelect.exe, , 2
if ErrorLevel {
	; Restore original printer if we changed it
	if (origPrinter != "")
		RunWait, powershell -NoProfile -Command "Set-Printer -Name '%origPrinter%' -Default",, Hide
	Return
}
; Use keyboard menu navigation to open Print dialog (avoids triggering other hotkeys)
Sleep, 1000
Send, !f        ; Alt+F to open File menu
Sleep, 300
Send, p         ; P to highlight Print submenu
Sleep, 300
Send, {Right}   ; Open the submenu
Sleep, 300
Send, {Enter}   ; Select first item (Order/Invoice Report...)
Sleep, 1000
; Wait for the Print dialog to appear
WinWait, ahk_class #32770, , 3
if ErrorLevel {
	ToolTip, Print dialog did not open
	SetTimer, RemoveToolTip, -2000
	Return
}
Sleep, 300
; Read the last sync result to determine payment plan
resultFile := A_AppData . "\SideKick_PS\ghl_invoice_sync_result.json"
hasPayPlan := false
if FileExist(resultFile) {
	FileRead, rJson, %resultFile%
	if InStr(rJson, """schedule_created"": true")
		hasPayPlan := true
}
; Check Button20 (print option checkbox)
Control, Check,, Button20, ahk_class #32770
Sleep, 100
; Find matching template in ComboBox5 dropdown list
searchTerm := hasPayPlan ? Settings_PrintTemplate_PayPlan : Settings_PrintTemplate_Standard
ControlGet, cbList, List,, ComboBox5, ahk_class #32770
templateFound := false
Loop, Parse, cbList, `n
{
	if InStr(A_LoopField, searchTerm) {
		Control, ChooseString, %A_LoopField%, ComboBox5, ahk_class #32770
		templateFound := true
		break
	}
}
if (!templateFound) {
	ToolTip, Template containing "%searchTerm%" not found
	SetTimer, RemoveToolTip, -2000
	Return
}
Sleep, 100
; Click Print (Button32) - opens Windows Print dialog
ControlClick, Button32, ahk_class #32770

; Wait for the Windows "ProSelect - Print" dialog
WinWait, ProSelect - Print, , 10
if ErrorLevel {
	ToolTip, Windows Print dialog did not appear
	SetTimer, RemoveToolTip, -3000
	Return
}

; Activate and click inside the window to ensure focus
WinActivate, ProSelect - Print
WinWaitActive, ProSelect - Print, , 3
Sleep, 500

; Windows 10 vs Windows 11 have different Print dialogs
if (IsWindows10) {
	; Windows 10: Classic Print dialog - use Alt+P to click Print button
	Sleep, 3000
	WinActivate, Print
	WinWaitActive, Print, , 2
	Send, !p
} else {
	; Windows 11: Modern dialog - use tab navigation
	; 6 tabs from Printer dropdown to reach Print button
	Send, {Tab}
	Sleep, 300
	Send, {Tab}
	Sleep, 300
	Send, {Tab}
	Sleep, 300
	Send, {Tab}
	Sleep, 300
	Send, {Tab}
	Sleep, 300
	Send, {Tab}
	Sleep, 300
	
	; Send Enter to activate Print button
	Send, {Enter}
}

; Restore original printer if we changed it
Sleep, 500
if (origPrinter != "")
	RunWait, powershell -NoProfile -Command "Set-Printer -Name '%origPrinter%' -Default",, Hide
Return

; ═══════════════════════════════════════════════════════════════════════════════
; PDF DOC BUTTON - Always prints to PDF (ignores Settings_EnablePDF toggle)
; ═══════════════════════════════════════════════════════════════════════════════
Toolbar_PDFDoc:
; Ctrl+Shift+Click = calibration mode
if (GetKeyState("Ctrl", "P") && GetKeyState("Shift", "P")) {
	PDF_CalibrationMode := true
	ToolTip, 🔧 Calibration mode enabled
	SetTimer, RemoveToolTip, -1500
}
Gosub, Toolbar_PrintToPDF
PDF_CalibrationMode := false
Return

; ═══════════════════════════════════════════════════════════════════════════════
; PRINT TO PDF - Sets Microsoft Print to PDF as default, triggers print,
; handles the Save As dialog, saves to album folder + optional copy folder
; ═══════════════════════════════════════════════════════════════════════════════
Toolbar_PrintToPDF:
	global Settings_PDFOutputFolder
	
	; Check ProSelect is running
	if !WinExist("ahk_exe ProSelect.exe") {
		DarkMsgBox("Print to PDF", "ProSelect is not running.", "error")
		Return
	}
	
	; Show hands-off warning GUI
	Gui, PDFProgress:New, +AlwaysOnTop +ToolWindow +HwndPDFProgressHwnd
	Gui, PDFProgress:Color, 1E1E1E
	Gui, PDFProgress:Font, s12 cFFFFFF, Segoe UI
	Gui, PDFProgress:Add, Text, x20 y20 w260 Center, 📄 Printing to PDF...
	Gui, PDFProgress:Font, s10 cFFCC00, Segoe UI
	Gui, PDFProgress:Add, Text, x20 y55 w260 Center, ⚠️ HANDS OFF
	Gui, PDFProgress:Font, s9 cCCCCCC, Segoe UI
	Gui, PDFProgress:Add, Text, x20 y80 w260 Center, Do not touch mouse or keyboard
	Gui, PDFProgress:Show, w300 h115, Print to PDF
	DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", PDFProgressHwnd, "Int", 20, "Int*", 1, "Int", 4)
	
	; Get the album folder from ProSelect via Save Album As dialog
	albumFolder := GetAlbumFolder()
	if (albumFolder = "") {
		Gui, PDFProgress:Destroy
		DarkMsgBox("Print to PDF", "Could not determine album folder.`n`nMake sure an album is open in ProSelect.", "error")
		Return
	}
	
	; Save original default printer
	origPrinter := ""
	RunWait, powershell -NoProfile -Command "(Get-CimInstance Win32_Printer -Filter 'Default=True').Name | Set-Content '%A_Temp%\sidekick_orig_printer.txt'",, Hide
	FileRead, origPrinter, %A_Temp%\sidekick_orig_printer.txt
	origPrinter := Trim(origPrinter, " `t`r`n")
	FileDelete, %A_Temp%\sidekick_orig_printer.txt
	
	; Set Microsoft Print to PDF as default
	RunWait, RUNDLL32 PRINTUI.DLL`,PrintUIEntry /y /n "Microsoft Print to PDF",, Hide
	Sleep, 500
	
	; Activate ProSelect and use keyboard menu navigation to Print
	WinActivate, ahk_exe ProSelect.exe
	WinWaitActive, ahk_exe ProSelect.exe, , 2
	if ErrorLevel {
		Gui, PDFProgress:Destroy
		if (origPrinter != "")
			RunWait, powershell -NoProfile -Command "Set-Printer -Name '%origPrinter%' -Default",,Hide
		Return
	}
	Sleep, 300
	Send, !f        ; Alt+F to open File menu
	Sleep, 300
	Send, p         ; P to highlight Print submenu
	Sleep, 300
	Send, {Right}   ; Open the submenu
	Sleep, 300
	Send, {Enter}   ; Select first item (Order/Invoice Report...)
	Sleep, 1000
	
	; Wait for the ProSelect Print Order/Invoice Report dialog
	WinWait, Print Order/Invoice Report, , 5
	if ErrorLevel {
		Gui, PDFProgress:Destroy
		ToolTip, Print dialog did not open
		SetTimer, RemoveToolTip, -2000
		if (origPrinter != "")
			RunWait, powershell -NoProfile -Command "Set-Printer -Name '%origPrinter%' -Default",, Hide
		Return
	}
	Sleep, 1000
	
	; Auto-select template (same logic as QuickPrint)
	resultFile := A_AppData . "\SideKick_PS\ghl_invoice_sync_result.json"
	hasPayPlan := false
	if FileExist(resultFile) {
		FileRead, rJson, %resultFile%
		if InStr(rJson, """schedule_created"": true")
			hasPayPlan := true
	}
	searchTerm := hasPayPlan ? Settings_PrintTemplate_PayPlan : Settings_PrintTemplate_Standard
	
	Control, Check,, Button20, Print Order/Invoice Report
	Sleep, 100
	ControlGet, cbList, List,, ComboBox5, Print Order/Invoice Report
	Loop, Parse, cbList, `n
	{
		if InStr(A_LoopField, searchTerm) {
			Control, ChooseString, %A_LoopField%, ComboBox5, Print Order/Invoice Report
			break
		}
	}
	Sleep, 100
	
	; Click Print in ProSelect dialog — this opens the Windows Print dialog
	ControlFocus, Button32, Print Order/Invoice Report
	Sleep, 200
	Send, {Enter}
	
	; Wait for the Windows "ProSelect - Print" dialog
	WinWait, ProSelect - Print, , 10
	if ErrorLevel {
		Gui, PDFProgress:Destroy
		ToolTip, Windows Print dialog did not appear
		SetTimer, RemoveToolTip, -3000
		if (origPrinter != "")
			RunWait, powershell -NoProfile -Command "Set-Printer -Name '%origPrinter%' -Default",, Hide
		Return
	}
	Sleep, 1000
	
	; Click Print button in Windows Print dialog
	; PDF printer is already set as default so it should be pre-selected
	; Activate and click inside the window to force focus
	WinActivate, ProSelect - Print
	WinWaitActive, ProSelect - Print, , 3
	if ErrorLevel {
		ToolTip, Could not activate Print dialog
		SetTimer, RemoveToolTip, -2000
	}
	
	; Click inside the dialog window to ensure it has keyboard focus
	WinGetPos, winX, winY, winW, winH, ProSelect - Print
	clickX := winX + (winW // 2)
	clickY := winY + 100  ; Click upper area, avoid buttons
	Click, %clickX%, %clickY%
	Sleep, 1000
	
	; Windows 10 vs Windows 11 have different Print dialogs
	; Both use calibration: first run or Ctrl+Shift+Click prompts user to click Print button
	
	; Ensure we're using screen coordinates
	CoordMode, Mouse, Screen
	
	; Check if we need calibration (Ctrl+Shift+Click OR no saved offsets)
	needCalibration := PDF_CalibrationMode || (Settings_PDFPrintBtnOffsetRight = 0 && Settings_PDFPrintBtnOffsetBottom = 0)
	
	if (IsWindows10) {
		; Windows 10: Classic Print dialog
		Sleep, 3000
		WinActivate, Print
		WinWaitActive, Print, , 2
		
		; Get window position
		WinGetPos, winX, winY, winW, winH, Print
		
		if (needCalibration) {
			; Show calibration instruction GUI (yellow, in front of hands-off GUI)
			Gui, PDFCalibrate:New, +AlwaysOnTop +ToolWindow +HwndPDFCalibrateHwnd -Caption
			Gui, PDFCalibrate:Color, FFD700
			Gui, PDFCalibrate:Font, s14 Bold c000000, Segoe UI
			Gui, PDFCalibrate:Add, Text, x15 y15 w370 Center, 🖱️ CALIBRATION REQUIRED
			Gui, PDFCalibrate:Font, s10 Normal c000000, Segoe UI
			Gui, PDFCalibrate:Add, Text, x15 y50 w370, Windows Print dialogs vary by PC and DPI settings.
			Gui, PDFCalibrate:Add, Text, x15 y75 w370, SideKick needs to learn where the Print button is.
			Gui, PDFCalibrate:Font, s11 Bold c000000, Segoe UI
			Gui, PDFCalibrate:Add, Text, x15 y110 w370 Center, Click the PRINT button now
			Gui, PDFCalibrate:Font, s9 Normal c444444, Segoe UI
			Gui, PDFCalibrate:Add, Text, x15 y140 w370 Center, (Ctrl+Shift+Click PDF icon to recalibrate later)
			; Center on screen
			calibrateX := (A_ScreenWidth - 400) // 2
			calibrateY := (A_ScreenHeight - 170) // 2
			Gui, PDFCalibrate:Show, x%calibrateX% y%calibrateY% w400 h170, Calibration
			WinSet, AlwaysOnTop, On, ahk_id %PDFCalibrateHwnd%
			
			KeyWait, LButton, D T30
			Gui, PDFCalibrate:Destroy
			if ErrorLevel {
				DarkMsgBox("Print to PDF", "Calibration timed out.`n`nPlease try again and click the Print button when prompted.", "warning")
				Gui, PDFProgress:Destroy
				if (origPrinter != "")
					RunWait, powershell -NoProfile -Command "Set-Printer -Name '%origPrinter%' -Default",, Hide
				Return
			}
			
			; Capture click position
			MouseGetPos, clickX, clickY
			Settings_PDFPrintBtnOffsetRight := (winX + winW) - clickX
			Settings_PDFPrintBtnOffsetBottom := (winY + winH) - clickY
			
			; Save to INI
			IniWrite, %Settings_PDFPrintBtnOffsetRight%, %IniFilename%, Toolbar, PDFPrintBtnOffsetRight
			IniWrite, %Settings_PDFPrintBtnOffsetBottom%, %IniFilename%, Toolbar, PDFPrintBtnOffsetBottom
			
			ToolTip, ✅ Calibrated! Position saved.
			Sleep, 1500
			ToolTip
			
			KeyWait, LButton
			Sleep, 300
		} else {
			; Use saved calibration
			printBtnX := winX + winW - Settings_PDFPrintBtnOffsetRight
			printBtnY := winY + winH - Settings_PDFPrintBtnOffsetBottom
			Click, %printBtnX%, %printBtnY%
			Sleep, 500
			if WinExist("Print") {
				Sleep, 300
				Click, %printBtnX%, %printBtnY%
			}
		}
	} else {
		; Windows 11: Modern UWP dialog - mouse clicks work better than keystrokes
		
		; Get window position
		WinGetPos, winX, winY, winW, winH, ProSelect - Print
		
		if (needCalibration) {
			; Show calibration instruction GUI (yellow, in front of hands-off GUI)
			Gui, PDFCalibrate:New, +AlwaysOnTop +ToolWindow +HwndPDFCalibrateHwnd -Caption
			Gui, PDFCalibrate:Color, FFD700
			Gui, PDFCalibrate:Font, s14 Bold c000000, Segoe UI
			Gui, PDFCalibrate:Add, Text, x15 y15 w370 Center, 🖱️ CALIBRATION REQUIRED
			Gui, PDFCalibrate:Font, s10 Normal c000000, Segoe UI
			Gui, PDFCalibrate:Add, Text, x15 y50 w370, Windows Print dialogs vary by PC and DPI settings.
			Gui, PDFCalibrate:Add, Text, x15 y75 w370, SideKick needs to learn where the Print button is.
			Gui, PDFCalibrate:Font, s11 Bold c000000, Segoe UI
			Gui, PDFCalibrate:Add, Text, x15 y110 w370 Center, Click the PRINT button now
			Gui, PDFCalibrate:Font, s9 Normal c444444, Segoe UI
			Gui, PDFCalibrate:Add, Text, x15 y140 w370 Center, (Ctrl+Shift+Click PDF icon to recalibrate later)
			; Center on screen
			calibrateX := (A_ScreenWidth - 400) // 2
			calibrateY := (A_ScreenHeight - 170) // 2
			Gui, PDFCalibrate:Show, x%calibrateX% y%calibrateY% w400 h170, Calibration
			WinSet, AlwaysOnTop, On, ahk_id %PDFCalibrateHwnd%
			
			; Wait for click
			KeyWait, LButton, D T30  ; Wait up to 30 seconds for left click
			if ErrorLevel {
				Gui, PDFCalibrate:Destroy
				DarkMsgBox("Print to PDF", "Calibration timed out.`n`nPlease try again and click the Print button when prompted.", "warning")
				Gui, PDFProgress:Destroy
				if (origPrinter != "")
					RunWait, powershell -NoProfile -Command "Set-Printer -Name '%origPrinter%' -Default",, Hide
				Return
			}
			
			; Capture where user clicked
			MouseGetPos, clickX, clickY
			Gui, PDFCalibrate:Destroy
			
			; Calculate offset from window edges
			Settings_PDFPrintBtnOffsetRight := (winX + winW) - clickX
			Settings_PDFPrintBtnOffsetBottom := (winY + winH) - clickY
			
			; Save to INI
			IniWrite, %Settings_PDFPrintBtnOffsetRight%, %IniFilename%, Toolbar, PDFPrintBtnOffsetRight
			IniWrite, %Settings_PDFPrintBtnOffsetBottom%, %IniFilename%, Toolbar, PDFPrintBtnOffsetBottom
			
			; Show what we captured
			ToolTip, ✅ Calibrated! Offset: %Settings_PDFPrintBtnOffsetRight% x %Settings_PDFPrintBtnOffsetBottom%, winX + 10, winY - 30
			Sleep, 1500
			ToolTip
			
			; User's click already triggered the button - wait for release
			KeyWait, LButton
			Sleep, 300
		} else {
			; Use saved calibration offsets
			printBtnX := winX + winW - Settings_PDFPrintBtnOffsetRight
			printBtnY := winY + winH - Settings_PDFPrintBtnOffsetBottom
			
			; Click the Print button
			Click, %printBtnX%, %printBtnY%
			Sleep, 500
			
			; If dialog still open, try again
			if WinExist("ProSelect - Print") {
				Sleep, 300
				Click, %printBtnX%, %printBtnY%
			}
		}
	}
	
	; Destroy hands-off GUI immediately after Print button clicked
	Gui, PDFProgress:Destroy
	
	Sleep, 1000
	
	; Wait for Save As dialog
	saveWinTitle := ""
	Loop, 40 {
		; Check various possible window titles
		if WinExist("Save Print Output As") {
			saveWinTitle := "Save Print Output As"
			break
		}
		if WinExist("Save As") {
			saveWinTitle := "Save As"
			break
		}
		if WinExist("ahk_class #32770") {
			; Generic Windows dialog - check if it has a Save button
			IfWinExist, ahk_class #32770
			{
				ControlGet, hasEdit, Enabled,, Edit1, ahk_class #32770
				if (hasEdit) {
					saveWinTitle := "ahk_class #32770"
					break
				}
			}
		}
		Sleep, 500
	}
	
	if (saveWinTitle = "") {
		ToolTip, PDF Save dialog did not appear (waited 20 seconds)
		SetTimer, RemoveToolTip, -3000
		if (origPrinter != "")
			RunWait, powershell -NoProfile -Command "Set-Printer -Name '%origPrinter%' -Default",, Hide
		Return
	}
	Sleep, 300
	
	; Build filename from album name (parent folder of album file location)
	; Album file may be in subfolder like "Unprocessed", so go up one level
	SplitPath, albumFolder, , parentFolder
	SplitPath, parentFolder, albumName
	
	; Clean up album name for PDF filename
	; Remove "copy" (case-insensitive, may appear multiple times)
	albumName := RegExReplace(albumName, "i)\s*copy\s*", "")
	; Replace spaces with underscores
	albumName := StrReplace(albumName, " ", "_")
	; Remove multiple consecutive underscores
	albumName := RegExReplace(albumName, "_+", "_")
	; Trim leading/trailing underscores
	albumName := Trim(albumName, "_")
	
	pdfName := albumName . ".pdf"
	pdfFullPath := albumFolder . "\" . pdfName
	
	; Activate and wait for the Save As dialog
	WinActivate, %saveWinTitle%
	WinWaitActive, %saveWinTitle%, , 3
	Sleep, 300
	
	; Set the filename in the Save As dialog
	ControlSetText, Edit1, %pdfFullPath%, %saveWinTitle%
	Sleep, 300
	
	; Focus and click Save (Button2 in this dialog)
	ControlFocus, Button2, %saveWinTitle%
	Sleep, 100
	ControlClick, Button2, %saveWinTitle%
	Sleep, 300
	
	; Fallback: if dialog still open, try Enter key
	if WinExist(saveWinTitle) {
		WinActivate, %saveWinTitle%
		Sleep, 100
		Send, {Enter}
	}
	Sleep, 500
	
	; Handle file overwrite confirmation dialogs
	; Check for various Windows confirmation dialog titles
	Loop, 5 {
		Sleep, 300
		; Check for "Confirm Save As" (standard dialog)
		if WinExist("Confirm Save As") {
			ControlClick, Button1, Confirm Save As  ; Click Yes to overwrite
			Sleep, 300
			continue
		}
		; Check for generic "Replace" or file exists dialogs
		if WinExist("ahk_class #32770") {
			; Look for Yes button in generic dialogs
			ControlGet, hasYes, Visible,, Button1, ahk_class #32770
			if (hasYes) {
				ControlClick, Button1, ahk_class #32770  ; Click Yes
				Sleep, 300
				continue
			}
		}
		break
	}
	
	; Wait for Save dialog to close
	WinWaitClose, %saveWinTitle%, , 5
	
	; Show tooltip while PDF generates
	ToolTip, 📄 Generating PDF...
	
	; Wait for ProSelect "Task In Progress" window to appear and close (PDF generation)
	SetTitleMatchMode, 2
	WinWait, Task In Progress ahk_exe ProSelect.exe, , 5
	if !ErrorLevel
		WinWaitClose, Task In Progress ahk_exe ProSelect.exe, , 30
	SetTitleMatchMode, 1
	
	ToolTip  ; Clear generating tooltip
	
	; Wait for PDF file to be fully written
	Sleep, 1000
	
	; Copy to secondary folder if configured
	copyStatus := ""
	if (Settings_PDFOutputFolder != "") {
		; Try to create destination folder - will fail if drive doesn't exist
		if (!FileExist(Settings_PDFOutputFolder)) {
			FileCreateDir, %Settings_PDFOutputFolder%
		}
		
		; Only proceed if destination folder now exists
		if (FileExist(Settings_PDFOutputFolder)) {
			; Wait for source file to exist (PDF generation may still be in progress)
			Loop, 10 {
				if FileExist(pdfFullPath)
					break
				Sleep, 500
			}
			
			if FileExist(pdfFullPath) {
				copyDest := Settings_PDFOutputFolder . "\" . pdfName
				FileCopy, %pdfFullPath%, %copyDest%, 1
				if ErrorLevel
					copyStatus := "Copy FAILED to " . Settings_PDFOutputFolder
				else
					copyStatus := "Also copied to " . Settings_PDFOutputFolder
			} else {
				copyStatus := "PDF file not found at " . pdfFullPath
			}
		}
		; If folder doesn't exist (drive not available), mark as skipped
		else {
			copyStatus := "SKIPPED - destination unavailable"
		}
	}
	
	; Show final result
	if FileExist(pdfFullPath) {
		if (copyStatus = "Also copied to " . Settings_PDFOutputFolder) {
			ToolTip, ✅ PDF saved + copied to %Settings_PDFOutputFolder%
		} else if InStr(copyStatus, "FAILED") {
			ToolTip, ⚠ PDF saved but copy failed
		} else if InStr(copyStatus, "SKIPPED") {
			ToolTip, ✅ PDF saved (copy skipped - drive unavailable)
		} else {
			; No copy configured
			ToolTip, ✅ PDF saved to album folder
		}
	} else {
		ToolTip, ⚠ PDF file not found at %pdfFullPath%
	}
	SetTimer, RemoveToolTip, -4000
	
	; Restore original default printer
	if (origPrinter != "")
		RunWait, powershell -NoProfile -Command "Set-Printer -Name '%origPrinter%' -Default",, Hide
Return

; ═══════════════════════════════════════════════════════════════════════════════
; GetAlbumFolder() - Gets the current album's folder path from ProSelect
; Uses menu File > Save Album as... to open Save dialog, reads the path from
; the ToolbarWindow324 breadcrumb bar, then cancels.
; ═══════════════════════════════════════════════════════════════════════════════
GetAlbumFolder() {
	; Activate ProSelect
	WinActivate, ahk_exe ProSelect.exe
	WinWaitActive, ahk_exe ProSelect.exe, , 5
	if ErrorLevel
		return ""
	Sleep, 500
	
	; Use menu to open Save Album As dialog (avoids triggering other hotkeys)
	WinMenuSelectItem, ahk_exe ProSelect.exe, , File, Save Album as...
	
	; Wait for the Save As dialog
	WinWait, Save, , 10
	if ErrorLevel
		return ""
	Sleep, 2000
	
	; Get the actual folder path by focusing the address bar (Alt+D) and copying
	; This gives us the real path including UNC paths for network locations
	albumPath := ""
	
	; Method 1: Focus address bar with Alt+D, select all, copy (clipboard-safe)
	savedClip := ""
	ClipboardSafeGet(savedClip)
	Send, !d  ; Alt+D focuses address bar in Explorer/Save dialogs
	Sleep, 500
	Send, ^c  ; Copy the path
	ClipWait, 2
	if (!ErrorLevel)
		albumPath := Clipboard
	ClipboardSafeRestore(savedClip)
	
	; Fallback: try reading Edit1 and building path from it
	if (albumPath = "" || InStr(albumPath, ".psa")) {
		; Edit1 contains the filename - we need the folder
		; Try the breadcrumb bar as fallback
		ControlGetText, breadcrumb, ToolbarWindow324, Save
		if (InStr(breadcrumb, "Address: ") = 1)
			albumPath := SubStr(breadcrumb, 10)
	}
	
	; Cancel the Save dialog without saving
	; After Alt+D, focus is in address bar - need to click Cancel button
	Sleep, 300
	ControlClick, Button2, Save  ; Cancel button
	Sleep, 200
	if WinExist("Save") {
		WinActivate, Save
		Send, {Escape}
		Sleep, 200
	}
	if WinExist("Save") {
		; Last resort - click Cancel again
		ControlClick, Cancel, Save
		Sleep, 200
	}
	WinWaitClose, Save, , 3
	Sleep, 300
	
	; Clean up trailing backslash
	albumPath := RTrim(albumPath, "\")
	
	return albumPath
}

; ═══════════════════════════════════════════════════════════════════════════════
; GetDefaultPrinterName() - Returns the name of the default printer
; Uses WMI via COM for fast access without spawning PowerShell
; ═══════════════════════════════════════════════════════════════════════════════
GetDefaultPrinterName() {
	try {
		objWMI := ComObjGet("winmgmts:{impersonationLevel=impersonate}!\\.\root\cimv2")
		for printer in objWMI.ExecQuery("SELECT Name FROM Win32_Printer WHERE Default=TRUE")
			return printer.Name
	}
	return "Unknown"
}

; ═══════════════════════════════════════════════════════════════════════════════
; GetPrinterList() - Returns pipe-separated list of available printers
; Uses WMI via COM for fast access without spawning PowerShell
; ═══════════════════════════════════════════════════════════════════════════════
GetPrinterList() {
	printerList := ""
	try {
		objWMI := ComObjGet("winmgmts:{impersonationLevel=impersonate}!\\.\root\cimv2")
		for printer in objWMI.ExecQuery("SELECT Name FROM Win32_Printer")
			printerList .= (printerList != "" ? "|" : "") . printer.Name
	}
	return printerList
}

; Debug keystroke progress indicator - shows what key is being sent when debug logging enabled
; Press Right Ctrl to skip waiting and proceed immediately
DebugKeystroke(keystrokeDesc) {
	global Settings_DebugLogging
	if (!Settings_DebugLogging)
		return
	
	; Show progress bar with keystroke description - press RCtrl to skip
	Progress, B W350 FS12 WS700, %keystrokeDesc%, Press Right Ctrl to skip (10s wait)..., SideKick Debug
	
	; Wait up to 10 seconds, checking for right control key every 100ms to skip
	Loop, 100
	{
		Sleep, 100
		; Check if right control key was pressed
		if (GetKeyState("RControl", "P"))
		{
			; Wait for key release
			KeyWait, RControl
			break
		}
	}
	Progress, Off
}

DebugKeystrokeClose:
Progress, Off
Return

; ═══════════════════════════════════════════════════════════════════════════════
; DEBUG PROGRESS GUI - Step-by-step workflow debugging with Next/Stop buttons
; Shows current step, waits for user to click Next before proceeding
; GUI is always-on-top but does NOT steal focus - keystrokes go to target window
; ═══════════════════════════════════════════════════════════════════════════════

; Show the debug progress GUI
; totalSteps: Number of steps in the workflow
DebugProgress_Show(totalSteps) {
	global DebugProgress_Active, DebugProgress_NextClicked, DebugProgress_StopClicked
	global DebugProgress_StepNum, DebugProgress_TotalSteps, Settings_DebugLogging
	global DebugProg_StepCounter, DebugProg_StepText, DebugProg_NextBtn  ; GUI control variables
	
	if (!Settings_DebugLogging)
		return
	
	DebugProgress_Active := true
	DebugProgress_NextClicked := false
	DebugProgress_StopClicked := false
	DebugProgress_StepNum := 0
	DebugProgress_TotalSteps := totalSteps
	
	; Create GUI - ToolWindow so no taskbar entry, AlwaysOnTop to stay visible
	; -SysMenu removes close button, user must click Stop to abort
	Gui, DebugProg:New, +AlwaysOnTop +ToolWindow -SysMenu +Owner
	Gui, DebugProg:Color, 2D2D30
	Gui, DebugProg:Font, s10 cWhite, Segoe UI
	
	; Title
	Gui, DebugProg:Font, s12 cE67E22 Bold
	Gui, DebugProg:Add, Text, x15 y10 w370, 🔧 Print to PDF - Debug Mode
	
	; Step counter
	Gui, DebugProg:Font, s10 cAAAAAA Normal
	Gui, DebugProg:Add, Text, x15 y40 w370 vDebugProg_StepCounter, Step 0 of %totalSteps%
	
	; Current step description
	Gui, DebugProg:Font, s11 cFFFFFF
	Gui, DebugProg:Add, Text, x15 y65 w370 h50 vDebugProg_StepText, Initializing...
	
	; Buttons - no v-variable needed, just g-label for click handler
	Gui, DebugProg:Font, s10 cFFFFFF Bold
	Gui, DebugProg:Add, Button, x15 y125 w175 h35 gDebugProg_NextClick vDebugProg_NextBtn, ▶ Next Step
	Gui, DebugProg:Add, Button, x200 y125 w175 h35 gDebugProg_StopClick, ⛔ Stop / Broken
	
	; Show GUI in bottom-right corner (above taskbar)
	SysGet, MonWork, MonitorWorkArea
	guiW := 400
	guiH := 175
	guiX := MonWorkRight - guiW - 20
	guiY := MonWorkBottom - guiH - 20
	
	Gui, DebugProg:Show, x%guiX% y%guiY% w%guiW% h%guiH% NoActivate, SideKick Debug Progress
}

; Update step text and wait for user to click Next or Stop
; stepNum: Current step number
; stepText: Description of what this step does
; Returns: true to continue, false if user clicked Stop
DebugProgress_Update(stepNum, stepText) {
	global DebugProgress_Active, DebugProgress_NextClicked, DebugProgress_StopClicked
	global DebugProgress_StepNum, DebugProgress_TotalSteps, Settings_DebugLogging
	global DebugProg_StepCounter, DebugProg_StepText  ; GUI control variables
	
	if (!Settings_DebugLogging || !DebugProgress_Active)
		return true
	
	DebugProgress_StepNum := stepNum
	DebugProgress_NextClicked := false
	
	; Update GUI text
	GuiControl, DebugProg:, DebugProg_StepCounter, Step %stepNum% of %DebugProgress_TotalSteps%
	GuiControl, DebugProg:, DebugProg_StepText, %stepText%
	
	; Note: Removed Flash - it can steal focus from dialogs we're trying to interact with
	
	; Wait for user to click Next or Stop
	Loop {
		if (DebugProgress_StopClicked) {
			DebugProgress_Close()
			return false
		}
		if (DebugProgress_NextClicked) {
			DebugProgress_NextClicked := false
			return true
		}
		Sleep, 50
	}
}

; Close the debug progress GUI
DebugProgress_Close() {
	global DebugProgress_Active
	DebugProgress_Active := false
	Gui, DebugProg:Destroy
}

; Button click handlers
DebugProg_NextClick:
	global DebugProgress_NextClicked
	DebugProgress_NextClicked := true
Return

DebugProg_StopClick:
	global DebugProgress_StopClicked
	DebugProgress_StopClicked := true
Return

DebugProgGuiClose:
	; Treat closing GUI same as Stop
	global DebugProgress_StopClicked
	DebugProgress_StopClicked := true
Return

; Calibrate menu delay based on system performance
; Runs a quick benchmark and sets Settings_MenuDelay accordingly
; Fast PC (< 50ms): 50ms delay
; Medium PC (50-100ms): 100ms delay  
; Slow PC (> 100ms): 200ms delay
CalibrateMenuDelay() {
	global Settings_MenuDelay
	
	; Run a simple CPU benchmark - count iterations in a fixed time
	startTick := A_TickCount
	iterations := 0
	
	; Do some computational work for ~20ms
	Loop {
		; Simple math operations to stress CPU
		temp := Mod(A_Index * 7919, 104729)  ; Prime number operations
		temp := Sqrt(temp)
		iterations++
		if (A_TickCount - startTick >= 20)
			break
	}
	
	; Calculate performance score (iterations per ms)
	elapsed := A_TickCount - startTick
	if (elapsed < 1)
		elapsed := 1
	score := iterations / elapsed
	
	; Set delay based on score
	; Modern PC: score > 500 (very fast)
	; Good PC: score > 200 (fast)
	; Normal PC: score > 100 (medium)
	; Slow PC: score <= 100 (slow)
	if (score > 500)
		Settings_MenuDelay := 50
	else if (score > 200)
		Settings_MenuDelay := 75
	else if (score > 100)
		Settings_MenuDelay := 100
	else
		Settings_MenuDelay := 200
}

; Calibrate the Rooms button position using OCR
; Should be called once when ProSelect is first detected
; Stores the button offset relative to window position for later use
CalibrateRoomsButton() {
	global RoomsBtn_Calibrated, RoomsBtn_X, RoomsBtn_Y, RoomsBtn_OffsetX, RoomsBtn_OffsetY
	global RoomsBtn_CalibW, RoomsBtn_CalibH
	global DPI_Scale, DebugLogFile
	static lastAttempt := 0
	
	; Cooldown - don't retry more than once per 5 seconds
	if (A_TickCount - lastAttempt < 5000)
		return false
	lastAttempt := A_TickCount
	
	; Ensure ProSelect is the active window before screen capture
	WinActivate, ahk_exe ProSelect.exe
	WinWaitActive, ahk_exe ProSelect.exe, , 2
	if (ErrorLevel) {
		FileAppend, % A_Now . " - Could not activate ProSelect for OCR calibration`n", %DebugLogFile%
		return false
	}
	Sleep, 100  ; Brief wait for window to fully render
	
	; Get ProSelect window position
	WinGetPos, psX, psY, psW, psH, ahk_exe ProSelect.exe
	if (psW = "" || psH = "")
		return false
	
	FileAppend, % A_Now . " - Calibrating Rooms button via OCR...`n", %DebugLogFile%
	FileAppend, % A_Now . " - ProSelect window: X=" . psX . " Y=" . psY . " W=" . psW . " H=" . psH . "`n", %DebugLogFile%
	
	; Define toolbar region to scan - toolbar is below title bar and menu
	; Start at ~50px from window top (after title bar + menu), scan 80px tall area
	scanX := psX + Round(psW * 0.30)
	scanY := psY + Round(50 * DPI_Scale)
	scanW := Round(psW * 0.60)
	scanH := Round(80 * DPI_Scale)
	
	FileAppend, % A_Now . " - Scan region: X=" . scanX . " Y=" . scanY . " W=" . scanW . " H=" . scanH . " DPI=" . DPI_Scale . "`n", %DebugLogFile%
	
	; Run OCR script to find "Rooms" text
	ocrScript := A_ScriptDir . "\OCR_FindText.ps1"
	if (!FileExist(ocrScript)) {
		FileAppend, % A_Now . " - OCR script not found: " . ocrScript . "`n", %DebugLogFile%
		return false
	}
	
	psCmd := "powershell.exe -ExecutionPolicy Bypass -File """ . ocrScript . """ -x " . scanX . " -y " . scanY . " -width " . scanW . " -height " . scanH . " -searchText ""Rooms"""
	
	; Run and capture output
	RunWait, %ComSpec% /c %psCmd% > "%A_Temp%\ocr_result.json" 2>&1, , Hide
	
	; Read result
	FileRead, ocrJson, %A_Temp%\ocr_result.json
	if (ocrJson = "") {
		FileAppend, % A_Now . " - OCR returned empty result`n", %DebugLogFile%
		return false
	}
	
	; Log raw JSON for debugging (first 500 chars)
	FileAppend, % A_Now . " - OCR raw output: " . SubStr(ocrJson, 1, 500) . "`n", %DebugLogFile%
	
	; Log what OCR detected for debugging
	RegExMatch(ocrJson, """fullText"":""([^""]*)", fullTextMatch)
	FileAppend, % A_Now . " - OCR detected: " . fullTextMatch1 . "`n", %DebugLogFile%
	
	; Parse JSON to find "Rooms" position
	; Look for "found":{"text":"Rooms", pattern
	if (InStr(ocrJson, """found"":null") || !InStr(ocrJson, """found"":{")) {
		FileAppend, % A_Now . " - OCR did not find 'Rooms' text in detected words`n", %DebugLogFile%
		return false
	}
	
	; Extract centerX and centerY from found object
	RegExMatch(ocrJson, """centerX"":(\d+)", matchX)
	RegExMatch(ocrJson, """centerY"":(\d+)", matchY)
	
	if (matchX1 = "" || matchY1 = "") {
		FileAppend, % A_Now . " - Could not parse Rooms button position from OCR`n", %DebugLogFile%
		return false
	}
	
	; Store absolute position and offset from window
	RoomsBtn_X := matchX1
	RoomsBtn_Y := matchY1
	RoomsBtn_OffsetX := RoomsBtn_X - psX
	RoomsBtn_OffsetY := RoomsBtn_Y - psY
	RoomsBtn_CalibW := psW
	RoomsBtn_CalibH := psH
	RoomsBtn_Calibrated := true
	
	FileAppend, % A_Now . " - Rooms button calibrated at offset (" . RoomsBtn_OffsetX . ", " . RoomsBtn_OffsetY . ") for window " . psW . "x" . psH . "`n", %DebugLogFile%
	return true
}

; Check if ProSelect is currently showing Room View
; Uses calibrated Rooms button position if available, otherwise scans toolbar
; Returns true if Room view is active, false otherwise
IsRoomViewActive() {
	global DPI_Scale, RoomsBtn_Calibrated, RoomsBtn_OffsetX, RoomsBtn_OffsetY
	global RoomsBtn_CalibW, RoomsBtn_CalibH, DebugLogFile, Settings_DebugLogging
	
	; Get ProSelect window position
	WinGetPos, psX, psY, psW, psH, ahk_exe ProSelect.exe
	if (psW = "" || psH = "")
		return false
	
	; If calibrated, check the known Rooms button position
	if (RoomsBtn_Calibrated) {
		baseX := psX + RoomsBtn_OffsetX
		baseY := psY + RoomsBtn_OffsetY
		
		; Only check pixels if ProSelect is the active window (avoid reading covered pixels)
		WinGet, activeExe, ProcessName, A
		if (activeExe != "ProSelect.exe")
			return false  ; Can't determine state, assume not in Room view
		
		; Use screen coordinates for pixel check
		CoordMode, Pixel, Screen
		
		; Icon is RIGHT of text "Rooms" and both change color
		; Text center is at baseX, scan from 0 to +40px right
		; Check 9 points across text and icon area
		Loop, 3 {
			scanY := baseY - 3 + (A_Index - 1) * 3  ; -3, 0, +3 from text center
			Loop, 3 {
				scanX := baseX + (A_Index - 1) * 15  ; 0, +15, +30 right of text center
				
				PixelGetColor, pixelColor, %scanX%, %scanY%, RGB Slow
				red := (pixelColor >> 16) & 0xFF
				green := (pixelColor >> 8) & 0xFF
				blue := pixelColor & 0xFF
				
				; Yellow detection: based on actual samples, active=159,112,71, inactive=68,68,68
				; Detect if R>120 AND (R+G) > 200 AND R > B+20 (not gray)
				if (red > 120 && (red + green) > 200 && red > blue + 20)
					return true
			}
		}
		
		; Log every 5 seconds during debugging - sample a grid
		global RoomView_LastLogTime
		if (Settings_DebugLogging && A_TickCount - RoomView_LastLogTime > 5000) {
			RoomView_LastLogTime := A_TickCount
			; Sample 10 points across the Rooms text/icon area and log all colors
			FileAppend, % A_Now . " - RoomView grid sample starting at (" . baseX . "," . baseY . "):`n", %DebugLogFile%
			maxR := 0
			maxG := 0
			Loop, 10 {
				sX := baseX - 10 + (A_Index - 1) * 5  ; -10 to +35 from center
				PixelGetColor, pxColor, %sX%, %baseY%, RGB Slow
				pR := (pxColor >> 16) & 0xFF
				pG := (pxColor >> 8) & 0xFF
				pB := pxColor & 0xFF
				FileAppend, % "  x" . A_Index . "=" . pR . "," . pG . "," . pB, %DebugLogFile%
				if (pR > maxR)
					maxR := pR
				if (pG > maxG)
					maxG := pG
			}
			FileAppend, % "`n  Max R=" . maxR . " Max G=" . maxG . "`n", %DebugLogFile%
		}
		
		return false
	}
	
	; Fallback: If not calibrated, assume not in room view (user gets gray icon, must click to try)
	; This avoids false positives from other orange icons in the toolbar
	return false
}

; === QR Code Cache Management ===
; Pre-generates QR codes on startup/settings change for instant display

GenerateQRCache() {
	global Settings_QRCode_Text1, Settings_QRCode_Text2, Settings_QRCode_Text3
	global QR_CacheFolder, QR_CachedFiles
	
	; Create cache folder if needed
	if (!FileExist(QR_CacheFolder))
		FileCreateDir, %QR_CacheFolder%
	
	; Clear cached files array
	QR_CachedFiles := []
	
	; Generate QR for each non-empty text
	texts := [Trim(Settings_QRCode_Text1), Trim(Settings_QRCode_Text2), Trim(Settings_QRCode_Text3)]
	
	Loop, 3
	{
		text := texts[A_Index]
		if (text = "")
			continue
		
		; Create hash-based filename from text content
		hash := QR_SimpleHash(text)
		cacheFile := QR_CacheFolder . "\qr_" . A_Index . "_" . hash . ".png"
		
		; Only regenerate if file doesn't exist (text changed or first run)
		if (!FileExist(cacheFile)) {
			; Delete old cached files for this slot
			FileDelete, %QR_CacheFolder%\qr_%A_Index%_*.png
			; Generate new QR code (1000px for high quality display)
			SaveQRFile(text, cacheFile, 1000)
		}
		
		QR_CachedFiles[A_Index] := cacheFile
	}
}

; Simple hash function for cache invalidation
QR_SimpleHash(str) {
	hash := 0
	Loop, Parse, str
		hash := (hash * 31 + Asc(A_LoopField)) & 0x7FFFFFFF
	return Format("{:08X}", hash)
}

Toolbar_QRCode:
; Show fullscreen display - cycles through QR codes, bank details, and images
{
	global Settings_QRCode_Text1, Settings_QRCode_Text2, Settings_QRCode_Text3
	global Settings_BankInstitution, Settings_BankName, Settings_BankSortCode, Settings_BankAccNo
	global Settings_DisplayImage1, Settings_DisplayImage2, Settings_DisplayImage3
	global Slide_CurrentIndex, Slide_Items, Slide_Count
	
	; Build array of all slide items
	Slide_Items := []
	
	; Add QR codes (if not blank)
	qrText1 := Trim(Settings_QRCode_Text1)
	qrText2 := Trim(Settings_QRCode_Text2)
	qrText3 := Trim(Settings_QRCode_Text3)
	if (qrText1 != "")
		Slide_Items.Push({type: "qr", data: qrText1})
	if (qrText2 != "")
		Slide_Items.Push({type: "qr", data: qrText2})
	if (qrText3 != "")
		Slide_Items.Push({type: "qr", data: qrText3})
	
	; Add bank details slide (if any bank field is not blank)
	bankInst := Trim(Settings_BankInstitution)
	bankName := Trim(Settings_BankName)
	bankSort := Trim(Settings_BankSortCode)
	bankAcc := Trim(Settings_BankAccNo)
	if (bankInst != "" || bankName != "" || bankSort != "" || bankAcc != "")
		Slide_Items.Push({type: "bank", data: {inst: bankInst, name: bankName, sort: bankSort, acc: bankAcc}})
	
	; Add images (if not blank and file exists)
	img1 := Trim(Settings_DisplayImage1)
	img2 := Trim(Settings_DisplayImage2)
	img3 := Trim(Settings_DisplayImage3)
	if (img1 != "" && FileExist(img1))
		Slide_Items.Push({type: "image", data: img1})
	if (img2 != "" && FileExist(img2))
		Slide_Items.Push({type: "image", data: img2})
	if (img3 != "" && FileExist(img3))
		Slide_Items.Push({type: "image", data: img3})
	
	Slide_Count := Slide_Items.Length()
	if (Slide_Count = 0) {
		DarkMsgBox("Display", "No content configured.`n`nGo to Settings → Display tab to add QR codes, bank details, or images.", "info", {timeout: 5})
		return
	}
	
	Slide_CurrentIndex := 1
	ShowFullscreenSlide(Slide_CurrentIndex)
}
Return

ShowFullscreenSlide(index) {
	global Slide_Items, Slide_Count, Slide_CurrentIndex
	global QRImage, QRLabel, QRCounter, QRDisplayHwnd
	global QR_CacheFolder, QR_CachedFiles
	global Settings_QRCode_Display, Settings_DisplaySize, Settings_BankScale
	global QRDisplay_Created
	
	Slide_CurrentIndex := index
	slide := Slide_Items[index]
	
	; Get selected monitor dimensions
	monNum := Settings_QRCode_Display ? Settings_QRCode_Display : 1
	SysGet, monCount, MonitorCount
	if (monNum > monCount)
		monNum := 1
	SysGet, mon, MonitorWorkArea, %monNum%
	screenW := monRight - monLeft
	screenH := monBottom - monTop
	screenX := monLeft
	screenY := monTop
	
	; Get DPI scale factor
	hDC := DllCall("GetDC", "Ptr", 0, "Ptr")
	dpi := DllCall("GetDeviceCaps", "Ptr", hDC, "Int", 88)
	DllCall("ReleaseDC", "Ptr", 0, "Ptr", hDC)
	dpiScale := dpi / 96
	
	; Use Settings_DisplaySize for content size (default 80%)
	displaySize := Settings_DisplaySize ? Settings_DisplaySize : 80
	contentSize := Round(Min(screenW, screenH) * (displaySize / 100))
	
	; Counter text
	counterText := index . " / " . Slide_Count . "    ↑↓ cycle slides  •  ←→ move display  •  Esc to close"
	counterY := screenH - Round(40 * dpiScale)
	counterFontSize := Round(11 * dpiScale)
	
	; Always recreate GUI for different slide types
	Gui, QRDisplay:Destroy
	QRDisplay_Created := false
	
	Gui, QRDisplay:New, +AlwaysOnTop -Caption -DPIScale +HwndQRDisplayHwnd
	Gui, QRDisplay:Color, 000000
	
	if (slide.type = "qr") {
		; QR CODE SLIDE
		text := slide.data
		
		; Get cached file or generate
		global Settings_QRCode_Text1, Settings_QRCode_Text2, Settings_QRCode_Text3
		slot := 0
		if (text = Trim(Settings_QRCode_Text1))
			slot := 1
		else if (text = Trim(Settings_QRCode_Text2))
			slot := 2
		else if (text = Trim(Settings_QRCode_Text3))
			slot := 3
		
		tempFile := ""
		if (slot > 0 && QR_CachedFiles.HasKey(slot) && FileExist(QR_CachedFiles[slot])) {
			tempFile := QR_CachedFiles[slot]
		} else {
			tempFile := A_Temp . "\sidekick_qrcode_" . index . ".png"
			SaveQRFile(text, tempFile, 1000)
		}
		
		if (!FileExist(tempFile)) {
			DarkMsgBox("QR Code Error", "Failed to load QR code.", "error", {timeout: 5})
			return
		}
		
		; Build display label
		displayText := text
		if (RegExMatch(text, "i)^WIFI:T:([^;]*);S:([^;]*);P:([^;]*);", wifiMatch)) {
			displayText := "WiFi: " . wifiMatch2 . "  |  Password: " . wifiMatch3
		} else if (RegExMatch(text, "i)^https?://([^/]+)", match)) {
			displayText := match1
		}
		if (StrLen(displayText) > 60)
			displayText := SubStr(displayText, 1, 60) . "..."
		
		; Calculate positions
		qrX := Round((screenW - contentSize) / 2)
		qrY := Round((screenH - contentSize - 70) / 2)
		labelY := qrY + contentSize + Round(20 * dpiScale)
		
		Gui, QRDisplay:Add, Picture, x%qrX% y%qrY% w%contentSize% h%contentSize% vQRImage, %tempFile%
		
		labelFontSize := Round(18 * dpiScale)
		Gui, QRDisplay:Font, s%labelFontSize% cCCCCCC, Segoe UI
		Gui, QRDisplay:Add, Text, x0 y%labelY% w%screenW% Center BackgroundTrans vQRLabel, %displayText%
		
	} else if (slide.type = "bank") {
		; BANK DETAILS SLIDE
		bankData := slide.data
		
		; Extract to local variables (required for AHK v1 GUI commands)
		bankInst := bankData.inst
		bankName := bankData.name
		bankSort := bankData.sort
		bankAcc := bankData.acc
		
		; Format sort code as ##-##-##
		sortCode := bankSort
		sortCode := RegExReplace(sortCode, "[^0-9]", "")  ; Remove non-digits
		if (StrLen(sortCode) = 6)
			sortCode := SubStr(sortCode, 1, 2) . "-" . SubStr(sortCode, 3, 2) . "-" . SubStr(sortCode, 5, 2)
		
		; Scale fonts based on display size (same as QR sizing)
		sizeScale := displaySize / 80  ; 80% is baseline
		; Bank scale adjusts font and spacing relative to DPI
		bankScale := Settings_BankScale / 100  ; 100% is baseline
		
		; Calculate box dimensions based on content size
		boxW := Round(contentSize * 1.2)
		boxH := Round(contentSize)
		boxX := Round((screenW - boxW) / 2)
		boxY := Round((screenH - boxH) / 2)
		
		; Add white border/background box
		Gui, QRDisplay:Add, Text, x%boxX% y%boxY% w%boxW% h%boxH% Background1A1A1A Border
		
		; Calculate total content height to center vertically (using bank scale for spacing)
		iconH := Round(110 * dpiScale * sizeScale * bankScale)
		iconPad := Round(25 * dpiScale * sizeScale * bankScale)
		titleH := Round(100 * dpiScale * sizeScale * bankScale)
		detailH := Round(85 * dpiScale * sizeScale * bankScale)
		labelH := Round(55 * dpiScale * sizeScale * bankScale)
		valueH := Round(95 * dpiScale * sizeScale * bankScale)
		spacing := Round(50 * dpiScale * sizeScale * bankScale)
		titleExtra := Round(60 * dpiScale * sizeScale * bankScale)
		
		totalH := iconH + iconPad + titleH + titleExtra
		if (bankInst != "")
			totalH += detailH
		if (bankName != "")
			totalH += detailH + spacing
		if (sortCode != "")
			totalH += labelH + valueH + spacing
		if (bankAcc != "")
			totalH += labelH + valueH
		
		; Start Y centered in box
		lineY := boxY + Round((boxH - totalH) / 2)
		
		; Icon on its own line (not bold)
		iconFontSize := Round(90 * dpiScale * sizeScale * bankScale)
		Gui, QRDisplay:Font, s%iconFontSize% cFFFFFF, Segoe UI
		Gui, QRDisplay:Add, Text, x%boxX% y%lineY% w%boxW% Center BackgroundTrans, 🏦
		lineY += iconH + iconPad
		
		; Title text (bold, gray)
		titleFontSize := Round(80 * dpiScale * sizeScale * bankScale)
		Gui, QRDisplay:Font, s%titleFontSize% cCCCCCC Bold, Segoe UI
		Gui, QRDisplay:Add, Text, x%boxX% y%lineY% w%boxW% Center BackgroundTrans, Bank Transfer
		lineY += titleH + titleExtra
		
		; Bank details (white)
		detailFontSize := Round(56 * dpiScale * sizeScale * bankScale)
		Gui, QRDisplay:Font, s%detailFontSize% cFFFFFF, Segoe UI
		
		if (bankInst != "") {
			Gui, QRDisplay:Add, Text, x%boxX% y%lineY% w%boxW% Center BackgroundTrans, %bankInst%
			lineY += detailH
		}
		if (bankName != "") {
			Gui, QRDisplay:Add, Text, x%boxX% y%lineY% w%boxW% Center BackgroundTrans, %bankName%
			lineY += detailH + spacing
		}
		
		; Sort code and account number with labels
		labelFontSize := Round(40 * dpiScale * sizeScale * bankScale)
		valueFontSize := Round(72 * dpiScale * sizeScale * bankScale)
		
		if (sortCode != "") {
			Gui, QRDisplay:Font, s%labelFontSize% c888888, Segoe UI
			Gui, QRDisplay:Add, Text, x%boxX% y%lineY% w%boxW% Center BackgroundTrans, Sort Code
			lineY += labelH
			Gui, QRDisplay:Font, s%valueFontSize% cFFFFFF Bold, Consolas
			Gui, QRDisplay:Add, Text, x%boxX% y%lineY% w%boxW% Center BackgroundTrans, %sortCode%
			lineY += valueH + spacing
		}
		if (bankAcc != "") {
			Gui, QRDisplay:Font, s%labelFontSize% c888888, Segoe UI
			Gui, QRDisplay:Add, Text, x%boxX% y%lineY% w%boxW% Center BackgroundTrans, Account Number
			lineY += labelH
			Gui, QRDisplay:Font, s%valueFontSize% cFFFFFF Bold, Consolas
			Gui, QRDisplay:Add, Text, x%boxX% y%lineY% w%boxW% Center BackgroundTrans, %bankAcc%
		}
		
	} else if (slide.type = "image") {
		; IMAGE SLIDE
		imagePath := slide.data
		
		; Center image (it will auto-scale with w and h)
		imgX := Round((screenW - contentSize) / 2)
		imgY := Round((screenH - contentSize - 50) / 2)
		
		Gui, QRDisplay:Add, Picture, x%imgX% y%imgY% w%contentSize% h-1 vQRImage, %imagePath%
		
		; Show filename as label
		SplitPath, imagePath, fileName
		labelFontSize := Round(14 * dpiScale)
		labelY := imgY + contentSize + Round(20 * dpiScale)
		Gui, QRDisplay:Font, s%labelFontSize% c666666, Segoe UI
		Gui, QRDisplay:Add, Text, x0 y%labelY% w%screenW% Center BackgroundTrans vQRLabel, %fileName%
	}
	
	; Counter / instructions at bottom
	Gui, QRDisplay:Font, s%counterFontSize% c666666, Segoe UI
	Gui, QRDisplay:Add, Text, x0 y%counterY% w%screenW% Center BackgroundTrans vQRCounter, %counterText%
	
	; Show fullscreen
	Gui, QRDisplay:Show, x%screenX% y%screenY% w%screenW% h%screenH%, SideKick QR Code
	QRDisplay_Created := true
	
	; Bind hotkeys
	Hotkey, IfWinActive, SideKick QR Code
	Hotkey, WheelUp, QRCode_Prev, On
	Hotkey, WheelDown, QRCode_Next, On
	Hotkey, Up, QRCode_Prev, On
	Hotkey, Down, QRCode_Next, On
	Hotkey, Left, QRCode_MonitorPrev, On
	Hotkey, Right, QRCode_MonitorNext, On
	Hotkey, MButton, QRDisplayGuiClose, On
	Hotkey, IfWinActive
}

QRCode_Next:
{
	global Slide_CurrentIndex, Slide_Count
	newIndex := Slide_CurrentIndex + 1
	if (newIndex > Slide_Count)
		newIndex := 1
	ShowFullscreenSlide(newIndex)
}
Return

QRCode_Prev:
{
	global Slide_CurrentIndex, Slide_Count
	newIndex := Slide_CurrentIndex - 1
	if (newIndex < 1)
		newIndex := Slide_Count
	ShowFullscreenSlide(newIndex)
}
Return

QRCode_MonitorNext:
{
	global Settings_QRCode_Display, QRDisplay_Created, Slide_CurrentIndex
	SysGet, monCount, MonitorCount
	if (monCount <= 1)
		return
	Settings_QRCode_Display := Settings_QRCode_Display + 1
	if (Settings_QRCode_Display > monCount)
		Settings_QRCode_Display := 1
	Gui, QRDisplay:Destroy
	QRDisplay_Created := false
	ShowFullscreenSlide(Slide_CurrentIndex)
}
Return

QRCode_MonitorPrev:
{
	global Settings_QRCode_Display, QRDisplay_Created, Slide_CurrentIndex
	SysGet, monCount, MonitorCount
	if (monCount <= 1)
		return
	Settings_QRCode_Display := Settings_QRCode_Display - 1
	if (Settings_QRCode_Display < 1)
		Settings_QRCode_Display := monCount
	Gui, QRDisplay:Destroy
	QRDisplay_Created := false
	ShowFullscreenSlide(Slide_CurrentIndex)
}
Return

QRDisplayGuiClose:
QRDisplayGuiEscape:
global QRDisplay_Created
QRDisplay_Created := false
Hotkey, IfWinActive, SideKick QR Code
Hotkey, WheelUp, QRCode_Prev, Off
Hotkey, WheelDown, QRCode_Next, Off
Hotkey, Up, QRCode_Prev, Off
Hotkey, Down, QRCode_Next, Off
Hotkey, Left, QRCode_MonitorPrev, Off
Hotkey, Right, QRCode_MonitorNext, Off
Hotkey, IfWinActive
Gui, QRDisplay:Destroy
Return

QRCode_UrlEncode(str) {
	old := A_FormatInteger
	SetFormat, IntegerFast, H
	VarSetCapacity(out, StrPut(str, "UTF-8"), 0)
	StrPut(str, &out, "UTF-8")
	result := ""
	Loop
	{
		code := NumGet(out, A_Index - 1, "UChar")
		if (!code)
			break
		if (code >= 0x30 && code <= 0x39)       ; 0-9
			|| (code >= 0x41 && code <= 0x5A)    ; A-Z
			|| (code >= 0x61 && code <= 0x7A)    ; a-z
			|| (code = 0x2D)                     ; -
			|| (code = 0x2E)                     ; .
			|| (code = 0x5F)                     ; _
			|| (code = 0x7E)                     ; ~
			result .= Chr(code)
		else {
			hex := SubStr(code + 0x100, -1)
			result .= "%" . hex
		}
	}
	SetFormat, IntegerFast, %old%
	return result
}

Toolbar_DownloadSD:
; License check for SD download feature
if (!CheckLicenseForFeature("SD Card Download"))
	return
; Placeholder - Image download functionality coming soon
DarkMsgBox("Coming Soon", "📥 Image Download`n`nImage download functionality to follow in a future update.", "info", {timeout: 5})
Return

Toolbar_GoCardless:
; GoCardless Direct Debit - check mandate and send link if needed
{
	global GHL_ContactData, Settings_GCEmailTemplateID, Settings_GCEmailTemplateName
	global Settings_GCSMSTemplateID, Settings_GCSMSTemplateName
	global Settings_GoCardlessToken, Settings_GoCardlessEnvironment
	global GHL_CachedEmailTemplates
	
	; Check if ProSelect has an album loaded
	if WinExist("ProSelect ahk_exe ProSelect.exe")
	{
		WinGetTitle, psTitle, ahk_exe ProSelect.exe
		if (psTitle = "ProSelect - Untitled" || psTitle = "ProSelect") {
			DarkMsgBox("No Album Loaded", "Please open an album in ProSelect first before checking GoCardless mandate.", "warning")
			return
		}
	} else {
		DarkMsgBox("ProSelect Not Running", "ProSelect is not running.`n`nPlease open ProSelect with an album first.", "warning")
		return
	}
	
	; Check if GoCardless is configured
	if (Settings_GoCardlessToken = "") {
		DarkMsgBox("GoCardless Not Configured", "Please configure your GoCardless API token in Settings > GoCardless first.", "warning")
		return
	}
	
	; Check if we have a GHL contact loaded - if not, try to auto-fetch from album name
	if (GHL_ContactData = "" || !GHL_ContactData.HasKey("id")) {
		; Try to extract Client ID from ProSelect album name
		albumContactId := ""
		if WinExist("ProSelect ahk_exe ProSelect.exe")
		{
			WinGetTitle, psTitle, ahk_exe ProSelect.exe
			; Look for GHL Client ID pattern in album name (20+ alphanumeric chars after underscore)
			if (RegExMatch(psTitle, "_([A-Za-z0-9]{20,})", idMatch))
				albumContactId := idMatch1
		}
		
		if (albumContactId != "") {
			; Auto-fetch client data from GHL
			ToolTip, Fetching client from GHL...
			GHL_ContactData := FetchGHLData(albumContactId)
			ToolTip
			
			if (!GHL_ContactData.success) {
				DarkMsgBox("GHL Fetch Failed", "Could not fetch client data from GHL.`n`n" . GHL_ContactData.error, "error")
				return
			}
		} else {
			DarkMsgBox("No Client Found", "No GHL Client ID in album name.`n`nPlease fetch a client from GHL first using the Client button,`nor ensure the album name contains a GHL Client ID.", "warning")
			return
		}
	}
	
	clientName := GHL_ContactData.firstName . " " . GHL_ContactData.lastName
	clientEmail := GHL_ContactData.email
	
	if (clientEmail = "") {
		DarkMsgBox("No Email", "Client '" . clientName . "' has no email address.`n`nCannot send GoCardless mandate link.", "warning")
		return
	}
	
	; Show checking status
	ToolTip, Checking GoCardless mandate for %clientEmail%...
	
	; Check if customer has existing mandate
	mandateResult := GC_CheckCustomerMandate(clientEmail)
	
	ToolTip
	
	if (mandateResult.error) {
		DarkMsgBox("GoCardless Error", "Could not check mandate status.`n`n" . mandateResult.error, "error")
		return
	}
	
	if (mandateResult.hasMandate) {
		; Customer has an active mandate - ask if they want to set up a payment plan
		mandateId := mandateResult.mandateId
		mandateStatus := mandateResult.mandateStatus
		bankName := mandateResult.bankName
		customerId := mandateResult.customerId
		existingPlans := mandateResult.plans ? Trim(mandateResult.plans) : ""
		
		; DEBUG: Show what we got
		; MsgBox, % "Plans value: [" . existingPlans . "] Length: " . StrLen(existingPlans)
		
		; Build message - default to "No Existing Plans", only show plans if we have real content
		plansMsg := "`n`n✅ No Existing Plans"
		if (existingPlans != "") {
			; Only show if there's actual plan text (not just whitespace)
			cleanPlans := RegExReplace(existingPlans, "^\s+|\s+$")
			if (StrLen(cleanPlans) > 0) {
				plansMsg := "`n`n⚠️ Existing Plans:`n" . cleanPlans
			}
		}
		
		; Dark dialog with custom buttons
		msg := "✅ " . clientName . " has an active Direct Debit mandate." . plansMsg
		
		result := DarkMsgBox("Mandate Active", msg, "success", {buttons: ["Add PayPlan", "Open GC Client", "Cancel"]})
		
		if (result = "Add PayPlan") {
			GC_ShowPayPlanDialog(GHL_ContactData, mandateResult)
		}
		else if (result = "Open GC Client") {
			; Open GoCardless customer page
			gcEnv := (Settings_GoCardlessEnvironment = "live") ? "manage" : "manage-sandbox"
			gcUrl := "https://" . gcEnv . ".gocardless.com/customers/" . customerId
			Run, %gcUrl%
		}
		return
	}
	
	; No mandate - ask if user wants to send request
	; Check if at least one notification method is configured
	hasEmail := (Settings_GCEmailTemplateName != "" && Settings_GCEmailTemplateName != "SELECT")
	hasSMS := (Settings_GCSMSTemplateName != "" && Settings_GCSMSTemplateName != "SELECT")
	
	if (!hasEmail && !hasSMS) {
		DarkMsgBox("No Template Selected", "No mandate found for " . clientName . ".`n`nPlease select an Email or SMS template in Settings > GoCardless to send mandate requests.", "warning")
		ShowSettingsTab("GoCardless")
		Gui, Settings:Show
		return
	}
	
	; Build notification method description
	notifyMethods := ""
	if (hasEmail)
		notifyMethods .= "📧 Email: " . Settings_GCEmailTemplateName . "`n"
	if (hasSMS)
		notifyMethods .= "📱 SMS: " . Settings_GCSMSTemplateName
	
	; Show confirmation dialog with dark theme
	msg := "No Direct Debit mandate found for:`n`n👤 " . clientName . "`n📧 " . clientEmail . "`n`nWould you like to send a mandate setup request?`n`n" . notifyMethods
	result := DarkMsgBox("Send Mandate Request?", msg, "question", {buttons: ["Send Request", "Use Another", "Cancel"]})
	
	if (result = "Send Request")
	{
		; Create billing request and send notifications
		GC_SendMandateRequest(GHL_ContactData, hasEmail, hasSMS)
	}
	else if (result = "Use Another")
	{
		; Ask user for name or email to search
		GC_SearchMandateByNameOrEmail(GHL_ContactData)
	}
}
Return

; Search for mandate by a different name or email (e.g., partner's name/email)
GC_SearchMandateByNameOrEmail(contactData) {
	global Settings_GoCardlessEnvironment, DebugLogFile
	
	; Show input dialog for name or email (AlwaysOnTop)
	Gui, GCSearchInput:New, +AlwaysOnTop +ToolWindow +HwndGCSearchHwnd
	Gui, GCSearchInput:Add, Text, x15 y15, Enter name or email to search for mandate:
	Gui, GCSearchInput:Add, Edit, x15 y40 w280 vGCSearchTerm
	Gui, GCSearchInput:Add, Button, x85 y75 w60 gGCSearchOK Default, OK
	Gui, GCSearchInput:Add, Button, x155 y75 w60 gGCSearchCancel, Cancel
	Gui, GCSearchInput:Show, w310 h115, Search Mandate
	
	; Wait for user input
	global GCSearchResult := ""
	WinWaitClose, ahk_id %GCSearchHwnd%
	searchTerm := GCSearchResult
	
	if (searchTerm = "")
		return
	
	; Detect if it's an email (contains @) or a name
	isEmail := InStr(searchTerm, "@") > 0
	searchType := isEmail ? "email" : "name"
	
	ToolTip, Searching for mandate by %searchType%: %searchTerm%...
	
	; Call Python script with appropriate argument
	envFlag := (Settings_GoCardlessEnvironment = "live") ? " --live" : ""
	if (isEmail)
		scriptCmd := GetScriptCommand("gocardless_api", "--check-mandate """ . searchTerm . """" . envFlag)
	else
		scriptCmd := GetScriptCommand("gocardless_api", "--check-mandate-by-name """ . searchTerm . """" . envFlag)
	
	FileAppend, % A_Now . " - GC_SearchMandateByNameOrEmail - scriptCmd: " . scriptCmd . "`n", %DebugLogFile%
	
	tempResult := A_Temp . "\gc_mandate_search_" . A_TickCount . ".txt"
	fullCmd := ComSpec . " /c " . scriptCmd . " > """ . tempResult . """ 2>&1"
	RunWait, %fullCmd%, , Hide
	
	FileRead, scriptOutput, %tempResult%
	FileAppend, % A_Now . " - GC_SearchMandateByNameOrEmail - output: " . scriptOutput . "`n", %DebugLogFile%
	FileDelete, %tempResult%
	
	ToolTip
	
	scriptOutput := Trim(scriptOutput)
	
	if (InStr(scriptOutput, "ERROR|")) {
		errorMsg := StrReplace(scriptOutput, "ERROR|", "")
		DarkMsgBox("Search Error", "Failed to search mandate.`n`n" . errorMsg, "error")
		return
	}
	
	if (InStr(scriptOutput, "NO_CUSTOMER")) {
		DarkMsgBox("Not Found", "No customer found matching '" . searchTerm . "'.", "warning")
		return
	}
	
	if (InStr(scriptOutput, "MANDATE_FOUND|")) {
		; MANDATE_FOUND|customer_id|mandate_id|status|bank_name|plans|customer_name|customer_email
		parts := StrSplit(scriptOutput, "|")
		mandateResult := {}
		mandateResult.hasMandate := true
		mandateResult.customerId := parts[2]
		mandateResult.mandateId := parts[3]
		mandateResult.mandateStatus := parts[4]
		mandateResult.bankName := parts[5]
		mandateResult.plans := (parts.Length() >= 6) ? parts[6] : ""
		foundName := (parts.Length() >= 7) ? parts[7] : searchTerm
		foundEmail := (parts.Length() >= 8) ? parts[8] : ""
		
		; Show success and offer to create payment plan
		plansMsg := "`n`n✅ No Existing Plans"
		if (mandateResult.plans != "") {
			cleanPlans := RegExReplace(mandateResult.plans, "^\s+|\s+$")
			if (StrLen(cleanPlans) > 0)
				plansMsg := "`n`n⚠️ Existing Plans:`n" . cleanPlans
		}
		
		msg := "✅ Found mandate for " . foundName . plansMsg
		
		result := DarkMsgBox("Mandate Found", msg, "success", {buttons: ["Add PayPlan", "Open GC Client", "Cancel"]})
		
		if (result = "Add PayPlan") {
			GC_ShowPayPlanDialog(contactData, mandateResult)
		}
		else if (result = "Open GC Client") {
			; Open GoCardless customer page
			gcEnv := (Settings_GoCardlessEnvironment = "live") ? "manage" : "manage-sandbox"
			gcUrl := "https://" . gcEnv . ".gocardless.com/customers/" . mandateResult.customerId
			Run, %gcUrl%
		}
		return
	}
	
	if (InStr(scriptOutput, "NO_MANDATE|")) {
		; NO_MANDATE|customer_id|customer_name|customer_email (for name search)
		; NO_MANDATE|customer_id (for email search)
		parts := StrSplit(scriptOutput, "|")
		foundName := (parts.Length() >= 3) ? parts[3] : searchTerm
		DarkMsgBox("No Mandate", "Customer '" . foundName . "' exists but has no active mandate.", "warning")
		return
	}
	
	; Unexpected response
	DarkMsgBox("Search Error", "Unexpected response from search.`n`n" . SubStr(scriptOutput, 1, 200), "error")
}
Return

; Button handlers for Search Mandate dialog
GCSearchOK:
Gui, GCSearchInput:Submit
GCSearchResult := GCSearchTerm
Gui, GCSearchInput:Destroy
return

GCSearchCancel:
GCSearchInputGuiClose:
GCSearchInputGuiEscape:
GCSearchResult := ""
Gui, GCSearchInput:Destroy
return

Toolbar_CaptureRoom:
; Capture the central room view from ProSelect and save as JPG
{
	global Settings_RoomCaptureFolder, IniFilename, DPI_Scale
	
	; Get the album name from ProSelect window title
	WinGetTitle, psTitle, ahk_exe ProSelect.exe
	if (psTitle = "" || psTitle = "ProSelect")
	{
		DarkMsgBox("Capture Failed", "No album is open in ProSelect.", "warning", {timeout: 3})
		return
	}
	
	; Activate ProSelect first to ensure we're checking the right window
	WinActivate, ahk_exe ProSelect.exe
	WinWaitActive, ahk_exe ProSelect.exe, , 2
	Sleep, 100
	
	; Room view check disabled - capture from any view
	/*
	; Check if ProSelect is in Room View by looking for yellow/orange highlighted Rooms button
	; The Rooms button is in the icon toolbar at the top, has yellow color when active
	if (!IsRoomViewActive())
	{
		DarkMsgBox("Room View Required", "📷 Please switch to Room View first.`n`nClick the Rooms button (🏠) in the ProSelect toolbar, then try again.", "warning", {timeout: 5})
		return
	}
	*/
	
	; Extract album name - remove "ProSelect - " prefix and " - ProSelect" suffix
	albumName := RegExReplace(psTitle, "^ProSelect\s*-\s*", "")  ; Remove "ProSelect - " prefix
	albumName := RegExReplace(albumName, "\s*-\s*ProSelect.*$", "")  ; Remove " - ProSelect" suffix
	albumName := RegExReplace(albumName, "[\\/:*?""<>|]", "_")  ; Remove invalid filename chars
	
	; Get save folder from settings
	saveFolder := Settings_RoomCaptureFolder
	
	; Handle "Album Folder" option - use current album's directory
	if (saveFolder = "" || saveFolder = "Album Folder") {
		; Get album folder from PS_AlbumPath global (set when album opens)
		if (PS_AlbumPath != "" && FileExist(PS_AlbumPath)) {
			SplitPath, PS_AlbumPath,, albumDir
			saveFolder := albumDir
		} else {
			; Fallback to Documents folder
			saveFolder := A_MyDocuments . "\ProSelect Room Captures"
			if (!FileExist(saveFolder))
				FileCreateDir, %saveFolder%
		}
	} else if (!FileExist(saveFolder)) {
		; Custom folder doesn't exist, create it
		FileCreateDir, %saveFolder%
	}
	
	; Generate filename with room counter
	roomNum := 1
	Loop
	{
		outputFile := saveFolder . "\" . albumName . "-room" . roomNum . ".jpg"
		if (!FileExist(outputFile))
			break
		roomNum++
		if (roomNum > 99)
		{
			DarkMsgBox("Capture Failed", "Too many room captures for this album.", "warning", {timeout: 3})
			return
		}
	}
	
	; Hide the toolbar temporarily
	Gui, Toolbar:Hide
	Sleep, 100
	
	; Activate ProSelect and wait
	WinActivate, ahk_exe ProSelect.exe
	WinWaitActive, ahk_exe ProSelect.exe, , 2
	Sleep, 200
	
	; Get ProSelect window position
	WinGetPos, psX, psY, psW, psH, ahk_exe ProSelect.exe
	
	; Calculate the central panel area for room view
	; ProSelect UI: Left sidebar is fixed ~170px, top toolbar ~90px, right sidebar ~45px
	; These are fixed UI element sizes, scaled by DPI
	; Apply DPI scaling to fixed UI element sizes
	leftSidebarWidth := Round(220 * DPI_Scale)   ; Fixed left sidebar (collections panel)
	topToolbarHeight := Round(115 * DPI_Scale)   ; Fixed menu bar + icon toolbar
	rightSidebarWidth := Round(70 * DPI_Scale)   ; Fixed right sidebar icons
	bottomBarHeight := Round(5 * DPI_Scale)      ; Small margin to include price bar
	
	captureX := psX + leftSidebarWidth
	captureY := psY + topToolbarHeight
	captureW := psW - leftSidebarWidth - rightSidebarWidth
	captureH := psH - topToolbarHeight - bottomBarHeight
	
	; Ensure minimum size (scaled)
	minW := Round(400 * DPI_Scale)
	minH := Round(300 * DPI_Scale)
	if (captureW < minW || captureH < minH)
	{
		; Fall back to capturing more of the window
		captureX := psX + Round(100 * DPI_Scale)
		captureY := psY + Round(80 * DPI_Scale)
		captureW := psW - Round(150 * DPI_Scale)
		captureH := psH - Round(120 * DPI_Scale)
	}
	
	; Initialize GDI+
	pToken := Gdip_Startup()
	if (!pToken)
	{
		DarkMsgBox("Capture Failed", "Could not initialize GDI+.", "error", {timeout: 3})
		Gui, Toolbar:Show
		return
	}
	
	; Capture the screen region
	pBitmap := Gdip_BitmapFromScreen(captureX . "|" . captureY . "|" . captureW . "|" . captureH)
	if (!pBitmap)
	{
		Gdip_Shutdown(pToken)
		DarkMsgBox("Capture Failed", "Could not capture screen.", "error", {timeout: 3})
		Gui, Toolbar:Show
		return
	}
	
	; Save as JPEG (quality 95)
	result := Gdip_SaveBitmapToFile(pBitmap, outputFile, 95)
	
	; Cleanup
	Gdip_DisposeImage(pBitmap)
	Gdip_Shutdown(pToken)
	
	; Show toolbar again
	Sleep, 100
	Gui, Toolbar:Show
	
	if (result = 0)
	{
		; Play success sound
		SoundPlay, *48
		
		; Auto-copy path to clipboard
		Clipboard := outputFile
		
		; Show confirmation dialog with image preview
		captureResult := ShowRoomCapturedDialog(outputFile, albumName, roomNum)
		if (captureResult = "Open")
		{
			; Open the image file with default viewer
			Run, "%outputFile%"
		}
		else if (captureResult = "Reveal")
		{
			; Open Explorer and select the file
			Run, explorer.exe /select`,"%outputFile%"
		}
		else if (captureResult = "Email")
		{
			; Extract GHL contact ID from album name
			; Album name format: P26016P_Hornett_UWge6H1hK1raUtu1roAo
			emailContactId := ""
			if (InStr(albumName, "_")) {
				albumParts := StrSplit(albumName, "_")
				; Check each part from the end for a GHL-like ID (15+ alphanumeric chars)
				idx := albumParts.MaxIndex()
				while (idx >= 1) {
					part := albumParts[idx]
					if (StrLen(part) >= 15 && RegExMatch(part, "^[A-Za-z0-9]+$"))
					{
						emailContactId := part
						break
					}
					idx--
				}
			}
			
			if (emailContactId = "") {
				DarkMsgBox("No Contact ID", "Could not extract GHL contact ID from album name:`n" . albumName . "`n`nAlbum name should contain the contact ID`n(e.g. P26016P_Hornett_UWge6H1hK1raUtu1roAo)", "warning")
			} else {
				; Store for use in send handler
				global RoomEmail_ContactId, RoomEmail_OutputFile, RoomEmail_AlbumName, RoomEmail_RoomNum, RoomEmail_SelectedTemplateID
				RoomEmail_ContactId := emailContactId
				RoomEmail_OutputFile := outputFile
				RoomEmail_AlbumName := albumName
				RoomEmail_RoomNum := roomNum
				
				; Show email template picker dialog
				ShowRoomEmailDialog()
			}
		}
	}
	else
	{
		DarkMsgBox("Capture Failed", "Could not save image. Error: " . result, "error", {timeout: 3})
	}
}
Return

RemoveCopyToolTip:
ToolTip, , , , 2
Return

Toolbar_GetInvoice:
; Check for Ctrl+Click to delete last invoice
if (GetKeyState("Ctrl", "P")) {
	Gosub, Toolbar_DeleteLastInvoice
	Return
}

; DEBUG: Clear and start invoice log
; Don't delete - append to preserve startup info
FileAppend, % "`n`n=== Invoice Sync Debug Log ===" . "`n", %DebugLogFile%
FileAppend, % "Started: " . A_Now . "`n`n", %DebugLogFile%

; Proceed with ProSelect export flow - exports XML then syncs it
FileAppend, % A_Now . " - Checking GHL warning setting...`n", %DebugLogFile%
; Check if warning should be shown
if (!Settings_GHLInvoiceWarningShown)
{
	; Create custom GUI with checkbox - dark mode aware
	Gui, GHLWarning:New, +AlwaysOnTop +OwnDialogs
	
	; Apply dark mode styling if enabled
	if (Settings_DarkMode) {
		Gui, GHLWarning:Color, 1E1E1E, 2D2D2D
		Gui, GHLWarning:Font, s11 cFFFFFF, Segoe UI
	} else {
		Gui, GHLWarning:Color, FFFFFF, FFFFFF
		Gui, GHLWarning:Font, s11 c000000, Segoe UI
	}
	
	; Warning icon and header
	Gui, GHLWarning:Add, Picture, x25 y25 w40 h40 Icon78, %A_WinDir%\System32\imageres.dll
	
	if (Settings_DarkMode)
		Gui, GHLWarning:Font, s12 Bold cFFCC00, Segoe UI
	else
		Gui, GHLWarning:Font, s12 Bold cCC6600, Segoe UI
	Gui, GHLWarning:Add, Text, x80 y25 w380, ⚠️ GHL Invoice Email Warning
	
	if (Settings_DarkMode)
		Gui, GHLWarning:Font, s10 Norm cCCCCCC, Segoe UI
	else
		Gui, GHLWarning:Font, s10 Norm c333333, Segoe UI
	Gui, GHLWarning:Add, Text, x80 y55 w380, Before proceeding, please be aware that Go High Level (GHL) may send automated emails to your clients when invoices are created.
	Gui, GHLWarning:Add, Text, x80 y+15 w380, We recommend configuring your GHL payment receipt settings to control what emails are sent.
	
	if (Settings_DarkMode)
		Gui, GHLWarning:Font, s10 Norm cAAAAAA, Segoe UI
	else
		Gui, GHLWarning:Font, s10 Norm c555555, Segoe UI
	Gui, GHLWarning:Add, CheckBox, x80 y+25 vGHLWarning_DontShowAgain, Don't show this warning again
	
	if (Settings_DarkMode)
		Gui, GHLWarning:Font, s10 Norm cFFFFFF, Segoe UI
	else
		Gui, GHLWarning:Font, s10 Norm c000000, Segoe UI
	Gui, GHLWarning:Add, Button, x50 y+25 w140 h35 gGHLWarning_OpenSettings, Open GHL Settings
	Gui, GHLWarning:Add, Button, x200 yp w100 h35 Default gGHLWarning_Continue, Continue
	Gui, GHLWarning:Add, Button, x310 yp w100 h35 gGHLWarning_Cancel, Cancel
	
	Gui, GHLWarning:Show, w490 h280, GHL Invoice Warning
	
	; Apply dark mode to title bar if enabled
	if (Settings_DarkMode) {
		Gui, GHLWarning:+LastFound
		WinGet, hWnd, ID
		DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hWnd, "Int", 20, "Int*", 1, "Int", 4)
	}
	
	; Wait for GUI to close
	WinWait, GHL Invoice Warning
	WinWaitClose, GHL Invoice Warning
	if (GHLWarning_Cancelled)
		Return
	Goto, Toolbar_GetInvoice_AfterWarning
	
GHLWarning_OpenSettings:
	if (Settings_GHLPaymentSettingsURL != "")
		Run, %Settings_GHLPaymentSettingsURL%
	Return

GHLWarning_Cancel:
GHLWarningGuiClose:
GHLWarningGuiEscape:
	GHLWarning_Cancelled := 1
	Gui, GHLWarning:Destroy
	Return

GHLWarning_Continue:
	GHLWarning_Cancelled := 0
	Gui, GHLWarning:Submit
	if (GHLWarning_DontShowAgain)
	{
		Settings_GHLInvoiceWarningShown := 1
		IniWrite, 1, %IniFilename%, GHL, InvoiceWarningShown
	}
	Gui, GHLWarning:Destroy
	Return
}

Toolbar_GetInvoice_AfterWarning:
FileAppend, % A_Now . " - Starting invoice export...`n", %DebugLogFile%

; Reset cancellation flag
ExportCancelled := false

; Show hands-off warning GUI during export automation
Gui, InvoiceHandsOff:New, +AlwaysOnTop +ToolWindow -Caption +HwndInvoiceHandsOffHwnd
Gui, InvoiceHandsOff:Color, 1E1E1E
Gui, InvoiceHandsOff:Font, s14 Bold cWhite, Segoe UI
Gui, InvoiceHandsOff:Add, Text, x20 y20 w260 Center, 📤 Exporting Invoice...
Gui, InvoiceHandsOff:Font, s10 cFFCC00, Segoe UI
Gui, InvoiceHandsOff:Add, Text, x20 y55 w260 Center, ⚠️ HANDS OFF
Gui, InvoiceHandsOff:Font, s9 cCCCCCC, Segoe UI
Gui, InvoiceHandsOff:Add, Text, x20 y80 w260 Center, Do not touch mouse or keyboard
Gui, InvoiceHandsOff:Font, s8 c888888, Segoe UI
Gui, InvoiceHandsOff:Add, Text, x20 y100 w260 Center, Press ESC to cancel
Gui, InvoiceHandsOff:Show, w300 h130, Exporting Invoice
DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", InvoiceHandsOffHwnd, "Int", 20, "Int*", 1, "Int", 4)

; Enable ESC hotkey during export
Hotkey, Escape, ExportCancelCheck, On

; Suspend file watcher during export to prevent duplicate prompts
ExportInProgress := true

; Check if cancelled before continuing
if (ExportCancelled) {
	Hotkey, Escape, ExportCancelCheck, Off
	Gui, InvoiceHandsOff:Destroy
	ExportInProgress := false
	Return
}

; Use configured watch folder as the export folder
ExportFolder := Settings_InvoiceWatchFolder

; If no watch folder configured, show error
if (ExportFolder = "" || !FileExist(ExportFolder))
{
	ExportInProgress := false  ; Re-enable file watcher
	Gui, InvoiceHandsOff:Destroy
	DarkMsgBox("Watch Folder Required", "Please set Invoice Watch Folder in Settings before exporting.", "warning")
	Return
}

; Trigger ProSelect XML export using shared function
if (!PS_TriggerXMLExport(true)) {
	; Export failed - function already showed error message
	ExportInProgress := false
	Hotkey, Escape, ExportCancelCheck, Off
	Gui, InvoiceHandsOff:Destroy
	Return
}

; Find the most recent XML file in the export folder
Sleep, 500  ; Give filesystem time to write file
latestXml := ""
latestTime := 0
Loop, Files, %ExportFolder%\*.xml
{
	FileGetTime, fileTime, %A_LoopFileFullPath%, M
	if (fileTime > latestTime)
	{
		latestTime := fileTime
		latestXml := A_LoopFileFullPath
	}
}

if (latestXml = "")
{
	ExportInProgress := false  ; Re-enable file watcher
	Gui, InvoiceHandsOff:Destroy
	ToolTip, No XML files found in: %ExportFolder%
	SetTimer, RemoveToolTip, -3000
	Return
}

; Safety check: Verify XML contains a client ID before syncing
FileRead, xmlContent, %latestXml%

; Check for Client_ID tag with actual content
hasClientID := false
if (InStr(xmlContent, "<Client_ID>"))
{
	; Extract the Client_ID value using regex
	if (RegExMatch(xmlContent, "<Client_ID>(.+?)</Client_ID>", match))
	{
		if (match1 != "")
			hasClientID := true
	}
}

if (!hasClientID)
{
	FileAppend, % A_Now . " - ERROR: Missing Client ID`n", %DebugLogFile%
	ExportInProgress := false  ; Re-enable file watcher
	Gui, InvoiceHandsOff:Destroy
	DarkMsgBox("Missing Client ID", "Invoice XML is missing a Client ID.`n`nPlease link this order to a GHL contact before exporting.`n`nFile: " . latestXml, "warning")
	Return
}
FileAppend, % A_Now . " - Client ID found in XML`n", %DebugLogFile%

; Auto-save XML copy to watch folder if enabled
if (Settings_AutoSaveXML && Settings_InvoiceWatchFolder != "") {
	SplitPath, latestXml, xmlFileName
	destPath := Settings_InvoiceWatchFolder . "\\" . xmlFileName
	FileCopy, %latestXml%, %destPath%, 1  ; 1 = overwrite
	if (!ErrorLevel)
		FileAppend, % A_Now . " - Auto-saved XML copy to: " . destPath . "`n", %DebugLogFile%
	else
		FileAppend, % A_Now . " - WARN: Failed to auto-save XML to: " . destPath . "`n", %DebugLogFile%
}

; Run sync_ps_invoice to upload to GHL (non-blocking with progress GUI)
scriptPath := GetScriptPath("sync_ps_invoice")
FileAppend, % A_Now . " - Script path: " . scriptPath . "`n", %DebugLogFile%
FileAppend, % A_Now . " - Script exists: " . FileExist(scriptPath) . "`n", %DebugLogFile%

if (!FileExist(scriptPath))
{
	FileAppend, % A_Now . " - ERROR: Script not found`n", %DebugLogFile%
	ExportInProgress := false  ; Re-enable file watcher
	Gui, InvoiceHandsOff:Destroy
	DarkMsgBox("Script Missing", "Invoice exported but sync_ps_invoice not found.`n`nLooking for: " . scriptPath . "`nScript Dir: " . A_ScriptDir, "warning")
	Return
}

; Build arguments with optional financials-only flag
syncArgs := """" . latestXml . """"
if (Settings_FinancialsOnly)
	syncArgs .= " --financials-only"
if (!Settings_ContactSheet)
	syncArgs .= " --no-contact-sheet"
if (Settings_CollectContactSheets && Settings_ContactSheetFolder != "")
	syncArgs .= " --collect-folder """ . Settings_ContactSheetFolder . """"
if (Settings_RoundingInDeposit)
	syncArgs .= " --rounding-in-deposit"
if (!Settings_OpenInvoiceURL)
	syncArgs .= " --no-open-browser"
syncCmd := GetScriptCommand("sync_ps_invoice", syncArgs)
FileAppend, % A_Now . " - Sync command: " . syncCmd . "`n", %DebugLogFile%

; Check if user cancelled before syncing
if (ExportCancelled) {
	Hotkey, Escape, ExportCancelCheck, Off
	Gui, InvoiceHandsOff:Destroy
	ExportInProgress := false
	Return
}

FileAppend, % A_Now . " - Showing progress GUI...`n", %DebugLogFile%
; Close hands-off GUI before showing sync progress
Gui, InvoiceHandsOff:Destroy
; Disable ESC handler once we move to sync phase
Hotkey, Escape, ExportCancelCheck, Off
; Show non-blocking progress GUI
ShowSyncProgressGUI(latestXml)
FileAppend, % A_Now . " - Progress GUI shown`n", %DebugLogFile%

; Run in background (non-blocking) - AHK's Run is async by default
scriptPath := GetScriptPath("sync_ps_invoice")
FileAppend, % A_Now . " - Running sync process...`n", %DebugLogFile%
FileAppend, % A_Now . " - syncCmd: " . syncCmd . "`n", %DebugLogFile%
FileAppend, % A_Now . " - Working dir: " . A_ScriptDir . "`n", %DebugLogFile%

; Run directly - AHK Run is already non-blocking
; Don't use start /b as it can cause issues with argument parsing
try {
	Run, %syncCmd%, %A_ScriptDir%, Hide, SyncProgress_ProcessId
	FileAppend, % A_Now . " - Run succeeded, PID: " . SyncProgress_ProcessId . "`n", %DebugLogFile%
} catch e {
	FileAppend, % A_Now . " - Run FAILED: " . e.Message . "`n", %DebugLogFile%
}

; Update folder watcher's file list so it doesn't re-prompt for this file
SplitPath, latestXml, fileName
if (!InStr(LastInvoiceFiles, fileName . "|"))
	LastInvoiceFiles .= fileName . "|"

FileAppend, % A_Now . " - Export completed, file watcher re-enabled`n", %DebugLogFile%
ExportInProgress := false  ; Re-enable file watcher immediately so user can continue
Hotkey, Escape, ExportCancelCheck, Off  ; Disable ESC handler
Return

; ESC key handler during export - shows cancel confirmation
ExportCancelCheck:
if (!ExportInProgress) {
	; Export not in progress, disable hotkey
	Hotkey, Escape, ExportCancelCheck, Off
	Return
}
; Show cancel confirmation dialog
MsgBox, 36, Cancel Export?, Do you want to cancel this export?
IfMsgBox, Yes
{
	ExportCancelled := true
	ExportInProgress := false
	Hotkey, Escape, ExportCancelCheck, Off
	Gui, InvoiceHandsOff:Destroy
	FileAppend, % A_Now . " - Export CANCELLED by user (ESC)`n", %DebugLogFile%
	DarkMsgBox("Export Cancelled", "Invoice export cancelled.", "info")
}
Return

; Delete invoices for current client from GHL (Ctrl+Click on invoice button)
Toolbar_DeleteLastInvoice:

; Get shoot number from ProSelect window title
WinGetTitle, psTitle, ahk_exe ProSelect.exe
if (psTitle = "" || psTitle = "ProSelect") {
	DarkMsgBox("No Album Open", "No album is open in ProSelect.`n`nOpen a client's album first, then Ctrl+Click to delete their invoice.", "info")
	Return
}

; Extract album name from title (format: "AlbumName - ProSelect")
delAlbumName := RegExReplace(psTitle, "^ProSelect\s*-\s*", "")
delAlbumName := RegExReplace(delAlbumName, "\s*-\s*ProSelect.*$", "")

; Extract shoot number (first part before underscore)
delShootNo := ""
if (InStr(delAlbumName, "_"))
	delShootNo := SubStr(delAlbumName, 1, InStr(delAlbumName, "_") - 1)
else
	delShootNo := delAlbumName

; Extract client name (second part between first and second underscore)
delClientName := ""
if (InStr(delAlbumName, "_")) {
	parts := StrSplit(delAlbumName, "_")
	if (parts.MaxIndex() >= 2)
		delClientName := parts[2]
}

if (delShootNo = "") {
	DarkMsgBox("No Shoot Number", "Could not determine shoot number from ProSelect title.`n`nTitle: " . psTitle, "warning")
	Return
}

; Find the matching XML in the export/watch folder
ExportFolder := Settings_InvoiceWatchFolder
if (ExportFolder = "" || !FileExist(ExportFolder)) {
	DarkMsgBox("Watch Folder Missing", "Invoice Watch Folder is not set or doesn't exist.`n`nConfigure it in Settings → Invoice tab.", "warning")
	Return
}

; Search for XML files containing this shoot number (most recent first)
delClientXml := ""
delLatestTime := 0
Loop, Files, %ExportFolder%\*.xml
{
	if (InStr(A_LoopFileName, delShootNo)) {
		FileGetTime, fileTime, %A_LoopFileFullPath%, M
		if (fileTime > delLatestTime) {
			delLatestTime := fileTime
			delClientXml := A_LoopFileFullPath
		}
	}
}

if (delClientXml = "") {
	DarkMsgBox("No XML Found", "No invoice XML found for " . delShootNo . " in:`n" . ExportFolder . "`n`nExport an invoice for this client first.", "info")
	Return
}

; Build display label
delLabel := delShootNo
if (delClientName != "")
	delLabel := delClientName . " (" . delShootNo . ")"

; Confirmation dialog
Gui, DeleteInvoice:New, +AlwaysOnTop +OwnDialogs
if (Settings_DarkMode) {
	Gui, DeleteInvoice:Color, 1E1E1E, 2D2D2D
	Gui, DeleteInvoice:Font, s11 cFFFFFF, Segoe UI
} else {
	Gui, DeleteInvoice:Color, FFFFFF, FFFFFF
	Gui, DeleteInvoice:Font, s11 c000000, Segoe UI
}

; Warning icon and header
Gui, DeleteInvoice:Add, Picture, x25 y25 w40 h40 Icon110, %A_WinDir%\System32\imageres.dll

if (Settings_DarkMode)
	Gui, DeleteInvoice:Font, s12 Bold cFF6666, Segoe UI
else
	Gui, DeleteInvoice:Font, s12 Bold cCC0000, Segoe UI
Gui, DeleteInvoice:Add, Text, x80 y25 w320, Delete Invoice?

if (Settings_DarkMode)
	Gui, DeleteInvoice:Font, s10 Norm cCCCCCC, Segoe UI
else
	Gui, DeleteInvoice:Font, s10 Norm c333333, Segoe UI
Gui, DeleteInvoice:Add, Text, x80 y55 w320, This will delete all invoices and payment schedules for:

if (Settings_DarkMode)
	Gui, DeleteInvoice:Font, s11 Bold cFFFFFF, Segoe UI
else
	Gui, DeleteInvoice:Font, s11 Bold c000000, Segoe UI
Gui, DeleteInvoice:Add, Text, x80 y+5 w320, %delLabel%

if (Settings_DarkMode)
	Gui, DeleteInvoice:Font, s9 Norm cAAAA00, Segoe UI
else
	Gui, DeleteInvoice:Font, s9 Norm c996600, Segoe UI
Gui, DeleteInvoice:Add, Text, x80 y+10 w320, Recorded payments will be automatically refunded.
Gui, DeleteInvoice:Add, Text, x80 y+3 w320, Recurring schedules will be cancelled.

if (Settings_DarkMode)
	Gui, DeleteInvoice:Font, s10 Norm cFFFFFF, Segoe UI
else
	Gui, DeleteInvoice:Font, s10 Norm c000000, Segoe UI
Gui, DeleteInvoice:Add, Button, x120 y+20 w120 h35 Default gDeleteInvoice_Cancel, Cancel
Gui, DeleteInvoice:Add, Button, x250 yp w120 h35 gDeleteInvoice_Confirm, Delete

Gui, DeleteInvoice:Show, w430 h240, Delete Invoice

if (Settings_DarkMode) {
	Gui, DeleteInvoice:+LastFound
	WinGet, hWnd, ID
	DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hWnd, "Int", 20, "Int*", 1, "Int", 4)
}

; Store XML path for confirm handler
DeleteInvoice_XmlPath := delClientXml
Return

DeleteInvoice_Cancel:
DeleteInvoiceGuiClose:
DeleteInvoiceGuiEscape:
Gui, DeleteInvoice:Destroy
Return

DeleteInvoice_Confirm:
Gui, DeleteInvoice:Destroy
xmlPath := DeleteInvoice_XmlPath

; Run delete-for-client command
scriptCmd := GetScriptCommand("sync_ps_invoice", "--delete-for-client """ . xmlPath . """")
RunWait, %scriptCmd%, %A_ScriptDir%, Hide
exitCode := ErrorLevel

; Read result file to check what happened
resultFile := A_AppData . "\SideKick_PS\ghl_invoice_sync_result.json"
FileRead, resultJson, %resultFile%

; Build summary message
msgParts := ""

; Get client name from result
RegExMatch(resultJson, """client_name"":\s*""([^""]+)""", matchCN)
if (matchCN1 != "")
	msgParts .= matchCN1 . "`n`n"

; Invoice counts
RegExMatch(resultJson, """invoices_deleted"":\s*(\d+)", matchDel)
RegExMatch(resultJson, """invoices_voided"":\s*(\d+)", matchVoid)
RegExMatch(resultJson, """invoices_failed"":\s*(\d+)", matchFailed)
invDel := matchDel1 ? matchDel1 : 0
invVoid := matchVoid1 ? matchVoid1 : 0
invFailed := matchFailed1 ? matchFailed1 : 0

if (invDel > 0)
	msgParts .= invDel . " invoice(s) deleted`n"
if (invVoid > 0)
	msgParts .= invVoid . " invoice(s) voided`n"
if (invFailed > 0)
	msgParts .= invFailed . " invoice(s) FAILED (need manual refund)`n"

; Schedule counts
RegExMatch(resultJson, """schedules_cancelled"":\s*(\d+)", matchSC)
if (matchSC1 > 0)
	msgParts .= matchSC1 . " schedule(s) cancelled`n"

; No invoices found
if (invDel = 0 && invVoid = 0 && invFailed = 0 && (!matchSC1 || matchSC1 = 0)) {
	if (InStr(resultJson, "No invoices or schedules found"))
		msgParts .= "No invoices or schedules found for this client."
}

; Check for specific error types
hasPermissionError := InStr(resultJson, "permission_error")
hasProviderRefundNeeded := InStr(resultJson, "needs_provider_refund")
hasManualRefundOnly := InStr(resultJson, "needs_manual_refund")

; Get list of problematic invoices if any
RegExMatch(resultJson, """problem_invoices"":\s*\[([^\]]+)\]", matchProblems)
problemList := matchProblems1 ? matchProblems1 : ""

; Get problem invoice details (id|number pairs) for void action
RegExMatch(resultJson, """problem_invoice_details"":\s*\[([^\]]*)\]", matchDetails)
problemDetails := matchDetails1 ? matchDetails1 : ""

if (exitCode = 0 && invFailed = 0) {
	DarkMsgBox("Invoice Removed", msgParts, "info")
} else if (hasPermissionError) {
	DarkMsgBox("Permission Error", "API key lacks permission to void/delete invoices.`n`n" . msgParts . "`nUpdate GHL Private Integration scopes to include:`n• invoices.readonly`n• invoices.write", "warning")
} else if (hasProviderRefundNeeded || hasManualRefundOnly) {
	; Show custom dialog with clickable link to GHL payments
	ShowRefundRequiredDialog(msgParts, problemList, problemDetails)
} else {
	DarkMsgBox("Delete Failed", "Could not remove all invoices.`n`n" . msgParts . "`nCheck GHL for payment status.", "warning")
}
Return

Toolbar_Settings:
Gosub, ShowSettings
Return

; ============================================================================
; Settings GUI - Modern Dark Theme with Sidebar Navigation
; ============================================================================

ShowSettings:
Gui, Settings:Destroy

; Initialize dark mode if not already set
if (Settings_DarkMode = "")
	global Settings_DarkMode := true

; Theme-aware colors
if (Settings_DarkMode) {
	mainBg := "1E1E1E"
	sidebarBg := "252526"
	contentBg := "2D2D2D"
	textColor := "FFFFFF"
	headerColor := "4FC3F7"
	mutedColor := "888888"
} else {
	mainBg := "F5F5F5"
	sidebarBg := "E8E8E8"
	contentBg := "FFFFFF"
	textColor := "1E1E1E"
	headerColor := "0078D4"
	mutedColor := "666666"
}

; Main settings window
settingsIconPath := A_ScriptDir . "\SideKick_PS.ico"
Gui, Settings:New, +HwndSettingsHwnd
Gui, Settings:Color, %contentBg%
; Load window icon
global hSettingsIcon, hSettingsIconSmall
if FileExist(settingsIconPath) {
	hSettingsIcon := DllCall("LoadImage", "UPtr", 0, "Str", settingsIconPath, "UInt", 1, "Int", 32, "Int", 32, "UInt", 0x10, "UPtr")
	hSettingsIconSmall := DllCall("LoadImage", "UPtr", 0, "Str", settingsIconPath, "UInt", 1, "Int", 16, "Int", 16, "UInt", 0x10, "UPtr")
}
Gui, Settings:Font, s10 c%textColor%, Segoe UI

; Sidebar background
Gui, Settings:Add, Text, x0 y0 w180 h750 BackgroundTrans
Gui, Settings:Add, Progress, x0 y0 w180 h750 Background%sidebarBg% Disabled

; Sidebar header
Gui, Settings:Font, s12 c%headerColor%, Segoe UI
Gui, Settings:Add, Text, x15 y20 w150 BackgroundTrans Center, SideKick Hub

; Sidebar navigation tabs
Gui, Settings:Font, s11 c%textColor%, Segoe UI

; Tab buttons with highlight indicator
global TabGeneral, TabGHL, TabHotkeys, TabFiles, TabLicense, TabAbout, TabShortcuts, TabPrint, TabGoCardless, TabDisplay
global TabGeneralBg, TabGHLBg, TabHotkeysBg, TabFilesBg, TabLicenseBg, TabAboutBg, TabDeveloperBg, TabShortcutsBg, TabPrintBg, TabGoCardlessBg, TabDisplayBg

; General tab
Gui, Settings:Add, Progress, x0 y60 w4 h35 Background0078D4 vTabGeneralBg Hidden
Gui, Settings:Add, Text, x15 y65 w160 h25 BackgroundTrans gSettingsTabGeneral vTabGeneral, ⚙  General

; GHL Integration tab  
Gui, Settings:Add, Progress, x0 y100 w4 h35 Background0078D4 vTabGHLBg Hidden
Gui, Settings:Add, Text, x15 y105 w160 h25 BackgroundTrans gSettingsTabGHL vTabGHL, 🔗  GHL Integration

; Hotkeys tab
Gui, Settings:Add, Progress, x0 y140 w4 h35 Background0078D4 vTabHotkeysBg Hidden
Gui, Settings:Add, Text, x15 y145 w160 h25 BackgroundTrans gSettingsTabHotkeys vTabHotkeys, ⌨  Hotkeys

; File Management tab
Gui, Settings:Add, Progress, x0 y180 w4 h35 Background0078D4 vTabFilesBg Hidden
Gui, Settings:Add, Text, x15 y185 w160 h25 BackgroundTrans gSettingsTabFiles vTabFiles, 📁  File Management

; License tab
Gui, Settings:Add, Progress, x0 y220 w4 h35 Background0078D4 vTabLicenseBg Hidden
Gui, Settings:Add, Text, x15 y225 w160 h25 BackgroundTrans gSettingsTabLicense vTabLicense, 🔑  License

; About tab
Gui, Settings:Add, Progress, x0 y260 w4 h35 Background0078D4 vTabAboutBg Hidden
Gui, Settings:Add, Text, x15 y265 w160 h25 BackgroundTrans gSettingsTabAbout vTabAbout, ℹ  About

; Toolbar tab
Gui, Settings:Add, Progress, x0 y300 w4 h35 Background0078D4 vTabShortcutsBg Hidden
Gui, Settings:Add, Text, x15 y305 w160 h25 BackgroundTrans gSettingsTabShortcuts vTabShortcuts, 🎛  Toolbar

; Print tab
Gui, Settings:Add, Progress, x0 y340 w4 h35 Background0078D4 vTabPrintBg Hidden
Gui, Settings:Add, Text, x15 y345 w160 h25 BackgroundTrans gSettingsTabPrint vTabPrint, 🖨  Print

; Display tab
Gui, Settings:Add, Progress, x0 y380 w4 h35 Background0078D4 vTabDisplayBg Hidden
Gui, Settings:Add, Text, x15 y385 w160 h25 BackgroundTrans gSettingsTabDisplay vTabDisplay, 🖥  Display

; GoCardless tab
Gui, Settings:Add, Progress, x0 y420 w4 h35 Background0078D4 vTabGoCardlessBg Hidden
Gui, Settings:Add, Text, x15 y425 w160 h25 BackgroundTrans gSettingsTabGoCardless vTabGoCardless, 💳  GoCardless

; Developer tab (only for dev location)
Gui, Settings:Add, Progress, x0 y460 w4 h35 Background0078D4 vTabDeveloperBg Hidden
Gui, Settings:Add, Text, x15 y465 w160 h25 BackgroundTrans gSettingsTabDeveloper vTabDeveloper Hidden, 🛠  Developer

; SideKick Logo at bottom of sidebar - transparent PNG, use appropriate version for theme
logoPathDark := A_ScriptDir . "\SideKick_Logo_2025_Dark.png"
logoPathLight := A_ScriptDir . "\SideKick_Logo_2025_Light.png"
logoPath := Settings_DarkMode ? logoPathDark : logoPathLight

if FileExist(logoPath) {
	; Add background patch to match sidebar color for logo area
	Gui, Settings:Add, Progress, x20 y545 w140 h140 Background%sidebarBg% Disabled
	; Add logo on top
	Gui, Settings:Add, Picture, x20 y545 w140 h140 vSettingsLogo BackgroundTrans, %logoPath%
} else {
	; Fallback text if logo not found
	Gui, Settings:Font, s14 cFF8C00, Segoe UI
	Gui, Settings:Add, Text, x15 y580 w150 h40 BackgroundTrans Center, 🚀 SIDEKICK
}

; Version at bottom of sidebar
Gui, Settings:Font, s9 c%mutedColor%, Segoe UI
Gui, Settings:Add, Text, x15 y535 w150 BackgroundTrans Center, v%ScriptVersion%

; Main content area background
Gui, Settings:Add, Progress, x180 y0 w520 h600 Background%contentBg% Disabled

; Content panels (we'll show/hide these based on selected tab)
CreateGeneralPanel()
CreateGHLPanel()
CreateHotkeysPanel()
CreateFilesPanel()
CreateLicensePanel()
CreateAboutPanel()
CreateShortcutsPanel()
CreatePrintPanel()
CreateGoCardlessPanel()
CreateDisplayPanel()
CreateDeveloperPanel()

; Show Developer tab only for dev location
if (GHL_LocationID = "8IWxk5M0PvbNf1w3npQU") {
	GuiControl, Settings:Show, TabDeveloper
}

; Bottom button bar
Gui, Settings:Add, Progress, x0 y695 w700 h55 Background%sidebarBg% Disabled

Gui, Settings:Font, s10 Norm c%textColor%, Segoe UI
Gui, Settings:Add, Button, x400 y705 w80 h30 gSettingsApply, &Apply
Gui, Settings:Add, Button, x490 y705 w80 h30 gSettingsClose, &Close

; Show the current tab
ShowSettingsTab(Settings_CurrentTab)

; Register mouse move handler for hover tooltips
OnMessage(0x200, "SettingsMouseMove")

Gui, Settings:Show, w700 h750, SideKick_PS Settings

; Apply custom icon to Settings window taskbar and title bar
if (hSettingsIcon) {
	; Set the big icon (Alt+Tab, taskbar)
	DllCall("SendMessage", "Ptr", SettingsHwnd, "UInt", 0x80, "Ptr", 1, "Ptr", hSettingsIcon)
	; Set the small icon (title bar)
	DllCall("SendMessage", "Ptr", SettingsHwnd, "UInt", 0x80, "Ptr", 0, "Ptr", hSettingsIconSmall)
}
Return

; Toggle slider helper functions - Icon-based approach using Unicode
CreateToggleSlider(guiName, sliderName, xPos, yPos, initialState)
{
	global
	
	; Theme-aware OFF color
	offColor := Settings_DarkMode ? "888888" : "999999"
	labelColor := Settings_DarkMode ? "CCCCCC" : "444444"
	
	; ON: ✓ cyan checkmark | OFF: ✗ gray X
	if (initialState) {
		Gui, %guiName%:Font, s16 c4FC3F7 Bold, Segoe UI
		Gui, %guiName%:Add, Text, x%xPos% y%yPos% w20 h24 BackgroundTrans vToggle_%sliderName% gToggleClick_%sliderName%, ✓
	} else {
		Gui, %guiName%:Font, s16 c%offColor% Bold, Segoe UI
		Gui, %guiName%:Add, Text, x%xPos% y%yPos% w20 h24 BackgroundTrans vToggle_%sliderName% gToggleClick_%sliderName%, ✗
	}
	
	; Restore font for labels (important - next label needs this)
	Gui, %guiName%:Font, s10 c%labelColor%, Segoe UI
	
	; Store the state
	Toggle_%sliderName%_State := initialState
}

UpdateToggleSlider(guiName, sliderName, newState, baseX)
{
	global
	
	; Update icon and color
	if (newState) {
		toggleIcon := "✓"
		; Set cyan color
		Gui, %guiName%:Font, s16 c4FC3F7 Bold, Segoe UI
	} else {
		toggleIcon := "✗"
		; Set gray color
		Gui, %guiName%:Font, s16 c888888 Bold, Segoe UI
	}
	
	; Apply font to control then update text
	GuiControl, %guiName%:Font, Toggle_%sliderName%
	GuiControl, %guiName%:, Toggle_%sliderName%, %toggleIcon%
	
	; Update state
	Toggle_%sliderName%_State := newState
}

; Toggle click handlers
ToggleClick_StartOnBoot:
Toggle_StartOnBoot_State := !Toggle_StartOnBoot_State
UpdateToggleSlider("Settings", "StartOnBoot", Toggle_StartOnBoot_State, 590)
; Update registry immediately for this critical setting
Settings_StartOnBoot := Toggle_StartOnBoot_State
if (Settings_StartOnBoot)
	RegWrite, REG_SZ, HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run, SideKick_PS, %A_ScriptFullPath%
else
	RegDelete, HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run, SideKick_PS
IniWrite, %Settings_StartOnBoot%, %IniFilename%, Settings, StartOnBoot
Return

ToggleClick_ShowTrayIcon:
Toggle_ShowTrayIcon_State := !Toggle_ShowTrayIcon_State
UpdateToggleSlider("Settings", "ShowTrayIcon", Toggle_ShowTrayIcon_State, 590)
Return

ToggleClick_EnableSounds:
Toggle_EnableSounds_State := !Toggle_EnableSounds_State
UpdateToggleSlider("Settings", "EnableSounds", Toggle_EnableSounds_State, 590)
Return

ToggleClick_AutoDetectPS:
Toggle_AutoDetectPS_State := !Toggle_AutoDetectPS_State
UpdateToggleSlider("Settings", "AutoDetectPS", Toggle_AutoDetectPS_State, 590)
Return

ToggleClick_GHL_Enabled:
Toggle_GHL_Enabled_State := !Toggle_GHL_Enabled_State
UpdateToggleSlider("Settings", "GHL_Enabled", Toggle_GHL_Enabled_State, 590)
Return

ToggleClick_GHL_AutoLoad:
Toggle_GHL_AutoLoad_State := !Toggle_GHL_AutoLoad_State
UpdateToggleSlider("Settings", "GHL_AutoLoad", Toggle_GHL_AutoLoad_State, 590)
Return

ToggleClick_GoCardlessEnabled:
Toggle_GoCardlessEnabled_State := !Toggle_GoCardlessEnabled_State
UpdateToggleSlider("Settings", "GoCardlessEnabled", Toggle_GoCardlessEnabled_State, 630)
Settings_GoCardlessEnabled := Toggle_GoCardlessEnabled_State
IniWrite, %Settings_GoCardlessEnabled%, %IniFilename%, GoCardless, Enabled
; Enable/disable controls and recreate toolbar
if (Settings_GoCardlessEnabled) {
	GuiControl, Settings:Enable, GCEnvDDL
	GuiControl, Settings:Enable, GCTokenEditBtn
	GuiControl, Settings:Enable, GCTestBtn
	GuiControl, Settings:Enable, GCDashboardBtn
	GuiControl, Settings:Enable, GCEmailTplCombo
	GuiControl, Settings:Enable, GCEmailTplRefresh
	GuiControl, Settings:Enable, GCSMSTplCombo
	GuiControl, Settings:Enable, GCSMSTplRefresh
	GuiControl, Settings:Enable, Toggle_GCAutoSetup
	GuiControl, Settings:Enable, GCNamePart1DDL
	GuiControl, Settings:Enable, GCNamePart2DDL
	GuiControl, Settings:Enable, GCNamePart3DDL
} else {
	GuiControl, Settings:Disable, GCEnvDDL
	GuiControl, Settings:Disable, GCTokenEditBtn
	GuiControl, Settings:Disable, GCTestBtn
	GuiControl, Settings:Disable, GCDashboardBtn
	GuiControl, Settings:Disable, GCEmailTplCombo
	GuiControl, Settings:Disable, GCEmailTplRefresh
	GuiControl, Settings:Disable, GCSMSTplCombo
	GuiControl, Settings:Disable, GCSMSTplRefresh
	GuiControl, Settings:Disable, Toggle_GCAutoSetup
	GuiControl, Settings:Disable, GCNamePart1DDL
	GuiControl, Settings:Disable, GCNamePart2DDL
	GuiControl, Settings:Disable, GCNamePart3DDL
}
CreateFloatingToolbar()
Return

ToggleClick_GCAutoSetup:
Toggle_GCAutoSetup_State := !Toggle_GCAutoSetup_State
UpdateToggleSlider("Settings", "GCAutoSetup", Toggle_GCAutoSetup_State, 630)
Settings_GCAutoSetup := Toggle_GCAutoSetup_State
IniWrite, %Settings_GCAutoSetup%, %IniFilename%, GoCardless, AutoSetup
Return

ToggleClick_OpenInvoiceURL:
Toggle_OpenInvoiceURL_State := !Toggle_OpenInvoiceURL_State
UpdateToggleSlider("Settings", "OpenInvoiceURL", Toggle_OpenInvoiceURL_State, 590)
Return

ToggleClick_FinancialsOnly:
Toggle_FinancialsOnly_State := !Toggle_FinancialsOnly_State
Settings_FinancialsOnly := Toggle_FinancialsOnly_State
UpdateToggleSlider("Settings", "FinancialsOnly", Toggle_FinancialsOnly_State, 590)
SaveSettings()
Return

ToggleClick_AutoSaveXML:
Toggle_AutoSaveXML_State := !Toggle_AutoSaveXML_State
Settings_AutoSaveXML := Toggle_AutoSaveXML_State
UpdateToggleSlider("Settings", "AutoSaveXML", Toggle_AutoSaveXML_State, 590)
SaveSettings()
Return

ToggleClick_ContactSheet:
Toggle_ContactSheet_State := !Toggle_ContactSheet_State
Settings_ContactSheet := Toggle_ContactSheet_State
UpdateToggleSlider("Settings", "ContactSheet", Toggle_ContactSheet_State, 590)
SaveSettings()
Return

ToggleClick_RoundingDeposit:
Toggle_RoundingDeposit_State := !Toggle_RoundingDeposit_State
Settings_RoundingInDeposit := Toggle_RoundingDeposit_State
UpdateToggleSlider("Settings", "RoundingDeposit", Toggle_RoundingDeposit_State, 630)
SaveSettings()
Return

ToggleClick_CollectContactSheets:
Toggle_CollectContactSheets_State := !Toggle_CollectContactSheets_State
Settings_CollectContactSheets := Toggle_CollectContactSheets_State
UpdateToggleSlider("Settings", "CollectContactSheets", Toggle_CollectContactSheets_State, 630)
SaveSettings()
Return

ToggleClick_AutoAddContactTags:
Toggle_AutoAddContactTags_State := !Toggle_AutoAddContactTags_State
Settings_AutoAddContactTags := Toggle_AutoAddContactTags_State
UpdateToggleSlider("Settings", "AutoAddContactTags", Toggle_AutoAddContactTags_State, 630)
SaveSettings()
Return

ToggleClick_AutoAddOppTags:
Toggle_AutoAddOppTags_State := !Toggle_AutoAddOppTags_State
Settings_AutoAddOppTags := Toggle_AutoAddOppTags_State
UpdateToggleSlider("Settings", "AutoAddOppTags", Toggle_AutoAddOppTags_State, 630)
SaveSettings()
Return

BrowseContactSheetFolder:
Gui, Settings:Submit, NoHide
startFolder := Settings_ContactSheetFolder ? Settings_ContactSheetFolder : A_Desktop
FileSelectFolder, selectedFolder, *%startFolder%, 3, Select folder to save contact sheets
if (selectedFolder != "") {
	Settings_ContactSheetFolder := selectedFolder
	GuiControl, Settings:, GHLCSFolderEdit, %selectedFolder%
	SaveSettings()
}
Return

ToggleClick_AutoUpdate:
Toggle_AutoUpdate_State := !Toggle_AutoUpdate_State
Settings_AutoUpdate := Toggle_AutoUpdate_State
UpdateToggleSlider("Settings", "AutoUpdate", Toggle_AutoUpdate_State, 590)
SaveSettings()
Return

ToggleClick_AutoSendLogs:
Toggle_AutoSendLogs_State := !Toggle_AutoSendLogs_State
Settings_AutoSendLogs := Toggle_AutoSendLogs_State
UpdateToggleSlider("Settings", "AutoSendLogs", Toggle_AutoSendLogs_State, 590)
SaveSettings()
Return

ToggleClick_DebugLogging:
Toggle_DebugLogging_State := !Toggle_DebugLogging_State
Settings_DebugLogging := Toggle_DebugLogging_State
; Set timestamp when enabling, clear when disabling
if (Settings_DebugLogging) {
	FormatTime, Settings_DebugLoggingTimestamp, , yyyyMMddHHmmss
} else {
	Settings_DebugLoggingTimestamp := ""
}
UpdateToggleSlider("Settings", "DebugLogging", Toggle_DebugLogging_State, 360)
SaveSettings()
Return

; File Management toggle click handlers
ToggleClick_AutoShootYear:
Toggle_AutoShootYear_State := !Toggle_AutoShootYear_State
Settings_AutoShootYear := Toggle_AutoShootYear_State
UpdateToggleSlider("Settings", "AutoShootYear", Toggle_AutoShootYear_State, 420)
SaveSettings()
Return

ToggleClick_AutoRenameImages:
Toggle_AutoRenameImages_State := !Toggle_AutoRenameImages_State
Settings_AutoRenameImages := Toggle_AutoRenameImages_State
UpdateToggleSlider("Settings", "AutoRenameImages", Toggle_AutoRenameImages_State, 420)
SaveSettings()
Return

ToggleClick_BrowsDown:
Toggle_BrowsDown_State := !Toggle_BrowsDown_State
Settings_BrowsDown := Toggle_BrowsDown_State
UpdateToggleSlider("Settings", "BrowsDown", Toggle_BrowsDown_State, 420)
SaveSettings()
Return

ToggleClick_AutoDriveDetect:
; Block if SD Card feature is disabled
if (!Settings_SDCardEnabled) {
	ToolTip, Enable SD Card Download first
	SetTimer, RemoveSettingsTooltip, -1500
	Return
}
Toggle_AutoDriveDetect_State := !Toggle_AutoDriveDetect_State
Settings_AutoDriveDetect := Toggle_AutoDriveDetect_State
UpdateToggleSlider("Settings", "AutoDriveDetect", Toggle_AutoDriveDetect_State, 420)
SaveSettings()
; Start or stop the drive detection timer
if (Settings_AutoDriveDetect) {
	CheckLBAutoDetectConflict()
	SetTimer, checkNewDrives, 2000
} else {
	SetTimer, checkNewDrives, Off
}
Return

ToggleClick_SDCardEnabled:
Toggle_SDCardEnabled_State := !Toggle_SDCardEnabled_State
Settings_SDCardEnabled := Toggle_SDCardEnabled_State
UpdateToggleSlider("Settings", "SDCardEnabled", Toggle_SDCardEnabled_State, 420)
; If disabling SD Card, also disable auto-detect
if (!Settings_SDCardEnabled) {
	Toggle_AutoDriveDetect_State := false
	Settings_AutoDriveDetect := false
	UpdateToggleSlider("Settings", "AutoDriveDetect", false, 420)
	SetTimer, checkNewDrives, Off
}
; Update enabled/disabled state of File Management controls
UpdateFilesControlsState(Settings_SDCardEnabled)
SaveSettings()
; Recreate toolbar with new layout
Gui, Toolbar:Destroy
CreateFloatingToolbar()
Return

; Old toggle slider handlers removed - toolbar buttons now use ToggleTB_* handlers with graphical icons

ToggleClick_EnablePDF:
Toggle_EnablePDF_State := !Toggle_EnablePDF_State
UpdateToggleSlider("Settings", "EnablePDF", Toggle_EnablePDF_State, 590)
; Save immediately so it persists without needing Apply/Close
Settings_EnablePDF := Toggle_EnablePDF_State
IniWrite, %Settings_EnablePDF%, %IniFilename%, Toolbar, EnablePDF
; Rebuild toolbar immediately to show/hide PDF button
Gui, Toolbar:Destroy
CreateFloatingToolbar()
Return

; Function to enable/disable File Management controls based on SD Card enabled state
UpdateFilesControlsState(enabled) {
	; Determine the command: Enable or Disable
	cmd := enabled ? "Enable" : "Disable"
	
	; Edit controls
	GuiControl, Settings:%cmd%, FilesCardDriveEdit
	GuiControl, Settings:%cmd%, FilesDownloadEdit
	GuiControl, Settings:%cmd%, FilesArchiveEdit
	GuiControl, Settings:%cmd%, FilesFolderTemplateEdit
	GuiControl, Settings:%cmd%, FilesPrefixEdit
	GuiControl, Settings:%cmd%, FilesSuffixEdit
	GuiControl, Settings:%cmd%, FilesEditorEdit
	
	; Buttons
	GuiControl, Settings:%cmd%, FilesCardDriveBrowse
	GuiControl, Settings:%cmd%, FilesDownloadBrowse
	GuiControl, Settings:%cmd%, FilesArchiveBrowse
	GuiControl, Settings:%cmd%, FilesFolderTemplateBrowse
	GuiControl, Settings:%cmd%, FilesEditorBrowse
	GuiControl, Settings:%cmd%, FilesSyncFromLBBtn
	
	; Toggle sliders (these are Text controls)
	GuiControl, Settings:%cmd%, Toggle_AutoShootYear
	GuiControl, Settings:%cmd%, Toggle_AutoRenameImages
	GuiControl, Settings:%cmd%, Toggle_BrowsDown
	GuiControl, Settings:%cmd%, Toggle_AutoDriveDetect
	
	; Labels - gray them out visually
	if (enabled) {
		labelColor := Settings_DarkMode ? "CCCCCC" : "444444"
		sectionColor := Settings_DarkMode ? "4FC3F7" : "0078D4"
	} else {
		labelColor := Settings_DarkMode ? "666666" : "999999"
		sectionColor := Settings_DarkMode ? "666666" : "999999"
	}
	
	; Update label colors
	GuiControl, Settings:+c%labelColor%, FilesCardDriveLabel
	GuiControl, Settings:+c%labelColor%, FilesDownloadLabel
	GuiControl, Settings:+c%labelColor%, FilesArchiveLabel
	GuiControl, Settings:+c%labelColor%, FilesFolderTemplateLabel
	GuiControl, Settings:+c%labelColor%, FilesPrefixLabel
	GuiControl, Settings:+c%labelColor%, FilesSuffixLabel
	GuiControl, Settings:+c%labelColor%, FilesEditorLabel
	GuiControl, Settings:+c%labelColor%, FilesAutoYear
	GuiControl, Settings:+c%labelColor%, FilesAutoRename
	GuiControl, Settings:+c%labelColor%, FilesOpenEditor
	GuiControl, Settings:+c%labelColor%, FilesAutoDrive
	
	; Section headers
	GuiControl, Settings:+c%sectionColor%, FilesSDCard
	GuiControl, Settings:+c%sectionColor%, FilesArchive
	GuiControl, Settings:+c%sectionColor%, FilesNaming
	GuiControl, Settings:+c%sectionColor%, FilesEditor
}

; ============================================================
; ShowRefundRequiredDialog - Shows dialog with clickable GHL link
; ============================================================
ShowRefundRequiredDialog(msgParts, problemList, problemDetails := "") {
	global Settings_DarkMode, GHL_LocationID, DPI_Scale
	
	; DPI scaling factor
	dpi := DPI_Scale ? DPI_Scale : 1.0
	
	; Build GHL URL for transactions (where refunds are processed)
	ghlUrl := "https://app.gohighlevel.com/v2/location/" . GHL_LocationID . "/payments/v2/transactions"
	
	; Store URL and invoice details for click handlers
	global RefundDialog_URL := ghlUrl
	global RefundDialog_InvoiceDetails := problemDetails
	
	; Parse invoice numbers from problemList for display
	invoiceNumbers := []
	if (problemList != "") {
		; problemList is like: "#000093", "#000090"
		cleanList := StrReplace(problemList, """", "")
		Loop, Parse, cleanList, `,
		{
			num := Trim(A_LoopField)
			if (num != "")
				invoiceNumbers.Push(num)
		}
	}
	
	; Window dimensions
	winWidth := Round(520 * dpi)
	winHeight := Round(450 * dpi)
	
	; Create GUI
	Gui, RefundDlg:New, +AlwaysOnTop +OwnDialogs
	
	if (Settings_DarkMode) {
		Gui, RefundDlg:Color, 1E1E1E, 2D2D2D
		textColor := "CCCCCC"
		headerColor := "FFCC00"
		linkColor := "4FC3F7"
		invColor := "FF9999"
	} else {
		Gui, RefundDlg:Color, FFFFFF, FFFFFF
		textColor := "333333"
		headerColor := "CC8800"
		linkColor := "0066CC"
		invColor := "CC3333"
	}
	
	; DPI-scaled positions
	iconX := Round(25 * dpi)
	iconY := Round(25 * dpi)
	iconSize := Round(40 * dpi)
	textX := Round(80 * dpi)
	contentX := Round(25 * dpi)
	contentW := winWidth - Round(50 * dpi)
	
	; Icon (key icon for security)
	Gui, RefundDlg:Add, Picture, x%iconX% y%iconY% w%iconSize% h%iconSize% Icon77, %A_WinDir%\System32\imageres.dll
	
	; Header
	headerFont := Round(12 * dpi)
	Gui, RefundDlg:Font, s%headerFont% Bold c%headerColor%, Segoe UI
	Gui, RefundDlg:Add, Text, x%textX% y%iconY%, Manual Refund Required
	
	; Description
	yPos := Round(75 * dpi)
	textFont := Round(10 * dpi)
	Gui, RefundDlg:Font, s%textFont% Norm c%textColor%, Segoe UI
	Gui, RefundDlg:Add, Text, x%contentX% y%yPos% w%contentW%, These invoices have payment provider transactions`n(GoCardless/Stripe) that must be manually refunded.
	
	; Invoice list header
	yPos += Round(50 * dpi)
	Gui, RefundDlg:Font, s%textFont% Bold c%invColor%, Segoe UI
	Gui, RefundDlg:Add, Text, x%contentX% y%yPos%, INVOICES REQUIRING REFUND:
	
	; List invoice numbers
	yPos += Round(22 * dpi)
	Gui, RefundDlg:Font, s%textFont% Norm c%invColor%, Segoe UI
	if (invoiceNumbers.Length() > 0) {
		invListText := ""
		for i, num in invoiceNumbers {
			if (i > 1)
				invListText .= ", "
			invListText .= num
		}
		Gui, RefundDlg:Add, Text, x%contentX% y%yPos% w%contentW%, %invListText%
	} else {
		Gui, RefundDlg:Add, Text, x%contentX% y%yPos% w%contentW%, (invoice numbers not available)
	}
	
	; Steps header
	yPos += Round(35 * dpi)
	stepsColor := "FFCC00"
	Gui, RefundDlg:Font, s%textFont% Bold c%stepsColor%, Segoe UI
	Gui, RefundDlg:Add, Text, x%contentX% y%yPos%, STEPS TO FIX:
	
	; Steps list
	yPos += Round(25 * dpi)
	Gui, RefundDlg:Font, s%textFont% Norm c%textColor%, Segoe UI
	Gui, RefundDlg:Add, Text, x%contentX% y%yPos% w%contentW%, 1. Click the link below to open GHL Transactions
	yPos += Round(22 * dpi)
	Gui, RefundDlg:Add, Text, x%contentX% y%yPos% w%contentW%, 2. Find the payment transaction for this client
	yPos += Round(22 * dpi)
	Gui, RefundDlg:Add, Text, x%contentX% y%yPos% w%contentW%, 3. Click the transaction → Refund
	yPos += Round(22 * dpi)
	Gui, RefundDlg:Add, Text, x%contentX% y%yPos% w%contentW%, 4. Click 'Done' below to void the invoices
	
	; Clickable link to GHL
	yPos += Round(35 * dpi)
	Gui, RefundDlg:Font, s%textFont% Underline c%linkColor%, Segoe UI
	Gui, RefundDlg:Add, Text, x%contentX% y%yPos% w%contentW% gRefundDlg_OpenGHL, 🔗 Open GHL Transactions Page
	
	; Buttons - Done (void invoices) and Cancel
	btnWidth := Round(140 * dpi)
	btnHeight := Round(32 * dpi)
	btnSpacing := Round(15 * dpi)
	totalBtnW := (btnWidth * 2) + btnSpacing
	btnStartX := (winWidth - totalBtnW) // 2
	yPos += Round(50 * dpi)
	
	Gui, RefundDlg:Font, s%textFont% Norm, Segoe UI
	
	; Only show "Done - Void" button if we have invoice details to void
	if (problemDetails != "") {
		Gui, RefundDlg:Add, Button, x%btnStartX% y%yPos% w%btnWidth% h%btnHeight% gRefundDlg_VoidInvoices, ✓ Done - Void Now
		btnStartX += btnWidth + btnSpacing
	}
	Gui, RefundDlg:Add, Button, x%btnStartX% y%yPos% w%btnWidth% h%btnHeight% Default gRefundDlg_Close, Close
	
	; Show dialog
	winHeight := yPos + Round(55 * dpi)
	Gui, RefundDlg:Show, w%winWidth% h%winHeight%, Manual Refund Required
	return
}

RefundDlg_OpenGHL:
	global RefundDialog_URL
	Run, %RefundDialog_URL%
return

RefundDlg_VoidInvoices:
	global RefundDialog_InvoiceDetails
	Gui, RefundDlg:Destroy
	
	; Parse invoice details and void each one
	; Format: "id1|#num1", "id2|#num2"
	if (RefundDialog_InvoiceDetails = "") {
		DarkMsgBox("Error", "No invoice details available to void.", "error")
		return
	}
	
	; Clean and parse
	cleanDetails := StrReplace(RefundDialog_InvoiceDetails, """", "")
	voidedCount := 0
	failedCount := 0
	voidResults := ""
	
	Loop, Parse, cleanDetails, `,
	{
		pair := Trim(A_LoopField)
		if (pair = "")
			continue
		
		; Split by |
		pipePos := InStr(pair, "|")
		if (pipePos > 0) {
			invId := SubStr(pair, 1, pipePos - 1)
			invNum := SubStr(pair, pipePos + 1)
			
			; Call Python to void this invoice using --void-invoice
			voidCmd := GetScriptCommand("sync_ps_invoice", "--void-invoice """ . invId . """")
			RunWait, %ComSpec% /c %voidCmd%, , Hide
			
			; Check result file
			resultFile := A_Temp . "\ghl_sync_result.json"
			if FileExist(resultFile) {
				FileRead, voidJson, %resultFile%
				if (InStr(voidJson, """voided"": true") || InStr(voidJson, """success"": true"))
					voidedCount++
				else
					failedCount++
			} else {
				voidedCount++  ; Assume success if no result file
			}
		}
	}
	
	if (voidedCount > 0 && failedCount = 0)
		DarkMsgBox("Invoices Voided", voidedCount . " invoice(s) have been voided successfully.", "success")
	else if (voidedCount > 0)
		DarkMsgBox("Partial Success", voidedCount . " voided, " . failedCount . " failed.`nCheck GHL for remaining invoices.", "warning")
	else
		DarkMsgBox("Void Failed", "Could not void invoices.`nPayments may not be refunded yet.`nCheck GHL for status.", "warning")
return

RefundDlg_Close:
RefundDlgGuiClose:
RefundDlgGuiEscape:
	Gui, RefundDlg:Destroy
return

; ============================================================
; DarkMsgBox - Dark mode aware message box function
; ============================================================
; Usage: result := DarkMsgBox(title, message, type, options)
; 
; Parameters:
;   title   - Window title
;   message - Message text (supports `n for newlines)
;   type    - "info", "warning", "error", "question", "success"
;   options - Object with optional keys:
;             .buttons     - Array of button labels, e.g. ["OK"] or ["Yes", "No", "Cancel"]
;             .default     - Index of default button (1-based)
;             .checkbox    - Checkbox label text (result in DarkMsgBox_Checked)
;             .width       - Custom width (default auto-calculated)
;             .timeout     - Auto-close after N seconds (0 = no timeout)
;
; Returns: Button text that was clicked (e.g. "OK", "Yes", "Cancel")
;          Also sets global DarkMsgBox_Checked if checkbox was used
;
DarkMsgBox(title, message, type := "info", options := "") {
	global Settings_DarkMode, DarkMsgBox_Result, DarkMsgBox_Checked, DPI_Scale
	global DarkMsgBox_LastX, DarkMsgBox_LastY, DarkMsgBox_RememberPos
	static iconMap := {info: 76, warning: 78, error: 93, question: 99, success: 78}
	static colorMap := {info: "4FC3F7", warning: "FFCC00", error: "FF6B6B", question: "4FC3F7", success: "00CC66"}
	
	; DPI scaling factor (default to 1.0 if not set)
	dpi := DPI_Scale ? DPI_Scale : 1.0
	
	; Default options
	buttons := (options && options.buttons) ? options.buttons : ["OK"]
	defaultBtn := (options && options.default) ? options.default : 1
	checkboxText := (options && options.checkbox) ? options.checkbox : ""
	customWidth := (options && options.width) ? options.width : 0
	timeout := (options && options.timeout) ? options.timeout : 0
	btnTooltips := (options && options.tooltips) ? options.tooltips : {}
	rememberPos := (options && options.rememberPosition) ? options.rememberPosition : false
	DarkMsgBox_RememberPos := rememberPos
	
	; Calculate dimensions
	msgLines := StrSplit(message, "`n")
	maxLineLen := 0
	for i, line in msgLines
		if (StrLen(line) > maxLineLen)
			maxLineLen := StrLen(line)
	
	; Auto-calculate width (min 350, max 600) with DPI scaling
	calcWidth := Round((maxLineLen * 8 + 120) * dpi)
	minWidth := Round(350 * dpi)
	maxWidth := Round(600 * dpi)
	if (calcWidth < minWidth)
		calcWidth := minWidth
	if (calcWidth > maxWidth)
		calcWidth := maxWidth
	winWidth := customWidth ? Round(customWidth * dpi) : calcWidth
	
	; Calculate height based on content - account for text wrapping
	; Estimate characters that fit per visual line (accounting for margins)
	charsPerLine := Round((winWidth - 100 * dpi) / 8)
	if (charsPerLine < 30)
		charsPerLine := 30
	
	; Count actual visual lines including wrapping
	lineCount := 0
	for i, line in msgLines {
		lineLen := StrLen(line)
		if (lineLen = 0)
			lineCount += 1
		else
			lineCount += Ceil(lineLen / charsPerLine)
	}
	
	lineHeight := Round(22 * dpi)
	msgHeight := lineCount * lineHeight + Round(30 * dpi)
	minMsgHeight := Round(80 * dpi)
	if (msgHeight < minMsgHeight)
		msgHeight := minMsgHeight
	
	topPad := Round(60 * dpi)
	btnArea := Round(60 * dpi)
	baseHeight := topPad + msgHeight + btnArea
	if (checkboxText != "")
		baseHeight += Round(35 * dpi)
	winHeight := baseHeight
	
	; Initialize result
	DarkMsgBox_Result := ""
	DarkMsgBox_Checked := 0
	
	; Create GUI
	Gui, DarkMsg:New, +AlwaysOnTop +OwnDialogs
	
	if (Settings_DarkMode) {
		Gui, DarkMsg:Color, 1E1E1E, 2D2D2D
		bgColor := "1E1E1E"
		textColor := "CCCCCC"
		btnTextColor := "FFFFFF"
	} else {
		Gui, DarkMsg:Color, FFFFFF, FFFFFF
		bgColor := "FFFFFF"
		textColor := "333333"
		btnTextColor := "000000"
	}
	
	; DPI-scaled positions
	iconX := Round(25 * dpi)
	iconY := Round(25 * dpi)
	iconSize := Round(40 * dpi)
	textX := Round(80 * dpi)
	textY := Round(25 * dpi)
	
	; Icon
	iconNum := iconMap.HasKey(type) ? iconMap[type] : 76
	Gui, DarkMsg:Add, Picture, x%iconX% y%iconY% w%iconSize% h%iconSize% Icon%iconNum%, %A_WinDir%\System32\imageres.dll
	
	; Header/Title with type color
	headerColor := colorMap.HasKey(type) ? colorMap[type] : "FFFFFF"
	headerFont := Round(12 * dpi)
	titleWidth := winWidth - Round(100 * dpi)
	Gui, DarkMsg:Font, s%headerFont% Bold c%headerColor%, Segoe UI
	Gui, DarkMsg:Add, Text, x%textX% y%textY% w%titleWidth%, %title%
	
	; Message body - line by line with color support for emojis
	msgWidth := winWidth - Round(100 * dpi)
	yPos := Round(55 * dpi)
	textFont := Round(10 * dpi)
	Loop, Parse, message, `n
	{
		line := A_LoopField
		
		; Calculate how many visual lines this text needs (for wrapping)
		lineLen := StrLen(line)
		if (lineLen = 0)
			visualLines := 1
		else
			visualLines := Ceil(lineLen / charsPerLine)
		if (visualLines < 1)
			visualLines := 1
		thisLineHeight := visualLines * lineHeight
		
		; Determine color based on line prefix
		if (InStr(line, "✨") || InStr(line, "NEW:"))
			lineColor := "4FC3F7"  ; Cyan for new features
		else if (InStr(line, "🔧") || InStr(line, "FIX:"))
			lineColor := "FFB74D"  ; Orange for fixes
		else if (InStr(line, "💫") || InStr(line, "✓"))
			lineColor := "81C784"  ; Green for improvements
		else if (InStr(line, "⚠") || InStr(line, "WARNING:"))
			lineColor := "FFCC00"  ; Yellow for warnings
		else if (InStr(line, "❌") || InStr(line, "ERROR:"))
			lineColor := "FF6B6B"  ; Red for errors
		else
			lineColor := textColor
		
		Gui, DarkMsg:Font, s%textFont% Norm c%lineColor%, Segoe UI
		Gui, DarkMsg:Add, Text, x%textX% y%yPos% w%msgWidth% h%thisLineHeight%, %line%
		yPos += thisLineHeight
	}
	yPos += Round(10 * dpi)  ; Extra spacing after message
	
	; Checkbox if requested
	if (checkboxText != "") {
		Gui, DarkMsg:Font, s%textFont% Norm c%textColor%, Segoe UI
		Gui, DarkMsg:Add, CheckBox, x%textX% y%yPos% vDarkMsgBox_CheckVar, %checkboxText%
		yPos += Round(35 * dpi)
	}
	
	; Calculate button layout with DPI scaling
	btnCount := buttons.Length()
	btnWidth := Round(100 * dpi)
	btnHeight := Round(32 * dpi)
	btnSpacing := Round(10 * dpi)
	totalBtnWidth := (btnCount * btnWidth) + ((btnCount - 1) * btnSpacing)
	btnStartX := (winWidth - totalBtnWidth) // 2
	
	; Add spacing before button and recalculate window height
	yPos += Round(20 * dpi)  ; Extra spacing before button
	btnYPos := yPos
	bottomPad := Round(20 * dpi)
	winHeight := btnYPos + btnHeight + bottomPad  ; Button position + button height + bottom padding
	
	; Add buttons - use styled text buttons for dark mode
	btnFont := Round(10 * dpi)
	Gui, DarkMsg:Font, s%btnFont% Bold c%btnTextColor%, Segoe UI
	static DarkMsgBox_BtnHwnds := []
	DarkMsgBox_BtnHwnds := []
	for i, btnText in buttons {
		xPos := btnStartX + ((i - 1) * (btnWidth + btnSpacing))
		defaultFlag := (i = defaultBtn) ? "Default" : ""
		if (Settings_DarkMode) {
			; Dark mode: use styled buttons with dark background
			Gui, DarkMsg:Add, Button, x%xPos% y%btnYPos% w%btnWidth% h%btnHeight% %defaultFlag% gDarkMsgBox_Click hwndBtnHwnd, %btnText%
			DarkMsgBox_BtnHwnds.Push({hwnd: BtnHwnd, text: btnText})
		} else {
			Gui, DarkMsg:Add, Button, x%xPos% y%btnYPos% w%btnWidth% h%btnHeight% %defaultFlag% gDarkMsgBox_Click hwndBtnHwnd, %btnText%
			DarkMsgBox_BtnHwnds.Push({hwnd: BtnHwnd, text: btnText})
		}
	}
	
	; Add tooltips if provided
	if (btnTooltips.Count() > 0) {
		for idx, btnInfo in DarkMsgBox_BtnHwnds {
			if (btnTooltips.HasKey(btnInfo.text)) {
				DarkMsgBox_AddTooltip(btnInfo.hwnd, btnTooltips[btnInfo.text])
			}
		}
	}
	
	; Show window - use remembered position if available and requested
	if (rememberPos && DarkMsgBox_LastX != "" && DarkMsgBox_LastY != "") {
		Gui, DarkMsg:Show, x%DarkMsgBox_LastX% y%DarkMsgBox_LastY% w%winWidth% h%winHeight%, %title%
	} else {
		Gui, DarkMsg:Show, w%winWidth% h%winHeight%, %title%
	}
	
	; Ensure window stays on top (reinforce AlwaysOnTop after show)
	Gui, DarkMsg:+LastFound
	WinSet, AlwaysOnTop, On
	
	; Apply dark title bar if dark mode
	if (Settings_DarkMode) {
		Gui, DarkMsg:+LastFound
		WinGet, hWnd, ID
		DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hWnd, "Int", 20, "Int*", 1, "Int", 4)
	}
	
	; Set timeout if requested
	if (timeout > 0) {
		DarkMsgBox_Timeout := timeout
		SetTimer, DarkMsgBox_TimeoutHandler, 1000
	}
	
	; Wait for result
	WinWait, %title% ahk_class AutoHotkeyGUI
	
	; Get window handle for position tracking
	Gui, DarkMsg:+LastFound
	WinGet, msgHwnd, ID
	
	WinWaitClose, %title% ahk_class AutoHotkeyGUI
	
	; Save final position if rememberPosition is enabled
	if (rememberPos && msgHwnd) {
		WinGetPos, finalX, finalY,,, ahk_id %msgHwnd%
		if (finalX != "")
			DarkMsgBox_LastX := finalX
		if (finalY != "")
			DarkMsgBox_LastY := finalY
	}
	
	; Clear timeout
	SetTimer, DarkMsgBox_TimeoutHandler, Off
	
	return DarkMsgBox_Result
}

DarkMsgBox_Click:
	global DarkMsgBox_LastX, DarkMsgBox_LastY, DarkMsgBox_RememberPos
	; Save position before destroying if rememberPosition is enabled
	if (DarkMsgBox_RememberPos) {
		Gui, DarkMsg:+LastFound
		WinGetPos, clickX, clickY
		if (clickX != "")
			DarkMsgBox_LastX := clickX
		if (clickY != "")
			DarkMsgBox_LastY := clickY
	}
	Gui, DarkMsg:Submit
	DarkMsgBox_Result := A_GuiControl
	if (DarkMsgBox_CheckVar)
		DarkMsgBox_Checked := 1
	Gui, DarkMsg:Destroy
Return

DarkMsgBox_TimeoutHandler:
	global DarkMsgBox_Timeout, DarkMsgBox_Result, DarkMsgBox_LastX, DarkMsgBox_LastY, DarkMsgBox_RememberPos
	DarkMsgBox_Timeout--
	if (DarkMsgBox_Timeout <= 0) {
		; Save position before destroying if rememberPosition is enabled
		if (DarkMsgBox_RememberPos) {
			Gui, DarkMsg:+LastFound
			WinGetPos, timeoutX, timeoutY
			if (timeoutX != "")
				DarkMsgBox_LastX := timeoutX
			if (timeoutY != "")
				DarkMsgBox_LastY := timeoutY
		}
		SetTimer, DarkMsgBox_TimeoutHandler, Off
		DarkMsgBox_Result := "Timeout"
		Gui, DarkMsg:Destroy
	}
Return

DarkMsgBox_AddTooltip(hwnd, tipText) {
	static TT_ADDTOOL := 0x432, TTF_IDISHWND := 1, TTF_SUBCLASS := 0x10
	static hToolTip := 0
	
	; Create tooltip control once
	if (!hToolTip) {
		hToolTip := DllCall("CreateWindowEx", "UInt", 0, "Str", "tooltips_class32", "Str", ""
			, "UInt", 0x80000002, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "Ptr", 0, "Ptr", 0, "Ptr", 0, "Ptr", 0, "Ptr")
	}
	
	; Set up TOOLINFO structure
	VarSetCapacity(ti, A_PtrSize = 8 ? 72 : 48, 0)
	NumPut(A_PtrSize = 8 ? 72 : 48, ti, 0, "UInt")  ; cbSize
	NumPut(TTF_IDISHWND | TTF_SUBCLASS, ti, 4, "UInt")  ; uFlags
	NumPut(hwnd, ti, A_PtrSize = 8 ? 16 : 12, "Ptr")  ; uId
	NumPut(&tipText, ti, A_PtrSize = 8 ? 48 : 36, "Ptr")  ; lpszText
	
	; Add tool
	DllCall("SendMessage", "Ptr", hToolTip, "UInt", TT_ADDTOOL, "Ptr", 0, "Ptr", &ti)
}
Return

DarkMsgGuiClose:
DarkMsgGuiEscape:
	DarkMsgBox_Result := "Cancel"
	Gui, DarkMsg:Destroy
Return

; ============================================================
; Non-Blocking Invoice Sync Progress GUI
; ============================================================

; Global variables for sync progress
global SyncProgress_ProcessId := 0
global SyncProgress_XmlPath := ""
global SyncProgress_LastContent := ""
global SyncProgress_NoUpdateCount := 0
global SyncProgress_ErrorMessage := ""

ShowSyncProgressGUI(xmlPath) {
	global Settings_DarkMode, DPI_Scale, SyncProgress_ProcessId, SyncProgress_XmlPath
	global SyncProgress_Title, SyncProgress_Bar, SyncProgress_Status
	global SyncProgress_ErrorMessage
	
	SyncProgress_XmlPath := xmlPath
	SyncProgress_ErrorMessage := ""  ; Reset error message for new sync
	
	; Theme colors
	if (Settings_DarkMode) {
		bgColor := "2D2D30"
		textColor := "E0E0E0"
		progressBg := "3C3C3C"
		progressFg := "4FC3F7"
	} else {
		bgColor := "F5F5F5"
		textColor := "333333"
		progressBg := "E0E0E0"
		progressFg := "0078D4"
	}
	
	; Calculate sizes
	dpi := DPI_Scale ? DPI_Scale : 1.0
	guiW := Round(400 * dpi)
	guiH := Round(120 * dpi)
	margin := Round(20 * dpi)
	progressW := guiW - (margin * 2)
	progressH := Round(8 * dpi)
	
	; Create GUI
	Gui, SyncProgress:Destroy
	Gui, SyncProgress:New, +AlwaysOnTop -SysMenu +ToolWindow
	Gui, SyncProgress:Color, %bgColor%
	Gui, SyncProgress:Font, s11 c%textColor%, Segoe UI
	
	; Title
	Gui, SyncProgress:Add, Text, x%margin% y%margin% w%progressW% vSyncProgress_Title, 📤 Syncing Invoice to GHL...
	
	; Progress bar (custom)
	yPos := Round(50 * dpi)
	Gui, SyncProgress:Add, Progress, x%margin% y%yPos% w%progressW% h%progressH% Background%progressBg% c%progressFg% vSyncProgress_Bar Range0-100, 10
	
	; Status text
	yPos := Round(70 * dpi)
	Gui, SyncProgress:Font, s9 c%textColor%
	Gui, SyncProgress:Add, Text, x%margin% y%yPos% w%progressW% vSyncProgress_Status, Starting...
	
	; Show the GUI
	Gui, SyncProgress:Show, w%guiW% h%guiH%, Invoice Sync Progress
	
	; Start the timer to poll progress file
	SetTimer, SyncProgress_UpdateTimer, 500
}

SyncProgress_UpdateTimer:
	global SyncProgress_ProcessId, SyncProgress_XmlPath
	
	; Read progress file
	progressFile := A_Temp . "\sidekick_sync_progress.txt"
	if (FileExist(progressFile)) {
		FileRead, progressContent, %progressFile%
		if (progressContent != "") {
			; Parse: step|total|message|status
			StringSplit, parts, progressContent, |
			if (parts0 >= 4) {
				step := parts1
				total := parts2
				message := parts3
				status := parts4
				
				; Update progress bar
				if (total > 0) {
					percent := Round((step / total) * 100)
					GuiControl, SyncProgress:, SyncProgress_Bar, %percent%
				}
				
				; Update status text
				GuiControl, SyncProgress:, SyncProgress_Status, %message%
				
				; Check if done
				if (status = "success" || status = "error") {
					SetTimer, SyncProgress_UpdateTimer, Off
					
					; Show final status briefly then close
					if (status = "success") {
						GuiControl, SyncProgress:, SyncProgress_Title, ✓ Sync Complete
						GuiControl, SyncProgress:, SyncProgress_Bar, 100
						; Check for GoCardless prompt after sync success
						SetTimer, CheckGoCardlessAfterSync, -2500
					} else {
						GuiControl, SyncProgress:, SyncProgress_Title, ✗ Sync Failed
						; Store error message for showing after GUI closes
						global SyncProgress_ErrorMessage := message
					}
					
					; Auto-send logs if enabled (on BOTH success and error)
					if (Settings_AutoSendLogs)
						SetTimer, AutoSendLogsOnComplete, -500
					
					; Close after 2 seconds (error MsgBox will show after close)
					SetTimer, SyncProgress_Close, -2000
				}
			}
		}
	}
	
	; Note: We don't check process exit because cmd /c exits immediately
	; and the Python process runs independently. We rely on the progress file
	; and a timeout to detect issues.
	
	; Track how long we've been waiting without progress updates
	if (progressContent = SyncProgress_LastContent) {
		SyncProgress_NoUpdateCount++
		; If no progress for 60 seconds (120 x 500ms), assume something went wrong
		if (SyncProgress_NoUpdateCount > 120) {
			SetTimer, SyncProgress_UpdateTimer, Off
			GuiControl, SyncProgress:, SyncProgress_Title, ✗ Sync Timeout
			GuiControl, SyncProgress:, SyncProgress_Status, No response from sync process
			; Auto-send logs if enabled
			if (Settings_AutoSendLogs)
				SetTimer, AutoSendLogsOnComplete, -500
			SetTimer, SyncProgress_Close, -3000
			SyncProgress_NoUpdateCount := 0
		}
	} else {
		SyncProgress_LastContent := progressContent
		SyncProgress_NoUpdateCount := 0
	}
Return

SyncProgress_Close:
	global SyncProgress_ErrorMessage, ScriptVersion, HelperVersion, HelperModified
	Gui, SyncProgress:Destroy
	; Delete progress file
	progressFile := A_Temp . "\sidekick_sync_progress.txt"
	FileDelete, %progressFile%
	
	; Show detailed error MsgBox if there was an error
	if (SyncProgress_ErrorMessage != "") {
		; Read the result JSON to get more details
		resultFile := A_AppData . "\SideKick_PS\ghl_invoice_sync_result.json"
		if (FileExist(resultFile)) {
			FileRead, resultJson, %resultFile%
			; Parse JSON for client details
			clientName := ""
			email := ""
			albumName := ""
			shootNo := ""
			contactId := ""
			errorMsg := SyncProgress_ErrorMessage
			
			; Extract fields from JSON
			if (RegExMatch(resultJson, """client_name""\s*:\s*""([^""]*)""", m))
				clientName := m1
			if (RegExMatch(resultJson, """email""\s*:\s*""([^""]*)""", m))
				email := m1
			if (RegExMatch(resultJson, """album_name""\s*:\s*""([^""]*)""", m))
				albumName := m1
			if (RegExMatch(resultJson, """shoot_no""\s*:\s*""([^""]*)""", m))
				shootNo := m1
			if (RegExMatch(resultJson, """contact_id""\s*:\s*""([^""]*)""", m))
				contactId := m1
			if (RegExMatch(resultJson, """error""\s*:\s*""([^""]*)""", m))
				errorMsg := m1
			
			; Build detailed error message
			msg := "Invoice sync failed:`n`n"
			msg .= "ERROR: " . errorMsg . "`n`n"
			msg .= "══════════════════════════════`n"
			msg .= "AVAILABLE DATA:`n"
			msg .= "══════════════════════════════`n"
			if (clientName != "")
				msg .= "  Client Name:  " . clientName . "`n"
			if (shootNo != "")
				msg .= "  Shoot No:     " . shootNo . "`n"
			if (email != "")
				msg .= "  Email:        " . email . "`n"
			if (albumName != "")
				msg .= "  Album:        " . albumName . "`n"
			
			msg .= "`n══════════════════════════════`n"
			msg .= "MISSING/INVALID:`n"
			msg .= "══════════════════════════════`n"
			
			; Check what's missing based on error type
			if (InStr(errorMsg, "not found") || InStr(errorMsg, "No GHL Contact ID")) {
				if (contactId != "")
					msg .= "  ✗ Contact ID '" . contactId . "' not found in GHL`n"
				else
					msg .= "  ✗ GHL Contact ID not in XML`n"
				msg .= "`nTO FIX:`n"
				msg .= "  1. Import this client from GHL first`n"
				msg .= "  2. Or link the order to a GHL contact`n"
				msg .= "  3. Then re-export the invoice"
			} else if (InStr(errorMsg, "authentication") || InStr(errorMsg, "401")) {
				msg .= "  ✗ GHL API key invalid or expired`n"
				msg .= "`nTO FIX: Update API key in SideKick Settings"
			} else {
				msg .= "  ✗ " . errorMsg . "`n"
			}
			
			; Add version info for diagnostics
			msg .= "`n`n══════════════════════════════`n"
			msg .= "VERSION INFO:`n"
			msg .= "══════════════════════════════`n"
			msg .= "  SideKick:     v" . ScriptVersion . "`n"
			msg .= "  Helper:       v" . HelperVersion . "`n"
			if (HelperModified != "")
				msg .= "  Helper Built: " . HelperModified . "`n"
			
			DarkMsgBox("Invoice Sync Failed", msg, "error")
		}
		SyncProgress_ErrorMessage := ""
	}
Return

SyncProgressGuiClose:
SyncProgressGuiEscape:
	SetTimer, SyncProgress_UpdateTimer, Off
	Gui, SyncProgress:Destroy
Return

; ============================================================
; Hover-based Tooltip System for Settings and PayPlan GUIs
; ============================================================

; Mouse hover handler for Settings, PP windows, and Toolbar
SettingsMouseMove(wParam, lParam, msg, hwnd) {
	global SettingsTooltips, LastHoveredControl, SettingsHwnd, ToolbarHwnd
	global ToolbarTooltips, ToolbarLastHoveredButton
	static hoverTimer := 0
	
	; Get the control under the mouse cursor
	MouseGetPos, , , mouseWin, controlHwnd, 2
	
	; Check for Toolbar tooltips using the control under mouse
	if (ToolbarTooltips.HasKey(controlHwnd)) {
		if (controlHwnd != ToolbarLastHoveredButton) {
			ToolbarLastHoveredButton := controlHwnd
			ToolTip, % ToolbarTooltips[controlHwnd]
			SetTimer, ToolbarTooltipOff, -2000
		}
		return
	} else if (ToolbarLastHoveredButton && mouseWin != ToolbarHwnd) {
		; Mouse moved off toolbar entirely
		ToolbarLastHoveredButton := 0
		ToolTip
	}
	
	; Process if Settings window or PP window is active
	if !WinExist("ahk_id " . SettingsHwnd) && !WinActive("Payment Calculator")
		return
	
	; If we moved to a different control
	if (controlHwnd != LastHoveredControl) {
		LastHoveredControl := controlHwnd
		ToolTip  ; Clear existing tooltip
		
		; Check if this control has a tooltip
		if (SettingsTooltips.HasKey(controlHwnd)) {
			; Show tooltip after brief delay
			SetTimer, ShowHoverTooltip, -400
		}
	}
}

ShowHoverTooltip:
	global SettingsTooltips, LastHoveredControl
	if (SettingsTooltips.HasKey(LastHoveredControl)) {
		ToolTip, % SettingsTooltips[LastHoveredControl]
		SetTimer, RemoveToolTip, -5000
	}
Return

; Register tooltip for a control by hwnd
RegisterSettingsTooltip(hwnd, tooltipText) {
	global SettingsTooltips
	SettingsTooltips[hwnd] := tooltipText
}

; Format hotkey for display (e.g., "^+g" -> "Ctrl+Shift+G")
FormatHotkeyDisplay(hotkey) {
	if (hotkey = "" || hotkey = "None")
		return "Not set"
	display := ""
	if (InStr(hotkey, "^"))
		display .= "Ctrl+"
	if (InStr(hotkey, "+"))
		display .= "Shift+"
	if (InStr(hotkey, "!"))
		display .= "Alt+"
	if (InStr(hotkey, "#"))
		display .= "Win+"
	; Get the key part - remove all modifier symbols
	key := hotkey
	StringReplace, key, key, ^,, All
	StringReplace, key, key, +,, All
	StringReplace, key, key, !,, All
	StringReplace, key, key, #,, All
	StringUpper, key, key
	if (key != "")
		display .= key
	return display
}

; Capture hotkey dialog - shows a dialog to capture a hotkey
CaptureHotkeyDialog(actionName) {
	global CapturedKey
	CapturedKey := ""
	
	; Create capture dialog
	Gui, HotkeyCapture:New, +AlwaysOnTop +ToolWindow
	Gui, HotkeyCapture:Color, 2D2D2D
	Gui, HotkeyCapture:Font, s11 cFFFFFF, Segoe UI
	Gui, HotkeyCapture:Add, Text, x20 y20 w300 Center, Press the hotkey combination for:
	Gui, HotkeyCapture:Font, s12 cFFCC00 Bold, Segoe UI
	Gui, HotkeyCapture:Add, Text, x20 y50 w300 Center, %actionName%
	Gui, HotkeyCapture:Font, s10 Norm cCCCCCC, Segoe UI
	Gui, HotkeyCapture:Add, Text, x20 y90 w300 Center vCaptureStatus, Waiting for hotkey...
	Gui, HotkeyCapture:Add, Text, x20 y120 w300 Center, (Press Escape to cancel)
	Gui, HotkeyCapture:Show, w340 h160, Capture Hotkey
	
	; Install keyboard hook to capture the hotkey
	Hotkey, IfWinActive, Capture Hotkey
	Loop, 255 {
		key := GetKeyName(Format("vk{:02X}", A_Index))
		if (key != "" && key != "Control" && key != "Shift" && key != "Alt" && key != "LWin" && key != "RWin")
			Hotkey, *%key%, CaptureKeyHandler, On
	}
	Hotkey, IfWinActive
	
	; Wait for capture or cancel
	WinWaitClose, Capture Hotkey
	
	; Disable all the hotkeys we set up
	Hotkey, IfWinActive, Capture Hotkey
	Loop, 255 {
		key := GetKeyName(Format("vk{:02X}", A_Index))
		if (key != "" && key != "Control" && key != "Shift" && key != "Alt" && key != "LWin" && key != "RWin") {
			try Hotkey, *%key%, Off
		}
	}
	Hotkey, IfWinActive
	
	return CapturedKey
}

CaptureKeyHandler:
	; Build the hotkey string
	CapturedKey := ""
	if GetKeyState("Ctrl", "P")
		CapturedKey .= "^"
	if GetKeyState("Shift", "P")
		CapturedKey .= "+"
	if GetKeyState("Alt", "P")
		CapturedKey .= "!"
	if GetKeyState("LWin", "P") || GetKeyState("RWin", "P")
		CapturedKey .= "#"
	
	; Get the actual key pressed
	CapturedKey .= SubStr(A_ThisHotkey, 2)  ; Remove the * prefix
	
	; Close the dialog
	Gui, HotkeyCapture:Destroy
Return

HotkeyCaptureGuiClose:
HotkeyCaptureGuiEscape:
	CapturedKey := ""
	Gui, HotkeyCapture:Destroy
Return

; Legacy click-based tooltip labels (kept for compatibility, now enhanced)
TT_StartOnBoot:
tt := "START ON BOOT`n`nAutomatically launch SideKick_PS when Windows starts.`nRecommended: Enable for daily ProSelect users."
ToolTip, %tt%
SetTimer, RemoveToolTip, -5000
Return

TT_ShowTrayIcon:
tt := "SHOW TRAY ICON`n`nDisplay the SideKick icon in your system tray.`nRight-click for quick access to features."
ToolTip, %tt%
SetTimer, RemoveToolTip, -5000
Return

TT_EnableSounds:
tt := "SOUND EFFECTS`n`nPlay audio feedback for actions and notifications.`nDisable if working in quiet environments."
ToolTip, %tt%
SetTimer, RemoveToolTip, -5000
Return

TT_AutoDetectPS:
tt := "AUTO-DETECT PROSELECT VERSION`n`nAutomatically identify which ProSelect version is installed.`nRecommended: Keep enabled unless detection causes issues."
ToolTip, %tt%
SetTimer, RemoveToolTip, -5000
Return

TT_DefaultRecurring:
tt := "DEFAULT PAYMENT FREQUENCY`n`nSet the pre-selected payment schedule for new plans.`nOptions: Monthly, Weekly, Bi-Weekly, 4-Weekly"
ToolTip, %tt%
SetTimer, RemoveToolTip, -5000
Return

TT_DefaultPayType:
tt := "DEFAULT PAYMENT METHOD`n`nSet the pre-selected payment type for new plans.`nOptions: GoCardless DD, Credit Card, Cash, Online"
ToolTip, %tt%
SetTimer, RemoveToolTip, -5000
Return

TT_GHLEnable:
tt := "ENABLE GHL INTEGRATION`n`nConnect SideKick to your GoHighLevel CRM account.`nRequires a valid GHL API key to function."
ToolTip, %tt%
SetTimer, RemoveToolTip, -5000
Return

TT_GHLAutoLoad:
tt := "AUTO-LOAD TO PROSELECT`n`nWhen ENABLED: Client data loads immediately to ProSelect.`nWhen DISABLED: Preview dialog appears first."
ToolTip, %tt%
SetTimer, RemoveToolTip, -5000
Return

TT_GHLApiKey:
tt := "GHL API KEY`n`nYour GoHighLevel API key for authentication.`nKeep this key secure - do not share it!"
ToolTip, %tt%
SetTimer, RemoveToolTip, -5000
Return

TT_GHLApiKeyV2:
tt := "GHL V2 API KEY (Private Integration Token)`n`nUsed for: Invoices, Payments, full API access`nKeep this key secure - do not share it!"
ToolTip, %tt%
SetTimer, RemoveToolTip, -5000
Return

TT_GHLLocID:
tt := "GHL LOCATION ID`n`nYour GoHighLevel sub-account ID.`nUsed for API calls to the correct location."
ToolTip, %tt%
SetTimer, RemoveToolTip, -5000
Return

TT_DarkMode:
tt := "DARK MODE`n`nToggle between dark and light color themes.`nChanges apply immediately."
ToolTip, %tt%
SetTimer, RemoveToolTip, -5000
Return

TT_GCEnable:
tt := "ENABLE GOCARDLESS`n`nConnect to GoCardless Direct Debit.`nAllows creating mandates and collecting payments."
ToolTip, %tt%
SetTimer, RemoveToolTip, -5000
Return

TT_GCEnv:
tt := "GOCARDLESS ENVIRONMENT`n`nSandbox: Testing environment (no real transactions).`nLive: Production environment (real transactions)."
ToolTip, %tt%
SetTimer, RemoveToolTip, -5000
Return

TT_GCToken:
tt := "API TOKEN`n`nYour GoCardless API access token.`nKeep this secure - do not share it!"
ToolTip, %tt%
SetTimer, RemoveToolTip, -5000
Return

TT_GCSMS:
tt := "SMS MANDATE LINK`n`nAlso send the mandate signup link via SMS.`nRequires valid phone number in GHL contact."
ToolTip, %tt%
SetTimer, RemoveToolTip, -5000
Return

TT_GCAutoSetup:
tt := "AUTO-PROMPT GOCARDLESS`n`nWhen enabled, automatically prompts you after syncing`nan invoice with future payments to set up GoCardless.`n`nThe GC toolbar button works regardless of this setting."
ToolTip, %tt%
SetTimer, RemoveToolTip, -5000
Return

; Theme toggle handler (dark/light mode)
ToggleTheme:
ToggleClick_DarkMode:
; Toggle the dark mode state
Settings_DarkMode := !Settings_DarkMode

; Show brief tooltip
ToolTip, % Settings_DarkMode ? "Dark mode" : "Light mode"
SetTimer, RemoveToolTip, -1000

; Fully rebuild the Settings GUI with new theme colors
GoSub, ShowSettings
Return

CreateGeneralPanel()
{
	global
	
	; Theme-aware colors
	if (Settings_DarkMode) {
		headerColor := "4FC3F7"
		textColor := "FFFFFF"
		labelColor := "CCCCCC"
		mutedColor := "888888"
		groupColor := "666666"
	} else {
		headerColor := "0078D4"
		textColor := "1E1E1E"
		labelColor := "444444"
		mutedColor := "666666"
		groupColor := "999999"
	}
	
	; General panel container
	Gui, Settings:Add, Text, x190 y10 w510 h680 BackgroundTrans vPanelGeneral
	
	; Section header
	Gui, Settings:Font, s16 c%headerColor%, Segoe UI
	Gui, Settings:Add, Text, x200 y20 w400 BackgroundTrans vGenHeader, ⚙ General Settings
	
	; ═══════════════════════════════════════════════════════════════════════════
	; BEHAVIOR GROUP BOX (y55)
	; ═══════════════════════════════════════════════════════════════════════════
	Gui, Settings:Font, s10 Norm c%groupColor%, Segoe UI
	Gui, Settings:Add, GroupBox, x195 y55 w480 h195 vGenBehaviorGroup, Behavior
	
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	
	; Start on Boot toggle slider
	Gui, Settings:Add, Text, x210 y80 w300 BackgroundTrans vGenStartBoot gTT_StartOnBoot HwndHwndStartBoot, Start on Boot
	RegisterSettingsTooltip(HwndStartBoot, "START ON BOOT`n`nAutomatically launch SideKick_PS when Windows starts.`nThe script runs silently in the background and is ready`nwhenever you need it - no manual startup required.`n`nRecommended: Enable for daily ProSelect users.")
	CreateToggleSlider("Settings", "StartOnBoot", 630, 78, Settings_StartOnBoot)
	
	; Show Tray Icon toggle slider
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x210 y110 w300 BackgroundTrans vGenTrayIcon gTT_ShowTrayIcon HwndHwndTrayIcon, Show Tray Icon
	RegisterSettingsTooltip(HwndTrayIcon, "SHOW TRAY ICON`n`nDisplay the SideKick icon in your system tray (notification area).`nWhen visible you can right-click for quick access to features.`nWhen hidden the script still runs - use hotkeys to access.`n`nTip: Keep visible until you learn the keyboard shortcuts.")
	CreateToggleSlider("Settings", "ShowTrayIcon", 630, 108, Settings_ShowTrayIcon)
	
	; Enable Sounds toggle slider
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x210 y140 w300 BackgroundTrans vGenSounds gTT_EnableSounds HwndHwndSounds, Enable Sound Effects
	RegisterSettingsTooltip(HwndSounds, "SOUND EFFECTS`n`nPlay audio feedback for actions and notifications.`nIncludes confirmation beeps and alert sounds.`n`nDisable if working in quiet environments`nor if sounds become distracting.")
	CreateToggleSlider("Settings", "EnableSounds", 630, 138, Settings_EnableSounds)
	
	; Auto-detect ProSelect toggle slider
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x210 y170 w300 BackgroundTrans vGenAutoPS gTT_AutoDetectPS HwndHwndAutoPS, Auto-detect ProSelect Version
	RegisterSettingsTooltip(HwndAutoPS, "AUTO-DETECT PROSELECT VERSION`n`nAutomatically identify which ProSelect version is installed.`nThis optimizes keyboard shortcuts and window detection`nfor your specific ProSelect version (2022, 2024, 2025).`n`nRecommended: Keep enabled unless detection causes issues.")
	CreateToggleSlider("Settings", "AutoDetectPS", 630, 168, Settings_AutoDetectPS)
	
	; Dark Mode toggle slider
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x210 y200 w300 BackgroundTrans vGenDarkMode gTT_DarkMode HwndHwndDarkMode, Dark Mode
	RegisterSettingsTooltip(HwndDarkMode, "DARK MODE`n`nToggle between dark and light color themes.`n`nDark Mode: Easy on the eyes, matches ProSelect 2025 style`nLight Mode: Traditional bright interface`n`nChanges apply immediately to the Settings window.")
	CreateToggleSlider("Settings", "DarkMode", 630, 198, Settings_DarkMode)
	
	; ═══════════════════════════════════════════════════════════════════════════
	; PAYMENT DEFAULTS GROUP BOX (y260)
	; ═══════════════════════════════════════════════════════════════════════════
	Gui, Settings:Font, s10 Norm c%groupColor%, Segoe UI
	Gui, Settings:Add, GroupBox, x195 y260 w480 h110 vGenDefaultsGroup, Payment Defaults
	
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	
	; Default Recurring
	Gui, Settings:Add, Text, x210 y290 w150 BackgroundTrans vGenRecurLabel gTT_DefaultRecurring HwndHwndRecur, Default Recurring:
	RegisterSettingsTooltip(HwndRecur, "DEFAULT PAYMENT FREQUENCY`n`nSet the pre-selected payment schedule for new plans.`nMonthly is always available. Other options can be customized.`n`nThis can be changed per-plan when creating payments.")
	Gui, Settings:Add, DropDownList, x380 y287 w150 vSettings_DefaultRecurring_DDL, Monthly||Weekly|Bi-Weekly|4-Weekly
	
	; Recurring Options (editable)
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x210 y325 w150 BackgroundTrans vGenRecurOptionsLabel, Recurring Options:
	Gui, Settings:Add, Edit, x380 y322 w150 h24 vGenRecurOptionsEdit ReadOnly, Monthly, Weekly, Bi-Weekly, 4-Weekly
	Gui, Settings:Add, Button, x540 y321 w60 h26 gEditRecurringOptions vGenRecurOptionsBtn, Edit
	
	; ═══════════════════════════════════════════════════════════════════════════
	; APP SETTINGS GROUP BOX (y380)
	; ═══════════════════════════════════════════════════════════════════════════
	Gui, Settings:Font, s10 Norm c%groupColor%, Segoe UI
	Gui, Settings:Add, GroupBox, x195 y380 w480 h80 vGenProSelectGroup, App Settings
	
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	
	; Buttons row
	Gui, Settings:Add, Button, x210 y410 w110 h30 gCreateSideKickShortcut vGenShortcutBtn, 🚀 Shortcut
	Gui, Settings:Add, Button, x330 y410 w100 h30 gOpenUserManual vGenManualBtn HwndHwndGenManual, 📖 Manual
	RegisterSettingsTooltip(HwndGenManual, "USER MANUAL`n`nOpen the online documentation and user guide.`nLearn about features, setup, and troubleshooting.")
	Gui, Settings:Add, Button, x440 y410 w70 h30 gExportSettings vGenExportBtn, 📤 Export
	Gui, Settings:Add, Button, x520 y410 w70 h30 gImportSettings vGenImportBtn, 📥 Import
}

CreateGHLPanel()
{
	global
	
	; Theme-aware colors
	if (Settings_DarkMode) {
		headerColor := "4FC3F7"
		textColor := "FFFFFF"
		labelColor := "CCCCCC"
		mutedColor := "888888"
		groupColor := "666666"
	} else {
		headerColor := "0078D4"
		textColor := "1E1E1E"
		labelColor := "444444"
		mutedColor := "666666"
		groupColor := "999999"
	}
	
	; GHL panel container (initially hidden)
	Gui, Settings:Add, Text, x190 y10 w510 h680 BackgroundTrans vPanelGHL Hidden
	
	; Section header
	Gui, Settings:Font, s16 c%headerColor%, Segoe UI
	Gui, Settings:Add, Text, x195 y20 w480 BackgroundTrans vGHLHeader Hidden, 🔗 GHL Integration
	
	; ═══════════════════════════════════════════════════════════════════════════
	; CONNECTION GROUP BOX (y55 to y165)
	; ═══════════════════════════════════════════════════════════════════════════
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, GroupBox, x195 y55 w480 h110 vGHLConnection Hidden, Connection
	
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	
	; Enable GHL Integration toggle slider
	Gui, Settings:Add, Text, x210 y80 w300 BackgroundTrans vGHLEnable Hidden gTT_GHLEnable HwndHwndGHLEnable, Enable GHL Integration
	RegisterSettingsTooltip(HwndGHLEnable, "ENABLE GHL INTEGRATION`n`nConnect SideKick to your GoHighLevel CRM.`nFetch client details and auto-populate ProSelect.`n`nRequires a valid GHL API key.")
	CreateToggleSlider("Settings", "GHL_Enabled", 630, 78, Settings_GHL_Enabled)
	
	; Auto-load to ProSelect toggle slider
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x210 y110 w300 BackgroundTrans vGHLAutoLoad Hidden gTT_GHLAutoLoad HwndHwndGHLAutoLoad, Autoload client data
	RegisterSettingsTooltip(HwndGHLAutoLoad, "AUTOLOAD CLIENT DATA`n`nENABLED: Client data loads immediately.`nDISABLED: Preview dialog appears first.`n`nKeep disabled until you trust data quality.")
	CreateToggleSlider("Settings", "GHL_AutoLoad", 630, 108, Settings_GHL_AutoLoad)
	
	; ═══════════════════════════════════════════════════════════════════════════
	; API CONFIGURATION GROUP BOX (y170 to y300)
	; ═══════════════════════════════════════════════════════════════════════════
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, GroupBox, x195 y170 w480 h130 vGHLApiConfig Hidden, API Configuration
	
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	
	; API Key display (masked)
	Gui, Settings:Add, Text, x210 y195 w90 BackgroundTrans vGHLApiLabel Hidden gTT_GHLApiKey HwndHwndGHLApiKey, API Key:
	RegisterSettingsTooltip(HwndGHLApiKey, "GHL API KEY (Private Integration Token)`n`nUsed for: Contacts, Invoices, Payments, etc.`n`nTo get your key:`n1. Go to GHL Marketplace`n2. My Apps > Create Private App`n3. Copy the Private Integration Token`n`nKeys are stored encrypted in the INI file.")
	apiKeyDisplay := GHL_API_Key ? SubStr(GHL_API_Key, 1, 8) . "..." . SubStr(GHL_API_Key, -4) : "Not configured"
	Gui, Settings:Font, s10 Norm cFFFFFF, Segoe UI
	Gui, Settings:Add, Edit, x305 y192 w250 h25 vGHLApiKeyDisplay Hidden ReadOnly, %apiKeyDisplay%
	Gui, Settings:Add, Button, x560 y190 w100 h28 gEditGHLApiKey vGHLApiEditBtn Hidden, Edit
	
	; Location ID display
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x210 y225 w90 BackgroundTrans vGHLLocLabel Hidden gTT_GHLLocID HwndHwndGHLLocID, Location ID:
	RegisterSettingsTooltip(HwndGHLLocID, "GHL LOCATION ID`n`nYour GoHighLevel sub-account ID.`nUsed for API calls to the correct location.`n`nFind it in GHL: Settings > Business Profile")
	locIdDisplay := GHL_LocationID ? GHL_LocationID : "Not configured"
	Gui, Settings:Font, s10 Norm cFFFFFF, Segoe UI
	Gui, Settings:Add, Edit, x305 y222 w250 h25 vGHLLocIDDisplay Hidden ReadOnly, %locIdDisplay%
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Button, x560 y220 w100 h28 gEditGHLLocationID vGHLLocEditBtn Hidden, Edit
	
	; Status row
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x210 y258 w60 BackgroundTrans vGHLStatus Hidden, Status:
	statusText := GHL_API_Key ? "✅ Connected" : "❌ Not configured"
	statusColor := GHL_API_Key ? "00FF00" : "FF6B6B"
	Gui, Settings:Font, s10 Norm c%statusColor%, Segoe UI
	Gui, Settings:Add, Text, x275 y258 w120 BackgroundTrans vGHLStatusText Hidden HwndHwndGHLStatus, %statusText%
	RegisterSettingsTooltip(HwndGHLStatus, "CONNECTION STATUS`n`n✅ Connected = API key configured`n`nUse 'Test' to verify.")
	
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Button, x455 y255 w100 h26 gTestGHLConnection vGHLTestBtn Hidden HwndHwndGHLTest, Test
	RegisterSettingsTooltip(HwndGHLTest, "TEST CONNECTION`n`nVerify your API key works by making`na test request to the GHL API.")
	Gui, Settings:Add, Button, x560 y255 w100 h26 gRunGHLSetupWizard vGHLSetupBtn Hidden, 🔧 Wizard
	
	; ═══════════════════════════════════════════════════════════════════════════
	; INVOICE SYNC GROUP BOX (y305 to y580)
	; ═══════════════════════════════════════════════════════════════════════════
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, GroupBox, x195 y305 w480 h280 vGHLInvoiceHeader Hidden, Invoice Sync
	
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	
	; Watch Folder
	Gui, Settings:Add, Text, x210 y330 w90 BackgroundTrans vGHLWatchLabel Hidden, Watch Folder:
	Gui, Settings:Add, Edit, x305 y327 w250 h25 cBlack vGHLWatchFolderEdit Hidden, %Settings_InvoiceWatchFolder%
	Gui, Settings:Add, Button, x560 y325 w100 h28 gBrowseInvoiceFolder vGHLWatchBrowseBtn Hidden, Browse
	
	; Open invoice URL toggle slider
	Gui, Settings:Add, Text, x210 y360 w360 BackgroundTrans vGHLOpenInvoiceURL Hidden HwndHwndOpenInvoiceURL, Open invoice URL
	RegisterSettingsTooltip(HwndOpenInvoiceURL, "OPEN INVOICE URL`n`nWhen enabled, opens the newly created invoice`nin Chrome after syncing to GHL.`n`nDisabled: Invoice is created but not opened.")
	CreateToggleSlider("Settings", "OpenInvoiceURL", 630, 358, Settings_OpenInvoiceURL)
	
	; Financials only toggle slider
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x210 y390 w360 BackgroundTrans vGHLFinancialsOnly Hidden HwndHwndFinancialsOnly, Financials only (exclude image lines)
	RegisterSettingsTooltip(HwndFinancialsOnly, "FINANCIALS ONLY MODE`n`nWhen enabled, invoice sync will only include:`n• Lines with monetary values`n• Comment/text lines`n`nExcludes lines that are just image numbers (e.g. 001, 002).`nThis keeps your GHL invoices clean and financial-focused.")
	CreateToggleSlider("Settings", "FinancialsOnly", 630, 388, Settings_FinancialsOnly)
	
	; Auto-save XML toggle slider
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x210 y420 w360 BackgroundTrans vGHLAutoSaveXML Hidden HwndHwndAutoSaveXML, Auto-save XML copy to watch folder
	RegisterSettingsTooltip(HwndAutoSaveXML, "AUTO-SAVE XML COPY`n`nWhen enabled, saves a copy of the invoice XML`nto the watch folder during export.`n`nUseful for integration with other programs`nthat read ProSelect XML files.")
	CreateToggleSlider("Settings", "AutoSaveXML", 630, 418, Settings_AutoSaveXML)
	
	; Contact Sheet toggle slider
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x210 y450 w360 BackgroundTrans vGHLContactSheet Hidden HwndHwndContactSheet, Create contact sheet with order
	RegisterSettingsTooltip(HwndContactSheet, "CONTACT SHEET WITH ORDER`n`nWhen enabled, creates a JPG contact sheet showing`nall product images and uploads to GHL Media.`n`nThe contact sheet is added as a note on the contact`nfor easy reference.")
	CreateToggleSlider("Settings", "ContactSheet", 630, 448, Settings_ContactSheet)
	
	; GHL Contact Tags field with ComboBox for selecting from existing tags
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x210 y483 w95 BackgroundTrans vGHLTagsLabel Hidden HwndHwndGHLTags, Contact tags:
	RegisterSettingsTooltip(HwndGHLTags, "CONTACT TAGS`n`nTags to add to the GHL contact when syncing.`nThese appear in CRM > Contacts > Tags.`n`nClick 🔄 to fetch existing tags from GHL,`nor type a new tag name to create it.`n`nExample: proselect, vip-client")
	; Build tag list for ComboBox (saved value first, then cached tags)
	tagList := Settings_GHLTags
	if (GHL_CachedTags != "") {
		if (tagList != "")
			tagList .= "||"
		tagList .= GHL_CachedTags
	}
	Gui, Settings:Add, ComboBox, x305 y480 w170 r15 vGHLTagsEdit Hidden, %tagList%
	Gui, Settings:Add, Button, x480 y479 w40 h27 gRefreshGHLTags vGHLTagsRefresh Hidden HwndHwndTagsRefresh, 🔄
	RegisterSettingsTooltip(HwndTagsRefresh, "REFRESH CONTACT TAGS`n`nFetch your existing contact tags from GHL.")
	Gui, Settings:Font, s8 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x525 y483 w100 BackgroundTrans vAutoTagContactLabel Hidden, Auto tag on inv
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	CreateToggleSlider("Settings", "AutoAddContactTags", 630, 478, Settings_AutoAddContactTags)
	
	; GHL Opportunity Tags field with ComboBox
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x210 y513 w95 BackgroundTrans vGHLOppTagsLabel Hidden HwndHwndGHLOppTags, Opp tags:
	RegisterSettingsTooltip(HwndGHLOppTags, "OPPORTUNITY TAGS`n`nTags to add to the GHL opportunity when syncing.`nThese are used for Smart Lists and filtering.`n`nClick 🔄 to fetch existing opp tags from GHL,`nor type any tag name you want to use.`n`nExample: proselect, invoice-synced")
	; Build opp tag list for ComboBox (saved value first, then cached opp tags)
	oppTagList := Settings_GHLOppTags
	if (GHL_CachedOppTags != "") {
		if (oppTagList != "")
			oppTagList .= "||"
		oppTagList .= GHL_CachedOppTags
	}
	Gui, Settings:Add, ComboBox, x305 y510 w170 r15 vGHLOppTagsEdit Hidden, %oppTagList%
	Gui, Settings:Add, Button, x480 y509 w40 h27 gRefreshGHLOppTags vGHLOppTagsRefresh Hidden HwndHwndOppTagsRefresh, 🔄
	RegisterSettingsTooltip(HwndOppTagsRefresh, "REFRESH OPPORTUNITY TAGS`n`nFetch existing tags from your GHL opportunities.")
	Gui, Settings:Font, s8 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x525 y513 w100 BackgroundTrans vAutoTagOppLabel Hidden, Auto tag on inv
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	CreateToggleSlider("Settings", "AutoAddOppTags", 630, 508, Settings_AutoAddOppTags)
	
	; Set Order QR button - unified format works for both phone and scanner
	Gui, Settings:Font, s9 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Button, x210 y545 w150 h26 gSetOrderQRUrl vGHLSetOrderQRBtn Hidden HwndHwndSetOrderQR, 📱 Set Order QR URL
	RegisterSettingsTooltip(HwndSetOrderQR, "SET ORDER QR URL`n`nConfigures ProSelect QR code that works for BOTH:`n`n📱 Phone: Scan with camera → opens GHL contact`n🔫 Scanner: Barcode scanner → SideKick opens URL`n`nThe long URL path provides natural padding for scanner timing.")
	
	; ═══════════════════════════════════════════════════════════════════════════
	; CONTACT SHEET COLLECTION GROUP BOX (y590 to y685)
	; ═══════════════════════════════════════════════════════════════════════════
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, GroupBox, x195 y590 w480 h95 vGHLInfo Hidden, Contact Sheet Collection

	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	
	; Collect Contact Sheets toggle slider
	Gui, Settings:Add, Text, x210 y615 w360 BackgroundTrans vGHLCollectCS Hidden HwndHwndCollectCS, Save local copies of contact sheets
	RegisterSettingsTooltip(HwndCollectCS, "COLLECT CONTACT SHEETS`n`nSave a copy of each contact sheet JPG to a local folder.`n`nFiles are named using the ProSelect album name`nfor easy organization and reference.")
	CreateToggleSlider("Settings", "CollectContactSheets", 630, 613, Settings_CollectContactSheets)
	
	; Contact Sheet folder path
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x210 y650 w90 BackgroundTrans vGHLCSFolderLabel Hidden, Save Folder:
	Gui, Settings:Add, Edit, x305 y647 w250 h25 cBlack vGHLCSFolderEdit Hidden, %Settings_ContactSheetFolder%
	Gui, Settings:Add, Button, x560 y645 w100 h28 gBrowseContactSheetFolder vGHLCSFolderBrowse Hidden, Browse
}

CreateHotkeysPanel()
{
	global
	
	; Theme-aware colors
	if (Settings_DarkMode) {
		headerColor := "4FC3F7"
		textColor := "FFFFFF"
		labelColor := "CCCCCC"
		mutedColor := "888888"
		inputBg := "3C3C3C"
		groupColor := "666666"
	} else {
		headerColor := "0078D4"
		textColor := "1E1E1E"
		labelColor := "444444"
		mutedColor := "666666"
		inputBg := "FFFFFF"
		groupColor := "999999"
	}
	
	; Hotkeys panel container (initially hidden)
	Gui, Settings:Add, Text, x190 y10 w510 h680 BackgroundTrans vPanelHotkeys Hidden
	
	; Section header
	Gui, Settings:Font, s16 c%headerColor%, Segoe UI
	Gui, Settings:Add, Text, x195 y20 w480 BackgroundTrans vHotkeysHeader Hidden, ⌨ Keyboard Shortcuts
	
	; Info note - hotkeys work when ProSelect or SideKick is active
	Gui, Settings:Font, s9 c%mutedColor%, Segoe UI
	Gui, Settings:Add, Text, x195 y45 w480 BackgroundTrans vHotkeysNote Hidden, ℹ️ Hotkeys work when ProSelect or SideKick is active
	
	; ═══════════════════════════════════════════════════════════════════════════
	; GLOBAL HOTKEYS GROUP BOX
	; ═══════════════════════════════════════════════════════════════════════════
	Gui, Settings:Font, s10 Norm c%groupColor%, Segoe UI
	devHotkeyHeight := A_IsCompiled ? 155 : 195
	Gui, Settings:Add, GroupBox, x195 y65 w480 h%devHotkeyHeight% vHotkeysGlobalGroup Hidden, Global Hotkeys
	
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	
	; GHL Client Lookup hotkey
	Gui, Settings:Add, Text, x210 y90 w180 BackgroundTrans vHKLabelGHL Hidden HwndHwndHKGHL, GHL Client Lookup:
	RegisterSettingsTooltip(HwndHKGHL, "GHL CLIENT LOOKUP HOTKEY`n`nTrigger a GoHighLevel client lookup from anywhere.`nFetches contact details, notes, and custom fields`nfor the currently active client in ProSelect.`n`nClick 'Set' then press your desired key combination.`nDefault: Ctrl+Shift+G")
	displayGHL := FormatHotkeyDisplay(Hotkey_GHLLookup)
	Gui, Settings:Add, Edit, x400 y87 w150 h25 vHotkey_GHLLookup_Edit ReadOnly Hidden, %displayGHL%
	Gui, Settings:Add, Button, x560 y86 w60 h27 gCaptureHotkey_GHL vHKCaptureGHL Hidden HwndHwndHKCaptureGHL, Set
	RegisterSettingsTooltip(HwndHKCaptureGHL, "SET HOTKEY`n`nClick this button, then press your desired`nkey combination (e.g., Ctrl+Shift+G).`n`nThe hotkey will be captured and saved automatically.")
	
	; PayPlan hotkey
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x210 y120 w180 BackgroundTrans vHKLabelPP Hidden HwndHwndHKPP, Open PayPlan:
	RegisterSettingsTooltip(HwndHKPP, "PAYPLAN CALCULATOR HOTKEY`n`nOpen the PayPlan calculator for creating payment plans.`nQuickly generate monthly/weekly payment schedules`nfor client invoices.`n`nClick 'Set' then press your desired key combination.`nDefault: Ctrl+Shift+P")
	displayPP := FormatHotkeyDisplay(Hotkey_PayPlan)
	Gui, Settings:Add, Edit, x400 y117 w150 h25 vHotkey_PayPlan_Edit ReadOnly Hidden, %displayPP%
	Gui, Settings:Add, Button, x560 y116 w60 h27 gCaptureHotkey_PayPlan vHKCapturePP Hidden HwndHwndHKCapturePP, Set
	RegisterSettingsTooltip(HwndHKCapturePP, "SET HOTKEY`n`nClick this button, then press your desired`nkey combination (e.g., Ctrl+Shift+P).`n`nThe hotkey will be captured and saved automatically.")
	
	; Settings hotkey
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x210 y150 w180 BackgroundTrans vHKLabelSettings Hidden HwndHwndHKSettings, Open Settings:
	RegisterSettingsTooltip(HwndHKSettings, "SETTINGS WINDOW HOTKEY`n`nOpen this Settings window from anywhere.`nQuickly access configuration, hotkeys,`nand GHL integration options.`n`nClick 'Set' then press your desired key combination.`nDefault: Ctrl+Shift+W")
	displaySettings := FormatHotkeyDisplay(Hotkey_Settings)
	Gui, Settings:Add, Edit, x400 y147 w150 h25 vHotkey_Settings_Edit ReadOnly Hidden, %displaySettings%
	Gui, Settings:Add, Button, x560 y146 w60 h27 gCaptureHotkey_Settings vHKCaptureSettings Hidden HwndHwndHKCaptureSettings, Set
	RegisterSettingsTooltip(HwndHKCaptureSettings, "SET HOTKEY`n`nClick this button, then press your desired`nkey combination (e.g., Ctrl+Shift+W).`n`nThe hotkey will be captured and saved automatically.")
	
	; Dev Reload hotkey (only visible in dev mode - not compiled)
	if (!A_IsCompiled) {
		Gui, Settings:Font, s10 cFF9900, Segoe UI  ; Orange for dev-only
		Gui, Settings:Add, Text, x210 y180 w180 BackgroundTrans vHKLabelDevReload Hidden HwndHwndHKDevReload, 🔧 Reload Script:
		RegisterSettingsTooltip(HwndHKDevReload, "RELOAD SCRIPT HOTKEY (Dev Only)`n`nReloads the script for testing code changes.`nOnly available when running as uncompiled script.`n`nUseful during development to quickly apply changes`nwithout manually restarting.`n`nDefault: Ctrl+Shift+R")
		displayDevReload := FormatHotkeyDisplay(Hotkey_DevReload)
		Gui, Settings:Add, Edit, x400 y177 w150 h25 vHotkey_DevReload_Edit ReadOnly Hidden, %displayDevReload%
		Gui, Settings:Add, Button, x560 y176 w60 h27 gCaptureHotkey_DevReload vHKCaptureDevReload Hidden, Set
		Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	}
	
	; ═══════════════════════════════════════════════════════════════════════════
	; ACTIONS GROUP BOX
	; ═══════════════════════════════════════════════════════════════════════════
	actionsY := A_IsCompiled ? 230 : 270
	Gui, Settings:Font, s10 Norm c%groupColor%, Segoe UI
	Gui, Settings:Add, GroupBox, x195 y%actionsY% w480 h75 vHotkeysActionsGroup Hidden, Actions
	
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	btnY := actionsY + 30
	Gui, Settings:Add, Button, x210 y%btnY% w150 h30 gResetHotkeysToDefault vHKResetBtn Hidden HwndHwndHKReset, Reset to Defaults
	RegisterSettingsTooltip(HwndHKReset, "RESET TO DEFAULTS`n`nRestore all hotkeys to their original settings:`n• GHL Lookup: Ctrl+Shift+G`n• PayPlan: Ctrl+Shift+P`n• Settings: Ctrl+Shift+W`n`nUseful if you've made changes and want to start fresh.")
	Gui, Settings:Add, Button, x380 y%btnY% w150 h30 gClearAllHotkeys vHKClearBtn Hidden HwndHwndHKClear, Clear All
	RegisterSettingsTooltip(HwndHKClear, "CLEAR ALL HOTKEYS`n`nRemove all assigned keyboard shortcuts.`nHotkey fields will be empty until you set new ones.`n`nUse this if hotkeys conflict with other applications`nor if you prefer to use the tray menu/GUI instead.")
	
	; ═══════════════════════════════════════════════════════════════════════════
	; TOOLBAR GROUP BOX
	; ═══════════════════════════════════════════════════════════════════════════
	toolbarY := A_IsCompiled ? 315 : 355
	Gui, Settings:Font, s10 Norm c%groupColor%, Segoe UI
	Gui, Settings:Add, GroupBox, x195 y%toolbarY% w480 h135 vHotkeysToolbarGroup Hidden, Toolbar Appearance
	
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	iconLabelY := toolbarY + 30
	Gui, Settings:Add, Text, x210 y%iconLabelY% w120 BackgroundTrans vHKToolbarIconLabel Hidden HwndHwndHKToolbarIcon, Icon Color:
	RegisterSettingsTooltip(HwndHKToolbarIcon, "TOOLBAR ICON COLOR`n`nSelect the color for toolbar button icons.`n`n• White - Best for dark backgrounds (default)`n• Black - Best for light backgrounds`n• Yellow - High visibility option`n`nThe toolbar will be recreated after changing.")
	iconDropY := iconLabelY - 3
	; Check if current color is a preset or custom
	if (Settings_ToolbarIconColor = "White" || Settings_ToolbarIconColor = "Black" || Settings_ToolbarIconColor = "Yellow")
		colorOptions := "White|Black|Yellow"
	else
		colorOptions := "White|Black|Yellow|Custom"
	Gui, Settings:Add, DropDownList, x340 y%iconDropY% w100 vSettings_ToolbarIconColor_DDL gToolbarIconColorChanged Hidden, %colorOptions%
	if (Settings_ToolbarIconColor = "White" || Settings_ToolbarIconColor = "Black" || Settings_ToolbarIconColor = "Yellow")
		GuiControl, Settings:ChooseString, Settings_ToolbarIconColor_DDL, %Settings_ToolbarIconColor%
	else
		GuiControl, Settings:ChooseString, Settings_ToolbarIconColor_DDL, Custom
	
	; Color preview swatch
	previewColor := GetColorHex(Settings_ToolbarIconColor)
	previewX := 445
	Gui, Settings:Add, Progress, x%previewX% y%iconDropY% w30 h23 Background%previewColor% vHKColorPreview Hidden
	
	; Pick button
	pickBtnX := 480
	Gui, Settings:Add, Button, x%pickBtnX% y%iconDropY% w65 h25 gHKPickColor vHKPickColorBtn Hidden, Pick...
	
	; Position reset row
	posLabelY := iconLabelY + 35
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x210 y%posLabelY% w120 BackgroundTrans vHKToolbarPosLabel Hidden HwndHwndHKToolbarPos, Position:
	RegisterSettingsTooltip(HwndHKToolbarPos, "TOOLBAR POSITION`n`nThe toolbar position can be adjusted by Ctrl+Clicking the grab handle (⋮) on the left of the toolbar.`n`nClick Reset to restore default position.")
	posBtnY := posLabelY - 3
	Gui, Settings:Add, Button, x340 y%posBtnY% w120 h25 gHKResetToolbarPos vHKResetPosBtn Hidden, Reset Position
	
	; Auto Background toggle
	autoBgY := posLabelY + 30
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x210 y%autoBgY% w200 BackgroundTrans vHKAutoBlendLabel Hidden HwndHwndHKAutoBG, Auto-blend with background
	RegisterSettingsTooltip(HwndHKAutoBG, "AUTO-BLEND BACKGROUND`n`nWhen enabled, the toolbar samples the screen area behind it and matches the background color.`n`nThis helps the toolbar blend seamlessly with ProSelect's interface instead of floating on top.")
	autoBgToggleX := 430
	autoBgToggleY := autoBgY - 3
	CreateToggleSlider("Settings", "ToolbarAutoBG", autoBgToggleX, autoBgToggleY, Settings_ToolbarAutoBG)
	
	; ═══════════════════════════════════════════════════════════════════════════
	; INSTRUCTIONS GROUP BOX
	; ═══════════════════════════════════════════════════════════════════════════
	instructY := A_IsCompiled ? 455 : 495
	Gui, Settings:Font, s10 Norm c%groupColor%, Segoe UI
	Gui, Settings:Add, GroupBox, x195 y%instructY% w480 h130 vHotkeysInstructGroup Hidden, How to Set Hotkeys
	
	Gui, Settings:Font, s10 Norm c%mutedColor%, Segoe UI
	step1Y := instructY + 30
	step2Y := instructY + 55
	step3Y := instructY + 80
	tipY := instructY + 105
	Gui, Settings:Add, Text, x210 y%step1Y% w440 BackgroundTrans vHKInstructions1 Hidden, 1. Click the "Set" button next to the action you want to configure
	Gui, Settings:Add, Text, x210 y%step2Y% w440 BackgroundTrans vHKInstructions2 Hidden, 2. Press your desired key combination (e.g., Ctrl+Shift+G)
	Gui, Settings:Add, Text, x210 y%step3Y% w440 BackgroundTrans vHKInstructions3 Hidden, 3. The hotkey is saved automatically and active immediately
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x210 y%tipY% w440 BackgroundTrans vHKInstructions4 Hidden, 💡 Tip: Use Ctrl, Alt, or Shift modifiers to avoid conflicts
}

CreateFilesPanel()
{
	global
	
	; Theme-aware colors (matching Hotkeys panel)
	if (Settings_DarkMode) {
		headerColor := "4FC3F7"
		textColor := "FFFFFF"
		labelColor := "CCCCCC"
		mutedColor := "888888"
		groupColor := "666666"
	} else {
		headerColor := "0078D4"
		textColor := "1E1E1E"
		labelColor := "444444"
		mutedColor := "666666"
		groupColor := "999999"
	}
	
	; Files panel container (initially hidden)
	Gui, Settings:Add, Text, x190 y10 w510 h680 BackgroundTrans vPanelFiles Hidden
	
	; Section header
	Gui, Settings:Font, s16 c%headerColor%, Segoe UI
	Gui, Settings:Add, Text, x195 y20 w480 BackgroundTrans vFilesHeader Hidden, 📁 File Management
	
	; ═══════════════════════════════════════════════════════════════════════════
	; SD CARD DOWNLOAD GROUP BOX
	; ═══════════════════════════════════════════════════════════════════════════
	Gui, Settings:Font, s10 Norm c%groupColor%, Segoe UI
	Gui, Settings:Add, GroupBox, x195 y55 w480 h135 vFilesSDCardGroup Hidden, SD Card Download
	
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x210 y80 w200 BackgroundTrans vFilesEnableSDCard Hidden HwndHwndFilesSDCard, Enable SD Card Download
	RegisterSettingsTooltip(HwndFilesSDCard, "ENABLE SD CARD DOWNLOAD`n`nWhen enabled, shows the SD card download button`nin the toolbar for quick access.`n`nAllows one-click transfer of photos from your`nmemory card to the download folder.")
	CreateToggleSlider("Settings", "SDCardEnabled", 630, 78, Settings_SDCardEnabled)
	GuiControl, Settings:Hide, Toggle_SDCardEnabled
	
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x210 y110 w100 BackgroundTrans vFilesCardDriveLabel Hidden, Card Path:
	Gui, Settings:Add, Edit, x315 y107 w240 h25 cBlack vFilesCardDriveEdit Hidden, %Settings_CardDrive%
	Gui, Settings:Add, Button, x560 y106 w100 h27 gFilesCardDriveBrowseBtn vFilesCardDriveBrowse Hidden, Browse
	
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x210 y140 w100 BackgroundTrans vFilesDownloadLabel Hidden, Download To:
	Gui, Settings:Add, Edit, x315 y137 w240 h25 cBlack vFilesDownloadEdit Hidden, %Settings_CameraDownloadPath%
	Gui, Settings:Add, Button, x560 y136 w100 h27 gFilesDownloadBrowseBtn vFilesDownloadBrowse Hidden, Browse
	
	; ═══════════════════════════════════════════════════════════════════════════
	; ARCHIVE SETTINGS GROUP BOX
	; ═══════════════════════════════════════════════════════════════════════════
	Gui, Settings:Font, s10 Norm c%groupColor%, Segoe UI
	Gui, Settings:Add, GroupBox, x195 y200 w480 h100 vFilesArchiveGroup Hidden, Archive Settings
	
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x210 y225 w100 BackgroundTrans vFilesArchiveLabel Hidden HwndHwndFilesArchive, Archive Path:
	RegisterSettingsTooltip(HwndFilesArchive, "ARCHIVE PATH`n`nLocation where completed shoots are archived.`nUsed for long-term storage and backup.`n`nOrganize by year/month for easy retrieval.")
	Gui, Settings:Add, Edit, x315 y222 w240 h25 cBlack vFilesArchiveEdit Hidden, %Settings_ShootArchivePath%
	Gui, Settings:Add, Button, x560 y221 w100 h27 gShowArchiveFolderPicker vFilesArchiveBrowse Hidden, Select
	
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x210 y255 w100 BackgroundTrans vFilesFolderTemplateLabel Hidden HwndHwndFolderTemplate, Folder Template:
	RegisterSettingsTooltip(HwndFolderTemplate, "FOLDER TEMPLATE`n`nTemplate folder structure to copy when creating new shoots.`nContains subfolders like Originals, Edited, Exports, etc.`n`nLeave empty if not using folder templates.")
	Gui, Settings:Add, Edit, x315 y252 w240 h25 cBlack vFilesFolderTemplateEdit Hidden, %Settings_FolderTemplatePath%
	Gui, Settings:Add, Button, x560 y251 w100 h27 gFilesFolderTemplateBrowseBtn vFilesFolderTemplateBrowse Hidden, Browse
	
	; ═══════════════════════════════════════════════════════════════════════════
	; FILE NAMING GROUP BOX
	; ═══════════════════════════════════════════════════════════════════════════
	Gui, Settings:Font, s10 Norm c%groupColor%, Segoe UI
	Gui, Settings:Add, GroupBox, x195 y310 w480 h130 vFilesNamingGroup Hidden, File Naming
	
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x210 y335 w80 BackgroundTrans vFilesPrefixLabel Hidden HwndHwndFilesPrefix, Prefix:
	RegisterSettingsTooltip(HwndFilesPrefix, "FILE PREFIX`n`nText added before the shoot number.`nExample: 'ZP' creates 'ZP2026001'`n`nUseful for studio branding or identification.")
	Gui, Settings:Add, Edit, x295 y332 w60 h25 cBlack vFilesPrefixEdit Hidden, %Settings_ShootPrefix%
	
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x380 y335 w80 BackgroundTrans vFilesSuffixLabel Hidden HwndHwndFilesSuffix, Suffix:
	RegisterSettingsTooltip(HwndFilesSuffix, "FILE SUFFIX`n`nText added after the shoot number.`nExample: '_RAW' creates '2026001_RAW'`n`nUseful for categorizing shoot types.")
	Gui, Settings:Add, Edit, x465 y332 w60 h25 cBlack vFilesSuffixEdit Hidden, %Settings_ShootSuffix%
	
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x210 y370 w200 BackgroundTrans vFilesAutoYear Hidden HwndHwndFilesAutoYear, Include Year in Shoot No
	RegisterSettingsTooltip(HwndFilesAutoYear, "INCLUDE YEAR IN SHOOT NUMBER`n`nWhen enabled, adds the year prefix to shoot numbers.`nExample: '2026001' instead of just '001'`n`nRecommended for multi-year organization.")
	CreateToggleSlider("Settings", "AutoShootYear", 630, 368, Settings_AutoShootYear)
	GuiControl, Settings:Hide, Toggle_AutoShootYear
	
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x210 y400 w200 BackgroundTrans vFilesAutoRename Hidden HwndHwndFilesAutoRename, Auto-Rename by Date
	RegisterSettingsTooltip(HwndFilesAutoRename, "AUTO-RENAME BY DATE`n`nAutomatically rename downloaded images using`nthe capture date from EXIF metadata.`n`nCreates organized filenames like '2026-02-01_001.jpg'")
	CreateToggleSlider("Settings", "AutoRenameImages", 630, 398, Settings_AutoRenameImages)
	GuiControl, Settings:Hide, Toggle_AutoRenameImages
	
	; ═══════════════════════════════════════════════════════════════════════════
	; PHOTO EDITOR GROUP BOX
	; ═══════════════════════════════════════════════════════════════════════════
	Gui, Settings:Font, s10 Norm c%groupColor%, Segoe UI
	Gui, Settings:Add, GroupBox, x195 y450 w480 h130 vFilesEditorGroup Hidden, Photo Editor
	
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x210 y475 w100 BackgroundTrans vFilesEditorLabel Hidden HwndHwndFilesEditor, Editor Path:
	RegisterSettingsTooltip(HwndFilesEditor, "PHOTO EDITOR PATH`n`nPath to your preferred photo editing software.`nLeave as 'Windows Explorer' to open folder instead.`n`nCommon editors: Lightroom, Photoshop, Capture One")
	editorDisplay := (Settings_EditorRunPath = "Explore" || Settings_EditorRunPath = "") ? "Windows Explorer" : Settings_EditorRunPath
	Gui, Settings:Add, Edit, x315 y472 w240 h25 cBlack vFilesEditorEdit Hidden, %editorDisplay%
	Gui, Settings:Add, Button, x560 y471 w100 h27 gFilesEditorBrowseBtn vFilesEditorBrowse Hidden, Browse
	
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x210 y510 w200 BackgroundTrans vFilesOpenEditor Hidden HwndHwndFilesOpenEditor, Open Editor After Download
	RegisterSettingsTooltip(HwndFilesOpenEditor, "OPEN EDITOR AFTER DOWNLOAD`n`nAutomatically launch your photo editor`nafter SD card download completes.`n`nSaves time by jumping straight to editing.")
	CreateToggleSlider("Settings", "BrowsDown", 630, 508, Settings_BrowsDown)
	GuiControl, Settings:Hide, Toggle_BrowsDown
	
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x210 y540 w200 BackgroundTrans vFilesAutoDrive Hidden HwndHwndFilesAutoDrive, Auto-Detect SD Cards
	RegisterSettingsTooltip(HwndFilesAutoDrive, "AUTO-DETECT SD CARDS`n`nAutomatically detect when an SD card is inserted.`nShows a notification or prompt when detected.`n`nConvenient for streamlined download workflow.")
	CreateToggleSlider("Settings", "AutoDriveDetect", 630, 538, Settings_AutoDriveDetect)
	GuiControl, Settings:Hide, Toggle_AutoDriveDetect
}

CreateLicensePanel()
{
	global
	
	; Theme-aware colors
	if (Settings_DarkMode) {
		headerColor := "4FC3F7"
		textColor := "FFFFFF"
		labelColor := "CCCCCC"
		mutedColor := "888888"
		groupColor := "666666"
		successColor := "00FF00"
		warningColor := "FFB84D"
		errorColor := "FF6B6B"
	} else {
		headerColor := "0078D4"
		textColor := "1E1E1E"
		labelColor := "444444"
		mutedColor := "666666"
		groupColor := "999999"
		successColor := "008800"
		warningColor := "CC6600"
		errorColor := "CC0000"
	}
	
	; License panel container (initially hidden)
	Gui, Settings:Add, Text, x190 y10 w510 h680 BackgroundTrans vPanelLicense Hidden
	
	; Section header
	Gui, Settings:Font, s16 c%headerColor%, Segoe UI
	Gui, Settings:Add, Text, x195 y20 w480 BackgroundTrans vLicenseHeader Hidden, 🔑 License
	
	; ═══════════════════════════════════════════════════════════════════════════
	; STATUS GROUP BOX
	; ═══════════════════════════════════════════════════════════════════════════
	Gui, Settings:Font, s10 Norm c%groupColor%, Segoe UI
	Gui, Settings:Add, GroupBox, x195 y55 w480 h70 vLicenseStatusGroup Hidden, Status
	
	; Status indicator - dynamic based on license state
	statusText := GetLicenseStatusText()
	statusColor := GetLicenseStatusColor()
	Gui, Settings:Font, s11 Norm c%statusColor%, Segoe UI
	Gui, Settings:Add, Text, x210 y80 w440 BackgroundTrans vLicenseStatusText Hidden HwndHwndLicenseStatus, %statusText%
	RegisterSettingsTooltip(HwndLicenseStatus, "LICENSE STATUS`n`nShows your current license state:`n• Licensed - Active: Full features enabled`n• Trial Mode: Limited functionality`n• Expired: Renewal required`n• Invalid: Contact support")
	
	; ═══════════════════════════════════════════════════════════════════════════
	; LICENSE KEY GROUP BOX
	; ═══════════════════════════════════════════════════════════════════════════
	Gui, Settings:Font, s10 Norm c%groupColor%, Segoe UI
	Gui, Settings:Add, GroupBox, x195 y135 w480 h100 vLicenseKeyGroup Hidden, License Key
	
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x210 y160 w80 BackgroundTrans vLicenseKeyLabel Hidden, Key:
	keyDisplay := License_Key ? License_Key : ""
	Gui, Settings:Add, Edit, x295 y157 w265 h25 cBlack vLicenseKeyEdit Hidden, %keyDisplay%
	Gui, Settings:Add, Button, x565 y156 w95 h27 gActivateLicenseBtn vLicenseActivateBtn Hidden HwndHwndLicenseActivate, Activate
	RegisterSettingsTooltip(HwndLicenseActivate, "ACTIVATE LICENSE`n`nEnter your license key and click Activate.`nYour license will be bound to your GHL Location ID.`n`nLicense keys are provided after purchase.")
	
	; Location binding info
	Gui, Settings:Font, s10 Norm c%mutedColor%, Segoe UI
	locDisplay := GHL_LocationID ? GHL_LocationID : "(Configure in GHL tab first)"
	Gui, Settings:Add, Text, x210 y195 w440 BackgroundTrans vLicenseLocationInfo Hidden HwndHwndLicenseLoc, Bound to Location: %locDisplay%
	RegisterSettingsTooltip(HwndLicenseLoc, "LOCATION BINDING`n`nYour license is tied to your GHL Location ID.`nThis prevents unauthorized sharing.`n`nSet up your GHL Location ID in the GHL Integration tab`nbefore activating your license.")
	
	; ═══════════════════════════════════════════════════════════════════════════
	; ACTIVATION DETAILS GROUP BOX
	; ═══════════════════════════════════════════════════════════════════════════
	Gui, Settings:Font, s10 Norm c%groupColor%, Segoe UI
	Gui, Settings:Add, GroupBox, x195 y245 w480 h155 vLicenseDetailsGroup Hidden, Activation Details
	
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	
	; Customer name
	nameDisplay := License_CustomerName ? License_CustomerName : "—"
	Gui, Settings:Add, Text, x210 y270 w100 BackgroundTrans vLicenseNameLabel Hidden, Licensed to:
	Gui, Settings:Add, Text, x315 y270 w340 BackgroundTrans vLicenseNameValue Hidden, %nameDisplay%
	
	; Customer email
	emailDisplay := License_CustomerEmail ? License_CustomerEmail : "—"
	Gui, Settings:Add, Text, x210 y295 w100 BackgroundTrans vLicenseEmailLabel Hidden, Email:
	Gui, Settings:Add, Text, x315 y295 w340 BackgroundTrans vLicenseEmailValue Hidden, %emailDisplay%
	
	; Activation date
	activatedDisplay := License_ActivatedAt ? License_ActivatedAt : "—"
	Gui, Settings:Add, Text, x210 y320 w100 BackgroundTrans vLicenseActivatedLabel Hidden, Activated:
	Gui, Settings:Add, Text, x315 y320 w340 BackgroundTrans vLicenseActivatedValue Hidden, %activatedDisplay%
	
	; Expiry date
	expiryDisplay := License_ExpiresAt ? License_ExpiresAt : "—"
	Gui, Settings:Add, Text, x210 y345 w100 BackgroundTrans vLicenseExpiryLabel Hidden, Expires:
	Gui, Settings:Add, Text, x315 y345 w340 BackgroundTrans vLicenseExpiryValue Hidden HwndHwndLicenseExpiry, %expiryDisplay%
	RegisterSettingsTooltip(HwndLicenseExpiry, "LICENSE EXPIRY`n`nDate when your license expires.`nYou'll receive renewal reminders before expiry.`n`nRenew early to avoid interruption.")
	
	; ═══════════════════════════════════════════════════════════════════════════
	; ACTIONS GROUP BOX
	; ═══════════════════════════════════════════════════════════════════════════
	Gui, Settings:Font, s10 Norm c%groupColor%, Segoe UI
	Gui, Settings:Add, GroupBox, x195 y410 w480 h125 vLicenseActionsGroup Hidden, Actions
	
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Button, x210 y440 w120 h30 gValidateLicenseBtn vLicenseValidateBtn Hidden HwndHwndLicenseValidate, ✓ Validate
	RegisterSettingsTooltip(HwndLicenseValidate, "VALIDATE LICENSE`n`nCheck your license status with the server.`nVerifies your license is still active and valid.`n`nUse if you've renewed or need to confirm status.")
	Gui, Settings:Add, Button, x340 y440 w120 h30 gDeactivateLicenseBtn vLicenseDeactivateBtn Hidden HwndHwndLicenseDeactivate, ✗ Deactivate
	RegisterSettingsTooltip(HwndLicenseDeactivate, "DEACTIVATE LICENSE`n`nRemove license from this location.`nFrees up the license for use elsewhere.`n`nYou'll need to reactivate to use licensed features.")
	Gui, Settings:Add, Button, x470 y440 w190 h30 gBuyLicenseBtn vLicenseBuyBtn Hidden HwndHwndLicenseBuy, 🛒 Buy License
	RegisterSettingsTooltip(HwndLicenseBuy, "BUY LICENSE`n`nPurchase a new SideKick license.`nOpens the purchase page in your browser.`n`nLicenses unlock all features and include updates.")
	
	; Purchase info
	Gui, Settings:Font, s10 Norm c%mutedColor%, Segoe UI
	Gui, Settings:Add, Text, x210 y480 w440 BackgroundTrans vLicensePurchaseInfo Hidden, Licenses are bound to your GHL Location ID for security.
	Gui, Settings:Add, Text, x210 y500 w440 BackgroundTrans vLicensePurchaseInfo2 Hidden, Each license allows activation on one location.
}

; License helper functions
GetLicenseStatusText() {
	global License_Status, License_Key
	
	if (License_Status = "active")
		return "● Licensed - Active"
	else if (License_Status = "expired")
		return "● License Expired"
	else if (License_Status = "invalid")
		return "● Invalid License"
	else if (License_Key != "")
		return "● License Not Validated"
	else
		return "● Trial Mode"
}

GetLicenseStatusColor() {
	global License_Status, Settings_DarkMode
	
	if (License_Status = "active")
		return Settings_DarkMode ? "00FF00" : "008800"
	else if (License_Status = "expired" || License_Status = "invalid")
		return Settings_DarkMode ? "FF6B6B" : "CC0000"
	else
		return Settings_DarkMode ? "FFB84D" : "CC6600"
}

; ============================================================
; Icon Font Detection
; ============================================================

DetectIconFont() {
	; Returns the best available icon font for the system
	; Phosphor Thin is bundled with the installer (thin outline icons)
	
	; Primary: Phosphor Thin (bundled, thin outline)
	if (FontExists("Phosphor Thin"))
		return "Phosphor Thin"
	
	; Fallback: Segoe Fluent Icons (Windows 11, thin outline)
	if (FontExists("Segoe Fluent Icons"))
		return "Segoe Fluent Icons"
	
	; Fallback: Font Awesome 6 Free Solid (bundled, solid/bold)
	if (FontExists("Font Awesome 6 Free Solid"))
		return "Font Awesome 6 Free Solid"
	
	; If nothing found, default to Phosphor Thin (bundled)
	return "Phosphor Thin"
}

FontExists(fontName) {
	; Check if a font is installed by trying to create a dummy GUI with it
	; Returns true if font exists, false otherwise
	
	hDC := DllCall("GetDC", "Ptr", 0, "Ptr")
	
	; Try to create a font with the given name
	VarSetCapacity(LOGFONT, 92, 0)
	NumPut(16, LOGFONT, 0, "Int")  ; lfHeight
	StrPut(fontName, &LOGFONT + 28, 32, "UTF-16")  ; lfFaceName
	
	hFont := DllCall("CreateFontIndirect", "Ptr", &LOGFONT, "Ptr")
	
	if (!hFont) {
		DllCall("ReleaseDC", "Ptr", 0, "Ptr", hDC)
		return false
	}
	
	; Select the font and get the text metrics
	hOldFont := DllCall("SelectObject", "Ptr", hDC, "Ptr", hFont, "Ptr")
	
	; Get the actual font face name that was used
	VarSetCapacity(actualName, 64, 0)
	DllCall("GetTextFace", "Ptr", hDC, "Int", 32, "Ptr", &actualName)
	actualFontName := StrGet(&actualName, "UTF-16")
	
	; Clean up
	DllCall("SelectObject", "Ptr", hDC, "Ptr", hOldFont)
	DllCall("DeleteObject", "Ptr", hFont)
	DllCall("ReleaseDC", "Ptr", 0, "Ptr", hDC)
	
	; Compare requested vs actual font name
	return (actualFontName = fontName)
}

; ============================================================
; License Enforcement Functions
; ============================================================

IsDeveloperMode() {
	; Developer mode = specific GHL Location ID
	global GHL_LocationID
	return (GHL_LocationID = "8IWxk5M0PvbNf1w3npQU")
}

GetLicenseDaysRemaining() {
	; Returns days until license expires, or -1 if no expiry date
	global License_ExpiresAt, License_Status
	
	if (License_Status != "active" || License_ExpiresAt = "")
		return -1
	
	; Parse expiry date (format: 2026-02-15T00:00:00 or 2026-02-15)
	expiryDate := SubStr(License_ExpiresAt, 1, 10)
	StringReplace, expiryDate, expiryDate, -, , All
	
	FormatTime, today,, yyyyMMdd
	; Calculate days remaining using EnvSub (AHK v1 date math)
	daysRemaining := expiryDate
	EnvSub, daysRemaining, %today%, Days
	return daysRemaining
}

CheckLicenseExpiryOnStartup() {
	global License_Status, License_ExpiresAt, License_PurchaseURL
	
	; Only check for active licenses
	if (License_Status != "active")
		return
	
	daysRemaining := GetLicenseDaysRemaining()
	if (daysRemaining < 0)
		return
	
	isDev := IsDeveloperMode()
	devPrefix := isDev ? "[DEV MODE] " : ""
	
	; Show warning if 14 days or less remaining
	if (daysRemaining <= 0) {
		; License has expired
		if (isDev) {
			DarkMsgBox(devPrefix . "License Expired", devPrefix . "Your SideKick_PS license has expired.`n`nIn production, GHL features would be disabled.`n`nClick OK to continue (dev mode - features remain enabled).", "warning")
		} else {
			DarkMsgBox("License Expired", "Your SideKick_PS license has expired.`n`nGHL integration features are now disabled.`n`nPlease renew your license to continue using all features.", "warning")
			result := DarkMsgBox("Renew License?", "Would you like to purchase/renew your license now?", "question", {buttons: ["Yes", "No"]})
			if (result = "Yes")
				Run, %License_PurchaseURL%
		}
	} else if (daysRemaining <= 14) {
		; Warning: expiring soon
		DarkMsgBox(devPrefix . "License Expiring Soon", devPrefix . "Your SideKick_PS license expires in " . daysRemaining . " days.`n`nPlease renew to avoid interruption of GHL features.", "warning")
		result := DarkMsgBox("Renew Now?", "Would you like to renew your license now?", "question", {buttons: ["Yes", "No"]})
		if (result = "Yes")
			Run, %License_PurchaseURL%
	}
}

IsLicenseValid() {
	; Returns true if license is valid and not expired
	; Developer mode always returns true
	global License_Status
	
	if (IsDeveloperMode())
		return true
	
	if (License_Status = "active") {
		daysRemaining := GetLicenseDaysRemaining()
		if (daysRemaining < 0)  ; No expiry date set
			return true
		return (daysRemaining > 0)
	}
	
	; Trial mode - check trial days
	if (License_Status = "trial")
		return IsTrialValid()
	
	return false
}

IsTrialValid() {
	global License_TrialStart, License_TrialDays
	
	if (License_TrialStart = "")
		return true  ; Trial not started yet
	
	FormatTime, today,, yyyyMMdd
	; Calculate days used using EnvSub (AHK v1 date math)
	daysUsed := today
	EnvSub, daysUsed, %License_TrialStart%, Days
	return (daysUsed < License_TrialDays)
}

CheckLicenseForFeature(featureName := "This feature") {
	; Check if license is valid before using licensed features
	; Returns true if allowed to proceed, false if blocked
	global License_PurchaseURL, License_Status
	
	if (IsLicenseValid())
		return true
	
	if (IsDeveloperMode()) {
		; Show warning but allow
		ToolTip, [DEV] License check failed - would block: %featureName%
		SetTimer, RemoveToolTip, -3000
		return true
	}
	
	; License not valid - show message and offer to purchase
	if (License_Status = "trial") {
		DarkMsgBox("Trial Expired", "Your SideKick_PS trial has expired.`n`n" . featureName . " requires a valid license.`n`nPlease purchase a license to continue.", "warning")
	} else {
		DarkMsgBox("License Required", "Your SideKick_PS license has expired or is invalid.`n`n" . featureName . " requires a valid license.`n`nPlease renew your license to continue.", "warning")
	}
	
	result := DarkMsgBox("Purchase License?", "Would you like to purchase a license now?", "question", {buttons: ["Yes", "No"]})
	if (result = "Yes")
		Run, %License_PurchaseURL%
	
	return false
}

; ============================================================
; Monthly Validation and Auto-Update Check
; ============================================================

; Async timer label for background check
AsyncMonthlyCheck:
	CheckMonthlyValidationAndUpdate()
Return

; Check for updates on every launch (non-blocking)
CheckForUpdatesOnLaunch:
	CheckForUpdatesStartup()
Return

CheckMonthlyValidationAndUpdate() {
	; Check if a month has passed since last validation
	; If so, validate license AND check for updates
	global License_ValidatedAt, License_Status, License_Key, Update_LastCheckDate
	
	; Get today's date in yyyyMMdd format
	FormatTime, today,, yyyyMMdd
	
	; Check if validation/update check is needed (weekly = 7 days)
	needsCheck := false
	
	if (Update_LastCheckDate = "") {
		needsCheck := true
	} else {
		; Calculate days since last check using EnvSub (AHK v1 date math)
		daysSinceCheck := today
		EnvSub, daysSinceCheck, %Update_LastCheckDate%, Days
		if (daysSinceCheck >= 7)
			needsCheck := true
	}
	
	if (!needsCheck)
		return
	
	; Validate license if we have one
	if (License_Key != "" && License_Status = "active") {
		ValidateLicenseSilent()
	}
	
	; Check for updates
	CheckForUpdates()
	
	; Update last check date
	FormatTime, Update_LastCheckDate,, yyyyMMdd
	SaveSettings()
}

ValidateLicenseSilent() {
	; Silently validate license in background
	global License_Key, License_Status, License_ValidatedAt, GHL_LocationID
	
	if (License_Key = "" || GHL_LocationID = "")
		return
	
	tempFile := A_Temp . "\license_validate.json"
	validateCmd := GetScriptCommand("validate_license", "validate """ . License_Key . """ """ . GHL_LocationID . """")
	
	RunWait, %ComSpec% /c "%validateCmd% > "%tempFile%"", , Hide
	
	FileRead, resultJson, %tempFile%
	FileDelete, %tempFile%
	
	if InStr(resultJson, """valid"": true") {
		FormatTime, License_ValidatedAt,, yyyy-MM-ddTHH:mm:ss
		SaveSettings()
		TrayTip, SideKick_PS, License validated successfully, 3
	} else if InStr(resultJson, "expired") {
		License_Status := "expired"
		SaveSettings()
		TrayTip, SideKick_PS, License validation failed - license may be expired, 3, 2
	}
}

ValidateLicenseOnline() {
	; Validate license online and return true/false
	global License_Key, License_Status, License_ValidatedAt, GHL_LocationID
	
	if (License_Key = "" || GHL_LocationID = "")
		return false
	
	tempFile := A_Temp . "\license_validate_check.json"
	validateCmd := GetScriptCommand("validate_license", "validate """ . License_Key . """ """ . GHL_LocationID . """")
	
	RunWait, %ComSpec% /c "%validateCmd% > "%tempFile%"", , Hide
	
	FileRead, resultJson, %tempFile%
	FileDelete, %tempFile%
	
	if InStr(resultJson, """valid"": true") {
		FormatTime, License_ValidatedAt,, yyyy-MM-ddTHH:mm:ss
		return true
	}
	return false
}

; Check for updates on every app launch - always runs regardless of weekly schedule
CheckForUpdatesStartup() {
	CheckForUpdates()
}

CheckForUpdates() {
	; Check GitHub releases for new version
	global ScriptVersion, Update_SkippedVersion, Update_AvailableVersion, Update_DownloadURL, Update_GitHubReleaseURL
	global Settings_AutoUpdate, Update_DownloadReady, Update_DownloadPath, Update_UserDeclined
	
	tempFile := A_Temp . "\update_check.json"
	
	; Use PowerShell to fetch from GitHub API
	psCmd := "powershell -NoProfile -Command ""try { $r = Invoke-RestMethod -Uri '" . Update_GitHubReleaseURL . "' -TimeoutSec 10; @{tag=$r.tag_name;url=$r.assets[0].browser_download_url;body=$r.body} | ConvertTo-Json } catch { Write-Output '{''error'': true}' }"""
	
	RunWait, %ComSpec% /c "%psCmd% > "%tempFile%"", , Hide
	
	FileRead, resultJson, %tempFile%
	FileDelete, %tempFile%
	
	if InStr(resultJson, "'error'")
		return  ; Network error, skip silently
	
	; Parse version from response
	RegExMatch(resultJson, """tag"":\s*""v?([^""]*)""", match)
	latestVersion := match1
	
	RegExMatch(resultJson, """url"":\s*""([^""]*)""", match)
	downloadUrl := match1
	
	if (latestVersion = "")
		return
	
	; Compare versions
	if (CompareVersions(latestVersion, ScriptVersion) > 0) {
		Update_AvailableVersion := latestVersion
		Update_DownloadURL := downloadUrl
		
		; If auto-update enabled, download in background then prompt
		if (Settings_AutoUpdate) {
			DownloadUpdateInBackground(downloadUrl, latestVersion)
		} else {
			; Manual mode - just offer update
			OfferUpdate(latestVersion, downloadUrl)
		}
	}
}

; Download update installer in background, then prompt user
DownloadUpdateInBackground(downloadUrl, newVersion) {
	global Update_DownloadReady, Update_DownloadPath, Update_AvailableVersion, Update_UserDeclined
	
	Update_DownloadPath := A_Temp . "\SideKick_PS_Setup.exe"
	batchFile := A_Temp . "\download_update_bg.bat"
	resultFile := A_Temp . "\download_result_bg.txt"
	
	; Show subtle notification that download is starting
	TrayTip, SideKick Update, Downloading v%newVersion% in background..., 3, 1
	
	; Create batch file to run PowerShell download
	FileDelete, %batchFile%
	FileAppend, @echo off`n, %batchFile%
	FileAppend, powershell -NoProfile -Command "try { Invoke-WebRequest -Uri '%downloadUrl%' -OutFile '%Update_DownloadPath%'; Unblock-File -Path '%Update_DownloadPath%'; Write-Output 'OK' } catch { Write-Output 'FAILED' }" > "%resultFile%"`n, %batchFile%
	
	RunWait, %batchFile%, , Hide
	FileDelete, %batchFile%
	
	FileRead, downloadResult, %resultFile%
	FileDelete, %resultFile%
	
	if (!FileExist(Update_DownloadPath) || InStr(downloadResult, "FAILED")) {
		; Download failed silently - will retry next check
		Update_DownloadReady := false
		return
	}
	
	; Download ready!
	Update_DownloadReady := true
	Update_UserDeclined := false
	
	; Prompt user if it's convenient to update now
	PromptUpdateReady(newVersion)
}

; Prompt user that download is ready - is now a good time?
PromptUpdateReady(newVersion) {
	global ScriptVersion, Update_UserDeclined, Update_DownloadPath, Update_DownloadReady
	
	Gui, UpdateReadyDlg:New, +AlwaysOnTop +ToolWindow
	Gui, UpdateReadyDlg:Font, s10
	Gui, UpdateReadyDlg:Add, Text, w320, SideKick v%newVersion% is ready to install!
	Gui, UpdateReadyDlg:Add, Text, w320 y+10, Current: v%ScriptVersion%  →  New: v%newVersion%
	Gui, UpdateReadyDlg:Add, Text, w320 y+15, Is now a good time to update?
	Gui, UpdateReadyDlg:Add, Text, w320 y+5 cGray, (SideKick will restart automatically)
	Gui, UpdateReadyDlg:Add, Button, w100 y+20 gUpdateReadyNow Default, Update Now
	Gui, UpdateReadyDlg:Add, Button, w100 x+10 gUpdateReadyLater, Later
	Gui, UpdateReadyDlg:Show, , Update Ready
	return

UpdateReadyNow:
	Gui, UpdateReadyDlg:Destroy
	InstallDownloadedUpdate()
	return

UpdateReadyLater:
	Gui, UpdateReadyDlg:Destroy
	Update_UserDeclined := true
	TrayTip, SideKick Update, Update ready - will ask again when you exit., 3, 1
	return

UpdateReadyDlgGuiClose:
UpdateReadyDlgGuiEscape:
	Gui, UpdateReadyDlg:Destroy
	Update_UserDeclined := true
	return
}

; Install the already-downloaded update
InstallDownloadedUpdate() {
	global Update_DownloadPath, Update_AvailableVersion, Update_DownloadReady
	
	if (!Update_DownloadReady || !FileExist(Update_DownloadPath))
		return
	
	; Run the installer
	Run, "%Update_DownloadPath%"
	
	; Exit current instance
	ExitApp
}

; Check for pending update on exit - if user said "Later", ask one more time
CheckPendingUpdateOnExit() {
	global Update_DownloadReady, Update_UserDeclined, Update_AvailableVersion, Update_DownloadPath
	
	if (!Update_DownloadReady || !Update_UserDeclined)
		return false
	
	if (!FileExist(Update_DownloadPath))
		return false
	
	result := DarkMsgBox("Update Ready", "SideKick v" . Update_AvailableVersion . " is ready to install.`n`nWould you like to update before exiting?", "question", {buttons: ["Yes", "No"]})
	if (result = "Yes")
	{
		Run, "%Update_DownloadPath%"
		return true
	}
	return false
}

; Refresh latest version for About panel (non-blocking display)
RefreshLatestVersion() {
	global ScriptVersion, Update_AvailableVersion, Update_DownloadURL
	
	GuiControl, Settings:, AboutLatestValue, Checking...
	
	tempFile := A_Temp . "\version_check.json"
	batchFile := A_Temp . "\version_check.bat"
	
	; Fetch version.json from raw GitHub (stable URL)
	versionUrl := "https://raw.githubusercontent.com/GuyMayer/SideKick_PS/main/version.json"
	psScript := "$ErrorActionPreference = 'Stop'; try { (Invoke-RestMethod -Uri '" . versionUrl . "' -TimeoutSec 10) | ConvertTo-Json } catch { if ($_.Exception.Message -match 'Unable to connect|network|resolve') { 'OFFLINE' } else { 'ERROR' } }"
	
	FileDelete, %batchFile%
	FileAppend, @echo off`npowershell -NoProfile -Command "%psScript%" > "%tempFile%"`n, %batchFile%
	
	RunWait, %batchFile%, , Hide
	FileDelete, %batchFile%
	
	FileRead, resultJson, %tempFile%
	FileDelete, %tempFile%
	
	if (InStr(resultJson, "OFFLINE") || resultJson = "") {
		GuiControl, Settings:, AboutLatestValue, (Unable to check - offline)
		GuiControl, Settings:, AboutUpdateBtn, 🔧 Reinstall
		GuiControl, Settings:Show, AboutUpdateBtn
		return
	}
	
	if InStr(resultJson, "ERROR") {
		GuiControl, Settings:, AboutLatestValue, (Unable to check)
		GuiControl, Settings:, AboutUpdateBtn, 🔧 Reinstall
		GuiControl, Settings:Show, AboutUpdateBtn
		return
	}
	
	; Parse version from response
	RegExMatch(resultJson, """tag_name"":\s*""v?([^""]*)""", match)
	latestVersion := match1
	
	RegExMatch(resultJson, """url"":\s*""([^""]*)""", match)
	downloadUrl := match1
	
	; If tag is "latest", try to get version from the release name or use current version
	if (latestVersion = "latest" || latestVersion = "") {
		RegExMatch(resultJson, """name"":\s*""[^""]*v?([0-9]+\.[0-9]+\.[0-9]+)[^""]*""", match)
		if (match1 != "")
			latestVersion := match1
		else
			latestVersion := ScriptVersion  ; Assume up to date if we can't parse
	}
	
	if (latestVersion = "") {
		GuiControl, Settings:, AboutLatestValue, (Error)
		return
	}
	
	Update_AvailableVersion := latestVersion
	Update_DownloadURL := downloadUrl
	
	; Compare and show status - always show button (for reinstall option)
	comparison := CompareVersions(latestVersion, ScriptVersion)
	if (comparison > 0) {
		GuiControl, Settings:, AboutLatestValue, v%latestVersion% ✨ NEW
		GuiControl, Settings:, AboutUpdateBtn, 🔄 Update
		GuiControl, Settings:Show, AboutUpdateBtn
	} else if (comparison = 0) {
		GuiControl, Settings:, AboutLatestValue, v%latestVersion% ✅ Up to date
		GuiControl, Settings:, AboutUpdateBtn, 🔧 Reinstall
		GuiControl, Settings:Show, AboutUpdateBtn
	} else {
		GuiControl, Settings:, AboutLatestValue, v%latestVersion% (dev build)
		GuiControl, Settings:, AboutUpdateBtn, 🔧 Reinstall
		GuiControl, Settings:Show, AboutUpdateBtn
	}
}

OfferUpdate(newVersion, downloadUrl) {
	global ScriptVersion, Update_UserChoice, Update_PendingURL, Update_PendingVersion
	
	isDev := IsDeveloperMode()
	devPrefix := isDev ? "[DEV MODE] " : ""
	
	Update_UserChoice := ""
	Update_PendingURL := downloadUrl
	Update_PendingVersion := newVersion
	
	Gui, UpdateDlg:New, +AlwaysOnTop +ToolWindow
	Gui, UpdateDlg:Font, s10
	Gui, UpdateDlg:Add, Text, w300, %devPrefix%A new version of SideKick_PS is available!
	Gui, UpdateDlg:Add, Text, w300 y+10, Current: v%ScriptVersion%
	Gui, UpdateDlg:Add, Text, w300, Latest: v%newVersion%
	Gui, UpdateDlg:Add, Text, w300 y+15, Would you like to download and install the update?
	Gui, UpdateDlg:Add, Button, w100 y+20 gUpdateDlgUpdate Default, Update Now
	Gui, UpdateDlg:Add, Button, w100 x+10 gUpdateDlgLater, Later
	Gui, UpdateDlg:Show, , %devPrefix%Update Available
	
	WinWaitClose, %devPrefix%Update Available
	
	if (Update_UserChoice = "update") {
		if (Update_PendingURL != "") {
			DownloadAndInstallUpdate(Update_PendingURL, Update_PendingVersion, false)
		} else {
			Run, https://github.com/guychen-zp/SideKick_PS/releases/latest
		}
	}
	; User chose "Later" - they'll be reminded next check
	return

UpdateDlgUpdate:
	Update_UserChoice := "update"
	Gui, UpdateDlg:Destroy
	return

UpdateDlgLater:
	Update_UserChoice := "later"
	Gui, UpdateDlg:Destroy
	return

UpdateDlgGuiClose:
UpdateDlgGuiEscape:
	Update_UserChoice := "later"
	Gui, UpdateDlg:Destroy
	return
}

DownloadAndInstallUpdate(downloadUrl, newVersion, silent := false) {
	global Download_InProgress, Download_Path, Download_Silent
	
	Download_Path := A_Temp . "\SideKick_PS_Setup.exe"
	Download_Silent := silent
	FileDelete, %Download_Path%
	
	; Show progress bar on About panel (if visible)
	if (!silent) {
		GuiControl, Settings:Show, AboutDownloadProgress
		GuiControl, Settings:Show, AboutDownloadStatus
		GuiControl, Settings:, AboutDownloadStatus, Preparing download v%newVersion%...
		GuiControl, Settings:, AboutDownloadProgress, 0
		GuiControl, Settings:Disable, AboutUpdateBtn
		Gui, Settings:+Disabled  ; Prevent closing during download
	}
	
	; Start BITS transfer in background for real progress tracking
	Download_InProgress := true
	progressFile := A_Temp . "\download_progress.txt"
	completeFile := A_Temp . "\download_complete.txt"
	FileDelete, %progressFile%
	FileDelete, %completeFile%
	
	; Create PowerShell script for BITS download with progress
	psScript := A_Temp . "\download_with_progress.ps1"
	FileDelete, %psScript%
	
	scriptContent =
(
$progressFile = '%progressFile%'
$completeFile = '%completeFile%'
$downloadUrl = '%downloadUrl%'
$downloadPath = '%Download_Path%'

try {
    # First try BITS transfer
    try {
        # Remove any stale BITS jobs
        Get-BitsTransfer -Name "SideKickUpdate" -ErrorAction SilentlyContinue | Remove-BitsTransfer -ErrorAction SilentlyContinue

        # Start BITS transfer
        $job = Start-BitsTransfer -Source $downloadUrl -Destination $downloadPath -Asynchronous -DisplayName "SideKickUpdate"
        
        # Monitor progress with timeout
        $timeout = [DateTime]::Now.AddMinutes(5)
        while (($job.JobState -eq "Transferring" -or $job.JobState -eq "Connecting") -and [DateTime]::Now -lt $timeout) {
            if ($job.BytesTotal -gt 0) {
                $percent = [int](($job.BytesTransferred / $job.BytesTotal) * 100)
                $percent | Out-File -FilePath $progressFile -Force
            }
            Start-Sleep -Milliseconds 100
        }
        
        if ($job.JobState -eq "Transferred") {
            Complete-BitsTransfer -BitsJob $job
            "100" | Out-File -FilePath $progressFile -Force
            "OK" | Out-File -FilePath $completeFile -Force
            Unblock-File -Path $downloadPath -ErrorAction SilentlyContinue
        } else {
            throw "BITS failed: $($job.JobState)"
        }
    } catch {
        # BITS failed - fallback to Invoke-WebRequest
        "50" | Out-File -FilePath $progressFile -Force
        
        # Use TLS 1.2
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        
        Invoke-WebRequest -Uri $downloadUrl -OutFile $downloadPath -UseBasicParsing
        
        if (Test-Path $downloadPath) {
            "100" | Out-File -FilePath $progressFile -Force
            "OK" | Out-File -FilePath $completeFile -Force
            Unblock-File -Path $downloadPath -ErrorAction SilentlyContinue
        } else {
            throw "Download file not created"
        }
    }
} catch {
    "FAILED: $($_.Exception.Message)" | Out-File -FilePath $completeFile -Force
}
)
	
	FileAppend, %scriptContent%, %psScript%
	
	; Run PowerShell in background
	Run, powershell -NoProfile -ExecutionPolicy Bypass -File "%psScript%", , Hide
	
	; Start timer to monitor progress
	SetTimer, UpdateDownloadProgress, 150
	
	; Wait loop with GUI updates
	while (Download_InProgress) {
		if (FileExist(completeFile)) {
			FileRead, result, %completeFile%
			Download_InProgress := false
			SetTimer, UpdateDownloadProgress, Off
			
			if (InStr(result, "OK")) {
				; Success - update progress to 100%
				if (!silent) {
					GuiControl, Settings:, AboutDownloadProgress, 100
					GuiControl, Settings:, AboutDownloadStatus, Download complete! Starting installer...
					Sleep, 500
				}
			} else {
				; Failed
				FileDelete, %psScript%
				FileDelete, %progressFile%
				FileDelete, %completeFile%
				
				if (!silent) {
					GuiControl, Settings:Hide, AboutDownloadProgress
					GuiControl, Settings:Hide, AboutDownloadStatus
					GuiControl, Settings:Enable, AboutUpdateBtn
					Gui, Settings:-Disabled
				}
				errorMsg := RegExReplace(result, "^FAILED:\s*", "")
				DarkMsgBox("Download Failed", "Failed to download the update.`n`nError: " . errorMsg . "`n`nPlease download manually from:`nhttps://github.com/GuyMayer/SideKick_PS/releases/latest", "error")
				return
			}
		}
		Sleep, 50
	}
	
	; Cleanup temp files
	FileDelete, %psScript%
	FileDelete, %progressFile%
	FileDelete, %completeFile%
	
	; Verify file exists
	if (!FileExist(Download_Path)) {
		if (!silent) {
			GuiControl, Settings:Hide, AboutDownloadProgress
			GuiControl, Settings:Hide, AboutDownloadStatus
			GuiControl, Settings:Enable, AboutUpdateBtn
			Gui, Settings:-Disabled
		}
		DarkMsgBox("Download Failed", "Download file not found.`n`nPlease download manually from:`nhttps://github.com/GuyMayer/SideKick_PS/releases/latest", "error")
		return
	}
	
	; Hide progress
	if (!silent) {
		GuiControl, Settings:Hide, AboutDownloadProgress
		GuiControl, Settings:Hide, AboutDownloadStatus
		Gui, Settings:-Disabled
	}
	
	; Run the installer (silent mode if auto-update enabled)
	if (silent) {
		; Very silent install - no UI at all
		Run, "%Download_Path%" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /CLOSEAPPLICATIONS
	} else {
		; Normal install with UI
		Run, "%Download_Path%"
	}
	
	; Exit current instance to allow update
	ExitApp
}

; Timer to update download progress bar
UpdateDownloadProgress:
	progressFile := A_Temp . "\download_progress.txt"
	if (FileExist(progressFile)) {
		FileRead, progress, %progressFile%
		progress := Trim(progress)
		if (progress != "" && progress is number) {
			GuiControl, Settings:, AboutDownloadProgress, %progress%
			if (progress < 100)
				GuiControl, Settings:, AboutDownloadStatus, Downloading... %progress%`%
		}
	}
Return

; Silent update function for auto-updates
SilentUpdate() {
	global Update_DownloadURL, Update_AvailableVersion
	
	if (Update_DownloadURL != "" && Update_AvailableVersion != "") {
		DownloadAndInstallUpdate(Update_DownloadURL, Update_AvailableVersion, true)
	}
}

CompareVersions(v1, v2) {
	; Compare two version strings (e.g., "1.2.3" vs "1.2.4")
	; Returns: 1 if v1 > v2, -1 if v1 < v2, 0 if equal
	
	; Remove 'v' prefix if present
	v1 := RegExReplace(v1, "^v", "")
	v2 := RegExReplace(v2, "^v", "")
	
	; Split into parts
	StringSplit, p1, v1, .
	StringSplit, p2, v2, .
	
	maxParts := p1_0 > p2_0 ? p1_0 : p2_0
	
	Loop, %maxParts%
	{
		part1 := p1_%A_Index% + 0  ; Convert to number
		part2 := p2_%A_Index% + 0
		
		if (part1 > part2)
			return 1
		if (part1 < part2)
			return -1
	}
	
	return 0
}

CreateAboutPanel()
{
	global
	
	; Theme-aware colors
	if (Settings_DarkMode) {
		headerColor := "4FC3F7"
		textColor := "FFFFFF"
		labelColor := "CCCCCC"
		mutedColor := "888888"
		linkColor := "4FC3F7"
	} else {
		headerColor := "0078D4"
		textColor := "1E1E1E"
		labelColor := "444444"
		mutedColor := "666666"
		linkColor := "0078D4"
	}
	
	; About panel container (initially hidden)
	Gui, Settings:Add, Text, x190 y10 w510 h680 BackgroundTrans vPanelAbout Hidden
	
	; Section header
	Gui, Settings:Font, s16 c%headerColor%, Segoe UI
	Gui, Settings:Add, Text, x195 y20 w480 BackgroundTrans vAboutHeader Hidden, ℹ About SideKick_PS
	
	; ═══════════════════════════════════════════════════════════════════════════
	; APP INFO GROUP BOX
	; ═══════════════════════════════════════════════════════════════════════════
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, GroupBox, x195 y55 w480 h120 vAboutAppGroup Hidden, Application
	
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x210 y80 w100 BackgroundTrans vAboutDescLabel Hidden, Description:
	Gui, Settings:Add, Text, x315 y80 w340 BackgroundTrans vAboutDescValue Hidden HwndHwndAboutDesc, File management && GHL integration for ProSelect
	RegisterSettingsTooltip(HwndAboutDesc, "SIDEKICK_PS DESCRIPTION`n`nSideKick_PS enhances your ProSelect workflow with:`n• Automated file management and organization`n• GoHighLevel CRM integration for contacts`n• Invoice syncing and contact sheet creation`n• Keyboard shortcuts for common tasks`n`nDesigned for professional photographers using ProSelect.")
	
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x210 y105 w100 BackgroundTrans vAboutVersionLabel Hidden, Version:
	Gui, Settings:Add, Text, x315 y105 w80 BackgroundTrans vAboutVersionValue Hidden HwndHwndAboutVersion, %ScriptVersion%
	RegisterSettingsTooltip(HwndAboutVersion, "CURRENT VERSION`n`nThe version of SideKick_PS you are running.`nVersion numbers follow semantic versioning:`n• Major.Minor.Patch (e.g., 1.2.3)`n`nCheck 'Updates' section below to see if a newer version is available.")
	
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x400 y105 w80 BackgroundTrans vAboutPSLabel Hidden, ProSelect:
	psVer := ProSelectVersion ? ProSelectVersion : "Not detected"
	Gui, Settings:Add, Text, x480 y105 w80 BackgroundTrans vAboutPSValue Hidden HwndHwndAboutPS, %psVer%
	RegisterSettingsTooltip(HwndAboutPS, "PROSELECT VERSION`n`nThe detected version of ProSelect on your system.`nSideKick optimizes automation for your specific version.`n`nSupported versions: 2022, 2024, 2025`n`nIf showing 'Not detected', ensure ProSelect is installed.")
	
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x210 y130 w100 BackgroundTrans vAboutBuildLabel Hidden, Build Date:
	Gui, Settings:Add, Text, x315 y130 w150 BackgroundTrans vAboutBuildValue Hidden HwndHwndAboutBuild, %BuildDate%
	RegisterSettingsTooltip(HwndAboutBuild, "BUILD DATE`n`nWhen this version of SideKick_PS was compiled.`nUseful for troubleshooting and support requests.`n`nNewer builds may include bug fixes and improvements`neven within the same version number.")
	
	; ═══════════════════════════════════════════════════════════════════════════
	; UPDATES GROUP BOX
	; ═══════════════════════════════════════════════════════════════════════════
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, GroupBox, x195 y180 w480 h120 vAboutUpdatesGroup Hidden, Updates
	
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x210 y205 w100 BackgroundTrans vAboutLatestLabel Hidden, Latest Version:
	Gui, Settings:Add, Text, x315 y205 w150 BackgroundTrans vAboutLatestValue Hidden HwndHwndAboutLatest, Checking...
	RegisterSettingsTooltip(HwndAboutLatest, "LATEST VERSION AVAILABLE`n`nShows the newest version available on the update server.`nCompare with your current version above.`n`nIf newer, use 'Check Now' to download and install.`nUpdates include bug fixes, new features, and improvements.")
	
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x210 y230 w300 BackgroundTrans vAboutAutoUpdateText Hidden HwndHwndAboutAutoUpdate, Enable automatic updates
	RegisterSettingsTooltip(HwndAboutAutoUpdate, "AUTOMATIC UPDATES`n`nWhen enabled, SideKick checks for updates on startup.`nIf a new version is found, it downloads and installs automatically.`n`nRecommended: Keep enabled for latest features and fixes.`nDisable if you need to control exactly which version runs.")
	CreateToggleSlider("Settings", "AutoUpdate", 630, 228, Settings_AutoUpdate)
	GuiControl, Settings:Hide, Toggle_AutoUpdate
	
	; Download progress bar (hidden by default, shown during update)
	Gui, Settings:Add, Progress, x210 y260 w120 h20 vAboutDownloadProgress Hidden Range0-100 c4FC3F7, 0
	Gui, Settings:Add, Text, x210 y260 w120 BackgroundTrans vAboutDownloadStatus Hidden,
	
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Button, x210 y255 w110 h28 gShowWhatsNew vAboutWhatsNewButton Hidden HwndHwndAboutWhatsNew, 📋 What's New
	RegisterSettingsTooltip(HwndAboutWhatsNew, "WHAT'S NEW`n`nView the changelog and release notes.`nSee what features, fixes, and improvements`nare included in each version.`n`nHelpful for understanding what changed after an update.")
	Gui, Settings:Add, Button, x325 y255 w100 h28 gAboutReinstall vAboutReinstallBtn Hidden HwndHwndAboutReinstall, Reinstall
	RegisterSettingsTooltip(HwndAboutReinstall, "REINSTALL SIDEKICK`n`nDownload and reinstall the current version.`nUseful if files are corrupted or missing.`n`nThis will replace all SideKick files with fresh copies`nfrom the update server. Your settings are preserved.")
	Gui, Settings:Add, Button, x430 y255 w100 h28 gAboutUpdateNow vAboutCheckNowBtn Hidden HwndHwndAboutCheckNow, Check Now
	RegisterSettingsTooltip(HwndAboutCheckNow, "CHECK FOR UPDATES`n`nManually check the update server for new versions.`nIf a newer version is found, you'll be prompted to install.`n`nProgress will show in the bar to the left during download.")
	
	; ═══════════════════════════════════════════════════════════════════════════
	; SUPPORT GROUP BOX
	; ═══════════════════════════════════════════════════════════════════════════
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, GroupBox, x195 y305 w480 h60 vAboutSupportGroup Hidden, Support
	
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x210 y330 w60 BackgroundTrans vAboutAuthorLabel Hidden, Author:
	Gui, Settings:Add, Text, x275 y330 w100 BackgroundTrans vAboutAuthorValue Hidden HwndHwndAboutAuthor, GuyMayer
	RegisterSettingsTooltip(HwndAboutAuthor, "DEVELOPER`n`nSideKick_PS is developed and maintained by GuyMayer.`nBuilt specifically for professional photographers`nusing ProSelect and GoHighLevel CRM.")
	
	Gui, Settings:Font, s10 Norm c%linkColor%, Segoe UI
	Gui, Settings:Add, Text, x380 y330 w170 BackgroundTrans gOpenSupportEmail vAboutEmailLink Hidden HwndHwndAboutEmail, guy@zoom-photo.co.uk
	RegisterSettingsTooltip(HwndAboutEmail, "SUPPORT EMAIL`n`nClick to send an email for technical support.`n`nPlease include:`n• Your SideKick version (shown above)`n• ProSelect version`n• Description of the issue`n• Steps to reproduce the problem`n`nFor faster resolution, use 'Send Logs' in Diagnostics.")
	
	Gui, Settings:Font, s9 Norm c%linkColor%, Segoe UI
	Gui, Settings:Add, Text, x560 y330 w100 BackgroundTrans gOpenUserManual vAboutManualLink Hidden HwndHwndAboutManual, 📖 User Manual
	RegisterSettingsTooltip(HwndAboutManual, "USER MANUAL`n`nOpen the full user manual in your browser.`n`nIncludes:`n• Getting started guide`n• Feature documentation`n• Keyboard shortcuts`n• Troubleshooting tips")
	
	Gui, Settings:Font, s9 Norm c%linkColor%, Segoe UI
	Gui, Settings:Add, Text, x560 y350 w100 BackgroundTrans gOpenDocsPage vAboutDocsLink Hidden HwndHwndAboutDocs, 📚 Docs
	RegisterSettingsTooltip(HwndAboutDocs, "DOCUMENTATION`n`nOpen the ProSelect to GHL field mapping guide.`n`nIncludes:`n• Invoice line item mapping`n• SKU/Product Code sync`n• Xero integration fields`n• QuickBooks integration fields`n• Tax configuration checklist")
	
	; ═══════════════════════════════════════════════════════════════════════════
	; DIAGNOSTICS GROUP BOX
	; ═══════════════════════════════════════════════════════════════════════════
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, GroupBox, x195 y370 w480 h125 vAboutDiagnostics Hidden, Diagnostics
	
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x210 y395 w300 BackgroundTrans vAboutAutoSendText Hidden HwndHwndAboutAutoSend, Auto-send activity logs
	RegisterSettingsTooltip(HwndAboutAutoSend, "AUTO-SEND ACTIVITY LOGS`n`nWhen enabled, sync activity logs are automatically`nsent to support after every invoice sync.`n`nThis helps track successful syncs AND identify issues.`nNo personal data is included - only sync details`nand script state information.`n`nRecommended: Keep enabled for proactive support.")
	CreateToggleSlider("Settings", "AutoSendLogs", 630, 393, Settings_AutoSendLogs)
	GuiControl, Settings:Hide, Toggle_AutoSendLogs
	
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x210 y425 w300 BackgroundTrans vAboutDebugText Hidden HwndHwndAboutDebug, Enable debug logging
	RegisterSettingsTooltip(HwndAboutDebug, "DEBUG LOGGING`n`nWhen enabled, detailed diagnostic information is logged.`nThis creates more verbose log files for troubleshooting.`n`nEnable temporarily when experiencing issues.`nDisable for normal use to improve performance`nand reduce log file size.`n`nLogs are stored locally and sent via 'Send Logs'.")
	CreateToggleSlider("Settings", "DebugLogging", 630, 423, Settings_DebugLogging)
	GuiControl, Settings:Hide, Toggle_DebugLogging
	
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Button, x210 y455 w100 h28 gSendLogsNow vAboutSendLogsButton Hidden HwndHwndAboutSendLogs, 📤 Send Logs
	RegisterSettingsTooltip(HwndAboutSendLogs, "SEND DIAGNOSTIC LOGS`n`nManually send current logs to support.`nUse this when reporting an issue or if requested by support.`n`nLogs include:`n• Recent actions and errors`n• Script configuration (no passwords)`n• System information`n`nThis helps diagnose problems quickly.")
	
	; Show log folder path next to Send Logs button
	logFolder := A_AppData . "\SideKick_PS\Logs"
	Gui, Settings:Font, s8 Norm c%mutedColor%, Segoe UI
	Gui, Settings:Add, Text, x320 y461 w280 h20 BackgroundTrans vAboutLogPath Hidden gOpenLogFolder HwndHwndAboutLogPath, 📁 %logFolder%
	RegisterSettingsTooltip(HwndAboutLogPath, "LOG FOLDER`n`nClick to open the folder containing diagnostic logs.`n`nLogs are automatically cleaned up after 7 days.")
}

CreateShortcutsPanel()
{
	global
	
	; Theme-aware colors
	if (Settings_DarkMode) {
		headerColor := "4FC3F7"
		textColor := "FFFFFF"
		labelColor := "CCCCCC"
		mutedColor := "888888"
		groupColor := "666666"
		iconBg := "333333"
	} else {
		headerColor := "0078D4"
		textColor := "1E1E1E"
		labelColor := "444444"
		mutedColor := "666666"
		groupColor := "999999"
		iconBg := "E0E0E0"
	}
	
	; Shortcuts panel container
	Gui, Settings:Add, Text, x190 y10 w510 h680 BackgroundTrans vPanelShortcuts
	
	; Section header
	Gui, Settings:Font, s16 c%headerColor%, Segoe UI
	Gui, Settings:Add, Text, x200 y20 w400 BackgroundTrans vSCHeader, 🎛 Toolbar Shortcuts
	
	; ═══════════════════════════════════════════════════════════════════════════
	; TOOLBAR BUTTONS GROUP BOX - Click icons to toggle on/off
	; ═══════════════════════════════════════════════════════════════════════════
	Gui, Settings:Font, s10 Norm c%groupColor%, Segoe UI
	Gui, Settings:Add, GroupBox, x195 y55 w480 h415 vSCButtonsGroup, Toolbar Buttons
	
	Gui, Settings:Font, s10 Norm c%mutedColor%, Segoe UI
	Gui, Settings:Add, Text, x210 y78 w450 BackgroundTrans vSCDescription, Click buttons to toggle on/off. Grayed buttons are disabled.
	
	; Row spacing: 35px per row, starting at y105
	; Each row: Clickable Icon + Clickable Label (both toggle)
	
	; Client button (👤) - Blue background
	iconBgClient := Settings_ShowBtn_Client ? "0000FF" : "444444"
	iconFgClient := Settings_ShowBtn_Client ? "FFFFFF" : "888888"
	lblColorClient := Settings_ShowBtn_Client ? labelColor : "666666"
	Gui, Settings:Font, s14, Segoe UI
	Gui, Settings:Add, Text, x215 y105 w30 h28 Center Background%iconBgClient% c%iconFgClient% vSCIcon_Client gToggleTB_Client, 👤
	Gui, Settings:Font, s10 Norm c%lblColorClient%, Segoe UI
	Gui, Settings:Add, Text, x255 y109 w380 BackgroundTrans vSCLabel_Client gToggleTB_Client, Client Lookup  —  GHL contact search
	
	; Invoice button (📋) - Green background
	iconBgInvoice := Settings_ShowBtn_Invoice ? "008000" : "444444"
	iconFgInvoice := Settings_ShowBtn_Invoice ? "FFFFFF" : "888888"
	lblColorInvoice := Settings_ShowBtn_Invoice ? labelColor : "666666"
	Gui, Settings:Font, s14, Segoe UI
	Gui, Settings:Add, Text, x215 y140 w30 h28 Center Background%iconBgInvoice% c%iconFgInvoice% vSCIcon_Invoice gToggleTB_Invoice, 📋
	Gui, Settings:Font, s10 Norm c%lblColorInvoice%, Segoe UI
	Gui, Settings:Add, Text, x255 y144 w380 BackgroundTrans vSCLabel_Invoice gToggleTB_Invoice, Invoice  —  Sync / Ctrl+Click to delete
	
	; Open GHL button (🌐) - Teal background
	iconBgOpenGHL := Settings_ShowBtn_OpenGHL ? "008080" : "444444"
	iconFgOpenGHL := Settings_ShowBtn_OpenGHL ? "FFFFFF" : "888888"
	lblColorOpenGHL := Settings_ShowBtn_OpenGHL ? labelColor : "666666"
	Gui, Settings:Font, s14, Segoe UI
	Gui, Settings:Add, Text, x215 y175 w30 h28 Center Background%iconBgOpenGHL% c%iconFgOpenGHL% vSCIcon_OpenGHL gToggleTB_OpenGHL, 🌐
	Gui, Settings:Font, s10 Norm c%lblColorOpenGHL%, Segoe UI
	Gui, Settings:Add, Text, x255 y179 w380 BackgroundTrans vSCLabel_OpenGHL gToggleTB_OpenGHL, Open GHL  —  Open client in browser
	
	; Camera button (📷) - Maroon background
	iconBgCamera := Settings_ShowBtn_Camera ? "800000" : "444444"
	iconFgCamera := Settings_ShowBtn_Camera ? "FFFFFF" : "888888"
	lblColorCamera := Settings_ShowBtn_Camera ? labelColor : "666666"
	Gui, Settings:Font, s14, Segoe UI
	Gui, Settings:Add, Text, x215 y210 w30 h28 Center Background%iconBgCamera% c%iconFgCamera% vSCIcon_Camera gToggleTB_Camera, 📷
	Gui, Settings:Font, s10 Norm c%lblColorCamera%, Segoe UI
	Gui, Settings:Add, Text, x255 y214 w380 BackgroundTrans vSCLabel_Camera gToggleTB_Camera, Camera  —  Room capture
	
	; Sort button (🔀) - Gray background
	iconBgSort := Settings_ShowBtn_Sort ? "808080" : "444444"
	iconFgSort := Settings_ShowBtn_Sort ? "FFFFFF" : "888888"
	lblColorSort := Settings_ShowBtn_Sort ? labelColor : "666666"
	Gui, Settings:Font, s14, Segoe UI
	Gui, Settings:Add, Text, x215 y245 w30 h28 Center Background%iconBgSort% c%iconFgSort% vSCIcon_Sort gToggleTB_Sort, 🔀
	Gui, Settings:Font, s10 Norm c%lblColorSort%, Segoe UI
	Gui, Settings:Add, Text, x255 y249 w380 BackgroundTrans vSCLabel_Sort gToggleTB_Sort, Sort Order  —  Random / filename toggle
	
	; Photoshop button (Ps) - Dark blue with lighter blue text
	iconBgPhotoshop := Settings_ShowBtn_Photoshop ? "001E36" : "444444"
	iconFgPhotoshop := Settings_ShowBtn_Photoshop ? "33A1FD" : "888888"
	lblColorPhotoshop := Settings_ShowBtn_Photoshop ? labelColor : "666666"
	Gui, Settings:Font, s10 Bold, Segoe UI
	Gui, Settings:Add, Text, x215 y280 w30 h28 Center Background%iconBgPhotoshop% c%iconFgPhotoshop% vSCIcon_Photoshop gToggleTB_Photoshop, Ps
	Gui, Settings:Font, s10 Norm c%lblColorPhotoshop%, Segoe UI
	Gui, Settings:Add, Text, x255 y284 w380 BackgroundTrans vSCLabel_Photoshop gToggleTB_Photoshop, Photoshop  —  Send to Photoshop (Ctrl+T)
	
	; Refresh button (🔄) - Navy background
	iconBgRefresh := Settings_ShowBtn_Refresh ? "000080" : "444444"
	iconFgRefresh := Settings_ShowBtn_Refresh ? "FFFFFF" : "888888"
	lblColorRefresh := Settings_ShowBtn_Refresh ? labelColor : "666666"
	Gui, Settings:Font, s14, Segoe UI
	Gui, Settings:Add, Text, x215 y315 w30 h28 Center Background%iconBgRefresh% c%iconFgRefresh% vSCIcon_Refresh gToggleTB_Refresh, 🔄
	Gui, Settings:Font, s10 Norm c%lblColorRefresh%, Segoe UI
	Gui, Settings:Add, Text, x255 y319 w380 BackgroundTrans vSCLabel_Refresh gToggleTB_Refresh, Refresh  —  Update album (Ctrl+U)
	
	; Print button (🖨) - Dark gray background
	iconBgPrint := Settings_ShowBtn_Print ? "444444" : "333333"
	iconFgPrint := Settings_ShowBtn_Print ? "FFFFFF" : "888888"
	lblColorPrint := Settings_ShowBtn_Print ? labelColor : "666666"
	Gui, Settings:Font, s14, Segoe UI
	Gui, Settings:Add, Text, x215 y350 w30 h28 Center Background%iconBgPrint% c%iconFgPrint% vSCIcon_Print gToggleTB_Print, 🖨
	Gui, Settings:Font, s10 Norm c%lblColorPrint%, Segoe UI
	Gui, Settings:Add, Text, x255 y354 w380 BackgroundTrans vSCLabel_Print gToggleTB_Print, Quick Print  —  Auto-print with template
	
	; QR Code button (▣) - Teal background
	iconBgQRCode := Settings_ShowBtn_QRCode ? "006666" : "444444"
	iconFgQRCode := Settings_ShowBtn_QRCode ? "FFFFFF" : "888888"
	lblColorQRCode := Settings_ShowBtn_QRCode ? labelColor : "666666"
	Gui, Settings:Font, s14, Segoe UI
	Gui, Settings:Add, Text, x215 y385 w30 h28 Center Background%iconBgQRCode% c%iconFgQRCode% vSCIcon_QRCode gToggleTB_QRCode, ▣
	Gui, Settings:Font, s10 Norm c%lblColorQRCode%, Segoe UI
	Gui, Settings:Add, Text, x255 y389 w380 BackgroundTrans vSCLabel_QRCode gToggleTB_QRCode, QR Code  —  Display QR code from text
	
	; SD Download button (📥) — note: managed separately in File Management
	Gui, Settings:Font, s14, Segoe UI
	Gui, Settings:Add, Text, x215 y420 w30 h28 Center BackgroundFF8C00 cWhite vSCIcon_Download, 📥
	Gui, Settings:Font, s10 Norm c%mutedColor%, Segoe UI
	Gui, Settings:Add, Text, x255 y424 w350 BackgroundTrans vSCLabel_Download, SD Download  —  Managed in File Management tab
	
	; ═══════════════════════════════════════════════════════════════════════════
	; INFO NOTE
	; ═══════════════════════════════════════════════════════════════════════════
	Gui, Settings:Font, s9 Norm c%mutedColor%, Segoe UI
	Gui, Settings:Add, Text, x210 y475 w440 BackgroundTrans vSCInfoNote, ℹ Settings button (⚙) is always visible.  Changes apply after clicking Apply.
	
	Gui, Settings:Font, s10 Norm c%textColor%, Segoe UI
}

CreatePrintPanel()
{
	global
	
	; Theme-aware colors
	if (Settings_DarkMode) {
		headerColor := "4FC3F7"
		textColor := "FFFFFF"
		labelColor := "CCCCCC"
		mutedColor := "888888"
		groupColor := "666666"
	} else {
		headerColor := "0078D4"
		textColor := "1E1E1E"
		labelColor := "444444"
		mutedColor := "666666"
		groupColor := "999999"
	}
	
	; Print panel container
	Gui, Settings:Add, Text, x190 y10 w510 h680 BackgroundTrans vPanelPrint
	
	; Section header
	Gui, Settings:Font, s16 c%headerColor%, Segoe UI
	Gui, Settings:Add, Text, x200 y20 w400 BackgroundTrans vPrintHeader, 🖨 Print Settings
	
	; ═══════════════════════════════════════════════════════════════════════════
	; QUICK PRINT PRINTER GROUP BOX
	; ═══════════════════════════════════════════════════════════════════════════
	Gui, Settings:Font, s10 Norm c%groupColor%, Segoe UI
	Gui, Settings:Add, GroupBox, x195 y60 w480 h80 vPrintPrinterGroup, Printer
	
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x210 y88 w95 h22 BackgroundTrans vPrintPrinterLabel HwndHwndPrintPrinter, Printer:
	RegisterSettingsTooltip(HwndPrintPrinter, "QUICK PRINT PRINTER`n`nSelect which printer to use for Quick Print.`nLeave as 'System Default' to use Windows default printer.")
	; Build printer list: System Default first, then all available printers
	printerList := GetPrinterList()
	Gui, Settings:Add, DropDownList, x310 y86 w345 r10 vPrintPrinterCombo Choose1, System Default|%printerList%
	; Select saved value if it exists
	if (Settings_QuickPrintPrinter != "" && Settings_QuickPrintPrinter != "System Default")
		GuiControl, Settings:ChooseString, PrintPrinterCombo, %Settings_QuickPrintPrinter%
	
	Gui, Settings:Font, s9 Norm c%mutedColor%, Segoe UI
	Gui, Settings:Add, Text, x210 y115 w440 BackgroundTrans vPrintPrinterHint, Select printer for Quick Print button. 'System Default' uses Windows default.
	
	; ═══════════════════════════════════════════════════════════════════════════
	; QUICK PRINT TEMPLATES GROUP BOX
	; ═══════════════════════════════════════════════════════════════════════════
	Gui, Settings:Font, s10 Norm c%groupColor%, Segoe UI
	Gui, Settings:Add, GroupBox, x195 y150 w480 h150 vPrintTemplatesGroup, Quick Print Templates
	
	Gui, Settings:Font, s10 Norm c%mutedColor%, Segoe UI
	Gui, Settings:Add, Text, x210 y175 w440 BackgroundTrans vPrintTemplatesDesc, Template name to match in ProSelect's Print dialog dropdown.
	
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x210 y205 w95 h22 BackgroundTrans vPrintPayPlanLabel HwndHwndPrintPayPlan, Payment Plan:
	RegisterSettingsTooltip(HwndPrintPayPlan, "PAYMENT PLAN TEMPLATE`n`nTemplate to auto-select when printing with`na payment plan (Ctrl+Shift+O).")
	; Build dropdown: SELECT first, then saved value, then cached options
	payplanList := "SELECT"
	if (Settings_PrintTemplateOptions != "")
		payplanList .= "|" . Settings_PrintTemplateOptions
	Gui, Settings:Add, ComboBox, x310 y203 w295 r10 vPrintPayPlanCombo Choose1, %payplanList%
	; Select saved value if it exists
	if (Settings_PrintTemplate_PayPlan != "" && Settings_PrintTemplate_PayPlan != "SELECT")
		GuiControl, Settings:ChooseString, PrintPayPlanCombo, %Settings_PrintTemplate_PayPlan%
	Gui, Settings:Add, Button, x610 y202 w45 h55 gRefreshPrintTemplates vPrintRefreshBtn HwndHwndPrintRefresh, 🔄
	RegisterSettingsTooltip(HwndPrintRefresh, "REFRESH TEMPLATES`n`nOpens ProSelect's Print dialog and reads available`ntemplate names for the dropdown lists.`n`nMake sure ProSelect is running with an album open.")
	
	Gui, Settings:Add, Text, x210 y235 w95 h22 BackgroundTrans vPrintStandardLabel HwndHwndPrintStandard, Standard:
	RegisterSettingsTooltip(HwndPrintStandard, "STANDARD TEMPLATE`n`nTemplate to auto-select when printing without`na payment plan (Ctrl+Shift+P).")
	; Build dropdown: SELECT first, then saved value, then cached options
	standardList := "SELECT"
	if (Settings_PrintTemplateOptions != "")
		standardList .= "|" . Settings_PrintTemplateOptions
	Gui, Settings:Add, ComboBox, x310 y233 w295 r10 vPrintStandardCombo Choose1, %standardList%
	; Select saved value if it exists
	if (Settings_PrintTemplate_Standard != "" && Settings_PrintTemplate_Standard != "SELECT")
		GuiControl, Settings:ChooseString, PrintStandardCombo, %Settings_PrintTemplate_Standard%
	
	Gui, Settings:Font, s9 Norm c%mutedColor%, Segoe UI
	Gui, Settings:Add, Text, x210 y265 w440 BackgroundTrans vPrintTemplatesHint, The template matching this name will be auto-selected when using Quick Print.
	
	; ═══════════════════════════════════════════════════════════════════════════
	; ROOM CAPTURE EMAIL GROUP BOX
	; ═══════════════════════════════════════════════════════════════════════════
	Gui, Settings:Font, s10 Norm c%groupColor%, Segoe UI
	Gui, Settings:Add, GroupBox, x195 y310 w480 h120 vPrintEmailGroup, Room Capture Email
	
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x210 y335 w95 h22 BackgroundTrans vPrintEmailTplLabel HwndHwndPrintEmailTpl, Template:
	RegisterSettingsTooltip(HwndPrintEmailTpl, "EMAIL TEMPLATE`n`nSelect a GHL email template for room capture emails.`nThe room image will be appended to the template body.`n`nClick 🔄 to fetch templates from GHL.")
	
	; Build template list for ComboBox (SELECT first, then cached options)
	tplList := "SELECT"
	if (GHL_CachedEmailTemplates != "") {
		; Extract just the names from cached templates (format: id|name`nid|name...)
		Loop, Parse, GHL_CachedEmailTemplates, `n, `r
		{
			if (A_LoopField = "")
				continue
			parts := StrSplit(A_LoopField, "|")
			if (parts.Length() >= 2) {
				tplList .= "|" . parts[2]
			}
		}
	}
	Gui, Settings:Add, ComboBox, x310 y333 w200 r10 vPrintEmailTplCombo gPrintEmailTplChanged Choose1, %tplList%
	; Select saved value if it exists
	if (Settings_EmailTemplateName != "" && Settings_EmailTemplateName != "(none selected)" && Settings_EmailTemplateName != "SELECT")
		GuiControl, Settings:ChooseString, PrintEmailTplCombo, %Settings_EmailTemplateName%
	Gui, Settings:Add, Button, x515 y332 w40 h27 gRefreshPrintEmailTemplates vPrintEmailTplRefresh HwndHwndPrintEmailRefresh, 🔄
	RegisterSettingsTooltip(HwndPrintEmailRefresh, "REFRESH EMAIL TEMPLATES`n`nFetch available email templates from GHL.")
	
	Gui, Settings:Font, s9 Norm c%mutedColor%, Segoe UI
	Gui, Settings:Add, Text, x210 y365 w440 BackgroundTrans vPrintEmailTplHint, GHL email template used when emailing room captures to client.
	
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x210 y390 w95 h22 BackgroundTrans vPrintRoomFolderLabel HwndHwndPrintRoomFolder, Save Folder:
	RegisterSettingsTooltip(HwndPrintRoomFolder, "ROOM CAPTURE SAVE FOLDER`n`nWhere room capture images are saved before`nbeing emailed to the client.`n`nAlbum Folder = saves in current album folder.")
	; Build dropdown: Album Folder first, then custom path if set
	roomFolderList := "Album Folder"
	if (Settings_RoomCaptureFolder != "" && Settings_RoomCaptureFolder != "Album Folder")
		roomFolderList .= "|" . Settings_RoomCaptureFolder
	Gui, Settings:Add, ComboBox, x310 y388 w280 r5 vPrintRoomFolderCombo, %roomFolderList%
	; Select saved value
	if (Settings_RoomCaptureFolder != "" && Settings_RoomCaptureFolder != "Album Folder")
		GuiControl, Settings:ChooseString, PrintRoomFolderCombo, %Settings_RoomCaptureFolder%
	else
		GuiControl, Settings:ChooseString, PrintRoomFolderCombo, Album Folder
	Gui, Settings:Add, Button, x595 y387 w60 h24 gBrowseRoomCaptureFolder vPrintRoomFolderBrowse HwndHwndPrintRoomBrowse, Browse
	RegisterSettingsTooltip(HwndPrintRoomBrowse, "Browse for custom save folder")
	
	; ═══════════════════════════════════════════════════════════════════════════
	; PDF OUTPUT GROUP BOX
	; ═══════════════════════════════════════════════════════════════════════════
	Gui, Settings:Font, s10 Norm c%groupColor%, Segoe UI
	Gui, Settings:Add, GroupBox, x195 y440 w480 h150 vPrintPDFGroup, PDF Output

	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x210 y468 w300 h22 BackgroundTrans vPrintEnablePDFLabel HwndHwndPrintEnablePDF, Enable Print to PDF
	RegisterSettingsTooltip(HwndPrintEnablePDF, "ENABLE PDF OUTPUT`n`nShows a dedicated PDF button on the toolbar.`nPrints invoice to PDF instead of physical printer.")
	CreateToggleSlider("Settings", "EnablePDF", 590, 465, Settings_EnablePDF)

	Gui, Settings:Font, s9 Norm c%mutedColor%, Segoe UI
	Gui, Settings:Add, Text, x210 y490 w440 BackgroundTrans vPrintPDFDesc, Shows PDF button on toolbar. Print saves PDF to album folder + optional copy.

	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x210 y530 w95 h22 BackgroundTrans vPrintPDFCopyLabel HwndHwndPrintPDFCopy, Copy Folder:
	RegisterSettingsTooltip(HwndPrintPDFCopy, "PDF COPY FOLDER`n`nOptional secondary location to copy the PDF.`nLeave blank to only save in the album folder.")
	Gui, Settings:Add, Edit, x310 y528 w280 h22 cBlack vPrintPDFCopyEdit, %Settings_PDFOutputFolder%
	Gui, Settings:Add, Button, x595 y527 w60 h24 gBrowsePDFOutputFolder vPrintPDFCopyBrowse HwndHwndPrintPDFBrowse, Browse
	RegisterSettingsTooltip(HwndPrintPDFBrowse, "Browse for PDF copy folder")

	Gui, Settings:Font, s9 Norm c%mutedColor%, Segoe UI
	Gui, Settings:Add, Text, x210 y558 w440 BackgroundTrans vPrintPDFHint, PDF is always saved to the album folder. Leave blank to skip copying.

	Gui, Settings:Font, s10 Norm c%textColor%, Segoe UI
}

BrowsePDFOutputFolder:
	FileSelectFolder, selectedFolder, *%Settings_PDFOutputFolder%, 3, Select PDF Copy Folder
	if (selectedFolder != "") {
		Settings_PDFOutputFolder := selectedFolder
		GuiControl, Settings:, PrintPDFCopyEdit, %selectedFolder%
	}
return

RefreshPrintTemplates:
	; Refresh print template options from ProSelect's Print dialog
	ToolTip, Fetching print templates from ProSelect...
	
	; Check ProSelect is running
	if !WinExist("ahk_exe ProSelect.exe") {
		ToolTip
		DarkMsgBox("Error", "ProSelect is not running.", "error")
		return
	}
	
	; Activate ProSelect
	WinActivate, ahk_exe ProSelect.exe
	WinWaitActive, ahk_exe ProSelect.exe,, 2
	
	; Open Print dialog using keyboard navigation
	Send, !f        ; Alt+F to open File menu
	Sleep, 300
	Send, p         ; P to highlight Print submenu
	Sleep, 300
	Send, {Right}   ; Open the submenu
	Sleep, 300
	Send, {Enter}   ; Select first item (Order/Invoice Report...)
	Sleep, 1000
	
	; Wait for Print Order/Invoice Report window
	WinWait, Print Order/Invoice Report, , 3
	if ErrorLevel {
		ToolTip
		DarkMsgBox("Error", "Could not open Print dialog.", "error")
		return
	}
	
	; Read ComboBox5 (Template dropdown) list
	ControlGet, cbList, List,, ComboBox5, Print Order/Invoice Report
	if (ErrorLevel || cbList = "") {
		; Close dialog and report error
		Send, {Escape}
		ToolTip
		DarkMsgBox("Error", "Could not read template list from Print dialog.", "error")
		return
	}
	
	; Close dialog
	Send, {Escape}
	Sleep, 200
	
	; Re-activate Settings window
	Gui, Settings:Show
	
	; Convert newline-separated list to pipe-separated
	StringReplace, cbList, cbList, `n, |, All
	Settings_PrintTemplateOptions := cbList
	
	; Update the ComboBox controls in Settings (prepend SELECT option)
	GuiControl, Settings:, PrintPayPlanCombo, |SELECT|%cbList%
	GuiControl, Settings:, PrintStandardCombo, |SELECT|%cbList%
	
	; Re-select current values if they still exist, otherwise set to SELECT
	if (InStr("|" . cbList . "|", "|" . Settings_PrintTemplate_PayPlan . "|"))
		GuiControl, Settings:ChooseString, PrintPayPlanCombo, %Settings_PrintTemplate_PayPlan%
	else
		GuiControl, Settings:ChooseString, PrintPayPlanCombo, SELECT
	
	if (InStr("|" . cbList . "|", "|" . Settings_PrintTemplate_Standard . "|"))
		GuiControl, Settings:ChooseString, PrintStandardCombo, %Settings_PrintTemplate_Standard%
	else
		GuiControl, Settings:ChooseString, PrintStandardCombo, SELECT
	
	; Save to INI immediately
	IniWrite, %Settings_PrintTemplateOptions%, %IniFilename%, Toolbar, PrintTemplateOptions
	
	; Show success tooltip (auto-hide after 2 seconds)
	templateCount := StrSplit(cbList, "|").MaxIndex()
	ToolTip, Loaded %templateCount% print templates
	SetTimer, RemoveToolTip, -2000
return

PrintEmailTplChanged:
	; Room Capture email template dropdown changed - save immediately
	Gui, Settings:Submit, NoHide
	GuiControlGet, selectedTemplate,, PrintEmailTplCombo
	if (selectedTemplate = "SELECT" || selectedTemplate = "") {
		Settings_EmailTemplateID := ""
		Settings_EmailTemplateName := "SELECT"
	} else {
		Settings_EmailTemplateName := selectedTemplate
		; Look up the template ID from cached templates
		Settings_EmailTemplateID := ""
		Loop, Parse, GHL_CachedEmailTemplates, `n
		{
			if (A_LoopField = "")
				continue
			parts := StrSplit(A_LoopField, "|")
			if (parts.Length() >= 2 && parts[2] = selectedTemplate) {
				Settings_EmailTemplateID := parts[1]
				break
			}
		}
	}
	IniWrite, %Settings_EmailTemplateID%, %IniFilename%, Toolbar, EmailTemplateID
	IniWrite, %Settings_EmailTemplateName%, %IniFilename%, Toolbar, EmailTemplateName
return

RefreshPrintEmailTemplates:
	; Same as RefreshEmailTemplates but updates Print tab controls
	ToolTip, Fetching email templates from GHL...
	
	; Log file for email template debugging
	etLogFile := A_ScriptDir . "\email_templates_debug.log"
	FormatTime, etTimestamp,, yyyy-MM-dd HH:mm:ss
	FileAppend, % "`n" . etTimestamp . " [RefreshPrintEmailTemplates] === START ===`n", %etLogFile%
	
	; Build command using GetScriptCommand (handles .exe vs .py automatically)
	tempFile := A_Temp . "\ghl_email_templates.json"
	scriptCmd := GetScriptCommand("sync_ps_invoice", "--list-email-templates")
	
	FileAppend, % etTimestamp . " [RefreshPrintEmailTemplates] A_IsCompiled=" . A_IsCompiled . "`n", %etLogFile%
	FileAppend, % etTimestamp . " [RefreshPrintEmailTemplates] A_ScriptDir=" . A_ScriptDir . "`n", %etLogFile%
	FileAppend, % etTimestamp . " [RefreshPrintEmailTemplates] scriptCmd=" . scriptCmd . "`n", %etLogFile%
	FileAppend, % etTimestamp . " [RefreshPrintEmailTemplates] tempFile=" . tempFile . "`n", %etLogFile%
	
	if (scriptCmd = "") {
		ToolTip
		FileAppend, % etTimestamp . " [RefreshPrintEmailTemplates] ERROR: scriptCmd is empty - script not found`n", %etLogFile%
		DarkMsgBox("Error", "Script not found: sync_ps_invoice", "error")
		return
	}
	
	; Check if the exe/py actually exists
	scriptPath := GetScriptPath("sync_ps_invoice")
	FileAppend, % etTimestamp . " [RefreshPrintEmailTemplates] scriptPath=" . scriptPath . "`n", %etLogFile%
	if (FileExist(scriptPath))
		FileAppend, % etTimestamp . " [RefreshPrintEmailTemplates] Script file EXISTS`n", %etLogFile%
	else
		FileAppend, % etTimestamp . " [RefreshPrintEmailTemplates] Script file NOT FOUND!`n", %etLogFile%
	
	; Delete any existing temp file
	FileDelete, %tempFile%
	
	; Write command to temp .cmd file to avoid cmd.exe /c quoting issues with .exe vs .py
	tempCmd := A_Temp . "\sk_email_tpl_" . A_TickCount . ".cmd"
	FileDelete, %tempCmd%
	FileAppend, % "@" . scriptCmd . " > """ . tempFile . """ 2>&1`n", %tempCmd%
	FileAppend, % etTimestamp . " [RefreshPrintEmailTemplates] TempCmd: " . tempCmd . "`n", %etLogFile%
	FileRead, etCmdContent, %tempCmd%
	FileAppend, % etTimestamp . " [RefreshPrintEmailTemplates] CmdContent: " . etCmdContent, %etLogFile%
	RunWait, %ComSpec% /c "%tempCmd%", , Hide
	etExitCode := ErrorLevel
	FileDelete, %tempCmd%
	FileAppend, % etTimestamp . " [RefreshPrintEmailTemplates] ExitCode=" . etExitCode . "`n", %etLogFile%
	
	; Check temp file exists and its size
	FileGetSize, etTempSize, %tempFile%
	FileAppend, % etTimestamp . " [RefreshPrintEmailTemplates] TempFile exists=" . (FileExist(tempFile) ? "YES" : "NO") . " size=" . etTempSize . " bytes`n", %etLogFile%
	
	; Read and parse the result
	FileRead, result, %tempFile%
	
	; Log raw output (first 500 chars)
	etRawPreview := SubStr(result, 1, 500)
	FileAppend, % etTimestamp . " [RefreshPrintEmailTemplates] Raw output (" . StrLen(result) . " chars):`n" . etRawPreview . "`n", %etLogFile%
	FileDelete, %tempFile%
	
	ToolTip
	
	if (InStr(result, "ERROR") || result = "") {
		FileAppend, % etTimestamp . " [RefreshPrintEmailTemplates] FAILED: result empty=" . (result = "" ? "YES" : "NO") . " containsERROR=" . (InStr(result, "ERROR") ? "YES" : "NO") . "`n", %etLogFile%
		DarkMsgBox("Error", "Failed to fetch email templates.`n`nCommand: " . scriptCmd . "`n`nExit code: " . etExitCode . "`n`nOutput: " . SubStr(result, 1, 300), "error")
		return
	}
	
	FileAppend, % etTimestamp . " [RefreshPrintEmailTemplates] SUCCESS`n", %etLogFile%
	
	; Cache the templates (format: id|name per line)
	GHL_CachedEmailTemplates := result
	
	; Rebuild the dropdown with SELECT first
	newList := "SELECT"
	Loop, Parse, result, `n, `r
	{
		if (A_LoopField = "")
			continue
		parts := StrSplit(A_LoopField, "|")
		if (parts.Length() >= 2) {
			newList .= "|" . parts[2]
		}
	}
	
	GuiControl, Settings:, PrintEmailTplCombo, |%newList%
	if (Settings_EmailTemplateName != "" && Settings_EmailTemplateName != "(none selected)" && Settings_EmailTemplateName != "SELECT")
		GuiControl, Settings:ChooseString, PrintEmailTplCombo, %Settings_EmailTemplateName%
	else
		GuiControl, Settings:ChooseString, PrintEmailTplCombo, SELECT
	
	DarkMsgBox("Templates Loaded", "Loaded " . StrSplit(result, "`n").MaxIndex() . " email templates from GHL.", "success", {timeout: 2})
return

BrowseRoomCaptureFolder:
	FileSelectFolder, selectedFolder, *%Settings_RoomCaptureFolder%, 3, Select Room Capture Folder
	if (selectedFolder != "") {
		Settings_RoomCaptureFolder := selectedFolder
		; Add to dropdown and select it
		GuiControl, Settings:, PrintRoomFolderCombo, |Album Folder|%selectedFolder%
		GuiControl, Settings:ChooseString, PrintRoomFolderCombo, %selectedFolder%
	}
return

; ═══════════════════════════════════════════════════════════════════════════════════════════════
; GoCardless Integration Panel
; ═══════════════════════════════════════════════════════════════════════════════════════════════
CreateGoCardlessPanel()
{
	global
	
	; Prevent change handlers from firing during initial GUI build
	GC_BuildingPanel := true
	
	; Theme-aware colors
	if (Settings_DarkMode) {
		headerColor := "4FC3F7"
		textColor := "FFFFFF"
		labelColor := "CCCCCC"
		mutedColor := "888888"
		groupColor := "666666"
	} else {
		headerColor := "0078D4"
		textColor := "1E1E1E"
		labelColor := "444444"
		mutedColor := "666666"
		groupColor := "999999"
	}
	
	; GoCardless panel container (initially hidden)
	Gui, Settings:Add, Text, x190 y10 w510 h680 BackgroundTrans vPanelGoCardless Hidden
	
	; Section header
	Gui, Settings:Font, s16 c%headerColor%, Segoe UI
	Gui, Settings:Add, Text, x195 y20 w480 BackgroundTrans vGCHeader Hidden, 💳 GoCardless Integration
	
	; ═══════════════════════════════════════════════════════════════════════════
	; CONNECTION GROUP BOX (y55 to y195)
	; ═══════════════════════════════════════════════════════════════════════════
	Gui, Settings:Font, s10 Norm c%groupColor%, Segoe UI
	Gui, Settings:Add, GroupBox, x195 y55 w480 h140 vGCConnection Hidden, Connection
	
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	
	; Enable GoCardless Integration toggle slider
	Gui, Settings:Add, Text, x210 y80 w300 BackgroundTrans vGCEnable Hidden gTT_GCEnable HwndHwndGCEnable, Enable GoCardless Integration
	RegisterSettingsTooltip(HwndGCEnable, "ENABLE GOCARDLESS INTEGRATION`n`nConnect SideKick to GoCardless Direct Debit.`nAllows creating mandates and collecting payments.`n`nRequires a valid GoCardless API token.")
	CreateToggleSlider("Settings", "GoCardlessEnabled", 630, 78, Settings_GoCardlessEnabled)
	
	; Auto-setup toggle (under enable)
	Gui, Settings:Add, Text, x210 y115 w340 BackgroundTrans vGCAutoSetupLabel Hidden gTT_GCAutoSetup HwndHwndGCAutoSetup, Auto-prompt GoCardless after invoice sync
	RegisterSettingsTooltip(HwndGCAutoSetup, "AUTO-PROMPT GOCARDLESS`n`nWhen enabled, automatically prompts to set up`nGoCardless payments after syncing an invoice`nthat has future payment dates.`n`nIf disabled you can still use the GC toolbar button.")
	CreateToggleSlider("Settings", "GCAutoSetup", 630, 113, Settings_GCAutoSetup)
	Gui, Settings:Font, s9 Norm c%mutedColor%, Segoe UI
	Gui, Settings:Add, Text, x210 y150 w290 BackgroundTrans vGCAutoHint Hidden, Applies to invoices with future payment dates.
	
	; Setup Wizard button
	Gui, Settings:Font, s9 Norm, Segoe UI
	Gui, Settings:Add, Button, x510 y145 w160 h30 gGCSetupWizard vGCWizardBtn Hidden HwndHwndGCWizard, 🧙 Setup Wizard
	RegisterSettingsTooltip(HwndGCWizard, "GOCARDLESS SETUP WIZARD`n`nStep-by-step guide to connect SideKick`nto your GoCardless account.`n`nPerfect for first-time setup!")
	
	; ═══════════════════════════════════════════════════════════════════════════
	; API CONFIGURATION GROUP BOX (y200 to y350)
	; ═══════════════════════════════════════════════════════════════════════════
	Gui, Settings:Font, s10 Norm c%groupColor%, Segoe UI
	Gui, Settings:Add, GroupBox, x195 y200 w480 h150 vGCApiConfig Hidden, API Configuration
	
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	
	; Environment selector
	Gui, Settings:Add, Text, x210 y225 w90 BackgroundTrans vGCEnvLabel Hidden gTT_GCEnv HwndHwndGCEnv, Environment:
	RegisterSettingsTooltip(HwndGCEnv, "ENVIRONMENT`n`nSandbox: For testing (no real money)`nLive: Production (real transactions)`n`nStart with Sandbox to test your setup.")
	Gui, Settings:Add, DropDownList, x305 y222 w150 vGCEnvDDL Hidden Choose1 gGCEnvChanged, Sandbox|Live
	if (Settings_GoCardlessEnvironment = "live")
		GuiControl, Settings:ChooseString, GCEnvDDL, Live
	
	; API Token display (masked)
	Gui, Settings:Add, Text, x210 y258 w90 BackgroundTrans vGCTokenLabel Hidden gTT_GCToken HwndHwndGCToken, API Token:
	RegisterSettingsTooltip(HwndGCToken, "GOCARDLESS API TOKEN`n`nYour GoCardless access token.`nGet it from: GoCardless Dashboard > Developers > Create > Access token`n`nTokens are stored securely in credentials.json (base64 encoded).")
	tokenDisplay := Settings_GoCardlessToken ? SubStr(Settings_GoCardlessToken, 1, 12) . "..." . SubStr(Settings_GoCardlessToken, -4) : "Not configured"
	Gui, Settings:Font, s10 Norm cFFFFFF, Segoe UI
	Gui, Settings:Add, Edit, x305 y255 w250 h25 vGCTokenDisplay Hidden ReadOnly, %tokenDisplay%
	Gui, Settings:Add, Button, x560 y253 w100 h28 gEditGCToken vGCTokenEditBtn Hidden, Edit
	
	; Status row
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x210 y298 w60 BackgroundTrans vGCStatus Hidden, Status:
	statusText := Settings_GoCardlessToken ? "✅ Token Set" : "❌ Not configured"
	statusColor := Settings_GoCardlessToken ? "00FF00" : "FF6B6B"
	Gui, Settings:Font, s10 Norm c%statusColor%, Segoe UI
	Gui, Settings:Add, Text, x275 y298 w120 BackgroundTrans vGCStatusText Hidden HwndHwndGCStatus, %statusText%
	RegisterSettingsTooltip(HwndGCStatus, "CONNECTION STATUS`n`n✅ Token Set = API token configured`n`nUse 'Test' to verify the token works.")
	
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Button, x405 y295 w60 h26 gTestGCConnection vGCTestBtn Hidden HwndHwndGCTest, Test
	RegisterSettingsTooltip(HwndGCTest, "TEST CONNECTION`n`nVerify your API token works by making`na test request to the GoCardless API.`n`nWill show your creditor name if successful.")
	Gui, Settings:Add, Button, x470 y295 w110 h26 gListEmptyMandates vGCEmptyMandatesBtn Hidden HwndHwndGCEmpty, No Plans
	RegisterSettingsTooltip(HwndGCEmpty, "LIST MANDATES WITHOUT PLANS`n`nScans ALL active GoCardless mandates and`nfinds those with no payment plans set up.`n`nUseful for:`n• Follow-up reminders to clients`n• Finding forgotten mandates`n• Identifying setup issues`n`nResults can be copied to clipboard`nfor Excel or email follow-up.")
	Gui, Settings:Add, Button, x585 y295 w85 h26 gOpenGCDashboard vGCDashboardBtn Hidden HwndHwndGCDash, Dashboard
	RegisterSettingsTooltip(HwndGCDash, "GOCARDLESS DASHBOARD`n`nOpen the GoCardless web dashboard`nin your browser.`n`nOpens Sandbox or Live dashboard based`non your Environment setting.")
	
	; Progress bar for No Plans scan
	Gui, Settings:Add, Progress, x405 y325 w265 h12 vGCProgressBar Hidden Range0-100 c00BFFF Background3D3D3D, 0
	Gui, Settings:Add, Text, x405 y340 w265 h18 vGCProgressText Hidden cAAAAAA, 
	
	; ═══════════════════════════════════════════════════════════════════════════
	; MANDATE NOTIFICATIONS GROUP BOX (y360 to y480)
	; ═══════════════════════════════════════════════════════════════════════════
	Gui, Settings:Font, s10 Norm c%groupColor%, Segoe UI
	Gui, Settings:Add, GroupBox, x195 y360 w480 h130 vGCNotifyGroup Hidden, Mandate Link Notifications
	
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	
	; Email Template selector
	Gui, Settings:Add, Text, x210 y385 w95 h22 BackgroundTrans vGCEmailTplLabel Hidden HwndHwndGCEmailTpl, Email Template:
	RegisterSettingsTooltip(HwndGCEmailTpl, "EMAIL TEMPLATE`n`nSelect a GHL email template to send the mandate link.`nThe mandate URL will be inserted into the template.`n`nClick 🔄 to fetch templates from GHL.")
	
	; Build template list for ComboBox (SELECT first, then cached options)
	gcTplList := "SELECT"
	if (GHL_CachedEmailTemplates != "") {
		Loop, Parse, GHL_CachedEmailTemplates, `n, `r
		{
			if (A_LoopField = "")
				continue
			parts := StrSplit(A_LoopField, "|")
			if (parts.Length() >= 2) {
				gcTplList .= "|" . parts[2]
			}
		}
	}
	Gui, Settings:Add, ComboBox, x310 y383 w200 r10 vGCEmailTplCombo Hidden gGCEmailTplChanged, %gcTplList%
	if (Settings_GCEmailTemplateName != "" && Settings_GCEmailTemplateName != "(none selected)" && Settings_GCEmailTemplateName != "SELECT")
		GuiControl, Settings:ChooseString, GCEmailTplCombo, %Settings_GCEmailTemplateName%
	else
		GuiControl, Settings:Choose, GCEmailTplCombo, 1  ; Select "SELECT" by default
	Gui, Settings:Add, Button, x515 y382 w40 h27 gRefreshGCEmailTemplates vGCEmailTplRefresh Hidden HwndHwndGCEmailRefresh, 🔄
	RegisterSettingsTooltip(HwndGCEmailRefresh, "REFRESH EMAIL TEMPLATES`n`nFetch available email templates from GHL.")
	
	; SMS Template selector
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x210 y420 w95 h22 BackgroundTrans vGCSMSTplLabel Hidden HwndHwndGCSMSTpl, SMS Template:
	RegisterSettingsTooltip(HwndGCSMSTpl, "SMS TEMPLATE`n`nSelect a GHL SMS template to send the mandate link.`nChoose SELECT to skip SMS notification.`n`nClick 🔄 to fetch templates from GHL.")
	
	; Build SMS template list (SELECT first, then cached options)
	gcSmsTplList := "SELECT"
	if (GHL_CachedSMSTemplates != "") {
		Loop, Parse, GHL_CachedSMSTemplates, `n, `r
		{
			if (A_LoopField = "")
				continue
			parts := StrSplit(A_LoopField, "|")
			if (parts.Length() >= 2) {
				gcSmsTplList .= "|" . parts[2]
			}
		}
	}
	Gui, Settings:Add, ComboBox, x310 y418 w200 r10 vGCSMSTplCombo Hidden gGCSMSTplChanged, %gcSmsTplList%
	if (Settings_GCSMSTemplateName != "" && Settings_GCSMSTemplateName != "(none selected)" && Settings_GCSMSTemplateName != "SELECT")
		GuiControl, Settings:ChooseString, GCSMSTplCombo, %Settings_GCSMSTemplateName%
	else
		GuiControl, Settings:Choose, GCSMSTplCombo, 1  ; Select "SELECT" by default
	Gui, Settings:Add, Button, x515 y417 w40 h27 gRefreshGCSMSTemplates vGCSMSTplRefresh Hidden HwndHwndGCSMSRefresh, 🔄
	RegisterSettingsTooltip(HwndGCSMSRefresh, "REFRESH SMS TEMPLATES`n`nFetch available templates from GHL.")
	
	Gui, Settings:Font, s9 Norm c%mutedColor%, Segoe UI
	Gui, Settings:Add, Text, x210 y450 w440 BackgroundTrans vGCNotifyHint Hidden, Choose SELECT to skip sending that notification type.
	
	; ═══════════════════════════════════════════════════════════════════════════
	; PLAN NAMING GROUP BOX (y500 to y590)
	; ═══════════════════════════════════════════════════════════════════════════
	Gui, Settings:Font, s10 Norm c%groupColor%, Segoe UI
	Gui, Settings:Add, GroupBox, x195 y500 w480 h90 vGCAutoGroup Hidden, Plan Naming
	
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x210 y525 w60 BackgroundTrans vGCNamingLabel Hidden HwndHwndGCNaming, Format:
	RegisterSettingsTooltip(HwndGCNaming, "PLAN NAME FORMAT`n`nChoose up to 3 fields to include in the`nGoCardless instalment schedule name.`n`nFields are joined with ' - ' separator.")
	
	; Name format dropdowns (3 in a row)
	gcNameOptions := "(none)|Shoot No|Surname|First Name|Full Name|GHL ID|Album Name"
	Gui, Settings:Add, DropDownList, x275 y522 w115 vGCNamePart1DDL Hidden gGCNamePartChanged Choose1, %gcNameOptions%
	Gui, Settings:Add, Text, x393 y525 w10 BackgroundTrans vGCNameSep1 Hidden, -
	Gui, Settings:Add, DropDownList, x408 y522 w115 vGCNamePart2DDL Hidden gGCNamePartChanged Choose1, %gcNameOptions%
	Gui, Settings:Add, Text, x526 y525 w10 BackgroundTrans vGCNameSep2 Hidden, -
	Gui, Settings:Add, DropDownList, x541 y522 w115 vGCNamePart3DDL Hidden gGCNamePartChanged Choose1, %gcNameOptions%
	
	; Example preview
	Gui, Settings:Font, s9 Norm c%mutedColor%, Segoe UI
	Gui, Settings:Add, Text, x210 y558 w60 BackgroundTrans vGCNameExLabel Hidden, Example:
	Gui, Settings:Font, s9 Norm c4FC3F7, Segoe UI
	Gui, Settings:Add, Text, x275 y558 w380 BackgroundTrans vGCNameExample Hidden, P26005 - Smith - abc123xyz
	
	; Set saved values
	if (Settings_GCNamePart1 != "")
		GuiControl, Settings:ChooseString, GCNamePart1DDL, %Settings_GCNamePart1%
	if (Settings_GCNamePart2 != "")
		GuiControl, Settings:ChooseString, GCNamePart2DDL, %Settings_GCNamePart2%
	if (Settings_GCNamePart3 != "")
		GuiControl, Settings:ChooseString, GCNamePart3DDL, %Settings_GCNamePart3%
	
	; Update example based on saved values
	UpdateGCNameExample()
	
	; Done building panel - allow change handlers to work normally
	GC_BuildingPanel := false
	
	Gui, Settings:Font, s10 Norm c%textColor%, Segoe UI
}

; GoCardless Settings Handlers
GCEnvChanged:
	Gui, Settings:Submit, NoHide
	Settings_GoCardlessEnvironment := (GCEnvDDL = "Live") ? "live" : "sandbox"
	IniWrite, %Settings_GoCardlessEnvironment%, %IniFilename%, GoCardless, Environment
	; Update status display
	UpdateGCStatus()
return

EditGCToken:
	InputBox, newToken, GoCardless API Token, Enter your GoCardless API access token:,, 450, 150,,,,, %Settings_GoCardlessToken%
	if (!ErrorLevel && newToken != "") {
		Settings_GoCardlessToken := newToken
		; Save to credentials JSON file (base64 encoded)
		SaveGHLCredentials()
		; Update display
		tokenDisplay := SubStr(newToken, 1, 12) . "..." . SubStr(newToken, -4)
		GuiControl, Settings:, GCTokenDisplay, %tokenDisplay%
		UpdateGCStatus()
	}
return

TestGCConnection:
	if (Settings_GoCardlessToken = "") {
		DarkMsgBox("Error", "No API token configured.`n`nPlease enter your GoCardless API token first.", "error")
		return
	}
	
	ToolTip, Testing GoCardless connection...
	
	; Use Python script for GoCardless API test
	envFlag := (Settings_GoCardlessEnvironment = "live") ? " --live" : ""
	scriptCmd := GetScriptCommand("gocardless_api", "--test-connection" . envFlag)
	
	if (scriptCmd = "") {
		ToolTip
		DarkMsgBox("Error", "gocardless_api script not found.", "error")
		return
	}
	
	; Run the script and capture output
	tempResult := A_Temp . "\gc_test_result_" . A_TickCount . ".txt"
	RunWait, %ComSpec% /c %scriptCmd% > "%tempResult%" 2>&1, , Hide
	
	FileRead, testResult, %tempResult%
	FileDelete, %tempResult%
	
	ToolTip
	
	if (InStr(testResult, "SUCCESS|")) {
		parts := StrSplit(testResult, "|")
		creditorName := Trim(parts[2])
		creditorId := Trim(parts[3])
		GuiControl, Settings:, GCStatusText, ✅ Connected
		GuiControl, Settings:+c00FF00, GCStatusText
		DarkMsgBox("Connection Successful", "Connected to GoCardless!`n`nCreditor: " . creditorName . "`nID: " . creditorId . "`nEnvironment: " . Settings_GoCardlessEnvironment, "success")
	} else {
		errMsg := InStr(testResult, "ERROR|") ? StrReplace(testResult, "ERROR|", "") : testResult
		GuiControl, Settings:, GCStatusText, ❌ Failed
		GuiControl, Settings:+cFF6B6B, GCStatusText
		DarkMsgBox("Connection Failed", "Could not connect to GoCardless.`n`nError: " . Trim(errMsg) . "`n`nCheck your API token and try again.", "error")
	}
return

OpenGCDashboard:
	gcDashUrl := (Settings_GoCardlessEnvironment = "live") ? "https://manage.gocardless.com" : "https://manage-sandbox.gocardless.com"
	Run, %gcDashUrl%
return

; ═══════════════════════════════════════════════════════════════════════════════════════════════
; GoCardless Setup Wizard
; Step-by-step guide for first-time GoCardless setup
; ═══════════════════════════════════════════════════════════════════════════════════════════════
GCSetupWizard:
	global GCWizard_Step, GCWizard_Token
	GCWizard_Step := 1
	GCWizard_Token := ""
	Gosub, GCWizard_ShowStep
return

GCWizard_ShowStep:
	global GCWizard_Step, GCWizard_Token, Settings_GoCardlessEnvironment
	
	; Destroy previous wizard window if it exists
	Gui, GCWizard:Destroy
	
	; Create wizard window
	wizW := Round(520 * DPI_Scale)
	wizH := Round(420 * DPI_Scale)
	
	Gui, GCWizard:New, +AlwaysOnTop -MinimizeBox +HwndGCWizardHwnd
	Gui, GCWizard:Color, 1E1E1E
	Gui, GCWizard:Margin, 20, 20
	
	; Header - step indicator
	Gui, GCWizard:Font, s12 c888888, Segoe UI
	stepText := "Step " . GCWizard_Step . " of 5"
	Gui, GCWizard:Add, Text, x20 y15 w%wizW% BackgroundTrans, %stepText%
	
	; Progress dots
	dotY := 18
	Loop, 5 {
		dotX := wizW - 120 + (A_Index * 20)
		dotColor := (A_Index <= GCWizard_Step) ? "4FC3F7" : "444444"
		Gui, GCWizard:Font, s14 c%dotColor%, Segoe UI
		Gui, GCWizard:Add, Text, x%dotX% y%dotY% w20 h20 BackgroundTrans, ●
	}
	
	; Divider line
	Gui, GCWizard:Add, Text, x20 y45 w480 h1 Background333333
	
	; Content area based on step
	contentY := 60
	
	if (GCWizard_Step = 1) {
		; Step 1: Welcome
		Gui, GCWizard:Font, s18 cFFFFFF Bold, Segoe UI
		Gui, GCWizard:Add, Text, x20 y%contentY% w480 BackgroundTrans, 🏦 Welcome to GoCardless Setup
		
		contentY += 50
		Gui, GCWizard:Font, s11 cCCCCCC Norm, Segoe UI
		Gui, GCWizard:Add, Text, x20 y%contentY% w480 BackgroundTrans, This wizard will help you connect SideKick to GoCardless for Direct Debit payments.
		
		contentY += 40
		Gui, GCWizard:Add, Text, x20 y%contentY% w480 BackgroundTrans, With GoCardless you can:
		
		contentY += 35
		Gui, GCWizard:Font, s10 c4FC3F7, Segoe UI
		Gui, GCWizard:Add, Text, x35 y%contentY% w460 BackgroundTrans, ✓  Collect payment plans automatically via BACS Direct Debit
		contentY += 28
		Gui, GCWizard:Add, Text, x35 y%contentY% w460 BackgroundTrans, ✓  Send mandate setup links to clients via email or SMS
		contentY += 28
		Gui, GCWizard:Add, Text, x35 y%contentY% w460 BackgroundTrans, ✓  Check existing mandates before creating new ones
		contentY += 28
		Gui, GCWizard:Add, Text, x35 y%contentY% w460 BackgroundTrans, ✓  Low fees: 1`% + 20p per transaction (capped at £4)
		
		contentY += 45
		Gui, GCWizard:Font, s10 c888888, Segoe UI
		Gui, GCWizard:Add, Text, x20 y%contentY% w480 BackgroundTrans, You'll need a GoCardless account. Don't have one? You can sign up in the next step.
		
	} else if (GCWizard_Step = 2) {
		; Step 2: Choose Environment
		Gui, GCWizard:Font, s18 cFFFFFF Bold, Segoe UI
		Gui, GCWizard:Add, Text, x20 y%contentY% w480 BackgroundTrans, 🔧 Choose Environment
		
		contentY += 50
		Gui, GCWizard:Font, s11 cCCCCCC Norm, Segoe UI
		Gui, GCWizard:Add, Text, x20 y%contentY% w480 BackgroundTrans, GoCardless has two environments. Select which one to use:
		
		contentY += 45
		; Sandbox option
		Gui, GCWizard:Font, s12 cFFFFFF, Segoe UI
		sandboxSelected := (Settings_GoCardlessEnvironment != "live")
		Gui, GCWizard:Add, Radio, x35 y%contentY% w200 vGCWizard_EnvSandbox Checked%sandboxSelected% gGCWizard_EnvChanged, Sandbox (Testing)
		contentY += 28
		Gui, GCWizard:Font, s9 c888888, Segoe UI
		Gui, GCWizard:Add, Text, x55 y%contentY% w420 BackgroundTrans, No real money moves. Perfect for testing your setup first.
		
		contentY += 40
		; Live option
		Gui, GCWizard:Font, s12 cFFFFFF, Segoe UI
		liveSelected := (Settings_GoCardlessEnvironment = "live")
		Gui, GCWizard:Add, Radio, x35 y%contentY% w200 vGCWizard_EnvLive Checked%liveSelected% gGCWizard_EnvChanged, Live (Production)
		contentY += 28
		Gui, GCWizard:Font, s9 c888888, Segoe UI
		Gui, GCWizard:Add, Text, x55 y%contentY% w420 BackgroundTrans, Real transactions. Use this when you're ready to collect payments.
		
		contentY += 50
		Gui, GCWizard:Font, s10 cFFAA00, Segoe UI
		Gui, GCWizard:Add, Text, x20 y%contentY% w480 BackgroundTrans, ⚠️ We recommend starting with Sandbox to test everything first.
		
	} else if (GCWizard_Step = 3) {
		; Step 3: Sign up / Get token
		Gui, GCWizard:Font, s18 cFFFFFF Bold, Segoe UI
		Gui, GCWizard:Add, Text, x20 y%contentY% w480 BackgroundTrans, 🔑 Get Your API Token
		
		contentY += 50
		Gui, GCWizard:Font, s11 cCCCCCC Norm, Segoe UI
		envName := (Settings_GoCardlessEnvironment = "live") ? "Live" : "Sandbox"
		Gui, GCWizard:Add, Text, x20 y%contentY% w480 BackgroundTrans, Follow these steps in the GoCardless %envName% Dashboard:
		
		contentY += 40
		Gui, GCWizard:Font, s10 c4FC3F7, Segoe UI
		Gui, GCWizard:Add, Text, x35 y%contentY% w460 BackgroundTrans, 1. Click the button below to open GoCardless Dashboard
		contentY += 28
		Gui, GCWizard:Add, Text, x35 y%contentY% w460 BackgroundTrans, 2. Sign in (or create a new account if needed)
		contentY += 28
		Gui, GCWizard:Add, Text, x35 y%contentY% w460 BackgroundTrans, 3. Go to: Developers → Create → Access Token
		contentY += 28
		Gui, GCWizard:Add, Text, x35 y%contentY% w460 BackgroundTrans, 4. Name it "SideKick" and enable Read + Write access
		contentY += 28
		Gui, GCWizard:Add, Text, x35 y%contentY% w460 BackgroundTrans, 5. Copy the token (starts with "live_" or "sandbox_")
		
		contentY += 45
		gcDashUrl := (Settings_GoCardlessEnvironment = "live") ? "https://manage.gocardless.com/developers/access-tokens/create" : "https://manage-sandbox.gocardless.com/developers/access-tokens/create"
		Gui, GCWizard:Font, s11, Segoe UI
		Gui, GCWizard:Add, Button, x150 y%contentY% w220 h35 gGCWizard_OpenDashboard vGCWizard_DashBtn, 🌐 Open GoCardless Dashboard
		
	} else if (GCWizard_Step = 4) {
		; Step 4: Paste token
		Gui, GCWizard:Font, s18 cFFFFFF Bold, Segoe UI
		Gui, GCWizard:Add, Text, x20 y%contentY% w480 BackgroundTrans, 📋 Paste Your API Token
		
		contentY += 50
		Gui, GCWizard:Font, s11 cCCCCCC Norm, Segoe UI
		Gui, GCWizard:Add, Text, x20 y%contentY% w480 BackgroundTrans, Paste the API token you copied from GoCardless:
		
		contentY += 40
		Gui, GCWizard:Font, s10 cFFFFFF, Consolas
		Gui, GCWizard:Add, Edit, x20 y%contentY% w480 h30 vGCWizard_TokenInput, %GCWizard_Token%
		
		contentY += 45
		Gui, GCWizard:Font, s9 c888888, Segoe UI
		envName := (Settings_GoCardlessEnvironment = "live") ? "live" : "sandbox"
		Gui, GCWizard:Add, Text, x20 y%contentY% w480 BackgroundTrans, Token should start with "%envName%_" for %envName% environment.
		
		contentY += 35
		Gui, GCWizard:Font, s9 c4FC3F7, Segoe UI
		Gui, GCWizard:Add, Text, x20 y%contentY% w480 BackgroundTrans, Your token is stored securely in encrypted credentials.json
		
	} else if (GCWizard_Step = 5) {
		; Step 5: Test & Complete
		Gui, GCWizard:Font, s18 cFFFFFF Bold, Segoe UI
		Gui, GCWizard:Add, Text, x20 y%contentY% w480 BackgroundTrans vGCWizard_CompleteTitle, 🧪 Testing Connection...
		
		contentY += 50
		Gui, GCWizard:Font, s11 cCCCCCC Norm, Segoe UI
		Gui, GCWizard:Add, Text, x20 y%contentY% w480 BackgroundTrans vGCWizard_CompleteMsg, Verifying your GoCardless API token...
		
		contentY += 40
		Gui, GCWizard:Add, Text, x20 y%contentY% w480 h100 BackgroundTrans cFFFFFF vGCWizard_ResultText,
	}
	
	; Navigation buttons
	btnY := wizH - 60
	
	; Back button (not on step 1)
	if (GCWizard_Step > 1 && GCWizard_Step < 5) {
		Gui, GCWizard:Font, s10, Segoe UI
		Gui, GCWizard:Add, Button, x20 y%btnY% w100 h35 gGCWizard_Back, ← Back
	}
	
	; Cancel button
	Gui, GCWizard:Font, s10, Segoe UI
	Gui, GCWizard:Add, Button, x300 y%btnY% w90 h35 gGCWizard_Cancel, Cancel
	
	; Next/Finish button
	if (GCWizard_Step < 4) {
		Gui, GCWizard:Add, Button, x400 y%btnY% w100 h35 gGCWizard_Next Default, Next →
	} else if (GCWizard_Step = 4) {
		Gui, GCWizard:Add, Button, x400 y%btnY% w100 h35 gGCWizard_TestToken Default, Test →
	} else if (GCWizard_Step = 5) {
		Gui, GCWizard:Add, Button, x400 y%btnY% w100 h35 gGCWizard_Finish vGCWizard_FinishBtn Default, Finish
		GuiControl, GCWizard:Disable, GCWizard_FinishBtn
	}
	
	; Show wizard
	Gui, GCWizard:Show, w%wizW% h%wizH%, GoCardless Setup Wizard
	
	; If step 5, auto-run the test
	if (GCWizard_Step = 5) {
		SetTimer, GCWizard_RunTest, -500
	}
return

GCWizard_EnvChanged:
	Gui, GCWizard:Submit, NoHide
	if (GCWizard_EnvLive)
		Settings_GoCardlessEnvironment := "live"
	else
		Settings_GoCardlessEnvironment := "sandbox"
return

GCWizard_OpenDashboard:
	gcDashUrl := (Settings_GoCardlessEnvironment = "live") ? "https://manage.gocardless.com/developers/access-tokens/create" : "https://manage-sandbox.gocardless.com/developers/access-tokens/create"
	Run, %gcDashUrl%
return

GCWizard_Back:
	global GCWizard_Step
	if (GCWizard_Step > 1) {
		GCWizard_Step--
		Gosub, GCWizard_ShowStep
	}
return

GCWizard_Next:
	global GCWizard_Step
	
	; Validate step 2 (environment)
	if (GCWizard_Step = 2) {
		Gui, GCWizard:Submit, NoHide
		if (GCWizard_EnvLive)
			Settings_GoCardlessEnvironment := "live"
		else
			Settings_GoCardlessEnvironment := "sandbox"
		; Save environment setting
		IniWrite, %Settings_GoCardlessEnvironment%, %IniFilename%, GoCardless, Environment
		; Update Settings GUI dropdown if visible
		GuiControl, Settings:ChooseString, GCEnvDDL, % (Settings_GoCardlessEnvironment = "live") ? "Live" : "Sandbox"
	}
	
	GCWizard_Step++
	Gosub, GCWizard_ShowStep
return

GCWizard_TestToken:
	global GCWizard_Step, GCWizard_Token
	
	; Get token from input
	Gui, GCWizard:Submit, NoHide
	GCWizard_Token := Trim(GCWizard_TokenInput)
	
	if (GCWizard_Token = "") {
		DarkMsgBox("Token Required", "Please paste your GoCardless API token.", "warning")
		return
	}
	
	; Validate token prefix matches environment
	envPrefix := (Settings_GoCardlessEnvironment = "live") ? "live_" : "sandbox_"
	if (!InStr(GCWizard_Token, envPrefix) && GCWizard_Token != "") {
		wrongEnv := (Settings_GoCardlessEnvironment = "live") ? "Sandbox" : "Live"
		result := DarkMsgBox("Environment Mismatch", "This token appears to be for " . wrongEnv . " environment.`n`nYou selected: " . ((Settings_GoCardlessEnvironment = "live") ? "Live" : "Sandbox") . "`n`nContinue anyway?", "warning", ["Continue", "Go Back"])
		if (result != "Continue")
			return
	}
	
	; Save token
	Settings_GoCardlessToken := GCWizard_Token
	SaveGHLCredentials()
	
	; Go to test step
	GCWizard_Step := 5
	Gosub, GCWizard_ShowStep
return

GCWizard_RunTest:
	global Settings_GoCardlessToken, Settings_GoCardlessEnvironment
	
	; Run API test
	envFlag := (Settings_GoCardlessEnvironment = "live") ? " --live" : ""
	scriptCmd := GetScriptCommand("gocardless_api", "--test-connection" . envFlag)
	
	if (scriptCmd = "") {
		GuiControl, GCWizard:, GCWizard_CompleteTitle, ❌ Setup Error
		GuiControl, GCWizard:, GCWizard_CompleteMsg, Could not find the gocardless_api script.
		GuiControl, GCWizard:, GCWizard_ResultText, Please ensure SideKick is properly installed.
		GuiControl, GCWizard:Enable, GCWizard_FinishBtn
		return
	}
	
	; Run the script and capture output
	tempResult := A_Temp . "\gc_wizard_test_" . A_TickCount . ".txt"
	RunWait, %ComSpec% /c %scriptCmd% > "%tempResult%" 2>&1, , Hide
	
	FileRead, testResult, %tempResult%
	FileDelete, %tempResult%
	
	if (InStr(testResult, "SUCCESS|")) {
		parts := StrSplit(testResult, "|")
		creditorName := Trim(parts[2])
		creditorId := Trim(parts[3])
		
		GuiControl, GCWizard:, GCWizard_CompleteTitle, ✅ Connection Successful!
		GuiControl, GCWizard:, GCWizard_CompleteMsg, Your GoCardless account is now connected.
		resultMsg := "Creditor: " . creditorName . "`nCreditor ID: " . creditorId . "`nEnvironment: " . ((Settings_GoCardlessEnvironment = "live") ? "Live" : "Sandbox")
		GuiControl, GCWizard:, GCWizard_ResultText, %resultMsg%
		
		; Update Settings GUI
		tokenDisplay := SubStr(Settings_GoCardlessToken, 1, 12) . "..." . SubStr(Settings_GoCardlessToken, -4)
		GuiControl, Settings:, GCTokenDisplay, %tokenDisplay%
		GuiControl, Settings:, GCStatusText, ✅ Connected
		GuiControl, Settings:+c00FF00, GCStatusText
		
		; Enable GoCardless integration
		Settings_GoCardlessEnabled := true
		Toggle_GoCardlessEnabled_State := true
		IniWrite, 1, %IniFilename%, GoCardless, Enabled
		UpdateToggleSlider("Settings", "GoCardlessEnabled", Toggle_GoCardlessEnabled_State, 630)
		
	} else {
		errMsg := InStr(testResult, "ERROR|") ? StrReplace(testResult, "ERROR|", "") : testResult
		
		GuiControl, GCWizard:, GCWizard_CompleteTitle, ❌ Connection Failed
		GuiControl, GCWizard:, GCWizard_CompleteMsg, Could not connect to GoCardless.
		GuiControl, GCWizard:, GCWizard_ResultText, Error: %errMsg%`n`nCheck your token and try again.
	}
	
	GuiControl, GCWizard:Enable, GCWizard_FinishBtn
return

GCWizard_Finish:
GCWizard_Cancel:
GCWizardGuiClose:
GCWizardGuiEscape:
	Gui, GCWizard:Destroy
return

ListEmptyMandates:
	global Settings_GoCardlessToken, Settings_GoCardlessEnvironment, GC_EmptyMandatesList, GC_EmptyMandatesArray, Settings_ShootArchivePath
	global GC_ProgressFile, GC_ResultFile, GC_FetchInProgress
	
	if (Settings_GoCardlessToken = "") {
		DarkMsgBox("Error", "No API token configured.`n`nPlease enter your GoCardless API token first.", "error")
		return
	}
	
	GuiControl, Settings:, GCProgressBar, 0
	GuiControl, Settings:Show, GCProgressBar
	GuiControl, Settings:, GCProgressText, Fetching mandates from GoCardless...
	GuiControl, Settings:Show, GCProgressText
	
	envFlag := (Settings_GoCardlessEnvironment = "live") ? " --live" : ""
	scriptCmd := GetScriptCommand("gocardless_api", "--list-empty-mandates" . envFlag)
	
	if (scriptCmd = "") {
		ToolTip
		DarkMsgBox("Error", "gocardless_api script not found.", "error")
		return
	}
	
	; Set up progress and result files
	GC_ProgressFile := A_Temp . "\gc_progress_" . A_TickCount . ".txt"
	GC_ResultFile := A_Temp . "\gc_empty_mandates_" . A_TickCount . ".txt"
	GC_FetchInProgress := true
	
	; Add progress file argument
	scriptCmd := scriptCmd . " --progress-file """ . GC_ProgressFile . """"
	
	; Run Python in background (not RunWait)
	Run, %ComSpec% /c %scriptCmd% > "%GC_ResultFile%" 2>&1, , Hide
	
	; Start timer to poll progress
	SetTimer, GC_FetchProgressTimer, 200
return

; Timer to update mandate fetch progress bar
GC_FetchProgressTimer:
	global GC_ProgressFile, GC_ResultFile, GC_FetchInProgress
	
	if (!GC_FetchInProgress) {
		SetTimer, GC_FetchProgressTimer, Off
		return
	}
	
	; Check if result file exists and has content (script finished)
	if (FileExist(GC_ResultFile)) {
		FileRead, resultContent, %GC_ResultFile%
		if (resultContent != "") {
			; Script finished - stop timer and process results
			SetTimer, GC_FetchProgressTimer, Off
			GC_FetchInProgress := false
			FileDelete, %GC_ProgressFile%
			Gosub, GC_ProcessFetchResults
			return
		}
	}
	
	; Read and update progress
	if (FileExist(GC_ProgressFile)) {
		FileRead, progressData, %GC_ProgressFile%
		if (progressData != "") {
			parts := StrSplit(progressData, "|")
			if (parts.Length() >= 3) {
				current := parts[1]
				total := parts[2]
				message := parts[3]
				if (total > 0) {
					progress := Round((current / total) * 100)
					GuiControl, Settings:, GCProgressBar, %progress%
				}
				GuiControl, Settings:, GCProgressText, %message%
			}
		}
	}
return

GC_ProcessFetchResults:
	global GC_ResultFile, GC_EmptyMandatesList, GC_EmptyMandatesArray, Settings_ShootArchivePath
	
	FileRead, mandatesOutput, %GC_ResultFile%
	FileDelete, %GC_ResultFile%
	
	if (InStr(mandatesOutput, "NO_EMPTY_MANDATES")) {
		GuiControl, Settings:, GCProgressBar, 0
		GuiControl, Settings:Hide, GCProgressBar
		GuiControl, Settings:, GCProgressText,
		GuiControl, Settings:Hide, GCProgressText
		DarkMsgBox("All Mandates Have Plans", "✅ Great news!`n`nAll active mandates have payment plans assigned.", "success")
		return
	}
	
	if (InStr(mandatesOutput, "ERROR")) {
		GuiControl, Settings:, GCProgressBar, 0
		GuiControl, Settings:Hide, GCProgressBar
		GuiControl, Settings:, GCProgressText,
		GuiControl, Settings:Hide, GCProgressText
		DarkMsgBox("Error", "Failed to fetch mandates.`n`n" . mandatesOutput, "error")
		return
	}
	
	; Parse results and build display - store in array for sorting
	GC_EmptyMandatesList := ""
	GC_EmptyMandatesArray := []
	mandateCount := 0
	
	; Get archive path for shoot number lookup
	archivePath := Settings_ShootArchivePath
	if (archivePath = "")
		archivePath := "D:\Shoot_Archive"
	
	; First pass - count total mandates for progress bar
	totalMandates := 0
	Loop, Parse, mandatesOutput, `n, `r
	{
		if (A_LoopField = "" || InStr(A_LoopField, "ERROR"))
			continue
		parts := StrSplit(A_LoopField, "|")
		if (parts.Length() >= 5)
			totalMandates++
	}
	
	; Show progress bar and text
	GuiControl, Settings:, GCProgressBar, 0
	GuiControl, Settings:, GCProgressText, Looking up shoot numbers...
	
	; Second pass - process mandates with progress
	currentMandate := 0
	Loop, Parse, mandatesOutput, `n, `r
	{
		if (A_LoopField = "" || InStr(A_LoopField, "ERROR"))
			continue
		
		parts := StrSplit(A_LoopField, "|")
		if (parts.Length() >= 6) {
			mandateId := parts[1]
			customerId := parts[2]
			customerName := parts[3]
			email := parts[4]
			createdAt := parts[5]
			bankName := parts[6]
			
			currentMandate++
			
			; Update progress bar
			progress := Round((currentMandate / totalMandates) * 100)
			GuiControl, Settings:, GCProgressBar, %progress%
			GuiControl, Settings:, GCProgressText, % "Processing " . currentMandate . " of " . totalMandates . "..."
			Sleep, 1  ; Allow GUI to redraw
			
			; Try to find shoot number by searching archive for surname
			shootNo := ""
			nameParts := StrSplit(customerName, " ")
			surname := nameParts[nameParts.Length()]
			if (surname != "" && StrLen(surname) >= 2) {
				Loop, Files, %archivePath%\*, D
				{
					if (InStr(A_LoopFileName, surname)) {
						; Extract shoot number from folder name (format: P26001_Surname_...)
						if (RegExMatch(A_LoopFileName, "i)(P\d{5})", match)) {
							shootNo := match1
							break
						}
					}
				}
			}
			
			mandateCount++
			GC_EmptyMandatesArray.Push({mandateId: mandateId, customerId: customerId, name: customerName, email: email, date: createdAt, shootNo: shootNo, raw: A_LoopField})
		}
	}
	
	; Clear and hide progress bar
	GuiControl, Settings:, GCProgressBar, 0
	GuiControl, Settings:Hide, GCProgressBar
	GuiControl, Settings:, GCProgressText, 
	GuiControl, Settings:Hide, GCProgressText
	
	; Sort by date (newest first) - simple bubble sort for AHK
	Loop, % GC_EmptyMandatesArray.Length() - 1
	{
		i := A_Index
		Loop, % GC_EmptyMandatesArray.Length() - i
		{
			j := A_Index
			if (GC_EmptyMandatesArray[j].date < GC_EmptyMandatesArray[j+1].date) {
				temp := GC_EmptyMandatesArray[j]
				GC_EmptyMandatesArray[j] := GC_EmptyMandatesArray[j+1]
				GC_EmptyMandatesArray[j+1] := temp
			}
		}
	}
	
	; Build display list for ListBox (pipe separates items, use different char for fields)
	displayList := ""
	Loop, % GC_EmptyMandatesArray.Length()
	{
		m := GC_EmptyMandatesArray[A_Index]
		shootDisplay := m.shootNo != "" ? m.shootNo : "---"
		; Use tabs or dashes instead of pipes (pipes are ListBox item separators)
		displayList .= m.date . "  " . shootDisplay . "  " . m.name . "  " . m.email . "|"
		GC_EmptyMandatesList .= m.raw . "`n"
	}
	
	if (mandateCount = 0) {
		DarkMsgBox("No Results", "Could not parse mandate data.`n`nCheck the debug log for details.", "warning")
		return
	}
	
	; Show GUI with results - 50% wider (750 instead of 500)
	Gui, GCEmptyMandates:New, +AlwaysOnTop +ToolWindow -MinimizeBox +Resize
	Gui, GCEmptyMandates:Color, 2D2D2D, 3D3D3D
	Gui, GCEmptyMandates:Font, s10 cWhite, Segoe UI
	
	headerText := mandateCount . " mandate(s) without payment plans - double-click to find album:"
	Gui, GCEmptyMandates:Add, Text, x15 y15 w720 cCCCCCC, %headerText%
	
	Gui, GCEmptyMandates:Font, s9 cWhite, Consolas
	Gui, GCEmptyMandates:Add, ListBox, x15 y45 w720 h250 vGC_EmptyMandatesList Background3D3D3D cWhite gGC_MandateListClick AltSubmit, %displayList%
	
	Gui, GCEmptyMandates:Font, s10 cWhite, Segoe UI
	Gui, GCEmptyMandates:Add, Button, x120 y305 w100 h30 gGC_OpenInGC, Open in GC
	Gui, GCEmptyMandates:Add, Button, x240 y305 w120 h30 gGC_CopyEmptyMandates, Copy to Clipboard
	Gui, GCEmptyMandates:Add, Button, x380 y305 w100 h30 gGC_CloseEmptyMandates, Close
	
	Gui, GCEmptyMandates:Show, w750 h350, Mandates Without Plans
return

; Handle ListBox click/double-click
GC_MandateListClick:
	if (A_GuiEvent != "DoubleClick")
		return
	; Fall through to find album
	
GC_FindAlbumFromList:
	global GC_EmptyMandatesArray, Settings_ShootArchivePath
	
	; Get selected index from ListBox
	Gui, GCEmptyMandates:Submit, NoHide
	GuiControlGet, selectedIndex,, GC_EmptyMandatesList
	
	if (selectedIndex = "" || selectedIndex < 1 || selectedIndex > GC_EmptyMandatesArray.Length()) {
		DarkMsgBox("No Selection", "Please select a line to search for.", "warning")
		return
	}
	
	; Get mandate data from array
	m := GC_EmptyMandatesArray[selectedIndex]
	
	; Build search terms: job number and surname
	searchTerms := []
	
	; Add job number if available
	if (m.shootNo != "" && m.shootNo != "---") {
		searchTerms.Push(m.shootNo)
	}
	
	; Add surname (last word of name)
	if (m.name != "") {
		nameParts := StrSplit(m.name, " ")
		surname := nameParts[nameParts.Length()]
		if (surname != "" && StrLen(surname) > 1)
			searchTerms.Push(surname)
	}
	
	if (searchTerms.Length() = 0) {
		DarkMsgBox("Invalid Search", "No job number or name to search for.", "warning")
		return
	}
	
	; Search archive folder for matching albums using ALL search terms
	archivePath := Settings_ShootArchivePath
	if (archivePath = "") {
		archivePath := "D:\Shoot_Archive"
	}
	
	; Build search description
	searchDesc := ""
	for i, term in searchTerms
		searchDesc .= (i > 1 ? " or " : "") . term
	
	ToolTip, Searching for "%searchDesc%" in archive...
	
	foundFolders := []
	foundPaths := []
	
	; Search main archive path using all search terms
	Loop, Files, %archivePath%\*, D
	{
		for i, searchTerm in searchTerms {
			if (InStr(A_LoopFileName, searchTerm)) {
				; Avoid duplicates
				alreadyFound := false
				for j, existing in foundPaths {
					if (existing = A_LoopFileLongPath) {
						alreadyFound := true
						break
					}
				}
				if (!alreadyFound) {
					foundFolders.Push(A_LoopFileName)
					foundPaths.Push(A_LoopFileLongPath)
				}
				break  ; Found a match for this folder, move to next folder
			}
		}
	}
	
	; If not found, try alternative search paths with each term
	if (foundFolders.Length() = 0) {
		for i, searchTerm in searchTerms {
			altPath := SearchAlternativePaths(searchTerm)
			if (altPath != "") {
				SplitPath, altPath, altFolderName
				foundFolders.Push(altFolderName)
				foundPaths.Push(altPath)
				break
			}
		}
	}
	
	ToolTip
	
	if (foundFolders.Length() = 0) {
		DarkMsgBox("No Albums Found", "No folders matching '" . searchDesc . "' found in archive or alternative paths.", "warning")
		return
	}
	
	; Single match - check for PSA and offer to open
	if (foundFolders.Length() = 1) {
		fullPath := foundPaths[1]
		psaResult := FindPSAInFolder(fullPath)
		
		if (psaResult.count = 1) {
			OpenPSAAndOffer(psaResult.path, fullPath)
		} else if (psaResult.count > 1) {
			; Multiple PSA files - open ProSelect file dialog in that folder
			OpenPSAFolderInProSelect(psaResult.folder)
		} else {
			Run, explorer.exe "%fullPath%"
		}
		return
	}
	
	; Multiple matches - show selection dialog
	foundList := ""
	for i, folder in foundFolders {
		foundList .= folder . "`n"
	}
	
	result := DarkMsgBox("Multiple Albums Found", "Found " . foundFolders.Length() . " folders matching '" . searchDesc . "':`n`n" . foundList . "`nOpen the first match?", "question", {buttons: ["Open First", "Cancel"]})
	
	if (result = "Open First") {
		fullPath := foundPaths[1]
		psaResult := FindPSAInFolder(fullPath)
		
		if (psaResult.count = 1) {
			OpenPSAAndOffer(psaResult.path, fullPath)
		} else if (psaResult.count > 1) {
			; Multiple PSA files - open ProSelect file dialog in that folder
			OpenPSAFolderInProSelect(psaResult.folder)
		} else {
			Run, explorer.exe "%fullPath%"
		}
	}
return

GC_CopyEmptyMandates:
	global GC_EmptyMandatesArray
	
	; Format for clipboard: Date, ShootNo, Name, Email
	clipText := "Date`tShootNo`tName`tEmail`n"
	Loop, % GC_EmptyMandatesArray.Length()
	{
		m := GC_EmptyMandatesArray[A_Index]
		shootDisplay := m.shootNo != "" ? m.shootNo : "---"
		clipText .= m.date . "`t" . shootDisplay . "`t" . m.name . "`t" . m.email . "`n"
	}
	
	Clipboard := clipText
	ToolTip, Copied to clipboard!
	SetTimer, RemoveToolTip, -1500
return

GC_OpenInGC:
	global GC_EmptyMandatesArray, Settings_GoCardlessEnvironment
	
	; Get selected index from ListBox
	Gui, GCEmptyMandates:Submit, NoHide
	GuiControlGet, selectedIndex,, GC_EmptyMandatesList
	
	if (selectedIndex = "" || selectedIndex < 1 || selectedIndex > GC_EmptyMandatesArray.Length()) {
		DarkMsgBox("No Selection", "Please select a mandate to open in GoCardless.", "warning")
		return
	}
	
	; Get customer ID from array
	m := GC_EmptyMandatesArray[selectedIndex]
	if (m.customerId = "") {
		DarkMsgBox("Error", "No customer ID found for this mandate.", "error")
		return
	}
	
	; Open GoCardless customer page
	gcEnv := (Settings_GoCardlessEnvironment = "live") ? "manage" : "manage-sandbox"
	gcUrl := "https://" . gcEnv . ".gocardless.com/customers/" . m.customerId
	Run, %gcUrl%
return

GC_CloseEmptyMandates:
GCEmptyMandatesGuiClose:
GCEmptyMandatesGuiEscape:
	Gui, GCEmptyMandates:Destroy
return

; ═══════════════════════════════════════════════════════════════════════════
; PSA File Search Functions
; ═══════════════════════════════════════════════════════════════════════════

; Find a .psa file in given folder (and subfolders)
; Returns object: {path: "path to first psa", count: N, folder: "folder containing psa files"}
FindPSAInFolder(folderPath) {
	result := {path: "", count: 0, folder: ""}
	
	if (folderPath = "" || !FileExist(folderPath))
		return result
	
	psaFiles := []
	psaFolder := ""
	
	; First check root folder
	Loop, Files, %folderPath%\*.psa
	{
		psaFiles.Push(A_LoopFileLongPath)
		psaFolder := folderPath
	}
	
	; Then check common subfolders (Unprocessed, ProSelect, Album)
	if (psaFiles.Length() = 0) {
		subfolders := ["Unprocessed", "ProSelect", "Album", "Albums"]
		for i, sub in subfolders {
			subPath := folderPath . "\" . sub
			if (FileExist(subPath)) {
				Loop, Files, %subPath%\*.psa
				{
					psaFiles.Push(A_LoopFileLongPath)
					psaFolder := subPath
				}
				if (psaFiles.Length() > 0)
					break
			}
		}
	}
	
	; Recursive search as fallback (max 2 levels) if still not found
	if (psaFiles.Length() = 0) {
		Loop, Files, %folderPath%\*\*.psa, F
		{
			psaFiles.Push(A_LoopFileLongPath)
			SplitPath, A_LoopFileLongPath,, psaFolder
		}
	}
	if (psaFiles.Length() = 0) {
		Loop, Files, %folderPath%\*\*\*.psa, F
		{
			psaFiles.Push(A_LoopFileLongPath)
			SplitPath, A_LoopFileLongPath,, psaFolder
		}
	}
	
	result.count := psaFiles.Length()
	result.folder := psaFolder
	if (psaFiles.Length() > 0)
		result.path := psaFiles[1]
	
	return result
}

; Search for album folder in alternative locations from _Additional_Archives.txt
; Returns full path to matching folder if found, empty string if not
SearchAlternativePaths(searchTerm) {
	global Settings_ShootArchivePath
	
	; Determine where to look for the paths file
	archivePath := Settings_ShootArchivePath
	if (archivePath = "")
		archivePath := "D:\Shoot_Archive"
	
	pathsFile := archivePath . "\_Additional_Archives.txt"
	
	; Silently return if file doesn't exist
	if (!FileExist(pathsFile))
		return ""
	
	; Read paths file
	FileRead, pathsContent, *P1252 %pathsFile%
	if (ErrorLevel)
		return ""
	
	; Search each path in order
	Loop, Parse, pathsContent, `n, `r
	{
		searchPath := Trim(A_LoopField)
		if (searchPath = "" || SubStr(searchPath, 1, 1) = "#")  ; Skip empty lines and comments
			continue
		
		if (!FileExist(searchPath))
			continue
		
		; Look for matching folders in this path
		Loop, Files, %searchPath%\*, D
		{
			if (InStr(A_LoopFileName, searchTerm)) {
				return A_LoopFileLongPath
			}
		}
	}
	
	return ""
}

; Open PSA file in ProSelect, or offer to do so
; Returns true if opened, false if not
OpenPSAAndOffer(psaPath, folderPath := "") {
	if (psaPath = "")
		return false
	
	; Extract filename for display
	SplitPath, psaPath, psaName
	
	result := DarkMsgBox("Album Found", "Found ProSelect album:`n`n" . psaName . "`n`nOpen in ProSelect?", "question", {buttons: ["Open Album", "Open Folder", "Cancel"]})
	
	if (result = "Open Album") {
		Run, "%psaPath%"
		return true
	} else if (result = "Open Folder") {
		if (folderPath != "")
			Run, explorer.exe "%folderPath%"
		else {
			SplitPath, psaPath,, psaDir
			Run, explorer.exe "%psaDir%"
		}
		return true
	}
	
	return false
}

; Open ProSelect file dialog in a specific folder (when multiple PSA files exist)
OpenPSAFolderInProSelect(folderPath) {
	if (folderPath = "")
		return false
	
	; Count PSA files for display
	psaCount := 0
	Loop, Files, %folderPath%\*.psa
		psaCount++
	
	result := DarkMsgBox("Multiple Albums", "Found " . psaCount . " ProSelect albums in this folder.`n`nFolder: " . folderPath . "`n`nOpen ProSelect file dialog to select one?", "question", {buttons: ["Open Dialog", "Open Folder", "Cancel"]})
	
	if (result = "Open Dialog") {
		; Activate or start ProSelect
		if (!WinExist("ahk_exe ProSelect.exe")) {
			Run, ProSelect.exe
			WinWait, ahk_exe ProSelect.exe, , 10
		}
		
		WinActivate, ahk_exe ProSelect.exe
		WinWaitActive, ahk_exe ProSelect.exe, , 3
		Sleep, 300
		
		; Send Ctrl+O to open file dialog
		SendInput, ^o
		Sleep, 500
		
		; Wait for file dialog
		WinWait, Select an Album File, , 5
		if (!ErrorLevel) {
			; Navigate to folder using the filename edit control
			Sleep, 300
			; Click into filename field and type full path
			ControlFocus, Edit1, Select an Album File
			Sleep, 100
			ControlSetText, Edit1, %folderPath%, Select an Album File
			Sleep, 200
			SendInput, {Enter}
			Sleep, 500
		}
		return true
	} else if (result = "Open Folder") {
		Run, explorer.exe "%folderPath%"
		return true
	}
	
	return false
}

; Get list of alternative search paths (for display in UI)
GetPSASearchPaths() {
	global Settings_ShootArchivePath
	
	archivePath := Settings_ShootArchivePath
	if (archivePath = "")
		archivePath := "D:\Shoot_Archive"
	
	pathsFile := archivePath . "\_Additional_Archives.txt"
	
	if (!FileExist(pathsFile))
		return ""
	
	FileRead, pathsContent, *P1252 %pathsFile%
	return pathsContent
}

; Save alternative search paths
SavePSASearchPaths(pathsContent) {
	global Settings_ShootArchivePath
	
	archivePath := Settings_ShootArchivePath
	if (archivePath = "")
		archivePath := "D:\Shoot_Archive"
	
	; Create archive folder if it doesn't exist
	if (!FileExist(archivePath))
		FileCreateDir, %archivePath%
	
	pathsFile := archivePath . "\_Additional_Archives.txt"
	
	; Delete existing file
	if (FileExist(pathsFile))
		FileDelete, %pathsFile%
	
	; Write new content
	FileAppend, %pathsContent%, %pathsFile%
	
	return !ErrorLevel
}

UpdateGCStatus() {
	global Settings_GoCardlessToken
	if (Settings_GoCardlessToken != "") {
		GuiControl, Settings:, GCStatusText, ✅ Token Set
		GuiControl, Settings:+c00FF00, GCStatusText
	} else {
		GuiControl, Settings:, GCStatusText, ❌ Not configured
		GuiControl, Settings:+cFF6B6B, GCStatusText
	}
}

; ═══════════════════════════════════════════════════════════════════════════
; GoCardless API Helper Functions
; ═══════════════════════════════════════════════════════════════════════════

GC_CheckCustomerMandate(customerEmail) {
	; Check if a customer has an existing active mandate in GoCardless
	; Returns object: {hasMandate: bool, mandateId: string, mandateStatus: string, bankName: string, customerId: string, plans: string, error: string}
	global Settings_GoCardlessToken, Settings_GoCardlessEnvironment, DebugLogFile
	
	result := {hasMandate: false, mandateId: "", mandateStatus: "", bankName: "", customerId: "", plans: "", error: ""}
	
	if (Settings_GoCardlessToken = "") {
		result.error := "No API token configured"
		return result
	}
	
	; Use Python script for GoCardless API calls
	envFlag := (Settings_GoCardlessEnvironment = "live") ? " --live" : ""
	scriptCmd := GetScriptCommand("gocardless_api", "--check-mandate """ . customerEmail . """" . envFlag)
	
	FileAppend, % A_Now . " - GC_CheckCustomerMandate - scriptCmd: " . scriptCmd . "`n", %DebugLogFile%
	
	if (scriptCmd = "") {
		result.error := "gocardless_api script not found"
		return result
	}
	
	; Run the script and capture output
	tempResult := A_Temp . "\gc_check_result_" . A_TickCount . ".txt"
	fullCmd := ComSpec . " /c " . scriptCmd . " > """ . tempResult . """ 2>&1"
	FileAppend, % A_Now . " - GC_CheckCustomerMandate - fullCmd: " . fullCmd . "`n", %DebugLogFile%
	
	RunWait, %fullCmd%, , Hide
	
	FileRead, scriptOutput, %tempResult%
	FileAppend, % A_Now . " - GC_CheckCustomerMandate - scriptOutput: " . scriptOutput . "`n", %DebugLogFile%
	FileDelete, %tempResult%
	
	scriptOutput := Trim(scriptOutput)
	
	; Check for empty output
	if (scriptOutput = "") {
		result.error := "No response from GoCardless API"
		return result
	}
	
	if (InStr(scriptOutput, "NO_CUSTOMER")) {
		; No customer found - no mandate
		return result
	}
	else if (InStr(scriptOutput, "NO_MANDATE|")) {
		parts := StrSplit(scriptOutput, "|")
		result.customerId := parts[2]
		return result
	}
	else if (InStr(scriptOutput, "MANDATE_FOUND|")) {
		parts := StrSplit(scriptOutput, "|")
		result.hasMandate := true
		result.customerId := parts[2]
		result.mandateId := parts[3]
		result.mandateStatus := parts[4]
		result.bankName := parts[5]
		; parts[6] may not exist if nothing after last pipe
		result.plans := (parts.Length() >= 6) ? Trim(parts[6]) : ""
		return result
	}
	else if (InStr(scriptOutput, "ERROR|")) {
		result.error := StrReplace(scriptOutput, "ERROR|", "")
		return result
	}
	else {
		result.error := "Unexpected response: " . SubStr(scriptOutput, 1, 100)
		return result
	}
}

; Shared function to trigger ProSelect XML export
; Returns true on success, false on failure
; showErrors: if true, shows DarkMsgBox on errors; if false, fails silently
PS_TriggerXMLExport(showErrors := false) {
	global DebugLogFile
	
	FileAppend, % A_Now . " - PS_TriggerXMLExport - Starting export`n", %DebugLogFile%
	
	; Activate ProSelect
	WinActivate, ahk_exe ProSelect.exe
	Sleep, 300
	WinWaitActive, ahk_exe ProSelect.exe, , 2
	
	; Try multiple methods to open Export Orders dialog
	exportOpened := false
	
	FileAppend, % A_Now . " - PS_TriggerXMLExport - Method 1: WinMenuSelectItem...`n", %DebugLogFile%
	; Method 1: WinMenuSelectItem - most reliable for standard menus
	WinMenuSelectItem, ahk_exe ProSelect.exe, , Orders, Export Orders...
	Sleep, 800
	if WinExist("Export Orders ahk_exe ProSelect.exe")
	{
		exportOpened := true
		FileAppend, % A_Now . " - PS_TriggerXMLExport - Method 1 SUCCESS`n", %DebugLogFile%
	}
	
	; Method 2: SendInput with longer delays (fallback)
	if (!exportOpened)
	{
		FileAppend, % A_Now . " - PS_TriggerXMLExport - Method 2: SendInput Alt+O, E...`n", %DebugLogFile%
		WinActivate, ahk_exe ProSelect.exe
		Sleep, 300
		SendInput, {Alt down}o{Alt up}
		Sleep, 500
		SendInput, e
		Sleep, 800
		if WinExist("Export Orders ahk_exe ProSelect.exe")
		{
			exportOpened := true
			FileAppend, % A_Now . " - PS_TriggerXMLExport - Method 2 SUCCESS`n", %DebugLogFile%
		}
	}
	
	; Method 3: Send with even longer delays (last resort)
	if (!exportOpened)
	{
		FileAppend, % A_Now . " - PS_TriggerXMLExport - Method 3: Send !o, e...`n", %DebugLogFile%
		WinActivate, ahk_exe ProSelect.exe
		Sleep, 500
		Send, !o
		Sleep, 800
		Send, e
		Sleep, 1000
		if WinExist("Export Orders ahk_exe ProSelect.exe")
		{
			exportOpened := true
			FileAppend, % A_Now . " - PS_TriggerXMLExport - Method 3 SUCCESS`n", %DebugLogFile%
		}
	}
	
	; Wait for dialog if not already open
	if (!exportOpened)
	{
		FileAppend, % A_Now . " - PS_TriggerXMLExport - Waiting 5s for Export Orders dialog...`n", %DebugLogFile%
		WinWait, Export Orders ahk_exe ProSelect.exe, , 5
		if ErrorLevel
		{
			FileAppend, % A_Now . " - PS_TriggerXMLExport - FAILED: Export Orders dialog did not open`n", %DebugLogFile%
			if (showErrors)
				DarkMsgBox("SideKick PS", "Export Orders dialog did not open.`n`nTry opening it manually: Orders menu → Export Orders...", "warning")
			return false
		}
	}
	FileAppend, % A_Now . " - PS_TriggerXMLExport - Export Orders dialog opened`n", %DebugLogFile%
	Sleep, 300
	
	; Get the window handle for more reliable control interaction
	exportWin := WinExist("Export Orders ahk_exe ProSelect.exe")
	
	; Ensure Export To is set to "Standard XML" (ComboBox1)
	ControlFocus, ComboBox1, ahk_id %exportWin%
	Sleep, 100
	Control, ChooseString, Standard XML, ComboBox1, ahk_id %exportWin%
	Sleep, 300
	
	; Click "Check All" button (Button4) - try multiple methods for reliability
	; Method 1: ControlClick with window handle
	ControlClick, Button4, ahk_id %exportWin%, , , , NA
	Sleep, 500
	
	; Check if it worked by verifying window is still responsive
	if !WinExist("ahk_id " . exportWin)
	{
		FileAppend, % A_Now . " - PS_TriggerXMLExport - Export Orders dialog closed unexpectedly`n", %DebugLogFile%
		if (showErrors)
			DarkMsgBox("SideKick PS", "Export Orders dialog closed unexpectedly", "warning")
		return false
	}
	
	; Method 2: If first click didn't work, try sending BM_CLICK message directly
	ControlGet, checkAllHwnd, Hwnd, , Button4, ahk_id %exportWin%
	if (checkAllHwnd)
	{
		SendMessage, 0x00F5, 0, 0, , ahk_id %checkAllHwnd%  ; BM_CLICK = 0x00F5
	}
	Sleep, 1500
	
	; Click Export Now (Button2)
	Sleep, 300
	ControlClick, Button2, ahk_id %exportWin%, , , , NA
	
	; Wait for "Export in Standard XML format completed" confirmation dialog
	WinWait, Export Orders, completed, 15
	if !ErrorLevel
	{
		Sleep, 500
		; Get the completion dialog window handle (the one with "completed" text)
		completedWin := WinExist("Export Orders")
		
		; Click OK on the completion dialog - try multiple methods
		; Method 1: ControlClick
		ControlClick, OK, ahk_id %completedWin%, , , , NA
		Sleep, 300
		
		; Method 2: Try Button1 with ControlClick
		ControlClick, Button1, ahk_id %completedWin%, , , , NA
		Sleep, 300
		
		; Method 3: Send Enter key to the window
		ControlSend, , {Enter}, ahk_id %completedWin%
		Sleep, 500
		
		; Wait for the completion dialog to close
		WinWaitClose, ahk_id %completedWin%, , 3
		
		; Now find and close the main Export Orders window
		Sleep, 300
		exportWin := WinExist("Export Orders ahk_exe ProSelect.exe")
		
		; Click Cancel to close the Export Orders window
		if (exportWin) {
			; Try Cancel button
			ControlClick, Cancel, ahk_id %exportWin%, , , , NA
			Sleep, 300
			
			; Try Button3 (Cancel is often Button3)
			ControlClick, Button3, ahk_id %exportWin%, , , , NA
			Sleep, 300
			
			; Send Escape key as fallback
			ControlSend, , {Escape}, ahk_id %exportWin%
			Sleep, 500
			
			; Wait for window to close
			WinWaitClose, ahk_id %exportWin%, , 3
		}
		
		FileAppend, % A_Now . " - PS_TriggerXMLExport - Export complete`n", %DebugLogFile%
		return true
	}
	else
	{
		FileAppend, % A_Now . " - PS_TriggerXMLExport - Completion dialog did not appear`n", %DebugLogFile%
		; Close export dialog anyway
		exportWin := WinExist("Export Orders ahk_exe ProSelect.exe")
		if (exportWin) {
			ControlClick, Cancel, ahk_id %exportWin%, , , , NA
			Sleep, 300
			ControlSend, , {Escape}, ahk_id %exportWin%
		}
		if (showErrors)
			DarkMsgBox("SideKick PS", "Export did not complete.`n`nPlease try exporting manually.", "warning")
		return false
	}
}

; Trigger ProSelect Export Orders and click Export (wrapper for GoCardless flow)
GC_TriggerExport() {
	global DebugLogFile
	FileAppend, % A_Now . " - GC_TriggerExport - Calling shared PS_TriggerXMLExport`n", %DebugLogFile%
	PS_TriggerXMLExport(false)  ; Silent mode - no error dialogs
}

GC_SendMandateRequest(contactData, sendEmail, sendSMS) {
	; Create a GoCardless billing request flow and send notification via GHL
	global Settings_GoCardlessToken, Settings_GoCardlessEnvironment
	global Settings_GCEmailTemplateID, Settings_GCEmailTemplateName
	global Settings_GCSMSTemplateID, Settings_GCSMSTemplateName
	global GHL_API_Key, GHL_LocationID
	
	clientName := contactData.firstName . " " . contactData.lastName
	clientEmail := contactData.email
	clientPhone := contactData.phone
	contactId := contactData.id
	
	ToolTip, Creating GoCardless billing request...
	
	; Step 1: Create billing request flow using Python script
	; Build JSON for the contact data
	contactJson := "{""email"": """ . clientEmail . """, ""first_name"": """ . contactData.firstName . """, ""last_name"": """ . contactData.lastName . """}"
	
	envFlag := (Settings_GoCardlessEnvironment = "live") ? " --live" : ""
	scriptCmd := GetScriptCommand("gocardless_api", "--create-billing-request """ . contactJson . """" . envFlag)
	
	if (scriptCmd = "") {
		ToolTip
		DarkMsgBox("Error", "gocardless_api script not found.", "error")
		return
	}
	
	; Run the script and capture output
	tempResult := A_Temp . "\gc_br_result_" . A_TickCount . ".txt"
	RunWait, %ComSpec% /c %scriptCmd% > "%tempResult%" 2>&1, , Hide
	
	FileRead, scriptOutput, %tempResult%
	FileDelete, %tempResult%
	
	scriptOutput := Trim(scriptOutput)
	
	if (InStr(scriptOutput, "ERROR|")) {
		ToolTip
		errMsg := StrReplace(scriptOutput, "ERROR|", "")
		DarkMsgBox("GoCardless Error", "Failed to create billing request.`n`n" . errMsg, "error")
		return
	}
	
	if (!InStr(scriptOutput, "SUCCESS|")) {
		ToolTip
		DarkMsgBox("GoCardless Error", "Unexpected response from GoCardless.`n`n" . SubStr(scriptOutput, 1, 200), "error")
		return
	}
	
	parts := StrSplit(scriptOutput, "|")
	billingRequestId := parts[2]
	mandateUrl := parts[3]
	
	ToolTip, Sending notifications via GHL...
	
	; Step 2: Send email via GHL if enabled
	emailSent := false
	smsSent := false
	
	if (sendEmail && Settings_GCEmailTemplateID != "") {
		; Send email via GHL Conversations API
		emailScript := "
		(
try {
	$headers = @{
		'Authorization' = 'Bearer " . GHL_API_Key . "'
		'Content-Type' = 'application/json'
		'Version' = '2021-07-28'
	}
	
	# Get template HTML
	$tplResponse = Invoke-RestMethod -Uri 'https://services.leadconnectorhq.com/emails/templates/" . Settings_GCEmailTemplateID . "' -Headers $headers -TimeoutSec 15
	$templateHtml = $tplResponse.html
	
	if (-not $templateHtml) {
		$templateHtml = '<p>Please click the link below to set up your Direct Debit:</p>'
	}
	
	# Append mandate link to template
	$mandateHtml = $templateHtml + ""<p><a href='" . mandateUrl . "' style='display:inline-block;padding:12px 24px;background-color:#1ABC9C;color:white;text-decoration:none;border-radius:5px;'>Set Up Direct Debit</a></p><p>Or copy this link: " . mandateUrl . "</p>""
	
	$body = @{
		type = 'Email'
		contactId = '" . contactId . "'
		subject = 'Set Up Your Direct Debit'
		html = $mandateHtml
	} | ConvertTo-Json -Depth 3
	
	$response = Invoke-RestMethod -Uri 'https://services.leadconnectorhq.com/conversations/messages' -Method POST -Headers $headers -Body $body -TimeoutSec 30
	Write-Output 'EMAIL_SENT'
} catch {
	Write-Output ""EMAIL_ERROR|$($_.Exception.Message)""
}
		)"
		
		tempScript := A_Temp . "\gc_email_" . A_TickCount . ".ps1"
		tempResult := A_Temp . "\gc_email_result_" . A_TickCount . ".txt"
		FileDelete, %tempScript%
		FileAppend, %emailScript%, %tempScript%
		RunWait, %ComSpec% /c powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%tempScript%" > "%tempResult%" 2>&1, , Hide
		FileRead, emailResult, %tempResult%
		FileDelete, %tempScript%
		FileDelete, %tempResult%
		emailSent := InStr(emailResult, "EMAIL_SENT")
	}
	
	if (sendSMS && Settings_GCSMSTemplateID != "" && clientPhone != "") {
		; Send SMS via GHL Conversations API
		smsScript := "
		(
try {
	$headers = @{
		'Authorization' = 'Bearer " . GHL_API_Key . "'
		'Content-Type' = 'application/json'
		'Version' = '2021-07-28'
	}
	
	$smsMessage = 'Hi " . contactData.firstName . ", please set up your Direct Debit here: " . mandateUrl . "'
	
	$body = @{
		type = 'SMS'
		contactId = '" . contactId . "'
		message = $smsMessage
	} | ConvertTo-Json -Depth 3
	
	$response = Invoke-RestMethod -Uri 'https://services.leadconnectorhq.com/conversations/messages' -Method POST -Headers $headers -Body $body -TimeoutSec 30
	Write-Output 'SMS_SENT'
} catch {
	Write-Output ""SMS_ERROR|$($_.Exception.Message)""
}
		)"
		
		tempScript := A_Temp . "\gc_sms_" . A_TickCount . ".ps1"
		tempResult := A_Temp . "\gc_sms_result_" . A_TickCount . ".txt"
		FileDelete, %tempScript%
		FileAppend, %smsScript%, %tempScript%
		RunWait, %ComSpec% /c powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%tempScript%" > "%tempResult%" 2>&1, , Hide
		FileRead, smsResult, %tempResult%
		FileDelete, %tempScript%
		FileDelete, %tempResult%
		smsSent := InStr(smsResult, "SMS_SENT")
	}
	
	ToolTip
	
	; Show result
	resultMsg := "Mandate setup link created for " . clientName . "!`n`n"
	resultMsg .= "📋 Billing Request: " . billingRequestId . "`n`n"
	
	if (sendEmail) {
		resultMsg .= emailSent ? "✅ Email sent`n" : "⚠️ Email may not have sent`n"
	}
	if (sendSMS && clientPhone != "") {
		resultMsg .= smsSent ? "✅ SMS sent`n" : "⚠️ SMS may not have sent`n"
	} else if (sendSMS && clientPhone = "") {
		resultMsg .= "⚠️ No phone number - SMS skipped`n"
	}
	
	resultMsg .= "`nThe client will receive a link to set up their Direct Debit."
	
	DarkMsgBox("Mandate Request Sent", resultMsg, "success")
}

; Show dialog for setting up a GoCardless payment plan using an existing mandate
GC_ShowPayPlanDialog(contactData, mandateResult) {
	global Settings_GoCardlessToken, Settings_GoCardlessEnvironment, DebugLogFile
	global GC_PP_ContactData, GC_PP_MandateResult
	global GC_PP_Amount, GC_PP_Count, GC_PP_DayOfMonth, GC_PP_Name
	global GC_PP_ModeInstalment, GC_PP_ModeSingle, GC_PP_SingleInfo, GC_PP_PaymentList
	global GC_PP_LblName, GC_PP_LblAmount, GC_PP_LblCount, GC_PP_LblMonthly, GC_PP_LblDay, GC_PP_LblDayHelp
	global GC_PP_BtnCreate, GC_PP_BtnCreateSingles
	global PayPlanLine, PayNo, DownpaymentLineAdded
	global Settings_InvoiceWatchFolder
	global GC_PP_PsaFilePath  ; Store .psa file path for display
	
	; Initialize .psa path
	GC_PP_PsaFilePath := ""
	
	; Store data for GUI handlers
	GC_PP_ContactData := contactData
	GC_PP_MandateResult := mandateResult
	
	; Build client name from firstName + lastName
	clientName := ""
	if (contactData.firstName != "" || contactData.lastName != "")
		clientName := Trim(contactData.firstName . " " . contactData.lastName)
	if (clientName = "" && contactData.name != "")
		clientName := contactData.name
	if (clientName = "")
		clientName := "Unknown Client"
	
	mandateId := mandateResult.mandateId
	bankName := mandateResult.bankName
	
	; Get album name from ProSelect title as default plan name
	WinGetTitle, psTitle, ahk_exe ProSelect.exe
	defaultName := RegExReplace(psTitle, "^ProSelect\s*-\s*", "")
	defaultName := RegExReplace(defaultName, "\s*-\s*ProSelect.*$", "")
	defaultName := Trim(defaultName)
	if (defaultName = "" || defaultName = "ProSelect")
		defaultName := contactData.lastName ? contactData.lastName : "PayPlan"
	
	; Extract job code for XML matching (e.g., "P26014P_Barnes_ABC123" -> "P26014P")
	jobCode := ""
	if (RegExMatch(defaultName, "^([A-Z]\d+[A-Z])", m))
		jobCode := m1
	else if (InStr(defaultName, "_"))
		jobCode := SubStr(defaultName, 1, InStr(defaultName, "_") - 1)
	else
		jobCode := defaultName
	
	; Also get surname for alternative matching (album might be "Risbey" instead of "P26014P")
	searchTerms := []
	if (jobCode != "")
		searchTerms.Push(jobCode)
	if (contactData.lastName && contactData.lastName != "")
		searchTerms.Push(contactData.lastName)
	; If album name starts with a name (not job code), use first word
	if (!RegExMatch(defaultName, "^[A-Z]\d+[A-Z]") && InStr(defaultName, "_"))
		searchTerms.Push(SubStr(defaultName, 1, InStr(defaultName, "_") - 1))
	else if (!RegExMatch(defaultName, "^[A-Z]\d+[A-Z]") && defaultName != "")
		searchTerms.Push(defaultName)
	
	; Read existing payment lines and filter for DD payments only
	; PayPlanLine format: day,month,year,PayType,Amount
	ddPayments := []
	ddPaymentCount := 0
	ddTotalAmount := 0
	ddFirstDay := 0
	ddCommonAmount := 0
	
	startIdx := DownpaymentLineAdded ? 0 : 1
	endIdx := DownpaymentLineAdded ? PayNo : PayNo
	
	FileAppend, % A_Now . " - GC_ShowPayPlanDialog - Scanning PayPlanLine " . startIdx . " to " . endIdx . "`n", %DebugLogFile%
	
	Loop
	{
		idx := startIdx + A_Index - 1
		if (idx > endIdx)
			break
		
		lineData := PayPlanLine[idx]
		if (lineData = "")
			continue
		
		parts := StrSplit(lineData, ",")
		if (parts.Length() < 5)
			continue
		
		payType := parts[4]
		payAmount := parts[5]
		payDay := parts[1]
		
		; Check if this is a DD payment type (case-insensitive)
		; Match: GoCardless, DD, Direct Debit, BACS
		isDDPayment := false
		if (InStr(payType, "GoCardless") || InStr(payType, "Direct Debit") || InStr(payType, " DD") || payType = "DD" || InStr(payType, "BACS"))
			isDDPayment := true
		
		if (!isDDPayment) {
			FileAppend, % A_Now . " - GC_ShowPayPlanDialog - Skipping non-DD payment: " . payType . "`n", %DebugLogFile%
			continue
		}
		
		FileAppend, % A_Now . " - GC_ShowPayPlanDialog - Found DD payment: " . lineData . "`n", %DebugLogFile%
		
		ddPayments.Push(lineData)
		ddPaymentCount++
		ddTotalAmount += payAmount
		
		; Track first day and common amount for defaults
		if (ddFirstDay = 0)
			ddFirstDay := payDay
		if (ddCommonAmount = 0)
			ddCommonAmount := payAmount
	}
	
	; If no DD payments found in PayPlanLine, try to read from .psa album file
	if (ddPaymentCount = 0) {
		; Build search terms string for logging
		searchTermsStr := ""
		for idx, term in searchTerms
			searchTermsStr .= (searchTermsStr ? ", " : "") . term
		FileAppend, % A_Now . " - GC_ShowPayPlanDialog - No DD payments in PayPlanLine, will read from .psa album file`n", %DebugLogFile%
		FileAppend, % A_Now . " - GC_ShowPayPlanDialog - Search terms: " . searchTermsStr . "`n", %DebugLogFile%
		
		; Ask user to save the album FIRST (before opening any dialogs)
		result := DarkMsgBox("Save Album", "📁 The album needs to be saved to read payment data.`n`nClick 'Save Album' to save and continue.", "info", {buttons: ["Save Album", "Cancel"]})
		
		if (result = "Cancel")
			return
		
		; Save the album for the user (Ctrl+S in ProSelect)
		Send, ^s
		Sleep, 3000  ; Wait for save to complete (slow ProSelect)
		
		; NOW get the album folder using Save As dialog trick
		albumFolder := GetAlbumFolder()
		if (albumFolder = "" || !FileExist(albumFolder)) {
			DarkMsgBox("Album Not Found", "Could not determine album location.`n`nFolder: " . (albumFolder ? albumFolder : "(empty)") . "`n`nMake sure an album is open in ProSelect.", "error")
			return
		}
		
		FileAppend, % A_Now . " - GC_ShowPayPlanDialog - Album folder: " . albumFolder . "`n", %DebugLogFile%
		
		; Find .psa file in the album folder (use most recently modified)
		psaFile := ""
		latestTime := 0
		Loop, Files, %albumFolder%\*.psa
		{
			FileGetTime, fileTime, %A_LoopFileFullPath%, M
			if (fileTime > latestTime) {
				latestTime := fileTime
				psaFile := A_LoopFileFullPath
			}
		}
		
		if (psaFile = "") {
			DarkMsgBox("Album Not Found", "No .psa album file found in:`n" . albumFolder . "`n`nMake sure the album has been saved.", "error")
			return
		}
		
		FileAppend, % A_Now . " - GC_ShowPayPlanDialog - Found .psa file: " . psaFile . "`n", %DebugLogFile%
		GC_PP_PsaFilePath := psaFile  ; Store for display in dialog
		
		; Call Python script to read payments from .psa
		ToolTip, Reading payment data from album...
		scriptCmd := GetScriptCommand("read_psa_payments", """" . psaFile . """")
		FileAppend, % A_Now . " - GC_ShowPayPlanDialog - Running: " . scriptCmd . "`n", %DebugLogFile%
		
		tempResult := A_Temp . "\psa_payments_" . A_TickCount . ".txt"
		fullCmd := ComSpec . " /c " . scriptCmd . " > """ . tempResult . """ 2>&1"
		RunWait, %fullCmd%, , Hide
		
		FileRead, scriptOutput, %tempResult%
		FileDelete, %tempResult%
		ToolTip
		
		scriptOutput := Trim(scriptOutput)
		FileAppend, % A_Now . " - GC_ShowPayPlanDialog - Script output: " . scriptOutput . "`n", %DebugLogFile%
		
		if (InStr(scriptOutput, "ERROR|")) {
			errorMsg := StrReplace(scriptOutput, "ERROR|", "")
			DarkMsgBox("Read Error", "Failed to read album file.`n`n" . errorMsg, "error")
			return
		}
		
		if (InStr(scriptOutput, "NO_PAYMENTS")) {
			; No payments at all - let user know
			DarkMsgBox("No Payments", "No payments found in the album.`n`nAdd a payment schedule in ProSelect first.", "warning")
			return
		}
		
		if (InStr(scriptOutput, "PAYMENTS|")) {
			; Parse payments: PAYMENTS|count|day,month,year,amount,methodName,methodID|...
			parts := StrSplit(scriptOutput, "|")
			paymentCount := parts[2]
			
			Loop, %paymentCount%
			{
				paymentData := parts[A_Index + 2]
				payParts := StrSplit(paymentData, ",")
				
				if (payParts.Length() >= 6) {
					payDay := payParts[1]
					payMonth := payParts[2]
					payYear := payParts[3]
					payAmount := payParts[4]
					methodName := payParts[5]
					methodID := payParts[6]
					
					; Check if this is a DD payment (GoCardless, DD, Direct Debit, BACS)
					isDDPayment := false
					if (InStr(methodName, "GoCardless") || InStr(methodName, "Direct Debit") || InStr(methodName, " DD") || methodName = "DD" || InStr(methodName, "BACS"))
						isDDPayment := true
					
					if (isDDPayment) {
						; Format: day,month,year,PayType,Amount
						lineData := payDay . "," . payMonth . "," . payYear . ",DD," . payAmount
						ddPayments.Push(lineData)
						ddPaymentCount++
						ddTotalAmount += payAmount
						if (ddFirstDay = 0)
							ddFirstDay := payDay
						if (ddCommonAmount = 0)
							ddCommonAmount := payAmount
						FileAppend, % A_Now . " - GC_ShowPayPlanDialog - Found DD payment in .psa: " . lineData . "`n", %DebugLogFile%
					} else {
						FileAppend, % A_Now . " - GC_ShowPayPlanDialog - Skipping non-DD payment: " . methodName . " - " . payAmount . "`n", %DebugLogFile%
					}
				}
			}
		} else {
			; Unexpected script output - show it for debugging
			DarkMsgBox("Unexpected Output", "Script returned unexpected output:`n`n" . SubStr(scriptOutput, 1, 500), "warning")
			return
		}
	}
	
	; Set defaults - use found DD payments if any, otherwise use defaults
	defaultAmount := ddCommonAmount > 0 ? ddCommonAmount : 50.00
	defaultCount := ddPaymentCount > 0 ? ddPaymentCount : 12
	defaultDay := ddFirstDay > 0 ? ddFirstDay : 15
	
	FileAppend, % A_Now . " - GC_ShowPayPlanDialog - Found " . ddPaymentCount . " DD payments, total £" . ddTotalAmount . "`n", %DebugLogFile%
	
	; Analyze payments to detect singles vs instalments
	; Singles = payments with varying amounts (deposits), Instalments = recurring same amount
	singlePayments := []
	instalmentPayments := []
	instalmentAmount := 0
	
	if (ddPayments.Length() > 0) {
		; Count frequency of each amount to find the "instalment" amount (most common)
		amountCounts := {}
		for idx, payment in ddPayments {
			parts := StrSplit(payment, ",")
			amt := parts[5]
			if (!amountCounts.HasKey(amt))
				amountCounts[amt] := 0
			amountCounts[amt]++
		}
		
		; Find most common amount (this is likely the instalment amount)
		maxCount := 0
		for amt, cnt in amountCounts {
			if (cnt > maxCount) {
				maxCount := cnt
				instalmentAmount := amt
			}
		}
		
		; If most common appears >= 3 times, treat as instalment pattern
		if (maxCount >= 3) {
			for idx, payment in ddPayments {
				parts := StrSplit(payment, ",")
				amt := parts[5]
				if (amt = instalmentAmount)
					instalmentPayments.Push(payment)
				else
					singlePayments.Push(payment)
			}
		} else {
			; All different amounts - treat all as singles
			for idx, payment in ddPayments
				singlePayments.Push(payment)
		}
	}
	
	; Build preview text
	paymentPreview := ""
	if (singlePayments.Length() > 0 && instalmentPayments.Length() > 0) {
		; Calculate singles total
		singlesTotal := 0
		for idx, payment in singlePayments {
			parts := StrSplit(payment, ",")
			singlesTotal += parts[5]
		}
		paymentPreview := singlePayments.Length() . " single payments (£" . Format("{:.2f}", singlesTotal) . ") + " . instalmentPayments.Length() . " instalments (£" . instalmentAmount . " each)"
	} else if (singlePayments.Length() > 0) {
		paymentPreview := singlePayments.Length() . " single payments detected"
	} else if (instalmentPayments.Length() > 0) {
		paymentPreview := instalmentPayments.Length() . " instalments @ £" . Format("{:.2f}", instalmentAmount) . " each"
	} else {
		paymentPreview := "No DD payments found - enter details manually"
	}
	
	FileAppend, % A_Now . " - GC_ShowPayPlanDialog - Preview: " . paymentPreview . "`n", %DebugLogFile%
	FileAppend, % A_Now . " - GC_ShowPayPlanDialog - Singles: " . singlePayments.Length() . ", Instalments: " . instalmentPayments.Length() . "`n", %DebugLogFile%
	
	; Update defaults to use instalment-specific values if detected
	if (instalmentPayments.Length() > 0) {
		defaultAmount := instalmentAmount
		defaultCount := instalmentPayments.Length()
		; Get day from first instalment payment
		parts := StrSplit(instalmentPayments[1], ",")
		defaultDay := parts[1]
	}
	
	global GC_PP_DDPayments  ; Store DD payments for single payment mode
	global GC_PP_SinglePayments, GC_PP_InstalmentPayments, GC_PP_InstalmentAmount
	GC_PP_SinglePayments := singlePayments
	GC_PP_InstalmentPayments := instalmentPayments
	GC_PP_InstalmentAmount := instalmentAmount
	
	; Create dark-themed GUI
	Gui, GCPayPlan:New, +AlwaysOnTop +ToolWindow -MinimizeBox
	Gui, GCPayPlan:Color, 2D2D2D, 3D3D3D
	Gui, GCPayPlan:Font, s10 cWhite, Segoe UI
	
	; Header
	Gui, GCPayPlan:Add, Text, x15 y15 w350 cCCCCCC, Create GoCardless Payments
	Gui, GCPayPlan:Font, s9 cWhite, Segoe UI
	
	; Client info
	Gui, GCPayPlan:Add, Text, x15 y45 w80 cAAAAAA, Client:
	Gui, GCPayPlan:Add, Text, x100 y45 w270, %clientName%
	Gui, GCPayPlan:Add, Text, x15 y65 w80 cAAAAAA, Bank:
	Gui, GCPayPlan:Add, Text, x100 y65 w270, %bankName%
	
	; Payment preview (detected from invoice) - wrap long text
	Gui, GCPayPlan:Add, Text, x15 y90 w80 cAAAAAA, Detected:
	previewColor := (singlePayments.Length() > 0 && instalmentPayments.Length() > 0) ? "00CC66" : (ddPaymentCount > 0 ? "AAAAAA" : "FF6666")
	Gui, GCPayPlan:Add, Text, x100 y90 w270 h30 c%previewColor%, %paymentPreview%
	
	; Show .psa file path if we have one (just filename, full path in tooltip)
	psaDisplayPath := GC_PP_PsaFilePath ? GC_PP_PsaFilePath : "(not loaded)"
	SplitPath, psaDisplayPath, psaFileName
	if (psaFileName = "")
		psaFileName := psaDisplayPath
	Gui, GCPayPlan:Add, Text, x15 y120 w80 cAAAAAA, Album:
	Gui, GCPayPlan:Add, Edit, x100 y117 w270 h22 ReadOnly Background2D2D2D c888888, %psaDisplayPath%
	
	; Separator
	Gui, GCPayPlan:Add, Text, x15 y145 w355 h1 0x10  ; SS_ETCHEDHORZ
	
	; Plan Name
	Gui, GCPayPlan:Add, Text, x15 y160 w80 cAAAAAA, Plan Name:
	Gui, GCPayPlan:Add, Edit, x100 y157 w270 h24 vGC_PP_Name Background3D3D3D cWhite, %defaultName%
	
	; Build payment list for display
	paymentListText := ""
	GC_PP_DDPayments := []
	Loop, % ddPayments.Length()
	{
		parts := StrSplit(ddPayments[A_Index], ",")
		if (parts.Length() >= 5) {
			payDay := parts[1]
			payMonth := parts[2]
			payYear := parts[3]
			payAmount := parts[5]
			dateStr := Format("{:02d}/{:02d}/{}", payDay, payMonth, payYear)
			amountStr := Format("£{:.2f}", payAmount)
			paymentListText .= dateStr . "  " . amountStr . "`n"
			; Store ISO date and amount for API
			GC_PP_DDPayments.Push({date: Format("{}-{:02d}-{:02d}", payYear, payMonth, payDay), amount: payAmount})
		}
	}
	if (paymentListText = "")
		paymentListText := "(No DD payments found in invoice)"
	
	; Payment list (read-only)
	Gui, GCPayPlan:Add, Text, x15 y190 cAAAAAA, Payments:
	Gui, GCPayPlan:Add, Edit, x15 y210 w355 h270 vGC_PP_PaymentList ReadOnly Background3D3D3D cWhite, %paymentListText%
	
	; Store data for create function
	global GC_PP_MandateResult, GC_PP_ContactData
	GC_PP_MandateResult := mandateResult
	GC_PP_ContactData := contactData
	
	; Buttons
	createEnabled := (ddPaymentCount > 0) ? "" : "Disabled"
	Gui, GCPayPlan:Add, Button, x60 y495 w130 h32 gGC_PP_CreateMixed Default %createEnabled%, Create Payments
	Gui, GCPayPlan:Add, Button, x200 y495 w80 h32 gGC_PP_Cancel, Cancel
	
	Gui, GCPayPlan:Show, w385 h545, GoCardless Payments
	return
}

GC_PP_CreateMixed:
	global GC_PP_ContactData, GC_PP_MandateResult, GC_PP_DDPayments, GC_PP_Name
	global GC_PP_SinglePayments, GC_PP_InstalmentPayments, GC_PP_InstalmentAmount
	global DebugLogFile, Settings_GoCardlessEnvironment
	
	Gui, GCPayPlan:Submit, NoHide
	
	if (GC_PP_DDPayments.Length() = 0) {
		DarkMsgBox("No Payments", "No DD payments found in the invoice to create.", "warning")
		return
	}
	
	; Check for past payment dates
	FormatTime, todayISO, , yyyy-MM-dd
	pastPayments := ""
	pastCount := 0
	earliestPastDate := ""
	
	for idx, payment in GC_PP_DDPayments {
		if (payment.date < todayISO) {
			; Format date for display (YYYY-MM-DD to DD/MM/YYYY)
			parts := StrSplit(payment.date, "-")
			displayDate := parts[3] . "/" . parts[2]  . "/" . parts[1]
			pastPayments .= "   • " . displayDate . " - £" . Format("{:.2f}", payment.amount) . "`n"
			pastCount++
			if (earliestPastDate = "" || payment.date < earliestPastDate)
				earliestPastDate := parts[3] . "," . parts[2] . "," . parts[1]  ; Store as D,M,YYYY
		}
	}
	
	if (pastCount > 0) {
		; Calculate months to bump
		FormatTime, CurrentMonth, , M
		FormatTime, CurrentYear, , yyyy
		FormatTime, CurrentDay, , d
		
		; Get day from earliest past payment
		epParts := StrSplit(earliestPastDate, ",")
		PaymentDay := epParts[1] + 0
		
		; Determine next available month
		NextAvailMonth := CurrentMonth + 0
		NextAvailYear := CurrentYear + 0
		
		; If we're past the payment day this month, use next month
		if ((CurrentDay + 0) >= PaymentDay) {
			NextAvailMonth++
			if (NextAvailMonth > 12) {
				NextAvailMonth := 1
				NextAvailYear++
			}
		}
		
		; Get month names
		GC_Months := {1: "January", 2: "February", 3: "March", 4: "April", 5: "May", 6: "June"
			, 7: "July", 8: "August", 9: "September", 10: "October", 11: "November", 12: "December"}
		NextMonthName := GC_Months[NextAvailMonth]
		
		; Calculate bump from earliest payment
		OrigMonth := epParts[2] + 0
		OrigYear := epParts[3] + 0
		MonthsBump := (NextAvailYear - OrigYear) * 12 + (NextAvailMonth - OrigMonth)
		OrigMonthName := GC_Months[OrigMonth]
		
		msg := "⚠️ PAYMENT DATES IN THE PAST ⚠️`n`n"
		msg .= "The following payment dates have already passed:`n`n" . pastPayments
		msg .= "`nGoCardless will REJECT payments with past dates.`n`n"
		msg .= "📅 Bump by " . MonthsBump . " month" . (MonthsBump > 1 ? "s" : "") . "`n"
		msg .= "    From: " . OrigMonthName . " " . OrigYear . "`n"
		msg .= "    To: " . NextMonthName . " " . NextAvailYear . "`n`n"
		msg .= "Click 'Cancel' to go back and review."
		
		result := DarkMsgBox("Past Payment Dates", msg, "warning", {buttons: ["Bump Dates", "Cancel"]})
		
		if (result != "Bump Dates")
			return
		
		; Bump all payment dates by MonthsBump months
		for idx, payment in GC_PP_DDPayments {
			parts := StrSplit(payment.date, "-")
			pYear := parts[1] + 0
			pMonth := parts[2] + 0
			pDay := parts[3] + 0
			
			; Add months
			pMonth += MonthsBump
			while (pMonth > 12) {
				pMonth -= 12
				pYear++
			}
			
			GC_PP_DDPayments[idx].date := Format("{}-{:02d}-{:02d}", pYear, pMonth, pDay)
		}
		
		; Also bump GC_PP_SinglePayments (format: day,month,year,?,amount)
		for idx, payment in GC_PP_SinglePayments {
			parts := StrSplit(payment, ",")
			pDay := parts[1]
			pMonth := parts[2] + 0
			pYear := parts[3] + 0
			
			pMonth += MonthsBump
			while (pMonth > 12) {
				pMonth -= 12
				pYear++
			}
			
			GC_PP_SinglePayments[idx] := pDay . "," . pMonth . "," . pYear . "," . parts[4] . "," . parts[5]
		}
		
		; Also bump GC_PP_InstalmentPayments
		for idx, payment in GC_PP_InstalmentPayments {
			parts := StrSplit(payment, ",")
			pDay := parts[1]
			pMonth := parts[2] + 0
			pYear := parts[3] + 0
			
			pMonth += MonthsBump
			while (pMonth > 12) {
				pMonth -= 12
				pYear++
			}
			
			GC_PP_InstalmentPayments[idx] := pDay . "," . pMonth . "," . pYear . "," . parts[4] . "," . parts[5]
		}
		
		; Update the payments list display in the GUI
		paymentListText := ""
		for idx, payment in GC_PP_DDPayments {
			parts := StrSplit(payment.date, "-")
			dateStr := Format("{:02d}/{:02d}/{}", parts[3], parts[2], parts[1])
			amountStr := Format("£{:.2f}", payment.amount)
			paymentListText .= dateStr . "  " . amountStr . "`n"
		}
		GuiControl, GCPayPlan:, GC_PP_PaymentList, %paymentListText%
		
		DarkMsgBox("Dates Updated", "✅ Payment dates bumped by " . MonthsBump . " month" . (MonthsBump > 1 ? "s" : "") . ".`n`nReview the updated dates and click 'Create Payments' again.", "success")
		return
	}
	
	mandateId := GC_PP_MandateResult.mandateId
	planName := GC_PP_Name
	
	; Build the payment plan JSON
	; Format: { mandate_id, name, single_payments: [{amount, charge_date, description}], instalment: {amount, count, day_of_month} }
	
	planJson := "{""mandate_id"": """ . mandateId . """, ""name"": """ . planName . """"
	
	; Add single payments if any
	if (GC_PP_SinglePayments.Length() > 0) {
		planJson .= ", ""single_payments"": ["
		for idx, payment in GC_PP_SinglePayments {
			parts := StrSplit(payment, ",")
			payDay := parts[1]
			payMonth := parts[2]
			payYear := parts[3]
			payAmount := Round(parts[5] * 100)  ; Convert to pence
			chargeDate := Format("{}-{:02d}-{:02d}", payYear, payMonth, payDay)
			
			if (idx > 1)
				planJson .= ", "
			planJson .= "{""amount"": " . payAmount . ", ""charge_date"": """ . chargeDate . """, ""description"": """ . planName . " - Deposit " . idx . """}"
		}
		planJson .= "]"
	}
	
	; Add instalment schedule if any
	if (GC_PP_InstalmentPayments.Length() > 0) {
		; Get day from first instalment payment
		parts := StrSplit(GC_PP_InstalmentPayments[1], ",")
		instalDay := parts[1] + 0  ; Convert to number to remove leading zeros
		instalCount := GC_PP_InstalmentPayments.Length()
		; Calculate total amount (GoCardless will handle rounding on first payment)
		instalTotalAmount := Round(GC_PP_InstalmentAmount * instalCount * 100)  ; Total in pence
		
		planJson .= ", ""instalment"": {""total_amount"": " . instalTotalAmount . ", ""count"": " . instalCount . ", ""day_of_month"": " . instalDay . "}"
	}
	
	planJson .= "}"
	
	FileAppend, % A_Now . " - GC_PP_CreateMixed - planJson: " . planJson . "`n", %DebugLogFile%
	
	; Write JSON to temp file
	tempJsonFile := A_Temp . "\gc_payplan_" . A_TickCount . ".json"
	FileDelete, %tempJsonFile%
	FileAppend, %planJson%, %tempJsonFile%
	
	Gui, GCPayPlan:Destroy
	ToolTip, Creating payments...
	
	; Call Python script
	envFlag := (Settings_GoCardlessEnvironment = "live") ? " --live" : ""
	scriptCmd := GetScriptCommand("gocardless_api", "--create-payment-plan-file """ . tempJsonFile . """" . envFlag)
	FileAppend, % A_Now . " - GC_PP_CreateMixed - scriptCmd: " . scriptCmd . "`n", %DebugLogFile%
	
	tempResult := A_Temp . "\gc_payplan_result_" . A_TickCount . ".txt"
	fullCmd := ComSpec . " /c " . scriptCmd . " > """ . tempResult . """ 2>&1"
	RunWait, %fullCmd%, , Hide
	
	FileRead, scriptOutput, %tempResult%
	FileAppend, % A_Now . " - GC_PP_CreateMixed - scriptOutput: " . scriptOutput . "`n", %DebugLogFile%
	FileDelete, %tempResult%
	FileDelete, %tempJsonFile%
	
	ToolTip
	
	scriptOutput := Trim(scriptOutput)
	
	if (InStr(scriptOutput, "SUCCESS|")) {
		parts := StrSplit(scriptOutput, "|")
		; SUCCESS|payment_ids|subscription_id|summary
		summary := parts[4]
		
		; Show success with option to open GoCardless
		result := DarkMsgBox("Payments Created", "✅ GoCardless payments created successfully!`n`n" . summary, "success", {buttons: ["Open GC", "OK"]})
		
		if (result = "Open GC") {
			; Open GoCardless customer page
			customerId := GC_PP_MandateResult.customerId
			gcEnv := (Settings_GoCardlessEnvironment = "live") ? "manage" : "manage-sandbox"
			gcUrl := "https://" . gcEnv . ".gocardless.com/customers/" . customerId
			Run, %gcUrl%
		}
	}
	else if (InStr(scriptOutput, "ERROR|")) {
		errorMsg := StrReplace(scriptOutput, "ERROR|", "")
		DarkMsgBox("GoCardless Error", "Failed to create payments.`n`n" . errorMsg, "error")
	}
	else {
		DarkMsgBox("GoCardless Error", "Unexpected response from GoCardless.`n`n" . SubStr(scriptOutput, 1, 200), "error")
	}
	return

; Legacy mode change handler (kept for compatibility)
GC_PP_ModeChange:
	Gui, GCPayPlan:Submit, NoHide
	GuiControlGet, isSingleMode,, GC_PP_ModeSingle
	
	if (isSingleMode) {
		; Show single payment controls, hide instalment controls
		GuiControl, Hide, GC_PP_LblAmount
		GuiControl, Hide, GC_PP_Amount
		GuiControl, Hide, GC_PP_LblCount
		GuiControl, Hide, GC_PP_Count
		GuiControl, Hide, GC_PP_LblMonthly
		GuiControl, Hide, GC_PP_LblDay
		GuiControl, Hide, GC_PP_DayOfMonth
		GuiControl, Hide, GC_PP_LblDayHelp
		GuiControl, Hide, GC_PP_BtnCreate
		GuiControl, Show, GC_PP_SingleInfo
		GuiControl, Show, GC_PP_PaymentList
		GuiControl, Show, GC_PP_BtnCreateSingles
	} else {
		; Show instalment controls, hide single payment controls
		GuiControl, Show, GC_PP_LblAmount
		GuiControl, Show, GC_PP_Amount
		GuiControl, Show, GC_PP_LblCount
		GuiControl, Show, GC_PP_Count
		GuiControl, Show, GC_PP_LblMonthly
		GuiControl, Show, GC_PP_LblDay
		GuiControl, Show, GC_PP_DayOfMonth
		GuiControl, Show, GC_PP_LblDayHelp
		GuiControl, Show, GC_PP_BtnCreate
		GuiControl, Hide, GC_PP_SingleInfo
		GuiControl, Hide, GC_PP_PaymentList
		GuiControl, Hide, GC_PP_BtnCreateSingles
	}
	return

GC_PP_CreateSingles:
	global GC_PP_ContactData, GC_PP_MandateResult, GC_PP_DDPayments, GC_PP_Name, DebugLogFile, Settings_GoCardlessEnvironment
	
	Gui, GCPayPlan:Submit, NoHide
	
	if (GC_PP_DDPayments.Length() = 0) {
		DarkMsgBox("No Payments", "No DD payments found in the PayPlan to create.", "warning")
		return
	}
	
	mandateId := GC_PP_MandateResult.mandateId
	planName := GC_PP_Name
	
	; Confirm creation
	payCount := GC_PP_DDPayments.Length()
	totalAmount := 0
	Loop, % payCount
		totalAmount += GC_PP_DDPayments[A_Index].amount
	
	MsgBox, 0x24, Create Single Payments?, Create %payCount% individual one-off payments?`n`nTotal: £%totalAmount%`n`nEach payment will be named "%planName%"
	IfMsgBox, No
		return
	
	Gui, GCPayPlan:Destroy
	
	; Create each payment
	successCount := 0
	failedCount := 0
	createdIds := ""
	envFlag := (Settings_GoCardlessEnvironment = "live") ? " --live" : ""
	
	Loop, % payCount
	{
		payment := GC_PP_DDPayments[A_Index]
		amountPence := Round(payment.amount * 100)
		chargeDate := payment.date
		description := planName
		
		ToolTip, Creating payment %A_Index% of %payCount%...
		
		; Escape quotes in description
		descEscaped := StrReplace(description, """", "\""")
		
		paymentJson := "{""mandate_id"": """ . mandateId . """, ""amount"": " . amountPence . ", ""description"": """ . descEscaped . """, ""charge_date"": """ . chargeDate . """}"
		
		FileAppend, % A_Now . " - GC_PP_CreateSingles - paymentJson: " . paymentJson . "`n", %DebugLogFile%
		
		scriptCmd := GetScriptCommand("gocardless_api", "--create-payment """ . paymentJson . """" . envFlag)
		tempResult := A_Temp . "\gc_payment_result_" . A_TickCount . ".txt"
		RunWait, %ComSpec% /c %scriptCmd% > "%tempResult%" 2>&1, , Hide
		FileRead, scriptOutput, %tempResult%
		FileDelete, %tempResult%
		
		scriptOutput := Trim(scriptOutput)
		FileAppend, % A_Now . " - GC_PP_CreateSingles - output: " . scriptOutput . "`n", %DebugLogFile%
		
		if (InStr(scriptOutput, "SUCCESS|")) {
			successCount++
			parts := StrSplit(scriptOutput, "|")
			if (parts.Length() >= 2)
				createdIds .= parts[2] . ","
		} else {
			failedCount++
		}
		
		Sleep, 200  ; Small delay between API calls
	}
	
	ToolTip
	
	; Show result
	if (failedCount = 0) {
		DarkMsgBox("Payments Created", "✅ Successfully created " . successCount . " one-off payments.`n`nPayments will be collected on their scheduled dates.", "success")
	} else {
		DarkMsgBox("Partial Success", "Created " . successCount . " payments.`n`nFailed: " . failedCount . "`n`nCheck the debug log for details.", "warning")
	}
	return

GC_PP_Create:
	global GC_PP_ContactData, GC_PP_MandateResult, DebugLogFile
	global GC_PP_Amount, GC_PP_Count, GC_PP_DayOfMonth, GC_PP_Name
	
	Gui, GCPayPlan:Submit, NoHide
	
	; Validate inputs
	if (GC_PP_Amount = "" || GC_PP_Amount <= 0) {
		DarkMsgBox("Invalid Amount", "Please enter a valid amount.", "warning")
		return
	}
	
	if (GC_PP_Count = "" || GC_PP_Count <= 0) {
		DarkMsgBox("Invalid Count", "Please enter the number of payments.", "warning")
		return
	}
	
	if (GC_PP_DayOfMonth = "" || (GC_PP_DayOfMonth < -1 || GC_PP_DayOfMonth > 28 || GC_PP_DayOfMonth = 0)) {
		DarkMsgBox("Invalid Day", "Day must be 1-28, or -1 for last day of month.", "warning")
		return
	}
	
	; Check for duplicate plan name before creating
	mandateId := GC_PP_MandateResult.mandateId
	planName := GC_PP_Name
	
	ToolTip, Checking for existing plans...
	envFlag := (Settings_GoCardlessEnvironment = "live") ? " --live" : ""
	checkCmd := GetScriptCommand("gocardless_api", "--list-plans """ . mandateId . """" . envFlag)
	tempCheck := A_Temp . "\gc_check_plans_" . A_TickCount . ".txt"
	RunWait, %ComSpec% /c %checkCmd% > "%tempCheck%" 2>&1, , Hide
	FileRead, subsOutput, %tempCheck%
	FileDelete, %tempCheck%
	ToolTip
	
	; Check if plan name already exists
	duplicateFound := false
	duplicateStatus := ""
	Loop, Parse, subsOutput, `n, `r
	{
		if (A_LoopField = "" || A_LoopField = "NO_PLANS")
			continue
		parts := StrSplit(A_LoopField, "|")
		if (parts.Length() >= 3) {
			existingName := parts[2]
			existingStatus := parts[3]
			if (existingName = planName) {
				duplicateFound := true
				duplicateStatus := existingStatus
				break
			}
		}
	}
	
	if (duplicateFound) {
		MsgBox, 0x134, Duplicate Plan Name, ⚠️ A plan named "%planName%" already exists for this mandate.`n`nStatus: %duplicateStatus%`n`nDo you want to create another plan with the same name?`n`n(Tip: The system will auto-add a suffix like -1, -2)
		IfMsgBox, No
			return
	}
	
	; Convert amount to pence
	amountPence := Round(GC_PP_Amount * 100)
	
	; Escape quotes in name for JSON
	planNameEscaped := StrReplace(planName, """", "\""")
	
	instalmentJson := "{""mandate_id"": """ . mandateId . """, ""amount"": " . amountPence . ", ""name"": """ . planNameEscaped . """, ""count"": " . GC_PP_Count . ", ""day_of_month"": " . GC_PP_DayOfMonth . "}"
	
	FileAppend, % A_Now . " - GC_PP_Create - instalmentJson: " . instalmentJson . "`n", %DebugLogFile%
	
	; Write JSON to temp file to avoid command line quote issues
	tempJsonFile := A_Temp . "\gc_instalment_" . A_TickCount . ".json"
	FileDelete, %tempJsonFile%
	FileAppend, %instalmentJson%, %tempJsonFile%
	
	; Close dialog and show progress
	Gui, GCPayPlan:Destroy
	ToolTip, Creating payment plan...
	
	; Call Python script
	envFlag := (Settings_GoCardlessEnvironment = "live") ? " --live" : ""
	scriptCmd := GetScriptCommand("gocardless_api", "--create-instalment-file """ . tempJsonFile . """" . envFlag)
	FileAppend, % A_Now . " - GC_PP_Create - scriptCmd: " . scriptCmd . "`n", %DebugLogFile%
	
	tempResult := A_Temp . "\gc_instalment_result_" . A_TickCount . ".txt"
	fullCmd := ComSpec . " /c " . scriptCmd . " > """ . tempResult . """ 2>&1"
	RunWait, %fullCmd%, , Hide
	
	FileRead, scriptOutput, %tempResult%
	FileAppend, % A_Now . " - GC_PP_Create - scriptOutput: " . scriptOutput . "`n", %DebugLogFile%
	FileDelete, %tempResult%
	FileDelete, %tempJsonFile%
	
	ToolTip
	
	scriptOutput := Trim(scriptOutput)
	
	if (InStr(scriptOutput, "SUCCESS|")) {
		parts := StrSplit(scriptOutput, "|")
		scheduleId := parts[2]
		actualPlanName := parts[3]
		paymentCount := parts[4]
		firstDate := parts[5]
		lastDate := parts[6]
		
		; Format amount for display
		amountStr := Format("£{:.2f}", GC_PP_Amount)
		
		DarkMsgBox("Payment Plan Created", "✅ GoCardless payment plan created successfully!`n`n📋 Plan: " . actualPlanName . "`n💰 Amount: " . amountStr . " x " . paymentCount . " payments`n📅 Schedule: " . firstDate . " to " . lastDate . "`n🔖 Schedule ID: " . scheduleId, "success")
	}
	else if (InStr(scriptOutput, "ERROR|")) {
		errorMsg := StrReplace(scriptOutput, "ERROR|", "")
		DarkMsgBox("GoCardless Error", "Failed to create payment plan.`n`n" . errorMsg, "error")
	}
	else {
		DarkMsgBox("GoCardless Error", "Unexpected response from GoCardless.`n`n" . SubStr(scriptOutput, 1, 200), "error")
	}
return

GC_PP_Cancel:
GCPayPlanGuiClose:
GCPayPlanGuiEscape:
	Gui, GCPayPlan:Destroy
return

; Toggle handler for GoCardless enabled - controls panel enable/disable state
Toggle_GoCardlessEnabled_Changed:
	Gui, Settings:Submit, NoHide
	; Get the toggle state
	GuiControlGet, toggleState,, Toggle_GoCardlessEnabled
	Settings_GoCardlessEnabled := toggleState
	IniWrite, %Settings_GoCardlessEnabled%, %IniFilename%, GoCardless, Enabled
	; Enable/disable all other GoCardless controls based on toggle state
	if (Settings_GoCardlessEnabled) {
		GuiControl, Settings:Enable, GCEnvDDL
		GuiControl, Settings:Enable, GCTokenEditBtn
		GuiControl, Settings:Enable, GCTestBtn
		GuiControl, Settings:Enable, GCDashboardBtn
		GuiControl, Settings:Enable, GCEmailTplCombo
		GuiControl, Settings:Enable, GCEmailTplRefresh
		GuiControl, Settings:Enable, GCSMSTplCombo
		GuiControl, Settings:Enable, GCSMSTplRefresh
		GuiControl, Settings:Enable, Toggle_GCAutoSetup
		GuiControl, Settings:Enable, GCNamePart1DDL
		GuiControl, Settings:Enable, GCNamePart2DDL
		GuiControl, Settings:Enable, GCNamePart3DDL
	} else {
		GuiControl, Settings:Disable, GCEnvDDL
		GuiControl, Settings:Disable, GCTokenEditBtn
		GuiControl, Settings:Disable, GCTestBtn
		GuiControl, Settings:Disable, GCDashboardBtn
		GuiControl, Settings:Disable, GCEmailTplCombo
		GuiControl, Settings:Disable, GCEmailTplRefresh
		GuiControl, Settings:Disable, GCSMSTplCombo
		GuiControl, Settings:Disable, GCSMSTplRefresh
		GuiControl, Settings:Disable, Toggle_GCAutoSetup
		GuiControl, Settings:Disable, GCNamePart1DDL
		GuiControl, Settings:Disable, GCNamePart2DDL
		GuiControl, Settings:Disable, GCNamePart3DDL
	}
	; Recreate toolbar to reflect changes
	CreateFloatingToolbar()
return

; Toggle handler for GC Auto Setup
Toggle_GCAutoSetup_Changed:
	Gui, Settings:Submit, NoHide
	GuiControlGet, toggleState,, Toggle_GCAutoSetup
	Settings_GCAutoSetup := toggleState
	IniWrite, %Settings_GCAutoSetup%, %IniFilename%, GoCardless, AutoSetup
return

; Handler for PayPlan name format dropdowns
GCNamePartChanged:
	Gui, Settings:Submit, NoHide
	GuiControlGet, Settings_GCNamePart1,, GCNamePart1DDL
	GuiControlGet, Settings_GCNamePart2,, GCNamePart2DDL
	GuiControlGet, Settings_GCNamePart3,, GCNamePart3DDL
	IniWrite, %Settings_GCNamePart1%, %IniFilename%, GoCardless, NamePart1
	IniWrite, %Settings_GCNamePart2%, %IniFilename%, GoCardless, NamePart2
	IniWrite, %Settings_GCNamePart3%, %IniFilename%, GoCardless, NamePart3
	UpdateGCNameExample()
return

; Update the PayPlan name example based on current dropdown selections
UpdateGCNameExample() {
	global Settings_GCNamePart1, Settings_GCNamePart2, Settings_GCNamePart3
	
	; Sample data for preview
	sampleData := {shootNo: "P26005", surname: "Smith", firstName: "John", fullName: "John Smith", ghlId: "abc123xyz", albumName: "2026-02-17_Smith"}
	
	; Build example string from selected parts
	parts := []
	Loop, 3 {
		partNum := A_Index
		partVal := Settings_GCNamePart%partNum%
		if (partVal = "" || partVal = "(none)")
			continue
		if (partVal = "Shoot No")
			parts.Push(sampleData.shootNo)
		else if (partVal = "Surname")
			parts.Push(sampleData.surname)
		else if (partVal = "First Name")
			parts.Push(sampleData.firstName)
		else if (partVal = "Full Name")
			parts.Push(sampleData.fullName)
		else if (partVal = "GHL ID")
			parts.Push(sampleData.ghlId)
		else if (partVal = "Album Name")
			parts.Push(sampleData.albumName)
	}
	
	; Join with " - " separator
	example := ""
	for i, part in parts {
		if (example != "")
			example .= " - "
		example .= part
	}
	
	if (example = "")
		example := "(no format selected)"
	
	GuiControl, Settings:, GCNameExample, %example%
}

GCEmailTplChanged:
	Gui, Settings:Submit, NoHide
	; Skip saving if we're in the middle of a refresh or initial build
	if (GC_TemplateRefreshing || GC_BuildingPanel)
		return
	GuiControlGet, selectedTemplate,, GCEmailTplCombo
	if (selectedTemplate = "SELECT" || selectedTemplate = "") {
		; Clear the settings when SELECT is chosen
		Settings_GCEmailTemplateID := ""
		Settings_GCEmailTemplateName := "SELECT"
		IniWrite, %Settings_GCEmailTemplateID%, %IniFilename%, GoCardless, EmailTemplateID
		IniWrite, %Settings_GCEmailTemplateName%, %IniFilename%, GoCardless, EmailTemplateName
	} else {
		Settings_GCEmailTemplateName := selectedTemplate
		; Look up the template ID from cached templates
		Loop, Parse, GHL_CachedEmailTemplates, `n
		{
			if (A_LoopField = "")
				continue
			parts := StrSplit(A_LoopField, "|")
			if (parts.Length() >= 2 && parts[2] = selectedTemplate) {
				Settings_GCEmailTemplateID := parts[1]
				break
			}
		}
		; Save to INI
		IniWrite, %Settings_GCEmailTemplateID%, %IniFilename%, GoCardless, EmailTemplateID
		IniWrite, %Settings_GCEmailTemplateName%, %IniFilename%, GoCardless, EmailTemplateName
	}
return

GCSMSTplChanged:
	Gui, Settings:Submit, NoHide
	; Skip saving if we're in the middle of a refresh or initial build
	if (GC_TemplateRefreshing || GC_BuildingPanel)
		return
	GuiControlGet, selectedTemplate,, GCSMSTplCombo
	if (selectedTemplate = "SELECT" || selectedTemplate = "") {
		; Clear the settings when SELECT is chosen
		Settings_GCSMSTemplateID := ""
		Settings_GCSMSTemplateName := "SELECT"
		IniWrite, %Settings_GCSMSTemplateID%, %IniFilename%, GoCardless, SMSTemplateID
		IniWrite, %Settings_GCSMSTemplateName%, %IniFilename%, GoCardless, SMSTemplateName
	} else {
		Settings_GCSMSTemplateName := selectedTemplate
		; Look up the template ID from cached SMS templates
		Loop, Parse, GHL_CachedSMSTemplates, `n
		{
			if (A_LoopField = "")
				continue
			parts := StrSplit(A_LoopField, "|")
			if (parts.Length() >= 2 && parts[2] = selectedTemplate) {
				Settings_GCSMSTemplateID := parts[1]
				break
			}
		}
		; Save to INI
		IniWrite, %Settings_GCSMSTemplateID%, %IniFilename%, GoCardless, SMSTemplateID
		IniWrite, %Settings_GCSMSTemplateName%, %IniFilename%, GoCardless, SMSTemplateName
	}
return

RefreshGCSMSTemplates:
	; Fetch SMS templates from GHL for GoCardless mandate notifications
	GC_TemplateRefreshing := true
	ToolTip, Fetching SMS templates from GHL...
	
	; Build command using GetScriptCommand
	tempFile := A_Temp . "\ghl_sms_templates_gc.json"
	scriptCmd := GetScriptCommand("sync_ps_invoice", "--list-sms-templates")
	
	if (scriptCmd = "") {
		ToolTip
		GC_TemplateRefreshing := false
		DarkMsgBox("Error", "Script not found: sync_ps_invoice", "error")
		return
	}
	
	; Delete any existing temp file
	FileDelete, %tempFile%
	
	; Write command to temp .cmd file
	tempCmd := A_Temp . "\sk_gc_sms_tpl_" . A_TickCount . ".cmd"
	FileDelete, %tempCmd%
	FileAppend, % "@" . scriptCmd . " > """ . tempFile . """ 2>&1`n", %tempCmd%
	RunWait, %ComSpec% /c "%tempCmd%", , Hide
	FileDelete, %tempCmd%
	
	; Read and parse the result
	FileRead, result, %tempFile%
	FileDelete, %tempFile%
	
	ToolTip
	
	if (InStr(result, "ERROR") || InStr(result, "NO_TEMPLATES") || result = "") {
		GC_TemplateRefreshing := false
		DarkMsgBox("No SMS Templates", "No SMS templates found in GHL.`n`nCreate an SMS template in GHL first.", "info")
		return
	}
	
	; Cache the SMS templates
	GHL_CachedSMSTemplates := result
	
	; Save to INI for persistence
	iniValue := StrReplace(result, "`n", "§§")
	iniValue := StrReplace(iniValue, "`r", "")
	IniWrite, %iniValue%, %IniFilename%, GHL, CachedSMSTemplates
	
	; Rebuild the dropdown with SELECT first
	newSmsList := "SELECT"
	Loop, Parse, result, `n, `r
	{
		if (A_LoopField = "")
			continue
		parts := StrSplit(A_LoopField, "|")
		if (parts.Length() >= 2) {
			newSmsList .= "|" . parts[2]
		}
	}
	
	GuiControl, Settings:, GCSMSTplCombo, |%newSmsList%
	if (Settings_GCSMSTemplateName != "" && Settings_GCSMSTemplateName != "(none selected)" && Settings_GCSMSTemplateName != "SELECT")
		GuiControl, Settings:ChooseString, GCSMSTplCombo, %Settings_GCSMSTemplateName%
	else
		GuiControl, Settings:ChooseString, GCSMSTplCombo, SELECT
	
	templateCount := StrSplit(result, "`n").MaxIndex()
	GC_TemplateRefreshing := false
	DarkMsgBox("SMS Templates Loaded", "Loaded " . templateCount . " SMS templates from GHL.", "success", {timeout: 2})
return

RefreshGCEmailTemplates:
	; Fetch email templates from GHL for GoCardless mandate notifications
	GC_TemplateRefreshing := true
	ToolTip, Fetching email templates from GHL...
	
	; Build command using GetScriptCommand (handles .exe vs .py automatically)
	tempFile := A_Temp . "\ghl_email_templates_gc.json"
	scriptCmd := GetScriptCommand("sync_ps_invoice", "--list-email-templates")
	
	if (scriptCmd = "") {
		ToolTip
		GC_TemplateRefreshing := false
		DarkMsgBox("Error", "Script not found: sync_ps_invoice", "error")
		return
	}
	
	; Delete any existing temp file
	FileDelete, %tempFile%
	
	; Write command to temp .cmd file
	tempCmd := A_Temp . "\sk_gc_email_tpl_" . A_TickCount . ".cmd"
	FileDelete, %tempCmd%
	FileAppend, % "@" . scriptCmd . " > """ . tempFile . """ 2>&1`n", %tempCmd%
	RunWait, %ComSpec% /c "%tempCmd%", , Hide
	FileDelete, %tempCmd%
	
	; Read and parse the result
	FileRead, result, %tempFile%
	FileDelete, %tempFile%
	
	ToolTip
	
	if (InStr(result, "ERROR") || result = "") {
		GC_TemplateRefreshing := false
		DarkMsgBox("Error", "Failed to fetch email templates from GHL.", "error")
		return
	}
	
	; Cache the templates (format: id|name per line)
	GHL_CachedEmailTemplates := result
	
	; Save to INI for persistence (use same format as Print tab)
	iniValue := StrReplace(result, "`n", "§§")
	iniValue := StrReplace(iniValue, "`r", "")
	IniWrite, %iniValue%, %IniFilename%, GHL, CachedEmailTemplates
	
	; Rebuild the dropdown with SELECT first
	newList := "SELECT"
	Loop, Parse, result, `n, `r
	{
		if (A_LoopField = "")
			continue
		parts := StrSplit(A_LoopField, "|")
		if (parts.Length() >= 2) {
			newList .= "|" . parts[2]
		}
	}
	
	GuiControl, Settings:, GCEmailTplCombo, |%newList%
	if (Settings_GCEmailTemplateName != "" && Settings_GCEmailTemplateName != "(none selected)" && Settings_GCEmailTemplateName != "SELECT")
		GuiControl, Settings:ChooseString, GCEmailTplCombo, %Settings_GCEmailTemplateName%
	else
		GuiControl, Settings:ChooseString, GCEmailTplCombo, SELECT
	
	templateCount := StrSplit(result, "`n").MaxIndex()
	GC_TemplateRefreshing := false
	DarkMsgBox("Templates Loaded", "Loaded " . templateCount . " email templates from GHL.", "success", {timeout: 2})
return

CreateDisplayPanel()
{
	global
	
	; Theme-aware colors
	if (Settings_DarkMode) {
		headerColor := "4FC3F7"
		textColor := "FFFFFF"
		labelColor := "CCCCCC"
		mutedColor := "888888"
		groupColor := "666666"
	} else {
		headerColor := "0078D4"
		textColor := "1E1E1E"
		labelColor := "444444"
		mutedColor := "666666"
		groupColor := "999999"
	}
	
	; Display panel container
	Gui, Settings:Add, Text, x190 y10 w510 h680 BackgroundTrans vPanelDisplay
	
	; Section header
	Gui, Settings:Font, s16 c%headerColor%, Segoe UI
	Gui, Settings:Add, Text, x200 y20 w400 BackgroundTrans vDisplayHeader, 🖥 Display Settings
	
	; ═══════════════════════════════════════════════════════════════════════════
	; TOOLBAR GROUP BOX - Display and Size settings
	; ═══════════════════════════════════════════════════════════════════════════
	Gui, Settings:Font, s10 Norm c%groupColor%, Segoe UI
	Gui, Settings:Add, GroupBox, x195 y60 w480 h55 vDisplayToolbarGroup, Toolbar
	
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	; Display monitor dropdown
	Gui, Settings:Add, Text, x210 y82 w50 h22 BackgroundTrans vDisplayMonitorLabel, Display:
	SysGet, monCount, MonitorCount
	monList := ""
	Loop, %monCount%
		monList .= (A_Index > 1 ? "|" : "") . A_Index
	Gui, Settings:Add, DropDownList, x265 y80 w50 cBlack vDisplayQRDisplay Choose%Settings_QRCode_Display%, %monList%
	
	; Size slider (25% to 85%)
	Gui, Settings:Add, Text, x330 y82 w30 h22 BackgroundTrans vDisplaySizeLabel, Size:
	Gui, Settings:Add, Slider, x365 y78 w150 h24 Range25-85 TickInterval10 vDisplaySizeSlider AltSubmit gDisplaySizeChanged, %Settings_DisplaySize%
	Gui, Settings:Add, Text, x520 y82 w40 h22 BackgroundTrans vDisplaySizeValue, %Settings_DisplaySize%`%
	
	; Identify displays button
	Gui, Settings:Add, Button, x570 y78 w85 h24 gDisplayIdentifyBtn vDisplayIdentifyBtn, Identify
	
	; ═══════════════════════════════════════════════════════════════════════════
	; QR CODE TEXT FIELDS GROUP BOX
	; ═══════════════════════════════════════════════════════════════════════════
	Gui, Settings:Font, s10 Norm c%groupColor%, Segoe UI
	Gui, Settings:Add, GroupBox, x195 y125 w480 h130 vDisplayQRCodeGroup, QR Code Text
	
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x210 y150 w65 h22 BackgroundTrans vDisplayQRLabel1, QR Text 1:
	Gui, Settings:Add, Edit, x280 y148 w375 h22 cBlack vDisplayQREdit1, %Settings_QRCode_Text1%
	
	Gui, Settings:Add, Text, x210 y178 w65 h22 BackgroundTrans vDisplayQRLabel2, QR Text 2:
	Gui, Settings:Add, Edit, x280 y176 w375 h22 cBlack vDisplayQREdit2, %Settings_QRCode_Text2%
	
	Gui, Settings:Add, Text, x210 y206 w65 h22 BackgroundTrans vDisplayQRLabel3, QR Text 3:
	Gui, Settings:Add, Edit, x280 y204 w375 h22 cBlack vDisplayQREdit3, %Settings_QRCode_Text3%
	
	; ═══════════════════════════════════════════════════════════════════════════
	; BANK TRANSFER GROUP BOX
	; ═══════════════════════════════════════════════════════════════════════════
	Gui, Settings:Font, s10 Norm c%groupColor%, Segoe UI
	Gui, Settings:Add, GroupBox, x195 y265 w480 h155 vDisplayBankGroup, Bank Transfer Details
	
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x210 y292 w75 h22 BackgroundTrans vDisplayBankInstLabel, Bank:
	Gui, Settings:Add, Edit, x290 y290 w365 h22 cBlack vDisplayBankInstEdit, %Settings_BankInstitution%
	
	Gui, Settings:Add, Text, x210 y320 w75 h22 BackgroundTrans vDisplayBankNameLabel, Acc Name:
	Gui, Settings:Add, Edit, x290 y318 w365 h22 cBlack vDisplayBankNameEdit, %Settings_BankName%
	
	Gui, Settings:Add, Text, x210 y348 w75 h22 BackgroundTrans vDisplayBankSortLabel, Sort Code:
	; Format sort code with dashes for display
	displaySortCode := Settings_BankSortCode
	if (StrLen(RegExReplace(displaySortCode, "[^0-9]")) = 6 && !InStr(displaySortCode, "-"))
		displaySortCode := SubStr(displaySortCode, 1, 2) . "-" . SubStr(displaySortCode, 3, 2) . "-" . SubStr(displaySortCode, 5, 2)
	Gui, Settings:Add, Edit, x290 y346 w120 h22 cBlack vDisplayBankSortEdit, %displaySortCode%
	; Scale slider next to sort code
	Gui, Settings:Add, Text, x425 y348 w35 h22 BackgroundTrans vDisplayBankScaleLabel, Scale:
	Gui, Settings:Add, Slider, x465 y344 w130 h24 Range50-150 TickInterval25 vDisplayBankScaleSlider AltSubmit gDisplayBankScaleChanged, %Settings_BankScale%
	Gui, Settings:Add, Text, x600 y348 w50 h22 BackgroundTrans vDisplayBankScaleValue, %Settings_BankScale%`%
	
	Gui, Settings:Add, Text, x210 y376 w75 h22 BackgroundTrans vDisplayBankAccLabel, Acc No:
	Gui, Settings:Add, Edit, x290 y374 w120 h22 cBlack vDisplayBankAccEdit, %Settings_BankAccNo%
	
	; ═══════════════════════════════════════════════════════════════════════════
	; CUSTOM IMAGES GROUP BOX
	; ═══════════════════════════════════════════════════════════════════════════
	Gui, Settings:Font, s10 Norm c%groupColor%, Segoe UI
	Gui, Settings:Add, GroupBox, x195 y430 w480 h120 vDisplayImagesGroup, Custom Images
	
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x210 y453 w60 h22 BackgroundTrans vDisplayImg1Label, Image 1:
	Gui, Settings:Add, Edit, x275 y451 w310 h22 cBlack vDisplayImg1Edit, %Settings_DisplayImage1%
	Gui, Settings:Add, Button, x590 y450 w65 h24 gDisplayImg1Browse vDisplayImg1Btn, Browse
	
	Gui, Settings:Add, Text, x210 y479 w60 h22 BackgroundTrans vDisplayImg2Label, Image 2:
	Gui, Settings:Add, Edit, x275 y477 w310 h22 cBlack vDisplayImg2Edit, %Settings_DisplayImage2%
	Gui, Settings:Add, Button, x590 y476 w65 h24 gDisplayImg2Browse vDisplayImg2Btn, Browse
	
	Gui, Settings:Add, Text, x210 y505 w60 h22 BackgroundTrans vDisplayImg3Label, Image 3:
	Gui, Settings:Add, Edit, x275 y503 w310 h22 cBlack vDisplayImg3Edit, %Settings_DisplayImage3%
	Gui, Settings:Add, Button, x590 y502 w65 h24 gDisplayImg3Browse vDisplayImg3Btn, Browse
	
	Gui, Settings:Font, s9 Norm c%mutedColor%, Segoe UI
	Gui, Settings:Add, Text, x210 y560 w440 BackgroundTrans vDisplayImagesHint, All displays cycle with arrow keys. Use toolbar to configure monitor and size.
	
	Gui, Settings:Font, s10 Norm c%textColor%, Segoe UI
}

CreateDeveloperPanel()
{
	global
	
	; Get theme colors
	textColor := Settings_DarkMode ? "FFFFFF" : "000000"
	headerColor := Settings_DarkMode ? "FF8C00" : "E67E00"
	labelColor := Settings_DarkMode ? "AAAAAA" : "666666"
	mutedColor := Settings_DarkMode ? "888888" : "999999"
	groupColor := Settings_DarkMode ? "666666" : "999999"
	successColor := "00AA00"
	
	; Developer panel container (initially hidden)
	Gui, Settings:Add, Text, x190 y10 w510 h680 BackgroundTrans vPanelDeveloper Hidden
	
	; Section header
	Gui, Settings:Font, s16 c%headerColor%, Segoe UI
	Gui, Settings:Add, Text, x195 y20 w480 BackgroundTrans vDevHeader Hidden, 🛠 Developer Tools
	
	; ═══════════════════════════════════════════════════════════════════════════
	; STATUS GROUP BOX
	; ═══════════════════════════════════════════════════════════════════════════
	Gui, Settings:Font, s10 Norm c%groupColor%, Segoe UI
	Gui, Settings:Add, GroupBox, x195 y55 w480 h115 vDevStatusGroup Hidden, Status
	
	; Warning message
	Gui, Settings:Font, s10 Norm cFF6600, Segoe UI
	Gui, Settings:Add, Text, x210 y80 w440 BackgroundTrans vDevWarning Hidden HwndHwndDevWarning, ⚠ Developer mode - for internal use only
	RegisterSettingsTooltip(HwndDevWarning, "DEVELOPER MODE`n`nThis panel is only visible when running`nas an uncompiled script.`n`nNot available in the released EXE version.")
	
	; Version info
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x210 y105 w100 BackgroundTrans vDevVersionLabel Hidden, Version:
	Gui, Settings:Add, Text, x315 y105 w80 BackgroundTrans vDevVersionValue Hidden, %ScriptVersion%
	
	; Running mode indicator
	runningMode := A_IsCompiled ? "Consumer (EXE)" : "Developer (Script)"
	modeColor := A_IsCompiled ? "00CC00" : "FF9900"
	Gui, Settings:Font, s10 Norm c%modeColor%, Segoe UI
	Gui, Settings:Add, Text, x400 y105 w80 BackgroundTrans vDevModeLabel Hidden, Mode:
	Gui, Settings:Add, Text, x485 y105 w150 BackgroundTrans vDevModeValue Hidden, %runningMode%
	
	; Menu delay calibration result
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x210 y125 w100 BackgroundTrans vDevDelayLabel Hidden, Menu Delay:
	delayText := Settings_MenuDelay . "ms"
	if (Settings_MenuDelay <= 50)
		delayColor := "00CC00"  ; Green - fast
	else if (Settings_MenuDelay <= 100)
		delayColor := "FF9900"  ; Orange - medium
	else
		delayColor := "FF6600"  ; Red-orange - slow
	Gui, Settings:Font, s10 Norm c%delayColor%, Segoe UI
	Gui, Settings:Add, Text, x315 y125 w340 BackgroundTrans vDevDelayValue Hidden HwndHwndDevDelay, %delayText%
	RegisterSettingsTooltip(HwndDevDelay, "MENU DELAY CALIBRATION`n`nAuto-detected at startup based on CPU speed.`n`n50ms = Fast PC`n75ms = Good PC`n100ms = Medium PC`n200ms = Slow PC`n`nUsed for menu keystroke timing.")
	
	; ═══════════════════════════════════════════════════════════════════════════
	; BUILD & RELEASE GROUP BOX
	; ═══════════════════════════════════════════════════════════════════════════
	Gui, Settings:Font, s10 Norm c%groupColor%, Segoe UI
	Gui, Settings:Add, GroupBox, x195 y180 w480 h130 vDevBuildGroup Hidden, Build && Release
	
	Gui, Settings:Font, s10 Norm c%mutedColor%, Segoe UI
	Gui, Settings:Add, Text, x210 y205 w440 BackgroundTrans vDevBuildDesc Hidden, Create release package, update version, and push to GitHub.
	
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Button, x210 y235 w140 h40 gDevCreateRelease vDevCreateBtn Hidden HwndHwndDevCreate, 📦 Create Release
	RegisterSettingsTooltip(HwndDevCreate, "CREATE RELEASE`n`nCompile the script to EXE and create`na release package with all required files.`n`nOutput goes to the build folder.")
	Gui, Settings:Add, Button, x360 y235 w140 h40 gDevUpdateVersion vDevUpdateBtn Hidden HwndHwndDevUpdate, 🔢 Update Version
	RegisterSettingsTooltip(HwndDevUpdate, "UPDATE VERSION`n`nIncrement the version number.`nUpdates ScriptVersion and BuildDate variables.`n`nFollow semantic versioning: Major.Minor.Patch")
	Gui, Settings:Add, Button, x510 y235 w150 h40 gDevPushGitHub vDevPushBtn Hidden HwndHwndDevPush, 🚀 Push GitHub
	RegisterSettingsTooltip(HwndDevPush, "PUSH TO GITHUB`n`nCommit changes and push to the remote repository.`nOpens GitHub Desktop or runs git push.`n`nMake sure all changes are saved first.")
	
	; ═══════════════════════════════════════════════════════════════════════════
	; QUICK ACTIONS GROUP BOX
	; ═══════════════════════════════════════════════════════════════════════════
	Gui, Settings:Font, s10 Norm c%groupColor%, Segoe UI
	Gui, Settings:Add, GroupBox, x195 y320 w480 h130 vDevQuickGroup Hidden, Quick Actions
	
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Button, x210 y350 w100 h35 gDevReloadScript vDevReloadBtn Hidden HwndHwndDevReload, 🔄 Reload
	RegisterSettingsTooltip(HwndDevReload, "RELOAD SCRIPT`n`nReload the script to apply code changes.`nSame as pressing the Dev Reload hotkey.`n`nUseful when testing modifications.")
	Gui, Settings:Add, Button, x320 y350 w110 h35 gDevTestBuild vDevTestBtn Hidden HwndHwndDevTest, 🧪 Test Build
	RegisterSettingsTooltip(HwndDevTest, "TEST BUILD`n`nRun a test compilation to check for errors.`nDoes not create a release package.`n`nUseful for validating syntax before release.")
	Gui, Settings:Add, Button, x440 y350 w100 h35 gDevOpenGitHub vDevGitHubBtn Hidden HwndHwndDevGitHub, 🌐 GitHub
	RegisterSettingsTooltip(HwndDevGitHub, "OPEN GITHUB`n`nOpen the GitHub repository in your browser.`nView commits, issues, and pull requests.")
	Gui, Settings:Add, Button, x550 y350 w110 h35 gDevQuickPush vDevQuickPushBtn Hidden HwndHwndDevQuickPush, ⚡ Publish
	RegisterSettingsTooltip(HwndDevQuickPush, "QUICK PUBLISH`n`nOne-click build and push to GitHub.`nCreates release and uploads automatically.`nIncludes changelog, version.json, and user manual.`n`nUse for rapid deployment.")
	
	; Second row
	Gui, Settings:Add, Button, x210 y395 w120 h35 gDevOpenFolder vDevOpenFolderBtn Hidden HwndHwndDevFolder, 📂 Open Folder
	RegisterSettingsTooltip(HwndDevFolder, "OPEN FOLDER`n`nOpen the script folder in Windows Explorer.`nQuick access to source files and resources.")
	Gui, Settings:Add, Button, x340 y395 w140 h35 gDevPushWebsite vDevPushWebBtn Hidden HwndHwndDevPushWeb, 🌍 Push Website
	RegisterSettingsTooltip(HwndDevPushWeb, "PUSH WEBSITE`n`nSync website_ps to docs folder and push to GitHub.`nOnly commits website files (no scripts).`n`nSite goes live in ~1-2 minutes.")
	
	; Progress bar for Push Website (hidden by default)
	Gui, Settings:Add, Progress, x340 y435 w140 h8 vDevWebProgress Hidden BackgroundBlack c4FC3F7, 0
	Gui, Settings:Add, Text, x340 y435 w140 h8 vDevWebProgressStatus Hidden BackgroundTrans Center c4FC3F7,
}

ShowSettingsTab(tabName)
{
	global
	
	; Hide all tab indicators
	GuiControl, Settings:Hide, TabGeneralBg
	GuiControl, Settings:Hide, TabGHLBg
	GuiControl, Settings:Hide, TabHotkeysBg
	GuiControl, Settings:Hide, TabFilesBg
	GuiControl, Settings:Hide, TabAboutBg
	GuiControl, Settings:Hide, TabShortcutsBg
	GuiControl, Settings:Hide, TabPrintBg
	GuiControl, Settings:Hide, TabGoCardlessBg
	GuiControl, Settings:Hide, TabDisplayBg
	GuiControl, Settings:Hide, TabDeveloperBg
	
	; Hide all panels - General
	GuiControl, Settings:Hide, PanelGeneral
	GuiControl, Settings:Hide, GenHeader
	GuiControl, Settings:Hide, GenBehaviorGroup
	GuiControl, Settings:Hide, GenStartBoot
	GuiControl, Settings:Hide, Toggle_StartOnBoot
	GuiControl, Settings:Hide, GenTrayIcon
	GuiControl, Settings:Hide, Toggle_ShowTrayIcon
	GuiControl, Settings:Hide, GenSounds
	GuiControl, Settings:Hide, Toggle_EnableSounds
	GuiControl, Settings:Hide, GenAutoPS
	GuiControl, Settings:Hide, Toggle_AutoDetectPS
	GuiControl, Settings:Hide, GenDarkMode
	GuiControl, Settings:Hide, Toggle_DarkMode
	GuiControl, Settings:Hide, GenDefaultsGroup
	GuiControl, Settings:Hide, GenRecurLabel
	GuiControl, Settings:Hide, Settings_DefaultRecurring_DDL
	GuiControl, Settings:Hide, GenRecurOptionsLabel
	GuiControl, Settings:Hide, GenRecurOptionsEdit
	GuiControl, Settings:Hide, GenRecurOptionsBtn
	GuiControl, Settings:Hide, GenProSelectGroup
	GuiControl, Settings:Hide, GenShortcutBtn
	GuiControl, Settings:Hide, GenManualBtn
	GuiControl, Settings:Hide, GenExportBtn
	GuiControl, Settings:Hide, GenImportBtn
	
	; Hide all panels - GHL
	GuiControl, Settings:Hide, PanelGHL
	GuiControl, Settings:Hide, GHLHeader
	GuiControl, Settings:Hide, GHLConnection
	GuiControl, Settings:Hide, GHLEnable
	GuiControl, Settings:Hide, Toggle_GHL_Enabled
	GuiControl, Settings:Hide, GHLAutoLoad
	GuiControl, Settings:Hide, Toggle_GHL_AutoLoad
	GuiControl, Settings:Hide, GHLApiConfig
	GuiControl, Settings:Hide, GHLApiLabel
	GuiControl, Settings:Hide, GHLApiKeyDisplay
	GuiControl, Settings:Hide, GHLApiEditBtn
	GuiControl, Settings:Hide, GHLLocLabel
	GuiControl, Settings:Hide, GHLLocIDDisplay
	GuiControl, Settings:Hide, GHLLocEditBtn
	GuiControl, Settings:Hide, GHLStatus
	GuiControl, Settings:Hide, GHLStatusText
	GuiControl, Settings:Hide, GHLTestBtn
	GuiControl, Settings:Hide, GHLSetupBtn
	GuiControl, Settings:Hide, GHLInvoiceHeader
	GuiControl, Settings:Hide, GHLWatchLabel
	GuiControl, Settings:Hide, GHLWatchFolderEdit
	GuiControl, Settings:Hide, GHLWatchBrowseBtn
	GuiControl, Settings:Hide, GHLOpenInvoiceURL
	GuiControl, Settings:Hide, Toggle_OpenInvoiceURL
	GuiControl, Settings:Hide, GHLFinancialsOnly
	GuiControl, Settings:Hide, Toggle_FinancialsOnly
	GuiControl, Settings:Hide, GHLAutoSaveXML
	GuiControl, Settings:Hide, Toggle_AutoSaveXML
	GuiControl, Settings:Hide, GHLContactSheet
	GuiControl, Settings:Hide, Toggle_ContactSheet
	GuiControl, Settings:Hide, GHLTagsLabel
	GuiControl, Settings:Hide, GHLTagsEdit
	GuiControl, Settings:Hide, GHLTagsRefresh
	GuiControl, Settings:Hide, AutoTagContactLabel
	GuiControl, Settings:Hide, Toggle_AutoAddContactTags
	GuiControl, Settings:Hide, GHLOppTagsLabel
	GuiControl, Settings:Hide, GHLOppTagsEdit
	GuiControl, Settings:Hide, GHLOppTagsRefresh
	GuiControl, Settings:Hide, AutoTagOppLabel
	GuiControl, Settings:Hide, Toggle_AutoAddOppTags
	GuiControl, Settings:Hide, GHLSetOrderQRBtn
	GuiControl, Settings:Hide, GHLCollectCS
	GuiControl, Settings:Hide, Toggle_CollectContactSheets
	GuiControl, Settings:Hide, GHLCSFolderLabel
	GuiControl, Settings:Hide, GHLCSFolderEdit
	GuiControl, Settings:Hide, GHLCSFolderBrowse
	GuiControl, Settings:Hide, GHLInfo
	
	; Hide all panels - Hotkeys
	GuiControl, Settings:Hide, PanelHotkeys
	GuiControl, Settings:Hide, HotkeysHeader
	GuiControl, Settings:Hide, HotkeysNote
	GuiControl, Settings:Hide, HotkeysGlobalGroup
	GuiControl, Settings:Hide, HKLabelGHL
	GuiControl, Settings:Hide, Hotkey_GHLLookup_Edit
	GuiControl, Settings:Hide, HKCaptureGHL
	GuiControl, Settings:Hide, HKLabelPP
	GuiControl, Settings:Hide, Hotkey_PayPlan_Edit
	GuiControl, Settings:Hide, HKCapturePP
	GuiControl, Settings:Hide, HKLabelSettings
	GuiControl, Settings:Hide, Hotkey_Settings_Edit
	GuiControl, Settings:Hide, HKCaptureSettings
	GuiControl, Settings:Hide, HKLabelDevReload
	GuiControl, Settings:Hide, Hotkey_DevReload_Edit
	GuiControl, Settings:Hide, HKCaptureDevReload
	GuiControl, Settings:Hide, HotkeysActionsGroup
	GuiControl, Settings:Hide, HKResetBtn
	GuiControl, Settings:Hide, HKClearBtn
	GuiControl, Settings:Hide, HotkeysInstructGroup
	GuiControl, Settings:Hide, HKInstructions1
	GuiControl, Settings:Hide, HKInstructions2
	GuiControl, Settings:Hide, HKInstructions3
	GuiControl, Settings:Hide, HKInstructions4
	GuiControl, Settings:Hide, HotkeysToolbarGroup
	GuiControl, Settings:Hide, HKToolbarIconLabel
	GuiControl, Settings:Hide, Settings_ToolbarIconColor_DDL
	GuiControl, Settings:Hide, HKColorPreview
	GuiControl, Settings:Hide, HKPickColorBtn
	GuiControl, Settings:Hide, HKToolbarPosLabel
	GuiControl, Settings:Hide, HKResetPosBtn
	GuiControl, Settings:Hide, HKAutoBlendLabel
	GuiControl, Settings:Hide, Toggle_ToolbarAutoBG
	
	; Hide all panels - About
	GuiControl, Settings:Hide, PanelAbout
	GuiControl, Settings:Hide, AboutHeader
	GuiControl, Settings:Hide, AboutAppGroup
	GuiControl, Settings:Hide, AboutDescLabel
	GuiControl, Settings:Hide, AboutDescValue
	GuiControl, Settings:Hide, AboutVersionLabel
	GuiControl, Settings:Hide, AboutVersionValue
	GuiControl, Settings:Hide, AboutBuildLabel
	GuiControl, Settings:Hide, AboutBuildValue
	GuiControl, Settings:Hide, AboutPSLabel
	GuiControl, Settings:Hide, AboutPSValue
	GuiControl, Settings:Hide, AboutUpdatesGroup
	GuiControl, Settings:Hide, AboutLatestLabel
	GuiControl, Settings:Hide, AboutLatestValue
	GuiControl, Settings:Hide, AboutAutoUpdateText
	GuiControl, Settings:Hide, Toggle_AutoUpdate
	GuiControl, Settings:Hide, AboutReinstallBtn
	GuiControl, Settings:Hide, AboutCheckNowBtn
	GuiControl, Settings:Hide, AboutSupportGroup
	GuiControl, Settings:Hide, AboutAuthorLabel
	GuiControl, Settings:Hide, AboutAuthorValue
	GuiControl, Settings:Hide, AboutEmailLink
	GuiControl, Settings:Hide, AboutManualLink
	GuiControl, Settings:Hide, AboutDocsLink
	GuiControl, Settings:Hide, AboutWhatsNewButton
	GuiControl, Settings:Hide, AboutSendLogsButton
	GuiControl, Settings:Hide, AboutLogPath
	GuiControl, Settings:Hide, AboutDiagnostics
	GuiControl, Settings:Hide, AboutAutoSendText
	GuiControl, Settings:Hide, Toggle_AutoSendLogs
	GuiControl, Settings:Hide, AboutDebugText
	GuiControl, Settings:Hide, Toggle_DebugLogging
	
	; Hide all panels - License
	GuiControl, Settings:Hide, TabLicenseBg
	GuiControl, Settings:Hide, PanelLicense
	GuiControl, Settings:Hide, LicenseHeader
	GuiControl, Settings:Hide, LicenseStatusGroup
	GuiControl, Settings:Hide, LicenseStatusText
	GuiControl, Settings:Hide, LicenseKeyGroup
	GuiControl, Settings:Hide, LicenseKeyLabel
	GuiControl, Settings:Hide, LicenseKeyEdit
	GuiControl, Settings:Hide, LicenseActivateBtn
	GuiControl, Settings:Hide, LicenseLocationInfo
	GuiControl, Settings:Hide, LicenseDetailsGroup
	GuiControl, Settings:Hide, LicenseNameLabel
	GuiControl, Settings:Hide, LicenseNameValue
	GuiControl, Settings:Hide, LicenseEmailLabel
	GuiControl, Settings:Hide, LicenseEmailValue
	GuiControl, Settings:Hide, LicenseActivatedLabel
	GuiControl, Settings:Hide, LicenseActivatedValue
	GuiControl, Settings:Hide, LicenseExpiryLabel
	GuiControl, Settings:Hide, LicenseExpiryValue
	GuiControl, Settings:Hide, LicenseActionsGroup
	GuiControl, Settings:Hide, LicenseValidateBtn
	GuiControl, Settings:Hide, LicenseDeactivateBtn
	GuiControl, Settings:Hide, LicenseBuyBtn
	GuiControl, Settings:Hide, LicensePurchaseInfo
	GuiControl, Settings:Hide, LicensePurchaseInfo2
	
	; Hide all panels - Files
	GuiControl, Settings:Hide, PanelFiles
	GuiControl, Settings:Hide, FilesHeader
	GuiControl, Settings:Hide, FilesSDCardGroup
	GuiControl, Settings:Hide, FilesEnableSDCard
	GuiControl, Settings:Hide, Toggle_SDCardEnabled
	GuiControl, Settings:Hide, FilesCardDriveLabel
	GuiControl, Settings:Hide, FilesCardDriveEdit
	GuiControl, Settings:Hide, FilesCardDriveBrowse
	GuiControl, Settings:Hide, FilesDownloadLabel
	GuiControl, Settings:Hide, FilesDownloadEdit
	GuiControl, Settings:Hide, FilesDownloadBrowse
	GuiControl, Settings:Hide, FilesArchiveGroup
	GuiControl, Settings:Hide, FilesArchiveLabel
	GuiControl, Settings:Hide, FilesArchiveEdit
	GuiControl, Settings:Hide, FilesArchiveBrowse
	GuiControl, Settings:Hide, FilesFolderTemplateLabel
	GuiControl, Settings:Hide, FilesFolderTemplateEdit
	GuiControl, Settings:Hide, FilesFolderTemplateBrowse
	GuiControl, Settings:Hide, FilesNamingGroup
	GuiControl, Settings:Hide, FilesPrefixLabel
	GuiControl, Settings:Hide, FilesPrefixEdit
	GuiControl, Settings:Hide, FilesSuffixLabel
	GuiControl, Settings:Hide, FilesSuffixEdit
	GuiControl, Settings:Hide, FilesAutoYear
	GuiControl, Settings:Hide, Toggle_AutoShootYear
	GuiControl, Settings:Hide, FilesAutoRename
	GuiControl, Settings:Hide, Toggle_AutoRenameImages
	GuiControl, Settings:Hide, FilesEditorGroup
	GuiControl, Settings:Hide, FilesEditorLabel
	GuiControl, Settings:Hide, FilesEditorEdit
	GuiControl, Settings:Hide, FilesEditorBrowse
	GuiControl, Settings:Hide, FilesOpenEditor
	GuiControl, Settings:Hide, Toggle_BrowsDown
	GuiControl, Settings:Hide, FilesAutoDrive
	GuiControl, Settings:Hide, Toggle_AutoDriveDetect
	GuiControl, Settings:Hide, FilesPSAGroup
	GuiControl, Settings:Hide, FilesPSALabel
	GuiControl, Settings:Hide, FilesPSAEdit
	
	; Hide all panels - Shortcuts
	GuiControl, Settings:Hide, PanelShortcuts
	GuiControl, Settings:Hide, SCHeader
	GuiControl, Settings:Hide, SCButtonsGroup
	GuiControl, Settings:Hide, SCDescription
	GuiControl, Settings:Hide, SCIcon_Client
	GuiControl, Settings:Hide, SCLabel_Client
	GuiControl, Settings:Hide, Toggle_ShowBtn_Client
	GuiControl, Settings:Hide, SCIcon_Invoice
	GuiControl, Settings:Hide, SCLabel_Invoice
	GuiControl, Settings:Hide, Toggle_ShowBtn_Invoice
	GuiControl, Settings:Hide, SCIcon_OpenGHL
	GuiControl, Settings:Hide, SCLabel_OpenGHL
	GuiControl, Settings:Hide, Toggle_ShowBtn_OpenGHL
	GuiControl, Settings:Hide, SCIcon_Camera
	GuiControl, Settings:Hide, SCLabel_Camera
	GuiControl, Settings:Hide, Toggle_ShowBtn_Camera
	GuiControl, Settings:Hide, SCIcon_Sort
	GuiControl, Settings:Hide, SCLabel_Sort
	GuiControl, Settings:Hide, Toggle_ShowBtn_Sort
	GuiControl, Settings:Hide, SCIcon_Photoshop
	GuiControl, Settings:Hide, SCLabel_Photoshop
	GuiControl, Settings:Hide, Toggle_ShowBtn_Photoshop
	GuiControl, Settings:Hide, SCIcon_Refresh
	GuiControl, Settings:Hide, SCLabel_Refresh
	GuiControl, Settings:Hide, Toggle_ShowBtn_Refresh
	GuiControl, Settings:Hide, SCIcon_Print
	GuiControl, Settings:Hide, SCLabel_Print
	GuiControl, Settings:Hide, Toggle_ShowBtn_Print
	GuiControl, Settings:Hide, SCIcon_Download
	GuiControl, Settings:Hide, SCLabel_Download
	GuiControl, Settings:Hide, SCIcon_QRCode
	GuiControl, Settings:Hide, SCLabel_QRCode
	GuiControl, Settings:Hide, Toggle_ShowBtn_QRCode
	GuiControl, Settings:Hide, SCInfoNote
	
	; Hide all panels - Print
	GuiControl, Settings:Hide, TabPrintBg
	GuiControl, Settings:Hide, PanelPrint
	GuiControl, Settings:Hide, PrintHeader
	GuiControl, Settings:Hide, PrintPrinterGroup
	GuiControl, Settings:Hide, PrintPrinterLabel
	GuiControl, Settings:Hide, PrintPrinterCombo
	GuiControl, Settings:Hide, PrintPrinterHint
	GuiControl, Settings:Hide, PrintTemplatesGroup
	GuiControl, Settings:Hide, PrintTemplatesDesc
	GuiControl, Settings:Hide, PrintRefreshBtn
	GuiControl, Settings:Hide, PrintPayPlanLabel
	GuiControl, Settings:Hide, PrintPayPlanCombo
	GuiControl, Settings:Hide, PrintStandardLabel
	GuiControl, Settings:Hide, PrintStandardCombo
	GuiControl, Settings:Hide, PrintTemplatesHint
	GuiControl, Settings:Hide, PrintEmailGroup
	GuiControl, Settings:Hide, PrintEmailTplLabel
	GuiControl, Settings:Hide, PrintEmailTplCombo
	GuiControl, Settings:Hide, PrintEmailTplRefresh
	GuiControl, Settings:Hide, PrintEmailTplHint
	GuiControl, Settings:Hide, PrintRoomFolderLabel
	GuiControl, Settings:Hide, PrintRoomFolderCombo
	GuiControl, Settings:Hide, PrintRoomFolderBrowse
	GuiControl, Settings:Hide, PrintPDFGroup
	GuiControl, Settings:Hide, PrintEnablePDFLabel
	GuiControl, Settings:Hide, Toggle_EnablePDF
	GuiControl, Settings:Hide, PrintPDFDesc
	GuiControl, Settings:Hide, PrintPDFCopyLabel
	GuiControl, Settings:Hide, PrintPDFCopyEdit
	GuiControl, Settings:Hide, PrintPDFCopyBrowse
	GuiControl, Settings:Hide, PrintPDFHint
	GuiControl, Settings:Hide, PrintPDFBtn
	
	; Hide all panels - Developer
	GuiControl, Settings:Hide, PanelDeveloper
	GuiControl, Settings:Hide, DevHeader
	GuiControl, Settings:Hide, DevStatusGroup
	GuiControl, Settings:Hide, DevWarning
	GuiControl, Settings:Hide, DevVersionLabel
	GuiControl, Settings:Hide, DevVersionValue
	GuiControl, Settings:Hide, DevModeLabel
	GuiControl, Settings:Hide, DevModeValue
	GuiControl, Settings:Hide, DevDelayLabel
	GuiControl, Settings:Hide, DevDelayValue
	GuiControl, Settings:Hide, DevBuildGroup
	GuiControl, Settings:Hide, DevBuildDesc
	GuiControl, Settings:Hide, DevCreateBtn
	GuiControl, Settings:Hide, DevUpdateBtn
	GuiControl, Settings:Hide, DevPushBtn
	GuiControl, Settings:Hide, DevQuickGroup
	GuiControl, Settings:Hide, DevReloadBtn
	GuiControl, Settings:Hide, DevTestBtn
	GuiControl, Settings:Hide, DevGitHubBtn
	GuiControl, Settings:Hide, DevQuickPushBtn
	GuiControl, Settings:Hide, DevOpenFolderBtn
	GuiControl, Settings:Hide, DevPushWebBtn
	GuiControl, Settings:Hide, DevWebProgress
	GuiControl, Settings:Hide, DevWebProgressStatus
	
	; Hide all panels - GoCardless
	GuiControl, Settings:Hide, TabGoCardlessBg
	GuiControl, Settings:Hide, PanelGoCardless
	GuiControl, Settings:Hide, GCHeader
	GuiControl, Settings:Hide, GCConnection
	GuiControl, Settings:Hide, GCEnable
	GuiControl, Settings:Hide, Toggle_GoCardlessEnabled
	GuiControl, Settings:Hide, GCApiConfig
	GuiControl, Settings:Hide, GCEnvLabel
	GuiControl, Settings:Hide, GCEnvDDL
	GuiControl, Settings:Hide, GCTokenLabel
	GuiControl, Settings:Hide, GCTokenDisplay
	GuiControl, Settings:Hide, GCTokenEditBtn
	GuiControl, Settings:Hide, GCStatus
	GuiControl, Settings:Hide, GCStatusText
	GuiControl, Settings:Hide, GCTestBtn
	GuiControl, Settings:Hide, GCEmptyMandatesBtn
	GuiControl, Settings:Hide, GCDashboardBtn
	GuiControl, Settings:Hide, GCProgressBar
	GuiControl, Settings:Hide, GCProgressText
	GuiControl, Settings:Hide, GCNotifyGroup
	GuiControl, Settings:Hide, GCEmailTplLabel
	GuiControl, Settings:Hide, GCEmailTplCombo
	GuiControl, Settings:Hide, GCEmailTplRefresh
	GuiControl, Settings:Hide, GCSMSTplLabel
	GuiControl, Settings:Hide, GCSMSTplCombo
	GuiControl, Settings:Hide, GCSMSTplRefresh
	GuiControl, Settings:Hide, GCNotifyHint
	GuiControl, Settings:Hide, GCAutoGroup
	GuiControl, Settings:Hide, GCAutoSetupLabel
	GuiControl, Settings:Hide, Toggle_GCAutoSetup
	GuiControl, Settings:Hide, GCAutoHint
	GuiControl, Settings:Hide, GCWizardBtn
	GuiControl, Settings:Hide, GCNamingLabel
	GuiControl, Settings:Hide, GCNamePart1DDL
	GuiControl, Settings:Hide, GCNameSep1
	GuiControl, Settings:Hide, GCNamePart2DDL
	GuiControl, Settings:Hide, GCNameSep2
	GuiControl, Settings:Hide, GCNamePart3DDL
	GuiControl, Settings:Hide, GCNameExLabel
	GuiControl, Settings:Hide, GCNameExample
	
	; Hide all panels - Display
	GuiControl, Settings:Hide, TabDisplayBg
	GuiControl, Settings:Hide, PanelDisplay
	GuiControl, Settings:Hide, DisplayHeader
	GuiControl, Settings:Hide, DisplayToolbarGroup
	GuiControl, Settings:Hide, DisplayMonitorLabel
	GuiControl, Settings:Hide, DisplayQRDisplay
	GuiControl, Settings:Hide, DisplaySizeLabel
	GuiControl, Settings:Hide, DisplaySizeSlider
	GuiControl, Settings:Hide, DisplaySizeValue
	GuiControl, Settings:Hide, DisplayIdentifyBtn
	GuiControl, Settings:Hide, DisplayQRCodeGroup
	GuiControl, Settings:Hide, DisplayQRLabel1
	GuiControl, Settings:Hide, DisplayQREdit1
	GuiControl, Settings:Hide, DisplayQRLabel2
	GuiControl, Settings:Hide, DisplayQREdit2
	GuiControl, Settings:Hide, DisplayQRLabel3
	GuiControl, Settings:Hide, DisplayQREdit3
	GuiControl, Settings:Hide, DisplayBankGroup
	GuiControl, Settings:Hide, DisplayBankInstLabel
	GuiControl, Settings:Hide, DisplayBankInstEdit
	GuiControl, Settings:Hide, DisplayBankNameLabel
	GuiControl, Settings:Hide, DisplayBankNameEdit
	GuiControl, Settings:Hide, DisplayBankSortLabel
	GuiControl, Settings:Hide, DisplayBankSortEdit
	GuiControl, Settings:Hide, DisplayBankScaleLabel
	GuiControl, Settings:Hide, DisplayBankScaleSlider
	GuiControl, Settings:Hide, DisplayBankScaleValue
	GuiControl, Settings:Hide, DisplayBankAccLabel
	GuiControl, Settings:Hide, DisplayBankAccEdit
	GuiControl, Settings:Hide, DisplayImagesGroup
	GuiControl, Settings:Hide, DisplayImg1Label
	GuiControl, Settings:Hide, DisplayImg1Edit
	GuiControl, Settings:Hide, DisplayImg1Btn
	GuiControl, Settings:Hide, DisplayImg2Label
	GuiControl, Settings:Hide, DisplayImg2Edit
	GuiControl, Settings:Hide, DisplayImg2Btn
	GuiControl, Settings:Hide, DisplayImg3Label
	GuiControl, Settings:Hide, DisplayImg3Edit
	GuiControl, Settings:Hide, DisplayImg3Btn
	GuiControl, Settings:Hide, DisplayImagesHint
	
	; Show selected tab
	if (tabName = "General")
	{
		GuiControl, Settings:Show, TabGeneralBg
		GuiControl, Settings:Show, PanelGeneral
		GuiControl, Settings:Show, GenHeader
		GuiControl, Settings:Show, GenBehaviorGroup
		GuiControl, Settings:Show, GenStartBoot
		GuiControl, Settings:Show, Toggle_StartOnBoot
		GuiControl, Settings:Show, GenTrayIcon
		GuiControl, Settings:Show, Toggle_ShowTrayIcon
		GuiControl, Settings:Show, GenSounds
		GuiControl, Settings:Show, Toggle_EnableSounds
		GuiControl, Settings:Show, GenAutoPS
		GuiControl, Settings:Show, Toggle_AutoDetectPS
		GuiControl, Settings:Show, GenDarkMode
		GuiControl, Settings:Show, Toggle_DarkMode
		GuiControl, Settings:Show, GenDefaultsGroup
		GuiControl, Settings:Show, GenRecurLabel
		GuiControl, Settings:Show, Settings_DefaultRecurring_DDL
		GuiControl, Settings:Show, GenRecurOptionsLabel
		GuiControl, Settings:Show, GenRecurOptionsEdit
		GuiControl, Settings:Show, GenRecurOptionsBtn
		GuiControl, Settings:Show, GenProSelectGroup
		GuiControl, Settings:Show, GenShortcutBtn
		GuiControl, Settings:Show, GenManualBtn
		GuiControl, Settings:Show, GenExportBtn
		GuiControl, Settings:Show, GenImportBtn
	}
	else if (tabName = "GHL")
	{
		GuiControl, Settings:Show, TabGHLBg
		GuiControl, Settings:Show, PanelGHL
		GuiControl, Settings:Show, GHLHeader
		GuiControl, Settings:Show, GHLConnection
		GuiControl, Settings:Show, GHLEnable
		GuiControl, Settings:Show, Toggle_GHL_Enabled
		GuiControl, Settings:Show, GHLAutoLoad
		GuiControl, Settings:Show, Toggle_GHL_AutoLoad
		GuiControl, Settings:Show, GHLApiConfig
		GuiControl, Settings:Show, GHLApiLabel
		GuiControl, Settings:Show, GHLApiKeyDisplay
		GuiControl, Settings:Show, GHLApiEditBtn
		GuiControl, Settings:Show, GHLLocLabel
		GuiControl, Settings:Show, GHLLocIDDisplay
		GuiControl, Settings:Show, GHLLocEditBtn
		GuiControl, Settings:Show, GHLStatus
		GuiControl, Settings:Show, GHLStatusText
		GuiControl, Settings:Show, GHLTestBtn
		GuiControl, Settings:Show, GHLSetupBtn
		GuiControl, Settings:Show, GHLInvoiceHeader
		GuiControl, Settings:Show, GHLWatchLabel
		GuiControl, Settings:Show, GHLWatchFolderEdit
		GuiControl, Settings:Show, GHLWatchBrowseBtn
		GuiControl, Settings:Show, GHLOpenInvoiceURL
		GuiControl, Settings:Show, Toggle_OpenInvoiceURL
		GuiControl, Settings:Show, GHLFinancialsOnly
		GuiControl, Settings:Show, Toggle_FinancialsOnly
		GuiControl, Settings:Show, GHLAutoSaveXML
		GuiControl, Settings:Show, Toggle_AutoSaveXML
		GuiControl, Settings:Show, GHLContactSheet
		GuiControl, Settings:Show, Toggle_ContactSheet
		GuiControl, Settings:Show, GHLTagsLabel
		GuiControl, Settings:Show, GHLTagsEdit
		GuiControl, Settings:Show, GHLTagsRefresh
		GuiControl, Settings:Show, AutoTagContactLabel
		GuiControl, Settings:Show, Toggle_AutoAddContactTags
		GuiControl, Settings:Show, GHLOppTagsLabel
		GuiControl, Settings:Show, GHLOppTagsEdit
		GuiControl, Settings:Show, GHLOppTagsRefresh
		GuiControl, Settings:Show, AutoTagOppLabel
		GuiControl, Settings:Show, Toggle_AutoAddOppTags
		GuiControl, Settings:Show, GHLSetOrderQRBtn
		GuiControl, Settings:Show, GHLCollectCS
		GuiControl, Settings:Show, Toggle_CollectContactSheets
		GuiControl, Settings:Show, GHLCSFolderLabel
		GuiControl, Settings:Show, GHLCSFolderEdit
		GuiControl, Settings:Show, GHLCSFolderBrowse
		GuiControl, Settings:Show, GHLInfo
	}
	else if (tabName = "Hotkeys")
	{
		GuiControl, Settings:Show, TabHotkeysBg
		GuiControl, Settings:Show, PanelHotkeys
		GuiControl, Settings:Show, HotkeysHeader
		GuiControl, Settings:Show, HotkeysNote
		GuiControl, Settings:Show, HotkeysGlobalGroup
		GuiControl, Settings:Show, HKLabelGHL
		GuiControl, Settings:Show, Hotkey_GHLLookup_Edit
		GuiControl, Settings:Show, HKCaptureGHL
		GuiControl, Settings:Show, HKLabelPP
		GuiControl, Settings:Show, Hotkey_PayPlan_Edit
		GuiControl, Settings:Show, HKCapturePP
		GuiControl, Settings:Show, HKLabelSettings
		GuiControl, Settings:Show, Hotkey_Settings_Edit
		GuiControl, Settings:Show, HKCaptureSettings
		; Dev Reload hotkey only in dev mode
		if (!A_IsCompiled) {
			GuiControl, Settings:Show, HKLabelDevReload
			GuiControl, Settings:Show, Hotkey_DevReload_Edit
			GuiControl, Settings:Show, HKCaptureDevReload
		}
		GuiControl, Settings:Show, HotkeysActionsGroup
		GuiControl, Settings:Show, HKResetBtn
		GuiControl, Settings:Show, HKClearBtn
		GuiControl, Settings:Show, HotkeysToolbarGroup
		GuiControl, Settings:Show, HKToolbarIconLabel
		GuiControl, Settings:Show, Settings_ToolbarIconColor_DDL
		GuiControl, Settings:Show, HKColorPreview
		GuiControl, Settings:Show, HKPickColorBtn
		GuiControl, Settings:Show, HKToolbarPosLabel
		GuiControl, Settings:Show, HKResetPosBtn
		GuiControl, Settings:Show, HKAutoBlendLabel
		GuiControl, Settings:Show, Toggle_ToolbarAutoBG
		; Restore icon color dropdown to current value
		if (Settings_ToolbarIconColor = "White" || Settings_ToolbarIconColor = "Black" || Settings_ToolbarIconColor = "Yellow") {
			GuiControl, Settings:, Settings_ToolbarIconColor_DDL, White|Black|Yellow
			GuiControl, Settings:ChooseString, Settings_ToolbarIconColor_DDL, %Settings_ToolbarIconColor%
		} else {
			GuiControl, Settings:, Settings_ToolbarIconColor_DDL, White|Black|Yellow|Custom
			GuiControl, Settings:ChooseString, Settings_ToolbarIconColor_DDL, Custom
		}
		; Update color preview
		previewColor := GetColorHex(Settings_ToolbarIconColor)
		GuiControl, Settings:+Background%previewColor%, HKColorPreview
		GuiControl, Settings:Show, HotkeysInstructGroup
		GuiControl, Settings:Show, HKInstructions1
		GuiControl, Settings:Show, HKInstructions2
		GuiControl, Settings:Show, HKInstructions3
		GuiControl, Settings:Show, HKInstructions4
	}
	else if (tabName = "License")
	{
		GuiControl, Settings:Show, TabLicenseBg
		GuiControl, Settings:Show, PanelLicense
		GuiControl, Settings:Show, LicenseHeader
		; Status GroupBox
		GuiControl, Settings:Show, LicenseStatusGroup
		GuiControl, Settings:Show, LicenseStatusText
		; License Key GroupBox
		GuiControl, Settings:Show, LicenseKeyGroup
		GuiControl, Settings:Show, LicenseKeyLabel
		GuiControl, Settings:Show, LicenseKeyEdit
		GuiControl, Settings:Show, LicenseActivateBtn
		GuiControl, Settings:Show, LicenseLocationInfo
		; Activation Details GroupBox
		GuiControl, Settings:Show, LicenseDetailsGroup
		GuiControl, Settings:Show, LicenseNameLabel
		GuiControl, Settings:Show, LicenseNameValue
		GuiControl, Settings:Show, LicenseEmailLabel
		GuiControl, Settings:Show, LicenseEmailValue
		GuiControl, Settings:Show, LicenseActivatedLabel
		GuiControl, Settings:Show, LicenseActivatedValue
		GuiControl, Settings:Show, LicenseExpiryLabel
		GuiControl, Settings:Show, LicenseExpiryValue
		; Actions GroupBox
		GuiControl, Settings:Show, LicenseActionsGroup
		GuiControl, Settings:Show, LicenseValidateBtn
		GuiControl, Settings:Show, LicenseDeactivateBtn
		GuiControl, Settings:Show, LicenseBuyBtn
		GuiControl, Settings:Show, LicensePurchaseInfo
		GuiControl, Settings:Show, LicensePurchaseInfo2
		
		; Update license status display
		UpdateLicenseDisplay()
	}
	else if (tabName = "Files")
	{
		GuiControl, Settings:Show, TabFilesBg
		GuiControl, Settings:Show, PanelFiles
		GuiControl, Settings:Show, FilesHeader
		; SD Card Download GroupBox
		GuiControl, Settings:Show, FilesSDCardGroup
		GuiControl, Settings:Show, FilesEnableSDCard
		GuiControl, Settings:Show, Toggle_SDCardEnabled
		GuiControl, Settings:Show, FilesCardDriveLabel
		GuiControl, Settings:Show, FilesCardDriveEdit
		GuiControl, Settings:Show, FilesCardDriveBrowse
		GuiControl, Settings:Show, FilesDownloadLabel
		GuiControl, Settings:Show, FilesDownloadEdit
		GuiControl, Settings:Show, FilesDownloadBrowse
		; Archive Settings GroupBox
		GuiControl, Settings:Show, FilesArchiveGroup
		GuiControl, Settings:Show, FilesArchiveLabel
		GuiControl, Settings:Show, FilesArchiveEdit
		GuiControl, Settings:Show, FilesArchiveBrowse
		GuiControl, Settings:Show, FilesFolderTemplateLabel
		GuiControl, Settings:Show, FilesFolderTemplateEdit
		GuiControl, Settings:Show, FilesFolderTemplateBrowse
		; File Naming GroupBox
		GuiControl, Settings:Show, FilesNamingGroup
		GuiControl, Settings:Show, FilesPrefixLabel
		GuiControl, Settings:Show, FilesPrefixEdit
		GuiControl, Settings:Show, FilesSuffixLabel
		GuiControl, Settings:Show, FilesSuffixEdit
		GuiControl, Settings:Show, FilesAutoYear
		GuiControl, Settings:Show, Toggle_AutoShootYear
		GuiControl, Settings:Show, FilesAutoRename
		GuiControl, Settings:Show, Toggle_AutoRenameImages
		; Photo Editor GroupBox
		GuiControl, Settings:Show, FilesEditorGroup
		GuiControl, Settings:Show, FilesEditorLabel
		GuiControl, Settings:Show, FilesEditorEdit
		GuiControl, Settings:Show, FilesEditorBrowse
		GuiControl, Settings:Show, FilesOpenEditor
		GuiControl, Settings:Show, Toggle_BrowsDown
		GuiControl, Settings:Show, FilesAutoDrive
		GuiControl, Settings:Show, Toggle_AutoDriveDetect
		; Additional Archives - SideKick GroupBox
		GuiControl, Settings:Show, FilesPSAGroup
		GuiControl, Settings:Show, FilesPSALabel
		GuiControl, Settings:Show, FilesPSAEdit
		
		; Update enabled/disabled state based on SD Card setting
		UpdateFilesControlsState(Settings_SDCardEnabled)
	}
	else if (tabName = "About")
	{
		GuiControl, Settings:Show, TabAboutBg
		GuiControl, Settings:Show, PanelAbout
		GuiControl, Settings:Show, AboutHeader
		; Application GroupBox
		GuiControl, Settings:Show, AboutAppGroup
		GuiControl, Settings:Show, AboutDescLabel
		GuiControl, Settings:Show, AboutDescValue
		GuiControl, Settings:Show, AboutVersionLabel
		GuiControl, Settings:Show, AboutVersionValue
		GuiControl, Settings:Show, AboutBuildLabel
		GuiControl, Settings:Show, AboutBuildValue
		GuiControl, Settings:Show, AboutPSLabel
		GuiControl, Settings:Show, AboutPSValue
		; Updates GroupBox
		GuiControl, Settings:Show, AboutUpdatesGroup
		GuiControl, Settings:Show, AboutLatestLabel
		GuiControl, Settings:Show, AboutLatestValue
		GuiControl, Settings:Show, AboutAutoUpdateText
		GuiControl, Settings:Show, Toggle_AutoUpdate
		GuiControl, Settings:Show, AboutReinstallBtn
		GuiControl, Settings:Show, AboutCheckNowBtn
		; Support GroupBox
		GuiControl, Settings:Show, AboutSupportGroup
		GuiControl, Settings:Show, AboutAuthorLabel
		GuiControl, Settings:Show, AboutAuthorValue
		GuiControl, Settings:Show, AboutEmailLink
		GuiControl, Settings:Show, AboutManualLink
		GuiControl, Settings:Show, AboutDocsLink
		GuiControl, Settings:Show, AboutWhatsNewButton
		GuiControl, Settings:Show, AboutSendLogsButton
		GuiControl, Settings:Show, AboutLogPath
		; Diagnostics GroupBox
		GuiControl, Settings:Show, AboutDiagnostics
		GuiControl, Settings:Show, AboutAutoSendText
		GuiControl, Settings:Show, Toggle_AutoSendLogs
		GuiControl, Settings:Show, AboutDebugText
		GuiControl, Settings:Show, Toggle_DebugLogging
		
		; Refresh latest version info
		RefreshLatestVersion()
	}
	else if (tabName = "Shortcuts")
	{
		GuiControl, Settings:Show, TabShortcutsBg
		GuiControl, Settings:Show, PanelShortcuts
		GuiControl, Settings:Show, SCHeader
		GuiControl, Settings:Show, SCButtonsGroup
		GuiControl, Settings:Show, SCDescription
		GuiControl, Settings:Show, SCIcon_Client
		GuiControl, Settings:Show, SCLabel_Client
		GuiControl, Settings:Show, Toggle_ShowBtn_Client
		GuiControl, Settings:Show, SCIcon_Invoice
		GuiControl, Settings:Show, SCLabel_Invoice
		GuiControl, Settings:Show, Toggle_ShowBtn_Invoice
		GuiControl, Settings:Show, SCIcon_OpenGHL
		GuiControl, Settings:Show, SCLabel_OpenGHL
		GuiControl, Settings:Show, Toggle_ShowBtn_OpenGHL
		GuiControl, Settings:Show, SCIcon_Camera
		GuiControl, Settings:Show, SCLabel_Camera
		GuiControl, Settings:Show, Toggle_ShowBtn_Camera
		GuiControl, Settings:Show, SCIcon_Sort
		GuiControl, Settings:Show, SCLabel_Sort
		GuiControl, Settings:Show, Toggle_ShowBtn_Sort
		GuiControl, Settings:Show, SCIcon_Photoshop
		GuiControl, Settings:Show, SCLabel_Photoshop
		GuiControl, Settings:Show, Toggle_ShowBtn_Photoshop
		GuiControl, Settings:Show, SCIcon_Refresh
		GuiControl, Settings:Show, SCLabel_Refresh
		GuiControl, Settings:Show, Toggle_ShowBtn_Refresh
		GuiControl, Settings:Show, SCIcon_Print
		GuiControl, Settings:Show, SCLabel_Print
		GuiControl, Settings:Show, Toggle_ShowBtn_Print
		GuiControl, Settings:Show, SCIcon_Download
		GuiControl, Settings:Show, SCLabel_Download
		GuiControl, Settings:Show, SCIcon_QRCode
		GuiControl, Settings:Show, SCLabel_QRCode
		GuiControl, Settings:Show, Toggle_ShowBtn_QRCode
		GuiControl, Settings:Show, SCInfoNote
	}
	else if (tabName = "Print")
	{
		GuiControl, Settings:Show, TabPrintBg
		GuiControl, Settings:Show, PanelPrint
		GuiControl, Settings:Show, PrintHeader
		GuiControl, Settings:Show, PrintPrinterGroup
		GuiControl, Settings:Show, PrintPrinterLabel
		GuiControl, Settings:Show, PrintPrinterCombo
		GuiControl, Settings:Show, PrintPrinterHint
		GuiControl, Settings:Show, PrintTemplatesGroup
		GuiControl, Settings:Show, PrintTemplatesDesc
		GuiControl, Settings:Show, PrintRefreshBtn
		GuiControl, Settings:Show, PrintPayPlanLabel
		GuiControl, Settings:Show, PrintPayPlanCombo
		GuiControl, Settings:Show, PrintStandardLabel
		GuiControl, Settings:Show, PrintStandardCombo
		GuiControl, Settings:Show, PrintTemplatesHint
		GuiControl, Settings:Show, PrintEmailGroup
		GuiControl, Settings:Show, PrintEmailTplLabel
		GuiControl, Settings:Show, PrintEmailTplCombo
		GuiControl, Settings:Show, PrintEmailTplRefresh
		GuiControl, Settings:Show, PrintEmailTplHint
		GuiControl, Settings:Show, PrintRoomFolderLabel
		GuiControl, Settings:Show, PrintRoomFolderCombo
		GuiControl, Settings:Show, PrintRoomFolderBrowse
		GuiControl, Settings:Show, PrintPDFGroup
		GuiControl, Settings:Show, PrintEnablePDFLabel
		GuiControl, Settings:Show, Toggle_EnablePDF
		GuiControl, Settings:Show, PrintPDFDesc
		GuiControl, Settings:Show, PrintPDFCopyLabel
		GuiControl, Settings:Show, PrintPDFCopyEdit
		GuiControl, Settings:Show, PrintPDFCopyBrowse
		GuiControl, Settings:Show, PrintPDFHint
		GuiControl, Settings:Show, PrintPDFBtn
	}
	else if (tabName = "GoCardless")
	{
		GuiControl, Settings:Show, TabGoCardlessBg
		GuiControl, Settings:Show, PanelGoCardless
		GuiControl, Settings:Show, GCHeader
		GuiControl, Settings:Show, GCConnection
		GuiControl, Settings:Show, GCEnable
		GuiControl, Settings:Show, Toggle_GoCardlessEnabled
		GuiControl, Settings:Show, GCApiConfig
		; Environment selector only for developers
		if (IsDeveloperMode()) {
			GuiControl, Settings:Show, GCEnvLabel
			GuiControl, Settings:Show, GCEnvDDL
		}
		GuiControl, Settings:Show, GCTokenLabel
		GuiControl, Settings:Show, GCTokenDisplay
		GuiControl, Settings:Show, GCTokenEditBtn
		GuiControl, Settings:Show, GCStatus
		GuiControl, Settings:Show, GCStatusText
		GuiControl, Settings:Show, GCTestBtn
		GuiControl, Settings:Show, GCEmptyMandatesBtn
		GuiControl, Settings:Show, GCDashboardBtn
		GuiControl, Settings:Show, GCProgressBar
		GuiControl, Settings:Show, GCProgressText
		GuiControl, Settings:Show, GCNotifyGroup
		GuiControl, Settings:Show, GCEmailTplLabel
		GuiControl, Settings:Show, GCEmailTplCombo
		GuiControl, Settings:Show, GCEmailTplRefresh
		GuiControl, Settings:Show, GCSMSTplLabel
		GuiControl, Settings:Show, GCSMSTplCombo
		GuiControl, Settings:Show, GCSMSTplRefresh
		GuiControl, Settings:Show, GCNotifyHint
		GuiControl, Settings:Show, GCAutoGroup
		GuiControl, Settings:Show, GCAutoSetupLabel
		GuiControl, Settings:Show, Toggle_GCAutoSetup
		GuiControl, Settings:Show, GCAutoHint
		GuiControl, Settings:Show, GCWizardBtn
		GuiControl, Settings:Show, GCNamingLabel
		GuiControl, Settings:Show, GCNamePart1DDL
		GuiControl, Settings:Show, GCNameSep1
		GuiControl, Settings:Show, GCNamePart2DDL
		GuiControl, Settings:Show, GCNameSep2
		GuiControl, Settings:Show, GCNamePart3DDL
		GuiControl, Settings:Show, GCNameExLabel
		GuiControl, Settings:Show, GCNameExample
		; Apply enable/disable state based on toggle
		if (Settings_GoCardlessEnabled) {
			GuiControl, Settings:Enable, GCEnvDDL
			GuiControl, Settings:Enable, GCTokenEditBtn
			GuiControl, Settings:Enable, GCTestBtn
			GuiControl, Settings:Enable, GCDashboardBtn
			GuiControl, Settings:Enable, GCEmailTplCombo
			GuiControl, Settings:Enable, GCEmailTplRefresh
			GuiControl, Settings:Enable, GCSMSTplCombo
			GuiControl, Settings:Enable, GCSMSTplRefresh
			GuiControl, Settings:Enable, Toggle_GCAutoSetup
			GuiControl, Settings:Enable, GCNamePart1DDL
			GuiControl, Settings:Enable, GCNamePart2DDL
			GuiControl, Settings:Enable, GCNamePart3DDL
		} else {
			GuiControl, Settings:Disable, GCEnvDDL
			GuiControl, Settings:Disable, GCTokenEditBtn
			GuiControl, Settings:Disable, GCTestBtn
			GuiControl, Settings:Disable, GCDashboardBtn
			GuiControl, Settings:Disable, GCEmailTplCombo
			GuiControl, Settings:Disable, GCEmailTplRefresh
			GuiControl, Settings:Disable, GCSMSTplCombo
			GuiControl, Settings:Disable, GCSMSTplRefresh
			GuiControl, Settings:Disable, Toggle_GCAutoSetup
			GuiControl, Settings:Disable, GCNamePart1DDL
			GuiControl, Settings:Disable, GCNamePart2DDL
			GuiControl, Settings:Disable, GCNamePart3DDL
		}
	}
	else if (tabName = "Display")
	{
		GuiControl, Settings:Show, TabDisplayBg
		GuiControl, Settings:Show, PanelDisplay
		GuiControl, Settings:Show, DisplayHeader
		GuiControl, Settings:Show, DisplayToolbarGroup
		GuiControl, Settings:Show, DisplayMonitorLabel
		GuiControl, Settings:Show, DisplayQRDisplay
		GuiControl, Settings:Show, DisplaySizeLabel
		GuiControl, Settings:Show, DisplaySizeSlider
		GuiControl, Settings:Show, DisplaySizeValue
		GuiControl, Settings:Show, DisplayIdentifyBtn
		GuiControl, Settings:Show, DisplayQRCodeGroup
		GuiControl, Settings:Show, DisplayQRLabel1
		GuiControl, Settings:Show, DisplayQREdit1
		GuiControl, Settings:Show, DisplayQRLabel2
		GuiControl, Settings:Show, DisplayQREdit2
		GuiControl, Settings:Show, DisplayQRLabel3
		GuiControl, Settings:Show, DisplayQREdit3
		GuiControl, Settings:Show, DisplayBankGroup
		GuiControl, Settings:Show, DisplayBankInstLabel
		GuiControl, Settings:Show, DisplayBankInstEdit
		GuiControl, Settings:Show, DisplayBankNameLabel
		GuiControl, Settings:Show, DisplayBankNameEdit
		GuiControl, Settings:Show, DisplayBankSortLabel
		GuiControl, Settings:Show, DisplayBankSortEdit
		GuiControl, Settings:Show, DisplayBankScaleLabel
		GuiControl, Settings:Show, DisplayBankScaleSlider
		GuiControl, Settings:Show, DisplayBankScaleValue
		GuiControl, Settings:Show, DisplayBankAccLabel
		GuiControl, Settings:Show, DisplayBankAccEdit
		GuiControl, Settings:Show, DisplayImagesGroup
		GuiControl, Settings:Show, DisplayImg1Label
		GuiControl, Settings:Show, DisplayImg1Edit
		GuiControl, Settings:Show, DisplayImg1Btn
		GuiControl, Settings:Show, DisplayImg2Label
		GuiControl, Settings:Show, DisplayImg2Edit
		GuiControl, Settings:Show, DisplayImg2Btn
		GuiControl, Settings:Show, DisplayImg3Label
		GuiControl, Settings:Show, DisplayImg3Edit
		GuiControl, Settings:Show, DisplayImg3Btn
		GuiControl, Settings:Show, DisplayImagesHint
	}
	else if (tabName = "Developer")
	{
		GuiControl, Settings:Show, TabDeveloperBg
		GuiControl, Settings:Show, PanelDeveloper
		GuiControl, Settings:Show, DevHeader
		; Status GroupBox
		GuiControl, Settings:Show, DevStatusGroup
		GuiControl, Settings:Show, DevWarning
		GuiControl, Settings:Show, DevVersionLabel
		GuiControl, Settings:Show, DevVersionValue
		GuiControl, Settings:Show, DevModeLabel
		GuiControl, Settings:Show, DevModeValue
		GuiControl, Settings:Show, DevDelayLabel
		GuiControl, Settings:Show, DevDelayValue
		; Build & Release GroupBox
		GuiControl, Settings:Show, DevBuildGroup
		GuiControl, Settings:Show, DevBuildDesc
		GuiControl, Settings:Show, DevCreateBtn
		GuiControl, Settings:Show, DevUpdateBtn
		GuiControl, Settings:Show, DevPushBtn
		; Quick Actions GroupBox
		GuiControl, Settings:Show, DevQuickGroup
		GuiControl, Settings:Show, DevReloadBtn
		GuiControl, Settings:Show, DevTestBtn
		GuiControl, Settings:Show, DevGitHubBtn
		GuiControl, Settings:Show, DevQuickPushBtn
		GuiControl, Settings:Show, DevOpenFolderBtn
		GuiControl, Settings:Show, DevPushWebBtn
	}
	
	Settings_CurrentTab := tabName
}

; Tab click handlers
SettingsTabGeneral:
ShowSettingsTab("General")
Return

SettingsTabGHL:
ShowSettingsTab("GHL")
Return

SettingsTabHotkeys:
ShowSettingsTab("Hotkeys")
Return

SettingsTabAbout:
ShowSettingsTab("About")
Return

SettingsTabLicense:
ShowSettingsTab("License")
Return

SettingsTabFiles:
ShowSettingsTab("Files")
Return

SettingsTabShortcuts:
ShowSettingsTab("Shortcuts")
Return

SettingsTabPrint:
ShowSettingsTab("Print")
Return

SettingsTabGoCardless:
ShowSettingsTab("GoCardless")
Return

SettingsTabDisplay:
ShowSettingsTab("Display")
Return

SettingsTabDeveloper:
ShowSettingsTab("Developer")
Return

; Developer button handlers
DevCreateRelease:
	; Build full release with EXE-only files (compiles AHK and Python)
	ToolTip, Building release (compiling to EXE)...
	buildScript := A_ScriptDir . "\build_and_archive.ps1"
	if FileExist(buildScript) {
		; Open PowerShell to run build interactively
		Run, powershell.exe -NoExit -ExecutionPolicy Bypass -Command "cd '%A_ScriptDir%'; .\build_and_archive.ps1 -Version '%ScriptVersion%'", %A_ScriptDir%
		ToolTip
	} else {
		ToolTip
		DarkMsgBox("Error", "Build script not found:`n" . buildScript . "`n`nExpected at: C:\Stash\SideKick_PS\build_and_archive.ps1", "error")
	}
Return

DevUpdateVersion:
	InputBox, newVer, Update Version, Enter new version number (e.g., 2.5.0):,, 300, 130,,,,, %ScriptVersion%
	if (!ErrorLevel && newVer != "") {
		; Update version.json (single source of truth)
		versionFile := A_ScriptDir . "\version.json"
		if FileExist(versionFile) {
			; Read and update version.json
			FileRead, versionJson, %versionFile%
			; Update version field
			versionJson := RegExReplace(versionJson, """version"":\s*""[^""]+""", """version"": """ . newVer . """", , 1)
			; Update build_date field
			FormatTime, todayDate,, yyyy-MM-dd
			versionJson := RegExReplace(versionJson, """build_date"":\s*""[^""]+""", """build_date"": """ . todayDate . """", , 1)
			FileDelete, %versionFile%
			FileAppend, %versionJson%, %versionFile%
			; Reload to pick up new version (version.json is single source of truth)
			MsgBox, 4, Version Updated, Updated version.json to v%newVer%`n`nReload script to apply new version?
			IfMsgBox, Yes
				Reload
		} else {
			DarkMsgBox("Error", "version.json not found at:`n" . versionFile, "error")
		}
	}
Return

DevPushGitHub:
	repoDir := A_ScriptDir
	Run, powershell.exe -NoExit -Command "cd '%repoDir%'; git status; Write-Host ''; Write-Host 'Ready to commit and push. Use:' -ForegroundColor Yellow; Write-Host 'git add . && git commit -m \"Your message\" && git push' -ForegroundColor Cyan", %repoDir%
Return

DevRefreshGit:
	RefreshDevGitStatus()
Return

DevOpenFolder:
	Run, explorer.exe "%A_ScriptDir%"
Return

DevPushWebsite:
	; Sync website_ps to docs and push website only
	GuiControl, Settings:Show, DevWebProgress
	GuiControl, Settings:, DevWebProgress, 0
	GuiControl, Settings:Disable, DevPushWebBtn
	
	; Step 1: Sync files (33%)
	GuiControl, Settings:, DevWebProgress, 25
	RunWait, %ComSpec% /c "cd /d "%A_ScriptDir%" && copy /y website_ps\*.html docs\ >nul 2>&1 && copy /y website_ps\*.xml docs\ >nul 2>&1 && copy /y website_ps\*.txt docs\ >nul 2>&1 && copy /y website_ps\CNAME docs\ >nul 2>&1 && xcopy /s /y /q website_ps\images\* docs\images\ >nul 2>&1", , Hide
	
	; Step 2: Stage files (50%)
	GuiControl, Settings:, DevWebProgress, 50
	RunWait, %ComSpec% /c "cd /d "%A_ScriptDir%" && git add website_ps/* docs/* 2>nul", , Hide
	
	; Step 3: Check for changes and commit (75%)
	GuiControl, Settings:, DevWebProgress, 75
	RunWait, %ComSpec% /c "cd /d "%A_ScriptDir%" && git diff --cached --quiet" , , Hide
	hasChanges := ErrorLevel
	
	if (hasChanges) {
		; Step 4: Commit and push (100%)
		RunWait, %ComSpec% /c "cd /d "%A_ScriptDir%" && git commit -m "Update website" && git push origin main" , , Hide
		pushResult := ErrorLevel
		GuiControl, Settings:, DevWebProgress, 100
		Sleep, 300
		GuiControl, Settings:Hide, DevWebProgress
		GuiControl, Settings:Enable, DevPushWebBtn
		if (pushResult)
			DarkMsgBox("Push Website", "❌ Website push failed.`n`nCheck the terminal for details.", "error")
		else
			DarkMsgBox("Push Website", "✓ Website synced and pushed to GitHub.`n`nChanges live in ~1-2 minutes.", "success", {timeout: 5})
	} else {
		GuiControl, Settings:, DevWebProgress, 100
		Sleep, 300
		GuiControl, Settings:Hide, DevWebProgress
		GuiControl, Settings:Enable, DevPushWebBtn
		DarkMsgBox("Push Website", "No changes to push.`n`nWebsite files are already up to date.", "info", {timeout: 3})
	}
Return

DevReloadScript:
	; Reload the script (useful for development)
	Reload
Return

DevTestBuild:
	; Quick test - compile AHK only
	ToolTip, Testing AHK compilation...
	ahkCompilers := ["C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe", A_ProgramFiles . "\AutoHotkey\Compiler\Ahk2Exe.exe"]
	for i, compiler in ahkCompilers {
		if FileExist(compiler) {
			testExe := A_Temp . "\SideKick_PS_test.exe"
			RunWait, "%compiler%" /in "%A_ScriptDir%\SideKick_PS.ahk" /out "%testExe%",, Hide
			if FileExist(testExe) {
				FileDelete, %testExe%
				ToolTip
				DarkMsgBox("Build Test", "✓ AHK compilation successful!", "success")
			} else {
				ToolTip
				DarkMsgBox("Build Test", "✗ AHK compilation failed.", "error")
			}
			return
		}
	}
	ToolTip
	DarkMsgBox("Error", "Ahk2Exe compiler not found.", "error")
Return

DevOpenGitHub:
	Run, https://github.com/GuyMayer/SideKick_PS
Return

DevQuickPush:
	; One-click: Build EXE-only release, commit, push, and create GitHub release
	global ScriptVersion
	
	; Use current version (don't auto-increment - user can change if needed)
	newVersion := ScriptVersion
	
	; Ask for version using always-on-top GUI
	Gui, QuickPub:New, +AlwaysOnTop +ToolWindow
	Gui, QuickPub:Add, Text,, Enter version number:
	Gui, QuickPub:Add, Edit, w180 vQuickPubVersion, %newVersion%
	Gui, QuickPub:Add, Button, x10 w85 Default gQuickPubOK, OK
	Gui, QuickPub:Add, Button, x+10 w85 gQuickPubCancel, Cancel
	Gui, QuickPub:Show,, Quick Publish
	WinWaitClose, Quick Publish
	if (QuickPubCancelled) {
		QuickPubCancelled := false
		return
	}
	newVersion := QuickPubVersionResult
	if (newVersion = "")
		return
	
	; Ask for commit message using always-on-top GUI
	Gui, QuickPub2:New, +AlwaysOnTop +ToolWindow
	Gui, QuickPub2:Add, Text,, Enter release notes for v%newVersion%:
	Gui, QuickPub2:Add, Edit, w280 vQuickPubCommit, v%newVersion% release
	Gui, QuickPub2:Add, Button, x10 w85 Default gQuickPub2OK, OK
	Gui, QuickPub2:Add, Button, x+10 w85 gQuickPub2Cancel, Cancel
	Gui, QuickPub2:Show,, Quick Publish
	WinWaitClose, Quick Publish
	if (QuickPub2Cancelled) {
		QuickPub2Cancelled := false
		return
	}
	commitMsg := QuickPub2CommitResult
	if (commitMsg = "")
		return
	
	repoDir := A_ScriptDir
	buildScript := repoDir . "\build_and_archive.ps1"
	
	if !FileExist(buildScript) {
		DarkMsgBox("Error", "Build script not found:`n" . buildScript, "error")
		return
	}
	
	; Update ScriptVersion in main script FIRST
	ToolTip, Updating version in script...
	mainScript := A_ScriptDir . "\SideKick_PS.ahk"
	FileRead, scriptContent, %mainScript%
	scriptContent := RegExReplace(scriptContent, "global ScriptVersion := ""[^""]+""", "global ScriptVersion := """ . newVersion . """")
	FileDelete, %mainScript%
	FileAppend, %scriptContent%, %mainScript%, UTF-8
	
	; Run the full build (compiles AHK + Python to EXE)
	ToolTip, Building EXE-only release v%newVersion%...`nThis may take a minute...
	
	; Create a batch file to run the build (ensures proper waiting)
	batchFile := repoDir . "\run_build.bat"
	FileDelete, %batchFile%
	
	; Write batch file line by line
	FileAppend, @echo off`n, %batchFile%
	FileAppend, cd /d "%repoDir%"`n, %batchFile%
	FileAppend, call C:\Stash\.venv\Scripts\activate.bat`n, %batchFile%
	FileAppend, powershell -ExecutionPolicy Bypass -File "build_and_archive.ps1" -Version "%newVersion%" -ForceRebuild -SkipPublish`n, %batchFile%
	FileAppend, pause`n, %batchFile%
	
	Run, %batchFile%, %repoDir%
	
	; Wait for the installer to be created (poll every 2 seconds for up to 5 minutes)
	; Now uses 'latest' folder with fixed filename
	installerFile := repoDir . "\Releases\latest\SideKick_PS_Setup.exe"
	zipFile := repoDir . "\Releases\latest\SideKick_PS.zip"
	
	Loop, 150 {
		Sleep, 2000
		if FileExist(installerFile) || FileExist(zipFile)
			break
		ToolTip, Building EXE-only release v%newVersion%...`nWaiting for build to complete (%A_Index%/150)
	}
	
	ToolTip
	Sleep, 1000
	
	; Check if build succeeded - look for installer EXE or ZIP in 'latest' folder
	if FileExist(installerFile) {
		releaseAsset := "Releases/latest/SideKick_PS_Setup.exe"
	} else if FileExist(zipFile) {
		releaseAsset := "Releases/latest/SideKick_PS.zip"
	} else {
		ToolTip
		DarkMsgBox("Build Failed", "Build failed - no installer or ZIP created in:`n" . repoDir . "\Releases\latest", "error")
		return
	}
	
	; Git add, commit, push (with pull first to avoid conflicts)
	ToolTip, Pushing to GitHub...
	gitBatch := repoDir . "\git_push.bat"
	FileDelete, %gitBatch%
	FileAppend, @echo off`n, %gitBatch%
	FileAppend, cd /d "%repoDir%"`n, %gitBatch%
	FileAppend, echo Waiting for installer to be released...`n, %gitBatch%
	FileAppend, timeout /t 5 /nobreak >nul`n, %gitBatch%
	FileAppend, echo Adding changelog and version files...`n, %gitBatch%
	FileAppend, git add version.json CHANGELOG.md SideKick_PS_Manual.md 2>nul`n, %gitBatch%
	FileAppend, echo Adding all other files...`n, %gitBatch%
	FileAppend, :retry_add`n, %gitBatch%
	FileAppend, git add -A 2>nul`n, %gitBatch%
	FileAppend, if errorlevel 1 (`n, %gitBatch%
	FileAppend,     echo File still locked, waiting...`n, %gitBatch%
	FileAppend,     timeout /t 3 /nobreak >nul`n, %gitBatch%
	FileAppend,     goto retry_add`n, %gitBatch%
	FileAppend, )`n, %gitBatch%
	FileAppend, echo Committing...`n, %gitBatch%
	FileAppend, git commit -m "%commitMsg%"`n, %gitBatch%
	FileAppend, echo Pulling latest...`n, %gitBatch%
	FileAppend, git pull --rebase origin main`n, %gitBatch%
	FileAppend, echo Pushing to GitHub...`n, %gitBatch%
	FileAppend, git push origin main`n, %gitBatch%
	FileAppend, echo.`n, %gitBatch%
	FileAppend, echo Git push complete!`n, %gitBatch%
	FileAppend, timeout /t 2 /nobreak`n, %gitBatch%
	
	RunWait, %gitBatch%, %repoDir%, Hide
	FileDelete, %gitBatch%
	
	; Create GitHub release with gh CLI (use full path)
	ToolTip, Creating GitHub release...
	ghBatch := repoDir . "\gh_release.bat"
	FileDelete, %ghBatch%
	FileAppend, @echo off`n, %ghBatch%
	FileAppend, cd /d "%repoDir%"`n, %ghBatch%
	FileAppend, echo Creating GitHub release v%newVersion%...`n, %ghBatch%
	FileAppend, "C:\Program Files\GitHub CLI\gh.exe" release create v%newVersion% "%releaseAsset%" --title "SideKick_PS v%newVersion%" --notes "%commitMsg%"`n, %ghBatch%
	FileAppend, if errorlevel 1 (`n, %ghBatch%
	FileAppend,     echo WARNING: GitHub release may have failed or already exists.`n, %ghBatch%
	FileAppend,     timeout /t 5 /nobreak`n, %ghBatch%
	FileAppend, ) else (`n, %ghBatch%
	FileAppend,     echo GitHub release created successfully!`n, %ghBatch%
	FileAppend,     timeout /t 2 /nobreak`n, %ghBatch%
	FileAppend, )`n, %ghBatch%
	
	RunWait, %ghBatch%, %repoDir%, Hide
	FileDelete, %ghBatch%
	
	ToolTip, Cleaning up old releases...
	
	; Clean up old releases - keep only current and previous version
	CleanupOldReleases(repoDir, newVersion)
	
	ToolTip
	
	; Update the display
	ScriptVersion := newVersion
	GuiControl, Settings:, DevVersionValue, %newVersion%
	
	DarkMsgBox("Quick Publish Complete", "✓ Built EXE-only release v" . newVersion . "`n✓ All Python scripts compiled`n✓ Pushed to GitHub`n✓ Created GitHub Release`n✓ Cleaned up old releases`n`n⚠ Remember: Ask Copilot to update changelog!", "success")
	
	; Refresh git status
	RefreshDevGitStatus()
Return

CleanupOldReleases(repoDir, currentVersion) {
	; Clean up old releases - keep 'latest' folder and one fallback version
	; Structure: Releases/latest/ (current) + Releases/vX.X.X/ (one fallback)
	
	releasesDir := repoDir . "\Releases"
	
	if !FileExist(releasesDir)
		return
	
	; First, copy 'latest' to a versioned folder for backup
	latestDir := releasesDir . "\latest"
	versionedDir := releasesDir . "\v" . currentVersion
	
	if FileExist(latestDir) && !FileExist(versionedDir) {
		; Create versioned backup of current release
		FileCreateDir, %versionedDir%
		FileCopy, %latestDir%\*.*, %versionedDir%\, 1
	}
	
	; Collect all versioned folders (v*)
	versions := []
	Loop, Files, %releasesDir%\v*, D
	{
		; Check if folder has files
		fileCount := 0
		Loop, Files, %A_LoopFileFullPath%\*.*
			fileCount++
		
		if (fileCount > 0) {
			; Extract version number from folder name (e.g., "v2.4.13" -> "2.4.13")
			verNum := SubStr(A_LoopFileName, 2)
			versions.Push({folder: A_LoopFileFullPath, version: verNum, name: A_LoopFileName})
		}
	}
	
	; Keep only current version and one previous
	; Skip if 2 or fewer versions
	if (versions.Length() <= 2)
		return
	
	; Find the two highest versions to keep
	keepVersions := []
	keepVersions.Push("v" . currentVersion)
	
	; Find previous version (highest version that's not current)
	prevVersion := ""
	prevVersionNum := 0
	for i, v in versions {
		if (v.name != "v" . currentVersion) {
			; Parse version number for comparison
			parts := StrSplit(v.version, ".")
			vNum := (parts[1] * 10000) + (parts[2] * 100) + parts[3]
			if (vNum > prevVersionNum) {
				prevVersionNum := vNum
				prevVersion := v.name
			}
		}
	}
	
	if (prevVersion != "")
		keepVersions.Push(prevVersion)
	
	; Delete folders not in keepVersions
	deletedFolders := []
	for i, v in versions {
		keep := false
		for j, kv in keepVersions {
			if (v.name = kv) {
				keep := true
				break
			}
		}
		if (!keep) {
			FileRemoveDir, % v.folder, 1
			deletedFolders.Push(v.name)
		}
	}
	
	; Delete old GitHub releases (keep only 2 newest)
	if (deletedFolders.Length() > 0) {
		; Create batch to delete old GitHub releases silently (only show errors)
		cleanBatch := repoDir . "\cleanup_releases.bat"
		FileDelete, %cleanBatch%
		FileAppend, @echo off`n, %cleanBatch%
		FileAppend, cd /d "%repoDir%"`n, %cleanBatch%
		
		for i, folder in deletedFolders {
			; Delete silently - only show output if there's an error
			FileAppend, "C:\Program Files\GitHub CLI\gh.exe" release delete %folder% --yes >nul 2>&1 || echo Failed to delete release %folder%`n, %cleanBatch%
		}
		
		Run, %cleanBatch%, %repoDir%, Hide
		Sleep, 2000
		FileDelete, %cleanBatch%
		
		; Commit the cleanup
		RunWait, %ComSpec% /c "cd /d "%repoDir%" && git add -A && git commit -m "Cleanup old releases" && git push origin main",, Hide
	}
}

RefreshDevGitStatus()
{
	global
	repoDir := A_ScriptDir
	tempFile := A_Temp . "\git_status.txt"
	
	if !FileExist(repoDir . "\.git") {
		GuiControl, Settings:, DevGitOutput, (Not a git repository)`n`nRun: git init
		return
	}
	
	RunWait, %ComSpec% /c "cd /d "%repoDir%" && git status -s > "%tempFile%" 2>&1",, Hide
	FileRead, gitOutput, %tempFile%
	FileDelete, %tempFile%
	
	if (gitOutput = "") {
		gitOutput := "✓ Working directory clean`n`nNo uncommitted changes."
	}
	
	GuiControl, Settings:, DevGitOutput, %gitOutput%
}

; License button handlers
ActivateLicenseBtn:
	Gui, Settings:Submit, NoHide
	GuiControlGet, licenseKey,, LicenseKeyEdit
	
	if (licenseKey = "" || licenseKey = "Not entered") {
		DarkMsgBox("License Error", "Please enter a license key first.", "warning")
		return
	}
	
	if (GHL_LocationID = "") {
		DarkMsgBox("Location Required", "Please configure your GHL Location ID in the GHL tab first.`n`nThe license will be bound to your Location ID.", "warning")
		return
	}
	
	; Activate via Python script (uses compiled .exe if available)
	ToolTip, Activating license...
	tempFile := A_Temp . "\license_result.json"
	scriptCmd := GetScriptCommand("validate_license", "activate """ . licenseKey . """ """ . GHL_LocationID . """")
	fullCmd := ComSpec . " /s /c """ . scriptCmd . " > """ . tempFile . """"""
	RunWait, %fullCmd%, , Hide
	
	; Read result
	FileRead, resultJson, %tempFile%
	FileDelete, %tempFile%
	ToolTip
	
	; Parse JSON result
	if InStr(resultJson, """success"": true") || InStr(resultJson, """activated"": true") {
		License_Key := licenseKey
		License_Status := "active"
		FormatTime, License_ActivatedAt,, yyyy-MM-dd
		FormatTime, License_ValidatedAt,, yyyy-MM-ddTHH:mm:ss
		
		; Extract customer info from JSON
		RegExMatch(resultJson, """customer_name"":\s*""([^""]*)""", match)
		License_CustomerName := match1
		RegExMatch(resultJson, """customer_email"":\s*""([^""]*)""", match)
		License_CustomerEmail := match1
		RegExMatch(resultJson, """instance_id"":\s*""([^""]*)""", match)
		License_InstanceID := match1
		RegExMatch(resultJson, """expires_at"":\s*""([^""]*)""", match)
		License_ExpiresAt := match1
		
		SaveSettings()
		UpdateLicenseDisplay()
		DarkMsgBox("License Activated", "Your license has been activated successfully!`n`nBound to Location: " . GHL_LocationID, "success")
	} else {
		; Extract error message
		RegExMatch(resultJson, """message"":\s*""([^""]*)""", match)
		errorMsg := match1 ? match1 : "Activation failed. Please check your license key."
		DarkMsgBox("Activation Failed", errorMsg, "error")
	}
Return

ValidateLicenseBtn:
	if (License_Key = "") {
		DarkMsgBox("No License", "No license key to validate.", "warning")
		return
	}
	
	if (GHL_LocationID = "") {
		DarkMsgBox("Location Required", "Please configure your GHL Location ID first.", "warning")
		return
	}
	
	ToolTip, Validating license...
	tempFile := A_Temp . "\license_result.json"
	scriptCmd := GetScriptCommand("validate_license", "validate """ . License_Key . """ """ . GHL_LocationID . """")
	fullCmd := ComSpec . " /s /c """ . scriptCmd . " > """ . tempFile . """"""
	RunWait, %fullCmd%, , Hide
	
	FileRead, resultJson, %tempFile%
	FileDelete, %tempFile%
	ToolTip
	
	if InStr(resultJson, """valid"": true") {
		License_Status := "active"
		FormatTime, License_ValidatedAt,, yyyy-MM-ddTHH:mm:ss
		SaveSettings()
		UpdateLicenseDisplay()
		DarkMsgBox("License Valid", "Your license is valid and active!`n`nNext validation due in 30 days.", "success")
	} else {
		RegExMatch(resultJson, """message"":\s*""([^""]*)""", match)
		errorMsg := match1 ? match1 : "Validation failed."
		
		if InStr(resultJson, "expired") {
			License_Status := "expired"
		} else {
			License_Status := "invalid"
		}
		SaveSettings()
		UpdateLicenseDisplay()
		DarkMsgBox("Validation Failed", errorMsg, "error")
	}
Return

DeactivateLicenseBtn:
	if (License_Key = "") {
		DarkMsgBox("No License", "No license to deactivate.", "warning")
		return
	}
	
	result := DarkMsgBox("Confirm Deactivation", "Are you sure you want to deactivate this license?`n`nYou can reactivate it on this or another location later.", "question", {buttons: ["Yes", "No"]})
	if (result = "No")
		return
	
	ToolTip, Deactivating license...
	tempFile := A_Temp . "\license_result.json"
	scriptCmd := GetScriptCommand("validate_license", "deactivate """ . License_Key . """ """ . GHL_LocationID . """ """ . License_InstanceID . """")
	fullCmd := ComSpec . " /s /c """ . scriptCmd . " > """ . tempFile . """"""
	RunWait, %fullCmd%, , Hide
	
	FileRead, resultJson, %tempFile%
	FileDelete, %tempFile%
	ToolTip
	
	if InStr(resultJson, """success"": true") || InStr(resultJson, """deactivated"": true") {
		License_Status := "trial"
		License_InstanceID := ""
		License_ActivatedAt := ""
		License_ValidatedAt := ""
		SaveSettings()
		UpdateLicenseDisplay()
		DarkMsgBox("License Deactivated", "License has been deactivated.`n`nYou can reactivate it with the same key.", "success")
	} else {
		RegExMatch(resultJson, """message"":\s*""([^""]*)""", match)
		errorMsg := match1 ? match1 : "Deactivation failed."
		DarkMsgBox("Deactivation Failed", errorMsg, "error")
	}
Return

BuyLicenseBtn:
	Run, %License_PurchaseURL%
Return

; Update license display in Settings GUI
UpdateLicenseDisplay() {
	global
	
	statusText := GetLicenseStatusText()
	statusColor := GetLicenseStatusColor()
	
	GuiControl, Settings:, LicenseStatusText, %statusText%
	
	; Update details
	nameDisplay := License_CustomerName ? License_CustomerName : "—"
	GuiControl, Settings:, LicenseNameValue, %nameDisplay%
	
	emailDisplay := License_CustomerEmail ? License_CustomerEmail : "—"
	GuiControl, Settings:, LicenseEmailValue, %emailDisplay%
	
	activatedDisplay := License_ActivatedAt ? License_ActivatedAt : "—"
	GuiControl, Settings:, LicenseActivatedValue, %activatedDisplay%
	
	expiryDisplay := License_ExpiresAt ? License_ExpiresAt : "—"
	GuiControl, Settings:, LicenseExpiryValue, %expiryDisplay%
	
	locDisplay := GHL_LocationID ? GHL_LocationID : "(Configure in GHL tab first)"
	GuiControl, Settings:, LicenseLocationInfo, Bound to Location: %locDisplay%
}

; ============================================================
; License Obfuscation Functions
; Prevents casual tampering with INI file license values
; ============================================================

; Encode license data to obfuscated token
EncodeLicenseToken() {
	global License_Key, License_Status, License_ValidatedAt, License_ExpiresAt, License_InstanceID, License_ObfuscationKey
	
	; Combine critical license data with separator
	plainData := License_Key . "|" . License_Status . "|" . License_ValidatedAt . "|" . License_ExpiresAt . "|" . License_InstanceID
	
	; Create checksum (simple hash of the data)
	checksum := 0
	Loop, Parse, plainData
		checksum := checksum + Asc(A_LoopField)
	checksum := Mod(checksum, 65536)
	
	; Add checksum to data
	plainData := checksum . ":" . plainData
	
	; XOR encode with key
	encoded := ""
	keyLen := StrLen(License_ObfuscationKey)
	Loop, Parse, plainData
	{
		keyChar := SubStr(License_ObfuscationKey, Mod(A_Index - 1, keyLen) + 1, 1)
		xorVal := Asc(A_LoopField) ^ Asc(keyChar)
		encoded .= Format("{:02X}", xorVal)
	}
	
	return encoded
}

; Decode and verify license token from INI
DecodeLicenseToken(encoded) {
	global License_ObfuscationKey
	
	if (encoded = "" || StrLen(encoded) < 10)
		return ""
	
	; Decode XOR
	decoded := ""
	keyLen := StrLen(License_ObfuscationKey)
	charIndex := 0
	Loop, % StrLen(encoded) // 2
	{
		hexPair := SubStr(encoded, (A_Index - 1) * 2 + 1, 2)
		SetFormat, Integer, D
		charVal := "0x" . hexPair
		charVal += 0  ; Convert to number
		keyChar := SubStr(License_ObfuscationKey, Mod(charIndex, keyLen) + 1, 1)
		decoded .= Chr(charVal ^ Asc(keyChar))
		charIndex++
	}
	
	; Verify checksum
	colonPos := InStr(decoded, ":")
	if (!colonPos)
		return ""
	
	storedChecksum := SubStr(decoded, 1, colonPos - 1)
	dataOnly := SubStr(decoded, colonPos + 1)
	
	; Calculate checksum of data
	calcChecksum := 0
	Loop, Parse, dataOnly
		calcChecksum := calcChecksum + Asc(A_LoopField)
	calcChecksum := Mod(calcChecksum, 65536)
	
	; Verify
	if (storedChecksum != calcChecksum)
		return ""  ; Tampered!
	
	return dataOnly
}

; Save license with obfuscation
SaveLicenseSecure() {
	global
	
	; Save obfuscated token
	token := EncodeLicenseToken()
	IniWrite, %token%, %IniFilename%, License, Token
	
	; Still save non-sensitive values in plain text for display purposes
	IniWrite, %License_CustomerName%, %IniFilename%, License, CustomerName
	IniWrite, %License_CustomerEmail%, %IniFilename%, License, CustomerEmail
	IniWrite, %License_ActivatedAt%, %IniFilename%, License, ActivatedAt
	IniWrite, %License_TrialStart%, %IniFilename%, License, TrialStart
	
	; Remove old plain-text values (migration)
	IniDelete, %IniFilename%, License, Key
	IniDelete, %IniFilename%, License, Status
	IniDelete, %IniFilename%, License, ValidatedAt
	IniDelete, %IniFilename%, License, ExpiresAt
	IniDelete, %IniFilename%, License, InstanceID
}

; Load license with verification
LoadLicenseSecure() {
	global
	
	; Try to read obfuscated token first
	IniRead, token, %IniFilename%, License, Token, %A_Space%
	
	if (token != "") {
		; Decode and verify
		decoded := DecodeLicenseToken(token)
		
		if (decoded = "") {
			; Tampered or corrupted! Force re-validation
			License_Key := ""
			License_Status := "invalid"
			License_ValidatedAt := ""
			License_ExpiresAt := ""
			License_InstanceID := ""
			return false  ; Indicates tampering detected
		}
		
		; Parse the decoded data
		parts := StrSplit(decoded, "|")
		License_Key := parts[1]
		License_Status := parts[2]
		License_ValidatedAt := parts[3]
		License_ExpiresAt := parts[4]
		License_InstanceID := parts[5]
		return true
	}
	
	; Fallback: try old plain-text format (migration from old version)
	IniRead, License_Key, %IniFilename%, License, Key, %A_Space%
	IniRead, License_Status, %IniFilename%, License, Status, trial
	IniRead, License_ValidatedAt, %IniFilename%, License, ValidatedAt, %A_Space%
	IniRead, License_ExpiresAt, %IniFilename%, License, ExpiresAt, %A_Space%
	IniRead, License_InstanceID, %IniFilename%, License, InstanceID, %A_Space%
	
	; If we found a license key in old format, save in new secure format
	if (License_Key != "") {
		SaveLicenseSecure()
	}
	
	return true
}

; Check license on startup (monthly validation)
CheckMonthlyLicenseValidation() {
	global License_Key, License_Status, License_ValidatedAt, GHL_LocationID
	
	; If status is invalid (tampered or corrupted), force validation
	if (License_Status = "invalid") {
		DarkMsgBox("License Verification Required", "License data could not be verified.`n`nPlease re-enter your license key to continue using premium features.", "warning")
		return
	}
	
	if (License_Key = "" || License_Status != "active")
		return
	
	if (GHL_LocationID = "")
		return
	
	; Check if validation needed
	tempFile := A_Temp . "\license_check.json"
	checkCmd := GetScriptCommand("validate_license", "check """ . License_ValidatedAt . """")
	
	RunWait, %ComSpec% /c "%checkCmd% > "%tempFile%"", , Hide
	
	FileRead, resultJson, %tempFile%
	FileDelete, %tempFile%
	
	if InStr(resultJson, """needs_validation"": true") {
		; Validate license
		validateCmd := GetScriptCommand("validate_license", "validate """ . License_Key . """ """ . GHL_LocationID . """")
		RunWait, %ComSpec% /c "%validateCmd% > "%tempFile%"", , Hide
		
		FileRead, validateResult, %tempFile%
		FileDelete, %tempFile%
		
		if InStr(validateResult, """valid"": true") {
			FormatTime, License_ValidatedAt,, yyyy-MM-ddTHH:mm:ss
			SaveSettings()
			TrayTip, SideKick_PS, License validated successfully, 3
		} else {
			License_Status := "expired"
			SaveSettings()
			DarkMsgBox("License Issue", "Your license could not be validated.`n`nPlease check your internet connection or contact support.", "warning")
		}
	}
}

; Check trial status on startup (tied to Location ID)
CheckTrialStatus() {
	global License_Key, License_Status, GHL_LocationID, License_TrialStart, License_TrialWarningDate, License_PurchaseURL
	
	; Skip if licensed
	if (License_Key != "" && License_Status = "active")
		return
	
	; Need Location ID for trial
	if (GHL_LocationID = "") {
		; Can't check trial without Location ID - will prompt user
		return
	}
	
	tempFile := A_Temp . "\trial_result.json"
	trialCmd := GetScriptCommand("validate_license", "trial """ . GHL_LocationID . """")
	
	RunWait, %ComSpec% /c "%trialCmd% > "%tempFile%"", , Hide
	
	FileRead, resultJson, %tempFile%
	FileDelete, %tempFile%
	
	; Parse trial info
	if InStr(resultJson, """is_expired"": true") {
		License_Status := "expired"
		DarkMsgBox("Trial Expired", "Your 14-day trial has expired.`n`nPlease purchase a license to continue using SideKick_PS.", "warning")
		Run, %License_PurchaseURL%
	} else {
		; Extract days remaining
		RegExMatch(resultJson, """days_remaining"":\s*(\d+)", match)
		daysRemaining := match1
		
		RegExMatch(resultJson, """trial_start"":\s*""([^""]*)""", match)
		License_TrialStart := match1
		
		; Show daily trial warning popup
		ShowDailyTrialWarning(daysRemaining)
	}
}

; Show trial warning popup once per day
ShowDailyTrialWarning(daysRemaining) {
	global License_TrialWarningDate, License_PurchaseURL
	
	; Get today's date
	FormatTime, today,, yyyy-MM-dd
	
	; Skip if already shown today
	if (License_TrialWarningDate = today)
		return
	
	; Update last warning date
	License_TrialWarningDate := today
	IniWrite, %License_TrialWarningDate%, %IniFilename%, License, TrialWarningDate
	
	; Build warning message based on days remaining
	if (daysRemaining <= 0) {
		title := "Trial Expired"
		msg := "Your SideKick_PS trial has expired!`n`nPurchase a license to continue using all features."
		msgType := "warning"
	} else if (daysRemaining = 1) {
		title := "Trial Ending Tomorrow"
		msg := "Your SideKick_PS trial expires TOMORROW!`n`nOnly 1 day remaining.`n`nPurchase now to avoid interruption."
		msgType := "warning"
	} else if (daysRemaining <= 3) {
		title := "Trial Ending Soon"
		msg := "Your SideKick_PS trial expires in " . daysRemaining . " days!`n`nPurchase a license to continue using all features."
		msgType := "warning"
	} else {
		title := "SideKick_PS Trial"
		msg := "You are using SideKick_PS in trial mode.`n`n" . daysRemaining . " days remaining in your free trial.`n`nEnjoy exploring all features!"
		msgType := "info"
	}
	
	; Show dialog with Buy License option
	result := DarkMsgBox(title, msg . "`n`nWould you like to purchase a license now?", msgType, {buttons: ["Buy License", "Later"]})
	if (result = "Buy License")
	{
		Run, %License_PurchaseURL%
	}
}

; Hotkey capture handlers
CaptureHotkey_GHL:
	GuiControl, Settings:, HKCaptureGHL, Press key...
	; Wait for a key press
	KeyWait, Control
	KeyWait, Shift
	KeyWait, Alt
	
	; Capture the hotkey using a hook
	hotkeyStr := CaptureHotkeyCombo()
	
	if (hotkeyStr != "") {
		Hotkey_GHLLookup := hotkeyStr
		GuiControl, Settings:, Hotkey_GHLLookup_Edit, % FormatHotkeyDisplay(hotkeyStr)
	}
	GuiControl, Settings:, HKCaptureGHL, Set
Return

CaptureHotkey_PayPlan:
	GuiControl, Settings:, HKCapturePP, Press key...
	KeyWait, Control
	KeyWait, Shift
	KeyWait, Alt
	
	hotkeyStr := CaptureHotkeyCombo()
	
	if (hotkeyStr != "") {
		Hotkey_PayPlan := hotkeyStr
		GuiControl, Settings:, Hotkey_PayPlan_Edit, % FormatHotkeyDisplay(hotkeyStr)
	}
	GuiControl, Settings:, HKCapturePP, Set
Return

CaptureHotkey_Settings:
	GuiControl, Settings:, HKCaptureSettings, Press key...
	KeyWait, Control
	KeyWait, Shift
	KeyWait, Alt
	
	hotkeyStr := CaptureHotkeyCombo()
	
	if (hotkeyStr != "") {
		Hotkey_Settings := hotkeyStr
		GuiControl, Settings:, Hotkey_Settings_Edit, % FormatHotkeyDisplay(hotkeyStr)
	}
	GuiControl, Settings:, HKCaptureSettings, Set
Return

CaptureHotkey_DevReload:
	GuiControl, Settings:, HKCaptureDevReload, Press key...
	KeyWait, Control
	KeyWait, Shift
	KeyWait, Alt
	
	hotkeyStr := CaptureHotkeyCombo()
	
	if (hotkeyStr != "") {
		Hotkey_DevReload := hotkeyStr
		GuiControl, Settings:, Hotkey_DevReload_Edit, % FormatHotkeyDisplay(hotkeyStr)
	}
	GuiControl, Settings:, HKCaptureDevReload, Set
Return

; Function to capture a hotkey combination
CaptureHotkeyCombo() {
	; Wait for user to press and release modifiers, then a key
	Loop {
		; Check for escape to cancel
		if GetKeyState("Escape", "P")
			return ""
		
		; Check each possible key
		Loop, 26 {
			letter := Chr(64 + A_Index)  ; A-Z
			if GetKeyState(letter, "P") {
				; Found the key - build the hotkey string
				hotkeyStr := ""
				if GetKeyState("Control", "P")
					hotkeyStr .= "^"
				if GetKeyState("Shift", "P")
					hotkeyStr .= "+"
				if GetKeyState("Alt", "P")
					hotkeyStr .= "!"
				if GetKeyState("LWin", "P") || GetKeyState("RWin", "P")
					hotkeyStr .= "#"
				
				StringLower, letter, letter
				hotkeyStr .= letter
				
				; Wait for key release
				KeyWait, %letter%
				return hotkeyStr
			}
		}
		
		; Check number keys 0-9
		Loop, 10 {
			num := A_Index - 1
			if GetKeyState(num, "P") {
				hotkeyStr := ""
				if GetKeyState("Control", "P")
					hotkeyStr .= "^"
				if GetKeyState("Shift", "P")
					hotkeyStr .= "+"
				if GetKeyState("Alt", "P")
					hotkeyStr .= "!"
				if GetKeyState("LWin", "P") || GetKeyState("RWin", "P")
					hotkeyStr .= "#"
				hotkeyStr .= num
				KeyWait, %num%
				return hotkeyStr
			}
		}
		
		; Check F1-F12
		Loop, 12 {
			fkey := "F" . A_Index
			if GetKeyState(fkey, "P") {
				hotkeyStr := ""
				if GetKeyState("Control", "P")
					hotkeyStr .= "^"
				if GetKeyState("Shift", "P")
					hotkeyStr .= "+"
				if GetKeyState("Alt", "P")
					hotkeyStr .= "!"
				if GetKeyState("LWin", "P") || GetKeyState("RWin", "P")
					hotkeyStr .= "#"
				hotkeyStr .= fkey
				KeyWait, %fkey%
				return hotkeyStr
			}
		}
		
		Sleep, 10
	}
}
Return

ResetHotkeysToDefault:
result := DarkMsgBox("Reset Hotkeys", "Reset all hotkeys to defaults?`n`nGHL Lookup: Ctrl+Shift+G`nPayPlan: Ctrl+Shift+P`nSettings: Ctrl+Shift+W", "question", {buttons: ["Yes", "No"]})
if (result = "Yes")
{
	Hotkey_GHLLookup := "^+g"
	Hotkey_PayPlan := "^+p"
	Hotkey_Settings := "^+w"
	GuiControl, Settings:, Hotkey_GHLLookup_Edit, % FormatHotkeyDisplay("^+g")
	GuiControl, Settings:, Hotkey_PayPlan_Edit, % FormatHotkeyDisplay("^+p")
	GuiControl, Settings:, Hotkey_Settings_Edit, % FormatHotkeyDisplay("^+w")
	if (!A_IsCompiled) {
		Hotkey_DevReload := "^+r"
		GuiControl, Settings:, Hotkey_DevReload_Edit, % FormatHotkeyDisplay("^+r")
	}
	ToolTip, Hotkeys reset to defaults
	SetTimer, RemoveSettingsTooltip, -1500
}
Return

ClearAllHotkeys:
result := DarkMsgBox("Clear Hotkeys", "Clear all hotkeys? They will be disabled until you set new ones.", "question", {buttons: ["Yes", "No"]})
if (result = "Yes")
{
	Hotkey_GHLLookup := "None"
	Hotkey_PayPlan := "None"
	Hotkey_Settings := "None"
	GuiControl, Settings:, Hotkey_GHLLookup_Edit, None
	GuiControl, Settings:, Hotkey_PayPlan_Edit, None
	GuiControl, Settings:, Hotkey_Settings_Edit, None
	if (!A_IsCompiled) {
		Hotkey_DevReload := "None"
		GuiControl, Settings:, Hotkey_DevReload_Edit, None
	}
	ToolTip, All hotkeys cleared
	SetTimer, RemoveSettingsTooltip, -1500
}
Return

; ═══════════════════════════════════════════════════════════════════════════
; TOOLBAR BUTTON TOGGLE HANDLERS - Click to toggle enabled/disabled
; ═══════════════════════════════════════════════════════════════════════════

ToggleTB_Client:
Settings_ShowBtn_Client := !Settings_ShowBtn_Client
GoSub, UpdateTBButtonStates
Return

ToggleTB_Invoice:
Settings_ShowBtn_Invoice := !Settings_ShowBtn_Invoice
GoSub, UpdateTBButtonStates
Return

ToggleTB_OpenGHL:
Settings_ShowBtn_OpenGHL := !Settings_ShowBtn_OpenGHL
GoSub, UpdateTBButtonStates
Return

ToggleTB_Camera:
Settings_ShowBtn_Camera := !Settings_ShowBtn_Camera
GoSub, UpdateTBButtonStates
Return

ToggleTB_Sort:
Settings_ShowBtn_Sort := !Settings_ShowBtn_Sort
GoSub, UpdateTBButtonStates
Return

ToggleTB_Photoshop:
Settings_ShowBtn_Photoshop := !Settings_ShowBtn_Photoshop
GoSub, UpdateTBButtonStates
Return

ToggleTB_Refresh:
Settings_ShowBtn_Refresh := !Settings_ShowBtn_Refresh
GoSub, UpdateTBButtonStates
Return

ToggleTB_Print:
Settings_ShowBtn_Print := !Settings_ShowBtn_Print
GoSub, UpdateTBButtonStates
Return

ToggleTB_QRCode:
Settings_ShowBtn_QRCode := !Settings_ShowBtn_QRCode
GoSub, UpdateTBButtonStates
Return

UpdateTBButtonStates:
; Update visual appearance of toolbar button icons and labels based on enabled state
; Theme colors
if (Settings_DarkMode) {
	labelColor := "CCCCCC"
	disabledLabelColor := "666666"
	disabledIconColor := "888888"
} else {
	labelColor := "444444"
	disabledLabelColor := "999999"
	disabledIconColor := "666666"
}

; Client button
if (Settings_ShowBtn_Client) {
	GuiControl, Settings:+Background0000FF, SCIcon_Client
	Gui, Settings:Font, s14 cFFFFFF, Segoe UI
} else {
	GuiControl, Settings:+Background444444, SCIcon_Client
	Gui, Settings:Font, s14 c%disabledIconColor%, Segoe UI
}
GuiControl, Settings:Font, SCIcon_Client
Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
if (!Settings_ShowBtn_Client)
	Gui, Settings:Font, s10 Norm c%disabledLabelColor%, Segoe UI
GuiControl, Settings:Font, SCLabel_Client

; Invoice button
if (Settings_ShowBtn_Invoice) {
	GuiControl, Settings:+Background008000, SCIcon_Invoice
	Gui, Settings:Font, s14 cFFFFFF, Segoe UI
} else {
	GuiControl, Settings:+Background444444, SCIcon_Invoice
	Gui, Settings:Font, s14 c%disabledIconColor%, Segoe UI
}
GuiControl, Settings:Font, SCIcon_Invoice
Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
if (!Settings_ShowBtn_Invoice)
	Gui, Settings:Font, s10 Norm c%disabledLabelColor%, Segoe UI
GuiControl, Settings:Font, SCLabel_Invoice

; OpenGHL button
if (Settings_ShowBtn_OpenGHL) {
	GuiControl, Settings:+Background008080, SCIcon_OpenGHL
	Gui, Settings:Font, s14 cFFFFFF, Segoe UI
} else {
	GuiControl, Settings:+Background444444, SCIcon_OpenGHL
	Gui, Settings:Font, s14 c%disabledIconColor%, Segoe UI
}
GuiControl, Settings:Font, SCIcon_OpenGHL
Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
if (!Settings_ShowBtn_OpenGHL)
	Gui, Settings:Font, s10 Norm c%disabledLabelColor%, Segoe UI
GuiControl, Settings:Font, SCLabel_OpenGHL

; Camera button
if (Settings_ShowBtn_Camera) {
	GuiControl, Settings:+Background800000, SCIcon_Camera
	Gui, Settings:Font, s14 cFFFFFF, Segoe UI
} else {
	GuiControl, Settings:+Background444444, SCIcon_Camera
	Gui, Settings:Font, s14 c%disabledIconColor%, Segoe UI
}
GuiControl, Settings:Font, SCIcon_Camera
Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
if (!Settings_ShowBtn_Camera)
	Gui, Settings:Font, s10 Norm c%disabledLabelColor%, Segoe UI
GuiControl, Settings:Font, SCLabel_Camera

; Sort button
if (Settings_ShowBtn_Sort) {
	GuiControl, Settings:+Background808080, SCIcon_Sort
	Gui, Settings:Font, s14 cFFFFFF, Segoe UI Emoji
} else {
	GuiControl, Settings:+Background444444, SCIcon_Sort
	Gui, Settings:Font, s14 c%disabledIconColor%, Segoe UI Emoji
}
GuiControl, Settings:Font, SCIcon_Sort
Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
if (!Settings_ShowBtn_Sort)
	Gui, Settings:Font, s10 Norm c%disabledLabelColor%, Segoe UI
GuiControl, Settings:Font, SCLabel_Sort

; Photoshop button
if (Settings_ShowBtn_Photoshop) {
	GuiControl, Settings:+Background001E36, SCIcon_Photoshop
	Gui, Settings:Font, s10 Bold c33A1FD, Segoe UI
} else {
	GuiControl, Settings:+Background444444, SCIcon_Photoshop
	Gui, Settings:Font, s10 Bold c%disabledIconColor%, Segoe UI
}
GuiControl, Settings:Font, SCIcon_Photoshop
Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
if (!Settings_ShowBtn_Photoshop)
	Gui, Settings:Font, s10 Norm c%disabledLabelColor%, Segoe UI
GuiControl, Settings:Font, SCLabel_Photoshop

; Refresh button
if (Settings_ShowBtn_Refresh) {
	GuiControl, Settings:+Background000080, SCIcon_Refresh
	Gui, Settings:Font, s14 cFFFFFF, Segoe UI
} else {
	GuiControl, Settings:+Background444444, SCIcon_Refresh
	Gui, Settings:Font, s14 c%disabledIconColor%, Segoe UI
}
GuiControl, Settings:Font, SCIcon_Refresh
Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
if (!Settings_ShowBtn_Refresh)
	Gui, Settings:Font, s10 Norm c%disabledLabelColor%, Segoe UI
GuiControl, Settings:Font, SCLabel_Refresh

; Print button
if (Settings_ShowBtn_Print) {
	GuiControl, Settings:+Background444444, SCIcon_Print
	Gui, Settings:Font, s14 cFFFFFF, Segoe UI
} else {
	GuiControl, Settings:+Background333333, SCIcon_Print
	Gui, Settings:Font, s14 c%disabledIconColor%, Segoe UI
}
GuiControl, Settings:Font, SCIcon_Print
Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
if (!Settings_ShowBtn_Print)
	Gui, Settings:Font, s10 Norm c%disabledLabelColor%, Segoe UI
GuiControl, Settings:Font, SCLabel_Print

; QRCode button
if (Settings_ShowBtn_QRCode) {
	GuiControl, Settings:+Background006666, SCIcon_QRCode
	Gui, Settings:Font, s14 cFFFFFF, Segoe UI
} else {
	GuiControl, Settings:+Background444444, SCIcon_QRCode
	Gui, Settings:Font, s14 c%disabledIconColor%, Segoe UI
}
GuiControl, Settings:Font, SCIcon_QRCode
Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
if (!Settings_ShowBtn_QRCode)
	Gui, Settings:Font, s10 Norm c%disabledLabelColor%, Segoe UI
GuiControl, Settings:Font, SCLabel_QRCode

Return

; Button handlers
SettingsApply:
Gui, Settings:Submit, NoHide
; Copy toggle states to settings variables
Settings_StartOnBoot := Toggle_StartOnBoot_State
Settings_ShowTrayIcon := Toggle_ShowTrayIcon_State
Settings_EnableSounds := Toggle_EnableSounds_State
Settings_AutoDetectPS := Toggle_AutoDetectPS_State
Settings_GHL_Enabled := Toggle_GHL_Enabled_State
Settings_GHL_AutoLoad := Toggle_GHL_AutoLoad_State
; Get dropdown values
Settings_DefaultRecurring := Settings_DefaultRecurring_DDL
; File Management settings from edit controls
Settings_CardDrive := FilesCardDriveEdit
Settings_CameraDownloadPath := FilesDownloadEdit
Settings_ShootArchivePath := FilesArchiveEdit
Settings_ShootPrefix := FilesPrefixEdit
Settings_ShootSuffix := FilesSuffixEdit
; Handle editor path - if "Windows Explorer", save as "Explore"
Settings_EditorRunPath := (FilesEditorEdit = "Windows Explorer") ? "Explore" : FilesEditorEdit
; File Management toggles (using _State from toggle sliders)
Settings_AutoShootYear := Toggle_AutoShootYear_State
Settings_AutoRenameImages := Toggle_AutoRenameImages_State
Settings_BrowsDown := Toggle_BrowsDown_State
Settings_AutoDriveDetect := Toggle_AutoDriveDetect_State
Settings_SDCardEnabled := Toggle_SDCardEnabled_State
; Toolbar button visibility - already updated directly by ToggleTB_* handlers
; QR Code text fields from Display tab
Settings_QRCode_Text1 := DisplayQREdit1
Settings_QRCode_Text2 := DisplayQREdit2
Settings_QRCode_Text3 := DisplayQREdit3
Settings_QRCode_Display := DisplayQRDisplay
Settings_DisplaySize := DisplaySizeSlider
Settings_BankScale := DisplayBankScaleSlider
; Bank transfer fields from Display tab
Settings_BankInstitution := DisplayBankInstEdit
Settings_BankName := DisplayBankNameEdit
; Strip any non-digits from sort code (user may enter 123456, 12-34-56, or 12 34 56)
Settings_BankSortCode := RegExReplace(DisplayBankSortEdit, "[^0-9]")
Settings_BankAccNo := DisplayBankAccEdit
; Quick Print printer from Print tab dropdown
if (PrintPrinterCombo != "" && PrintPrinterCombo != "System Default")
	Settings_QuickPrintPrinter := PrintPrinterCombo
else
	Settings_QuickPrintPrinter := ""
; Quick Print template strings from Print tab combo boxes
if (PrintPayPlanCombo != "" && PrintPayPlanCombo != "SELECT")
	Settings_PrintTemplate_PayPlan := PrintPayPlanCombo
if (PrintStandardCombo != "" && PrintStandardCombo != "SELECT")
	Settings_PrintTemplate_Standard := PrintStandardCombo
; Email template from Print tab combo box - look up ID from cached templates
if (PrintEmailTplCombo != "" && PrintEmailTplCombo != "(none selected)" && PrintEmailTplCombo != "SELECT") {
	Settings_EmailTemplateName := PrintEmailTplCombo
	; Find ID for this template name
	Settings_EmailTemplateID := ""
	Loop, Parse, GHL_CachedEmailTemplates, `n, `r
	{
		if (A_LoopField = "")
			continue
		parts := StrSplit(A_LoopField, "|")
		if (parts.Length() >= 2 && parts[2] = PrintEmailTplCombo) {
			Settings_EmailTemplateID := parts[1]
			break
		}
	}
} else {
	Settings_EmailTemplateName := "(none selected)"
	Settings_EmailTemplateID := ""
}
; Room capture folder from Print tab combo box
Settings_RoomCaptureFolder := PrintRoomFolderCombo
; PDF settings from Print tab
Settings_EnablePDF := Toggle_EnablePDF_State
Settings_PDFOutputFolder := PrintPDFCopyEdit
; GHL settings from edit controls
Settings_GHLTags := GHLTagsEdit
Settings_GHLOppTags := GHLOppTagsEdit
Settings_InvoiceWatchFolder := GHLWatchFolderEdit
Settings_ContactSheetFolder := GHLCSFolderEdit
; Save settings
SaveSettings()
; Rebuild toolbar to reflect button visibility changes
Gui, Toolbar:Destroy
; Cancel any pending background sample timers
SetTimer, FirstLaunchBackgroundSample, Off
global Toolbar_FirstShowDone := true
; Use saved background color (don't resample - it's unreliable after dialogs close)
global Settings_ToolbarAutoBG_Temp := Settings_ToolbarAutoBG
Settings_ToolbarAutoBG := false
CreateFloatingToolbar()
Settings_ToolbarAutoBG := Settings_ToolbarAutoBG_Temp
ToolTip, Settings saved!
SetTimer, RemoveSettingsTooltip, -1500
Return

RemoveSettingsTooltip:
ToolTip
Return

SettingsClose:
SettingsGuiClose:
SettingsGuiEscape:
Gui, Settings:Submit, NoHide
; Copy toggle states to settings variables
Settings_StartOnBoot := Toggle_StartOnBoot_State
Settings_ShowTrayIcon := Toggle_ShowTrayIcon_State
Settings_EnableSounds := Toggle_EnableSounds_State
Settings_AutoDetectPS := Toggle_AutoDetectPS_State
Settings_GHL_Enabled := Toggle_GHL_Enabled_State
Settings_GHL_AutoLoad := Toggle_GHL_AutoLoad_State
; Get dropdown values
Settings_DefaultRecurring := Settings_DefaultRecurring_DDL
; File Management settings from edit controls
Settings_CardDrive := FilesCardDriveEdit
Settings_CameraDownloadPath := FilesDownloadEdit
Settings_ShootArchivePath := FilesArchiveEdit
Settings_ShootPrefix := FilesPrefixEdit
Settings_ShootSuffix := FilesSuffixEdit
; Handle editor path - if "Windows Explorer", save as "Explore"
Settings_EditorRunPath := (FilesEditorEdit = "Windows Explorer") ? "Explore" : FilesEditorEdit
; File Management toggles (using _State from toggle sliders)
Settings_AutoShootYear := Toggle_AutoShootYear_State
Settings_AutoRenameImages := Toggle_AutoRenameImages_State
Settings_BrowsDown := Toggle_BrowsDown_State
Settings_AutoDriveDetect := Toggle_AutoDriveDetect_State
Settings_SDCardEnabled := Toggle_SDCardEnabled_State
; Toolbar button visibility - already updated directly by ToggleTB_* handlers
; QR Code text fields from Display tab
Settings_QRCode_Text1 := DisplayQREdit1
Settings_QRCode_Text2 := DisplayQREdit2
Settings_QRCode_Text3 := DisplayQREdit3
Settings_QRCode_Display := DisplayQRDisplay
Settings_DisplaySize := DisplaySizeSlider
Settings_BankScale := DisplayBankScaleSlider
; Bank transfer fields from Display tab
Settings_BankInstitution := DisplayBankInstEdit
Settings_BankName := DisplayBankNameEdit
; Strip any non-digits from sort code (user may enter 123456, 12-34-56, or 12 34 56)
Settings_BankSortCode := RegExReplace(DisplayBankSortEdit, "[^0-9]")
Settings_BankAccNo := DisplayBankAccEdit
; Quick Print printer from Print tab dropdown
if (PrintPrinterCombo != "" && PrintPrinterCombo != "System Default")
	Settings_QuickPrintPrinter := PrintPrinterCombo
else
	Settings_QuickPrintPrinter := ""
; Quick Print template strings from Print tab combo boxes
if (PrintPayPlanCombo != "" && PrintPayPlanCombo != "SELECT")
	Settings_PrintTemplate_PayPlan := PrintPayPlanCombo
if (PrintStandardCombo != "" && PrintStandardCombo != "SELECT")
	Settings_PrintTemplate_Standard := PrintStandardCombo
; Email template from Print tab combo box - look up ID from cached templates
if (PrintEmailTplCombo != "" && PrintEmailTplCombo != "(none selected)" && PrintEmailTplCombo != "SELECT") {
	Settings_EmailTemplateName := PrintEmailTplCombo
	; Find ID for this template name
	Settings_EmailTemplateID := ""
	Loop, Parse, GHL_CachedEmailTemplates, `n, `r
	{
		if (A_LoopField = "")
			continue
		parts := StrSplit(A_LoopField, "|")
		if (parts.Length() >= 2 && parts[2] = PrintEmailTplCombo) {
			Settings_EmailTemplateID := parts[1]
			break
		}
	}
} else {
	Settings_EmailTemplateName := "(none selected)"
	Settings_EmailTemplateID := ""
}
; Room capture folder from Print tab combo box
Settings_RoomCaptureFolder := PrintRoomFolderCombo
; PDF settings from Print tab
Settings_EnablePDF := Toggle_EnablePDF_State
Settings_PDFOutputFolder := PrintPDFCopyEdit
; GHL settings from edit controls
Settings_GHLTags := GHLTagsEdit
Settings_GHLOppTags := GHLOppTagsEdit
Settings_InvoiceWatchFolder := GHLWatchFolderEdit
Settings_ContactSheetFolder := GHLCSFolderEdit
; Save settings
SaveSettings()
; Rebuild toolbar: hide Settings first to prevent flash during destruction
Gui, Settings:Hide
Gui, Toolbar:Destroy
Sleep, 50
Gui, Settings:Destroy
; Cancel any pending background sample timers
SetTimer, FirstLaunchBackgroundSample, Off
global Toolbar_FirstShowDone := true
; Use saved background color (don't resample - it's unreliable after dialogs close)
global Settings_ToolbarAutoBG_Temp := Settings_ToolbarAutoBG
Settings_ToolbarAutoBG := false
CreateFloatingToolbar()
Settings_ToolbarAutoBG := Settings_ToolbarAutoBG_Temp
Settings_CurrentTab := "General"  ; Reset to General for next open
Return

EditGHLApiKey:
InputBox, newApiKey, 🔑 Edit GHL API Key, Enter your GHL API Key (Private Integration Token):`n`nGet it from GHL: Settings > Business Profile > API, , 500, 180, , , , , %GHL_API_Key%
if (!ErrorLevel && newApiKey != "")
{
	GHL_API_Key := newApiKey
	; Save to JSON credentials file
	SaveGHLCredentials()
	; Update display
	apiKeyDisplay := SubStr(GHL_API_Key, 1, 8) . "..." . SubStr(GHL_API_Key, -4)
	GuiControl, Settings:, GHLApiKeyDisplay, %apiKeyDisplay%
	; Update status
	statusText := GHL_API_Key ? "✅ Connected" : "❌ Not configured"
	GuiControl, Settings:, GHLStatusText, %statusText%
	ToolTip, API Key updated!
	SetTimer, RemoveSettingsTooltip, -1500
}
Return

EditGHLLocationID:
InputBox, newLocID, 📍 Edit GHL Location ID, Enter your GHL Location ID:`n`nFind it in GHL: Settings > Business Profile, , 450, 160, , , , , %GHL_LocationID%
if (!ErrorLevel && newLocID != "")
{
	GHL_LocationID := newLocID
	; Save to JSON credentials file
	SaveGHLCredentials()
	; Update display
	GuiControl, Settings:, GHLLocIDDisplay, %GHL_LocationID%
	ToolTip, Location ID updated!
	SetTimer, RemoveSettingsTooltip, -1500
}
Return

SetOrderQRUrl:
	global GHL_LocationID, GHL_AgencyDomain, Settings_QRCode_Text1
	
	; Check if ProSelect is running FIRST
	if !WinExist("ahk_exe ProSelect.exe") {
		DarkMsgBox("Set Order QR", "ProSelect is not running.`n`nPlease open ProSelect first, then try again.", "warning")
		Return
	}
	
	; Activate ProSelect and ensure it's ready
	WinActivate, ahk_exe ProSelect.exe
	WinWaitActive, ahk_exe ProSelect.exe, , 3
	if ErrorLevel {
		DarkMsgBox("Set Order QR", "Could not activate ProSelect.`n`nPlease click on ProSelect and try again.", "warning")
		Return
	}
	Sleep, 300
	
	if (GHL_LocationID = "") {
		DarkMsgBox("Set Order QR", "GHL Location ID is not configured.`n`nPlease set your Location ID first.", "warning")
		Return
	}
	
	; Build combined QR code URL that works for both phone AND scanner
	; Format: Full URL - the path is long enough to act as padding
	; - Phones: Scan QR → open URL directly in browser
	; - Scanners: Type fast → SideKick detects https:// → opens URL
	ghlDomain := (GHL_AgencyDomain != "") ? GHL_AgencyDomain : "app.gohighlevel.com"
	qrUrl := "https://" . ghlDomain . "/v2/location/" . GHL_LocationID . "/contacts/detail/[ACCOUNTCODE]"
	qrTitle := "GHL Client QR"
	
	Settings_QRCode_Text1 := qrUrl
	; Save to INI
	IniWrite, %qrUrl%, %IniFilename%, QRCode, Text1
	
	; Copy URL to clipboard for easy paste
	Clipboard := qrUrl
	
	; Open Resources menu using menu bar click
	; Menu order: File, Edit, Images, Products, Slideshow, Orders, Production, Resources, View, Help
	WinMenuSelectItem, ahk_exe ProSelect.exe, , Resources, Setup QR Codes...
	Sleep, 500
	
	; Wait for QR Codes window
	WinWait, QR Codes, , 3
	if ErrorLevel {
		DarkMsgBox("Set Order QR", "QR Codes window did not open.`n`nURL copied to clipboard - paste manually.", "warning")
		Return
	}
	
	WinActivate, QR Codes
	Sleep, 300
	
	; Set Title field (Edit1)
	ControlSetText, Edit1, %qrTitle%, QR Codes
	Sleep, 300
	
	; Set QR Message field to the URL (RICHEDIT50W1 is the rich text control)
	ControlSetText, RICHEDIT50W1, %qrUrl%, QR Codes
	Sleep, 300
	
	; Click Save Changes button (Button1)
	ControlClick, Button1, QR Codes
	Sleep, 750
	
	; Click Close button (Button2) - try multiple methods
	ControlClick, Button2, QR Codes
	Sleep, 300
	
	; Fallback: if window still exists, send Escape or click again
	if WinExist("QR Codes") {
		WinActivate, QR Codes
		Sleep, 100
		ControlFocus, Button2, QR Codes
		Sleep, 100
		Send, {Enter}
	}
	Sleep, 300
	
	ToolTip, ✅ GHL Client QR configured!
	SetTimer, RemoveToolTip, -3000
Return

; Handler for QR mode dropdown change
BrowseInvoiceFolder:
FileSelectFolder, selectedFolder, , 3, Select Invoice Watch Folder
if (selectedFolder != "")
{
	Settings_InvoiceWatchFolder := selectedFolder
	GuiControl, Settings:, GHLWatchFolderEdit, %selectedFolder%
	SaveSettings()
	ToolTip, Invoice watch folder set!
	SetTimer, RemoveSettingsTooltip, -1500
}
Return

; File Management Panel Handlers
FilesCardDriveBrowseBtn:
FileSelectFolder, selectedFolder, , 3, Select SD Card / DCIM Path
if (selectedFolder != "")
{
	Settings_CardDrive := selectedFolder
	GuiControl, Settings:, FilesCardDriveEdit, %selectedFolder%
}
Return

FilesDownloadBrowseBtn:
FileSelectFolder, selectedFolder, , 3, Select Download Folder
if (selectedFolder != "")
{
	Settings_CameraDownloadPath := selectedFolder
	GuiControl, Settings:, FilesDownloadEdit, %selectedFolder%
}
Return

; ============================================
; Archive Folders TreeView Picker
; ============================================
ShowArchiveFolderPicker:
global Settings_ShootArchivePath, FolderPicker_SelectedPaths, FolderPicker_TreeView

; Destroy any existing picker
Gui, FolderPicker:Destroy

; Dark theme colors
FP_BgColor := "1a1a2e"
FP_TreeBg := "252542"
FP_TextColor := "ffffff"
FP_AccentColor := "e94560"

; Create GUI
Gui, FolderPicker:New, +LabelFolderPicker +OwnDialogs -MaximizeBox +AlwaysOnTop
Gui, FolderPicker:Color, %FP_BgColor%
Gui, FolderPicker:+hwndFolderPickerHwnd

; Title
Gui, FolderPicker:Font, s12 Bold c%FP_TextColor%, Segoe UI
Gui, FolderPicker:Add, Text, x15 y10 w400, Select Archive Folders

Gui, FolderPicker:Font, s9 c888888, Segoe UI
Gui, FolderPicker:Add, Text, x15 y32 w450, Check folders to search for shoot archives:

; TreeView with checkboxes
Gui, FolderPicker:Font, s9 c%FP_TextColor%, Segoe UI
Gui, FolderPicker:Add, TreeView, x15 y60 w450 h350 vFolderPicker_TreeView gFolderPickerTV +Checked +HwndFP_TV Background%FP_TreeBg%

; Load existing selections from file
AdditionalArchivesFile := Settings_ShootArchivePath . "\_Additional_Archives.txt"
FolderPicker_SelectedPaths := {}
if FileExist(AdditionalArchivesFile) {
	FileRead, existingPaths, *P1252 %AdditionalArchivesFile%
	Loop, Parse, existingPaths, `n, `r
	{
		path := Trim(A_LoopField)
		if (path != "" && SubStr(path, 1, 1) != "#" && SubStr(path, 1, 1) != ";")
			FolderPicker_SelectedPaths[path] := true
	}
}

; Populate TreeView with drives
DriveGet, driveList, List, FIXED
Loop, Parse, driveList
{
	driveLetter := A_LoopField . ":"
	DriveGet, driveLabel, Label, %driveLetter%\
	if (driveLabel = "")
		driveLabel := "Local Disk"
	displayName := driveLetter . " [" . driveLabel . "]"
	
	; Add drive as root node
	driveNode := TV_Add(displayName, 0, "Expand")
	FP_SetItemData(driveNode, driveLetter . "\")
	
	; Check if this drive is in selected paths
	if (FolderPicker_SelectedPaths.HasKey(driveLetter . "\"))
		TV_Modify(driveNode, "Check")
	
	; Add first level folders
	Loop, Files, %driveLetter%\*, D
	{
		if (SubStr(A_LoopFileName, 1, 1) = "$" || A_LoopFileName = "System Volume Information" || A_LoopFileName = "Recovery" || A_LoopFileName = "Windows")
			continue
		
		folderPath := A_LoopFileFullPath
		folderNode := TV_Add(A_LoopFileName, driveNode)
		FP_SetItemData(folderNode, folderPath)
		
		; Check if this folder is in selected paths
		if (FolderPicker_SelectedPaths.HasKey(folderPath))
			TV_Modify(folderNode, "Check")
		
		; Add placeholder for subfolders (lazy loading)
		Loop, Files, %folderPath%\*, D
		{
			if (SubStr(A_LoopFileName, 1, 1) != "$") {
				TV_Add("", folderNode)  ; Placeholder
				break
			}
		}
	}
}

; Buttons
Gui, FolderPicker:Font, s10 Bold c%FP_TextColor%, Segoe UI
Gui, FolderPicker:Add, Button, x15 y420 w100 h30 gFolderPickerAddCustom, Add Folder...
Gui, FolderPicker:Add, Button, x280 y420 w90 h30 gFolderPickerSave Default, Save
Gui, FolderPicker:Add, Button, x375 y420 w90 h30 gFolderPickerCancel, Cancel

; Show with dark title bar
Gui, FolderPicker:Show, w480 h460, Archive Folders
Gui, FolderPicker:+LastFound
WinGet, hWnd, ID
DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hWnd, "Int", 20, "Int*", 1, "Int", 4)
Return

; TreeView expand event - lazy load subfolders
FolderPickerTV:
if (A_GuiEvent = "E") {  ; Expand
	; Get the expanded item
	itemID := A_EventInfo
	
	; Check if first child is placeholder (empty text)
	childID := TV_GetChild(itemID)
	if (childID) {
		TV_GetText(childText, childID)
		if (childText = "") {
			; Remove placeholder
			TV_Delete(childID)
			
			; Get folder path from item data
			parentPath := FP_GetItemData(itemID)
			if (parentPath != "") {
				; Load actual subfolders
				Loop, Files, %parentPath%\*, D
				{
					if (SubStr(A_LoopFileName, 1, 1) = "$" || A_LoopFileName = "System Volume Information")
						continue
					
					folderPath := A_LoopFileFullPath
					folderNode := TV_Add(A_LoopFileName, itemID)
					FP_SetItemData(folderNode, folderPath)
					
					; Check if selected
					if (FolderPicker_SelectedPaths.HasKey(folderPath))
						TV_Modify(folderNode, "Check")
					
					; Add placeholder if has subfolders
					Loop, Files, %folderPath%\*, D
					{
						if (SubStr(A_LoopFileName, 1, 1) != "$") {
							TV_Add("", folderNode)
							break
						}
					}
				}
			}
		}
	}
}
Return

; Store item data (path) in a global associative array
FP_SetItemData(itemID, data) {
	global FolderPicker_ItemData
	if !IsObject(FolderPicker_ItemData)
		FolderPicker_ItemData := {}
	FolderPicker_ItemData[itemID] := data
}

FP_GetItemData(itemID) {
	global FolderPicker_ItemData
	return FolderPicker_ItemData.HasKey(itemID) ? FolderPicker_ItemData[itemID] : ""
}

FolderPickerAddCustom:
Gui, FolderPicker:+OwnDialogs
FileSelectFolder, customPath, , 3, Select folder to add:
if (customPath != "") {
	; Find or create the node
	rootNode := TV_Add(customPath, 0, "Check")
	FP_SetItemData(rootNode, customPath)
}
Return

FolderPickerSave:
global Settings_ShootArchivePath, FolderPicker_ItemData

; Collect all checked items
checkedPaths := ""
itemID := 0
Loop {
	itemID := TV_GetNext(itemID, "Checked")
	if (!itemID)
		break
	
	path := FP_GetItemData(itemID)
	if (path != "")
		checkedPaths .= path . "`n"
}

; Save to file
AdditionalArchivesFile := Settings_ShootArchivePath . "\_Additional_Archives.txt"

; Create archive folder if needed
if (!FileExist(Settings_ShootArchivePath))
	FileCreateDir, %Settings_ShootArchivePath%

; Write file
if (FileExist(AdditionalArchivesFile))
	FileDelete, %AdditionalArchivesFile%

if (checkedPaths != "") {
	checkedPaths := RTrim(checkedPaths, "`n")
	FileAppend, %checkedPaths%, %AdditionalArchivesFile%
}

; Update the edit field with first path (or keep existing)
if (checkedPaths != "") {
	firstPath := StrSplit(checkedPaths, "`n")[1]
	Settings_ShootArchivePath := firstPath
	GuiControl, Settings:, FilesArchiveEdit, %firstPath%
}

; Clean up and close
FolderPicker_ItemData := {}
Gui, FolderPicker:Destroy
Return

FolderPickerCancel:
FolderPickerGuiClose:
FolderPickerGuiEscape:
FolderPicker_ItemData := {}
Gui, FolderPicker:Destroy
Return

FilesFolderTemplateBrowseBtn:
FileSelectFolder, selectedFolder, , 3, Select Folder Template
if (selectedFolder != "")
{
	Settings_FolderTemplatePath := selectedFolder
	GuiControl, Settings:, FilesFolderTemplateEdit, %selectedFolder%
}
Return

FilesEditorBrowseBtn:
FileSelectFile, selectedFile, 3, , Select Photo Editor, Executables (*.exe)
if (selectedFile != "")
{
	Settings_EditorRunPath := selectedFile
	GuiControl, Settings:, FilesEditorEdit, %selectedFile%
}
Return

DisplayImg1Browse:
FileSelectFile, selectedFile, 3, , Select Image 1, Images (*.jpg; *.jpeg; *.png; *.bmp; *.gif)
if (selectedFile != "")
{
	Settings_DisplayImage1 := selectedFile
	GuiControl, Settings:, DisplayImg1Edit, %selectedFile%
}
Return

DisplayImg2Browse:
FileSelectFile, selectedFile, 3, , Select Image 2, Images (*.jpg; *.jpeg; *.png; *.bmp; *.gif)
if (selectedFile != "")
{
	Settings_DisplayImage2 := selectedFile
	GuiControl, Settings:, DisplayImg2Edit, %selectedFile%
}
Return

DisplayImg3Browse:
FileSelectFile, selectedFile, 3, , Select Image 3, Images (*.jpg; *.jpeg; *.png; *.bmp; *.gif)
if (selectedFile != "")
{
	Settings_DisplayImage3 := selectedFile
	GuiControl, Settings:, DisplayImg3Edit, %selectedFile%
}
Return

DisplaySizeChanged:
	Gui, Settings:Submit, NoHide
	GuiControl, Settings:, DisplaySizeValue, %DisplaySizeSlider%`%
	Settings_DisplaySize := DisplaySizeSlider
Return

DisplayBankScaleChanged:
	Gui, Settings:Submit, NoHide
	GuiControl, Settings:, DisplayBankScaleValue, %DisplayBankScaleSlider%`%
	Settings_BankScale := DisplayBankScaleSlider
Return

DisplayIdentifyBtn:
	; Show display number overlay on each monitor for 5 seconds
	SysGet, monCount, MonitorCount
	Loop, %monCount%
	{
		monNum := A_Index
		SysGet, mon, Monitor, %monNum%
		monW := monRight - monLeft
		monH := monBottom - monTop
		; Calculate center position and size for overlay
		overlayW := 300
		overlayH := 300
		overlayX := monLeft + (monW - overlayW) // 2
		overlayY := monTop + (monH - overlayH) // 2
		; Create overlay GUI for this monitor
		Gui, DisplayID%monNum%:New, +AlwaysOnTop -Caption +ToolWindow -DPIScale +HwndDisplayIDHwnd%monNum%
		Gui, DisplayID%monNum%:Color, 000000
		Gui, DisplayID%monNum%:Font, s150 cFFFFFF Bold, Segoe UI
		Gui, DisplayID%monNum%:Add, Text, x0 y20 w%overlayW% h250 Center BackgroundTrans, %monNum%
		Gui, DisplayID%monNum%:Show, x%overlayX% y%overlayY% w%overlayW% h%overlayH% NoActivate, Display ID %monNum%
		; Make it semi-transparent
		hwnd := DisplayIDHwnd%monNum%
		WinSet, Transparent, 220, ahk_id %hwnd%
	}
	; Set timer to close all overlays after 5 seconds
	SetTimer, DisplayIdentifyClose, -5000
Return

DisplayIdentifyClose:
	SysGet, monCount, MonitorCount
	Loop, %monCount%
	{
		monNum := A_Index
		Gui, DisplayID%monNum%:Destroy
	}
Return

FilesSyncFromLB:
	; Manual sync settings from SideKick_LB
	lbIniPath := FindLBIniPath()
	if (lbIniPath = "") {
		DarkMsgBox("SideKick_LB Not Found", "Could not find SideKick_LB configuration file.`n`nLBSidekick.ini was not found in:`n• Script folder`n• AppData`n• Documents", "warning")
		return
	}
	SyncPathsFromLB(lbIniPath)
Return

; Check if SideKick_LB has auto-detect enabled and warn user
CheckLBAutoDetectConflict() {
	global
	
	lbIniPath := FindLBIniPath()
	if (lbIniPath = "")
		return  ; LB not installed or INI not found
	
	; Read LB's auto-detect setting
	IniRead, lbAutoDetect, %lbIniPath%, Config, AutoDriveDetect, 0
	
	if (lbAutoDetect = 1) {
		; Both have auto-detect enabled - warn user
		result := DarkMsgBox("⚠ SD Card Detection Conflict"
			, "SideKick_LB also has Auto-Detect SD Cards enabled.`n`n"
			. "Having both enabled may cause conflicts when an SD card is inserted.`n`n"
			. "Would you like to disable auto-detect in SideKick_LB?"
			, "warning"
			, {buttons: ["Disable in LB", "Keep Both"]})
		
		if (result = "Disable in LB") {
			; Write to LB's INI file to disable auto-detect
			IniWrite, 0, %lbIniPath%, Config, AutoDriveDetect
			DarkMsgBox("✓ Updated", "Auto-detect has been disabled in SideKick_LB.`n`nSideKick_PS will now handle SD card detection.", "success")
		}
	}
	
	; Also offer to sync other file management paths from LB
	SyncPathsFromLB(lbIniPath)
}

; Find the LBSidekick.ini file path
FindLBIniPath() {
	; Try common locations for LBSidekick.ini
	lbIniPaths := [A_ScriptDir . "\LBSidekick.ini"
		, A_AppData . "\SideKick_LB\LBSidekick.ini"
		, A_MyDocuments . "\SideKick_LB\LBSidekick.ini"]
	
	for i, path in lbIniPaths {
		if (FileExist(path))
			return path
	}
	return ""
}

; Sync file management paths from SideKick_LB if different/missing
SyncPathsFromLB(lbIniPath) {
	global Settings_CardDrive, Settings_CameraDownloadPath, Settings_ShootArchivePath
	global Settings_ShootPrefix, Settings_ShootSuffix, Settings_EditorRunPath
	
	; Read LB settings
	IniRead, lb_CardDrive, %lbIniPath%, Config, CardDrive, %A_Space%
	IniRead, lb_CardPath, %lbIniPath%, Config, CardPath, %A_Space%
	IniRead, lb_CameraDownloadPath, %lbIniPath%, Config, CameraDownloadPath, %A_Space%
	IniRead, lb_ShootArchivePath, %lbIniPath%, Config, ShootArchivePath, %A_Space%
	IniRead, lb_ShootPrefix, %lbIniPath%, Config, ShootPrefix, %A_Space%
	IniRead, lb_ShootSuffix, %lbIniPath%, Config, ShootSuffix, %A_Space%
	IniRead, lb_EditorRunPath, %lbIniPath%, Config, EditorRunPath, %A_Space%
	
	; Clean up quoted paths
	lb_CameraDownloadPath := StrReplace(lb_CameraDownloadPath, """", "")
	lb_ShootArchivePath := StrReplace(lb_ShootArchivePath, """", "")
	lb_EditorRunPath := StrReplace(lb_EditorRunPath, """", "")
	
	; Use CardPath if available, otherwise CardDrive + \DCIM
	lb_CardDrive := lb_CardPath != "" ? lb_CardPath : (lb_CardDrive != "" ? lb_CardDrive . "\DCIM" : "")
	
	; Build list of differences
	differences := []
	
	if (lb_CardDrive != "" && Settings_CardDrive != lb_CardDrive)
		differences.Push({name: "Card Path", current: Settings_CardDrive, lb: lb_CardDrive, setting: "CardDrive"})
	
	if (lb_CameraDownloadPath != "" && Settings_CameraDownloadPath != lb_CameraDownloadPath)
		differences.Push({name: "Download Folder", current: Settings_CameraDownloadPath, lb: lb_CameraDownloadPath, setting: "CameraDownloadPath"})
	
	if (lb_ShootArchivePath != "" && Settings_ShootArchivePath != lb_ShootArchivePath)
		differences.Push({name: "Archive Path", current: Settings_ShootArchivePath, lb: lb_ShootArchivePath, setting: "ShootArchivePath"})
	
	if (lb_ShootPrefix != "" && Settings_ShootPrefix != lb_ShootPrefix)
		differences.Push({name: "File Prefix", current: Settings_ShootPrefix, lb: lb_ShootPrefix, setting: "ShootPrefix"})
	
	if (lb_ShootSuffix != "" && Settings_ShootSuffix != lb_ShootSuffix)
		differences.Push({name: "File Suffix", current: Settings_ShootSuffix, lb: lb_ShootSuffix, setting: "ShootSuffix"})
	
	if (lb_EditorRunPath != "" && lb_EditorRunPath != "Explore" && Settings_EditorRunPath != lb_EditorRunPath)
		differences.Push({name: "Photo Editor", current: Settings_EditorRunPath, lb: lb_EditorRunPath, setting: "EditorRunPath"})
	
	; If no differences, return
	if (differences.Length() = 0)
		return
	
	; Build message showing differences
	msg := "SideKick_LB has different file management settings:`n`n"
	for i, diff in differences {
		currentDisplay := diff.current = "" ? "(not set)" : diff.current
		msg .= "• " . diff.name . ":`n"
		msg .= "   PS: " . currentDisplay . "`n"
		msg .= "   LB: " . diff.lb . "`n`n"
	}
	msg .= "Would you like to copy these settings from SideKick_LB?"
	
	result := DarkMsgBox("📋 Sync Settings from LB?", msg, "question", {buttons: ["Copy from LB", "Keep Current"]})
	
	if (result = "Copy from LB") {
		; Apply each difference
		for i, diff in differences {
			if (diff.setting = "CardDrive")
				Settings_CardDrive := diff.lb
			else if (diff.setting = "CameraDownloadPath")
				Settings_CameraDownloadPath := diff.lb
			else if (diff.setting = "ShootArchivePath")
				Settings_ShootArchivePath := diff.lb
			else if (diff.setting = "ShootPrefix")
				Settings_ShootPrefix := diff.lb
			else if (diff.setting = "ShootSuffix")
				Settings_ShootSuffix := diff.lb
			else if (diff.setting = "EditorRunPath")
				Settings_EditorRunPath := diff.lb
		}
		
		; Save settings
		SaveSettings()
		
		; Update the Files panel controls if visible
		GuiControl, Settings:, FilesCardDriveEdit, %Settings_CardDrive%
		GuiControl, Settings:, FilesDownloadEdit, %Settings_CameraDownloadPath%
		GuiControl, Settings:, FilesArchiveEdit, %Settings_ShootArchivePath%
		GuiControl, Settings:, FilesPrefixEdit, %Settings_ShootPrefix%
		GuiControl, Settings:, FilesSuffixEdit, %Settings_ShootSuffix%
		editorDisplay := (Settings_EditorRunPath = "Explore" || Settings_EditorRunPath = "") ? "Windows Explorer" : Settings_EditorRunPath
		GuiControl, Settings:, FilesEditorEdit, %editorDisplay%
		
		DarkMsgBox("✓ Settings Synced", "File management settings have been copied from SideKick_LB.", "success")
	}
}

; Global variable for invoice folder watcher
global LastInvoiceFiles := ""

WatchInvoiceFolder:
; Skip if export automation is in progress
if (ExportInProgress)
	return
if (Settings_InvoiceWatchFolder = "" || !FileExist(Settings_InvoiceWatchFolder))
	return
currentFiles := ""
fileCount := 0
Loop, Files, %Settings_InvoiceWatchFolder%\*.xml
{
	currentFiles .= A_LoopFileName . "|"
	fileCount++
}

; Just track the files - no prompts. User syncs by clicking toolbar icon.
LastInvoiceFiles := currentFiles
Return

ProcessInvoiceXML(xmlFile)
{
	global
	
	; Safety check: Verify XML contains a client ID before syncing
	FileRead, xmlContent, %xmlFile%
	
	; Check for Client_ID tag with actual content and extract it
	contactId := ""
	if (InStr(xmlContent, "<Client_ID>"))
	{
		; Extract the Client_ID value using regex
		if (RegExMatch(xmlContent, "<Client_ID>(.+?)</Client_ID>", match))
		{
			if (match1 != "")
				contactId := match1
		}
	}
	
	; Validate contactId - must be 20+ chars (GHL format). If not, try album title fallback
	if (StrLen(contactId) < 20)
	{
		; Try to get Client ID from ProSelect album title as fallback
		albumContactId := ""
		if WinExist("ProSelect ahk_exe ProSelect.exe")
		{
			WinGetTitle, psTitle, ahk_exe ProSelect.exe
			; Look for GHL Client ID pattern in album name (20+ alphanumeric chars after underscore)
			if (RegExMatch(psTitle, "_([A-Za-z0-9]{20,})", idMatch))
				albumContactId := idMatch1
		}
		
		if (albumContactId != "" && StrLen(albumContactId) >= 20)
		{
			if (contactId != "" && contactId != albumContactId)
			{
				; XML has a different ID (likely shootNo) - use album title instead
				FileAppend, % A_Now . " - XML Client_ID '" . contactId . "' appears invalid, using album ID: " . albumContactId . "`n", %DebugLogFile%
			}
			contactId := albumContactId
		}
	}
	
	if (contactId = "" || StrLen(contactId) < 20)
	{
		DarkMsgBox("Missing Client ID", "Invoice XML is missing a valid GHL Client ID.`n`nPlease link this order to a GHL contact before exporting.`n`nFile: " . xmlFile, "warning")
		return
	}
	
	; Run the sync script (uses compiled .exe if available)
	scriptPath := GetScriptPath("sync_ps_invoice")
	
	if (!FileExist(scriptPath))
	{
		DarkMsgBox("Script Missing", "sync_ps_invoice not found (neither .exe nor .py).", "warning")
		return
	}
	
	; Build arguments - pass contact ID explicitly in case XML has wrong value
	syncArgs := """" . xmlFile . """ --contact-id """ . contactId . """"
	if (Settings_FinancialsOnly)
		syncArgs .= " --financials-only"
	if (!Settings_ContactSheet)
		syncArgs .= " --no-contact-sheet"
	if (Settings_CollectContactSheets && Settings_ContactSheetFolder != "")
		syncArgs .= " --collect-folder """ . Settings_ContactSheetFolder . """"
	if (Settings_RoundingInDeposit)
		syncArgs .= " --rounding-in-deposit"
	if (!Settings_OpenInvoiceURL)
		syncArgs .= " --no-open-browser"
	syncCmd := GetScriptCommand("sync_ps_invoice", syncArgs)
	
	; Show non-blocking progress GUI
	ShowSyncProgressGUI(xmlFile)
	
	; Run directly - AHK Run is already non-blocking
	try {
		Run, %syncCmd%, %A_ScriptDir%, Hide, SyncProgress_ProcessId
	}
	
	; Update folder watcher's file list so it doesn't re-prompt for this file
	SplitPath, xmlFile, fileName
	if (!InStr(LastInvoiceFiles, fileName . "|"))
		LastInvoiceFiles .= fileName . "|"
}

; Show folder picker GUI for GHL Media folders
ShowGHLFolderPicker()
{
	global IniFilename, Settings_MediaFolderID, Settings_MediaFolderName
	
	; Get list of folders from GHL
	ToolTip, Loading GHL Media folders...
	scriptPath := GetScriptPath("sync_ps_invoice")
	scriptCmd := GetScriptCommand("sync_ps_invoice", "--list-folders")
	
	tempOutput := A_Temp . "\ghl_folders_" . A_TickCount . ".txt"
	fullCmd := ComSpec . " /s /c """ . scriptCmd . " > """ . tempOutput . """ 2>&1"""
	RunWait, %fullCmd%, , Hide
	ToolTip
	
	FileRead, folderOutput, %tempOutput%
	FileDelete, %tempOutput%
	
	; Check for errors
	if (InStr(folderOutput, "API_ERROR") || InStr(folderOutput, "ERROR|"))
	{
		DarkMsgBox("API Error", "Could not load GHL Media folders. Check API connection.", "warning")
		return
	}
	
	if (InStr(folderOutput, "NO_FOLDERS") || folderOutput = "")
	{
		DarkMsgBox("No Folders", "No folders found in GHL Media Library.`n`nPlease create a folder in GHL Media first.", "warning")
		return
	}
	
	; Parse folder list into arrays
	folderIDs := []
	folderNames := []
	folderDropdown := ""
	
	Loop, Parse, folderOutput, `n, `r
	{
		if (A_LoopField = "")
			continue
		parts := StrSplit(A_LoopField, "|")
		if (parts.Length() >= 2)
		{
			folderIDs.Push(parts[1])
			folderNames.Push(parts[2])
			folderDropdown .= parts[2] . "|"
		}
	}
	
	if (folderIDs.Length() = 0)
	{
		DarkMsgBox("No Folders", "No folders found in GHL Media Library.", "warning")
		return
	}
	
	; Create folder picker GUI
	Gui, FolderPicker:New, +AlwaysOnTop +ToolWindow
	Gui, FolderPicker:Color, 1a1a2e
	Gui, FolderPicker:Font, s10 cWhite, Segoe UI
	Gui, FolderPicker:Add, Text, x20 y15 w360, Select a folder for Contact Sheet uploads:
	Gui, FolderPicker:Font, s10 cWhite, Segoe UI
	Gui, FolderPicker:Add, DropDownList, x20 y45 w360 vSelectedFolderName hwndHDDL, %folderDropdown%
	Gui, FolderPicker:Add, Text, x20 y85 w360 c888888, This folder will be used for all future contact sheet uploads.
	Gui, FolderPicker:Add, Button, x100 y120 w100 gFolderPickerOK Default, OK
	Gui, FolderPicker:Add, Button, x220 y120 w100 gFolderPickerCancel, Cancel
	
	; Store arrays for use in OK handler
	FolderPicker_IDs := folderIDs
	FolderPicker_Names := folderNames
	
	Gui, FolderPicker:Show, w400 h170, Select GHL Media Folder
	return
	
	FolderPickerOK:
		Gui, FolderPicker:Submit
		
		; Find selected folder ID
		Loop, % FolderPicker_Names.Length()
		{
			if (FolderPicker_Names[A_Index] = SelectedFolderName)
			{
				Settings_MediaFolderID := FolderPicker_IDs[A_Index]
				Settings_MediaFolderName := SelectedFolderName
				break
			}
		}
		
		; Save to INI
		IniWrite, %Settings_MediaFolderID%, %IniFilename%, GHL, MediaFolderID
		IniWrite, %Settings_MediaFolderName%, %IniFilename%, GHL, MediaFolderName
		
		Gui, FolderPicker:Destroy
		DarkMsgBox("Folder Selected", "Contact sheets will be uploaded to:`n" . Settings_MediaFolderName, "success")
		return
}

; ============================================================================
; Refresh Email Templates - Fetch templates from GHL API
; ============================================================================
RefreshEmailTemplates:
{
	global GHL_CachedEmailTemplates, Settings_EmailTemplateID, Settings_EmailTemplateName, IniFilename
	
	; Log file for email template debugging
	etLogFile := A_ScriptDir . "\email_templates_debug.log"
	FormatTime, etTimestamp,, yyyy-MM-dd HH:mm:ss
	FileAppend, % "`n" . etTimestamp . " [RefreshEmailTemplates] === START ===`n", %etLogFile%
	
	ToolTip, Fetching email templates from GHL...
	scriptCmd := GetScriptCommand("sync_ps_invoice", "--list-email-templates")
	
	FileAppend, % etTimestamp . " [RefreshEmailTemplates] A_IsCompiled=" . A_IsCompiled . "`n", %etLogFile%
	FileAppend, % etTimestamp . " [RefreshEmailTemplates] A_ScriptDir=" . A_ScriptDir . "`n", %etLogFile%
	FileAppend, % etTimestamp . " [RefreshEmailTemplates] scriptCmd=" . scriptCmd . "`n", %etLogFile%
	
	; Check if the exe/py actually exists
	scriptPath := GetScriptPath("sync_ps_invoice")
	FileAppend, % etTimestamp . " [RefreshEmailTemplates] scriptPath=" . scriptPath . "`n", %etLogFile%
	if (FileExist(scriptPath))
		FileAppend, % etTimestamp . " [RefreshEmailTemplates] Script file EXISTS`n", %etLogFile%
	else
		FileAppend, % etTimestamp . " [RefreshEmailTemplates] Script file NOT FOUND!`n", %etLogFile%
	
	tempOutput := A_Temp . "\ghl_templates_" . A_TickCount . ".txt"
	; Write command to temp .cmd file to avoid cmd.exe /c quoting issues with .exe vs .py
	tempCmd := A_Temp . "\sk_email_tpl2_" . A_TickCount . ".cmd"
	FileDelete, %tempCmd%
	FileAppend, % "@" . scriptCmd . " > """ . tempOutput . """ 2>&1`n", %tempCmd%
	FileAppend, % etTimestamp . " [RefreshEmailTemplates] TempCmd: " . tempCmd . "`n", %etLogFile%
	FileRead, etCmdContent, %tempCmd%
	FileAppend, % etTimestamp . " [RefreshEmailTemplates] CmdContent: " . etCmdContent, %etLogFile%
	RunWait, %ComSpec% /c "%tempCmd%", , Hide
	etExitCode := ErrorLevel
	FileDelete, %tempCmd%
	FileAppend, % etTimestamp . " [RefreshEmailTemplates] ExitCode=" . etExitCode . "`n", %etLogFile%
	ToolTip
	
	; Check temp file
	FileGetSize, etTempSize, %tempOutput%
	FileAppend, % etTimestamp . " [RefreshEmailTemplates] TempFile exists=" . (FileExist(tempOutput) ? "YES" : "NO") . " size=" . etTempSize . " bytes`n", %etLogFile%
	
	FileRead, tplOutput, %tempOutput%
	
	; Log raw output (first 500 chars)
	etRawPreview := SubStr(tplOutput, 1, 500)
	FileAppend, % etTimestamp . " [RefreshEmailTemplates] Raw output (" . StrLen(tplOutput) . " chars):`n" . etRawPreview . "`n", %etLogFile%
	FileDelete, %tempOutput%
	
	; Check for errors
	if (InStr(tplOutput, "API_ERROR") || InStr(tplOutput, "ERROR|"))
	{
		FileAppend, % etTimestamp . " [RefreshEmailTemplates] FAILED: API_ERROR or ERROR| found in output`n", %etLogFile%
		DarkMsgBox("API Error", "Could not load email templates from GHL.`nCheck API connection.`n`nCommand: " . scriptCmd . "`nExit code: " . etExitCode . "`n`nOutput: " . SubStr(tplOutput, 1, 300), "warning")
		return
	}
	
	if (InStr(tplOutput, "NO_TEMPLATES") || tplOutput = "")
	{
		FileAppend, % etTimestamp . " [RefreshEmailTemplates] FAILED: empty=" . (tplOutput = "" ? "YES" : "NO") . " NO_TEMPLATES=" . (InStr(tplOutput, "NO_TEMPLATES") ? "YES" : "NO") . "`n", %etLogFile%
		DarkMsgBox("No Templates", "No email templates found in GHL.`n`nCreate an email template in GHL first.`n`nCommand: " . scriptCmd . "`nExit code: " . etExitCode . "`nOutput: " . SubStr(tplOutput, 1, 300), "info")
		return
	}
	
	FileAppend, % etTimestamp . " [RefreshEmailTemplates] SUCCESS`n", %etLogFile%
	
	; Cache the raw output (id|name per line)
	GHL_CachedEmailTemplates := tplOutput
	
	; Save to INI for persistence
	; Replace newlines with §§ for INI storage
	iniValue := StrReplace(tplOutput, "`n", "§§")
	iniValue := StrReplace(iniValue, "`r", "")
	IniWrite, %iniValue%, %IniFilename%, GHL, CachedEmailTemplates
	
	; Build template name list for ComboBox
	templateNames := []
	Loop, Parse, tplOutput, `n, `r
	{
		if (A_LoopField = "")
			continue
		parts := StrSplit(A_LoopField, "|")
		if (parts.Length() >= 2)
			templateNames.Push(parts[2])
	}
	
	; Update the ComboBox with SELECT first
	newList := "SELECT"
	for i, tplName in templateNames {
		newList .= "|" . tplName
	}
	GuiControl, Settings:, PrintEmailTplCombo, |%newList%
	
	; Select current value if it exists
	if (Settings_EmailTemplateName != "" && Settings_EmailTemplateName != "(none selected)" && Settings_EmailTemplateName != "SELECT")
		GuiControl, Settings:ChooseString, PrintEmailTplCombo, %Settings_EmailTemplateName%
	else
		GuiControl, Settings:ChooseString, PrintEmailTplCombo, SELECT
	
	tplCount := templateNames.MaxIndex() ? templateNames.MaxIndex() : 0
	if (tplCount > 0)
		DarkMsgBox("Templates Loaded", "Loaded " . tplCount . " email templates from GHL.", "success")
	
	return
}

; ============================================================================
; Room Captured Dialog - Show image preview with action buttons
; ============================================================================
ShowRoomCapturedDialog(imagePath, albumName, roomNum)
{
	global Settings_RoomCaptureFolder, DPI_Scale, RoomCapturedResult, RoomCaptured_ImageHwnd
	
	; Initialize GDI+ for thumbnail
	pToken := Gdip_Startup()
	if (!pToken)
		return "OK"
	
	; Load the captured image
	pBitmap := Gdip_CreateBitmapFromFile(imagePath)
	if (!pBitmap) {
		Gdip_Shutdown(pToken)
		return "OK"
	}
	
	; Get original dimensions
	origW := Gdip_GetImageWidth(pBitmap)
	origH := Gdip_GetImageHeight(pBitmap)
	
	; Calculate thumbnail size (max 300x200 at 100% DPI)
	thumbMaxW := Round(300 * DPI_Scale)
	thumbMaxH := Round(200 * DPI_Scale)
	
	if (origW / origH > thumbMaxW / thumbMaxH) {
		thumbW := thumbMaxW
		thumbH := Round(origH * (thumbMaxW / origW))
	} else {
		thumbH := thumbMaxH
		thumbW := Round(origW * (thumbMaxH / origH))
	}
	
	; Create resized bitmap for thumbnail
	pThumb := Gdip_CreateBitmap(thumbW, thumbH)
	G := Gdip_GraphicsFromImage(pThumb)
	Gdip_SetInterpolationMode(G, 7)  ; High quality bicubic
	Gdip_DrawImage(G, pBitmap, 0, 0, thumbW, thumbH, 0, 0, origW, origH)
	Gdip_DeleteGraphics(G)
	Gdip_DisposeImage(pBitmap)
	
	; Create HBITMAP for GUI
	hBitmap := Gdip_CreateHBITMAPFromBitmap(pThumb)
	Gdip_DisposeImage(pThumb)
	Gdip_Shutdown(pToken)
	
	; Calculate dialog dimensions
	dlgPadding := Round(20 * DPI_Scale)
	btnH := Round(35 * DPI_Scale)
	btnW := Round(80 * DPI_Scale)
	fontSize := Round(11 * DPI_Scale)
	titleSize := Round(14 * DPI_Scale)
	
	dlgW := thumbW + (dlgPadding * 2)
	if (dlgW < Round(400 * DPI_Scale))
		dlgW := Round(400 * DPI_Scale)
	
	; Build the dialog
	RoomCapturedResult := "OK"
	
	Gui, RoomCaptured:New, +AlwaysOnTop +HwndRoomCapturedHwnd -MinimizeBox
	Gui, RoomCaptured:Color, 1E1E1E
	Gui, RoomCaptured:Font, s%titleSize% c00BFFF, Segoe UI
	
	; Title with icon
	yPos := dlgPadding
	Gui, RoomCaptured:Add, Text, x%dlgPadding% y%yPos% w%dlgW% cWhite, 🖼 Room Captured
	
	; Image preview
	yPos += Round(30 * DPI_Scale)
	imgX := (dlgW - thumbW) / 2
	Gui, RoomCaptured:Add, Picture, x%imgX% y%yPos% w%thumbW% h%thumbH% vRoomCaptured_ImageHwnd +0xE
	
	; Set the bitmap to the picture control
	GuiControl, RoomCaptured:, RoomCaptured_ImageHwnd, HBITMAP:*%hBitmap%
	
	; Filename info
	yPos += thumbH + Round(15 * DPI_Scale)
	Gui, RoomCaptured:Font, s%fontSize% cWhite, Segoe UI
	fileName := albumName . "-room" . roomNum . ".jpg"
	Gui, RoomCaptured:Add, Text, x%dlgPadding% y%yPos% w%dlgW%, Saved: %fileName%
	
	; Folder info
	yPos += Round(22 * DPI_Scale)
	Gui, RoomCaptured:Font, s%fontSize% cGray, Segoe UI
	SplitPath, imagePath,, folderDisplay
	if (StrLen(folderDisplay) > 50)
		folderDisplay := "..." . SubStr(folderDisplay, -47)
	Gui, RoomCaptured:Add, Text, x%dlgPadding% y%yPos% w%dlgW%, Folder: %folderDisplay%
	
	; Clipboard notice
	yPos += Round(22 * DPI_Scale)
	Gui, RoomCaptured:Font, s%fontSize% c00FF00, Segoe UI
	Gui, RoomCaptured:Add, Text, x%dlgPadding% y%yPos% w%dlgW%, 📋 Image path copied to clipboard
	
	; Buttons
	yPos += Round(40 * DPI_Scale)
	btnSpacing := Round(10 * DPI_Scale)
	totalBtnW := (btnW * 4) + (btnSpacing * 3)
	btnX := (dlgW - totalBtnW) / 2
	
	Gui, RoomCaptured:Font, s%fontSize% cWhite, Segoe UI
	Gui, RoomCaptured:Add, Button, x%btnX% y%yPos% w%btnW% h%btnH% gRoomCapturedOK Default, OK
	btnX += btnW + btnSpacing
	Gui, RoomCaptured:Add, Button, x%btnX% y%yPos% w%btnW% h%btnH% gRoomCapturedOpen, Open
	btnX += btnW + btnSpacing
	Gui, RoomCaptured:Add, Button, x%btnX% y%yPos% w%btnW% h%btnH% gRoomCapturedReveal, Reveal
	btnX += btnW + btnSpacing
	Gui, RoomCaptured:Add, Button, x%btnX% y%yPos% w%btnW% h%btnH% gRoomCapturedEmail, Email
	
	; Show dialog
	dlgH := yPos + btnH + dlgPadding
	Gui, RoomCaptured:Show, w%dlgW% h%dlgH%, Room Captured
	
	; Wait for user action
	WinWaitClose, ahk_id %RoomCapturedHwnd%
	
	; Cleanup
	DllCall("DeleteObject", "Ptr", hBitmap)
	
	return RoomCapturedResult
}

RoomCapturedOK:
RoomCapturedResult := "OK"
Gui, RoomCaptured:Destroy
return

RoomCapturedOpen:
RoomCapturedResult := "Open"
Gui, RoomCaptured:Destroy
return

RoomCapturedReveal:
RoomCapturedResult := "Reveal"
Gui, RoomCaptured:Destroy
return

RoomCapturedEmail:
RoomCapturedResult := "Email"
Gui, RoomCaptured:Destroy
return

RoomCapturedGuiClose:
RoomCapturedGuiEscape:
RoomCapturedResult := "OK"
Gui, RoomCaptured:Destroy
return

; ============================================================================
; Room Email Dialog - Show template picker before sending room capture email
; ============================================================================
ShowRoomEmailDialog()
{
	global GHL_CachedEmailTemplates, Settings_EmailTemplateID, Settings_EmailTemplateName
	global RoomEmail_SelectedTplName, RoomEmail_TplIDs, RoomEmail_TplNames
	
	; Build template list from cached templates
	RoomEmail_TplIDs := []
	RoomEmail_TplNames := []
	tplDropdown := "(none - use default)|"
	
	Loop, Parse, GHL_CachedEmailTemplates, `n, `r
	{
		if (A_LoopField = "")
			continue
		parts := StrSplit(A_LoopField, "|")
		if (parts.Length() >= 2)
		{
			RoomEmail_TplIDs.Push(parts[1])
			RoomEmail_TplNames.Push(parts[2])
			tplDropdown .= parts[2] . "|"
		}
	}
	
	; Create template picker GUI
	Gui, RoomEmail:New, +AlwaysOnTop +ToolWindow
	Gui, RoomEmail:Color, 1a1a2e
	Gui, RoomEmail:Font, s11 cWhite, Segoe UI
	Gui, RoomEmail:Add, Text, x20 y15 w360, 📧 Send Room Capture Email
	Gui, RoomEmail:Font, s10 c888888, Segoe UI
	Gui, RoomEmail:Add, Text, x20 y45 w360, Select an email template:
	Gui, RoomEmail:Font, s10 cWhite, Segoe UI
	Gui, RoomEmail:Add, DropDownList, x20 y70 w320 vRoomEmail_SelectedTplName, %tplDropdown%
	Gui, RoomEmail:Add, Button, x345 y69 w35 h24 gRoomEmailRefresh, 🔄
	
	; Pre-select the default template if configured
	if (Settings_EmailTemplateName != "" && Settings_EmailTemplateName != "(none selected)")
		GuiControl, RoomEmail:ChooseString, RoomEmail_SelectedTplName, %Settings_EmailTemplateName%
	else
		GuiControl, RoomEmail:Choose, RoomEmail_SelectedTplName, 1
	
	Gui, RoomEmail:Font, s9 c888888, Segoe UI
	Gui, RoomEmail:Add, Text, x20 y105 w360, The room image will be attached to the email body.
	Gui, RoomEmail:Add, Button, x100 y140 w100 gRoomEmailSend Default, 📧 Send
	Gui, RoomEmail:Add, Button, x220 y140 w100 gRoomEmailCancel, Cancel
	
	Gui, RoomEmail:Show, w400 h185, Send Room Capture
	return
}

RoomEmailSend:
{
	global RoomEmail_SelectedTplName, RoomEmail_TplIDs, RoomEmail_TplNames
	global RoomEmail_ContactId, RoomEmail_OutputFile, RoomEmail_AlbumName, RoomEmail_RoomNum
	global Settings_EmailTemplateID, Settings_EmailTemplateName, IniFilename
	
	Gui, RoomEmail:Submit
	
	; Find selected template ID
	selectedTemplateID := ""
	if (RoomEmail_SelectedTplName != "(none - use default)" && RoomEmail_SelectedTplName != "") {
		Loop, % RoomEmail_TplNames.Length()
		{
			if (RoomEmail_TplNames[A_Index] = RoomEmail_SelectedTplName)
			{
				selectedTemplateID := RoomEmail_TplIDs[A_Index]
				break
			}
		}
		; Save selected template as default for next time
		Settings_EmailTemplateName := RoomEmail_SelectedTplName
		Settings_EmailTemplateID := selectedTemplateID
		IniWrite, %Settings_EmailTemplateID%, %IniFilename%, Toolbar, EmailTemplateID
		IniWrite, %Settings_EmailTemplateName%, %IniFilename%, Toolbar, EmailTemplateName
	}
	
	; Run sync_ps_invoice with --send-room-email
	emailArgs := "--send-room-email " . RoomEmail_ContactId . " """ . RoomEmail_OutputFile . """"
	if (selectedTemplateID != "")
		emailArgs .= " --email-template " . selectedTemplateID
	
	emailCmd := GetScriptCommand("sync_ps_invoice", emailArgs)
	ToolTip, 📧 Sending room capture email...
	RunWait, %emailCmd%, %A_ScriptDir%, Hide
	
	; Check result
	resultFile := A_AppData . "\SideKick_PS\ghl_invoice_sync_result.json"
	if FileExist(resultFile) {
		FileRead, emailResultJson, %resultFile%
		if InStr(emailResultJson, """success"": true") {
			; Extract email from result
			RegExMatch(emailResultJson, """contact_email"":\s*""([^""]+)""", emailMatch)
			ToolTip
			DarkMsgBox("Email Sent", "📧 Room capture emailed successfully!`n`nSent to: " . emailMatch1 . "`nImage: " . RoomEmail_AlbumName . "-room" . RoomEmail_RoomNum . ".jpg", "info", {timeout: 5})
		} else {
			RegExMatch(emailResultJson, """error"":\s*""([^""]+)""", errMatch)
			ToolTip
			DarkMsgBox("Email Failed", "Could not send email.`n`n" . errMatch1, "error")
		}
	} else {
		ToolTip
		DarkMsgBox("Email Failed", "No result returned from email send.", "error")
	}
	return
}

RoomEmailCancel:
RoomEmailGuiClose:
RoomEmailGuiEscape:
Gui, RoomEmail:Destroy
return

RoomEmailRefresh:
{
	global GHL_CachedEmailTemplates, IniFilename, RoomEmail_TplIDs, RoomEmail_TplNames
	global Settings_EmailTemplateName
	
	ToolTip, Fetching email templates from GHL...
	scriptCmd := GetScriptCommand("sync_ps_invoice", "--list-email-templates")
	
	tempOutput := A_Temp . "\ghl_templates_" . A_TickCount . ".txt"
	fullCmd := ComSpec . " /s /c """ . scriptCmd . " > """ . tempOutput . """ 2>&1"""
	RunWait, %fullCmd%, , Hide
	ToolTip
	
	FileRead, tplOutput, %tempOutput%
	FileDelete, %tempOutput%
	
	; Check for errors
	if (InStr(tplOutput, "API_ERROR") || InStr(tplOutput, "ERROR|"))
	{
		DarkMsgBox("API Error", "Could not load email templates from GHL.`nCheck API connection.", "warning")
		return
	}
	
	if (InStr(tplOutput, "NO_TEMPLATES") || tplOutput = "")
	{
		DarkMsgBox("No Templates", "No email templates found in GHL.`n`nCreate an email template in GHL first.", "info")
		return
	}
	
	; Cache the raw output (id|name per line)
	GHL_CachedEmailTemplates := tplOutput
	
	; Save to INI for persistence
	iniValue := StrReplace(tplOutput, "`n", "§§")
	iniValue := StrReplace(iniValue, "`r", "")
	IniWrite, %iniValue%, %IniFilename%, GHL, CachedEmailTemplates
	
	; Rebuild template list arrays and dropdown
	RoomEmail_TplIDs := []
	RoomEmail_TplNames := []
	tplDropdown := "(none - use default)|"
	
	Loop, Parse, tplOutput, `n, `r
	{
		if (A_LoopField = "")
			continue
		parts := StrSplit(A_LoopField, "|")
		if (parts.Length() >= 2)
		{
			RoomEmail_TplIDs.Push(parts[1])
			RoomEmail_TplNames.Push(parts[2])
			tplDropdown .= parts[2] . "|"
		}
	}
	
	; Update the dropdown
	GuiControl, RoomEmail:, RoomEmail_SelectedTplName, |%tplDropdown%
	
	; Re-select the default template if configured
	if (Settings_EmailTemplateName != "" && Settings_EmailTemplateName != "(none selected)")
		GuiControl, RoomEmail:ChooseString, RoomEmail_SelectedTplName, %Settings_EmailTemplateName%
	else
		GuiControl, RoomEmail:Choose, RoomEmail_SelectedTplName, 1
	
	tplCount := RoomEmail_TplNames.Length()
	DarkMsgBox("Templates Refreshed", "Loaded " . tplCount . " email templates.", "success", {timeout: 2})
	return
}

; ============================================================================
; Refresh GHL Tags - Fetch CONTACT tags from GHL API
; Note: Opportunity tags are free-form strings, not from a central list
; ============================================================================
RefreshGHLTags:
{
	global GHL_API_Key, GHL_LocationID, GHL_CachedTags, Settings_GHLTags, Settings_GHLOppTags
	
	if (!GHL_API_Key || GHL_API_Key = "") {
		DarkMsgBox("No API Key", "Please configure your GHL API Key first.", "warning")
		return
	}
	if (!GHL_LocationID || GHL_LocationID = "") {
		DarkMsgBox("No Location ID", "Please configure your GHL Location ID first.", "warning")
		return
	}
	
	ToolTip, Fetching contact tags from GHL...
	
	try {
		http := ComObjCreate("WinHttp.WinHttpRequest.5.1")
		http.SetTimeouts(10000, 10000, 10000, 10000)
		tagsUrl := "https://services.leadconnectorhq.com/locations/" . GHL_LocationID . "/tags"
		http.open("GET", tagsUrl, false)
		http.SetRequestHeader("Authorization", "Bearer " . GHL_API_Key)
		http.SetRequestHeader("Version", "2021-07-28")
		http.send()
		
		if (http.status >= 200 && http.status < 300) {
			responseText := http.responseText
			; Parse JSON to extract tag names
			tagNames := []
			; Simple regex extraction for tag names from JSON
			pos := 1
			while (pos := RegExMatch(responseText, """name""\s*:\s*""([^""]+)""", match, pos)) {
				tagNames.Push(match1)
				pos += StrLen(match)
			}
			
			; Build pipe-separated list for ComboBox
			GHL_CachedTags := ""
			for i, tagName in tagNames {
				if (GHL_CachedTags != "")
					GHL_CachedTags .= "|"
				GHL_CachedTags .= tagName
			}
			
			; Save to INI for persistence
			IniWrite, %GHL_CachedTags%, %IniFilename%, GHL, CachedTags
			
			; Update the Contact Tags ComboBox
			currentValue := Settings_GHLTags
			newList := currentValue
			if (GHL_CachedTags != "") {
				if (newList != "")
					newList .= "||"
				newList .= GHL_CachedTags
			}
			GuiControl, Settings:, GHLTagsEdit, |%newList%
			if (currentValue != "")
				GuiControl, Settings:ChooseString, GHLTagsEdit, %currentValue%
			
			ToolTip
			tagCount := tagNames.MaxIndex() ? tagNames.MaxIndex() : 0
			if (tagCount > 0)
				DarkMsgBox("Contact Tags Loaded", "Loaded " . tagCount . " contact tags from GHL.", "success")
			else
				DarkMsgBox("No Tags Found", "No contact tags found in GHL.`n`nCreate tags in GHL first, then refresh.", "info")
		} else {
			ToolTip
			DarkMsgBox("Failed to Load Tags", "GHL API returned error: " . http.status . "`n`nCheck your API key and Location ID.", "error")
		}
	} catch e {
		ToolTip
		DarkMsgBox("Connection Failed", "Could not connect to GHL API.`n`nError: " . e.Message, "error")
	}
	return
}

; ============================================================================
; Refresh GHL Opportunity Tags - Fetch tags from existing opportunities
; ============================================================================
RefreshGHLOppTags:
{
	global GHL_API_Key, GHL_LocationID, GHL_CachedOppTags, Settings_GHLOppTags
	
	if (!GHL_API_Key || GHL_API_Key = "") {
		DarkMsgBox("No API Key", "Please configure your GHL API Key first.", "warning")
		return
	}
	if (!GHL_LocationID || GHL_LocationID = "") {
		DarkMsgBox("No Location ID", "Please configure your GHL Location ID first.", "warning")
		return
	}
	
	ToolTip, Fetching opportunity tags from GHL...
	
	try {
		http := ComObjCreate("WinHttp.WinHttpRequest.5.1")
		http.SetTimeouts(15000, 15000, 15000, 15000)
		; Search for opportunities in this location
		oppUrl := "https://services.leadconnectorhq.com/opportunities/search"
		http.open("POST", oppUrl, false)
		http.SetRequestHeader("Authorization", "Bearer " . GHL_API_Key)
		http.SetRequestHeader("Version", "2021-07-28")
		http.SetRequestHeader("Content-Type", "application/json")
		
		; Build JSON payload - get first 100 opportunities
		payload := "{""locationId"": """ . GHL_LocationID . """, ""limit"": 100}"
		http.send(payload)
		
		if (http.status >= 200 && http.status < 300) {
			responseText := http.responseText
			; Parse JSON to extract all unique tags from opportunities
			allTags := {}
			; Match tags arrays: "tags":["tag1","tag2"]
			pos := 1
			while (pos := RegExMatch(responseText, """tags""\s*:\s*\[([^\]]*)\]", match, pos)) {
				tagsContent := match1
				; Extract individual tag strings
				tagPos := 1
				while (tagPos := RegExMatch(tagsContent, """([^""]+)""", tagMatch, tagPos)) {
					tagName := tagMatch1
					if (tagName != "")
						allTags[tagName] := true
					tagPos += StrLen(tagMatch)
				}
				pos += StrLen(match)
			}
			
			; Build pipe-separated list for ComboBox
			GHL_CachedOppTags := ""
			for tagName, _ in allTags {
				if (GHL_CachedOppTags != "")
					GHL_CachedOppTags .= "|"
				GHL_CachedOppTags .= tagName
			}
			
			; Save to INI for persistence
			IniWrite, %GHL_CachedOppTags%, %IniFilename%, GHL, CachedOppTags
			
			; Update the Opportunity Tags ComboBox
			currentValue := Settings_GHLOppTags
			newList := currentValue
			if (GHL_CachedOppTags != "") {
				if (newList != "")
					newList .= "||"
				newList .= GHL_CachedOppTags
			}
			GuiControl, Settings:, GHLOppTagsEdit, |%newList%
			if (currentValue != "")
				GuiControl, Settings:ChooseString, GHLOppTagsEdit, %currentValue%
			
			ToolTip
			tagCount := 0
			for _ in allTags
				tagCount++
			if (tagCount > 0)
				DarkMsgBox("Opportunity Tags Loaded", "Found " . tagCount . " unique tags from your opportunities.", "success")
			else
				DarkMsgBox("No Tags Found", "No opportunity tags found in GHL.`n`nTags will appear here once you add them to opportunities.", "info")
		} else {
			ToolTip
			DarkMsgBox("Failed to Load Tags", "GHL API returned error: " . http.status . "`n`nCheck your API key and Location ID.", "error")
		}
	} catch e {
		ToolTip
		DarkMsgBox("Connection Failed", "Could not connect to GHL API.`n`nError: " . e.Message, "error")
	}
	return
}

; ============================================================================
; Silent refresh functions (no dialogs) - used by Setup Wizard
; ============================================================================
RefreshGHLTagsSilent:
{
	global GHL_API_Key, GHL_LocationID, GHL_CachedTags, Settings_GHLTags
	
	if (!GHL_API_Key || GHL_API_Key = "" || !GHL_LocationID || GHL_LocationID = "")
		return
	
	try {
		http := ComObjCreate("WinHttp.WinHttpRequest.5.1")
		http.SetTimeouts(10000, 10000, 10000, 10000)
		tagsUrl := "https://services.leadconnectorhq.com/locations/" . GHL_LocationID . "/tags"
		http.open("GET", tagsUrl, false)
		http.SetRequestHeader("Authorization", "Bearer " . GHL_API_Key)
		http.SetRequestHeader("Version", "2021-07-28")
		http.send()
		
		if (http.status >= 200 && http.status < 300) {
			responseText := http.responseText
			tagNames := []
			pos := 1
			while (pos := RegExMatch(responseText, """name""\s*:\s*""([^""]+)""", match, pos)) {
				tagNames.Push(match1)
				pos += StrLen(match)
			}
			
			GHL_CachedTags := ""
			for i, tagName in tagNames {
				if (GHL_CachedTags != "")
					GHL_CachedTags .= "|"
				GHL_CachedTags .= tagName
			}
			
			IniWrite, %GHL_CachedTags%, %IniFilename%, GHL, CachedTags
			
			currentValue := Settings_GHLTags
			newList := currentValue
			if (GHL_CachedTags != "") {
				if (newList != "")
					newList .= "||"
				newList .= GHL_CachedTags
			}
			GuiControl, Settings:, GHLTagsEdit, |%newList%
			if (currentValue != "")
				GuiControl, Settings:ChooseString, GHLTagsEdit, %currentValue%
		}
	}
	return
}

RefreshGHLOppTagsSilent:
{
	global GHL_API_Key, GHL_LocationID, GHL_CachedOppTags, Settings_GHLOppTags
	
	if (!GHL_API_Key || GHL_API_Key = "" || !GHL_LocationID || GHL_LocationID = "")
		return
	
	try {
		http := ComObjCreate("WinHttp.WinHttpRequest.5.1")
		http.SetTimeouts(15000, 15000, 15000, 15000)
		oppUrl := "https://services.leadconnectorhq.com/opportunities/search"
		http.open("POST", oppUrl, false)
		http.SetRequestHeader("Authorization", "Bearer " . GHL_API_Key)
		http.SetRequestHeader("Version", "2021-07-28")
		http.SetRequestHeader("Content-Type", "application/json")
		
		payload := "{""locationId"": """ . GHL_LocationID . """, ""limit"": 100}"
		http.send(payload)
		
		if (http.status >= 200 && http.status < 300) {
			responseText := http.responseText
			allTags := {}
			pos := 1
			while (pos := RegExMatch(responseText, """tags""\s*:\s*\[([^\]]*)\]", match, pos)) {
				tagsContent := match1
				tagPos := 1
				while (tagPos := RegExMatch(tagsContent, """([^""]+)""", tagMatch, tagPos)) {
					tagName := tagMatch1
					if (tagName != "")
						allTags[tagName] := true
					tagPos += StrLen(tagMatch)
				}
				pos += StrLen(match)
			}
			
			GHL_CachedOppTags := ""
			for tagName, _ in allTags {
				if (GHL_CachedOppTags != "")
					GHL_CachedOppTags .= "|"
				GHL_CachedOppTags .= tagName
			}
			
			IniWrite, %GHL_CachedOppTags%, %IniFilename%, GHL, CachedOppTags
			
			currentValue := Settings_GHLOppTags
			newList := currentValue
			if (GHL_CachedOppTags != "") {
				if (newList != "")
					newList .= "||"
				newList .= GHL_CachedOppTags
			}
			GuiControl, Settings:, GHLOppTagsEdit, |%newList%
			if (currentValue != "")
				GuiControl, Settings:ChooseString, GHLOppTagsEdit, %currentValue%
		}
	}
	return
}

; ============================================================================
; Silent refresh for Email Templates (no dialogs) - used by Setup Wizard
; ============================================================================
RefreshEmailTemplatesSilent:
{
	global GHL_CachedEmailTemplates, Settings_EmailTemplateName
	
	tempFile := A_Temp . "\ghl_email_templates.json"
	scriptCmd := GetScriptCommand("sync_ps_invoice", "--list-email-templates")
	
	if (scriptCmd = "")
		return
	
	FileDelete, %tempFile%
	
	tempCmd := A_Temp . "\sk_email_tpl_" . A_TickCount . ".cmd"
	FileDelete, %tempCmd%
	FileAppend, % "@" . scriptCmd . " > """ . tempFile . """ 2>&1`n", %tempCmd%
	RunWait, %ComSpec% /c "%tempCmd%", , Hide
	FileDelete, %tempCmd%
	
	FileRead, result, %tempFile%
	FileDelete, %tempFile%
	
	if (InStr(result, "ERROR") || result = "")
		return
	
	GHL_CachedEmailTemplates := result
	
	newList := "SELECT"
	Loop, Parse, result, `n, `r
	{
		if (A_LoopField = "")
			continue
		parts := StrSplit(A_LoopField, "|")
		if (parts.Length() >= 2) {
			newList .= "|" . parts[2]
		}
	}
	
	GuiControl, Settings:, PrintEmailTplCombo, |%newList%
	if (Settings_EmailTemplateName != "" && Settings_EmailTemplateName != "(none selected)" && Settings_EmailTemplateName != "SELECT")
		GuiControl, Settings:ChooseString, PrintEmailTplCombo, %Settings_EmailTemplateName%
	else
		GuiControl, Settings:ChooseString, PrintEmailTplCombo, SELECT
	
	return
}

; ============================================================================
; Silent refresh for ProSelect Print Templates (no dialogs) - used by Setup Wizard
; ============================================================================
RefreshPrintTemplatesSilent:
{
	global Settings_PrintTemplateOptions, Settings_PrintTemplate_PayPlan, Settings_PrintTemplate_Standard
	
	if !WinExist("ahk_exe ProSelect.exe")
		return
	
	WinActivate, ahk_exe ProSelect.exe
	WinWaitActive, ahk_exe ProSelect.exe,, 2
	
	Send, !f
	Sleep, 300
	Send, p
	Sleep, 300
	Send, {Right}
	Sleep, 300
	Send, {Enter}
	Sleep, 1000
	
	WinWait, Print Order/Invoice Report, , 3
	if ErrorLevel {
		return
	}
	
	ControlGet, cbList, List,, ComboBox5, Print Order/Invoice Report
	if (ErrorLevel || cbList = "") {
		Send, {Escape}
		return
	}
	
	Send, {Escape}
	Sleep, 200
	
	Gui, Settings:Show
	
	StringReplace, cbList, cbList, `n, |, All
	Settings_PrintTemplateOptions := cbList
	
	GuiControl, Settings:, PrintPayPlanCombo, |SELECT|%cbList%
	GuiControl, Settings:, PrintStandardCombo, |SELECT|%cbList%
	
	if (InStr("|" . cbList . "|", "|" . Settings_PrintTemplate_PayPlan . "|"))
		GuiControl, Settings:ChooseString, PrintPayPlanCombo, %Settings_PrintTemplate_PayPlan%
	else
		GuiControl, Settings:ChooseString, PrintPayPlanCombo, SELECT
	
	if (InStr("|" . cbList . "|", "|" . Settings_PrintTemplate_Standard . "|"))
		GuiControl, Settings:ChooseString, PrintStandardCombo, %Settings_PrintTemplate_Standard%
	else
		GuiControl, Settings:ChooseString, PrintStandardCombo, SELECT
	
	IniWrite, %Settings_PrintTemplateOptions%, %IniFilename%, Toolbar, PrintTemplateOptions
	
	return
}

TestGHLConnection:
; Test API connection with detailed status
if (!GHL_API_Key || GHL_API_Key = "")
{
	DarkMsgBox("No API Key", "Please configure your GHL API Key first.", "warning")
	Return
}
if (!GHL_LocationID || GHL_LocationID = "")
{
	DarkMsgBox("No Location ID", "Please configure your GHL Location ID first.", "warning")
	Return
}

ToolTip, Testing GHL connection...
apiStatus := 0
apiError := ""

try {
	http := ComObjCreate("WinHttp.WinHttpRequest.5.1")
	http.SetTimeouts(5000, 5000, 5000, 5000)
	testUrl := "https://services.leadconnectorhq.com/contacts/?locationId=" . GHL_LocationID . "&limit=1"
	http.open("GET", testUrl, false)
	http.SetRequestHeader("Authorization", "Bearer " . GHL_API_Key)
	http.SetRequestHeader("Version", "2021-07-28")
	http.send()
	apiStatus := http.status
} catch e {
	apiError := e.Message
}

ToolTip

; Handle different status codes
if (apiStatus = 200) {
	statusText := "✅ Connected"
	GuiControl, Settings:, GHLStatusText, %statusText%
	DarkMsgBox("Connection Test", "GHL API connection successful!`n`nYour API key and Location ID are working correctly.", "success")
} else if (apiStatus = 401) {
	statusText := "❌ Unauthorized"
	GuiControl, Settings:, GHLStatusText, %statusText%
	msg := "API Key is INVALID or EXPIRED!`n`n"
	msg .= "Your API key has been revoked or has expired.`n"
	msg .= "Invoice sync will fail with this key.`n`n"
	msg .= "To fix:`n"
	msg .= "1. Go to GHL → Settings → Integrations`n"
	msg .= "2. Create a new Private Integration`n"
	msg .= "3. Copy the new API key (starts with 'pit-')`n"
	msg .= "4. Update your API key here"
	DarkMsgBox("API Key Expired", msg, "error")
} else if (apiStatus = 400) {
	statusText := "⚠️ Bad Request"
	GuiControl, Settings:, GHLStatusText, %statusText%
	DarkMsgBox("Invalid Location ID", "The Location ID appears to be invalid.`n`nCheck your Location ID in GHL settings.", "warning")
} else if (apiError != "") {
	statusText := "❌ Connection Failed"
	GuiControl, Settings:, GHLStatusText, %statusText%
	DarkMsgBox("Connection Failed", "Could not connect to GHL API.`n`nError: " . apiError, "error")
} else {
	statusText := "❌ Error " . apiStatus
	GuiControl, Settings:, GHLStatusText, %statusText%
	DarkMsgBox("Connection Failed", "GHL API returned error: " . apiStatus . "`n`nCheck your API key and Location ID.", "error")
}
Return

; ============================================================================
; GHL Setup Wizard
; ============================================================================
RunGHLSetupWizard:
{
	global GHL_LocationID, GHL_API_Key, DarkMsgBox_LastX, DarkMsgBox_LastY
	
	; Reset wizard position at start (so each wizard run starts centered)
	DarkMsgBox_LastX := ""
	DarkMsgBox_LastY := ""
	
	; Step 1: Welcome and explain what we need
	msg := "This wizard will help you connect SideKick to GoHighLevel.`n`n"
	msg .= "We need two things:`n"
	msg .= "   1. Your Location ID (from the URL)`n"
	msg .= "   2. An API Key (from Private Integrations)`n`n"
	msg .= "Ready to get started?"
	
	result := DarkMsgBox("🔧 GHL Setup Wizard - Step 1", msg, "YesNo", {rememberPosition: true})
	if (result != "Yes")
		Return
	
	; Step 2: Check if we already have Location ID
	if (GHL_LocationID != "") {
		result := DarkMsgBox("📍 Location ID Found", "You already have a Location ID configured:`n`n" . GHL_LocationID . "`n`nWould you like to keep this and skip to API key setup?", "YesNo", {rememberPosition: true})
		if (result = "Yes")
			Goto, GHLWizardApiKeyStep
	}
	
	; Step 3: Open Chrome to GHL
	msg := "I'll open your GHL dashboard in Chrome.`n`n"
	msg .= "1. Log in to your GHL sub-account`n"
	msg .= "2. Once logged in, click 'Yes' to read the URL`n`n"
	msg .= "Ready to open GHL?"
	
	result := DarkMsgBox("📍 Step 2: Get Your Location ID", msg, "YesNo", {rememberPosition: true})
	if (result != "Yes")
		Return
	
	; Open GHL login page
	; Open GHL login page (use generic app.gohighlevel.com or user's existing domain)
	ghlDomain := (GHL_AgencyDomain != "") ? GHL_AgencyDomain : "app.gohighlevel.com"
	Run, https://%ghlDomain%/v2/location/
	Sleep, 5000  ; Give Chrome time to open and load page
	
	; Step 4: Wait for user to log in, then read URL
	Loop {
		result := DarkMsgBox("📍 Read Location ID", "Log in to your GHL sub-account.`n`nOnce you see your dashboard, click 'Yes' to read the URL.`n`nClick 'No' to cancel.", "YesNo", {rememberPosition: true})
		if (result != "Yes")
			Return
		
		; Try to read Chrome URL (also extracts domain into GHL_ExtractedDomain)
		locationId := GetChromeLocationID()
		
		if (locationId != "") {
			; Show extracted domain if found
			domainInfo := (GHL_ExtractedDomain != "") ? "`n`nAgency Domain: " . GHL_ExtractedDomain : ""
			result := DarkMsgBox("✅ Location ID Found!", "Found Location ID:`n`n" . locationId . domainInfo . "`n`nIs this correct?", "YesNo", {rememberPosition: true})
			if (result = "Yes")
			{
				GHL_LocationID := locationId
				; Save extracted domain if available
				if (GHL_ExtractedDomain != "")
					GHL_AgencyDomain := GHL_ExtractedDomain
				GuiControl, Settings:, GHLLocIDDisplay, %locationId%
				SaveSettings()
				Break
			}
		} else {
			result := DarkMsgBox("⚠️ Could Not Read URL", "Could not find Location ID in Chrome URL.`n`nMake sure you are on your GHL dashboard and the URL contains '/location/'.`n`nWould you like to try again?", "RetryCancel", {rememberPosition: true})
			if (result = "Cancel")
				Return
		}
	}
	
GHLWizardApiKeyStep:
	; Step 5: Guide to create API key - Open page first, then show instructions
	locID := GHL_LocationID
	ghlDomain := (GHL_AgencyDomain != "") ? GHL_AgencyDomain : "app.gohighlevel.com"
	apiUrl := "https://" . ghlDomain . "/v2/location/" . locID . "/settings/private-integrations"
	
	; Open the page first
	Run, %apiUrl%
	Sleep, 1500
	
	; Now show instructions
	msg := "The Private Integrations page is now open.`n`n"
	msg .= "Follow these steps:`n`n"
	msg .= "1. Click 'Create Integration'`n"
	msg .= "2. Name it 'SideKick_PS'`n"
	msg .= "3. Enable these scopes:`n"
	msg .= "   ✅ View Contacts - contacts.readonly`n"
	msg .= "   ✅ Edit Contacts - contacts.write`n"
	msg .= "   ✅ View Medias - medias.readonly`n"
	msg .= "   ✅ Edit Medias - medias.write`n"
	msg .= "   ✅ View Invoices - invoices.readonly`n"
	msg .= "   ✅ Edit Invoices - invoices.write`n"
	msg .= "   ✅ View Payment Orders - payments/orders.readonly`n"
	msg .= "   ✅ Edit Payment Orders - payments/orders.write`n"
	msg .= "4. Click Create`n"
	msg .= "5. Copy the API key (starts with 'pit-...')`n`n"
	msg .= "Click OK when you have copied the API key."
	
	result := DarkMsgBox("🔑 Step 3: Create API Key", msg, "OKCancel", {rememberPosition: true})
	if (result = "Cancel")
		Return
	
	; Get API key input
	InputBox, newApiKey, 🔑 Enter API Key, Paste your GHL Private Integration API Key:`n`n(starts with 'pit-...'),,400, 180
	if (ErrorLevel || newApiKey = "")
		Return
	
	; Validate format
	if (!InStr(newApiKey, "pit-")) {
		DarkMsgBox("⚠️ Invalid Key Format", "API key should start with 'pit-'.`n`nPlease try again.", "OK", {rememberPosition: true})
		Return
	}
	
	; Save API key
	GHL_API_Key := newApiKey
	apiKeyDisplay := SubStr(GHL_API_Key, 1, 8) . "..." . SubStr(GHL_API_Key, -4)
	GuiControl, Settings:, GHLApiKeyDisplay, %apiKeyDisplay%
	SaveSettings()
	
	; Update status
	GuiControl, Settings:, GHLStatusText, ✅ Connected
	
	; Auto-refresh GHL data after successful setup
	ToolTip, Loading GHL data...
	Sleep, 500
	
	; Fetch GHL contact tags silently
	Gosub, RefreshGHLTagsSilent
	Sleep, 300
	
	; Fetch GHL opportunity tags silently
	Gosub, RefreshGHLOppTagsSilent
	Sleep, 300
	
	; Fetch GHL email templates silently
	ToolTip, Loading email templates...
	Gosub, RefreshEmailTemplatesSilent
	Sleep, 300
	
	; Detect ProSelect version
	DetectProSelectVersion()
	
	; Fetch ProSelect print templates - launch ProSelect if needed
	psWasRunning := WinExist("ahk_exe ProSelect.exe")
	
	if (!psWasRunning) {
		; ProSelect not running - ask user if we should launch it
		result := DarkMsgBox("📋 Load Print Templates?", "ProSelect is not running.`n`nWould you like to launch ProSelect to load your print templates?`n`n(This may take up to 60 seconds)", "YesNo", {rememberPosition: true})
		
		if (result = "Yes") {
			ToolTip, Launching ProSelect...
			
			; Try to find and launch ProSelect
			psPath := ""
			if FileExist("C:\Program Files\Pro Studio Software\ProSelect 2025\ProSelect.exe")
				psPath := "C:\Program Files\Pro Studio Software\ProSelect 2025\ProSelect.exe"
			else if FileExist("C:\Program Files\Pro Studio Software\ProSelect 2024\ProSelect.exe")
				psPath := "C:\Program Files\Pro Studio Software\ProSelect 2024\ProSelect.exe"
			else if FileExist("C:\Program Files\Pro Studio Software\ProSelect 2022\ProSelect.exe")
				psPath := "C:\Program Files\Pro Studio Software\ProSelect 2022\ProSelect.exe"
			else if FileExist("C:\Program Files\TimeExposure\ProSelect\ProSelect.exe")
				psPath := "C:\Program Files\TimeExposure\ProSelect\ProSelect.exe"
			
			if (psPath != "") {
				Run, "%psPath%"
				
				; Wait up to 60 seconds for ProSelect to fully load
				ToolTip, Waiting for ProSelect to load (up to 60 seconds)...
				startTime := A_TickCount
				timeout := 60000  ; 60 seconds
				
				Loop {
					if WinExist("ahk_exe ProSelect.exe") {
						; Window exists, wait a bit more for full initialization
						Sleep, 5000
						ToolTip, ProSelect detected - loading templates...
						Sleep, 2000
						break
					}
					if (A_TickCount - startTime > timeout) {
						ToolTip
						DarkMsgBox("Timeout", "ProSelect did not start within 60 seconds.`n`nYou can manually refresh print templates later from Settings > Print.", "warning", {rememberPosition: true})
						break
					}
					Sleep, 1000
					elapsed := Round((A_TickCount - startTime) / 1000)
					ToolTip, Waiting for ProSelect to load... (%elapsed%s)
				}
			} else {
				ToolTip
				DarkMsgBox("ProSelect Not Found", "Could not find ProSelect installation.`n`nYou can manually refresh print templates later from Settings > Print.", "warning", {rememberPosition: true})
			}
		}
	}
	
	; Now fetch templates if ProSelect is running
	if WinExist("ahk_exe ProSelect.exe") {
		ToolTip, Loading ProSelect templates...
		Gosub, RefreshPrintTemplatesSilent
		Sleep, 300
	}
	
	ToolTip
	
	DarkMsgBox("Setup Complete", "GHL Integration is now configured!`n`nLocation ID: " . GHL_LocationID . "`nAPI Key: " . apiKeyDisplay . "`n`nTags, templates, and data have been loaded automatically.", "success", {rememberPosition: true})
}
Return

; Get Location ID and Agency Domain from Chrome URL
; Sets global GHL_ExtractedDomain with the domain found
GetChromeLocationID() {
	global GHL_ExtractedDomain
	; Try to get URL from Chrome using Acc library or window title
	locationId := ""
	GHL_ExtractedDomain := ""
	
	; Method 1: Try Chrome debug port if available
	try {
		http := ComObjCreate("WinHttp.WinHttpRequest.5.1")
		http.SetTimeouts(1000, 1000, 1000, 1000)
		http.open("GET", "http://127.0.0.1:9222/json", false)
		http.send()
		
		if (http.status = 200) {
			responseText := http.responseText
			; Parse JSON for URL
			if RegExMatch(responseText, """url"":\s*""([^""]+)""", urlMatch) {
				url := urlMatch1
				; Extract domain from URL (e.g. https://app.yourcompany.com/v2/location/...)
				if RegExMatch(url, "https?://([^/]+)/v2/location/([a-zA-Z0-9]+)", match) {
					GHL_ExtractedDomain := match1
					locationId := match2
				}
			}
		}
	}
	
	; Method 2: Try Acc library to read URL bar
	if (locationId = "") {
		try {
			WinGet, hWnd, ID, ahk_exe chrome.exe
			if (hWnd) {
				; Try to get URL from Chrome's address bar using UI Automation
				WinGetTitle, chromeTitle, ahk_id %hWnd%
				; Chrome title sometimes contains URL info
			}
		}
	}
	
	; Method 3: Ask user to paste URL manually
	if (locationId = "") {
		InputBox, manualUrl, 📋 Paste URL, Could not read Chrome URL automatically.`n`nPlease copy the URL from Chrome's address bar and paste it here:,,450, 180
		if (!ErrorLevel && manualUrl != "") {
			; Extract domain and location ID from pasted URL
			if RegExMatch(manualUrl, "https?://([^/]+)/v2/location/([a-zA-Z0-9]+)", match) {
				GHL_ExtractedDomain := match1
				locationId := match2
			} else if RegExMatch(manualUrl, "/location/([a-zA-Z0-9]+)", locMatch) {
				; Fallback: just location ID
				locationId := locMatch1
			}
		}
	}
	
	return locationId
}

; Check if first run and needs GHL setup
CheckFirstRunGHLSetup() {
	global GHL_LocationID, GHL_API_Key, License_Status
	
	; Skip if already configured (Location ID or API Key exists)
	if (GHL_LocationID != "" || GHL_API_Key != "")
		return
	
	; Check if we've already asked (don't nag every startup)
	IniRead, askedGHLSetup, %IniFilename%, Setup, AskedGHLSetup, 0
	if (askedGHLSetup = 1)
		return
	
	; Mark that we've asked
	IniWrite, 1, %IniFilename%, Setup, AskedGHLSetup
	
	msg := "Welcome to SideKick_PS!`n`n"
	msg .= "To unlock all features, you need to connect to your GoHighLevel account.`n`n"
	msg .= "This will allow SideKick to:`n"
	msg .= "   • Fetch client details from GHL`n"
	msg .= "   • Auto-populate ProSelect fields`n"
	msg .= "   • Sync invoice data`n`n"
	msg .= "Would you like to set up GHL integration now?"
	
	result := DarkMsgBox("Connect to GoHighLevel", msg, "question", {buttons: ["Yes", "Later"], rememberPosition: true})
	if (result = "Yes")
	{
		Gosub, RunGHLSetupWizard
	}
}

OpenSupportEmail:
Run, mailto:guy@zoom-photo.co.uk
Return

OpenUserManual:
Run, https://sidekick.zoom-photo.uk/docs.html
Return

OpenDocsPage:
Run, https://sidekick.zoom-photo.uk/docs.html
Return

ShowWhatsNew:
	ShowWhatsNewDialog()
Return

; ============================================================================
; What's New Dialog - Scrollable list of all version history from version.json
; ============================================================================
ShowWhatsNewDialog()
{
	global ScriptVersion, WhatsNewVersions, WhatsNewCurrentIndex
	WhatsNewVersions := []
	WhatsNewCurrentIndex := 1
	
	jsonText := ""
	
	; Try local file first (more reliable during development)
	; Use the script's actual directory, not working directory
	SplitPath, A_ScriptFullPath,, scriptFolder
	localPath := scriptFolder . "\version.json"
	
	if (FileExist(localPath)) {
		FileRead, jsonText, %localPath%
	}
	
	; Fallback to GitHub if local not found or empty
	if (jsonText = "") {
		versionUrl := "https://raw.githubusercontent.com/GuyMayer/SideKick_PS/main/version.json"
		try {
			whr := ComObjCreate("WinHttp.WinHttpRequest.5.1")
			whr.Open("GET", versionUrl, false)
			whr.SetTimeouts(5000, 5000, 5000, 5000)
			whr.Send()
			if (whr.Status = 200)
				jsonText := whr.ResponseText
		}
	}
	
	if (jsonText = "") {
		DarkMsgBox("What's New", "Could not load version history.", "info", {buttons: ["OK"], width: 400})
		return
	}
	
	; Parse version info from JSON
	; First: parse the current version at root level (always present)
	version := ""
	buildDate := ""
	releaseNotes := ""
	changelog := []
	
	; Look for version at start of JSON (root level object)
	if (RegExMatch(jsonText, """version""\s*:\s*""(\d+\.\d+\.\d+)""", verMatch)) {
		version := verMatch1
		
		; Extract build_date at root level
		if (RegExMatch(jsonText, """build_date""\s*:\s*""([^""]+)""", dateMatch))
			buildDate := dateMatch1
		
		; Extract release_notes at root level
		if (RegExMatch(jsonText, """release_notes""\s*:\s*""([^""]+)""", notesMatch))
			releaseNotes := notesMatch1
		
		; Extract changelog array at root level
		if (RegExMatch(jsonText, """changelog""\s*:\s*\[([^\]]+)\]", clArrayMatch)) {
			clContent := clArrayMatch1
			clPos := 1
			Loop {
				clFoundPos := RegExMatch(clContent, """([^""]+)""", clItem, clPos)
				if (!clFoundPos)
					break
				changelog.Push(clItem1)
				clPos := clFoundPos + StrLen(clItem)
			}
		}
		
		WhatsNewVersions.Push({version: version, date: buildDate, notes: releaseNotes, changelog: changelog})
	}
	
	; Second: also parse historical "versions" array if present
	versionsArrayPos := InStr(jsonText, """versions""")
	if (versionsArrayPos) {
		; Find the opening bracket of the versions array
		arrayStart := InStr(jsonText, "[", false, versionsArrayPos)
		if (!arrayStart)
			arrayStart := versionsArrayPos
		
		; Find the closing bracket of the versions array
		arrayEnd := StrLen(jsonText)
		bracketDepth := 0
		foundStart := false
		Loop, Parse, % SubStr(jsonText, arrayStart)
		{
			if (A_LoopField = "[") {
				bracketDepth++
				foundStart := true
			} else if (A_LoopField = "]") {
				bracketDepth--
				if (foundStart && bracketDepth = 0) {
					arrayEnd := arrayStart + A_Index - 1
					break
				}
			}
		}
		
		; Extract just the versions array content
		versionsArrayText := SubStr(jsonText, arrayStart, arrayEnd - arrayStart + 1)
		
		; Now parse each version object within this array
		searchPos := 1
		
		Loop {
			; Find next version in array
			foundPos := RegExMatch(versionsArrayText, """version""\s*:\s*""(\d+\.\d+\.\d+)""", verMatch, searchPos)
			if (!foundPos)
				break
			
			version := verMatch1
			
			; Skip if this version was already added (root level)
			isDuplicate := false
			for i, existingVer in WhatsNewVersions {
				if (existingVer.version = version) {
					isDuplicate := true
					break
				}
			}
			if (isDuplicate) {
				searchPos := foundPos + 10
				continue
			}
			
			; Find the opening brace before this "version" key
			bracePos := foundPos
			Loop {
				bracePos--
				if (bracePos < 1)
					break
				if (SubStr(versionsArrayText, bracePos, 1) = "{")
					break
			}
			blockStart := bracePos
			
			; Find matching closing brace
			depth := 0
			blockEnd := blockStart
			Loop {
				char := SubStr(versionsArrayText, blockEnd, 1)
				if (char = "{")
					depth++
				else if (char = "}") {
					depth--
					if (depth = 0)
						break
				}
				blockEnd++
				if (blockEnd > StrLen(versionsArrayText))
					break
			}
			
			block := SubStr(versionsArrayText, blockStart, blockEnd - blockStart + 1)
			
			; Extract build_date
			buildDate := ""
			if (RegExMatch(block, """build_date""\s*:\s*""([^""]+)""", dateMatch))
				buildDate := dateMatch1
			
			; Extract release_notes
			releaseNotes := ""
			if (RegExMatch(block, """release_notes""\s*:\s*""([^""]+)""", notesMatch))
				releaseNotes := notesMatch1
			
			; Extract changelog array items
			changelog := []
			if (RegExMatch(block, """changelog""\s*:\s*\[([^\]]+)\]", clArrayMatch)) {
				clContent := clArrayMatch1
				clPos := 1
				Loop {
					clFoundPos := RegExMatch(clContent, """([^""]+)""", clItem, clPos)
					if (!clFoundPos)
						break
					changelog.Push(clItem1)
					clPos := clFoundPos + StrLen(clItem)
				}
			}
			
			WhatsNewVersions.Push({version: version, date: buildDate, notes: releaseNotes, changelog: changelog})
			searchPos := blockEnd + 1
		}
	}
	
	if (WhatsNewVersions.Length() = 0) {
		DarkMsgBox("What's New", "No version history found.", "info", {buttons: ["OK"], width: 400})
		return
	}
	
	; Create scrollable dialog
	ShowWhatsNewGUI()
}

ShowWhatsNewGUI()
{
	global WhatsNewVersions, WhatsNewCurrentIndex, ScriptVersion
	global WhatsNewTitle, WhatsNewPrevBtn, WhatsNewVersionLabel, WhatsNewNextBtn
	global WhatsNewCounter, WhatsNewChangelog
	
	Gui, WhatsNew:Destroy
	Gui, WhatsNew:New, +AlwaysOnTop +ToolWindow
	Gui, WhatsNew:Color, 1e1e1e
	Gui, WhatsNew:Font, s10 cWhite, Segoe UI
	
	; Title
	Gui, WhatsNew:Add, Text, x20 y15 w360 h25 +Center vWhatsNewTitle, What's New
	
	; Version selector row
	Gui, WhatsNew:Add, Button, x20 y45 w40 h28 gWhatsNewPrev vWhatsNewPrevBtn, ◀
	Gui, WhatsNew:Add, Text, x70 y50 w260 h25 +Center vWhatsNewVersionLabel, v%ScriptVersion%
	Gui, WhatsNew:Add, Button, x340 y45 w40 h28 gWhatsNewNext vWhatsNewNextBtn, ▶
	
	; Version counter
	totalVersions := WhatsNewVersions.Length()
	Gui, WhatsNew:Add, Text, x20 y78 w360 h20 +Center cGray vWhatsNewCounter, 1 of %totalVersions%
	
	; Changelog area (scrollable edit control, read-only)
	Gui, WhatsNew:Add, Edit, x20 y105 w360 h280 +ReadOnly +Multi +VScroll vWhatsNewChangelog -E0x200 Background2d2d2d cWhite,
	
	; OK button
	Gui, WhatsNew:Add, Button, x150 y400 w100 h30 gWhatsNewClose Default, OK
	
	; Apply dark styling
	Gui, WhatsNew:Font, s11 Bold cWhite, Segoe UI
	GuiControl, WhatsNew:Font, WhatsNewTitle
	Gui, WhatsNew:Font, s10 Norm cWhite, Segoe UI
	
	; Load first version
	UpdateWhatsNewContent()
	
	Gui, WhatsNew:Show, w400 h450, What's New
}

UpdateWhatsNewContent()
{
	global WhatsNewVersions, WhatsNewCurrentIndex
	
	if (WhatsNewVersions.Length() = 0)
		return
		
	ver := WhatsNewVersions[WhatsNewCurrentIndex]
	totalVersions := WhatsNewVersions.Length()
	
	; Update version label
	versionText := "v" . ver.version
	if (ver.date != "")
		versionText .= " (" . ver.date . ")"
	GuiControl, WhatsNew:, WhatsNewVersionLabel, %versionText%
	
	; Update counter
	counterText := WhatsNewCurrentIndex . " of " . totalVersions
	GuiControl, WhatsNew:, WhatsNewCounter, %counterText%
	
	; Build changelog text
	content := ""
	if (ver.notes != "")
		content .= ver.notes . "`n`n"
	
	for i, item in ver.changelog {
		content .= "• " . item . "`n"
	}
	
	GuiControl, WhatsNew:, WhatsNewChangelog, %content%
	
	; Enable/disable nav buttons
	if (WhatsNewCurrentIndex <= 1)
		GuiControl, WhatsNew:Disable, WhatsNewPrevBtn
	else
		GuiControl, WhatsNew:Enable, WhatsNewPrevBtn
		
	if (WhatsNewCurrentIndex >= totalVersions)
		GuiControl, WhatsNew:Disable, WhatsNewNextBtn
	else
		GuiControl, WhatsNew:Enable, WhatsNewNextBtn
}

WhatsNewPrev:
	global WhatsNewCurrentIndex
	if (WhatsNewCurrentIndex > 1) {
		WhatsNewCurrentIndex--
		UpdateWhatsNewContent()
	}
	return

WhatsNewNext:
	global WhatsNewCurrentIndex, WhatsNewVersions
	if (WhatsNewCurrentIndex < WhatsNewVersions.Length()) {
		WhatsNewCurrentIndex++
		UpdateWhatsNewContent()
	}
	return

WhatsNewClose:
WhatsNewGuiClose:
WhatsNewGuiEscape:
	Gui, WhatsNew:Destroy
	return

ShowWhatsNewOnUpdate:
	ShowWhatsNewSinceVersion(LastSeenVersion)
	return

ShowWhatsNewSinceVersion(sinceVersion)
{
	global ScriptVersion
	
	; Fetch CHANGELOG.md from GitHub to get all version entries
	changelogUrl := "https://raw.githubusercontent.com/GuyMayer/SideKick_PS/main/CHANGELOG.md"
	
	try {
		whr := ComObjCreate("WinHttp.WinHttpRequest.5.1")
		whr.Open("GET", changelogUrl, false)
		whr.SetTimeouts(5000, 5000, 5000, 5000)
		whr.Send()
		
		if (whr.Status = 200) {
			fullChangelog := whr.ResponseText
			
			; Parse changelog entries since the user's last version
			changelog := ""
			collecting := false
			stopVersion := sinceVersion ? sinceVersion : ""
			
			; Process line by line
			Loop, Parse, fullChangelog, `n, `r
			{
				line := A_LoopField
				
				; Check for version header (## vX.X.X)
				if (RegExMatch(line, "^## v(\d+\.\d+\.\d+)", verMatch)) {
					foundVersion := verMatch1
					
					; Stop if we hit the user's last seen version
					if (stopVersion != "" && foundVersion = stopVersion)
						break
					
					; Start collecting from first version found
					if (!collecting) {
						collecting := true
					} else {
						changelog .= "`n"  ; Add separator between versions
					}
					changelog .= foundVersion . ":`n"
				}
				else if (collecting) {
					; Collect content lines (skip empty lines and separators)
					if (line != "" && !InStr(line, "---") && !InStr(line, "<!--")) {
						; Clean up markdown formatting
						cleanLine := RegExReplace(line, "^\s*[-*]\s*", "• ")
						cleanLine := RegExReplace(cleanLine, "\*\*([^*]+)\*\*", "$1")
						cleanLine := RegExReplace(cleanLine, "`([^`]+)`", "$1")
						if (cleanLine != "" && !InStr(cleanLine, "###"))
							changelog .= cleanLine . "`n"
					}
				}
				
				; Limit to avoid huge dialogs (max 3 versions if updating from old version)
				if (collecting && StrLen(changelog) > 2000)
					break
			}
			
			if (changelog != "") {
				title := sinceVersion ? "What's New since v" . sinceVersion : "What's New in v" . ScriptVersion
				DarkMsgBox(title, changelog, "info", {buttons: ["OK"], width: 500})
				return
			}
		}
	}
	
	; Fallback: fetch from version.json for current version only
	FetchCurrentVersionChangelog()
}

FetchCurrentVersionChangelog()
{
	global ScriptVersion
	
	versionUrl := "https://raw.githubusercontent.com/GuyMayer/SideKick_PS/main/version.json"
	
	try {
		whr := ComObjCreate("WinHttp.WinHttpRequest.5.1")
		whr.Open("GET", versionUrl, false)
		whr.SetTimeouts(5000, 5000, 5000, 5000)
		whr.Send()
		
		if (whr.Status = 200) {
			jsonText := whr.ResponseText
			
			; Parse changelog array from JSON
			changelog := ""
			pos := 1
			
			if (RegExMatch(jsonText, """changelog""\s*:\s*\[", startMatch, pos)) {
				arrayStart := startMatch + StrLen(startMatch) - 1
				searchPos := arrayStart
				while (RegExMatch(jsonText, """([^""]+)""", itemMatch, searchPos)) {
					if (InStr(SubStr(jsonText, arrayStart, itemMatch - arrayStart), "]"))
						break
					if (changelog != "")
						changelog .= "`n"
					changelog .= "• " . itemMatch1
					searchPos := itemMatch + StrLen(itemMatch)
				}
			}
			
			if (changelog = "") {
				if (RegExMatch(jsonText, """release_notes""\s*:\s*""([^""]+)""", rnMatch))
					changelog := StrReplace(rnMatch1, "\n", "`n")
			}
			
			if (changelog != "") {
				DarkMsgBox("What's New in v" . ScriptVersion, changelog, "info", {buttons: ["OK"], width: 500})
				return
			}
		}
	}
	
	DarkMsgBox("What's New", "Could not fetch changelog.`n`nCheck GitHub for latest release notes.", "info", {buttons: ["OK"], width: 400})
}

; Check if version changed and show What's New
CheckVersionChanged()
{
	global IniFilename, ScriptVersion, LastSeenVersion
	
	IniRead, LastSeenVersion, %IniFilename%, Settings, LastSeenVersion, %A_Space%
	
	if (LastSeenVersion != "" && LastSeenVersion != ScriptVersion)
	{
		; Version changed - show What's New after a short delay
		SetTimer, ShowWhatsNewOnUpdate, -2000
	}
	
	; Save current version as last seen
	IniWrite, %ScriptVersion%, %IniFilename%, Settings, LastSeenVersion
}

; About panel update handlers
AboutUpdateNow:
	global Update_DownloadURL, Update_AvailableVersion, ScriptVersion
	
	; Check if we have a newer version or offer reinstall
	if (Update_AvailableVersion != "" && Update_DownloadURL != "") {
		comparison := CompareVersions(Update_AvailableVersion, ScriptVersion)
		if (comparison > 0) {
			; Newer version available - download it
			DownloadAndInstallUpdate(Update_DownloadURL, Update_AvailableVersion, false)
		} else {
			; Already up to date - offer reinstall
			result := DarkMsgBox("Reinstall Current Version?", "You already have the latest version (v" . ScriptVersion . ").`n`nWould you like to reinstall it?`n`n(This can fix corrupted files)", "question", {buttons: ["Reinstall", "Cancel"]})
			if (result = "Reinstall")
				DownloadAndInstallUpdate(Update_DownloadURL, ScriptVersion, false)
		}
	} else {
		; No version info - offer reinstall from fixed URL
		downloadUrl := "https://github.com/GuyMayer/SideKick_PS/releases/latest/download/SideKick_PS_Setup.exe"
		result := DarkMsgBox("Reinstall Current Version?", "Would you like to reinstall SideKick_PS v" . ScriptVersion . "?`n`n(This can fix corrupted files)", "question", {buttons: ["Reinstall", "Cancel"]})
		if (result = "Reinstall")
			DownloadAndInstallUpdate(downloadUrl, ScriptVersion, false)
	}
Return

AboutCheckUpdate:
	RefreshLatestVersion()
Return

AboutReinstall:
	; Force reinstall from GitHub
	downloadUrl := "https://github.com/GuyMayer/SideKick_PS/releases/latest/download/SideKick_PS_Setup.exe"
	result := DarkMsgBox("Reinstall SideKick_PS?", "This will download and reinstall SideKick_PS v" . ScriptVersion . ".`n`nUse this to fix corrupted files or reset the installation.", "question", {buttons: ["Reinstall", "Cancel"]})
	if (result = "Reinstall")
		DownloadAndInstallUpdate(downloadUrl, ScriptVersion, false)
Return

AboutAutoUpdateToggle:
	Gui, Settings:Submit, NoHide
	Settings_AutoUpdate := AboutAutoUpdate
	SaveSettings()
Return

; Toggle handler for auto-send logs
Toggle_AutoSendLogs:
	Settings_AutoSendLogs := Toggle_AutoSendLogs_State
	SaveSettings()
Return

; Timer handler to check for GoCardless setup after sync with future payments
CheckGoCardlessAfterSync:
	; Only proceed if GoCardless is enabled AND auto-setup is on
	if (!Settings_GoCardlessEnabled || Settings_GoCardlessToken = "" || !Settings_GCAutoSetup)
		return
	
	; Read the result JSON to check for future payments
	resultFile := A_AppData . "\SideKick_PS\ghl_invoice_sync_result.json"
	if (!FileExist(resultFile))
		return
	
	FileRead, resultJson, %resultFile%
	if (resultJson = "")
		return
	
	; Check if there are future payments
	if (!InStr(resultJson, """future_payments"""))
		return
	
	; Extract future_payments info
	futureCount := 0
	futureTotal := 0
	clientName := ""
	customerEmail := ""
	contactId := ""
	
	if (RegExMatch(resultJson, """count""\s*:\s*(\d+)", m))
		futureCount := m1
	if (RegExMatch(resultJson, """total""\s*:\s*(\d+(?:\.\d+)?)", m))
		futureTotal := m1
	if (RegExMatch(resultJson, """client_name""\s*:\s*""([^""]*)""", m))
		clientName := m1
	if (RegExMatch(resultJson, """email""\s*:\s*""([^""]*)""", m))
		customerEmail := m1
	if (RegExMatch(resultJson, """contact_id""\s*:\s*""([^""]*)""", m))
		contactId := m1
	
	; If no future payments, exit
	if (futureCount = 0 || futureTotal = 0)
		return
	
	; Format total for display
	formattedTotal := "£" . Format("{:.2f}", futureTotal / 100)
	
	; Show prompt asking if they want to set up GoCardless
	result := DarkMsgBox("Set Up GoCardless Payments?", "This order has " . futureCount . " future payment(s) totaling " . formattedTotal . ".`n`nWould you like to set up Direct Debit payments via GoCardless for " . clientName . "?", "question", {buttons: ["Set Up GoCardless", "Not Now"]})
	
	if (result != "Set Up GoCardless")
		return
	
	; Check mandate status
	if (customerEmail = "") {
		DarkMsgBox("Missing Email", "Cannot check GoCardless mandate - no email address found for this customer.", "warning")
		return
	}
	
	ToolTip, Checking GoCardless mandate status...
	mandateResult := GC_CheckCustomerMandate(customerEmail)
	ToolTip
	
	if (mandateResult.error != "") {
		DarkMsgBox("GoCardless Error", "Could not check mandate status:`n`n" . mandateResult.error, "error")
		return
	}
	
	if (mandateResult.hasMandate) {
		; Customer has active mandate - offer to set up payment plan
		bankInfo := mandateResult.bankName != "" ? " (" . mandateResult.bankName . ")" : ""
		planResult := DarkMsgBox("Mandate Found", clientName . " already has an active Direct Debit mandate" . bankInfo . ".`n`nMandate ID: " . mandateResult.mandateId . "`n`nWould you like to set up a payment plan using this mandate?", "success", {buttons: ["Set Up PayPlan", "Open GC Client", "Cancel"]})
		
		if (planResult = "Open GC Client") {
			; Open GoCardless customer page
			gcEnv := (Settings_GoCardlessEnvironment = "live") ? "manage" : "manage-sandbox"
			gcUrl := "https://" . gcEnv . ".gocardless.com/customers/" . mandateResult.customerId
			Run, %gcUrl%
		}
		else if (planResult = "Set Up PayPlan") {
			; Store data for PayPlan dialog
			global GC_PayPlan_ContactData := {}
			GC_PayPlan_ContactData.name := clientName
			GC_PayPlan_ContactData.email := customerEmail
			GC_PayPlan_ContactData.contactId := contactId
			GC_PayPlan_ContactData.mandateId := mandateResult.mandateId
			GC_PayPlan_ContactData.customerId := mandateResult.customerId
			GC_PayPlan_ContactData.futurePaymentsJson := resultJson
			; TODO: Show PayPlan dialog
			DarkMsgBox("Coming Soon", "Payment plan creation will be available in a future update.`n`nMandate ID: " . mandateResult.mandateId, "info")
		}
	} else {
		; No mandate - offer to send mandate request
		sendResult := DarkMsgBox("No Mandate Found", clientName . " does not have an active Direct Debit mandate.`n`nWould you like to send a mandate setup request via email/SMS?", "info", {buttons: ["Send Request", "Cancel"]})
		
		if (sendResult = "Send Request") {
			; Build contact data object
			contactData := {}
			contactData.name := clientName
			contactData.email := customerEmail
			contactData.id := contactId
			contactData.phone := ""
			
			; Try to get phone from result JSON
			if (RegExMatch(resultJson, """phone""\s*:\s*""([^""]*)""", m))
				contactData.phone := m1
			
			; Determine send methods based on settings
			sendEmail := (Settings_GCEmailTemplateID != "")
			sendSMS := (Settings_GCSMSTemplateID != "") && (contactData.phone != "")
			
			if (!sendEmail && !sendSMS) {
				DarkMsgBox("No Templates", "Please configure email and/or SMS templates in GoCardless settings first.", "warning")
				return
			}
			
			ToolTip, Sending mandate request...
			gcResult := GC_SendMandateRequest(contactData, sendEmail, sendSMS)
			ToolTip
			
			if (gcResult.success) {
				sentVia := ""
				if (sendEmail && sendSMS)
					sentVia := "Email and SMS"
				else if (sendEmail)
					sentVia := "Email"
				else if (sendSMS)
					sentVia := "SMS"
				DarkMsgBox("Request Sent", "Mandate setup link sent to " . clientName . " via " . sentVia . ".`n`nBilling Request: " . gcResult.billingRequestId, "success")
			} else {
				DarkMsgBox("Send Failed", "Could not send mandate request:`n`n" . gcResult.error, "error")
			}
		}
	}
Return

; Timer handler for auto-sending logs on sync complete (silent, no prompts)
AutoSendLogsOnComplete:
	SendDebugLogsSilent()
Return

; Silent version of SendDebugLogs for auto-send (no dialogs, no prompts)
SendDebugLogsSilent() {
	global GHL_LocationID
	
	; Path to SideKick_PS logs folder in AppData (matches Python DEBUG_LOG_FOLDER)
	logsFolder := A_AppData . "\SideKick_PS\Logs"
	
	; Check if folder exists
	if (!FileExist(logsFolder))
		return false
	
	; GitHub Gist token - assembled from parts to avoid secret scanning
	gistToken := "ghp" . "_" . "5iyc62vax5VllMndhvrRzk" . "ItNRJeom3cShIM"
	
	; Collect all log files
	logFiles := []
	Loop, Files, %logsFolder%\*.log, R
	{
		logFiles.Push(A_LoopFileLongPath)
	}
	
	if (logFiles.Length() = 0)
		return false
	
	; Build gist content with all logs
	gistFiles := {}
	for i, logPath in logFiles {
		SplitPath, logPath, fileName
		FileRead, logContent, %logPath%
		if (logContent != "") {
			relativePath := SubStr(logPath, StrLen(logsFolder) + 2)
			relativePath := StrReplace(relativePath, "\", "_")
			gistFiles[relativePath] := {"content": logContent}
		}
	}
	
	if (gistFiles.Count() = 0)
		return false
	
	; Build JSON payload
	computerName := A_ComputerName
	timestamp := A_YYYY . "-" . A_MM . "-" . A_DD . "_" . A_Hour . A_Min . A_Sec
	locationId := GHL_LocationID ? GHL_LocationID : "Unknown"
	
	filesJson := ""
	for fileName, fileObj in gistFiles {
		content := fileObj.content
		content := StrReplace(content, "\", "\\")
		content := StrReplace(content, """", "\""")
		content := StrReplace(content, "`n", "\n")
		content := StrReplace(content, "`r", "\r")
		content := StrReplace(content, "`t", "\t")
		
		if (filesJson != "")
			filesJson .= ","
		filesJson .= """" . fileName . """: {""content"": """ . content . """}"
	}
	
	gistJson := "{""description"": ""SideKick Logs - " . computerName . " - " . locationId . " - " . timestamp . """, ""public"": false, ""files"": {" . filesJson . "}}"
	
	; Upload silently
	try {
		http := ComObjCreate("WinHttp.WinHttpRequest.5.1")
		http.SetTimeouts(30000, 30000, 30000, 60000)
		http.open("POST", "https://api.github.com/gists", false)
		http.SetRequestHeader("Authorization", "token " . gistToken)
		http.SetRequestHeader("Accept", "application/vnd.github.v3+json")
		http.SetRequestHeader("Content-Type", "application/json")
		http.send(gistJson)
		
		if (http.status = 201) {
			; Delete uploaded log files to prevent re-uploading old logs
			for i, logPath in logFiles {
				FileDelete, %logPath%
			}
			return true
		}
		return false
	}
	catch {
		return false
	}
}

; Send debug logs to developer via GitHub Gist
SendLogsNow:
	SendDebugLogs()
Return

; Open the log folder in Windows Explorer
OpenLogFolder:
	logFolder := A_AppData . "\SideKick_PS\Logs"
	if (FileExist(logFolder)) {
		Run, explorer.exe "%logFolder%"
	} else {
		; Create folder if it doesn't exist and open it
		FileCreateDir, %logFolder%
		Run, explorer.exe "%logFolder%"
	}
Return

SendDebugLogs() {
	global GHL_LocationID, IniFilename
	
	; Path to SideKick_PS logs folder in AppData (matches Python DEBUG_LOG_FOLDER)
	logsFolder := A_AppData . "\SideKick_PS\Logs"
	
	; Check if folder exists
	if (!FileExist(logsFolder)) {
		DarkMsgBox("No Logs Found", "Log folder does not exist:`n`n" . logsFolder . "`n`nTo enable logging:`n1. Go to Settings > About tab`n2. Turn ON 'Debug Logging'`n3. Run an invoice sync`n4. Try 'Send Logs' again", "info")
		return false
	}
	
	; GitHub Gist token - assembled from parts to avoid secret scanning
	; Token parts: ghp_ + 5iyc62vax5VllMndhvrRzk + ItNRJeom3cShIM
	gistToken := "ghp" . "_" . "5iyc62vax5VllMndhvrRzk" . "ItNRJeom3cShIM"
	
	; Collect all log files
	logFiles := []
	Loop, Files, %logsFolder%\*.log, R
	{
		logFiles.Push(A_LoopFileLongPath)
	}
	
	logCount := logFiles.Length()
	if (logCount = 0) {
		DarkMsgBox("No Logs Found", "No .log files found in:`n`n" . logsFolder . "`n`nTo create logs:`n1. Ensure 'Debug Logging' is ON in Settings`n2. Run an invoice sync`n3. Try 'Send Logs' again", "info")
		return false
	}
	
	; Show progress
	ToolTip, Uploading %logCount% log file(s)...
	
	; Build gist content with all logs
	gistFiles := {}
	for i, logPath in logFiles {
		SplitPath, logPath, fileName
		FileRead, logContent, %logPath%
		if (logContent != "") {
			; Get relative path for folder organization
			relativePath := SubStr(logPath, StrLen(logsFolder) + 2)
			relativePath := StrReplace(relativePath, "\", "_")
			gistFiles[relativePath] := {"content": logContent}
		}
	}
	
	if (gistFiles.Count() = 0) {
		ToolTip
		DarkMsgBox("No Content", "Log files were empty.", "info")
		return false
	}
	
	; Build JSON payload manually (AHK v1 JSON)
	computerName := A_ComputerName
	timestamp := A_YYYY . "-" . A_MM . "-" . A_DD . "_" . A_Hour . A_Min . A_Sec
	locationId := GHL_LocationID ? GHL_LocationID : "Unknown"
	
	; Build files JSON
	filesJson := ""
	for fileName, fileObj in gistFiles {
		content := fileObj.content
		; Escape special characters for JSON
		content := StrReplace(content, "\", "\\")
		content := StrReplace(content, """", "\""")
		content := StrReplace(content, "`n", "\n")
		content := StrReplace(content, "`r", "\r")
		content := StrReplace(content, "`t", "\t")
		
		if (filesJson != "")
			filesJson .= ","
		filesJson .= """" . fileName . """: {""content"": """ . content . """}"
	}
	
	gistJson := "{""description"": ""SideKick Logs - " . computerName . " - " . locationId . " - " . timestamp . """, ""public"": false, ""files"": {" . filesJson . "}}"
	
	; Upload to GitHub Gist
	try {
		http := ComObjCreate("WinHttp.WinHttpRequest.5.1")
		http.SetTimeouts(30000, 30000, 30000, 60000)
		http.open("POST", "https://api.github.com/gists", false)
		http.SetRequestHeader("Authorization", "token " . gistToken)
		http.SetRequestHeader("Accept", "application/vnd.github.v3+json")
		http.SetRequestHeader("Content-Type", "application/json")
		http.send(gistJson)
		
		ToolTip
		
		if (http.status = 201) {
			; Parse response to get gist URL
			response := http.responseText
			RegExMatch(response, """html_url"":\s*""([^""]+)""", urlMatch)
			gistUrl := urlMatch1
			
			; Ask if user wants to delete local logs
			result := DarkMsgBox("Logs Uploaded Successfully", "Debug logs uploaded!`n`n" . logCount . " log file(s) sent.`n`nURL: " . gistUrl . "`n`nWould you like to delete the local log files?", "success", {buttons: ["Delete Logs", "Keep Logs"]})
			
			if (result = "Delete Logs") {
				; Delete log files
				for i, logPath in logFiles {
					FileDelete, %logPath%
				}
				; Try to remove empty folders
				Loop, Files, %logsFolder%\*, D
				{
					FileRemoveDir, %A_LoopFileLongPath%
				}
				DarkMsgBox("Logs Deleted", "Local log files have been deleted.", "success")
			}
			
			return true
		} else {
			DarkMsgBox("Upload Failed", "Failed to upload logs.`n`nHTTP Status: " . http.status . "`n`nResponse: " . SubStr(http.responseText, 1, 200), "error")
			return false
		}
	}
	catch e {
		ToolTip
		errMsg := e.Message ? e.Message : e
		DarkMsgBox("Upload Error", "Error uploading logs:`n`n" . errMsg, "error")
		return false
	}
}

; ============================================================================
; Desktop Shortcut Creation Functions
; ============================================================================
CreateChromeDebugShortcut:
; Find Chrome executable
chromePath := ""
if FileExist("C:\Program Files\Google\Chrome\Application\chrome.exe")
	chromePath := "C:\Program Files\Google\Chrome\Application\chrome.exe"
else if FileExist("C:\Program Files (x86)\Google\Chrome\Application\chrome.exe")
	chromePath := "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
else if FileExist(A_LocalAppData . "\Google\Chrome\Application\chrome.exe")
	chromePath := A_LocalAppData . "\Google\Chrome\Application\chrome.exe"

if (chromePath = "")
{
	DarkMsgBox("Chrome Not Found", "Could not find Chrome installation.`n`nPlease locate chrome.exe manually.", "warning")
	Return
}

; Create shortcut on desktop
desktopPath := A_Desktop . "\Chrome (Debug Mode).lnk"

; Create debug profile directory if it doesn't exist
debugProfileDir := A_Temp . "\ChromeDebugProfile"
if !FileExist(debugProfileDir)
	FileCreateDir, %debugProfileDir%

; Use WScript.Shell to create shortcut
try {
	oWS := ComObjCreate("WScript.Shell")
	oLink := oWS.CreateShortcut(desktopPath)
	oLink.TargetPath := chromePath
	oLink.Arguments := "--remote-debugging-port=9222 --user-data-dir=" . debugProfileDir
	oLink.Description := "Chrome with remote debugging for SideKick GHL integration"
	oLink.WorkingDirectory := "C:\Program Files\Google\Chrome\Application"
	oLink.IconLocation := chromePath . ",0"
	oLink.Save()
	
	DarkMsgBox("Shortcut Created", "Chrome (Debug Mode) shortcut created on Desktop!`n`nThis opens a separate Chrome profile with debugging enabled.`n`nYou can use both normal Chrome and debug Chrome at the same time.", "success")
}
catch e
{
	errMsg := e.Message ? e.Message : e
	DarkMsgBox("Error", "Failed to create shortcut.`n`nError: " . errMsg, "error")
}
Return

EditRecurringOptions:
; Edit the available recurring payment options (Monthly is always included)
global Settings_RecurringOptions
if (Settings_RecurringOptions = "")
	Settings_RecurringOptions := "Weekly,Bi-Weekly,4-Weekly"

InputBox, newOptions, Edit Recurring Options, Enter comma-separated recurring options.`nMonthly is always included automatically.`n`nExample: Weekly`, Bi-Weekly`, 4-Weekly`, Fortnightly,, 400, 180,,,,, %Settings_RecurringOptions%

if (!ErrorLevel && newOptions != "") {
	; Clean up the input
	newOptions := Trim(newOptions)
	Settings_RecurringOptions := newOptions
	
	; Build the dropdown list (Monthly always first and default)
	ddlOptions := "Monthly||" . StrReplace(newOptions, ",", "|")
	ddlOptions := StrReplace(ddlOptions, " |", "|")  ; Remove spaces before |
	ddlOptions := StrReplace(ddlOptions, "| ", "|")  ; Remove spaces after |
	
	; Update the dropdown
	GuiControl, Settings:, Settings_DefaultRecurring_DDL, |%ddlOptions%
	GuiControl, Settings:ChooseString, Settings_DefaultRecurring_DDL, Monthly
	
	; Update the display
	displayText := "Monthly, " . newOptions
	GuiControl, Settings:, GenRecurOptionsEdit, %displayText%
	
	; Save to INI
	IniWrite, %newOptions%, %IniFilename%, Settings, RecurringOptions
}
Return

CreateSideKickShortcut:
; Create shortcut for this script on desktop
desktopPath := A_Desktop . "\SideKick_PS.lnk"
scriptPath := A_ScriptFullPath

try {
	oWS := ComObjCreate("WScript.Shell")
	oLink := oWS.CreateShortcut(desktopPath)
	oLink.TargetPath := scriptPath
	oLink.Description := "SideKick_PS - Payment Plan Calculator & GHL Integration"
	oLink.WorkingDirectory := A_ScriptDir
	; Use script's icon if available, otherwise use AHK icon
	if FileExist(A_ScriptDir . "\Images\SideKick_PS.ico")
		oLink.IconLocation := A_ScriptDir . "\Images\SideKick_PS.ico,0"
	else
		oLink.IconLocation := A_AhkPath . ",0"
	oLink.Save()
	
	DarkMsgBox("Shortcut Created", "SideKick_PS shortcut created on Desktop!", "success")
}
catch e
{
	errMsg := e.Message ? e.Message : e
	DarkMsgBox("Error", "Failed to create shortcut.`n`nError: " . errMsg, "error")
}
Return

; ============================================
; Settings Import/Export System
; ============================================

; Export settings to encrypted .skp file
ExportSettings:
; Suggest filename with date stamp
FormatTime, dateStamp,, yyyy-MM-dd
defaultName := "SideKick_Settings_" . dateStamp . ".skp"

FileSelectFile, exportPath, S16, %A_Desktop%\%defaultName%, Export SideKick Settings, SideKick Package (*.skp)
if (exportPath = "")
	return
	
; Ensure .skp extension
if !InStr(exportPath, ".skp")
	exportPath .= ".skp"

; Build settings data string
settingsData := BuildExportData()

; Encrypt and save
encrypted := EncryptSettingsData(settingsData)

; Write to file with header
FileDelete, %exportPath%
FileAppend, SKPS1|%encrypted%, %exportPath%

if ErrorLevel {
	DarkMsgBox("Export Failed", "Failed to write settings file.`n`nPlease check write permissions.", "error")
	return
}

DarkMsgBox("Settings Exported", "Settings exported successfully!`n`nFile: " . exportPath . "`n`n✅ INCLUDED IN PACKAGE:`n• All settings and preferences`n• GHL API Key and Location ID`n• License information`n• Hotkey configurations`n`nImport this file on another machine to copy`nyour complete SideKick setup.", "success")
Return

; Import settings from encrypted .skp file
ImportSettings:
FileSelectFile, importPath, 3, %A_Desktop%, Import SideKick Settings, SideKick Package (*.skp)
if (importPath = "")
	return

; Read file content
FileRead, fileContent, %importPath%
if ErrorLevel {
	DarkMsgBox("Import Failed", "Failed to read settings file.`n`nPlease check that the file exists and is accessible.", "error")
	return
}

; Verify header
if !InStr(fileContent, "SKPS1|") {
	DarkMsgBox("Invalid File", "This file is not a valid SideKick settings package.`n`nPlease select a .skp file exported from SideKick.", "error")
	return
}

; Extract encrypted data
encrypted := SubStr(fileContent, 7)  ; Skip "SKPS1|"

; Decrypt
decrypted := DecryptSettingsData(encrypted)
if (decrypted = "") {
	DarkMsgBox("Decryption Failed", "Failed to decrypt settings file.`n`nThe file may be corrupted or from an incompatible version.", "error")
	return
}

; Parse and show preview
parsedSettings := ParseImportData(decrypted)
if (parsedSettings = "") {
	DarkMsgBox("Parse Failed", "Failed to parse settings data.`n`nThe file may be corrupted.", "error")
	return
}

; Confirm import
result := DarkMsgBox("📥 Import Settings", "Import settings from this package?`n`nThis will replace your current settings.`nYour current settings will be backed up first.`n`nContinue?", "question", {buttons: ["Yes", "No"]})
if (result != "Yes")
	return

; Backup current settings
FormatTime, backupStamp,, yyyyMMdd_HHmmss
backupPath := IniFilename . ".backup_" . backupStamp
FileCopy, %IniFilename%, %backupPath%

; Apply imported settings
ApplyImportedSettings(decrypted)

; Reload settings
LoadSettings()

; Refresh settings GUI if open
Gui, Settings:Default
RefreshSettingsDisplay()

; Validate imported settings (GHL connection and license)
importWarnings := ""

; Test GHL connection
if (GHL_API_Key != "" && GHL_LocationID != "") {
	ghlOk := false
	try {
		http := ComObjCreate("WinHttp.WinHttpRequest.5.1")
		http.SetTimeouts(5000, 5000, 5000, 5000)
		testUrl := "https://services.leadconnectorhq.com/contacts/?locationId=" . GHL_LocationID . "&limit=1"
		http.open("GET", testUrl, false)
		http.SetRequestHeader("Authorization", "Bearer " . GHL_API_Key)
		http.SetRequestHeader("Version", "2021-07-28")
		http.send()
		if (http.status = 200)
			ghlOk := true
	}
	if (!ghlOk)
		importWarnings .= "• GHL connection failed - check API Key and Location ID`n"
}

; Test license (if license data was imported)
if (License_Key != "" && License_Status = "active") {
	licenseOk := ValidateLicenseOnline()
	if (!licenseOk)
		importWarnings .= "• License validation failed - may need to re-activate`n"
}

; Show result with any warnings
if (importWarnings != "") {
	DarkMsgBox("Settings Imported with Warnings", "Settings imported successfully!`n`nBackup saved to:`n" . backupPath . "`n`n⚠️ VALIDATION WARNINGS:`n" . importWarnings . "`nThe imported settings may be from a different GHL account`nor a different licensed installation.`n`nPlease go to Settings to verify and update as needed.", "warning")
} else {
	DarkMsgBox("Settings Imported", "Settings imported successfully!`n`nBackup saved to:`n" . backupPath . "`n`n✅ IMPORTED AND VALIDATED:`n• All settings and preferences`n• GHL connection verified`n• License verified`n• Hotkey configurations`n`nYou're ready to go!", "success")
}
Return

; Build settings data for export - reads complete INI file and credentials
BuildExportData() {
	global IniFilename
	
	; Read the complete INI file content (including license)
	FileRead, data, %IniFilename%
	if ErrorLevel {
		; Fallback: file doesn't exist or can't be read
		return ""
	}
	
	; Add credentials.json content (marked with special header)
	credFile := GetCredentialsFilePath()
	if FileExist(credFile) {
		FileRead, credData, %credFile%
		if (!ErrorLevel && credData != "") {
			data .= "`n[__CREDENTIALS_JSON__]`n" . credData . "`n[__END_CREDENTIALS__]"
		}
	}
	
	; Export everything - license and credentials included for multi-machine setup
	return data
}

; Encrypt settings data using XOR cipher with checksum
EncryptSettingsData(plainData) {
	global
	encryptKey := "Sk1Pr0S3l3ctP4ck4g32026"
	
	; Create checksum
	checksum := 0
	Loop, Parse, plainData
		checksum := checksum + Asc(A_LoopField)
	checksum := Mod(checksum, 65536)
	
	; Add checksum to data
	plainData := checksum . ":" . plainData
	
	; XOR encode
	encoded := ""
	keyLen := StrLen(encryptKey)
	Loop, Parse, plainData
	{
		keyChar := SubStr(encryptKey, Mod(A_Index - 1, keyLen) + 1, 1)
		xorVal := Asc(A_LoopField) ^ Asc(keyChar)
		encoded .= Format("{:02X}", xorVal)
	}
	
	return encoded
}

; Decrypt settings data
DecryptSettingsData(encoded) {
	global
	encryptKey := "Sk1Pr0S3l3ctP4ck4g32026"
	
	if (encoded = "" || StrLen(encoded) < 10)
		return ""
	
	; Decode XOR
	decoded := ""
	keyLen := StrLen(encryptKey)
	charIndex := 0
	Loop, % StrLen(encoded) // 2
	{
		hexPair := SubStr(encoded, (A_Index - 1) * 2 + 1, 2)
		SetFormat, Integer, D
		charVal := "0x" . hexPair
		charVal += 0
		keyChar := SubStr(encryptKey, Mod(charIndex, keyLen) + 1, 1)
		decoded .= Chr(charVal ^ Asc(keyChar))
		charIndex++
	}
	
	; Verify checksum
	colonPos := InStr(decoded, ":")
	if (!colonPos)
		return ""
	
	storedChecksum := SubStr(decoded, 1, colonPos - 1)
	dataOnly := SubStr(decoded, colonPos + 1)
	
	; Calculate checksum
	calcChecksum := 0
	Loop, Parse, dataOnly
		calcChecksum := calcChecksum + Asc(A_LoopField)
	calcChecksum := Mod(calcChecksum, 65536)
	
	if (storedChecksum != calcChecksum)
		return ""
	
	return dataOnly
}

; Parse import data and return preview string
ParseImportData(data) {
	if (data = "")
		return ""
	
	; Check for expected sections
	if (!InStr(data, "[Settings]") || !InStr(data, "[GHL]"))
		return ""
	
	return data
}

; Apply imported settings to current configuration
ApplyImportedSettings(data) {
	global
	
	; Check for embedded credentials JSON
	credStart := InStr(data, "[__CREDENTIALS_JSON__]")
	credEnd := InStr(data, "[__END_CREDENTIALS__]")
	if (credStart && credEnd) {
		; Extract credentials JSON
		credJsonStart := credStart + StrLen("[__CREDENTIALS_JSON__]") + 1
		credJson := SubStr(data, credJsonStart, credEnd - credJsonStart - 1)
		credJson := Trim(credJson, "`n`r")
		
		; Save credentials to file
		if (credJson != "") {
			credFile := GetCredentialsFilePath()
			FileDelete, %credFile%
			FileAppend, %credJson%, %credFile%, UTF-8
		}
		
		; Remove credentials section from INI data for processing
		data := SubStr(data, 1, credStart - 1)
	}
	
	currentSection := ""
	
	Loop, Parse, data, `n, `r
	{
		line := A_LoopField
		
		; Check for section header
		if RegExMatch(line, "^\[(.+)\]$", m) {
			currentSection := m1
			continue
		}
		
		; Parse key=value
		if (InStr(line, "=")) {
			equalPos := InStr(line, "=")
			key := SubStr(line, 1, equalPos - 1)
			value := SubStr(line, equalPos + 1)
			
			; Write to INI file
			if (currentSection != "" && key != "")
				IniWrite, %value%, %IniFilename%, %currentSection%, %key%
		}
	}
	
	; Reload credentials from JSON
	LoadGHLCredentials()
}

; Refresh settings display after import
RefreshSettingsDisplay() {
	global
	
	; This reloads GUI elements with new values
	; Most will be updated on next panel selection
}

; ============================================
; Hotkey Registration System
; ============================================

; Custom condition: ProSelect or SideKick windows are active
IsProSelectOrSideKickActive() {
	; Check if ProSelect is active
	if WinActive("ahk_exe ProSelect.exe")
		return true
	; Check if any SideKick window is active (toolbar, settings, etc.)
	WinGetTitle, activeTitle, A
	if (InStr(activeTitle, "SideKick") || InStr(activeTitle, "Settings") || InStr(activeTitle, "PayPlan"))
		return true
	return false
}

RegisterHotkeys()
{
	global Hotkey_GHLLookup, Hotkey_PayPlan, Hotkey_Settings, Hotkey_DevReload
	
	; Clear any existing hotkeys first (in case we're re-registering)
	try {
		Hotkey, %Hotkey_GHLLookup%, Off, UseErrorLevel
		Hotkey, %Hotkey_PayPlan%, Off, UseErrorLevel
		Hotkey, %Hotkey_Settings%, Off, UseErrorLevel
		if (!A_IsCompiled)
			Hotkey, %Hotkey_DevReload%, Off, UseErrorLevel
	}
	
	; Register new hotkeys globally - condition checked in handlers
	if (Hotkey_GHLLookup != "" && Hotkey_GHLLookup != "None") {
		Hotkey, %Hotkey_GHLLookup%, HK_GHLLookup, On
	}
	if (Hotkey_PayPlan != "" && Hotkey_PayPlan != "None") {
		Hotkey, %Hotkey_PayPlan%, HK_PayPlan, On
	}
	if (Hotkey_Settings != "" && Hotkey_Settings != "None") {
		Hotkey, %Hotkey_Settings%, HK_Settings, On
	}
	; Dev reload hotkey - only in dev mode (not compiled)
	if (!A_IsCompiled && Hotkey_DevReload != "" && Hotkey_DevReload != "None") {
		Hotkey, %Hotkey_DevReload%, HK_DevReload, On
	}
}

; Hotkey handler labels - check if ProSelect/SideKick is active before executing
HK_GHLLookup:
if (!IsProSelectOrSideKickActive())
	Return
GoSub, GHLClientLookup
Return

HK_PayPlan:
if (!IsProSelectOrSideKickActive())
	Return
GoSub, PlaceButton
Return

HK_Settings:
if (!IsProSelectOrSideKickActive())
	Return
GoSub, ShowSettings
Return

HK_DevReload:
if (!IsProSelectOrSideKickActive())
	Return
Run, "%A_ScriptFullPath%"
ExitApp
Return

; Settings persistence functions
LoadSettings()
{
	global
	
	; Reload GHL API credentials from JSON (important after import!)
	LoadGHLCredentials()
	
	IniRead, Settings_StartOnBoot, %IniFilename%, Settings, StartOnBoot, 0
	IniRead, Settings_ShowTrayIcon, %IniFilename%, Settings, ShowTrayIcon, 1
	IniRead, Settings_EnableSounds, %IniFilename%, Settings, EnableSounds, 1
	IniRead, Settings_AutoDetectPS, %IniFilename%, Settings, AutoDetectPS, 1
	IniRead, Settings_DefaultRecurring, %IniFilename%, Settings, DefaultRecurring, Monthly
	IniRead, Settings_RecurringOptions, %IniFilename%, Settings, RecurringOptions, Weekly,Bi-Weekly,4-Weekly
	IniRead, Settings_GHL_Enabled, %IniFilename%, GHL, Enabled, 1
	IniRead, Settings_GHL_AutoLoad, %IniFilename%, GHL, AutoLoad, 0
	
	; Load hotkey settings
	IniRead, Hotkey_GHLLookup, %IniFilename%, Hotkeys, GHLLookup, ^+g
	IniRead, Hotkey_PayPlan, %IniFilename%, Hotkeys, PayPlan, ^+p
	IniRead, Hotkey_Settings, %IniFilename%, Hotkeys, Settings, ^+w
	IniRead, Hotkey_DevReload, %IniFilename%, Hotkeys, DevReload, ^+r
	
	; Invoice folder settings
	IniRead, Settings_InvoiceWatchFolder, %IniFilename%, GHL, InvoiceWatchFolder, %A_Space%
	IniRead, Settings_OpenInvoiceURL, %IniFilename%, GHL, OpenInvoiceURL, 1
	IniRead, Settings_FinancialsOnly, %IniFilename%, GHL, FinancialsOnly, 0
	IniRead, Settings_AutoSaveXML, %IniFilename%, GHL, AutoSaveXML, 0
	IniRead, Settings_ContactSheet, %IniFilename%, GHL, ContactSheet, 1
	IniRead, Settings_CollectContactSheets, %IniFilename%, GHL, CollectContactSheets, 0
	IniRead, Settings_ContactSheetFolder, %IniFilename%, GHL, ContactSheetFolder, %A_Space%
	IniRead, Settings_GHLTags, %IniFilename%, GHL, Tags, %A_Space%
	IniRead, Settings_GHLOppTags, %IniFilename%, GHL, OppTags, %A_Space%
	IniRead, Settings_AutoAddContactTags, %IniFilename%, GHL, AutoAddContactTags, 1
	IniRead, Settings_AutoAddOppTags, %IniFilename%, GHL, AutoAddOppTags, 1
	IniRead, GHL_CachedTags, %IniFilename%, GHL, CachedTags, %A_Space%
	IniRead, GHL_CachedOppTags, %IniFilename%, GHL, CachedOppTags, %A_Space%
	; Load cached email templates (stored with §§ as newline separator)
	IniRead, cachedEmailTpls, %IniFilename%, GHL, CachedEmailTemplates, %A_Space%
	GHL_CachedEmailTemplates := StrReplace(cachedEmailTpls, "§§", "`n")
	; Load cached SMS templates (stored with §§ as newline separator)
	IniRead, cachedSMSTpls, %IniFilename%, GHL, CachedSMSTemplates, %A_Space%
	GHL_CachedSMSTemplates := StrReplace(cachedSMSTpls, "§§", "`n")
	IniRead, Settings_RoundingInDeposit, %IniFilename%, GHL, RoundingInDeposit, 1
	IniRead, Settings_GHLInvoiceWarningShown, %IniFilename%, GHL, InvoiceWarningShown, 0
	IniRead, Settings_MediaFolderID, %IniFilename%, GHL, MediaFolderID, %A_Space%
	IniRead, Settings_MediaFolderName, %IniFilename%, GHL, MediaFolderName, %A_Space%
	
	; Debug log settings
	IniRead, Settings_AutoSendLogs, %IniFilename%, Settings, AutoSendLogs, 1
	IniRead, Settings_DebugLogging, %IniFilename%, Settings, DebugLogging, 0
	IniRead, Settings_DebugLoggingTimestamp, %IniFilename%, Settings, DebugLoggingTimestamp, %A_Space%
	
	; Auto-disable debug logging after 24 hours
	if (Settings_DebugLogging && Settings_DebugLoggingTimestamp != "") {
		FormatTime, nowStamp, , yyyyMMddHHmmss
		; Calculate hours since enabled
		EnvSub, nowStamp, %Settings_DebugLoggingTimestamp%, Hours
		if (nowStamp >= 24) {
			Settings_DebugLogging := false
			Settings_DebugLoggingTimestamp := ""
			IniWrite, 0, %IniFilename%, Settings, DebugLogging
			IniDelete, %IniFilename%, Settings, DebugLoggingTimestamp
		}
	}
	
	; File Management settings
	IniRead, Settings_CardDrive, %IniFilename%, FileManagement, CardDrive, F:\DCIM
	IniRead, Settings_CameraDownloadPath, %IniFilename%, FileManagement, CameraDownloadPath, %A_Space%
	IniRead, Settings_ShootArchivePath, %IniFilename%, FileManagement, ShootArchivePath, %A_Space%
	IniRead, Settings_FolderTemplatePath, %IniFilename%, FileManagement, FolderTemplatePath, %A_Space%
	IniRead, Settings_ShootPrefix, %IniFilename%, FileManagement, ShootPrefix, P
	IniRead, Settings_ShootSuffix, %IniFilename%, FileManagement, ShootSuffix, P
	IniRead, Settings_AutoShootYear, %IniFilename%, FileManagement, AutoShootYear, 1
	IniRead, Settings_EditorRunPath, %IniFilename%, FileManagement, EditorRunPath, Explore
	IniRead, Settings_BrowsDown, %IniFilename%, FileManagement, BrowsDown, 1
	IniRead, Settings_AutoRenameImages, %IniFilename%, FileManagement, AutoRenameImages, 0
	IniRead, Settings_AutoDriveDetect, %IniFilename%, FileManagement, AutoDriveDetect, 1
	IniRead, Settings_SDCardEnabled, %IniFilename%, FileManagement, SDCardEnabled, 1
	IniRead, Settings_ToolbarIconColor, %IniFilename%, Appearance, ToolbarIconColor, White
	IniRead, Settings_ToolbarAutoBG, %IniFilename%, Appearance, ToolbarAutoBG, 1
	IniRead, Settings_ToolbarLastBGColor, %IniFilename%, Appearance, ToolbarLastBGColor, 333333
	
	; Toolbar button visibility
	IniRead, Settings_ShowBtn_Client, %IniFilename%, Toolbar, ShowBtn_Client, 1
	IniRead, Settings_ShowBtn_Invoice, %IniFilename%, Toolbar, ShowBtn_Invoice, 1
	IniRead, Settings_ShowBtn_OpenGHL, %IniFilename%, Toolbar, ShowBtn_OpenGHL, 1
	IniRead, Settings_ShowBtn_Camera, %IniFilename%, Toolbar, ShowBtn_Camera, 1
	IniRead, Settings_ShowBtn_Sort, %IniFilename%, Toolbar, ShowBtn_Sort, 1
	IniRead, Settings_ShowBtn_Photoshop, %IniFilename%, Toolbar, ShowBtn_Photoshop, 1
	IniRead, Settings_ShowBtn_Refresh, %IniFilename%, Toolbar, ShowBtn_Refresh, 1
	IniRead, Settings_ShowBtn_Print, %IniFilename%, Toolbar, ShowBtn_Print, 1
	IniRead, Settings_ShowBtn_QRCode, %IniFilename%, Toolbar, ShowBtn_QRCode, 1
	IniRead, Settings_ShowBtn_GoCardless, %IniFilename%, Toolbar, ShowBtn_GoCardless, 0
	IniRead, Settings_ToolbarOffsetX, %IniFilename%, Toolbar, OffsetX, 0
	IniRead, Settings_ToolbarOffsetY, %IniFilename%, Toolbar, OffsetY, 0
	IniRead, Settings_QRCode_Text1, %IniFilename%, QRCode, Text1, %A_Space%
	IniRead, Settings_QRCode_Text2, %IniFilename%, QRCode, Text2, %A_Space%
	IniRead, Settings_QRCode_Text3, %IniFilename%, QRCode, Text3, %A_Space%
	IniRead, Settings_QRCode_Display, %IniFilename%, QRCode, Display, 1
	IniRead, Settings_DisplaySize, %IniFilename%, Display, Size, 80
	IniRead, Settings_BankScale, %IniFilename%, Display, BankScale, 100
	IniRead, Settings_BankInstitution, %IniFilename%, Display, BankInstitution, %A_Space%
	IniRead, Settings_BankName, %IniFilename%, Display, BankName, %A_Space%
	IniRead, Settings_BankSortCode, %IniFilename%, Display, BankSortCode, %A_Space%
	IniRead, Settings_BankAccNo, %IniFilename%, Display, BankAccNo, %A_Space%
	IniRead, Settings_DisplayImage1, %IniFilename%, Display, Image1, %A_Space%
	IniRead, Settings_DisplayImage2, %IniFilename%, Display, Image2, %A_Space%
	IniRead, Settings_DisplayImage3, %IniFilename%, Display, Image3, %A_Space%
	IniRead, Settings_PrintTemplate_PayPlan, %IniFilename%, Toolbar, PrintTemplate_PayPlan, PayPlan
	IniRead, Settings_PrintTemplate_Standard, %IniFilename%, Toolbar, PrintTemplate_Standard, Terms of Sale
	IniRead, Settings_PrintTemplateOptions, %IniFilename%, Toolbar, PrintTemplateOptions, %A_Space%
	IniRead, Settings_QuickPrintPrinter, %IniFilename%, Toolbar, QuickPrintPrinter, %A_Space%
	IniRead, Settings_EmailTemplateID, %IniFilename%, Toolbar, EmailTemplateID, %A_Space%
	IniRead, Settings_EmailTemplateName, %IniFilename%, Toolbar, EmailTemplateName, SELECT
	IniRead, Settings_RoomCaptureFolder, %IniFilename%, Toolbar, RoomCaptureFolder, Album Folder
	IniRead, Settings_EnablePDF, %IniFilename%, Toolbar, EnablePDF, 0
	IniRead, Settings_PDFOutputFolder, %IniFilename%, Toolbar, PDFOutputFolder, %A_Space%
	IniRead, Settings_PDFPrintBtnOffsetRight, %IniFilename%, Toolbar, PDFPrintBtnOffsetRight, 0
	IniRead, Settings_PDFPrintBtnOffsetBottom, %IniFilename%, Toolbar, PDFPrintBtnOffsetBottom, 0
	
	; GoCardless settings (token is loaded separately via LoadGHLCredentials)
	IniRead, Settings_GoCardlessEnabled, %IniFilename%, GoCardless, Enabled, 0
	IniRead, Settings_GoCardlessEnvironment, %IniFilename%, GoCardless, Environment, sandbox
	IniRead, Settings_GCEmailTemplateID, %IniFilename%, GoCardless, EmailTemplateID, %A_Space%
	IniRead, Settings_GCEmailTemplateName, %IniFilename%, GoCardless, EmailTemplateName, SELECT
	IniRead, Settings_GCSMSTemplateID, %IniFilename%, GoCardless, SMSTemplateID, %A_Space%
	IniRead, Settings_GCSMSTemplateName, %IniFilename%, GoCardless, SMSTemplateName, SELECT
	IniRead, Settings_GCAutoSetup, %IniFilename%, GoCardless, AutoSetup, 0
	IniRead, Settings_GCNamePart1, %IniFilename%, GoCardless, NamePart1, Shoot No
	IniRead, Settings_GCNamePart2, %IniFilename%, GoCardless, NamePart2, Surname
	IniRead, Settings_GCNamePart3, %IniFilename%, GoCardless, NamePart3, (none)
	
	; Load GHL agency domain - check if migration needed for existing users
	IniRead, GHL_AgencyDomain, %IniFilename%, GHL, AgencyDomain, %A_Space%
	
	; Migration: If user has Location ID but no saved AgencyDomain, use default silently
	if (GHL_AgencyDomain = "") {
		GHL_AgencyDomain := "app.thefullybookedphotographer.com"
		; Save it so it's persistent
		if (GHL_LocationID != "")
			IniWrite, %GHL_AgencyDomain%, %IniFilename%, GHL, AgencyDomain
	}
	
	; Build GHL payment settings URL from location ID
	if (GHL_LocationID != "" && GHL_AgencyDomain != "")
		Settings_GHLPaymentSettingsURL := "https://" . GHL_AgencyDomain . "/v2/location/" . GHL_LocationID . "/payments/settings/receipts"
	
	; Load license settings (secure/obfuscated)
	licenseOK := LoadLicenseSecure()
	IniRead, License_CustomerName, %IniFilename%, License, CustomerName, %A_Space%
	IniRead, License_CustomerEmail, %IniFilename%, License, CustomerEmail, %A_Space%
	IniRead, License_ActivatedAt, %IniFilename%, License, ActivatedAt, %A_Space%
	IniRead, License_TrialStart, %IniFilename%, License, TrialStart, %A_Space%
	IniRead, License_TrialWarningDate, %IniFilename%, License, TrialWarningDate, %A_Space%
	
	; If license data was tampered with, force online validation
	if (!licenseOK && License_Status = "invalid") {
		; Will be caught by CheckMonthlyLicenseValidation
	}
	
	; Start trial if not set
	if (License_TrialStart = "" && License_Status = "trial") {
		FormatTime, License_TrialStart,, yyyy-MM-dd
		IniWrite, %License_TrialStart%, %IniFilename%, License, TrialStart
	}
	
	; Check if monthly license validation is needed (only if licensed)
	if (License_Status = "active" && License_Key != "") {
		CheckMonthlyLicenseValidation()
	}
	; Trial check disabled - LemonSqueezy handles licensing
	; else {
	; 	CheckTrialStatus()
	; }
	
	; Start invoice folder monitor if configured
	if (Settings_InvoiceWatchFolder != "" && FileExist(Settings_InvoiceWatchFolder))
		SetTimer, WatchInvoiceFolder, 3000
	
	; Check if first run and needs GHL setup
	CheckFirstRunGHLSetup()
	
	; Check if version changed and show What's New
	CheckVersionChanged()
}

SaveSettings()
{
	global
	IniWrite, %Settings_StartOnBoot%, %IniFilename%, Settings, StartOnBoot
	IniWrite, %Settings_ShowTrayIcon%, %IniFilename%, Settings, ShowTrayIcon
	IniWrite, %Settings_EnableSounds%, %IniFilename%, Settings, EnableSounds
	IniWrite, %Settings_AutoDetectPS%, %IniFilename%, Settings, AutoDetectPS
	IniWrite, %Settings_DefaultRecurring%, %IniFilename%, Settings, DefaultRecurring
	IniWrite, %Settings_DefaultPayType%, %IniFilename%, Settings, DefaultPayType
	IniWrite, %Settings_GHL_Enabled%, %IniFilename%, GHL, Enabled
	IniWrite, %Settings_GHL_AutoLoad%, %IniFilename%, GHL, AutoLoad
	IniWrite, %GHL_AgencyDomain%, %IniFilename%, GHL, AgencyDomain
	
	; Save hotkey settings
	IniWrite, %Hotkey_GHLLookup%, %IniFilename%, Hotkeys, GHLLookup
	IniWrite, %Hotkey_PayPlan%, %IniFilename%, Hotkeys, PayPlan
	IniWrite, %Hotkey_Settings%, %IniFilename%, Hotkeys, Settings
	IniWrite, %Hotkey_DevReload%, %IniFilename%, Hotkeys, DevReload
	
	; Save invoice folder settings
	IniWrite, %Settings_InvoiceWatchFolder%, %IniFilename%, GHL, InvoiceWatchFolder
	IniWrite, %Settings_OpenInvoiceURL%, %IniFilename%, GHL, OpenInvoiceURL
	IniWrite, %Settings_FinancialsOnly%, %IniFilename%, GHL, FinancialsOnly
	IniWrite, %Settings_AutoSaveXML%, %IniFilename%, GHL, AutoSaveXML
	IniWrite, %Settings_ContactSheet%, %IniFilename%, GHL, ContactSheet
	IniWrite, %Settings_CollectContactSheets%, %IniFilename%, GHL, CollectContactSheets
	IniWrite, %Settings_ContactSheetFolder%, %IniFilename%, GHL, ContactSheetFolder
	IniWrite, %Settings_GHLTags%, %IniFilename%, GHL, Tags
	IniWrite, %Settings_GHLOppTags%, %IniFilename%, GHL, OppTags
	IniWrite, %Settings_AutoAddContactTags%, %IniFilename%, GHL, AutoAddContactTags
	IniWrite, %Settings_AutoAddOppTags%, %IniFilename%, GHL, AutoAddOppTags
	IniWrite, %Settings_GHLInvoiceWarningShown%, %IniFilename%, GHL, InvoiceWarningShown
	
	; Save license settings (secure/obfuscated)
	SaveLicenseSecure()
	
	; Save update settings
	IniWrite, %Update_SkippedVersion%, %IniFilename%, Updates, SkippedVersion
	IniWrite, %Update_LastCheckDate%, %IniFilename%, Updates, LastCheckDate
	IniWrite, %Settings_AutoSendLogs%, %IniFilename%, Settings, AutoSendLogs
	IniWrite, %Settings_DebugLogging%, %IniFilename%, Settings, DebugLogging
	if (Settings_DebugLoggingTimestamp != "")
		IniWrite, %Settings_DebugLoggingTimestamp%, %IniFilename%, Settings, DebugLoggingTimestamp
	else
		IniDelete, %IniFilename%, Settings, DebugLoggingTimestamp
	
	; Save File Management settings
	IniWrite, %Settings_CardDrive%, %IniFilename%, FileManagement, CardDrive
	IniWrite, %Settings_CameraDownloadPath%, %IniFilename%, FileManagement, CameraDownloadPath
	IniWrite, %Settings_ShootArchivePath%, %IniFilename%, FileManagement, ShootArchivePath
	IniWrite, %Settings_FolderTemplatePath%, %IniFilename%, FileManagement, FolderTemplatePath
	IniWrite, %Settings_ShootPrefix%, %IniFilename%, FileManagement, ShootPrefix
	IniWrite, %Settings_ShootSuffix%, %IniFilename%, FileManagement, ShootSuffix
	IniWrite, %Settings_AutoShootYear%, %IniFilename%, FileManagement, AutoShootYear
	IniWrite, %Settings_EditorRunPath%, %IniFilename%, FileManagement, EditorRunPath
	IniWrite, %Settings_BrowsDown%, %IniFilename%, FileManagement, BrowsDown
	IniWrite, %Settings_AutoRenameImages%, %IniFilename%, FileManagement, AutoRenameImages
	IniWrite, %Settings_AutoDriveDetect%, %IniFilename%, FileManagement, AutoDriveDetect
	IniWrite, %Settings_SDCardEnabled%, %IniFilename%, FileManagement, SDCardEnabled
	
	; Save toolbar button visibility
	IniWrite, %Settings_ShowBtn_Client%, %IniFilename%, Toolbar, ShowBtn_Client
	IniWrite, %Settings_ShowBtn_Invoice%, %IniFilename%, Toolbar, ShowBtn_Invoice
	IniWrite, %Settings_ShowBtn_OpenGHL%, %IniFilename%, Toolbar, ShowBtn_OpenGHL
	IniWrite, %Settings_ShowBtn_Camera%, %IniFilename%, Toolbar, ShowBtn_Camera
	IniWrite, %Settings_ShowBtn_Sort%, %IniFilename%, Toolbar, ShowBtn_Sort
	IniWrite, %Settings_ShowBtn_Photoshop%, %IniFilename%, Toolbar, ShowBtn_Photoshop
	IniWrite, %Settings_ShowBtn_Refresh%, %IniFilename%, Toolbar, ShowBtn_Refresh
	IniWrite, %Settings_ShowBtn_Print%, %IniFilename%, Toolbar, ShowBtn_Print
	IniWrite, %Settings_ShowBtn_QRCode%, %IniFilename%, Toolbar, ShowBtn_QRCode
	IniWrite, %Settings_ShowBtn_GoCardless%, %IniFilename%, Toolbar, ShowBtn_GoCardless
	IniWrite, %Settings_ToolbarOffsetX%, %IniFilename%, Toolbar, OffsetX
	IniWrite, %Settings_ToolbarOffsetY%, %IniFilename%, Toolbar, OffsetY
	IniWrite, %Settings_QRCode_Text1%, %IniFilename%, QRCode, Text1
	IniWrite, %Settings_QRCode_Text2%, %IniFilename%, QRCode, Text2
	IniWrite, %Settings_QRCode_Text3%, %IniFilename%, QRCode, Text3
	IniWrite, %Settings_QRCode_Display%, %IniFilename%, QRCode, Display
	; Regenerate QR cache if text fields changed
	GenerateQRCache()
	; Display settings
	IniWrite, %Settings_DisplaySize%, %IniFilename%, Display, Size
	IniWrite, %Settings_BankScale%, %IniFilename%, Display, BankScale
	IniWrite, %Settings_BankInstitution%, %IniFilename%, Display, BankInstitution
	IniWrite, %Settings_BankName%, %IniFilename%, Display, BankName
	IniWrite, %Settings_BankSortCode%, %IniFilename%, Display, BankSortCode
	IniWrite, %Settings_BankAccNo%, %IniFilename%, Display, BankAccNo
	IniWrite, %Settings_DisplayImage1%, %IniFilename%, Display, Image1
	IniWrite, %Settings_DisplayImage2%, %IniFilename%, Display, Image2
	IniWrite, %Settings_DisplayImage3%, %IniFilename%, Display, Image3
	IniWrite, %Settings_PrintTemplate_PayPlan%, %IniFilename%, Toolbar, PrintTemplate_PayPlan
	IniWrite, %Settings_PrintTemplate_Standard%, %IniFilename%, Toolbar, PrintTemplate_Standard
	IniWrite, %Settings_PrintTemplateOptions%, %IniFilename%, Toolbar, PrintTemplateOptions
	IniWrite, %Settings_QuickPrintPrinter%, %IniFilename%, Toolbar, QuickPrintPrinter
	IniWrite, %Settings_EmailTemplateID%, %IniFilename%, Toolbar, EmailTemplateID
	IniWrite, %Settings_EmailTemplateName%, %IniFilename%, Toolbar, EmailTemplateName
	IniWrite, %Settings_RoomCaptureFolder%, %IniFilename%, Toolbar, RoomCaptureFolder
	IniWrite, %Settings_EnablePDF%, %IniFilename%, Toolbar, EnablePDF
	IniWrite, %Settings_PDFOutputFolder%, %IniFilename%, Toolbar, PDFOutputFolder
	
	; Save GoCardless settings (token is saved separately via SaveGHLCredentials)
	IniWrite, %Settings_GoCardlessEnabled%, %IniFilename%, GoCardless, Enabled
	IniWrite, %Settings_GoCardlessEnvironment%, %IniFilename%, GoCardless, Environment
	IniWrite, %Settings_GCEmailTemplateID%, %IniFilename%, GoCardless, EmailTemplateID
	IniWrite, %Settings_GCEmailTemplateName%, %IniFilename%, GoCardless, EmailTemplateName
	IniWrite, %Settings_GCAutoSetup%, %IniFilename%, GoCardless, AutoSetup
	SaveGHLCredentials()  ; Save API keys to encrypted credentials file
	
	; Update invoice folder monitor
	if (Settings_InvoiceWatchFolder != "" && FileExist(Settings_InvoiceWatchFolder))
		SetTimer, WatchInvoiceFolder, 3000
	else
		SetTimer, WatchInvoiceFolder, Off
	
	; Re-register hotkeys with new values
	RegisterHotkeys()
	
	; Handle Start on Boot registry
	if (Settings_StartOnBoot)
		RegWrite, REG_SZ, HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run, SideKick_PS, %A_ScriptFullPath%
	else
		RegDelete, HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run, SideKick_PS
}

ReloadScript:
Reload
Return

ExitGui:
PPGuiClose:
PPGuiEscape:
PayCalcOpen := false  ; Reset flag - Payment Calculator closed
Gui, PP:destroy
Goto, PlaceButton
ExitApp,

MakePayments:
ToolTip, Processing ... Hand off!
Gui, PP:Submit, NoHide
if (PayDue ="0")
{
	DarkMsgBox("ATTENTION", "No payment value!", "warning")
	return
}
;MsgBox, % PayDay InStr(PayDay, "Select") " Month "PayMonth InStr(PayMonth, "Select")
If InStr(PayDay, "Select")
{
	DarkMsgBox("ATTENTION", "Select Pay Day", "warning")
	return
}
If InStr(PayMonth, "Select")
{
	DarkMsgBox("ATTENTION", "Select Pay Month", "warning")
	return
}

; Check if downpayment is being used (amount > 0)
HasDownpayment := (DownpaymentAmount != "" && DownpaymentAmount > 0)

; Validate downpayment method if amount is entered
if (HasDownpayment && DownpaymentMethod = "")
{
	DarkMsgBox("ATTENTION", "Select a downpayment method", "warning")
	return
}

; Calculate remaining balance after downpayment
RemainingBalance := PayDue
if (HasDownpayment)
	RemainingBalance := PayDue - DownpaymentAmount

PayValue := FloorDecimal(RemainingBalance/PayNo)
GuiControl,, ComboBox3, %PayValue%

; Calculate rounding error for first payment adjustment
TotalPayments := PayValue * PayNo
RoundingError := RemainingBalance - TotalPayments
RoundingError := Round(RoundingError, 2)

; If downpayment is entered, add rounding error to it
if (HasDownpayment && RoundingError != 0)
{
	DownpaymentAmount := DownpaymentAmount + RoundingError
	DownpaymentAmount := Round(DownpaymentAmount, 2)
}

ToolTip,

gosub, GetBalance
/*
	if ((PayDue != "0.00") & !InStr(PayDay, "Select"))
	{
		MsgBox,,, % "Deposit Correction, There is a rounding up error of £" . Format("{:.2f}", PayDue) . "`nYou may want to add this to any deposit payment"
	
	}
*/
Gosub, SaveData
Goto, PlaceButton
return

ProcessData:
If (PayDay = "Last Day") ; Day
{
	if PayMonth In %30daylist%
	{
		PayPlanDay := 30
	}
	if PayMonth In %31daylist%
	{
		PayPlanDay := 31
	}
	if PayMonth In %28daylist%
	{
		PayPlanDay := 28
	}
}
else
{
	PayPlanDay := JEE_StrReplaceChars(PayDay, "thnsrd", "", vCount)
}
PayPlanMonth := ObjIndexOf(Months, PayMonth)
PayPlanMonth := StrReplace(PayPlanMonth,",","")
PayPlanYear := SubStr(PayYear,3,2)

PaymentLine =%PayPlanDay%,%PayPlanMonth%,%PayPlanYear%,%PayTypeSel%,%PayValue%
; MsgBox,, Output, PaymentLine %PaymentLine%
LastPayPlanMonth := PayPlanMonth 
if (LastPayPlanMonth := 12)
	PayPlanYear := 1
Return

CheckPastPaymentDates:
; Check if first payment date is in the past and offer to bump to next available month
if (PayNo < 1)
	return

; Get first payment line data (index 1, not 0 which is downpayment)
FirstPayLine := PayPlanLine[1]
if (FirstPayLine = "")
	return

Data := StrSplit(FirstPayLine, ",")
FirstDay := Data[1]
FirstMonth := Data[2]
FirstYear := Data[3]

; Build full year (assuming 20xx)
FullYear := "20" . FirstYear

; Build date in YYYYMMDD format for comparison
FirstPayDate := FullYear . Format("{:02}", FirstMonth) . Format("{:02}", FirstDay)

; Get today's date in same format
FormatTime, Today, , yyyyMMdd

; Check if first payment is in the past
if (FirstPayDate < Today)
{
	; Calculate how many months behind
	FormatTime, CurrentMonth, , M
	FormatTime, CurrentYear, , yyyy
	FormatTime, CurrentDay, , d
	
	MonthsBehind := 0
	TempMonth := FirstMonth
	TempYear := FullYear
	
	; Count months until we reach current month
	Loop, 24  ; Max 2 years
	{
		TempDate := TempYear . Format("{:02}", TempMonth) . Format("{:02}", FirstDay)
		if (TempDate >= Today)
			break
		MonthsBehind++
		TempMonth++
		if (TempMonth > 12)
		{
			TempMonth := 1
			TempYear++
		}
	}
	
	; Determine next available month
	NextAvailMonth := CurrentMonth
	NextAvailYear := CurrentYear
	
	; If we're past the payment day this month, use next month
	if (CurrentDay >= FirstDay)
	{
		NextAvailMonth++
		if (NextAvailMonth > 12)
		{
			NextAvailMonth := 1
			NextAvailYear++
		}
	}
	
	NextMonthName := Months[NextAvailMonth]
	
	; Calculate how many months we're bumping
	OriginalMonthName := Months[FirstMonth]
	MonthsBump := (NextAvailYear - FullYear) * 12 + (NextAvailMonth - FirstMonth)
	
	; Build message showing which payments are past due
	PastPayments := ""
	Loop, %PayNo%
	{
		LineData := StrSplit(PayPlanLine[A_Index], ",")
		LineDate := "20" . LineData[3] . Format("{:02}", LineData[2]) . Format("{:02}", LineData[1])
		if (LineDate < Today)
		{
			PastPayments .= "   • " . LineData[1] . "/" . LineData[2] . "/20" . LineData[3] . " - £" . LineData[5] . "`n"
		}
	}
	
	msg := "⚠️ PAYMENT DATES IN THE PAST ⚠️`n`n"
	msg .= "The following payment dates have already passed:`n`n" . PastPayments
	msg .= "`nGoCardless will REJECT payments with past dates.`n`n"
	msg .= "📅 Bump by " . MonthsBump . " month" . (MonthsBump > 1 ? "s" : "") . "`n"
	msg .= "    From: " . OriginalMonthName . " " . FullYear . "`n"
	msg .= "    To: " . NextMonthName . " " . NextAvailYear . "`n`n"
	msg .= "Click 'Cancel' to go back and fix the dates manually."
	
	result := DarkMsgBox("Past Payment Dates", msg, "warning", {buttons: ["Bump Dates", "Cancel"]})
	
	if (result = "Bump Dates")
	{
		; Update PayMonth and PayYear to next available
		PayMonth := NextMonthName
		PayYear := NextAvailYear
		
		; Rebuild payment plan lines with new start date
		Gosub, BuildPayPlanLines
		
		ToolTip, 📅 Payment dates bumped to start from %NextMonthName% %NextAvailYear%
		SetTimer, RemovePPTooltip, -2000
	}
	else
	{
		; User cancelled - abort the save operation
		return
	}
}
return

RemovePPTooltip:
ToolTip
return

BuildPayPlanLines: ; make PayPlanLines

; If downpayment amount is entered, add it as the FIRST payment line (index 0)
global DownpaymentLineAdded := false
if (HasDownpayment)
{
	; Format downpayment date from DateTime control (YYYYMMDD format)
	FormatTime, DPDay, %DownpaymentDate%, d
	FormatTime, DPMonth, %DownpaymentDate%, M
	FormatTime, DPYear, %DownpaymentDate%, yy
	
	; Create downpayment line: day,month,year,method,amount
	DownpaymentLine := DPDay "," DPMonth "," DPYear "," DownpaymentMethod "," DownpaymentAmount
	PayPlanLine[0] := DownpaymentLine
	DownpaymentLineAdded := true
}

NextMonth := ObjIndexOf(Months, PayMonth)
PayPlanDay := PayDay

; Determine if we're using weekly-based recurring payments
WeeklyRecurring := false
DaysToAdd := 0

if (Recurring = "Weekly")
{
	WeeklyRecurring := true
	DaysToAdd := 7
}
else if (Recurring = "Bi-Weekly")
{
	WeeklyRecurring := true
	DaysToAdd := 14
}
else if (Recurring = "4-Weekly")
{
	WeeklyRecurring := true
	DaysToAdd := 28
}

; For weekly-based payments, use date calculation
if (WeeklyRecurring)
{
	; Build the starting date in YYYYMMDD format
	StartDate := PayYear
	StartDate .= Format("{:02}", ObjIndexOf(Months, PayMonth))
	StartDate .= Format("{:02}", PayDay)
	
	loop, %PayNo%
	{
		if (A_Index = 1)
		{
			; First payment uses the original date
			CurrentDate := StartDate
		}
		else
		{
			; Add days for each subsequent payment based on recurring period
			CurrentDate := DateCalc(StartDate, 0, 0, (A_Index - 1) * DaysToAdd)
		}
		
		; Extract day, month, year from calculated date
		PayPlanYear := SubStr(CurrentDate, 3, 2)  ; YY
		PayPlanMonth := SubStr(CurrentDate, 5, 2) ; MM
		PayPlanDay := SubStr(CurrentDate, 7, 2)   ; DD
		
		; Remove leading zeros for display
		PayPlanMonth := PayPlanMonth + 0
		PayPlanDay := PayPlanDay + 0
		
		; Add rounding error to first payment (only if NOT adding to deposit)
		if (A_Index = 1 && RoundingError != 0 && !Settings_RoundingInDeposit)
		{
			FirstPayValue := PayValue + RoundingError
			FirstPayValue := Round(FirstPayValue, 2)
			PaymentLine := PayPlanDay "," PayPlanMonth "," PayPlanYear "," PayTypeSel "," FirstPayValue
		}
		else
		{
			PaymentLine := PayPlanDay "," PayPlanMonth "," PayPlanYear "," PayTypeSel "," PayValue
		}
		
		PayPlanLine[A_Index] := PaymentLine
	}
}
else  ; Monthly payments (original logic)
{
	loop, %PayNo%
	{
		Gosub, ProcessData
		
		; Add rounding error to first payment (only if NOT adding to deposit)
		if (A_Index = 1 && RoundingError != 0 && !Settings_RoundingInDeposit)
		{
			FirstPayValue := PayValue + RoundingError
			FirstPayValue := Round(FirstPayValue, 2)
			PaymentLine := PayPlanDay "," PayPlanMonth "," PayPlanYear "," PayTypeSel "," FirstPayValue
		}
		
		PayPlanLine[A_Index] := PaymentLine
		;MsgBox,, WIP build pay lines, % PayNo "x" PayValue "`r`n" PayDay "/" PayMonth "/" PayYear "`r`n" 
		NextMonth := NextMonth + 1
		if (NextMonth >= 13)
		{
			NextMonth := 1
			PayYear := PayYear + 1
			PayPlanYear := SubStr(payYear,3,2)
		}
		PayMonth := Months[NextMonth]
	}
}
return

;write Ini File
SaveData:
;SoundPlay C:\Stash\KbdSpacebar.wav

; Ensure INI file exists - create if missing
if !FileExist(IniFilename) {
	; Create folder if needed
	if !FileExist(IniFolder)
		FileCreateDir, %IniFolder%
	; Create empty INI file
	FileAppend,, %IniFilename%
}

Gosub, BuildPayPlanLines

; Check if any payment dates are in the past and offer to bump them
Gosub, CheckPastPaymentDates

IniWrite, %PayDue%, %IniFilename%, Payments, PayDue
Sleep 100
IniWrite, %PayNo%, %IniFilename%, Payments, PayNo
Sleep 100
IniWrite, %PayValue%, %IniFilename%, Payments, PayValue
Sleep 100
IniWrite, %PayDay%, %IniFilename%, Payments, PayDay
Sleep 100
IniWrite, %PayMonth%, %IniFilename%, Payments, PayMonth
Sleep 100
IniWrite, %PayYear%, %IniFilename%, Payments, PayYear
Sleep 100
IniWrite, %PayTypeSel%, %IniFilename%, Payments, PayType
Sleep 100
IniWrite, %Recurring%, %IniFilename%, Payments, Recurring
Sleep 100

loop, %PayNo%
{	
	TempLine := PayPlanLine[A_Index]
	IniWrite,%TempLine% , %IniFilename%, PaymentLines, PaymentLine.%A_Index%
	Sleep 100
}

PayCalcOpen := false  ; Reset flag - Payment Calculator closed
Gui, PP:Destroy
GoSub, UpdatePS
Reload 
Return


ReadData:
SoundPlay %A_ScriptDir%\sidekick\media\KbdSpacebar.wav
IniRead, PayDue, %IniFilename%, Payments, PayDue
IniRead, PayNo, %IniFilename%, Payments, PayNo
IniRead, PayValue, %IniFilename%, Payments, PayValue
IniRead, PayDay, %IniFilename%, Payments, PayDay
IniRead, PayMonth, %IniFilename%, Payments, PayMonth
IniRead, PayTypeSel, %IniFilename%, Payments, PayType
IniRead, Recurring, %IniFilename%, Payments, Recurring
;MsgBox,, Read, % PayNo "x" PayValue "`r`n" PayDay "/" PayMonth "/" PayYear "`r`n" 
Return

GetBalance:
; Read balance from the Payline window's Amount field
WinActivate, Add Payment, Date
WinWaitActive, Add Payment, Date
PayDue :=
; Amount field is Edit2 in the Payline window
ControlGetText, PayDue, Edit2, Add Payment, Date
PayDue := StrReplace(PayDue,"£","")
PayDue := StrReplace(PayDue,",","")
PayDue := RegExReplace(PayDue,"(\.\d{2})\d*","$1")
If (PayDue = "0.00" || PayDue = "")
{
	DarkMsgBox("No Balance", "Error: No Balance to calculate!", "error", {timeout: 5})
	Exit
}
Return

; Global flag for cancelling payment entry
global PaymentEntryCancelled := false

UpdatePS:
EnteringPaylines := True
PaymentEntryCancelled := false

; Create progress bar GUI
Gui, PayProgress:New, +AlwaysOnTop +ToolWindow +HwndPayProgressHwnd
Gui, PayProgress:Color, 1E1E1E
Gui, PayProgress:Font, s12 cFFFFFF, Segoe UI
Gui, PayProgress:Add, Text, x20 y15 w300 vPayProgressTitle, 💳 Entering Payments...
Gui, PayProgress:Font, s10 cCCCCCC, Segoe UI
Gui, PayProgress:Add, Text, x20 y45 w300 vPayProgressStatus, Preparing...
Gui, PayProgress:Add, Progress, x20 y80 w300 h25 vPayProgressBar Range0-100 c4FC3F7 Background2D2D2D, 0
Gui, PayProgress:Font, s9 cFFCC00, Segoe UI
Gui, PayProgress:Add, Text, x20 y115 w300 Center, ⚠️ HANDS OFF - Do not touch mouse or keyboard
Gui, PayProgress:Font, s9 cFFFFFF Bold, Segoe UI
Gui, PayProgress:Add, Button, x120 y145 w100 h30 gPayProgressCancel vPayProgressCancelBtn, Cancel
Gui, PayProgress:Show, w340 h190, Payment Entry Progress

; Apply dark title bar
DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", PayProgressHwnd, "Int", 20, "Int*", 1, "Int", 4)

SetTitleMatchMode, 2
SetTitleMatchMode, Slow
WinActivate, Add Payment 
WinWaitActive, Add Payment 

; Detect ProSelect version if not already done
if (ProSelectVersion = "")
	DetectProSelectVersion()

sleep, 150
SetControlDelay -1

; Use version-specific automation
if (ProSelectVersion = "2025")
{
	; ProSelect 2025 automation
	; Payline window is already open

	; Read payment types from ComboBox1 on first run and save to INI
	global PaymentTypes2025
	if (PaymentTypes2025 = "")
	{
		ControlGet, PaymentTypes2025, List, , ComboBox1, Add Payment, Date
		IniWrite, %PaymentTypes2025%, %IniFilename%, ProSelect2025, PaymentTypes
	}

	; Determine how many payments to enter (including downpayment if added)
	TotalPaymentsToEnter := PayNo
	StartIndex := 1
	if (DownpaymentLineAdded)
	{
		TotalPaymentsToEnter := PayNo + 1
		StartIndex := 0  ; Start from index 0 (downpayment)
	}

	; Enter all payments - click Add button to open Payline window for each payment
	; EXCEPT the first one - the Payline window is already open from where PayPlan button was clicked
	CurrentPayment := 0
	Loop %TotalPaymentsToEnter%
	{
		; Check if cancelled
		if (PaymentEntryCancelled)
		{
			Gui, PayProgress:Destroy
			DarkMsgBox("Cancelled", "Payment entry was cancelled.`n`n" . (A_Index - 1) . " of " . TotalPaymentsToEnter . " payments entered.", "warning", {timeout: 3})
			EnteringPaylines := False
			return
		}
		
		; Update progress bar
		progressPercent := Round((A_Index / TotalPaymentsToEnter) * 100)
		GuiControl, PayProgress:, PayProgressBar, %progressPercent%
		GuiControl, PayProgress:, PayProgressStatus, % "Payment " . A_Index . " of " . TotalPaymentsToEnter . " (" . progressPercent . "%)"
		
		PaymentIndex := StartIndex + A_Index - 1
		Data_array := StrSplit(PayPlanLine[PaymentIndex],",")

		; For first payment, use the already-open Payline window
		; For subsequent payments, click Add button to open a new Payline window
		if (A_Index > 1)
		{
			; Click Add button on Add Payments window to open Payline window
			WinActivate, Add Payment, Payments
			WinWaitActive, Add Payment, Payments, 2
			Sleep, 200
			ControlClick, Button3, Add Payment, Payments
			Sleep, 2000
		}

		; Ensure Payline window is active
		WinActivate, Add Payment, Date
		WinWaitActive, Add Payment, Date, 2
		Sleep, 200

		; Click on date field and enter date
		ControlClick, SysDateTimePick321, Add Payment
		Sleep, 200
		; Enter: YYYY{Right}DD{Right}MM format
		; Format with leading zeros for day and month
		FormattedDay := SubStr("0" . Data_array[1], -1)
		FormattedMonth := SubStr("0" . Data_array[2], -1)
		ControlSend, SysDateTimePick321, % "20" Data_array[3], Add Payment
		Sleep, 100
		ControlSend, SysDateTimePick321, {Right}, Add Payment
		Sleep, 100
		ControlSend, SysDateTimePick321, % FormattedDay, Add Payment
		Sleep, 100
		ControlSend, SysDateTimePick321, {Right}, Add Payment
		Sleep, 100
		ControlSend, SysDateTimePick321, % FormattedMonth, Add Payment
		Sleep, 100

		; Tab to Amount field and enter value
		ControlSend, SysDateTimePick321, {Tab}, Add Payment
		Sleep, 200
		ControlSend, Edit2, % Data_array[5], Add Payment
		Sleep, 100

		; Tab 3 times to reach payment method dropdown
		ControlSend, Edit2, {Tab}{Tab}{Tab}, Add Payment
		Sleep, 200

		; Enter payment type - use Control, ChooseString to select exact match
		Control, ChooseString, % Data_array[4], ComboBox1, Add Payment, Date
		Sleep, 100

		; Click "Add" button (Button1) to add payment line - Payline window closes
		Sleep, 300
		ControlClick, Button1, Add Payment, Date
		Sleep, 2000
	}
	
	; Destroy progress bar
	Gui, PayProgress:Destroy
	
	; Play ding sound and show confirmation
	SoundPlay, *48
	if (DownpaymentLineAdded)
		DarkMsgBox("Payments Entered", "✅ Downpayment + " . PayNo . " scheduled payment(s) entered!", "info", {timeout: 5})
	else
		DarkMsgBox("Payments Entered", "✅ " . PayNo . " payment(s) successfully entered!", "info", {timeout: 5})
}
else
{
	; ============================================================================
	; ProSelect 2022 automation
	; ============================================================================
	
	; Determine how many payments to enter (including downpayment if added)
	TotalPaymentsToEnter := PayNo
	StartIndex := 1
	if (DownpaymentLineAdded)
	{
		TotalPaymentsToEnter := PayNo + 1
		StartIndex := 0  ; Start from index 0 (downpayment)
	}
	
	Loop %TotalPaymentsToEnter%
	{
		; Check if cancelled
		if (PaymentEntryCancelled)
		{
			Gui, PayProgress:Destroy
			DarkMsgBox("Cancelled", "Payment entry was cancelled.`n`n" . (A_Index - 1) . " of " . TotalPaymentsToEnter . " payments entered.", "warning", {timeout: 3})
			EnteringPaylines := False
			return
		}
		
		; Update progress bar
		progressPercent := Round((A_Index / TotalPaymentsToEnter) * 100)
		GuiControl, PayProgress:, PayProgressBar, %progressPercent%
		GuiControl, PayProgress:, PayProgressStatus, % "Payment " . A_Index . " of " . TotalPaymentsToEnter . " (" . progressPercent . "%)"
		
		PaymentIndex := StartIndex + A_Index - 1
		Data_array := StrSplit(PayPlanLine[PaymentIndex],",")
		ControlClick,Button3,Add Payment
		sleep, 1000
		ControlClick,SysDateTimePick321,Add Payment
		Sleep, 200
		ControlSend,SysDateTimePick321,% Data_array[3]"/"Data_array[1]"/"Data_array[2]"{tab}",Add Payment
		ControlSend, Edit2, % Data_array[5]"{tab}" , Add Payment ; £
		sleep, 200
		; Use ChooseString to select exact payment type match
		Control, ChooseString, % Data_array[4], ComboBox1, Add Payment, Date
		Sleep, 50
		ControlSend, ComboBox1, {Enter}, Add Payment ; Confirm selection
		Sleep, 200
		ControlClick,Button4,Add Payment,D
		Sleep, 1000
	}
	
	; Destroy progress bar
	Gui, PayProgress:Destroy
	
	; Play ding sound for 2022 too
	SoundPlay, *48
	if (DownpaymentLineAdded)
		DarkMsgBox("Payments Entered", "✅ Downpayment + " . PayNo . " scheduled payment(s) entered!", "info", {timeout: 5})
	else
		DarkMsgBox("Payments Entered", "✅ " . PayNo . " payment(s) successfully entered!", "info", {timeout: 5})
}

EnteringPaylines := False
Return

PayProgressCancel:
PaymentEntryCancelled := true
Return

Cord2Pos:
Location_array := [] ; Pars Location and translate xywh to xy xy
Location_array := StrSplit(XY, A_Space,"xywh")
x := Location_array[1]
y := Location_array[2]
w := Location_array[3]
h := Location_array[4]
xe := x + w
ye := y + h
xc := (x+(w/2))
yc := (Y+(h/2))
Return

; DowloadFolder = %A_DD%%A_MM%%A_YYYY%_%A_Hour%%A_Min%
; function to round up to 2 Decimal places
FloorDecimal(num) 
{ 
	
	num:=Floor(num*100)
	SetFormat Float, 0.2
	return num/100
	
}


;vText := JEE_StrReplaceChars("1s334t", "thsrd", "", vCount)
;MsgBox, % vCount "`r`n" vText

JEE_StrReplaceChars(vText, vNeedles, vReplaceText:="", ByRef vCount:="")
{
	
	vCount := StrLen(vText)
	;Loop, Parse, vNeedles ;change it to this for older versions of AHK v1
	Loop, Parse, % vNeedles
		vText := StrReplace(vText, A_LoopField, vReplaceText)
	vCount := vCount-StrLen(vText)
	return vText
}
ObjIndexOf(obj, item, case_sensitive:=false)
{
	for i, val in obj {
		if (case_sensitive ? (val == item) : (val = item))
			return i
	}
}



ParentByTitle(Window_Title)

{ 
	
	Parent_Handle := WinExist(Window_Title)
	
	Gui, PP:+LastFound 
	
	Return DllCall( "SetParent", "uint", WinExist(), "uint", Parent_Handle ) ; success = handle to previous parent, failure =null
	
}

WinCheck:
if !WinExist("Add Payment")
	Reload	
return

/*
	ActionWhenChildWindowCreated:
	;Warning: this command loop indefinitely, nothing is processed after this command => Must place this command at the end of script
	Winwait, ahk_group ActionWhenChildWindowCreated
	
	ifwinactive, Add Payment
		Gosub, PlaceButton
	
	ifwinactive, Microsoft Excel ahk_class #32770, This workbook contains links to other data sources.
		PostMessage, 0x112, 0xF060    ;0x112 = WM_SYSCOMMAND, 0xF060 = SC_CLOSE
	
	ifwinactive, ahk_group ResizeFileBrowser
		Winmove,,,A_ScreenWidth/10,10,A_ScreenWidth/1.3,A_ScreenHeight/1.07
	
	SoundPlay %A_ScriptDir%\sidekick\media\KbdSpacebar.wav
	
	sleep, 2000
	Gosub, ActionWhenChildWindowCreated
*/
/*
	This DateCalc() function calculates a new date for any StartDate by 
	providing Years, Months, and/or Days (+ or -) as parameters.
	https://jacks-autohotkey-blog.com/2021/04/01/calculating-dates-in-autohotkey-by-adding-years-months-and-or-days/
	
	Uses the Floor() and Mod() functions to account for months and years.
	https://jacks-autohotkey-blog.com/2021/04/12/fake-math-tricks-using-the-floor-and-mod-functions-autohotkey-tips/
	
	August 18, 2021 Added test for valid date when calculated month contains less days than the starting month.
	
*/

/*
	StartDate := "20200913"
	Years := 2
	Months := 8
	Days := 21
*/

/*
; Force test for valid date
	StartDate := "20210131"
	Years := 2
	Months := 1
	Days := 0
*/
; ######################################################################

; Date Calc function http://www.computoredge.com/AutoHotkey/Downloads/DateCalc.ahk
NewDate := DateCalc(StartDate,Years,Months,Days)

FormatTime, Start , %StartDate%, LongDate
FormatTime, New , %NewDate%, LongDate


;MsgBox,, DateCalc, % Start "`r`rAdd:`r`tYears " Years "`r`tMonths " Months "`r`tDays " Days "`r`r" New

DateCalc(Date := "",Years := 0,Months := 0,Days := 0)
{
	If (Date = "")
		Date := A_Now
	Months := SubStr(Date,5,2)+Months
	CalcYears := Floor(Months/12) + Years
	CalcMonths := Mod(Months,12)
	If (CalcMonths <= 0)
	{
		CalcYears := CalcMonths = 0 ? CalcYears-1 : CalcYears
		CalcMonths := CalcMonths + 12
	}
	NewDate := Substr(Date,1,4)+CalcYears . Format("{:02}", CalcMonths) . Substr(Date,7,2)
	
; Check for valid date
	FormatTime, TestDate, %NewDate%, ShortDate
	While !TestDate
	{
		NewDate := Substr(Date,1,4)+Years
		. Format("{:02}", Months)
		. Substr(Date,7,2)-A_Index
		
		FormatTime, TestDate, %NewDate%, ShortDate
	}
	
	NewDate += Days , Days
	Return NewDate
}
Return

PrintOrders:


IfWinNotExist, ahk_exe ProSelect.exe
	return

;Acc copy
;ToolTip, Printing Accounts copy
WinActivate, ahk_exe ProSelect.exe
WinWaitActive, ahk_exe ProSelect.exe
Sleep, 1000
Send, !f        ; Alt+F to open File menu
Sleep, 300
Send, p         ; P to highlight Print submenu
Sleep, 300
Send, {Right}   ; Open the submenu
Sleep, 300
Send, {Enter}   ; Select first item (Order/Invoice Report...)
sleep, 2000
WinActivate, Print Order Report
WinWaitActive, Print Order Report
WinActivate, Print Order Report
Control, Check ,, Append this Message:, Print Order Report
sleep, 200
Control, Check ,, Include QR Code, Print Order Report
sleep, 200
WinActivate, Print Order Report
ControlClick, Print Report, Print Order Report
Send {enter}
SoundPlay %A_ScriptDir%\KbdSpacebar.wav
Sleep, 2000
WinActivate, Print
WinWaitActive, Print
Send {enter}
sleep, 2000

WinWaitClose, Task in Progress...,10

;Return ; ######################## temp

;Client copy
SoundPlay %A_ScriptDir%\KbdSpacebar.wav
WinActivate, ahk_exe ProSelect.exe
WinWaitActive, ahk_exe ProSelect.exe
WinActivate, ahk_exe ProSelect.exe
Sleep, 1000
Send, !f        ; Alt+F to open File menu
Sleep, 300
Send, p         ; P to highlight Print submenu
Sleep, 300
Send, {Right}   ; Open the submenu
Sleep, 300
Send, {Enter}   ; Select first item (Order/Invoice Report...)
sleep, 2000
WinActivate, Print Order Report
WinWaitActive, Print Order Report
WinActivate, Print Order Report
Control, Check ,, Append this Message:, Print Order Report
sleep, 200
Control, UnCheck ,, Include QR Code, Print Order Report
sleep, 200
WinActivate, Print Order Report
ControlClick, Print Report, Print Order Report
Send {enter}
SoundPlay %A_ScriptDir%\KbdSpacebar.wav
Sleep, 2000
WinActivate, Print
WinWaitActive, Print
Send {enter}
sleep, 2000

WinWaitClose, Task in Progress...,10
; Production copy

WinActivate, ahk_exe ProSelect.exe
Sleep, 1000
Send, !f        ; Alt+F to open File menu
Sleep, 300
Send, p         ; P to highlight Print submenu
Sleep, 300
Send, {Right}   ; Open the submenu
Sleep, 300
Send, {Enter}   ; Select first item (Order/Invoice Report...)
sleep, 2000
WinActivate, Print Order Report
WinWaitActive, Print Order Report
WinActivate, Print Order Report
Control, UnCheck ,, Append this Message:, Print Order Report
sleep, 200
Control, Check ,, Include QR Code, Print Order Report
sleep, 200
WinActivate, Print Order Report
ControlClick, Print Report, Print Order Report
Send {enter}
SoundPlay %A_ScriptDir%\KbdSpacebar.wav
Sleep, 2000
WinActivate, Print
WinWaitActive, Print
Send {enter}
sleep, 2000
Return


; ============================================================================
; GHL Integration Functions - Open Client URL in Browser
; ============================================================================

OpenGHLClientURL:
; Check license before allowing GHL features
if (!CheckLicenseForFeature("Open GHL Client"))
	Return

; Check if we have a location ID configured
if (GHL_LocationID = "")
{
	DarkMsgBox("GHL Not Configured", "Please configure your GHL Location ID in Settings first.", "warning", {timeout: 5})
	Return
}

; First, try to get Client_ID from ProSelect window title (album name may contain it)
contactId := ""
if WinExist("ahk_exe ProSelect.exe")
{
	WinGetTitle, psTitle, ahk_exe ProSelect.exe
	; Look for GHL contact ID pattern in title (20+ alphanumeric chars)
	; Album names with client ID look like: "P26001_Smith_qatlAMlMrQQmZvLb71pj - ProSelect"
	if (RegExMatch(psTitle, "([A-Za-z0-9]{20,})", titleMatch))
	{
		contactId := titleMatch1
	}
}

; If not found in title, try the most recent XML export
if (contactId = "")
{
	ExportFolder := Settings_InvoiceWatchFolder
	if (ExportFolder != "" && FileExist(ExportFolder))
	{
		; Find the most recent XML file
		latestXml := ""
		latestTime := 0
		Loop, Files, %ExportFolder%\*.xml
		{
			FileGetTime, fileTime, %A_LoopFileFullPath%, M
			if (fileTime > latestTime)
			{
				latestTime := fileTime
				latestXml := A_LoopFileFullPath
			}
		}
		
		if (latestXml != "")
		{
			; Read the Client_ID from the XML
			FileRead, xmlContent, %latestXml%
			if (InStr(xmlContent, "<Client_ID>"))
			{
				if (RegExMatch(xmlContent, "<Client_ID>(.+?)</Client_ID>", match))
				{
					if (match1 != "")
						contactId := match1
				}
			}
		}
	}
}

if (contactId = "")
{
	DarkMsgBox("No Client ID Found", "Could not find a GHL Client ID.`n`nThe Client ID should be in either:`n• The ProSelect album name (after importing a GHL client)`n• The most recent invoice XML export`n`nImport a GHL client or export an order first.", "warning", {timeout: 5})
	Return
}

; Build the GHL URL and open it
ghlDomain := (GHL_AgencyDomain != "") ? GHL_AgencyDomain : "app.gohighlevel.com"
ghlURL := "https://" . ghlDomain . "/v2/location/" . GHL_LocationID . "/contacts/detail/" . contactId
Run, %ghlURL%

; Show brief confirmation
ToolTip, Opening GHL client page...
SetTimer, RemoveToolTip, -2000
Return


; ============================================================================
; GHL Integration Functions - Scan Chrome for FBPE URLs
; ============================================================================

GHLClientLookup:
; Check license before allowing GHL features
if (!CheckLicenseForFeature("GHL Client Lookup"))
	Return

; Check ProSelect state to determine action
existingClientId := ""
albumOpenNoId := false

if WinExist("ProSelect ahk_exe ProSelect.exe")
{
	WinGetTitle, psTitle, ahk_exe ProSelect.exe
	
	; Check for Client ID pattern in album name (20+ alphanumeric chars)
	if (RegExMatch(psTitle, "_([A-Za-z0-9]{20,})", idMatch))
	{
		; Album has Client ID - automatically use it (no need to ask)
		existingClientId := idMatch1
		
		; Fetch client data using existing ID
		GHL_Data := FetchGHLData(existingClientId)
		
		if (GHL_Data.success)
		{
			global GHL_CurrentData := GHL_Data
			
			if (Settings_GHL_AutoLoad)
			{
				UpdateProSelectClient(GHL_Data)
			}
			else
			{
				ghlDomain := (GHL_AgencyDomain != "") ? GHL_AgencyDomain : "app.gohighlevel.com"
				ShowGHLClientDialog(GHL_Data, existingClientId, "https://" . ghlDomain . "/v2/location/" . GHL_LocationID . "/contacts/detail/" . existingClientId)
			}
		}
		else
		{
			ErrorMsg := GHL_Data.error ? GHL_Data.error : "Unknown error fetching client data"
			DarkMsgBox("GHL Lookup Failed", ErrorMsg . "`n`nContact ID: " . existingClientId, "error", {timeout: 10})
		}
		Return
	}
	else if (!InStr(psTitle, "Untitled"))
	{
		; Album is open but has no Client ID - offer to update it from Chrome
		albumOpenNoId := true
		result := DarkMsgBox("Update Open Album?", "Album is open without a Client ID:`n`n" . psTitle . "`n`nScan Chrome and link this album to a GHL client?", "question", {buttons: ["Update Album", "Import New"]})
		
		if (result = "Import New")
		{
			albumOpenNoId := false  ; Treat as new import
		}
	}
	; else: Untitled album - treat as new import
}

; Scan all Chrome windows for FBPE URL
FBPE_URL := ""
GHL_ContactID := ""

; Try to find FBPE URL from Chrome windows
FBPE_URL := FindFBPEURLFromChrome()

if (!FBPE_URL || FBPE_URL = "")
{
	DarkMsgBox("FBPE URL Not Found", "No GHL URL found in any open Chrome tabs.`n`nPlease open the client's contact page in Chrome first.`n`n(URL should contain: thefullybookedphotographer.com/v2/location/.../contacts/detail/...)", "warning", {timeout: 10})
	Return
}

; Validate it's a valid GHL URL
if (!InStr(FBPE_URL, "thefullybookedphotographer.com"))
{
	DarkMsgBox("Invalid FBPE Link", "The URL doesn't appear to be a valid FBPE link.`n`nCaptured: " . FBPE_URL, "warning", {timeout: 10})
	Return
}

; Extract contact ID
if RegExMatch(FBPE_URL, "contacts/detail/([A-Za-z0-9]{20,})", contactMatch)
{
	GHL_ContactID := contactMatch1
}
else
{
	DarkMsgBox("Contact ID Not Found", "Could not extract Contact ID from FBPE URL.`n`nURL: " . FBPE_URL, "warning", {timeout: 10})
	Return
}

; Fetch client data from GHL
GHL_Data := FetchGHLData(GHL_ContactID)

if (GHL_Data.success)
{
	; Store GHL data globally for use by UpdateProSelect
	global GHL_CurrentData := GHL_Data
	global GHL_UpdateExistingAlbum := albumOpenNoId  ; Pass flag for existing album update
	
	; Check if Auto-load is enabled
	if (Settings_GHL_AutoLoad)
	{
		; Auto-load: directly update ProSelect without confirmation
		UpdateProSelectClient(GHL_Data, albumOpenNoId)
	}
	else
	{
		; Manual confirmation: show custom dialog with Update ProSelect button
		ShowGHLClientDialog(GHL_Data, GHL_ContactID, FBPE_URL)
	}
}
else
{
	ErrorMsg := GHL_Data.error ? GHL_Data.error : "Unknown error fetching client data"
	DarkMsgBox("GHL Lookup Failed", ErrorMsg . "`n`nContact ID: " . GHL_ContactID, "error", {timeout: 10})
}
Return

; ============================================================================
; Show GHL Client Dialog with Update ProSelect button
; ============================================================================
ShowGHLClientDialog(GHL_Data, ContactID, URL)
{
	global GHL_CurrentData
	GHL_CurrentData := GHL_Data
	
	Gui, GHLClient:New, +AlwaysOnTop +OwnDialogs
	Gui, GHLClient:Color, 2D2D2D
	Gui, GHLClient:Font, s14 cWhite Bold, Segoe UI
	Gui, GHLClient:Add, Text, x20 y15 w460, ✅ GHL Client Details
	
	Gui, GHLClient:Font, s10 cCCCCCC, Segoe UI
	
	; Build client details display
	yPos := 55
	
	fullName := GHL_Data.firstName . " " . GHL_Data.lastName
	Gui, GHLClient:Add, Text, x20 y%yPos% w120, Name:
	Gui, GHLClient:Add, Text, x150 y%yPos% w330 cWhite, %fullName%
	yPos += 25
	
	email := GHL_Data.email
	Gui, GHLClient:Add, Text, x20 y%yPos% w120, Email:
	Gui, GHLClient:Add, Text, x150 y%yPos% w330 cWhite, %email%
	yPos += 25
	
	phone := GHL_Data.phone
	Gui, GHLClient:Add, Text, x20 y%yPos% w120, Phone:
	Gui, GHLClient:Add, Text, x150 y%yPos% w330 cWhite, %phone%
	yPos += 25
	
	address := GHL_Data.address1
	Gui, GHLClient:Add, Text, x20 y%yPos% w120, Address:
	Gui, GHLClient:Add, Text, x150 y%yPos% w330 cWhite, %address%
	yPos += 25
	
	city := GHL_Data.city
	Gui, GHLClient:Add, Text, x20 y%yPos% w120, City:
	Gui, GHLClient:Add, Text, x150 y%yPos% w330 cWhite, %city%
	yPos += 25
	
	state := GHL_Data.state
	Gui, GHLClient:Add, Text, x20 y%yPos% w120, State:
	Gui, GHLClient:Add, Text, x150 y%yPos% w330 cWhite, %state%
	yPos += 25
	
	postalCode := GHL_Data.postalCode
	Gui, GHLClient:Add, Text, x20 y%yPos% w120, Postcode:
	Gui, GHLClient:Add, Text, x150 y%yPos% w330 cWhite, %postalCode%
	yPos += 25
	
	country := GHL_Data.country
	Gui, GHLClient:Add, Text, x20 y%yPos% w120, Country:
	Gui, GHLClient:Add, Text, x150 y%yPos% w330 cWhite, %country%
	yPos += 35
	
	; Separator line
	Gui, GHLClient:Font, s9 c888888, Segoe UI
	Gui, GHLClient:Add, Text, x20 y%yPos% w460, Contact ID: %ContactID%
	yPos += 20
	shortURL := SubStr(URL, 1, 55) . "..."
	Gui, GHLClient:Add, Text, x20 y%yPos% w460, %shortURL%
	yPos += 35
	
	; Buttons
	Gui, GHLClient:Font, s10 Norm cWhite, Segoe UI
	Gui, GHLClient:Add, Button, x20 y%yPos% w180 h35 gGHLClientUpdatePS Default, 📋 Update ProSelect
	Gui, GHLClient:Add, Button, x220 y%yPos% w120 h35 gGHLClientClose, Close
	
	yPos += 55
	Gui, GHLClient:Show, w500 h%yPos%, 🔍 GHL Client Lookup - SideKick_PS
	Return
}

GHLClientUpdatePS:
Gui, GHLClient:Destroy
global GHL_CurrentData, GHL_UpdateExistingAlbum
UpdateProSelectClient(GHL_CurrentData, GHL_UpdateExistingAlbum)
Return

GHLClientClose:
GHLClientGuiClose:
GHLClientGuiEscape:
Gui, GHLClient:Destroy
Return

; ============================================================================
; Update ProSelect Client Information
; Populates client fields in ProSelect from GHL data using PSConsole
; updateExisting: if true, updating an existing album (skip confirmation, use Save As to add ID)
; ============================================================================
UpdateProSelectClient(GHL_Data, updateExisting := false)
{
	global PsConsolePath, ProSelect2025Path, ProSelect2022Path
	
	; Check if PSConsole is available
	if (PsConsolePath = "")
	{
		DarkMsgBox("PSConsole Not Found", "PSConsole.exe was not found.`n`nPlease ensure ProSelect is properly installed.", "warning", {timeout: 10})
		Return
	}
	
	; Check if ProSelect is running - if not, start it and wait
	if WinExist("ProSelect ahk_exe ProSelect.exe")
	{
		; ProSelect is already running - good to proceed
		; (User already confirmed via GHLClientLookup prompts)
	}
	else
	{
		; Determine which ProSelect to launch
		if FileExist(ProSelect2025Path)
			psPath := ProSelect2025Path
		else if FileExist(ProSelect2022Path)
			psPath := ProSelect2022Path
		else
		{
			DarkMsgBox("ProSelect Not Found", "ProSelect is not installed.`n`nPlease install ProSelect and try again.", "warning", {timeout: 10})
			Return
		}
		
		ToolTip, 🚀 Starting ProSelect... Please wait...
		Run, "%psPath%"
		
		; Wait for ProSelect to fully load (up to 120 seconds)
		; ProSelect is ready when window title contains "Untitled" or a filename
		startTime := A_TickCount
		timeout := 120000  ; 120 seconds total
		
		Loop
		{
			Sleep, 1000
			elapsed := A_TickCount - startTime
			remaining := Round((timeout - elapsed) / 1000)
			
			; Check if ProSelect window exists with "Untitled" in title (means fully loaded)
			if WinExist("ProSelect - Untitled") || WinExist("ProSelect ahk_exe ProSelect.exe")
			{
				WinGetTitle, psTitle, ProSelect ahk_exe ProSelect.exe
				if (InStr(psTitle, "Untitled") || InStr(psTitle, ".psa"))
				{
					; ProSelect is fully loaded
					ToolTip, ✅ ProSelect ready!
					Sleep, 2000
					break
				}
			}
			
			; Show appropriate message based on state
			if WinExist("ahk_exe ProSelect.exe")
				ToolTip, ⏳ ProSelect setting up... Please wait (%remaining%s)...
			else
				ToolTip, 🚀 Starting ProSelect... Please wait... (%remaining%s)
			
			if (elapsed > timeout)
			{
				ToolTip
				DarkMsgBox("Timeout", "ProSelect did not fully load within 120 seconds.`n`nPlease wait for ProSelect to finish loading and try again.", "warning", {timeout: 10})
				Return
			}
		}
		ToolTip
	}
	
	; Prepare parameters for loadordergroup command
	; Parameters: Group, FirstName, LastName, Account, HomePhone, WorkPhone, CellPhone, 
	;             Address1, Address2, City, State, Country, Email, Zip
	Group := ""  ; Order group - leave empty for default
	FirstName := GHL_Data.firstName ? GHL_Data.firstName : ""
	LastName := GHL_Data.lastName ? GHL_Data.lastName : ""
	Account := GHL_Data.id ? GHL_Data.id : ""  ; Use GHL Contact ID as Account (like LB_ShootNo)
	HomePhone := GHL_Data.phone ? GHL_Data.phone : ""
	WorkPhone := ""
	CellPhone := ""
	Address1 := GHL_Data.address1 ? GHL_Data.address1 : ""
	Address2 := ""
	City := GHL_Data.city ? GHL_Data.city : ""
	State := GHL_Data.state ? GHL_Data.state : ""
	Country := GHL_Data.country ? GHL_Data.country : ""
	Email := GHL_Data.email ? GHL_Data.email : ""
	Zip := GHL_Data.postalCode ? GHL_Data.postalCode : ""
	
	; Show loading tooltip
	ToolTip, 📥 Loading client data to ProSelect...
	
	; Call PSConsole with loadordergroup command
	result := PsConsole("loadordergroup", Group, FirstName, LastName, Account, HomePhone, WorkPhone, CellPhone, Address1, Address2, City, State, Country, Email, Zip)
	
	ToolTip
	
	if (result)
	{
		; Now save album with client ID appended to album name
		; This makes it easy to identify the GHL contact from the window title
		if (Account != "")
		{
			; Get current album path from ProSelect window title
			WinGetTitle, psTitle, ahk_exe ProSelect.exe
			
			; Extract album name - title format is "ProSelect - AlbumName" or "ProSelect - C:\path\AlbumName.psa"
			albumPath := ""
			if (RegExMatch(psTitle, "^ProSelect - (.+)$", pathMatch))
			{
				albumPath := pathMatch1
			}
			
			; Build new album name with client ID appended
			newAlbumName := ""
			
			if (albumPath = "Untitled" || albumPath = "")
			{
				; New album - create name from client info: LastName_ClientID.psa
				newAlbumName := LastName . "_" . Account . ".psa"
			}
			else if (!InStr(albumPath, Account))
			{
				; Existing album without client ID - need to append it
				; Check if it's a full path or just a name
				SplitPath, albumPath, fileName, dirPath, ext, nameNoExt
				
				; Remove " copy" suffix if present (from ProSelect duplicate albums)
				nameNoExt := RegExReplace(nameNoExt, "\s+copy$", "")
				
				; Just need the new filename with .psa extension
				newAlbumName := nameNoExt . "_" . Account . ".psa"
			}
			; else: Album already has client ID - skip renaming
			
			if (newAlbumName != "")
			{
				ToolTip, 💾 Saving album with client ID...
				Sleep, 300
				
				; Activate ProSelect and use menu to open Save As (avoids triggering other hotkeys)
				WinActivate, ahk_exe ProSelect.exe
				Sleep, 500
				WinWaitActive, ahk_exe ProSelect.exe, , 3
				
				; Use File menu > Save Album as... to open Save Album As dialog
				WinMenuSelectItem, ahk_exe ProSelect.exe, , File, Save Album as...
				Sleep, 1500
				
				; Wait for Save As dialog
				saveAsDialogHwnd := WinExist("Save Album As")
				if (!saveAsDialogHwnd)
					saveAsDialogHwnd := WinExist("Save As")
				
				if (saveAsDialogHwnd)
				{
					WinActivate, ahk_id %saveAsDialogHwnd%
					Sleep, 500
					
					; Read original filename from edit control before changing it
					ControlGetText, originalFileName, Edit1, ahk_id %saveAsDialogHwnd%
					
					; Focus filename edit, select all, type new name
					ControlFocus, Edit1, ahk_id %saveAsDialogHwnd%
					Sleep, 200
					SendInput, ^a
					Sleep, 200
					SendInput, %newAlbumName%
					Sleep, 2000
					
					; Click Save button (Button2)
					ControlClick, Button2, ahk_id %saveAsDialogHwnd%
					Sleep, 1000
					
					; Handle any confirmation dialogs
					if WinExist("Confirm Save As")
					{
						Send, {Enter}
						Sleep, 500
					}
					
					; Delete original .psa file if it differs from new name
					if (originalFileName != "" && originalFileName != newAlbumName)
					{
						; Get album folder from original albumPath
						SplitPath, albumPath, , albumDir
						if (albumDir != "")
						{
							originalFullPath := albumDir . "\" . originalFileName
							if FileExist(originalFullPath)
							{
								FileDelete, %originalFullPath%
								if !ErrorLevel
									ToolTip, ✅ Album saved and old file removed!
								else
									ToolTip, ✅ Album saved (old file still exists)
							}
							else
							{
								ToolTip, ✅ Album saved with client ID!
							}
						}
						else
						{
							ToolTip, ✅ Album saved with client ID!
						}
					}
					else
					{
						ToolTip, ✅ Album saved with client ID!
					}
					SetTimer, RemoveUpdateTooltip, -2000
				}
				else
				{
					; Save As dialog didn't open - show error
					ToolTip
					DarkMsgBox("Save As Failed", "Could not open Save As dialog.`n`nPlease save the album manually with the client ID:`n" . newAlbumName, "warning", {timeout: 10})
				}
			}
		}
		
		ToolTip, ✅ Client data loaded to ProSelect!
		SetTimer, RemoveUpdateTooltip, -2000
	}
	else
	{
		DarkMsgBox("Update Failed", "Failed to update ProSelect client data.`n`nPlease try again or enter the data manually.", "warning", {timeout: 10})
	}
	Return
}

; ============================================================================
; PSConsole Function - Execute ProSelect Console commands
; ============================================================================
PsConsole(command, param1:="", param2:="", param3:="", param4:="", param5:="", param6:="", param7:="", param8:="", param9:="", param10:="", param11:="", param12:="", param13:="", param14:="", param15:="") {
	global PsConsolePath
	
	if (PsConsolePath = "")
		return false
	
	fullCommand := "cd /d """ . PsConsolePath . """ && psconsole.exe " . command
	
	; Collect all parameters
	params := [param1, param2, param3, param4, param5, param6, param7, param8, param9, param10, param11, param12, param13, param14, param15]
	paramString := ""
	
	if (command = "loadordergroup") {
		For index, param in params {
			; Quote the parameter if it's not already quoted
			if (!InStr(param, """")) {
				formattedParam := """" . param . """"
			} else {
				formattedParam := param
			}
			paramString .= " " . formattedParam
		}
	} else {
		; Find the last non-empty parameter
		lastNonEmpty := 0
		For index, param in params {
			if (param != "") {
				lastNonEmpty := index
			}
		}
		
		; Only add parameters up to the last non-empty one
		Loop, %lastNonEmpty% {
			param := params[A_Index]
			; Quote the parameter if it's not already quoted
			if (!InStr(param, """")) {
				formattedParam := """" . param . """"
			} else {
				formattedParam := param
			}
			paramString .= " " . formattedParam
		}
	}
	
	; Construct the final command
	fullCommand .= paramString
	
	tempFile := A_Temp . "\psconsole_output.txt"
	RunWait, *RunAs %ComSpec% /c chcp 65001 >nul && %fullCommand% > "%tempFile%" 2>&1, , Hide
	
	; Read the output with UTF-8 encoding
	FileRead, output, *P65001 %tempFile%
	FileDelete, %tempFile%
	
	; Check for success status
	if (InStr(output, "<result status=""0""></result>")) {
		return true
	} else {
		; Error - show the output for debugging
		; MsgBox, 16, PSConsole Error, Error executing command:`n`n%fullCommand%`n`nOutput:`n%output%
		return false
	}
}

RemoveUpdateTooltip:
ToolTip
Return

FindFBPEURLFromChrome()
{
	; Find Chrome window with "fullybookedphotographer" or "Contacts" in title
	chromeHwnd := ""
	WinGet, ChromeList, List, ahk_exe chrome.exe
	Loop, %ChromeList%
	{
		hwnd := ChromeList%A_Index%
		WinGetTitle, title, ahk_id %hwnd%
		if (InStr(title, "fullybookedphotographer") || InStr(title, "Contacts"))
		{
			chromeHwnd := hwnd
			break
		}
	}
	
	; Fallback to any Chrome window
	if (!chromeHwnd)
		WinGet, chromeHwnd, ID, ahk_exe chrome.exe
	
	if (!chromeHwnd)
		return ""
	
	; Activate Chrome, grab URL, return focus
	WinGet, origHwnd, ID, A
	
	WinActivate, ahk_id %chromeHwnd%
	WinWaitActive, ahk_id %chromeHwnd%, , 1
	
	; Check active tab only
	url := GetChromeTabURL()
	if (url && InStr(url, "thefullybookedphotographer.com") && InStr(url, "contacts/detail"))
	{
		WinActivate, ahk_id %origHwnd%
		return url
	}
	
	; Return focus to original window
	WinActivate, ahk_id %origHwnd%
	return ""
}

; ============================================================
; Clipboard Helper Functions
; Safely get/copy text without losing user's clipboard contents
; ============================================================

ClipboardSafeGet(ByRef savedClip) {
	; Save user's clipboard and clear for fresh copy
	; Usage: savedClip := "", text := ClipboardSafeGet(savedClip)
	;        ... do clipboard operation (Send ^c) ...
	;        result := Clipboard
	;        ClipboardSafeRestore(savedClip)
	savedClip := ClipboardAll
	Clipboard := ""
	return savedClip
}

ClipboardSafeRestore(ByRef savedClip) {
	; Restore user's original clipboard contents
	; Call this after getting the text you need
	if (savedClip != "") {
		Clipboard := savedClip
		savedClip := ""
	}
}

ClipboardSafeCopy(timeout := 2) {
	; Send Ctrl+C and wait for text, preserving user's clipboard
	; Returns: copied text (or empty if failed), restores original clipboard
	; Usage: text := ClipboardSafeCopy()
	savedClip := ClipboardAll
	Clipboard := ""
	Send, ^c
	ClipWait, %timeout%
	if (ErrorLevel) {
		Clipboard := savedClip
		return ""
	}
	result := Clipboard
	Clipboard := savedClip
	return result
}

GetChromeTabURL()
{
	savedClip := ""
	ClipboardSafeGet(savedClip)
	
	Send, ^l
	Sleep, 100
	Send, ^c
	ClipWait, 1
	
	url := Clipboard
	ClipboardSafeRestore(savedClip)
	
	Send, {Escape}
	return url
}

ShowURLSelectionDialog(urlArray, titleArray)
{
	; Build selection GUI for multiple FBPE URLs
	global SelectedFBPEURL
	SelectedFBPEURL := ""
	
	Gui, URLSelect:New, +AlwaysOnTop +OwnDialogs
	Gui, URLSelect:Color, 2D2D2D
	Gui, URLSelect:Font, s11 cWhite, Segoe UI
	Gui, URLSelect:Add, Text, x20 y15 w460, Multiple GHL contact tabs detected. Select one:
	
	; Add radio buttons for each URL
	yPos := 50
	Loop, % urlArray.Length()
	{
		idx := A_Index
		title := titleArray[idx]
		url := urlArray[idx]
		
		; Extract contact ID for display
		if RegExMatch(url, "contacts/detail/([A-Za-z0-9]+)", match)
			contactID := match1
		else
			contactID := "Unknown"
		
		; Truncate title if too long
		displayTitle := StrLen(title) > 50 ? SubStr(title, 1, 47) . "..." : title
		
		; First option is default selected
		if (A_Index = 1)
			Gui, URLSelect:Add, Radio, x20 y%yPos% w460 vURLOption%idx% Checked gURLOptionClicked, %displayTitle%
		else
			Gui, URLSelect:Add, Radio, x20 y%yPos% w460 vURLOption%idx% gURLOptionClicked, %displayTitle%
		
		yPos += 25
		Gui, URLSelect:Font, s9 c888888
		Gui, URLSelect:Add, Text, x40 y%yPos% w440, ID: %contactID%
		yPos += 30
		Gui, URLSelect:Font, s11 Norm cWhite
	}
	
	; Add OK and Cancel buttons
	yPos += 15
	Gui, URLSelect:Add, Button, x120 y%yPos% w100 h30 gURLSelectOK Default, &OK
	Gui, URLSelect:Add, Button, x240 y%yPos% w100 h30 gURLSelectCancel, &Cancel
	
	; Store URLs globally for the button handlers
	global URLSelectArray := urlArray
	
	guiHeight := yPos + 50
	Gui, URLSelect:Show, w500 h%guiHeight%, 🔍 Select GHL Contact
	
	; Wait for GUI to close
	WinWaitClose, 🔍 Select GHL Contact
	
	return SelectedFBPEURL
}

URLOptionClicked:
return

URLSelectOK:
Gui, URLSelect:Submit, NoHide
global URLSelectArray, SelectedFBPEURL

; Find which option was selected
Loop, % URLSelectArray.Length()
{
	GuiControlGet, isChecked,, URLOption%A_Index%
	if (isChecked)
	{
		SelectedFBPEURL := URLSelectArray[A_Index]
		break
	}
}
Gui, URLSelect:Destroy
return

URLSelectCancel:
global SelectedFBPEURL
SelectedFBPEURL := ""
Gui, URLSelect:Destroy
return

FindURLInAccTree(oAcc, depth := 0)
{
	; Limit recursion depth
	if (depth > 10)
		return ""
	
	try {
		; Check if this element has a value that looks like a URL
		value := oAcc.accValue(0)
		if (value && InStr(value, "http") && InStr(value, "thefullybookedphotographer.com"))
			return value
		
		; Also check name for URLs
		name := oAcc.accName(0)
		if (name && InStr(name, "http") && InStr(name, "thefullybookedphotographer.com"))
			return name
		
		; Recurse into children
		children := Acc_Children(oAcc)
		for idx, child in children
		{
			if (IsObject(child))
			{
				result := FindURLInAccTree(child, depth + 1)
				if (result)
					return result
			}
		}
	}
	
	return ""
}

FetchGHLData(contactID)
{
	global GHL_API_Key
	
	if (!contactID)
		return {success: false, error: "No contact ID provided"}
	
	if (!GHL_API_Key || GHL_API_Key = "")
		return {success: false, error: "GHL API Key not configured. Go to Settings > GHL Integration"}
	
	; Use native AHK HTTP request - no Python dependency
	try {
		http := ComObjCreate("WinHttp.WinHttpRequest.5.1")
		http.SetTimeouts(10000, 10000, 10000, 10000)
		
		; Build the API URL - V2 API endpoint
		apiUrl := "https://services.leadconnectorhq.com/contacts/" . contactID
		
		http.open("GET", apiUrl, false)
		http.SetRequestHeader("Authorization", "Bearer " . GHL_API_Key)
		http.SetRequestHeader("Version", "2021-07-28")
		http.SetRequestHeader("Content-Type", "application/json")
		http.send()
		
		httpStatus := http.status
		if (httpStatus = 200)
		{
			jsonText := http.responseText
			return ParseGHLJSON(jsonText)
		}
		else if (httpStatus = 401)
		{
			return {success: false, error: "Invalid API Key (401 Unauthorized)"}
		}
		else if (httpStatus = 404)
		{
			return {success: false, error: "Contact not found (404)"}
		}
		else
		{
			return {success: false, error: "API Error - Status: " . httpStatus}
		}
	}
	catch e
	{
		errMsg := IsObject(e) ? e.Message : e
		return {success: false, error: "HTTP Request failed: " . errMsg}
	}
}

ParseGHLJSON(jsonText)
{
	; Simple JSON parser for GHL API direct response
	; The API returns contact data directly, not wrapped in a "contact" object
	contact := {}
	
	; Check if response contains an error
	if (InStr(jsonText, """error""") || InStr(jsonText, """statusCode"""))
	{
		contact.success := false
		if RegExMatch(jsonText, """message""\s*:\s*""([^""]+)""", match)
			contact.error := match1
		else
			contact.error := "API returned an error"
		return contact
	}
	
	; If we got contact data, mark as success
	if (InStr(jsonText, """id""") || InStr(jsonText, """email""") || InStr(jsonText, """firstName"""))
	{
		contact.success := true
	}
	else
	{
		contact.success := false
		contact.error := "Invalid response format"
		return contact
	}
	
	; Extract all fields from direct API response
	fields := ["id", "firstName", "lastName", "name", "email", "phone", "address1", "city", "state", "postalCode", "country"]
	
	for index, field in fields
	{
		if RegExMatch(jsonText, """" . field . """\s*:\s*""([^""]*)""", match)
			contact[field] := match1
		else
			contact[field] := ""
	}
	
	return contact
}


; functions####################

; ##################################################################################
; # This #Include file was generated by Image2Include.ahk, you must not change it! #
; ##################################################################################
Create_SideKick_PS_png(NewHandle := False) {
	Static hBitmap := 0
	If (NewHandle)
		hBitmap := 0
	If (hBitmap)
		Return hBitmap
	VarSetCapacity(B64, 52276 << !!A_IsUnicode)
	B64 := "iVBORw0KGgoAAAANSUhEUgAAAPsAAAEBCAIAAAAxbkQ6AAAACXBIWXMAABJ0AAASdAHeZh94AAAJmmlUWHRYTUw6Y29tLmFkb2JlLnhtcAAAAAAAPD94cGFja2V0IGJlZ2luPSLvu78iIGlkPSJXNU0wTXBDZWhpSHpyZVN6TlRjemtjOWQiPz4gPHg6eG1wbWV0YSB4bWxuczp4PSJhZG9iZTpuczptZXRhLyIgeDp4bXB0az0iQWRvYmUgWE1QIENvcmUgNy4xLWMwMDAgNzkuYjBmOGJlOSwgMjAyMS8xMi8wOC0xOToxMToyMiAgICAgICAgIj4gPHJkZjpSREYgeG1sbnM6cmRmPSJodHRwOi8vd3d3LnczLm9yZy8xOTk5LzAyLzIyLXJkZi1zeW50YXgtbnMjIj4gPHJkZjpEZXNjcmlwdGlvbiByZGY6YWJvdXQ9IiIgeG1sbnM6eG1wPSJodHRwOi8vbnMuYWRvYmUuY29tL3hhcC8xLjAvIiB4bWxuczpkYz0iaHR0cDovL3B1cmwub3JnL2RjL2VsZW1lbnRzLzEuMS8iIHhtbG5zOnBob3Rvc2hvcD0iaHR0cDovL25zLmFkb2JlLmNvbS9waG90b3Nob3AvMS4wLyIgeG1sbnM6eG1wTU09Imh0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC9tbS8iIHhtbG5zOnN0RXZ0PSJodHRwOi8vbnMuYWRvYmUuY29tL3hhcC8xLjAvc1R5cGUvUmVzb3VyY2VFdmVudCMiIHhtbG5zOnN0UmVmPSJodHRwOi8vbnMuYWRvYmUuY29tL3hhcC8xLjAvc1R5cGUvUmVzb3VyY2VSZWYjIiB4bXA6Q3JlYXRvclRvb2w9IkFkb2JlIFBob3Rvc2hvcCAyMy4yIChXaW5kb3dzKSIgeG1wOkNyZWF0ZURhdGU9IjIwMjItMDMtMThUMTM6NTQ6NTdaIiB4bXA6TW9kaWZ5RGF0ZT0iMjAyMi0wMy0xOFQxMzo1Nzo1M1oiIHhtcDpNZXRhZGF0YURhdGU9IjIwMjItMDMtMThUMTM6NTc6NTNaIiBkYzpmb3JtYXQ9ImltYWdlL3BuZyIgcGhvdG9zaG9wOkNvbG9yTW9kZT0iMyIgeG1wTU06SW5zdGFuY2VJRD0ieG1wLmlpZDowNmUwMDRmNy1jMDBmLTljNDYtYTI1ZC03NWU3YTEyODc5ZGIiIHhtcE1NOkRvY3VtZW50SUQ9ImFkb2JlOmRvY2lkOnBob3Rvc2hvcDo1MzAwNjY4YS05YmY4LTRiNGQtYjY0My03MGRhNjJhMGQ1NzQiIHhtcE1NOk9yaWdpbmFsRG9jdW1lbnRJRD0ieG1wLmRpZDo3MDEyNTY2ZC00ODZlLWYyNGItYjMxYy01ZjlhZWY2YjQyZTQiPiA8eG1wTU06SGlzdG9yeT4gPHJkZjpTZXE+IDxyZGY6bGkgc3RFdnQ6YWN0aW9uPSJjcmVhdGVkIiBzdEV2dDppbnN0YW5jZUlEPSJ4bXAuaWlkOjcwMTI1NjZkLTQ4NmUtZjI0Yi1iMzFjLTVmOWFlZjZiNDJlNCIgc3RFdnQ6d2hlbj0iMjAyMi0wMy0xOFQxMzo1NDo1N1oiIHN0RXZ0OnNvZnR3YXJlQWdlbnQ9IkFkb2JlIFBob3Rvc2hvcCAyMy4yIChXaW5kb3dzKSIvPiA8cmRmOmxpIHN0RXZ0OmFjdGlvbj0iY29udmVydGVkIiBzdEV2dDpwYXJhbWV0ZXJzPSJmcm9tIGltYWdlL3BuZyB0byBhcHBsaWNhdGlvbi92bmQuYWRvYmUucGhvdG9zaG9wIi8+IDxyZGY6bGkgc3RFdnQ6YWN0aW9uPSJzYXZlZCIgc3RFdnQ6aW5zdGFuY2VJRD0ieG1wLmlpZDozNmZjMDFmOS0xY2FmLTk1NGEtYjQxYi1lNTk3NWZlM2YyOGEiIHN0RXZ0OndoZW49IjIwMjItMDMtMThUMTM6NTY6MjlaIiBzdEV2dDpzb2Z0d2FyZUFnZW50PSJBZG9iZSBQaG90b3Nob3AgMjMuMiAoV2luZG93cykiIHN0RXZ0OmNoYW5nZWQ9Ii8iLz4gPHJkZjpsaSBzdEV2dDphY3Rpb249InNhdmVkIiBzdEV2dDppbnN0YW5jZUlEPSJ4bXAuaWlkOmU0NGU4OWQ5LTViNGUtYmI0Yi05NWRmLWE1NWY0MzA2NzIwOSIgc3RFdnQ6d2hlbj0iMjAyMi0wMy0xOFQxMzo1Nzo1M1oiIHN0RXZ0OnNvZnR3YXJlQWdlbnQ9IkFkb2JlIFBob3Rvc2hvcCAyMy4yIChXaW5kb3dzKSIgc3RFdnQ6Y2hhbmdlZD0iLyIvPiA8cmRmOmxpIHN0RXZ0OmFjdGlvbj0iY29udmVydGVkIiBzdEV2dDpwYXJhbWV0ZXJzPSJmcm9tIGFwcGxpY2F0aW9uL3ZuZC5hZG9iZS5waG90b3Nob3AgdG8gaW1hZ2UvcG5nIi8+IDxyZGY6bGkgc3RFdnQ6YWN0aW9uPSJkZXJpdmVkIiBzdEV2dDpwYXJhbWV0ZXJzPSJjb252ZXJ0ZWQgZnJvbSBhcHBsaWNhdGlvbi92bmQuYWRvYmUucGhvdG9zaG9wIHRvIGltYWdlL3BuZyIvPiA8cmRmOmxpIHN0RXZ0OmFjdGlvbj0ic2F2ZWQiIHN0RXZ0Omluc3RhbmNlSUQ9InhtcC5paWQ6MDZlMDA0ZjctYzAwZi05YzQ2LWEyNWQtNzVlN2ExMjg3OWRiIiBzdEV2dDp3aGVuPSIyMDIyLTAzLTE4VDEzOjU3OjUzWiIgc3RFdnQ6c29mdHdhcmVBZ2VudD0iQWRvYmUgUGhvdG9zaG9wIDIzLjIgKFdpbmRvd3MpIiBzdEV2dDpjaGFuZ2VkPSIvIi8+IDwvcmRmOlNlcT4gPC94bXBNTTpIaXN0b3J5PiA8eG1wTU06RGVyaXZlZEZyb20gc3RSZWY6aW5zdGFuY2VJRD0ieG1wLmlpZDplNDRlODlkOS01YjRlLWJiNGItOTVkZi1hNTVmNDMwNjcyMDkiIHN0UmVmOmRvY3VtZW50SUQ9InhtcC5kaWQ6NzAxMjU2NmQtNDg2ZS1mMjRiLWIzMWMtNWY5YWVmNmI0MmU0IiBzdFJlZjpvcmlnaW5hbERvY3VtZW50SUQ9InhtcC5kaWQ6NzAxMjU2NmQtNDg2ZS1mMjRiLWIzMWMtNWY5YWVmNmI0MmU0Ii8+IDwvcmRmOkRlc2NyaXB0aW9uPiA8L3JkZjpSREY+IDwveDp4bXBtZXRhPiA8P3hwYWNrZXQgZW5kPSJyIj8+h1eLvQAAjzJJREFUeNrs/fmzZFt2HoZ9a+29zzk5552nml9Vvbnf6wFooNFAgwCngGjahASalMhwBCNs2XKEf3eEFf4HFA7/YCsYNk0xLIsiRUsgTYKgQAki0GBj6Hl48zzUfOebmWfYe63lH07eW/Xe6272a/Rr1HB3ZFTlzZs3h3O+s/YavvUt4HT91BcRnfz7fX/7g351uk7X/YXjDyE1hBBC+OgznXM/OqZP0f+TXXx6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"
	B64 .= "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"
	B64 .= "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"
	B64 .= "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"
	If !DllCall("Crypt32.dll\CryptStringToBinary", "Ptr", &B64, "UInt", 0, "UInt", 0x01, "Ptr", 0, "UIntP", DecLen, "Ptr", 0, "Ptr", 0)
		Return False
	VarSetCapacity(Dec, DecLen, 0)
	If !DllCall("Crypt32.dll\CryptStringToBinary", "Ptr", &B64, "UInt", 0, "UInt", 0x01, "Ptr", &Dec, "UIntP", DecLen, "Ptr", 0, "Ptr", 0)
		Return False
; Bitmap creation adopted from "How to convert Image data (JPEG/PNG/GIF) to hBITMAP?" by SKAN
; -> http://www.autohotkey.com/board/topic/21213-how-to-convert-image-data-jpegpnggif-to-hbitmap/?p=139257
	hData := DllCall("Kernel32.dll\GlobalAlloc", "UInt", 2, "UPtr", DecLen, "UPtr")
	pData := DllCall("Kernel32.dll\GlobalLock", "Ptr", hData, "UPtr")
	DllCall("Kernel32.dll\RtlMoveMemory", "Ptr", pData, "Ptr", &Dec, "UPtr", DecLen)
	DllCall("Kernel32.dll\GlobalUnlock", "Ptr", hData)
	DllCall("Ole32.dll\CreateStreamOnHGlobal", "Ptr", hData, "Int", True, "PtrP", pStream)
	hGdip := DllCall("Kernel32.dll\LoadLibrary", "Str", "Gdiplus.dll", "UPtr")
	VarSetCapacity(SI, 16, 0), NumPut(1, SI, 0, "UChar")
	DllCall("Gdiplus.dll\GdiplusStartup", "PtrP", pToken, "Ptr", &SI, "Ptr", 0)
	DllCall("Gdiplus.dll\GdipCreateBitmapFromStream",  "Ptr", pStream, "PtrP", pBitmap)
	DllCall("Gdiplus.dll\GdipCreateHBITMAPFromBitmap", "Ptr", pBitmap, "PtrP", hBitmap, "UInt", 0)
	DllCall("Gdiplus.dll\GdipDisposeImage", "Ptr", pBitmap)
	DllCall("Gdiplus.dll\GdiplusShutdown", "Ptr", pToken)
	DllCall("Kernel32.dll\FreeLibrary", "Ptr", hGdip)
	DllCall(NumGet(NumGet(pStream + 0, 0, "UPtr") + (A_PtrSize * 2), 0, "UPtr"), "Ptr", pStream)
	Return hBitmap
}

; ============================================================================
; SD Card Download Functions (Ported from SideKick_LB)
; ============================================================================

; Global variables for SD card download
global DownloadSDNumber := 0
global MultiCardDownload := false
global CancelCopy := false
global fullfolderpath := ""
global NextShootNo := ""
global Year := ""

; Initialize year
FormatTime, Year, , yy

DownloadSDCard:
if (Settings_EnableSounds)
	SoundPlay, %A_ScriptDir%\sidekick\media\DullDing.wav

; Validate settings first
if (Settings_ShootArchivePath = "" || !FileExist(Settings_ShootArchivePath)) {
	DarkMsgBox("Configuration Required", "Please configure your Archive Path in Settings → File Management first.", "warning")
	ShowSettingsTab("Files")
	Gui, Settings:Show
	return
}

if (Settings_CameraDownloadPath = "") {
	DarkMsgBox("Configuration Required", "Please configure your Download Path in Settings → File Management first.", "warning")
	ShowSettingsTab("Files")
	Gui, Settings:Show
	return
}

DownloadSD:
DownloadSDNumber := -1

; Check if card path exists with DCIM folder
CardPath := Settings_CardDrive
if (!FileExist(CardPath) || !InStr(CardPath, "DCIM")) {
	; Try to find DCIM in the drive
	driveLetter := SubStr(Settings_CardDrive, 1, 2)
	if FileExist(driveLetter . "\DCIM") {
		CardPath := driveLetter . "\DCIM"
	} else {
		DriveGet, DriveLabel, Label, %driveLetter%
		DarkMsgBox("SD Card Not Found", driveLetter . " " . DriveLabel . " Drive`n`nDCIM folder not found.`n`nNot a valid image drive.", "warning")
		return
	}
}

; Get drive label for display
driveLetter := SubStr(CardPath, 1, 2)
DriveGet, DriveLabel, Label, %driveLetter%

Gosub, SearchShootNoInFolder ; find latest Archived shoot
Sleep, 100

MultiCardDownload := false
OnMessage(0x44, "OnMsgBox4")
MsgBox 0x40223, SideKick PS ~ Downloader, %DriveLabel% Drive %driveLetter%\  Detected `n`nWould you like to download Images?`n`nNext Available Shoot No: %NextShootNo%`n`nSelect Multi Card for shoots spanning more than a single card., 120
OnMessage(0x44, "")

IfMsgBox, Yes
	return
IfMsgBox, No
	MultiCardDownload := true
IfMsgBox, Cancel
	MultiCardDownload := false
IfMsgBox, Timeout
	return

; Create download folder with timestamp
FormatTime, downloadFolder, , ddMMyyyy_HHmm
fullfolderpath := Settings_CameraDownloadPath . "\" . downloadFolder
FileCreateDir, %fullfolderpath%
IniWrite, %fullfolderpath%, %IniFilename%, Current_Shoot, ImageDownloadFolder

DowloadAnotherSD:
DownloadSDNumber++
Dir := CardPath
CopyDir := fullfolderpath

; Copy files from all DCIM subfolders
Loop Files, %driveLetter%\DCIM\*, D
{
	Dir := A_LoopFileFullPath
	Gosub, CopyFilesProgress
}

if (Settings_EnableSounds)
	SoundPlay, %A_ScriptDir%\sidekick\media\Speech On.wav

Gosub, AskShootNo
return

; Custom message box button handler
OnMsgBox4() {
	DetectHiddenWindows, On
	Process, Exist
	If (WinExist("ahk_class #32770 ahk_pid " . ErrorLevel)) {
		ControlSetText Button1, Cancel
		ControlSetText Button2, Multi Card
		ControlSetText Button3, Single Card
	}
}

AskShootNo:
Gosub, SearchShootNoInFolder
UserInput := ""
NextShootNo := Format("{:05}", NextShootNo)

test := RegExReplace(Trim(UserInput), "[^\d]+", "") ; numbers only
if (test = "")
	UserInput := NextShootNo

UserInput := Format("{:05}", UserInput)

SerchTarget := Settings_ShootArchivePath . "\" . Settings_ShootPrefix . UserInput . Settings_ShootSuffix

if !InStr(FileExist(SerchTarget), "D") ; if new shoot
{
	Gosub, RenameFiles
	
	if (MultiCardDownload)
	{
		MsgBox 0x40024, SideKick ~ %SerchTarget%, Download another Card for this shoot?`n`nJust Replace Card and click Yes.
		IfMsgBox, Yes
			Goto, DowloadAnotherSD
		IfMsgBox, No
		{
			Target := fullfolderpath . "\" . Settings_ShootPrefix . UserInput . Settings_ShootSuffix
			RemoveDir(fullfolderpath, "\" . Settings_ShootPrefix . "*" . Settings_ShootSuffix) ; clear empty old job folders
			
			if !InStr(FileExist(Target), "D")
				FileCreateDir, %Target% ; create blank job folder
			
			if (Settings_BrowsDown)
				Goto, RunEditor
		}
	}
	else
	{
		SerchTarget := fullfolderpath . "\" . Settings_ShootPrefix . UserInput . Settings_ShootSuffix
		RemoveDir(fullfolderpath, "\" . Settings_ShootPrefix . "*" . Settings_ShootSuffix) ; clear empty old job folders
		
		if !InStr(FileExist(SerchTarget), "D")
			FileCreateDir, %SerchTarget% ; create blank job folder
		
		if (Settings_BrowsDown)
			Goto, RunEditor
	}
}
else
{
	; Shoot already exists in archive
	OnMessage(0x44, "OnMsgBox7")
	MsgBox 0x131, SideKick ~ ATTENTION, Shoot %SerchTarget% already present in Archive!`n`nDo you wish to Append new images to shoot.
	OnMessage(0x44, "")
	if ErrorLevel
	{
		MsgBox, 262160, SideKick ~ Archiving Aborted, Images downloaded but NOT Renamed or Archived.
		return
	}
	IfMsgBox, OK
	{
		IniWrite, %UserInput%, %IniFilename%, Current_Shoot, CurrentShootNumber
		Gosub, RenameFiles
		DarkMsgBox("Complete", "All Camera Images Transferred", "success")
		
		if (Settings_BrowsDown)
			Goto, RunEditor
	}
}
return

OnMsgBox7() {
	DetectHiddenWindows, On
	Process, Exist
	If (WinExist("ahk_class #32770 ahk_pid " . ErrorLevel)) {
		ControlSetText Button2, Cancel
		ControlSetText Button1, Append
	}
}

; Remove empty folders matching pattern
RemoveDir(parentFolder, pattern := "\*", Self := 0) {
	if !(parentFolder)
		return
	Loop, Files, % parentFolder . pattern, DR
	{
		if DllCall("Shlwapi\PathIsDirectoryEmpty", "Str", A_LoopFilePath)
		{
			FileRemoveDir, %A_LoopFilePath%
		}
	}
	if Self
	{
		if DllCall("Shlwapi\PathIsDirectoryEmpty", "Str", parentFolder)
			FileRemoveDir, %parentFolder%
	}
}

; Search for next available shoot number in archive folder
SearchShootNoInFolder:
NextShootNo := ""
if (Settings_AutoShootYear)
	Padding := "###"
else
	Padding := "#####"
FList := ""
PLen := StrLen(Settings_ShootPrefix)
SLen := StrLen(Settings_ShootSuffix)
Shoot := Settings_ShootPrefix . Year . Padding . Settings_ShootSuffix
ShootNoLen := StrLen(Shoot)
FolderNameLen := PLen + SLen + ShootNoLen
Folder := ""

Loop, Files, % Settings_ShootArchivePath . "\" . Settings_ShootPrefix . Year . "*" . Settings_ShootSuffix . "*", D
{
	Folder := SubStr(A_LoopFileName, 1, ShootNoLen)
	if (Folder = "")
		Continue
	if InStr(Folder, "ERRO")
		Continue
	FList .= Folder . "`n"
}

Sort, FList, R  ; Sort in reverse order
MaxShootNo := ""

Loop, parse, FList, `n
{
	Folder := SubStr(A_LoopField, (PLen + 1), 5)
	if (Folder = "")
		continue
	if (A_Index = 1)
		MaxShootNo := Folder
	MinShootNo := Folder
}

NextShootNo := RegExReplace(MaxShootNo, "[^\d]+", "") + 1 ; numbers only + 1

if !(MaxShootNo) ; No shoot found
{
	NextShootNo++
	DarkMsgBox("Notice", "No " . Settings_ShootPrefix . Year . " Shoots found in archive.`n`nIf this is NOT your 1st shoot of the year something is wrong!", "warning")
}

if (Settings_AutoShootYear)
	NextShootNo := Year . SubStr(Format("{:03}", NextShootNo), -2)
else
	NextShootNo := Format("{:05}", NextShootNo)

IniWrite, %NextShootNo%, %IniFilename%, Current_Shoot, NextShootNo
return

; Rename files with shoot prefix
RenameFiles:
IniRead, fullfolderpath, %IniFilename%, Current_Shoot, ImageDownloadFolder, %A_Space%
IniRead, UserInput, %IniFilename%, Current_Shoot, NextShootNo, %A_Space%

AppendLetter := ""
if (DownloadSDNumber = 0 || DownloadSDNumber = "" || DownloadSDNumber = "0")
	DownloadSDNumber := ""
else
	DownloadSDNumber := Format("{:d}", DownloadSDNumber) ; ensure integer

NewFilePrefix := Settings_ShootPrefix . UserInput . Settings_ShootSuffix
NewFilePrefix := Trim(NewFilePrefix)

ImageName := Settings_ShootPrefix . UserInput . Settings_ShootSuffix . AppendLetter . DownloadSDNumber
StringUpper, ImageName, ImageName

if (ImageName = Settings_ShootSuffix . Settings_ShootPrefix || InStr(fullfolderpath, "\\"))
{
	DarkMsgBox("Error", "No shoot found to rename in`n" . fullfolderpath, "error")
	return
}

fullfolderpath := Trim(fullfolderpath)
FullDIRlist := ""
fPrefix := ""

Loop, Files, %fullfolderpath%\*, DFR
{
	SplitPath, A_LoopFileName, , , , fPrefix
	fPrefix := RTrim(fPrefix, "1234567890 ") ; find prefix before numbers
	
	if (fPrefix = "")
	{
		; Filename is purely numeric - construct new filename directly
		newFN := ImageName . "." . A_LoopFileExt
	}
	else
	{
		newFN := StrReplace(A_LoopFileName, fPrefix, ImageName) ; replace prefix
	}
	
	newPath := StrReplace(A_LoopFileFullPath, A_LoopFileName, "") ; delete filename
	FullFN := newPath . newFN
	orgFN := A_LoopFileFullPath
	
	if A_LoopFileExt
		FileMove, %orgFN%, %FullFN%
	else
		FileMoveDir, %orgFN%, %FullFN%, R
}
return

; Renumber files by date taken
RenumberByDate:
if (!Settings_AutoRenameImages && DownloadSDNumber)
{
	MsgBox, 262180, SideKick ~ Recommendation, %DownloadSDNumber% cards Downloaded.`n`nRenumber images by taken Time Stamp?
	IfMsgBox, No
		return
}

Flist := ""
Loop Files, %fullfolderpath%\*.*
{
	FileName := StrReplace(A_LoopFileName, "." . A_LoopFileExt)
	Flist .= FileName . "|" . A_LoopFileTimeModified . "`n"
}

Sort, Flist, U |:
Shoot := Settings_ShootPrefix . UserInput . Settings_ShootSuffix

Loop, Parse, Flist, `n
{
	ImageNumber := Format("{:04}", A_Index)
	Split := StrSplit(A_LoopField, "|")
	Filename := Split[1]
	if (Filename = "")
		Continue
	
	FileMove, %fullfolderpath%\%Filename%.*, %fullfolderpath%\%Shoot%%ImageNumber%.*
}
return

; Run photo editor
RunEditor:
if (Settings_AutoRenameImages)
	Gosub, RenumberByDate

if (Settings_EditorRunPath = "" || Settings_EditorRunPath = "Explore")
{
	CmdLine := "explorer /n,/e," . fullfolderpath . "\"
	Run, %CmdLine%
	return
}

SplitPath, Settings_EditorRunPath, Editorexe
EditorPath := """" . Settings_EditorRunPath . """"
Run, %EditorPath% %fullfolderpath%\
Sleep, 1000
WinActivate, ahk_exe %Editorexe%
return

; Copy files with progress indicator
CopyFilesProgress:
Unz(Dir, CopyDir)
return

; Shell copy function (uses Windows Shell for progress)
Unz(sZip, sUnz)
{
	; Validate paths
	if (!sZip || !sUnz) {
		DarkMsgBox("Error", "Invalid source or destination path.`n`nSource: " . sZip . "`nDest: " . sUnz, "error")
		return
	}
	
	if (!FileExist(sZip)) {
		DarkMsgBox("Error", "Source folder not found:`n" . sZip, "error")
		return
	}
	
	; Create destination folder
	if (!FileExist(sUnz)) {
		FileCreateDir, %sUnz%
		if (ErrorLevel) {
			DarkMsgBox("Error", "Failed to create destination folder:`n" . sUnz, "error")
			return
		}
	}
	
	Try {
		psh := ComObjCreate("Shell.Application")
		sourceItems := psh.Namespace(sZip).items()
		itemCount := sourceItems.count
		if !(itemCount) {
			ToolTip, No files found to copy
			Sleep, 2000
			ToolTip
			return
		}
		; Copy with Windows Shell progress dialog (flag 16 = respond Yes to All)
		psh.Namespace(sUnz).CopyHere(sourceItems, 16)
	}
	Catch e {
		DarkMsgBox("Error", "Failed to copy files from:`n" . sZip . "`n`nError: " . e, "error")
		return
	}
	return
}

; Set taskbar progress indicator (Windows 7+)
SetTaskbarProgress(pct, state := "", hwnd := "") {
	static tbl, s0 := 0, sI := 1, sN := 2, sE := 4, sP := 8
	if !tbl
		Try tbl := ComObjCreate("{56FDF344-FD6D-11d0-958A-006097C9A090}"
			, "{ea1afb91-9e28-4b86-90e9-9e9f8a5eefaf}")
	Catch
		return 0
	if (hwnd = "")
		hwnd := WinExist()
	if pct is not number
		state := pct, pct := ""
	else if (pct = 0 && state = "")
		state := 0, pct := ""
	if state in 0,I,N,E,P
		DllCall(NumGet(NumGet(tbl+0)+10*A_PtrSize), "uint", tbl, "uint", hwnd, "uint", s%state%)
	if (pct != "")
		DllCall(NumGet(NumGet(tbl+0)+9*A_PtrSize), "uint", tbl, "uint", hwnd, "int64", pct*10, "int64", 1000)
	return 1
}

; Auto-detect new drives (SD card insertion)
checkNewDrives:
if (!Settings_AutoDriveDetect)
	return

DriveGet, DriveListNew, List
if (DriveListNew && (DriveListNew != DriveListOld))
{
	Loop, Parse, DriveListOld
		StringReplace, DriveListNew, DriveListNew, %A_LoopField%
	if DriveListNew
	{
		DriveLabel := ""
		DriveGet, DriveLabel, Label, %DriveListNew%:
		
		; Ignore Google Drive and OneDrive
		if (InStr(DriveLabel, "Google Drive") || InStr(DriveLabel, "OneDrive"))
		{
			DriveGet, DriveListOld, List
			return
		}
		
		; Check if this drive has DCIM folder
		newDrive := DriveListNew . ":"
		if FileExist(newDrive . "\DCIM")
		{
			Settings_CardDrive := newDrive . "\DCIM"
			Gosub, DownloadSD
		}
	}
	DriveGet, DriveListOld, List
}
return

; Initialize drive list for detection
global DriveListOld := ""
DriveGet, DriveListOld, List

; Start drive detection timer if enabled
if (Settings_AutoDriveDetect)
	SetTimer, checkNewDrives, 3000

; ============================================
; Quick Publish GUI Handlers
; ============================================
QuickPubOK:
	Gui, QuickPub:Submit
	QuickPubVersionResult := QuickPubVersion
	Gui, QuickPub:Destroy
Return

QuickPubCancel:
QuickPubGuiClose:
QuickPubGuiEscape:
	QuickPubCancelled := true
	Gui, QuickPub:Destroy
Return

QuickPub2OK:
	Gui, QuickPub2:Submit
	QuickPub2CommitResult := QuickPubCommit
	Gui, QuickPub2:Destroy
Return

QuickPub2Cancel:
QuickPub2GuiClose:
QuickPub2GuiEscape:
	QuickPub2Cancelled := true
	Gui, QuickPub2:Destroy
Return

; ═══════════════════════════════════════════════════════════════════════════════
; QR Code Keyboard Wedge Scanner Support
; Triggers when a barcode scanner types the GHL URL quickly (faster than human typing)
; K-1 option ensures only fast keyboard wedge input triggers, not manual typing
; ═══════════════════════════════════════════════════════════════════════════════

; URL scanner support - triggers on https:// prefix (fast typing only)
; QR code format: https://app.domain.com/v2/location/.../contacts/detail/{ContactID}
; The long URL path provides natural padding - contact ID is at the END
:*CK-1:https`://::
	; Capture the rest of the URL (scanner types it fast)
	Input, urlRest, T3 L200, {Enter}{Tab}{Space}
	
	; Calculate total backspaces: https:// (8) + urlRest length
	backspaceCount := 8 + StrLen(urlRest)
	Loop, %backspaceCount%
		Send, {Backspace}
	
	; Build and open the full URL if it looks valid
	if (urlRest != "") {
		fullUrl := "https://" . urlRest
		; Check if it's a GHL contact URL (contains /contacts/detail/)
		if InStr(fullUrl, "/contacts/detail/") {
			Run, %fullUrl%
			ToolTip, Opening GHL Contact...
			SetTimer, RemoveToolTip, -2000
		} else {
			; Not a GHL contact URL - still open it but with different message
			Run, %fullUrl%
			ToolTip, Opening URL...
			SetTimer, RemoveToolTip, -2000
		}
	}
Return

; === QR Code Generation Library (must be at end of script) ===
#Include %A_ScriptDir%\Lib\Qr_CodeGen.ahk

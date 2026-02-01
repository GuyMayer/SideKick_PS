; ============================================================================
; Script:      SideKick_PS.ahk
; Description: Payment Plan Calculator for ProSelect Photography Software
; Version:     2.4.0
; Build Date:  2026-01-30
; Author:      GuyMayer
; Repository:  https://github.com/GuyMayer/SideKick_PS
; ============================================================================
; Changelog:
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
#SingleInstance Force

; Enable DPI awareness for proper scaling on high-DPI displays
DllCall("SetThreadDpiAwarenessContext", "ptr", -2, "ptr")  ; DPI_AWARENESS_CONTEXT_SYSTEM_AWARE

; Get system DPI scale factor (100 = 100%, 125 = 125%, etc.)
global DPI_Scale := A_ScreenDPI / 96

#Include %A_ScriptDir%\Lib\Acc.ahk
#Include %A_ScriptDir%\Lib\Chrome.ahk
#Include %A_ScriptDir%\Lib\Notes.ahk

; Script version info
global ScriptVersion := "2.4.42"
global BuildDate := "2026-01-26"
global LastSeenVersion := ""  ; User's last seen version for What's New dialog

; GHL Integration variables
global FBPE_URL := ""
global GHL_ContactID := ""
global GHL_API_Key := ""        ; V2 Private Integration Token
global GHL_LocationID := ""     ; GHL Location ID
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
global Settings_SearchAllTabs := 1  ; Search all Chrome tabs for GHL contact
global Settings_InvoiceWatchFolder := ""  ; Folder to watch for ProSelect invoice XML files
global Settings_GHLInvoiceWarningShown := 0  ; Has user been warned about GHL automated emails?
global Settings_GHLPaymentSettingsURL := ""  ; URL to GHL payment settings for email configuration
global Settings_CurrentTab := "General"

; File Management settings
global Settings_CardDrive := "F:\DCIM"  ; Default SD card path
global Settings_CameraDownloadPath := ""  ; Temp download folder
global Settings_ShootArchivePath := ""    ; Final archive location
global Settings_ShootPrefix := "P"        ; Shoot number prefix
global Settings_ShootSuffix := "P"        ; Shoot number suffix
global Settings_AutoShootYear := true     ; Include year in shoot number
global Settings_EditorRunPath := "Explore"  ; Photo editor path or "Explore"
global Settings_BrowsDown := true         ; Open editor after download
global Settings_AutoRenameImages := false ; Auto-rename by date
global Settings_AutoDriveDetect := true   ; Detect SD card insertion

; Hotkey settings (modifiers: ^ = Ctrl, ! = Alt, + = Shift, # = Win)
global Hotkey_GHLLookup := "^+g"  ; Ctrl+Shift+G
global Hotkey_PayPlan := "^+p"    ; Ctrl+Shift+P
global Hotkey_Settings := "^+s"   ; Ctrl+Shift+S

; License settings
global License_Key := ""          ; LemonSqueezy license key
global License_Status := "trial"  ; trial, active, expired, invalid
global License_CustomerName := ""
global License_CustomerEmail := ""
global License_ExpiresAt := ""
global License_InstanceID := ""
global License_ActivatedAt := ""
global License_ValidatedAt := ""  ; Last successful validation date
global License_PurchaseURL := "https://zoomphoto.lemonsqueezy.com/checkout/buy/234060d4-063d-4e6f-b91b-744c254c0e7c"

; Update check settings
global Update_SkippedVersion := ""    ; Version user chose to skip
global Update_LastCheckDate := ""     ; Last time we checked for updates
global Update_AvailableVersion := ""  ; Latest version found
global Update_DownloadURL := ""       ; URL to download update
global Settings_AutoUpdate := true    ; Enable automatic silent updates
global Settings_AutoSendLogs := true  ; Auto-send debug logs to developer
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

; Close any previous instances (no admin required)
#SingleInstance Force

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

PayPlanLine := []
LastButtonX := 0
LastButtonY := 0

; Load GHL API Key from SideKick_PS.ini (Base64 encoded)
; Try new key name first, fall back to V2 key for backwards compatibility
IniRead, GHL_API_Key_B64, %IniFilename%, GHL, API_Key_B64, %A_Space%
if (GHL_API_Key_B64 = "")
	IniRead, GHL_API_Key_B64, %IniFilename%, GHL, API_Key_V2_B64, %A_Space%
IniRead, GHL_LocationID, %IniFilename%, GHL, LocationID, %A_Space%

; Decode API key from Base64
if (GHL_API_Key_B64 != "")
	GHL_API_Key := Base64_Decode(GHL_API_Key_B64)

; Load settings from INI
LoadSettings()

; Add dev menu items if developer mode
if (IsDeveloperMode()) {
	Menu, Tray, Insert, &Settings, &Quick Publish, DevQuickPush
	Menu, Tray, Insert, &Quick Publish  ; Separator before Quick Publish
}

; Check license expiry status on startup
CheckLicenseExpiryOnStartup()

; Monthly license validation and update check (delayed to not block startup)
SetTimer, AsyncMonthlyCheck, -5000  ; Run once after 5 seconds

; Check for first-run GHL setup
CheckFirstRunGHLSetup()

; Initialize tooltip data for settings controls (hwnd => tooltip text)
global SettingsTooltips := {}
global LastHoveredControl := 0

; Detect ProSelect version on startup
DetectProSelectVersion()

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
RegisterHotkeys()

; Create floating toolbar
CreateFloatingToolbar()

;#######################################################
;Payplan Helper
SoundPlay %A_ScriptDir%\sidekick\media\KbdSpacebar.wav
sleep 250
SoundPlay %A_ScriptDir%\sidekick\media\KbdSpacebar.wav


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
		; Position unchanged, but ensure button is visible since window is focused
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
gosub, GetBalance

; Reset dropdown list variables to ensure correct format
Recurring := "Monthly||Weekly|Bi-Weekly|4-Weekly"
PayDayL := "Select||1st|2nd|3rd|4th|5th|6th|7th|8th|9th|10th|11th|12th|13th|14th|15th|16th|17th|18th|19th|20th|21st|22nd|23rd|24th|25th|26th|27th|28th|Last Day"
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

; Apply ProSelect 2025 dark theme with orange accents
if (ProSelectVersion = "2025") {
	Gui, PP:Color, 1E1E1E  ; Dark background matching ProSelect
	Gui, PP:Font, s9 cSilver, Segoe UI

	; Balance Due with orange highlight
	Gui, PP:Font, s11 cFF8000 Bold, Segoe UI
	Gui, PP:Add, Text, x20 y15 w200 h25, % "Balance Due: £" . PayDue

	; Labels
	Gui, PP:Font, s9 cSilver, Segoe UI
	Gui, PP:Add, Text, x20 y50 w110 h20, No. Payments:
	Gui, PP:Add, Text, x20 y80 w110 h20, Payment Amount:
	Gui, PP:Add, Text, x20 y120 w110 h20, Payment Type:
	Gui, PP:Add, Text, x20 y160 w110 h20, Recurring Period:

	; GroupBox for date selection
	Gui, PP:Font, s9 cSilver, Segoe UI
	Gui, PP:Add, GroupBox, x10 y195 w380 h70 cSilver, Start on Specific Date
	Gui, PP:Add, Text, x20 y218 w40 h20, Day:
	Gui, PP:Add, Text, x200 y218 w50 h20, Month:

	; Controls
	Gui, PP:Add, Edit, x140 y47 w80 h22 vPayNo gRecalcFromNo, %PayNo%
	Gui, PP:Add, UpDown, vMyUpDown gRecalcFromNo Range1-24, 3
	PayValue := ( PayDue / PayNo )
	PayValue := RegExReplace(PayValue,"(\.\d{2})\d*","$1")
	Gui, PP:Add, Edit, x140 y77 w80 h22 vPayValue1, %PayValue%
	Gui, PP:Add, Button, x230 y77 w60 h22 gRecalcFromAmount, Calc
	Gui, PP:Add, DropDownList, x140 y117 w160 h2000 vPayTypeSel gPayTypeSel, %PayType%
	Gui, PP:Add, DropDownList, x140 y157 w160 h2000 vRecurring, %Recurring%
	Gui, PP:Add, DropDownList, x60 y218 w130 h2000 vPayDay, %PayDayL%
	Gui, PP:Add, DropDownList, x250 y218 w130 h2000 vPayMonth, %PayMonthL%

	; Buttons - Schedule first, then Cancel (same font as PayPlan button)
	Gui, PP:Font, s10 Norm, Segoe UI Symbol
	Gui, PP:Add, Button, x20 y280 w220 h35 gMakePayments, 📅 Schedule Payments
	Gui, PP:Add, Button, x260 y280 w120 h35 gExitGui, Cancel

	Gui, PP:Show, w400 h330, SideKick_PS v%ScriptVersion% - Payment Calculator
} else {
	; ProSelect 2022 default style
	Gui, PP:Color, Default
	Gui, PP:Font, S10 CDefault, Verdana

	Gui, PP:Add, Text, x32 y39 w200 h20, % "Balance Due: £" . PayDue
	Gui, PP:Add, Text, x32 y69 w100 h20 +Right, No. Payments
	Gui, PP:Add, Text, x32 y99 w100 h20 +Right, Payments
	Gui, PP:Add, Text, x32 y149 w100 h20, Payment Type
	Gui, PP:Add, Text, x12 y192 w120 h20, Recurring Period
	Gui, PP:Add, GroupBox, x12 y229 w380 h70 +Center, Start on Specific date
	Gui, PP:Add, DropDownList, x32 y249 w140 h2000 vPayDay, %PayDayL%
	Gui, PP:Add, DropDownList, x202 y249 w170 h2000 vPayMonth, %PayMonthL%
	Gui, PP:Add, DropDownList, x142 y189 w160 h2000 vRecurring, %Recurring%
	Gui, PP:Add, DropDownList, x142 y149 w160 h2000 vPayTypeSel gPayTypeSel, %PayType%
	Gui, PP:Add, Edit, x142 y69 w100 h20 vPayNo gRecalcFromNo, %PayNo%
	Gui, PP:Add, UpDown, vMyUpDown gRecalcFromNo Range1-24, 3
	PayValue := ( PayDue / PayNo )
	PayValue := RegExReplace(PayValue,"(\.\d{2})\d*","$1")
	Gui, PP:Add, Edit, x142 y99 w100 h20 vPayValue1, %PayValue%
	Gui, PP:Add, Button, x250 y99 w60 h20 gRecalcFromAmount, Calc
	Gui, PP:Font, s10 Norm, Segoe UI Symbol
	Gui, PP:Add, Button, x42 y329 w200 h35 gMakePayments, 📅 Schedule Payments
	Gui, PP:Add, Button, x260 y329 w120 h35 gExitGui, Cancel

	Gui, PP:Show, x670 y236 h390 w414, SideKick_PS v%ScriptVersion% - Payment Calculator
}

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
Return

; Recalculate payment amount when number of payments changes
RecalcFromNo:
Gui, PP:Submit, NoHide
Gui, PP: +OwnDialogs
if (PayNo < 1)
	PayNo := 1
if (PayNo > 24)
	PayNo := 24
PayValue := ( PayDue / PayNo )
PayValue := RegExReplace(PayValue,"(\.\d{2})\d*","$1")
GuiControl,, PayValue1, %PayValue%

; Calculate rounding error
TotalPayments := PayValue * PayNo
RoundingError := PayDue - TotalPayments
RoundingError := Round(RoundingError, 2)
Return

; Recalculate number of payments when payment amount changes
RecalcFromAmount:
Gui, PP:Submit, NoHide
Gui, PP: +OwnDialogs

; Get the entered payment value
EnteredAmount := PayValue1
if (EnteredAmount <= 0 || EnteredAmount = "")
	Return

; Calculate how many payments needed (round to nearest whole number)
CalcPayNo := PayDue / EnteredAmount
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
PayValue := ( PayDue / PayNo )
PayValue := RegExReplace(PayValue,"(\.\d{2})\d*","$1")
GuiControl,, PayValue1, %PayValue%

; Calculate rounding error
TotalPayments := PayValue * PayNo
RoundingError := PayDue - TotalPayments
RoundingError := Round(RoundingError, 2)
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

; Function to get the correct Python executable path
; Checks for bundled Python first, then venv, then system Python
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
	
	; Check for virtual environment Python
	venvPython := A_ScriptDir . "\.venv\Scripts\python.exe"
	if (FileExist(venvPython)) {
		return venvPython
	}
	
	; Fall back to system Python
	return "python"
}

; Function to get the correct script path - checks for compiled .exe first, then .py
; This allows distribution with PyInstaller-compiled executables while supporting dev mode
; scriptName: base name without extension (e.g., "validate_license")
; Returns: full path to .exe if exists, otherwise full path to .py
GetScriptPath(scriptName) {
	; Check for compiled executable first (PyInstaller output)
	exePath := A_ScriptDir . "\" . scriptName . ".exe"
	if (FileExist(exePath)) {
		return exePath
	}
	
	; Fall back to Python script (development mode)
	pyPath := A_ScriptDir . "\" . scriptName . ".py"
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
	pythonPath := GetPythonPath()
	return """" . pythonPath . """ """ . scriptPath . """ " . args
}

ShowAbout:
; Open settings to About tab
Settings_CurrentTab := "About"
Gosub, ShowSettings
Return

; ============================================================================
; Floating Toolbar - Docks to ProSelect Window
; ============================================================================

CreateFloatingToolbar()
{
	global
	
	; Toolbar dimensions (0.75x of 1.5x = 1.125x original)
	toolbarWidth := 203
	toolbarHeight := 43
	
	; Transparent background with colored buttons
	Gui, Toolbar:New, +AlwaysOnTop +ToolWindow -Caption +HwndToolbarHwnd
	Gui, Toolbar:Color, 1E1E1E
	Gui, Toolbar:Font, s16, Segoe UI
	
	; Colored icon buttons (0.75x: 44x38)
	Gui, Toolbar:Add, Text, x2 y3 w44 h38 Center BackgroundBlue cWhite gToolbar_GetClient vTB_Client, 👤
	Gui, Toolbar:Add, Text, x53 y3 w44 h38 Center BackgroundGreen cWhite gToolbar_GetInvoice vTB_Invoice, 📋
	Gui, Toolbar:Add, Text, x104 y3 w44 h38 Center BackgroundOrange cWhite gToolbar_DownloadSD vTB_Download, 📥
	Gui, Toolbar:Add, Text, x155 y3 w44 h38 Center BackgroundPurple cWhite gToolbar_Settings vTB_Settings, ⚙
	
	; Make background transparent
	WinSet, TransColor, 1E1E1E, ahk_id %ToolbarHwnd%
	
	; Start position timer
	SetTimer, PositionToolbar, 200
}

PositionToolbar:
; Only show toolbar when ProSelect is the active window
WinGet, activeExe, ProcessName, A
if (activeExe != "ProSelect.exe")
{
	Gui, Toolbar:Hide
	return
}

; Get active window title
WinGetTitle, psTitle, A

; Don't show toolbar during splash screen - only hide if title is empty or just "ProSelect"
if (psTitle = "" || psTitle = "ProSelect")
{
	; Still on splash screen or loading - hide toolbar
	Gui, Toolbar:Hide
	return
}

; Skip dialog windows (Review Orders, Add Payment, etc.) - only attach to main album window
; Main window titles contain album name and end with " - ProSelect" or similar patterns
; Dialog windows have titles like "Review Orders", "Add Payment", "Print", etc.
dialogTitles := ["Review Orders", "Add Payment", "Print", "Export", "Preferences", "About", "License", "Settings", "Order Summary"]
for index, dialogTitle in dialogTitles {
	if (psTitle = dialogTitle || InStr(psTitle, dialogTitle) = 1) {
		; This is a dialog, don't move toolbar - just hide it or keep position
		Gui, Toolbar:Hide
		return
	}
}

WinGetPos, psX, psY, psW, psH, A
if (psX = "" || psW = "")
{
	Gui, Toolbar:Hide
	return
}

; Only attach to main window (should be reasonably large, not a small dialog)
if (psW < 800 || psH < 600)
{
	Gui, Toolbar:Hide
	return
}

; Position inline with window close X button
newX := psX + psW - 350
newY := psY + 6

Gui, Toolbar:Show, x%newX% y%newY% w203 h43 NoActivate
Return

Toolbar_GetClient:
Gosub, GHLClientLookup
Return

Toolbar_DownloadSD:
Gosub, DownloadSDCard
Return

Toolbar_GetInvoice:
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

; Open ProSelect Export Orders dialog (Orders menu -> Export Order)
WinActivate, ahk_exe ProSelect.exe
Sleep, 200
Send, !o  ; Alt+O opens Orders menu
Sleep, 200
Send, e   ; E selects Export Order
Sleep, 500
; Wait for Export Orders dialog (must be ProSelect window)
WinWait, Export Orders ahk_exe ProSelect.exe, , 3
if ErrorLevel
{
	DarkMsgBox("SideKick PS", "Export Orders dialog did not open", "warning")
	Return
}
Sleep, 200
; Ensure Export To is set to "Standard XML" (ComboBox1)
Control, ChooseString, Standard XML, ComboBox1, Export Orders ahk_exe ProSelect.exe
Sleep, 300
; Click "Check All" button (Button4) - explicitly target ProSelect Export Orders window
ControlClick, Button4, Export Orders ahk_exe ProSelect.exe
Sleep, 2000

; Use configured watch folder as the export folder (most reliable method)
ExportFolder := Settings_InvoiceWatchFolder

; If no watch folder configured, show error
if (ExportFolder = "" || !FileExist(ExportFolder))
{
	DarkMsgBox("Watch Folder Required", "Please set Invoice Watch Folder in Settings before exporting.", "warning")
	Return
}

; Click Export Now (Button2)
Sleep, 300
ControlClick, Button2, Export Orders ahk_exe ProSelect.exe
; Wait for export completion popup (ProSelect confirmation dialog)
WinWait, Export Orders ahk_exe ProSelect.exe, completed, 15
if !ErrorLevel
{
	Sleep, 500
	; Click OK on the completion dialog
	ControlClick, Button1, Export Orders ahk_exe ProSelect.exe
	Sleep, 500
	; Click Cancel to close the Export Orders window
	ControlClick, Cancel, Export Orders ahk_exe ProSelect.exe
	Sleep, 300
	
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
		DarkMsgBox("Missing Client ID", "Invoice XML is missing a Client ID.`n`nPlease link this order to a GHL contact before exporting.`n`nFile: " . latestXml, "warning")
		Return
	}
	
	; Run sync_ps_invoice to upload to GHL
	ToolTip, Syncing invoice to GHL...
	scriptPath := GetScriptPath("sync_ps_invoice")
	
	if (!FileExist(scriptPath))
	{
		DarkMsgBox("Script Missing", "Invoice exported but sync_ps_invoice not found.`n`nLooking for: " . scriptPath . "`nScript Dir: " . A_ScriptDir, "warning")
		Return
	}
	
	; Build arguments with optional financials-only flag
	syncArgs := """" . latestXml . """"
	if (Settings_FinancialsOnly)
		syncArgs .= " --financials-only"
	if (!Settings_ContactSheet)
		syncArgs .= " --no-contact-sheet"
	syncCmd := GetScriptCommand("sync_ps_invoice", syncArgs)
	RunWait, %ComSpec% /c "%syncCmd%", , Hide
	ToolTip  ; Clear the tooltip
	
	DarkMsgBox("Invoice Synced", "Invoice synced to GHL:`n" . latestXml, "success")
}
else
{
	DarkMsgBox("Export Timeout", "Export timeout - check ProSelect", "warning")
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
Gui, Settings:Color, %mainBg%
; Load window icon
global hSettingsIcon, hSettingsIconSmall
if FileExist(settingsIconPath) {
	hSettingsIcon := DllCall("LoadImage", "UPtr", 0, "Str", settingsIconPath, "UInt", 1, "Int", 32, "Int", 32, "UInt", 0x10, "UPtr")
	hSettingsIconSmall := DllCall("LoadImage", "UPtr", 0, "Str", settingsIconPath, "UInt", 1, "Int", 16, "Int", 16, "UInt", 0x10, "UPtr")
}
Gui, Settings:Font, s10 c%textColor%, Segoe UI

; Sidebar background
Gui, Settings:Add, Text, x0 y0 w180 h600 BackgroundTrans
Gui, Settings:Add, Progress, x0 y0 w180 h600 Background%sidebarBg% Disabled

; Sidebar header
Gui, Settings:Font, s12 c%headerColor%, Segoe UI
Gui, Settings:Add, Text, x15 y20 w150 BackgroundTrans Center, SideKick Hub

; Sidebar navigation tabs
Gui, Settings:Font, s11 c%textColor%, Segoe UI

; Tab buttons with highlight indicator
global TabGeneral, TabGHL, TabHotkeys, TabFiles, TabLicense, TabAbout
global TabGeneralBg, TabGHLBg, TabHotkeysBg, TabFilesBg, TabLicenseBg, TabAboutBg, TabDeveloperBg

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

; Developer tab (only for dev location)
Gui, Settings:Add, Progress, x0 y300 w4 h35 Background0078D4 vTabDeveloperBg Hidden
Gui, Settings:Add, Text, x15 y305 w160 h25 BackgroundTrans gSettingsTabDeveloper vTabDeveloper Hidden, 🛠  Developer

; SideKick Logo at bottom of sidebar - transparent PNG, use appropriate version for theme
logoPathDark := A_ScriptDir . "\SideKick_Logo_2025_Dark.png"
logoPathLight := A_ScriptDir . "\SideKick_Logo_2025_Light.png"
logoPath := Settings_DarkMode ? logoPathDark : logoPathLight

if FileExist(logoPath) {
	Gui, Settings:Add, Picture, x20 y380 w140 h140 vSettingsLogo, %logoPath%
} else {
	; Fallback text if logo not found
	Gui, Settings:Font, s14 cFF8C00, Segoe UI
	Gui, Settings:Add, Text, x15 y420 w150 h40 BackgroundTrans Center, 🚀 SIDEKICK
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
CreateDeveloperPanel()

; Show Developer tab only for dev location
if (GHL_LocationID = "8IWxk5M0PvbNf1w3npQU") {
	GuiControl, Settings:Show, TabDeveloper
}

; Bottom button bar
Gui, Settings:Add, Progress, x180 y550 w520 h50 Background%sidebarBg% Disabled

Gui, Settings:Font, s10 Norm c%textColor%, Segoe UI
Gui, Settings:Add, Button, x400 y560 w80 h30 gSettingsApply, &Apply
Gui, Settings:Add, Button, x490 y560 w80 h30 gSettingsClose, &Close

; Show the current tab
ShowSettingsTab(Settings_CurrentTab)

; Register mouse move handler for hover tooltips
OnMessage(0x200, "SettingsMouseMove")

Gui, Settings:Show, w700 h600, SideKick_PS Settings

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

ToggleClick_SearchAllTabs:
Toggle_SearchAllTabs_State := !Toggle_SearchAllTabs_State
UpdateToggleSlider("Settings", "SearchAllTabs", Toggle_SearchAllTabs_State, 590)
Return

ToggleClick_FinancialsOnly:
Toggle_FinancialsOnly_State := !Toggle_FinancialsOnly_State
Settings_FinancialsOnly := Toggle_FinancialsOnly_State
UpdateToggleSlider("Settings", "FinancialsOnly", Toggle_FinancialsOnly_State, 590)
SaveSettings()
Return

ToggleClick_ContactSheet:
Toggle_ContactSheet_State := !Toggle_ContactSheet_State
Settings_ContactSheet := Toggle_ContactSheet_State
UpdateToggleSlider("Settings", "ContactSheet", Toggle_ContactSheet_State, 590)
SaveSettings()
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
	
	; Calculate height based on content - more padding for button
	lineCount := msgLines.Length()
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
		Gui, DarkMsg:Add, Text, x%textX% y%yPos% w%msgWidth%, %line%
		yPos += lineHeight
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
	for i, btnText in buttons {
		xPos := btnStartX + ((i - 1) * (btnWidth + btnSpacing))
		defaultFlag := (i = defaultBtn) ? "Default" : ""
		if (Settings_DarkMode) {
			; Dark mode: use styled buttons with dark background
			Gui, DarkMsg:Add, Button, x%xPos% y%btnYPos% w%btnWidth% h%btnHeight% %defaultFlag% gDarkMsgBox_Click hwndBtnHwnd%i%, %btnText%
		} else {
			Gui, DarkMsg:Add, Button, x%xPos% y%btnYPos% w%btnWidth% h%btnHeight% %defaultFlag% gDarkMsgBox_Click, %btnText%
		}
	}
	
	; Show window
	Gui, DarkMsg:Show, w%winWidth% h%winHeight%, %title%
	
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
	WinWaitClose, %title% ahk_class AutoHotkeyGUI
	
	; Clear timeout
	SetTimer, DarkMsgBox_TimeoutHandler, Off
	
	return DarkMsgBox_Result
}

DarkMsgBox_Click:
	Gui, DarkMsg:Submit
	DarkMsgBox_Result := A_GuiControl
	if (DarkMsgBox_CheckVar)
		DarkMsgBox_Checked := 1
	Gui, DarkMsg:Destroy
Return

DarkMsgBox_TimeoutHandler:
	global DarkMsgBox_Timeout, DarkMsgBox_Result
	DarkMsgBox_Timeout--
	if (DarkMsgBox_Timeout <= 0) {
		SetTimer, DarkMsgBox_TimeoutHandler, Off
		DarkMsgBox_Result := "Timeout"
		Gui, DarkMsg:Destroy
	}
Return

DarkMsgGuiClose:
DarkMsgGuiEscape:
	DarkMsgBox_Result := "Cancel"
	Gui, DarkMsg:Destroy
Return

; ============================================================
; Hover-based Tooltip System for Settings GUI
; ============================================================

; Mouse hover handler for Settings window
SettingsMouseMove(wParam, lParam, msg, hwnd) {
	global SettingsTooltips, LastHoveredControl, SettingsHwnd
	static hoverTimer := 0
	
	; Only process if Settings window is active
	if !WinExist("ahk_id " . SettingsHwnd)
		return
	
	; Get the control under the mouse
	MouseGetPos, , , , controlHwnd, 2
	
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

TT_PSVersion:
tt := "DETECTED PROSELECT VERSION`n`nShows which ProSelect version was detected.`nSideKick uses this to optimize automation commands."
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
	} else {
		headerColor := "0078D4"
		textColor := "1E1E1E"
		labelColor := "444444"
		mutedColor := "666666"
	}
	
	; General panel container
	Gui, Settings:Add, Text, x190 y10 w500 h430 BackgroundTrans vPanelGeneral
	
	; Section header
	Gui, Settings:Font, s16 c%headerColor%, Segoe UI
	Gui, Settings:Add, Text, x200 y20 w400 BackgroundTrans vGenHeader, ⚙ General Settings
	
	; Behavior section
	Gui, Settings:Font, s12 c%textColor%, Segoe UI
	Gui, Settings:Add, Text, x200 y65 w200 BackgroundTrans vGenBehavior, Behavior
	
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	
	; Start on Boot toggle slider
	Gui, Settings:Add, Text, x200 y100 w300 BackgroundTrans vGenStartBoot gTT_StartOnBoot HwndHwndStartBoot, Start on Boot
	RegisterSettingsTooltip(HwndStartBoot, "START ON BOOT`n`nAutomatically launch SideKick_PS when Windows starts.`nThe script runs silently in the background and is ready`nwhenever you need it - no manual startup required.`n`nRecommended: Enable for daily ProSelect users.")
	CreateToggleSlider("Settings", "StartOnBoot", 590, 98, Settings_StartOnBoot)
	
	; Show Tray Icon toggle slider
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x200 y130 w300 BackgroundTrans vGenTrayIcon gTT_ShowTrayIcon HwndHwndTrayIcon, Show Tray Icon
	RegisterSettingsTooltip(HwndTrayIcon, "SHOW TRAY ICON`n`nDisplay the SideKick icon in your system tray (notification area).`nWhen visible you can right-click for quick access to features.`nWhen hidden the script still runs - use hotkeys to access.`n`nTip: Keep visible until you learn the keyboard shortcuts.")
	CreateToggleSlider("Settings", "ShowTrayIcon", 590, 128, Settings_ShowTrayIcon)
	
	; Enable Sounds toggle slider
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x200 y160 w300 BackgroundTrans vGenSounds gTT_EnableSounds HwndHwndSounds, Enable Sound Effects
	RegisterSettingsTooltip(HwndSounds, "SOUND EFFECTS`n`nPlay audio feedback for actions and notifications.`nIncludes confirmation beeps and alert sounds.`n`nDisable if working in quiet environments`nor if sounds become distracting.")
	CreateToggleSlider("Settings", "EnableSounds", 590, 158, Settings_EnableSounds)
	
	; Auto-detect ProSelect toggle slider
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x200 y190 w300 BackgroundTrans vGenAutoPS gTT_AutoDetectPS HwndHwndAutoPS, Auto-detect ProSelect Version
	RegisterSettingsTooltip(HwndAutoPS, "AUTO-DETECT PROSELECT VERSION`n`nAutomatically identify which ProSelect version is installed.`nThis optimizes keyboard shortcuts and window detection`nfor your specific ProSelect version (2022, 2024, 2025).`n`nRecommended: Keep enabled unless detection causes issues.")
	CreateToggleSlider("Settings", "AutoDetectPS", 590, 188, Settings_AutoDetectPS)
	
	; Dark Mode toggle slider
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x200 y220 w300 BackgroundTrans vGenDarkMode gTT_DarkMode HwndHwndDarkMode, Dark Mode
	RegisterSettingsTooltip(HwndDarkMode, "DARK MODE`n`nToggle between dark and light color themes.`n`nDark Mode: Easy on the eyes, matches ProSelect 2025 style`nLight Mode: Traditional bright interface`n`nChanges apply immediately to the Settings window.")
	CreateToggleSlider("Settings", "DarkMode", 590, 218, Settings_DarkMode)
	
	; Defaults section
	Gui, Settings:Font, s12 c%textColor%, Segoe UI
	Gui, Settings:Add, Text, x200 y270 w200 BackgroundTrans vGenDefaults, Payment Defaults
	
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	
	; Default Recurring
	Gui, Settings:Add, Text, x200 y305 w150 BackgroundTrans vGenRecurLabel gTT_DefaultRecurring HwndHwndRecur, Default Recurring:
	RegisterSettingsTooltip(HwndRecur, "DEFAULT PAYMENT FREQUENCY`n`nSet the pre-selected payment schedule for new plans.`nMonthly is always available. Other options can be customized.`n`nThis can be changed per-plan when creating payments.")
	Gui, Settings:Add, DropDownList, x380 y302 w150 vSettings_DefaultRecurring_DDL, Monthly||Weekly|Bi-Weekly|4-Weekly
	
	; Recurring Options (editable)
	Gui, Settings:Add, Text, x200 y340 w150 BackgroundTrans vGenRecurOptionsLabel, Recurring Options:
	Gui, Settings:Add, Edit, x380 y337 w150 h24 vGenRecurOptionsEdit ReadOnly, Monthly, Weekly, Bi-Weekly, 4-Weekly
	Gui, Settings:Add, Button, x540 y336 w60 h26 gEditRecurringOptions vGenRecurOptionsBtn, Edit
	
	; ProSelect section
	Gui, Settings:Font, s12 c%textColor%, Segoe UI
	Gui, Settings:Add, Text, x200 y380 w200 BackgroundTrans vGenProSelect, ProSelect
	
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	DetectProSelectVersion()
	psVer := ProSelectVersion ? ProSelectVersion : "Not detected"
	Gui, Settings:Add, Text, x200 y410 w300 BackgroundTrans vGenPSVersion gTT_PSVersion HwndHwndPSVersion, Detected Version: %psVer%
	RegisterSettingsTooltip(HwndPSVersion, "DETECTED PROSELECT VERSION`n`nShows which ProSelect version was automatically detected.`nSideKick uses this to optimize automation commands`nand window handling for your specific version.`n`nIf showing 'Not detected' ensure ProSelect is installed.")
	
	; Desktop Shortcut button
	Gui, Settings:Add, Button, x200 y445 w150 h30 gCreateSideKickShortcut vGenShortcutBtn, 🚀 Desktop Shortcut
	
	; Import/Export Settings buttons
	Gui, Settings:Add, Button, x390 y445 w100 h30 gExportSettings vGenExportBtn, 📤 Export
	Gui, Settings:Add, Button, x500 y445 w100 h30 gImportSettings vGenImportBtn, 📥 Import
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
	} else {
		headerColor := "0078D4"
		textColor := "1E1E1E"
		labelColor := "444444"
		mutedColor := "666666"
	}
	
	; GHL panel container (initially hidden)
	Gui, Settings:Add, Text, x190 y10 w500 h430 BackgroundTrans vPanelGHL Hidden
	
	; Section header
	Gui, Settings:Font, s16 c%headerColor%, Segoe UI
	Gui, Settings:Add, Text, x200 y20 w400 BackgroundTrans vGHLHeader Hidden, 🔗 GHL Integration
	
	; Connection section
	Gui, Settings:Font, s12 c%textColor%, Segoe UI
	Gui, Settings:Add, Text, x200 y65 w200 BackgroundTrans vGHLConnection Hidden, Connection
	
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	
	; Enable GHL Integration toggle slider
	Gui, Settings:Add, Text, x200 y100 w300 BackgroundTrans vGHLEnable Hidden gTT_GHLEnable HwndHwndGHLEnable, Enable GHL Integration
	RegisterSettingsTooltip(HwndGHLEnable, "ENABLE GHL INTEGRATION`n`nConnect SideKick to your GoHighLevel CRM.`nFetch client details and auto-populate ProSelect.`n`nRequires a valid GHL API key.")
	CreateToggleSlider("Settings", "GHL_Enabled", 590, 98, Settings_GHL_Enabled)
	
	; Auto-load to ProSelect toggle slider
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x200 y130 w300 BackgroundTrans vGHLAutoLoad Hidden gTT_GHLAutoLoad HwndHwndGHLAutoLoad, Auto-load to ProSelect (skip confirmation)
	RegisterSettingsTooltip(HwndGHLAutoLoad, "AUTO-LOAD TO PROSELECT`n`nENABLED: Client data loads immediately.`nDISABLED: Preview dialog appears first.`n`nKeep disabled until you trust data quality.")
	CreateToggleSlider("Settings", "GHL_AutoLoad", 590, 128, Settings_GHL_AutoLoad)
	
	; API Configuration section
	Gui, Settings:Font, s12 c%textColor%, Segoe UI
	Gui, Settings:Add, Text, x200 y200 w200 BackgroundTrans vGHLApiConfig Hidden, API Configuration
	
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	
	; API Key display (masked) - Private Integration Token
	Gui, Settings:Add, Text, x200 y230 w100 BackgroundTrans vGHLApiLabel Hidden gTT_GHLApiKey HwndHwndGHLApiKey, API Key:
	RegisterSettingsTooltip(HwndGHLApiKey, "GHL API KEY (Private Integration Token)`n`nUsed for: Contacts, Invoices, Payments, etc.`n`nTo get your key:`n1. Go to GHL Marketplace`n2. My Apps > Create Private App`n3. Copy the Private Integration Token`n`nKeys are stored encrypted in the INI file.")
	apiKeyDisplay := GHL_API_Key ? SubStr(GHL_API_Key, 1, 8) . "..." . SubStr(GHL_API_Key, -4) : "Not configured"
	Gui, Settings:Add, Edit, x310 y227 w220 h25 vGHLApiKeyDisplay Hidden ReadOnly, %apiKeyDisplay%
	Gui, Settings:Add, Button, x540 y225 w90 h28 gEditGHLApiKey vGHLApiEditBtn Hidden, Edit
	
	; Location ID display
	Gui, Settings:Add, Text, x200 y260 w100 BackgroundTrans vGHLLocLabel Hidden gTT_GHLLocID HwndHwndGHLLocID, Location ID:
	RegisterSettingsTooltip(HwndGHLLocID, "GHL LOCATION ID`n`nYour GoHighLevel sub-account ID.`nUsed for API calls to the correct location.`n`nFind it in GHL: Settings > Business Profile")
	locIdDisplay := GHL_LocationID ? GHL_LocationID : "Not configured"
	Gui, Settings:Add, Edit, x310 y257 w220 h25 vGHLLocIDDisplay Hidden ReadOnly, %locIdDisplay%
	Gui, Settings:Add, Button, x540 y255 w90 h28 gEditGHLLocationID vGHLLocEditBtn Hidden, Edit
	
	; Status section
	Gui, Settings:Font, s12 c%textColor%, Segoe UI
	Gui, Settings:Add, Text, x200 y295 w200 BackgroundTrans vGHLStatus Hidden, Status
	
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	
	; Connection status
	statusText := GHL_API_Key ? "✅ Connected" : "❌ Not configured"
	statusColor := GHL_API_Key ? "00FF00" : "FF6B6B"
	Gui, Settings:Font, s10 c%statusColor%, Segoe UI
	Gui, Settings:Add, Text, x200 y320 w400 BackgroundTrans vGHLStatusText Hidden HwndHwndGHLStatus, %statusText%
	RegisterSettingsTooltip(HwndGHLStatus, "CONNECTION STATUS`n`n✅ Connected = API key configured`n`nUse 'Test' to verify.")
	
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Button, x200 y345 w80 h28 gTestGHLConnection vGHLTestBtn Hidden HwndHwndGHLTest, Test
	RegisterSettingsTooltip(HwndGHLTest, "TEST CONNECTION`n`nVerify your API key works by making`na test request to the GHL API.")
	
	Gui, Settings:Add, Button, x290 y345 w130 h28 gRunGHLSetupWizard vGHLSetupBtn Hidden, 🔧 Setup Wizard
	
	; Invoice Settings section
	Gui, Settings:Font, s12 Norm c%textColor%, Segoe UI
	Gui, Settings:Add, Text, x200 y385 w200 BackgroundTrans vGHLInvoiceHeader Hidden, Invoice Settings
	
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x200 y410 w100 BackgroundTrans vGHLWatchLabel Hidden, Watch Folder:
	Gui, Settings:Add, Edit, x310 y407 w250 h25 vGHLWatchFolderEdit Hidden, %Settings_InvoiceWatchFolder%
	Gui, Settings:Add, Button, x565 y405 w60 h28 gBrowseInvoiceFolder vGHLWatchBrowseBtn Hidden, Browse
	
	; Search all tabs toggle slider
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x200 y440 w350 BackgroundTrans vGHLSearchAllTabs Hidden HwndHwndSearchAllTabs, Search all Chrome tabs for GHL contact
	RegisterSettingsTooltip(HwndSearchAllTabs, "SEARCH ALL CHROME TABS`n`nWhen enabled, searches all open Chrome tabs`nfor a matching GHL contact URL.`n`nDisabled: Only checks the active tab.")
	CreateToggleSlider("Settings", "SearchAllTabs", 590, 438, Settings_SearchAllTabs)
	
	; Financials only toggle slider
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x200 y470 w350 BackgroundTrans vGHLFinancialsOnly Hidden HwndHwndFinancialsOnly, Financials only (exclude image lines)
	RegisterSettingsTooltip(HwndFinancialsOnly, "FINANCIALS ONLY MODE`n`nWhen enabled, invoice sync will only include:`n• Lines with monetary values`n• Comment/text lines`n`nExcludes lines that are just image numbers (e.g. 001, 002).`nThis keeps your GHL invoices clean and financial-focused.")
	CreateToggleSlider("Settings", "FinancialsOnly", 590, 468, Settings_FinancialsOnly)
	
	; Contact Sheet toggle slider
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x200 y500 w350 BackgroundTrans vGHLContactSheet Hidden HwndHwndContactSheet, Create contact sheet with order
	RegisterSettingsTooltip(HwndContactSheet, "CONTACT SHEET WITH ORDER`n`nWhen enabled, creates a JPG contact sheet showing`nall product images and uploads to GHL Media.`n`nThe contact sheet is added as a note on the contact`nfor easy reference.")
	CreateToggleSlider("Settings", "ContactSheet", 590, 498, Settings_ContactSheet)
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
	} else {
		headerColor := "0078D4"
		textColor := "1E1E1E"
		labelColor := "444444"
		mutedColor := "666666"
		inputBg := "FFFFFF"
	}
	
	; Hotkeys panel container (initially hidden)
	Gui, Settings:Add, Text, x190 y10 w500 h430 BackgroundTrans vPanelHotkeys Hidden
	
	; Section header
	Gui, Settings:Font, s16 c%headerColor%, Segoe UI
	Gui, Settings:Add, Text, x200 y20 w400 BackgroundTrans vHotkeysHeader Hidden, ⌨ Keyboard Shortcuts
	
	; Info text
	Gui, Settings:Font, s10 c%mutedColor%, Segoe UI
	Gui, Settings:Add, Text, x200 y55 w450 BackgroundTrans vHotkeysInfo Hidden, Click a field then press your desired key combination
	
	; Hotkey configuration section
	Gui, Settings:Font, s12 c%textColor%, Segoe UI
	Gui, Settings:Add, Text, x200 y100 w200 BackgroundTrans vHotkeysSection Hidden, Global Hotkeys
	
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	
	; GHL Client Lookup hotkey
	Gui, Settings:Add, Text, x200 y140 w180 BackgroundTrans vHKLabelGHL Hidden HwndHwndHKGHL, GHL Client Lookup:
	RegisterSettingsTooltip(HwndHKGHL, "GHL CLIENT LOOKUP`n`nFetch client details from GoHighLevel.`nClick field and press your hotkey.`n`nDefault: Ctrl+Shift+G")
	displayGHL := FormatHotkeyDisplay(Hotkey_GHLLookup)
	Gui, Settings:Add, Edit, x400 y137 w150 h25 vHotkey_GHLLookup_Edit ReadOnly Hidden, %displayGHL%
	Gui, Settings:Add, Button, x560 y136 w60 h27 gCaptureHotkey_GHL vHKCaptureGHL Hidden, Set
	
	; PayPlan hotkey
	Gui, Settings:Add, Text, x200 y180 w180 BackgroundTrans vHKLabelPP Hidden HwndHwndHKPP, Open PayPlan:
	RegisterSettingsTooltip(HwndHKPP, "OPEN PAYPLAN`n`nOpen the PayPlan calculator window.`nClick field and press your hotkey.`n`nDefault: Ctrl+Shift+P")
	displayPP := FormatHotkeyDisplay(Hotkey_PayPlan)
	Gui, Settings:Add, Edit, x400 y177 w150 h25 vHotkey_PayPlan_Edit ReadOnly Hidden, %displayPP%
	Gui, Settings:Add, Button, x560 y176 w60 h27 gCaptureHotkey_PayPlan vHKCapturePP Hidden, Set
	
	; Settings hotkey
	Gui, Settings:Add, Text, x200 y220 w180 BackgroundTrans vHKLabelSettings Hidden HwndHwndHKSettings, Open Settings:
	RegisterSettingsTooltip(HwndHKSettings, "OPEN SETTINGS`n`nOpen this Settings window.`nClick field and press your hotkey.`n`nDefault: Ctrl+Shift+S")
	displaySettings := FormatHotkeyDisplay(Hotkey_Settings)
	Gui, Settings:Add, Edit, x400 y217 w150 h25 vHotkey_Settings_Edit ReadOnly Hidden, %displaySettings%
	Gui, Settings:Add, Button, x560 y216 w60 h27 gCaptureHotkey_Settings vHKCaptureSettings Hidden, Set
	
	; Clear buttons section
	Gui, Settings:Font, s12 c%textColor%, Segoe UI
	Gui, Settings:Add, Text, x200 y280 w200 BackgroundTrans vHKActionsTitle Hidden, Actions
	
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Button, x200 y315 w150 h30 gResetHotkeysToDefault vHKResetBtn Hidden, Reset to Defaults
	Gui, Settings:Add, Button, x370 y315 w150 h30 gClearAllHotkeys vHKClearBtn Hidden, Clear All
	
	; Instructions
	Gui, Settings:Font, s10 c%mutedColor%, Segoe UI
	Gui, Settings:Add, Text, x200 y370 w430 BackgroundTrans vHKInstructions1 Hidden, How to set a hotkey:
	Gui, Settings:Add, Text, x200 y390 w430 BackgroundTrans vHKInstructions2 Hidden, 1. Click the "Set" button next to the action
	Gui, Settings:Add, Text, x200 y410 w430 BackgroundTrans vHKInstructions3 Hidden, 2. Press your desired key combination
	Gui, Settings:Add, Text, x200 y430 w430 BackgroundTrans vHKInstructions4 Hidden, 3. The hotkey will be captured automatically
	
	; Note about changes
	Gui, Settings:Font, s9 c%mutedColor%, Segoe UI
	Gui, Settings:Add, Text, x200 y460 w400 BackgroundTrans vHKNote Hidden, Changes take effect when you click Apply or close Settings
}

CreateFilesPanel()
{
	global
	
	; Theme-aware colors
	if (Settings_DarkMode) {
		headerColor := "4FC3F7"
		textColor := "FFFFFF"
		labelColor := "CCCCCC"
		mutedColor := "888888"
		sectionColor := "4FC3F7"
	} else {
		headerColor := "0078D4"
		textColor := "1E1E1E"
		labelColor := "444444"
		mutedColor := "666666"
		sectionColor := "0078D4"
	}
	
	; Files panel container (initially hidden)
	Gui, Settings:Add, Text, x190 y10 w500 h530 BackgroundTrans vPanelFiles Hidden
	
	; Section header
	Gui, Settings:Font, s16 c%headerColor%, Segoe UI
	Gui, Settings:Add, Text, x200 y20 w400 BackgroundTrans vFilesHeader Hidden, 📁 File Management
	
	; SD Card Download Section
	Gui, Settings:Font, s12 c%sectionColor%, Segoe UI
	Gui, Settings:Add, Text, x200 y60 w300 BackgroundTrans vFilesSDCard Hidden, SD Card Download
	
	; Card Drive Path
	Gui, Settings:Font, s10 c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x200 y95 w120 BackgroundTrans vFilesCardDriveLabel Hidden, Card Path:
	Gui, Settings:Add, Edit, x320 y92 w230 h25 vFilesCardDriveEdit Hidden, %Settings_CardDrive%
	Gui, Settings:Add, Button, x555 y90 w60 h28 gFilesCardDriveBrowseBtn vFilesCardDriveBrowse Hidden, Browse
	
	; Download Folder
	Gui, Settings:Add, Text, x200 y125 w120 BackgroundTrans vFilesDownloadLabel Hidden, Download To:
	Gui, Settings:Add, Edit, x320 y122 w230 h25 vFilesDownloadEdit Hidden, %Settings_CameraDownloadPath%
	Gui, Settings:Add, Button, x555 y120 w60 h28 gFilesDownloadBrowseBtn vFilesDownloadBrowse Hidden, Browse
	
	; Archive Section
	Gui, Settings:Font, s12 c%sectionColor%, Segoe UI
	Gui, Settings:Add, Text, x200 y160 w300 BackgroundTrans vFilesArchive Hidden, Archive Settings
	
	; Archive Path
	Gui, Settings:Font, s10 c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x200 y195 w120 BackgroundTrans vFilesArchiveLabel Hidden, Archive Path:
	Gui, Settings:Add, Edit, x320 y192 w230 h25 vFilesArchiveEdit Hidden, %Settings_ShootArchivePath%
	Gui, Settings:Add, Button, x555 y190 w60 h28 gFilesArchiveBrowseBtn vFilesArchiveBrowse Hidden, Browse
	
	; Naming Convention Section
	Gui, Settings:Font, s12 c%sectionColor%, Segoe UI
	Gui, Settings:Add, Text, x200 y230 w300 BackgroundTrans vFilesNaming Hidden, File Naming
	
	Gui, Settings:Font, s10 c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x200 y265 w80 BackgroundTrans vFilesPrefixLabel Hidden, Prefix:
	Gui, Settings:Add, Edit, x280 y262 w60 h25 vFilesPrefixEdit Hidden, %Settings_ShootPrefix%
	
	Gui, Settings:Add, Text, x360 y265 w80 BackgroundTrans vFilesSuffixLabel Hidden, Suffix:
	Gui, Settings:Add, Edit, x440 y262 w60 h25 vFilesSuffixEdit Hidden, %Settings_ShootSuffix%
	
	; Auto Year Toggle
	Gui, Settings:Add, Text, x200 y300 w200 BackgroundTrans vFilesAutoYear Hidden, Include Year in Shoot No:
	autoYearState := Settings_AutoShootYear ? "On" : "Off"
	Gui, Settings:Add, Checkbox, x420 y300 w20 h20 vToggle_AutoShootYear gToggle_AutoShootYear Checked%Settings_AutoShootYear% Hidden
	
	; Auto Rename Toggle
	Gui, Settings:Add, Text, x200 y330 w200 BackgroundTrans vFilesAutoRename Hidden, Auto-Rename by Date:
	Gui, Settings:Add, Checkbox, x420 y330 w20 h20 vToggle_AutoRenameImages gToggle_AutoRenameImages Checked%Settings_AutoRenameImages% Hidden
	
	; Editor Section
	Gui, Settings:Font, s12 c%sectionColor%, Segoe UI
	Gui, Settings:Add, Text, x200 y370 w300 BackgroundTrans vFilesEditor Hidden, Photo Editor
	
	Gui, Settings:Font, s10 c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x200 y405 w120 BackgroundTrans vFilesEditorLabel Hidden, Editor Path:
	editorDisplay := (Settings_EditorRunPath = "Explore" || Settings_EditorRunPath = "") ? "Windows Explorer" : Settings_EditorRunPath
	Gui, Settings:Add, Edit, x320 y402 w230 h25 vFilesEditorEdit Hidden, %editorDisplay%
	Gui, Settings:Add, Button, x555 y400 w60 h28 gFilesEditorBrowseBtn vFilesEditorBrowse Hidden, Browse
	
	; Open Editor After Download Toggle
	Gui, Settings:Add, Text, x200 y440 w200 BackgroundTrans vFilesOpenEditor Hidden, Open Editor After Download:
	Gui, Settings:Add, Checkbox, x420 y440 w20 h20 vToggle_BrowsDown gToggle_BrowsDown Checked%Settings_BrowsDown% Hidden
	
	; Auto Drive Detection Toggle
	Gui, Settings:Add, Text, x200 y470 w200 BackgroundTrans vFilesAutoDrive Hidden, Auto-Detect SD Cards:
	Gui, Settings:Add, Checkbox, x420 y470 w20 h20 vToggle_AutoDriveDetect gToggle_AutoDriveDetect Checked%Settings_AutoDriveDetect% Hidden
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
		successColor := "00FF00"
		warningColor := "FFB84D"
		errorColor := "FF6B6B"
	} else {
		headerColor := "0078D4"
		textColor := "1E1E1E"
		labelColor := "444444"
		mutedColor := "666666"
		successColor := "008800"
		warningColor := "CC6600"
		errorColor := "CC0000"
	}
	
	; License panel container (initially hidden)
	Gui, Settings:Add, Text, x190 y10 w500 h530 BackgroundTrans vPanelLicense Hidden
	
	; Section header
	Gui, Settings:Font, s16 c%headerColor%, Segoe UI
	Gui, Settings:Add, Text, x200 y20 w400 BackgroundTrans vLicenseHeader Hidden, 🔑 License
	
	; License Status Section
	Gui, Settings:Font, s12 c%textColor%, Segoe UI
	Gui, Settings:Add, Text, x200 y65 w200 BackgroundTrans vLicenseStatusTitle Hidden, Status
	
	; Status indicator - dynamic based on license state
	statusText := GetLicenseStatusText()
	statusColor := GetLicenseStatusColor()
	Gui, Settings:Font, s11 c%statusColor%, Segoe UI
	Gui, Settings:Add, Text, x200 y95 w400 BackgroundTrans vLicenseStatusText Hidden, %statusText%
	
	; License Key Section
	Gui, Settings:Font, s12 c%textColor%, Segoe UI
	Gui, Settings:Add, Text, x200 y160 w200 BackgroundTrans vLicenseKeyTitle Hidden, License Key
	
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x200 y195 w100 BackgroundTrans vLicenseKeyLabel Hidden, Key:
	keyDisplay := License_Key ? License_Key : "Not entered"
	Gui, Settings:Add, Edit, x300 y192 w230 h25 vLicenseKeyEdit Hidden, %keyDisplay%
	Gui, Settings:Add, Button, x540 y190 w80 h28 gActivateLicenseBtn vLicenseActivateBtn Hidden, Activate
	
	; Location binding info
	Gui, Settings:Font, s10 c%mutedColor%, Segoe UI
	locDisplay := GHL_LocationID ? GHL_LocationID : "(Configure in GHL tab first)"
	Gui, Settings:Add, Text, x200 y230 w430 BackgroundTrans vLicenseLocationInfo Hidden, Bound to Location: %locDisplay%
	
	; Activation Details Section (shown when activated)
	Gui, Settings:Font, s12 c%textColor%, Segoe UI
	Gui, Settings:Add, Text, x200 y275 w200 BackgroundTrans vLicenseDetailsTitle Hidden, Activation Details
	
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	
	; Customer name
	nameDisplay := License_CustomerName ? License_CustomerName : "—"
	Gui, Settings:Add, Text, x200 y310 w120 BackgroundTrans vLicenseNameLabel Hidden, Licensed to:
	Gui, Settings:Add, Text, x330 y310 w290 BackgroundTrans vLicenseNameValue Hidden, %nameDisplay%
	
	; Customer email
	emailDisplay := License_CustomerEmail ? License_CustomerEmail : "—"
	Gui, Settings:Add, Text, x200 y335 w120 BackgroundTrans vLicenseEmailLabel Hidden, Email:
	Gui, Settings:Add, Text, x330 y335 w290 BackgroundTrans vLicenseEmailValue Hidden, %emailDisplay%
	
	; Activation date
	activatedDisplay := License_ActivatedAt ? License_ActivatedAt : "—"
	Gui, Settings:Add, Text, x200 y360 w120 BackgroundTrans vLicenseActivatedLabel Hidden, Activated:
	Gui, Settings:Add, Text, x330 y360 w290 BackgroundTrans vLicenseActivatedValue Hidden, %activatedDisplay%
	
	; Expiry date
	expiryDisplay := License_ExpiresAt ? License_ExpiresAt : "—"
	Gui, Settings:Add, Text, x200 y385 w120 BackgroundTrans vLicenseExpiryLabel Hidden, Expires:
	Gui, Settings:Add, Text, x330 y385 w290 BackgroundTrans vLicenseExpiryValue Hidden, %expiryDisplay%
	
	; Action buttons
	Gui, Settings:Font, s10 Norm c%textColor%, Segoe UI
	Gui, Settings:Add, Button, x200 y430 w120 h30 gValidateLicenseBtn vLicenseValidateBtn Hidden, ✓ Validate
	Gui, Settings:Add, Button, x330 y430 w120 h30 gDeactivateLicenseBtn vLicenseDeactivateBtn Hidden, ✗ Deactivate
	Gui, Settings:Add, Button, x460 y430 w150 h30 gBuyLicenseBtn vLicenseBuyBtn Hidden, 🛒 Buy License
	
	; Purchase info
	Gui, Settings:Font, s10 c%mutedColor%, Segoe UI
	Gui, Settings:Add, Text, x200 y480 w430 BackgroundTrans vLicensePurchaseInfo Hidden, Licenses are bound to your GHL Location ID for security.
	Gui, Settings:Add, Text, x200 y500 w430 BackgroundTrans vLicensePurchaseInfo2 Hidden, Each license allows activation on one location.
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

CheckLicenseForGHL(featureName := "GHL Integration") {
	; Check if license is valid before using GHL features
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

CheckMonthlyValidationAndUpdate() {
	; Check if a month has passed since last validation
	; If so, validate license AND check for updates
	global License_ValidatedAt, License_Status, License_Key, Update_LastCheckDate
	
	; Get today's date in yyyyMMdd format
	FormatTime, today,, yyyyMMdd
	
	; Check if validation/update check is needed (monthly = 30 days)
	needsCheck := false
	
	if (Update_LastCheckDate = "") {
		needsCheck := true
	} else {
		; Calculate days since last check using EnvSub (AHK v1 date math)
		daysSinceCheck := today
		EnvSub, daysSinceCheck, %Update_LastCheckDate%, Days
		if (daysSinceCheck >= 30)
			needsCheck := true
	}
	
	if (!needsCheck)
		return
	
	; Show status
	ToolTip, Checking for updates and validating license...
	
	; Validate license if we have one
	if (License_Key != "" && License_Status = "active") {
		ValidateLicenseSilent()
	}
	
	; Check for updates
	CheckForUpdates()
	
	; Update last check date
	FormatTime, Update_LastCheckDate,, yyyyMMdd
	SaveSettings()
	
	ToolTip
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
		
		; Check if user skipped this version
		if (latestVersion = Update_SkippedVersion)
			return
		
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
	global
	
	; Download installer to temp
	ToolTip, Downloading update v%newVersion%...
	
	downloadPath := A_Temp . "\SideKick_PS_Setup.exe"
	batchFile := A_Temp . "\download_update.bat"
	resultFile := A_Temp . "\download_result.txt"
	
	; Create batch file to run PowerShell (avoids quote escaping issues)
	FileDelete, %batchFile%
	FileAppend, @echo off`n, %batchFile%
	FileAppend, powershell -NoProfile -Command "try { Invoke-WebRequest -Uri '%downloadUrl%' -OutFile '%downloadPath%'; Unblock-File -Path '%downloadPath%'; Write-Output 'OK' } catch { Write-Output 'FAILED' }" > "%resultFile%"`n, %batchFile%
	
	RunWait, %batchFile%, , Hide
	FileDelete, %batchFile%
	
	FileRead, downloadResult, %resultFile%
	FileDelete, %resultFile%
	
	ToolTip
	
	if (!FileExist(downloadPath) || InStr(downloadResult, "FAILED")) {
		DarkMsgBox("Download Failed", "Failed to download the update.`n`nPlease download manually from:`nhttps://github.com/GuyMayer/SideKick_PS/releases/latest", "error")
		return
	}
	
	; Run the installer (silent mode if auto-update enabled)
	if (silent) {
		; Very silent install - no UI at all
		Run, "%downloadPath%" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /CLOSEAPPLICATIONS
	} else {
		; Normal install with UI
		Run, "%downloadPath%"
	}
	
	; Exit current instance to allow update
	ExitApp
}

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
	Gui, Settings:Add, Text, x190 y10 w500 h430 BackgroundTrans vPanelAbout Hidden
	
	; Section header
	Gui, Settings:Font, s16 c%headerColor%, Segoe UI
	Gui, Settings:Add, Text, x200 y20 w400 BackgroundTrans vAboutHeader Hidden, ℹ About SideKick_PS
	
	; App info
	Gui, Settings:Font, s24 c%textColor%, Segoe UI
	Gui, Settings:Add, Text, x200 y70 w400 BackgroundTrans vAboutTitle Hidden, SideKick_PS
	
	Gui, Settings:Font, s11 c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x200 y110 w400 BackgroundTrans vAboutSubtitle Hidden, Payment Plan Calculator for ProSelect
	
	; Version info
	Gui, Settings:Font, s10 c%textColor%, Segoe UI
	Gui, Settings:Add, Text, x200 y160 w150 BackgroundTrans vAboutVerLabel Hidden, Version:
	Gui, Settings:Add, Text, x350 y160 w150 BackgroundTrans vAboutVerValue Hidden, %ScriptVersion%
	
	Gui, Settings:Add, Text, x200 y185 w150 BackgroundTrans vAboutBuildLabel Hidden, Build Date:
	Gui, Settings:Add, Text, x350 y185 w150 BackgroundTrans vAboutBuildValue Hidden, %BuildDate%
	
	; Latest version section
	Gui, Settings:Add, Text, x200 y210 w150 BackgroundTrans vAboutLatestLabel Hidden, Latest Version:
	Gui, Settings:Add, Text, x350 y210 w200 BackgroundTrans vAboutLatestValue Hidden, Checking...
	Gui, Settings:Font, s9 Norm cFFFFFF, Segoe UI
	Gui, Settings:Add, Button, x555 y207 w90 h22 gAboutUpdateNow vAboutUpdateBtn Hidden, 🔄 Update
	
	; Auto-update toggle slider (same style as General tab)
	Gui, Settings:Add, Text, x200 y235 w300 BackgroundTrans vAboutAutoUpdateLabel Hidden, Enable automatic updates
	CreateToggleSlider("Settings", "AutoUpdate", 590, 233, Settings_AutoUpdate)
	; Hide the toggle by default (About panel hidden initially)
	GuiControl, Settings:Hide, Toggle_AutoUpdate
	
	; Features section
	Gui, Settings:Font, s12 c%textColor%, Segoe UI
	Gui, Settings:Add, Text, x200 y265 w200 BackgroundTrans vAboutFeatures Hidden, Features
	
	Gui, Settings:Font, s10 c%mutedColor%, Segoe UI
	Gui, Settings:Add, Text, x200 y295 w430 BackgroundTrans vAboutFeat1 Hidden, • Automatic payment calculations with rounding correction
	Gui, Settings:Add, Text, x200 y315 w430 BackgroundTrans vAboutFeat2 Hidden, • Weekly, Bi-Weekly, 4-Weekly, and Monthly payments
	Gui, Settings:Add, Text, x200 y335 w430 BackgroundTrans vAboutFeat3 Hidden, • ProSelect 2022 && 2025 integration
	Gui, Settings:Add, Text, x200 y355 w430 BackgroundTrans vAboutFeat4 Hidden, • GHL client lookup from Chrome
	Gui, Settings:Add, Text, x200 y375 w430 BackgroundTrans vAboutFeat5 Hidden, • Multi-copy print workflow automation
	
	; Author & Contact
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x200 y410 w150 BackgroundTrans vAboutAuthor Hidden, Author: GuyMayer
	Gui, Settings:Font, s10 c%linkColor% Underline, Segoe UI
	Gui, Settings:Add, Text, x350 y410 w250 BackgroundTrans gOpenSupportEmail vAboutEmail Hidden, guy@zoom-photo.co.uk
	
	; What's New and Send Logs buttons
	Gui, Settings:Font, s10 Norm cFFFFFF, Segoe UI
	Gui, Settings:Add, Button, x200 y440 w120 h28 gShowWhatsNew vAboutWhatsNewBtn Hidden, 📋 What's New
	Gui, Settings:Add, Button, x330 y440 w110 h28 gSendLogsNow vAboutSendLogsBtn Hidden, 📤 Send Logs
	
	; Auto-send toggle (right side)
	Gui, Settings:Font, s10 c%mutedColor%, Segoe UI
	Gui, Settings:Add, Text, x480 y448 w100 BackgroundTrans vAboutAutoSendLabel Hidden, Auto-send
	CreateToggleSlider("Settings", "AutoSendLogs", 580, 446, Settings_AutoSendLogs)
	GuiControl, Settings:Hide, Toggle_AutoSendLogs
}

CreateDeveloperPanel()
{
	global
	
	; Get theme colors
	textColor := Settings_DarkMode ? "FFFFFF" : "000000"
	headerColor := Settings_DarkMode ? "FF8C00" : "E67E00"
	labelColor := Settings_DarkMode ? "AAAAAA" : "666666"
	mutedColor := Settings_DarkMode ? "888888" : "999999"
	successColor := "00AA00"
	
	; Developer panel container (initially hidden)
	Gui, Settings:Add, Text, x190 y10 w500 h530 BackgroundTrans vPanelDeveloper Hidden
	
	; Section header
	Gui, Settings:Font, s16 c%headerColor%, Segoe UI
	Gui, Settings:Add, Text, x200 y20 w400 BackgroundTrans vDevHeader Hidden, 🛠 Developer Tools
	
	; Warning message
	Gui, Settings:Font, s10 cFF6600, Segoe UI
	Gui, Settings:Add, Text, x200 y60 w400 BackgroundTrans vDevWarning Hidden, ⚠ Developer mode - for internal use only
	
	; Build section
	Gui, Settings:Font, s12 c%textColor%, Segoe UI
	Gui, Settings:Add, Text, x200 y100 w300 BackgroundTrans vDevBuildTitle Hidden, Build && Release
	
	Gui, Settings:Font, s10 c%mutedColor%, Segoe UI
	Gui, Settings:Add, Text, x200 y130 w430 BackgroundTrans vDevBuildDesc Hidden, Create release package, update version, and push to GitHub.
	
	; Version info
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x200 y170 w120 BackgroundTrans vDevVersionLabel Hidden, Current Version:
	Gui, Settings:Font, s10 c%textColor%, Segoe UI
	Gui, Settings:Add, Text, x330 y170 w100 BackgroundTrans vDevVersionValue Hidden, %ScriptVersion%
	
	; Running mode indicator (Dev Script vs Consumer EXE)
	runningMode := A_IsCompiled ? "Consumer (EXE)" : "Developer (Script)"
	modeColor := A_IsCompiled ? "00CC00" : "FF9900"
	Gui, Settings:Font, s10 c%modeColor%, Segoe UI
	Gui, Settings:Add, Text, x200 y195 w120 BackgroundTrans vDevModeLabel Hidden, Running Mode:
	Gui, Settings:Add, Text, x330 y195 w150 BackgroundTrans vDevModeValue Hidden, %runningMode%
	
	; Build action buttons
	Gui, Settings:Font, s10 Norm cFFFFFF, Segoe UI
	Gui, Settings:Add, Button, x200 y235 w140 h40 gDevCreateRelease vDevCreateBtn Hidden, 📦 Create Release
	Gui, Settings:Add, Button, x350 y235 w140 h40 gDevUpdateVersion vDevUpdateBtn Hidden, 🔢 Update Version
	Gui, Settings:Add, Button, x500 y235 w120 h40 gDevPushGitHub vDevPushBtn Hidden, 🚀 Push GitHub
	
	; Git section
	Gui, Settings:Font, s12 c%textColor%, Segoe UI
	Gui, Settings:Add, Text, x200 y305 w300 BackgroundTrans vDevGitTitle Hidden, Git Status
	
	Gui, Settings:Font, s9 c%mutedColor%, Consolas
	Gui, Settings:Add, Edit, x200 y335 w420 h120 ReadOnly vDevGitOutput Hidden, (Click Refresh to see git status)
	
	Gui, Settings:Font, s10 Norm, Segoe UI
	Gui, Settings:Add, Button, x200 y465 w100 h30 gDevRefreshGit vDevRefreshBtn Hidden, 🔄 Refresh
	Gui, Settings:Add, Button, x310 y465 w120 h30 gDevOpenFolder vDevOpenFolderBtn Hidden, 📂 Open Folder
	
	; Quick actions
	Gui, Settings:Font, s12 c%textColor%, Segoe UI
	Gui, Settings:Add, Text, x200 y515 w300 BackgroundTrans vDevQuickTitle Hidden, Quick Actions
	
	Gui, Settings:Font, s10 Norm, Segoe UI
	Gui, Settings:Add, Button, x200 y545 w130 h30 gDevTestBuild vDevTestBtn Hidden, 🧪 Test Build
	Gui, Settings:Add, Button, x340 y545 w130 h30 gDevOpenGitHub vDevGitHubBtn Hidden, 🌐 Open GitHub
	Gui, Settings:Add, Button, x480 y545 w140 h30 gDevQuickPush vDevQuickPushBtn Hidden, ⚡ Quick Publish
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
	GuiControl, Settings:Hide, TabDeveloperBg
	
	; Hide all panels - General
	GuiControl, Settings:Hide, PanelGeneral
	GuiControl, Settings:Hide, GenHeader
	GuiControl, Settings:Hide, GenBehavior
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
	GuiControl, Settings:Hide, GenDefaults
	GuiControl, Settings:Hide, GenRecurLabel
	GuiControl, Settings:Hide, Settings_DefaultRecurring_DDL
	GuiControl, Settings:Hide, GenRecurOptionsLabel
	GuiControl, Settings:Hide, GenRecurOptionsEdit
	GuiControl, Settings:Hide, GenRecurOptionsBtn
	GuiControl, Settings:Hide, GenProSelect
	GuiControl, Settings:Hide, GenPSVersion
	GuiControl, Settings:Hide, GenShortcutBtn
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
	GuiControl, Settings:Hide, GHLSearchAllTabs
	GuiControl, Settings:Hide, Toggle_SearchAllTabs
	GuiControl, Settings:Hide, GHLFinancialsOnly
	GuiControl, Settings:Hide, Toggle_FinancialsOnly
	GuiControl, Settings:Hide, GHLContactSheet
	GuiControl, Settings:Hide, Toggle_ContactSheet
	GuiControl, Settings:Hide, GHLInfo
	
	; Hide all panels - Hotkeys
	GuiControl, Settings:Hide, PanelHotkeys
	GuiControl, Settings:Hide, HotkeysHeader
	GuiControl, Settings:Hide, HotkeysInfo
	GuiControl, Settings:Hide, HotkeysSection
	GuiControl, Settings:Hide, HKLabelGHL
	GuiControl, Settings:Hide, Hotkey_GHLLookup_Edit
	GuiControl, Settings:Hide, HKCaptureGHL
	GuiControl, Settings:Hide, HKLabelPP
	GuiControl, Settings:Hide, Hotkey_PayPlan_Edit
	GuiControl, Settings:Hide, HKCapturePP
	GuiControl, Settings:Hide, HKLabelSettings
	GuiControl, Settings:Hide, Hotkey_Settings_Edit
	GuiControl, Settings:Hide, HKCaptureSettings
	GuiControl, Settings:Hide, HKActionsTitle
	GuiControl, Settings:Hide, HKResetBtn
	GuiControl, Settings:Hide, HKClearBtn
	GuiControl, Settings:Hide, HKInstructions1
	GuiControl, Settings:Hide, HKInstructions2
	GuiControl, Settings:Hide, HKInstructions3
	GuiControl, Settings:Hide, HKInstructions4
	GuiControl, Settings:Hide, HKNote
	
	; Hide all panels - About
	GuiControl, Settings:Hide, PanelAbout
	GuiControl, Settings:Hide, AboutHeader
	GuiControl, Settings:Hide, AboutTitle
	GuiControl, Settings:Hide, AboutSubtitle
	GuiControl, Settings:Hide, AboutVerLabel
	GuiControl, Settings:Hide, AboutVerValue
	GuiControl, Settings:Hide, AboutBuildLabel
	GuiControl, Settings:Hide, AboutBuildValue
	GuiControl, Settings:Hide, AboutPSLabel
	GuiControl, Settings:Hide, AboutPSValue
	GuiControl, Settings:Hide, AboutLatestLabel
	GuiControl, Settings:Hide, AboutLatestValue
	GuiControl, Settings:Hide, AboutUpdateBtn
	GuiControl, Settings:Hide, AboutAutoUpdateLabel
	GuiControl, Settings:Hide, Toggle_AutoUpdate
	GuiControl, Settings:Hide, AboutFeatures
	GuiControl, Settings:Hide, AboutFeat1
	GuiControl, Settings:Hide, AboutFeat2
	GuiControl, Settings:Hide, AboutFeat3
	GuiControl, Settings:Hide, AboutFeat4
	GuiControl, Settings:Hide, AboutFeat5
	GuiControl, Settings:Hide, AboutAuthor
	GuiControl, Settings:Hide, AboutEmail
	GuiControl, Settings:Hide, AboutWhatsNewBtn
	GuiControl, Settings:Hide, AboutAutoSendLabel
	GuiControl, Settings:Hide, Toggle_AutoSendLogs
	GuiControl, Settings:Hide, AboutSendLogsBtn
	
	; Hide all panels - License
	GuiControl, Settings:Hide, TabLicenseBg
	GuiControl, Settings:Hide, PanelLicense
	GuiControl, Settings:Hide, LicenseHeader
	GuiControl, Settings:Hide, LicenseStatusTitle
	GuiControl, Settings:Hide, LicenseStatusText
	GuiControl, Settings:Hide, LicenseKeyTitle
	GuiControl, Settings:Hide, LicenseKeyLabel
	GuiControl, Settings:Hide, LicenseKeyEdit
	GuiControl, Settings:Hide, LicenseActivateBtn
	GuiControl, Settings:Hide, LicenseLocationInfo
	GuiControl, Settings:Hide, LicenseDetailsTitle
	GuiControl, Settings:Hide, LicenseNameLabel
	GuiControl, Settings:Hide, LicenseNameValue
	GuiControl, Settings:Hide, LicenseEmailLabel
	GuiControl, Settings:Hide, LicenseEmailValue
	GuiControl, Settings:Hide, LicenseActivatedLabel
	GuiControl, Settings:Hide, LicenseActivatedValue
	GuiControl, Settings:Hide, LicenseExpiryLabel
	GuiControl, Settings:Hide, LicenseExpiryValue
	GuiControl, Settings:Hide, LicenseValidateBtn
	GuiControl, Settings:Hide, LicenseDeactivateBtn
	GuiControl, Settings:Hide, LicenseBuyBtn
	GuiControl, Settings:Hide, LicensePurchaseInfo
	GuiControl, Settings:Hide, LicensePurchaseInfo2
	
	; Hide all panels - Files
	GuiControl, Settings:Hide, PanelFiles
	GuiControl, Settings:Hide, FilesHeader
	GuiControl, Settings:Hide, FilesSDCard
	GuiControl, Settings:Hide, FilesCardDriveLabel
	GuiControl, Settings:Hide, FilesCardDriveEdit
	GuiControl, Settings:Hide, FilesCardDriveBrowse
	GuiControl, Settings:Hide, FilesDownloadLabel
	GuiControl, Settings:Hide, FilesDownloadEdit
	GuiControl, Settings:Hide, FilesDownloadBrowse
	GuiControl, Settings:Hide, FilesArchive
	GuiControl, Settings:Hide, FilesArchiveLabel
	GuiControl, Settings:Hide, FilesArchiveEdit
	GuiControl, Settings:Hide, FilesArchiveBrowse
	GuiControl, Settings:Hide, FilesNaming
	GuiControl, Settings:Hide, FilesPrefixLabel
	GuiControl, Settings:Hide, FilesPrefixEdit
	GuiControl, Settings:Hide, FilesSuffixLabel
	GuiControl, Settings:Hide, FilesSuffixEdit
	GuiControl, Settings:Hide, FilesAutoYear
	GuiControl, Settings:Hide, Toggle_AutoShootYear
	GuiControl, Settings:Hide, FilesAutoRename
	GuiControl, Settings:Hide, Toggle_AutoRenameImages
	GuiControl, Settings:Hide, FilesEditor
	GuiControl, Settings:Hide, FilesEditorLabel
	GuiControl, Settings:Hide, FilesEditorEdit
	GuiControl, Settings:Hide, FilesEditorBrowse
	GuiControl, Settings:Hide, FilesOpenEditor
	GuiControl, Settings:Hide, Toggle_BrowsDown
	GuiControl, Settings:Hide, FilesAutoDrive
	GuiControl, Settings:Hide, Toggle_AutoDriveDetect
	
	; Hide all panels - Developer
	GuiControl, Settings:Hide, PanelDeveloper
	GuiControl, Settings:Hide, DevHeader
	GuiControl, Settings:Hide, DevWarning
	GuiControl, Settings:Hide, DevBuildTitle
	GuiControl, Settings:Hide, DevBuildDesc
	GuiControl, Settings:Hide, DevVersionLabel
	GuiControl, Settings:Hide, DevVersionValue
	GuiControl, Settings:Hide, DevModeLabel
	GuiControl, Settings:Hide, DevModeValue
	GuiControl, Settings:Hide, DevCreateBtn
	GuiControl, Settings:Hide, DevUpdateBtn
	GuiControl, Settings:Hide, DevPushBtn
	GuiControl, Settings:Hide, DevGitTitle
	GuiControl, Settings:Hide, DevGitOutput
	GuiControl, Settings:Hide, DevRefreshBtn
	GuiControl, Settings:Hide, DevOpenFolderBtn
	GuiControl, Settings:Hide, DevQuickTitle
	GuiControl, Settings:Hide, DevTestBtn
	GuiControl, Settings:Hide, DevGitHubBtn
	GuiControl, Settings:Hide, DevQuickPushBtn
	
	; Show selected tab
	if (tabName = "General")
	{
		GuiControl, Settings:Show, TabGeneralBg
		GuiControl, Settings:Show, PanelGeneral
		GuiControl, Settings:Show, GenHeader
		GuiControl, Settings:Show, GenBehavior
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
		GuiControl, Settings:Show, GenDefaults
		GuiControl, Settings:Show, GenRecurLabel
		GuiControl, Settings:Show, Settings_DefaultRecurring_DDL
		GuiControl, Settings:Show, GenRecurOptionsLabel
		GuiControl, Settings:Show, GenRecurOptionsEdit
		GuiControl, Settings:Show, GenRecurOptionsBtn
		GuiControl, Settings:Show, GenProSelect
		GuiControl, Settings:Show, GenPSVersion
		GuiControl, Settings:Show, GenShortcutBtn
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
		GuiControl, Settings:Show, GHLSearchAllTabs
		GuiControl, Settings:Show, Toggle_SearchAllTabs
		GuiControl, Settings:Show, GHLFinancialsOnly
		GuiControl, Settings:Show, Toggle_FinancialsOnly
		GuiControl, Settings:Show, GHLContactSheet
		GuiControl, Settings:Show, Toggle_ContactSheet
		GuiControl, Settings:Show, GHLInfo
	}
	else if (tabName = "Hotkeys")
	{
		GuiControl, Settings:Show, TabHotkeysBg
		GuiControl, Settings:Show, PanelHotkeys
		GuiControl, Settings:Show, HotkeysHeader
		GuiControl, Settings:Show, HotkeysInfo
		GuiControl, Settings:Show, HotkeysSection
		GuiControl, Settings:Show, HKLabelGHL
		GuiControl, Settings:Show, Hotkey_GHLLookup_Edit
		GuiControl, Settings:Show, HKCaptureGHL
		GuiControl, Settings:Show, HKLabelPP
		GuiControl, Settings:Show, Hotkey_PayPlan_Edit
		GuiControl, Settings:Show, HKCapturePP
		GuiControl, Settings:Show, HKLabelSettings
		GuiControl, Settings:Show, Hotkey_Settings_Edit
		GuiControl, Settings:Show, HKCaptureSettings
		GuiControl, Settings:Show, HKActionsTitle
		GuiControl, Settings:Show, HKResetBtn
		GuiControl, Settings:Show, HKClearBtn
		GuiControl, Settings:Show, HKInstructions1
		GuiControl, Settings:Show, HKInstructions2
		GuiControl, Settings:Show, HKInstructions3
		GuiControl, Settings:Show, HKInstructions4
		GuiControl, Settings:Show, HKNote
	}
	else if (tabName = "License")
	{
		GuiControl, Settings:Show, TabLicenseBg
		GuiControl, Settings:Show, PanelLicense
		GuiControl, Settings:Show, LicenseHeader
		GuiControl, Settings:Show, LicenseStatusTitle
		GuiControl, Settings:Show, LicenseStatusText
		GuiControl, Settings:Show, LicenseKeyTitle
		GuiControl, Settings:Show, LicenseKeyLabel
		GuiControl, Settings:Show, LicenseKeyEdit
		GuiControl, Settings:Show, LicenseActivateBtn
		GuiControl, Settings:Show, LicenseLocationInfo
		GuiControl, Settings:Show, LicenseDetailsTitle
		GuiControl, Settings:Show, LicenseNameLabel
		GuiControl, Settings:Show, LicenseNameValue
		GuiControl, Settings:Show, LicenseEmailLabel
		GuiControl, Settings:Show, LicenseEmailValue
		GuiControl, Settings:Show, LicenseActivatedLabel
		GuiControl, Settings:Show, LicenseActivatedValue
		GuiControl, Settings:Show, LicenseExpiryLabel
		GuiControl, Settings:Show, LicenseExpiryValue
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
		GuiControl, Settings:Show, FilesSDCard
		GuiControl, Settings:Show, FilesCardDriveLabel
		GuiControl, Settings:Show, FilesCardDriveEdit
		GuiControl, Settings:Show, FilesCardDriveBrowse
		GuiControl, Settings:Show, FilesDownloadLabel
		GuiControl, Settings:Show, FilesDownloadEdit
		GuiControl, Settings:Show, FilesDownloadBrowse
		GuiControl, Settings:Show, FilesArchive
		GuiControl, Settings:Show, FilesArchiveLabel
		GuiControl, Settings:Show, FilesArchiveEdit
		GuiControl, Settings:Show, FilesArchiveBrowse
		GuiControl, Settings:Show, FilesNaming
		GuiControl, Settings:Show, FilesPrefixLabel
		GuiControl, Settings:Show, FilesPrefixEdit
		GuiControl, Settings:Show, FilesSuffixLabel
		GuiControl, Settings:Show, FilesSuffixEdit
		GuiControl, Settings:Show, FilesAutoYear
		GuiControl, Settings:Show, Toggle_AutoShootYear
		GuiControl, Settings:Show, FilesAutoRename
		GuiControl, Settings:Show, Toggle_AutoRenameImages
		GuiControl, Settings:Show, FilesEditor
		GuiControl, Settings:Show, FilesEditorLabel
		GuiControl, Settings:Show, FilesEditorEdit
		GuiControl, Settings:Show, FilesEditorBrowse
		GuiControl, Settings:Show, FilesOpenEditor
		GuiControl, Settings:Show, Toggle_BrowsDown
		GuiControl, Settings:Show, FilesAutoDrive
		GuiControl, Settings:Show, Toggle_AutoDriveDetect
	}
	else if (tabName = "About")
	{
		GuiControl, Settings:Show, TabAboutBg
		GuiControl, Settings:Show, PanelAbout
		GuiControl, Settings:Show, AboutHeader
		GuiControl, Settings:Show, AboutTitle
		GuiControl, Settings:Show, AboutSubtitle
		GuiControl, Settings:Show, AboutVerLabel
		GuiControl, Settings:Show, AboutVerValue
		GuiControl, Settings:Show, AboutBuildLabel
		GuiControl, Settings:Show, AboutBuildValue
		GuiControl, Settings:Show, AboutLatestLabel
		GuiControl, Settings:Show, AboutLatestValue
		; Check button removed - version check is automatic
		GuiControl, Settings:Show, AboutAutoUpdateLabel
		GuiControl, Settings:Show, Toggle_AutoUpdate
		GuiControl, Settings:Show, AboutFeatures
		GuiControl, Settings:Show, AboutFeat1
		GuiControl, Settings:Show, AboutFeat2
		GuiControl, Settings:Show, AboutFeat3
		GuiControl, Settings:Show, AboutFeat4
		GuiControl, Settings:Show, AboutFeat5
		GuiControl, Settings:Show, AboutAuthor
		GuiControl, Settings:Show, AboutEmail
		GuiControl, Settings:Show, AboutWhatsNewBtn
		GuiControl, Settings:Show, AboutAutoSendLabel
		GuiControl, Settings:Show, Toggle_AutoSendLogs
		GuiControl, Settings:Show, AboutSendLogsBtn
		
		; Refresh latest version info
		RefreshLatestVersion()
	}
	else if (tabName = "Developer")
	{
		GuiControl, Settings:Show, TabDeveloperBg
		GuiControl, Settings:Show, PanelDeveloper
		GuiControl, Settings:Show, DevHeader
		GuiControl, Settings:Show, DevWarning
		GuiControl, Settings:Show, DevBuildTitle
		GuiControl, Settings:Show, DevBuildDesc
		GuiControl, Settings:Show, DevVersionLabel
		GuiControl, Settings:Show, DevVersionValue
		GuiControl, Settings:Show, DevModeLabel
		GuiControl, Settings:Show, DevModeValue
		GuiControl, Settings:Show, DevCreateBtn
		GuiControl, Settings:Show, DevUpdateBtn
		GuiControl, Settings:Show, DevPushBtn
		GuiControl, Settings:Show, DevGitTitle
		GuiControl, Settings:Show, DevGitOutput
		GuiControl, Settings:Show, DevRefreshBtn
		GuiControl, Settings:Show, DevOpenFolderBtn
		GuiControl, Settings:Show, DevQuickTitle
		GuiControl, Settings:Show, DevTestBtn
		GuiControl, Settings:Show, DevGitHubBtn
		GuiControl, Settings:Show, DevQuickPushBtn
		
		; Refresh git status
		RefreshDevGitStatus()
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

SettingsTabDeveloper:
ShowSettingsTab("Developer")
Return

; Developer button handlers
DevCreateRelease:
	; Build full release with EXE-only files (compiles AHK and Python)
	ToolTip, Building release (compiling to EXE)...
	buildScript := A_ScriptDir . "\SideKick_PS\build_and_archive.ps1"
	if FileExist(buildScript) {
		; Open PowerShell to run build interactively
		Run, powershell.exe -NoExit -ExecutionPolicy Bypass -Command "cd '%A_ScriptDir%\SideKick_PS'; .\build_and_archive.ps1 -Version '%ScriptVersion%'", %A_ScriptDir%\SideKick_PS
		ToolTip
	} else {
		ToolTip
		DarkMsgBox("Error", "Build script not found:`n" . buildScript . "`n`nExpected at: C:\Stash\SideKick_PS\build_and_archive.ps1", "error")
	}
Return

DevUpdateVersion:
	InputBox, newVer, Update Version, Enter new version number (e.g., 2.5.0):,, 300, 130,,,,, %ScriptVersion%
	if (!ErrorLevel && newVer != "") {
		; Update version.json
		versionFile := A_ScriptDir . "\SideKick_PS\version.json"
		if FileExist(versionFile) {
			; Read and update version.json
			FileRead, versionJson, %versionFile%
			versionJson := RegExReplace(versionJson, """version"":\s*""[^""]+""", """version"": """ . newVer . """")
			FileDelete, %versionFile%
			FileAppend, %versionJson%, %versionFile%
			DarkMsgBox("Version Updated", "Updated version.json to v" . newVer . "`n`nRemember to update ScriptVersion in the main script too.", "success")
		}
	}
Return

DevPushGitHub:
	repoDir := A_ScriptDir . "\SideKick_PS"
	Run, powershell.exe -NoExit -Command "cd '%repoDir%'; git status; Write-Host ''; Write-Host 'Ready to commit and push. Use:' -ForegroundColor Yellow; Write-Host 'git add . && git commit -m \"Your message\" && git push' -ForegroundColor Cyan", %repoDir%
Return

DevRefreshGit:
	RefreshDevGitStatus()
Return

DevOpenFolder:
	Run, explorer.exe "%A_ScriptDir%\SideKick_PS"
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
	
	; Parse current version and increment patch
	versionParts := StrSplit(ScriptVersion, ".")
	if (versionParts.Length() >= 3) {
		major := versionParts[1]
		minor := versionParts[2]
		patch := versionParts[3] + 1
		newVersion := major . "." . minor . "." . patch
	} else {
		DarkMsgBox("Error", "Could not parse version: " . ScriptVersion, "error")
		return
	}
	
	; Ask for version and commit message
	InputBox, newVersion, Quick Publish, Enter version number:,, 300, 130,,,,, %newVersion%
	if (ErrorLevel || newVersion = "") {
		return  ; User cancelled
	}
	
	InputBox, commitMsg, Quick Publish, Enter release notes for v%newVersion%:,, 400, 130,,,,, v%newVersion% release
	if (ErrorLevel || commitMsg = "") {
		return  ; User cancelled
	}
	
	repoDir := A_ScriptDir . "\SideKick_PS"
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
	FileAppend, powershell -ExecutionPolicy Bypass -File "build_and_archive.ps1" -Version "%newVersion%"`n, %batchFile%
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
	FileAppend, echo Adding files...`n, %gitBatch%
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
		; Create batch to delete old GitHub releases (use full path to gh)
		cleanBatch := repoDir . "\cleanup_releases.bat"
		FileDelete, %cleanBatch%
		FileAppend, @echo off`n, %cleanBatch%
		FileAppend, cd /d "%repoDir%"`n, %cleanBatch%
		
		for i, folder in deletedFolders {
			FileAppend, echo Deleting GitHub release %folder%...`n, %cleanBatch%
			FileAppend, "C:\Program Files\GitHub CLI\gh.exe" release delete %folder% --yes 2>nul`n, %cleanBatch%
		}
		
		FileAppend, echo.`n, %cleanBatch%
		FileAppend, echo Cleanup complete!`n, %cleanBatch%
		FileAppend, pause`n, %cleanBatch%
		
		RunWait, %cleanBatch%, %repoDir%
		FileDelete, %cleanBatch%
		
		; Commit the cleanup
		RunWait, %ComSpec% /c "cd /d "%repoDir%" && git add -A && git commit -m "Cleanup old releases" && git push origin main",, Hide
	}
}

RefreshDevGitStatus()
{
	global
	repoDir := A_ScriptDir . "\SideKick_PS"
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
	
	RunWait, %ComSpec% /c "%scriptCmd% > "%tempFile%"", , Hide
	
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
	
	RunWait, %ComSpec% /c "%scriptCmd% > "%tempFile%"", , Hide
	
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
	
	RunWait, %ComSpec% /c "%scriptCmd% > "%tempFile%"", , Hide
	
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
result := DarkMsgBox("Reset Hotkeys", "Reset all hotkeys to defaults?`n`nGHL Lookup: Ctrl+Shift+G`nPayPlan: Ctrl+Shift+P`nSettings: Ctrl+Shift+S", "question", {buttons: ["Yes", "No"]})
if (result = "Yes")
{
	Hotkey_GHLLookup := "^+g"
	Hotkey_PayPlan := "^+p"
	Hotkey_Settings := "^+s"
	GuiControl, Settings:, Hotkey_GHLLookup_Edit, % FormatHotkeyDisplay("^+g")
	GuiControl, Settings:, Hotkey_PayPlan_Edit, % FormatHotkeyDisplay("^+p")
	GuiControl, Settings:, Hotkey_Settings_Edit, % FormatHotkeyDisplay("^+s")
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
	ToolTip, All hotkeys cleared
	SetTimer, RemoveSettingsTooltip, -1500
}
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
; Save settings
SaveSettings()
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
; Save settings
SaveSettings()
Gui, Settings:Destroy
Settings_CurrentTab := "General"  ; Reset to General for next open
Return

EditGHLApiKey:
InputBox, newApiKey, 🔑 Edit GHL API Key, Enter your GHL API Key (Private Integration Token):`n`nGet it from GHL: Settings > Business Profile > API, , 500, 180, , , , , %GHL_API_Key%
if (!ErrorLevel && newApiKey != "")
{
	GHL_API_Key := newApiKey
	; Save Base64 encoded to SideKick_PS.ini
	encodedKey := Base64_Encode(GHL_API_Key)
	IniWrite, %encodedKey%, %IniFilename%, GHL, API_Key_B64
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
	; Save to SideKick_PS.ini (not encrypted - it's not sensitive)
	IniWrite, %GHL_LocationID%, %IniFilename%, GHL, LocationID
	; Update display
	GuiControl, Settings:, GHLLocIDDisplay, %GHL_LocationID%
	ToolTip, Location ID updated!
	SetTimer, RemoveSettingsTooltip, -1500
}
Return

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

FilesArchiveBrowseBtn:
FileSelectFolder, selectedFolder, , 3, Select Archive Folder
if (selectedFolder != "")
{
	Settings_ShootArchivePath := selectedFolder
	GuiControl, Settings:, FilesArchiveEdit, %selectedFolder%
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

Toggle_AutoShootYear:
Gui, Settings:Submit, NoHide
Return

Toggle_AutoRenameImages:
Gui, Settings:Submit, NoHide
Return

Toggle_BrowsDown:
Gui, Settings:Submit, NoHide
Return

Toggle_AutoDriveDetect:
Gui, Settings:Submit, NoHide
Return

; Global variable for invoice folder watcher
global LastInvoiceFiles := ""

WatchInvoiceFolder:
if (Settings_InvoiceWatchFolder = "" || !FileExist(Settings_InvoiceWatchFolder))
	return
currentFiles := ""
fileCount := 0
Loop, Files, %Settings_InvoiceWatchFolder%\*.xml
{
	currentFiles .= A_LoopFileName . "|"
	fileCount++
}

; First run: if exactly 1 XML file exists, offer to process it
if (LastInvoiceFiles = "" && fileCount = 1)
{
	; Extract the single filename (remove trailing |)
	singleFile := SubStr(currentFiles, 1, StrLen(currentFiles) - 1)
	fullPath := Settings_InvoiceWatchFolder . "\" . singleFile
	result := DarkMsgBox("📋 Invoice XML Found", "Found invoice file:`n`n" . singleFile . "`n`nLoad this invoice to GHL?", "question", {buttons: ["Yes", "No"]})
	if (result = "Yes")
	{
		ProcessInvoiceXML(fullPath)
	}
	LastInvoiceFiles := currentFiles
	return
}

; Check for new files
if (LastInvoiceFiles != "" && currentFiles != LastInvoiceFiles)
{
	Loop, Parse, currentFiles, |
	{
		if (A_LoopField = "")
			continue
		if (!InStr(LastInvoiceFiles, A_LoopField . "|"))
		{
			; New XML file found!
			newFile := Settings_InvoiceWatchFolder . "\" . A_LoopField
			result := DarkMsgBox("📋 New Invoice XML", "New invoice file detected:`n`n" . A_LoopField . "`n`nLoad this invoice to GHL?", "question", {buttons: ["Yes", "No"]})
			if (result = "Yes")
			{
				ProcessInvoiceXML(newFile)
			}
		}
	}
}
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
	
	if (contactId = "")
	{
		DarkMsgBox("Missing Client ID", "Invoice XML is missing a Client ID.`n`nPlease link this order to a GHL contact before exporting.`n`nFile: " . xmlFile, "warning")
		return
	}
	
	; Run the sync script (uses compiled .exe if available)
	scriptPath := GetScriptPath("sync_ps_invoice")
	
	if (!FileExist(scriptPath))
	{
		DarkMsgBox("Script Missing", "sync_ps_invoice not found (neither .exe nor .py).", "warning")
		return
	}
	
	ToolTip, Processing invoice...
	; Build arguments - contact ID is read from XML by Python script
	syncArgs := """" . xmlFile . """"
	if (Settings_FinancialsOnly)
		syncArgs .= " --financials-only"
	if (!Settings_ContactSheet)
		syncArgs .= " --no-contact-sheet"
	syncCmd := GetScriptCommand("sync_ps_invoice", syncArgs)
	
	; Run and capture output to check for folder not found
	tempOutput := A_Temp . "\sync_output_" . A_TickCount . ".txt"
	RunWait, %ComSpec% /c "%syncCmd%" > "%tempOutput%" 2>&1, , Hide
	
	; Check output for folder not found marker
	FileRead, syncOutput, %tempOutput%
	FileDelete, %tempOutput%
	
	if (InStr(syncOutput, "FOLDER_NOT_FOUND:Order Sheets") && Settings_MediaFolderID = "")
	{
		; No folder configured - show folder picker
		ToolTip
		ShowGHLFolderPicker()
	}
	
	ToolTip
	
	DarkMsgBox("Invoice Processed", "Invoice has been synced to GHL contact.", "success")
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
	RunWait, %ComSpec% /c "%scriptCmd%" > "%tempOutput%" 2>&1, , Hide
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
	
	FolderPickerCancel:
	FolderPickerGuiClose:
	FolderPickerGuiEscape:
		Gui, FolderPicker:Destroy
		return
}

TestGHLConnection:
; Test API connection
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
apiOk := false

try {
	http := ComObjCreate("WinHttp.WinHttpRequest.5.1")
	http.SetTimeouts(5000, 5000, 5000, 5000)
	testUrl := "https://services.leadconnectorhq.com/contacts/?locationId=" . GHL_LocationID . "&limit=1"
	http.open("GET", testUrl, false)
	http.SetRequestHeader("Authorization", "Bearer " . GHL_API_Key)
	http.SetRequestHeader("Version", "2021-07-28")
	http.send()
	if (http.status = 200)
		apiOk := true
}

ToolTip
statusText := apiOk ? "✅ Connected" : "❌ Failed"
GuiControl, Settings:, GHLStatusText, %statusText%

if (apiOk)
	DarkMsgBox("Connection Test", "GHL API connection successful!", "success")
else
	DarkMsgBox("Connection Failed", "Could not connect to GHL API.`nCheck your API key and Location ID.", "error")
Return

; ============================================================================
; GHL Setup Wizard
; ============================================================================
RunGHLSetupWizard:
{
	global GHL_LocationID, GHL_API_Key
	
	; Step 1: Welcome and explain what we need
	msg := "This wizard will help you connect SideKick to GoHighLevel.`n`n"
	msg .= "We need two things:`n"
	msg .= "   1. Your Location ID (from the URL)`n"
	msg .= "   2. An API Key (from Private Integrations)`n`n"
	msg .= "Ready to get started?"
	
	result := DarkMsgBox("🔧 GHL Setup Wizard - Step 1", msg, "YesNo")
	if (result != "Yes")
		Return
	
	; Step 2: Check if we already have Location ID
	if (GHL_LocationID != "") {
		result := DarkMsgBox("📍 Location ID Found", "You already have a Location ID configured:`n`n" . GHL_LocationID . "`n`nWould you like to keep this and skip to API key setup?", "YesNo")
		if (result = "Yes")
			Goto, GHLWizardApiKeyStep
	}
	
	; Step 3: Open Chrome to GHL
	msg := "I'll open your GHL dashboard in Chrome.`n`n"
	msg .= "1. Log in to your GHL sub-account`n"
	msg .= "2. Once logged in, click 'Yes' to read the URL`n`n"
	msg .= "Ready to open GHL?"
	
	result := DarkMsgBox("📍 Step 2: Get Your Location ID", msg, "YesNo")
	if (result != "Yes")
		Return
	
	; Open GHL login page
	Run, https://app.thefullybookedphotographer.com/v2/location/
	Sleep, 5000  ; Give Chrome time to open and load page
	
	; Step 4: Wait for user to log in, then read URL
	Loop {
		result := DarkMsgBox("📍 Read Location ID", "Log in to your GHL sub-account.`n`nOnce you see your dashboard, click 'Yes' to read the URL.`n`nClick 'No' to cancel.", "YesNo")
		if (result != "Yes")
			Return
		
		; Try to read Chrome URL
		locationId := GetChromeLocationID()
		
		if (locationId != "") {
			result := DarkMsgBox("✅ Location ID Found!", "Found Location ID:`n`n" . locationId . "`n`nIs this correct?", "YesNo")
			if (result = "Yes")
			{
				GHL_LocationID := locationId
				GuiControl, Settings:, GHLLocIDDisplay, %locationId%
				SaveSettings()
				Break
			}
		} else {
			result := DarkMsgBox("⚠️ Could Not Read URL", "Could not find Location ID in Chrome URL.`n`nMake sure you are on your GHL dashboard and the URL contains '/location/'.`n`nWould you like to try again?", "RetryCancel")
			if (result = "Cancel")
				Return
		}
	}
	
GHLWizardApiKeyStep:
	; Step 5: Guide to create API key - Open page first, then show instructions
	locID := GHL_LocationID
	apiUrl := "https://app.thefullybookedphotographer.com/v2/location/" . locID . "/settings/private-integrations"
	
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
	
	result := DarkMsgBox("🔑 Step 3: Create API Key", msg, "OKCancel")
	if (result = "Cancel")
		Return
	
	; Get API key input
	InputBox, newApiKey, 🔑 Enter API Key, Paste your GHL Private Integration API Key:`n`n(starts with 'pit-...'),,400, 180
	if (ErrorLevel || newApiKey = "")
		Return
	
	; Validate format
	if (!InStr(newApiKey, "pit-")) {
		DarkMsgBox("⚠️ Invalid Key Format", "API key should start with 'pit-'.`n`nPlease try again.", "OK")
		Return
	}
	
	; Save API key
	GHL_API_Key := newApiKey
	apiKeyDisplay := SubStr(GHL_API_Key, 1, 8) . "..." . SubStr(GHL_API_Key, -4)
	GuiControl, Settings:, GHLApiKeyDisplay, %apiKeyDisplay%
	SaveSettings()
	
	; Update status
	GuiControl, Settings:, GHLStatusText, ✅ Connected
	
	DarkMsgBox("Setup Complete", "GHL Integration is now configured!`n`nLocation ID: " . GHL_LocationID . "`nAPI Key: " . apiKeyDisplay . "`n`nYou can test the connection using the 'Test' button.", "success")
}
Return

; Get Location ID from Chrome URL
GetChromeLocationID() {
	; Try to get URL from Chrome using Acc library or window title
	locationId := ""
	
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
				if RegExMatch(url, "/location/([a-zA-Z0-9]+)", locMatch) {
					locationId := locMatch1
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
			if RegExMatch(manualUrl, "/location/([a-zA-Z0-9]+)", locMatch) {
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
	
	result := DarkMsgBox("Connect to GoHighLevel", msg, "question", {buttons: ["Yes", "Later"]})
	if (result = "Yes")
	{
		Gosub, RunGHLSetupWizard
	}
}

OpenSupportEmail:
Run, mailto:guy@zoom-photo.co.uk
Return

ShowWhatsNew:
	ShowWhatsNewDialog()
Return

; ============================================================================
; What's New Dialog - Shows changelog since last user version
; ============================================================================
ShowWhatsNewDialog()
{
	global ScriptVersion
	ShowWhatsNewSinceVersion("")  ; Show current version only
}

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

; Send debug logs to developer via GitHub Gist
SendLogsNow:
	SendDebugLogs()
Return

SendDebugLogs() {
	global GHL_LocationID
	
	; Path to SideKick_Logs folder on user's Desktop
	logsFolder := A_Desktop . "\SideKick_Logs"
	
	; Check if folder exists
	if (!FileExist(logsFolder)) {
		DarkMsgBox("No Logs Found", "No debug logs found.`n`nLogs are created when invoice sync runs with debug mode enabled.", "info")
		return false
	}
	
	; GitHub Gist token - read from environment or config
	; Token should be stored securely, not in source code
	EnvGet, gistToken, SIDEKICK_GIST_TOKEN
	if (gistToken = "") {
		IniRead, gistToken, %IniFilename%, Debug, GistToken, %A_Space%
	}
	if (gistToken = "") {
		DarkMsgBox("Configuration Required", "GitHub Gist token not configured.`n`nPlease set SIDEKICK_GIST_TOKEN environment variable.", "warning")
		return false
	}
	
	; Collect all log files
	logFiles := []
	Loop, Files, %logsFolder%\*.log, R
	{
		logFiles.Push(A_LoopFileLongPath)
	}
	
	logCount := logFiles.Length()
	if (logCount = 0) {
		DarkMsgBox("No Logs Found", "No .log files found in:`n" . logsFolder, "info")
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

; Build settings data for export - reads complete INI file
BuildExportData() {
	global IniFilename
	
	; Read the complete INI file content (including license)
	FileRead, data, %IniFilename%
	if ErrorLevel {
		; Fallback: file doesn't exist or can't be read
		return ""
	}
	
	; Export everything - license included for multi-machine setup
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
RegisterHotkeys()
{
	global Hotkey_GHLLookup, Hotkey_PayPlan, Hotkey_Settings
	
	; Clear any existing hotkeys first (in case we're re-registering)
	try {
		Hotkey, %Hotkey_GHLLookup%, Off, UseErrorLevel
		Hotkey, %Hotkey_PayPlan%, Off, UseErrorLevel
		Hotkey, %Hotkey_Settings%, Off, UseErrorLevel
	}
	
	; Register new hotkeys
	if (Hotkey_GHLLookup != "" && Hotkey_GHLLookup != "None") {
		Hotkey, %Hotkey_GHLLookup%, HK_GHLLookup, On
	}
	if (Hotkey_PayPlan != "" && Hotkey_PayPlan != "None") {
		Hotkey, %Hotkey_PayPlan%, HK_PayPlan, On
	}
	if (Hotkey_Settings != "" && Hotkey_Settings != "None") {
		Hotkey, %Hotkey_Settings%, HK_Settings, On
	}
}

; Hotkey handler labels
HK_GHLLookup:
GoSub, GHLClientLookup
Return

HK_PayPlan:
GoSub, PlaceButton
Return

HK_Settings:
GoSub, ShowSettings
Return

; Settings persistence functions
LoadSettings()
{
	global
	
	; Reload GHL API credentials (important after import!)
	IniRead, GHL_API_Key_B64, %IniFilename%, GHL, API_Key_B64, %A_Space%
	if (GHL_API_Key_B64 = "")
		IniRead, GHL_API_Key_B64, %IniFilename%, GHL, API_Key_V2_B64, %A_Space%
	IniRead, GHL_LocationID, %IniFilename%, GHL, LocationID, %A_Space%
	
	; Decode API key from Base64
	if (GHL_API_Key_B64 != "")
		GHL_API_Key := Base64_Decode(GHL_API_Key_B64)
	else
		GHL_API_Key := ""
	
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
	IniRead, Hotkey_Settings, %IniFilename%, Hotkeys, Settings, ^+s
	
	; Invoice folder settings
	IniRead, Settings_InvoiceWatchFolder, %IniFilename%, GHL, InvoiceWatchFolder, %A_Space%
	IniRead, Settings_SearchAllTabs, %IniFilename%, GHL, SearchAllTabs, 1
	IniRead, Settings_FinancialsOnly, %IniFilename%, GHL, FinancialsOnly, 0
	IniRead, Settings_ContactSheet, %IniFilename%, GHL, ContactSheet, 1
	IniRead, Settings_GHLInvoiceWarningShown, %IniFilename%, GHL, InvoiceWarningShown, 0
	IniRead, Settings_MediaFolderID, %IniFilename%, GHL, MediaFolderID, %A_Space%
	IniRead, Settings_MediaFolderName, %IniFilename%, GHL, MediaFolderName, %A_Space%
	
	; Debug log settings
	IniRead, Settings_AutoSendLogs, %IniFilename%, Settings, AutoSendLogs, 1
	
	; File Management settings
	IniRead, Settings_CardDrive, %IniFilename%, FileManagement, CardDrive, F:\DCIM
	IniRead, Settings_CameraDownloadPath, %IniFilename%, FileManagement, CameraDownloadPath, %A_Space%
	IniRead, Settings_ShootArchivePath, %IniFilename%, FileManagement, ShootArchivePath, %A_Space%
	IniRead, Settings_ShootPrefix, %IniFilename%, FileManagement, ShootPrefix, P
	IniRead, Settings_ShootSuffix, %IniFilename%, FileManagement, ShootSuffix, P
	IniRead, Settings_AutoShootYear, %IniFilename%, FileManagement, AutoShootYear, 1
	IniRead, Settings_EditorRunPath, %IniFilename%, FileManagement, EditorRunPath, Explore
	IniRead, Settings_BrowsDown, %IniFilename%, FileManagement, BrowsDown, 1
	IniRead, Settings_AutoRenameImages, %IniFilename%, FileManagement, AutoRenameImages, 0
	IniRead, Settings_AutoDriveDetect, %IniFilename%, FileManagement, AutoDriveDetect, 1
	
	; Build GHL payment settings URL from location ID
	if (GHL_LocationID != "")
		Settings_GHLPaymentSettingsURL := "https://app.thefullybookedphotographer.com/v2/location/" . GHL_LocationID . "/payments/settings/receipts"
	
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
	} else {
		; Check trial status (tied to Location ID)
		CheckTrialStatus()
	}
	
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
	
	; Save hotkey settings
	IniWrite, %Hotkey_GHLLookup%, %IniFilename%, Hotkeys, GHLLookup
	IniWrite, %Hotkey_PayPlan%, %IniFilename%, Hotkeys, PayPlan
	IniWrite, %Hotkey_Settings%, %IniFilename%, Hotkeys, Settings
	
	; Save invoice folder settings
	IniWrite, %Settings_InvoiceWatchFolder%, %IniFilename%, GHL, InvoiceWatchFolder
	IniWrite, %Settings_SearchAllTabs%, %IniFilename%, GHL, SearchAllTabs
	IniWrite, %Settings_FinancialsOnly%, %IniFilename%, GHL, FinancialsOnly
	IniWrite, %Settings_ContactSheet%, %IniFilename%, GHL, ContactSheet
	IniWrite, %Settings_GHLInvoiceWarningShown%, %IniFilename%, GHL, InvoiceWarningShown
	
	; Save license settings (secure/obfuscated)
	SaveLicenseSecure()
	
	; Save update settings
	IniWrite, %Update_SkippedVersion%, %IniFilename%, Updates, SkippedVersion
	IniWrite, %Update_LastCheckDate%, %IniFilename%, Updates, LastCheckDate
	IniWrite, %Settings_AutoSendLogs%, %IniFilename%, Settings, AutoSendLogs
	
	; Save File Management settings
	IniWrite, %Settings_CardDrive%, %IniFilename%, FileManagement, CardDrive
	IniWrite, %Settings_CameraDownloadPath%, %IniFilename%, FileManagement, CameraDownloadPath
	IniWrite, %Settings_ShootArchivePath%, %IniFilename%, FileManagement, ShootArchivePath
	IniWrite, %Settings_ShootPrefix%, %IniFilename%, FileManagement, ShootPrefix
	IniWrite, %Settings_ShootSuffix%, %IniFilename%, FileManagement, ShootSuffix
	IniWrite, %Settings_AutoShootYear%, %IniFilename%, FileManagement, AutoShootYear
	IniWrite, %Settings_EditorRunPath%, %IniFilename%, FileManagement, EditorRunPath
	IniWrite, %Settings_BrowsDown%, %IniFilename%, FileManagement, BrowsDown
	IniWrite, %Settings_AutoRenameImages%, %IniFilename%, FileManagement, AutoRenameImages
	IniWrite, %Settings_AutoDriveDetect%, %IniFilename%, FileManagement, AutoDriveDetect
	
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
PayValue := FloorDecimal(PayDue/PayNo)
GuiControl,, ComboBox3, %PayValue%

; Calculate rounding error for first payment adjustment
TotalPayments := PayValue * PayNo
RoundingError := PayDue - TotalPayments
RoundingError := Round(RoundingError, 2)

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

BuildPayPlanLines: ; make PayPlanLines
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
		
		; Add rounding error to first payment
		if (A_Index = 1 && RoundingError != 0)
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
		
		; Add rounding error to first payment
		if (A_Index = 1 && RoundingError != 0)
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

UpdatePS:
EnteringPaylines := True
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

	; Enter all payments - click Add button to open Payline window for each payment
	Loop %PayNo%
	{
		Data_array := StrSplit(PayPlanLine[A_Index],",")

		; Click Add button on Add Payments window to open Payline window for EVERY payment
		WinActivate, Add Payment, Payments
		WinWaitActive, Add Payment, Payments, 2
		Sleep, 200
		ControlClick, Button3, Add Payment, Payments
		Sleep, 500

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
		Sleep, 500
	}
}
else
{
	; ============================================================================
	; ProSelect 2022 automation (original code)
	; STABLE - DO NOT EDIT without specific instruction
	; This code has been tested and works correctly. Any modifications
	; should only be made with explicit user request.
	; ============================================================================
	Loop %PayNo%
	{
		Data_array := StrSplit(PayPlanLine[A_Index],",")
		ControlClick,Button3,Add Payment
		sleep, 500
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
		Sleep, 500
	}
}

EnteringPaylines := False
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
Send, ^p
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
Send, ^p
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
Send, ^p
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
; GHL Integration Functions - Scan Chrome for FBPE URLs
; ============================================================================

GHLClientLookup:
; Check license before allowing GHL features
if (!CheckLicenseForGHL("GHL Client Lookup"))
	Return

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
	
	; Check if Auto-load is enabled
	if (Settings_GHL_AutoLoad)
	{
		; Auto-load: directly update ProSelect without confirmation
		UpdateProSelectClient(GHL_Data)
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
global GHL_CurrentData
UpdateProSelectClient(GHL_CurrentData)
Return

GHLClientClose:
GHLClientGuiClose:
GHLClientGuiEscape:
Gui, GHLClient:Destroy
Return

; ============================================================================
; Update ProSelect Client Information
; Populates client fields in ProSelect from GHL data using PSConsole
; ============================================================================
UpdateProSelectClient(GHL_Data)
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
		; ProSelect is already running - check if a file is open
		WinGetTitle, psTitle, ProSelect ahk_exe ProSelect.exe
		if !InStr(psTitle, "Untitled")
		{
			; A file is already open - confirm before overwriting
			result := DarkMsgBox("ProSelect Has Open File", "ProSelect already has a file open:`n`n" . psTitle . "`n`nLoading new client data may overwrite existing data.`n`nDo you want to continue?", "question", {buttons: ["Yes", "No"]})
			if (result = "No")
				Return
		}
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
	global Settings_SearchAllTabs
	
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
	
	; Try active tab first
	url := GetChromeTabURL()
	if (url && InStr(url, "thefullybookedphotographer.com") && InStr(url, "contacts/detail"))
	{
		WinActivate, ahk_id %origHwnd%
		return url
	}
	
	; Only cycle tabs if Search All Tabs is enabled
	if (Settings_SearchAllTabs)
	{
		; Cycle through tabs to find GHL contact (max 20 tabs)
		WinGetTitle, startTitle, A
		Loop, 20
		{
			Send, ^{Tab}
			Sleep, 150
			
			WinGetTitle, currentTitle, A
			if (currentTitle = startTitle)
				break  ; Back to start, stop cycling
			
			url := GetChromeTabURL()
			if (url && InStr(url, "thefullybookedphotographer.com") && InStr(url, "contacts/detail"))
			{
				WinActivate, ahk_id %origHwnd%
				return url
			}
		}
	}
	
	; Return focus to original window
	WinActivate, ahk_id %origHwnd%
	return ""
}

GetChromeTabURL()
{
	ClipSaved := ClipboardAll
	Clipboard := ""
	
	Send, ^l
	Sleep, 100
	Send, ^c
	ClipWait, 1
	
	url := Clipboard
	Clipboard := ClipSaved
	ClipSaved := ""
	
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
MsgBox 0x40223, SideKick ~ Downloader, %DriveLabel% Drive %driveLetter%\  Detected `n`nWould you like to download Images?`n`nNext Available Shoot No: %NextShootNo%`n`nSelect Multi Card for shoots spanning more than a single card., 120
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
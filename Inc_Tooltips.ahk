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
	
	; Lead Connector app toggle
	chkLC := Settings_QR_UseLeadConnector ? "Checked" : ""
	Gui, Settings:Add, CheckBox, x380 y548 w280 vGHLQRLeadConnectorChk BackgroundTrans Hidden %chkLC% HwndHwndQRLC, Open in Lead Connector app
	RegisterSettingsTooltip(HwndQRLC, "LEAD CONNECTOR APP`n`nWhen enabled, the QR code URL uses the`nLead Connector app domain so scanning`nopens the contact directly in the LC`nmobile app instead of a web browser.`n`nRequires the Lead Connector app to be`ninstalled on your phone.")
	
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
	; FILE BROWSER GROUP BOX
	; ═══════════════════════════════════════════════════════════════════════════
	Gui, Settings:Font, s10 Norm c%groupColor%, Segoe UI
	Gui, Settings:Add, GroupBox, x195 y450 w480 h130 vFilesEditorGroup Hidden, File Browser
	
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x210 y475 w100 BackgroundTrans vFilesEditorLabel Hidden HwndHwndFilesEditor, File Browser:
	RegisterSettingsTooltip(HwndFilesEditor, "FILE BROWSER`n`nApplication used to open shoot folders`nafter download or archive.`n`nWindows Explorer opens a folder window.`nBridge/Lightroom launch the Adobe app.")
	; Build dropdown list of detected file browsers
	browserList := DetectFileBrowsers()
	editorDisplay := (Settings_EditorRunPath = "Explore" || Settings_EditorRunPath = "") ? "Windows Explorer" : Settings_EditorRunPath
	; Find which option to pre-select by matching the saved path to known items
	selectedBrowser := FileBrowserDisplayFromPath(editorDisplay)
	Gui, Settings:Add, DropDownList, x315 y472 w240 r4 vFilesEditorEdit Hidden, %browserList%
	GuiControl, Settings:ChooseString, FilesEditorEdit, %selectedBrowser%
	Gui, Settings:Add, Button, x560 y471 w100 h27 gFilesEditorBrowseBtn vFilesEditorBrowse Hidden, Browse
	
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x210 y510 w200 BackgroundTrans vFilesOpenEditor Hidden HwndHwndFilesOpenEditor, Open Browser After Download
	RegisterSettingsTooltip(HwndFilesOpenEditor, "OPEN BROWSER AFTER DOWNLOAD`n`nAutomatically launch your file browser`nafter SD card download completes.`n`nSaves time by jumping straight to your files.")
	CreateToggleSlider("Settings", "BrowsDown", 630, 508, Settings_BrowsDown)
	GuiControl, Settings:Hide, Toggle_BrowsDown
	
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x210 y540 w200 BackgroundTrans vFilesAutoDrive Hidden HwndHwndFilesAutoDrive, Auto-Detect SD Cards
	RegisterSettingsTooltip(HwndFilesAutoDrive, "AUTO-DETECT SD CARDS`n`nAutomatically detect when an SD card is inserted.`nShows a notification or prompt when detected.`n`nConvenient for streamlined download workflow.")
	CreateToggleSlider("Settings", "AutoDriveDetect", 630, 538, Settings_AutoDriveDetect)
	GuiControl, Settings:Hide, Toggle_AutoDriveDetect
}

; ═══════════════════════════════════════════════════════════════════════════
; DetectFileBrowsers - Scan registry & filesystem for installed file browsers
; Returns pipe-delimited list for AHK DropDownList (e.g. "Windows Explorer|Adobe Bridge 2026|...")
; ═══════════════════════════════════════════════════════════════════════════
DetectFileBrowsers()
{
	global FileBrowserPaths
	FileBrowserPaths := {}
	list := "Windows Explorer"
	FileBrowserPaths["Windows Explorer"] := "Explore"
	
	; --- Adobe Bridge (yearly releases) ---
	Loop, Files, C:\Program Files\Adobe\Adobe Bridge*, D
	{
		exePath := A_LoopFileFullPath . "\Adobe Bridge.exe"
		if FileExist(exePath) {
			; Use folder name as display (e.g. "Adobe Bridge 2026")
			SplitPath, A_LoopFileFullPath, folderName
			list .= "|" . folderName
			FileBrowserPaths[folderName] := exePath
		}
	}
	; Fallback: check App Paths registry
	if !FileBrowserPaths.HasKey("Adobe Bridge") {
		RegRead, regBridge, HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\bridge.exe
		if (regBridge != "" && FileExist(regBridge)) {
			list .= "|Adobe Bridge"
			FileBrowserPaths["Adobe Bridge"] := regBridge
		}
	}
	
	; --- Adobe Lightroom Classic ---
	Loop, Files, C:\Program Files\Adobe\Adobe Lightroom Classic*, D
	{
		exePath := A_LoopFileFullPath . "\Lightroom.exe"
		if FileExist(exePath) {
			SplitPath, A_LoopFileFullPath, folderName
			list .= "|" . folderName
			FileBrowserPaths[folderName] := exePath
		}
	}
	; Fallback: check App Paths registry
	RegRead, regLR, HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\lightroom.exe
	if (regLR != "" && FileExist(regLR) && !InStr(list, "Lightroom")) {
		list .= "|Adobe Lightroom Classic"
		FileBrowserPaths["Adobe Lightroom Classic"] := regLR
	}
	
	; --- Adobe Photoshop ---
	Loop, Files, C:\Program Files\Adobe\Adobe Photoshop*, D
	{
		exePath := A_LoopFileFullPath . "\Photoshop.exe"
		if FileExist(exePath) {
			SplitPath, A_LoopFileFullPath, folderName
			list .= "|" . folderName
			FileBrowserPaths[folderName] := exePath
		}
	}
	
	; --- Capture One ---
	RegRead, regC1, HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\CaptureOne.exe
	if (regC1 != "" && FileExist(regC1)) {
		list .= "|Capture One"
		FileBrowserPaths["Capture One"] := regC1
	}
	
	return list
}

; Convert a stored path back to the display name for the dropdown
FileBrowserDisplayFromPath(pathOrDisplay)
{
	global FileBrowserPaths
	if (pathOrDisplay = "Explore" || pathOrDisplay = "" || pathOrDisplay = "Windows Explorer")
		return "Windows Explorer"
	; Check if it already matches a display name
	if FileBrowserPaths.HasKey(pathOrDisplay)
		return pathOrDisplay
	; Search by path value
	for displayName, exePath in FileBrowserPaths
	{
		if (exePath = pathOrDisplay)
			return displayName
	}
	; Fallback: return the raw path
	return pathOrDisplay
}

; Convert a dropdown display name to the executable path for saving
FileBrowserPathFromDisplay(displayName)
{
	global FileBrowserPaths
	if FileBrowserPaths.HasKey(displayName)
		return FileBrowserPaths[displayName]
	return displayName  ; Fallback: assume it's already a path
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


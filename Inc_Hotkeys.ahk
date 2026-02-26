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
	IniRead, Settings_QR_UseLeadConnector, %IniFilename%, QRCode, UseLeadConnector, 0
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
	
	; Cardly settings
	IniRead, Settings_Cardly_DashboardURL, %IniFilename%, Cardly, DashboardURL, https://zoom-photography-studio.cardly.net/manage
	IniRead, Settings_Cardly_MessageField, %IniFilename%, Cardly, MessageField, Message
	IniRead, Settings_Cardly_AutoSend, %IniFilename%, Cardly, AutoSend, 1
	IniRead, Settings_Cardly_TestMode, %IniFilename%, Cardly, TestMode, 0
	IniRead, Settings_Cardly_MediaID, %IniFilename%, Cardly, MediaID, %A_Space%
	IniRead, Settings_Cardly_MediaName, %IniFilename%, Cardly, MediaName, %A_Space%
	IniRead, Settings_Cardly_DefaultMessage, %IniFilename%, Cardly, DefaultMessage, %A_Space%
	StringReplace, Settings_Cardly_DefaultMessage, Settings_Cardly_DefaultMessage, ``n, `n, All
	IniRead, Settings_Cardly_PostcardFolder, %IniFilename%, Cardly, PostcardFolder, %A_Space%
	IniRead, Settings_Cardly_CardWidth, %IniFilename%, Cardly, CardWidth, 2913
	IniRead, Settings_Cardly_CardHeight, %IniFilename%, Cardly, CardHeight, 2125
	IniRead, Settings_Cardly_GHLMediaFolderID, %IniFilename%, Cardly, GHLMediaFolderID, %A_Space%
	IniRead, Settings_Cardly_GHLMediaFolderName, %IniFilename%, Cardly, GHLMediaFolderName, Client Photos
	IniRead, Settings_Cardly_PhotoLinkField, %IniFilename%, Cardly, PhotoLinkField, Contact Photo Link
	IniRead, Settings_Cardly_SaveToAlbum, %IniFilename%, Cardly, SaveToAlbum, 0
	IniRead, Settings_ShowBtn_Cardly, %IniFilename%, Toolbar, ShowBtn_Cardly, 1
	
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
	IniWrite, %Settings_QR_UseLeadConnector%, %IniFilename%, QRCode, UseLeadConnector
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
	
	; Save Cardly settings
	IniWrite, %Settings_Cardly_DashboardURL%, %IniFilename%, Cardly, DashboardURL
	IniWrite, %Settings_Cardly_MessageField%, %IniFilename%, Cardly, MessageField
	IniWrite, %Settings_Cardly_AutoSend%, %IniFilename%, Cardly, AutoSend
	IniWrite, %Settings_Cardly_TestMode%, %IniFilename%, Cardly, TestMode
	IniWrite, %Settings_Cardly_MediaID%, %IniFilename%, Cardly, MediaID
	IniWrite, %Settings_Cardly_MediaName%, %IniFilename%, Cardly, MediaName
	; Escape newlines for INI storage (IniRead only reads one line)
	Cardly_DefMsg_Escaped := Settings_Cardly_DefaultMessage
	StringReplace, Cardly_DefMsg_Escaped, Cardly_DefMsg_Escaped, `n, ``n, All
	IniWrite, %Cardly_DefMsg_Escaped%, %IniFilename%, Cardly, DefaultMessage
	IniWrite, %Settings_Cardly_PostcardFolder%, %IniFilename%, Cardly, PostcardFolder
	IniWrite, %Settings_Cardly_CardWidth%, %IniFilename%, Cardly, CardWidth
	IniWrite, %Settings_Cardly_CardHeight%, %IniFilename%, Cardly, CardHeight
	IniWrite, %Settings_Cardly_GHLMediaFolderID%, %IniFilename%, Cardly, GHLMediaFolderID
	IniWrite, %Settings_Cardly_GHLMediaFolderName%, %IniFilename%, Cardly, GHLMediaFolderName
	IniWrite, %Settings_Cardly_PhotoLinkField%, %IniFilename%, Cardly, PhotoLinkField
	IniWrite, %Settings_ShowBtn_Cardly%, %IniFilename%, Toolbar, ShowBtn_Cardly
	
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

; ═══════════════════════════════════════════════════════════════════════════════
; Direct .psa injection: save album → write payments to SQLite → reload album
; Replaces fragile keyboard automation with reliable database writes
; ═══════════════════════════════════════════════════════════════════════════════

FileAppend, % A_Now . " - UpdatePS - Starting direct .psa payment injection`n", %DebugLogFile%

; Step 1a: Close payment windows (Escape x3 covers Payline → Add Payment list → Payment tab)
FileAppend, % A_Now . " - UpdatePS - Closing payment windows`n", %DebugLogFile%
Loop, 3
{
	Send, {Escape}
	Sleep, 300
}
Sleep, 500

; Step 1b: Determine how many payments to enter (including downpayment if added)
TotalPaymentsToEnter := PayNo
StartIndex := 1
if (DownpaymentLineAdded)
{
	TotalPaymentsToEnter := PayNo + 1
	StartIndex := 0
}

if (TotalPaymentsToEnter < 1)
{
	DarkMsgBox("No Payments", "No payment lines to enter.", "warning", {timeout: 3})
	EnteringPaylines := False
	return
}

; Step 2: Save the album via PSConsole so .psa is up to date
FileAppend, % A_Now . " - UpdatePS - Saving album via PSConsole`n", %DebugLogFile%
saveResult := PsConsole("saveAlbum")
Sleep, 1000  ; Give filesystem time to finish writing

; Step 3: Get album path from PSConsole
albumData := PsConsole("getAlbumData")
if (!albumData || albumData = "false" || albumData = "true") {
	FileAppend, % A_Now . " - UpdatePS - FAILED: Could not get album data`n", %DebugLogFile%
	DarkMsgBox("Error", "Could not get album data from ProSelect.`n`nMake sure an album is open.", "error")
	EnteringPaylines := False
	return
}

; Extract .psa file path from album data
psaPath := ""
if (RegExMatch(albumData, "path=""([^""]+)""", pathMatch))
	psaPath := StrReplace(pathMatch1, "\\", "\")

if (psaPath = "" || !FileExist(psaPath)) {
	FileAppend, % A_Now . " - UpdatePS - FAILED: Album path not found: " . psaPath . "`n", %DebugLogFile%
	DarkMsgBox("Error", "Could not locate album file.`n`n" . psaPath, "error")
	EnteringPaylines := False
	return
}

FileAppend, % A_Now . " - UpdatePS - Album path: " . psaPath . "`n", %DebugLogFile%

; Step 4: Build Python command with all payment lines as arguments
pythonScript := A_ScriptDir . "\write_psa_payments.py"
if (!FileExist(pythonScript)) {
	FileAppend, % A_Now . " - UpdatePS - FAILED: write_psa_payments.py not found`n", %DebugLogFile%
	DarkMsgBox("Error", "write_psa_payments.py not found in SideKick folder.", "error")
	EnteringPaylines := False
	return
}

; Build argument string with quoted payment lines
; Use --clear to replace existing payments (Payment Calculator provides the complete plan)
pyArgs := """" . pythonScript . """ """ . psaPath . """ --clear"

Loop %TotalPaymentsToEnter%
{
	PaymentIndex := StartIndex + A_Index - 1
	payLine := PayPlanLine[PaymentIndex]
	if (payLine != "")
		pyArgs .= " """ . payLine . """"
}

FileAppend, % A_Now . " - UpdatePS - Running: python " . pyArgs . "`n", %DebugLogFile%

; Step 5: Run the Python script
RunWait, python %pyArgs%, %A_ScriptDir%, Hide, pyPID
; Read output via a temp file approach
tempOut := A_Temp . "\sk_psa_write_" . A_TickCount . ".txt"
RunWait, % "cmd /c python " . pyArgs . " > """ . tempOut . """ 2>&1", %A_ScriptDir%, Hide
FileRead, pyOutput, %tempOut%
FileDelete, %tempOut%
pyOutput := Trim(pyOutput)

FileAppend, % A_Now . " - UpdatePS - Python output: " . pyOutput . "`n", %DebugLogFile%

; Step 6: Check result
if (InStr(pyOutput, "SUCCESS|")) {
	countAdded := StrReplace(pyOutput, "SUCCESS|", "")
	FileAppend, % A_Now . " - UpdatePS - SUCCESS: " . countAdded . " payments written to .psa`n", %DebugLogFile%
	
	; Step 7: Reload the album in ProSelect so changes appear
	FileAppend, % A_Now . " - UpdatePS - Reloading album via PSConsole openAlbum`n", %DebugLogFile%
	reloadResult := PsConsole("openAlbum", psaPath, "true")
	Sleep, 2000  ; Give ProSelect time to reload
	
	; Play ding sound and show confirmation
	SoundPlay, *48
	if (DownpaymentLineAdded)
		DarkMsgBox("Payments Entered", "✅ Downpayment + " . PayNo . " scheduled payment(s) written to album!", "info", {timeout: 5})
	else
		DarkMsgBox("Payments Entered", "✅ " . countAdded . " payment(s) written to album!", "info", {timeout: 5})
} else {
	; Failed
	errorMsg := StrReplace(pyOutput, "ERROR|", "")
	FileAppend, % A_Now . " - UpdatePS - FAILED: " . errorMsg . "`n", %DebugLogFile%
	DarkMsgBox("Payment Write Failed", "Failed to write payments to album.`n`n" . errorMsg, "error")
}

; Legacy ProSelect 2024 and older - keep keyboard automation as fallback
if (false)
{

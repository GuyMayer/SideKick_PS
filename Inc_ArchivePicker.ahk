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


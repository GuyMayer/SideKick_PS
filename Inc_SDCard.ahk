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


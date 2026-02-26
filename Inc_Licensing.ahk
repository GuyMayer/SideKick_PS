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
	Gui, Settings:Add, GroupBox, x195 y55 w480 h450 vSCButtonsGroup, Toolbar Buttons
	
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
	
	; Cardly button (📮) - Coral/salmon background
	iconBgCardly := Settings_ShowBtn_Cardly ? "E88D67" : "444444"
	iconFgCardly := Settings_ShowBtn_Cardly ? "FFFFFF" : "888888"
	lblColorCardly := Settings_ShowBtn_Cardly ? labelColor : "666666"
	Gui, Settings:Font, s14, Segoe UI
	Gui, Settings:Add, Text, x215 y420 w30 h28 Center Background%iconBgCardly% c%iconFgCardly% vSCIcon_Cardly gToggleTB_Cardly, 📮
	Gui, Settings:Font, s10 Norm c%lblColorCardly%, Segoe UI
	Gui, Settings:Add, Text, x255 y424 w380 BackgroundTrans vSCLabel_Cardly gToggleTB_Cardly, Cardly  —  Send postcard via Cardly
	
	; SD Download button (📥) — note: managed separately in File Management
	Gui, Settings:Font, s14, Segoe UI
	Gui, Settings:Add, Text, x215 y455 w30 h28 Center BackgroundFF8C00 cWhite vSCIcon_Download, 📥
	Gui, Settings:Font, s10 Norm c%mutedColor%, Segoe UI
	Gui, Settings:Add, Text, x255 y459 w350 BackgroundTrans vSCLabel_Download, SD Download  —  Managed in File Management tab
	
	; ═══════════════════════════════════════════════════════════════════════════
	; INFO NOTE
	; ═══════════════════════════════════════════════════════════════════════════
	Gui, Settings:Font, s9 Norm c%mutedColor%, Segoe UI
	Gui, Settings:Add, Text, x210 y510 w440 BackgroundTrans vSCInfoNote, ℹ Settings button (⚙) is always visible.  Changes apply after clicking Apply.
	
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
; Cardly Integration Panel
; ═══════════════════════════════════════════════════════════════════════════════════════════════
CreateCardlyPanel()
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
	
	; Load Cardly API key from credentials if not already loaded
	if (Settings_Cardly_ApiKey = "") {
		_credPath := GetCredentialsFilePath()
		if (FileExist(_credPath)) {
			FileRead, _credJson, %_credPath%
			if (_credJson != "") {
				if (RegExMatch(_credJson, """cardly_api_key_b64""\s*:\s*""([^""]+)""", _m))
					Settings_Cardly_ApiKey := Base64_Decode(_m1)
				if (RegExMatch(_credJson, """cardly_media_id""\s*:\s*""([^""]+)""", _m))
					Settings_Cardly_MediaID := _m1
				if (RegExMatch(_credJson, """cardly_media_name""\s*:\s*""([^""]+)""", _m))
					Settings_Cardly_MediaName := _m1
			}
			_credJson := ""
		}
	}
	
	; Cardly panel container (initially hidden)
	Gui, Settings:Add, Text, x190 y10 w510 h680 BackgroundTrans vPanelCardly Hidden
	
	; Section header
	Gui, Settings:Font, s16 c%headerColor%, Segoe UI
	Gui, Settings:Add, Text, x195 y20 w380 BackgroundTrans vCrdHeader Hidden, 📮 Cardly Integration
	
	; Dashboard button (top-right)
	Gui, Settings:Font, s9 Norm c%textColor%, Segoe UI
	Gui, Settings:Add, Button, x490 y20 w85 h28 gOpenCardlyDashboard vCrdDashboardBtn Hidden, Dashboard
	Gui, Settings:Add, Button, x585 y20 w85 h28 gOpenCardlySignup vCrdSignupBtn Hidden, Sign Up
	
	; ═══════════════════════════════════════════════════════════════════════════
	; API CONFIGURATION GROUP BOX
	; ═══════════════════════════════════════════════════════════════════════════
	Gui, Settings:Font, s10 Norm c%groupColor%, Segoe UI
	Gui, Settings:Add, GroupBox, x195 y55 w480 h310 vCrdAPIGroup Hidden, Cardly API Configuration
	
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	
	; API Key
	Gui, Settings:Add, Text, x210 y80 w150 BackgroundTrans vCrdApiKeyLabel Hidden, API Key:
	Gui, Settings:Font, s10 Norm c000000, Segoe UI
	Gui, Settings:Add, Edit, x210 y100 w350 h25 vCrdApiKeyEdit Password* Hidden, %Settings_Cardly_ApiKey%
	
	; Template Name dropdown + Refresh
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x210 y133 w150 BackgroundTrans vCrdTemplateLabel Hidden, Template Name:
	Gui, Settings:Font, s10 Norm c000000, Segoe UI
	CardlyMediaNameList := Settings_Cardly_MediaName ? Settings_Cardly_MediaName . "||" : "Click Refresh to load templates"
	Gui, Settings:Add, DropDownList, x210 y153 w350 vCrdTemplateDDL gCardlyTemplateSelected Hidden, %CardlyMediaNameList%
	Gui, Settings:Add, Button, x570 y152 w90 h27 gRefreshCardlyTemplates vCrdTemplateRefresh Hidden, Refresh
	
	; GHL Media Folder dropdown + Refresh
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x210 y186 w200 BackgroundTrans vCrdGHLFolderLabel Hidden, GHL Media Folder:
	Gui, Settings:Font, s10 Norm c000000, Segoe UI
	CardlyGHLFolderList := Settings_Cardly_GHLMediaFolderName ? Settings_Cardly_GHLMediaFolderName . "||" : "Click Refresh to load GHL folders"
	Gui, Settings:Add, DropDownList, x210 y206 w350 vCrdGHLFolderDDL Hidden, %CardlyGHLFolderList%
	Gui, Settings:Add, Button, x570 y205 w90 h27 gRefreshGHLMediaFolders vCrdGHLFolderRefresh Hidden, Refresh
	
	; Client Photo Link Field dropdown + Refresh
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x210 y239 w200 BackgroundTrans vCrdPhotoLinkLabel Hidden, Client Photo Link Field:
	Gui, Settings:Font, s10 Norm c000000, Segoe UI
	CardlyPhotoLinkFieldList := Settings_Cardly_PhotoLinkField ? Settings_Cardly_PhotoLinkField . "||" : "Click Refresh to load GHL fields"
	Gui, Settings:Add, DropDownList, x210 y259 w350 vCrdPhotoLinkDDL Hidden, %CardlyPhotoLinkFieldList%
	Gui, Settings:Add, Button, x570 y258 w90 h27 gRefreshCardlyPhotoLinkFields vCrdPhotoLinkRefresh Hidden, Refresh
	
	; Local Postcard Folder + Browse
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x210 y292 w200 BackgroundTrans vCrdFolderLabel Hidden, Local Postcard Folder:
	Gui, Settings:Font, s10 Norm c000000, Segoe UI
	Gui, Settings:Add, Edit, x210 y312 w350 h25 vCrdFolderEdit Hidden, %Settings_Cardly_PostcardFolder%
	Gui, Settings:Add, Button, x570 y311 w90 h27 gBrowseCardlyFolder vCrdFolderBrowse Hidden, Browse
	
	; ═══════════════════════════════════════════════════════════════════════════
	; CARD MESSAGE SETTINGS GROUP BOX
	; ═══════════════════════════════════════════════════════════════════════════
	Gui, Settings:Font, s10 Norm c%groupColor%, Segoe UI
	Gui, Settings:Add, GroupBox, x195 y375 w480 h280 vCrdMsgGroup Hidden, Card Message Settings
	
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	
	; GHL Message Field dropdown + Refresh
	Gui, Settings:Add, Text, x210 y400 w200 BackgroundTrans vCrdMsgFieldLabel Hidden, GHL Message Field:
	Gui, Settings:Font, s10 Norm c000000, Segoe UI
	CardlyMsgFieldList := Settings_Cardly_MessageField ? Settings_Cardly_MessageField . "||" : "Click Refresh to load GHL fields"
	Gui, Settings:Add, DropDownList, x210 y420 w350 vCrdMsgFieldDDL Hidden, %CardlyMsgFieldList%
	Gui, Settings:Add, Button, x570 y419 w90 h27 gRefreshCardlyFields vCrdMsgFieldRefresh Hidden, Refresh
	
	; Default Message
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	Gui, Settings:Add, Text, x210 y453 w200 BackgroundTrans vCrdDefMsgLabel Hidden, Default Message:
	Gui, Settings:Font, s10 Norm c000000, Segoe UI
	Gui, Settings:Add, Edit, x210 y473 w450 h60 vCrdDefMsgEdit Hidden +Multi, %Settings_Cardly_DefaultMessage%
	
	; Auto Send checkbox
	Gui, Settings:Font, s10 Norm c%labelColor%, Segoe UI
	chkAutoSend := Settings_Cardly_AutoSend ? "Checked" : ""
	Gui, Settings:Add, CheckBox, x210 y527 w250 vCrdAutoSendChk BackgroundTrans Hidden %chkAutoSend%, Auto send card (skip preview)
	
	; Test Mode checkbox
	chkTestMode := Settings_Cardly_TestMode ? "Checked" : ""
	Gui, Settings:Add, CheckBox, x210 y552 w350 vCrdTestModeChk BackgroundTrans Hidden %chkTestMode%, Test mode (upload artwork; skip order)
	
	; Save to Album Folder checkbox
	chkSaveToAlbum := Settings_Cardly_SaveToAlbum ? "Checked" : ""
	Gui, Settings:Add, CheckBox, x210 y577 w350 vCrdSaveToAlbumChk BackgroundTrans Hidden %chkSaveToAlbum%, Save to album folder
	
	; Info text
	Gui, Settings:Font, s9 Norm c%mutedColor%, Segoe UI
	Gui, Settings:Add, Text, x210 y602 w450 h40 BackgroundTrans vCrdInfoText Hidden, API Key and credentials are stored securely in credentials.json
	
	; Reset font
	Gui, Settings:Font, s10 Norm c%textColor%, Segoe UI
}

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
	
	; Environment is always "live" - no selector needed
	
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
	RegisterSettingsTooltip(HwndGCDash, "GOCARDLESS DASHBOARD`n`nOpen the GoCardless web dashboard`nin your browser.")
	
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
	gcNameOptions := "(none)|Shoot No|Surname|First Name|Full Name|Order Date|GHL ID|Album Name"
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
; GoCardless environment is always "live" - no handler needed

EditGCToken:
	InputBox, newToken, GoCardless API Token, Enter your GoCardless API access token:,, 450, 150,,,,, %Settings_GoCardlessToken%
	if (!ErrorLevel && newToken != "") {
		newToken := Trim(newToken, " `t`r`n")
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
	envFlag := " --live"  ; Always live
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
		DarkMsgBox("Connection Successful", "Connected to GoCardless!`n`nCreditor: " . creditorName . "`nID: " . creditorId, "success")
	} else {
		errMsg := InStr(testResult, "ERROR|") ? StrReplace(testResult, "ERROR|", "") : testResult
		GuiControl, Settings:, GCStatusText, ❌ Failed
		GuiControl, Settings:+cFF6B6B, GCStatusText
		DarkMsgBox("Connection Failed", "Could not connect to GoCardless.`n`nError: " . Trim(errMsg) . "`n`nCheck your API token and try again.", "error")
	}
return

OpenCardlyDashboard:
	if (Settings_Cardly_DashboardURL != "")
		Run, %Settings_Cardly_DashboardURL%
	else
		Run, https://www.cardly.net/account
return

OpenCardlySignup:
	Run, https://www.cardly.net/business/signup
return

OpenGCDashboard:
	gcDashUrl := "https://manage.gocardless.com"
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
	stepText := "Step " . GCWizard_Step . " of 4"
	Gui, GCWizard:Add, Text, x20 y15 w%wizW% BackgroundTrans, %stepText%
	
	; Progress dots
	dotY := 18
	Loop, 4 {
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
		; Step 2: Sign up / Get token
		Gui, GCWizard:Font, s18 cFFFFFF Bold, Segoe UI
		Gui, GCWizard:Add, Text, x20 y%contentY% w480 BackgroundTrans, 🔑 Get Your API Token
		
		contentY += 50
		Gui, GCWizard:Font, s11 cCCCCCC Norm, Segoe UI
		Gui, GCWizard:Add, Text, x20 y%contentY% w480 BackgroundTrans, Follow these steps in the GoCardless Live Dashboard:
		
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
		Gui, GCWizard:Add, Text, x35 y%contentY% w460 BackgroundTrans, 5. Copy the token (starts with "live_")
		
		contentY += 45
		gcDashUrl := "https://manage.gocardless.com/developers/access-tokens/create"
		Gui, GCWizard:Font, s11, Segoe UI
		Gui, GCWizard:Add, Button, x150 y%contentY% w220 h35 gGCWizard_OpenDashboard vGCWizard_DashBtn, 🌐 Open GoCardless Dashboard
		
	} else if (GCWizard_Step = 3) {
		; Step 3: Paste token
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
		Gui, GCWizard:Add, Text, x20 y%contentY% w480 BackgroundTrans, Token should start with "live_".
		
		contentY += 35
		Gui, GCWizard:Font, s9 c4FC3F7, Segoe UI
		Gui, GCWizard:Add, Text, x20 y%contentY% w480 BackgroundTrans, Your token is stored securely in encrypted credentials.json
		
	} else if (GCWizard_Step = 4) {
		; Step 4: Test & Complete
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
	if (GCWizard_Step > 1 && GCWizard_Step < 4) {
		Gui, GCWizard:Font, s10, Segoe UI
		Gui, GCWizard:Add, Button, x20 y%btnY% w100 h35 gGCWizard_Back, ← Back
	}
	
	; Cancel button
	Gui, GCWizard:Font, s10, Segoe UI
	Gui, GCWizard:Add, Button, x300 y%btnY% w90 h35 gGCWizard_Cancel, Cancel
	
	; Next/Finish button
	if (GCWizard_Step < 3) {
		Gui, GCWizard:Add, Button, x400 y%btnY% w100 h35 gGCWizard_Next Default, Next →
	} else if (GCWizard_Step = 3) {
		Gui, GCWizard:Add, Button, x400 y%btnY% w100 h35 gGCWizard_TestToken Default, Test →
	} else if (GCWizard_Step = 4) {
		Gui, GCWizard:Add, Button, x400 y%btnY% w100 h35 gGCWizard_Finish vGCWizard_FinishBtn Default, Finish
		GuiControl, GCWizard:Disable, GCWizard_FinishBtn
	}
	
	; Show wizard
	Gui, GCWizard:Show, w%wizW% h%wizH%, GoCardless Setup Wizard
	
	; If step 4, auto-run the test
	if (GCWizard_Step = 4) {
		SetTimer, GCWizard_RunTest, -500
	}
return

GCWizard_OpenDashboard:
	gcDashUrl := "https://manage.gocardless.com/developers/access-tokens/create"
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
	
	; Validate token prefix - must be live
	if (!InStr(GCWizard_Token, "live_") && GCWizard_Token != "") {
		result := DarkMsgBox("Token Warning", "This token doesn't start with ""live_"".`n`nGoCardless live tokens should start with ""live_"".`n`nContinue anyway?", "warning", ["Continue", "Go Back"])
		if (result != "Continue")
			return
	}
	
	; Save token
	Settings_GoCardlessToken := GCWizard_Token
	SaveGHLCredentials()
	
	; Go to test step
	GCWizard_Step := 4
	Gosub, GCWizard_ShowStep
return

GCWizard_RunTest:
	global Settings_GoCardlessToken, Settings_GoCardlessEnvironment
	
	; Run API test
	envFlag := " --live"  ; Always live
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
		resultMsg := "Creditor: " . creditorName . "`nCreditor ID: " . creditorId . "`nEnvironment: Live"
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
	
	envFlag := " --live"  ; Always live
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
	gcUrl := "https://manage.gocardless.com/customers/" . m.customerId
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
		
		; If only one PSA, open it directly via PSConsole
		if (psaCount = 1) {
			Loop, Files, %folderPath%\*.psa
				psaSinglePath := A_LoopFileFullPath
			PsConsole("openAlbum", psaSinglePath, "true")
			return true
		}
		
		; Multiple PSAs — open file dialog so user can choose
		WinActivate, ahk_exe ProSelect.exe
		WinWaitActive, ahk_exe ProSelect.exe, , 3
		Sleep, 300
		
		SendInput, ^o
		Sleep, 500
		
		; Wait for file dialog
		WinWait, Select an Album File, , 5
		if (!ErrorLevel) {
			; Navigate to folder using the filename edit control
			Sleep, 300
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
	envFlag := " --live"  ; Always live
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
; Returns the full path to the exported XML file on success, empty string on failure
; showErrors: if true, shows DarkMsgBox on errors; if false, fails silently
PS_TriggerXMLExport(showErrors := false) {
	global DebugLogFile, PsConsolePath, Settings_InvoiceWatchFolder
	
	FileAppend, % A_Now . " - PS_TriggerXMLExport - Starting PSConsole export`n", %DebugLogFile%
	
	; Check if PSConsole is available
	if (PsConsolePath = "") {
		FileAppend, % A_Now . " - PS_TriggerXMLExport - FAILED: PSConsole not found`n", %DebugLogFile%
		if (showErrors)
			DarkMsgBox("PSConsole Not Found", "PSConsole.exe was not found.`n`nPlease ensure ProSelect is properly installed.", "warning")
		return ""
	}
	
	; Get export folder (watch folder)
	exportFolder := Settings_InvoiceWatchFolder
	if (exportFolder = "" || !FileExist(exportFolder))
		exportFolder := A_MyDocuments . "\Proselect Order Exports"
	
	; Ensure export folder exists
	if (!FileExist(exportFolder))
		FileCreateDir, %exportFolder%
	
	; Get album data to build filename
	albumData := PsConsole("getAlbumData")
	if (!albumData || albumData = "false" || albumData = "true") {
		FileAppend, % A_Now . " - PS_TriggerXMLExport - FAILED: Could not get album data`n", %DebugLogFile%
		if (showErrors)
			DarkMsgBox("Export Failed", "Could not get album data from ProSelect.`n`nMake sure an album is open.", "warning")
		return ""
	}
	
	; Extract album name from XML
	albumName := ""
	if (RegExMatch(albumData, "<albumFile[^>]+albumName=""([^""]+)""", nameMatch))
		albumName := nameMatch1
	
	; Remove .psa extension if present
	albumName := RegExReplace(albumName, "\.psa$", "")
	
	; Extract shoot number from album name (e.g., P26010P from "P26010P_Smith_abc123")
	shootNo := ""
	if (RegExMatch(albumName, "^(P\d+[A-Z]?)", shootMatch))
		shootNo := shootMatch1
	
	; Build filename in ProSelect format: YYYY-MM-DD_HHMMSS_ShootNo_1.xml
	FormatTime, timestamp, , yyyy-MM-dd_HHmmss
	if (shootNo != "")
		baseFilename := timestamp . "_" . shootNo
	else if (albumName != "")
		baseFilename := timestamp . "_" . albumName
	else
		baseFilename := timestamp . "_export"
	
	; Find next available suffix (_1, _2, _3, etc.)
	suffix := 1
	Loop {
		xmlFilename := baseFilename . "_" . suffix . ".xml"
		xmlPath := exportFolder . "\" . xmlFilename
		if (!FileExist(xmlPath))
			break
		suffix++
		if (suffix > 999)  ; Safety limit
			break
	}
	
	FileAppend, % A_Now . " - PS_TriggerXMLExport - Export path: " . xmlPath . "`n", %DebugLogFile%
	
	; Call PSConsole exportOrderData
	; format: 1 = PhotoOne XML (Standard XML)
	; group: 0 = all groups
	; includeSampleImages: false
	; sampleimagesfolder: temp folder (required parameter even if not used)
	tempFolder := A_Temp
	result := PsConsole("exportOrderData", xmlPath, "1", "0", "false", tempFolder)
	
	if (!result || result = "false" || result = "true") {
		FileAppend, % A_Now . " - PS_TriggerXMLExport - FAILED: PSConsole exportOrderData failed`n", %DebugLogFile%
		if (showErrors)
			DarkMsgBox("Export Failed", "PSConsole exportOrderData command failed.`n`nMake sure the album has orders.", "warning")
		return ""
	}
	
	; Check if file was created
	Sleep, 500  ; Give filesystem time to write
	if (!FileExist(xmlPath)) {
		FileAppend, % A_Now . " - PS_TriggerXMLExport - FAILED: XML file not created`n", %DebugLogFile%
		if (showErrors)
			DarkMsgBox("Export Failed", "XML file was not created.`n`nPath: " . xmlPath, "warning")
		return ""
	}
	
	FileAppend, % A_Now . " - PS_TriggerXMLExport - SUCCESS: " . xmlPath . "`n", %DebugLogFile%
	return xmlPath
}

; Trigger ProSelect Export Orders and click Export (wrapper for GoCardless flow)
GC_TriggerExport() {
	global DebugLogFile
	FileAppend, % A_Now . " - GC_TriggerExport - Calling shared PS_TriggerXMLExport`n", %DebugLogFile%
	xmlPath := PS_TriggerXMLExport(false)  ; Silent mode - no error dialogs
	FileAppend, % A_Now . " - GC_TriggerExport - Export result: " . (xmlPath ? xmlPath : "(failed)") . "`n", %DebugLogFile%
	return xmlPath
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
	
	envFlag := " --live"  ; Always live
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
	global GC_PP_OrderDate    ; Store order date from .psa for plan naming
	
	; Initialize .psa path
	GC_PP_PsaFilePath := ""
	GC_PP_OrderDate := ""
	
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
		
		; Save the album via PSConsole (no blind sleep needed)
		PsConsole("saveAlbum")
		
		; NOW get the album folder using PSConsole getAlbumData
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
			; Extract order date if present (NO_PAYMENTS|DD/MM/YYYY)
			noParts := StrSplit(scriptOutput, "|")
			if (noParts.Length() >= 2 && noParts[2] != "")
				GC_PP_OrderDate := noParts[2]
			; No payments at all - let user know
			DarkMsgBox("No Payments", "No payments found in the album.`n`nAdd a payment schedule in ProSelect first.", "warning")
			return
		}
		
		if (InStr(scriptOutput, "PAYMENTS|")) {
			; Parse payments: PAYMENTS|count|order_date|day,month,year,amount,methodName,methodID|...
			parts := StrSplit(scriptOutput, "|")
			paymentCount := parts[2]
			; Extract order date (DD/MM/YYYY format)
			if (parts[3] != "")
				GC_PP_OrderDate := parts[3]
			
			Loop, %paymentCount%
			{
				paymentData := parts[A_Index + 3]
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
	
	; Build plan name from naming format parts (Settings)
	global Settings_GCNamePart1, Settings_GCNamePart2, Settings_GCNamePart3
	
	; Resolve each naming part to actual data
	resolvedParts := []
	Loop, 3 {
		partNum := A_Index
		partVal := Settings_GCNamePart%partNum%
		if (partVal = "" || partVal = "(none)")
			continue
		resolved := ""
		if (partVal = "Shoot No")
			resolved := jobCode
		else if (partVal = "Surname")
			resolved := contactData.lastName
		else if (partVal = "First Name")
			resolved := contactData.firstName
		else if (partVal = "Full Name")
			resolved := Trim(contactData.firstName . " " . contactData.lastName)
		else if (partVal = "Order Date")
			resolved := GC_PP_OrderDate
		else if (partVal = "GHL ID")
			resolved := contactData.id
		else if (partVal = "Album Name")
			resolved := defaultName
		if (resolved != "")
			resolvedParts.Push(resolved)
	}
	
	; If naming parts produced a result, use it; otherwise keep defaultName
	if (resolvedParts.Length() > 0) {
		formattedName := ""
		for i, part in resolvedParts {
			if (formattedName != "")
				formattedName .= " - "
			formattedName .= part
		}
		defaultName := formattedName
	}
	
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
	envFlag := " --live"  ; Always live
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
			gcUrl := "https://manage.gocardless.com/customers/" . customerId
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
	envFlag := " --live"  ; Always live
	
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
	envFlag := " --live"  ; Always live
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
	envFlag := " --live"  ; Always live
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
	sampleData := {shootNo: "P26005", surname: "Smith", firstName: "John", fullName: "John Smith", orderDate: "17/02/2026", ghlId: "abc123xyz", albumName: "2026-02-17_Smith"}
	
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
		else if (partVal = "Order Date")
			parts.Push(sampleData.orderDate)
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
	RegisterSettingsTooltip(HwndDevPushWeb, "PUSH WEBSITE`n`nSync SideKick_PS_Website to docs folder and push to GitHub.`nOnly commits website files (no scripts).`n`nSite goes live in ~1-2 minutes.")
	
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
	GuiControl, Settings:Hide, TabCardlyBg
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
	GuiControl, Settings:Hide, GHLQRLeadConnectorChk
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
	GuiControl, Settings:Hide, SCIcon_Cardly
	GuiControl, Settings:Hide, SCLabel_Cardly
	GuiControl, Settings:Hide, Toggle_ShowBtn_Cardly
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
	
	; Hide all panels - Cardly
	GuiControl, Settings:Hide, TabCardlyBg
	GuiControl, Settings:Hide, PanelCardly
	GuiControl, Settings:Hide, CrdHeader
	GuiControl, Settings:Hide, CrdDashboardBtn
	GuiControl, Settings:Hide, CrdSignupBtn
	GuiControl, Settings:Hide, CrdAPIGroup
	GuiControl, Settings:Hide, CrdApiKeyLabel
	GuiControl, Settings:Hide, CrdApiKeyEdit
	GuiControl, Settings:Hide, CrdTemplateLabel
	GuiControl, Settings:Hide, CrdTemplateDDL
	GuiControl, Settings:Hide, CrdTemplateRefresh
	GuiControl, Settings:Hide, CrdGHLFolderLabel
	GuiControl, Settings:Hide, CrdGHLFolderDDL
	GuiControl, Settings:Hide, CrdGHLFolderRefresh
	GuiControl, Settings:Hide, CrdPhotoLinkLabel
	GuiControl, Settings:Hide, CrdPhotoLinkDDL
	GuiControl, Settings:Hide, CrdPhotoLinkRefresh
	GuiControl, Settings:Hide, CrdFolderLabel
	GuiControl, Settings:Hide, CrdFolderEdit
	GuiControl, Settings:Hide, CrdFolderBrowse
	GuiControl, Settings:Hide, CrdMsgGroup
	GuiControl, Settings:Hide, CrdMsgFieldLabel
	GuiControl, Settings:Hide, CrdMsgFieldDDL
	GuiControl, Settings:Hide, CrdMsgFieldRefresh
	GuiControl, Settings:Hide, CrdDefMsgLabel
	GuiControl, Settings:Hide, CrdDefMsgEdit
	GuiControl, Settings:Hide, CrdAutoSendChk
	GuiControl, Settings:Hide, CrdTestModeChk
	GuiControl, Settings:Hide, CrdSaveToAlbumChk
	GuiControl, Settings:Hide, CrdInfoText
	
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
		GuiControl, Settings:Show, GHLQRLeadConnectorChk
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
		GuiControl, Settings:Show, SCIcon_Cardly
		GuiControl, Settings:Show, SCLabel_Cardly
		GuiControl, Settings:Show, Toggle_ShowBtn_Cardly
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
	else if (tabName = "Cardly")
	{
		GuiControl, Settings:Show, TabCardlyBg
		GuiControl, Settings:Show, PanelCardly
		GuiControl, Settings:Show, CrdHeader
		GuiControl, Settings:Show, CrdDashboardBtn
		GuiControl, Settings:Show, CrdSignupBtn
		GuiControl, Settings:Show, CrdAPIGroup
		GuiControl, Settings:Show, CrdApiKeyLabel
		GuiControl, Settings:Show, CrdApiKeyEdit
		GuiControl, Settings:Show, CrdTemplateLabel
		GuiControl, Settings:Show, CrdTemplateDDL
		GuiControl, Settings:Show, CrdTemplateRefresh
		GuiControl, Settings:Show, CrdGHLFolderLabel
		GuiControl, Settings:Show, CrdGHLFolderDDL
		GuiControl, Settings:Show, CrdGHLFolderRefresh
		GuiControl, Settings:Show, CrdPhotoLinkLabel
		GuiControl, Settings:Show, CrdPhotoLinkDDL
		GuiControl, Settings:Show, CrdPhotoLinkRefresh
		GuiControl, Settings:Show, CrdFolderLabel
		GuiControl, Settings:Show, CrdFolderEdit
		GuiControl, Settings:Show, CrdFolderBrowse
		GuiControl, Settings:Show, CrdMsgGroup
		GuiControl, Settings:Show, CrdMsgFieldLabel
		GuiControl, Settings:Show, CrdMsgFieldDDL
		GuiControl, Settings:Show, CrdMsgFieldRefresh
		GuiControl, Settings:Show, CrdDefMsgLabel
		GuiControl, Settings:Show, CrdDefMsgEdit
		GuiControl, Settings:Show, CrdAutoSendChk
		GuiControl, Settings:Show, CrdTestModeChk
		GuiControl, Settings:Show, CrdSaveToAlbumChk
		GuiControl, Settings:Show, CrdInfoText
		; Re-select saved dropdown values
		if (Settings_Cardly_MediaName != "")
			GuiControl, Settings:ChooseString, CrdTemplateDDL, %Settings_Cardly_MediaName%
		if (Settings_Cardly_GHLMediaFolderName != "")
			GuiControl, Settings:ChooseString, CrdGHLFolderDDL, %Settings_Cardly_GHLMediaFolderName%
		if (Settings_Cardly_PhotoLinkField != "")
			GuiControl, Settings:ChooseString, CrdPhotoLinkDDL, %Settings_Cardly_PhotoLinkField%
		if (Settings_Cardly_MessageField != "")
			GuiControl, Settings:ChooseString, CrdMsgFieldDDL, %Settings_Cardly_MessageField%
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

SettingsTabCardly:
ShowSettingsTab("Cardly")
Return

SettingsTabDeveloper:
ShowSettingsTab("Developer")
Return

SettingsLogoClick:
SettingsWebLinkClick:
	Run, https://ps.ghl-sidekick.com
Return

; ═══════════════════════════════════════════════════════════════════════════════════════════════
; Cardly Settings Handlers
; ═══════════════════════════════════════════════════════════════════════════════════════════════

RefreshCardlyTemplates:
{
	Gui, Settings:Submit, NoHide
	
	; Use Cardly API key - try global first, then GUI field
	apiKey := Settings_Cardly_ApiKey
	if (apiKey = "") {
		GuiControlGet, apiKey, Settings:, CrdApiKeyEdit
	}
	if (apiKey = "") {
		DarkMsgBox("Error", "No Cardly API Key found.`n`nEnter an API Key above and click Apply first, or ensure credentials.json has a valid key.", "error")
		Return
	}
	
	global CardlyTemplateMap, CardlyTemplateSizes, CardlyTemplateAltOrientation
	CardlyTemplateMap := {}
	CardlyTemplateSizes := {}
	CardlyTemplateAltOrientation := {}
	templateList := ""
	mediaList := ""
	templateCount := 0
	mediaCount := 0
	
	ToolTip, Loading Cardly templates...
	
	; --- Fetch TEMPLATES from /templates (pre-made with variables) ---
	try {
		whr := ComObjCreate("WinHttp.WinHttpRequest.5.1")
		whr.SetTimeouts(10000, 10000, 10000, 10000)
		whr.Open("GET", "https://api.card.ly/v2/templates", false)
		whr.SetRequestHeader("API-Key", apiKey)
		whr.Send()
		if (whr.Status = 200) {
			responseText := whr.ResponseText
			; Parse templates using RegEx (no ParseJSON in PS)
			pos := 1
			while (pos := RegExMatch(responseText, """id""\s*:\s*""([^""]+)""\s*,\s*""name""\s*:\s*""([^""]+)""", tMatch, pos)) {
				tId := tMatch1
				tName := tMatch2
				if (tName != "" && tId != "") {
					; Try to extract art pixel dimensions (art.px.width / art.px.height)
					artW := ""
					artH := ""
					; Look for "px" section then its width/height within the template block
					subStr := SubStr(responseText, pos, 800)
					; Find the "px" object and extract width/height from it
					if (RegExMatch(subStr, """px""\s*:\s*\{[^}]*""width""\s*:\s*(\d+)", wMatch))
						artW := wMatch1
					if (RegExMatch(subStr, """px""\s*:\s*\{[^}]*""height""\s*:\s*(\d+)", hMatch))
						artH := hMatch1
					; Fallback: if no px section found, try top-level (legacy API)
					if (artW = "" || artH = "") {
						if (RegExMatch(subStr, """width""\s*:\s*(\d+)", wMatch))
							artW := wMatch1
						if (RegExMatch(subStr, """height""\s*:\s*(\d+)", hMatch))
							artH := hMatch1
						; If values look like mm (both < 500), convert to px at 400dpi
						if (artW != "" && artH != "" && artW < 500 && artH < 500) {
							artW := Round(artW * 400 / 25.4)
							artH := Round(artH * 400 / 25.4)
						}
					}
					displayName := tName
					if (artW != "" && artH != "")
						displayName := tName . " (" . artW . "x" . artH . "px)"
					if (!CardlyTemplateMap.HasKey(displayName)) {
						templateList .= (templateList ? "|" : "") . displayName
						CardlyTemplateMap[displayName] := tId
						CardlyTemplateSizes[displayName] := artW . "x" . artH
						templateCount++
					}
				}
				pos += StrLen(tMatch)
			}
		}
	} catch {
	}
	
	; --- Fetch MEDIA from /media (base card types for custom artwork) ---
	try {
		whr2 := ComObjCreate("WinHttp.WinHttpRequest.5.1")
		whr2.SetTimeouts(10000, 10000, 10000, 10000)
		whr2.Open("GET", "https://api.card.ly/v2/media", false)
		whr2.SetRequestHeader("API-Key", apiKey)
		whr2.Send()
		if (whr2.Status = 200) {
			responseText2 := whr2.ResponseText
			pos := 1
			while (pos := RegExMatch(responseText2, """id""\s*:\s*""([^""]+)""\s*,\s*""name""\s*:\s*""([^""]+)""", mMatch, pos)) {
				mId := mMatch1
				mName := mMatch2
				if (mName != "" && mId != "") {
					artW := ""
					artH := ""
					subStr := SubStr(responseText2, pos, 800)
					; Find the "px" object and extract width/height from it
					if (RegExMatch(subStr, """px""\s*:\s*\{[^}]*""width""\s*:\s*(\d+)", wMatch))
						artW := wMatch1
					if (RegExMatch(subStr, """px""\s*:\s*\{[^}]*""height""\s*:\s*(\d+)", hMatch))
						artH := hMatch1
					; Fallback: if no px section found, try top-level (legacy API)
					if (artW = "" || artH = "") {
						if (RegExMatch(subStr, """width""\s*:\s*(\d+)", wMatch))
							artW := wMatch1
						if (RegExMatch(subStr, """height""\s*:\s*(\d+)", hMatch))
							artH := hMatch1
						; If values look like mm (both < 500), convert to px at 400dpi
						if (artW != "" && artH != "" && artW < 500 && artH < 500) {
							artW := Round(artW * 400 / 25.4)
							artH := Round(artH * 400 / 25.4)
						}
					}
					displayName := mName
					if (artW != "" && artH != "")
						displayName := mName . " (" . artW . "x" . artH . "px)"
					if (!CardlyTemplateMap.HasKey(displayName)) {
						mediaList .= (mediaList ? "|" : "") . displayName
						CardlyTemplateMap[displayName] := mId
						CardlyTemplateSizes[displayName] := artW . "x" . artH
						mediaCount++
					}
				}
				pos += StrLen(mMatch)
			}
		}
	} catch {
	}
	
	ToolTip
	
	totalCount := templateCount + mediaCount
	if (totalCount = 0) {
		DarkMsgBox("No Templates", "No templates or media found in your Cardly account.", "warning")
		Return
	}
	
	; Build combined list with divider: Templates first, then Media
	combinedList := ""
	if (templateList != "") {
		combinedList := "── Templates ──|" . templateList
	}
	if (mediaList != "") {
		if (combinedList != "")
			combinedList .= "|── Media (Artwork) ──|" . mediaList
		else
			combinedList := "── Media (Artwork) ──|" . mediaList
	}
	
	; --- Build orientation pair map (L↔P / Landscape↔Portrait) ---
	; For each template, strip orientation suffix to get a base name, then find its partner.
	; Method 1: Match by display name (e.g. "MyCard-L (WxHpx)" ↔ "MyCard-P (WxHpx)")
	; Method 2: Fallback — match by API ID (e.g. "thankyou-photocard-l" ↔ "thankyou-photocard-p")
	CardlyTemplateAltOrientation := {}
	orientSuffix := "i)[\s_-]+(landscape|portrait|l|p)$"
	for dName, tId in CardlyTemplateMap {
		if (CardlyTemplateAltOrientation.HasKey(dName))
			continue
		; --- Method 1: match by display name ---
		rawName := RegExReplace(dName, "\s*\([^)]*px\)$")
		baseName := RegExReplace(rawName, orientSuffix)
		found := false
		for dName2, tId2 in CardlyTemplateMap {
			if (dName2 = dName)
				continue
			rawName2 := RegExReplace(dName2, "\s*\([^)]*px\)$")
			baseName2 := RegExReplace(rawName2, orientSuffix)
			if (baseName != "" && baseName != rawName && baseName2 != "" && baseName2 != rawName2) {
				StringLower, bLow, baseName
				StringLower, bLow2, baseName2
				if (bLow = bLow2) {
					CardlyTemplateAltOrientation[dName] := dName2
					found := true
					break
				}
			}
		}
		; --- Method 2: fallback — match by API template ID ---
		if (!found) {
			baseId := RegExReplace(tId, orientSuffix)
			if (baseId != "" && baseId != tId) {
				for dName2, tId2 in CardlyTemplateMap {
					if (dName2 = dName)
						continue
					baseId2 := RegExReplace(tId2, orientSuffix)
					if (baseId2 != "" && baseId2 != tId2) {
						StringLower, iLow, baseId
						StringLower, iLow2, baseId2
						if (iLow = iLow2) {
							CardlyTemplateAltOrientation[dName] := dName2
							break
						}
					}
				}
			}
		}
	}
	
	; Update template dropdown
	GuiControl, Settings:, CrdTemplateDDL, |%combinedList%
	; Re-select saved value if it exists in the list
	if (Settings_Cardly_MediaName != "")
		GuiControl, Settings:ChooseString, CrdTemplateDDL, %Settings_Cardly_MediaName%
	DarkMsgBox("Templates Loaded", "Loaded " . templateCount . " templates and " . mediaCount . " media types.`n`nSelect one to use for cards.", "success")
	Return
}

CardlyTemplateSelected:
{
	Gui, Settings:Submit, NoHide
	GuiControlGet, selectedTemplate, Settings:, CrdTemplateDDL
	; Ignore divider lines
	if (InStr(selectedTemplate, "──"))
		Return
	if (CardlyTemplateMap.HasKey(selectedTemplate)) {
		Settings_Cardly_MediaID := CardlyTemplateMap[selectedTemplate]
	}
	Return
}

RefreshCardlyFields:
{
	Gui, Settings:Submit, NoHide
	
	; Need GHL API key to fetch fields
	if (GHL_API_Key = "") {
		DarkMsgBox("Error", "Please enter a GHL API Key in the GHL Integration tab first.", "error")
		Return
	}
	
	ToolTip, Loading GHL custom fields...
	
	; Fetch custom fields from GHL API
	fieldsUrl := "https://services.leadconnectorhq.com/locations/" . GHL_LocationID . "/customFields"
	cardlyFieldsList := ""
	try {
		whr := ComObjCreate("WinHttp.WinHttpRequest.5.1")
		whr.SetTimeouts(10000, 10000, 10000, 10000)
		whr.Open("GET", fieldsUrl, false)
		whr.SetRequestHeader("Authorization", "Bearer " . GHL_API_Key)
		whr.SetRequestHeader("Version", "2021-07-28")
		whr.Send()
		ToolTip
		whrStatus := whr.Status
		if (whrStatus = 200) {
			response := whr.ResponseText
			; Parse custom field names using RegEx
			pos := 1
			while (pos := RegExMatch(response, """name""\s*:\s*""([^""]+)""", fMatch, pos)) {
				fieldName := fMatch1
				if (fieldName != "")
					cardlyFieldsList .= (cardlyFieldsList ? "|" : "") . fieldName
				pos += StrLen(fMatch)
			}
		} else {
			DarkMsgBox("Error", "Failed to fetch GHL fields.`nStatus: " . whrStatus . "`n`nCheck your API Key and Location ID in the GHL tab.", "error")
			Return
		}
	} catch e {
		ToolTip
		DarkMsgBox("Error", "Error connecting to GHL:`n" . e.Message, "error")
		Return
	}
	
	if (cardlyFieldsList = "") {
		DarkMsgBox("No Fields", "No custom fields found in your GHL location.", "warning")
		Return
	}
	
	; Update Cardly message field dropdown
	GuiControl, Settings:, CrdMsgFieldDDL, |%cardlyFieldsList%
	if (Settings_Cardly_MessageField != "")
		GuiControl, Settings:ChooseString, CrdMsgFieldDDL, %Settings_Cardly_MessageField%
	; Also update photo link field dropdown with same field list
	GuiControl, Settings:, CrdPhotoLinkDDL, |%cardlyFieldsList%
	if (Settings_Cardly_PhotoLinkField != "")
		GuiControl, Settings:ChooseString, CrdPhotoLinkDDL, %Settings_Cardly_PhotoLinkField%
	DarkMsgBox("Fields Loaded", "Loaded GHL custom fields.`n`nSelect the message field and photo link field for Cardly.", "success")
	Return
}

RefreshCardlyPhotoLinkFields:
{
	Gui, Settings:Submit, NoHide
	
	if (GHL_API_Key = "") {
		DarkMsgBox("Error", "Please enter a GHL API Key in the GHL Integration tab first.", "error")
		Return
	}
	
	ToolTip, Loading GHL custom fields...
	
	fieldsUrl := "https://services.leadconnectorhq.com/locations/" . GHL_LocationID . "/customFields"
	photoFieldsList := ""
	try {
		whr := ComObjCreate("WinHttp.WinHttpRequest.5.1")
		whr.SetTimeouts(10000, 10000, 10000, 10000)
		whr.Open("GET", fieldsUrl, false)
		whr.SetRequestHeader("Authorization", "Bearer " . GHL_API_Key)
		whr.SetRequestHeader("Version", "2021-07-28")
		whr.Send()
		ToolTip
		whrStatus := whr.Status
		if (whrStatus = 200) {
			response := whr.ResponseText
			pos := 1
			while (pos := RegExMatch(response, """name""\s*:\s*""([^""]+)""", fMatch, pos)) {
				fieldName := fMatch1
				if (fieldName != "")
					photoFieldsList .= (photoFieldsList ? "|" : "") . fieldName
				pos += StrLen(fMatch)
			}
		} else {
			DarkMsgBox("Error", "Failed to fetch GHL fields.`nStatus: " . whrStatus, "error")
			Return
		}
	} catch e {
		ToolTip
		DarkMsgBox("Error", "Error connecting to GHL:`n" . e.Message, "error")
		Return
	}
	
	if (photoFieldsList = "") {
		DarkMsgBox("No Fields", "No custom fields found.", "warning")
		Return
	}
	
	GuiControl, Settings:, CrdPhotoLinkDDL, |%photoFieldsList%
	if (Settings_Cardly_PhotoLinkField != "")
		GuiControl, Settings:ChooseString, CrdPhotoLinkDDL, %Settings_Cardly_PhotoLinkField%
	DarkMsgBox("Fields Loaded", "Loaded GHL custom fields.`n`nSelect the field to store the client photo URL.", "success")
	Return
}

RefreshGHLMediaFolders:
{
	Gui, Settings:Submit, NoHide
	
	if (GHL_API_Key = "") {
		DarkMsgBox("Error", "Please enter GHL API Key in the GHL Integration tab first.", "error")
		Return
	}
	
	ToolTip, Loading GHL Media folders...
	global CardlyGHLFolderMap
	CardlyGHLFolderMap := {}
	folderList := ""
	folderCount := 0
	
	try {
		whr := ComObjCreate("WinHttp.WinHttpRequest.5.1")
		whr.SetTimeouts(10000, 10000, 10000, 10000)
		; GHL Media Library API - fetch folders
		mediaUrl := "https://services.leadconnectorhq.com/medias/files?sortBy=name&sortOrder=asc&limit=100&type=folder&altId=" . GHL_LocationID . "&altType=location"
		whr.Open("GET", mediaUrl, false)
		whr.SetRequestHeader("Authorization", "Bearer " . GHL_API_Key)
		whr.SetRequestHeader("Version", "2021-07-28")
		whr.SetRequestHeader("Accept", "application/json")
		whr.Send()
		ToolTip
		if (whr.Status = 200) {
			response := whr.ResponseText
			; Parse folder names and IDs using RegEx
			pos := 1
			while (pos := RegExMatch(response, """(?:_id|id)""\s*:\s*""([^""]+)""", idMatch, pos)) {
				fId := idMatch1
				; Find the name field near this id
				namePos := RegExMatch(response, """name""\s*:\s*""([^""]+)""", nameMatch, pos)
				if (namePos && nameMatch1 != "") {
					fName := nameMatch1
					if (fId != "" && fName != "") {
						folderList .= (folderList ? "|" : "") . fName
						CardlyGHLFolderMap[fName] := fId
						folderCount++
					}
				}
				pos += StrLen(idMatch)
			}
		} else {
			whrStatus := whr.Status
			DarkMsgBox("Error", "GHL API returned status " . whrStatus . "`n`nCheck your API Key.", "error")
			Return
		}
	} catch e {
		ToolTip
		DarkMsgBox("Error", "Failed to fetch GHL Media folders.`n`n" . e.Message, "error")
		Return
	}
	
	if (folderCount = 0) {
		DarkMsgBox("No Folders", "No folders found in GHL Media Library.`n`nPlease create a folder in GHL Media first.", "warning")
		Return
	}
	
	; Update dropdown with fetched folders
	GuiControl, Settings:, CrdGHLFolderDDL, |%folderList%
	; Try to re-select previously saved folder
	if (Settings_Cardly_GHLMediaFolderName != "")
		GuiControl, Settings:ChooseString, CrdGHLFolderDDL, %Settings_Cardly_GHLMediaFolderName%
	DarkMsgBox("Folders Loaded", "Loaded " . folderCount . " GHL Media folder(s).", "success")
	Return
}

BrowseCardlyFolder:
{
	Gui, Settings:+OwnDialogs
	FileSelectFolder, SelectedFolder, *%Settings_Cardly_PostcardFolder%, 3, Select Local Postcard Folder
	if (SelectedFolder != "") {
		GuiControl, Settings:, CrdFolderEdit, %SelectedFolder%
		Settings_Cardly_PostcardFolder := SelectedFolder
	}
	Return
}

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
	; Sync SideKick_PS_Website to docs and push website only
	GuiControl, Settings:Show, DevWebProgress
	GuiControl, Settings:, DevWebProgress, 0
	GuiControl, Settings:Disable, DevPushWebBtn
	
	; Source is sibling folder ..\SideKick_PS_Website
	webSrc := A_ScriptDir . "\..\SideKick_PS_Website"
	webDst := A_ScriptDir . "\docs"
	
	; Step 1: Sync files (25%)
	GuiControl, Settings:, DevWebProgress, 25
	RunWait, %ComSpec% /c "copy /y "%webSrc%\*.html" "%webDst%\" >nul 2>&1 && copy /y "%webSrc%\*.xml" "%webDst%\" >nul 2>&1 && copy /y "%webSrc%\*.txt" "%webDst%\" >nul 2>&1 && copy /y "%webSrc%\CNAME" "%webDst%\" >nul 2>&1 && xcopy /s /y /q "%webSrc%\images\*" "%webDst%\images\" >nul 2>&1", , Hide
	
	; Step 2: Stage files (50%)
	GuiControl, Settings:, DevWebProgress, 50
	RunWait, %ComSpec% /c "cd /d "%A_ScriptDir%" && git add docs/* 2>nul", , Hide
	
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


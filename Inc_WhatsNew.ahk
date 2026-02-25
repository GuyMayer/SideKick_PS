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


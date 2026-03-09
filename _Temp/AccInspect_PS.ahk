#Requires AutoHotkey v1.1+
#SingleInstance Force

; ============================================
; ProSelect Click Inspector — Ctrl+Shift+]
; Hover over a pace button in ProSelect, then
; press the hotkey to log which control and
; position is under cursor. Click all 3 buttons
; to map them. Results append to a log file.
; ============================================

; Clear previous log
outFile := A_Temp . "\PS_ClickLog.txt"
FileDelete, %outFile%

ToolTip, Click Inspector loaded.`nHover over each pace button`nthen press Ctrl+Shift+]
SetTimer, RemoveTT, -4000
return

RemoveTT:
ToolTip
return

^+]::
	if !WinActive("ahk_exe ProSelect.exe") {
		MsgBox, 48, Click Inspector, ProSelect must be the active window.`nClick on ProSelect first.
		return
	}

	; Get mouse position (screen coords)
	CoordMode, Mouse, Screen
	MouseGetPos, mx, my, mWinHwnd, mCtlHwnd, 2
	; Also get ClassNN
	MouseGetPos,,, , mCtlNN, 1

	; Get window info
	WinGetTitle, winTitle, ahk_id %mWinHwnd%
	WinGetPos, wx, wy, ww, wh, ahk_id %mWinHwnd%

	; Get control position relative to parent window
	ControlGetPos, cx, cy, cw, ch, , ahk_id %mCtlHwnd%

	; Convert window client origin to screen coords
	VarSetCapacity(pt, 8, 0)
	NumPut(0, pt, 0, "Int")
	NumPut(0, pt, 4, "Int")
	DllCall("ClientToScreen", "Ptr", mWinHwnd, "Ptr", &pt)
	clientX := NumGet(pt, 0, "Int")
	clientY := NumGet(pt, 4, "Int")

	; Mouse relative to window client area
	mRelWinX := mx - clientX
	mRelWinY := my - clientY

	; Mouse relative to control
	mRelCtlX := mRelWinX - cx
	mRelCtlY := mRelWinY - cy

	; Percentage position within control
	pctX := cw > 0 ? Round((mRelCtlX / cw) * 100, 1) : 0
	pctY := ch > 0 ? Round((mRelCtlY / ch) * 100, 1) : 0

	; Distance from right/bottom edges of control
	fromRight := cw - mRelCtlX
	fromBottom := ch - mRelCtlY

	; Build output
	out := "=== Click Position Report ===`n"
	out .= "Window: " . winTitle . "`n"
	out .= "Window pos: " . wx . "," . wy . " size: " . ww . "x" . wh . "`n"
	out .= "Mouse screen: " . mx . "," . my . "`n"
	out .= "Mouse rel window: " . mRelWinX . "," . mRelWinY . "`n"
	out .= "Control ClassNN: " . mCtlNN . "`n"
	out .= "Control hwnd: " . mCtlHwnd . "`n"
	out .= "Control pos (in window): " . cx . "," . cy . " size: " . cw . "x" . ch . "`n"
	out .= "Mouse rel control: " . mRelCtlX . "," . mRelCtlY . "`n"
	out .= "From right edge: " . fromRight . "  From bottom: " . fromBottom . "`n"
	out .= "Mouse % in control: " . pctX . "% x, " . pctY . "% y`n"

	; Show tooltip
	ToolTip, %mCtlNN%`nrel: %mRelCtlX%`, %mRelCtlY%`npct: %pctX%`% x`, %pctY%`% y
	SetTimer, RemoveTT, -5000

	; Append to log
	outFile := A_Temp . "\PS_ClickLog.txt"
	FileAppend, %out%`n, %outFile%

	; After 3 entries, offer to open log
	FileRead, logContent, %outFile%
	StringReplace, logContent, logContent, === Click Position Report ===, === Click Position Report ===, UseErrorLevel
	clickCount := ErrorLevel
	if (clickCount >= 3) {
		ToolTip, %clickCount% clicks logged!`nOpening log...
		SetTimer, RemoveTT, -3000
		Run, notepad.exe %outFile%
	}
return

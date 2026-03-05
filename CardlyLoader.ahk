#Requires AutoHotkey v1.1+
#NoEnv
#SingleInstance Force
#NoTrayIcon
SetBatchLines, -1
SetWinDelay, -1   ; prevent 100ms delay on every WinExist() call — this caused the freeze

; CardlyLoader.ahk -- standalone loading GUI for Cardly preview
; Runs as a separate process so it stays animated while the main
; SideKick_PS script does blocking prep work (HTTP, file I/O).
;
; Usage:  CardlyLoader.ahk [DarkMode] [DPI_Scale]
;   DarkMode  = 1 (dark, default) or 0 (light)
;   DPI_Scale = e.g. 1.25 (default 1.0)
;
; Closes automatically when:
;   - "SideKick - Send Greeting Card" window appears
;   - "Cardly Loading" window is closed externally (WinClose from main script)
;   - 60 seconds timeout (safety)

; -- Parse args --
darkMode := 1
dpiScale := 1.0
if (A_Args.Length() >= 1)
    darkMode := A_Args[1]
if (A_Args.Length() >= 2)
    dpiScale := A_Args[2] + 0  ; force numeric

; -- Theme --
clBg       := darkMode ? "2D2D30" : "F5F5F5"
clTxt      := darkMode ? "E0E0E0" : "333333"
clAccent   := darkMode ? "E88D67" : "D97040"
clBorder   := darkMode ? "555555" : "BBBBBB"

; -- Layout (DPI-aware) --
borderPx  := Round(1 * dpiScale)
padOuter  := borderPx  ; border thickness
clW       := Round(320 * dpiScale)
clH       := Round(100 * dpiScale)
clMargin  := Round(20 * dpiScale)
clBarW    := clW - (clMargin * 2)
clBarH    := Round(6 * dpiScale)
clYBar    := Round(52 * dpiScale)
clYStatus := Round(68 * dpiScale)

; -- Build GUI with border --
; Outer window = border colour, inner panel = background colour
Gui, +AlwaysOnTop -SysMenu -Caption +ToolWindow
Gui, Color, %clBorder%
; Inner content panel (creates the border effect)
innerX := padOuter
innerY := padOuter
innerW := clW - (padOuter * 2)
innerH := clH - (padOuter * 2)
Gui, Add, Text, x%innerX% y%innerY% w%innerW% h%innerH% Background%clBg%

; Controls on top of inner panel
contentX := clMargin
Gui, Font, s12 c%clTxt%, Segoe UI
Gui, Add, Text, x%contentX% y%clMargin% w%clBarW% vLoadTitle BackgroundTrans, Preparing Cardly...
Gui, Add, Progress, x%contentX% y%clYBar% w%clBarW% h%clBarH% Background3C3C3C c%clAccent% vLoadBar Range0-100, 5
Gui, Font, s9 c%clTxt%
Gui, Add, Text, x%contentX% y%clYStatus% w%clBarW% vLoadStatus BackgroundTrans, Checking ProSelect...

; Centre on ProSelect window if available, otherwise default placement
WinGetPos, _psX, _psY, _psW, _psH, ahk_exe ProSelect.exe
if (_psW != "" && _psH != "") {
	clShowX := _psX + (_psW - clW) // 2
	clShowY := _psY + (_psH - clH) // 2
	Gui, Show, x%clShowX% y%clShowY% w%clW% h%clH%, Cardly Loading
} else {
	Gui, Show, w%clW% h%clH%, Cardly Loading
}

; -- Single animation + check timer (avoids timer collision) --
progress := 5
startTick := A_TickCount
checkCounter := 0
SetTimer, Tick, 80
return

; -- Combined tick: animate bar + check for exit conditions --
Tick:
    elapsed := (A_TickCount - startTick) / 1000

    ; Animate progress bar
    if (elapsed < 15) {
        progress := 5 + Round(83 * (elapsed / 15))
    } else {
        cycle := Mod(Round(elapsed * 2), 20)
        progress := (cycle <= 10) ? 85 + cycle : 95 - (cycle - 10)
    }
    GuiControl,, LoadBar, %progress%

    ; Animated dots
    dotCount := Mod(Round(elapsed * 2), 4)
    dots := ""
    Loop, %dotCount%
        dots .= "."

    ; Status text phases
    if (elapsed < 3)
        statusTxt := "Checking ProSelect" . dots
    else if (elapsed < 6)
        statusTxt := "Fetching client data" . dots
    else if (elapsed < 9)
        statusTxt := "Building preview" . dots
    else
        statusTxt := "Loading card preview" . dots
    GuiControl,, LoadStatus, %statusTxt%

    ; Check exit conditions every ~6th tick (~480ms) to keep animation smooth
    checkCounter++
    if (Mod(checkCounter, 6) = 0) {
        ; Cardly preview window appeared — done
        if WinExist("SideKick - Send Greeting Card") {
            SetTimer, Tick, Off
            Gui, Destroy
            ExitApp, 0
        }
        ; Safety timeout: 60 seconds
        if ((A_TickCount - startTick) > 60000) {
            SetTimer, Tick, Off
            Gui, Destroy
            ExitApp, 1
        }
        ; Our window was closed externally (main script WinClose)
        if !WinExist("Cardly Loading") {
            SetTimer, Tick, Off
            ExitApp, 0
        }
    }
return

GuiClose:
    ExitApp, 0
return

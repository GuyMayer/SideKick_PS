#Requires AutoHotkey v1.1+
#NoEnv
#SingleInstance Force
#NoTrayIcon
SetBatchLines, -1

; CardlyLoader.ahk — standalone loading GUI for Cardly preview
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

; ── Parse args ──────────────────────────────────────────────────────
darkMode := 1
dpiScale := 1.0
if (A_Args.Length() >= 1)
    darkMode := A_Args[1]
if (A_Args.Length() >= 2)
    dpiScale := A_Args[2] + 0  ; force numeric

; ── Theme ───────────────────────────────────────────────────────────
clBg     := darkMode ? "2D2D30" : "F5F5F5"
clTxt    := darkMode ? "E0E0E0" : "333333"
clAccent := darkMode ? "E88D67" : "D97040"

; ── Layout (DPI-aware) ──────────────────────────────────────────────
clW       := Round(320 * dpiScale)
clH       := Round(100 * dpiScale)
clMargin  := Round(20 * dpiScale)
clBarW    := clW - (clMargin * 2)
clBarH    := Round(6 * dpiScale)
clYBar    := Round(52 * dpiScale)
clYStatus := Round(68 * dpiScale)

; ── Build GUI ───────────────────────────────────────────────────────
Gui, +AlwaysOnTop -SysMenu +ToolWindow
Gui, Color, %clBg%
Gui, Font, s12 c%clTxt%, Segoe UI
Gui, Add, Text, x%clMargin% y%clMargin% w%clBarW% vLoadTitle, 📮 Preparing Cardly...
Gui, Add, Progress, x%clMargin% y%clYBar% w%clBarW% h%clBarH% Background3C3C3C c%clAccent% vLoadBar Range0-100, 5
Gui, Font, s9 c%clTxt%
Gui, Add, Text, x%clMargin% y%clYStatus% w%clBarW% vLoadStatus, Checking ProSelect...
Gui, Show, w%clW% h%clH%, Cardly Loading

; ── Animation timer ─────────────────────────────────────────────────
progress := 5
startTick := A_TickCount
SetTimer, AnimateBar, 120
SetTimer, CheckDone, 500
return

; ── Animate the progress bar smoothly ───────────────────────────────
AnimateBar:
    elapsed := (A_TickCount - startTick) / 1000  ; seconds
    ; Ease progress from 5→88 over first 15 seconds, then pulse 85-95
    if (elapsed < 15) {
        progress := 5 + Round(83 * (elapsed / 15))
    } else {
        ; Pulse between 85 and 95
        cycle := Mod(Round(elapsed * 2), 20)
        progress := (cycle <= 10) ? 85 + cycle : 95 - (cycle - 10)
    }
    dots := ""
    Loop, % Mod(Round(elapsed * 2), 4)
        dots .= "."
    GuiControl,, LoadBar, %progress%
    if (elapsed < 3)
        statusTxt := "Checking ProSelect" . dots
    else if (elapsed < 6)
        statusTxt := "Fetching client data" . dots
    else if (elapsed < 9)
        statusTxt := "Building preview" . dots
    else
        statusTxt := "Loading card preview" . dots
    GuiControl,, LoadStatus, %statusTxt%
return

; ── Check if Python window appeared or timeout ──────────────────────
CheckDone:
    ; Close when the Cardly preview window appears
    if WinExist("SideKick - Send Greeting Card") {
        SetTimer, AnimateBar, Off
        SetTimer, CheckDone, Off
        Gui, Destroy
        ExitApp, 0
    }
    ; Safety timeout: 60 seconds
    if ((A_TickCount - startTick) > 60000) {
        SetTimer, AnimateBar, Off
        SetTimer, CheckDone, Off
        Gui, Destroy
        ExitApp, 1
    }
    ; If our own window was closed externally (main script WinClose)
    if !WinExist("Cardly Loading") {
        SetTimer, AnimateBar, Off
        SetTimer, CheckDone, Off
        ExitApp, 0
    }
return

GuiClose:
    ExitApp, 0
return

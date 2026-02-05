#Requires AutoHotkey v1.1+
; ==================================================================================
; SK_LB_Hotkeys.ahk - LightBurn Hotkeys Module  
; Extracted from SideKick_LB_PubAI.ahk for modularization
; Contains: Mouse wheel navigation, XButton handlers, screen scrolling
; ==================================================================================

; These hotkeys require the following globals from main script:
; LB_DiaryWheel, AudioFB, LastScreen, SK_Active
; Functions: LB_Pollscreen(), ToolTipDisplay(), SetSystemCursor(), RestoreCursor()
;            ACCForToolbar(), Acc_Get(), Cord2Pos(), SystemCursor()
#IfWinActive Light Blue 2
^Wheeldown:: ;  LB Scrolling diary or screens
#IfWinActive Light Blue 2
XButton1::
MouseGetPos, xm, ym
if !(LB_DiaryWheel)
	return
CurrentScreen := LB_Pollscreen()
;traytip,,Current Screen %CurrentScreen%

ToolTipDisplay(CurrentScreen)
if (InStr(CurrentScreen,"Diary"))
{
	SetSystemCursor()
	;winactivate, Light Blue
	;WinWaitActive, Light Blue,,1
	XY :=
	ACC := "4.12.4.2.4.1.4.14.4"
	ACC := ACCForToolbar(ACC)
	XY := Acc_Get("Location", ACC, 0, "Light Blue")
	
	Cord2Pos(XY,x,y,w,h,xc,yc,xe,ye)
	
	MouseClick, l,Xc+3,Yc+3,1,0
	Sleep, 50
	MouseMove, xm,ym,0
	winactivate, Light Blue 2
	RestoreCursor()
}
return



#IfWinActive Light Blue 2
^Wheelup:: ; LB Scrolling diary or screens
#IfWinActive Light Blue 2
XButton2::
MouseGetPos, xm, ym
if !(LB_DiaryWheel)
	return
CurrentScreen := LB_Pollscreen()
;traytip,,Current Screen %CurrentScreen%
if (InStr(CurrentScreen,"Diary"))
{
	XY :=
	SetSystemCursor()
	;winactivate, Light Blue
	;WinWaitActive, Light Blue,,1
	ACC := "4.12.4.2.4.1.4.12.4"
	ACC := ACCForToolbar(ACC)
	XY := Acc_Get("Location",ACC, 0, "Light Blue")
	
	Cord2Pos(XY,x,y,w,h,xc,yc,xe,ye)
	
	MouseClick, l,Xc+3,Yc+3,1,0
	Sleep, 50
	MouseMove, xm,ym,0
	winactivate, Light Blue 2
	RestoreCursor()
	
}
Return

#IfWinActive Light Blue 2 ; LB screens wheel 
+Wheelup::
if AudioFB 
	SoundPlay %A_ScriptDir%\media\DullDing.wav
Send, ^]
sleep,300
; Force toolbar refresh after screen change
LastScreen := ""
SetTimer, LB_PlaceSideKickToolBar, -200
Return

#IfWinActive Light Blue 2
+WheelDown::
if AudioFB 
	SoundPlay %A_ScriptDir%\media\DullDing.wav
Send, ^[
sleep,300
; Force toolbar refresh after screen change
LastScreen := ""
SetTimer, LB_PlaceSideKickToolBar, -200
Return

#IfWinActive Light Blue 2 ; LB screens wheel 
~^MButton::
MouseGetPos, xm, ym
if !(LB_DiaryWheel)
	return
SK_Active := False
winactivate, Light Blue 2
WinWaitActive, Light Blue 2,1
sleep, 200
try XY := ACCForToolbar(Acc_Get("Location", "4.11.4.2.4.1.4.13.4", 0, "Light Blue"))
if !(XY) 
{	Tooltip, Error ~ No Location
	Return
}
Cord2Pos(XY,x,y,w,h,xc,yc,xe,ye)
if (AudioFB )
	SoundPlay %A_ScriptDir%\media\DullDing.wav
sleep, 300
SystemCursor(0)
winactivate, Light Blue 2
WinWaitActive, Light Blue 2
Mousemove, Xc,Yc,0
click
Sleep, 100
MouseMove, xm,ym,0
winactivate, Light Blue 2
#IfWinActive  ; Reset context

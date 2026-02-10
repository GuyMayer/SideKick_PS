#Requires AutoHotkey v1.1+


#Include %A_ScriptDir%\lib\BARCODER.ahk
#Include %A_ScriptDir%\lib\GDIP_all.ahk
Global 	PixelSize, test, MATRIX_TO_PRINT, FILE_PATH_AND_NAME,QRPath 

SaveQRFile(Data,Path,_Width :=200,_Clip :=false){	
	
	; Validate inputs
	if (Path = "") {
		MsgBox,262208,SideKick ~ QR Error,Cannot save QR code: Path is empty
		return
	}
	if (Data = "") {
		MsgBox,262208,SideKick ~ QR Error,Cannot save QR code: Data is empty
		return
	}
	
	FILE_PATH_AND_NAME := Path
	QRPath := Path
	PixelSize := 15
	test := Data
	splitpath, Path,FILE_NAME_TO_USE,PathDIR
	
	; Create directory if it doesn't exist
	if (!FileExist(PathDIR)) {
		FileCreateDir, %PathDIR%
		if (ErrorLevel) {
			MsgBox,262208,SideKick ~ Dev Info QR_CodeGen %A_LineNumber%,%PathDIR%`n`nFailed to create directory
			return
		}
	}
	/*
		IfExist,%FILE_PATH_AND_NAME%
		{
			MsgBox,262208,SideKick ~ Dev Info QR_CodeGen %A_LineNumber%,%FILE_PATH_AND_NAME%`nalready exists - try again
			Exit
		}
	*/
	if Sk_DevMode
		MsgBox,262208,SideKick ~ Dev Info QR_CodeGen %A_LineNumber%,QRData: `n%Data%`n`nFile Path: `n%FILE_PATH_AND_NAME%
	
	gosub, MakeQR
	;run, explore %PathDIR%
}

MakeQR:

MATRIX_TO_PRINT := BARCODER_GENERATE_QR_CODE(test)
if (MATRIX_TO_PRINT = 1)
{
	MsgBox,262208,SideKick ~ Dev Info %A_ScriptName% %A_LineNumber%, Error, The QR data is blank is blank.
	Exit
}

If MATRIX_TO_PRINT between 1 and 7
{
	MsgBox,262208,SideKick ~ Dev Info %A_ScriptName% %A_LineNumber%, ERROR CODE: %MATRIX_TO_PRINT% `n`nERROR CODE TABLE:`n`n1 - Input message is blank.`n2 - The Choosen Code Mode cannot encode all the characters in the input message.`n3 - Choosen Code Mode does not correspond to one of the currently indexed code modes (Automatic, numeric, alphanumeric or byte).`n4 - The choosen forced QR Matrix version (size) cannot encode the entire input message using the choosen ECL Code_Mode. Try forcing a higher version or choosing automated version selection (parameter value 0).`n5 - The input message is exceeding the QR Code standards maximum length for the choosen ECL and Code Mode.`n6 - Choosen Error Correction Level does not correspond to one of the standard ECLs (L, M, Q and H).`n7 - Forced version does not correspond to one of the QR Code standards versions.
	Exit
}

  ; Start gdi+ only if not already running (SideKick manages GDI+ globally)
  QR_OwnedGdip := false
  If !DllCall("GetModuleHandle", "str", "gdiplus", "Ptr")
  {
	If !pToken := Gdip_Startup()
	{
		MsgBox,262208,SideKick ~ Dev Info %A_ScriptName% %A_LineNumber%, Gdiplus failed to start. Please ensure you have gdiplus on your system
		ExitApp
	}
	QR_OwnedGdip := true
  }

pBitmap := Gdip_CreateBitmap((MATRIX_TO_PRINT.MaxIndex() + 8) * PixelSize, (MATRIX_TO_PRINT.MaxIndex() + 8) * PixelSize) ; Adding 8 pixels to the width and height here as a "quiet zone" for the image. This serves to improve the printed code readability. QR Code specs require the quiet zones to surround the whole image and to be at least 4 modules wide (4 on each side = 8 total width added to the image). Don't forget to increase this number accordingly if you plan to change the pixel size of each module.
G := Gdip_GraphicsFromImage(pBitmap)
Gdip_SetSmoothingMode(pBitmap, 3)
pBrush := Gdip_BrushCreateSolid(0xFFFFFFFF)
Gdip_FillRectangle(G, pBrush, 0, 0, (MATRIX_TO_PRINT.MaxIndex() + 8) * PixelSize, (MATRIX_TO_PRINT.MaxIndex() + 8) * PixelSize) ; Same as above.
Gdip_DeleteBrush(pBrush)

Loop % MATRIX_TO_PRINT.MaxIndex() ; Acess the Rows of the Matrix
{
	CURRENT_ROW := A_Index
	Loop % MATRIX_TO_PRINT[1].MaxIndex() ; Access the modules (Columns of the Rows).
	{
		CURRENT_COLUMN := A_Index
		If (MATRIX_TO_PRINT[CURRENT_ROW, A_Index] = 1)
		{
        ;Gdip_SetPixel(pBitmap, A_Index + 3, CURRENT_ROW + 3, 0xFF000000) ; Adding 3 to the current column and row to skip the quiet zones.
			Loop %PixelSize%
			{
				CURRENT_REDIMENSION_ROW := A_Index
				Loop %PixelSize%
				{
					Gdip_SetPixel(pBitmap, (CURRENT_COLUMN * PixelSize) + (3*PixelSize) - 1 + A_Index, (CURRENT_ROW * PixelSize) + (3*PixelSize) - 1 + CURRENT_REDIMENSION_ROW, 0xFF000000)
				}
			}
		}
		If (MATRIX_TO_PRINT[CURRENT_ROW, A_Index] = 0) ; White pixels need some more attention too when doing multi pixelwide images.
		{
			Loop %PixelSize%
			{
				CURRENT_REDIMENSION_ROW := A_Index
				Loop %PixelSize%
				{
					Gdip_SetPixel(pBitmap, (CURRENT_COLUMN * PixelSize) + (3*PixelSize) - 1 + A_Index, (CURRENT_ROW * PixelSize) + (3*PixelSize) -1 + CURRENT_REDIMENSION_ROW, 0xFFFFFFFF)
				}
			}
		}
	}
}
/*
	StringReplace, FILE_NAME_TO_USE, test, `" ; We can't use all the characters that byte mode can encode in the name of the file. So we are replacing them here (if they exist).
	FILE_PATH_AND_NAME := A_ScriptDir . "\" . SubStr(RegExReplace(FILE_NAME_TO_USE, "[\t\r\n\\\/\`:\`?\`*\`|\`>\`<]"), 1) ; Same as above.
	If (StrLen(FILE_PATH_AND_NAME)>252)
		FILE_PATH_AND_NAME:=SubStr(FILE_PATH_AND_NAME,1,252)
	FILE_PATH_AND_NAME:=FILE_PATH_AND_NAME . ".png"
*/


;Gdip_SetBitmapToClipboard(pBitmap)

FILE_PATH_AND_NAME := QRPath
GdipError := Gdip_SaveBitmapToFile(pBitmap, FILE_PATH_AND_NAME)
if GdipError {
	SplitPath, FILE_PATH_AND_NAME, , saveDir
	dirExists := FileExist(saveDir) ? "Yes" : "No"
	MsgBox,262208,SideKick ~ QR Save Error,Failed to save QR code (Error %GdipError%)`n`nPath: %FILE_PATH_AND_NAME%`nDirectory: %saveDir%`nDirectory exists: %dirExists%
}
Gdip_DisposeImage(pBitmap)
Gdip_DeleteGraphics(G)
; Only shutdown GDI+ if we started it ourselves
If (QR_OwnedGdip)
	Gdip_Shutdown(pToken)

Return


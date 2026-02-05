#Requires AutoHotkey v1.1+


#Include %A_ScriptDir%\lib\BARCODER.ahk
#Include %A_ScriptDir%\lib\GDIP_all.ahk
Global 	PixelSize, test, MATRIX_TO_PRINT, FILE_PATH_AND_NAME,QRPath 

SaveQRFile(Data,Path,_Width :=200,_Clip :=false){	
	
	FILE_PATH_AND_NAME := Path
	QRPath := path
	PixelSize := 15
	test := Data
	splitpath, Path,FILE_NAME_TO_USE,PathDIR
	
	ifNotExist, %PathDIR%
	{
		MsgBox,262208,SideKick ~ Dev Info QR_CodeGen %A_LineNumber%,%PathDIR%`n`nDirectory Unavailable
		Exit
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

  ; Start gdi+
If !pToken := Gdip_Startup()
{
	MsgBox,262208,SideKick ~ Dev Info %A_ScriptName% %A_LineNumber%, Gdiplus failed to start. Please ensure you have gdiplus on your system
	ExitApp
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


if _Clip
	Gdip_SetBitmapToClipboard(pBitmap)

FILE_PATH_AND_NAME := QRPath
GdipError := Gdip_SaveBitmapToFile(pBitmap, FILE_PATH_AND_NAME)
if GdipError
	MsgBox,262208,SideKick ~ Dev Info QR_CodeGen %A_LineNumber%,gDip File save ERROR %GdipError%

FileDestination := A_ScriptDir "\QR_Code.bmp"
convert_resize(FILE_PATH_AND_NAME,FileDestination,"k_width",_Width) ; make qr for lables mailmurge



Gdip_DisposeImage(pBitmap)
Gdip_DeleteGraphics(G)
Gdip_Shutdown(pToken)

Return


; https://www.autohotkey.com/board/topic/52033-convertresize-image-with-gdip-solved/

convert_resize(source_file,out_file,function="",value=1,color="0xff000000"){
	global
	If !pToken := Gdip_Startup()
	{
		MsgBox, 48, gdiplus error!, Gdiplus failed to start. Please ensure you have gdiplus on your system
		ExitApp
	}
	
	if (source_file="clipboard")
		pBitmapFile :=Gdip_CreateBitmapFromClipboard()
	else
		pBitmapFile :=Gdip_CreateBitmapFromFile(source_file)
	
	Width := Gdip_GetImageWidth(pBitmapFile), Height := Gdip_GetImageHeight(pBitmapFile)
	ratio=1
	if (function = "k_ratio")
	{
		ratio:=value
		w:=width*ratio
		h:=height*ratio
	}
	if (function = "k_width")
	{
		ratio:=value/width
		w:=width*ratio
		h:=height*ratio
	}
	if (function = "k_height")
	{
		ratio:=value/height
		w:=width*ratio
		h:=height*ratio
	}
	
	if (function = "k_fixed_width_height")
	{
		stringsplit,out,value,|
		wf:=out1
		hf:=out2
		
		if !wf or ! hf
		{
			msgbox error in value parameter for fixed width and height
			Gdip_Shutdown(pToken)  
			return
		}
		
		if (width>wf)
		{
			r1:=wf/width
			
			w:=wf
			h:=height*r1
			
			if (h>hf)
			{
				r2:=hf/h
				w:=w*r2
				h:=hf
			}
		}
		else
		{
			if (width<wf) and (height<hf)
			{
				w:=width
				h:=height
			}
			else
			{
				r1:=hf/height
				
				h:=hf
				w:=width*r1
				
				if (w>wf)
				{
					r2:=wf/w
					w:=wf
					h:=hf*r2
				}
			}
		}
	}
	
	if (function = "k_fixed_width_height")
		pBitmap := Gdip_CreateBitmap(wf, hf)
	else
		pBitmap := Gdip_CreateBitmap(w,h)
	
	G := Gdip_GraphicsFromImage(pBitmap)
	
	if (function = "k_fixed_width_height")
	{
		pbrush:=Gdip_BrushCreateSolid(color)
		Gdip_FillRectangle(G, pBrush, 0, 0, wf, hf)
		
		x:=floor((wf-w)/2)
		y:=floor((hf-h)/2)
	}
	else
	{
		x=0
		y=0
	}
	
	
	
	Gdip_DrawImage(G, pBitmapFile, x, y, w, h, 0, 0, Width, Height)
	Gdip_SaveBitmapToFile(pBitmap, out_file)
	if (function = "k_fixed_width_height")
		Gdip_DeleteBrush(pBrush)
	Gdip_DisposeImage(pBitmapFile)
	Gdip_DisposeImage(pBitmap)
	Gdip_DeleteGraphics(G)
	Gdip_Shutdown(pToken)
}
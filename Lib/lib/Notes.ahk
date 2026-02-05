#Requires AutoHotkey v1.1+
#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.

Notes_Plus(String,Delimiters)
{
	Delimiters_Pos := 1
	Loop, Parse, String
	{
		Notes_String .= Chr((Asc(A_LoopField) ^ Asc(SubStr(Delimiters,Delimiters_Pos,1))) + 15000)
		Delimiters_Pos += 1
		if (Delimiters_Pos > StrLen(Delimiters))
			Delimiters_Pos := 1
	}
	return Notes_String
}

Notes_Minus(String,Delimiters)
{
	Delimiters_Pos := 1
	Loop, Parse, String
	{
		Notes_String .= Chr(((Asc(A_LoopField) - 15000) ^ Asc(SubStr(Delimiters,Delimiters_Pos,1))))
		Delimiters_Pos += 1
		if (Delimiters_Pos > StrLen(Delimiters))
			Delimiters_Pos := 1
	}
	return Notes_String
}
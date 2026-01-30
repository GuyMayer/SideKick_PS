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

; Base64 Decode - returns raw bytes as string
Base64_Decode(B64) {
    VarSetCapacity(Bin, StrLen(B64) * 2)
    DllCall("Crypt32.dll\CryptStringToBinaryW"
        , "Str", B64            ; pszString
        , "UInt", 0             ; cchString (0 = auto)
        , "UInt", 1             ; dwFlags = CRYPT_STRING_BASE64
        , "Ptr", &Bin           ; pbBinary
        , "UIntP", Size := StrLen(B64) * 2  ; pcbBinary
        , "Ptr", 0              ; pdwSkip
        , "Ptr", 0)             ; pdwFlags
    return StrGet(&Bin, Size, "CP0")  ; Raw bytes as ANSI
}

; Base64 Encode - encodes string to Base64
Base64_Encode(Str) {
    VarSetCapacity(Bin, StrLen(Str) + 1)
    StrPut(Str, &Bin, "CP0")
    Size := StrLen(Str)
    ; Get required buffer size
    DllCall("Crypt32.dll\CryptBinaryToStringW"
        , "Ptr", &Bin           ; pbBinary
        , "UInt", Size          ; cbBinary
        , "UInt", 1             ; dwFlags = CRYPT_STRING_BASE64
        , "Ptr", 0              ; pszString (null to get size)
        , "UIntP", B64Size := 0) ; pcchString
    VarSetCapacity(B64, B64Size * 2)
    DllCall("Crypt32.dll\CryptBinaryToStringW"
        , "Ptr", &Bin
        , "UInt", Size
        , "UInt", 1
        , "Str", B64
        , "UIntP", B64Size)
    return RTrim(B64, "`r`n")  ; Remove trailing newlines
}

; Simple XOR decrypt (no +15000 offset)
SimpleXOR(String, Key) {
    result := ""
    keyLen := StrLen(Key)
    Loop, Parse, String
    {
        keyChar := SubStr(Key, Mod(A_Index - 1, keyLen) + 1, 1)
        result .= Chr(Asc(A_LoopField) ^ Asc(keyChar))
    }
    return result
}

; Decrypt Base64-encoded XOR-encrypted string
; Usage: DecryptB64(base64_string, Key)
DecryptB64(B64, Key) {
    decoded := Base64_Decode(B64)
    return SimpleXOR(decoded, Key)
}
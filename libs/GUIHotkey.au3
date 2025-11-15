
#include-once
#include "WindowsConstants.au3"
#include "WinAPI.au3"
#include "SendMessage.au3"
;#include "UDFGlobalID.au3"
;#AutoIt3Wrapper_Au3Check_Parameters=-d -w 1 -w 2 -w 3 -w 4 -w 5 -w 6

; #INDEX# =======================================================================================================================
; Title .........: GUIHotkey.au3
; AutoIt Version : 3.3.0.0+
; Minimum OS ....: Windows NT 3.51, Windows 95
; Language ......: English
; Description ...: Creation and management of hotkey controls.
; Author(s) .....: Mat
; Forum link ....: http://www.autoitscript.com/forum/index.php?showtopic=107965
; MSDN link .....: http://msdn.microsoft.com/en-us/library/bb775233(VS.85).aspx
; ===============================================================================================================================

; #VARIABLES# ===================================================================================================================
Global Const $__HOTKEYCONSTANT_ClassName = "msctls_hotkey32"
Global $Debug_HK
; ===============================================================================================================================

; #CONSTANTS# ===================================================================================================================

; Hotkey Messages. For internal use mainly.
Global Const $HKM_SETHOTKEY = $WM_USER + 1
Global Const $HKM_GETHOTKEY = $WM_USER + 2
Global Const $HKM_SETRULES = $WM_USER + 3

; Modifier keys.
Global Const $HOTKEYF_SHIFT = 0x01 ; SHIFT key
Global Const $HOTKEYF_CONTROL = 0x02 ; CONTROL key
Global Const $HOTKEYF_ALT = 0x04 ; ALT key
Global Const $HOTKEYF_EXT = 0x08 ; EXTENDED key

; Invalid Key Combinations. For use with _GUICtrlHotkey_SetRules second parameter $iCombInv
Global Const $HKCOMB_NONE = 0x01 ; Unmodified keys
Global Const $HKCOMB_S = 0x02 ; SHIFT
Global Const $HKCOMB_C = 0x04 ; CTRL
Global Const $HKCOMB_A = 0x08 ; ALT
Global Const $HKCOMB_SC = 0x10 ; SHIFT + CTRL
Global Const $HKCOMB_SA = 0x20 ; SHIFT + ALT
Global Const $HKCOMB_CA = 0x40 ; CTRL + ALT
Global Const $HKCOMB_SCA = 0x80 ; SHIFT + CTRL + ALT
; ===============================================================================================================================

; #CURRENT# =====================================================================================================================
; _GUICtrlHotkey_Create
; _GUICtrlHotkey_Delete
; _GUICtrlHotkey_GetHotkey
; _GUICtrlHotkey_GetHotkeyCode
; _GUICtrlHotkey_GetHotkeyName
; _GUICtrlHotkey_SetHotkey
; _GUICtrlHotkey_SetHotkeyCode
; _GUICtrlHotkey_SetHotkeyName
; _GUICtrlHotkey_SetRules
; ===============================================================================================================================

; #FUNCTION# ====================================================================================================================
; Name...........: _GUICtrlHotkey_Create
; Description ...: Creates a Hotkey control.
; Syntax.........: _GUICtrlHotkey_Create($hWnd, $vHotkey, $iX, $iY [, $iWidth [, $iHeight [, $iStyle [, $iExStyle]]] )
; Parameters ....: $hWnd        - A handle to the parent window.
;                  $iX          - Horizontal position of the control
;                  $iY          - Vertical position of the control
;                  $iWidth      - Control width (default is 200)
;                  $iHeight     - Control height (default is 20)
;                  $iStyle      - Control style:
;                  |Default: $WS_OVERLAPPED
;                  |Forced: $WS_CHILD, $WS_VISIBLE
;                  $iExStyle    - Control extended style
;                  |Default: $WS_EX_CLIENTEDGE
; Return values .: Success      - Handle to the control
;                  Failure      - Returns zero and sets the @error flag.
; Author ........: Mat
; Modified.......:
; Remarks .......:
; Related .......:
; Link ..........:
; Example .......: Yes
; ===============================================================================================================================

Func _GUICtrlHotkey_Create($hWnd, $iX, $iY, $iWidth = -1, $iHeight = -1, $iStyle = -1, $iStyleEx = -1)
	If (Not IsHWnd($hWnd)) Or (Not WinExists($hWnd)) Then Return SetError(1, 0, 0) ; hWnd is invalid

	If $iWidth = -1 Then $iWidth = 200
	If $iHeight = -1 Then $iHeight = 20
	If $iStyle = -1 Then $iStyle = $WS_OVERLAPPED
	If $iStyleEx = -1 Then $iStyleEx = $WS_EX_CLIENTEDGE

	$iStyle = BitOR($iStyle, $WS_VISIBLE, $WS_CHILD) ; forced styles

	Local $nCtrlID = 0
	Local $hRet = _WinAPI_CreateWindowEx($iStyleEx, $__HOTKEYCONSTANT_ClassName, "", $iStyle, $iX, $iY, $iWidth, $iHeight, $hWnd, $nCtrlID)
	If @error Then Return SetError(@error, @extended, 0)

	Return $hRet
EndFunc   ;==>_GUICtrlHotkey_Create

; #FUNCTION# ====================================================================================================================
; Name...........: _GUICtrlHotkey_Delete
; Description ...: Deletes the control and tidies up.
; Syntax.........: _GUICtrlHotkey_Delete($hHotkey)
; Parameters ....: $hHotkey     - A handle to the Hotkey control.
; Return values .: Success      - 1
;                  Failure      - 0
; Author ........: Mat
; Modified.......:
; Remarks .......: Should be called before exit, especially if the user sets his own fonts.
; Related .......: _GUICtrlHotkey_Create
; Link ..........:
; Example .......: Yes
; ===============================================================================================================================

Func _GUICtrlHotkey_Delete($hHotkey)
	If Not WinExists($hHotkey) Then Return SetError(1, 0, 0)

	; Release the font handle
	Local $hFont = _SendMessage($hHotkey, $WM_GETFONT)
	If $hFont = 0 Then Return SetExtended(1, 1)
	_WinAPI_DeleteObject($hFont)

	; Destroy the window
	_WinAPI_DestroyWindow($hHotkey)
	If @error Then Return SetError(@error, @extended, 0)

	Return 1
EndFunc ; ==> _GUICtrlHotkey_Delete

; #FUNCTION# ====================================================================================================================
; Name...........: _GUICtrlHotkey_GetHotkey
; Description ...: Gets the Send style code for the hotkey control
; Syntax.........: _GUICtrlHotkey_GetHotkey($hHotkey)
; Parameters ....: $hHotkey     - A handle to the Hotkey control.
; Return values .: Returns a string with the send syntax that can be used directly with functions such as HotkeySet.
; Author ........: Mat
; Modified.......:
; Remarks .......: See send for details on the return string
; Related .......: Send, HotkeySet, _GUICtrlHotkey_GetHotkeyCode
; Link ..........:
; Example .......: Yes
; ===============================================================================================================================

Func _GUICtrlHotkey_GetHotkey($hHotkey)
	If Not WinExists($hHotkey) Then Return SetError(1, 0, 0)

	Local $iHotkey = _GUICtrlhotkey_GetHotkeyCode($hHotkey)
	If $iHotkey = 0 Then Return ""

	Local $sRet = ""
	Local $iHiByte = BitShift($iHotkey, 8)
	Local $iLoByte = BitAND($iHotkey, 0xFF)

	If BitAND($iHiByte, $HOTKEYF_CONTROL) Then $sRet &= "^"
	If BitAND($iHiByte, $HOTKEYF_SHIFT) Then $sRet &= "+"
	If BitAND($iHiByte, $HOTKEYF_ALT) Then $sRet &= "!"

	If BitAND($iHiByte, $HOTKEYF_EXT) Then
		Switch $iLoByte
			Case 33
				$sRet &= "{PGUP}"
			Case 34
				$sRet &= "{PGDN}"
			Case 35
				$sRet &= "{END}"
			Case 36
				$sRet &= "{HOME}"
			Case 37
				$sRet &= "{LEFT}"
			Case 38
				$sRet &= "{UP}"
			Case 39
				$sRet &= "{RIGHT}"
			Case 40
				$sRet &= "{DOWN}"
			Case 45
				$sRet &= "{INS}"
			Case 111
				$sRet &= "{NUMPADDIV}"
			Case 144
				$sRet &= "{NUMLOCK}"
		EndSwitch
	Else
		Switch $iLoByte
			Case 0
			Case 20
				$sRet &= "{CAPSLOCK}"
			Case 96 To 105
				$sRet &= "{NUMPAD" & ($iLoByte - 96) & "}"
			Case 106
				$sRet &= "{NUMPADMULT}"
			Case 107
				$sRet &= "{NUMPADADD}"
			Case 109
				$sRet &= "{NUMPADSUB}"
			Case 110
				$sRet &= "{NUMPADDOT}"
			Case 112 To 123
				$sRet &= "{F" & ($iLoByte - 111) & "}"
			Case 145
				$sRet &= "{SCROLLLOCK}"
			Case 186
				$sRet &= ";"
			Case 187
				$sRet &= "="
			Case 128 To 191
				$sRet &= Chr($iLoByte - 144)
			Case 192
				$sRet &= "`"
			Case 222
				$sRet &= "'"
			Case 193 To 255
				$sRet &= Chr($iLoByte - 128)
			Case Else
				$sRet &= Chr($iLoByte)
		EndSwitch
	EndIf

	Return $sRet
EndFunc   ;==>_GUICtrlHotkey_GetHotkey

; #FUNCTION# ====================================================================================================================
; Name...........: _GUICtrlHotkey_GetHotkeyCode
; Description ...: Gets the virtual key code and modifier flags of a hot key from a hot key control.
; Syntax.........: _GUICtrlHotkey_GetHotkeyCode($hHotkey)
; Parameters ....: $hHotkey     - A handle to the Hotkey control.
; Return values .: Success      - Returns the virtual key code and modifier flags. The LOBYTE of the LOWORD is the virtual key code of the hot key.
;                  The HIBYTE of the LOWORD is the key modifier that specifies the keys that define a hot key combination.
;                  The modifier flags can be a combination of the following values.
;                  |$HOTKEYF_ALT: ALT key
;                  |$HOTKEYF_CONTROL: CONTROL key
;                  |$HOTKEYF_EXT: Extended key
;                  |$HOTKEYF_SHIFT: SHIFT key
;                  Failure      - The function will return zero if hotkey control shows "none", @Error is set to 1 if control does not exist.
; Author ........: Mat
; Modified.......:
; Remarks .......: To return more user friendly codes, see the _GUICtrlHotkey_GetHotkey function.
; Related .......:
; Link ..........: http://msdn.microsoft.com/en-us/library/bb775235(VS.85).aspx
; Example .......: Yes
; ===============================================================================================================================

Func _GUICtrlhotkey_GetHotkeyCode($hHotkey)
	If Not WinExists($hHotkey) Then Return SetError(1, 0, 0)

	Return _SendMessage($hHotkey, $HKM_GETHOTKEY, 0, 0)
EndFunc   ;==>_GUICtrlhotkey_GetHotkeyCode


Func _GuiCtrlHotkey_NameFromCode($iHotkey)
	If $iHotkey = 0 Then Return ""

	Local $sRet = ""
	Local $iHiByte = BitShift($iHotkey, 8)
	Local $iLoByte = BitAND($iHotkey, 0xFF)

	If BitAND($iHiByte, $HOTKEYF_CONTROL) Then $sRet &= "CTRL+"
	If BitAND($iHiByte, $HOTKEYF_SHIFT) Then $sRet &= "SHIFT+"
	If BitAND($iHiByte, $HOTKEYF_ALT) Then $sRet &= "ALT+"

	If BitAND($iHiByte, $HOTKEYF_EXT) Then
		Switch $iLoByte
			Case 33
				$sRet &= "PGUP"
			Case 34
				$sRet &= "PGDN"
			Case 35
				$sRet &= "END"
			Case 36
				$sRet &= "HOME"
			Case 37
				$sRet &= "LEFT"
			Case 38
				$sRet &= "UP"
			Case 39
				$sRet &= "RIGHT"
			Case 40
				$sRet &= "DOWN"
			Case 45
				$sRet &= "INSERT"
			Case 111
				$sRet &= "NUM DIVIDE"
			Case 144
				$sRet &= "NUM LOCK"
		EndSwitch
	Else
		Switch $iLoByte
			Case 0
			Case 20
				$sRet &= "CAPSLOCK"
			Case 96 To 105
				$sRet &= "NUM " & ($iLoByte - 96) & ""
			Case 106
				$sRet &= "NUMMULT" ; Seems to be an exception...
			Case 107
				$sRet &= "NUM PLUS"
			Case 109
				$sRet &= "NUM SUB"
			Case 110
				$sRet &= "NUM DECIMAL"
			Case 112 To 123
				$sRet &= "F" & ($iLoByte - 111)
			Case 145
				$sRet &= "SCROLL LOCK"
			Case 186
				$sRet &= ";"
			Case 187
				$sRet &= "="
			Case 128 To 191
				$sRet &= Chr($iLoByte - 144)
			Case 192
				$sRet &= "`"
			Case 222
				$sRet &= "'"
			Case 193 To 255
				$sRet &= Chr($iLoByte - 128)
			Case Else
				$sRet &= Chr($iLoByte)
		EndSwitch
	EndIf

	Return $sRet
EndFunc

; #FUNCTION# ====================================================================================================================
; Name...........: _GUICtrlHotkey_GetHotkeyName
; Description ...: Gets a User friendly string for the hotkey control
; Syntax.........: _GUICtrlHotkey_GetHotkeyName($hHotkey)
; Parameters ....: $hHotkey     - A handle to the Hotkey control.
; Return values .: Returns a string with the hotkey,
; Author ........: Mat
; Modified.......:
; Remarks .......:
; Related .......: _GUICtrlHotkey_GetHotkeyCode
; Link ..........:
; Example .......: Yes
; ===============================================================================================================================

Func _GUICtrlHotkey_GetHotkeyName($hHotkey)
	If Not WinExists($hHotkey) Then Return SetError(1, 0, 0)

	Local $iHotkey = _GUICtrlhotkey_GetHotkeyCode($hHotkey)
	$sRet = _GUICtrlHotkey_NameFromCode($iHotkey)

	Return $sRet
EndFunc   ;==>_GUICtrlHotkey_GetHotkeyName

; #FUNCTION# ====================================================================================================================
; Name...........: _GUICtrlHotkey_SetFont
; Description ...: Sets the font for the control
; Syntax.........: _GUICtrlHotkey_SetFont($hHotkey, $nSize [, $nWeight [, $nAttribute [, $sFace [, $nQuality = 2]]]] )
; Parameters ....: $hHotkey            - The control handle of the hotkey control. (NB: This function will work with other controls
;                                        but will through up an error if $Debug_HK is set to true. Comment out that line to convert.
; Return values .: Success             - 1
;                  Failure             - 0
; Author ........: Mat
; Modified.......:
; Remarks .......: To use font specific constants, FontConstants.au3 must be used. There are constants for weight and quality.
; Related .......:
; Link ..........: SetFont: http://msdn.microsoft.com/en-us/library/ms632642(VS.85).aspx
;                  CreateFont: http://msdn.microsoft.com/en-us/library/dd183499(VS.85).aspx
; Example .......: Yes
; ===============================================================================================================================

Func _GUICtrlHotkey_SetFont($hHotkey, $nSize, $nWeight = 400, $nAttribute = 0, $sFace = "Arial", $nQuality = 2)
	If Not WinExists($hHotkey) Then Return SetError(1, 0, 0)

	Local $hDC, $nHeight, $fItalic = False, $fUnderline = False, $fStrikeout = False, $hFont, $hFont_Old

	; Convert the size to height. (See CreateFont for MSDN example)
	$hDC = _WinAPI_GetDC($hHotkey)
	If @error Then Return SetError(@error, @extended, 0)
	$nHeight = _WinAPI_MulDiv($nSize, _WinAPI_GetDeviceCaps($hDC, 90), 72) ; 90 = LOGPIXELSY
	_WinAPI_ReleaseDC($hHotkey, $hDC)

	; convert attributes
	If BitAND($nAttribute, 2) Then $fItalic = True
	If BitAND($nAttribute, 4) Then $fUnderline = True
	If BitAND($nAttribute, 8) Then $fStrikeout = True

	; Get the handle for the old font
	$hFont_Old = _SendMessage($hHotkey, $WM_GETFONT)

	; Create the font
	$hFont = _WinAPI_CreateFont($nHeight, 0, 0, 0, $nWeight, $fItalic, $fUnderline, $fStrikeOut, 1, 0, 0, $nQuality, 0, $sFace)
	If @error Then Return SetError(@error, @extended, 0)

	; Send the message and clear up.
	_WinAPI_SetFont($hHotkey, $hFont, True)
	If @error Then
		_WinAPI_DeleteObject($hFont)
		Return SetError(@error, @extended, 0)
	EndIf

	; Delete the old font
	If $hFont_Old Then _WinAPI_DeleteObject($hFont_Old)

	Return 1
EndFunc   ;==>_GUIHotkey_SetFont


Func _GuiCtrlHotkey_CodeFromAutoItHK($sHotKey)
   Local $iHiByte = 0
	Local $iLoByte = 0

	$sHotkey = StringReplace($sHotkey, "^", "")
	If @extended Then $iHiByte += $HOTKEYF_CONTROL

	$sHotkey = StringReplace($sHotkey, "+", "")
	If @extended Then $iHiByte += $HOTKEYF_SHIFT

	$sHotkey = StringReplace($sHotkey, "!", "")
	If @extended Then $iHiByte += $HOTKEYF_ALT

	While 1
		Switch $sHotkey
			Case "{PGUP}"
				$iLoByte += 33
			Case "{PGDN}"
				$iLoByte += 34
			Case "{END}"
				$iLoByte += 35
			Case "{HOME}"
				$iLoByte += 36
			Case "{LEFT}"
				$iLoByte += 37
			Case "{UP}"
				$iLoByte += 38
			Case "{RIGHT}"
				$iLoByte += 39
			Case "{DOWN}"
				$iLoByte += 40
			Case "{INS}"
				$iLoByte += 45
			Case "{NUMPADDIV}"
				$iLoByte += 111
			Case "{NUMLOCK}"
				$iLoByte += 144
			Case Else
				Switch $sHotkey
					Case "{CAPSLOCK}"
						$iLoByte = 20
					Case "{NUMPADMULT}"
						$iLoByte = 106
					Case "{NUMPADADD}"
						$iLoByte = 107
					Case "{NUMPADSUB}"
						$iLoByte = 109
					Case "{NUMPADDOT}"
						$iLoByte = 110
					Case "{SCROLLLOCK}"
						$iLoByte = 145
					Case ";"
						$iLoByte = 186
					Case "="
						$iLoByte = 187
					Case "`"
						$iLoByte = 192
					Case "'"
						$iLoByte = 222
					Case Else
						While 1
							For $i = 16 To 47
								If $sHotkey = Chr($i) Then
									$iLoByte = $i + 144
									ExitLoop 2
								EndIf
							Next
							For $i = 65 To 127
								If $sHotkey = Chr($i) Then
									$iLoByte = $i
									ExitLoop 2
								EndIf
							Next
							For $i = 0 To 9
								If $sHotkey = "{numpad" & $i & "}" Then
									$iLoByte = $i + 96
									ExitLoop 2
								EndIf
							Next
							For $i = 1 To 12
								If $sHotkey = "{f" & $i & "}" Then
									$iLoByte = $i + 111
									ExitLoop 2
								EndIf
							Next
							$iLoByte = Asc($sHotkey)
							ExitLoop
						WEnd
				EndSwitch
				ExitLoop
		EndSwitch
		$iHiByte += $HOTKEYF_EXT
		ExitLoop
	 WEnd
	 $iRet = BitShift($iHiByte, -8) + $iLoByte
	 Return $iRet
EndFunc

; #FUNCTION# ====================================================================================================================
; Name...........: _GUICtrlHotkey_SetHotkey
; Description ...: Sets the hot key combination for a hot key control in send form.
; Syntax.........: _GUICtrlHotkey_SetHotkey($hHotkey, $sHotkey)
; Parameters ....: $hHotkey     - A handle to the Hotkey control.
;                  $sHotkey     - A string in send form showing the hotkey.
; Return values .: Success      - 1
;                  Failure      - 0
; Author ........: Mat
; Modified.......:
; Remarks .......:
; Related .......: _GUICtrlHotkey_GetHotkey, _GUICtrlHotkey_SetHotKeyCode
; Link ..........:
; Example .......: Yes
; ===============================================================================================================================

Func _GUICtrlHotkey_SetHotkey($hHotkey, $sHotkey)
	If Not WinExists($hHotkey) Then Return SetError(1, 0, 0)
	If $sHotkey = "" Then _ ; Set hotkey control to "none"
			Return _GUICtrlHotkey_SetHotkeyCode($hHotkey, 0)

	Return _GUICtrlHotkey_SetHotkeyCode($hHotkey, _GuiCtrlHotkey_CodeFromAutoItHK($sHotkey))
EndFunc   ;==>_GUICtrlHotkey_SetHotkey

; #FUNCTION# ====================================================================================================================
; Name...........: _GUICtrlHotkey_SetHotkeyCode
; Description ...: Sets the hot key combination for a hot key control.
; Syntax.........: _GUICtrlHotkey_SetHotkeyCode($hHotkey, $iHotkey)
; Parameters ....: $hHotkey     - A handle to the Hotkey control.
;                  $iHotkey     - A value to show the code for the hotkey.
; Return values .: Success      - 1
;                  Failure      - 0
; Author ........: Mat
; Modified.......:
; Remarks .......:
; Related .......: _GUICtrlHotkey_GetHotkeyCode, _GUICtrlHotkey_SetHotKey
; Link ..........: http://msdn.microsoft.com/en-us/library/bb775236(VS.85).aspx
; Example .......: Yes
; ===============================================================================================================================

Func _GUICtrlHotkey_SetHotkeyCode($hHotkey, $iHotkey)
	If Not WinExists($hHotkey) Then Return SetError(1, 0, 0)

	_SendMessage($hHotkey, $HKM_SETHOTKEY, $iHotkey, 0)
	Return 1
EndFunc   ;==>_GUICtrlHotkey_SetHotkeyCode

; #FUNCTION# ====================================================================================================================
; Name...........: _GUICtrlHotkey_SetHotkeyName
; Description ...: Sets the hot key combination for a hot key control in user friendly form.
; Syntax.........: _GUICtrlHotkey_SetHotkey($hHotkey, $sHotkey)
; Parameters ....: $hHotkey     - A handle to the Hotkey control.
;                  $sHotkey     - A string in the normal form form showing the hotkey. (SHIFT+V)
; Return values .: Success      - 1
;                  Failure      - 0
; Author ........: Mat
; Modified.......:
; Remarks .......:
; Related .......: _GUICtrlHotkey_GetHotkeyName, _GUICtrlHotkey_SetHotKeyCode
; Link ..........:
; Example .......: Yes
; ===============================================================================================================================

Func _GUICtrlHotkey_SetHotkeyName($hHotkey, $sHotkey)
	If Not WinExists($hHotkey) Then Return SetError(1, 0, 0)
	If $sHotkey = "" Then _ ; Set hotkey control to "none"
			Return _GUICtrlHotkey_SetHotkeyCode($hHotkey, 0)

	Local $iHiByte = 0
	Local $iLoByte = 0

	$sHotkey = StringStripWS($sHotkey, 8)

	$sHotkey = StringReplace($sHotkey, "CTRL+", "")
	If @extended Then $iHiByte += $HOTKEYF_CONTROL

	$sHotkey = StringReplace($sHotkey, "SHIFT+", "")
	If @extended Then $iHiByte += $HOTKEYF_SHIFT

	$sHotkey = StringReplace($sHotkey, "ALT+", "")
	If @extended Then $iHiByte += $HOTKEYF_ALT

	Switch $sHotkey
		Case "CAPSLOCK"
			$iLoByte = 20
		Case "NUMMULT"
			$iLoByte = 106
		Case "NUMPLUS"
			$iLoByte = 107
		Case "NUMSUB"
			$iLoByte = 109
		Case "NUMDECIMAL"
			$iLoByte = 110
		Case "SCROLLLOCK"
			$iLoByte = 145
		Case ";"
			$iLoByte = 186
		Case "="
			$iLoByte = 187
		Case "`"
			$iLoByte = 192
		Case "'"
			$iLoByte = 222
		Case Else
			While 1
				For $i = 16 To 47
					If $sHotkey = Chr($i) Then
						$iLoByte = $i + 144
						ExitLoop 2
					EndIf
				Next
				For $i = 65 To 127
					If $sHotkey = Chr($i) Then
						$iLoByte = $i
						ExitLoop 2
					EndIf
				Next
				For $i = 0 To 9
					If $sHotkey = "NUM" & $i Then
						$iLoByte = $i + 96
						ExitLoop 2
					EndIf
				Next
				For $i = 1 To 12
					If $sHotkey = "F" & $i Then
						$iLoByte = $i + 111
						ExitLoop 2
					EndIf
				Next
				$iLoByte = Asc($sHotkey)
				ExitLoop
			WEnd
	EndSwitch

	Return _GUICtrlHotkey_SetHotkeyCode($hHotkey, BitShift($iHiByte, -8) + $iLoByte)
EndFunc   ;==>_GUICtrlHotkey_SetHotkeyName

; #FUNCTION# ====================================================================================================================
; Name...........: _GUICtrlHotkey_SetRules
; Description ...: Defines the invalid combinations and the default modifier combination for a hot key control.
; Syntax.........: _GUICtrlHotkey_SetRules($hHotkey, $iCombInv, $iModInv)
; Parameters ....: $hHotkey     - A handle to the Hotkey control.
;                  $iCombInv   - A value to specify the invalid key combinations. Can be a combination of the following:
;                  |$HKCOMB_A: ALT
;                  |$HKCOMB_C: CTRL
;                  |$HKCOMB_CA: CTRL+ALT
;                  |$HKCOMB_NONE: Unmodified keys
;                  |$HKCOMB_S: SHIFT
;                  |$HKCOMB_SA: SHIFT+ALT
;                  |$HKCOMB_SC: SHIFT+CTRL
;                  |$HKCOMB_SCA: SHIFT+CTRL+ALT
;                  $iModInv    - The key combination to use when the user enters an invalid combination. Can be a combination of the following:
;                  |$HOTKEYF_ALT: ALT key
;                  |$HOTKEYF_CONTROL: CONTROL key
;                  |$HOTKEYF_EXT: Extended key
;                  |$HOTKEYF_SHIFT: SHIFT key
; Return values .: No return value.
; Author ........: Mat
; Modified.......:
; Remarks .......: For multiple values, you should use the BitOR function.
; Related .......:
; Link ..........: http://msdn.microsoft.com/en-us/library/bb775237(VS.85).aspx
; Example .......: Yes
; ===============================================================================================================================

Func _GUICtrlHotkey_SetRules($hHotkey, $iCombInv, $iModInv)
	If Not WinExists($hHotkey) Then Return SetError(1, 0, 0)

	_SendMessage($hHotkey, $HKM_SETRULES, $iCombInv, $iModInv)
EndFunc   ;==>_GUICtrlHotkey_SetRules


Func _GuiCtrlHotkey_NameFromAutoItHK($sHotkey)
   $iHotkey = _GuiCtrlHotkey_CodeFromAutoItHK($sHotkey)
   $sName = _GuiCtrlHotkey_NameFromCode($iHotkey)
   Return $sName
EndFunc

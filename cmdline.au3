#include-once
#include <Array.au3>
#include "MinimizeToTray.au3"

Func CmdlineHasParams()
	Return UBound($CmdLine) > 1
EndFunc

Func _GetTitleFromProcName($sProcessName)
	$aAllProcesses = ProcessList()

	Dim $aDetectedProcesses[0]
	For $i = 0 To UBound($aAllProcesses) - 1
		If $aAllProcesses[$i][0] == $sProcessName Then
			_ArrayAdd($aDetectedProcesses, $aAllProcesses[$i][1])
		EndIf
	Next

	$aAllWnds = WinList()

	Local $aDetectedWndTitles[0]
	For $i = 0 To UBound($aAllWnds) - 1
		$sWndTitle = $aAllWnds[$i][0]
		If $sWndTitle == "" Then
			ContinueLoop
		EndIf
		$sPID = WinGetProcess($sWndTitle)  ; Got PID
		For $j = 0 To UBound($aDetectedProcesses) - 1
			If $sPID == $aDetectedProcesses[$j] Then
				_ArrayAdd($aDetectedWndTitles, $sWndTitle)
			EndIf
		Next
	Next

	Return $aDetectedWndTitles
EndFunc

Func CmdlineValidateParams()
	; Can't hide and show at the same time
	If _CmdLine_FlagExists('H') And _CmdLine_FlagExists('S') Then
		MsgBox(0, "MTT", "Error. Can't hide and show window at the same time.", 10)
		Return False
	EndIf

	; No -p or invalid arg value for -p
	If Not _CmdLine_KeyExists('p') Or _CmdLine_Get('p') == "" Then
		MsgBox(0, "MTT", "Error. Need to specific a valid process name for '-p' opt.", 10)
		Return False
	EndIf

	Return True
EndFunc

Func CmdlineRunCliMode()
	If Not CmdlineHasParams() Then
		Return
	EndIf

	If Not CmdlineValidateParams() Then
		Return
	EndIf

	$sProcessNameToHide = _CmdLine_Get('p')
	$aDetectedWndTitles = _GetTitleFromProcName($sProcessNameToHide)

	For $i = 0 To UBound($aDetectedWndTitles) - 1
		If _CmdLine_FlagExists('H') Then
			WinSetState($aDetectedWndTitles[$i], '', @SW_HIDE)
		ElseIf _CmdLine_FlagExists('S') Then
			WinSetState($aDetectedWndTitles[$i], '', @SW_SHOW)
		EndIf
	Next
EndFunc


;CmdLine UDF
;https://www.autoitscript.com/forum/topic/169610-cmdline-udf-get-valueexistenceflag/
Func _CmdLine_Get($sKey, $mDefault = Null)
	For $i = 1 To $CmdLine[0]
		If $CmdLine[$i] = "/" & $sKey OR $CmdLine[$i] = "-" & $sKey OR $CmdLine[$i] = "--" & $sKey Then
			If $CmdLine[0] >= $i+1 Then
				Return $CmdLine[$i+1]
			EndIf
		EndIf
	Next
	Return $mDefault
EndFunc

Func _CmdLine_KeyExists($sKey)
	For $i = 1 To $CmdLine[0]
		If $CmdLine[$i] = "/" & $sKey OR $CmdLine[$i] = "-" & $sKey OR $CmdLine[$i] = "--" & $sKey Then
			Return True
		EndIf
	Next
	Return False
EndFunc

Func _CmdLine_ValueExists($sValue)
	For $i = 1 To $CmdLine[0]
		If $CmdLine[$i] = $sValue Then
			Return True
		EndIf
	Next
	Return False
EndFunc

Func _CmdLine_FlagEnabled($sKey)
	For $i = 1 To $CmdLine[0]
		If StringRegExp($CmdLine[$i], "\+([a-zA-Z]*)" & $sKey & "([a-zA-Z]*)") Then
			Return True
		EndIf
	Next
	Return False
EndFunc

Func _CmdLine_FlagDisabled($sKey)
	For $i = 1 To $CmdLine[0]
		If StringRegExp($CmdLine[$i], "\-([a-zA-Z]*)" & $sKey & "([a-zA-Z]*)") Then
			Return True
		EndIf
	Next
	Return False
EndFunc

Func _CmdLine_FlagExists($sKey)
	For $i = 1 To $CmdLine[0]
		If StringRegExp($CmdLine[$i], "(\+|\-)([a-zA-Z]*)" & $sKey & "([a-zA-Z]*)") Then
			Return True
		EndIf
	Next
	Return False
EndFunc

Func _CmdLine_GetValByIndex($iIndex, $mDefault = Null)
	If $CmdLine[0] >= $iIndex Then
		Return $CmdLine[$iIndex]
	Else
		Return $mDefault
	EndIf
EndFunc

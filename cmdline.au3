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
	If Not _CmdLine_KeyExists('p') And Not _CmdLine_KeyEXists('t') Then
		MsgBox(0, "MTT", "Error. Need to specify a process name to hide with -p or a window title with -t.", 10)
		Return False
	EndIf

	If _CmdLine_KeyExists('p') and _CmdLine_Get('p') == '' Then
		Return False
	EndIf

	If _CmdLine_KeyExists('t') and _CmdLine_Get('t') == '' Then
		Return False
	EndIf

	Return True
EndFunc

Func CmdlineShowHelp()
	MsgBox(64, "MTT", "Cmdline options: " & @CRLF _
	& "We may hide/show windows based on either their title or process name:" & @CRLF _
	& "-p <process name>" & @CRLF _
	& "-t <window title>" & @CRLF _
	& "-H: To hide all visible window created by a process." & @CRLF _
	& "-S: To show/restore previously hidden window." & @CRLF & @CRLF _
	& "Example for hiding all open firefox windows:" & @CRLF _
	& "Minimize.exe -p firefox.exe -H")
EndFunc

Func _GetAllPossibleWnds($sWndTitle)
	Local $aRet[0]
	$aAllWnds = WinList()
	For $i = 0 To UBound($aAllWnds) - 1
		If StringInStr($aAllWnds[$i][0], $sWndTitle) Then
			_ArrayAdd($aRet, $aAllWnds[$i][0])
		EndIf
	Next

	Return $aRet
EndFunc

Func CmdlineRunCliMode()
	If Not CmdlineHasParams() Then
		Return
	EndIf

	If _CmdLine_FlagExists('h') Then
		CmdlineShowHelp()
		Return
	EndIf

	If Not CmdlineValidateParams() Then
		Return
	EndIf

	If _CmdLine_KeyExists('p') Then
		$sProcessNameToHide = _CmdLine_Get('p')
		$aDetectedWndTitles = _GetTitleFromProcName($sProcessNameToHide)
	ElseIf _CmdLine_KeyExists('t') Then
		$sWndTitle = _CmdLine_Get('t')
		$aDetectedWndTitles = _GetAllPossibleWnds($sWndTitle)
	EndIf
	For $i = 0 To UBound($aDetectedWndTitles) - 1
		$sWndTitle = $aDetectedWndTitles[$i]
		If _CmdLine_FlagExists('H') Then
			WinSetState($sWndTitle, '', @SW_HIDE)
		ElseIf _CmdLine_FlagExists('S') Then
			WinSetState($sWndTitle, '', @SW_SHOW)
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

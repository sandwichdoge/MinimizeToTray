#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Icon=..\Icons\MTT.ico
#AutoIt3Wrapper_Outfile=..\..\Soft\MinimizeToTray.Exe
#AutoIt3Wrapper_Res_Comment=Minimize Windows to Tray
#AutoIt3Wrapper_Res_Description=Minimize Windows to Tray
#AutoIt3Wrapper_Res_Fileversion=1.4
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
;//Minimize to tray
;//sandwichdoge@gmail.com
#include <Array.au3>
$sVersion = "1.4"

HotKeySet("!{f1}", "HideCurrentWnd")
HotKeySet("!{f2}", "RestoreLastWnd")
HotKeySet("{f10}", "RestoreAllWnd")
HotKeySet("+{esc}", "ExitS")


;//$aHiddenWndList = Array that contains handles of all hidden windows.
;//$aTrayItemHandles = Array that contains tray items that indicate names of hidden windows.
;//Elements of these 2 arrays must be perfectly in sync with each other.
Global $aHiddenWndList[0] = [], $aTrayItemHandles[0] = []
Global $hLastWnd;//Handle of the last window that was hidden

Opt('TrayAutoPause', 0)
Opt('TrayMenuMode', 3)

;$hTrayMenuShowSelectWnd = TrayCreateMenu("Restore Window")
$hTrayRestoreAllWnd = TrayCreateItem("Restore all Windows (F10)");, $hTrayMenuShowSelectWnd)
TrayCreateItem("");//Create a straight line
$hTrayHelp = TrayCreateItem("Quick manual")
$hTrayExit = TrayCreateItem("Exit (Shift+Esc)")
TrayTip("MinimizeToTray " & $sVersion, "Press [Alt+F1] to hide currently active Window." & @CRLF _
		 & "Press [Alt+F2] to restore last hidden Window." & @CRLF _
		 & "Hidden Windows are stored in MTT tray icon.", 5)

;//Legacy windows from last run are loaded on startup if available, this should only happen if MTT was unexpectedly closed while some windows were still hidden.
$aPrevWndTitleList = FileReadToArray("MTTlog.txt")
If Not @error Then
	For $i = 0 To UBound($aPrevWndTitleList) - 1
		If StringLen($aPrevWndTitleList[$i]) >= 1 Then
			$hTrayWnd = TrayCreateItem($aPrevWndTitleList[$i] & " - Legacy", -1, 0);, $hTrayMenuShowSelectWnd)
			_ArrayAdd($aTrayItemHandles, $hTrayWnd)
			_ArrayAdd($aHiddenWndList, WinGetHandle($aPrevWndTitleList[$i]))
		EndIf
	Next
	If UBound($aTrayItemHandles) Then
		TrayTip("", "You have " & UBound($aTrayItemHandles) & " legacy Window(s) waiting to be restored!", 4)
	EndIf
EndIf

;//Main Loop
While 1
	$hTrayMsg = TrayGetMsg()
	Switch $hTrayMsg
		Case $hTrayRestoreAllWnd
			RestoreAllWnd()
		Case $hTrayExit
			ExitS()
		Case $hTrayHelp
			Help()
	EndSwitch
	For $i = 0 To UBound($aTrayItemHandles) - 1
		If $hTrayMsg = $aTrayItemHandles[$i] Then
			RestoreWnd($aHiddenWndList[$i])
			ExitLoop
		EndIf
	Next
	Sleep(10)
WEnd


Func RestoreLastWnd()
	;//Restore last hidden window.
	RestoreWnd($hLastWnd)
EndFunc   ;==>RestoreLastWnd

Func RestoreWnd($hfWnd)
	Local $nIndex = _ArraySearch($aHiddenWndList, $hfWnd)
	WinSetState($hfWnd, "", @SW_SHOW)
	If $nIndex >= 0 Then
		TrayItemDelete($aTrayItemHandles[$nIndex])
		_ArrayDelete($aHiddenWndList, $nIndex)
		_ArrayDelete($aTrayItemHandles, $nIndex)
		;//Delete window's name from log file
		$sLog = FileRead("MTTlog.txt")
		$sLogN = StringReplace($sLog, WinGetTitle($hfWnd), "")
		FileWrite(FileOpen("MTTlog.txt", 2), $sLogN)
	EndIf
EndFunc   ;==>RestoreWnd

Func HideWnd($hfWnd)
	WinSetState($hfWnd, "", @SW_HIDE)
	_ArrayAdd($aHiddenWndList, $hfWnd)
	$hTrayWnd = TrayCreateItem(WinGetTitle($hfWnd), -1, 0);, $hTrayMenuShowSelectWnd)
	_ArrayAdd($aTrayItemHandles, $hTrayWnd)
	;//Write window's name to log file for legacy restoration in case of unexpected crash.
	FileWrite("MTTlog.txt", WinGetTitle($hfWnd) & @CRLF)
	$hLastWnd = $hfWnd
EndFunc   ;==>HideWnd

Func HideCurrentWnd()
	;//Hide currently active window.
	HideWnd(WinGetHandle("[ACTIVE]"))
EndFunc   ;==>HideCurrentWnd

Func RestoreAllWnd()
	;//Show all windows hidden during this session.
	Local $aTmp = $aHiddenWndList
	For $i = 0 To UBound($aTmp) - 1
		RestoreWnd($aTmp[$i])
	Next
	FileDelete("MTTlog.txt")
EndFunc   ;==>RestoreAllWnd

Func Help()
	MsgBox(64, "MinimizeToTray " & $sVersion, "Press [Alt+F1] to hide currently active Window." & @CRLF _
			 & "Press [Alt+F2] to restore last hidden Window." & @CRLF _
			 & "Hidden Windows are stored in MTT tray icon." & @CRLF _
			 & "If the window you want to hide is elevated to administrative level, you must run MTT as Administrator." & @CRLF & @CRLF _
			 & "sandwichdoge@gmail.com")
EndFunc   ;==>Help

Func ExitS()
	RestoreAllWnd()
	Exit
EndFunc   ;==>ExitS

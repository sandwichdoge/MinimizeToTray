#include <Array.au3>
$sVersion = "1.1"

HotKeySet("!{f2}", "HideCurrentWnd")
HotKeySet("!{f1}", "RestoreLastWnd")
HotKeySet("{f10}", "RestoreAllWnd")
HotKeySet("+{esc}", "ExitS")


;//$aHiddenWndList = Array that contains handles of all hidden windows.
;//$aTrayItems_Wnd = Array that contains handles of tray items that indicate names of hidden windows.
;//Elements of these 2 arrays must be perfectly in sync with each other.
Global $aHiddenWndList[0] = [], $aTrayItems_Wnd[0] = []
Global $hLastWnd;//Handle of the last window that was hidden

Opt('TrayAutoPause', 0)
Opt('TrayMenuMode', 3)

;$hTrayMenuShowSelectWnd = TrayCreateMenu("Restore Window")
$hTrayRestoreAllWnd = TrayCreateItem("Restore all Windows (F10)");, $hTrayMenuShowSelectWnd)
TrayCreateItem("");//Create a straight line
$hTrayHelp = TrayCreateItem("Quick manual")
$hTrayExit = TrayCreateItem("Exit (Shift+Esc)")

;//Legacy windows from last run are loaded on startup if available, this should only happen if MTT was unexpectedly closed while some windows were still hidden.
$aPrevWndTitleList = FileReadToArray("MTTlog.txt")
For $i = 0 To UBound($aPrevWndTitleList) - 1
	$hTrayWnd = TrayCreateItem($aPrevWndTitleList[$i] & " - Legacy", -1, 0);, $hTrayMenuShowSelectWnd)
	_ArrayAdd($aTrayItems_Wnd, $hTrayWnd)
	_ArrayAdd($aHiddenWndList, WinGetHandle($aPrevWndTitleList[$i]))
Next
If UBound($aPrevWndTitleList) Then
	TrayTip("", "You have " & UBound($aPrevWndTitleList) & " legacy Window(s) waiting to be restored!", 4)
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
	For $i = 0 To UBound($aTrayItems_Wnd) - 1
		If $hTrayMsg = $aTrayItems_Wnd[$i] Then
			RestoreWnd($aHiddenWndList[$i])
			ExitLoop
		EndIf
	Next
	Sleep(10)
WEnd


Func RestoreLastWnd()
	;//Restore last hidden window.
	RestoreWnd($hLastWnd)
EndFunc

Func RestoreWnd($hfWnd)
	Local $nIndex = _ArraySearch($aHiddenWndList, $hfWnd)
	WinSetState($hfWnd, "", @SW_SHOW)
	If $nIndex >= 0 Then
		TrayItemDelete($aTrayItems_Wnd[$nIndex])
		_ArrayDelete($aHiddenWndList, $nIndex)
		_ArrayDelete($aTrayItems_Wnd, $nIndex)
		;//Delete window's name from log file
		$sLog = FileRead("MTTlog.txt")
		$sLogN = StringReplace($sLog, WinGetTitle($hfWnd), "")
		FileWrite(FileOpen("MTTlog.txt", 2), $sLogN)
	EndIf
EndFunc

Func HideWnd($hfWnd)
	WinSetState($hfWnd, "", @SW_HIDE)
	_ArrayAdd($aHiddenWndList, $hfWnd)
	$hTrayWnd = TrayCreateItem(WinGetTitle($hfWnd), -1, 0);, $hTrayMenuShowSelectWnd)
	_ArrayAdd($aTrayItems_Wnd, $hTrayWnd)
	;//Write window's name to log file for legacy restoration in case of unexpected crash.
	FileWrite("MTTlog.txt", WinGetTitle($hfWnd) & @CRLF)
	$hLastWnd = $hfWnd
EndFunc

Func HideCurrentWnd()
	;//Hide currently active window.
	HideWnd(WinGetHandle("[ACTIVE]"))
EndFunc

Func RestoreAllWnd()
	;//Show all windows hidden during this session.
	For $i = 0 To UBound($aHiddenWndList) - 1
		WinSetState($aHiddenWndList[$i], "", @SW_SHOW)
	Next
	For $i = 0 To UBound($aTrayItems_Wnd) - 1
		TrayItemDelete($aTrayItems_Wnd[$i])
		_ArrayDelete($aHiddenWndList, $i)
	Next
	Global $aTrayItems_Wnd[0] = []
	FileDelete("MTTlog.txt")
EndFunc

Func Help()
	MsgBox(64, "MinimizeToTray " & $sVersion, "Press [Alt+F2] to hide currently active Window." & @CRLF _
	& "Press [Alt+F1] to restore last hidden Window." & @CRLF _
	& "Hidden Windows are stored in MTT tray icon." & @CRLF & @CRLF _
	& "evorlet@gmail.com")
EndFunc

Func ExitS()
	RestoreAllWnd()
	Exit
EndFunc

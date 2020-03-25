;//Minimize to tray
;//sandwichdoge@gmail.com


#include <Misc.au3>
#include <Array.au3>
#include <WinAPI.au3>

Global Const $VERSION = "1.9"

;//Exit if MTT is already running.
If _Singleton("MTT", 1) = 0 Then
	TrayTip("MinimizeToTray " & $VERSION, "An instance of MinimizeToTray is already running.", 2)
	Sleep(2000)
	Exit
EndIf

Opt('TrayAutoPause', 0)
Opt('TrayMenuMode', 3)

HotKeySet("!{f1}", "HideCurrentWnd")
HotKeySet("!{f2}", "RestoreLastWnd")
HotKeySet("!{f4}", "HandleAltF4")
HotKeySet("{f10}", "RestoreAllWnd")
HotKeySet("+{esc}", "ExitS")
OnAutoItExitRegister("ExitS")


;//$aHiddenWndList = Array that contains handles of all hidden windows.
;//$aTrayItemHandles = Array that contains tray items that indicate names of hidden windows.
;//Elements of these 2 arrays must be perfectly in sync with each other.
Global $aHiddenWndList[0] = [], $aTrayItemHandles[0] = []
Global $hLastWnd ;//Handle of the last window that was hidden
Global $g_hTempParentGUI[48], $g_aTempWindowSize[48][2], $g_nIndex = 0 ;//Method 1 of hiding window
Global $bAltF4EndProcess = False, $bRestoreOnExit = False
Global $SEMAPHORE = 1


;$hTrayMenuShowSelectWnd = TrayCreateMenu("Restore Window")
$hTrayRestoreAllWnd = TrayCreateItem("Restore all Windows (F10)") ;, $hTrayMenuShowSelectWnd)
TrayCreateItem("") ;//Create a straight line
$opt = TrayCreateMenu("Options")
$hTrayAltF4EndProcess = TrayCreateItem("Alt-F4 forces window's process to exit", $opt)
$hTrayRestoreOnExit = TrayCreateItem("Restore hidden windows on exit", $opt)
$hTrayHelp = TrayCreateItem("Quick manual")
$hTrayExit = TrayCreateItem("Exit (Shift+Esc)")

TrayTip("MinimizeToTray " & $VERSION, "Press [Alt+F1] to hide currently active Window." & @CRLF _
		 & "Press [Alt+F2] to restore last hidden Window." & @CRLF _
		 & "Hidden Windows are stored in MTT tray icon.", 5)

RestoreLastShutdownWindows()

;//Main Loop
While 1
	$hTrayMsg = TrayGetMsg()
	Switch $hTrayMsg
		Case $hTrayAltF4EndProcess
			ToggleOpt($bAltF4EndProcess, $hTrayAltF4EndProcess)
		Case $hTrayRestoreOnExit
			ToggleOpt($bRestoreOnExit, $hTrayRestoreOnExit)
		Case $hTrayRestoreAllWnd
			RestoreAllWnd()
		Case $hTrayExit
			ExitS()
		Case $hTrayHelp
			Help()
	EndSwitch
	
	For $i = 0 To UBound($aTrayItemHandles) - 1
		If $hTrayMsg = $aTrayItemHandles[$i] Then
			If $i < UBound($aHiddenWndList) Then
				RestoreWnd($aHiddenWndList[$i])
			EndIf
			ExitLoop
		EndIf
	Next
WEnd


Func ToggleOpt(ByRef $bFlag, ByRef $hTrayItem)
	$bFlag = Not $bFlag
	
	Local $nTrayItemState = TrayItemGetState($hTrayItem)
	If BitAND($nTrayItemState, 1) Then ;//CHECKED
		TrayItemSetState($hTrayItem, 4)
	ElseIf BitAND($nTrayItemState, 4) Then
		TrayItemSetState($hTrayItem, 1)
	EndIf

EndFunc   ;==>ToggleOpt


Func RestoreLastWnd()
	;//Restore window from top of hidden windows stack.
	If UBound($aHiddenWndList) Then
		RestoreWnd($aHiddenWndList[UBound($aHiddenWndList) - 1])
	EndIf
EndFunc   ;==>RestoreLastWnd


Func RestoreWnd($hfWnd)
	If ($SEMAPHORE == 0) Then
		Return
	EndIf
	$SEMAPHORE = 0
	Local $nIndex = _ArraySearch($aHiddenWndList, $hfWnd)
	WinSetState($hfWnd, "", @SW_SHOW)
	If $nIndex >= 0 Then
		If $nIndex < UBound($aTrayItemHandles) Then
			TrayItemDelete($aTrayItemHandles[$nIndex])
			_ArrayDelete($aTrayItemHandles, $nIndex)
		EndIf
		If $nIndex < UBound($aHiddenWndList) Then
			_ArrayDelete($aHiddenWndList, $nIndex)
		EndIf
		;//Delete window's name from log file
		$sLog = FileRead("MTTlog.txt")
		$sLogN = StringReplace($sLog, WinGetTitle($hfWnd), "")
		$fd = FileOpen("MTTlog.txt", 2)
		FileWrite($fd, $sLogN)
		FileClose($fd)
	EndIf
	$SEMAPHORE = 1
EndFunc   ;==>RestoreWnd


Func HideWnd($hfWnd, $nMethod = 0)
	WinSetState($hfWnd, "", @SW_HIDE) ;Traditional WinSetState method
	
	_ArrayAdd($aHiddenWndList, $hfWnd)
	$hTrayWnd = TrayCreateItem(WinGetTitle($hfWnd), -1, 0) ;, $hTrayMenuShowSelectWnd)
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
	FileDelete("MTTlog.txt") ;//Lazy way to delete legacy window list in log file.
EndFunc   ;==>RestoreAllWnd


Func CloseWnd()
	ProcessClose(WinGetProcess(WinGetHandle("[ACTIVE]")))
EndFunc   ;==>CloseWnd


Func HandleAltF4()
	If $bAltF4EndProcess = True Then
		CloseWnd()
	Else
		HotKeySet("!{f4}")
		Send("!{f4}")
		HotKeySet("!{f4}", "HandleAltF4")
	EndIf
EndFunc   ;==>HandleAltF4

Func RestoreLastShutdownWindows()
	;//Legacy windows from last run are loaded on startup if available,
	;//this should only happen if MTT was unexpectedly closed while some windows were still hidden.
	$aPrevWndTitleList = FileReadToArray("MTTlog.txt")
	If Not @error Then
		For $i = 0 To UBound($aPrevWndTitleList) - 1
			If StringLen($aPrevWndTitleList[$i]) >= 1 Then
				$hTrayWnd = TrayCreateItem($aPrevWndTitleList[$i] & " - Legacy", -1, 0) ;, $hTrayMenuShowSelectWnd)
				_ArrayAdd($aTrayItemHandles, $hTrayWnd)
				_ArrayAdd($aHiddenWndList, WinGetHandle($aPrevWndTitleList[$i]))
			EndIf
		Next
		
		If UBound($aTrayItemHandles) Then
			TrayTip("", "You have " & UBound($aTrayItemHandles) & " legacy Window(s) waiting to be restored!", 4)
		EndIf
	EndIf
EndFunc   ;==>RestoreLastShutdownWindows

Func Help()
	MsgBox(64, "MinimizeToTray " & $VERSION, "Press [Alt+F1] to hide currently active Window." & @CRLF _
			 & "Press [Alt+F2] to restore last hidden Window." & @CRLF _
			 & "Hidden Windows are stored in MTT tray icon." & @CRLF _
			 & "If the window you want to hide is elevated to administrative level, you must run MTT as Administrator." & @CRLF & @CRLF _
			 & "sandwichdoge@gmail.com")
EndFunc   ;==>Help


Func ExitS()
	If $bRestoreOnExit Then
		RestoreAllWnd()
	EndIf
	Exit
EndFunc   ;==>ExitS

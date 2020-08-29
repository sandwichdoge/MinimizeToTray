;//Minimize to tray
;//sandwichdoge@gmail.com

#include <Misc.au3>
#include <Array.au3>
#include <WinAPI.au3>
#include <GuiConstantsEx.au3>
#include <GUIHotkey.au3>

Global Const $VERSION = "2.0"
Global Const $CONFIG_INI = "MTTconf.ini"

Global Const $DEFAULT_HIDE_WND_HK = "!{f1}"
Global Const $DEFAULT_RESTORE_LAST_WND_HK = "!{f2}"
Global Const $DEFAULT_RESTORE_ALL_WND_HK = "{f10}"

;//Exit if MTT is already running.
If _Singleton("MTT", 1) = 0 Then
	TrayTip("MinimizeToTray " & $VERSION, "An instance of MinimizeToTray is already running.", 2)
	Sleep(2000)
	Exit
EndIf

Opt('TrayAutoPause', 0)
Opt('TrayMenuMode', 3)

; Initialize
; Read ini config file, set current global hotkeys
Global $sHK_HideWnd = IniRead($CONFIG_INI, "Hotkeys", "HIDE_WINDOW", $DEFAULT_HIDE_WND_HK)
Global $sHK_RestoreLastWnd = IniRead($CONFIG_INI, "Hotkeys", "RESTORE_LAST_WINDOW", $DEFAULT_RESTORE_LAST_WND_HK)
Global $sHK_RestoreAllWnd = IniRead($CONFIG_INI, "Hotkeys", "RESTORE_ALL_WINDOWS", $DEFAULT_RESTORE_ALL_WND_HK)

Global $sRestoreAllWndsOnExit = IniRead($CONFIG_INI, "Extra", "RESTORE_ALL_WINDOWS_ON_EXIT", "False")
Global $sAltF4EndProcess = IniRead($CONFIG_INI, "Extra", "ALT_F4_FORCE_END_PROCESS", "False")

HotKeySet($sHK_HideWnd, "HideCurrentWnd")
HotKeySet($sHK_RestoreLastWnd, "RestoreLastWnd")
HotKeySet("!{f4}", "HandleAltF4")
HotKeySet($sHK_RestoreAllWnd, "RestoreAllWnd")
HotKeySet("+{esc}", "ExitS")
OnAutoItExitRegister("ExitS")


;//$aHiddenWndList = Array that contains handles of all hidden windows.
;//$aTrayItemHandles = Array that contains tray items that indicate names of hidden windows.
;//Elements of these 2 arrays must be perfectly in sync with each other.
Global $aHiddenWndList[0] = [], $aTrayItemHandles[0] = []
Global $hLastWnd ;//Handle of the last window that was hidden
Global $g_hTempParentGUI[48], $g_aTempWindowSize[48][2], $g_nIndex = 0 ;//Method 1 of hiding window
Global $bAltF4EndProcess = TextToBool($sAltF4EndProcess)
Global $bRestoreOnExit = TextToBool($sRestoreAllWndsOnExit)
Global $SEMAPHORE = 1


; == GUI Creation Section ==
Global $hGUIHotkeyEdit = GUICreate("Edit MinimizeToTray Hotkeys", 300, 300)
Global $hGUIHotkeyEdit_Btn_OK = GUICtrlCreateButton("OK", 30, 260, 80, 24)
Global $hGUIHotkeyEdit_Btn_Default = GUICtrlCreateButton("Default", 170, 260, 80, 24)
GUICtrlCreateLabel("Hide active window", 10, 10)
Global $hGUIHotkeyEdit_HK_HideWnd = _GUICtrlHotkey_Create($hGUIHotkeyEdit, 8, 30)
_GUICtrlHotkey_SetRules($hGUIHotkeyEdit_HK_HideWnd, $HKCOMB_NONE, $HOTKEYF_ALT)
_GUICtrlHotkey_SetHotkey($hGUIHotkeyEdit_HK_HideWnd, $sHK_HideWnd)

GUICtrlCreateLabel("Restore last window", 10, 60)
Global $hGUIHotkeyEdit_HK_RestoreLastWnd = _GUICtrlHotkey_Create($hGUIHotkeyEdit, 8, 80)
_GUICtrlHotkey_SetRules($hGUIHotkeyEdit_HK_RestoreLastWnd, $HKCOMB_NONE, $HOTKEYF_ALT)
_GUICtrlHotkey_SetHotkey($hGUIHotkeyEdit_HK_RestoreLastWnd, $sHK_RestoreLastWnd)

GUICtrlCreateLabel("Restore all hidden windows", 10, 110)
Global $hGUIHotkeyEdit_HK_RestoreAllWnd = _GUICtrlHotkey_Create($hGUIHotkeyEdit, 8, 130)
_GUICtrlHotkey_SetRules($hGUIHotkeyEdit_HK_RestoreAllWnd, $HKCOMB_NONE, $HOTKEYF_ALT)
_GUICtrlHotkey_SetHotkey($hGUIHotkeyEdit_HK_RestoreAllWnd, $sHK_RestoreAllWnd)

GUICtrlCreateLabel("ESC key and ALT-F4 cannot be selected because they will interfere with system hotkeys.", 10, 165, 280, 50)


; == Tray Creation Section ==
$hTrayRestoreAllWnd = TrayCreateItem("Restore All Windows (" & _GuiCtrlHotkey_NameFromAutoItHK($sHK_RestoreAllWnd) & ")")
TrayCreateItem("") ;//Create a straight line
$opt = TrayCreateMenu("Extra")
$hTrayAltF4EndProcess = TrayCreateItem("Alt-F4 forces window's process to exit", $opt)
TrayItemSetState($hTrayAltF4EndProcess, $bAltF4EndProcess)
$hTrayRestoreOnExit = TrayCreateItem("Restore hidden windows on exit", $opt)
TrayItemSetState($hTrayRestoreOnExit, $bRestoreOnExit)
$hTrayEditHotkeys = TrayCreateItem("Edit Hotkeys")
$hTrayHelp = TrayCreateItem("Quick Help")
$hTrayExit = TrayCreateItem("Exit (Shift+Esc)")

TrayTip("MinimizeToTray " & $VERSION, "Press [" & _GuiCtrlHotkey_NameFromAutoItHK($sHK_HideWnd) & "] to hide currently active Window." & @CRLF _
		 & "Press [" & _GuiCtrlHotkey_NameFromAutoItHK($sHK_RestoreLastWnd) & "] to restore last hidden Window." & @CRLF _
		 & "Hidden Windows are stored in MTT tray icon.", 5)

RestoreLastShutdownWindows()

;//Main Loop
While 1
   HandleTrayEvents()
WEnd

Func HandleTrayEvents()
$hTrayMsg = TrayGetMsg()
   Switch $hTrayMsg
	 Case $hTrayAltF4EndProcess
		 ToggleOpt($bAltF4EndProcess, $hTrayAltF4EndProcess)
		 IniWrite($CONFIG_INI, "Extra", "ALT_F4_FORCE_END_PROCESS", BoolToText($bAltF4EndProcess))
	 Case $hTrayRestoreOnExit
		 ToggleOpt($bRestoreOnExit, $hTrayRestoreOnExit)
		 IniWrite($CONFIG_INI, "Extra", "RESTORE_ALL_WINDOWS_ON_EXIT", BoolToText($bRestoreOnExit))
	 Case $hTrayRestoreAllWnd
		 RestoreAllWnd()
	 Case $hTrayExit
		 ExitS()
	 Case $hTrayHelp
		 Help()
	 Case $hTrayEditHotkeys
		 EditHotkeys()
   EndSwitch

   For $i = 0 To UBound($aTrayItemHandles) - 1
	 If $hTrayMsg = $aTrayItemHandles[$i] Then
		 If $i < UBound($aHiddenWndList) Then
			 RestoreWnd($aHiddenWndList[$i])
		 EndIf
		 ExitLoop
	 EndIf
   Next
EndFunc


Func EditHotkeys()
   GUISetState(@SW_SHOW, $hGUIHotkeyEdit)
   ; Temporarily disable current hotkeys
   HotKeySet($sHK_HideWnd)
   HotKeySet($sHK_RestoreLastWnd)
   HotKeySet($sHK_RestoreAllWnd)
   While 1
	  $msg = GUIGetMsg()
	  Switch $msg
		 Case $GUI_EVENT_CLOSE
			ExitLoop
		 Case $hGUIHotkeyEdit_Btn_OK
			; Read GUI and save to config file
			$sHK_HideWnd = _GUICtrlHotkey_GetHotkey($hGUIHotkeyEdit_HK_HideWnd)
			$sHK_RestoreLastWnd = _GUICtrlHotkey_GetHotkey($hGUIHotkeyEdit_HK_RestoreLastWnd)
			$sHK_RestoreAllWnd = _GUICtrlHotkey_GetHotkey($hGUIHotkeyEdit_HK_RestoreAllWnd)

			; Validate new hotkeys
			If $sHK_HideWnd == "" Or $sHK_RestoreLastWnd == "" Or $sHK_RestoreAllWnd == "" Then
			   MsgBox(16, "", "Hotkeys must not be empty.")
			   ContinueLoop
			EndIf

			; Save new hotkeys to config ini file
			IniWrite($CONFIG_INI, "Hotkeys", "HIDE_WINDOW", $sHK_HideWnd)
			IniWrite($CONFIG_INI, "Hotkeys", "RESTORE_LAST_WINDOW", $sHK_RestoreLastWnd)
			IniWrite($CONFIG_INI, "Hotkeys", "RESTORE_ALL_WINDOWS", $sHK_RestoreAllWnd)

			; Update Tray Text for Restore All Windows
			TrayItemSetText($hTrayRestoreAllWnd, "Restore All Windows (" & _GuiCtrlHotkey_NameFromAutoItHK($sHK_RestoreAllWnd) & ")")
			ExitLoop
		 Case $hGUIHotkeyEdit_Btn_Default
			_GUICtrlHotkey_SetHotkey($hGUIHotkeyEdit_HK_HideWnd, $DEFAULT_HIDE_WND_HK)
			_GUICtrlHotkey_SetHotkey($hGUIHotkeyEdit_HK_RestoreLastWnd, $DEFAULT_RESTORE_LAST_WND_HK)
			_GUICtrlHotkey_SetHotkey($hGUIHotkeyEdit_HK_RestoreAllWnd, $DEFAULT_RESTORE_ALL_WND_HK)
	  EndSwitch
   WEnd

   ; Reenable hotkeys
   HotKeySet($sHK_HideWnd, "HideCurrentWnd")
   HotKeySet($sHK_RestoreLastWnd, "RestoreLastWnd")
   HotKeySet($sHK_RestoreAllWnd, "RestoreAllWnd")
   GUISetState(@SW_HIDE, $hGUIHotkeyEdit)
EndFunc


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
	MsgBox(64, "MinimizeToTray " & $VERSION, "Press [" & _GuiCtrlHotkey_NameFromAutoItHK($sHK_HideWnd) & "] to hide currently active Window." & @CRLF _
			 & "Press [" & _GuiCtrlHotkey_NameFromAutoItHK($sHK_RestoreLastWnd) & "] to restore last hidden Window." & @CRLF _
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


Func TextToBool($txt)
   If StringLower($txt) == "true" Then
	  Return True
   Else
	  Return False
   EndIf
EndFunc


Func BoolToText($bool)
   If $bool Then
	  Return "True"
   Else
	  Return "False"
   EndIf
EndFunc
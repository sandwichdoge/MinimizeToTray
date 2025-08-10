#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Icon=MTT.ico
#AutoIt3Wrapper_Outfile=MinimizeToTray.Exe
#AutoIt3Wrapper_UseX64=n
#AutoIt3Wrapper_Res_Description=Minimize windows to system tray
#AutoIt3Wrapper_Res_Fileversion=2.7.3.1
#AutoIt3Wrapper_Res_Fileversion_AutoIncrement=y
#AutoIt3Wrapper_Run_Tidy=y
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****

#include-once
#include <Misc.au3>
#include <Array.au3>
#include <WinAPI.au3>
#include <GuiConstantsEx.au3>
#include <File.au3>
#include "libs/GUIHotkey.au3"
#include "libs/Json.au3"
#include "cmdline.au3"

Global Const $CONFIG_INI = @ScriptDir & "\MTTconf.ini"

Global Const $DEFAULT_HIDE_WND_HK = "!{f1}"
Global Const $DEFAULT_RESTORE_LAST_WND_HK = "!{f2}"
Global Const $DEFAULT_RESTORE_ALL_WND_HK = "{f10}"

If CmdlineHasParams() Then
	;//Cmdline mode does not care about tray and GUI whatsoever.
	CmdlineRunCliMode()
	Exit
EndIf


Opt('TrayAutoPause', 0)
Opt('TrayMenuMode', 3)

; Pre-allocate the array with a reasonable size to reduce frequent resizing operations
Global $aWindowStack[20][3]
Global $nWindowStackSize = 0 ; Track actual number of windows in the stack

Global $hMutex = _WinAPI_CreateMutex("MTT_Operation_Mutex")

Main()


; Read ini config file, set current global hotkeys
Func InitializeConfigs()
	Global $sHK_HideWnd = IniRead($CONFIG_INI, "Hotkeys", "HIDE_WINDOW", $DEFAULT_HIDE_WND_HK)
	Global $sHK_RestoreLastWnd = IniRead($CONFIG_INI, "Hotkeys", "RESTORE_LAST_WINDOW", $DEFAULT_RESTORE_LAST_WND_HK)
	Global $sHK_RestoreAllWnd = IniRead($CONFIG_INI, "Hotkeys", "RESTORE_ALL_WINDOWS", $DEFAULT_RESTORE_ALL_WND_HK)

	Global $sRestoreAllWndsOnExit = IniRead($CONFIG_INI, "Extra", "RESTORE_ALL_WINDOWS_ON_EXIT", "True")
	Global $sAltF4EndProcess = IniRead($CONFIG_INI, "Extra", "ALT_F4_FORCE_END_PROCESS", "False")
	Global $sRestoreFocus = IniRead($CONFIG_INI, "Extra", "RESTORE_FOCUS", "True")
	Global $sAltEscFocusChange = IniRead($CONFIG_INI, "Extra", "ALT_ESC_FOCUS_CHANGE", "True")

	Global $bAltF4EndProcess = TextToBool($sAltF4EndProcess)
	Global $bRestoreOnExit = TextToBool($sRestoreAllWndsOnExit)
	Global $bRestoreFocus = TextToBool($sRestoreFocus)
	Global $bAltEscFocusChange = TextToBool($sAltEscFocusChange)

	Global $sLanguage = IniRead($CONFIG_INI, "Extra", "LANGUAGE", "en")

	HotKeySet($sHK_HideWnd, "HideCurrentWnd")
	HotKeySet($sHK_RestoreLastWnd, "RestoreLastWnd")
	HotKeySet("!{f4}", "HandleAltF4")
	HotKeySet($sHK_RestoreAllWnd, "RestoreAllWnd")
	OnAutoItExitRegister("ExitS")
EndFunc   ;==>InitializeConfigs


Func InitializeLanguage()
    Local $hJobj = False
    Local $sLanguageFile = FileRead(@ScriptDir & "\language_gen\" & $sLanguage & ".json")
    If $sLanguageFile Then $hJobj = Json_Decode($sLanguageFile)

    Global $sTextId_Already_Running = LoadText($hJobj, "TextId_Already_Running", "An instance of MinimizeToTray is already running.")
    Global $sTextId_Tray_Restore_All_Windows = LoadText($hJobj, "TextId_Tray_Restore_All_Windows", "Restore all windows")
    Global $sTextId_Tray_Extra = LoadText($hJobj, "TextId_Tray_Extra", "Extra")
    Global $sTextId_Tray_Opt_AltF4_Force_Exit_Desc = LoadText($hJobj, "TextId_Tray_Opt_AltF4_Force_Exit_Desc", "Alt-F4 forces window's process to exit")
    Global $sTextId_Tray_Opt_Restore_On_Exit_Desc = LoadText($hJobj, "TextId_Tray_Opt_Restore_On_Exit_Desc", "Restore hidden windows on exit")
    Global $sTextId_Tray_Opt_Restore_Focus = LoadText($hJobj, "TextId_Tray_Opt_Restore_Focus", "Return focus to restored windows")
    Global $sTextId_Tray_Opt_Alt_Esc_Focus_Change_Desc = LoadText($hJobj, "TextId_Tray_Opt_Alt_Esc_Focus_Change_Desc", "Auto Alt+Esc for smooth focus on hide")
    Global $sTextId_Tray_Edit_Hotkeys = LoadText($hJobj, "TextId_Tray_Edit_Hotkeys", "Configs")
    Global $sTextId_Tray_Quick_Help = LoadText($hJobj, "TextId_Tray_Quick_Help", "Quick Help")
    Global $sTextId_Tray_Exit = LoadText($hJobj, "TextId_Tray_Exit", "Exit")
    Global $sTextId_GUI_Edit_Hotkeys = LoadText($hJobj, "TextId_GUI_Edit_Hotkeys", "Edit Hotkeys")
    Global $sTextId_GUI_OK = LoadText($hJobj, "TextId_GUI_OK", "OK")
    Global $sTextId_GUI_Default = LoadText($hJobj, "TextId_GUI_Default", "Default")
    Global $sTextId_GUI_Hide_Active_Window = LoadText($hJobj, "TextId_GUI_Hide_Active_Window", "Hide active window")
    Global $sTextId_GUI_Restore_Last_Window = LoadText($hJobj, "TextId_GUI_Restore_Last_Window", "Restore last window")
    Global $sTextId_GUI_Restore_All_Windows = LoadText($hJobj, "TextId_GUI_Restore_All_Windows", "Restore all hidden windows")
    Global $sTextId_GUI_Warning_Key_Overlap = LoadText($hJobj, "TextId_GUI_Warning_Key_Overlap", "ESC key and ALT-F4 cannot be selected because they will interfere with system hotkeys.")
    Global $sTextId_GUI_Warning_Key_Empty = LoadText($hJobj, "TextId_GUI_Warning_Key_Empty", "Hotkeys must not be empty.")
    Global $sTextId_GUI_Language = LoadText($hJobj, "TextId_GUI_Language", "Language")
    Global $sTextId_Msg_Help_1_Press = LoadText($hJobj, "TextId_Msg_Help_1_Press", "Press")
    Global $sTextId_Msg_Help_2_To_Hide_Active = LoadText($hJobj, "TextId_Msg_Help_2_To_Hide_Active", "to hide currently active Window.")
    Global $sTextId_Msg_Help_3_To_Restore = LoadText($hJobj, "TextId_Msg_Help_3_To_Restore", "to restore last hidden Window.")
    Global $sTextId_Msg_Help_4_Stored_In_Tray = LoadText($hJobj, "TextId_Msg_Help_4_Stored_In_Tray", "Hidden Windows are stored in MTT tray icon.")
    Global $sTextId_Msg_Help_5_Elevated_Window_Admin = LoadText($hJobj, "TextId_Msg_Help_5_Elevated_Window_Admin", "If the window you want to hide is elevated to administrative level, you must run MTT as Administrator.")
EndFunc   ;==>InitializeLanguage

Func LoadText($hJobj, $sKey, $sFallback)
	If IsObj($hJobj) Then
		Local $sValue = Json_Get($hJobj, '["' & $sKey & '"]')
		If $sValue Then Return $sValue
	EndIf
	Return $sFallback
EndFunc   ;==>LoadText


Func InitializeTray()
	Global $hTrayRestoreAllWnd
	Global $hTrayLine1
	Global $hTrayEditHotkeys
	Global $hTrayOpt
	Global $hTrayHelp
	Global $hTrayExit
	TrayItemDelete($hTrayRestoreAllWnd)
	TrayItemDelete($hTrayLine1)
	TrayItemDelete($hTrayEditHotkeys)
	TrayItemDelete($hTrayOpt)
	TrayItemDelete($hTrayHelp)
	TrayItemDelete($hTrayExit)
	; == Tray Creation Section ==
	$hTrayRestoreAllWnd = TrayCreateItem($sTextId_Tray_Restore_All_Windows & " (" & _GuiCtrlHotkey_NameFromAutoItHK($sHK_RestoreAllWnd) & ")")
	$hTrayLine1 = TrayCreateItem("") ; Create a straight line

	$hTrayOpt = TrayCreateMenu($sTextId_Tray_Extra)
	Global $hTrayAltF4EndProcess = TrayCreateItem($sTextId_Tray_Opt_AltF4_Force_Exit_Desc, $hTrayOpt)
	TrayItemSetState($hTrayAltF4EndProcess, $bAltF4EndProcess)
	Global $hTrayRestoreOnExit = TrayCreateItem($sTextId_Tray_Opt_Restore_On_Exit_Desc, $hTrayOpt)
	TrayItemSetState($hTrayRestoreOnExit, $bRestoreOnExit)
	Global $hTrayRestoreFocus = TrayCreateItem($sTextId_Tray_Opt_Restore_Focus, $hTrayOpt)
	TrayItemSetState($hTrayRestoreFocus, $bRestoreFocus)
	Global $hTrayAltEscFocusChange = TrayCreateItem($sTextId_Tray_Opt_Alt_Esc_Focus_Change_Desc, $hTrayOpt)
	TrayItemSetState($hTrayAltEscFocusChange, $bAltEscFocusChange) ; Set initial check state based on config

	Global $hTrayEditHotkeys = TrayCreateItem($sTextId_Tray_Edit_Hotkeys)
	Global $hTrayHelp = TrayCreateItem($sTextId_Tray_Quick_Help)
	Global $hTrayExit = TrayCreateItem($sTextId_Tray_Exit)
EndFunc   ;==>InitializeTray


Func InitializeGUIs()
	; == GUI Creation Section ==
	Global $hGUIConfigs
	GUIDelete($hGUIConfigs)
	$hGUIConfigs = GUICreate($sTextId_GUI_Edit_Hotkeys, 300, 300)
	Global $hGUIConfigs_Btn_OK = GUICtrlCreateButton($sTextId_GUI_OK, 20, 260, 100, 25)
	Global $hGUIConfigs_Btn_Default = GUICtrlCreateButton($sTextId_GUI_Default, 160, 260, 100, 25)
	GUICtrlCreateLabel($sTextId_GUI_Hide_Active_Window, 10, 10)
	Global $hGUIConfigs_HK_HideWnd = _GUICtrlHotkey_Create($hGUIConfigs, 8, 30)
	_GUICtrlHotkey_SetRules($hGUIConfigs_HK_HideWnd, $HKCOMB_NONE, $HOTKEYF_ALT)
	_GUICtrlHotkey_SetHotkey($hGUIConfigs_HK_HideWnd, $sHK_HideWnd)

	GUICtrlCreateLabel($sTextId_GUI_Restore_Last_Window, 10, 60)
	Global $hGUIConfigs_HK_RestoreLastWnd = _GUICtrlHotkey_Create($hGUIConfigs, 8, 80)
	_GUICtrlHotkey_SetRules($hGUIConfigs_HK_RestoreLastWnd, $HKCOMB_NONE, $HOTKEYF_ALT)
	_GUICtrlHotkey_SetHotkey($hGUIConfigs_HK_RestoreLastWnd, $sHK_RestoreLastWnd)

	GUICtrlCreateLabel($sTextId_GUI_Restore_All_Windows, 10, 110)
	Global $hGUIConfigs_HK_RestoreAllWnd = _GUICtrlHotkey_Create($hGUIConfigs, 8, 130)
	_GUICtrlHotkey_SetRules($hGUIConfigs_HK_RestoreAllWnd, $HKCOMB_NONE, $HOTKEYF_ALT)
	_GUICtrlHotkey_SetHotkey($hGUIConfigs_HK_RestoreAllWnd, $sHK_RestoreAllWnd)

	GUICtrlCreateLabel($sTextId_GUI_Warning_Key_Overlap, 10, 165, 280, 50)

	Local $sLangDir = @ScriptDir & "\language_gen" ; language_gen is in the same dir as the script/exe
	Local $aLangFiles = _FileListToArray($sLangDir, "*.json", $FLTA_FILES)
	Local $sLangListString = ""
	Local $sCurrentLangValid = False

	If IsArray($aLangFiles) Then
		For $i = 1 To $aLangFiles[0] ; Start from index 1, index 0 holds the count
			Local $sLangCode = StringTrimRight($aLangFiles[$i], 5) ; Remove ".json" extension
			If $sLangListString = "" Then
				$sLangListString = $sLangCode
			Else
				$sLangListString &= "|" & $sLangCode
			EndIf
			; Check if the language read from INI is among the found files
			If StringLower($sLangCode) = StringLower($sLanguage) Then
				$sCurrentLangValid = True
			EndIf
		Next
	EndIf

	; Fallback if no language files are found or the current language is invalid
	If $sLangListString = "" Then
		$sLangListString = "en" ; Default to English if no files found
		If StringLower($sLanguage) <> "en" Then $sLanguage = "en" ; Force current lang to en if it wasn't
		$sCurrentLangValid = True ; 'en' is now considered valid
	ElseIf Not $sCurrentLangValid Then
		; If the language from INI wasn't found, default to the first one in the list (or 'en' if available)
		Local $aTempLangList = StringSplit($sLangListString, "|")
		If _ArraySearch($aTempLangList, "en", 0, 0, 0, 1) > 0 Then ; Check if 'en' exists (case-insensitive)
			$sLanguage = "en"
		Else
			$sLanguage = $aTempLangList[1] ; Default to the first language found
		EndIf
		ConsoleWrite("!> Warning: Configured language '" & $sLanguage & "' not found. Defaulting to '" & $sLanguage & "'" & @CRLF)
	EndIf


	GUICtrlCreateLabel($sTextId_GUI_Language, 10, 220, 100)
	Global $hGUIConfigs_Language = GUICtrlCreateCombo("", 110, 219, 100, 24) ; Create empty first
	GUICtrlSetData($hGUIConfigs_Language, $sLangListString, $sLanguage)
EndFunc   ;==>InitializeGUIs


Func HandleTrayEvents()
	$hTrayMsg = TrayGetMsg()
	Switch $hTrayMsg
		Case $hTrayAltF4EndProcess
			ToggleOpt($bAltF4EndProcess, $hTrayAltF4EndProcess)
			IniWrite($CONFIG_INI, "Extra", "ALT_F4_FORCE_END_PROCESS", BoolToText($bAltF4EndProcess))
		Case $hTrayRestoreOnExit
			ToggleOpt($bRestoreOnExit, $hTrayRestoreOnExit)
			IniWrite($CONFIG_INI, "Extra", "RESTORE_ALL_WINDOWS_ON_EXIT", BoolToText($bRestoreOnExit))
		Case $hTrayRestoreFocus
			ToggleOpt($bRestoreFocus, $hTrayRestoreFocus)
			IniWrite($CONFIG_INI, "Extra", "RESTORE_FOCUS", BoolToText($bRestoreFocus))
		Case $hTrayAltEscFocusChange
			ToggleOpt($bAltEscFocusChange, $hTrayAltEscFocusChange)
			IniWrite($CONFIG_INI, "Extra", "ALT_ESC_FOCUS_CHANGE", BoolToText($bAltEscFocusChange))
		Case $hTrayRestoreAllWnd
			RestoreAllWnd()
		Case $hTrayExit
			ExitS()
		Case $hTrayHelp
			Help()
		Case $hTrayEditHotkeys
			EditHotkeys()
	EndSwitch

	; Only attempt to lock the mutex if there's a tray message to process
	If $hTrayMsg = 0 Then Return

	If _WinAPI_WaitForSingleObject($hMutex, 100) <> 0 Then
		Return ; Couldn't acquire mutex, skip this cycle
	EndIf

	; Check if a specific window's tray item was clicked
	For $i = 0 To $nWindowStackSize - 1
		; Check if the array element is valid before accessing it
		If IsHWnd($aWindowStack[$i][0]) And $aWindowStack[$i][1] <> 0 Then
			If $hTrayMsg = $aWindowStack[$i][1] Then
				RestoreWnd($aWindowStack[$i][0])
				ExitLoop
			EndIf
		EndIf
	Next

	; Release mutex
	_WinAPI_ReleaseMutex($hMutex)
EndFunc   ;==>HandleTrayEvents


Func EditHotkeys()
	GUISetState(@SW_SHOW, $hGUIConfigs)
	; Temporarily disable current hotkeys
	HotKeySet($sHK_HideWnd)
	HotKeySet($sHK_RestoreLastWnd)
	HotKeySet($sHK_RestoreAllWnd)
	While 1
		$msg = GUIGetMsg()
		Switch $msg
			Case $GUI_EVENT_CLOSE
				ExitLoop
			Case $hGUIConfigs_Btn_OK
				; Read GUI and save to config file
				$sHK_HideWnd = _GUICtrlHotkey_GetHotkey($hGUIConfigs_HK_HideWnd)
				$sHK_RestoreLastWnd = _GUICtrlHotkey_GetHotkey($hGUIConfigs_HK_RestoreLastWnd)
				$sHK_RestoreAllWnd = _GUICtrlHotkey_GetHotkey($hGUIConfigs_HK_RestoreAllWnd)

				; Validate new hotkeys
				If $sHK_HideWnd = "" Then
					MsgBox(16, "", $sTextId_GUI_Warning_Key_Empty)
					ContinueLoop
				EndIf

				; Save new hotkeys to config ini file
				IniWrite($CONFIG_INI, "Hotkeys", "HIDE_WINDOW", $sHK_HideWnd)
				IniWrite($CONFIG_INI, "Hotkeys", "RESTORE_LAST_WINDOW", $sHK_RestoreLastWnd)
				IniWrite($CONFIG_INI, "Hotkeys", "RESTORE_ALL_WINDOWS", $sHK_RestoreAllWnd)

				$sLanguage = GUICtrlRead($hGUIConfigs_Language)
				IniWrite($CONFIG_INI, "Extra", "LANGUAGE", $sLanguage)

				; Update Tray Text for Restore All Windows
				TrayItemSetText($hTrayRestoreAllWnd, $sTextId_GUI_Restore_All_Windows & " (" & _GuiCtrlHotkey_NameFromAutoItHK($sHK_RestoreAllWnd) & ")")

				; Reinitialize UI Language
				InitializeLanguage()
				InitializeTray()
				InitializeGUIs()

				ExitLoop
			Case $hGUIConfigs_Btn_Default
				_GUICtrlHotkey_SetHotkey($hGUIConfigs_HK_HideWnd, $DEFAULT_HIDE_WND_HK)
				_GUICtrlHotkey_SetHotkey($hGUIConfigs_HK_RestoreLastWnd, $DEFAULT_RESTORE_LAST_WND_HK)
				_GUICtrlHotkey_SetHotkey($hGUIConfigs_HK_RestoreAllWnd, $DEFAULT_RESTORE_ALL_WND_HK)
		EndSwitch
	WEnd

	; Reenable hotkeys
	HotKeySet($sHK_HideWnd, "HideCurrentWnd")
	HotKeySet($sHK_RestoreLastWnd, "RestoreLastWnd")
	HotKeySet($sHK_RestoreAllWnd, "RestoreAllWnd")
	GUISetState(@SW_HIDE, $hGUIConfigs)
EndFunc   ;==>EditHotkeys


Func ToggleOpt(ByRef $bFlag, ByRef $hTrayItem)
	$bFlag = Not $bFlag

	Local $nTrayItemState = TrayItemGetState($hTrayItem)
	If BitAND($nTrayItemState, 1) Then ; CHECKED
		TrayItemSetState($hTrayItem, 4) ; Set to UNCHECKED
	ElseIf BitAND($nTrayItemState, 4) Then ; UNCHECKED
		TrayItemSetState($hTrayItem, 1) ; Set to CHECKED
	Else ; Default / Initial state might not be CHECKED or UNCHECKED explicitly
		If $bFlag Then
			TrayItemSetState($hTrayItem, 1) ; Set to CHECKED
		Else
			TrayItemSetState($hTrayItem, 4) ; Set to UNCHECKED
		EndIf
	EndIf

EndFunc   ;==>ToggleOpt


Func RestoreLastWnd()
	; Restore window from top of stack
	If $nWindowStackSize > 0 Then
		Local $nLastIndex = $nWindowStackSize - 1
		RestoreWnd($aWindowStack[$nLastIndex][0])
	EndIf
EndFunc   ;==>RestoreLastWnd


Func RestoreWnd($hfWnd)
	; Try to acquire mutex with timeout to prevent deadlocks
	If _WinAPI_WaitForSingleObject($hMutex, 1000) <> 0 Then
		ConsoleWrite("!> Warning: Could not acquire mutex to restore window." & @CRLF)
		Return
	EndIf

	Local $nIndex = -1
	Local $hTrayItemToDelete = 0

	; Find the window in our stack and get its tray item handle
	For $i = 0 To $nWindowStackSize - 1
		If $aWindowStack[$i][0] = $hfWnd Then
			$nIndex = $i
			$hTrayItemToDelete = $aWindowStack[$i][1]
			ExitLoop
		EndIf
	Next

	; Check if the window handle is still valid BEFORE trying to show/activate
	If WindowExists($hfWnd) Then
		WinSetState($hfWnd, "", @SW_SHOW)
		If $bRestoreFocus = True Then
			WinActivate($hfWnd)
		EndIf
	Else
		ConsoleWrite("!> Info: Window handle " & $hfWnd & " is no longer valid. Cleaning up tray item." & @CRLF)
	EndIf

	; Remove from our stack and delete tray item IF found
	If $nIndex >= 0 Then
		TrayItemDelete($hTrayItemToDelete) ; Use the stored handle

		If $nIndex < $nWindowStackSize - 1 Then
			; Move the last element to fill the gap
			$aWindowStack[$nIndex][0] = $aWindowStack[$nWindowStackSize - 1][0]
			$aWindowStack[$nIndex][1] = $aWindowStack[$nWindowStackSize - 1][1]
			$aWindowStack[$nIndex][2] = $aWindowStack[$nWindowStackSize - 1][2]
		EndIf

		$nWindowStackSize -= 1
	EndIf

	; Release mutex
	_WinAPI_ReleaseMutex($hMutex)
EndFunc   ;==>RestoreWnd


Func HideCurrentWnd()
	Local $hCurrentWndToHide = WinGetHandle("[ACTIVE]")

	; If there's no active window or we got the desktop/shell, don't proceed.
	If $hCurrentWndToHide = 0 Then Return
	If _WinAPI_GetClassName($hCurrentWndToHide) = "Progman" Then Return

	If IsWindowInStack($hCurrentWndToHide) Then
		; Window is already hidden, no need to hide it again
		Return
	EndIf

	If $bAltEscFocusChange Then
		; Send Alt+Esc. This typically shifts focus to the window that would become active if the current one was minimized.
		Send("!{ESC}")

		; Give Windows a brief moment to process the Alt+Esc and change focus.
		; Adjust this value if needed (50-150ms is usually sufficient).
		Sleep(100)
	EndIf

	; Now, hide the window we originally targeted (which may or may not still be active, depending on the toggle setting).
	HideWnd($hCurrentWndToHide)

EndFunc   ;==>HideCurrentWnd


; Function to check if a window is in the stack
Func IsWindowInStack($hWnd)
	For $i = 0 To $nWindowStackSize - 1
		If $aWindowStack[$i][0] = $hWnd Then
			Return True
		EndIf
	Next
	Return False
EndFunc   ;==>IsWindowInStack


Func RestoreAllWnd()
	; Try to acquire mutex
	If _WinAPI_WaitForSingleObject($hMutex, 1000) <> 0 Then
		ConsoleWrite("!> Warning: Could not acquire mutex to restore all windows." & @CRLF)
		Return
	EndIf

	If $nWindowStackSize > 0 Then
		Local $hLastValidWindow = 0

		For $i = 0 To $nWindowStackSize - 1
			Local $hWnd = $aWindowStack[$i][0]
			Local $hTrayItem = $aWindowStack[$i][1]

			; Check if the window handle is still valid BEFORE trying to show/activate
			If WindowExists($hWnd) Then
				WinSetState($hWnd, "", @SW_SHOW)
				$hLastValidWindow = $hWnd ; Keep track of the last valid window shown
			Else
				ConsoleWrite("!> Info: Window handle " & $hWnd & " is no longer valid during RestoreAll. Cleaning up tray item." & @CRLF)
			EndIf

			; Always delete the tray item
			TrayItemDelete($hTrayItem)
		Next

		; Bring focus to the last valid window that was restored, if requested
		If $bRestoreFocus = True And IsHWnd($hLastValidWindow) Then
			WinActivate($hLastValidWindow)
		EndIf

		; Reset the window stack completely
		$nWindowStackSize = 0
	EndIf

	; Release mutex
	_WinAPI_ReleaseMutex($hMutex)
EndFunc   ;==>RestoreAllWnd


Func CloseWnd()
	; Add error handling for process closing
	Local $hWnd = WinGetHandle("[ACTIVE]")
	If $hWnd = 0 Then
		ConsoleWrite("!> Error: No active window to close." & @CRLF)
		Return
	EndIf

	Local $iPID = WinGetProcess($hWnd)
	If $iPID <= 0 Then ; Check if PID is valid (greater than 0)
		ConsoleWrite("!> Error: Couldn't get process ID for window handle " & $hWnd & "." & @CRLF)
		Return
	EndIf

	ProcessClose($iPID)
	If @error Then
		ConsoleWrite("!> Warning: Failed to close process with PID " & $iPID & ". It might require elevated privileges or is unresponsive." & @CRLF)
	EndIf
EndFunc   ;==>CloseWnd


Func HandleAltF4()
	If $bAltF4EndProcess = True Then
		CloseWnd()
	Else
		; Temporarily disable the Alt+F4 hotkey to pass it through
		HotKeySet("!{f4}")
		Send("!{f4}")

		; Add a small delay before re-enabling the hotkey
		; This helps prevent hotkey registration issues
		Sleep(50)
		HotKeySet("!{f4}", "HandleAltF4")
	EndIf
EndFunc   ;==>HandleAltF4


Func Help()
	MsgBox(64, "MinimizeToTray", $sTextId_Msg_Help_1_Press & " [" & _GuiCtrlHotkey_NameFromAutoItHK($sHK_HideWnd) & "] " & $sTextId_Msg_Help_2_To_Hide_Active & @CRLF _
			 & $sTextId_Msg_Help_1_Press & " [" & _GuiCtrlHotkey_NameFromAutoItHK($sHK_RestoreLastWnd) & "] " & $sTextId_Msg_Help_3_To_Restore & @CRLF _
			 & $sTextId_Msg_Help_4_Stored_In_Tray & @CRLF _
			 & $sTextId_Msg_Help_5_Elevated_Window_Admin & @CRLF & @CRLF _
			 & "https://github.com/sandwichdoge/MinimizeToTray")
EndFunc   ;==>Help


Func ExitS()
	If $bRestoreOnExit Then
		RestoreAllWnd()
	EndIf

	; Clean up mutex properly
	If $hMutex Then
		_WinAPI_CloseHandle($hMutex)
	EndIf

	Exit
EndFunc   ;==>ExitS


Func TextToBool($txt)
	If StringLower($txt) = "true" Then
		Return True
	Else
		Return False
	EndIf
EndFunc   ;==>TextToBool


Func BoolToText($bool)
	If $bool Then
		Return "True"
	Else
		Return "False"
	EndIf
EndFunc   ;==>BoolToText


Func LimitWindowTitle($sTitle, $iMaxLength = 50)
	If StringLen($sTitle) > $iMaxLength Then
		Return StringLeft($sTitle, $iMaxLength - 3) & "..."
	Else
		Return $sTitle
	EndIf
EndFunc   ;==>LimitWindowTitle


Func WindowExists($hWnd)
	Return WinExists($hWnd) <> 0
EndFunc   ;==>WindowExists


Func HideWnd($hfWnd)
	; Try to acquire mutex with timeout
	If _WinAPI_WaitForSingleObject($hMutex, 1000) <> 0 Then
		ConsoleWrite("!> Warning: Could not acquire mutex to hide window." & @CRLF)
		Return
	EndIf

	; Get window title for tray menu
	Local $sTitle = WinGetTitle($hfWnd)
	If @error Then $sTitle = "[Error Getting Title]"
	If $sTitle = "" Then $sTitle = "[No Title]"

	; Limit the title length for better tray display
	$sTitle = LimitWindowTitle($sTitle, 50)

	; Hide the window
	WinSetState($hfWnd, "", @SW_HIDE)
	If @error Then ; Check if hiding failed (e.g., window closed between check and hide)
		ConsoleWrite("!> Warning: Failed to hide window handle " & $hfWnd & ". It might have closed." & @CRLF)
		_WinAPI_ReleaseMutex($hMutex)
		Return
	EndIf

	Local $hTrayWnd = TrayCreateItem($sTitle, -1, 0)

	; Check if we need to resize the array
	If $nWindowStackSize >= UBound($aWindowStack) Then
		; Resize the array in larger chunks (double the size) to reduce resize operations
		Local $iNewSize = UBound($aWindowStack) * 2
		ConsoleWrite("*> Info: Resizing window stack array to " & $iNewSize & @CRLF)
		ReDim $aWindowStack[$iNewSize][3]
		If @error Then
			ConsoleWrite("!> Error: Failed to resize window stack array." & @CRLF)
			TrayItemDelete($hTrayWnd)  ; Clean up the tray item we just created
			_WinAPI_ReleaseMutex($hMutex)
			Return  ; Cannot add window if resize failed
		EndIf
	EndIf

	; Add to our window stack
	$aWindowStack[$nWindowStackSize][0] = $hfWnd  ; Window handle
	$aWindowStack[$nWindowStackSize][1] = $hTrayWnd  ; Tray item handle
	$aWindowStack[$nWindowStackSize][2] = $sTitle  ; Window title
	$nWindowStackSize += 1

	; Release mutex
	_WinAPI_ReleaseMutex($hMutex)
EndFunc   ;==>HideWnd


Func Main()
	InitializeConfigs()
	InitializeLanguage()
	InitializeTray()
	InitializeGUIs()

	;//Exit if MTT is already running.
	If _Singleton("MTT", 1) = 0 Then
		TrayTip("MinimizeToTray", $sTextId_Already_Running, 2)
		Sleep(2000)
		Exit
	EndIf

	TrayTip("MinimizeToTray", $sTextId_Msg_Help_1_Press & " [" & _GuiCtrlHotkey_NameFromAutoItHK($sHK_HideWnd) & "] " & $sTextId_Msg_Help_2_To_Hide_Active & @CRLF _
			 & $sTextId_Msg_Help_1_Press & " [" & _GuiCtrlHotkey_NameFromAutoItHK($sHK_RestoreLastWnd) & "] " & $sTextId_Msg_Help_3_To_Restore & @CRLF _
			 & $sTextId_Msg_Help_4_Stored_In_Tray, 5)

	While 1
		HandleTrayEvents()
	WEnd
EndFunc   ;==>Main

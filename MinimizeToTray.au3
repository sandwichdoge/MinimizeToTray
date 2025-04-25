#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Icon=MTT.ico
#AutoIt3Wrapper_Outfile=MinimizeToTray.Exe
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
;//Minimize to tray
;//sandwichdoge@gmail.com

#include-once
#include <Misc.au3>
#include <Array.au3>
#include <WinAPI.au3>
#include <GuiConstantsEx.au3>
#include <File.au3>
#include "libs/GUIHotkey.au3"
#include "libs/Json.au3"
#include "cmdline.au3"

Global Const $VERSION = ""
Global Const $CONFIG_INI = "MTTconf.ini"

Global Const $DEFAULT_HIDE_WND_HK = "!{f1}"
Global Const $DEFAULT_RESTORE_LAST_WND_HK = "!{f2}"
Global Const $DEFAULT_RESTORE_ALL_WND_HK = "{f10}"

If CmdlineHasParams() Then
   ;Cmdline mode does not care about tray and GUI whatsoever.
   CmdlineRunCliMode()
   Exit
EndIf


Opt('TrayAutoPause', 0)
Opt('TrayMenuMode', 3)

;//$aHiddenWndList = Array that contains handles of all hidden windows.
;//$aTrayItemHandles = Array that contains tray items that indicate names of hidden windows.
;//Elements of these 2 arrays must be perfectly in sync with each other.
Global $aHiddenWndList[0] = [], $aTrayItemHandles[0] = []
Global $hLastWnd ;//Handle of the last window that was hidden
Global $g_hTempParentGUI[48], $g_aTempWindowSize[48][2], $g_nIndex = 0 ;//Method 1 of hiding window

Global $SEMAPHORE = 1

Main()


Func Main()
   InitializeConfigs()
   InitializeLanguage()
   InitializeTray()
   InitializeGUIs()

   ;//Exit if MTT is already running.
   If _Singleton("MTT", 1) = 0 Then
	  TrayTip("MinimizeToTray " & $VERSION, $sTextId_Already_Running, 2)
	  Sleep(2000)
	  Exit
   EndIf

   TrayTip("MinimizeToTray " & $VERSION, $sTextId_Msg_Help_1_Press & " [" & _GuiCtrlHotkey_NameFromAutoItHK($sHK_HideWnd) & "] " & $sTextId_Msg_Help_2_To_Hide_Active & @CRLF _
		  & $sTextId_Msg_Help_1_Press & " [" & _GuiCtrlHotkey_NameFromAutoItHK($sHK_RestoreLastWnd) & "] " & $sTextId_Msg_Help_3_To_Restore & @CRLF _
		  & $sTextId_Msg_Help_4_Stored_In_Tray, 5)

   RestoreLastShutdownWindows()

   ;//Main Loop
   While 1
	  HandleTrayEvents()
   WEnd
EndFunc

; Read ini config file, set current global hotkeys
Func InitializeConfigs()
   Global $sHK_HideWnd = IniRead($CONFIG_INI, "Hotkeys", "HIDE_WINDOW", $DEFAULT_HIDE_WND_HK)
   Global $sHK_RestoreLastWnd = IniRead($CONFIG_INI, "Hotkeys", "RESTORE_LAST_WINDOW", $DEFAULT_RESTORE_LAST_WND_HK)
   Global $sHK_RestoreAllWnd = IniRead($CONFIG_INI, "Hotkeys", "RESTORE_ALL_WINDOWS", $DEFAULT_RESTORE_ALL_WND_HK)

   Global $sRestoreAllWndsOnExit = IniRead($CONFIG_INI, "Extra", "RESTORE_ALL_WINDOWS_ON_EXIT", "False")
   Global $sAltF4EndProcess = IniRead($CONFIG_INI, "Extra", "ALT_F4_FORCE_END_PROCESS", "False")
   Global $sSaveLegacyWindows = IniRead($CONFIG_INI, "Extra", "SAVE_LEGACY_WINDOWS", "False")
   Global $sRestoreFocus = IniRead($CONFIG_INI, "Extra", "RESTORE_FOCUS", "False")

   Global $bAltF4EndProcess = TextToBool($sAltF4EndProcess)
   Global $bRestoreOnExit = TextToBool($sRestoreAllWndsOnExit)
   Global $bSaveLegacyWindows = TextToBool($sSaveLegacyWindows)
   Global $bRestoreFocus = TextToBool($sRestoreFocus)

   Global $sLanguage = IniRead($CONFIG_INI, "Extra", "LANGUAGE", "en")

   HotKeySet($sHK_HideWnd, "HideCurrentWnd")
   HotKeySet($sHK_RestoreLastWnd, "RestoreLastWnd")
   HotKeySet("!{f4}", "HandleAltF4")
   HotKeySet($sHK_RestoreAllWnd, "RestoreAllWnd")
   OnAutoItExitRegister("ExitS")
EndFunc

Func InitializeLanguage()
   Local $sLanguageFile = FileRead("language_gen\" & $sLanguage & ".json")
   Local $hJobj = Json_Decode($sLanguageFile)
   Global $sTextId_Already_Running = LoadTextFromLanguageJsonObj($hJobj, '["TextId_Already_Running"]')
   Global $sTextId_Tray_Restore_All_Windows = LoadTextFromLanguageJsonObj($hJobj, '["TextId_Tray_Restore_All_Windows"]')
   Global $sTextId_Tray_Extra = LoadTextFromLanguageJsonObj($hJobj, '["TextId_Tray_Extra"]')
   Global $sTextId_Tray_Opt_AltF4_Force_Exit_Desc = LoadTextFromLanguageJsonObj($hJobj, '["TextId_Tray_Opt_AltF4_Force_Exit_Desc"]')
   Global $sTextId_Tray_Opt_Restore_On_Exit_Desc = LoadTextFromLanguageJsonObj($hJobj, '["TextId_Tray_Opt_Restore_On_Exit_Desc"]')
   Global $sTextId_Tray_Opt_Save_Legacy_Windows_Desc = LoadTextFromLanguageJsonObj($hJobj, '["TextId_Tray_Opt_Save_Legacy_Windows_Desc"]')
   Global $sTextId_Tray_Opt_Restore_Focus = LoadTextFromLanguageJsonObj($hJobj, '["TextId_Tray_Opt_Restore_Focus"]')
   Global $sTextId_Tray_Edit_Hotkeys = LoadTextFromLanguageJsonObj($hJobj, '["TextId_Tray_Edit_Hotkeys"]')
   Global $sTextId_Tray_Quick_Help = LoadTextFromLanguageJsonObj($hJobj, '["TextId_Tray_Quick_Help"]')
   Global $sTextId_Tray_Exit = LoadTextFromLanguageJsonObj($hJobj, '["TextId_Tray_Exit"]')
   Global $sTextId_GUI_Edit_Hotkeys = LoadTextFromLanguageJsonObj($hJobj, '["TextId_GUI_Edit_Hotkeys"]')
   Global $sTextId_GUI_OK = LoadTextFromLanguageJsonObj($hJobj, '["TextId_GUI_OK"]')
   Global $sTextId_GUI_Default = LoadTextFromLanguageJsonObj($hJobj, '["TextId_GUI_Default"]')
   Global $sTextId_GUI_Hide_Active_Window = LoadTextFromLanguageJsonObj($hJobj, '["TextId_GUI_Hide_Active_Window"]')
   Global $sTextId_GUI_Restore_Last_Window = LoadTextFromLanguageJsonObj($hJobj, '["TextId_GUI_Restore_Last_Window"]')
   Global $sTextId_GUI_Restore_All_Windows = LoadTextFromLanguageJsonObj($hJobj, '["TextId_GUI_Restore_All_Windows"]')
   Global $sTextId_GUI_Warning_Key_Overlap = LoadTextFromLanguageJsonObj($hJobj, '["TextId_GUI_Warning_Key_Overlap"]')
   Global $sTextId_GUI_Warning_Key_Empty = LoadTextFromLanguageJsonObj($hJobj, '["TextId_GUI_Warning_Key_Empty"]')
   Global $sTextId_GUI_Language = LoadTextFromLanguageJsonObj($hJobj, '["TextId_GUI_Language"]')
   Global $sTextId_Msg_Help_1_Press = LoadTextFromLanguageJsonObj($hJobj, '["TextId_Msg_Help_1_Press"]')
   Global $sTextId_Msg_Help_2_To_Hide_Active = LoadTextFromLanguageJsonObj($hJobj, '["TextId_Msg_Help_2_To_Hide_Active"]')
   Global $sTextId_Msg_Help_3_To_Restore = LoadTextFromLanguageJsonObj($hJobj, '["TextId_Msg_Help_3_To_Restore"]')
   Global $sTextId_Msg_Help_4_Stored_In_Tray = LoadTextFromLanguageJsonObj($hJobj, '["TextId_Msg_Help_4_Stored_In_Tray"]')
   Global $sTextId_Msg_Help_5_Elevated_Window_Admin = LoadTextFromLanguageJsonObj($hJobj, '["TextId_Msg_Help_5_Elevated_Window_Admin"]')
EndFunc

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
   $hTrayLine1 = TrayCreateItem("") ;//Create a straight line

   $hTrayOpt = TrayCreateMenu($sTextId_Tray_Extra)
   Global $hTrayAltF4EndProcess = TrayCreateItem($sTextId_Tray_Opt_AltF4_Force_Exit_Desc, $hTrayOpt)
   TrayItemSetState($hTrayAltF4EndProcess, $bAltF4EndProcess)
   Global $hTrayRestoreOnExit = TrayCreateItem($sTextId_Tray_Opt_Restore_On_Exit_Desc, $hTrayOpt)
   TrayItemSetState($hTrayRestoreOnExit, $bRestoreOnExit)
   Global $hTraySaveLegacyWindows = TrayCreateItem($sTextId_Tray_Opt_Save_Legacy_Windows_Desc, $hTrayOpt)
   TrayItemSetState($hTraySaveLegacyWindows, $bSaveLegacyWindows)
   Global $hTrayRestoreFocus = TrayCreateItem($sTextId_Tray_Opt_Restore_Focus, $hTrayOpt)
   TrayItemSetState($hTrayRestoreFocus, $bRestoreFocus)

   Global $hTrayEditHotkeys = TrayCreateItem($sTextId_Tray_Edit_Hotkeys)
   Global $hTrayHelp = TrayCreateItem($sTextId_Tray_Quick_Help)
   Global $hTrayExit = TrayCreateItem($sTextId_Tray_Exit)
EndFunc

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

    Local $sLangDir = @ScriptDir & "\language_gen" ; Assumes language_gen is in the same dir as the script/exe
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
            If StringLower($sLangCode) == StringLower($sLanguage) Then
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
    ; Use the dynamically generated list and the validated $sLanguage
    GUICtrlSetData($hGUIConfigs_Language, $sLangListString, $sLanguage)
EndFunc

Func HandleTrayEvents()
   $hTrayMsg = TrayGetMsg()
   Switch $hTrayMsg
	  Case $hTrayAltF4EndProcess
		 ToggleOpt($bAltF4EndProcess, $hTrayAltF4EndProcess)
		 IniWrite($CONFIG_INI, "Extra", "ALT_F4_FORCE_END_PROCESS", BoolToText($bAltF4EndProcess))
	  Case $hTrayRestoreOnExit
		 ToggleOpt($bRestoreOnExit, $hTrayRestoreOnExit)
		 IniWrite($CONFIG_INI, "Extra", "RESTORE_ALL_WINDOWS_ON_EXIT", BoolToText($bRestoreOnExit))
	  Case $hTraySaveLegacyWindows
		 ToggleOpt($bSaveLegacyWindows, $hTraySaveLegacyWindows)
		 IniWrite($CONFIG_INI, "Extra", "SAVE_LEGACY_WINDOWS", BoolToText($bSaveLegacyWindows))
	  Case $hTrayRestoreFocus
		 ToggleOpt($bRestoreFocus, $hTrayRestoreFocus)
		 IniWrite($CONFIG_INI, "Extra", "RESTORE_FOCUS", BoolToText($bRestoreFocus))
	  Case $hTrayRestoreAllWnd
		 RestoreAllWnd()
	  Case $hTrayExit
		 ExitS()
	  Case $hTrayHelp
		 Help()
	  Case $hTrayEditHotkeys
		 EditHotkeys()
   EndSwitch

   If $SEMAPHORE = 0 Then  ; No mutex locks in AutoIt. Pseudo-mutex implementation failed. This is a workaround..
	  Return
   EndIf

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
			If $sHK_HideWnd == "" Then
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
   If $SEMAPHORE = 0 Then
   Return
   EndIf
   $SEMAPHORE = 0
   Local $nIndex = _ArraySearch($aHiddenWndList, $hfWnd)
   WinSetState($hfWnd, "", @SW_SHOW)
   If $bRestoreFocus == True Then
	  WinActivate($hfWnd)
   EndIf
   If $nIndex >= 0 Then
	  If $nIndex < UBound($aTrayItemHandles) Then
		 TrayItemDelete($aTrayItemHandles[$nIndex])
		 _ArrayDelete($aTrayItemHandles, $nIndex)
	  EndIf
	  If $nIndex < UBound($aHiddenWndList) Then
		 _ArrayDelete($aHiddenWndList, $nIndex)
	  EndIf

	  If $bSaveLegacyWindows Then
		 ;//Delete window's name from log file
		 $sLog = FileRead("MTTlog.txt")
		 $sLogN = StringReplace($sLog, WinGetTitle($hfWnd), "")
		 $fd = FileOpen("MTTlog.txt", 2)
		 FileWrite($fd, $sLogN)
		 FileClose($fd)
	  EndIf
   EndIf
   $SEMAPHORE = 1
EndFunc   ;==>RestoreWnd


Func HideCurrentWnd()
    ; Get the handle of the window that is currently active.
    Local $hCurrentWndToHide = WinGetHandle("[ACTIVE]")

    ; If there's no active window or we got the desktop/shell, don't proceed.
    If $hCurrentWndToHide = 0 Then Return

    ; Check if the window can be minimized - optional, but closer to real minimize behavior
    ; If Not BitAND(WinGetState($hCurrentWndToHide), 16) Then Return ; 16 = $WIN_STATE_MINIMIZED (check if minimizable) - Might prevent hiding some windows

    ; Send Alt+Esc. This typically shifts focus to the window
    ; that would become active if the current one was minimized.
    Send("!{ESC}")

    ; Give Windows a brief moment to process the Alt+Esc and change focus.
    ; Adjust this value if needed (50-150ms is usually sufficient).
    Sleep(100)
    ; === End Key Change ===

    ; Now, hide the window we originally targeted (which should no longer be active).
    ; We call HideWnd directly, passing the handle we saved earlier.
    HideWnd($hCurrentWndToHide)

EndFunc   ;==>HideCurrentWnd


Func HideWnd($hfWnd)
    If $SEMAPHORE = 0 Then
        Return
    EndIf
    $SEMAPHORE = 0

    ; Just hide the window - focus was handled before calling this function.
    WinSetState($hfWnd, "", @SW_HIDE)

    _ArrayAdd($aHiddenWndList, $hfWnd)

    Local $sTitle = WinGetTitle($hfWnd)
    If @error Then $sTitle = "[Error Getting Title]"
    If $sTitle = "" Then $sTitle = "[No Title]"

    Local $hTrayWnd = TrayCreateItem($sTitle, -1, 0) ;, $hTrayMenuShowSelectWnd)
    _ArrayAdd($aTrayItemHandles, $hTrayWnd)
    $SEMAPHORE = 1

    If $bSaveLegacyWindows Then
        FileWrite("MTTlog.txt", $sTitle & @CRLF)
    EndIf
    $hLastWnd = $hfWnd
EndFunc   ;==>HideWnd


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

Func LoadTextFromLanguageJsonObj(ByRef $hJobj, $sKey)
   $sValue = Json_Get($hJobj, $sKey)
   If $sValue Then
	  Return $sValue
   Else
	  Return "Language_Load_Error"
   EndIf
EndFunc

Func Help()
   MsgBox(64, "MinimizeToTray " & $VERSION, $sTextId_Msg_Help_1_Press & " [" & _GuiCtrlHotkey_NameFromAutoItHK($sHK_HideWnd) & "] " & $sTextId_Msg_Help_2_To_Hide_Active & @CRLF _
		  & $sTextId_Msg_Help_1_Press & " [" & _GuiCtrlHotkey_NameFromAutoItHK($sHK_RestoreLastWnd) & "] " & $sTextId_Msg_Help_3_To_Restore & @CRLF _
		  & $sTextId_Msg_Help_4_Stored_In_Tray & @CRLF _
		  & $sTextId_Msg_Help_5_Elevated_Window_Admin & @CRLF & @CRLF _
		  & "https://github.com/sandwichdoge/MinimizeToTray")
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
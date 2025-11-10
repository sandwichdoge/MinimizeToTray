# MinimizeToTray

MinimizeToTray is a simple application for Windows. It helps reduce taskbar clutter by allowing you to minimize any open window directly to the system tray. Minimized windows can be easily restored whenever needed.

No installation required.

![image](https://github.com/user-attachments/assets/c2a1ae90-6998-461b-bd60-b6085a318c7d)

**Basic Usage:**

1. Launch the MinimizeToTray application.
2. To minimize the active window to the system tray, press **Alt+F1** (configurable).
3. To restore the last window you minimized, press **Alt+F2** (configurable).
4. Alternatively, right-click the MinimizeToTray icon in the system tray to see a list of all minimized applications. Click any application in the list to restore its window.

**Shortcut Definition:**

1. Create a file named `MTTconf.ini` in the same folder where `MinimizeToTray.exe` is located
2. Write the following content and specify the desired shortcuts

```html
[Hotkeys]
HIDE_WINDOW=<shortcut>
RESTORE_LAST_WINDOW=<shortcut>
RESTORE_ALL_WINDOWS=<shortcut>

; OPTIONAL - you can also choose the start language here!
[Extra]
LANGUAGE=en
```

3. Choose your shorctus based on the AutoIt3 specification https://www.autoitscript.com/autoit3/docs/appendix/SendKeys.htm#KeysList

Some processes may need MinimizeToTray to be run with Admin privileges to be hidden.

**How to build and run from source:**

1. Install AutoIt3.
2. Use Aut2exe on MinimizeToTray.au3 to build an executable file.
3. Or simply run the script with AutoIt3.exe.

https://www.softpedia.com/get/PORTABLE-SOFTWARE/System/System-Enhancements/Minimize-ToTray.shtml

Download: https://github.com/sandwichdoge/MinimizeToTray/releases/

@echo off
rem Run once: puts a "Phone Launcher" shortcut on your Desktop.
powershell -NoProfile -Command "$d='%~dp0'; $s=(New-Object -ComObject WScript.Shell).CreateShortcut([Environment]::GetFolderPath('Desktop')+'\Phone Launcher.lnk'); $s.TargetPath=$d+'phone.bat'; $s.WorkingDirectory=$d; $s.IconLocation=$d+'scrcpy\scrcpy.exe,0'; $s.Save(); 'Created: Phone Launcher shortcut on your Desktop.'"
pause

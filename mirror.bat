@echo off
rem Mirror the whole phone screen. Extra scrcpy options can be passed, e.g.  mirror --turn-screen-off
call "%~dp0connect.bat" quiet >nul
start "" "%~dp0scrcpy\scrcpy.exe" -s "%ANDROID_SERIAL%" --keep-active %*

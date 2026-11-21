@echo off
rem Drop into a shell on the phone (adb's equivalent of ssh). Type exit to leave.
call "%~dp0connect.bat" quiet >nul
"%~dp0scrcpy\adb.exe" -s "%ANDROID_SERIAL%" shell

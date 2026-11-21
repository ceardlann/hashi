@echo off
rem One-time install: downloads scrcpy + adb into .\scrcpy and creates your data files from the examples.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1" %*
pause

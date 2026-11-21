@echo off
rem Captures the usage-summary part of the phone's stats into the diag folder (about 10 seconds, no windows).
call "%~dp0connect.bat" quiet
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0diag-usage.ps1"
pause

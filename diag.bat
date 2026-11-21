@echo off
rem Saves raw phone output into the diag folder so Claude can diagnose problems.
call "%~dp0connect.bat" quiet
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0diag.ps1"
pause

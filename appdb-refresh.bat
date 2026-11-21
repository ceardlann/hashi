@echo off
rem Rebuilds appdb.csv (the app table) from the phone. Same as F5 inside the launcher.
call "%~dp0connect.bat" quiet
powershell -NoProfile -ExecutionPolicy Bypass -Command "& { . '%~dp0appdb.ps1'; Update-AppDb }"
pause

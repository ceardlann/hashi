@echo off
rem  apps              -> list your (user) apps with package names
rem  apps youtube      -> only matches for "youtube"
rem  apps -All         -> include system apps     apps -Refresh  -> re-read from phone
call "%~dp0connect.bat" quiet >nul
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0applist.ps1" %*

@echo off
rem Terminal launcher for the phone: categories, search, top apps, bookmarks.
call "%~dp0connect.bat" quiet
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0phone.ps1"

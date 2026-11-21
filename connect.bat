@echo off
setlocal enabledelayedexpansion
rem Finds the phone and sets ANDROID_SERIAL for the script that called it.
rem Order: already connected (USB or Wi-Fi) > mDNS discovery on the LAN > last address > ask.
rem   connect         -> connect and show which device is used
rem   connect quiet   -> same, no pause (other scripts call it this way)
set "HERE=%~dp0"
if not exist "%HERE%scrcpy\adb.exe" (echo adb not found in "%HERE%scrcpy" - run setup.bat first. 1>&2 & endlocal & exit /b 1)
pushd "%HERE%scrcpy"
rem 1) already connected?
call :pick
if defined SER goto :done
rem 2) auto-discover the paired phone on the LAN via mDNS
echo Looking for your phone on the network... 1>&2
for /f "tokens=3" %%a in ('adb.exe mdns services 2^>nul ^| findstr /c:"_adb-tls-connect"') do (
  adb.exe connect %%a >nul 2>&1
  >"%HERE%last-phone.txt" echo %%a
)
call :pick
if defined SER goto :done
rem 3) last address that worked
set "LAST="
if exist "%HERE%last-phone.txt" set /p LAST=<"%HERE%last-phone.txt"
if defined LAST (
  echo Trying last address !LAST! ... 1>&2
  adb.exe connect !LAST! >nul 2>&1
  call :pick
)
if defined SER goto :done
rem 4) ask (prompt goes to stderr so it shows even when a caller hides our output)
echo Phone not found. On the phone: Developer options ^> Wireless debugging ^> IP address ^& Port. 1>&2
echo Type that IP:port (blank = give up): 1>&2
set "CONN="
set /p CONN=
if defined CONN (
  adb.exe connect !CONN! >nul 2>&1
  call :pick
  if defined SER >"%HERE%last-phone.txt" echo !CONN!
)
:done
popd
if not defined SER (
  echo No phone connected. Check Wireless debugging is ON ^(or USB is plugged in^), then run connect again. 1>&2
  if /i not "%~1"=="quiet" pause
  endlocal & set "ANDROID_SERIAL=" & exit /b 1
)
if /i not "%~1"=="quiet" (echo Using device: !SER! & pause)
endlocal & set "ANDROID_SERIAL=%SER%" & exit /b 0

:pick
rem Pick ONE serial (the phone can show up twice: IP:port and mDNS name). Prefer the mDNS
rem name - it survives the port changing after reboots.
set "SER="
for /f "skip=1 tokens=1,2" %%a in ('adb.exe devices') do if "%%b"=="device" (
  if not defined SER set "SER=%%a"
  echo %%a| findstr /c:"_adb-tls-connect" >nul && set "SER=%%a"
)
exit /b 0

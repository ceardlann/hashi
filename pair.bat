@echo off
setlocal
set "S=%~dp0scrcpy"
echo.
echo === Pair your phone (one time) ===
echo On the phone: Settings ^> System ^> Developer options ^> Wireless debugging
echo   ^> "Pair device with pairing code"
echo.
set /p PAIR=STEP 1 - IP:port shown INSIDE the pairing-code popup (e.g. 192.168.1.50:37123): 
set /p CODE=6-digit pairing code: 
"%S%\adb.exe" pair %PAIR% %CODE%
if errorlevel 1 (echo Pairing failed - check the numbers and try again. & pause & exit /b 1)
echo.
echo Paired. Now the CONNECT address: the IP:port on the main Wireless debugging
echo screen (under "IP address ^& Port") - it is a different port than pairing.
set /p CONN=STEP 2 - IP:port on the main Wireless debugging screen: 
"%S%\adb.exe" connect %CONN%
echo %CONN%> "%~dp0last-phone.txt"
"%S%\adb.exe" devices -l
echo.
echo Done. From now on use connect.bat (or just run mirror.bat / droid.bat).
pause

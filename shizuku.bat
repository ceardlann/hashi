@echo off
setlocal
rem Starts Shizuku on the phone over adb.
rem New Shizuku versions start from a native library whose path contains random folder names,
rem so we look the path up with pm path each time. Older versions use a start.sh instead.
rem Shizuku stops when the phone reboots - run this again afterwards.
call "%~dp0connect.bat" quiet >nul
if not defined ANDROID_SERIAL (echo No phone found. Run connect.bat first. & pause & exit /b 1)
set "A=%~dp0scrcpy\adb.exe"
set "P=moe.shizuku.privileged.api"

"%A%" -s "%ANDROID_SERIAL%" shell "pm path %P%" | findstr /i "package:" >nul
if errorlevel 1 (echo Shizuku is not installed on the phone. & pause & exit /b 1)

echo Starting Shizuku...
"%A%" -s "%ANDROID_SERIAL%" shell "d=$(pm path %P% | head -1 | cut -d: -f2 | sed 's#/base.apk$##'); if [ -x $d/lib/arm64/libshizuku.so ]; then $d/lib/arm64/libshizuku.so; elif [ -f /sdcard/Android/data/%P%/start.sh ]; then sh /sdcard/Android/data/%P%/start.sh; else echo Could not find Shizuku starter in $d; ls $d/lib; fi"
echo.
timeout /t 3 /nobreak >nul
"%A%" -s "%ANDROID_SERIAL%" shell "ps -A" | findstr /i shizuku_server >nul
if errorlevel 1 (
  echo Could not confirm it is running. Open the Shizuku app on the phone and check its status.
) else (
  echo Shizuku is running.
)
if /i not "%~1"=="quiet" pause

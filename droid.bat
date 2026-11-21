@echo off
setlocal
rem  droid <app>   -> opens that app in its OWN resizable window on a virtual display;
rem                   the real phone screen stays off/locked and untouched.
rem  <app> = package (com.spotify.music), an alias from aliases.txt, or an app name (youtube).
rem  Ambiguous names prompt you once and the choice is saved to aliases.txt.
rem  Optional 2nd word = window shape:  (none) landscape 1280x960 | phone = phone-shaped | big = 1920x1080
rem  Optional: set DROID_OPTS=... for extra scrcpy flags, e.g. set DROID_OPTS=--no-audio
if "%~1"=="" (
  echo Usage: droid ^<app name, alias or package^>     e.g.  droid youtube   /  droid com.android.settings
  echo        apps   ^(lists installed apps^)
  exit /b 1
)
call "%~dp0connect.bat" quiet >nul
set "PKG="
for /f "usebackq delims=" %%p in (`powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0resolve-app.ps1" "%~1"`) do set "PKG=%%p"
if not defined PKG exit /b 1
rem Wake the phone and dismiss the lock screen if it can be dismissed without a PIN
rem (e.g. Smart Lock / trusted place). A locked phone = black window on the virtual display.
"%~dp0scrcpy\adb.exe" -s "%ANDROID_SERIAL%" shell "input keyevent KEYCODE_WAKEUP; wm dismiss-keyguard" >nul 2>&1
rem Audio stays on the phone by default. Set DROID_AUDIO=pc (play on PC) or DROID_AUDIO=both (PC and phone).
set "AUDIO=--no-audio"
if /i "%DROID_AUDIO%"=="pc"   set "AUDIO="
if /i "%DROID_AUDIO%"=="both" set "AUDIO=--audio-dup"
set "SHAPE=--new-display"
if /i "%~2"=="phone" set "SHAPE=--new-display=1080x2400/420"
if /i "%~2"=="big"   set "SHAPE=--new-display=1920x1080/200"
echo Launching %PKG% ...  (black window? unlock the phone - it fills in instantly)
start "droid %~1" "%~dp0scrcpy\scrcpy.exe" -s "%ANDROID_SERIAL%" %SHAPE% -x --keep-active --hwdec=disabled -b16M --window-title="%~1" %AUDIO% --start-app=%PKG% %DROID_OPTS%

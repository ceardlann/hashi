@echo off
setlocal
rem Black-window diagnosis: runs 4 variants one after another. Close each window
rem (X or Alt+Q) to move to the next. Note which ones show a picture.
call "%~dp0connect.bat" quiet >nul
set "S=%~dp0scrcpy\scrcpy.exe"
echo.
echo  UNLOCK THE PHONE and leave it on the home screen before continuing.
pause
echo.
echo [TEST A] plain mirror of the phone screen
"%S%" -s "%ANDROID_SERIAL%" --window-title="TEST A - plain mirror" 
echo.
echo [TEST B] virtual display, NO flex (-x), hardware decoding
"%S%" -s "%ANDROID_SERIAL%" --new-display --start-app=com.android.settings --window-title="TEST B - virtual, no flex"
echo.
echo [TEST C] virtual display, NO flex, SOFTWARE decoding
"%S%" -s "%ANDROID_SERIAL%" --new-display --start-app=com.android.settings --hwdec=disabled --window-title="TEST C - virtual, sw decode"
echo.
echo [TEST D] virtual display WITH flex (-x), SOFTWARE decoding
"%S%" -s "%ANDROID_SERIAL%" --new-display -x --start-app=com.android.settings --hwdec=disabled --window-title="TEST D - flex, sw decode"
echo.
echo Done. Tell Claude which of A / B / C / D showed a picture.
pause

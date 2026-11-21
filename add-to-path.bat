@echo off
rem Optional, run once: adds this folder to YOUR user PATH so "droid spotify" works from any terminal.
powershell -NoProfile -Command "$d='%~dp0'.TrimEnd('\'); $p=[Environment]::GetEnvironmentVariable('Path','User'); if (($p -split ';') -notcontains $d) { [Environment]::SetEnvironmentVariable('Path', ($p.TrimEnd(';') + ';' + $d), 'User'); 'Added ' + $d + ' to PATH. Open a NEW terminal to use it.' } else { 'Already on PATH.' }"
pause

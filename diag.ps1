# diag.ps1 - saves raw phone/adb output into .\diag so problems can be diagnosed. Read-only queries.
$root = $PSScriptRoot
$out  = Join-Path $root 'diag'
New-Item -ItemType Directory -Path $out -Force | Out-Null
Get-ChildItem $out -File -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
$adb = Join-Path $root 'scrcpy\adb.exe'
$scr = Join-Path $root 'scrcpy\scrcpy.exe'
$ser = $env:ANDROID_SERIAL
$pre = @(); if ($ser) { $pre = @('-s', $ser) }
function Q([string[]]$a) { & $adb @pre @a 2>&1 | ForEach-Object { "$_" } }
function Save([string]$name, $lines, [string]$note) {
  $arr = @($lines)
  (@("# $note", "# total lines: $($arr.Count)") + $arr) | Set-Content (Join-Path $out $name) -Encoding UTF8
  Write-Host ('{0,-40} {1,6} lines' -f $name, $arr.Count)
}
Write-Host 'Collecting diagnostics (about 45 seconds)...' -ForegroundColor Cyan
Save '00-env.txt' @("ANDROID_SERIAL=$ser", "PSVersion=$($PSVersionTable.PSVersion)", "Edition=$($PSVersionTable.PSEdition)") 'environment'
Save '01-devices.txt' (& $adb devices -l 2>&1 | ForEach-Object { "$_" }) 'adb devices -l'
Save '02-shell-test.txt' (Q @('shell', 'echo hello; getprop ro.build.version.release; getprop ro.build.version.sdk; getprop ro.product.model')) 'shell test'
$pl = @(Q @('shell', 'pm list packages -i'))
Save '03-pm-list-installer.txt' ($pl | Select-Object -First 25) 'pm list packages -i (first 25)'
$us = @(Q @('shell', 'dumpsys usagestats'))
Save '04-usagestats-head.txt' ($us | Select-Object -First 100) 'dumpsys usagestats (first 100 lines)'
Save '05-usagestats-samples.txt' ($us | Where-Object { $_ -match 'stats|package=com\.android\.settings |package=com\.termux |package=com\.google\.android\.youtube ' } | Select-Object -First 120) 'usagestats headers and sample packages'
$dp = @(Q @('shell', 'dumpsys package com.android.settings'))
Save '06-package-settings.txt' ($dp | Where-Object { $_ -match 'Package \[|versionName|firstInstallTime|lastUpdateTime|installerPackageName|installInitiatingPackageName' } | Select-Object -First 40) 'dumpsys package com.android.settings (filtered)'
$ds = @(Q @('shell', 'dumpsys display'))
Save '07-display-ids-before.txt' ($ds | Where-Object { $_ -match 'mDisplayId|^\s*Display \d+:|Logical Displays' } | Select-Object -First 60) 'dumpsys display ids, before any test window'
$ac = @(Q @('shell', 'dumpsys activity activities'))
Save '08-activity-top.txt' ($ac | Where-Object { $_ -match 'topResumedActivity|ResumedActivity|mFocusedApp|Intent \{' } | Select-Object -First 40) 'dumpsys activity (top screen)'

$old = @(Get-Process scrcpy -ErrorAction SilentlyContinue | ForEach-Object { $_.Id })
$sa = '--new-display -x --hwdec=disabled --start-app=com.android.settings --window-title="diag test"'
if ($ser) { $sa = "-s `"$ser`" $sa" }

Write-Host 'Test A: scrcpy started directly, output captured by PowerShell (window opens 9 seconds)...'
$lo = Join-Path $out '09-testA.stdout.txt'; $le = Join-Path $out '09-testA.stderr.txt'
$pr = Start-Process -FilePath $scr -ArgumentList $sa -RedirectStandardOutput $lo -RedirectStandardError $le -PassThru -NoNewWindow
Start-Sleep -Seconds 9
$dsA = @(Q @('shell', 'dumpsys display'))
Save '09-testA-display-ids.txt' ($dsA | Where-Object { $_ -match 'mDisplayId|^\s*Display \d+:' } | Select-Object -First 60) 'display ids while test A window is open'
Get-Process scrcpy -ErrorAction SilentlyContinue | Where-Object { $old -notcontains $_.Id } | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

Write-Host 'Test B: scrcpy started through cmd with a redirect, the way phone.ps1 does it (9 seconds)...'
$lb = Join-Path $out '10-testB.cmdlog.txt'
$cl = '/c ""{0}" {1} > "{2}" 2>&1"' -f $scr, $sa, $lb
Start-Process -FilePath $env:ComSpec -ArgumentList $cl -WindowStyle Hidden
Start-Sleep -Seconds 9
$dsB = @(Q @('shell', 'dumpsys display'))
Save '10-testB-display-ids.txt' ($dsB | Where-Object { $_ -match 'mDisplayId|^\s*Display \d+:' } | Select-Object -First 60) 'display ids while test B window is open'
Get-Process scrcpy -ErrorAction SilentlyContinue | Where-Object { $old -notcontains $_.Id } | Stop-Process -Force -ErrorAction SilentlyContinue
foreach ($f in @($lo, $le, $lb)) {
  if (Test-Path $f) { Write-Host ('{0,-40} {1,6} bytes' -f (Split-Path $f -Leaf), (Get-Item $f).Length) } else { Write-Host ('{0,-40} MISSING' -f (Split-Path $f -Leaf)) -ForegroundColor Yellow }
}
Write-Host ''
Write-Host 'Done. Everything is in the diag folder. Tell Claude it finished.' -ForegroundColor Green

# diag-usage.ps1 - captures the per-app usage SUMMARY part of dumpsys usagestats (no windows open, ~10 seconds)
$root = $PSScriptRoot
$out  = Join-Path $root 'diag'
New-Item -ItemType Directory -Path $out -Force | Out-Null
$adb = Join-Path $root 'scrcpy\adb.exe'
$pre = @(); if ($env:ANDROID_SERIAL) { $pre = @('-s', $env:ANDROID_SERIAL) }
function Save([string]$name, $lines, [string]$note) {
  $arr = @($lines)
  (@("# $note", "# total lines: $($arr.Count)") + $arr) | Set-Content (Join-Path $out $name) -Encoding UTF8
  Write-Host ('{0,-40} {1,6} lines' -f $name, $arr.Count)
}
Write-Host 'Reading usage stats...' -ForegroundColor Cyan
$us = @(& $adb @pre shell dumpsys usagestats 2>&1 | ForEach-Object { "$_" })
Write-Host ('usagestats total lines: {0}' -f $us.Count)
$non = @($us | Where-Object { $_ -notmatch '^\s+time="' })
Save '20-usagestats-nonevent-head.txt' ($non | ForEach-Object { if ($_.Length -gt 300) { $_.Substring(0, 300) } else { $_ } } | Select-Object -First 160) 'usagestats lines that are NOT individual events (first 160)'
Save '21-usagestats-totaltime-lines.txt' ($us | Where-Object { $_ -match 'totalTime' } | Select-Object -First 30) 'lines containing totalTime (first 30)'
Save '22-usagestats-headers.txt' ($us | Where-Object { $_ -match '^\S|^\s{0,3}\S.*(stats|Stats|interval|packages|version=|beginTime)' -and $_ -notmatch '^\s+time="' } | Select-Object -First 80) 'section header candidates'
$cnt = $us | Where-Object { $_ -match 'type=([A-Z_]+)' } | ForEach-Object { $matches[1] } | Group-Object | Sort-Object Count -Descending | ForEach-Object { '{0,6}  {1}' -f $_.Count, $_.Name }
Save '23-usagestats-event-types.txt' $cnt 'event type counts'
Write-Host 'Done. Tell Claude it finished.' -ForegroundColor Green

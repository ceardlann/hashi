# appdb.ps1 - builds and loads the app table (appdb.csv). Dot-source it; it takes no parameters.
#   Update-AppDb   pulls names, install source, usage stats, install dates from the phone -> appdb.csv
#   Get-AppDb      loads appdb.csv (categories.csv always wins, so category edits need no phone refresh)
#   Invoke-Adb     runs adb against the connected phone (always passes -s when a phone is selected)
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}
. (Join-Path $PSScriptRoot 'applist.ps1')
$DbFile  = Join-Path $PSScriptRoot 'appdb.csv'
$CatFile = Join-Path $PSScriptRoot 'categories.csv'
$DbAdb   = Join-Path $PSScriptRoot 'scrcpy\adb.exe'
$DbDebug = Join-Path $PSScriptRoot 'appdb-debug-usagestats.txt'
$DbCols  = 'Name', 'Package', 'Category', 'Type', 'Installer', 'Installed', 'Updated', 'LastUsed', 'MinWeek', 'MinMonth', 'MinYear', 'PhoneLaunches', 'Version'

function Invoke-Adb {
  param([string[]]$AdbArgs)
  $pre = @()
  if ($env:ANDROID_SERIAL) { $pre = @('-s', $env:ANDROID_SERIAL) }
  & $DbAdb @pre @AdbArgs 2>&1 | ForEach-Object { "$_" }
}

# Makes sure ANDROID_SERIAL names exactly ONE connected phone (the phone can show up twice in adb:
# by IP:port and by its network name). Prefers the network name, which survives port changes.
function Select-Phone {
  $get = {
    @(& $DbAdb devices 2>&1 | ForEach-Object { "$_" } | ForEach-Object {
      $f = $_.Trim() -split '\s+'
      if ($f.Count -ge 2 -and $f[1] -eq 'device') { $f[0] }
    })
  }
  $devs = & $get
  if ($devs.Count -eq 0) {
    foreach ($s in @(& $DbAdb mdns services 2>&1 | ForEach-Object { "$_" } | Where-Object { $_ -match '_adb-tls-connect' })) {
      $addr = ($s.Trim() -split '\s+')[-1]
      if ($addr -match '^\d+\.\d+\.\d+\.\d+:\d+$') { & $DbAdb connect $addr 2>&1 | Out-Null; break }
    }
    Start-Sleep -Milliseconds 800
    $devs = & $get
  }
  $pick = @($devs | Where-Object { $_ -match '_adb-tls-connect' } | Select-Object -First 1)
  if (-not $pick) { $pick = @($devs | Select-Object -First 1) }
  if ($pick) { $env:ANDROID_SERIAL = "$($pick[0])"; return "$($pick[0])" }
  return $null
}

# "00:03:12", "+1h2m3s400ms", "+2m4s123ms" or plain milliseconds -> seconds
function ConvertTo-Sec([string]$t) {
  $t = "$t".Trim().Trim('"')
  if (-not $t) { return 0.0 }
  if ($t -match '^\d+(:\d+)+$') {
    $s = 0.0
    foreach ($p in ($t -split ':')) { $s = $s * 60 + [double]$p }
    return $s
  }
  if ($t -match '^\d+$') { return ([double]$t / 1000) }
  $s = 0.0
  foreach ($m in [regex]::Matches($t, '(\d+)(ms|d|h|m|s)')) {
    $n = [double]$m.Groups[1].Value
    switch ($m.Groups[2].Value) {
      'd'  { $s += $n * 86400 }
      'h'  { $s += $n * 3600 }
      'm'  { $s += $n * 60 }
      's'  { $s += $n }
      'ms' { $s += $n / 1000 }
    }
  }
  return $s
}
# "2026-11-09 22:10:11" or epoch milliseconds -> "yyyy-MM-dd HH:mm:ss" (else '')
function ConvertTo-StampText([string]$t) {
  $t = "$t".Trim().Trim('"')
  if ($t -match '^\d{4}-\d\d-\d\d \d\d:\d\d:\d\d$') { return $t }
  if ($t -match '^\d{12,}$') {
    try { return [DateTimeOffset]::FromUnixTimeMilliseconds([long]$t).LocalDateTime.ToString('yyyy-MM-dd HH:mm:ss') } catch { return '' }
  }
  return ''
}
function ConvertTo-Num($s) { $n = 0.0; [void][double]::TryParse("$s", [ref]$n); $n }

function Get-CategoryMap {
  $m = @{}
  if (Test-Path $CatFile) { foreach ($r in (Import-Csv $CatFile)) { if ($r.Package) { $m[$r.Package] = $r } } }
  $m
}
function Save-CategoryMap($m) {
  $m.Values | Sort-Object Category, Name | Select-Object Package, Category, Name, DisplayName |
    Export-Csv $CatFile -NoTypeInformation -Encoding UTF8
}

function Update-AppDb {
  Write-Host "Building the app table from the phone (about 20-40 seconds)..." -ForegroundColor Cyan
  Write-Host "  1/4 app names"
  Update-AppCache
  $list = @(Get-Apps)
  if ($list.Count -eq 0) { Write-Host "No apps read - is the phone connected? Run connect.bat." -ForegroundColor Red; return }

  Write-Host "  2/4 where each app was installed from"
  $inst = @{}
  $o2 = @(Invoke-Adb @('shell', 'pm list packages -i'))
  foreach ($l in $o2) { if ($l -match '^package:(\S+)\s+installer=(\S+)') { $inst[$matches[1]] = $matches[2] } }
  if ($inst.Count -eq 0) { Write-Host ("     no install info understood. Phone said: {0}" -f ($o2 | Select-Object -First 1)) -ForegroundColor Yellow }

  Write-Host "  3/4 usage statistics (last used, time in app)"
  $use = @{}; $sec = ''
  $rawU = @(Invoke-Adb @('shell', 'dumpsys usagestats'))
  foreach ($l in $rawU) {
    if ($l -notmatch '^\s*package=') {
      if ($l -match '(?i)\b(daily|weekly|monthly|yearly)\b.{0,12}\bstats\b') { $sec = $matches[1].ToLower() }
      continue
    }
    if (-not $sec) { continue }
    if ($l -notmatch 'package=(\S+)') { continue }
    $p = $matches[1]
    $t = 0.0; if ($l -match 'totalTimeUsed="?([^"\s]+)') { $t = ConvertTo-Sec $matches[1] }
    $lu = ''; if ($l -match 'lastTimeUsed="([^"]*)"') { $lu = ConvertTo-StampText $matches[1] }
    $lc = 0;  if ($l -match 'appLaunchCount=(\d+)') { $lc = [int]$matches[1] }
    if (-not $use.ContainsKey($p)) { $use[$p] = @{ daily = 0.0; weekly = 0.0; monthly = 0.0; yearly = 0.0; last = ''; launches = 0 } }
    $u = $use[$p]
    if ($u.ContainsKey($sec) -and $t -gt $u[$sec]) { $u[$sec] = $t }
    if ($lu -and $lu -notmatch '^19' -and $lu -gt $u.last) { $u.last = $lu }
    if ($lc -gt $u.launches) { $u.launches = $lc }
  }
  if ($use.Count -eq 0) {
    if ($rawU.Count -eq 0) { 'EMPTY OUTPUT from: adb shell dumpsys usagestats' | Set-Content $DbDebug -Encoding UTF8 }
    else { $rawU | Select-Object -First 300 | Set-Content $DbDebug -Encoding UTF8 }
    Write-Host ("     no usage data understood. Phone said: {0}" -f ($rawU | Select-Object -First 1)) -ForegroundColor Yellow
  }

  Write-Host "  4/4 install dates and versions (the slow one)"
  $pk = @{}; $cur = $null
  $rawP = @(Invoke-Adb @('shell', 'dumpsys package packages'))
  switch -Regex ($rawP) {
    '^\s*Package \[([^\]]+)\]' {
      if ($pk.ContainsKey($matches[1])) { $cur = $null } else { $cur = @{ ver = ''; first = ''; upd = '' }; $pk[$matches[1]] = $cur }
      continue
    }
    '^\s+versionName=(\S+)'              { if ($cur -and -not $cur.ver)   { $cur.ver   = $matches[1] }; continue }
    'firstInstallTime=(\d{4}-\d\d-\d\d)' { if ($cur -and -not $cur.first) { $cur.first = $matches[1] }; continue }
    'lastUpdateTime=(\d{4}-\d\d-\d\d)'   { if ($cur -and -not $cur.upd)   { $cur.upd   = $matches[1] }; continue }
  }
  if ($pk.Count -eq 0) { Write-Host ("     no package details understood. Phone said: {0}" -f ($rawP | Select-Object -First 1)) -ForegroundColor Yellow }

  $cats = Get-CategoryMap
  $rows = foreach ($a in $list) {
    $c = $cats[$a.Pkg]; $u = $use[$a.Pkg]; $k = $pk[$a.Pkg]
    $name = $a.Name
    if ($c -and $c.DisplayName) { $name = $c.DisplayName }
    $cat = 'Uncategorized'
    if ($c -and $c.Category) { $cat = $c.Category } elseif ($a.Sys) { $cat = 'System & Carrier' }
    $type = 'user'; if ($a.Sys) { $type = 'system' }
    $src = "$($inst[$a.Pkg])"
    if ($src -eq 'com.android.vending') { $src = 'Play Store' } elseif ($src -eq 'null' -or $src -eq '') { $src = 'preinstalled or sideloaded' }
    $o = [pscustomobject]@{
      Name = $name; Package = $a.Pkg; Category = $cat; Type = $type; Installer = $src
      Installed = ''; Updated = ''; LastUsed = ''; MinWeek = 0; MinMonth = 0; MinYear = 0; PhoneLaunches = 0; Version = ''
    }
    if ($k) { $o.Installed = $k.first; $o.Updated = $k.upd; $o.Version = $k.ver }
    if ($u) {
      $o.LastUsed = $u.last
      $o.MinWeek  = [int][math]::Round($u.weekly / 60)
      $o.MinMonth = [int][math]::Round($u.monthly / 60)
      $o.MinYear  = [int][math]::Round($u.yearly / 60)
      $o.PhoneLaunches = $u.launches
    }
    $o
  }
  $rows | Sort-Object Name | Select-Object $DbCols | Export-Csv $DbFile -NoTypeInformation -Encoding UTF8
  $nu = @($rows | Where-Object { $_.LastUsed -or $_.MinYear -gt 0 }).Count
  $nd = @($rows | Where-Object { $_.Installed }).Count
  $nc = @($rows | Where-Object { $_.Category -eq 'Uncategorized' }).Count
  Write-Host ("Done: {0} apps, usage data for {1}, install dates for {2}, {3} uncategorized -> appdb.csv" -f @($rows).Count, $nu, $nd, $nc) -ForegroundColor Green
}

function Get-AppDb {
  if (-not (Test-Path $DbFile)) { return }
  $cats = Get-CategoryMap
  foreach ($r in (Import-Csv $DbFile)) {
    $c = $cats[$r.Package]
    if ($c) {
      if ($c.Category)    { $r.Category = $c.Category }
      if ($c.DisplayName) { $r.Name = $c.DisplayName }
    }
    $d = $null
    try { if ($r.LastUsed) { $d = [datetime]::ParseExact($r.LastUsed, 'yyyy-MM-dd HH:mm:ss', $null) } } catch { $d = $null }
    $r | Add-Member -NotePropertyName nWeek  -NotePropertyValue (ConvertTo-Num $r.MinWeek)
    $r | Add-Member -NotePropertyName nMonth -NotePropertyValue (ConvertTo-Num $r.MinMonth)
    $r | Add-Member -NotePropertyName nYear  -NotePropertyValue (ConvertTo-Num $r.MinYear)
    $r | Add-Member -NotePropertyName dLast  -NotePropertyValue $d
    $r
  }
}

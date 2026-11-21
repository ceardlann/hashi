# applist.ps1 - shared app-list cache (Name <TAB> package <TAB> U=user app / S=system app)
#   dot-source for functions, or run:  applist.ps1 [-Refresh] [-Filter word] [-All]
param([switch]$Refresh, [string]$Filter = '', [switch]$All)
$script:Here   = $PSScriptRoot
$script:Cache  = Join-Path $PSScriptRoot 'apps-cache.txt'
$script:Scrcpy = Join-Path $PSScriptRoot 'scrcpy\scrcpy.exe'

# Fresh clone: create the editable data files from the shipped examples (never overwrites yours).
foreach ($p in @(@('aliases.example.txt','aliases.txt'), @('bookmarks.example.csv','bookmarks.csv'), @('categories.example.csv','categories.csv'))) {
  $s = Join-Path $PSScriptRoot $p[0]; $d = Join-Path $PSScriptRoot $p[1]
  if ((Test-Path $s) -and -not (Test-Path $d)) { Copy-Item $s $d }
}

function Update-AppCache {
  Write-Host "Reading app list from phone (a few seconds)..." -ForegroundColor DarkGray
  $a = @('--list-apps'); if ($env:ANDROID_SERIAL) { $a = @('-s', $env:ANDROID_SERIAL) + $a }
  $rows = & $script:Scrcpy @a 2>&1 | ForEach-Object { "$_" } |
    Where-Object { $_ -match '^\s*([*-])\s+(.+?)\s{2,}(\S+)\s*$' } |
    ForEach-Object { "{0}`t{1}`t{2}" -f $matches[2].Trim(), $matches[3], $(if ($matches[1] -eq '*') {'U'} else {'S'}) }
  if (-not $rows) { Write-Host "Could not read apps (is the phone connected?)" -ForegroundColor Red; return }
  @('#v2') + $rows | Set-Content $script:Cache -Encoding UTF8
}
function Get-Apps([switch]$Refresh) {
  if ($Refresh -or -not (Test-Path $script:Cache) -or (Get-Content $script:Cache -TotalCount 1) -ne '#v2') { Update-AppCache }
  if (-not (Test-Path $script:Cache)) { return @() }
  Get-Content $script:Cache -Encoding UTF8 | Select-Object -Skip 1 | ForEach-Object {
    $n,$p,$t = $_ -split "`t"; [pscustomobject]@{ Name=$n; Pkg=$p; Sys=($t -eq 'S') }
  } | Sort-Object Name
}

if ($MyInvocation.InvocationName -ne '.') {
  $apps = @(Get-Apps -Refresh:$Refresh)
  if (-not $All) { $apps = @($apps | Where-Object { -not $_.Sys }) }
  if ($Filter) { $apps = @($apps | Where-Object { "$($_.Name) $($_.Pkg)" -like "*$Filter*" }) }
  $apps | ForEach-Object { "{0,-34} {1}{2}" -f $_.Name, $_.Pkg, $(if ($_.Sys) {'  (system)'} else {''}) }
  Write-Host ("{0} app(s){1}. Launch with:  droid <package>   or   pick" -f $apps.Count, $(if ($All) {''} else {' (user apps; add -All for system apps)'})) -ForegroundColor DarkGray
}

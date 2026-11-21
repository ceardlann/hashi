# phone.ps1 - terminal launcher for the phone's apps. Start it with phone.bat.
. (Join-Path $PSScriptRoot 'appdb.ps1')
$Root    = $PSScriptRoot
$Adb     = Join-Path $Root 'scrcpy\adb.exe'
$Scrcpy  = Join-Path $Root 'scrcpy\scrcpy.exe'
$LogFile = Join-Path $Root 'launch-log.csv'
$BmFile  = Join-Path $Root 'bookmarks.csv'
$E       = [char]27
$Shapes  = @(
  @{ N = 'landscape'; A = '--new-display' },
  @{ N = 'phone';     A = '--new-display=1080x2400/420' },
  @{ N = 'big 1080p'; A = '--new-display=1920x1080/200' }
)
$ShapeIx = 0
$AudioModes = @(
  @{ N = 'phone only'; A = '--no-audio' },
  @{ N = 'PC only';    A = '' },
  @{ N = 'both';       A = '--audio-dup' }
)
$AudioIx = 0
$Sorts   = @('name', 'last used', 'most used', 'newest installed')
$SortIx  = 0
$Msg     = ''
$Apps = @(); $ByPkg = @{}; $Launches = @(); $Bms = @(); $Top10 = @()

function Fit([string]$s, [int]$w) { if ($s.Length -gt $w) { $s.Substring(0, $w) } else { $s.PadRight($w) } }
function Cut([string]$s, [int]$n) { if ($s.Length -gt $n) { $s.Substring(0, $n - 1) + '~' } else { $s } }
function Get-Rel($d) {
  if (-not $d) { return '' }
  $s = ((Get-Date) - $d).TotalSeconds
  if ($s -lt 60)     { return 'now' }
  if ($s -lt 3600)   { return ('{0}m ago' -f [int][math]::Floor($s / 60)) }
  if ($s -lt 172800) { return ('{0}h ago' -f [int][math]::Floor($s / 3600)) }
  return ('{0}d ago' -f [int][math]::Floor($s / 86400))
}
function Get-Dur($min) {
  if ($min -le 0) { return '' }
  if ($min -lt 60) { return ('{0}m' -f [int]$min) }
  return ('{0}h{1:00}m' -f [int][math]::Floor($min / 60), [int]($min % 60))
}
function Read-Shared([string]$p) {
  try {
    $fs = New-Object IO.FileStream($p, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
    $sr = New-Object IO.StreamReader($fs)
    $t = $sr.ReadToEnd(); $sr.Close(); $fs.Close(); $t
  } catch { '' }
}

function Add-Launch([string]$pkg, [string]$what) {
  if (-not (Test-Path $LogFile)) { Set-Content $LogFile 'Time,Package,What' -Encoding UTF8 }
  $line = '{0},{1},"{2}"' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $pkg, ($what -replace '"', '')
  Add-Content $LogFile $line -Encoding UTF8
  $script:Launches = @(Get-Launches)
}
function Get-Launches { if (Test-Path $LogFile) { Import-Csv $LogFile | Where-Object { $_.Time } } }
function Get-Bookmarks { if (Test-Path $BmFile) { Import-Csv $BmFile | Where-Object { $_.Name } } }
function Save-Bookmarks($b) { $b | Select-Object Group, Name, Package, Intent | Export-Csv $BmFile -NoTypeInformation -Encoding UTF8 }

function Reload {
  $script:Apps = @(Get-AppDb)
  $script:ByPkg = @{}
  foreach ($a in $script:Apps) { $script:ByPkg[$a.Package] = $a }
  $script:Launches = @(Get-Launches)
  $script:Bms = @(Get-Bookmarks)
  $top = @($script:Apps | Where-Object { $_.nMonth -gt 0 -or $_.nYear -gt 0 } |
    Sort-Object -Property @{ Expression = 'nMonth'; Descending = $true }, @{ Expression = 'nYear'; Descending = $true } |
    Select-Object -First 10)
  if ($top.Count -eq 0 -and $script:Launches.Count -gt 0) {
    $top = @($script:Launches | Group-Object Package | Sort-Object Count -Descending |
      Where-Object { $script:ByPkg.ContainsKey($_.Name) } | Select-Object -First 10 | ForEach-Object { $script:ByPkg[$_.Name] })
  }
  $script:Top10 = $top
}

function Get-DisplayIds {
  $ids = @()
  foreach ($l in @(Invoke-Adb @('shell', 'dumpsys display'))) {
    if ($l -match 'mDisplayId=(\d+)') { $ids += [int]$matches[1] }
    elseif ($l -match '^\s*Display (\d+):') { $ids += [int]$matches[1] }
  }
  @($ids | Sort-Object -Unique)
}

# Opens a scrcpy window on a new virtual display. With $Intent, opens that Android screen in it.
function Start-PhoneWindow([string]$Title, [string]$Pkg, [string]$Intent, [string]$FallbackPkg) {
  Invoke-Adb @('shell', 'input keyevent KEYCODE_WAKEUP; wm dismiss-keyguard') | Out-Null
  $before = @()
  if ($Intent) { $before = @(Get-DisplayIds) }
  $dir = Join-Path $Root 'logs'
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  Get-ChildItem $dir -Filter 'scrcpy-*.log' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending |
    Select-Object -Skip 12 | Remove-Item -Force -ErrorAction SilentlyContinue
  $log = Join-Path $dir ('scrcpy-{0}.log' -f (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
  $t = ($Title -replace '[^\w \.\-\(\)]', '').Trim()
  if (-not $t) { $t = 'phone' }
  $a = ''
  if ($env:ANDROID_SERIAL) { $a = '-s "{0}" ' -f $env:ANDROID_SERIAL }
  $a += '{0} -x --keep-active --hwdec=disabled -b16M --window-title="{1}"' -f $Shapes[$ShapeIx].A, $t
  if ($AudioModes[$AudioIx].A) { $a += ' ' + $AudioModes[$AudioIx].A }
  if ($Pkg -and -not $Intent) { $a += " --start-app=$Pkg" }
  $cl = '/c ""{0}" {1} > "{2}" 2>&1"' -f $Scrcpy, $a, $log
  Start-Process -FilePath $env:ComSpec -ArgumentList $cl -WindowStyle Hidden
  if (-not $Intent) {
    # give scrcpy a moment, and report a startup failure instead of claiming success
    $bad = $null
    for ($i = 0; $i -lt 16 -and -not $bad; $i++) {
      Start-Sleep -Milliseconds 250
      $txt = Read-Shared $log
      if ($txt -match 'New display:') { break }
      if ($txt -match '(?m)^ERROR:') {
        $bad = (@($txt -split "`n" | Where-Object { $_ -match '^ERROR:' } | Select-Object -First 2 | ForEach-Object { $_.Trim() })) -join ' '
      }
    }
    if ($bad) { return "scrcpy could not start: $bad   (log: logs\$(Split-Path $log -Leaf))" }
    return "Opened $Title ($($Shapes[$ShapeIx].N) window). If it stays black, unlock the phone."
  }

  # Find the new virtual display: from scrcpy's log, or by comparing the phone's display list.
  $id = $null
  for ($i = 0; $i -lt 60 -and -not $id; $i++) {
    Start-Sleep -Milliseconds 250
    if ((Read-Shared $log) -match 'New display:[^\r\n]*\(id=(\d+)\)') { $id = $matches[1] }
    elseif ($i -ge 6 -and ($i % 4) -eq 0) {
      $new = @(Get-DisplayIds | Where-Object { $before -notcontains $_ })
      if ($new.Count -ge 1) { $id = [string]($new | Select-Object -Last 1) }
    }
  }
  if (-not $id) {
    $tail = @((Read-Shared $log) -split "`n" | Where-Object { $_.Trim() } | Select-Object -Last 1)
    return "Could not find the new window's display number. scrcpy said: $tail   (log: logs\$(Split-Path $log -Leaf))"
  }
  Start-Sleep -Milliseconds 700
  $out = (Invoke-Adb @('shell', "am start --display $id $Intent") | Out-String)
  if ($out -match 'Error|Exception|Permission Denial|unable to resolve') {
    if ($FallbackPkg) {
      Invoke-Adb @('shell', "am start --display $id -a android.intent.action.MAIN -c android.intent.category.LAUNCHER -p $FallbackPkg") | Out-Null
      return "Android would not open that exact screen (the app keeps it private). Opened the app instead."
    }
    $why = @($out -split "`n" | Where-Object { $_ -match 'Error|Exception|Denial|unable' } | Select-Object -First 1)
    return "Android would not open that page: $why"
  }
  return "Opened $Title. If it stays black, unlock the phone."
}
function Start-App($a) {
  $m = Start-PhoneWindow $a.Name $a.Package '' ''
  Add-Launch $a.Package $a.Name
  $m
}

function Set-AppCategory($a) {
  [Console]::Write("$E[2J$E[H"); [Console]::CursorVisible = $true
  $cats = @($Apps | ForEach-Object { $_.Category } | Sort-Object -Unique)
  Write-Host "Category for $($a.Name)   (now: $($a.Category))"
  Write-Host ''
  for ($i = 0; $i -lt $cats.Count; $i++) { Write-Host ('  {0,2}) {1}' -f ($i + 1), $cats[$i]) }
  Write-Host ''
  $r = Read-Host 'Number, or type a new category name (blank = cancel)'
  [Console]::CursorVisible = $false
  [Console]::Write("$E[2J$E[H")
  if (-not $r) { return }
  $n = 0
  $new = $r.Trim()
  if ([int]::TryParse($r, [ref]$n)) { if ($n -ge 1 -and $n -le $cats.Count) { $new = $cats[$n - 1] } }
  $m = Get-CategoryMap
  if ($m.ContainsKey($a.Package)) { $m[$a.Package].Category = $new }
  else { $m[$a.Package] = [pscustomobject]@{ Package = $a.Package; Category = $new; Name = $a.Name; DisplayName = '' } }
  Save-CategoryMap $m
}

# Best effort: remember the screen currently open on the phone so it can be reopened later.
function Save-CurrentScreen {
  $raw = @(Invoke-Adb @('shell', 'dumpsys activity activities'))
  $pkg = $null; $cls = $null
  foreach ($l in $raw) {
    if ("$l" -match 'topResumedActivity=ActivityRecord\{\S+ \S+ ([^\s/]+)/([^\s\}]+)') { $pkg = $matches[1]; $cls = $matches[2]; break }
  }
  if (-not $pkg) {
    foreach ($l in $raw) {
      if ("$l" -match 'ResumedActivity: ?ActivityRecord\{\S+ \S+ ([^\s/]+)/([^\s\}]+)') { $pkg = $matches[1]; $cls = $matches[2]; break }
    }
  }
  if (-not $pkg) { return 'Could not tell which screen is open on the phone.' }
  $act = ''; $dat = ''; $hit = $false
  foreach ($l in $raw) {
    $l = "$l"
    if (-not $hit) { if ($l -match 'Hist' -and $l.Contains("$pkg/$cls")) { $hit = $true }; continue }
    if ($l -match 'Intent \{(.*)\}') {
      $body = $matches[1]
      if ($body -match 'act=(\S+)') { $act = $matches[1] }
      if ($body -match 'dat=(\S+)') { $dat = $matches[1] }
      break
    }
    if ($l -match 'Hist') { break }
  }
  $intent = "-n $pkg/$cls"
  if ($act) { $intent += " -a $act" }
  if ($dat -and $dat -notmatch '\.\.\.' -and $dat -notmatch "'") { $intent += " -d '$dat'" }
  $grp = $pkg
  if ($ByPkg.ContainsKey($pkg)) { $grp = $ByPkg[$pkg].Name }
  [Console]::Write("$E[2J$E[H"); [Console]::CursorVisible = $true
  Write-Host "Screen open on the phone:  $grp"
  Write-Host "  $pkg/$cls"
  if ($dat) { Write-Host "  link: $dat" }
  Write-Host ''
  $name = Read-Host 'Name for this bookmark (blank = cancel)'
  [Console]::CursorVisible = $false
  [Console]::Write("$E[2J$E[H")
  if (-not $name) { return 'Bookmark cancelled.' }
  $all = @(Get-Bookmarks) + [pscustomobject]@{ Group = $grp; Name = $name.Trim(); Package = $pkg; Intent = $intent }
  Save-Bookmarks $all
  return "Saved bookmark '$name' under $grp. Some apps refuse to reopen inner screens; then the app itself opens."
}

function New-View([string]$kind, [string]$title, [string]$key) {
  @{ Kind = $kind; Title = $title; Key = $key; Sel = 0; Top = 0; Filter = ''; App = $null }
}

function Get-ViewApps([string]$key) {
  if ($key -eq 'recent') {
    $seen = @{}; $out = @()
    for ($i = $Launches.Count - 1; $i -ge 0 -and $out.Count -lt 30; $i--) {
      $p = $Launches[$i].Package
      if ($p -and -not $seen.ContainsKey($p) -and $ByPkg.ContainsKey($p)) { $seen[$p] = 1; $out += $ByPkg[$p] }
    }
    return $out
  }
  if ($key -eq 'top') {
    return @($Apps | Where-Object { $_.nMonth -gt 0 -or $_.nYear -gt 0 } |
      Sort-Object -Property @{ Expression = 'nMonth'; Descending = $true }, @{ Expression = 'nYear'; Descending = $true } |
      Select-Object -First 30)
  }
  $src = $Apps
  if ($key -like 'cat:*') { $c = $key.Substring(4); $src = @($Apps | Where-Object { $_.Category -eq $c }) }
  if ($SortIx -eq 1) {
    $src = @($src | Sort-Object -Property @{ Expression = { if ($_.dLast) { $_.dLast } else { [datetime]::MinValue } }; Descending = $true })
  } elseif ($SortIx -eq 2) {
    $src = @($src | Sort-Object -Property @{ Expression = 'nMonth'; Descending = $true }, @{ Expression = 'nYear'; Descending = $true })
  } elseif ($SortIx -eq 3) {
    $src = @($src | Sort-Object -Property Installed -Descending)
  } else {
    $src = @($src | Sort-Object Name)
  }
  return $src
}

function Test-Hit([string]$text, [string]$f) {
  if (-not $f) { return $true }
  return ($text.IndexOf($f, [StringComparison]::OrdinalIgnoreCase) -ge 0)
}

function Get-Items($v) {
  $f = $v.Filter
  if ($v.Kind -eq 'home') {
    @{ K = 'nav'; Label = 'Recent  (opened from this launcher)'; Right = ''; View = @('apps', 'Recent', 'recent') }
    @{ K = 'nav'; Label = 'Top used  (by time on the phone)';    Right = ''; View = @('apps', 'Top used', 'top') }
    @{ K = 'nav'; Label = 'All apps';                            Right = "$($Apps.Count) apps"; View = @('apps', 'All apps', 'all') }
    @{ K = 'nav'; Label = 'Bookmarks and settings pages';        Right = "$($Bms.Count) saved"; View = @('bms', 'Bookmarks', '') }
    foreach ($g in ($Apps | Group-Object Category | Sort-Object Name)) {
      @{ K = 'nav'; Label = $g.Name; Right = "$($g.Count) apps"; View = @('apps', $g.Name, "cat:$($g.Name)") }
    }
  } elseif ($v.Kind -eq 'apps') {
    foreach ($a in @(Get-ViewApps $v.Key)) {
      if (Test-Hit "$($a.Name) $($a.Package) $($a.Category)" $f) { @{ K = 'app'; App = $a } }
    }
  } elseif ($v.Kind -eq 'bms') {
    foreach ($b in @($Bms | Sort-Object Group, Name)) {
      if (Test-Hit "$($b.Group) $($b.Name) $($b.Intent)" $f) { @{ K = 'bm'; B = $b } }
    }
  } elseif ($v.Kind -eq 'actions') {
    $a = $v.App
    @{ K = 'act'; Id = 'launch0'; Label = 'Open in a landscape window' }
    @{ K = 'act'; Id = 'launch1'; Label = 'Open in a phone-shaped window' }
    @{ K = 'act'; Id = 'launch2'; Label = 'Open in a big 1080p window' }
    @{ K = 'act'; Id = 'info';    Label = 'Android "App info" page for it  (permissions, storage, battery, force stop)' }
    @{ K = 'act'; Id = 'notif';   Label = 'Its notification settings' }
    @{ K = 'act'; Id = 'store';   Label = 'Its Play Store page' }
    @{ K = 'act'; Id = 'cat';     Label = "Change category  (now: $($a.Category))" }
    @{ K = 'act'; Id = 'copy';    Label = "Copy package name  ($($a.Package))" }
  }
}

function Format-Row($it) {
  if ($it.K -eq 'nav') { return ('  {0,-44} {1}' -f $it.Label, $it.Right) }
  if ($it.K -eq 'app') {
    $a = $it.App
    return ('  {0,-30} {1,-22} {2,-9} {3,-8} {4}' -f (Cut $a.Name 30), (Cut $a.Category 22), (Get-Rel $a.dLast), (Get-Dur $a.nMonth), $a.Package)
  }
  if ($it.K -eq 'bm') { return ('  {0,-22} {1,-38} {2}' -f (Cut $it.B.Group 22), (Cut $it.B.Name 38), $it.B.Intent) }
  return ('  ' + $it.Label)
}

function Draw($v, $items) {
  $w = [Math]::Max(60, [Console]::WindowWidth - 1)
  $rows = [Math]::Max(5, [Console]::WindowHeight - 11)
  if ($v.Sel -ge $items.Count) { $v.Sel = $items.Count - 1 }
  if ($v.Sel -lt 0) { $v.Sel = 0 }
  if ($v.Sel -lt $v.Top) { $v.Top = $v.Sel }
  if ($v.Sel -ge $v.Top + $rows) { $v.Top = $v.Sel - $rows + 1 }
  $R = "$E[0m$E[K`n"
  $sb = New-Object System.Text.StringBuilder
  $crumb = @($Stack | ForEach-Object { $_.Title }) -join ' > '
  [void]$sb.Append("$E[H$E[1;36m" + (Fit " PHONE   $crumb" $w) + $R)
  $srch = ''
  if ($v.Filter) { $srch = "    Search: $($v.Filter)_" }
  $bar = ' Window: {0} [Tab]   Audio: {4} [F7]   Sort: {1} [F2]   {2} shown{3}' -f $Shapes[$ShapeIx].N, $Sorts[$SortIx], $items.Count, $srch, $AudioModes[$AudioIx].N
  [void]$sb.Append("$E[33m" + (Fit $bar $w) + $R)
  $hdr = ''
  if ($v.Kind -eq 'apps') { $hdr = '  {0,-30} {1,-22} {2,-9} {3,-8} {4}' -f 'App', 'Category', 'Last used', 'Month', 'Package' }
  [void]$sb.Append("$E[90m" + (Fit $hdr $w) + $R)
  for ($i = 0; $i -lt $rows; $i++) {
    $n = $v.Top + $i
    if ($n -lt $items.Count) {
      $line = Fit (Format-Row $items[$n]) $w
      if ($n -eq $v.Sel) { [void]$sb.Append("$E[7m" + $line + $R) }
      elseif ($items[$n].K -eq 'app' -and $items[$n].App.Type -eq 'system') { [void]$sb.Append("$E[90m" + $line + $R) }
      else { [void]$sb.Append($line + $R) }
    } else { [void]$sb.Append($R) }
  }
  [void]$sb.Append("$E[90m" + (Fit ('-' * $w) $w) + $R)
  $last = ' Last opened: (nothing yet)'
  if ($Launches.Count -gt 0) { $ll = $Launches[$Launches.Count - 1]; $last = " Last opened: $($ll.What)   ($($ll.Time))" }
  [void]$sb.Append((Fit $last $w) + $R)
  $t1 = ' Top apps:'; $t2 = '          '
  for ($i = 0; $i -lt $Top10.Count; $i++) {
    $cell = '  {0}={1}' -f (($i + 1) % 10), (Cut $Top10[$i].Name 16)
    if ($i -lt 5) { $t1 += $cell } else { $t2 += $cell }
  }
  [void]$sb.Append("$E[32m" + (Fit $t1 $w) + $R)
  [void]$sb.Append("$E[32m" + (Fit $t2 $w) + $R)
  [void]$sb.Append("$E[90m" + (Fit ' Enter=open  Right=more actions  Left/Esc=back  type=search  1-0=open a top app' $w) + $R)
  [void]$sb.Append("$E[90m" + (Fit ' F4=category  F5=refresh  F6=bookmark screen  F7=audio  Del=remove bookmark' $w) + $R)
  [void]$sb.Append("$E[1;33m" + (Fit " $Msg" $w) + "$E[0m$E[K$E[J")
  [Console]::Write($sb.ToString())
}

# ---------------------------------------------------------------- main
$phoneSerial = Select-Phone
if (-not $phoneSerial) {
  Write-Host 'No phone found. Turn on Wireless debugging on the phone, then run connect.bat (or pair.bat the first time).' -ForegroundColor Red
  Read-Host 'Press Enter to close' | Out-Null
  exit 1
}
if (-not (Test-Path $DbFile) -or ((Get-Date) - (Get-Item $DbFile).LastWriteTime).TotalDays -gt 3) { Update-AppDb }
Reload
if ($Apps.Count -eq 0) {
  Write-Host 'No app data yet. Check the phone is connected (connect.bat), then try again.' -ForegroundColor Red
  Read-Host 'Press Enter to close' | Out-Null
  exit 1
}
if (@($Apps | Where-Object { $_.dLast -or $_.nYear -gt 0 }).Count -eq 0) { Update-AppDb; Reload }
$Stack = @( (New-View 'home' 'Home' '') )
$run = $true
[Console]::CursorVisible = $false
[Console]::Write("$E[2J")
try {
  while ($run) {
    $v = $Stack[$Stack.Count - 1]
    $items = @(Get-Items $v)
    Draw $v $items
    $k = [Console]::ReadKey($true)
    $Msg = ''
    $it = $null
    if ($items.Count -gt 0) { $it = $items[$v.Sel] }
    $page = [Math]::Max(5, [Console]::WindowHeight - 11)
    $do = ''
    $pop = $false
    switch ($k.Key) {
      'UpArrow'    { $v.Sel = $v.Sel - 1 }
      'DownArrow'  { $v.Sel = $v.Sel + 1 }
      'PageUp'     { $v.Sel = $v.Sel - $page }
      'PageDown'   { $v.Sel = $v.Sel + $page }
      'Home'       { $v.Sel = 0 }
      'End'        { $v.Sel = $items.Count - 1 }
      'Tab'        { $ShapeIx = ($ShapeIx + 1) % $Shapes.Count }
      'F2'         { $SortIx = ($SortIx + 1) % $Sorts.Count; $v.Sel = 0 }
      'F7'         { $AudioIx = ($AudioIx + 1) % $AudioModes.Count }
      'Enter'      { $do = 'open' }
      'RightArrow' { $do = 'more' }
      'LeftArrow'  { $pop = $true }
      'Escape'     { if ($v.Filter) { $v.Filter = ''; $v.Sel = 0 } elseif ($Stack.Count -gt 1) { $pop = $true } else { $run = $false } }
      'Backspace'  { if ($v.Filter) { $v.Filter = $v.Filter.Substring(0, $v.Filter.Length - 1); $v.Sel = 0 } else { $pop = $true } }
      'F4' {
        $target = $null
        if ($v.Kind -eq 'actions') { $target = $v.App } elseif ($it -and $it.K -eq 'app') { $target = $it.App }
        if ($target) { Set-AppCategory $target; Reload; $Msg = 'Category saved to categories.csv.' }
      }
      'F5' { [Console]::Write("$E[2J$E[H"); Update-AppDb; Reload; [Console]::Write("$E[2J"); $Msg = "Refreshed from the phone: $($Apps.Count) apps." }
      'F6' { $Msg = Save-CurrentScreen; Reload }
      'Delete' {
        if ($it -and $it.K -eq 'bm') {
          $gone = $it.B
          $keep = @($Bms | Where-Object { -not ($_.Name -eq $gone.Name -and $_.Intent -eq $gone.Intent) })
          Save-Bookmarks $keep; Reload; $Msg = "Removed bookmark '$($gone.Name)'."
        }
      }
      default {
        $ch = $k.KeyChar
        if ([char]::IsDigit($ch) -and -not $v.Filter -and $v.Kind -ne 'actions') {
          $ix = ([int][string]$ch + 9) % 10
          if ($ix -lt $Top10.Count) { $Msg = Start-App $Top10[$ix] }
        } elseif (-not [char]::IsControl($ch) -and $v.Kind -ne 'actions') {
          if ($v.Kind -eq 'home') {
            $nv = New-View 'apps' 'Search' 'all'
            $nv.Filter = [string]$ch
            $Stack += $nv
          } else { $v.Filter = $v.Filter + [string]$ch; $v.Sel = 0 }
        }
      }
    }
    if ($pop -and $Stack.Count -gt 1) { $Stack = @($Stack[0..($Stack.Count - 2)]) }
    if ($do -and $it) {
      if ($it.K -eq 'nav') {
        $Stack += (New-View ($it.View[0]) ($it.View[1]) ($it.View[2]))
      } elseif ($it.K -eq 'app') {
        if ($do -eq 'more') { $nv = New-View 'actions' $it.App.Name ''; $nv.App = $it.App; $Stack += $nv }
        else { $Msg = Start-App $it.App }
      } elseif ($it.K -eq 'bm') {
        $Msg = Start-PhoneWindow $it.B.Name '' $it.B.Intent $it.B.Package
        Add-Launch $it.B.Package "$($it.B.Group): $($it.B.Name)"
      } elseif ($it.K -eq 'act') {
        $a = $v.App
        $p = $a.Package
        if     ($it.Id -eq 'launch0') { $ShapeIx = 0; $Msg = Start-App $a }
        elseif ($it.Id -eq 'launch1') { $ShapeIx = 1; $Msg = Start-App $a }
        elseif ($it.Id -eq 'launch2') { $ShapeIx = 2; $Msg = Start-App $a }
        elseif ($it.Id -eq 'info')    { $Msg = Start-PhoneWindow "$($a.Name) - App info" '' "-a android.settings.APPLICATION_DETAILS_SETTINGS -d package:$p" '' }
        elseif ($it.Id -eq 'notif')   { $Msg = Start-PhoneWindow "$($a.Name) - Notifications" '' "-a android.settings.APP_NOTIFICATION_SETTINGS --es android.provider.extra.APP_PACKAGE $p" '' }
        elseif ($it.Id -eq 'store')   { $Msg = Start-PhoneWindow "$($a.Name) - Play Store" '' "-a android.intent.action.VIEW -d 'market://details?id=$p'" '' }
        elseif ($it.Id -eq 'cat')     { Set-AppCategory $a; Reload; if ($ByPkg.ContainsKey($p)) { $v.App = $ByPkg[$p] }; $Msg = 'Category saved to categories.csv.' }
        elseif ($it.Id -eq 'copy')    { Set-Clipboard -Value $p; $Msg = "Copied $p to the PC clipboard." }
      }
    }
  }
} finally {
  [Console]::CursorVisible = $true
  [Console]::Write("$E[0m$E[2J$E[H")
}

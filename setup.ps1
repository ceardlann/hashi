# setup.ps1 - one-time install for Hashi. Start it with setup.bat.
#   1. Downloads the pinned scrcpy release (it bundles adb) into .\scrcpy\  (skipped if already there)
#   2. Checks the download against a pinned SHA-256 hash
#   3. Creates your personal data files from the shipped *.example files (never overwrites yours)
# To upgrade scrcpy: change $ScrcpyVersion, set $ScrcpySha256 to the new hash (or '' to skip the
# check), then run:  setup.bat -Force
param([switch]$Force)
$ErrorActionPreference = 'Stop'

$ScrcpyVersion = '5.0.1'
$ScrcpySha256  = 'b12a2c4ee8be317422451fc7dcf8ee20a71b5ea7ef9ad73ddd825a25316227a5'

$Root    = $PSScriptRoot
$Dest    = Join-Path $Root 'scrcpy'
$ZipName = "scrcpy-win64-v$ScrcpyVersion.zip"
$Url     = "https://github.com/Genymobile/scrcpy/releases/download/v$ScrcpyVersion/$ZipName"

Write-Host ''
Write-Host '=== Hashi setup ===' -ForegroundColor Cyan

# --- 1. scrcpy + adb ---------------------------------------------------------
if ((Test-Path (Join-Path $Dest 'scrcpy.exe')) -and -not $Force) {
  Write-Host "scrcpy is already installed in $Dest (run 'setup.bat -Force' to reinstall)." -ForegroundColor Green
} else {
  $Zip = Join-Path $env:TEMP $ZipName
  $Tmp = Join-Path $env:TEMP "hashi-scrcpy-$ScrcpyVersion"
  Write-Host "Downloading scrcpy v$ScrcpyVersion (about 11 MB)..."
  Write-Host "  $Url" -ForegroundColor DarkGray
  [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
  $old = $ProgressPreference; $ProgressPreference = 'SilentlyContinue'   # the progress bar makes PS 5.1 downloads crawl
  try { Invoke-WebRequest -Uri $Url -OutFile $Zip -UseBasicParsing } finally { $ProgressPreference = $old }

  if ($ScrcpySha256) {
    $got = (Get-FileHash $Zip -Algorithm SHA256).Hash.ToLower()
    if ($got -ne $ScrcpySha256.ToLower()) {
      Remove-Item $Zip -Force
      throw "Checksum mismatch for $ZipName.`n  expected $ScrcpySha256`n  got      $got`nNothing was installed."
    }
    Write-Host 'Checksum OK.' -ForegroundColor DarkGray
  }

  # If scrcpy or adb is running, the files are locked - stop the adb server first (safe; it restarts on demand)
  $oldAdb = Join-Path $Dest 'adb.exe'
  if (Test-Path $oldAdb) { & $oldAdb kill-server 2>$null | Out-Null }

  if (Test-Path $Tmp) { Remove-Item $Tmp -Recurse -Force }
  Expand-Archive -Path $Zip -DestinationPath $Tmp -Force
  # The zip has a versioned top folder (scrcpy-win64-vX.Y.Z\) - flatten it into .\scrcpy\
  $inner = Get-ChildItem $Tmp -Directory | Select-Object -First 1
  $src = if ($inner -and (Test-Path (Join-Path $inner.FullName 'scrcpy.exe'))) { $inner.FullName } else { $Tmp }
  if (-not (Test-Path $Dest)) { New-Item -ItemType Directory -Path $Dest | Out-Null }
  Copy-Item -Path (Join-Path $src '*') -Destination $Dest -Recurse -Force
  "scrcpy v$ScrcpyVersion (win64), installed $(Get-Date -Format yyyy-MM-dd) by setup.ps1 from github.com/Genymobile/scrcpy" |
    Set-Content (Join-Path $Dest 'VERSION.txt') -Encoding ASCII
  Remove-Item $Tmp -Recurse -Force
  Remove-Item $Zip -Force
  if (-not (Test-Path (Join-Path $Dest 'adb.exe'))) { throw "adb.exe missing from $Dest after extract." }
  Write-Host "Installed scrcpy v$ScrcpyVersion + adb into $Dest" -ForegroundColor Green
}

# --- 2. personal data files from the examples ---------------------------------
foreach ($p in @(
    @('aliases.example.txt',    'aliases.txt'),
    @('bookmarks.example.csv',  'bookmarks.csv'),
    @('categories.example.csv', 'categories.csv'))) {
  $s = Join-Path $Root $p[0]; $d = Join-Path $Root $p[1]
  if (Test-Path $d)     { Write-Host "Keeping your existing $($p[1])." -ForegroundColor DarkGray }
  elseif (Test-Path $s) { Copy-Item $s $d; Write-Host "Created $($p[1]) from $($p[0])." }
}

# --- 3. next steps -------------------------------------------------------------
Write-Host ''
Write-Host 'Next steps:' -ForegroundColor Cyan
Write-Host '  1. Phone: Developer options > Wireless debugging ON (or plug in USB with USB debugging ON)'
Write-Host '  2. Run pair.bat once (Wi-Fi only; USB needs no pairing - just accept the prompt on the phone)'
Write-Host '  3. Optional: add-to-path.bat   (so droid / phone / mirror work from any terminal)'
Write-Host '  4. Optional: make-shortcut.bat (Desktop shortcut for the phone launcher)'
Write-Host '  5. Try:  phone    or    droid settings'
Write-Host ''

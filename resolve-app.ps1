# resolve-app.ps1 <name-or-package>  ->  prints ONE package name (or nothing on failure)
# Order: package as-is > aliases.txt > exact app-name match > single partial match > ask & remember
param([string]$q)
. (Join-Path $PSScriptRoot 'applist.ps1')
$alias = Join-Path $PSScriptRoot 'aliases.txt'
if ($q -match '\.') { $q; exit }
if (Test-Path $alias) {
  foreach ($l in Get-Content $alias) { if ($l -match '^\s*([^=#]+?)\s*=\s*(\S+)') { if ($matches[1] -ieq $q) { $matches[2]; exit } } }
}
function Find($apps) {
  $exact = @($apps | Where-Object { $_.Name -ieq $q })
  if ($exact.Count -ge 1) { return ,$exact }
  $part = @($apps | Where-Object { $_.Name -like "*$q*" })
  $user = @($part | Where-Object { -not $_.Sys })
  if ($user.Count -ge 1) { return ,$user }       # prefer user apps over system junk
  return ,$part
}
$hits = Find (Get-Apps)
if ($hits.Count -eq 0) { $hits = Find (Get-Apps -Refresh) }   # maybe newly installed
if ($hits.Count -eq 1) { $hits[0].Pkg; exit }
if ($hits.Count -eq 0) { Write-Host "No app matching '$q'. Try:  apps $q   or   pick"; exit }
Write-Host "Several apps match '$q':"
for ($i=0; $i -lt $hits.Count; $i++) { Write-Host ("  {0}) {1,-30} {2}" -f ($i+1), $hits[$i].Name, $hits[$i].Pkg) }
$c = Read-Host "Pick a number (remembered in aliases.txt)"
if ($c -match '^\d+$' -and [int]$c -ge 1 -and [int]$c -le $hits.Count) {
  $pkg = $hits[[int]$c-1].Pkg
  Add-Content $alias "$($q.ToLower())=$pkg"
  $pkg
}

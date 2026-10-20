<#
.SYNOPSIS
  Frees disk space left behind by test runs. run.ps1 calls it at the start
  of every run; it can also be run on its own.

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File .maestro\scripts\cleanup.ps1
  # only show what would be deleted
  powershell -NoProfile -ExecutionPolicy Bypass -File .maestro\scripts\cleanup.ps1 -DryRun

.NOTES
  Deletes:
  - .maestro\artifacts\<yyyy-MM-dd_HH-mm-ss>\ run folders older than KEEP_DAYS (kit.env, default 7).
    Nothing else in artifacts\ is touched: to keep a run, move it into
    .maestro\artifacts\_keep\.
  - %USERPROFILE%\.maestro\tests\* older than 1 day (Maestro's own debug copies).
  - %TEMP%\tmp<digits>.apk older than 1 hour: APK copies left behind by
    installs during test runs (they reached 52 GB on one machine before this script).
  Never fails the caller: a file that cannot be deleted is reported as a warning.
#>
param(
    [int]$KeepDays = 0,
    [switch]$DryRun
)

. (Join-Path $PSScriptRoot '_common.ps1')
if ($KeepDays -le 0) { $KeepDays = [int]$script:Kit['KEEP_DAYS'] }

$now = Get-Date
$items = @()

# 1. Old run folders. The age comes from the folder name, not LastWriteTime:
#    copying or opening a run folder must not make it "new" again.
$artifacts = Join-Path $script:MaestroDir 'artifacts'
if (Test-Path $artifacts) {
    $items += @(Get-ChildItem $artifacts -Directory -ErrorAction SilentlyContinue | Where-Object {
        $_.Name -match '^(\d{4}-\d{2}-\d{2})_\d{2}-\d{2}-\d{2}$' -and
        [datetime]::ParseExact($Matches[1], 'yyyy-MM-dd', $null) -lt $now.Date.AddDays(-$KeepDays)
    })
}

# 2. Maestro's per-run debug folders in the user profile.
$maestroTests = Join-Path $env:USERPROFILE '.maestro\tests'
if (Test-Path $maestroTests) {
    $items += @(Get-ChildItem $maestroTests -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt $now.AddDays(-1) })
}

# 3. Leftover APK copies in %TEMP%. Only the exact tmp<digits>.apk pattern,
#    and only older than an hour so an install in progress is never hit.
if ($env:TEMP -and (Test-Path $env:TEMP)) {
    $items += @(Get-ChildItem $env:TEMP -File -Filter 'tmp*.apk' -Force -ErrorAction SilentlyContinue | Where-Object {
        $_.Name -match '^tmp\d+\.apk$' -and $_.LastWriteTime -lt $now.AddHours(-1)
    })
}

$freed = 0L
$count = 0
foreach ($item in $items) {
    if ($item.PSIsContainer) {
        $size = (Get-ChildItem $item.FullName -Recurse -File -Force -ErrorAction SilentlyContinue |
            Measure-Object -Property Length -Sum).Sum
    }
    else { $size = $item.Length }
    if (-not $size) { $size = 0 }

    if ($DryRun) {
        Write-Host ("  would delete {0,8:N1} MB  {1}" -f ($size / 1MB), $item.FullName)
    }
    else {
        try { Remove-Item -LiteralPath $item.FullName -Recurse -Force -ErrorAction Stop }
        catch {
            Write-Warning "Cleanup: cannot delete $($item.FullName): $($_.Exception.Message)"
            continue
        }
    }
    $freed += $size
    $count++
}

$verb = if ($DryRun) { 'would free' } else { 'freed' }
Write-Host ("Cleanup: {0} {1:N2} GB ({2} items)" -f $verb, ($freed / 1GB), $count)

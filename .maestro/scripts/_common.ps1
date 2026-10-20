# Shared helpers for the Maestro scripts. Dot-sourced, not run directly.
# Kept ASCII-only: Windows PowerShell 5.1 reads BOM-less scripts in the ANSI
# code page, so non-ASCII text here would be garbled.

$script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$script:MaestroDir = Join-Path $script:RepoRoot '.maestro'

# --- kit.env ---------------------------------------------------------------
# App-specific settings (APP_ID, FRAMEWORK, ...). See kit.env.example.
$script:Kit = @{
    APP_ID          = 'com.example.app'
    FRAMEWORK       = 'flutter'
    APK_PATH        = ''
    FLUTTER_VARIANT = 'debug'
    BLANK_PNG_KB    = '25'
    KEEP_DAYS       = '7'
}
$kitFile = Join-Path $script:MaestroDir 'kit.env'
if (Test-Path $kitFile) {
    foreach ($raw in Get-Content -Path $kitFile -Encoding UTF8) {
        $line = $raw.Trim()
        if (-not $line -or $line.StartsWith('#')) { continue }
        $i = $line.IndexOf('=')
        if ($i -lt 1) { continue }
        $script:Kit[$line.Substring(0, $i).Trim()] = $line.Substring($i + 1).Trim()
    }
}
else {
    Write-Warning '.maestro\kit.env not found: using defaults (APP_ID=com.example.app). Run scripts\init.ps1 first.'
}
$script:AppId = $script:Kit['APP_ID']

# --- device ----------------------------------------------------------------
# Returns @{ Serial = 'emulator-5554'; Kind = 'ldplayer' | 'avd' | 'device' }.
# Exactly one device must be connected: two emulators on one PC usually means
# one of them is a leftover, and Maestro would pick an arbitrary one.
function Get-TestDevice {
    $lines = @(& adb devices | Select-String -Pattern "\tdevice$")
    if ($lines.Count -eq 0) {
        throw 'No device connected. Start an Android emulator (or plug in a device with USB debugging), then retry.'
    }
    if ($lines.Count -gt 1) {
        throw "More than one device connected ($($lines.Count)). Keep only one emulator running, or set ANDROID_SERIAL."
    }
    $serial = ($lines[0].Line -split "`t")[0].Trim()

    $ld = (& adb -s $serial shell pm list packages com.ldmnq.launcher3 2>$null | Out-String).Trim()
    $model = (& adb -s $serial shell getprop ro.product.model | Out-String).Trim()
    if ($ld) { $kind = 'ldplayer' }
    elseif ($serial -like 'emulator-*') { $kind = 'avd' }
    else { $kind = 'device' }

    Write-Host "Device: $serial ($kind, model '$model')"
    return @{ Serial = $serial; Kind = $kind }
}

# Kills Maestro CLI processes left over from an interrupted run. They keep a
# lock on ~/.maestro session files and make the next run hang on exit.
# The MCP server ("maestro mcp", started by Claude Code) is left alone.
function Stop-StaleMaestro {
    $stale = @(Get-CimInstance Win32_Process -Filter "Name='java.exe'" |
        Where-Object { $_.CommandLine -like '*maestro*' -and $_.CommandLine -notmatch '\smcp(\s|"|$)' })
    foreach ($p in $stale) {
        Write-Host "Stopping stale Maestro process $($p.ProcessId)"
        Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue
    }
}

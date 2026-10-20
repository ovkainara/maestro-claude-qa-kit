<#
.SYNOPSIS
  Runs Maestro flows with credentials from .maestro/.env and settings from .maestro/kit.env.

.EXAMPLE
  # whole suite (smoke + cases)
  powershell -NoProfile -ExecutionPolicy Bypass -File .maestro\scripts\run.ps1

  # one flow or one folder
  powershell -NoProfile -ExecutionPolicy Bypass -File .maestro\scripts\run.ps1 -Path .maestro\smoke\00_launch.yaml
  powershell -NoProfile -ExecutionPolicy Bypass -File .maestro\scripts\run.ps1 -Path .maestro\smoke

  # by tag
  powershell -NoProfile -ExecutionPolicy Bypass -File .maestro\scripts\run.ps1 -IncludeTags smoke
  powershell -NoProfile -ExecutionPolicy Bypass -File .maestro\scripts\run.ps1 -ExcludeTags slow

.NOTES
  Artifacts (screenshots, JUnit report, logs) go to .maestro\artifacts\<timestamp>\
  and are deleted after KEEP_DAYS by cleanup.ps1 (move a run into artifacts\_keep\
  to keep it). The folder is git-ignored.

  Always run flows through this script, not through the Maestro MCP `run` tool:
  the MCP server does not see the variables from .env.
#>
param(
    [string]$Path = '',
    [string]$IncludeTags = '',
    [string]$ExcludeTags = ''
)

. (Join-Path $PSScriptRoot '_common.ps1')

# Disk: old run folders, Maestro debug copies, leftover APK copies in %TEMP%.
try { & (Join-Path $PSScriptRoot 'cleanup.ps1') }
catch { Write-Warning "cleanup.ps1 failed: $($_.Exception.Message)" }

Stop-StaleMaestro
$dev = Get-TestDevice

if ($Path) { $target = (Resolve-Path $Path).Path } else { $target = $script:MaestroDir }

# Flows tagged `offline` toggle airplane mode. On LDPlayer that also cuts adb
# (it runs over the emulator's own network) and hangs Maestro. AVD only.
if ($dev.Kind -eq 'ldplayer') {
    if ($IncludeTags -match 'offline') {
        throw 'Flows tagged "offline" cannot run on LDPlayer (airplane mode cuts adb). Use an Android Studio AVD instead.'
    }
    if ((Test-Path $target -PathType Leaf) -and (Select-String -Path $target -Pattern '^\s*-\s*offline\s*$|^\s*tags:.*\boffline\b' -Quiet)) {
        throw "$target is tagged offline: run it on an Android Studio AVD, not LDPlayer."
    }
    $ExcludeTags = (@($ExcludeTags, 'offline') | Where-Object { $_ }) -join ','
}

# Maestro uses the flow `name:` as a folder name for its debug output.
# On Windows a name with : / \ * ? " < > | crashes the run (InvalidPathException).
$yamlFiles = if (Test-Path $target -PathType Leaf) { @(Get-Item $target) } else { @(Get-ChildItem $target -Recurse -Filter *.yaml) }
foreach ($f in $yamlFiles) {
    if ($f.Name -eq 'config.yaml') { continue }
    $nameLine = Select-String -Path $f.FullName -Pattern '^name:\s*(.+)$' | Select-Object -First 1
    if ($nameLine) {
        $flowName = $nameLine.Matches[0].Groups[1].Value.Trim().Trim('"').Trim("'")
        if ($flowName -match '[:/\\*?"<>|]') {
            throw "Flow name '$flowName' in $($f.FullName) has a character Windows forbids in folder names (: / \ * ? `" < > |). Use e.g. smoke-00-app-launches."
        }
    }
}

# Credentials: MAESTRO_* keys from .env go into this process's environment,
# Maestro passes them to flows. Not via -e on the command line, so special
# characters in passwords survive maestro.bat (cmd.exe) parsing.
$envFile = Join-Path $script:MaestroDir '.env'
if (Test-Path $envFile) {
    foreach ($raw in Get-Content -Path $envFile -Encoding UTF8) {
        $line = $raw.Trim()
        if (-not $line -or $line.StartsWith('#')) { continue }
        $i = $line.IndexOf('=')
        if ($i -lt 1) { continue }
        $key = $line.Substring(0, $i).Trim()
        $value = $line.Substring($i + 1)
        if (-not $key.StartsWith('MAESTRO_')) {
            Write-Warning "Skipping .env key '$key': keys must start with MAESTRO_"
            continue
        }
        [Environment]::SetEnvironmentVariable($key, $value, 'Process')
    }
}
else {
    Write-Warning '.maestro\.env not found: flows that log in will fail. Copy .env.example to .env and fill it in.'
}

# Artifacts: one folder per run (old ones are removed by cleanup.ps1).
$artifactsRoot = Join-Path $script:MaestroDir 'artifacts'
$out = Join-Path $artifactsRoot (Get-Date -Format 'yyyy-MM-dd_HH-mm-ss')
New-Item -ItemType Directory -Force -Path $out | Out-Null

$maestroArgs = @(
    '--device', $dev.Serial,
    'test', $target,
    '--format', 'JUNIT',
    '--output', (Join-Path $out 'report.xml'),
    '--test-output-dir', $out
)
if ($IncludeTags) { $maestroArgs += "--include-tags=$IncludeTags" }
if ($ExcludeTags) { $maestroArgs += "--exclude-tags=$ExcludeTags" }

# takeScreenshot writes relative to the working directory: run inside $out.
Push-Location $out
try {
    & maestro @maestroArgs
    $code = $LASTEXITCODE
}
finally { Pop-Location }

# A blank (all-white) PNG is tiny, a painted screen is several times larger.
# Flag suspiciously small screenshots: usually taken before the frame was painted.
$blankKb = [int]$script:Kit['BLANK_PNG_KB']
$blank = @(Get-ChildItem $out -Recurse -Filter *.png -ErrorAction SilentlyContinue | Where-Object { $_.Length -lt ($blankKb * 1KB) })
foreach ($b in $blank) {
    Write-Warning "Possibly BLANK screenshot ($([math]::Round($b.Length / 1KB)) KB): $($b.FullName). Add runFlow ../subflows/settle.yaml before takeScreenshot and check it visually."
}

Write-Host ''
Write-Host "Artifacts: $out"
Write-Host "Exit code: $code"
exit $code

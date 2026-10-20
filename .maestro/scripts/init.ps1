<#
.SYNOPSIS
  One-time setup: creates kit.env and .env from the examples and writes your
  APP_ID into every flow file (replaces com.example.app).

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File .maestro\scripts\init.ps1 -AppId com.mycompany.myapp -Framework expo

.NOTES
  Safe to re-run: existing kit.env / .env are kept, only the placeholder
  app id in *.yaml is replaced. Then check the tools:
    maestro --version   (Maestro CLI, needs Java 17+)
    adb devices         (one emulator or device, state "device")
#>
param(
    [Parameter(Mandatory = $true)][string]$AppId,
    [ValidateSet('flutter', 'expo', 'gradle', 'apk')][string]$Framework = 'flutter'
)

$maestroDir = Split-Path $PSScriptRoot -Parent

$kitFile = Join-Path $maestroDir 'kit.env'
if (-not (Test-Path $kitFile)) {
    $content = Get-Content (Join-Path $maestroDir 'kit.env.example') -Raw -Encoding UTF8
    $content = $content -replace '(?m)^APP_ID=.*$', "APP_ID=$AppId"
    $content = $content -replace '(?m)^FRAMEWORK=.*$', "FRAMEWORK=$Framework"
    Set-Content -Path $kitFile -Value $content -Encoding UTF8 -NoNewline
    Write-Host "Created $kitFile"
}
else { Write-Host "$kitFile exists, left as is" }

$envFile = Join-Path $maestroDir '.env'
if (-not (Test-Path $envFile)) {
    Copy-Item (Join-Path $maestroDir '.env.example') $envFile
    Write-Host "Created $envFile - fill in the test account credentials"
}
else { Write-Host "$envFile exists, left as is" }

$placeholder = 'com.example.app'
$changed = 0
foreach ($f in Get-ChildItem $maestroDir -Recurse -Filter *.yaml) {
    $text = Get-Content $f.FullName -Raw -Encoding UTF8
    if ($text -match [regex]::Escape($placeholder)) {
        Set-Content -Path $f.FullName -Value ($text -replace [regex]::Escape($placeholder), $AppId) -Encoding UTF8 -NoNewline
        $changed++
    }
}
Write-Host "appId set to $AppId in $changed flow file(s)"

Write-Host ''
Write-Host 'Next:'
Write-Host '  1. Fill in .maestro\.env (test account on a dev/staging backend).'
Write-Host '  2. Add the ids from docs\SELECTORS.md to your app (screen_login, screen_main, auth_login_*).'
Write-Host '  3. Start the emulator, then: .maestro\scripts\build-install.ps1 and .maestro\scripts\run.ps1 -Path .maestro\smoke'

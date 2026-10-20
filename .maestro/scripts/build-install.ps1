<#
.SYNOPSIS
  Builds the app for the connected emulator and installs it. FRAMEWORK in kit.env decides how.

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File .maestro\scripts\build-install.ps1
  powershell -NoProfile -ExecutionPolicy Bypass -File .maestro\scripts\build-install.ps1 -SkipBuild

.NOTES
  flutter : flutter build apk --<FLUTTER_VARIANT> --target-platform <emulator ABI>
            (one ABI is faster than the default three)
  expo    : npx expo run:android --variant release
            Release bundles the JS: no Metro bundler needed while tests run.
            A debug Expo build shows "Could not connect to development server"
            unless Metro is running, which is useless for unattended tests.
  gradle  : gradlew assembleDebug in android/
  apk     : no build, APK_PATH is installed as is

  Builds take minutes: call this with a 10-minute timeout.
  Point debug/test builds at a dev or staging backend, never at production.
#>
param(
    [switch]$SkipBuild
)

. (Join-Path $PSScriptRoot '_common.ps1')

$dev = Get-TestDevice
$serial = $dev.Serial
$framework = $script:Kit['FRAMEWORK'].ToLower()

switch ($framework) {
    'flutter' {
        $abi = (& adb -s $serial shell getprop ro.product.cpu.abi | Out-String).Trim()
        switch ($abi) {
            'x86_64'      { $platform = 'android-x64' }
            'arm64-v8a'   { $platform = 'android-arm64' }
            'armeabi-v7a' { $platform = 'android-arm' }
            default       { throw "Unknown device ABI '$abi'" }
        }
        $variant = $script:Kit['FLUTTER_VARIANT']
        Write-Host "ABI: $abi -> --target-platform $platform, variant $variant"
        if (-not $SkipBuild) {
            Push-Location $script:RepoRoot
            try {
                & flutter build apk "--$variant" --target-platform $platform
                if ($LASTEXITCODE -ne 0) { throw "flutter build failed (exit $LASTEXITCODE)" }
            }
            finally { Pop-Location }
        }
        $defaultApk = "build\app\outputs\flutter-apk\app-$variant.apk"
    }
    'expo' {
        if (-not $SkipBuild) {
            Push-Location $script:RepoRoot
            try {
                # expo run:android builds, installs and launches on the connected device.
                & npx expo run:android --variant release --device $serial
                if ($LASTEXITCODE -ne 0) { throw "expo run:android failed (exit $LASTEXITCODE)" }
            }
            finally { Pop-Location }
        }
        $defaultApk = 'android\app\build\outputs\apk\release\app-release.apk'
    }
    'gradle' {
        if (-not $SkipBuild) {
            Push-Location (Join-Path $script:RepoRoot 'android')
            try {
                & .\gradlew assembleDebug
                if ($LASTEXITCODE -ne 0) { throw "gradlew assembleDebug failed (exit $LASTEXITCODE)" }
            }
            finally { Pop-Location }
        }
        $defaultApk = 'android\app\build\outputs\apk\debug\app-debug.apk'
    }
    'apk' {
        if (-not $script:Kit['APK_PATH']) { throw 'FRAMEWORK=apk requires APK_PATH in kit.env' }
        $defaultApk = $script:Kit['APK_PATH']
    }
    default { throw "Unknown FRAMEWORK '$framework' in kit.env (flutter | expo | gradle | apk)" }
}

$apkRel = if ($script:Kit['APK_PATH']) { $script:Kit['APK_PATH'] } else { $defaultApk }
$apk = if ([System.IO.Path]::IsPathRooted($apkRel)) { $apkRel } else { Join-Path $script:RepoRoot $apkRel }
if (-not (Test-Path $apk)) { throw "APK not found: $apk" }

$result = (& adb -s $serial install -r $apk 2>&1 | Out-String)
if ($result -match 'INSTALL_FAILED_UPDATE_INCOMPATIBLE|signatures do not match') {
    # A build with another signing key (store build, another machine) is installed: replace it.
    # This wipes the app's data on the emulator (the user is logged out).
    Write-Host 'Installed app has a different signature: uninstalling and reinstalling (app data on the emulator is wiped).'
    & adb -s $serial uninstall $script:AppId | Out-Null
    $result = (& adb -s $serial install $apk 2>&1 | Out-String)
}
Write-Host $result.Trim()
if ($result -notmatch 'Success') { throw 'APK install failed' }
Write-Host "Installed $($script:AppId) on $serial"

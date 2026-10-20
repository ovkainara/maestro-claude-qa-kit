#!/usr/bin/env bash
# Builds the app for the connected emulator and installs it. FRAMEWORK in kit.env decides how.
#
#   .maestro/scripts/build-install.sh
#   .maestro/scripts/build-install.sh --skip-build
#
# flutter : flutter build apk --<FLUTTER_VARIANT> --target-platform <emulator ABI>
# expo    : npx expo run:android --variant release
#           Release bundles the JS: no Metro bundler needed while tests run.
#           A debug Expo build shows "Could not connect to development server"
#           unless Metro is running, which is useless for unattended tests.
# gradle  : ./gradlew assembleDebug in android/
# apk     : no build, APK_PATH is installed as is
#
# Builds take minutes: call this with a 10-minute timeout.
# Point debug/test builds at a dev or staging backend, never at production.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

SKIP_BUILD=0
[[ "${1:-}" == "--skip-build" ]] && SKIP_BUILD=1

get_test_device
framework="$(echo "$FRAMEWORK" | tr '[:upper:]' '[:lower:]')"

case "$framework" in
  flutter)
    abi="$(adb -s "$DEVICE_SERIAL" shell getprop ro.product.cpu.abi | tr -d '\r')"
    case "$abi" in
      x86_64) platform="android-x64" ;;
      arm64-v8a) platform="android-arm64" ;;
      armeabi-v7a) platform="android-arm" ;;
      *) echo "Unknown device ABI '$abi'" >&2; exit 1 ;;
    esac
    echo "ABI: $abi -> --target-platform $platform, variant $FLUTTER_VARIANT"
    if [[ "$SKIP_BUILD" -eq 0 ]]; then
      (cd "$REPO_ROOT" && flutter build apk "--$FLUTTER_VARIANT" --target-platform "$platform")
    fi
    default_apk="build/app/outputs/flutter-apk/app-$FLUTTER_VARIANT.apk"
    ;;
  expo)
    if [[ "$SKIP_BUILD" -eq 0 ]]; then
      # expo run:android builds, installs and launches on the connected device.
      (cd "$REPO_ROOT" && npx expo run:android --variant release --device "$DEVICE_SERIAL")
    fi
    default_apk="android/app/build/outputs/apk/release/app-release.apk"
    ;;
  gradle)
    if [[ "$SKIP_BUILD" -eq 0 ]]; then
      (cd "$REPO_ROOT/android" && ./gradlew assembleDebug)
    fi
    default_apk="android/app/build/outputs/apk/debug/app-debug.apk"
    ;;
  apk)
    [[ -z "$APK_PATH" ]] && { echo "FRAMEWORK=apk requires APK_PATH in kit.env" >&2; exit 1; }
    default_apk="$APK_PATH"
    ;;
  *) echo "Unknown FRAMEWORK '$framework' in kit.env (flutter | expo | gradle | apk)" >&2; exit 1 ;;
esac

apk_rel="${APK_PATH:-$default_apk}"
if [[ "$apk_rel" = /* ]]; then apk="$apk_rel"; else apk="$REPO_ROOT/$apk_rel"; fi
[[ -f "$apk" ]] || { echo "APK not found: $apk" >&2; exit 1; }

result="$(adb -s "$DEVICE_SERIAL" install -r "$apk" 2>&1 || true)"
if echo "$result" | grep -Eq 'INSTALL_FAILED_UPDATE_INCOMPATIBLE|signatures do not match'; then
  # A build with another signing key (store build, another machine) is installed: replace it.
  # This wipes the app's data on the emulator (the user is logged out).
  echo "Installed app has a different signature: uninstalling and reinstalling (app data on the emulator is wiped)."
  adb -s "$DEVICE_SERIAL" uninstall "$APP_ID" >/dev/null || true
  result="$(adb -s "$DEVICE_SERIAL" install "$apk" 2>&1 || true)"
fi
echo "$result"
echo "$result" | grep -q 'Success' || { echo "APK install failed" >&2; exit 1; }
echo "Installed $APP_ID on $DEVICE_SERIAL"

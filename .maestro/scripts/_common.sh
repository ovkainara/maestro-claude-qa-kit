#!/usr/bin/env bash
# Shared helpers for the Maestro scripts. Sourced, not run directly.
# Mirrors _common.ps1: same settings, same device rules.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
MAESTRO_DIR="$REPO_ROOT/.maestro"

# --- kit.env ---------------------------------------------------------------
APP_ID="com.example.app"
FRAMEWORK="flutter"
APK_PATH=""
FLUTTER_VARIANT="debug"
BLANK_PNG_KB="25"
KEEP_DAYS="7"

KIT_FILE="$MAESTRO_DIR/kit.env"
if [[ -f "$KIT_FILE" ]]; then
  while IFS= read -r raw || [[ -n "$raw" ]]; do
    line="${raw%%$'\r'}"
    line="$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    [[ -z "$line" || "$line" == \#* ]] && continue
    key="${line%%=*}"
    value="${line#*=}"
    case "$key" in
      APP_ID|FRAMEWORK|APK_PATH|FLUTTER_VARIANT|BLANK_PNG_KB|KEEP_DAYS) printf -v "$key" '%s' "$value" ;;
    esac
  done < "$KIT_FILE"
else
  echo "WARNING: .maestro/kit.env not found: using defaults (APP_ID=com.example.app). Run scripts/init.sh first." >&2
fi

# --- device ----------------------------------------------------------------
# Sets DEVICE_SERIAL and DEVICE_KIND (ldplayer | avd | device).
# Exactly one device must be connected, otherwise Maestro picks an arbitrary one.
get_test_device() {
  local lines
  lines="$(adb devices | awk -F'\t' '$2=="device"{print $1}')"
  local count
  count="$(echo -n "$lines" | grep -c . || true)"
  if [[ "$count" -eq 0 ]]; then
    echo "No device connected. Start an Android emulator (or plug in a device with USB debugging), then retry." >&2
    exit 1
  fi
  if [[ "$count" -gt 1 ]]; then
    echo "More than one device connected ($count). Keep only one emulator running, or set ANDROID_SERIAL." >&2
    exit 1
  fi
  DEVICE_SERIAL="$(echo "$lines" | head -n1)"
  local ld model
  ld="$(adb -s "$DEVICE_SERIAL" shell pm list packages com.ldmnq.launcher3 2>/dev/null | tr -d '\r' || true)"
  model="$(adb -s "$DEVICE_SERIAL" shell getprop ro.product.model | tr -d '\r')"
  if [[ -n "$ld" ]]; then DEVICE_KIND="ldplayer"
  elif [[ "$DEVICE_SERIAL" == emulator-* ]]; then DEVICE_KIND="avd"
  else DEVICE_KIND="device"; fi
  echo "Device: $DEVICE_SERIAL ($DEVICE_KIND, model '$model')"
}

# Kills Maestro CLI processes left over from an interrupted run (they lock
# ~/.maestro session files and make the next run hang on exit).
# The MCP server ("maestro mcp", started by Claude Code) is left alone.
stop_stale_maestro() {
  local pids
  pids="$(pgrep -f 'maestro' 2>/dev/null | while read -r pid; do
    cmd="$(ps -o args= -p "$pid" 2>/dev/null || true)"
    case "$cmd" in
      *java*maestro*) [[ "$cmd" != *" mcp"* ]] && echo "$pid" ;;
    esac
  done || true)"
  for pid in $pids; do
    echo "Stopping stale Maestro process $pid"
    kill -9 "$pid" 2>/dev/null || true
  done
}

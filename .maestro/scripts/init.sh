#!/usr/bin/env bash
# One-time setup: creates kit.env and .env from the examples and writes your
# APP_ID into every flow file (replaces com.example.app).
#
#   .maestro/scripts/init.sh --app-id com.mycompany.myapp --framework expo
#
# Safe to re-run: existing kit.env / .env are kept, only the placeholder
# app id in *.yaml is replaced. Then check the tools:
#   maestro --version   (Maestro CLI, needs Java 17+)
#   adb devices         (one emulator or device, state "device")

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAESTRO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

APP_ID=""
FRAMEWORK="flutter"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --app-id) APP_ID="$2"; shift 2 ;;
    --framework) FRAMEWORK="$2"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done
[[ -z "$APP_ID" ]] && { echo "Usage: init.sh --app-id <package> [--framework flutter|expo|gradle|apk]" >&2; exit 2; }
case "$FRAMEWORK" in flutter|expo|gradle|apk) ;; *) echo "framework must be flutter|expo|gradle|apk" >&2; exit 2 ;; esac

kit_file="$MAESTRO_DIR/kit.env"
if [[ ! -f "$kit_file" ]]; then
  sed -e "s/^APP_ID=.*/APP_ID=$APP_ID/" -e "s/^FRAMEWORK=.*/FRAMEWORK=$FRAMEWORK/" "$MAESTRO_DIR/kit.env.example" > "$kit_file"
  echo "Created $kit_file"
else
  echo "$kit_file exists, left as is"
fi

env_file="$MAESTRO_DIR/.env"
if [[ ! -f "$env_file" ]]; then
  cp "$MAESTRO_DIR/.env.example" "$env_file"
  echo "Created $env_file - fill in the test account credentials"
else
  echo "$env_file exists, left as is"
fi

placeholder="com.example.app"
changed=0
while IFS= read -r f; do
  if grep -q "$placeholder" "$f"; then
    # sed -i differs between GNU and BSD: write via a temp file instead.
    tmp="$f.tmp.$$"
    sed "s/$placeholder/$APP_ID/g" "$f" > "$tmp" && mv "$tmp" "$f"
    changed=$((changed + 1))
  fi
done < <(find "$MAESTRO_DIR" -name '*.yaml')
echo "appId set to $APP_ID in $changed flow file(s)"

chmod +x "$SCRIPT_DIR"/*.sh 2>/dev/null || true

echo
echo "Next:"
echo "  1. Fill in .maestro/.env (test account on a dev/staging backend)."
echo "  2. Add the ids from docs/SELECTORS.md to your app (screen_login, screen_main, auth_login_*)."
echo "  3. Start the emulator, then: .maestro/scripts/build-install.sh and .maestro/scripts/run.sh --path .maestro/smoke"

#!/usr/bin/env bash
# Runs Maestro flows with credentials from .maestro/.env and settings from .maestro/kit.env.
#
#   .maestro/scripts/run.sh                                   # whole suite (smoke + cases)
#   .maestro/scripts/run.sh --path .maestro/smoke/00_launch.yaml
#   .maestro/scripts/run.sh --path .maestro/smoke
#   .maestro/scripts/run.sh --include-tags smoke
#   .maestro/scripts/run.sh --exclude-tags slow
#
# Artifacts (screenshots, JUnit report, logs) go to .maestro/artifacts/<timestamp>/
# and are deleted after KEEP_DAYS by cleanup.sh (move a run into artifacts/_keep/
# to keep it). The folder is git-ignored.
#
# Always run flows through this script, not through the Maestro MCP `run` tool:
# the MCP server does not see the variables from .env.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

TARGET_PATH=""
INCLUDE_TAGS=""
EXCLUDE_TAGS=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --path|-p) TARGET_PATH="$2"; shift 2 ;;
    --include-tags) INCLUDE_TAGS="$2"; shift 2 ;;
    --exclude-tags) EXCLUDE_TAGS="$2"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

# Disk: old run folders, Maestro debug copies.
"$SCRIPT_DIR/cleanup.sh" || echo "WARNING: cleanup.sh failed" >&2

stop_stale_maestro
get_test_device

if [[ -n "$TARGET_PATH" ]]; then
  TARGET="$(cd "$(dirname "$TARGET_PATH")" && pwd)/$(basename "$TARGET_PATH")"
  [[ -d "$TARGET_PATH" ]] && TARGET="$(cd "$TARGET_PATH" && pwd)"
else
  TARGET="$MAESTRO_DIR"
fi

# Flows tagged `offline` toggle airplane mode. On LDPlayer that also cuts adb
# (it runs over the emulator's own network) and hangs Maestro. AVD only.
if [[ "$DEVICE_KIND" == "ldplayer" ]]; then
  if [[ "$INCLUDE_TAGS" == *offline* ]]; then
    echo 'Flows tagged "offline" cannot run on LDPlayer (airplane mode cuts adb). Use an Android Studio AVD instead.' >&2
    exit 1
  fi
  if [[ -f "$TARGET" ]] && grep -Eq '^\s*-\s*offline\s*$|^\s*tags:.*\boffline\b' "$TARGET"; then
    echo "$TARGET is tagged offline: run it on an Android Studio AVD, not LDPlayer." >&2
    exit 1
  fi
  EXCLUDE_TAGS="${EXCLUDE_TAGS:+$EXCLUDE_TAGS,}offline"
fi

# Flow names become folder names in Maestro's debug output. Characters that
# Windows forbids break the run for teammates on Windows: reject them everywhere.
if [[ -f "$TARGET" ]]; then yaml_files=("$TARGET"); else mapfile -t yaml_files < <(find "$TARGET" -name '*.yaml' -not -name 'config.yaml'); fi
for f in "${yaml_files[@]}"; do
  name="$(grep -m1 -E '^name:' "$f" | sed -E 's/^name:[[:space:]]*//; s/^["'"'"']//; s/["'"'"']$//' || true)"
  if [[ -n "$name" ]] && echo "$name" | grep -q '[:/\\*?"<>|]'; then
    echo "Flow name '$name' in $f has a character Windows forbids in folder names (: / \\ * ? \" < > |). Use e.g. smoke-00-app-launches." >&2
    exit 1
  fi
done

# Credentials: MAESTRO_* keys from .env go into the environment; Maestro
# exposes them to flows as ${MAESTRO_...}. Values are taken literally.
ENV_FILE="$MAESTRO_DIR/.env"
if [[ -f "$ENV_FILE" ]]; then
  while IFS= read -r raw || [[ -n "$raw" ]]; do
    line="${raw%%$'\r'}"
    line="$(echo "$line" | sed -e 's/^[[:space:]]*//')"
    [[ -z "$line" || "$line" == \#* ]] && continue
    key="${line%%=*}"; key="$(echo "$key" | sed -e 's/[[:space:]]*$//')"
    value="${line#*=}"
    if [[ "$key" != MAESTRO_* ]]; then
      echo "WARNING: skipping .env key '$key': keys must start with MAESTRO_" >&2
      continue
    fi
    export "$key=$value"
  done < "$ENV_FILE"
else
  echo "WARNING: .maestro/.env not found: flows that log in will fail. Copy .env.example to .env and fill it in." >&2
fi

# Artifacts: one folder per run.
OUT="$MAESTRO_DIR/artifacts/$(date +%Y-%m-%d_%H-%M-%S)"
mkdir -p "$OUT"

args=(--device "$DEVICE_SERIAL" test "$TARGET" --format JUNIT --output "$OUT/report.xml" --test-output-dir "$OUT")
[[ -n "$INCLUDE_TAGS" ]] && args+=("--include-tags=$INCLUDE_TAGS")
[[ -n "$EXCLUDE_TAGS" ]] && args+=("--exclude-tags=$EXCLUDE_TAGS")

# takeScreenshot writes relative to the working directory: run inside $OUT.
set +e
( cd "$OUT" && maestro "${args[@]}" )
code=$?
set -e

# A blank (all-white) PNG is tiny, a painted screen is several times larger.
blank_bytes=$(( BLANK_PNG_KB * 1024 ))
while IFS= read -r png; do
  size=$(wc -c < "$png")
  if [[ "$size" -lt "$blank_bytes" ]]; then
    echo "WARNING: possibly BLANK screenshot ($(( size / 1024 )) KB): $png. Add runFlow ../subflows/settle.yaml before takeScreenshot and check it visually." >&2
  fi
done < <(find "$OUT" -name '*.png' 2>/dev/null)

echo
echo "Artifacts: $OUT"
echo "Exit code: $code"
exit "$code"

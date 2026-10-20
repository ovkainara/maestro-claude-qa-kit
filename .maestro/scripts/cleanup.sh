#!/usr/bin/env bash
# Frees disk space left behind by test runs. run.sh calls it at the start of
# every run; it can also be run on its own.
#
#   .maestro/scripts/cleanup.sh
#   .maestro/scripts/cleanup.sh --dry-run      # only show what would be deleted
#
# Deletes:
# - .maestro/artifacts/<yyyy-MM-dd_HH-mm-ss>/ run folders older than KEEP_DAYS (kit.env, default 7).
#   Nothing else in artifacts/ is touched: to keep a run, move it into artifacts/_keep/.
# - ~/.maestro/tests/* older than 1 day (Maestro's own debug copies).
# Never fails the caller.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"
set +e

DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

cutoff="$(date -d "-$KEEP_DAYS days" +%Y-%m-%d 2>/dev/null || date -v-"${KEEP_DAYS}"d +%Y-%m-%d)"
count=0

# 1. Old run folders. The age comes from the folder name, not mtime:
#    copying or opening a run folder must not make it "new" again.
artifacts="$MAESTRO_DIR/artifacts"
if [[ -d "$artifacts" ]]; then
  for d in "$artifacts"/*/; do
    [[ -d "$d" ]] || continue
    name="$(basename "$d")"
    if [[ "$name" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2})_[0-9]{2}-[0-9]{2}-[0-9]{2}$ ]]; then
      day="${BASH_REMATCH[1]}"
      if [[ "$day" < "$cutoff" ]]; then
        if [[ "$DRY_RUN" -eq 1 ]]; then echo "  would delete $d"; else rm -rf "$d" || echo "WARNING: cannot delete $d" >&2; fi
        count=$((count + 1))
      fi
    fi
  done
fi

# 2. Maestro's per-run debug folders in the user profile.
maestro_tests="$HOME/.maestro/tests"
if [[ -d "$maestro_tests" ]]; then
  while IFS= read -r item; do
    if [[ "$DRY_RUN" -eq 1 ]]; then echo "  would delete $item"; else rm -rf "$item" || echo "WARNING: cannot delete $item" >&2; fi
    count=$((count + 1))
  done < <(find "$maestro_tests" -mindepth 1 -maxdepth 1 -mtime +1 2>/dev/null)
fi

verb="freed"; [[ "$DRY_RUN" -eq 1 ]] && verb="would free"
echo "Cleanup: $verb $count item(s)"
exit 0

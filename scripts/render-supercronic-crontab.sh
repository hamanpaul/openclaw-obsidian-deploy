#!/usr/bin/env bash
set -euo pipefail

source /ops/scripts/runtime-common.sh

mkdir -p "$(dirname "$SUPERCRONIC_CRONTAB_PATH")"

{
  printf 'SHELL=/bin/bash\n'
  printf 'PATH=%s\n' "$PATH"
  printf 'HOME=%s\n' "$HOME"
  printf 'TZ=%s\n\n' "$OPENCLAW_CRON_TZ"

  old_ifs="$IFS"
  IFS=':'
  for cron_root in $OPENCLAW_CRON_FRAGMENT_DIRS; do
    [ -d "$cron_root" ] || continue
    while IFS= read -r cron_file; do
      cat "$cron_file"
      printf '\n'
    done < <(find "$cron_root" -maxdepth 1 -type f -name '*.cron' | LC_ALL=C sort)
  done
  IFS="$old_ifs"
} >"$SUPERCRONIC_CRONTAB_PATH"

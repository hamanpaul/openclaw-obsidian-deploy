#!/usr/bin/env bash
set -euo pipefail

source /ops/scripts/runtime-common.sh

wait_secs="${OBSIDIAN_SYNC_WAIT_SECS:-30}"

while true; do
  sync_config_count="$(count_obsidian_sync_configs)"

  if [ "$sync_config_count" -ne 1 ]; then
    echo "obsidian-sync waiting for exactly one sync config at $OBSIDIAN_SYNC_CONFIG_ROOT/*/config.json (found $sync_config_count)" >&2
    sleep "$wait_secs"
    continue
  fi

  exec obsidian_sync_guard.sh
done

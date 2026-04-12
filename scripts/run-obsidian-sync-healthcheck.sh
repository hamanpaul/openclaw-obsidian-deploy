#!/usr/bin/env bash
set -euo pipefail

source /ops/scripts/runtime-common.sh

sync_config_count="$(count_obsidian_sync_configs)"

if [ "$sync_config_count" -ne 1 ]; then
  echo "skipping obsidian sync healthcheck: expected exactly one sync config at $OBSIDIAN_SYNC_CONFIG_ROOT/*/config.json (found $sync_config_count)" >&2
  exit 0
fi

exec obsidian_sync_healthcheck.sh

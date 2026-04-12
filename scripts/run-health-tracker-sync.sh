#!/usr/bin/env bash
set -euo pipefail

source /ops/scripts/runtime-common.sh

if [ ! -f "$HEALTH_TRACKER_RUNTIME_CONFIG" ]; then
  echo "skipping health-tracker sync: missing runtime config $HEALTH_TRACKER_RUNTIME_CONFIG" >&2
  exit 0
fi

args=(health-tracker-garmin --runtime-config "$HEALTH_TRACKER_RUNTIME_CONFIG" sync-and-ingest)
if [ "${HEALTH_TRACKER_FULL_SYNC:-0}" = "1" ]; then
  args+=(--full)
fi

exec "${args[@]}"

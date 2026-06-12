#!/usr/bin/env bash
set -euo pipefail

source /ops/scripts/runtime-common.sh

interval="${EXAMPLE_ADDON_INTERVAL_SEC:-15}"
state_dir="${EXAMPLE_ADDON_STATE_DIR:-$OPENCLAW_WORKSPACE_DIR/addons-example/state}"

mkdir -p "$state_dir"

while true; do
  timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  file_count="$(find "$OPENCLAW_WORKSPACE_DIR" -maxdepth 4 -type f | wc -l | tr -d ' ')"

  cat >"$state_dir/heartbeat.json" <<EOF
{
  "timestamp": "$timestamp",
  "workspaceFileCount": $file_count
}
EOF

  echo "[addons-example] wrote ${state_dir}/heartbeat.json at ${timestamp}"
  sleep "$interval"
done

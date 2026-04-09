#!/usr/bin/env bash
set -euo pipefail

OPS_ROOT="/opt/external-sources/custom-claw-tools/picoclaw-ops-companion"
OPS_DIST="$OPS_ROOT/dist/index.js"
OPS_HOST="${PICOCLAW_OPS_LISTEN_HOST:-0.0.0.0}"
OPS_PORT="${PICOCLAW_OPS_LISTEN_PORT:-45450}"

if [ ! -f "$OPS_DIST" ]; then
  echo "missing picoclaw-ops-companion build output: $OPS_DIST" >&2
  exit 1
fi

exec node "$OPS_DIST" listen --host "$OPS_HOST" --port "$OPS_PORT"

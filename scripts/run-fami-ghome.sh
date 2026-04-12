#!/usr/bin/env bash
set -euo pipefail

source /ops/scripts/runtime-common.sh

wait_secs="${FAMI_GHOME_WAIT_SECS:-30}"

while [ ! -f "$FAMI_GHOME_ENV_FILE" ]; do
  echo "waiting for fami-ghome env file: $FAMI_GHOME_ENV_FILE" >&2
  sleep "$wait_secs"
done

exec fami-ghome --env-file "$FAMI_GHOME_ENV_FILE" serve --host "$FAMI_GHOME_HOST" --port "$FAMI_GHOME_PORT"

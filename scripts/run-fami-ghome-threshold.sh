#!/usr/bin/env bash
set -euo pipefail

source /ops/scripts/runtime-common.sh

FAMICLEAN_HOME="${FAMICLEAN_HOME:-$CUSTOM_CLAW_TOOLS_ROOT/famiclean-skill}"
WRAPPER_PATH="${FAMICLEAN_HOME}/skills/fami-claw-skill/fami-claw"

if [ ! -x "$WRAPPER_PATH" ]; then
  echo "missing fami-claw wrapper: $WRAPPER_PATH" >&2
  exit 1
fi

if [ ! -f "$FAMICLEAN_ENV_FILE" ]; then
  echo "skipping fami-ghome threshold check: missing env file $FAMICLEAN_ENV_FILE" >&2
  exit 0
fi

exec "$WRAPPER_PATH" --env-file "$FAMICLEAN_ENV_FILE" check-threshold "$@"

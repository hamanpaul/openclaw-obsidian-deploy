#!/usr/bin/env bash
set -euo pipefail

source /ops/scripts/runtime-common.sh

exec /usr/local/bin/supercronic "$SUPERCRONIC_CRONTAB_PATH"

#!/usr/bin/env bash
set -euo pipefail

source /ops/scripts/runtime-common.sh

/ops/scripts/ensure-openclaw-config.sh
/ops/scripts/ensure-zh-tw-default.sh

exec node "$OPENCLAW_REPO_DIR/openclaw.mjs" gateway run --allow-unconfigured

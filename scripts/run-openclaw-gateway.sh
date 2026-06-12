#!/usr/bin/env bash
set -euo pipefail

source /ops/scripts/runtime-common.sh

/ops/scripts/ensure-openclaw-config.sh

case "$(printf '%s' "${OPENCLAW_BOOTSTRAP_AGENTS_FILE:-0}" | tr '[:upper:]' '[:lower:]')" in
  1|true|yes|on)
    /ops/scripts/ensure-zh-tw-default.sh
    ;;
esac

exec node "$OPENCLAW_REPO_DIR/openclaw.mjs" gateway run --allow-unconfigured

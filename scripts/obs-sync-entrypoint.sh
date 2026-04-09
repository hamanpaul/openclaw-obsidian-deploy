#!/usr/bin/env bash
set -euo pipefail

OBS_HANDLER_ROOT="/opt/external-sources/custom-skills/obs-service-wsl-handler"
OBS_HANDLER_BIN="$OBS_HANDLER_ROOT/bin/obsidian_sync_guard.sh"
TERMINAL_AUTH_RC="${TERMINAL_AUTH_RC:-41}"
TERMINAL_CONFIG_RC="${TERMINAL_CONFIG_RC:-42}"

if [ ! -x "$OBS_HANDLER_BIN" ]; then
  echo "missing obs sync handler: $OBS_HANDLER_BIN" >&2
  exit 1
fi

if ! command -v ob >/dev/null 2>&1; then
  echo "missing ob command; rebuild with OPENCLAW_INSTALL_OBSIDIAN_HEADLESS=1 or install obsidian-headless in the image" >&2
  exit 1
fi

set +e
"$OBS_HANDLER_BIN"
rc=$?
set -e

case "$rc" in
  "$TERMINAL_AUTH_RC")
    echo "obs sync stopped on terminal auth failure; inspect incident log/config before restarting" >&2
    exit 0
    ;;
  "$TERMINAL_CONFIG_RC")
    echo "obs sync stopped on terminal config failure; inspect incident log/config before restarting" >&2
    exit 0
    ;;
  *)
    exit "$rc"
    ;;
esac

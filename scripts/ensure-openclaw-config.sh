#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="/home/node/.openclaw"
CONFIG_FILE="${CONFIG_DIR}/openclaw.json"
ALLOW_INSECURE_RAW="${OPENCLAW_CONTROL_UI_ALLOW_INSECURE_AUTH:-1}"

mkdir -p "$CONFIG_DIR"

if [ ! -f "$CONFIG_FILE" ]; then
  printf '{}\n' >"$CONFIG_FILE"
fi

allow_insecure_json=false
case "$(printf '%s' "$ALLOW_INSECURE_RAW" | /usr/bin/tr '[:upper:]' '[:lower:]')" in
 1 | true | yes | on)
  allow_insecure_json=true
  ;;
esac

tmp_file="$(mktemp)"
jq --argjson allow_insecure_auth "$allow_insecure_json" '
  .gateway = (.gateway // {})
  | .gateway.mode = "local"
  | .gateway.bind = "lan"
  | .gateway.controlUi = (.gateway.controlUi // {})
  | .gateway.controlUi.enabled = true
  | .gateway.controlUi.allowInsecureAuth = $allow_insecure_auth
  | .auth = (.auth // {})
  | .auth.order = (.auth.order // .auth.orderOverrides // {})
  | del(.auth.orderOverrides)
' "$CONFIG_FILE" >"$tmp_file"
mv "$tmp_file" "$CONFIG_FILE"

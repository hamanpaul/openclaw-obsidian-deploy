#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="/home/node/.openclaw"
CONFIG_FILE="${CONFIG_DIR}/openclaw.json"
ALLOW_INSECURE_RAW="${OPENCLAW_CONTROL_UI_ALLOW_INSECURE_AUTH:-1}"
DEFAULT_MODEL="${OPENCLAW_DEFAULT_MODEL:-github-copilot/gpt-5-mini}"
DEFAULT_PROFILE_ID="${OPENCLAW_DEFAULT_PROFILE_ID:-github-copilot:github}"
ENABLE_TELEGRAM_PLUGIN_RAW="${OPENCLAW_ENABLE_TELEGRAM_PLUGIN:-1}"

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

enable_telegram_plugin_json=false
case "$(printf '%s' "$ENABLE_TELEGRAM_PLUGIN_RAW" | /usr/bin/tr '[:upper:]' '[:lower:]')" in
 1 | true | yes | on)
  enable_telegram_plugin_json=true
  ;;
esac

tmp_file="$(mktemp)"
jq \
  --argjson allow_insecure_auth "$allow_insecure_json" \
  --argjson enable_telegram_plugin "$enable_telegram_plugin_json" \
  --arg default_model "$DEFAULT_MODEL" \
  --arg default_profile_id "$DEFAULT_PROFILE_ID" '
  .gateway = (.gateway // {})
  | .gateway.mode = "local"
  | .gateway.bind = "lan"
  | .gateway.controlUi = (.gateway.controlUi // {})
  | .gateway.controlUi.enabled = true
  | .gateway.controlUi.allowInsecureAuth = $allow_insecure_auth
  | .auth = (.auth // {})
  | .auth.profiles = (.auth.profiles // {})
  | .auth.order = (.auth.order // .auth.orderOverrides // {})
  | del(.auth.orderOverrides)
  | .agents = (.agents // {})
  | .agents.defaults = (.agents.defaults // {})
  | .agents.defaults.model = (.agents.defaults.model // {})
  | .agents.defaults.model.primary = (.agents.defaults.model.primary // $default_model)
  | .agents.defaults.models = (.agents.defaults.models // {})
  | .agents.defaults.models[$default_model] = (.agents.defaults.models[$default_model] // {})
  | if (.auth.profiles[$default_profile_id] // null) != null then
      .auth.order[($default_model | split("/")[0])] = (.auth.order[($default_model | split("/")[0])] // [$default_profile_id])
    else
      .
    end
  | if $enable_telegram_plugin then
      .plugins = (.plugins // {})
      | .plugins.entries = (.plugins.entries // {})
      | .plugins.entries.telegram = (.plugins.entries.telegram // {})
      | .plugins.entries.telegram.enabled = true
      | .channels = (.channels // {})
      | .channels.telegram = (.channels.telegram // {})
      | .channels.telegram.enabled = (.channels.telegram.enabled // true)
    else
      .
    end
' "$CONFIG_FILE" >"$tmp_file"
mv "$tmp_file" "$CONFIG_FILE"

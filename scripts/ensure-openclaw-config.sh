#!/usr/bin/env bash
set -euo pipefail

source /ops/scripts/runtime-common.sh

CONFIG_FILE="${OPENCLAW_CONFIG_DIR}/openclaw.json"
MODELS_FILE="${OPENCLAW_CONFIG_DIR}/agents/main/agent/models.json"
DEFAULT_CONFIG_FILE="${OPENCLAW_DEFAULTS_DIR}/openclaw.json"
DEFAULT_MODELS_FILE="${OPENCLAW_DEFAULTS_DIR}/agents/main/agent/models.json"
ALLOW_INSECURE_RAW="${OPENCLAW_CONTROL_UI_ALLOW_INSECURE_AUTH:-1}"
DEFAULT_MODEL="${OPENCLAW_DEFAULT_MODEL:-github-copilot/gpt-5-mini}"
DEFAULT_PROFILE_ID="${OPENCLAW_DEFAULT_PROFILE_ID:-github-copilot:github}"
DEFAULT_PROVIDER="${DEFAULT_PROFILE_ID%%:*}"

mkdir -p "$OPENCLAW_CONFIG_DIR" "$(dirname "$MODELS_FILE")"

if [ ! -f "$CONFIG_FILE" ]; then
  if [ -f "$DEFAULT_CONFIG_FILE" ]; then
    cp "$DEFAULT_CONFIG_FILE" "$CONFIG_FILE"
  else
    printf '{}\n' >"$CONFIG_FILE"
  fi
fi

if [ ! -f "$MODELS_FILE" ] && [ -f "$DEFAULT_MODELS_FILE" ]; then
  cp "$DEFAULT_MODELS_FILE" "$MODELS_FILE"
fi

allow_insecure_json=false
case "$(printf '%s' "$ALLOW_INSECURE_RAW" | tr '[:upper:]' '[:lower:]')" in
  1|true|yes|on)
    allow_insecure_json=true
    ;;
esac

tmp_file="$(mktemp)"
jq \
  --argjson allow_insecure_auth "$allow_insecure_json" \
  --arg default_model "$DEFAULT_MODEL" \
  --arg default_profile_id "$DEFAULT_PROFILE_ID" \
  --arg default_provider "$DEFAULT_PROVIDER" \
  --arg skills_dir "$OPENCLAW_SKILLS_DIR" \
  --arg cron_store "$OPENCLAW_CRON_STORE" '
  .gateway = (.gateway // {})
  | .gateway.mode = "local"
  | .gateway.bind = "lan"
  | .gateway.controlUi = (.gateway.controlUi // {})
  | .gateway.controlUi.enabled = true
  | .gateway.controlUi.allowInsecureAuth = $allow_insecure_auth
  | .auth = (.auth // {})
  | .auth.profiles = (.auth.profiles // {})
  | .auth.profiles[$default_profile_id] = (.auth.profiles[$default_profile_id] // {provider:$default_provider, mode:"token"})
  | .auth.order = (.auth.order // .auth.orderOverrides // {})
  | del(.auth.orderOverrides)
  | .auth.order[$default_provider] = (((.auth.order[$default_provider] // []) + [$default_profile_id]) | unique)
  | .agents = (.agents // {})
  | .agents.defaults = (.agents.defaults // {})
  | .agents.defaults.model = (.agents.defaults.model // {})
  | .agents.defaults.model.primary = $default_model
  | .agents.defaults.models = (.agents.defaults.models // {})
  | .agents.defaults.models[$default_model] = (.agents.defaults.models[$default_model] // {})
  | .skills = (.skills // {})
  | .skills.load = (.skills.load // {})
  | .skills.load.extraDirs = (((.skills.load.extraDirs // []) + [$skills_dir]) | unique)
  | .cron = (.cron // {})
  | .cron.enabled = true
  | .cron.store = (.cron.store // $cron_store)
  ' "$CONFIG_FILE" >"$tmp_file"
mv "$tmp_file" "$CONFIG_FILE"

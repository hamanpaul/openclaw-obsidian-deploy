#!/usr/bin/env bash
set -euo pipefail

source /ops/scripts/runtime-common.sh

CONFIG_DIR="${OPENCLAW_CONFIG_DIR:-$HOME/.openclaw}"
CONFIG_FILE="${CONFIG_DIR}/openclaw.json"
MODELS_FILE="${CONFIG_DIR}/agents/main/agent/models.json"
DEFAULT_CONFIG_FILE="${OPENCLAW_DEFAULTS_DIR}/openclaw.json"
DEFAULT_MODELS_FILE="${OPENCLAW_DEFAULTS_DIR}/agents/main/agent/models.json"
ALLOW_INSECURE_RAW="${OPENCLAW_CONTROL_UI_ALLOW_INSECURE_AUTH:-1}"
DEFAULT_MODEL="${OPENCLAW_DEFAULT_MODEL:-google/gemini-3.1-flash-lite-preview}"
DEFAULT_PROFILE_ID="${OPENCLAW_DEFAULT_PROFILE_ID:-github-copilot:github}"
DEFAULT_PROVIDER="${DEFAULT_PROFILE_ID%%:*}"
ENABLE_TELEGRAM_PLUGIN_RAW="${OPENCLAW_ENABLE_TELEGRAM_PLUGIN:-1}"
SKILLS_DIR="${OPENCLAW_SKILLS_DIR:-$HOME/.agents/skills}"
CRON_STORE="${OPENCLAW_CRON_STORE:-$CONFIG_DIR/cron.json}"
GOOGLE_ENV_FILE="${OPENCLAW_GOOGLE_ENV_FILE:-$HOME/.gemini/.env}"
GOOGLE_PROVIDER_ID="${OPENCLAW_GOOGLE_PROVIDER_ID:-google}"
GOOGLE_MODEL_ID="${OPENCLAW_GOOGLE_MODEL_ID:-gemini-3.1-flash-lite-preview}"
GOOGLE_MODEL_REF="${GOOGLE_PROVIDER_ID}/${GOOGLE_MODEL_ID}"
GOOGLE_API_BASE_URL="${OPENCLAW_GOOGLE_API_BASE_URL:-https://generativelanguage.googleapis.com/v1beta}"

mkdir -p "$CONFIG_DIR" "$(dirname "$MODELS_FILE")"

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

enable_telegram_plugin_json=false
case "$(printf '%s' "$ENABLE_TELEGRAM_PLUGIN_RAW" | tr '[:upper:]' '[:lower:]')" in
  1|true|yes|on)
    enable_telegram_plugin_json=true
    ;;
esac

extract_env_value() {
  local env_file="$1"
  local env_key="$2"

  python3 - "$env_file" "$env_key" <<'PY'
from pathlib import Path
import sys

env_file = Path(sys.argv[1])
env_key = sys.argv[2]

if not env_file.is_file():
    raise SystemExit(0)

for raw_line in env_file.read_text().splitlines():
    line = raw_line.strip()
    if not line or line.startswith("#") or "=" not in line:
        continue
    key, value = line.split("=", 1)
    if key.strip() != env_key:
        continue
    value = value.strip()
    if (value.startswith('"') and value.endswith('"')) or (value.startswith("'") and value.endswith("'")):
        value = value[1:-1]
    print(value)
    break
PY
}

google_api_key="$(extract_env_value "$GOOGLE_ENV_FILE" GOOGLE_API_KEY)"
have_google_api_key_json=false
if [ -n "$google_api_key" ]; then
  have_google_api_key_json=true
fi

tmp_file="$(mktemp)"
jq \
  --argjson allow_insecure_auth "$allow_insecure_json" \
  --argjson enable_telegram_plugin "$enable_telegram_plugin_json" \
  --argjson have_google_api_key "$have_google_api_key_json" \
  --arg default_model "$DEFAULT_MODEL" \
  --arg default_profile_id "$DEFAULT_PROFILE_ID" \
  --arg default_provider "$DEFAULT_PROVIDER" \
  --arg skills_dir "$SKILLS_DIR" \
  --arg cron_store "$CRON_STORE" \
  --arg google_api_base_url "$GOOGLE_API_BASE_URL" \
  --arg google_api_key "$google_api_key" \
  --arg google_provider_id "$GOOGLE_PROVIDER_ID" \
  --arg google_model_id "$GOOGLE_MODEL_ID" \
  --arg google_model_ref "$GOOGLE_MODEL_REF" '
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
  | .agents.defaults.models[$google_model_ref] = (.agents.defaults.models[$google_model_ref] // {})
  | .skills = (.skills // {})
  | .skills.load = (.skills.load // {})
  | .skills.load.extraDirs = (((.skills.load.extraDirs // []) + [$skills_dir]) | unique)
  | .cron = (.cron // {})
  | .cron.enabled = true
  | .cron.store = (.cron.store // $cron_store)
  | if $have_google_api_key then
      .models = (.models // {})
      | .models.providers = (.models.providers // {})
      | .models.providers[$google_provider_id] = ((.models.providers[$google_provider_id] // {}) + {
          baseUrl: $google_api_base_url,
          auth: "api-key",
          api: "google-generative-ai",
          apiKey: $google_api_key,
          models: [
            {
              id: $google_model_id,
              name: $google_model_id
            }
          ]
        })
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

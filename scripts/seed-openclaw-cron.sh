#!/usr/bin/env bash
set -euo pipefail

source /ops/scripts/runtime-common.sh

if ! /ops/scripts/ensure-openclaw-config.sh >/dev/null 2>&1; then
  echo "[openclaw-cron] warning: unable to ensure OpenClaw config; skip cron seeding" >&2
  exit 0
fi

enabled_raw="${OPENCLAW_MORNING_RESEARCH_ENABLE:-1}"
case "$(printf '%s' "$enabled_raw" | tr '[:upper:]' '[:lower:]')" in
  0|false|no|off)
    echo "[openclaw-cron] morning research cron disabled"
    exit 0
    ;;
esac

gateway_port="${OPENCLAW_GATEWAY_PORT:-18789}"
name="${OPENCLAW_MORNING_RESEARCH_NAME:-openclaw-morning-research}"
cron_expr="${OPENCLAW_MORNING_RESEARCH_CRON:-0 8 * * *}"
message="${OPENCLAW_MORNING_RESEARCH_MESSAGE:-執行每日早晨研究資料搜集與整理，必要時回報重點。}"
channel="${OPENCLAW_MORNING_RESEARCH_CHANNEL:-}"
destination="${OPENCLAW_MORNING_RESEARCH_TO:-}"

for _ in $(seq 1 60); do
  if curl -fsS "http://127.0.0.1:${gateway_port}/healthz" >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

if ! curl -fsS "http://127.0.0.1:${gateway_port}/healthz" >/dev/null 2>&1; then
  echo "[openclaw-cron] warning: gateway not ready; skip cron seeding" >&2
  exit 0
fi

list_output="$(node "$OPENCLAW_REPO_DIR/openclaw.mjs" cron list 2>&1 || true)"
if printf '%s\n' "$list_output" | grep -Fq "$name"; then
  echo "[openclaw-cron] cron already exists: $name"
  exit 0
fi

cmd=(
  node "$OPENCLAW_REPO_DIR/openclaw.mjs" cron add
  --name "$name"
  --cron "$cron_expr"
  --tz "$OPENCLAW_CRON_TZ"
  --agent "${OPENCLAW_AGENT_ID:-main}"
  --message "$message"
)

if [ -n "$channel" ] && [ -n "$destination" ]; then
  cmd+=(--channel "$channel" --to "$destination")
fi

if ! "${cmd[@]}"; then
  echo "[openclaw-cron] warning: failed to seed cron $name" >&2
fi

#!/usr/bin/env bash
set -euo pipefail

export HOME="${OPENCLAW_RUNTIME_HOME:-/home/node}"
export TERM="${TERM:-xterm-256color}"
export OPENCLAW_REPO_DIR="${OPENCLAW_REPO_DIR:-/app}"
export OBSIDIAN_VAULT_DIR="${OBSIDIAN_VAULT_DIR:-/workspace/vault}"
export OBSTOOLS_DIR="${OBSTOOLS_DIR:-$OBSIDIAN_VAULT_DIR/ObsToolsVault}"
export OPENCLAW_EXTERNAL_MD_DIR="${OPENCLAW_EXTERNAL_MD_DIR:-$OBSIDIAN_VAULT_DIR/openclaw}"
export STATE_DIR="${STATE_DIR:-$OBSTOOLS_DIR/state}"
export STATE_FILE="${STATE_FILE:-$STATE_DIR/openclaw_obsidian_state.json}"
export QUEUE_FILE="${QUEUE_FILE:-$STATE_DIR/openclaw_obsidian_queue.json}"
export MANIFEST_FILE="${MANIFEST_FILE:-$STATE_DIR/openclaw_md_manifest.json}"
export MIGRATION_SUGGESTIONS_FILE="${MIGRATION_SUGGESTIONS_FILE:-$OBSTOOLS_DIR/specs/migration_suggestions.md}"
export AGENT_EXECUTE_GUIDE_FILE="${AGENT_EXECUTE_GUIDE_FILE:-$OBSTOOLS_DIR/specs/agent_execute_guide.md}"
export SCAN_INTERVAL_SEC="${SCAN_INTERVAL_SEC:-60}"
export INIT_EXTERNALIZE_MD="${INIT_EXTERNALIZE_MD:-1}"
export OPENCLAW_AGENT_ID="${OPENCLAW_AGENT_ID:-main}"
export OPENCLAW_DEFAULT_MODEL="${OPENCLAW_DEFAULT_MODEL:-github-copilot/gpt-5-mini}"
export OPENCLAW_DEFAULT_PROFILE_ID="${OPENCLAW_DEFAULT_PROFILE_ID:-github-copilot:github}"
export OPENCLAW_ENABLE_TELEGRAM_PLUGIN="${OPENCLAW_ENABLE_TELEGRAM_PLUGIN:-1}"
export OPENCLAW_GATEWAY_TOKEN="${OPENCLAW_GATEWAY_TOKEN:-local-dev-token}"
export OPENCLAW_GATEWAY_PORT="${OPENCLAW_GATEWAY_PORT:-18789}"
export OPENCLAW_CONTROL_UI_ALLOW_INSECURE_AUTH="${OPENCLAW_CONTROL_UI_ALLOW_INSECURE_AUTH:-1}"
export PICOCLAW_OPS_LISTEN_HOST="${PICOCLAW_OPS_LISTEN_HOST:-0.0.0.0}"
export PICOCLAW_OPS_LISTEN_PORT="${PICOCLAW_OPS_LISTEN_PORT:-45450}"

OPENCLAW_AUTOSTART_MAINTAINER="${OPENCLAW_AUTOSTART_MAINTAINER:-1}"
OPENCLAW_AUTOSTART_GATEWAY="${OPENCLAW_AUTOSTART_GATEWAY:-1}"
OPENCLAW_AUTOSTART_OBS="${OPENCLAW_AUTOSTART_OBS:-1}"
OPENCLAW_AUTOSTART_OPS="${OPENCLAW_AUTOSTART_OPS:-1}"
OPENCLAW_AUTOSTART_SERIALWRAP="${OPENCLAW_AUTOSTART_SERIALWRAP:-1}"

mkdir -p \
  "$OBSIDIAN_VAULT_DIR" \
  "$OBSTOOLS_DIR/specs" \
  "$STATE_DIR" \
  "$OPENCLAW_EXTERNAL_MD_DIR" \
  "$HOME/.openclaw" \
  "$HOME/.config/obsidian-headless" \
  "$HOME/.config/picoclaw-ops-companion" \
  "$HOME/.picoclaw/workspace" \
  "$HOME/.config/serialwrap/profiles" \
  "$HOME/.local/state/serialwrap"

PIDS=()
CORE_PIDS=()
CORE_NAMES=()

shutdown_children() {
  local pid
  for pid in "${PIDS[@]:-}"; do
    kill "$pid" >/dev/null 2>&1 || true
  done
  wait >/dev/null 2>&1 || true
}

on_signal() {
  echo "[all-in-one] received stop signal, shutting down children"
  shutdown_children
  exit 0
}

trap on_signal INT TERM

run_supervised() {
  local name="$1"
  local restart_policy="$2"
  local cmd="$3"
  local rc

  while true; do
    echo "[all-in-one] starting $name"
    (
      set -o pipefail
      /bin/bash -lc "$cmd" 2>&1 | sed -u "s/^/[$name] /"
    )
    rc=$?
    echo "[all-in-one] $name exited with rc=$rc"
    if [ "$restart_policy" = "on-failure" ] && [ "$rc" -ne 0 ]; then
      echo "[all-in-one] restarting $name after failure"
      sleep 2
      continue
    fi
    return "$rc"
  done
}

start_service() {
  local name="$1"
  local enabled="$2"
  local restart_policy="$3"
  local required="$4"
  local cmd="$5"

  if [ "$enabled" != "1" ]; then
    echo "[all-in-one] skip $name (disabled)"
    return
  fi

  run_supervised "$name" "$restart_policy" "$cmd" &
  local pid=$!
  PIDS+=("$pid")
  if [ "$required" = "1" ]; then
    CORE_PIDS+=("$pid")
    CORE_NAMES+=("$name")
  fi
}

start_service maintainer "$OPENCLAW_AUTOSTART_MAINTAINER" on-failure 1 "/ops/scripts/maintainer-loop.sh"
start_service gateway "$OPENCLAW_AUTOSTART_GATEWAY" on-failure 1 "/ops/scripts/ensure-openclaw-config.sh && /ops/scripts/ensure-zh-tw-default.sh && exec node /app/openclaw.mjs gateway run"
start_service obs "$OPENCLAW_AUTOSTART_OBS" on-failure 0 "/ops/scripts/obs-sync-entrypoint.sh"
start_service ops "$OPENCLAW_AUTOSTART_OPS" on-failure 1 "/ops/scripts/ops-companion-entrypoint.sh"
start_service serialwrap "$OPENCLAW_AUTOSTART_SERIALWRAP" on-failure 1 "/ops/scripts/serialwrap-entrypoint.sh"

if [ "${#CORE_PIDS[@]}" -eq 0 ]; then
  echo "[all-in-one] no core services enabled; nothing to keep alive"
  exit 1
fi

while true; do
  for i in "${!CORE_PIDS[@]}"; do
    pid="${CORE_PIDS[$i]}"
    name="${CORE_NAMES[$i]}"
    if ! kill -0 "$pid" >/dev/null 2>&1; then
      set +e
      wait "$pid"
      rc=$?
      set -e
      echo "[all-in-one] core service exited: $name (rc=$rc)"
      shutdown_children
      exit "$rc"
    fi
  done
  sleep 2
done

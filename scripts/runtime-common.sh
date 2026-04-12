#!/usr/bin/env bash
set -euo pipefail

export HOME="${HOME:-/home/appuser}"
export PATH="${HOME}/.local/bin:/usr/local/bin:/usr/bin:/bin"
export OPENCLAW_REPO_DIR="${OPENCLAW_REPO_DIR:-/app}"
export CUSTOM_CLAW_TOOLS_ROOT="${CUSTOM_CLAW_TOOLS_ROOT:-$HOME/custom-claw-tools}"
export CUSTOM_SKILLS_ROOT="${CUSTOM_SKILLS_ROOT:-$HOME/custom-skills}"
export OPENCLAW_DEFAULTS_DIR="${OPENCLAW_DEFAULTS_DIR:-/opt/openclaw-defaults}"
export OPENCLAW_WORKSPACE_DIR="${OPENCLAW_WORKSPACE_DIR:-/workspace}"
export OPENCLAW_CONFIG_DIR="${OPENCLAW_CONFIG_DIR:-$HOME/.openclaw}"
default_notes_dir="${OPENCLAW_WORKSPACE_DIR}/notes"
if [ ! -d "$default_notes_dir" ] && [ ! -L "$default_notes_dir" ] && { [ -d "$HOME/.picoclaw/workspace/notes" ] || [ -L "$HOME/.picoclaw/workspace/notes" ]; }; then
  default_notes_dir="${HOME}/.picoclaw/workspace/notes"
fi
export OBSIDIAN_NOTES_DIR="${OBSIDIAN_NOTES_DIR:-$default_notes_dir}"
export OBSIDIAN_VAULT_DIR="${OBSIDIAN_VAULT_DIR:-$OBSIDIAN_NOTES_DIR}"
export OBSTOOLS_DIR="${OBSTOOLS_DIR:-$OBSIDIAN_VAULT_DIR/ObsToolsVault}"
export OPENCLAW_CLAW_DIR="${OPENCLAW_CLAW_DIR:-$OBSIDIAN_VAULT_DIR/claw}"
export OPENCLAW_EXTERNAL_MD_DIR="${OPENCLAW_EXTERNAL_MD_DIR:-$OPENCLAW_CLAW_DIR/openclaw}"
export OPENCLAW_MEMORY_DIR="${OPENCLAW_MEMORY_DIR:-$OPENCLAW_CLAW_DIR/memory}"
export OPENCLAW_MEMORY_FILE="${OPENCLAW_MEMORY_FILE:-$OPENCLAW_CLAW_DIR/MEMORY.md}"
export OPENCLAW_USER_FILE="${OPENCLAW_USER_FILE:-$OPENCLAW_CLAW_DIR/USER.md}"
export OPENCLAW_SOUL_FILE="${OPENCLAW_SOUL_FILE:-$OPENCLAW_CLAW_DIR/SOUL.md}"
export OPENCLAW_RESEARCH_DIR="${OPENCLAW_RESEARCH_DIR:-$OPENCLAW_CLAW_DIR/research}"
export OPENCLAW_HEALTH_DIR="${OPENCLAW_HEALTH_DIR:-$OPENCLAW_CLAW_DIR/health}"
export STATE_DIR="${STATE_DIR:-$OBSTOOLS_DIR/state}"
export STATE_FILE="${STATE_FILE:-$STATE_DIR/openclaw_obsidian_state.json}"
export QUEUE_FILE="${QUEUE_FILE:-$STATE_DIR/openclaw_obsidian_queue.json}"
export MANIFEST_FILE="${MANIFEST_FILE:-$STATE_DIR/openclaw_md_manifest.json}"
export MIGRATION_SUGGESTIONS_FILE="${MIGRATION_SUGGESTIONS_FILE:-$OBSTOOLS_DIR/specs/migration_suggestions.md}"
export AGENT_EXECUTE_GUIDE_FILE="${AGENT_EXECUTE_GUIDE_FILE:-$OBSTOOLS_DIR/specs/agent_execute_guide.md}"
export OPENCLAW_SKILLS_DIR="${OPENCLAW_SKILLS_DIR:-$HOME/.agents/skills}"
export OPENCLAW_CRON_STORE="${OPENCLAW_CRON_STORE:-$OPENCLAW_CONFIG_DIR/cron.json}"
export SUPERCRONIC_CRONTAB_PATH="${SUPERCRONIC_CRONTAB_PATH:-$HOME/.local/state/openclaw/supercronic.crontab}"
export SUPERVISOR_CONFIG="${SUPERVISOR_CONFIG:-/etc/supervisor/supervisord.conf}"
export OPENCLAW_CRON_TZ="${OPENCLAW_CRON_TZ:-Asia/Taipei}"
export OBSIDIAN_SYNC_CONFIG_ROOT="${OBSIDIAN_SYNC_CONFIG_ROOT:-$HOME/.config/obsidian-headless/sync}"
export FAMI_GHOME_ENV_FILE="${FAMI_GHOME_ENV_FILE:-$HOME/.config/fami-ghome-live/.env}"
export FAMICLEAN_ENV_FILE="${FAMICLEAN_ENV_FILE:-$HOME/.config/fami-ghome-live/.env}"
export HEALTH_TRACKER_RUNTIME_CONFIG="${HEALTH_TRACKER_RUNTIME_CONFIG:-$HOME/.config/health-tracker/garmin-runtime.json}"
export PICOCLAW_OPS_LISTEN_HOST="${PICOCLAW_OPS_LISTEN_HOST:-0.0.0.0}"
export PICOCLAW_OPS_LISTEN_PORT="${PICOCLAW_OPS_LISTEN_PORT:-45450}"
export OBS_AUTO_MOC_LISTEN_HOST="${OBS_AUTO_MOC_LISTEN_HOST:-0.0.0.0}"
export OBS_AUTO_MOC_LISTEN_PORT="${OBS_AUTO_MOC_LISTEN_PORT:-45460}"
export FAMI_GHOME_HOST="${FAMI_GHOME_HOST:-0.0.0.0}"
export FAMI_GHOME_PORT="${FAMI_GHOME_PORT:-8080}"

list_obsidian_sync_config_files() {
  if [ ! -d "$OBSIDIAN_SYNC_CONFIG_ROOT" ]; then
    return 0
  fi

  find "$OBSIDIAN_SYNC_CONFIG_ROOT" -mindepth 2 -maxdepth 2 -type f -name config.json -print | LC_ALL=C sort
}

count_obsidian_sync_configs() {
  list_obsidian_sync_config_files | wc -l | tr -d ' '
}

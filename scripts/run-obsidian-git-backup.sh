#!/usr/bin/env bash
set -euo pipefail

source /ops/scripts/runtime-common.sh

export VAULT_PATH="${VAULT_PATH:-${OPENCLAW_WORKSPACE_DIR:-/workspace}}"
export REMOTE_URL="${REMOTE_URL:-${OBSIDIAN_GIT_BACKUP_REMOTE_URL:-}}"
export BRANCH_NAME="${BRANCH_NAME:-${OBSIDIAN_GIT_BACKUP_BRANCH:-main}}"

if [ -z "$REMOTE_URL" ]; then
  echo "[obsidian-git-backup] skipping: REMOTE_URL is not configured"
  exit 0
fi

exec obsidian_git_backup.sh

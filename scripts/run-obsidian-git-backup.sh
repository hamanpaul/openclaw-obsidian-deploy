#!/usr/bin/env bash
set -euo pipefail

source /ops/scripts/runtime-common.sh

export VAULT_PATH="${VAULT_PATH:-$OBSIDIAN_VAULT_DIR}"
export REMOTE_URL="${REMOTE_URL:-${OBSIDIAN_GIT_BACKUP_REMOTE_URL:-git@github-obsidian-backup:hamanpaul/obsidian_vault.git}}"
export BRANCH_NAME="${BRANCH_NAME:-${OBSIDIAN_GIT_BACKUP_BRANCH:-main}}"

exec obsidian_git_backup.sh

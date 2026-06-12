#!/usr/bin/env bash
set -euo pipefail

source /ops/scripts/runtime-common.sh

prepare_runtime_dirs() {
  mkdir -p \
    "$OPENCLAW_WORKSPACE_DIR" \
    "$HOME/.agents/skills" \
    "$HOME/.cache/supervisor" \
    "$HOME/.config" \
    "$HOME/.local/bin" \
    "$HOME/.local/state/openclaw" \
    "$OPENCLAW_CONFIG_DIR"
}

if [ "$(id -u)" -eq 0 ]; then
  runtime_uid="$(id -u appuser)"
  runtime_gid="$(id -g appuser)"

  prepare_runtime_dirs

  while IFS= read -r path; do
    [ -n "$path" ] || continue
    if [ -e "$path" ] && [ ! -L "$path" ]; then
      chown "$runtime_uid:$runtime_gid" "$path"
    fi
  done <<EOF
$HOME
$HOME/.agents
$HOME/.agents/skills
$HOME/.cache
$HOME/.cache/supervisor
$HOME/.config
$HOME/.local
$HOME/.local/bin
$HOME/.local/state
$HOME/.local/state/openclaw
$OPENCLAW_CONFIG_DIR
$OPENCLAW_WORKSPACE_DIR
EOF
fi

prepare_runtime_dirs
/ops/scripts/install-openclaw-skills.sh
/ops/scripts/install-runtime-bin-links.sh

if [ -d "$HOME/.ssh" ] && [ -w "$HOME/.ssh" ]; then
  chmod 700 "$HOME/.ssh" 2>/dev/null || true
  while IFS= read -r -d '' ssh_file; do
    chmod 600 "$ssh_file" 2>/dev/null || true
  done < <(find "$HOME/.ssh" -maxdepth 1 -type f -print0)
fi

exec /usr/bin/supervisord -c "$SUPERVISOR_CONFIG"

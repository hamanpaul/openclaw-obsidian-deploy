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
    "$HOME/.local/share" \
    "$HOME/.local/state" \
    "$HOME/.local/state/openclaw" \
    "$HOME/.openclaw" \
    "$HOME/.picoclaw/workspace" \
    "$HOME/.GarminDb" \
    "$HOME/HealthData" \
    "$OBSIDIAN_VAULT_DIR" \
    "$OPENCLAW_CLAW_DIR" \
    "$OPENCLAW_MEMORY_DIR" \
    "$OPENCLAW_RESEARCH_DIR" \
    "$OPENCLAW_HEALTH_DIR" \
    "$OBSTOOLS_DIR/specs" \
    "$STATE_DIR" \
    "$OPENCLAW_EXTERNAL_MD_DIR"
}

ensure_memory_entrypoint() {
  local canonical_file="$OPENCLAW_MEMORY_FILE"
  local legacy_file="$OPENCLAW_MEMORY_DIR/MEMORY.md"
  local legacy_link_target="$canonical_file"

  mkdir -p "$(dirname "$canonical_file")" "$OPENCLAW_MEMORY_DIR"

  if [ ! -e "$canonical_file" ] && [ ! -L "$canonical_file" ] && [ -e "$legacy_file" ]; then
    mv "$legacy_file" "$canonical_file"
  elif [ -f "$canonical_file" ] && [ ! -s "$canonical_file" ] && [ -f "$legacy_file" ] && [ -s "$legacy_file" ]; then
    rm -f "$canonical_file"
    mv "$legacy_file" "$canonical_file"
  fi

  if [ ! -e "$canonical_file" ] && [ ! -L "$canonical_file" ]; then
    touch "$canonical_file"
  fi

  if [ "$(dirname "$canonical_file")" = "$(dirname "$OPENCLAW_MEMORY_DIR")" ]; then
    legacy_link_target="../$(basename "$canonical_file")"
  fi

  if [ -L "$legacy_file" ]; then
    if [ "$(readlink "$legacy_file" || true)" = "$legacy_link_target" ]; then
      return 0
    fi
    rm -f "$legacy_file"
  elif [ -e "$legacy_file" ]; then
    if cmp -s "$legacy_file" "$canonical_file"; then
      rm -f "$legacy_file"
    else
      echo "[workspace-map] warning: leaving existing legacy memory file in place: $legacy_file (canonical memory already differs: $canonical_file)" >&2
      return 0
    fi
  fi

  ln -s "$legacy_link_target" "$legacy_file"
}

ensure_workspace_alias() {
  local workspace_name="$1"
  local target_path="$2"
  local workspace_path="$OPENCLAW_WORKSPACE_DIR/$workspace_name"
  local link_target="$target_path"

  mkdir -p "$(dirname "$target_path")"

  if [ "${target_path#"$OPENCLAW_WORKSPACE_DIR"/}" != "$target_path" ]; then
    link_target="${target_path#"$OPENCLAW_WORKSPACE_DIR"/}"
  fi

  if [ -L "$workspace_path" ]; then
    if [ "$(readlink "$workspace_path" || true)" = "$link_target" ] || [ "$(readlink "$workspace_path" || true)" = "$target_path" ]; then
      return 0
    fi
    rm -f "$workspace_path"
  elif [ -e "$workspace_path" ]; then
    if [ ! -e "$target_path" ] && [ ! -L "$target_path" ]; then
      mv "$workspace_path" "$target_path"
    else
      echo "[workspace-map] warning: leaving existing path in place: $workspace_path (target already exists: $target_path)" >&2
      return 0
    fi
  fi

  ln -s "$link_target" "$workspace_path"
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
$HOME/.local/share
$HOME/.local/state
$HOME/.local/state/openclaw
$HOME/.openclaw
$HOME/.picoclaw
$HOME/.picoclaw/workspace
$HOME/.GarminDb
$HOME/HealthData
$OPENCLAW_WORKSPACE_DIR
$OBSIDIAN_VAULT_DIR
$OPENCLAW_CLAW_DIR
$OPENCLAW_MEMORY_DIR
$OPENCLAW_MEMORY_FILE
$OPENCLAW_USER_FILE
$OPENCLAW_SOUL_FILE
$OPENCLAW_RESEARCH_DIR
$OPENCLAW_HEALTH_DIR
$OBSTOOLS_DIR
$OBSTOOLS_DIR/specs
$STATE_DIR
$OPENCLAW_EXTERNAL_MD_DIR
EOF
fi

prepare_runtime_dirs
ensure_memory_entrypoint
ensure_workspace_alias "memory" "$OPENCLAW_MEMORY_DIR"
ensure_workspace_alias "MEMORY.md" "$OPENCLAW_MEMORY_FILE"
ensure_workspace_alias "USER.md" "$OPENCLAW_USER_FILE"
ensure_workspace_alias "SOUL.md" "$OPENCLAW_SOUL_FILE"

if [ ! -e /home/haman ]; then
  ln -s "$HOME" /home/haman
fi

mkdir -p "$OPENCLAW_REPO_DIR/.agents"
ln -sfn "$OPENCLAW_SKILLS_DIR" "$OPENCLAW_REPO_DIR/.agents/skills"

/ops/scripts/install-runtime-bin-links.sh

if [ -d "$HOME/.ssh" ] && [ -w "$HOME/.ssh" ]; then
  chmod 700 "$HOME/.ssh" 2>/dev/null || true
  while IFS= read -r -d '' ssh_file; do
    chmod 600 "$ssh_file" 2>/dev/null || true
  done < <(find "$HOME/.ssh" -maxdepth 1 -type f -print0)
fi

if [ "$(id -u)" -eq 0 ]; then
  /usr/sbin/runuser -u appuser -- /ops/scripts/render-supercronic-crontab.sh
else
  /ops/scripts/render-supercronic-crontab.sh
fi

exec /usr/bin/supervisord -c "$SUPERVISOR_CONFIG"

#!/usr/bin/env bash
set -euo pipefail

TARGET_SPEC="${OPENCLAW_DOCKER_USER:-1000:1000}"

parse_uid_gid() {
  local raw="$1"
  local uid_part gid_part
  uid_part="${raw%%:*}"
  gid_part="${raw##*:}"
  if [ -z "$uid_part" ] || [ -z "$gid_part" ] || [ "$uid_part" = "$raw" ]; then
    return 1
  fi
  if ! [[ "$uid_part" =~ ^[0-9]+$ ]] || ! [[ "$gid_part" =~ ^[0-9]+$ ]]; then
    return 1
  fi
  printf '%s:%s' "$uid_part" "$gid_part"
}

ensure_owned_dir() {
  local path="$1"
  mkdir -p "$path"
  chown -R "$TARGET_UID:$TARGET_GID" "$path"
}

if ! parsed="$(parse_uid_gid "$TARGET_SPEC")"; then
  echo "invalid OPENCLAW_DOCKER_USER (expected uid:gid): $TARGET_SPEC" >&2
  exit 2
fi
TARGET_UID="${parsed%%:*}"
TARGET_GID="${parsed##*:}"
export OPENCLAW_RUNTIME_HOME="${OPENCLAW_RUNTIME_HOME:-/home/node}"

if [ "$(id -u)" -ne 0 ]; then
  exec /ops/scripts/all-services-entrypoint.sh "$@"
fi

ensure_owned_dir /workspace/vault
ensure_owned_dir /home/node/.openclaw
ensure_owned_dir /home/node/.config/obsidian-headless
ensure_owned_dir /home/node/.config/picoclaw-ops-companion
ensure_owned_dir /home/node/.picoclaw/workspace
ensure_owned_dir /home/node/.config/serialwrap/profiles
ensure_owned_dir /home/node/.local/state/serialwrap

exec setpriv \
  --reuid "$TARGET_UID" \
  --regid "$TARGET_GID" \
  --clear-groups \
  /ops/scripts/all-services-entrypoint.sh "$@"

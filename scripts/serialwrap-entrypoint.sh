#!/usr/bin/env bash
set -euo pipefail

SERIALWRAP_INSTALL_ROOT="${SERIALWRAP_INSTALL_ROOT:-/home/node/.paul_tools}"
SERIALWRAP_DAEMON_BIN="${SERIALWRAP_DAEMON_BIN:-$SERIALWRAP_INSTALL_ROOT/serialwrapd.py}"
SERIALWRAP_DEFAULT_PROFILE_DIR="${SERIALWRAP_DEFAULT_PROFILE_DIR:-$SERIALWRAP_INSTALL_ROOT/profiles}"
SERIALWRAP_PROFILE_DIR="${SERIALWRAP_PROFILE_DIR:-/home/node/.config/serialwrap/profiles}"
SERIALWRAP_STATE_DIR="${SERIALWRAP_STATE_DIR:-/home/node/.local/state/serialwrap}"
SERIALWRAP_RUN_DIR="${SERIALWRAP_RUN_DIR:-$SERIALWRAP_STATE_DIR/run}"
SERIALWRAP_WAL_DIR="${SERIALWRAP_WAL_DIR:-$SERIALWRAP_STATE_DIR/wal}"
SERIALWRAP_LOG_DIR="${SERIALWRAP_LOG_DIR:-$SERIALWRAP_STATE_DIR/logs}"
SERIALWRAP_SOCKET_PATH="${SERIALWRAP_SOCKET_PATH:-$SERIALWRAP_RUN_DIR/serialwrapd.sock}"
SERIALWRAP_LOCK_PATH="${SERIALWRAP_LOCK_PATH:-$SERIALWRAP_RUN_DIR/serialwrapd.lock}"
SERIALWRAP_BY_ID_DIR="${SERIALWRAP_BY_ID_DIR:-/host-dev/serial/by-id}"
SERIALWRAP_BY_PATH_DIR="${SERIALWRAP_BY_PATH_DIR:-/host-dev/serial/by-path}"
SERIALWRAP_SEED_DEFAULT_PROFILES="${SERIALWRAP_SEED_DEFAULT_PROFILES:-1}"
SERIALWRAP_AUTOBIND_DEFAULT_TARGET="${SERIALWRAP_AUTOBIND_DEFAULT_TARGET:-1}"
SERIALWRAP_DEFAULT_PLACEHOLDER_BY_ID="${SERIALWRAP_DEFAULT_PLACEHOLDER_BY_ID:-/dev/serial/by-id/target3}"

if [ ! -x "$SERIALWRAP_DAEMON_BIN" ]; then
  echo "missing serialwrap daemon: $SERIALWRAP_DAEMON_BIN" >&2
  exit 1
fi

mkdir -p \
  "$SERIALWRAP_PROFILE_DIR" \
  "$SERIALWRAP_STATE_DIR" \
  "$SERIALWRAP_RUN_DIR" \
  "$SERIALWRAP_WAL_DIR" \
  "$SERIALWRAP_LOG_DIR"

export SERIALWRAP_PROFILE_DIR
export SERIALWRAP_STATE_DIR
export SERIALWRAP_RUN_DIR
export SERIALWRAP_WAL_DIR
export SERIALWRAP_LOG_DIR
export SERIALWRAP_BY_ID_DIR
export SERIALWRAP_BY_PATH_DIR

if [ "$SERIALWRAP_SEED_DEFAULT_PROFILES" = "1" ] && [ ! -e "$SERIALWRAP_PROFILE_DIR/default.yaml" ]; then
  if [ ! -d "$SERIALWRAP_DEFAULT_PROFILE_DIR" ]; then
    echo "missing serialwrap default profile dir: $SERIALWRAP_DEFAULT_PROFILE_DIR" >&2
    exit 1
  fi
  echo "serialwrap seeding default profiles into $SERIALWRAP_PROFILE_DIR"
  rsync -a "$SERIALWRAP_DEFAULT_PROFILE_DIR/" "$SERIALWRAP_PROFILE_DIR/"
fi

if [ -f "$SERIALWRAP_PROFILE_DIR/default.yaml" ] && [ "$SERIALWRAP_BY_ID_DIR" != "/dev/serial/by-id" ]; then
  sed -i "s#/dev/serial/by-id/#${SERIALWRAP_BY_ID_DIR%/}/#g" "$SERIALWRAP_PROFILE_DIR/default.yaml"
fi

if [ ! -e "$SERIALWRAP_PROFILE_DIR/OPI.env" ] && [ ! -e "$SERIALWRAP_PROFILE_DIR/OPI.env.example" ]; then
  cat >"$SERIALWRAP_PROFILE_DIR/OPI.env.example" <<'EOF'
SW_OPI_U=root
SW_OPI_P=change-me
EOF
  echo "serialwrap wrote $SERIALWRAP_PROFILE_DIR/OPI.env.example; copy to OPI.env and set credentials for op3-template"
fi

if [ ! -d "$SERIALWRAP_BY_ID_DIR" ]; then
  echo "serialwrap warning: device discovery dir not found: $SERIALWRAP_BY_ID_DIR" >&2
elif [ "$SERIALWRAP_AUTOBIND_DEFAULT_TARGET" = "1" ] && [ -f "$SERIALWRAP_PROFILE_DIR/default.yaml" ]; then
  placeholder="$SERIALWRAP_DEFAULT_PLACEHOLDER_BY_ID"
  if [ "$SERIALWRAP_BY_ID_DIR" != "/dev/serial/by-id" ]; then
    placeholder="${SERIALWRAP_BY_ID_DIR%/}/target3"
  fi
  shopt -s nullglob
  by_id_entries=("$SERIALWRAP_BY_ID_DIR"/*)
  shopt -u nullglob
  if grep -Fq "$placeholder" "$SERIALWRAP_PROFILE_DIR/default.yaml" \
    && [ "${#by_id_entries[@]}" -eq 1 ] \
    && [ -e "${by_id_entries[0]}" ]; then
    sed -i "s#${placeholder}#${by_id_entries[0]}#g" "$SERIALWRAP_PROFILE_DIR/default.yaml"
    echo "serialwrap auto-bound default target to ${by_id_entries[0]}"
  fi
fi

exec python3 "$SERIALWRAP_DAEMON_BIN" \
  --profile-dir "$SERIALWRAP_PROFILE_DIR" \
  --socket "$SERIALWRAP_SOCKET_PATH" \
  --lock "$SERIALWRAP_LOCK_PATH"

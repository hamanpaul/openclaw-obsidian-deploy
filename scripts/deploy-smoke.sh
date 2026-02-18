#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

ENV_FILE="${ENV_FILE:-$ROOT_DIR/.env}"
COMPOSE_FILE="${COMPOSE_FILE:-$ROOT_DIR/docker-compose.obsidian.yml}"
TAIL_LINES="${TAIL_LINES:-120}"
SKIP_BASE_IMAGE=0
NO_LOGS=0
DOWN_AFTER=0

usage() {
  cat <<'EOF'
usage: deploy-smoke.sh [options]
  --env-file <path>      env file path (default: ./.env)
  --compose-file <path>  compose file path (default: ./docker-compose.obsidian.yml)
  --tail <n>             log tail lines (default: 120)
  --skip-base-image      skip prepare-openclaw-base-image.sh
  --no-logs              skip logs output
  --down-after           run compose down after checks
  -h, --help             show this help
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
  --env-file)
    shift
    [ "$#" -gt 0 ] || { echo "missing value for --env-file" >&2; exit 2; }
    ENV_FILE="$1"
    shift
    ;;
  --compose-file)
    shift
    [ "$#" -gt 0 ] || { echo "missing value for --compose-file" >&2; exit 2; }
    COMPOSE_FILE="$1"
    shift
    ;;
  --tail)
    shift
    [ "$#" -gt 0 ] || { echo "missing value for --tail" >&2; exit 2; }
    TAIL_LINES="$1"
    shift
    ;;
  --skip-base-image)
    SKIP_BASE_IMAGE=1
    shift
    ;;
  --no-logs)
    NO_LOGS=1
    shift
    ;;
  --down-after)
    DOWN_AFTER=1
    shift
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    echo "unknown argument: $1" >&2
    usage
    exit 2
    ;;
  esac
done

for bin in docker awk; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "missing dependency: $bin" >&2
    exit 1
  fi
done

if ! docker compose version >/dev/null 2>&1; then
  echo "docker compose not available" >&2
  exit 1
fi

if [ ! -f "$ENV_FILE" ]; then
  echo "missing env file: $ENV_FILE" >&2
  exit 2
fi

if [ ! -f "$COMPOSE_FILE" ]; then
  echo "missing compose file: $COMPOSE_FILE" >&2
  exit 2
fi

read_env_value() {
  local key="$1"
  awk -F= -v key="$key" '
    /^[[:space:]]*#/ {next}
    /^[[:space:]]*$/ {next}
    {
      raw_key=$1
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", raw_key)
      if (raw_key == key) {
        sub(/^[^=]*=/, "", $0)
        print $0
        exit
      }
    }
  ' "$ENV_FILE"
}

strip_wrapping_quotes() {
  local value="$1"
  if [ "${#value}" -ge 2 ] && [ "${value#\"}" != "$value" ] && [ "${value%\"}" != "$value" ]; then
    value="${value#\"}"
    value="${value%\"}"
  elif [ "${#value}" -ge 2 ] && [ "${value#\'}" != "$value" ] && [ "${value%\'}" != "$value" ]; then
    value="${value#\'}"
    value="${value%\'}"
  fi
  printf '%s' "$value"
}

resolve_var() {
  local key="$1"
  local default="$2"
  local from_env="${!key:-}"
  if [ -n "$from_env" ]; then
    printf '%s' "$from_env"
    return
  fi
  local from_file
  from_file="$(read_env_value "$key" || true)"
  if [ -n "$from_file" ]; then
    strip_wrapping_quotes "$from_file"
    return
  fi
  printf '%s' "$default"
}

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

run_compose() {
  docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" "$@"
}

echo "[deploy-smoke] root: $ROOT_DIR"
echo "[deploy-smoke] env-file: $ENV_FILE"
echo "[deploy-smoke] compose-file: $COMPOSE_FILE"

OPENCLAW_CONFIG_HOST_DIR="$(resolve_var OPENCLAW_CONFIG_HOST_DIR "")"
OPENCLAW_DOCKER_USER="$(resolve_var OPENCLAW_DOCKER_USER "1000:1000")"
if [ -z "$OPENCLAW_CONFIG_HOST_DIR" ]; then
  echo "OPENCLAW_CONFIG_HOST_DIR is empty in $ENV_FILE" >&2
  exit 2
fi
if [ ! -d "$OPENCLAW_CONFIG_HOST_DIR" ]; then
  echo "OPENCLAW_CONFIG_HOST_DIR does not exist: $OPENCLAW_CONFIG_HOST_DIR" >&2
  exit 2
fi
if ! parsed_uid_gid="$(parse_uid_gid "$OPENCLAW_DOCKER_USER")"; then
  echo "invalid OPENCLAW_DOCKER_USER (expected uid:gid): $OPENCLAW_DOCKER_USER" >&2
  exit 2
fi
docker_uid="${parsed_uid_gid%%:*}"
docker_gid="${parsed_uid_gid##*:}"
host_uid="$(id -u)"
host_gid="$(id -g)"
if [ "$docker_uid" = "$host_uid" ] && [ "$docker_gid" = "$host_gid" ] && [ ! -w "$OPENCLAW_CONFIG_HOST_DIR" ]; then
  echo "OPENCLAW_CONFIG_HOST_DIR is not writable for uid:gid $docker_uid:$docker_gid" >&2
  echo "fix: sudo chown -R $docker_uid:$docker_gid \"$OPENCLAW_CONFIG_HOST_DIR\"" >&2
  exit 2
fi

if [ "$SKIP_BASE_IMAGE" -ne 1 ]; then
  export OPENCLAW_BASE_VERSION
  OPENCLAW_BASE_VERSION="$(resolve_var OPENCLAW_BASE_VERSION "v2026.2.15")"
  export OPENCLAW_BASE_IMAGE
  OPENCLAW_BASE_IMAGE="$(resolve_var OPENCLAW_BASE_IMAGE "openclaw:v2026.2.15")"
  export OPENCLAW_BASE_IMAGE_CONTEXT
  OPENCLAW_BASE_IMAGE_CONTEXT="$(resolve_var OPENCLAW_BASE_IMAGE_CONTEXT "/home/paul_chen/ref/code/openclaw")"
  export OPENCLAW_BASE_IMAGE_DOCKERFILE
  OPENCLAW_BASE_IMAGE_DOCKERFILE="$(resolve_var OPENCLAW_BASE_IMAGE_DOCKERFILE "$OPENCLAW_BASE_IMAGE_CONTEXT/Dockerfile")"
  export OPENCLAW_DOCKER_APT_PACKAGES
  OPENCLAW_DOCKER_APT_PACKAGES="$(resolve_var OPENCLAW_DOCKER_APT_PACKAGES "")"
  echo "[deploy-smoke] prepare base image: $OPENCLAW_BASE_IMAGE (version: $OPENCLAW_BASE_VERSION)"
  "$SCRIPT_DIR/prepare-openclaw-base-image.sh"
else
  echo "[deploy-smoke] skip base image build"
fi

echo "[deploy-smoke] compose config"
run_compose config >/dev/null

echo "[deploy-smoke] compose build"
run_compose build

echo "[deploy-smoke] compose up -d"
run_compose up -d

echo "[deploy-smoke] compose ps"
run_compose ps

if [ "$NO_LOGS" -ne 1 ]; then
  echo "[deploy-smoke] maintainer logs (tail=$TAIL_LINES)"
  run_compose logs --no-log-prefix --tail "$TAIL_LINES" openclaw-obsidian-maintainer || true
  echo "[deploy-smoke] gateway logs (tail=$TAIL_LINES)"
  run_compose logs --no-log-prefix --tail "$TAIL_LINES" openclaw-obsidian-gateway || true
fi

if [ "$DOWN_AFTER" -eq 1 ]; then
  echo "[deploy-smoke] compose down --remove-orphans"
  run_compose down --remove-orphans
fi

echo "[deploy-smoke] done"

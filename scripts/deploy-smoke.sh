#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

ENV_FILE="${ENV_FILE:-$ROOT_DIR/.env.example}"
COMPOSE_FILE="${COMPOSE_FILE:-$ROOT_DIR/docker-compose.quickstart.yml}"
SERVICE_NAME="${SERVICE_NAME:-openclaw-quickstart}"
HEALTH_URL="${HEALTH_URL:-http://127.0.0.1:18789/healthz}"
TAIL_LINES="${TAIL_LINES:-120}"
HEALTH_TIMEOUT_SEC="${HEALTH_TIMEOUT_SEC:-90}"
NO_LOGS=0
DOWN_AFTER=0

usage() {
  cat <<'EOF'
usage: deploy-smoke.sh [options]
  --env-file <path>      env file path (default: ./.env.example)
  --compose-file <path>  compose file path (default: ./docker-compose.quickstart.yml)
  --service <name>       service name for logs (default: openclaw-quickstart)
  --health-url <url>     health endpoint to probe (default: http://127.0.0.1:18789/healthz)
  --health-timeout <s>   seconds to wait for health (default: 90)
  --tail <n>             log tail lines (default: 120)
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
    --service)
      shift
      [ "$#" -gt 0 ] || { echo "missing value for --service" >&2; exit 2; }
      SERVICE_NAME="$1"
      shift
      ;;
    --health-url)
      shift
      [ "$#" -gt 0 ] || { echo "missing value for --health-url" >&2; exit 2; }
      HEALTH_URL="$1"
      shift
      ;;
    --health-timeout)
      shift
      [ "$#" -gt 0 ] || { echo "missing value for --health-timeout" >&2; exit 2; }
      HEALTH_TIMEOUT_SEC="$1"
      shift
      ;;
    --tail)
      shift
      [ "$#" -gt 0 ] || { echo "missing value for --tail" >&2; exit 2; }
      TAIL_LINES="$1"
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
    -h|--help)
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

for bin in docker curl; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "missing dependency: $bin" >&2
    exit 1
  fi
done

run_compose() {
  docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" "$@"
}

echo "[deploy-smoke] root: $ROOT_DIR"
echo "[deploy-smoke] env-file: $ENV_FILE"
echo "[deploy-smoke] compose-file: $COMPOSE_FILE"
echo "[deploy-smoke] service: $SERVICE_NAME"
echo "[deploy-smoke] health-url: $HEALTH_URL"
echo "[deploy-smoke] health-timeout: ${HEALTH_TIMEOUT_SEC}s"

run_compose config >/dev/null
run_compose build
run_compose up -d
run_compose ps

if [ "$NO_LOGS" -ne 1 ]; then
  run_compose logs --no-log-prefix --tail "$TAIL_LINES" "$SERVICE_NAME" || true
fi

deadline=$((SECONDS + HEALTH_TIMEOUT_SEC))
until curl -fsS "$HEALTH_URL" >/dev/null 2>&1; do
  if [ "$SECONDS" -ge "$deadline" ]; then
    echo "[deploy-smoke] health check failed: $HEALTH_URL" >&2
    run_compose logs --no-log-prefix --tail "$TAIL_LINES" "$SERVICE_NAME" || true
    exit 1
  fi
  sleep 2
done

curl -fsS "$HEALTH_URL"

if [ "$DOWN_AFTER" -eq 1 ]; then
  run_compose down --remove-orphans
fi

echo "[deploy-smoke] done"

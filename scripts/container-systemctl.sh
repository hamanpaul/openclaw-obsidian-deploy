#!/usr/bin/env bash
set -euo pipefail

source /ops/scripts/runtime-common.sh

quiet=0
if [ "${1:-}" = "--user" ]; then
  shift
fi
if [ "${1:-}" = "--quiet" ]; then
  quiet=1
  shift
fi

command_name="${1:-}"
if [ -z "$command_name" ]; then
  echo "container-systemctl: missing command" >&2
  exit 1
fi
shift || true

unit_to_program() {
  case "$1" in
    openclaw-gateway.service) echo "openclaw-gateway" ;;
    maintainer-loop.service) echo "maintainer-loop" ;;
    obsidian-sync.service) echo "obsidian-sync" ;;
    obs-auto-moc-listener.service) echo "obs-auto-moc-listener" ;;
    picoclaw-ops-companion-listener.service) echo "picoclaw-ops-companion" ;;
    fami-ghome.service) echo "fami-ghome" ;;
    supercronic.service) echo "supercronic" ;;
    *)
      return 1
      ;;
  esac
}

supervisorctl_cmd=(/usr/bin/supervisorctl -c "$SUPERVISOR_CONFIG")

program_status() {
  "${supervisorctl_cmd[@]}" status "$1" 2>/dev/null || true
}

program_pid() {
  "${supervisorctl_cmd[@]}" pid "$1" 2>/dev/null || true
}

if [ "$command_name" = "daemon-reload" ]; then
  exit 0
fi

case "$command_name" in
  is-active)
    unit="${1:-}"
    program="$(unit_to_program "$unit")" || exit 4
    status_line="$(program_status "$program")"
    if printf '%s\n' "$status_line" | grep -Eq '\bRUNNING\b'; then
      if [ "$quiet" -ne 1 ]; then
        echo "active"
      fi
      exit 0
    fi
    if [ "$quiet" -ne 1 ]; then
      echo "inactive"
    fi
    exit 3
    ;;
  restart|start|stop|status)
    unit="${1:-}"
    program="$(unit_to_program "$unit")" || exit 4
    exec "${supervisorctl_cmd[@]}" "$command_name" "$program"
    ;;
  show)
    if [ "${1:-}" = "--property=MainPID" ] && [ "${2:-}" = "--value" ]; then
      shift 2
      unit="${1:-}"
      program="$(unit_to_program "$unit")" || exit 4
      pid="$(program_pid "$program" | tr -d '[:space:]')"
      if [ -z "$pid" ]; then
        pid=0
      fi
      printf '%s\n' "$pid"
      exit 0
    fi
    echo "container-systemctl: unsupported show command" >&2
    exit 1
    ;;
  *)
    echo "container-systemctl: unsupported command: $command_name" >&2
    exit 1
    ;;
esac

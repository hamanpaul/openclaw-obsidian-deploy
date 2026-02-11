#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OPS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_FILE_DEFAULT="$OPS_DIR/logs/command-record.md"
log_file="${OPENCLAW_CMD_LOG_FILE:-$LOG_FILE_DEFAULT}"

if [ "$#" -eq 0 ]; then
  echo "usage: $0 <command> [args...]" >&2
  exit 2
fi

/bin/mkdir -p "$(/usr/bin/dirname "$log_file")"

cmd_display=""
for arg in "$@"; do
  if [ -z "$cmd_display" ]; then
    cmd_display="$(printf '%q' "$arg")"
  else
    cmd_display="$cmd_display $(printf '%q' "$arg")"
  fi
done

ts="$("/usr/bin/date" -u +%Y-%m-%dT%H:%M:%SZ)"
{
  echo "## $ts"
  echo '```bash'
  echo "$cmd_display"
  echo '```'
} >> "$log_file"

set +e
"$@"
status=$?
set -e

echo "- exit_code: $status" >> "$log_file"
echo >> "$log_file"

exit "$status"

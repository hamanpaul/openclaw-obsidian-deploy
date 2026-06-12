#!/usr/bin/env bash
set -euo pipefail

source /ops/scripts/runtime-common.sh

exec obs-auto-moc-listen

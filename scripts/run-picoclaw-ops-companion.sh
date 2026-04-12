#!/usr/bin/env bash
set -euo pipefail

source /ops/scripts/runtime-common.sh

export NODE_BIN="${NODE_BIN:-$(command -v node)}"

exec picoclaw-ops-companion-listen

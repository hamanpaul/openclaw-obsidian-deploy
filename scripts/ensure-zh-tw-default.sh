#!/usr/bin/env bash
set -euo pipefail

WORKSPACE_DIR="${OPENCLAW_WORKSPACE_DIR:-/home/node/.openclaw/workspace}"
AGENTS_FILE="${WORKSPACE_DIR}/AGENTS.md"
MARKER="openclaw-obsidian-deploy:zh-tw-default"

mkdir -p "$WORKSPACE_DIR"

if [ ! -f "$AGENTS_FILE" ]; then
  cat >"$AGENTS_FILE" <<'EOF'
# AGENTS.md

<!-- openclaw-obsidian-deploy:zh-tw-default -->
- 預設回覆語言：繁體中文（zh-TW）。
- 使用中文時採用台灣常用詞與標點。
- 專有名詞、命令、程式碼與路徑維持原文。
EOF
  exit 0
fi

if ! rg -q "$MARKER" "$AGENTS_FILE"; then
  cat >>"$AGENTS_FILE" <<'EOF'

<!-- openclaw-obsidian-deploy:zh-tw-default -->
## Language Default
- 預設回覆語言：繁體中文（zh-TW）。
- 使用中文時採用台灣常用詞與標點。
- 專有名詞、命令、程式碼與路徑維持原文。
EOF
fi

#!/usr/bin/env bash
set -euo pipefail

OBSIDIAN_VAULT_DIR="${OBSIDIAN_VAULT_DIR:-/workspace/vault}"
STATE_FILE="${STATE_FILE:-$OBSIDIAN_VAULT_DIR/ObsToolsVault/state/openclaw_obsidian_state.json}"

if command -v fd >/dev/null 2>&1; then
  FD_BIN="$(command -v fd)"
elif command -v fdfind >/dev/null 2>&1; then
  FD_BIN="$(command -v fdfind)"
else
  echo "fd/fdfind not found" >&2
  exit 1
fi

for bin in rg jq sha256sum stat sort mktemp; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "missing dependency: $bin" >&2
    exit 1
  fi
done

tmp_files="$(mktemp)"
tmp_ndjson="$(mktemp)"
tmp_current_map="$(mktemp)"
tmp_prev_map="$(mktemp)"
trap 'rm -f "$tmp_files" "$tmp_ndjson" "$tmp_current_map" "$tmp_prev_map"' EXIT

"$FD_BIN" -HI -tf --glob '*.md' "$OBSIDIAN_VAULT_DIR" \
  | rg -v '/\.obsidian/|/ObsToolsVault/state/' \
  | LC_ALL=C sort >"$tmp_files"

while IFS= read -r abs_path; do
  [ -n "$abs_path" ] || continue
  rel_path="${abs_path#"$OBSIDIAN_VAULT_DIR"/}"
  sha256="$(sha256sum "$abs_path" | awk '{print $1}')"
  mtime_epoch="$(stat -c '%Y' "$abs_path")"

  jq -n \
    --arg path "$rel_path" \
    --arg sha "$sha256" \
    --arg mtime "$mtime_epoch" \
    '{path:$path, meta:{sha256:$sha, mtime:($mtime|tonumber)}}' \
    >>"$tmp_ndjson"
done <"$tmp_files"

if [ -s "$tmp_ndjson" ]; then
  jq -s 'reduce .[] as $entry ({}; .[$entry.path] = $entry.meta)' "$tmp_ndjson" >"$tmp_current_map"
else
  printf '{}\n' >"$tmp_current_map"
fi

if [ -f "$STATE_FILE" ]; then
  if ! jq '.files // {}' "$STATE_FILE" >"$tmp_prev_map" 2>/dev/null; then
    printf '{}\n' >"$tmp_prev_map"
  fi
else
  printf '{}\n' >"$tmp_prev_map"
fi

jq -n \
  --slurpfile current "$tmp_current_map" \
  --slurpfile prev "$tmp_prev_map" \
  '($current[0] // {}) as $current
  | ($prev[0] // {}) as $prev
  | {
    changed: [($current | to_entries[]) | select(($prev[.key].sha256 // "") != .value.sha256) | .key],
    deleted: [($prev | keys[]) as $key | select(($current | has($key)) | not) | $key],
    current: $current
  }'

#!/usr/bin/env bash
set -euo pipefail

OPENCLAW_REPO_DIR="${OPENCLAW_REPO_DIR:-/app}"
OBSIDIAN_VAULT_DIR="${OBSIDIAN_VAULT_DIR:-/workspace/vault}"
OPENCLAW_EXTERNAL_MD_DIR="${OPENCLAW_EXTERNAL_MD_DIR:-$OBSIDIAN_VAULT_DIR/openclaw}"
STATE_DIR="${STATE_DIR:-$OBSIDIAN_VAULT_DIR/ObsToolsVault/state}"
MANIFEST_FILE="${MANIFEST_FILE:-$STATE_DIR/openclaw_md_manifest.json}"

if command -v fd >/dev/null 2>&1; then
  FD_BIN="$(command -v fd)"
elif command -v fdfind >/dev/null 2>&1; then
  FD_BIN="$(command -v fdfind)"
else
  echo "fd/fdfind not found" >&2
  exit 1
fi

for bin in rg jq sha256sum sort readlink cp rm ln dirname mktemp date; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "missing dependency: $bin" >&2
    exit 1
  fi
done

mkdir -p "$OPENCLAW_EXTERNAL_MD_DIR" "$STATE_DIR"

tmp_all="$(mktemp)"
tmp_sorted="$(mktemp)"
tmp_ndjson="$(mktemp)"
tmp_entries_json="$(mktemp)"
trap 'rm -f "$tmp_all" "$tmp_sorted" "$tmp_ndjson" "$tmp_entries_json"' EXIT

warn_missing_source() {
  echo "[externalize] warning: source path missing: $1" >&2
}

source_hits=0

if [ ! -d "$OPENCLAW_REPO_DIR" ]; then
  warn_missing_source "$OPENCLAW_REPO_DIR"
fi

if [ -d "$OPENCLAW_REPO_DIR/skills" ]; then
  source_hits=$((source_hits + 1))
  "$FD_BIN" -HI -tf --glob 'SKILL.md' "$OPENCLAW_REPO_DIR/skills" >>"$tmp_all"
  {
    "$FD_BIN" -HI -tf --glob '*.md' "$OPENCLAW_REPO_DIR/skills" | rg '/references/' >>"$tmp_all"
  } || true
else
  warn_missing_source "$OPENCLAW_REPO_DIR/skills"
fi

if [ -d "$OPENCLAW_REPO_DIR/.agents/skills" ]; then
  source_hits=$((source_hits + 1))
  "$FD_BIN" -HI -tf --glob '*.md' "$OPENCLAW_REPO_DIR/.agents/skills" >>"$tmp_all"
else
  warn_missing_source "$OPENCLAW_REPO_DIR/.agents/skills"
fi

if [ -d "$OPENCLAW_REPO_DIR/docs/reference/templates" ]; then
  source_hits=$((source_hits + 1))
  "$FD_BIN" -HI -tf --glob '*.md' "$OPENCLAW_REPO_DIR/docs/reference/templates" >>"$tmp_all"
else
  warn_missing_source "$OPENCLAW_REPO_DIR/docs/reference/templates"
fi

if [ "$source_hits" -eq 0 ]; then
  echo "[externalize] warning: no scan sources available, writing empty manifest" >&2
fi

sort -u "$tmp_all" >"$tmp_sorted"

file_count=0
while IFS= read -r src_file; do
  [ -n "$src_file" ] || continue

  rel_path="${src_file#"$OPENCLAW_REPO_DIR"/}"
  dst_file="$OPENCLAW_EXTERNAL_MD_DIR/$rel_path"
  dst_rel="${dst_file#"$OBSIDIAN_VAULT_DIR"/}"

  mkdir -p "$(dirname "$dst_file")"

  if [ -L "$src_file" ]; then
    link_target="$(readlink -f "$src_file" || true)"
    if [ "$link_target" != "$dst_file" ]; then
      if [ ! -e "$dst_file" ]; then
        cp -fL "$src_file" "$dst_file"
      fi
      rm -f "$src_file"
      ln -s "$dst_file" "$src_file"
    fi
  else
    cp -f "$src_file" "$dst_file"
    rm -f "$src_file"
    ln -s "$dst_file" "$src_file"
  fi

  checksum="$(sha256sum "$dst_file" | awk '{print $1}')"
  jq -n \
    --arg orig "$rel_path" \
    --arg external "$dst_rel" \
    --arg target "$dst_file" \
    --arg checksum "$checksum" \
    '{orig_path:$orig, external_path:$external, symlink_target:$target, checksum:$checksum, active:true}' \
    >>"$tmp_ndjson"

  file_count=$((file_count + 1))
done <"$tmp_sorted"

if [ -s "$tmp_ndjson" ]; then
  jq -s '.' "$tmp_ndjson" >"$tmp_entries_json"
else
  printf '[]\n' >"$tmp_entries_json"
fi

jq -n \
  --arg generated_at "$(date -u +%FT%TZ)" \
  --slurpfile entries "$tmp_entries_json" \
  '{generated_at:$generated_at, entries:($entries[0] // [])}' \
  >"$MANIFEST_FILE"

echo "externalized markdown files: $file_count"
echo "manifest: $MANIFEST_FILE"

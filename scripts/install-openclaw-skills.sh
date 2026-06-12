#!/usr/bin/env bash
set -euo pipefail

source /ops/scripts/runtime-common.sh

mkdir -p "$OPENCLAW_SKILLS_DIR"

install_skill_dir() {
  local src="$1"
  local name="${2:-$(basename "$src")}"
  local dest="$OPENCLAW_SKILLS_DIR/$name"

  if [ ! -d "$src" ] || [ ! -f "$src/SKILL.md" ]; then
    return 0
  fi

  rm -rf "$dest"
  mkdir -p "$dest"
  rsync -a --delete --exclude '.git' "$src"/ "$dest"/
}

old_ifs="$IFS"
IFS=':'
for skill_root in $OPENCLAW_ADDON_SKILL_DIRS; do
  [ -d "$skill_root" ] || continue
  while IFS= read -r -d '' skill_dir; do
    install_skill_dir "$skill_dir"
  done < <(find "$skill_root" -mindepth 1 -maxdepth 2 -type d -print0)
done
IFS="$old_ifs"

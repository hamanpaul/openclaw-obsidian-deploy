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

if [ -x "$CUSTOM_SKILLS_ROOT/install.sh" ]; then
  "$CUSTOM_SKILLS_ROOT/install.sh" --all --force --dest "$OPENCLAW_SKILLS_DIR"
fi

while IFS= read -r -d '' skill_link; do
  skill_target="$(readlink -f "$skill_link")"
  skill_name="$(basename "$skill_link")"
  rm -f "$skill_link"
  install_skill_dir "$skill_target" "$skill_name"
done < <(find "$OPENCLAW_SKILLS_DIR" -mindepth 1 -maxdepth 1 -type l -print0)

for skill_dir in \
  "$CUSTOM_CLAW_TOOLS_ROOT/obs-auto-moc" \
  "$CUSTOM_CLAW_TOOLS_ROOT/health-tracker"
do
  install_skill_dir "$skill_dir"
done

for parent in \
  "$CUSTOM_CLAW_TOOLS_ROOT/famiclean-skill/skills" \
  "$CUSTOM_CLAW_TOOLS_ROOT/picoclaw-ops-companion/skills"
do
  if [ -d "$parent" ]; then
    while IFS= read -r -d '' skill_dir; do
      install_skill_dir "$skill_dir"
    done < <(find "$parent" -mindepth 1 -maxdepth 1 -type d -print0)
  fi
done

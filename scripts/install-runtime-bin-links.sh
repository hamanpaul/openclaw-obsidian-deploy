#!/usr/bin/env bash
set -euo pipefail

source /ops/scripts/runtime-common.sh

mkdir -p "$HOME/.local/bin" /usr/local/bin

link_bin() {
  local src="$1"
  local name="${2:-$(basename "$src")}"
  local dest_dir
  if [ ! -e "$src" ]; then
    return 0
  fi
  for dest_dir in "$HOME/.local/bin" /usr/local/bin; do
    ln -sfn "$src" "$dest_dir/$name"
  done
}

link_bin "$CUSTOM_CLAW_TOOLS_ROOT/obs-service-handler/bin/obsidian_sync_common.sh"
link_bin "$CUSTOM_CLAW_TOOLS_ROOT/obs-service-handler/bin/obsidian_sync_guard.sh"
link_bin "$CUSTOM_CLAW_TOOLS_ROOT/obs-service-handler/bin/obsidian_sync_healthcheck.sh"
link_bin "$CUSTOM_CLAW_TOOLS_ROOT/obs-service-handler/bin/obsidian_git_backup.sh"
link_bin "$CUSTOM_CLAW_TOOLS_ROOT/obs-auto-moc/bin/obs-auto-moc"
link_bin "$CUSTOM_CLAW_TOOLS_ROOT/obs-auto-moc/bin/obs-auto-moc-listen"
link_bin "$CUSTOM_CLAW_TOOLS_ROOT/obs-auto-moc/bin/obs-auto-moc-runner"
link_bin "$CUSTOM_CLAW_TOOLS_ROOT/fami-ghome/bin/fami-ghome"
link_bin "$CUSTOM_CLAW_TOOLS_ROOT/health-tracker/bin/health-tracker-garmin"
link_bin "$CUSTOM_CLAW_TOOLS_ROOT/famiclean-skill/skills/fami-claw-skill/fami-claw"

if [ -d "$CUSTOM_CLAW_TOOLS_ROOT/picoclaw-ops-companion/bin" ]; then
  while IFS= read -r -d '' src; do
    link_bin "$src"
  done < <(find "$CUSTOM_CLAW_TOOLS_ROOT/picoclaw-ops-companion/bin" -maxdepth 1 -type f -print0)
fi

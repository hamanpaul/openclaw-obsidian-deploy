#!/usr/bin/env bash
set -euo pipefail

source /ops/scripts/runtime-common.sh

mkdir -p "$HOME/.local/bin" /usr/local/bin

link_bin() {
  local src="$1"
  local name="${2:-$(basename "$src")}"
  local dest_dir

  if [ ! -f "$src" ]; then
    return 0
  fi

  for dest_dir in "$HOME/.local/bin" /usr/local/bin; do
    ln -sfn "$src" "$dest_dir/$name"
  done
}

old_ifs="$IFS"
IFS=':'
for bin_root in $OPENCLAW_ADDON_BIN_DIRS; do
  [ -d "$bin_root" ] || continue
  while IFS= read -r -d '' src; do
    link_bin "$src"
  done < <(find "$bin_root" -maxdepth 1 -type f -perm /111 -print0)
done
IFS="$old_ifs"

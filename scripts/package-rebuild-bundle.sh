#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OPS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

vault_dir="${OBSIDIAN_VAULT_HOST_DIR:-$HOME/obsidian_vault}"
config_dir="${OPENCLAW_CONFIG_HOST_DIR:-$HOME/.openclaw}"
include_auth=0
out_file=""

usage() {
  cat <<'EOF'
usage: package-rebuild-bundle.sh [--with-auth] [--output <bundle.tar.gz>]
  --with-auth           include ~/.openclaw (contains auth profiles/tokens)
  --output, -o <file>   output tar.gz path
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
  --with-auth)
    include_auth=1
    shift
    ;;
  --output | -o)
    shift
    if [ "$#" -eq 0 ]; then
      echo "missing value for --output" >&2
      usage
      exit 2
    fi
    out_file="$1"
    shift
    ;;
  --help | -h)
    usage
    exit 0
    ;;
  *)
    echo "unknown argument: $1" >&2
    usage
    exit 2
    ;;
  esac
done

if [ -z "$out_file" ]; then
  out_file="$OPS_DIR/openclaw-obsidian-rebuild-$("/usr/bin/date" -u +%Y%m%d-%H%M%S).tar.gz"
fi

required_paths=(
  "$OPS_DIR"
  "$vault_dir/openclaw"
  "$vault_dir/ObsToolsVault/specs"
  "$vault_dir/ObsToolsVault/state"
)

for path in "${required_paths[@]}"; do
  if [ ! -e "$path" ]; then
    echo "missing required path: $path" >&2
    exit 1
  fi
done

pack_paths=(
  "$OPS_DIR"
  "$vault_dir/openclaw"
  "$vault_dir/ObsToolsVault/specs"
  "$vault_dir/ObsToolsVault/state"
)

if [ "$include_auth" -eq 1 ]; then
  if [ ! -d "$config_dir" ]; then
    echo "missing auth config dir: $config_dir" >&2
    exit 1
  fi
  pack_paths+=("$config_dir")
fi

tmp_list="$("/usr/bin/mktemp")"
trap '/usr/bin/rm -f "$tmp_list"' EXIT

for path in "${pack_paths[@]}"; do
  echo "${path#/}" >>"$tmp_list"
done

/usr/bin/sort -u "$tmp_list" -o "$tmp_list"
/bin/mkdir -p "$(/usr/bin/dirname "$out_file")"

/usr/bin/tar -czf "$out_file" -C / --files-from "$tmp_list"

echo "bundle: $out_file"
echo "included paths:"
/usr/bin/sed 's#^#- /#' "$tmp_list"

if [ "$include_auth" -ne 1 ]; then
  echo "note: ~/.openclaw not included; add --with-auth if you need auth migration"
fi

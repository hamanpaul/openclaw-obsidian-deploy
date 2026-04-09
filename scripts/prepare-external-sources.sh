#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

OPENCLAW_EXTERNAL_SOURCES_DIR="${OPENCLAW_EXTERNAL_SOURCES_DIR:-$ROOT_DIR/build-context/external-sources}"
OPENCLAW_EXTERNAL_CACHE_DIR="${OPENCLAW_EXTERNAL_CACHE_DIR:-$HOME/.cache/openclaw-obsidian-deploy/external-sources}"
CUSTOM_CLAW_TOOLS_GIT_URL="${CUSTOM_CLAW_TOOLS_GIT_URL:-https://github.com/hamanpaul/custom-claw-tools.git}"
CUSTOM_CLAW_TOOLS_REF="${CUSTOM_CLAW_TOOLS_REF:-main}"
CUSTOM_SKILLS_GIT_URL="${CUSTOM_SKILLS_GIT_URL:-https://github.com/hamanpaul/custom-skills.git}"
CUSTOM_SKILLS_REF="${CUSTOM_SKILLS_REF:-main}"
SERIALWRAP_GIT_URL="${SERIALWRAP_GIT_URL:-https://github.com/hamanpaul/serialwrap.git}"
SERIALWRAP_REF="${SERIALWRAP_REF:-main}"

if [ "${OPENCLAW_EXTERNAL_SOURCES_DIR#/}" = "$OPENCLAW_EXTERNAL_SOURCES_DIR" ]; then
  OPENCLAW_EXTERNAL_SOURCES_DIR="$ROOT_DIR/$OPENCLAW_EXTERNAL_SOURCES_DIR"
fi
if [ "${OPENCLAW_EXTERNAL_CACHE_DIR#/}" = "$OPENCLAW_EXTERNAL_CACHE_DIR" ]; then
  OPENCLAW_EXTERNAL_CACHE_DIR="$ROOT_DIR/$OPENCLAW_EXTERNAL_CACHE_DIR"
fi

for bin in git jq rsync; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "missing dependency: $bin" >&2
    exit 2
  fi
done

prepare_repo() {
  local name="$1"
  local url="$2"
  local ref="$3"
  local cache_dir="$OPENCLAW_EXTERNAL_CACHE_DIR/$name"
  local checkout_target="$ref"

  if [ -d "$cache_dir/.git" ]; then
    git -C "$cache_dir" remote set-url origin "$url"
    git -C "$cache_dir" fetch --tags origin >/dev/null 2>&1
  else
    mkdir -p "$OPENCLAW_EXTERNAL_CACHE_DIR"
    git clone "$url" "$cache_dir"
  fi

  git -C "$cache_dir" fetch --tags origin "$ref" >/dev/null 2>&1 || true
  if git -C "$cache_dir" show-ref --verify --quiet "refs/remotes/origin/$ref"; then
    checkout_target="refs/remotes/origin/$ref"
  elif git -C "$cache_dir" show-ref --verify --quiet "refs/tags/$ref"; then
    checkout_target="refs/tags/$ref"
  elif git -C "$cache_dir" rev-parse --verify --quiet "$ref^{commit}" >/dev/null 2>&1; then
    checkout_target="$ref"
  elif git -C "$cache_dir" fetch origin "$ref" >/dev/null 2>&1; then
    checkout_target="FETCH_HEAD"
  fi

  if ! git -C "$cache_dir" checkout --force --detach "$checkout_target" >/dev/null 2>&1; then
    echo "[prepare-external] failed to checkout $name ref: $ref" >&2
    exit 1
  fi
  printf '%s' "$cache_dir"
}

stage_selected_paths() {
  local repo_name="$1"
  local source_root="$2"
  shift 2
  local dest_root="$OPENCLAW_EXTERNAL_SOURCES_DIR/$repo_name"
  mkdir -p "$dest_root"
  find "$dest_root" -mindepth 1 -maxdepth 1 -exec rm -rf {} +

  while [ "$#" -gt 0 ]; do
    local rel="$1"
    shift
    if [ -e "$source_root/$rel" ]; then
      mkdir -p "$(dirname "$dest_root/$rel")"
      rsync -a "$source_root/$rel" "$(dirname "$dest_root/$rel")/"
    else
      echo "[prepare-external] warning missing $repo_name/$rel" >&2
    fi
  done
}

mkdir -p "$OPENCLAW_EXTERNAL_SOURCES_DIR"
find "$OPENCLAW_EXTERNAL_SOURCES_DIR" -mindepth 1 -maxdepth 1 ! -name '.gitkeep' -exec rm -rf {} +

custom_claw_root="$(prepare_repo custom-claw-tools "$CUSTOM_CLAW_TOOLS_GIT_URL" "$CUSTOM_CLAW_TOOLS_REF")"
custom_claw_commit="$(git -C "$custom_claw_root" rev-parse HEAD)"
stage_selected_paths custom-claw-tools "$custom_claw_root" \
  obs-service-handler \
  obs-auto-moc \
  famiclean-skill \
  picoclaw-ops-companion

custom_skills_root="$(prepare_repo custom-skills "$CUSTOM_SKILLS_GIT_URL" "$CUSTOM_SKILLS_REF")"
custom_skills_commit="$(git -C "$custom_skills_root" rev-parse HEAD)"
stage_selected_paths custom-skills "$custom_skills_root" \
  test-playbook \
  serialwrap-mcp \
  obs-service-wsl-handler

serialwrap_root="$(prepare_repo serialwrap "$SERIALWRAP_GIT_URL" "$SERIALWRAP_REF")"
serialwrap_commit="$(git -C "$serialwrap_root" rev-parse HEAD)"
stage_selected_paths serialwrap "$serialwrap_root" \
  install.sh \
  serialwrap \
  serialwrap-mcp \
  serialwrapd.py \
  sw_core \
  sw_mcp \
  profiles \
  tools \
  docs

jq -n \
  --arg generated_at "$(date -u +%FT%TZ)" \
  --arg custom_claw_tools_git_url "$CUSTOM_CLAW_TOOLS_GIT_URL" \
  --arg custom_claw_tools_ref "$CUSTOM_CLAW_TOOLS_REF" \
  --arg custom_claw_tools_commit "$custom_claw_commit" \
  --arg custom_skills_git_url "$CUSTOM_SKILLS_GIT_URL" \
  --arg custom_skills_ref "$CUSTOM_SKILLS_REF" \
  --arg custom_skills_commit "$custom_skills_commit" \
  --arg serialwrap_git_url "$SERIALWRAP_GIT_URL" \
  --arg serialwrap_ref "$SERIALWRAP_REF" \
  --arg serialwrap_commit "$serialwrap_commit" \
  '{
    generated_at: $generated_at,
    repositories: [
      {
        name: "custom-claw-tools",
        git_url: $custom_claw_tools_git_url,
        ref: $custom_claw_tools_ref,
        commit: $custom_claw_tools_commit,
        selected_paths: [
          "obs-service-handler",
          "obs-auto-moc",
          "famiclean-skill",
          "picoclaw-ops-companion"
        ]
      },
      {
        name: "custom-skills",
        git_url: $custom_skills_git_url,
        ref: $custom_skills_ref,
        commit: $custom_skills_commit,
        selected_paths: [
          "test-playbook",
          "serialwrap-mcp",
          "obs-service-wsl-handler"
        ]
      },
      {
        name: "serialwrap",
        git_url: $serialwrap_git_url,
        ref: $serialwrap_ref,
        commit: $serialwrap_commit,
        selected_paths: [
          "install.sh",
          "serialwrap",
          "serialwrap-mcp",
          "serialwrapd.py",
          "sw_core",
          "sw_mcp",
          "profiles",
          "tools",
          "docs"
        ]
      }
    ]
  }' >"$OPENCLAW_EXTERNAL_SOURCES_DIR/manifest.json"

echo "[prepare-external] sources: $OPENCLAW_EXTERNAL_SOURCES_DIR"
echo "[prepare-external] custom-claw-tools: $custom_claw_commit"
echo "[prepare-external] custom-skills: $custom_skills_commit"
echo "[prepare-external] serialwrap: $serialwrap_commit"

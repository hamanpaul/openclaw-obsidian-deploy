#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

OPENCLAW_BASE_VERSION="${OPENCLAW_BASE_VERSION:-v2026.2.15}"
OPENCLAW_BASE_IMAGE="${OPENCLAW_BASE_IMAGE:-openclaw:v2026.2.15}"
OPENCLAW_BASE_IMAGE_GIT_URL="${OPENCLAW_BASE_IMAGE_GIT_URL:-https://github.com/openclaw/openclaw.git}"
OPENCLAW_BASE_IMAGE_CACHE_DIR="${OPENCLAW_BASE_IMAGE_CACHE_DIR:-$HOME/.cache/openclaw-obsidian-deploy/openclaw}"
OPENCLAW_DOCKER_APT_PACKAGES="${OPENCLAW_DOCKER_APT_PACKAGES:-}"

for bin in docker git; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "missing dependency: $bin" >&2
    exit 2
  fi
done

context_explicit=0
if [ "${OPENCLAW_BASE_IMAGE_CONTEXT+x}" = x ] && [ -n "${OPENCLAW_BASE_IMAGE_CONTEXT:-}" ]; then
  context_explicit=1
fi
if [ "$context_explicit" -ne 1 ]; then
  OPENCLAW_BASE_IMAGE_CONTEXT="$OPENCLAW_BASE_IMAGE_CACHE_DIR/$OPENCLAW_BASE_VERSION"
fi

dockerfile_explicit=0
if [ "${OPENCLAW_BASE_IMAGE_DOCKERFILE+x}" = x ] && [ -n "${OPENCLAW_BASE_IMAGE_DOCKERFILE:-}" ]; then
  dockerfile_explicit=1
fi
if [ "$dockerfile_explicit" -ne 1 ]; then
  OPENCLAW_BASE_IMAGE_DOCKERFILE="$OPENCLAW_BASE_IMAGE_CONTEXT/Dockerfile"
fi

if [ "${OPENCLAW_BASE_IMAGE_CONTEXT#/}" = "$OPENCLAW_BASE_IMAGE_CONTEXT" ]; then
  OPENCLAW_BASE_IMAGE_CONTEXT="$ROOT_DIR/$OPENCLAW_BASE_IMAGE_CONTEXT"
fi
if [ "${OPENCLAW_BASE_IMAGE_DOCKERFILE#/}" = "$OPENCLAW_BASE_IMAGE_DOCKERFILE" ]; then
  OPENCLAW_BASE_IMAGE_DOCKERFILE="$ROOT_DIR/$OPENCLAW_BASE_IMAGE_DOCKERFILE"
fi

ensure_context_checkout() {
  local current_tag=""

  if [ -d "$OPENCLAW_BASE_IMAGE_CONTEXT/.git" ]; then
    current_tag="$(git -C "$OPENCLAW_BASE_IMAGE_CONTEXT" describe --tags --exact-match HEAD 2>/dev/null || true)"
    if [ "$current_tag" = "$OPENCLAW_BASE_VERSION" ]; then
      return 0
    fi
    if [ "$context_explicit" -eq 1 ]; then
      echo "version mismatch: expected $OPENCLAW_BASE_VERSION but context HEAD is '${current_tag:-<no tag>}'" >&2
      exit 3
    fi
    echo "[prepare-base] refreshing cached context: $OPENCLAW_BASE_IMAGE_CONTEXT"
    rm -rf "$OPENCLAW_BASE_IMAGE_CONTEXT"
  elif [ -e "$OPENCLAW_BASE_IMAGE_CONTEXT" ]; then
    if [ "$context_explicit" -eq 1 ]; then
      echo "missing .git in context, expected checkout at tag $OPENCLAW_BASE_VERSION: $OPENCLAW_BASE_IMAGE_CONTEXT" >&2
      exit 2
    fi
    echo "[prepare-base] removing non-git cache path: $OPENCLAW_BASE_IMAGE_CONTEXT"
    rm -rf "$OPENCLAW_BASE_IMAGE_CONTEXT"
  fi

  if [ ! -d "$OPENCLAW_BASE_IMAGE_CONTEXT/.git" ]; then
    mkdir -p "$(dirname "$OPENCLAW_BASE_IMAGE_CONTEXT")"
    echo "[prepare-base] cloning $OPENCLAW_BASE_IMAGE_GIT_URL#$OPENCLAW_BASE_VERSION"
    git clone --depth 1 --branch "$OPENCLAW_BASE_VERSION" "$OPENCLAW_BASE_IMAGE_GIT_URL" "$OPENCLAW_BASE_IMAGE_CONTEXT"
  fi
}

ensure_context_checkout

if [ ! -f "$OPENCLAW_BASE_IMAGE_DOCKERFILE" ]; then
  echo "missing Dockerfile: $OPENCLAW_BASE_IMAGE_DOCKERFILE" >&2
  exit 2
fi

current_tag="$(git -C "$OPENCLAW_BASE_IMAGE_CONTEXT" describe --tags --exact-match HEAD 2>/dev/null || true)"
if [ "$current_tag" != "$OPENCLAW_BASE_VERSION" ]; then
  echo "version mismatch: expected $OPENCLAW_BASE_VERSION but context HEAD is '${current_tag:-<no tag>}'" >&2
  exit 3
fi

echo "[prepare-base] context: $OPENCLAW_BASE_IMAGE_CONTEXT"
echo "[prepare-base] dockerfile: $OPENCLAW_BASE_IMAGE_DOCKERFILE"
echo "[prepare-base] git-url: $OPENCLAW_BASE_IMAGE_GIT_URL"
echo "[prepare-base] version: $OPENCLAW_BASE_VERSION"
echo "[prepare-base] target image: $OPENCLAW_BASE_IMAGE"

if ! docker build \
  --build-arg "OPENCLAW_DOCKER_APT_PACKAGES=${OPENCLAW_DOCKER_APT_PACKAGES}" \
  -t "$OPENCLAW_BASE_IMAGE" \
  -f "$OPENCLAW_BASE_IMAGE_DOCKERFILE" \
  "$OPENCLAW_BASE_IMAGE_CONTEXT"; then
  echo "docker build failed for image: $OPENCLAW_BASE_IMAGE" >&2
  exit 4
fi

image_id="$(docker image inspect "$OPENCLAW_BASE_IMAGE" --format '{{.Id}}' 2>/dev/null || true)"
if [ -z "$image_id" ]; then
  echo "built image not found after build: $OPENCLAW_BASE_IMAGE" >&2
  exit 4
fi

echo "[prepare-base] done image=$OPENCLAW_BASE_IMAGE id=$image_id"

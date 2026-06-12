#!/usr/bin/env bash
set -euo pipefail

OPENCLAW_BASE_VERSION="${OPENCLAW_BASE_VERSION:-}"
OPENCLAW_BASE_IMAGE="${OPENCLAW_BASE_IMAGE:-openclaw:local}"
OPENCLAW_BASE_IMAGE_CONTEXT="${OPENCLAW_BASE_IMAGE_CONTEXT:-}"
OPENCLAW_BASE_IMAGE_DOCKERFILE="${OPENCLAW_BASE_IMAGE_DOCKERFILE:-}"
OPENCLAW_DOCKER_APT_PACKAGES="${OPENCLAW_DOCKER_APT_PACKAGES:-}"

for bin in docker git; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "missing dependency: $bin" >&2
    exit 2
  fi
done

if [ -z "$OPENCLAW_BASE_IMAGE_CONTEXT" ]; then
  echo "set OPENCLAW_BASE_IMAGE_CONTEXT to a local OpenClaw checkout before running this helper" >&2
  exit 2
fi

if [ -z "$OPENCLAW_BASE_IMAGE_DOCKERFILE" ]; then
  OPENCLAW_BASE_IMAGE_DOCKERFILE="$OPENCLAW_BASE_IMAGE_CONTEXT/Dockerfile"
fi

if [ ! -d "$OPENCLAW_BASE_IMAGE_CONTEXT" ]; then
  echo "missing build context: $OPENCLAW_BASE_IMAGE_CONTEXT" >&2
  exit 2
fi

if [ ! -f "$OPENCLAW_BASE_IMAGE_DOCKERFILE" ]; then
  echo "missing Dockerfile: $OPENCLAW_BASE_IMAGE_DOCKERFILE" >&2
  exit 2
fi

if [ -n "$OPENCLAW_BASE_VERSION" ] && [ -d "$OPENCLAW_BASE_IMAGE_CONTEXT/.git" ]; then
  current_tag="$(git -C "$OPENCLAW_BASE_IMAGE_CONTEXT" describe --tags --exact-match HEAD 2>/dev/null || true)"
  if [ "$current_tag" != "$OPENCLAW_BASE_VERSION" ]; then
    echo "version mismatch: expected $OPENCLAW_BASE_VERSION but context HEAD is '${current_tag:-<no tag>}'" >&2
    exit 3
  fi
fi

echo "[prepare-base] context: $OPENCLAW_BASE_IMAGE_CONTEXT"
echo "[prepare-base] dockerfile: $OPENCLAW_BASE_IMAGE_DOCKERFILE"
if [ -n "$OPENCLAW_BASE_VERSION" ]; then
  echo "[prepare-base] version: $OPENCLAW_BASE_VERSION"
fi
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

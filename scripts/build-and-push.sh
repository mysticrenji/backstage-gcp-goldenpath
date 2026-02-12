#!/usr/bin/env bash
set -euo pipefail

# Configuration
GHCR_REGISTRY="ghcr.io"
GHCR_OWNER="${GHCR_OWNER:-mysticrenji}"
IMAGE_NAME="${IMAGE_NAME:-backstage}"
IMAGE_TAG="v6"  #"${IMAGE_TAG:-$(git rev-parse --short HEAD)}"
FULL_IMAGE="${GHCR_REGISTRY}/${GHCR_OWNER}/${IMAGE_NAME}"
BACKSTAGE_DIR="$(cd "$(dirname "$0")/../backstage" && pwd)"

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Build the Backstage app and push the Docker image to ghcr.io.

Options:
  --tag TAG         Image tag (default: git short SHA)
  --owner OWNER     GHCR owner/org (default: mysticrenji)
  --name NAME       Image name (default: backstage)
  --skip-build      Skip the yarn build step (use existing build artifacts)
  --push            Push the image to GHCR (default: build only)
  --latest          Also tag and push as 'latest'
  --dry-run         Show what would be done without executing anything
  -h, --help        Show this help message
EOF
  exit 0
}

SKIP_BUILD=false
PUSH=false
TAG_LATEST=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --tag)        IMAGE_TAG="$2"; shift 2 ;;
    --owner)      GHCR_OWNER="$2"; FULL_IMAGE="${GHCR_REGISTRY}/${GHCR_OWNER}/${IMAGE_NAME}"; shift 2 ;;
    --name)       IMAGE_NAME="$2"; FULL_IMAGE="${GHCR_REGISTRY}/${GHCR_OWNER}/${IMAGE_NAME}"; shift 2 ;;
    --skip-build) SKIP_BUILD=true; shift ;;
    --push)       PUSH=true; shift ;;
    --latest)     TAG_LATEST=true; shift ;;
    --dry-run)    DRY_RUN=true; shift ;;
    -h|--help)    usage ;;
    *)            echo "Unknown option: $1"; usage ;;
  esac
done

run() {
  if [ "$DRY_RUN" = true ]; then
    echo "[dry-run] $*"
  else
    "$@"
  fi
}

if [ "$DRY_RUN" = true ]; then
  echo "==> DRY RUN MODE (no commands will be executed)"
fi

echo "==> Image: ${FULL_IMAGE}:${IMAGE_TAG}"

# Step 1: Build Backstage backend
if [ "$SKIP_BUILD" = false ]; then
  echo "==> Installing dependencies..."
  cd "$BACKSTAGE_DIR"
  run yarn install --immutable

  echo "==> Building backend..."
  run yarn build:backend
else
  echo "==> Skipping build (using existing artifacts)"
fi

# Step 2: Copy templates into Docker build context
REPO_ROOT="$(cd "$BACKSTAGE_DIR/.." && pwd)"
TEMPLATES_SRC="$REPO_ROOT/templates"
TEMPLATES_DST="$BACKSTAGE_DIR/templates"

if [ -d "$TEMPLATES_SRC" ]; then
  echo "==> Copying templates into build context..."
  run cp -r "$TEMPLATES_SRC" "$TEMPLATES_DST"
else
  echo "Warning: $TEMPLATES_SRC not found, skipping template copy"
fi

# Step 3: Build Docker image
echo "==> Building Docker image..."
cd "$BACKSTAGE_DIR"
run env DOCKER_BUILDKIT=1 docker build \
  -f packages/backend/Dockerfile \
  -t "${FULL_IMAGE}:${IMAGE_TAG}" \
  .

# Clean up copied templates from build context
if [ -d "$TEMPLATES_DST" ]; then
  run rm -rf "$TEMPLATES_DST"
fi

if [ "$TAG_LATEST" = true ]; then
  run docker tag "${FULL_IMAGE}:${IMAGE_TAG}" "${FULL_IMAGE}:latest"
fi

echo "==> Image built: ${FULL_IMAGE}:${IMAGE_TAG}"

# Step 4: Push to GHCR
if [ "$PUSH" = true ]; then
  echo "==> Logging in to ${GHCR_REGISTRY}..."
  if [ -z "${GITHUB_TOKEN:-}" ] && [ "$DRY_RUN" = false ]; then
    echo "Error: GITHUB_TOKEN environment variable is required for pushing."
    echo "Export it with: export GITHUB_TOKEN=ghp_..."
    echo "Or use: echo \$GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin"
    exit 1
  fi
  run sh -c "echo \"\${GITHUB_TOKEN}\" | docker login \"${GHCR_REGISTRY}\" -u \"${GHCR_OWNER}\" --password-stdin"

  echo "==> Pushing ${FULL_IMAGE}:${IMAGE_TAG}..."
  run docker push "${FULL_IMAGE}:${IMAGE_TAG}"

  if [ "$TAG_LATEST" = true ]; then
    echo "==> Pushing ${FULL_IMAGE}:latest..."
    run docker push "${FULL_IMAGE}:latest"
  fi

  echo "==> Push complete!"
else
  echo "==> Skipping push (use --push to push to GHCR)"
fi

echo "==> Done!"

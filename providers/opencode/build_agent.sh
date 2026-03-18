#!/usr/bin/env bash
# build_agent.sh
# Usage:
#   ./build_agent.sh --name=<project_name> --root=<path> [--no-cache]
#
# Builds the Docker image for a project. Does not start the container.
# Called directly by agent-sandbox build, or by agent-sandbox start/dry-run
# when the image is missing or --force-build is set.

set -euo pipefail

# -------------------------
# Flag parsing
# -------------------------
PROJECT_NAME=""
NO_CACHE=""

for ARG in "$@"; do
  case "$ARG" in
    --name=*)    PROJECT_NAME="${ARG#--name=}" ;;
    --root=*)      ;; # accepted but not needed
    --project=*)   ;; # accepted but not needed
    --sandbox=*)   ;; # accepted but not needed — build context is always REPO_ROOT
    --brief=*)     ;; # accepted but not needed
    --env=*)       ;; # accepted but not needed
    --serve)       ;; # accepted but not needed
    --no-cache)  NO_CACHE="--no-cache" ;;
    *)
      echo "Unknown flag: $ARG"
      exit 1
      ;;
  esac
done

if [[ -z "$PROJECT_NAME" ]]; then
  echo "Error: --name is required"
  exit 1
fi

# -------------------------
# Paths
# -------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# REPO_ROOT assumes this script lives at providers/opencode/
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

IMAGE_NAME="opencode-agent-${PROJECT_NAME,,}"
DOCKERFILE="$REPO_ROOT/providers/opencode/Dockerfile"

# -------------------------
# Build
# -------------------------

# Compute digest before build so it reflects the source files being built
source "$REPO_ROOT/libs/image.sh"
IMAGE_FILES_TXT="$REPO_ROOT/providers/opencode/image-files.txt"
DIGEST=$(image_compute_digest "$REPO_ROOT" "$IMAGE_FILES_TXT")

echo "Building Docker image: $IMAGE_NAME"
docker build $NO_CACHE \
  --label "agent-sandbox.digest=$DIGEST" \
  -t "$IMAGE_NAME" \
  -f "$DOCKERFILE" \
  "$REPO_ROOT"
echo "Build complete: $IMAGE_NAME"

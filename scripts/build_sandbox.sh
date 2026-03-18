#!/usr/bin/env bash
# build_sandbox.sh
# Usage:
#   ./build_sandbox.sh --name=<project_name> --sandbox=<path> [--no-cache]
#
# Builds the capability layer Docker image for a project.
# The Dockerfile is expected at SANDBOX_DIR/Dockerfile.sandbox.
# Build context is always REPO_ROOT (not SANDBOX_DIR) so that shared
# libs/ and scripts/ are available to COPY instructions.

set -euo pipefail

# -------------------------
# Flag parsing
# -------------------------
PROJECT_NAME=""
SANDBOX_DIR=""
NO_CACHE=""

for ARG in "$@"; do
  case "$ARG" in
    --name=*)    PROJECT_NAME="${ARG#--name=}" ;;
    --sandbox=*) SANDBOX_DIR="${ARG#--sandbox=}" ;;
    --no-cache)  NO_CACHE="--no-cache" ;;
    # Accepted but not needed — tolerated so callers can pass full flag sets
    --project=*) ;;
    --brief=*)   ;;
    --env=*)     ;;
    --serve)     ;;
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

if [[ -z "$SANDBOX_DIR" ]]; then
  echo "Error: --sandbox is required"
  exit 1
fi

# -------------------------
# Paths
# -------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# REPO_ROOT assumes this script lives at scripts/
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

IMAGE_NAME="agent-sandbox-${PROJECT_NAME,,}"
DOCKERFILE="$SANDBOX_DIR/Dockerfile.sandbox"

if [[ ! -f "$DOCKERFILE" ]]; then
  echo "Error: Dockerfile.sandbox not found: $DOCKERFILE"
  echo "  Place Dockerfile.sandbox in SANDBOX_DIR before building."
  exit 1
fi

# -------------------------
# Build
# -------------------------
echo "Building capability layer image: $IMAGE_NAME"
docker build $NO_CACHE \
  -t "$IMAGE_NAME" \
  -f "$DOCKERFILE" \
  "$REPO_ROOT"
echo "Build complete: $IMAGE_NAME"

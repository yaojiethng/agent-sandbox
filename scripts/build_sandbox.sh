#!/usr/bin/env bash
# build_sandbox.sh
# Usage:
#   ./build_sandbox.sh --name=<project_name> --sandbox=<path> [--no-cache]
#
# Builds the capability layer Docker image for a project.
# The Dockerfile is expected at SANDBOX_DIR/Dockerfile.sandbox.
# build_context populates a temp directory with the required files;
# docker build uses the temp directory as build context and tags the
# image with a digest of the context contents.

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

source "$REPO_ROOT/libs/containers.sh"

IMAGE_NAME="$(sandbox_image_name "$PROJECT_NAME")"
DOCKERFILE="$REPO_ROOT/libs/sandbox.Dockerfile"

if [[ ! -f "$DOCKERFILE" ]]; then
  echo "Error: sandbox Dockerfile not found: $DOCKERFILE"
  echo "  The agent-sandbox repo may be incomplete or out of date."
  exit 1
fi

# -------------------------
# Build context
# -------------------------
source "$REPO_ROOT/libs/build_context.sh"
CONTEXT_DIR=$(build_context sandbox "$REPO_ROOT")
trap 'rm -rf "$CONTEXT_DIR"' EXIT

DIGEST=$(find "$CONTEXT_DIR" -type f | sort | xargs sha256sum | sha256sum | awk '{print $1}')

# -------------------------
# Build
# -------------------------
echo "Building capability layer image: $IMAGE_NAME"
docker build $NO_CACHE \
  --label "agent-sandbox.digest=$DIGEST" \
  -t "$IMAGE_NAME" \
  -f "$DOCKERFILE" \
  "$CONTEXT_DIR"
echo "Build complete: $IMAGE_NAME"

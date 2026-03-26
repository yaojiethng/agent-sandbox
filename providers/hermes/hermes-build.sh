#!/usr/bin/env bash
# providers/hermes/build.sh
# Usage:
#   ./build.sh --name=<project_name> [--no-cache]
#
# Builds the reasoning layer Docker image for a project using the Hermes provider.
# build_context populates a temp directory with the required files;
# docker build uses the temp directory as build context and tags the
# image with a digest of the context contents.

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
# REPO_ROOT assumes this script lives at providers/hermes/
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

IMAGE_NAME="hermes-agent-${PROJECT_NAME,,}"
DOCKERFILE="$REPO_ROOT/providers/hermes/Dockerfile"

# -------------------------
# Build context
# -------------------------
source "$REPO_ROOT/libs/build_context.sh"

CONTEXT_DIR=$(build_context agent "$REPO_ROOT")
trap 'rm -rf "$CONTEXT_DIR"' EXIT

DIGEST=$(find "$CONTEXT_DIR" -type f | sort | xargs sha256sum | sha256sum | awk '{print $1}')

# -------------------------
# Build
# -------------------------
echo "Building Docker image: $IMAGE_NAME"
docker build $NO_CACHE \
  --label "agent-sandbox.digest=$DIGEST" \
  -t "$IMAGE_NAME" \
  -f "$DOCKERFILE" \
  "$CONTEXT_DIR"
echo "Build complete: $IMAGE_NAME"

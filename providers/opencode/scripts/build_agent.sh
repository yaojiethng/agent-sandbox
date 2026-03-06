#!/usr/bin/env bash

# Usage:
#   ./build-agent.sh [--no-cache]
#
# Options:
#   --no-cache : Build Docker image without cache
#
# Behavior:
# - Uses HOST_PROJECT_ROOT if set, defaults to ~/opencode-projects
# - Ensures required folders exist
# - Builds Docker image: opencode-agent-image:latest

set -e

NO_CACHE=""
if [ "$1" == "--no-cache" ]; then
    NO_CACHE="--no-cache"
fi

# Default host root
HOST_PROJECT_ROOT="${HOST_PROJECT_ROOT:-$HOME/opencode}"

# Build Docker image
echo "Building OpenCode agent Docker image..."
docker build $NO_CACHE -t opencode-agent-image:latest .

echo "Build complete."
echo
echo "Next steps:"
echo "1. Start an agent:"
echo "   ./start-agent.sh <project_name> safe"
echo "2. Verify container runs:"
echo "   docker ps"
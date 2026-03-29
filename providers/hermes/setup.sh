#!/usr/bin/env bash
# providers/hermes/setup.sh
# Pre-run host setup hook for the Hermes provider.
# Sourced by scripts/run_agent.sh before compose generation.
#
# Responsibilities:
#   - Export provider-specific vars needed by compose overlays
#   - Pre-create host-side files and directories for bind mounts
#
# Docker creates missing bind mount sources as root-owned directories.
# Files and directories must exist on the host before any docker compose call.
#
# OUTPUT_DIR is exported by scripts/start_agent.sh from .env and is available
# when this script is sourced.

# -------------------------
# Provider-specific vars
# -------------------------
export HERMES_CONFIG_FILE="$OUTPUT_DIR/.hermes/config.yaml"
export HERMES_ENV_FILE="$OUTPUT_DIR/.hermes/.env"

# -------------------------
# Pre-run host setup
# -------------------------
mkdir -p "$OUTPUT_DIR/.hermes"

if [[ ! -f "$HERMES_CONFIG_FILE" ]]; then
  cp "$REPO_ROOT/providers/hermes/config.yaml" "$HERMES_CONFIG_FILE"
fi

if [[ ! -f "$HERMES_ENV_FILE" ]]; then
  touch "$HERMES_ENV_FILE"
fi

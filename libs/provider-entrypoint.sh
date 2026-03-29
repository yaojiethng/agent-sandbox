#!/usr/bin/env bash
# libs/provider-entrypoint.sh
# Harness-owned wrapper entrypoint for all reasoning layer provider containers.
# Copied into the image via the build context — a change to this file triggers
# a Docker layer cache miss on the COPY step in provider.Dockerfile.
#
# Responsibilities:
#   1. Seed provider config files into AGENT_HOME if they are absent (first run).
#      Source: /opt/context/config/ — baked into the image via build context.
#      Each file is seeded independently; existing files are never overwritten.
#      env.stub is seeded as .env.
#   2. Register an EXIT trap to copy AGENT_HOME back to workspace/output/.<provider>/
#      (copy-out). Fires on all exits: normal, interrupt, docker stop.
#   3. exec the provider's real entrypoint command, replacing this process.
#
# Environment (set via ENV in provider.Dockerfile):
#   AGENT_HOME     — provider config dir inside the container (e.g. /home/agentuser/.hermes)
#   PROVIDER_NAME  — provider name (e.g. hermes, opencode)
#
# Copy-out target:
#   /home/agentuser/workspace/output/.<provider>/
#   Bind-mounted from $SANDBOX_DIR/.workspace/output/ on the host.
#   run_agent.sh moves it to $SANDBOX_DIR/.<provider>/ after the container exits.

set -euo pipefail

if [[ -z "${AGENT_HOME:-}" ]]; then
  echo "provider-entrypoint: AGENT_HOME is not set" >&2
  exit 1
fi

if [[ -z "${PROVIDER_NAME:-}" ]]; then
  echo "provider-entrypoint: PROVIDER_NAME is not set" >&2
  exit 1
fi

SEED_DIR="/opt/context/config"
COPY_OUT_TARGET="/home/agentuser/workspace/output/.${PROVIDER_NAME}"

# -------------------------
# Seed config (first run)
# -------------------------
# Seeds files from /opt/context/config/ into AGENT_HOME if absent.
# Each file is seeded independently — existing files are never overwritten.
# env.stub is seeded as .env.
if [[ -d "$SEED_DIR" ]]; then
  mkdir -p "$AGENT_HOME"
  for src in "$SEED_DIR"/*; do
    [[ -f "$src" ]] || continue
    filename="$(basename "$src")"
    if [[ "$filename" == "env.stub" ]]; then
      filename=".env"
    fi
    dst="$AGENT_HOME/$filename"
    if [[ ! -f "$dst" ]]; then
      cp "$src" "$dst"
    fi
  done
fi

# -------------------------
# Copy-out trap
# -------------------------
_copy_out() {
  if [[ -d "$AGENT_HOME" ]] && [[ -n "$(ls -A "$AGENT_HOME" 2>/dev/null)" ]]; then
    mkdir -p "$COPY_OUT_TARGET"
    cp -r "$AGENT_HOME/." "$COPY_OUT_TARGET/"
  fi
}

trap '_copy_out' EXIT

# -------------------------
# Exec provider command
# -------------------------
exec "$@"

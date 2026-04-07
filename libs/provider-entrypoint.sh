#!/usr/bin/env bash
# libs/provider-entrypoint.sh
# Harness-owned wrapper entrypoint for all reasoning layer provider containers.
# Copied into the image via the build context — a change to this file triggers
# a Docker layer cache miss on the COPY step in provider.Dockerfile.
#
# Responsibilities:
#   1. Copy provider config from /opt/provider-config/ (bind-mounted from
#      $SANDBOX_DIR/.<provider>/ on the host) into AGENT_HOME. Runs every
#      session start — first run seeds from onboarding templates, subsequent
#      runs resume from prior session state.
#   2. Register an EXIT trap to copy AGENT_HOME back to /opt/provider-config/
#      (persist). Fires on all exits: normal, interrupt, docker stop.
#   3. Run the provider's real entrypoint command as a child process and wait
#      for it to exit, forwarding SIGTERM/INT so docker stop works correctly.
#
# Environment (set via ENV in provider.Dockerfile):
#   AGENT_HOME     — provider config dir inside the container (e.g. /home/agentuser/.hermes)
#   PROVIDER_NAME  — provider name (e.g. hermes, opencode)
#
# Mount:
#   /opt/provider-config/  — RW bind mount from $SANDBOX_DIR/.<provider>/ on the host.
#                            Source for copy-in; target for copy-out.

set -euo pipefail

if [[ -z "${AGENT_HOME:-}" ]]; then
  echo "provider-entrypoint: AGENT_HOME is not set" >&2
  exit 1
fi

if [[ -z "${PROVIDER_NAME:-}" ]]; then
  echo "provider-entrypoint: PROVIDER_NAME is not set" >&2
  exit 1
fi

PROVIDER_CONFIG_DIR="/opt/provider-config"

# -------------------------
# Copy-in
# -------------------------
# Copies provider config from the bind-mounted host directory into AGENT_HOME.
# On first run: host directory contains onboarding templates (populated by
# agent-sandbox onboard). On subsequent runs: contains prior session state.
if [[ -d "$PROVIDER_CONFIG_DIR" ]] && [[ -n "$(ls -A "$PROVIDER_CONFIG_DIR" 2>/dev/null)" ]]; then
  mkdir -p "$AGENT_HOME"
  cp -r "$PROVIDER_CONFIG_DIR/." "$AGENT_HOME/"
fi

# -------------------------
# Copy-out trap
# -------------------------
# Copies AGENT_HOME back to the bind-mounted host directory on exit.
# Persists provider config and session state for the next run.
_copy_out() {
  if [[ -d "$AGENT_HOME" ]] && [[ -n "$(ls -A "$AGENT_HOME" 2>/dev/null)" ]]; then
    mkdir -p "$PROVIDER_CONFIG_DIR"
    cp -r "$AGENT_HOME/." "$PROVIDER_CONFIG_DIR/"
  fi
}

trap '_copy_out' EXIT

# -------------------------
# Run provider command
# -------------------------
# Do NOT exec here. exec replaces this shell process, which discards the EXIT
# trap registered above — copy-out would never run.
#
# Instead: launch the agent as a background child, capture its PID, forward
# SIGTERM/INT (sent by docker stop / Ctrl-C) to it, then wait. When wait
# returns the EXIT trap fires and copy-out runs.
"$@" &
AGENT_PID=$!

_forward_signal() {
  kill -TERM "$AGENT_PID" 2>/dev/null || true
}
trap '_forward_signal' TERM INT

wait "$AGENT_PID"

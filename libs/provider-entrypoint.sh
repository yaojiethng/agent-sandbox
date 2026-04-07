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
#   3. Launch the provider's real entrypoint as a background child, forward
#      SIGTERM from docker stop, and wait. When the child exits the EXIT trap
#      fires and copy-out runs.
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
# Launch the agent as a background child and wait. This keeps the shell alive
# so the EXIT trap above fires when the agent exits — copy-out runs cleanly in
# both termination cases:
#
#   Normal exit — agent quits on its own (user exits TUI, task complete, etc.).
#                 wait returns, EXIT trap fires, copy-out runs.
#
#   docker stop — SIGTERM is sent to PID 1 (this shell) only, not the child.
#                 TERM trap forwards it to the agent, waits for it to exit, then
#                 exits the shell — EXIT trap fires, copy-out runs.
#
# SIGINT (Ctrl-C) is not forwarded. The agent receives it directly via the
# process group and handles it internally. The shell traps it as a no-op to
# avoid dying mid-session on a routine keypress inside the TUI.
"$@" &
AGENT_PID=$!

_forward_term() {
  kill -TERM "$AGENT_PID" 2>/dev/null || true
}
trap '_forward_term' TERM
trap '' INT

wait "$AGENT_PID"

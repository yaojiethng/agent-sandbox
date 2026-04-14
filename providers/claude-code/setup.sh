#!/usr/bin/env bash
# providers/claude-code/setup.sh
# Pre-run host setup hook for the Claude Code provider.
# Sourced by scripts/run_agent.sh before compose generation.
# Has access to all variables exported by scripts/start_agent.sh and all libs/ functions.

# Pre-create the host-side config directory so copy-out has a landing target
# on the first session (before any prior state exists in SANDBOX_DIR).
mkdir -p "${SANDBOX_DIR}/.claude-code"

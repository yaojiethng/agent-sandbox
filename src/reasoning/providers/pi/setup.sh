#!/usr/bin/env bash
# providers/pi/setup.sh
# Pre-run host setup hook for the Pi provider.
# Sourced by scripts/run_agent.sh before compose generation.
# Has access to all variables exported by scripts/start_agent.sh and all libs/ functions.

# Pre-create the host-side subdirectories so the provider overlay has a mount
# on the first session (before any prior state exists in SANDBOX_DIR).
mkdir -p "${SANDBOX_DIR}/.pi"

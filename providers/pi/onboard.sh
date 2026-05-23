#!/usr/bin/env bash
# providers/pi/onboard.sh

echo "Running Pi provider onboard hook..."

# Pre-create the host-side config directory so copy-out has a landing target
# on the first session (before any prior state exists in SANDBOX_DIR).
mkdir -p "$SANDBOX_DIR/.pi/agent/sessions"
mkdir -p "$SANDBOX_DIR/.pi/agent/prompts"
mkdir -p "$SANDBOX_DIR/.pi/agent/skills"
mkdir -p "$SANDBOX_DIR/.pi/agent/extensions"



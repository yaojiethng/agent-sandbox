#!/usr/bin/env bash
# container-entrypoint.sh (reasoning layer)
# Brief injection, operator input copy, agent exec.
#
# Sequence:
#   1. copy brief.md into sandbox/        — if present in .agent-input/
#   2. copy input/ contents into sandbox/ — if .agent-input/input/ is non-empty
#   3. exec agent                         — hand off to OpenCode
#
# Snapshot unpacking, git baseline, and diff pipeline are handled by the
# capability layer container (sandbox-entrypoint.sh). This entrypoint assumes
# sandbox/ is already populated and git-initialised by the time it runs.
#
# Environment variables (all have defaults defined in libs/dirs.sh,
# override via docker run -e or compose .env):
#   AGENT_INPUT_DIR_NAME   — name of the input channel directory  (default: .agent-input)
#   SANDBOX_DIR_NAME       — name of the sandbox directory        (default: sandbox)

set -euo pipefail

shopt -s nullglob

# Redirect all entrypoint output to stderr so it doesn't pollute the TUI.
# View with: docker logs <container_name>
exec 1>&2

ROOT="/home/agentuser"

# Directory name defaults — single source of truth.
# Override via environment variables without rebuilding the image.
source /libs/dirs.sh

AGENT_INPUT_DIR="$ROOT/$AGENT_INPUT_DIR_NAME"
SANDBOX_DIR="$ROOT/$SANDBOX_DIR_NAME"

# -------------------------
# Copy brief into sandbox root
# -------------------------
if [[ -f "$AGENT_INPUT_DIR/brief.md" ]]; then
  cp -p "$AGENT_INPUT_DIR/brief.md" "$SANDBOX_DIR/AGENTS.md"
  echo "Brief copied to sandbox/AGENTS.md."
fi

# -------------------------
# Copy operator input files into sandbox
# -------------------------
# Contents of .agent-input/input/ are copied into sandbox/ so the agent
# can read task files, path lists, and other operator-provided materials
# alongside the project snapshot. The agent cannot write back to this channel.
if [[ -d "$AGENT_INPUT_DIR/input" ]]; then
  input_count=$(find "$AGENT_INPUT_DIR/input" -type f | wc -l)
  if [[ "$input_count" -gt 0 ]]; then
    cp -a "$AGENT_INPUT_DIR/input/." "$SANDBOX_DIR/"
    echo "Copied $input_count operator input file(s) into sandbox."
  fi
fi

# -------------------------
# Execute agent
# -------------------------
# exec replaces this shell — no EXIT trap needed here.
# The capability layer container owns the diff pipeline.
exec "$@"

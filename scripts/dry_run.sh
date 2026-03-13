#!/usr/bin/env bash
# dry_run.sh
# Diagnostic checks run inside the container during a dry-run.
# Prints all output to stdout. Does not write to .workspace.
# Mounted and executed by start_agent.sh; can be reused in other contexts.
#
# Expects env vars set by start_agent.sh:
#   AGENT_INPUT_DIR_NAME     — name of the input directory (e.g. .agent-input)
#   AGENT_WORKSPACE_DIR_NAME — name of the workspace directory (e.g. .workspace)

set -euo pipefail

ROOT="/home/agentuser"
AGENT_INPUT_DIR_NAME="${AGENT_INPUT_DIR_NAME:-.agent-input}"
AGENT_WORKSPACE_DIR_NAME="${AGENT_WORKSPACE_DIR_NAME:-.workspace}"

AGENT_INPUT_DIR="$ROOT/$AGENT_INPUT_DIR_NAME"
AGENT_WORKSPACE_DIR="$ROOT/$AGENT_WORKSPACE_DIR_NAME"

echo "=== identity ==="
id

echo ""
echo "=== $AGENT_INPUT_DIR_NAME mount ownership ==="
stat "$AGENT_INPUT_DIR"

echo ""
echo "=== $AGENT_WORKSPACE_DIR_NAME mount ownership ==="
stat "$AGENT_WORKSPACE_DIR"

echo ""
echo "=== snapshot contents ==="
ls -p "$AGENT_INPUT_DIR/snapshot" 2>&1 || echo "no snapshot found"

echo ""
echo "=== .gitignore present in snapshot ==="
ls "$AGENT_INPUT_DIR/snapshot/.gitignore" 2>&1 || echo "no .gitignore in snapshot"

echo ""
echo "=== brief present ==="
ls "$AGENT_INPUT_DIR/brief.md" 2>&1 || echo "no brief.md"

echo ""
echo "=== operator input files ==="
if [[ -d "$AGENT_INPUT_DIR/input" ]]; then
  ls -p "$AGENT_INPUT_DIR/input" 2>&1 || echo "input/ directory is empty"
else
  echo "no input/ directory"
fi

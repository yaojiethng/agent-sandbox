#!/usr/bin/env bash
# dry_run.sh
# Diagnostic checks run inside the agent container during a dry-run.
# Prints all output to stdout.
# Bind-mounted at /dry_run.sh via the dry-run compose overlay.
#
# Checks:
#   - identity (user, uid)
#   - workspace/input mount ownership and contents
#   - workspace/output mount ownership and writability
#   - sandbox/.git exists (capability layer completed init)
#   - snapshot .gitignore present (sanity check on snapshot quality)
#   - brief.md present in workspace/input/

set -euo pipefail

ROOT="/home/agentuser"

source /libs/dirs.sh

INPUT_DIR="$ROOT/$INPUT_DIR_NAME"
OUTPUT_DIR="$ROOT/$OUTPUT_DIR_NAME"
SANDBOX_DIR="$ROOT/$SANDBOX_DIR_NAME"

echo "=== identity ==="
id

echo ""
echo "=== workspace/input mount ==="
stat "$INPUT_DIR"

echo ""
echo "=== workspace/output mount ==="
stat "$OUTPUT_DIR"

echo ""
echo "=== workspace/input contents ==="
ls -p "$INPUT_DIR" 2>&1 || echo "workspace/input is empty"

echo ""
echo "=== brief present ==="
ls "$INPUT_DIR/brief.md" 2>&1 || echo "no brief.md in workspace/input/"

echo ""
echo "=== sandbox/.git present (capability layer ready) ==="
test -d "$SANDBOX_DIR/.git" && echo "sandbox/.git found" || echo "ERROR: sandbox/.git missing — capability layer may not have completed init"

echo ""
echo "=== .gitignore present in sandbox ==="
ls "$SANDBOX_DIR/.gitignore" 2>&1 || echo "no .gitignore in sandbox"

echo ""
echo "=== workspace/output write check ==="
LIVENESS_FILE="$OUTPUT_DIR/liveness.txt"
echo "PASS" > "$LIVENESS_FILE" && echo "liveness.txt written to workspace/output/" || echo "ERROR: could not write to workspace/output/"

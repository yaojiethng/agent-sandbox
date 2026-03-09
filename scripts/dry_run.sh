#!/usr/bin/env bash
# dry_run.sh
# Diagnostic checks run inside the container during a dry-run.
# Prints all output to stdout. Does not write to .workspace.
# Mounted and executed by start_agent.sh; can be reused in other contexts.

set -euo pipefail

echo "=== identity ==="
id

echo ""
echo "=== .bootstrap mount ownership ==="
stat /home/agentuser/.bootstrap

echo ""
echo "=== .workspace mount ownership ==="
stat /home/agentuser/.workspace

echo ""
echo "=== snapshot contents ==="
ls -p /home/agentuser/.bootstrap/snapshot 2>&1 || echo "no snapshot found"

echo ""
echo "=== .gitignore present in snapshot ==="
ls /home/agentuser/.bootstrap/snapshot/.gitignore 2>&1 || echo "no .gitignore in snapshot"

echo ""
echo "=== brief present ==="
ls /home/agentuser/.bootstrap/brief.md 2>&1 || echo "no brief.md"
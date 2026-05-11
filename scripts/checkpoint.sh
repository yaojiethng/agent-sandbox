#!/usr/bin/env bash
# scripts/checkpoint.sh
#
# Consolidated checkpoint library for agent-sandbox.
# Sourced by start_agent.sh.
# Contains only function definitions — no top-level code.
#
# Functions:
#   worktree_id_derive   — Derive WORKTREE_ID from PROJECT_DIR absolute path

set -euo pipefail

# Derive WORKTREE_ID from PROJECT_DIR absolute path
# Returns 8-character hex hash for namespacing per-worktree
# Args:
#   $1  PROJECT_DIR  — absolute path to project directory
# Returns:
#   8-character hex hash
worktree_id_derive() {
  local PROJECT_DIR="$1"
  echo "$PROJECT_DIR" | sha256sum | cut -c1-8
}

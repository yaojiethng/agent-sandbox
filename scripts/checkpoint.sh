#!/usr/bin/env bash
# scripts/checkpoint.sh
#
# Consolidated checkpoint library for agent-sandbox.
# Sourced by start_agent.sh, apply_workspace.sh, and advance_baseline.sh.
# Contains only function definitions — no top-level code.
#
# Functions (spec interface from Change 5):
#   worktree_id_derive   — Derive WORKTREE_ID from PROJECT_DIR absolute path
#   checkpoint_create    — Create checkpoint tag and prune old ones
#   checkpoint_prune     — Prune old checkpoint tags (standalone)
#   checkpoint_lookup    — Look up latest checkpoint tag for this worktree
#
# Aliases for internal consistency:
#   checkpoint_worktree_id — alias for worktree_id_derive
#   checkpoint_latest      — alias for checkpoint_lookup

set -euo pipefail

# Derive WORKTREE_ID from PROJECT_DIR absolute path
# Returns 8-character hex hash for namespacing checkpoint tags per-worktree
# Args:
#   $1  PROJECT_DIR  — absolute path to project directory
# Returns:
#   8-character hex hash
worktree_id_derive() {
  local PROJECT_DIR="$1"
  echo "$PROJECT_DIR" | sha256sum | cut -c1-8
}

# Alias for internal consistency
checkpoint_worktree_id() {
  worktree_id_derive "$1"
}

# Create checkpoint tag and prune old ones
# Tag format: agent-checkpoint/<worktree-id>/<timestamp>
# Args:
#   $1  PROJECT_DIR  — absolute path to project directory
#   $2  TIMESTAMP    — SESSION_TS from start_agent.sh (YYYYMMDD-HHMMSS)
# Returns:
#   Prints the created tag name to stdout
checkpoint_create() {
  local PROJECT_DIR="$1"
  local TIMESTAMP="$2"
  local WORKTREE_ID
  WORKTREE_ID=$(worktree_id_derive "$PROJECT_DIR")
  local TAG="agent-checkpoint/${WORKTREE_ID}/${TIMESTAMP}"
  git -C "$PROJECT_DIR" tag "$TAG"
  checkpoint_prune "$PROJECT_DIR" 5 &> dev/null
  echo "$TAG"
}

# Prune old checkpoint tags
# Args:
#   $1  PROJECT_DIR  — absolute path to project directory
#   $2  KEEP         — number of tags to keep (default: 5)
# Prunes to KEEP most recent tags per worktree.
checkpoint_prune() {
  local PROJECT_DIR="$1"
  local KEEP="${2:-5}"
  local WORKTREE_ID
  WORKTREE_ID=$(worktree_id_derive "$PROJECT_DIR")
  git -C "$PROJECT_DIR" tag --list "agent-checkpoint/${WORKTREE_ID}/*" \
    | sort | head -n -"$KEEP" \
    | xargs -r git -C "$PROJECT_DIR" tag -d
}

# Look up latest checkpoint tag for this worktree
# Args:
#   $1  PROJECT_DIR  — absolute path to project directory
# Returns:
#   Prints the latest tag name to stdout, or empty string if none found
checkpoint_lookup() {
  local PROJECT_DIR="$1"
  local WORKTREE_ID
  WORKTREE_ID=$(worktree_id_derive "$PROJECT_DIR")
  git -C "$PROJECT_DIR" tag --list "agent-checkpoint/${WORKTREE_ID}/*" \
    | sort | tail -n 1
}

# Alias for internal consistency
checkpoint_latest() {
  checkpoint_lookup "$1"
}

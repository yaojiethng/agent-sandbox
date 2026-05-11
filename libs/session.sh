#!/usr/bin/env bash
# libs/session.sh
#
# Shared session infrastructure for workflow libraries.
# Sourced by workflow libs — not executed standalone.
#
# Depends on: git, standard shell utilities.

# validate_project_dir PROJECT_DIR
#   Checks PROJECT_DIR exists, is a git repository, and has at least one commit.
#   Returns 1 with error message to stderr on failure.
validate_project_dir() {
  local PROJECT_DIR="$1"

  if [[ ! -d "$PROJECT_DIR" ]]; then
    echo "Error: PROJECT_DIR does not exist: $PROJECT_DIR" >&2
    return 1
  fi

  if ! git -C "$PROJECT_DIR" rev-parse --git-dir >/dev/null 2>&1; then
    echo "Error: $PROJECT_DIR is not a git repository" >&2
    return 1
  fi

  if ! git -C "$PROJECT_DIR" rev-parse HEAD >/dev/null 2>&1; then
    echo "Error: $PROJECT_DIR has no commits - cannot apply patch" >&2
    return 1
  fi
}

# Check for and remove a stale .git/index.lock.
# On Windows/WSL (drvfs mounts), git operations can leave a stale lock file
# behind even when they succeed (antivirus scanning, delayed unlink).
# Removing it prevents cascading failures in subsequent git commands.
draft_clear_stale_lock() {
  local PROJECT_DIR="$1"
  local LOCKFILE="$PROJECT_DIR/.git/index.lock"
  if [[ -f "$LOCKFILE" ]]; then
    # Check if a git process is actively holding the lock.
    # On Linux: lsof is reliable. On Windows/MINGW64: check process list.
    local LOCK_HELD=false
    if command -v lsof >/dev/null 2>&1; then
      if lsof "$LOCKFILE" >/dev/null 2>&1; then
        LOCK_HELD=true
      fi
    fi
    if [[ "$LOCK_HELD" == true ]]; then
      echo "Error: .git/index.lock is held by another git process" >&2
      echo "  File: $LOCKFILE" >&2
      echo "  Ensure no other git process is running and retry." >&2
      return 1
    fi
    echo "Warning: removing stale .git/index.lock" >&2
    rm -f "$LOCKFILE"
  fi
}

# session_state_read SANDBOX_DIR KEY
#   Reads a key from the SESSION_STATE file at SANDBOX_DIR/.git/SESSION_STATE.
#   The file format is one key=value pair per line.
#   Prints the value to stdout, or empty string if the file or key is missing.
#   Args:
#     $1  SANDBOX_DIR  — path to sandbox directory
#     $2  KEY          — key to look up
session_state_read() {
  local SANDBOX_DIR="$1"
  local KEY="$2"
  local STATE_FILE="$SANDBOX_DIR/.git/SESSION_STATE"

  if [[ ! -f "$STATE_FILE" ]]; then
    return 0
  fi

  while IFS='=' read -r k v; do
    if [[ "$k" == "$KEY" ]]; then
      echo "$v"
      return 0
    fi
  done < "$STATE_FILE"
}

# session_state_write SANDBOX_DIR KEY VALUE
#   Writes a key=value pair to the SESSION_STATE file at SANDBOX_DIR/.git/SESSION_STATE.
#   Creates the file if it does not exist. Appends the pair on a new line.
#   Args:
#     $1  SANDBOX_DIR  — path to sandbox directory
#     $2  KEY          — key to write
#     $3  VALUE        — value to write
session_state_write() {
  local SANDBOX_DIR="$1"
  local KEY="$2"
  local VALUE="$3"
  local STATE_FILE="$SANDBOX_DIR/.git/SESSION_STATE"

  local DIR="$(dirname "$STATE_FILE")"
  if [[ ! -d "$DIR" ]]; then
    return 1
  fi

  echo "${KEY}=${VALUE}" >> "$STATE_FILE"
}



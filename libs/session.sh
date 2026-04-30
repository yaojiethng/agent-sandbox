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

# session_state_write SANDBOX_DIR KEY VALUE
#   Writes or updates a key in the SESSION_STATE file at SANDBOX_DIR/.git/SESSION_STATE.
#   The file format is one key=value pair per line.
#   If the key already exists, its value is updated; otherwise it is appended.
#   Args:
#     $1  SANDBOX_DIR  — path to sandbox directory
#     $2  KEY          — key to write
#     $3  VALUE        — value to write
session_state_write() {
  local SANDBOX_DIR="$1"
  local KEY="$2"
  local VALUE="$3"
  local STATE_FILE="$SANDBOX_DIR/.git/SESSION_STATE"

  if [[ ! -d "$SANDBOX_DIR/.git" ]]; then
    echo "session_state_write: $SANDBOX_DIR/.git does not exist" >&2
    return 1
  fi

  if [[ ! -f "$STATE_FILE" ]]; then
    echo "${KEY}=${VALUE}" > "$STATE_FILE"
    return 0
  fi

  local UPDATED=0
  local TMPFILE
  TMPFILE=$(mktemp)

  while IFS='=' read -r k v; do
    if [[ "$k" == "$KEY" ]]; then
      echo "${KEY}=${VALUE}" >> "$TMPFILE"
      UPDATED=1
    else
      echo "${k}=${v}" >> "$TMPFILE"
    fi
  done < "$STATE_FILE"

  if [[ "$UPDATED" -eq 0 ]]; then
    echo "${KEY}=${VALUE}" >> "$TMPFILE"
  fi

  mv "$TMPFILE" "$STATE_FILE"
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

# resolve_session_dir BASE_DIR SESSION_ARG REQUIRE_SUBPATH
#   Resolves a session directory from an explicit or auto-detected path.
#   Prints resolved absolute path to stdout.
#   Returns 1 with error message to stderr on failure.
#
#   SESSION_ARG behaviours:
#     - absolute path (starts with /): used as-is; BASE_DIR need not exist
#     - relative path: resolved under BASE_DIR; BASE_DIR must exist
#     - empty: auto-resolve to lexicographically last directory under BASE_DIR
#
#   REQUIRE_SUBPATH: if non-empty, the resolved directory must contain this
#   subpath (e.g. "session/patches").
resolve_session_dir() {
  local BASE_DIR="$1"
  local SESSION_ARG="$2"
  local REQUIRE_SUBPATH="$3"
  local RESOLVED=""

  if [[ -n "$SESSION_ARG" ]]; then
    if [[ "$SESSION_ARG" == /* ]]; then
      RESOLVED="$SESSION_ARG"
    else
      if [[ ! -d "$BASE_DIR" ]]; then
        echo "Error: base directory not found: $BASE_DIR" >&2
        return 1
      fi
      RESOLVED="$BASE_DIR/$SESSION_ARG"
    fi

    if [[ ! -d "$RESOLVED" ]]; then
      echo "Error: session path not found: $RESOLVED" >&2
      if [[ "$SESSION_ARG" != /* ]]; then
        echo "  Relative paths resolve under: $BASE_DIR" >&2
      fi
      return 1
    fi
  else
    # Auto-resolve: lexicographically last directory under BASE_DIR
    if [[ ! -d "$BASE_DIR" ]]; then
      echo "Error: base directory not found: $BASE_DIR" >&2
      return 1
    fi

    RESOLVED=$(find "$BASE_DIR" -mindepth 1 -maxdepth 1 -type d | sort | tail -n 1)
    if [[ -z "$RESOLVED" ]]; then
      echo "Error: no session directories found in $BASE_DIR" >&2
      return 1
    fi
  fi

  if [[ -n "$REQUIRE_SUBPATH" ]]; then
    if [[ ! -d "$RESOLVED/$REQUIRE_SUBPATH" ]]; then
      echo "Error: required subpath not found: $RESOLVED/$REQUIRE_SUBPATH" >&2
      return 1
    fi
  fi

  echo "$RESOLVED"
}

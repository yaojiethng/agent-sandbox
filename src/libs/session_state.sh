#!/usr/bin/env bash
# src/libs/session_state.sh
# Session state K/V store  --  reads and writes the SESSION_STATE file.
# Cross-context  --  deployed to both host and container.
# Uses self-resolution for sibling sourcing (_self_dir).
#
# Provides:
#   session_state_read    --  read a key from SESSION_STATE
#   session_state_write   --  write a key=value pair to SESSION_STATE

# session_state_read SANDBOX_DIR KEY
#   Reads a key from the SESSION_STATE file at SANDBOX_DIR/.git/SESSION_STATE.
#   The file format is one key=value pair per line.
#   Prints the value to stdout, or empty string if the file or key is missing.
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

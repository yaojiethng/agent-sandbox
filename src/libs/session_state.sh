#!/usr/bin/env bash
# src/libs/session_state.sh
# Session state K/V store  --  reads and writes the SESSION_STATE file.
# Cross-context  --  deployed to both host and container.
# Uses self-resolution for sibling sourcing (_self_dir).
#
# Provides:
#   session_state_read    --  read a key from SESSION_STATE
#   session_state_write   --  write a key=value pair to SESSION_STATE
#   session_state_write_set --  write the identity block (init_sha + identity)

_self_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_self_dir/interface_contract.sh"

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

  local DIR
  DIR="$(dirname "$STATE_FILE")"
  if [[ ! -d "$DIR" ]]; then
    return 1
  fi

  echo "${KEY}=${VALUE}" >> "$STATE_FILE"
}

# session_state_write_set SANDBOX_DIR INIT_SHA
#   Writes the SESSION_STATE identity block (init_sha + session identity).
#   Shared by the seed and mount init paths; the only difference between
#   the delivery modes is the init_sha source.
session_state_write_set() {
  local SANDBOX_DIR="$1"
  local INIT_SHA="$2"
  session_state_write "$SANDBOX_DIR" "init_sha"      "$INIT_SHA"
  session_state_write "$SANDBOX_DIR" "session_ts"    "${SESSION_TS:-}"
  session_state_write "$SANDBOX_DIR" "session_id"    "${SESSION_ID:-}"
  session_state_write "$SANDBOX_DIR" "host_head_sha" "${HOST_HEAD_SHA:-}"
  # Interface-contract version of the copy that wrote this record (ADR
  # interface_contract_compatibility.md); host-readable without starting.
  session_state_write "$SANDBOX_DIR" "interface_contract_version" "$(interface_contract_version)"
}

# init_sha_is_valid SANDBOX_DIR
#   Returns 0 iff SESSION_STATE's init_sha is present AND a real COMMIT object
#   in the sandbox repo. Returns 1 if the key is absent/empty or the value is
#   not a commit (bogus hex, or a ref to a non-commit object).
#   Uses `git cat-file -e ...^{commit}`, which verifies object existence and
#   type -- `rev-parse --verify` alone would accept any well-formed full-length
#   hex id without checking the object database.
init_sha_is_valid() {
  local SANDBOX_DIR="$1"
  local sha
  sha=$(session_state_read "$SANDBOX_DIR" "init_sha" 2>/dev/null) || return 1
  [[ -z "$sha" ]] && return 1
  git -C "$SANDBOX_DIR" cat-file -e "$sha^{commit}" >/dev/null 2>&1
}

#!/usr/bin/env bash
# libs/dirs.sh  --  Directory name defaults and path derivation for the
# agent-sandbox harness.
#
# Provides:
#   1. Default leaf names for all harness-managed directories (settable via env)
#   2. dirs_resolve  --  derive all harness paths from a base directory
#   3. lib_preflight  --  verify baked libraries, refuse a missing CRITICAL one
#   4. _source_lib  --  source a baked library with a stale-image diagnostic
#
# Both the capability layer and reasoning layer entrypoints source this file
# so that directory names have a single source of truth.
#
# Usage:
#   source /opt/sandbox/lib/dirs.sh
#   dirs_resolve "$BASE_DIR"
#   # Then use $CHANGES_DIR, $INPUT_DIR, $OUTPUT_DIR

# Working content directory: owned by the capability layer container.
# Exposed to the reasoning layer via --volumes-from, not a named volume.
# Lifecycle is tied to the capability layer container  --  if it is not
# running, the reasoning layer cannot attach to this directory.
SANDBOX_DIR_NAME="${SANDBOX_DIR_NAME:-sandbox}"

# Workspace subdirectory name. On the host this is a hidden directory
# (.workspace). Inside the container it is visible (workspace) because
# Docker bind mounts specify the target path directly. Override to
# "workspace" for container-side invocation.
WORKSPACE_DIR_NAME="${WORKSPACE_DIR_NAME:-.workspace}"

# Diff output leaf name under the workspace directory.
# The diff pipeline writes uncommitted.diff, all-changes.diff, patches/, and
# changed-files/ here and nowhere else.
CHANGES_DIR_NAME="${CHANGES_DIR_NAME:-session-diffs}"

# Reasoning layer input channel leaf name under the workspace directory.
INPUT_DIR_NAME="${INPUT_DIR_NAME:-input}"

# Reasoning layer output channel leaf name under the workspace directory.
OUTPUT_DIR_NAME="${OUTPUT_DIR_NAME:-output}"

# -------------------------
# dirs_resolve  --  derive all harness paths from a base directory.
#
# Sets CHANGES_DIR, INPUT_DIR, OUTPUT_DIR in the caller's scope
# and exports them for downstream consumers (compose, routing).
#
# Does NOT set SANDBOX_DIR  --  callers supply it explicitly (as CLI arg, ROOT
# convention, or via a separate derivation) because SANDBOX_DIR has different
# base semantics on host (it IS the base) vs container (it is derived from
# ROOT + SANDBOX_DIR_NAME).
#
# Args:
#   $1  BASE_DIR   --  root for derived paths
#                   Host: SANDBOX_DIR (e.g. /mnt/m/Projects/foo/.sandbox/win)
#                   Container: /home/agentuser
#
# Derivation:
#   CHANGES_DIR   = BASE_DIR / WORKSPACE_DIR_NAME / CHANGES_DIR_NAME
#   INPUT_DIR     = BASE_DIR / WORKSPACE_DIR_NAME / INPUT_DIR_NAME
#   OUTPUT_DIR    = BASE_DIR / WORKSPACE_DIR_NAME / OUTPUT_DIR_NAME
#
# Environment overrides (all optional, set before calling):
#   WORKSPACE_DIR_NAME, CHANGES_DIR_NAME,
#   INPUT_DIR_NAME, OUTPUT_DIR_NAME
#
# Examples:
#   # Host convention (default WORKSPACE_DIR_NAME=.workspace):
#   dirs_resolve "$SANDBOX_DIR"
#   # -> CHANGES_DIR  = /mnt/project/.sandbox/.workspace/session-diffs
#
#   # Container convention:
#   WORKSPACE_DIR_NAME=workspace dirs_resolve "/home/agentuser"
#   # -> CHANGES_DIR  = /home/agentuser/workspace/session-diffs
#   # -> INPUT_DIR    = /home/agentuser/workspace/input
#   # -> OUTPUT_DIR   = /home/agentuser/workspace/output
#   #
#   # INPUT_DIR and OUTPUT_DIR derive correctly in both contexts but are mounted
#   # only in the agent (reasoning layer) container, not the sandbox (capability
#   # layer) container.  See tool_interface.md  --  Mount Shape Guarantees.
# -------------------------
dirs_resolve() {
  local BASE_DIR="$1"
  if [[ -z "$BASE_DIR" ]]; then
    echo "dirs_resolve: BASE_DIR is required" >&2
    return 1
  fi

  local WS="${WORKSPACE_DIR_NAME:-.workspace}"

  export CHANGES_DIR="${BASE_DIR}/${WS}/${CHANGES_DIR_NAME:-session-diffs}"
  export INPUT_DIR="${BASE_DIR}/${WS}/${INPUT_DIR_NAME:-input}"
  export OUTPUT_DIR="${BASE_DIR}/${WS}/${OUTPUT_DIR_NAME:-output}"
}

# lib_preflight LIB_DIR "name.sh:SEVERITY" ...
#   Verifies that each baked library exists. Returns 1 when a CRITICAL file is
#   missing, after printing the stale-image remedy; a missing WARN file warns
#   and continues. Returns 1 rather than exiting, per the library rule in
#   bash-coding-conventions.md 3.1 -- both entrypoints run at top level under
#   `set -euo pipefail`, so the returned status aborts them identically.
lib_preflight() {
  local lib_dir="$1"
  shift
  local entry lib severity
  for entry in "$@"; do
    lib="${entry%%:*}"
    severity="${entry##*:}"
    if [[ ! -f "$lib_dir/$lib" ]]; then
      if [[ "$severity" == "CRITICAL" ]]; then
        echo "FATAL: $lib_dir/$lib is missing  --  image is stale, rebuild with 'make build'" >&2
        return 1
      else
        echo "WARN: $lib_dir/$lib is missing  --  image may be stale" >&2
      fi
    fi
  done
}

# _source_lib FILE
#   Sources a baked library, reporting a stale image by name when it is absent.
#   A bare source would abort with a raw bash error that names neither the lib
#   nor the remedy. Returns 1 when the file is missing, per the library rule in
#   bash-coding-conventions.md 3.1; callers at top level abort under `set -e`.
#   Only the entrypoints' own sources go through this: a library's sibling
#   sources rely on lib_preflight having already named a missing file.
_source_lib() {
  local _lib="$1"
  if [[ ! -f "$_lib" ]]; then
    echo "FATAL: $_lib is missing  --  image is stale, rebuild with 'make build'" >&2
    return 1
  fi
  # shellcheck disable=SC1090  # path is runtime-resolved and -f validated above
  source "$_lib"
}

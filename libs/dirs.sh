#!/usr/bin/env bash
# libs/dirs.sh — Directory name defaults and path derivation for the
# agent-sandbox harness.
#
# Provides:
#   1. Default leaf names for all harness-managed directories (settable via env)
#   2. dirs_resolve — derive all harness paths from a base directory
#
# Both the capability layer and reasoning layer entrypoints source this file
# so that directory names have a single source of truth.
#
# Usage:
#   source /opt/sandbox/lib/dirs.sh
#   dirs_resolve "$BASE_DIR"
#   # Then use $SNAPSHOT_DIR, $CHANGES_DIR, $INPUT_DIR, $OUTPUT_DIR

# Snapshot input: bind-mounted read-only into the capability layer container.
SNAPSHOT_DIR_NAME="${SNAPSHOT_DIR_NAME:-.snapshot}"

# Working content directory: owned by the capability layer container.
# Exposed to the reasoning layer via --volumes-from, not a named volume.
# Lifecycle is tied to the capability layer container — if it is not
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
# dirs_resolve — derive all harness paths from a base directory.
#
# Sets SNAPSHOT_DIR, CHANGES_DIR, INPUT_DIR, OUTPUT_DIR in the caller's scope
# and exports them for downstream consumers (compose, routing).
#
# Does NOT set SANDBOX_DIR — callers supply it explicitly (as CLI arg, ROOT
# convention, or via a separate derivation) because SANDBOX_DIR has different
# base semantics on host (it IS the base) vs container (it is derived from
# ROOT + SANDBOX_DIR_NAME).
#
# Args:
#   $1  BASE_DIR  — root for derived paths
#                   Host: SANDBOX_DIR (e.g. /mnt/m/Projects/foo/.sandbox/win)
#                   Container: /home/agentuser
#
# Derivation:
#   SNAPSHOT_DIR  = BASE_DIR / SNAPSHOT_DIR_NAME
#   CHANGES_DIR   = BASE_DIR / WORKSPACE_DIR_NAME / CHANGES_DIR_NAME
#   INPUT_DIR     = BASE_DIR / WORKSPACE_DIR_NAME / INPUT_DIR_NAME
#   OUTPUT_DIR    = BASE_DIR / WORKSPACE_DIR_NAME / OUTPUT_DIR_NAME
#
# Environment overrides (all optional, set before calling):
#   SNAPSHOT_DIR_NAME, WORKSPACE_DIR_NAME, CHANGES_DIR_NAME,
#   INPUT_DIR_NAME, OUTPUT_DIR_NAME
#
# Examples:
#   # Host convention (default WORKSPACE_DIR_NAME=.workspace):
#   dirs_resolve "$SANDBOX_DIR"
#   # → SNAPSHOT_DIR = /mnt/project/.sandbox/.snapshot
#   # → CHANGES_DIR  = /mnt/project/.sandbox/.workspace/session-diffs
#
#   # Container convention:
#   WORKSPACE_DIR_NAME=workspace dirs_resolve "/home/agentuser"
#   # → SNAPSHOT_DIR = /home/agentuser/.snapshot
#   # → CHANGES_DIR  = /home/agentuser/workspace/session-diffs
# -------------------------
dirs_resolve() {
  local BASE_DIR="$1"
  if [[ -z "$BASE_DIR" ]]; then
    echo "dirs_resolve: BASE_DIR is required" >&2
    return 1
  fi

  local WS="${WORKSPACE_DIR_NAME:-.workspace}"

  export SNAPSHOT_DIR="${BASE_DIR}/${SNAPSHOT_DIR_NAME:-.snapshot}"
  export CHANGES_DIR="${BASE_DIR}/${WS}/${CHANGES_DIR_NAME:-session-diffs}"
  export INPUT_DIR="${BASE_DIR}/${WS}/${INPUT_DIR_NAME:-input}"
  export OUTPUT_DIR="${BASE_DIR}/${WS}/${OUTPUT_DIR_NAME:-output}"
}

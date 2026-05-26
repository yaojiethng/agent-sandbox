#!/usr/bin/env bash
# tests/knowledge/knowledge_session_diffs_path_resolution.sh
#
# Knowledge test: trace and validate the session-diffs path resolution
# chain across host and container contexts.
#
# This documents the behavioural assumptions about how dirs.sh resolves
# CHANGES_DIR and how the compose template and entrypoints set overrides.
#
# The bug: compose template sets CHANGES_DIR_NAME=workspace/session-diffs
# (a full subpath), but dirs.sh prepends WORKSPACE_DIR_NAME. Inside the
# sandbox container with WORKSPACE_DIR_NAME=workspace, this produces:
#
#   CHANGES_DIR = /home/agentuser/workspace/workspace/session-diffs
#
# The compose bind mount target is /home/agentuser/workspace/session-diffs.
# Diffs land at the doubled path and never survive to the host.
#
# Run:
#   bash tests/knowledge/knowledge_session_diffs_path_resolution.sh
#
# Exit 0 = all assumptions confirmed.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../libs/test_common.sh"
DIRS_LIB="$SCRIPT_DIR/../../libs/dirs.sh"

# -------------------------
# Test 1: Default host-side resolution
# -------------------------
echo "[ Test 1: Default host-side resolution ]"
test_default_host() {
  local tmpdir; tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' RETURN

  unset WORKSPACE_DIR_NAME CHANGES_DIR_NAME
  source "$DIRS_LIB"
  dirs_resolve "$tmpdir"

  if [[ "$CHANGES_DIR" == "$tmpdir/.workspace/session-diffs" ]]; then
    pass "host-side CHANGES_DIR = $tmpdir/.workspace/session-diffs"
  else
    fail "expected $tmpdir/.workspace/session-diffs, got $CHANGES_DIR"
  fi

  if [[ "$WORKSPACE_DIR_NAME" == ".workspace" ]]; then
    pass "host-side WORKSPACE_DIR_NAME = .workspace (default)"
  else
    fail "expected WORKSPACE_DIR_NAME=.workspace, got $WORKSPACE_DIR_NAME"
  fi
}
test_default_host

# -------------------------
# Test 2: Container-side resolution (WORKSPACE_DIR_NAME=workspace, default CHANGES_DIR_NAME)
# -------------------------
echo "[ Test 2: Container-like resolution (workspace, default CHANGES_DIR_NAME) ]"
test_container_default_changes() {
  local tmpdir; tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' RETURN

  unset CHANGES_DIR_NAME
  WORKSPACE_DIR_NAME=workspace
  source "$DIRS_LIB"
  dirs_resolve "$tmpdir"

  local expected="$tmpdir/workspace/session-diffs"
  if [[ "$CHANGES_DIR" == "$expected" ]]; then
    pass "container-side CHANGES_DIR = $expected"
  else
    fail "expected $expected, got $CHANGES_DIR"
  fi
}
test_container_default_changes

# -------------------------
# Test 3: Bug reproduction — compose env sets CHANGES_DIR_NAME=workspace/session-diffs
#         with WORKSPACE_DIR_NAME=workspace → doubled path
# -------------------------
echo "[ Test 3: Bug reproduction — doubled path from compose env ]"
test_bug_doubled_path() {
  local tmpdir; tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' RETURN

  # This is what the compose template sets as an env var:
  CHANGES_DIR_NAME=workspace/session-diffs
  WORKSPACE_DIR_NAME=workspace
  source "$DIRS_LIB"
  dirs_resolve "$tmpdir"

  local expected="$tmpdir/workspace/workspace/session-diffs"
  if [[ "$CHANGES_DIR" == "$expected" ]]; then
    pass "BUG CONFIRMED: CHANGES_DIR = $expected (doubled workspace/)"
  else
    fail "BUG VARIANT: expected $expected, got $CHANGES_DIR"
  fi
}
test_bug_doubled_path

# -------------------------
# Test 4: Fix — compose env sets CHANGES_DIR_NAME=session-diffs (just the leaf)
#         with WORKSPACE_DIR_NAME=workspace → correct path
# -------------------------
echo "[ Test 4: Fix — leaf-only CHANGES_DIR_NAME ]"
test_fix_leaf_only() {
  local tmpdir; tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' RETURN

  # Fix: use just the leaf name, not the full subpath
  CHANGES_DIR_NAME=session-diffs
  WORKSPACE_DIR_NAME=workspace
  source "$DIRS_LIB"
  dirs_resolve "$tmpdir"

  local expected="$tmpdir/workspace/session-diffs"
  if [[ "$CHANGES_DIR" == "$expected" ]]; then
    pass "FIX CONFIRMED: CHANGES_DIR = $expected (correct)"
  else
    fail "expected $expected, got $CHANGES_DIR"
  fi
}
test_fix_leaf_only

# -------------------------
# Test 5: Verify the compose template's env var + mount target
# -------------------------
echo "[ Test 5: Compose bind mount target vs dirs.sh resolution ]"
test_compose_mount_target() {
  local tmpdir; tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' RETURN

  # Simulate the compose template's mount target path as specified in docker-compose.yml
  local compose_mount_target="/home/agentuser/workspace/session-diffs"

  # Simulate what sandbox-entrypoint resolves (the buggy path)
  CHANGES_DIR_NAME=workspace/session-diffs
  WORKSPACE_DIR_NAME=workspace
  source "$DIRS_LIB"
  dirs_resolve "/home/agentuser"

  if [[ "$CHANGES_DIR" != "$compose_mount_target" ]]; then
    pass "MISMATCH CONFIRMED: container writes to $CHANGES_DIR, mount target is $compose_mount_target"
  else
    fail "PATHS MATCH — bug may already be fixed: $CHANGES_DIR == $compose_mount_target"
  fi
}
test_compose_mount_target

# -------------------------
# Test 6: The route libs/dirs.sh logic — verify CHANGES_DIR leaf logic
# -------------------------
echo "[ Test 6: CHANGES_DIR_NAME semantics — leaf only, not subpath ]"
test_changes_dir_name_leaf() {
  local tmpdir; tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' RETURN

  # Confirm the variable name encodes the intent: it's a NAME (leaf), not a PATH
  unset CHANGES_DIR_NAME WORKSPACE_DIR_NAME
  source "$DIRS_LIB"

  if [[ "${CHANGES_DIR_NAME:-session-diffs}" == */* ]]; then
    fail "CHANGES_DIR_NAME contains '/' — should be a leaf name, not a subpath"
  else
    pass "CHANGES_DIR_NAME is a leaf name (no '/'): ${CHANGES_DIR_NAME:-session-diffs}"
  fi
}
test_changes_dir_name_leaf

# -------------------------
# Summary
# -------------------------
echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]

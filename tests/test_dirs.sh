#!/usr/bin/env bash
# Tests for libs/dirs.sh — dirs_resolve function.
#
# Covers:
#   dirs_resolve host convention  — default WORKSPACE_DIR_NAME (.workspace)
#   dirs_resolve container conv   — WORKSPACE_DIR_NAME=workspace
#   dirs_resolve empty base fails — error handling
#   dirs_resolve env overrides    — custom _DIR_NAME overrides respected

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$REPO_ROOT/src/libs/dirs.sh"
source "$SCRIPT_DIR/libs/test_common.sh"

# =============================================================================
# dirs_resolve — host convention (default WORKSPACE_DIR_NAME=.workspace)
# =============================================================================

test_dirs_resolve_host_snapshot() {
  unset WORKSPACE_DIR_NAME SNAPSHOT_DIR CHANGES_DIR INPUT_DIR OUTPUT_DIR
  unset INPUT_DIR_NAME OUTPUT_DIR_NAME CHANGES_DIR_NAME SNAPSHOT_DIR_NAME SANDBOX_DIR_NAME
  dirs_resolve "/mnt/project/.sandbox"
  if [[ "$SNAPSHOT_DIR" == "/mnt/project/.sandbox/.snapshot" ]]; then
    pass "host: SNAPSHOT_DIR derives correctly"
  else
    fail "host: SNAPSHOT_DIR: expected /mnt/project/.sandbox/.snapshot, got $SNAPSHOT_DIR"
  fi
}

test_dirs_resolve_host_changes() {
  unset WORKSPACE_DIR_NAME SNAPSHOT_DIR CHANGES_DIR INPUT_DIR OUTPUT_DIR
  unset INPUT_DIR_NAME OUTPUT_DIR_NAME CHANGES_DIR_NAME SNAPSHOT_DIR_NAME SANDBOX_DIR_NAME
  dirs_resolve "/mnt/project/.sandbox"
  if [[ "$CHANGES_DIR" == "/mnt/project/.sandbox/.workspace/session-diffs" ]]; then
    pass "host: CHANGES_DIR derives correctly"
  else
    fail "host: CHANGES_DIR: expected /mnt/project/.sandbox/.workspace/session-diffs, got $CHANGES_DIR"
  fi
}

test_dirs_resolve_host_input() {
  unset WORKSPACE_DIR_NAME SNAPSHOT_DIR CHANGES_DIR INPUT_DIR OUTPUT_DIR
  unset INPUT_DIR_NAME OUTPUT_DIR_NAME CHANGES_DIR_NAME SNAPSHOT_DIR_NAME SANDBOX_DIR_NAME
  dirs_resolve "/mnt/project/.sandbox"
  if [[ "$INPUT_DIR" == "/mnt/project/.sandbox/.workspace/input" ]]; then
    pass "host: INPUT_DIR derives correctly"
  else
    fail "host: INPUT_DIR: expected /mnt/project/.sandbox/.workspace/input, got $INPUT_DIR"
  fi
}

test_dirs_resolve_host_output() {
  unset WORKSPACE_DIR_NAME SNAPSHOT_DIR CHANGES_DIR INPUT_DIR OUTPUT_DIR
  unset INPUT_DIR_NAME OUTPUT_DIR_NAME CHANGES_DIR_NAME SNAPSHOT_DIR_NAME SANDBOX_DIR_NAME
  dirs_resolve "/mnt/project/.sandbox"
  if [[ "$OUTPUT_DIR" == "/mnt/project/.sandbox/.workspace/output" ]]; then
    pass "host: OUTPUT_DIR derives correctly"
  else
    fail "host: OUTPUT_DIR: expected /mnt/project/.sandbox/.workspace/output, got $OUTPUT_DIR"
  fi
}

# =============================================================================
# dirs_resolve — container convention (WORKSPACE_DIR_NAME=workspace)
# =============================================================================

test_dirs_resolve_container_snapshot() {
  unset WORKSPACE_DIR_NAME SNAPSHOT_DIR CHANGES_DIR INPUT_DIR OUTPUT_DIR
  unset INPUT_DIR_NAME OUTPUT_DIR_NAME CHANGES_DIR_NAME SNAPSHOT_DIR_NAME SANDBOX_DIR_NAME
  WORKSPACE_DIR_NAME=workspace dirs_resolve "/home/agentuser"
  if [[ "$SNAPSHOT_DIR" == "/home/agentuser/.snapshot" ]]; then
    pass "container: SNAPSHOT_DIR derives correctly"
  else
    fail "container: SNAPSHOT_DIR: expected /home/agentuser/.snapshot, got $SNAPSHOT_DIR"
  fi
}

test_dirs_resolve_container_changes() {
  unset WORKSPACE_DIR_NAME SNAPSHOT_DIR CHANGES_DIR INPUT_DIR OUTPUT_DIR
  unset INPUT_DIR_NAME OUTPUT_DIR_NAME CHANGES_DIR_NAME SNAPSHOT_DIR_NAME SANDBOX_DIR_NAME
  WORKSPACE_DIR_NAME=workspace dirs_resolve "/home/agentuser"
  if [[ "$CHANGES_DIR" == "/home/agentuser/workspace/session-diffs" ]]; then
    pass "container: CHANGES_DIR derives correctly"
  else
    fail "container: CHANGES_DIR: expected /home/agentuser/workspace/session-diffs, got $CHANGES_DIR"
  fi
}

test_dirs_resolve_container_input() {
  unset WORKSPACE_DIR_NAME SNAPSHOT_DIR CHANGES_DIR INPUT_DIR OUTPUT_DIR
  unset INPUT_DIR_NAME OUTPUT_DIR_NAME CHANGES_DIR_NAME SNAPSHOT_DIR_NAME SANDBOX_DIR_NAME
  WORKSPACE_DIR_NAME=workspace dirs_resolve "/home/agentuser"
  if [[ "$INPUT_DIR" == "/home/agentuser/workspace/input" ]]; then
    pass "container: INPUT_DIR derives correctly"
  else
    fail "container: INPUT_DIR: expected /home/agentuser/workspace/input, got $INPUT_DIR"
  fi
}

test_dirs_resolve_container_output() {
  unset WORKSPACE_DIR_NAME SNAPSHOT_DIR CHANGES_DIR INPUT_DIR OUTPUT_DIR
  unset INPUT_DIR_NAME OUTPUT_DIR_NAME CHANGES_DIR_NAME SNAPSHOT_DIR_NAME SANDBOX_DIR_NAME
  WORKSPACE_DIR_NAME=workspace dirs_resolve "/home/agentuser"
  if [[ "$OUTPUT_DIR" == "/home/agentuser/workspace/output" ]]; then
    pass "container: OUTPUT_DIR derives correctly"
  else
    fail "container: OUTPUT_DIR: expected /home/agentuser/workspace/output, got $OUTPUT_DIR"
  fi
}

# =============================================================================
# dirs_resolve — empty base dir fails
# =============================================================================

test_dirs_resolve_empty_base_fails() {
  unset WORKSPACE_DIR_NAME SNAPSHOT_DIR CHANGES_DIR INPUT_DIR OUTPUT_DIR
  unset INPUT_DIR_NAME OUTPUT_DIR_NAME CHANGES_DIR_NAME SNAPSHOT_DIR_NAME SANDBOX_DIR_NAME
  if dirs_resolve "" 2>/dev/null; then
    fail "empty BASE_DIR: expected non-zero exit"
  else
    pass "empty BASE_DIR: returns non-zero"
  fi
}

# =============================================================================
# dirs_resolve — env overrides respected
# =============================================================================

test_dirs_resolve_snapshot_dir_name_override() {
  unset WORKSPACE_DIR_NAME SNAPSHOT_DIR CHANGES_DIR INPUT_DIR OUTPUT_DIR
  unset INPUT_DIR_NAME OUTPUT_DIR_NAME CHANGES_DIR_NAME SNAPSHOT_DIR_NAME SANDBOX_DIR_NAME
  SNAPSHOT_DIR_NAME=checkpoints dirs_resolve "/base"
  if [[ "$SNAPSHOT_DIR" == "/base/checkpoints" ]]; then
    pass "SNAPSHOT_DIR_NAME override works"
  else
    fail "SNAPSHOT_DIR_NAME: expected /base/checkpoints, got $SNAPSHOT_DIR"
  fi
}

test_dirs_resolve_changes_dir_name_override() {
  unset WORKSPACE_DIR_NAME SNAPSHOT_DIR CHANGES_DIR INPUT_DIR OUTPUT_DIR
  unset INPUT_DIR_NAME OUTPUT_DIR_NAME CHANGES_DIR_NAME SNAPSHOT_DIR_NAME SANDBOX_DIR_NAME
  CHANGES_DIR_NAME=diffs dirs_resolve "/base"
  if [[ "$CHANGES_DIR" == "/base/.workspace/diffs" ]]; then
    pass "CHANGES_DIR_NAME override works"
  else
    fail "CHANGES_DIR_NAME: expected /base/.workspace/diffs, got $CHANGES_DIR"
  fi
}

# =============================================================================
# Run
# =============================================================================

run_test test_dirs_resolve_host_snapshot
run_test test_dirs_resolve_host_changes
run_test test_dirs_resolve_host_input
run_test test_dirs_resolve_host_output
run_test test_dirs_resolve_container_snapshot
run_test test_dirs_resolve_container_changes
run_test test_dirs_resolve_container_input
run_test test_dirs_resolve_container_output
run_test test_dirs_resolve_empty_base_fails
run_test test_dirs_resolve_snapshot_dir_name_override
run_test test_dirs_resolve_changes_dir_name_override

test_done "dirs.sh"

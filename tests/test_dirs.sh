#!/usr/bin/env bash
# tests/test_dirs.sh  --  Unit tests for src/libs/dirs.sh path derivation.
#
# dirs_resolve is a maintained internal seam with a stable API (env-overridable
# defaults + BASE_DIR argument). These unit tests assert the contract directly
# and run under `make test` (previously only covered by a broken manual
# knowledge test that sourced a nonexistent libs/dirs.sh path).
#
# Run:
#   bash tests/test_dirs.sh

# shellcheck disable=SC2034  # env vars (WORKSPACE_DIR_NAME, CHANGES_DIR_NAME, ...) are consumed by dirs_resolve in the sourced src/libs/dirs.sh; shellcheck cannot see cross-file reads
set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup
source "$REPO_ROOT/src/libs/dirs.sh"


# Each test runs dirs_resolve in a subshell so exported vars do not leak.

test_requires_base_dir() {
  if (dirs_resolve "" 2>/dev/null); then
    fail "dirs_resolve should fail without BASE_DIR"
  else
    pass "dirs_resolve fails without BASE_DIR"
  fi
}

test_host_default_paths() {
  local OUT
  OUT=$(
    unset SNAPSHOT_DIR_NAME WORKSPACE_DIR_NAME CHANGES_DIR_NAME INPUT_DIR_NAME OUTPUT_DIR_NAME
    dirs_resolve "/srv/sandbox"
    echo "$SNAPSHOT_DIR|$CHANGES_DIR|$INPUT_DIR|$OUTPUT_DIR"
  )
  local exp="/srv/sandbox/.snapshot|/srv/sandbox/.workspace/session-diffs|/srv/sandbox/.workspace/input|/srv/sandbox/.workspace/output"
  if [[ "$OUT" == "$exp" ]]; then
    pass "host default: CHANGES_DIR/INPUT/OUTPUT under .workspace, SNAPSHOT under base"
  else
    fail "host default mismatch: got $OUT, want $exp"
  fi
}

test_container_override() {
  local OUT
  OUT=$(
    WORKSPACE_DIR_NAME=workspace
    dirs_resolve "/home/agentuser"
    echo "$SNAPSHOT_DIR|$CHANGES_DIR|$INPUT_DIR|$OUTPUT_DIR"
  )
  local exp="/home/agentuser/.snapshot|/home/agentuser/workspace/session-diffs|/home/agentuser/workspace/input|/home/agentuser/workspace/output"
  if [[ "$OUT" == "$exp" ]]; then
    pass "container override: WORKSPACE_DIR_NAME=workspace yields correct paths"
  else
    fail "container override mismatch: got $OUT, want $exp"
  fi
}

test_changes_dir_name_is_leaf() {
  # CHANGES_DIR_NAME is a leaf name; a slash-bearing value is a misconfiguration
  # that would double the subpath (the historical bug this suite guards against).
  local OUT
  OUT=$(
    WORKSPACE_DIR_NAME=workspace
    CHANGES_DIR_NAME="workspace/session-diffs"
    dirs_resolve "/home/agentuser"
    echo "$CHANGES_DIR"
  )
  if [[ "$OUT" == "/home/agentuser/workspace/workspace/session-diffs" ]]; then
    pass "leaf-enforcement: slash-bearing CHANGES_DIR_NAME is caught as doubled path"
  else
    fail "leaf-enforcement mismatch: got $OUT"
  fi
}

test_custom_leaf_overrides() {
  local OUT
  OUT=$(
    CHANGES_DIR_NAME="diffs"
    INPUT_DIR_NAME="in"
    OUTPUT_DIR_NAME="out"
    dirs_resolve "/base"
    echo "$CHANGES_DIR|$INPUT_DIR|$OUTPUT_DIR"
  )
  if [[ "$OUT" == "/base/.workspace/diffs|/base/.workspace/in|/base/.workspace/out" ]]; then
    pass "custom leaf names override defaults"
  else
    fail "custom leaf mismatch: got $OUT"
  fi
}

test_snapshot_dir_name_override() {
  local OUT
  OUT=$(
    SNAPSHOT_DIR_NAME="snap"
    dirs_resolve "/base"
    echo "$SNAPSHOT_DIR"
  )
  if [[ "$OUT" == "/base/snap" ]]; then
    pass "SNAPSHOT_DIR_NAME env override respected"
  else
    fail "snapshot override mismatch: got $OUT"
  fi
}

run_test test_requires_base_dir
run_test test_host_default_paths
run_test test_container_override
run_test test_changes_dir_name_is_leaf
run_test test_custom_leaf_overrides
run_test test_snapshot_dir_name_override

echo ""
echo "Results: $PASS passed, $FAIL failed, $SKIP skipped"
[[ "$FAIL" -eq 0 ]]

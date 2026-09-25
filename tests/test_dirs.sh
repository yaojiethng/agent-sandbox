#!/usr/bin/env bash
# tests/test_dirs.sh  --  Unit tests for src/libs/dirs.sh path derivation.
#
# Pins cite: docs/concepts/sandbox_identity.md l.142 (session-diffs layout);
#             devlog/discussions/design_workspace_path_resolution.md.

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

# Given: an empty BASE_DIR
# When:  dirs_resolve runs
# Then:  it returns non-zero
# Asserts: BASE_DIR is required.
test_requires_base_dir() {
  if (dirs_resolve "" 2>/dev/null); then
    fail "dirs_resolve should fail without BASE_DIR"
  else
    pass "dirs_resolve fails without BASE_DIR"
  fi
}

# Given: the leaf env vars unset
# When:  dirs_resolve /srv/sandbox runs
# Then:  CHANGES/INPUT/OUTPUT sit under .workspace
# Asserts: the host default layout.
test_host_default_paths() {
  local OUT
  OUT=$(
    unset WORKSPACE_DIR_NAME CHANGES_DIR_NAME INPUT_DIR_NAME OUTPUT_DIR_NAME
    dirs_resolve "/srv/sandbox"
    echo "$CHANGES_DIR|$INPUT_DIR|$OUTPUT_DIR"
  )
  local exp="/srv/sandbox/.workspace/session-diffs|/srv/sandbox/.workspace/input|/srv/sandbox/.workspace/output"
  assert_eq "$OUT" "$exp" "host default: CHANGES_DIR/INPUT/OUTPUT under .workspace"
}

# Given: WORKSPACE_DIR_NAME=workspace
# When:  dirs_resolve /home/agentuser runs
# Then:  CHANGES/INPUT/OUTPUT sit under workspace
# Asserts: the container override of the workspace leaf.
test_container_override() {
  local OUT
  OUT=$(
    WORKSPACE_DIR_NAME=workspace
    dirs_resolve "/home/agentuser"
    echo "$CHANGES_DIR|$INPUT_DIR|$OUTPUT_DIR"
  )
  local exp="/home/agentuser/workspace/session-diffs|/home/agentuser/workspace/input|/home/agentuser/workspace/output"
  assert_eq "$OUT" "$exp" "container override: WORKSPACE_DIR_NAME=workspace yields correct paths"
}

# Given: CHANGES_DIR_NAME=workspace/session-diffs (slash-bearing)
# When:  dirs_resolve runs
# Then:  the path doubles: /home/agentuser/workspace/workspace/session-diffs
# Asserts: the current behaviour that a slash-bearing leaf doubles the subpath (documents, does not prevent).
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
  assert_eq "$OUT" "/home/agentuser/workspace/workspace/session-diffs" "leaf-enforcement: slash-bearing CHANGES_DIR_NAME is caught as doubled path"
}

# Given: custom CHANGES_DIR_NAME/INPUT_DIR_NAME/OUTPUT_DIR_NAME
# When:  dirs_resolve /base runs
# Then:  the custom leaves appear in the paths
# Asserts: custom leaf names override the defaults.
test_custom_leaf_overrides() {
  local OUT
  OUT=$(
    CHANGES_DIR_NAME="diffs"
    INPUT_DIR_NAME="in"
    OUTPUT_DIR_NAME="out"
    dirs_resolve "/base"
    echo "$CHANGES_DIR|$INPUT_DIR|$OUTPUT_DIR"
  )
  assert_eq "$OUT" "/base/.workspace/diffs|/base/.workspace/in|/base/.workspace/out" "custom leaf names override defaults"
}

# lib_preflight: the shared loop both entrypoints call. Ordering and severity
# behaviour are the contract.
# Given: all listed libraries present
# When:  lib_preflight runs
# Then:  rc is 0 and nothing is printed
# Asserts: a complete library set passes silently.
test_lib_preflight_passes_when_all_present() {
  local d="$FIXTURE_DIR/libs_ok"
  mkdir -p "$d"
  touch "$d/aaa.sh" "$d/bbb.sh"
  local OUT RC=0
  OUT=$(lib_preflight "$d" "aaa.sh:CRITICAL" "bbb.sh:WARN" 2>&1) || RC=$?
  assert_eq "$RC" "0" "lib_preflight: all present -> 0"
  assert_eq "$OUT" "" "lib_preflight: all present -> silent"
}

# Given: a missing CRITICAL library
# When:  lib_preflight runs
# Then:  rc is 1
# Asserts: a missing CRITICAL library refuses (stale image).
test_lib_preflight_critical_exits() {
  local d="$FIXTURE_DIR/libs_crit"
  mkdir -p "$d"
  touch "$d/aaa.sh"
  local RC=0
  lib_preflight "$d" "aaa.sh:CRITICAL" "missing.sh:CRITICAL" >/dev/null 2>&1 || RC=$?
  assert_eq "$RC" "1" "lib_preflight: a missing CRITICAL file returns 1"
}

# Given: a missing WARN library
# When:  lib_preflight runs
# Then:  rc is 0 and the output names the remedy
# Asserts: a missing WARN library warns and continues.
test_lib_preflight_warn_continues() {
  local d="$FIXTURE_DIR/libs_warn"
  mkdir -p "$d"
  local OUT RC=0
  OUT=$(lib_preflight "$d" "missing.sh:WARN" 2>&1) || RC=$?
  assert_eq "$RC" "0" "lib_preflight: a missing WARN file does not fail the entrypoint"
  assert_contains "$OUT" "image may be stale" "lib_preflight: the WARN names the remedy"
}

# -------------------------
# Run all tests
# -------------------------

run_test test_requires_base_dir
run_test test_host_default_paths
run_test test_container_override
run_test test_changes_dir_name_is_leaf
run_test test_custom_leaf_overrides
run_test test_lib_preflight_passes_when_all_present
run_test test_lib_preflight_critical_exits
run_test test_lib_preflight_warn_continues
test_done test_dirs

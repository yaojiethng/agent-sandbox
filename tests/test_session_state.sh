#!/usr/bin/env bash
# tests/test_session_state.sh
# Unit tests for src/libs/session_state.sh  --  the SESSION_STATE key-value record.
#
# Covers:
#   session_state_read        --  key-value lookup from SESSION_STATE
#
# The write path (`session_state_write`, `session_state_write_set`) is exercised
# by the capability suites whose fixtures run the shipped entrypoint and seeder
# (tests/test_capability_entrypoint_mount.sh, tests/test_seed_volume.sh).
#
# Note: resolve_session_dir was removed in A.2  --  routing concerns moved
# to libs/routing.sh (tested in test_routing.sh).

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup
source "$REPO_ROOT/src/libs/session_state.sh"
source "$REPO_ROOT/scripts/guards.sh"


# validate_project_dir's units live in tests/test_guards.sh

# =============================================================================
# session_state_read
# =============================================================================

# Given: a SESSION_STATE holding init_sha and session_ts
# When:  session_state_read asks for init_sha
# Then:  it returns the recorded value
# Asserts: the key lookup.
test_session_state_read_existing_key() {
  local DIR="$FIXTURE_DIR/state_existing"
  mkdir -p "$DIR/.git"
  echo "init_sha=abc123" > "$DIR/.git/SESSION_STATE"
  echo "session_ts=20260401-120000" >> "$DIR/.git/SESSION_STATE"

  local RESULT
  RESULT=$(session_state_read "$DIR" "init_sha")
  assert_eq "$RESULT" "abc123" "session_state_read returns value for existing key"
}

# Given: no SESSION_STATE file
# When:  session_state_read asks for init_sha
# Then:  it returns empty
# Asserts: a missing record is not an error.
test_session_state_read_missing_file() {
  local DIR="$FIXTURE_DIR/state_nofile"
  mkdir -p "$DIR/.git"

  local RESULT
  RESULT=$(session_state_read "$DIR" "init_sha")
  assert_empty "$RESULT" "session_state_read returns empty for missing file"
}

# Given: a SESSION_STATE without the requested key
# When:  session_state_read asks for init_sha
# Then:  it returns empty
# Asserts: an absent key yields no value, not another key's.
test_session_state_read_missing_key() {
  local DIR="$FIXTURE_DIR/state_nokey"
  mkdir -p "$DIR/.git"
  echo "other_key=value" > "$DIR/.git/SESSION_STATE"

  local RESULT
  RESULT=$(session_state_read "$DIR" "init_sha")
  assert_empty "$RESULT" "session_state_read returns empty for missing key"
}

# Given: a SESSION_STATE whose line is not key=value
# When:  session_state_read asks for init_sha
# Then:  it returns empty
# Asserts: a malformed line is ignored (see finding 42).
test_session_state_read_malformed() {
  local DIR="$FIXTURE_DIR/state_malformed"
  mkdir -p "$DIR/.git"
  echo "not-a-key-value-pair" > "$DIR/.git/SESSION_STATE"

  local RESULT
  RESULT=$(session_state_read "$DIR" "init_sha")
  assert_empty "$RESULT" "session_state_read handles malformed file gracefully"
}

# =============================================================================
# Run
# =============================================================================

run_test test_session_state_read_existing_key
run_test test_session_state_read_missing_file
run_test test_session_state_read_missing_key
run_test test_session_state_read_malformed

test_done test_session_state.sh

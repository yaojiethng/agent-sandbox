#!/usr/bin/env bash
# tests/test_session.sh
# Tests for libs/session.sh
#
# Covers:
#   validate_project_dir     — checks existence, git repo, commits
#   session_state_read       — key-value lookup from SESSION_STATE
#   session_state_write      — key-value append to SESSION_STATE
#
# Note: resolve_session_dir was removed in A.2 — routing concerns moved
# to libs/routing.sh (tested in test_routing.sh).

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup
source "$REPO_ROOT/src/libs/session_state.sh"
source "$REPO_ROOT/scripts/guards.sh"


# =============================================================================
# validate_project_dir
# =============================================================================

test_validate_project_dir_missing() {
  if validate_project_dir "/nonexistent/path" 2>/dev/null; then
    fail "validate_project_dir should fail for non-existent dir"
  else
    pass "validate_project_dir fails for non-existent dir"
  fi
}

test_validate_project_dir_not_git() {
  local DIR="$FIXTURE_DIR/not_git"
  mkdir -p "$DIR"

  if validate_project_dir "$DIR" 2>/dev/null; then
    fail "validate_project_dir should fail for non-git dir"
  else
    pass "validate_project_dir fails for non-git dir"
  fi
}

test_validate_project_dir_no_commits() {
  local DIR="$FIXTURE_DIR/no_commits"
  mkdir -p "$DIR"
  git -C "$DIR" init --quiet 2>/dev/null

  if validate_project_dir "$DIR" 2>/dev/null; then
    fail "validate_project_dir should fail for repo with no commits"
  else
    pass "validate_project_dir fails for repo with no commits"
  fi
}

test_validate_project_dir_valid() {
  local DIR="$FIXTURE_DIR/valid"
  mkdir -p "$DIR"
  git -C "$DIR" init --quiet 2>/dev/null
  git -C "$DIR" config user.email "test@test"
  git -C "$DIR" config user.name "Test"
  echo "init" > "$DIR/file.txt"
  git -C "$DIR" add .
  git -C "$DIR" commit -m "init" --quiet 2>/dev/null

  if validate_project_dir "$DIR"; then
    pass "validate_project_dir passes for valid repo"
  else
    fail "validate_project_dir should pass for valid repo"
  fi
}

# =============================================================================
# session_state_read / session_state_write
# =============================================================================

test_session_state_read_existing_key() {
  local DIR="$FIXTURE_DIR/state_existing"
  mkdir -p "$DIR/.git"
  echo "init_sha=abc123" > "$DIR/.git/SESSION_STATE"
  echo "session_ts=20260401-120000" >> "$DIR/.git/SESSION_STATE"

  local RESULT
  RESULT=$(session_state_read "$DIR" "init_sha")
  if [[ "$RESULT" == "abc123" ]]; then
    pass "session_state_read returns value for existing key"
  else
    fail "session_state_read: expected abc123, got $RESULT"
  fi
}

test_session_state_read_missing_file() {
  local DIR="$FIXTURE_DIR/state_nofile"
  mkdir -p "$DIR/.git"

  local RESULT
  RESULT=$(session_state_read "$DIR" "init_sha")
  if [[ -z "$RESULT" ]]; then
    pass "session_state_read returns empty for missing file"
  else
    fail "session_state_read should return empty for missing file, got: $RESULT"
  fi
}

test_session_state_read_missing_key() {
  local DIR="$FIXTURE_DIR/state_nokey"
  mkdir -p "$DIR/.git"
  echo "other_key=value" > "$DIR/.git/SESSION_STATE"

  local RESULT
  RESULT=$(session_state_read "$DIR" "init_sha")
  if [[ -z "$RESULT" ]]; then
    pass "session_state_read returns empty for missing key"
  else
    fail "session_state_read should return empty for missing key, got: $RESULT"
  fi
}

test_session_state_read_malformed() {
  local DIR="$FIXTURE_DIR/state_malformed"
  mkdir -p "$DIR/.git"
  echo "not-a-key-value-pair" > "$DIR/.git/SESSION_STATE"

  local RESULT
  RESULT=$(session_state_read "$DIR" "init_sha")
  if [[ -z "$RESULT" ]]; then
    pass "session_state_read handles malformed file gracefully"
  else
    fail "session_state_read should return empty for malformed file, got: $RESULT"
  fi
}

# =============================================================================
# Run
# =============================================================================

run_test test_validate_project_dir_missing
run_test test_validate_project_dir_not_git
run_test test_validate_project_dir_no_commits
run_test test_validate_project_dir_valid
run_test test_session_state_read_existing_key
run_test test_session_state_read_missing_file
run_test test_session_state_read_missing_key
run_test test_session_state_read_malformed

test_done

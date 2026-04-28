#!/usr/bin/env bash
# tests/test_session.sh
# Tests for libs/session.sh
#
# Covers:
#   validate_project_dir — missing dir, not a repo, no commits, valid repo
#   resolve_session_dir  — absolute, relative, auto-resolve, require_subpath,
#                          missing base, missing resolved

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../libs/session.sh"

PASS=0
FAIL=0
FIXTURE_DIR="$(mktemp -d /tmp/XXXXXX)"
trap 'rm -rf "$FIXTURE_DIR"' EXIT

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

run_test() {
  echo "[ $1 ]"
  $1 || true
}

# -------------------------
# validate_project_dir
# -------------------------

test_validate_project_dir_missing() {
  local DIR="$FIXTURE_DIR/nonexistent"
  if ! validate_project_dir "$DIR" 2>/dev/null; then
    pass "returns error for missing directory"
  else
    fail "expected error for missing directory"
  fi
}

test_validate_project_dir_not_git() {
  local DIR="$FIXTURE_DIR/not_git"
  mkdir -p "$DIR"
  if ! validate_project_dir "$DIR" 2>/dev/null; then
    pass "returns error for non-git directory"
  else
    fail "expected error for non-git directory"
  fi
}

test_validate_project_dir_no_commits() {
  local DIR="$FIXTURE_DIR/no_commits"
  mkdir -p "$DIR"
  git -C "$DIR" init --quiet
  if ! validate_project_dir "$DIR" 2>/dev/null; then
    pass "returns error for repo with no commits"
  else
    fail "expected error for repo with no commits"
  fi
}

test_validate_project_dir_valid() {
  local DIR="$FIXTURE_DIR/valid_repo"
  mkdir -p "$DIR"
  git -C "$DIR" init --quiet
  git -C "$DIR" config user.email "test@test.com"
  git -C "$DIR" config user.name "Test"
  echo "baseline" > "$DIR/file.txt"
  git -C "$DIR" add .
  git -C "$DIR" commit -m "baseline" --quiet
  if validate_project_dir "$DIR" 2>/dev/null; then
    pass "succeeds for valid repo with commits"
  else
    fail "expected success for valid repo with commits"
  fi
}

# -------------------------
# resolve_session_dir
# -------------------------

test_resolve_absolute_path() {
  local DIR="$FIXTURE_DIR/abs_session"
  mkdir -p "$DIR/session/patches"
  local RESULT
  RESULT=$(resolve_session_dir "$FIXTURE_DIR/other" "$DIR" "")
  if [[ "$RESULT" == "$DIR" ]]; then
    pass "absolute path used as-is"
  else
    fail "expected '$DIR', got '$RESULT'"
  fi
}

test_resolve_relative_path() {
  local BASE="$FIXTURE_DIR/rel_base"
  mkdir -p "$BASE/my-session/session/patches"
  local RESULT
  RESULT=$(resolve_session_dir "$BASE" "my-session" "")
  if [[ "$RESULT" == "$BASE/my-session" ]]; then
    pass "relative path resolved under base"
  else
    fail "expected '$BASE/my-session', got '$RESULT'"
  fi
}

test_resolve_auto_resolve() {
  local BASE="$FIXTURE_DIR/auto_base"
  mkdir -p "$BASE/20260420-120000-main/session/patches"
  mkdir -p "$BASE/20260421-130000-feature/session/patches"
  local RESULT
  RESULT=$(resolve_session_dir "$BASE" "" "")
  if [[ "$RESULT" == "$BASE/20260421-130000-feature" ]]; then
    pass "auto-resolve selects lexicographically last directory"
  else
    fail "expected '$BASE/20260421-130000-feature', got '$RESULT'"
  fi
}

test_resolve_require_subpath_ok() {
  local DIR="$FIXTURE_DIR/sub_ok"
  mkdir -p "$DIR/session/patches"
  local RESULT
  RESULT=$(resolve_session_dir "$FIXTURE_DIR/other" "$DIR" "session/patches")
  if [[ "$RESULT" == "$DIR" ]]; then
    pass "require_subpath satisfied"
  else
    fail "expected '$DIR', got '$RESULT'"
  fi
}

test_resolve_require_subpath_missing() {
  local DIR="$FIXTURE_DIR/sub_missing"
  mkdir -p "$DIR/session"
  if ! resolve_session_dir "$FIXTURE_DIR/other" "$DIR" "session/patches" 2>/dev/null; then
    pass "returns error when require_subpath missing"
  else
    fail "expected error when require_subpath missing"
  fi
}

test_resolve_missing_base_relative() {
  local BASE="$FIXTURE_DIR/missing_base_rel"
  if ! resolve_session_dir "$BASE" "some-session" "" 2>/dev/null; then
    pass "returns error when base missing for relative path"
  else
    fail "expected error when base missing for relative path"
  fi
}

test_resolve_missing_base_auto() {
  local BASE="$FIXTURE_DIR/missing_base_auto"
  if ! resolve_session_dir "$BASE" "" "" 2>/dev/null; then
    pass "returns error when base missing for auto-resolve"
  else
    fail "expected error when base missing for auto-resolve"
  fi
}

test_resolve_missing_absolute() {
  local DIR="$FIXTURE_DIR/missing_abs"
  if ! resolve_session_dir "$FIXTURE_DIR/other" "$DIR" "" 2>/dev/null; then
    pass "returns error when absolute path does not exist"
  else
    fail "expected error when absolute path does not exist"
  fi
}

# -------------------------
# Run all
# -------------------------
run_test test_validate_project_dir_missing
run_test test_validate_project_dir_not_git
run_test test_validate_project_dir_no_commits
run_test test_validate_project_dir_valid
run_test test_resolve_absolute_path
run_test test_resolve_relative_path
run_test test_resolve_auto_resolve
run_test test_resolve_require_subpath_ok
run_test test_resolve_require_subpath_missing
run_test test_resolve_missing_base_relative
run_test test_resolve_missing_base_auto
run_test test_resolve_missing_absolute

echo ""
echo "Results: $PASS passed, $FAIL failed"
exit $FAIL

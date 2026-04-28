#!/usr/bin/env bash
# tests/test_checkpoint.sh
# Unit tests for scripts/checkpoint.sh functions.
#
# Covers:
#   worktree_id_derive   — 8-char hex hash from PROJECT_DIR path
#
# Note: checkpoint_create, checkpoint_prune, checkpoint_latest, and
# checkpoint_worktree_id alias were removed in 20260422-04-impl-remove_checkpoint_tags.md.
# Only worktree_id_derive remains.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$REPO_ROOT/scripts/checkpoint.sh"

PASS=0
FAIL=0

# -------------------------
# Helpers
# -------------------------
pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

run_test() {
  local NAME="$1"
  shift
  echo "[ $NAME ]"
  "$@" || true
}

FIXTURE_DIR="$(mktemp -d /tmp/XXXXXX)"
trap 'rm -rf "$FIXTURE_DIR"' EXIT

# -------------------------
# Fixture builder
# -------------------------
make_committed_repo() {
  local DIR="$1"
  mkdir -p "$DIR"
  git -C "$DIR" init --quiet --initial-branch=main 2>/dev/null || {
    git -C "$DIR" init --quiet
    git -C "$DIR" branch -M main 2>/dev/null || true
  }
  git -C "$DIR" config user.email "test@sandbox"
  git -C "$DIR" config user.name "test"
  echo "initial" > "$DIR/initial.txt"
  git -C "$DIR" add initial.txt
  git -C "$DIR" commit -m "initial commit" --quiet
}

# -------------------------
# worktree_id_derive tests
# -------------------------

test_worktree_id_derive_returns_8_chars() {
  local PROJECT_DIR="$FIXTURE_DIR/wtid_8_repo"
  make_committed_repo "$PROJECT_DIR"

  local WID
  WID=$(worktree_id_derive "$PROJECT_DIR")

  if [[ ${#WID} -eq 8 ]]; then
    pass "worktree_id_derive returns 8 characters"
  else
    fail "worktree_id_derive returned ${#WID} chars, expected 8"
  fi
}

test_worktree_id_derive_is_hex() {
  local PROJECT_DIR="$FIXTURE_DIR/wtid_hex_repo"
  make_committed_repo "$PROJECT_DIR"

  local WID
  WID=$(worktree_id_derive "$PROJECT_DIR")

  if [[ "$WID" =~ ^[a-f0-9]{8}$ ]]; then
    pass "worktree_id_derive returns valid hex"
  else
    fail "worktree_id_derive returned non-hex: $WID"
  fi
}

test_worktree_id_derive_stable_across_calls() {
  local PROJECT_DIR="$FIXTURE_DIR/wtid_stable_repo"
  make_committed_repo "$PROJECT_DIR"

  local WID1 WID2
  WID1=$(worktree_id_derive "$PROJECT_DIR")
  WID2=$(worktree_id_derive "$PROJECT_DIR")

  if [[ "$WID1" == "$WID2" ]]; then
    pass "worktree_id_derive is stable across multiple calls"
  else
    fail "worktree_id_derive not stable: $WID1 vs $WID2"
  fi
}

test_worktree_id_derive_different_for_different_paths() {
  local DIR1="$FIXTURE_DIR/wtid_diff_repo1"
  local DIR2="$FIXTURE_DIR/wtid_diff_repo2"
  mkdir -p "$DIR1" "$DIR2"

  local WID1 WID2
  WID1=$(worktree_id_derive "$DIR1")
  WID2=$(worktree_id_derive "$DIR2")

  if [[ "$WID1" != "$WID2" ]]; then
    pass "worktree_id_derive differs for different paths"
  else
    fail "worktree_id_derive should differ for different paths"
  fi
}

# -------------------------
# Run all tests
# -------------------------

echo "=== checkpoint.sh unit tests ==="
echo

run_test "worktree_id_derive_returns_8_chars" test_worktree_id_derive_returns_8_chars
run_test "worktree_id_derive_is_hex" test_worktree_id_derive_is_hex
run_test "worktree_id_derive_stable_across_calls" test_worktree_id_derive_stable_across_calls
run_test "worktree_id_derive_different_for_different_paths" test_worktree_id_derive_different_for_different_paths

echo
echo "Results: $PASS passed, $FAIL failed"

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi

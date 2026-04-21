#!/usr/bin/env bash
# tests/test_checkpoint.sh
# Unit tests for scripts/checkpoint.sh functions.
#
# Covers (spec interface from Change 5):
#   worktree_id_derive   — 8-char hex hash from PROJECT_DIR path
#   checkpoint_create    — tag creation and pruning
#   checkpoint_prune     — standalone pruning function
#   checkpoint_lookup    — lookup of most recent tag
#
# Also tests aliases: checkpoint_worktree_id, checkpoint_latest

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

FIXTURE_DIR="$(mktemp -d)"
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
# worktree_id_derive tests (canonical)
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

# Alias test
test_checkpoint_worktree_id_alias() {
  local PROJECT_DIR="$FIXTURE_DIR/wtid_alias_repo"
  make_committed_repo "$PROJECT_DIR"

  local WID1 WID2
  WID1=$(worktree_id_derive "$PROJECT_DIR")
  WID2=$(checkpoint_worktree_id "$PROJECT_DIR")

  if [[ "$WID1" == "$WID2" ]]; then
    pass "checkpoint_worktree_id alias matches worktree_id_derive"
  else
    fail "checkpoint_worktree_id alias mismatch: $WID1 vs $WID2"
  fi
}

# -------------------------
# checkpoint_create tests
# -------------------------

test_checkpoint_create_returns_tag() {
  local PROJECT_DIR="$FIXTURE_DIR/cc_return_repo"
  make_committed_repo "$PROJECT_DIR"

  local TIMESTAMP="20260420-120000"
  local TAG
  TAG=$(checkpoint_create "$PROJECT_DIR" "$TIMESTAMP")

  local WORKTREE_ID
  WORKTREE_ID=$(worktree_id_derive "$PROJECT_DIR")
  local EXPECTED="agent-checkpoint/${WORKTREE_ID}/${TIMESTAMP}"

  if [[ "$TAG" == "$EXPECTED" ]]; then
    pass "checkpoint_create returns correct tag format"
  else
    fail "checkpoint_create returned wrong tag: $TAG (expected $EXPECTED)"
  fi
}

test_checkpoint_create_creates_tag() {
  local PROJECT_DIR="$FIXTURE_DIR/cc_create_repo"
  make_committed_repo "$PROJECT_DIR"

  local TIMESTAMP="20260420-120001"
  checkpoint_create "$PROJECT_DIR" "$TIMESTAMP" >/dev/null

  local WORKTREE_ID
  WORKTREE_ID=$(worktree_id_derive "$PROJECT_DIR")
  local TAG="agent-checkpoint/${WORKTREE_ID}/${TIMESTAMP}"

  if git -C "$PROJECT_DIR" rev-parse --verify "$TAG" >/dev/null 2>&1; then
    pass "checkpoint_create creates git tag"
  else
    fail "checkpoint_create did not create git tag"
  fi
}

test_checkpoint_create_prunes_to_five() {
  local PROJECT_DIR="$FIXTURE_DIR/cc_prune_repo"
  make_committed_repo "$PROJECT_DIR"

  local WORKTREE_ID
  WORKTREE_ID=$(worktree_id_derive "$PROJECT_DIR")

  # Create 7 tags manually
  for i in 1 2 3 4 5 6 7; do
    local TS="20260420-12000${i}"
    local TAG="agent-checkpoint/${WORKTREE_ID}/${TS}"
    git -C "$PROJECT_DIR" tag "$TAG"
  done

  # Create one more via checkpoint_create (should prune to 5)
  checkpoint_create "$PROJECT_DIR" "20260420-120008" >/dev/null

  local COUNT
  COUNT=$(git -C "$PROJECT_DIR" tag --list "agent-checkpoint/${WORKTREE_ID}/*" | wc -l)

  if [[ "$COUNT" -eq 5 ]]; then
    pass "checkpoint_create prunes to 5 most recent tags"
  else
    fail "checkpoint_create pruning failed: expected 5 tags, got $COUNT"
  fi
}

# -------------------------
# checkpoint_prune tests (standalone)
# -------------------------

test_checkpoint_prune_standalone() {
  local PROJECT_DIR="$FIXTURE_DIR/cp_standalone_repo"
  make_committed_repo "$PROJECT_DIR"

  local WORKTREE_ID
  WORKTREE_ID=$(worktree_id_derive "$PROJECT_DIR")

  # Create 8 tags manually
  for i in 1 2 3 4 5 6 7 8; do
    local TS="20260420-12000${i}"
    local TAG="agent-checkpoint/${WORKTREE_ID}/${TS}"
    git -C "$PROJECT_DIR" tag "$TAG"
  done

  # Prune to 5 using standalone function
  checkpoint_prune "$PROJECT_DIR" 5

  local COUNT
  COUNT=$(git -C "$PROJECT_DIR" tag --list "agent-checkpoint/${WORKTREE_ID}/*" | wc -l)

  if [[ "$COUNT" -eq 5 ]]; then
    pass "checkpoint_prune standalone function prunes to specified count"
  else
    fail "checkpoint_prune failed: expected 5 tags, got $COUNT"
  fi
}

test_checkpoint_prune_default_keep() {
  local PROJECT_DIR="$FIXTURE_DIR/cp_default_repo"
  make_committed_repo "$PROJECT_DIR"

  local WORKTREE_ID
  WORKTREE_ID=$(worktree_id_derive "$PROJECT_DIR")

  # Create 7 tags manually
  for i in 1 2 3 4 5 6 7; do
    local TS="20260420-12000${i}"
    local TAG="agent-checkpoint/${WORKTREE_ID}/${TS}"
    git -C "$PROJECT_DIR" tag "$TAG"
  done

  # Prune with default (should keep 5)
  checkpoint_prune "$PROJECT_DIR"

  local COUNT
  COUNT=$(git -C "$PROJECT_DIR" tag --list "agent-checkpoint/${WORKTREE_ID}/*" | wc -l)

  if [[ "$COUNT" -eq 5 ]]; then
    pass "checkpoint_prune defaults to keeping 5 tags"
  else
    fail "checkpoint_prune default failed: expected 5 tags, got $COUNT"
  fi
}

# -------------------------
# checkpoint_latest tests
# -------------------------

test_checkpoint_latest_returns_newest() {
  local PROJECT_DIR="$FIXTURE_DIR/cl_newest_repo"
  make_committed_repo "$PROJECT_DIR"

  local WORKTREE_ID
  WORKTREE_ID=$(worktree_id_derive "$PROJECT_DIR")

  # Create 3 tags
  for i in 1 2 3; do
    local TS="20260420-12000${i}"
    local TAG="agent-checkpoint/${WORKTREE_ID}/${TS}"
    git -C "$PROJECT_DIR" tag "$TAG"
  done

  local LATEST
  LATEST=$(checkpoint_latest "$PROJECT_DIR")

  if [[ "$LATEST" == *"20260420-120003" ]]; then
    pass "checkpoint_latest returns most recent tag"
  else
    fail "checkpoint_latest returned wrong tag: $LATEST"
  fi
}

test_checkpoint_latest_empty_when_no_tags() {
  local PROJECT_DIR="$FIXTURE_DIR/cl_empty_repo"
  make_committed_repo "$PROJECT_DIR"

  local LATEST
  LATEST=$(checkpoint_latest "$PROJECT_DIR")

  if [[ -z "$LATEST" ]]; then
    pass "checkpoint_latest returns empty string when no tags exist"
  else
    fail "checkpoint_latest should return empty string, got: $LATEST"
  fi
}

test_checkpoint_latest_scoped_to_worktree() {
  local DIR1="$FIXTURE_DIR/cl_scope_repo1"
  local DIR2="$FIXTURE_DIR/cl_scope_repo2"
  make_committed_repo "$DIR1"
  make_committed_repo "$DIR2"

  local WID1 WID2
  WID1=$(checkpoint_worktree_id "$DIR1")
  WID2=$(checkpoint_worktree_id "$DIR2")

  # Create tags in both repos
  git -C "$DIR1" tag "agent-checkpoint/${WID1}/20260420-120000"
  git -C "$DIR2" tag "agent-checkpoint/${WID2}/20260420-120001"

  local LATEST1 LATEST2
  LATEST1=$(checkpoint_latest "$DIR1")
  LATEST2=$(checkpoint_latest "$DIR2")

  if [[ "$LATEST1" == *"20260420-120000" && "$LATEST2" == *"20260420-120001" ]]; then
    pass "checkpoint_latest is scoped to worktree namespace"
  else
    fail "checkpoint_latest worktree scoping failed: $LATEST1 vs $LATEST2"
  fi
}

# -------------------------
# Run all tests
# -------------------------

echo "=== checkpoint.sh unit tests ==="
echo

# worktree_id_derive tests
run_test "worktree_id_derive_returns_8_chars" test_worktree_id_derive_returns_8_chars
run_test "worktree_id_derive_is_hex" test_worktree_id_derive_is_hex
run_test "worktree_id_derive_stable_across_calls" test_worktree_id_derive_stable_across_calls
run_test "worktree_id_derive_different_for_different_paths" test_worktree_id_derive_different_for_different_paths
run_test "checkpoint_worktree_id_alias" test_checkpoint_worktree_id_alias

# checkpoint_create tests
run_test "checkpoint_create_returns_tag" test_checkpoint_create_returns_tag
run_test "checkpoint_create_creates_tag" test_checkpoint_create_creates_tag
run_test "checkpoint_create_prunes_to_five" test_checkpoint_create_prunes_to_five

# checkpoint_prune tests
run_test "checkpoint_prune_standalone" test_checkpoint_prune_standalone
run_test "checkpoint_prune_default_keep" test_checkpoint_prune_default_keep

# checkpoint_lookup tests
run_test "checkpoint_lookup_returns_newest" test_checkpoint_latest_returns_newest
run_test "checkpoint_lookup_empty_when_no_tags" test_checkpoint_latest_empty_when_no_tags
run_test "checkpoint_lookup_scoped_to_worktree" test_checkpoint_latest_scoped_to_worktree

echo
echo "Results: $PASS passed, $FAIL failed"

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi

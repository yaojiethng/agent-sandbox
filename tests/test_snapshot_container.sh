#!/usr/bin/env bash
# tests/test_snapshot_container.sh
# Container-side snapshot pipeline tests: snapshot_validate, snapshot_copy_to_sandbox, snapshot_init_git.
# All fixtures created under /tmp — no git repos created inside the harness repo.
# Can be run directly on the host or inside the container.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO_ROOT/libs/snapshot.sh"

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
make_snapshot() {
  local DIR="$1"
  mkdir -p "$DIR"
  echo "content" > "$DIR/file.txt"
  mkdir -p "$DIR/src"
  echo "source" > "$DIR/src/main.txt"
}

# -------------------------
# Test: snapshot_validate passes on valid snapshot
# -------------------------
test_validate_passes() {
  local DIR="$FIXTURE_DIR/validate_pass"
  make_snapshot "$DIR"

  if snapshot_validate "$DIR" 2>/dev/null; then
    pass "validate passes on valid snapshot"
  else
    fail "validate failed on valid snapshot"
  fi
}

# -------------------------
# Test: snapshot_validate fails on missing directory
# -------------------------
test_validate_missing() {
  if snapshot_validate "$FIXTURE_DIR/nonexistent" 2>/dev/null; then
    fail "validate should fail on missing directory"
  else
    pass "validate correctly fails on missing directory"
  fi
}

# -------------------------
# Test: snapshot_validate fails on empty directory
# -------------------------
test_validate_empty() {
  local DIR="$FIXTURE_DIR/empty"
  mkdir -p "$DIR"

  if snapshot_validate "$DIR" 2>/dev/null; then
    fail "validate should fail on empty directory"
  else
    pass "validate correctly fails on empty directory"
  fi
}

# -------------------------
# Test: snapshot_copy_to_sandbox copies all files
# -------------------------
test_copy_to_sandbox() {
  local SNAPSHOT="$FIXTURE_DIR/copy_snapshot"
  local SANDBOX="$FIXTURE_DIR/copy_sandbox"
  make_snapshot "$SNAPSHOT"

  snapshot_copy_to_sandbox "$SNAPSHOT" "$SANDBOX"

  if [[ -f "$SANDBOX/file.txt" && -f "$SANDBOX/src/main.txt" ]]; then
    pass "all files copied to sandbox"
  else
    fail "files missing after copy to sandbox"
  fi
}

# -------------------------
# Test: snapshot_copy_to_sandbox does not modify snapshot
# -------------------------
test_copy_leaves_snapshot_intact() {
  local SNAPSHOT="$FIXTURE_DIR/intact_snapshot"
  local SANDBOX="$FIXTURE_DIR/intact_sandbox"
  make_snapshot "$SNAPSHOT"

  snapshot_copy_to_sandbox "$SNAPSHOT" "$SANDBOX"

  if [[ -f "$SNAPSHOT/file.txt" ]]; then
    pass "snapshot intact after copy"
  else
    fail "snapshot modified by copy"
  fi
}

# -------------------------
# Test: snapshot_init_git produces a git repo with one commit
# -------------------------
test_init_git_baseline() {
  local SNAPSHOT="$FIXTURE_DIR/init_snapshot"
  local SANDBOX="$FIXTURE_DIR/init_sandbox"
  make_snapshot "$SNAPSHOT"
  snapshot_copy_to_sandbox "$SNAPSHOT" "$SANDBOX"

  local SHA
  SHA=$(snapshot_init_git "$SANDBOX")

  if [[ -d "$SANDBOX/.git" ]]; then
    pass "git repo initialised in sandbox"
  else
    fail "no git repo in sandbox after init"
  fi

  local COMMIT_COUNT
  COMMIT_COUNT=$(git -C "$SANDBOX" rev-list --count HEAD)
  if [[ "$COMMIT_COUNT" -eq 1 ]]; then
    pass "exactly one baseline commit"
  else
    fail "expected 1 commit, got $COMMIT_COUNT"
  fi

  if [[ -n "$SHA" ]]; then
    pass "baseline SHA returned: $SHA"
  else
    fail "no baseline SHA returned"
  fi
}

# -------------------------
# Test: snapshot_init_git baseline SHA matches first commit
# -------------------------
test_init_git_sha_matches() {
  local SNAPSHOT="$FIXTURE_DIR/sha_snapshot"
  local SANDBOX="$FIXTURE_DIR/sha_sandbox"
  make_snapshot "$SNAPSHOT"
  snapshot_copy_to_sandbox "$SNAPSHOT" "$SANDBOX"

  local SHA
  SHA=$(snapshot_init_git "$SANDBOX")

  local ACTUAL_SHA
  ACTUAL_SHA=$(git -C "$SANDBOX" rev-list --max-parents=0 HEAD)

  if [[ "$SHA" == "$ACTUAL_SHA" ]]; then
    pass "returned SHA matches baseline commit"
  else
    fail "SHA mismatch: got $SHA, expected $ACTUAL_SHA"
  fi
}

# -------------------------
# Test: sandbox is independent — changes do not affect snapshot
# -------------------------
test_sandbox_isolation() {
  local SNAPSHOT="$FIXTURE_DIR/isolation_snapshot"
  local SANDBOX="$FIXTURE_DIR/isolation_sandbox"
  make_snapshot "$SNAPSHOT"
  snapshot_copy_to_sandbox "$SNAPSHOT" "$SANDBOX"
  snapshot_init_git "$SANDBOX" > /dev/null

  echo "agent change" > "$SANDBOX/file.txt"

  local SNAPSHOT_CONTENT
  SNAPSHOT_CONTENT=$(cat "$SNAPSHOT/file.txt")

  if [[ "$SNAPSHOT_CONTENT" == "content" ]]; then
    pass "sandbox changes do not affect snapshot"
  else
    fail "snapshot was modified by sandbox write"
  fi
}

# -------------------------
# Run all tests
# -------------------------
run_test "validate passes"              test_validate_passes
run_test "validate missing dir"         test_validate_missing
run_test "validate empty dir"           test_validate_empty
run_test "copy to sandbox"              test_copy_to_sandbox
run_test "copy leaves snapshot intact"  test_copy_leaves_snapshot_intact
run_test "init git baseline"            test_init_git_baseline
run_test "init git SHA matches"         test_init_git_sha_matches
run_test "sandbox isolation"            test_sandbox_isolation

# -------------------------
# Summary
# -------------------------
echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]

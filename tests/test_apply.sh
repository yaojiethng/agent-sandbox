#!/usr/bin/env bash
# tests/test_apply.sh
# Tests for scripts/apply_workspace_inplace.sh and scripts/apply_workspace_to_branch.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPLY_INPLACE="$SCRIPT_DIR/../scripts/apply_workspace_inplace.sh"
APPLY_TO_BRANCH="$SCRIPT_DIR/../scripts/apply_workspace_to_branch.sh"

PASS=0
FAIL=0
FIXTURE_DIR="$(mktemp -d)"
trap 'rm -rf "$FIXTURE_DIR"' EXIT

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

run_test() {
  echo "[ $1 ]"
  $1 || true
}

# -------------------------
# Helpers
# -------------------------
make_repo() {
  local DIR="$1"
  mkdir -p "$DIR"
  git -C "$DIR" init --quiet
  git -C "$DIR" config user.email "test@test.com"
  git -C "$DIR" config user.name "Test"
  echo "baseline" > "$DIR/file.txt"
  git -C "$DIR" add .
  git -C "$DIR" commit -m "baseline" --quiet
}

make_workspace() {
  local DIR="$1"
  mkdir -p "$DIR/changes"
}

# Build a real patch from a sandbox against a repo with identical baseline.
make_staged_diff() {
  local SANDBOX="$1"
  local WORKSPACE="$2"

  mkdir -p "$SANDBOX"
  git -C "$SANDBOX" init --quiet
  git -C "$SANDBOX" config user.email "test@test.com"
  git -C "$SANDBOX" config user.name "Test"
  echo "baseline" > "$SANDBOX/file.txt"
  git -C "$SANDBOX" add .
  git -C "$SANDBOX" commit -m "baseline" --quiet
  local SHA
  SHA=$(git -C "$SANDBOX" rev-parse HEAD)

  # Make a change and commit it
  echo "agent change" > "$SANDBOX/file.txt"
  echo "new file" > "$SANDBOX/added.txt"
  git -C "$SANDBOX" add .
  git -C "$SANDBOX" commit -m "agent work" --quiet

  mkdir -p "$WORKSPACE/changes"
  git -C "$SANDBOX" diff "${SHA}..HEAD" > "$WORKSPACE/changes/staged.diff"
}

# -------------------------
# apply_workspace_inplace
# -------------------------
test_inplace_missing_staged_diff() {
  local PROJECT="$FIXTURE_DIR/inplace_nodiff"
  local WORKSPACE="$FIXTURE_DIR/inplace_nodiff_ws"
  make_repo "$PROJECT"
  make_workspace "$WORKSPACE"

  if "$APPLY_INPLACE" "$PROJECT" "$WORKSPACE" 2>/dev/null; then
    fail "inplace should fail when staged.diff is missing"
  else
    pass "inplace fails when staged.diff is missing"
  fi
}

test_inplace_empty_staged_diff() {
  local PROJECT="$FIXTURE_DIR/inplace_empty"
  local WORKSPACE="$FIXTURE_DIR/inplace_empty_ws"
  make_repo "$PROJECT"
  make_workspace "$WORKSPACE"
  touch "$WORKSPACE/changes/staged.diff"

  if "$APPLY_INPLACE" "$PROJECT" "$WORKSPACE" 2>/dev/null; then
    fail "inplace should fail when staged.diff is empty"
  else
    pass "inplace fails when staged.diff is empty"
  fi
}

test_inplace_not_a_git_repo() {
  local PROJECT="$FIXTURE_DIR/inplace_nogit"
  local WORKSPACE="$FIXTURE_DIR/inplace_nogit_ws"
  mkdir -p "$PROJECT"
  make_workspace "$WORKSPACE"
  echo "content" > "$WORKSPACE/changes/staged.diff"

  if "$APPLY_INPLACE" "$PROJECT" "$WORKSPACE" 2>/dev/null; then
    fail "inplace should fail when PROJECT_ROOT is not a git repo"
  else
    pass "inplace fails when PROJECT_ROOT is not a git repo"
  fi
}

test_inplace_no_commits() {
  local PROJECT="$FIXTURE_DIR/inplace_nocommit"
  local WORKSPACE="$FIXTURE_DIR/inplace_nocommit_ws"
  mkdir -p "$PROJECT"
  git -C "$PROJECT" init --quiet
  make_workspace "$WORKSPACE"
  echo "content" > "$WORKSPACE/changes/staged.diff"

  if "$APPLY_INPLACE" "$PROJECT" "$WORKSPACE" 2>/dev/null; then
    fail "inplace should fail when repo has no commits"
  else
    pass "inplace fails when repo has no commits"
  fi
}

test_inplace_clean_apply() {
  local PROJECT="$FIXTURE_DIR/inplace_apply"
  local SANDBOX="$FIXTURE_DIR/inplace_apply_sandbox"
  local WORKSPACE="$FIXTURE_DIR/inplace_apply_ws"
  make_repo "$PROJECT"
  make_staged_diff "$SANDBOX" "$WORKSPACE"

  if "$APPLY_INPLACE" "$PROJECT" "$WORKSPACE" 2>/dev/null; then
    if [[ "$(cat "$PROJECT/file.txt")" == "agent change" ]] && [[ -f "$PROJECT/added.txt" ]]; then
      pass "inplace applies staged.diff cleanly"
    else
      fail "inplace applied but file contents are wrong"
    fi
  else
    fail "inplace should succeed on clean apply"
  fi
}

test_inplace_does_not_commit() {
  local PROJECT="$FIXTURE_DIR/inplace_nocommit2"
  local SANDBOX="$FIXTURE_DIR/inplace_nocommit2_sandbox"
  local WORKSPACE="$FIXTURE_DIR/inplace_nocommit2_ws"
  make_repo "$PROJECT"
  make_staged_diff "$SANDBOX" "$WORKSPACE"
  local SHA_BEFORE
  SHA_BEFORE=$(git -C "$PROJECT" rev-parse HEAD)

  "$APPLY_INPLACE" "$PROJECT" "$WORKSPACE" 2>/dev/null || true

  local SHA_AFTER
  SHA_AFTER=$(git -C "$PROJECT" rev-parse HEAD)
  if [[ "$SHA_BEFORE" == "$SHA_AFTER" ]]; then
    pass "inplace does not commit after apply"
  else
    fail "inplace must not commit — HEAD should not advance"
  fi
}

# -------------------------
# apply_workspace_to_branch
# -------------------------
test_to_branch_missing_staged_diff() {
  local PROJECT="$FIXTURE_DIR/branch_nodiff"
  local WORKSPACE="$FIXTURE_DIR/branch_nodiff_ws"
  make_repo "$PROJECT"
  make_workspace "$WORKSPACE"

  if "$APPLY_TO_BRANCH" "$PROJECT" "$WORKSPACE" "agent/task-1" 2>/dev/null; then
    fail "to_branch should fail when staged.diff is missing"
  else
    pass "to_branch fails when staged.diff is missing"
  fi
}

test_to_branch_creates_new_branch() {
  local PROJECT="$FIXTURE_DIR/branch_new"
  local SANDBOX="$FIXTURE_DIR/branch_new_sandbox"
  local WORKSPACE="$FIXTURE_DIR/branch_new_ws"
  make_repo "$PROJECT"
  make_staged_diff "$SANDBOX" "$WORKSPACE"

  "$APPLY_TO_BRANCH" "$PROJECT" "$WORKSPACE" "agent/task-1" 2>/dev/null || true

  local CURRENT
  CURRENT=$(git -C "$PROJECT" rev-parse --abbrev-ref HEAD)
  if [[ "$CURRENT" == "agent/task-1" ]]; then
    pass "to_branch creates and checks out new branch"
  else
    fail "to_branch should create branch agent/task-1, got: $CURRENT"
  fi
}

test_to_branch_uses_existing_branch() {
  local PROJECT="$FIXTURE_DIR/branch_existing"
  local SANDBOX="$FIXTURE_DIR/branch_existing_sandbox"
  local WORKSPACE="$FIXTURE_DIR/branch_existing_ws"
  make_repo "$PROJECT"
  git -C "$PROJECT" checkout -b "agent/existing" --quiet
  git -C "$PROJECT" checkout master --quiet 2>/dev/null || git -C "$PROJECT" checkout main --quiet 2>/dev/null || true
  make_staged_diff "$SANDBOX" "$WORKSPACE"

  "$APPLY_TO_BRANCH" "$PROJECT" "$WORKSPACE" "agent/existing" 2>/dev/null || true

  local CURRENT
  CURRENT=$(git -C "$PROJECT" rev-parse --abbrev-ref HEAD)
  if [[ "$CURRENT" == "agent/existing" ]]; then
    pass "to_branch checks out existing branch"
  else
    fail "to_branch should switch to existing branch, got: $CURRENT"
  fi
}

test_to_branch_clean_apply() {
  local PROJECT="$FIXTURE_DIR/branch_apply"
  local SANDBOX="$FIXTURE_DIR/branch_apply_sandbox"
  local WORKSPACE="$FIXTURE_DIR/branch_apply_ws"
  make_repo "$PROJECT"
  make_staged_diff "$SANDBOX" "$WORKSPACE"

  if "$APPLY_TO_BRANCH" "$PROJECT" "$WORKSPACE" "agent/task-2" 2>/dev/null; then
    if [[ "$(cat "$PROJECT/file.txt")" == "agent change" ]] && [[ -f "$PROJECT/added.txt" ]]; then
      pass "to_branch applies staged.diff cleanly"
    else
      fail "to_branch applied but file contents are wrong"
    fi
  else
    fail "to_branch should succeed on clean apply"
  fi
}

test_to_branch_does_not_commit() {
  local PROJECT="$FIXTURE_DIR/branch_nocommit"
  local SANDBOX="$FIXTURE_DIR/branch_nocommit_sandbox"
  local WORKSPACE="$FIXTURE_DIR/branch_nocommit_ws"
  make_repo "$PROJECT"
  make_staged_diff "$SANDBOX" "$WORKSPACE"
  local SHA_BEFORE
  SHA_BEFORE=$(git -C "$PROJECT" rev-parse HEAD)

  "$APPLY_TO_BRANCH" "$PROJECT" "$WORKSPACE" "agent/task-3" 2>/dev/null || true

  local SHA_AFTER
  SHA_AFTER=$(git -C "$PROJECT" rev-parse HEAD)
  if [[ "$SHA_BEFORE" == "$SHA_AFTER" ]]; then
    pass "to_branch does not commit after apply"
  else
    fail "to_branch must not commit — HEAD should not advance"
  fi
}

# -------------------------
# Run all tests
# -------------------------
run_test test_inplace_missing_staged_diff
run_test test_inplace_empty_staged_diff
run_test test_inplace_not_a_git_repo
run_test test_inplace_no_commits
run_test test_inplace_clean_apply
run_test test_inplace_does_not_commit
run_test test_to_branch_missing_staged_diff
run_test test_to_branch_creates_new_branch
run_test test_to_branch_uses_existing_branch
run_test test_to_branch_clean_apply
run_test test_to_branch_does_not_commit

echo ""
echo "Results: $PASS passed, $FAIL failed"

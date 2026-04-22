#!/usr/bin/env bash
# tests/test_snapshot_container.sh
# Container-side snapshot pipeline tests: snapshot_validate, snapshot_copy_to_sandbox,
# snapshot_init_git.
#
# snapshot_init_git tests cover the full eight-case working tree state matrix.
# Each case builds a fixture that includes both a baseline.tar (via git archive HEAD)
# and an rsync working tree copy, then asserts git status --porcelain output.
#
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
# Fixture builders
# -------------------------
make_snapshot() {
  local DIR="$1"
  mkdir -p "$DIR"
  echo "content" > "$DIR/file.txt"
  mkdir -p "$DIR/src"
  echo "source" > "$DIR/src/main.txt"
}

# Build a complete snapshot fixture for snapshot_init_git:
# - PROJECT_DIR with a committed baseline
# - SNAPSHOT_DIR containing both baseline.tar and the rsync working tree copy
#
# Usage: make_init_fixture PROJECT_DIR SNAPSHOT_DIR
# After this returns, caller can modify the working tree in PROJECT_DIR
# and re-run the rsync step to simulate different operator states.
make_init_fixture() {
  local PROJECT_DIR="$1"
  local SNAPSHOT_DIR="$2"

  mkdir -p "$PROJECT_DIR"
  git -C "$PROJECT_DIR" init --quiet
  git -C "$PROJECT_DIR" config user.email "test@sandbox"
  git -C "$PROJECT_DIR" config user.name "test"

  # Committed content
  echo "committed content" > "$PROJECT_DIR/committed.txt"
  mkdir -p "$PROJECT_DIR/src"
  echo "source" > "$PROJECT_DIR/src/module.txt"
  git -C "$PROJECT_DIR" add .
  git -C "$PROJECT_DIR" commit -m "initial" --quiet

  # Produce baseline.tar from HEAD
  snapshot_archive_head "$PROJECT_DIR" "$SNAPSHOT_DIR"

  # Produce rsync working tree copy (current state = clean at this point)
  snapshot_copy_worktree "$PROJECT_DIR" "$SNAPSHOT_DIR"
}

# Re-sync the working tree into an existing SNAPSHOT_DIR after the caller
# has made working tree changes to PROJECT_DIR.
# Uses --delete so that files removed from the working tree are also removed
# from SNAPSHOT_DIR — this is required for deletion cases (4 and 5) to work
# correctly. snapshot_copy_worktree does not use --delete (it is a one-way
# copy, not a mirror), so we call rsync directly here.
resync_snapshot() {
  local PROJECT_DIR="$1"
  local SNAPSHOT_DIR="$2"
  rsync -a --delete     --filter=':- .gitignore'     --exclude='.git'     --exclude='baseline.tar'     "$PROJECT_DIR/" "$SNAPSHOT_DIR/"
}

# -------------------------
# snapshot_validate tests
# -------------------------

test_validate_passes() {
  local DIR="$FIXTURE_DIR/validate_pass"
  make_snapshot "$DIR"
  touch "$DIR/baseline.tar"

  if snapshot_validate "$DIR" 2>/dev/null; then
    pass "validate passes on valid snapshot with baseline.tar"
  else
    fail "validate failed on valid snapshot"
  fi
}

test_validate_missing() {
  if snapshot_validate "$FIXTURE_DIR/nonexistent" 2>/dev/null; then
    fail "validate should fail on missing directory"
  else
    pass "validate correctly fails on missing directory"
  fi
}

test_validate_empty() {
  local DIR="$FIXTURE_DIR/empty"
  mkdir -p "$DIR"

  if snapshot_validate "$DIR" 2>/dev/null; then
    fail "validate should fail on empty directory"
  else
    pass "validate correctly fails on empty directory"
  fi
}

test_validate_missing_baseline_tar() {
  local DIR="$FIXTURE_DIR/validate_no_tar"
  make_snapshot "$DIR"
  # baseline.tar intentionally absent

  if snapshot_validate "$DIR" 2>/dev/null; then
    fail "validate should fail when baseline.tar is absent"
  else
    pass "validate correctly fails when baseline.tar is absent"
  fi
}

# -------------------------
# snapshot_copy_to_sandbox tests
# -------------------------

test_copy_to_sandbox() {
  local SNAPSHOT="$FIXTURE_DIR/copy_snapshot"
  local SANDBOX="$FIXTURE_DIR/copy_sandbox"
  make_snapshot "$SNAPSHOT"
  touch "$SNAPSHOT/baseline.tar"

  snapshot_copy_to_sandbox "$SNAPSHOT" "$SANDBOX"

  # Only baseline.tar should be copied — working tree files are overlaid
  # by snapshot_init_git after the baseline commit is made, not here.
  if [[ -f "$SANDBOX/baseline.tar" ]]; then
    pass "baseline.tar copied to sandbox"
  else
    fail "baseline.tar missing from sandbox after copy"
  fi

  if [[ ! -f "$SANDBOX/file.txt" ]]; then
    pass "working tree files not copied at this stage (correct)"
  else
    fail "working tree files should not be present before snapshot_init_git runs"
  fi
}

test_copy_leaves_snapshot_intact() {
  local SNAPSHOT="$FIXTURE_DIR/intact_snapshot"
  local SANDBOX="$FIXTURE_DIR/intact_sandbox"
  make_snapshot "$SNAPSHOT"
  touch "$SNAPSHOT/baseline.tar"

  snapshot_copy_to_sandbox "$SNAPSHOT" "$SANDBOX"

  if [[ -f "$SNAPSHOT/file.txt" && -f "$SNAPSHOT/baseline.tar" ]]; then
    pass "snapshot intact after copy"
  else
    fail "snapshot modified by copy"
  fi
}

# -------------------------
# snapshot_init_git — working tree state matrix
#
# Each test:
#   1. Builds a project repo with committed content
#   2. Produces baseline.tar + rsync copy into a snapshot dir
#   3. Optionally modifies the working tree
#   4. Re-syncs the snapshot (rsync copy only — baseline.tar is unchanged)
#   5. Calls snapshot_init_git SANDBOX SNAPSHOT
#   6. Asserts git status --porcelain output in sandbox
# -------------------------

# Case 1: tracked file, no changes — clean
test_init_git_case1_clean() {
  local PROJECT="$FIXTURE_DIR/case1_project"
  local SNAPSHOT="$FIXTURE_DIR/case1_snapshot"
  local SANDBOX="$FIXTURE_DIR/case1_sandbox"
  mkdir -p "$SANDBOX"

  make_init_fixture "$PROJECT" "$SNAPSHOT"
  snapshot_copy_to_sandbox "$SNAPSHOT" "$SANDBOX"

  local SHA
  SHA=$(snapshot_init_git "$SANDBOX" "$SNAPSHOT")

  local STATUS
  STATUS=$(git -C "$SANDBOX" status --porcelain)

  if [[ -z "$STATUS" ]]; then
    pass "case 1 (clean): git status is clean"
  else
    fail "case 1 (clean): expected clean status, got: $STATUS"
  fi

  if [[ -n "$SHA" ]]; then
    pass "case 1 (clean): baseline SHA returned"
  else
    fail "case 1 (clean): no baseline SHA returned"
  fi
}

# Case 2: tracked file with unstaged edits — shows as M (unstaged)
test_init_git_case2_unstaged_edit() {
  local PROJECT="$FIXTURE_DIR/case2_project"
  local SNAPSHOT="$FIXTURE_DIR/case2_snapshot"
  local SANDBOX="$FIXTURE_DIR/case2_sandbox"
  mkdir -p "$SANDBOX"

  make_init_fixture "$PROJECT" "$SNAPSHOT"

  # Make unstaged edit after baseline is committed
  echo "unstaged edit" >> "$PROJECT/committed.txt"
  resync_snapshot "$PROJECT" "$SNAPSHOT"

  snapshot_copy_to_sandbox "$SNAPSHOT" "$SANDBOX"
  snapshot_init_git "$SANDBOX" "$SNAPSHOT" > /dev/null

  local STATUS
  STATUS=$(git -C "$SANDBOX" status --porcelain)

  # Expect: " M committed.txt" (unstaged modification)
  if echo "$STATUS" | grep -q '^ M committed\.txt'; then
    pass "case 2 (unstaged edit): shows as unstaged M"
  else
    fail "case 2 (unstaged edit): expected ' M committed.txt', got: '$STATUS'"
  fi

  # Baseline commit should contain the original content, not the edit
  local BASELINE_CONTENT
  BASELINE_CONTENT=$(git -C "$SANDBOX" show HEAD:committed.txt)
  if ! echo "$BASELINE_CONTENT" | grep -q "unstaged edit"; then
    pass "case 2 (unstaged edit): baseline commit contains original content"
  else
    fail "case 2 (unstaged edit): baseline commit should not contain the edit"
  fi
}

# Case 3: tracked file, staged edit (git add but not committed) — shows as M unstaged
# Note: staging state is lost (see snapshot_init_git comment). Content is correct.
test_init_git_case3_staged_edit() {
  local PROJECT="$FIXTURE_DIR/case3_project"
  local SNAPSHOT="$FIXTURE_DIR/case3_snapshot"
  local SANDBOX="$FIXTURE_DIR/case3_sandbox"
  mkdir -p "$SANDBOX"

  make_init_fixture "$PROJECT" "$SNAPSHOT"

  echo "staged edit" >> "$PROJECT/committed.txt"
  git -C "$PROJECT" add committed.txt  # staged but not committed
  resync_snapshot "$PROJECT" "$SNAPSHOT"

  snapshot_copy_to_sandbox "$SNAPSHOT" "$SANDBOX"
  snapshot_init_git "$SANDBOX" "$SNAPSHOT" > /dev/null

  local STATUS
  STATUS=$(git -C "$SANDBOX" status --porcelain)

  # Content is present (rsync copied the staged version) but shown as unstaged
  if grep -q "staged edit" "$SANDBOX/committed.txt"; then
    pass "case 3 (staged edit): edited content present in sandbox working tree"
  else
    fail "case 3 (staged edit): edited content missing from sandbox working tree"
  fi

  # Staging state is lost — shows as unstaged M, not staged M
  if echo "$STATUS" | grep -q 'committed\.txt'; then
    pass "case 3 (staged edit): file shows as modified (staging state lost — expected)"
  else
    fail "case 3 (staged edit): expected committed.txt to appear in git status"
  fi
}

# Case 4: tracked file deleted without staging — shows as D (unstaged)
test_init_git_case4_unstaged_deletion() {
  local PROJECT="$FIXTURE_DIR/case4_project"
  local SNAPSHOT="$FIXTURE_DIR/case4_snapshot"
  local SANDBOX="$FIXTURE_DIR/case4_sandbox"
  mkdir -p "$SANDBOX"

  make_init_fixture "$PROJECT" "$SNAPSHOT"

  rm "$PROJECT/committed.txt"  # unstaged deletion
  resync_snapshot "$PROJECT" "$SNAPSHOT"

  snapshot_copy_to_sandbox "$SNAPSHOT" "$SANDBOX"
  snapshot_init_git "$SANDBOX" "$SNAPSHOT" > /dev/null

  local STATUS
  STATUS=$(git -C "$SANDBOX" status --porcelain)

  # Expect: " D committed.txt" (unstaged deletion)
  if echo "$STATUS" | grep -q '^ D committed\.txt'; then
    pass "case 4 (unstaged deletion): shows as unstaged D"
  else
    fail "case 4 (unstaged deletion): expected ' D committed.txt', got: '$STATUS'"
  fi

  # Baseline commit should still contain the file
  if git -C "$SANDBOX" show HEAD:committed.txt &>/dev/null; then
    pass "case 4 (unstaged deletion): file present in baseline commit"
  else
    fail "case 4 (unstaged deletion): file missing from baseline commit"
  fi

  # File should be absent from working tree
  if [[ ! -f "$SANDBOX/committed.txt" ]]; then
    pass "case 4 (unstaged deletion): file absent from sandbox working tree"
  else
    fail "case 4 (unstaged deletion): file should not be present in working tree"
  fi
}

# Case 5: tracked file staged for deletion (git rm) — shows as D unstaged
# Note: staging state is lost. Content is correctly absent from working tree.
test_init_git_case5_staged_deletion() {
  local PROJECT="$FIXTURE_DIR/case5_project"
  local SNAPSHOT="$FIXTURE_DIR/case5_snapshot"
  local SANDBOX="$FIXTURE_DIR/case5_sandbox"
  mkdir -p "$SANDBOX"

  make_init_fixture "$PROJECT" "$SNAPSHOT"

  git -C "$PROJECT" rm committed.txt --quiet  # staged deletion
  resync_snapshot "$PROJECT" "$SNAPSHOT"

  snapshot_copy_to_sandbox "$SNAPSHOT" "$SANDBOX"
  snapshot_init_git "$SANDBOX" "$SNAPSHOT" > /dev/null

  local STATUS
  STATUS=$(git -C "$SANDBOX" status --porcelain)

  # File absent from working tree (rsync --delete removed it)
  if [[ ! -f "$SANDBOX/committed.txt" ]]; then
    pass "case 5 (staged deletion): file absent from sandbox working tree"
  else
    fail "case 5 (staged deletion): file should not be present in working tree"
  fi

  # File present in baseline commit
  if git -C "$SANDBOX" show HEAD:committed.txt &>/dev/null; then
    pass "case 5 (staged deletion): file present in baseline commit"
  else
    fail "case 5 (staged deletion): file missing from baseline commit"
  fi
}

# Case 6: untracked file, not gitignored — shows as ??
test_init_git_case6_untracked() {
  local PROJECT="$FIXTURE_DIR/case6_project"
  local SNAPSHOT="$FIXTURE_DIR/case6_snapshot"
  local SANDBOX="$FIXTURE_DIR/case6_sandbox"
  mkdir -p "$SANDBOX"

  make_init_fixture "$PROJECT" "$SNAPSHOT"

  echo "new untracked" > "$PROJECT/hello-world.txt"
  resync_snapshot "$PROJECT" "$SNAPSHOT"

  snapshot_copy_to_sandbox "$SNAPSHOT" "$SANDBOX"
  snapshot_init_git "$SANDBOX" "$SNAPSHOT" > /dev/null

  local STATUS
  STATUS=$(git -C "$SANDBOX" status --porcelain)

  # Expect: "?? hello-world.txt"
  if echo "$STATUS" | grep -q '^?? hello-world\.txt'; then
    pass "case 6 (untracked): shows as ??"
  else
    fail "case 6 (untracked): expected '?? hello-world.txt', got: '$STATUS'"
  fi

  # File should not be in baseline commit
  if ! git -C "$SANDBOX" show HEAD:hello-world.txt &>/dev/null; then
    pass "case 6 (untracked): file absent from baseline commit"
  else
    fail "case 6 (untracked): file should not be in baseline commit"
  fi
}

# Case 7: untracked file, gitignored — not visible in sandbox
test_init_git_case7_gitignored() {
  local PROJECT="$FIXTURE_DIR/case7_project"
  local SNAPSHOT="$FIXTURE_DIR/case7_snapshot"
  local SANDBOX="$FIXTURE_DIR/case7_sandbox"
  mkdir -p "$SANDBOX"

  # Need .gitignore committed before make_init_fixture
  mkdir -p "$PROJECT"
  git -C "$PROJECT" init --quiet
  git -C "$PROJECT" config user.email "test@sandbox"
  git -C "$PROJECT" config user.name "test"
  echo "committed content" > "$PROJECT/committed.txt"
  echo "secret.env" > "$PROJECT/.gitignore"
  git -C "$PROJECT" add .
  git -C "$PROJECT" commit -m "initial" --quiet

  snapshot_archive_head "$PROJECT" "$SNAPSHOT"
  snapshot_copy_worktree "$PROJECT" "$SNAPSHOT"

  echo "secret data" > "$PROJECT/secret.env"
  resync_snapshot "$PROJECT" "$SNAPSHOT"

  snapshot_copy_to_sandbox "$SNAPSHOT" "$SANDBOX"
  snapshot_init_git "$SANDBOX" "$SNAPSHOT" > /dev/null

  local STATUS
  STATUS=$(git -C "$SANDBOX" status --porcelain)

  if [[ ! -f "$SANDBOX/secret.env" ]]; then
    pass "case 7 (gitignored): file absent from sandbox"
  else
    fail "case 7 (gitignored): gitignored file should not appear in sandbox"
  fi

  if ! echo "$STATUS" | grep -q "secret.env"; then
    pass "case 7 (gitignored): file not visible in git status"
  else
    fail "case 7 (gitignored): gitignored file should not appear in git status"
  fi
}

# Case 8: new file staged with git add (not committed) — shows as ?? (untracked)
# Note: staging state is lost. Content is present on disk.
test_init_git_case8_staged_new_file() {
  local PROJECT="$FIXTURE_DIR/case8_project"
  local SNAPSHOT="$FIXTURE_DIR/case8_snapshot"
  local SANDBOX="$FIXTURE_DIR/case8_sandbox"
  mkdir -p "$SANDBOX"

  make_init_fixture "$PROJECT" "$SNAPSHOT"

  echo "new staged file" > "$PROJECT/new-staged.txt"
  git -C "$PROJECT" add new-staged.txt  # staged but not committed
  resync_snapshot "$PROJECT" "$SNAPSHOT"

  snapshot_copy_to_sandbox "$SNAPSHOT" "$SANDBOX"
  snapshot_init_git "$SANDBOX" "$SNAPSHOT" > /dev/null

  local STATUS
  STATUS=$(git -C "$SANDBOX" status --porcelain)

  # Content is present on disk (rsync copied it)
  if [[ -f "$SANDBOX/new-staged.txt" ]]; then
    pass "case 8 (staged new file): file present in sandbox working tree"
  else
    fail "case 8 (staged new file): file missing from sandbox working tree"
  fi

  # Shows as untracked (staging state lost — expected)
  if echo "$STATUS" | grep -q '^?? new-staged\.txt'; then
    pass "case 8 (staged new file): shows as ?? untracked (staging state lost — expected)"
  else
    fail "case 8 (staged new file): expected '?? new-staged.txt', got: '$STATUS'"
  fi
}

# Structural: exactly one baseline commit, SHA matches, init is idempotent-safe
test_init_git_one_commit() {
  local PROJECT="$FIXTURE_DIR/onecommit_project"
  local SNAPSHOT="$FIXTURE_DIR/onecommit_snapshot"
  local SANDBOX="$FIXTURE_DIR/onecommit_sandbox"
  mkdir -p "$SANDBOX"

  make_init_fixture "$PROJECT" "$SNAPSHOT"
  snapshot_copy_to_sandbox "$SNAPSHOT" "$SANDBOX"

  local SHA
  SHA=$(snapshot_init_git "$SANDBOX" "$SNAPSHOT")

  local COMMIT_COUNT
  COMMIT_COUNT=$(git -C "$SANDBOX" rev-list --count HEAD)
  if [[ "$COMMIT_COUNT" -eq 1 ]]; then
    pass "init_git: exactly one baseline commit"
  else
    fail "init_git: expected 1 commit, got $COMMIT_COUNT"
  fi

  local ACTUAL_SHA
  ACTUAL_SHA=$(git -C "$SANDBOX" rev-list --max-parents=0 HEAD)
  if [[ "$SHA" == "$ACTUAL_SHA" ]]; then
    pass "init_git: returned SHA matches baseline commit"
  else
    fail "init_git: SHA mismatch: returned $SHA, actual $ACTUAL_SHA"
  fi
}

# baseline.tar absent — should fail clearly
test_init_git_missing_baseline_tar() {
  local SNAPSHOT="$FIXTURE_DIR/missing_tar_snapshot"
  local SANDBOX="$FIXTURE_DIR/missing_tar_sandbox"
  mkdir -p "$SNAPSHOT" "$SANDBOX"
  echo "content" > "$SNAPSHOT/file.txt"
  # baseline.tar intentionally absent

  if snapshot_init_git "$SANDBOX" "$SNAPSHOT" 2>/dev/null; then
    fail "init_git: should fail when baseline.tar is absent"
  else
    pass "init_git: correctly fails when baseline.tar is absent"
  fi
}

# sandbox isolation — changes in sandbox do not affect snapshot
test_sandbox_isolation() {
  local PROJECT="$FIXTURE_DIR/isolation_project"
  local SNAPSHOT="$FIXTURE_DIR/isolation_snapshot"
  local SANDBOX="$FIXTURE_DIR/isolation_sandbox"
  mkdir -p "$SANDBOX"

  make_init_fixture "$PROJECT" "$SNAPSHOT"
  snapshot_copy_to_sandbox "$SNAPSHOT" "$SANDBOX"
  snapshot_init_git "$SANDBOX" "$SNAPSHOT" > /dev/null

  echo "agent change" > "$SANDBOX/committed.txt"

  local SNAPSHOT_CONTENT
  SNAPSHOT_CONTENT=$(cat "$SNAPSHOT/committed.txt")
  if [[ "$SNAPSHOT_CONTENT" == "committed content" ]]; then
    pass "sandbox changes do not affect snapshot"
  else
    fail "snapshot was modified by sandbox write"
  fi
}

# INIT_SHA file creation — verify .git/INIT_SHA is written correctly
test_init_git_creates_init_sha() {
  local PROJECT="$FIXTURE_DIR/init_sha_project"
  local SNAPSHOT="$FIXTURE_DIR/init_sha_snapshot"
  local SANDBOX="$FIXTURE_DIR/init_sha_sandbox"
  mkdir -p "$SANDBOX"

  make_init_fixture "$PROJECT" "$SNAPSHOT"
  snapshot_copy_to_sandbox "$SNAPSHOT" "$SANDBOX"

  local SHA
  SHA=$(snapshot_init_git "$SANDBOX" "$SNAPSHOT")

  # Check INIT_SHA file exists
  if [[ ! -f "$SANDBOX/.git/INIT_SHA" ]]; then
    fail "init_git: .git/INIT_SHA file not created"
    return
  fi

  # Check INIT_SHA file contains correct SHA
  local FILE_SHA
  FILE_SHA=$(cat "$SANDBOX/.git/INIT_SHA")

  if [[ "$FILE_SHA" == "$SHA" ]]; then
    pass "init_git: INIT_SHA file contains correct SHA"
  else
    fail "init_git: INIT_SHA mismatch: file has $FILE_SHA, returned $SHA"
  fi

  # Check INIT_SHA matches actual first commit
  local ACTUAL_SHA
  ACTUAL_SHA=$(git -C "$SANDBOX" rev-list --max-parents=0 HEAD)

  if [[ "$FILE_SHA" == "$ACTUAL_SHA" ]]; then
    pass "init_git: INIT_SHA matches first commit SHA"
  else
    fail "init_git: INIT_SHA mismatch: file has $FILE_SHA, actual first commit is $ACTUAL_SHA"
  fi
}

# -------------------------
# Run all tests
# -------------------------

run_test "validate passes"                   test_validate_passes
run_test "validate missing dir"              test_validate_missing
run_test "validate empty dir"                test_validate_empty
run_test "validate missing baseline.tar"     test_validate_missing_baseline_tar
run_test "copy to sandbox"                   test_copy_to_sandbox
run_test "copy leaves snapshot intact"       test_copy_leaves_snapshot_intact

run_test "init_git case 1: clean"                    test_init_git_case1_clean
run_test "init_git case 2: unstaged edit"            test_init_git_case2_unstaged_edit
run_test "init_git case 3: staged edit"              test_init_git_case3_staged_edit
run_test "init_git case 4: unstaged deletion"        test_init_git_case4_unstaged_deletion
run_test "init_git case 5: staged deletion"          test_init_git_case5_staged_deletion
run_test "init_git case 6: untracked file"           test_init_git_case6_untracked
run_test "init_git case 7: gitignored file"          test_init_git_case7_gitignored
run_test "init_git case 8: staged new file"          test_init_git_case8_staged_new_file
run_test "init_git: one baseline commit"             test_init_git_one_commit
run_test "init_git: missing baseline.tar"            test_init_git_missing_baseline_tar
run_test "sandbox isolation"                         test_sandbox_isolation
run_test "init_git: creates INIT_SHA file"           test_init_git_creates_init_sha

# -------------------------
# Summary
# -------------------------
echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
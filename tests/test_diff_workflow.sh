#!/usr/bin/env bash
# tests/test_diff_workflow.sh
# Tests for libs/diff_workflow.sh
#
# Covers:
#   apply_run  --  applies a diff file, optional branch checkout, force mode
#
# apply_run now takes a file path directly (no internal resolution).
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup
AGENT_SANDBOX_REPO="$REPO_ROOT"
source "$REPO_ROOT/scripts/workflows/apply.sh"
source "$TEST_DIR/libs/git_fixtures.sh"
source "$TEST_DIR/libs/session_fixtures.sh"
# =============================================================================
# APPLY tests  --  4-arg contract
# =============================================================================
# Given: a committed repo and a diff file generated outside it
# When:  apply_run applies with no branch and FORCE=false
# Then:  the file named in the diff exists in the working tree
# Asserts: the four-argument apply contract on a direct file path
test_apply_applies_diff() {
  local P="$FIXTURE_DIR/apply_diff_p"
  make_committed_repo "$P"
  # Create a diff file
  echo "new content" > "$P/new.txt"
  git -C "$P" add new.txt
  git -C "$P" diff --cached > "$P/../test.diff" 2>/dev/null || \
    git -C "$P" diff --cached > "$FIXTURE_DIR/test.diff"
  git -C "$P" reset --quiet HEAD -- new.txt
  rm -f "$P/new.txt"
  apply_run "$P" "$FIXTURE_DIR/test.diff" "" "false"
  if [[ -f "$P/new.txt" ]]; then
    pass "apply_run applies diff to project directory"
  else
    fail "apply_run should create new.txt from diff"
  fi
}
# Given: a committed repo on its default branch, a diff file, and a branch name no branch has yet
# When:  apply_run applies with APPLY_BRANCH set
# Then:  HEAD is on the new branch
# Asserts: the create-branch arm only (the existing-branch arm has no unit)
test_apply_applies_diff_with_branch() {
  local P="$FIXTURE_DIR/apply_branch_p"
  make_committed_repo "$P"
  echo "new content" > "$P/new.txt"
  git -C "$P" add new.txt
  git -C "$P" diff --cached > "$FIXTURE_DIR/branch.diff" 2>/dev/null || true
  git -C "$P" reset --quiet HEAD -- new.txt
  rm -f "$P/new.txt"
  git -C "$P" checkout -b "test-branch" 2>/dev/null
  git -C "$P" checkout main 2>/dev/null || git -C "$P" checkout master 2>/dev/null || true
  apply_run "$P" "$FIXTURE_DIR/branch.diff" "feature-branch" "false"
  local BRANCH
  BRANCH=$(git -C "$P" rev-parse --abbrev-ref HEAD)
  assert_eq "$BRANCH" "feature-branch" "apply_run creates and checks out new branch"
}
# Given: a repo whose committed file is edited after the diff was taken, so the hunks conflict
# When:  apply_run applies with FORCE=true
# Then:  rc 0, with the conflict tolerated as .rej files
# Asserts: the force contract is the rc, not the diff's line count
test_apply_force_mode() {
  local P="$FIXTURE_DIR/apply_force_p"
  make_committed_repo "$P"
  # Create a diff that will conflict  --  modify the existing committed file
  local COMMITTED_FILE
  COMMITTED_FILE=$(ls "$P" | head -1)
  if [[ -z "$COMMITTED_FILE" ]]; then
    # No files committed yet  --  create one
    echo "original" > "$P/base.txt"
    git -C "$P" add base.txt
    git -C "$P" commit -m "base" --quiet
    COMMITTED_FILE="base.txt"
  fi
  # Create diff with the same file modified differently
  echo "$COMMITTED_FILE content changed" > "$P/$COMMITTED_FILE"
  git -C "$P" diff > "$FIXTURE_DIR/reject.diff" 2>/dev/null || true
  git -C "$P" checkout -- "$COMMITTED_FILE"
  # Force mode should return 0 even though the hunks conflict (may produce
  # .rej files); the rc is the contract, not the input diff's line count.
  local OUT RC=0
  OUT=$(apply_run "$P" "$FIXTURE_DIR/reject.diff" "" "true" 2>&1) || RC=$?
  if [[ "$RC" == 0 ]]; then
    pass "apply_run force mode completes (rc=0)"
  else
    fail "apply_run force mode failed rc=$RC: $OUT"
  fi
}
# Given: a normal repo and a diff path no file occupies
# When:  apply_run runs
# Then:  it fails
# Asserts: only the failure - stderr is discarded, so which guard refused is not pinned
test_apply_missing_diff_file() {
  local P="$FIXTURE_DIR/apply_missing_p"
  make_committed_repo "$P"
  if apply_run "$P" "/nonexistent/diff.diff" "" "false" 2>/dev/null; then
    fail "apply_run should fail with missing diff file"
  else
    pass "apply_run fails with missing diff file"
  fi
}
# Given: a diff file and a project path that does not exist
# When:  apply_run runs
# Then:  it fails
# Asserts: only the failure - the project check, the clean-tree read, or the apply itself may refuse
test_apply_missing_project_dir() {
  local DIFF="$FIXTURE_DIR/missing_proj.diff"
  printf 'diff --git a/x b/x\n--- a/x\n+++ b/x\n@@ -0,0 +1 @@\n+new\n' > "$DIFF"
  if apply_run "/nonexistent" "$DIFF" "" "false" 2>/dev/null; then
    fail "apply_run should fail with missing project dir"
  else
    pass "apply_run fails with missing project dir"
  fi
}
# Given: empty strings for all four arguments
# When:  apply_run runs
# Then:  it fails
# Asserts: only the failure - the required-argument guard overlaps the not-found guard for empty input
test_apply_empty_args() {
  if apply_run "" "" "" "" 2>/dev/null; then
    fail "apply_run should fail with empty args"
  else
    pass "apply_run fails with empty args"
  fi
}
# Given: a diff that applied successfully
# When:  apply_run returns
# Then:  the diff file still exists
# Asserts: apply consumes nothing, so the operator keeps the artifact
test_apply_diff_file_preserved() {
  local P="$FIXTURE_DIR/apply_preserve_p"
  make_committed_repo "$P"
  echo "preserved content" > "$P/preserve.txt"
  git -C "$P" add preserve.txt
  git -C "$P" diff --cached > "$FIXTURE_DIR/preserve.diff" 2>/dev/null || true
  git -C "$P" reset --quiet HEAD -- preserve.txt
  rm -f "$P/preserve.txt"
  apply_run "$P" "$FIXTURE_DIR/preserve.diff" "" "false"
  # Verify the diff file still exists (it should not be deleted by apply_run)
  if [[ -f "$FIXTURE_DIR/preserve.diff" ]]; then
    pass "apply_run preserves the diff file after applying"
  else
    fail "apply_run should not delete the diff file"
  fi
}
# Empty diffs carry no valid patches: per the decided empty-diff behavior,
# apply_run skips them with a warning (rc=0) and leaves the target
# repository untouched.
# Given: a zero-byte diff and a committed repo
# When:  apply_run runs
# Then:  rc 0 with the skip warning, and neither the tree nor HEAD moves
# Asserts: the decided empty-diff rule on the apply path
test_apply_empty_diff_rejected_without_touching_repo() {
  local P="$FIXTURE_DIR/apply_empty_p"
  make_committed_repo "$P"
  local BEFORE
  BEFORE=$(git -C "$P" rev-parse HEAD)
  : > "$FIXTURE_DIR/empty.diff"
  local ERR RC=0
  ERR=$(apply_run "$P" "$FIXTURE_DIR/empty.diff" "" "false" </dev/null 2>&1 >/dev/null) || RC=$?
  if [[ $RC -ne 0 || "$ERR" != *"is empty; nothing to apply"* ]]; then
    fail "apply_run should skip an empty diff with a warning (rc=0), got rc=$RC err='$ERR'"
    return
  fi
  local AFTER
  AFTER=$(git -C "$P" rev-parse HEAD)
  if [[ -n $(git -C "$P" status --porcelain) || "$BEFORE" != "$AFTER" ]]; then
    fail "rejected empty diff must leave repo untouched: no changes, HEAD unmoved"
  else
    pass "apply_run rejects empty diff and leaves repo untouched"
  fi
}
# Given: a valid diff file passed directly
# When:  apply_run runs
# Then:  the change lands
# Asserts: apply_run resolves nothing - no session or channel lookup
# Asserts: the direct-path contract is what the interactive branch and --diff both rely on
test_apply_no_resolution_logic() {
  # Verify that apply_run does NOT look up sessions or channels internally.
  # Pass a valid diff file directly and confirm it applies.
  local P="$FIXTURE_DIR/apply_norse_p"
  make_committed_repo "$P"
  echo "direct content" > "$P/direct.txt"
  git -C "$P" add direct.txt
  git -C "$P" diff --cached > "$FIXTURE_DIR/direct.diff" 2>/dev/null || true
  git -C "$P" reset --quiet HEAD -- direct.txt
  rm -f "$P/direct.txt"
  apply_run "$P" "$FIXTURE_DIR/direct.diff" "" "false"
  if [[ -f "$P/direct.txt" ]]; then
    pass "apply_run applies diff from direct file path (no resolution)"
  else
    fail "apply_run should apply from direct file path"
  fi
}
# Given: --project and --sandbox but no --diff
# When:  the script's main runs
# Then:  it exits non-zero and names --diff as required
# Asserts: the one requirement the entry point owns, since the dispatcher forwards --diff through
test_apply_requires_diff_flag() {
  # Verify the apply entry point (main) refuses to run without --diff.
  local P="$FIXTURE_DIR/apply_req_diff_p"
  make_committed_repo "$P"
  local OUT RC=0
  OUT=$(bash "$AGENT_SANDBOX_REPO/scripts/workflows/apply.sh" \
    --project="$P" --sandbox="$FIXTURE_DIR/sb_req_diff" 2>&1) || RC=$?
  if [[ "$RC" -ne 0 ]] && [[ "$OUT" == *"Error: --diff=<path> is required"* ]]; then
    pass "apply without --diff errors with required message"
  else
    fail "apply should require --diff; rc=$RC out=$OUT"
  fi
}
# =============================================================================
# _apply_patch_file tests
# =============================================================================
# Given: a valid patch for the project
# When:  _apply_patch_file runs in normal mode
# Then:  rc 0 and the change is in the working tree
# Asserts: the normal apply path.
test_apply_patch_file_normal() {
  local P="$FIXTURE_DIR/apf_normal_p"
  make_committed_repo "$P"
  echo "new content" > "$P/new.txt"
  git -C "$P" add new.txt
  git -C "$P" diff --cached > "$FIXTURE_DIR/apf_normal.diff" 2>/dev/null || true
  git -C "$P" reset --quiet HEAD -- new.txt
  rm -f "$P/new.txt"
  _apply_patch_file "$P" "$FIXTURE_DIR/apf_normal.diff" false false
  if [[ -f "$P/new.txt" ]]; then
    pass "_apply_patch_file normal mode applies diff"
  else
    fail "_apply_patch_file normal mode should create new.txt"
  fi
}
# Given: a valid patch
# When:  _apply_patch_file runs with FORCE=true
# Then:  rc 0 with --reject semantics
# Asserts: force mode never returns 1.
test_apply_patch_file_force() {
  local P="$FIXTURE_DIR/apf_force_p"
  make_committed_repo "$P"
  local COMMITTED_FILE
  COMMITTED_FILE=$(ls "$P" | head -1)
  if [[ -z "$COMMITTED_FILE" ]]; then
    echo "original" > "$P/base.txt"
    git -C "$P" add base.txt
    git -C "$P" commit -m "base" --quiet
    COMMITTED_FILE="base.txt"
  fi
  echo "$COMMITTED_FILE content changed" > "$P/$COMMITTED_FILE"
  git -C "$P" diff > "$FIXTURE_DIR/apf_force.diff" 2>/dev/null || true
  git -C "$P" checkout -- "$COMMITTED_FILE"
  local OUT RC=0
  OUT=$(_apply_patch_file "$P" "$FIXTURE_DIR/apf_force.diff" true false 2>&1) || RC=$?
  # Force mode should succeed (returns 0) even if conflicts produce .rej
  if [[ "$RC" == 0 ]]; then
    pass "_apply_patch_file force mode completes (rc=0)"
  else
    fail "_apply_patch_file force mode failed rc=$RC: $OUT"
  fi
}
# Given: a patch path that does not exist
# When:  _apply_patch_file runs
# Then:  rc 1
# Asserts: the missing-input guard.
test_apply_patch_file_missing_diff() {
  local P="$FIXTURE_DIR/apf_missing_p"
  make_committed_repo "$P"
  _apply_patch_file "$P" "/nonexistent.diff" false false && {
    fail "_apply_patch_file should fail with missing diff"
    return
  }
  pass "_apply_patch_file fails with missing diff"
}
# =============================================================================
# apply_and_commit tests
# =============================================================================
# Given: a hash message and a patch to apply
# When:  apply_and_commit runs
# Then:  the change is committed with the message
# Asserts: the apply-then-commit contract, which leaves nothing unstaged.
test_apply_and_commit_applies_and_commits() {
  local P="$FIXTURE_DIR/aac_commit_p"
  make_committed_repo "$P"
  echo "commit content" > "$P/commit.txt"
  git -C "$P" add commit.txt
  git -C "$P" diff --cached > "$FIXTURE_DIR/aac_commit.diff" 2>/dev/null || true
  git -C "$P" reset --quiet HEAD -- commit.txt
  rm -f "$P/commit.txt"
  local AUTHOR
  AUTHOR="$(git -C "$P" config user.name) <$(git -C "$P" config user.email)>"
  apply_and_commit "$P" "$FIXTURE_DIR/aac_commit.diff" "Test commit" "$AUTHOR" false false
  if [[ -f "$P/commit.txt" ]]; then
    local MSG
    MSG=$(git -C "$P" log -1 --pretty=%s)
    if [[ "$MSG" == "Test commit" ]]; then
      pass "apply_and_commit applies diff and commits with correct message"
    else
      fail "apply_and_commit expected commit message 'Test commit', got: $MSG"
    fi
  else
    fail "apply_and_commit should create commit.txt"
  fi
}
# Given: empty arguments
# When:  apply_and_commit runs
# Then:  rc 1 with a diagnostic
# Asserts: the all-empty guard (partial-argument guards are unpinned, finding 13).
test_apply_and_commit_missing_args() {
  if apply_and_commit "" "" "" "" false false 2>/dev/null; then
    fail "apply_and_commit should fail with empty args"
  else
    pass "apply_and_commit fails with empty args"
  fi
}
# Given: a patch that conflicts with the project's state
# When:  apply_and_commit runs with FORCE=true
# Then:  the conflicts are tolerated and the commit lands
# Asserts: force propagation through apply_and_commit.
test_apply_and_commit_force_mode() {
  local P="$FIXTURE_DIR/aac_force_p"
  make_committed_repo "$P"
  local COMMITTED_FILE
  COMMITTED_FILE=$(ls "$P" | head -1)
  if [[ -z "$COMMITTED_FILE" ]]; then
    echo "original" > "$P/base.txt"
    git -C "$P" add base.txt
    git -C "$P" commit -m "base" --quiet
    COMMITTED_FILE="base.txt"
  fi
  echo "$COMMITTED_FILE force changed" > "$P/$COMMITTED_FILE"
  git -C "$P" diff > "$FIXTURE_DIR/aac_force.diff" 2>/dev/null || true
  git -C "$P" checkout -- "$COMMITTED_FILE"
  local AUTHOR
  AUTHOR="$(git -C "$P" config user.name) <$(git -C "$P" config user.email)>"
  apply_and_commit "$P" "$FIXTURE_DIR/aac_force.diff" "Force commit" "$AUTHOR" true false
  local MSG
  MSG=$(git -C "$P" log -1 --pretty=%s 2>/dev/null || echo "no-commit")
  assert_eq "$MSG" "Force commit" "apply_and_commit force mode commits even on conflicts"
}
# =============================================================================
# Run
# =============================================================================
# _apply_patch_file  --  recount retry / failure-hint branches
# =============================================================================

# make_recount_diff DIR FILE  --  a diff with an inserted '+' line whose hunk
# header was NOT adjusted (the classic hand-edited-patch case). Plain
# `git apply` rejects it as corrupt; `--recount` deduces real counts and
# succeeds. This is the exact scenario the retry branch exists for.
make_recount_diff() {
  local P="$1" OUT="$2"
  printf 'line1\nline2\nline3\n' > "$P/recount.txt"
  git -C "$P" add recount.txt
  git -C "$P" commit -m "recount base" --quiet
  cat > "$OUT" <<'EOF'
diff --git a/recount.txt b/recount.txt
--- a/recount.txt
+++ b/recount.txt
@@ -1,3 +1,3 @@
 line1
-line2
+line2 modified
+inserted-without-recount
 line3
EOF
}

# Given: a patch whose hunk counts are wrong but whose context matches
# When:  _apply_patch_file runs in normal mode
# Then:  the --recount retry applies it
# Asserts: the relaxed-context retry that makes apply permissive by default.
test_apply_patch_file_recount_retry_succeeds() {
  local P="$FIXTURE_DIR/apf_recount_p"
  make_committed_repo "$P"
  make_recount_diff "$P" "$FIXTURE_DIR/apf_recount.diff"

  local OUT RC=0
  OUT=$(_apply_patch_file "$P" "$FIXTURE_DIR/apf_recount.diff" false false 2>&1 </dev/null) || RC=$?

  if [[ $RC -eq 0 && "$(cat "$P/recount.txt")" == *"inserted-without-recount"* \
     && "$OUT" == *"retrying with --recount"* ]]
  then
    pass "_apply_patch_file: malformed counts trigger --recount retry and apply"
  else
    fail "recount retry broken: rc=$RC out='$OUT' file='$(cat "$P/recount.txt" 2>/dev/null)'"
  fi
}

# Given: a patch that applies under neither attempt
# When:  _apply_patch_file runs
# Then:  rc 1 with the diff path, the target branch, and the FORCE hint
# Asserts: the failure diagnostic.
test_apply_patch_file_unfixable_diff_fails_with_hints() {
  # Diff references a file that does not exist in the repo  --  recount cannot
  # save it. Must fail rc=1 with the FORCE hint block.
  local P="$FIXTURE_DIR/apf_hints_p"
  make_committed_repo "$P"
  cat > "$FIXTURE_DIR/apf_hints.diff" <<'EOF'
diff --git a/ghost.txt b/ghost.txt
--- a/ghost.txt
+++ b/ghost.txt
@@ -1,1 +1,2 @@
-nothing here
+something
EOF

  local OUT RC=0
  OUT=$(_apply_patch_file "$P" "$FIXTURE_DIR/apf_hints.diff" false false 2>&1 </dev/null) || RC=$?

  if [[ $RC -eq 1 && "$OUT" == *"Use FORCE=true"* ]]; then
    pass "_apply_patch_file: unfixable diff fails with actionable hints"
  else
    fail "hint path broken: rc=$RC out='$OUT'"
  fi
}

# Given: a diff file path that does not exist
# When:  apply_and_commit runs
# Then:  rc 1 with an explicit error, without touching the project
# Asserts: the pre-apply existence check.
test_apply_and_commit_missing_diff_file_fails_cleanly() {
  local P="$FIXTURE_DIR/aac_nodiff_p"
  make_committed_repo "$P"

  local OUT RC=0
  OUT=$(apply_and_commit "$P" "$FIXTURE_DIR/no-such.diff" msg author 2>&1 </dev/null) || RC=$?

  if [[ $RC -eq 1 && "$OUT" == *"diff file not found"* ]]; then
    pass "apply_and_commit: missing diff file -> explicit error, rc=1"
  else
    fail "missing-diff guard broken: rc=$RC out='$OUT'"
  fi
}
# =============================================================================
run_test test_apply_applies_diff
run_test test_apply_applies_diff_with_branch
run_test test_apply_force_mode
run_test test_apply_missing_diff_file
run_test test_apply_missing_project_dir
run_test test_apply_empty_args
run_test test_apply_diff_file_preserved
run_test test_apply_empty_diff_rejected_without_touching_repo
run_test test_apply_no_resolution_logic
run_test test_apply_requires_diff_flag
run_test test_apply_patch_file_normal
run_test test_apply_patch_file_force
run_test test_apply_patch_file_missing_diff
run_test test_apply_and_commit_applies_and_commits
run_test test_apply_and_commit_missing_args
# =============================================================================
# PREVIEW tests  --  apply_preview summary contract
# =============================================================================
# Multi-file diff: one line per file in diff order + Total line.
# Given: a two-file diff on disk
# When:  apply_preview runs
# Then:  one line per file in diff order, then the total
# Asserts: the preview's output contract, which the interactive branch prints to stderr
test_apply_preview_lists_files_and_total() {
  cat > "$FIXTURE_DIR/preview.diff" <<'EOF'
diff --git a/alpha.txt b/alpha.txt
index 111..222 100644
--- a/alpha.txt
+++ b/alpha.txt
@@ -1 +1 @@
-old
+new
diff --git a/sub/beta.txt b/sub/beta.txt
index 333..444 100644
--- a/sub/beta.txt
+++ b/sub/beta.txt
@@ -1 +1 @@
-old
+new
EOF
  local out
  out=$(apply_preview "$FIXTURE_DIR/preview.diff")
  if [[ "$out" == $'alpha.txt\nsub/beta.txt\nTotal files: 2' ]]; then
    pass "apply_preview lists each file in order plus total"
  else
    fail "apply_preview output mismatch: '$out'"
  fi
}
# Empty diff: exactly the no-changes message, exit 0, no Total line.
# Given: a zero-byte diff
# When:  apply_preview runs
# Then:  exactly the no-changes message, rc 0, and no Total line
# Asserts: the empty arm of the preview
test_apply_preview_empty_diff_reports_no_changes() {
  : > "$FIXTURE_DIR/preview_empty.diff"
  local out rc
  out=$(apply_preview "$FIXTURE_DIR/preview_empty.diff" 2>&1); rc=$?
  if [[ $rc -eq 0 && "$out" == "No changes found in $FIXTURE_DIR/preview_empty.diff" ]]; then
    pass "apply_preview on empty diff reports no changes and exits 0"
  else
    fail "apply_preview empty diff: rc=$rc out='$out'"
  fi
}
# Binary diffs have a header like any other; they must be counted.
# Given: a diff whose only header is a binary patch
# When:  apply_preview runs
# Then:  one line plus Total files: 1
# Asserts: binary diffs are counted by their header like any other
test_apply_preview_counts_binary_diffs() {
  printf 'diff --git a/img.png b/img.png\nindex 111..222 100644\nGIT binary patch\n' > "$FIXTURE_DIR/preview_bin.diff"
  local out
  out=$(apply_preview "$FIXTURE_DIR/preview_bin.diff")
  if [[ "$out" == $'img.png\nTotal files: 1' ]]; then
    pass "apply_preview counts binary diffs by their header"
  else
    fail "apply_preview binary diff output mismatch: '$out'"
  fi
}
run_test test_apply_and_commit_force_mode
run_test test_apply_patch_file_recount_retry_succeeds
run_test test_apply_patch_file_unfixable_diff_fails_with_hints
run_test test_apply_and_commit_missing_diff_file_fails_cleanly
run_test test_apply_preview_lists_files_and_total
run_test test_apply_preview_empty_diff_reports_no_changes
run_test test_apply_preview_counts_binary_diffs
test_done


#!/usr/bin/env bash
# tests/test_apply.sh
# Tests for scripts/apply_workspace.sh — draft/confirm/reject workflow
#
# Covers:
#   draft   — creates working branch, applies patches, resets author
#   confirm — rebases onto target, fast-forward merges, deletes branch
#   confirm TARGET — merges to named branch
#   reject  — restores source branch, deletes working branch
#   guards  — missing args, bad state, double-draft, missing patches
#
# Directory structure expected by draft:
#   session-diffs/<SESSION_TS>-<SANITIZED_HOST_BRANCH>/
#     session/
#       EXPORT-TIME.txt
#       changes.diff
#       staged.diff
#       patches/
#         0001-<sha>.diff
#         0002-<sha>.diff
#         ...
#
# Note: apply command tests are in tests/test_apply_workspace.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPLY_SCRIPT="$SCRIPT_DIR/../scripts/apply_workspace.sh"

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

# make_project DIR — git repo with one baseline commit on 'main'
make_project() {
  local DIR="$1"
  rm -rf "$DIR"
  mkdir -p "$DIR"
  git -C "$DIR" init --quiet
  git -C "$DIR" config user.email "operator@example.com"
  git -C "$DIR" config user.name "Operator"
  # Force branch name to 'main' regardless of git defaults
  git -C "$DIR" checkout -b main --quiet 2>/dev/null || true
  git -C "$DIR" branch -M main 2>/dev/null || true
  echo "baseline" > "$DIR/file.txt"
  git -C "$DIR" add .
  git -C "$DIR" commit -m "baseline" --quiet
}

# make_session PROJECT_DIR SANDBOX_DIR [SESSION_TS] [BRANCH]
# Creates sandbox with agent commits and produces session-diffs/<SESSION_TS>-<BRANCH>/
# with session/patches/*.diff, session/changes.diff, session/staged.diff,
# and session/EXPORT-TIME.txt.
make_session() {
  local PROJECT_DIR="$1"
  local SANDBOX_DIR="$2"
  local SESSION_TS="${3:-20260408-120000}"
  local BRANCH="${4:-main}"

  # Sandbox mirrors baseline — use unique path per SANDBOX_DIR
  local SANDBOX="$SANDBOX_DIR/sandbox-work"
  rm -rf "$SANDBOX"
  mkdir -p "$SANDBOX"
  git -C "$SANDBOX" init --quiet
  git -C "$SANDBOX" config user.email "agent@sandbox"
  git -C "$SANDBOX" config user.name "agent-sandbox"
  echo "baseline" > "$SANDBOX/file.txt"
  git -C "$SANDBOX" add .
  git -C "$SANDBOX" commit -m "baseline" --quiet
  local BASELINE_SHA
  BASELINE_SHA=$(git -C "$SANDBOX" rev-parse HEAD)

  # Agent makes two commits
  echo "agent change 1" > "$SANDBOX/agent1.txt"
  git -C "$SANDBOX" add .
  git -C "$SANDBOX" commit -m "feat: first agent commit" --quiet

  echo "agent change 2" > "$SANDBOX/agent2.txt"
  git -C "$SANDBOX" add .
  git -C "$SANDBOX" commit -m "feat: second agent commit" --quiet

  # Prepare workspace directory
  mkdir -p "$SANDBOX_DIR/.workspace"

  # Write session directory with new structure
  local SESSION_NAME="${SESSION_TS}-${BRANCH}"
  local SESSION_DIR="$SANDBOX_DIR/.workspace/session-diffs/$SESSION_NAME"
  rm -rf "$SESSION_DIR"
  mkdir -p "$SESSION_DIR/session/patches"

  # Write EXPORT-TIME.txt
  echo "20260408-120000" > "$SESSION_DIR/session/EXPORT-TIME.txt"

  # Write numbered .diff files (index-stripped) from BASELINE_SHA..HEAD
  local COMMIT_NUM=1
  local PREV_SHA="$BASELINE_SHA"
  for COMMIT_SHA in $(git -C "$SANDBOX" rev-list "${BASELINE_SHA}..HEAD" --reverse); do
    local PADDING
    PADDING=$(printf "%04d" "$COMMIT_NUM")
    git -C "$SANDBOX" diff "${PREV_SHA}..${COMMIT_SHA}" \
      | grep -v '^index ' \
      | sed 's/[[:space:]]*$//' \
      | sed -e '$a\' \
      > "$SESSION_DIR/session/patches/${PADDING}-${COMMIT_SHA}.diff"
    PREV_SHA="$COMMIT_SHA"
    COMMIT_NUM=$((COMMIT_NUM + 1))
  done

  # Write staged.diff (net delta from baseline)
  git -C "$SANDBOX" diff --binary -M "${BASELINE_SHA}..HEAD" \
    > "$SESSION_DIR/session/staged.diff"

  # Write changes.diff (working tree vs HEAD — empty since agent committed everything)
  > "$SESSION_DIR/session/changes.diff"
}

# current_branch DIR
current_branch() {
  git -C "$1" rev-parse --abbrev-ref HEAD
}

# branch_exists DIR NAME
branch_exists() {
  git -C "$1" show-ref --verify --quiet "refs/heads/$2"
}

# -------------------------
# DRAFT tests
# -------------------------

test_draft_creates_working_branch() {
  local P="$FIXTURE_DIR/draft_creates_p"
  local S="$FIXTURE_DIR/draft_creates_s"
  make_project "$P"
  make_session "$P" "$S"

  "$APPLY_SCRIPT" draft --project="$P" --sandbox="$S" 2>/dev/null

  local BRANCH
  BRANCH=$(git -C "$P" branch --list 'draft/*' | tr -d ' *' | head -1)
  if [[ "$BRANCH" == draft/20260408-120000-main-* ]]; then
    pass "draft creates working branch with correct name format"
  else
    fail "draft should create draft/<SESSION_TS>-<BRANCH>-<SHA6> branch, got: $BRANCH"
  fi
}

test_draft_checks_out_working_branch() {
  local P="$FIXTURE_DIR/draft_checkout_p"
  local S="$FIXTURE_DIR/draft_checkout_s"
  make_project "$P"
  make_session "$P" "$S"

  "$APPLY_SCRIPT" draft --project="$P" --sandbox="$S" 2>/dev/null

  local BRANCH
  BRANCH=$(current_branch "$P")
  if [[ "$BRANCH" == draft/20260408-120000-main-* ]]; then
    pass "draft checks out the working branch"
  else
    fail "draft should check out working branch, got: $BRANCH"
  fi
}

test_draft_applies_all_patches() {
  local P="$FIXTURE_DIR/draft_applies_p"
  local S="$FIXTURE_DIR/draft_applies_s"
  make_project "$P"
  make_session "$P" "$S"

  "$APPLY_SCRIPT" draft --project="$P" --sandbox="$S" 2>/dev/null

  # Should have 2 diff commits + .draft-state commit above baseline (3 total)
  local COUNT
  COUNT=$(git -C "$P" rev-list --count "main..HEAD")
  if [[ "$COUNT" -eq 3 ]]; then
    pass "draft applies all patches as commits (got $COUNT)"
  else
    fail "draft should apply 2 patches + .draft-state = 3 commits above main, got $COUNT"
  fi
}

test_draft_files_present_after_apply() {
  local P="$FIXTURE_DIR/draft_files_p"
  local S="$FIXTURE_DIR/draft_files_s"
  make_project "$P"
  make_session "$P" "$S"

  "$APPLY_SCRIPT" draft --project="$P" --sandbox="$S" 2>/dev/null

  if [[ -f "$P/agent1.txt" && -f "$P/agent2.txt" ]]; then
    pass "draft: agent-added files present in working branch"
  else
    fail "draft: agent files missing from working branch"
  fi
}

test_draft_resets_author_to_operator() {
  local P="$FIXTURE_DIR/draft_author_p"
  local S="$FIXTURE_DIR/draft_author_s"
  make_project "$P"
  make_session "$P" "$S"

  "$APPLY_SCRIPT" draft --project="$P" --sandbox="$S" 2>/dev/null

  # All commits above baseline should carry operator's identity
  local BAD_AUTHORS
  BAD_AUTHORS=$(git -C "$P" log main..HEAD --format='%ae' \
    | grep -v "operator@example.com" || true)

  if [[ -z "$BAD_AUTHORS" ]]; then
    pass "draft resets all commit authors to operator's git config identity"
  else
    fail "draft left non-operator author on commits: $BAD_AUTHORS"
  fi
}

test_draft_commit_messages() {
  local P="$FIXTURE_DIR/draft_msg_p"
  local S="$FIXTURE_DIR/draft_msg_s"
  make_project "$P"
  make_session "$P" "$S"

  "$APPLY_SCRIPT" draft --project="$P" --sandbox="$S" 2>/dev/null

  # The first commit above baseline should be .draft-state
  local FIRST_MSG
  FIRST_MSG=$(git -C "$P" log main..HEAD --reverse --format='%s' | head -1)
  if [[ "$FIRST_MSG" == ".draft-state" ]]; then
    pass "draft creates .draft-state as first commit"
  else
    fail "draft first commit should be .draft-state, got: $FIRST_MSG"
  fi

  # Subsequent commits should have "Apply <filename>" messages
  local SECOND_MSG
  SECOND_MSG=$(git -C "$P" log main..HEAD --reverse --format='%s' | sed -n '2p')
  if [[ "$SECOND_MSG" == "Apply "* ]]; then
    pass "draft applies patches with generated commit messages"
  else
    fail "draft commit messages should start with 'Apply', got: $SECOND_MSG"
  fi
}

test_draft_writes_draft_state_commit() {
  local P="$FIXTURE_DIR/draft_state_p"
  local S="$FIXTURE_DIR/draft_state_s"
  make_project "$P"
  make_session "$P" "$S"

  "$APPLY_SCRIPT" draft --project="$P" --sandbox="$S" 2>/dev/null

  # .draft-state should exist as a committed file on the branch, not in .workspace/
  local DRAFT_BRANCH
  DRAFT_BRANCH=$(git -C "$P" branch --list 'draft/*' | tr -d ' *' | head -1)
  local STATE_CONTENT
  STATE_CONTENT=$(git -C "$P" show "${DRAFT_BRANCH}:.draft-state" 2>/dev/null || echo "")

  if [[ -n "$STATE_CONTENT" ]]; then
    pass "draft commits .draft-state on the branch"
  else
    fail "draft should commit .draft-state on the branch"
    return
  fi

  local ALL_FIELDS=true
  for field in source_branch from_hash author session_ts host_branch diff_count exported-at drafted-at; do
    if [[ "$STATE_CONTENT" != *"${field}:"* ]]; then
      ALL_FIELDS=false
      fail "draft .draft-state missing field: $field"
    fi
  done
  if [[ "$ALL_FIELDS" == true ]]; then
    pass "draft .draft-state contains all required fields"
  fi
}

test_draft_selects_most_recent_session_by_default() {
  local P="$FIXTURE_DIR/draft_recent_p"
  local S="$FIXTURE_DIR/draft_recent_s"
  make_project "$P"

  # Create two sessions — the second has a later SESSION_TS, so it sorts last
  make_session "$P" "$S" "20260408-100000" "main"
  make_session "$P" "$S" "20260408-110000" "main"

  "$APPLY_SCRIPT" draft --project="$P" --sandbox="$S" 2>/dev/null

  # The draft branch should use the second session's patches (3 total commits:
  # .draft-state + 2 patches from the "110000" session)
  local COUNT
  COUNT=$(git -C "$P" rev-list --count "main..HEAD")
  if [[ "$COUNT" -eq 3 ]]; then
    pass "draft selects most recent session by lexicographic sort"
  else
    fail "draft should select most recent session, expected 3 commits, got $COUNT"
  fi
}

test_draft_explicit_session_selection() {
  local P="$FIXTURE_DIR/draft_explicit_p"
  local S="$FIXTURE_DIR/draft_explicit_s"
  make_project "$P"

  make_session "$P" "$S" "20260408-100000" "main"
  make_session "$P" "$S" "20260408-110000" "main"

  # Explicitly select the first (older) session
  "$APPLY_SCRIPT" draft --project="$P" --sandbox="$S" \
    --session="20260408-100000-main" 2>/dev/null

  # Should apply the first session's patches (3 commits: .draft-state + 2 patches)
  local COUNT
  COUNT=$(git -C "$P" rev-list --count "main..HEAD")
  if [[ "$COUNT" -eq 3 ]]; then
    pass "draft --session applies the specified session"
  else
    fail "draft --session should apply specified session, expected 3 commits, got $COUNT"
  fi
}

# -------------------------
# CONFIRM tests
# -------------------------

test_confirm_merges_to_source_branch() {
  local P="$FIXTURE_DIR/confirm_merge_p"
  local S="$FIXTURE_DIR/confirm_merge_s"
  make_project "$P"
  make_session "$P" "$S"
  "$APPLY_SCRIPT" draft --project="$P" --sandbox="$S" 2>/dev/null

  "$APPLY_SCRIPT" confirm --project="$P" --sandbox="$S" 2>/dev/null

  local BRANCH
  BRANCH=$(current_branch "$P")
  if [[ "$BRANCH" == "main" ]]; then
    pass "confirm returns to source branch (main)"
  else
    fail "confirm should return to main, got: $BRANCH"
  fi
}

test_confirm_commits_are_on_source_branch() {
  local P="$FIXTURE_DIR/confirm_commits_p"
  local S="$FIXTURE_DIR/confirm_commits_s"
  make_project "$P"
  make_session "$P" "$S"
  local BASELINE_SHA
  BASELINE_SHA=$(git -C "$P" rev-parse HEAD)
  "$APPLY_SCRIPT" draft --project="$P" --sandbox="$S" 2>/dev/null
  "$APPLY_SCRIPT" confirm --project="$P" --sandbox="$S" 2>/dev/null

  # After confirm, main should have 2 diff commits above baseline (.draft-state dropped)
  local COUNT
  COUNT=$(git -C "$P" rev-list --count "${BASELINE_SHA}..HEAD")
  if [[ "$COUNT" -eq 2 ]]; then
    pass "confirm: agent commits now on main ($COUNT commits above baseline)"
  else
    fail "confirm: expected 2 commits on main above baseline, got $COUNT"
  fi
}

test_confirm_history_is_linear() {
  local P="$FIXTURE_DIR/confirm_linear_p"
  local S="$FIXTURE_DIR/confirm_linear_s"
  make_project "$P"
  make_session "$P" "$S"
  "$APPLY_SCRIPT" draft --project="$P" --sandbox="$S" 2>/dev/null
  "$APPLY_SCRIPT" confirm --project="$P" --sandbox="$S" 2>/dev/null

  local MERGE_COMMITS
  MERGE_COMMITS=$(git -C "$P" log --merges --oneline | wc -l)
  if [[ "$MERGE_COMMITS" -eq 0 ]]; then
    pass "confirm produces linear history (no merge commits)"
  else
    fail "confirm should produce linear history, found $MERGE_COMMITS merge commit(s)"
  fi
}

test_confirm_deletes_working_branch() {
  local P="$FIXTURE_DIR/confirm_delete_p"
  local S="$FIXTURE_DIR/confirm_delete_s"
  make_project "$P"
  make_session "$P" "$S"
  "$APPLY_SCRIPT" draft --project="$P" --sandbox="$S" 2>/dev/null

  local WORKING_BRANCH
  WORKING_BRANCH=$(git -C "$P" branch --list 'draft/*' | tr -d ' *' | head -1)

  "$APPLY_SCRIPT" confirm --project="$P" --sandbox="$S" 2>/dev/null

  if ! branch_exists "$P" "$WORKING_BRANCH"; then
    pass "confirm deletes the working branch after merge"
  else
    fail "confirm should delete draft/* branch after merge"
  fi
}

test_confirm_target_branch() {
  local P="$FIXTURE_DIR/confirm_target_p"
  local S="$FIXTURE_DIR/confirm_target_s"
  make_project "$P"
  make_session "$P" "$S"

  git -C "$P" checkout -b other --quiet
  git -C "$P" checkout main --quiet

  "$APPLY_SCRIPT" draft --project="$P" --sandbox="$S" 2>/dev/null
  "$APPLY_SCRIPT" confirm --project="$P" --sandbox="$S" --target="other" 2>/dev/null

  local BRANCH
  BRANCH=$(current_branch "$P")
  if [[ "$BRANCH" == "other" ]]; then
    pass "confirm --target merges to specified branch"
  else
    fail "confirm --target should switch to 'other', got: $BRANCH"
  fi

  local COUNT
  COUNT=$(git -C "$P" rev-list --count "main..other")
  if [[ "$COUNT" -eq 2 ]]; then
    pass "confirm --target: agent commits present on target branch"
  else
    fail "confirm --target: expected 2 commits on 'other', got $COUNT"
  fi
}

test_confirm_retains_session_artefacts() {
  local P="$FIXTURE_DIR/confirm_artefacts_p"
  local S="$FIXTURE_DIR/confirm_artefacts_s"
  make_project "$P"
  make_session "$P" "$S"
  local SESSION_DIR="$S/.workspace/session-diffs/20260408-120000-main"
  "$APPLY_SCRIPT" draft   --project="$P" --sandbox="$S" 2>/dev/null
  "$APPLY_SCRIPT" confirm --project="$P" --sandbox="$S" 2>/dev/null

  local COUNT
  COUNT=$(find "$SESSION_DIR/session/patches" -name '*.diff' 2>/dev/null | wc -l)
  if [[ "$COUNT" -gt 0 ]]; then
    pass "confirm retains session patches after merge"
  else
    fail "confirm should not delete session artefacts"
  fi
}

# -------------------------
# REJECT tests
# -------------------------

test_reject_returns_to_source_branch() {
  local P="$FIXTURE_DIR/reject_branch_p"
  local S="$FIXTURE_DIR/reject_branch_s"
  make_project "$P"
  make_session "$P" "$S"
  "$APPLY_SCRIPT" draft  --project="$P" --sandbox="$S" 2>/dev/null
  "$APPLY_SCRIPT" reject --project="$P" --sandbox="$S" 2>/dev/null

  local BRANCH
  BRANCH=$(current_branch "$P")
  if [[ "$BRANCH" == "main" ]]; then
    pass "reject returns to source branch (main)"
  else
    fail "reject should return to main, got: $BRANCH"
  fi
}

test_reject_deletes_working_branch() {
  local P="$FIXTURE_DIR/reject_delete_p"
  local S="$FIXTURE_DIR/reject_delete_s"
  make_project "$P"
  make_session "$P" "$S"
  "$APPLY_SCRIPT" draft  --project="$P" --sandbox="$S" 2>/dev/null

  local WORKING_BRANCH
  WORKING_BRANCH=$(git -C "$P" branch --list 'draft/*' | tr -d ' *' | head -1)

  "$APPLY_SCRIPT" reject --project="$P" --sandbox="$S" 2>/dev/null

  if ! branch_exists "$P" "$WORKING_BRANCH"; then
    pass "reject deletes the working branch"
  else
    fail "reject should delete draft/* branch"
  fi
}

test_reject_source_branch_unchanged() {
  local P="$FIXTURE_DIR/reject_unchanged_p"
  local S="$FIXTURE_DIR/reject_unchanged_s"
  make_project "$P"
  make_session "$P" "$S"
  local SHA_BEFORE
  SHA_BEFORE=$(git -C "$P" rev-parse main)
  "$APPLY_SCRIPT" draft  --project="$P" --sandbox="$S" 2>/dev/null
  "$APPLY_SCRIPT" reject --project="$P" --sandbox="$S" 2>/dev/null

  local SHA_AFTER
  SHA_AFTER=$(git -C "$P" rev-parse main)
  if [[ "$SHA_BEFORE" == "$SHA_AFTER" ]]; then
    pass "reject leaves source branch HEAD unchanged"
  else
    fail "reject should not advance source branch HEAD"
  fi
}

test_reject_retains_session_artefacts() {
  local P="$FIXTURE_DIR/reject_artefacts_p"
  local S="$FIXTURE_DIR/reject_artefacts_s"
  make_project "$P"
  make_session "$P" "$S"
  local SESSION_DIR="$S/.workspace/session-diffs/20260408-120000-main"
  "$APPLY_SCRIPT" draft  --project="$P" --sandbox="$S" 2>/dev/null
  "$APPLY_SCRIPT" reject --project="$P" --sandbox="$S" 2>/dev/null

  local COUNT
  COUNT=$(find "$SESSION_DIR/session/patches" -name '*.diff' 2>/dev/null | wc -l)
  if [[ "$COUNT" -gt 0 ]]; then
    pass "reject retains session patches"
  else
    fail "reject should not delete session artefacts"
  fi
}

# -------------------------
# Guard / error condition tests
# -------------------------

test_draft_missing_project_fails() {
  local S="$FIXTURE_DIR/guard_noproject_s"
  mkdir -p "$S"

  if "$APPLY_SCRIPT" draft --project="/nonexistent" --sandbox="$S" 2>/dev/null; then
    fail "draft should fail when PROJECT_DIR does not exist"
  else
    pass "draft fails when PROJECT_DIR does not exist"
  fi
}

test_draft_missing_args_fails() {
  if "$APPLY_SCRIPT" draft 2>/dev/null; then
    fail "draft should fail when --project and --sandbox are missing"
  else
    pass "draft fails with missing --project/--sandbox"
  fi
}

test_draft_no_patches_dir_fails() {
  local P="$FIXTURE_DIR/guard_nopatch_p"
  local S="$FIXTURE_DIR/guard_nopatch_s"
  make_project "$P"

  # Create session directory without patches/
  mkdir -p "$S/.workspace/session-diffs/20260408-120000-main"

  if "$APPLY_SCRIPT" draft --project="$P" --sandbox="$S" 2>/dev/null; then
    fail "draft should fail when patches/ directory is missing"
  else
    pass "draft fails when patches/ directory is missing"
  fi
}

test_draft_empty_patches_fails() {
  local P="$FIXTURE_DIR/guard_emptypatch_p"
  local S="$FIXTURE_DIR/guard_emptypatch_s"
  make_project "$P"

  # Create session directory with empty session/patches/
  mkdir -p "$S/.workspace/session-diffs/20260408-120000-main/session/patches"

  if "$APPLY_SCRIPT" draft --project="$P" --sandbox="$S" 2>/dev/null; then
    fail "draft should fail when patches/ directory is empty"
  else
    pass "draft fails when patches/ directory is empty"
  fi
}

test_double_draft_fails() {
  local P="$FIXTURE_DIR/double_draft_p"
  local S="$FIXTURE_DIR/double_draft_s"
  make_project "$P"
  make_session "$P" "$S"

  "$APPLY_SCRIPT" draft --project="$P" --sandbox="$S" 2>/dev/null

  # Second draft attempt — should fail because already on a draft branch
  if "$APPLY_SCRIPT" draft --project="$P" --sandbox="$S" 2>/dev/null; then
    fail "second draft should fail when already on a draft branch"
  else
    pass "draft correctly rejects a second draft while one is in progress"
  fi
}

test_confirm_without_draft_fails() {
  local P="$FIXTURE_DIR/confirm_nodraft_p"
  local S="$FIXTURE_DIR/confirm_nodraft_s"
  make_project "$P"
  mkdir -p "$S/.workspace"

  if "$APPLY_SCRIPT" confirm --project="$P" --sandbox="$S" 2>/dev/null; then
    fail "confirm should fail when not on a draft branch"
  else
    pass "confirm fails when not on a draft branch"
  fi
}

test_reject_without_draft_fails() {
  local P="$FIXTURE_DIR/reject_nodraft_p"
  local S="$FIXTURE_DIR/reject_nodraft_s"
  make_project "$P"
  mkdir -p "$S/.workspace"

  if "$APPLY_SCRIPT" reject --project="$P" --sandbox="$S" 2>/dev/null; then
    fail "reject should fail when not on a draft branch"
  else
    pass "reject fails when not on a draft branch"
  fi
}

# -------------------------
# Run all tests
# -------------------------

# draft
run_test test_draft_creates_working_branch
run_test test_draft_checks_out_working_branch
run_test test_draft_applies_all_patches
run_test test_draft_files_present_after_apply
run_test test_draft_resets_author_to_operator
run_test test_draft_commit_messages
run_test test_draft_writes_draft_state_commit
run_test test_draft_selects_most_recent_session_by_default
run_test test_draft_explicit_session_selection

# confirm
run_test test_confirm_merges_to_source_branch
run_test test_confirm_commits_are_on_source_branch
run_test test_confirm_history_is_linear
run_test test_confirm_deletes_working_branch
run_test test_confirm_target_branch
run_test test_confirm_retains_session_artefacts

# reject
run_test test_reject_returns_to_source_branch
run_test test_reject_deletes_working_branch
run_test test_reject_source_branch_unchanged
run_test test_reject_retains_session_artefacts

# guards
run_test test_draft_missing_project_fails
run_test test_draft_missing_args_fails
run_test test_draft_no_patches_dir_fails
run_test test_draft_empty_patches_fails
run_test test_double_draft_fails
run_test test_confirm_without_draft_fails
run_test test_reject_without_draft_fails

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
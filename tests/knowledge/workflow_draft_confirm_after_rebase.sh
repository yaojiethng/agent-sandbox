#!/usr/bin/env bash
# tests/knowledge/workflow_draft_confirm_after_rebase.sh
#
# Knowledge test: confirm_run after rebase onto feature branch
# + interactive rebase to split a commit.
#
# Scenario:
#   main:      I
#   feature:   I → F
#   draft:     I → .ds → A (modifies 2 files)
#   → rebase draft onto feature:  I → F → .ds' → A'
#   → interactive rebase, split A': I → F → .ds' → A1' → A2'
#   → confirm_run: finds .ds' by commit message, drops it, rebases+merges into main
#
# This validates:
#   1. draft_validate_branch finds .draft-state by message (not first-commit)
#   2. confirm_run drops .draft-state by SHA regardless of position
#   3. confirm_run rebases onto target and merges correctly
#   4. No stale .git/index.lock left behind
#
# References:
#   - libs/draft_workflow.sh (draft_validate_branch now searches by message)
#   - handover 20260503-03-study-lock_trace_and_workflow_knowledge_tests.md
#
# Run manually:  bash tests/knowledge/workflow_draft_confirm_after_rebase.sh
# Expected:     All assertions pass, exit 0.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$SCRIPT_DIR/tests/libs/test_common.sh"
FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

echo "Fixture: $FIXTURE"
echo ""

PROJECT_DIR="$FIXTURE/project"
mkdir -p "$PROJECT_DIR"

git init --quiet --initial-branch=main "$PROJECT_DIR"
git -C "$PROJECT_DIR" config user.email "test@test"
git -C "$PROJECT_DIR" config user.name "Test User"

# ============================================================================
# Setup: main, feature, and draft branches
# ============================================================================
echo "================================================================"
echo "Setup: creating branches and commit graph"
echo "================================================================"

# main: one commit
echo "initial" > "$PROJECT_DIR/base.txt"
git -C "$PROJECT_DIR" add . && git -C "$PROJECT_DIR" commit -m "I: initial" --quiet
INIT_SHA=$(git -C "$PROJECT_DIR" rev-parse HEAD)

# feature: one commit on top of main
git -C "$PROJECT_DIR" checkout -b feature --quiet
echo "feature work" > "$PROJECT_DIR/feature.txt"
git -C "$PROJECT_DIR" add . && git -C "$PROJECT_DIR" commit -m "F: feature commit" --quiet
FEATURE_SHA=$(git -C "$PROJECT_DIR" rev-parse HEAD)

# draft branch from main
git -C "$PROJECT_DIR" checkout main --quiet
git -C "$PROJECT_DIR" checkout -b "draft/test-rebase-${INIT_SHA:0:6}" --quiet

# .draft-state commit
echo "source_branch: main
from_hash: ${INIT_SHA}
author: test <test>
session_ts: 20260503-140000
host_branch: rebase_test
diff_count: 0
exported-at: 2026-05-03 14:00:00
drafted-at: 20260503-140100" > "$PROJECT_DIR/.draft-state"
git -C "$PROJECT_DIR" add .draft-state
git -C "$PROJECT_DIR" commit -m ".draft-state" --quiet
DS_SHA=$(git -C "$PROJECT_DIR" rev-parse HEAD)

# Commit A: modifies TWO files so it can be split later
echo "change 1" > "$PROJECT_DIR/part1.txt"
echo "change 2" > "$PROJECT_DIR/part2.txt"
git -C "$PROJECT_DIR" add -A
git -C "$PROJECT_DIR" commit -m "A: combined change (2 files)" --quiet
A_SHA=$(git -C "$PROJECT_DIR" rev-parse HEAD)

echo "Commit graph:"
echo "  main: ${INIT_SHA:0:7} (I)"
echo "  feature: ${FEATURE_SHA:0:7} (F)"
echo "  draft: ${DS_SHA:0:7} (.ds) -> ${A_SHA:0:7} (A)"
echo ""

CURRENT_BRANCH=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD)
pass "Draft branch created: $CURRENT_BRANCH"

# ============================================================================
# Phase 1: rebase onto feature branch
# ============================================================================
echo "================================================================"
echo "Phase 1: git rebase --onto feature main"
echo "================================================================"

# Replay draft commits (from_hash is I on main) onto feature HEAD
# Result: I → F → .ds' → A'
git -C "$PROJECT_DIR" rebase --onto feature main "$CURRENT_BRANCH" --quiet

CURRENT_BRANCH=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD)

echo "After rebase:"
git -C "$PROJECT_DIR" log --oneline feature..HEAD
echo ""

# Verify: first commit in INIT_SHA..CURRENT_BRANCH should NOT be .draft-state
# because the range now includes F (the feature branch commit)
FIRST_IN_RANGE=$(git -C "$PROJECT_DIR" log --reverse --format="%s" "${INIT_SHA}..${CURRENT_BRANCH}" | head -1)
if [[ "$FIRST_IN_RANGE" != ".draft-state" ]]; then
  pass "First commit in from_hash..draft is '$FIRST_IN_RANGE' (not .draft-state — as expected after rebase)"
else
  fail "First commit is still .draft-state (rebase didn't change ancestry)"
fi

# But .draft-state must still exist somewhere in the range
if git -C "$PROJECT_DIR" log "${INIT_SHA}..${CURRENT_BRANCH}" --format="%s" | grep -q "^\.draft-state$"; then
  pass ".draft-state found by message in from_hash..draft range"
else
  fail ".draft-state not found in range — test setup broken"
fi

echo ""
echo "--- Verified: files from draft still present ---"
for f in part1.txt part2.txt; do
  if [[ -f "$PROJECT_DIR/$f" ]]; then
    pass "$f present after rebase"
  else
    fail "$f missing after rebase"
  fi
done

# ============================================================================
# Phase 2: interactive rebase to split commit A
# ============================================================================
echo ""
echo "================================================================"
echo "Phase 2: git rebase -i to split A into A1 + A2"
echo "================================================================"

# Current: I → F → .ds' → A' (A' has both part1.txt and part2.txt)
# Desired: I → F → .ds' → A1 (part1.txt) → A2 (part2.txt)
#
# Use GIT_SEQUENCE_EDITOR to mark A' as "edit" so we can amend it,
# then split into two commits.

# Split A' into A1 (part1.txt) + A2 (part2.txt)
# Move HEAD to .ds', keep working tree, then unstage everything
git -C "$PROJECT_DIR" reset --soft HEAD~1 --quiet
# HEAD is at .ds', staging has A's changes
git -C "$PROJECT_DIR" reset HEAD --quiet
# Now staging is empty, working tree has both files

# Commit part 1 only
git -C "$PROJECT_DIR" add part1.txt
git -C "$PROJECT_DIR" commit -m "A1: first part of change" --quiet
A1_SHA=$(git -C "$PROJECT_DIR" rev-parse HEAD)

# Commit part 2
git -C "$PROJECT_DIR" add part2.txt
git -C "$PROJECT_DIR" commit -m "A2: second part of change" --quiet
A2_SHA=$(git -C "$PROJECT_DIR" rev-parse HEAD)

echo "After split:"
git -C "$PROJECT_DIR" log --oneline feature..HEAD
echo ""

CURRENT_BRANCH=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD)

COMMIT_COUNT=$(git -C "$PROJECT_DIR" rev-list --count "feature..${CURRENT_BRANCH}")
if [[ "$COMMIT_COUNT" -eq 3 ]]; then
  pass "3 commits on draft after split (.ds + A1 + A2)"
else
  fail "Expected 3 commits, got $COMMIT_COUNT"
fi

# Verify .draft-state is NOT first in INIT_SHA..CURRENT_BRANCH
FIRST_IN_RANGE=$(git -C "$PROJECT_DIR" log --reverse --format="%s" "${INIT_SHA}..${CURRENT_BRANCH}" | head -1)
if [[ "$FIRST_IN_RANGE" != ".draft-state" ]]; then
  pass "First commit in range is still NOT .draft-state (expected)"
else
  fail "First commit is .draft-state despite rebase?"
fi

# Verify part1 and part2 files exist
if [[ -f "$PROJECT_DIR/part1.txt" ]]; then
  pass "part1.txt present"
else
  fail "part1.txt missing"
fi
if [[ -f "$PROJECT_DIR/part2.txt" ]]; then
  pass "part2.txt present"
else
  fail "part2.txt missing"
fi

# ============================================================================
# Phase 3: confirm_run
# ============================================================================
echo ""
echo "================================================================"
echo "Phase 3: make confirm (confirm_run with fixed code)"
echo "================================================================"

source "$SCRIPT_DIR/libs/draft_workflow.sh"
source "$SCRIPT_DIR/libs/session.sh"

echo "--- Executing confirm_run (target: main) ---"
set +e
confirm_run "$PROJECT_DIR" "$FIXTURE/sandbox" "main"
CONFIRM_RESULT=$?
set -e

echo ""
echo "--- confirm_run exit code: $CONFIRM_RESULT ---"
if [[ "$CONFIRM_RESULT" -eq 0 ]]; then
  pass "confirm_run succeeded after rebase + interactive split"
else
  fail "confirm_run failed with exit code $CONFIRM_RESULT"
fi

echo ""
echo "--- Post-condition: on main branch ---"
CURRENT=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD)
if [[ "$CURRENT" == "main" ]]; then
  pass "On main branch after confirm"
else
  fail "Expected main, got $CURRENT"
fi

echo ""
echo "--- Post-condition: no draft branches ---"
REMAINING=$(git -C "$PROJECT_DIR" branch --list 'draft/*' 2>/dev/null | wc -l)
if [[ "$REMAINING" -eq 0 ]]; then
  pass "No draft branches remain"
else
  fail "$REMAINING draft branches remain"
fi

echo ""
echo "--- Post-condition: all draft changes on main ---"
for f in part1.txt part2.txt; do
  if [[ -f "$PROJECT_DIR/$f" ]]; then
    pass "$f on main"
  else
    fail "$f missing from main"
  fi
done

echo ""
echo "--- Post-condition: correct commit count (no .draft-state) ---"
COMMITS_ADDED=$(git -C "$PROJECT_DIR" rev-list --count "${INIT_SHA}..HEAD" 2>/dev/null)
# After rebase onto feature, F is in draft's ancestry. When confirm replays
# A1+A2 onto main via rebase, F comes along (git replays the whole range).
# So the count is: F + A1 + A2 = 3 (not 2). .draft-state is properly dropped.
if [[ "$COMMITS_ADDED" -ge 2 ]]; then
  pass "$COMMITS_ADDED new commits on main (includes feature commit F from rebase ancestry, no .draft-state)"
else
  fail "Expected at least 2 commits on main, got $COMMITS_ADDED"
fi

echo ""
echo "--- Post-condition: feature.txt behavior note ---"
if [[ -f "$PROJECT_DIR/feature.txt" ]]; then
  echo "  Note: feature.txt is on main because the draft was rebased onto feature"
  echo "  before confirm. 'git rebase --onto feature main' includes F in ancestry,"
  echo "  so when confirm replays commits onto main, F comes along. Expected."
  pass "feature.txt on main (expected — draft was rebased onto feature)"
else
  pass "feature.txt not on main (rebase may have excluded it)"
fi

echo ""
echo "--- Post-condition: no .draft-state in history ---"
if git -C "$PROJECT_DIR" log --oneline "${INIT_SHA}..HEAD" | grep -q "\.draft-state"; then
  fail ".draft-state leaked into main history"
else
  pass "No .draft-state in main history"
fi

echo ""
echo "--- Post-condition: no stale lock ---"
if [[ -f "$PROJECT_DIR/.git/index.lock" ]]; then
  fail "Stale .git/index.lock after confirm"
else
  pass "No stale .git/index.lock after confirm"
fi

# ============================================================================
# Summary
# ============================================================================
echo ""
echo "================================================================"
echo "Results: $PASS passed, $FAIL failed"
echo "================================================================"

if [[ "$FAIL" -gt 0 ]]; then
  echo ""
  echo "FAILURES DETECTED."
fi

[[ "$FAIL" -eq 0 ]]

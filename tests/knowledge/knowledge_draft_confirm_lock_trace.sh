#!/usr/bin/env bash
# tests/knowledge/knowledge_draft_confirm_lock_trace.sh
#
# Knowledge test: trace index.lock creation at every git operation in
# the draft_run and confirm_run workflows.
#
# This file is NOT run by `make test` or `scripts/run_tests.sh`.
# It is a one-off diagnostic script.
#
# Run manually:  bash tests/knowledge/knowledge_draft_confirm_lock_trace.sh
# Expected:     All assertions pass, exit 0.
#
# Purpose: Determine exactly which git operation(s) in draft_run and
# confirm_run can leave a stale .git/index.lock, and under what
# conditions a subsequent operation encounters it.
#
# References:
#   - handover 20260503-01-impl-remove_snapshot_copy_to_sandbox.md
#   - handover 20260503-02-study-binary_file_handling_in_patch_pipeline.md
#   - libs/draft_workflow.sh
#   - libs/session.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../libs/test_common.sh"
source "$SCRIPT_DIR/../libs/git_fixtures.sh"

FIXTURE="$(mktemp -d)"
echo "Fixture: $FIXTURE"

# Trap for cleanup — but we want to inspect lock files during the run,
# so we only clean up at EXIT.
trap 'echo "Cleaning up..."; rm -rf "$FIXTURE"' EXIT

# ---------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------

# Check if .git/index.lock exists and report status
lock_status() {
  local REPO="$1"
  local LABEL="$2"
  if [[ -f "$REPO/.git/index.lock" ]]; then
    echo "  LOCK [${LABEL}]: PRESENT"
    return 0
  else
    echo "  LOCK [${LABEL}]: absent"
    return 1
  fi
}

# Simulate the grep -v '^index ' filter used in draft_run's apply loop
strip_index() {
  grep -v '^index '
}

# ============================================================================
# Section 1: Verify baseline — which git commands create/need index.lock?
# ============================================================================
echo ""
echo "================================================================"
echo "Section 1: git commands — lock creation baseline"
echo "================================================================"

make_repo "$FIXTURE/s1"
echo "initial" > "$FIXTURE/s1/file.txt"
echo "other" > "$FIXTURE/s1/other.txt"
git -C "$FIXTURE/s1" add . && git -C "$FIXTURE/s1" commit -m "init" --quiet

# 1a: git rev-parse (read-only)
rm -f "$FIXTURE/s1/.git/index.lock"
lock_status "$FIXTURE/s1" "before rev-parse"
git -C "$FIXTURE/s1" rev-parse HEAD > /dev/null
lock_status "$FIXTURE/s1" "after rev-parse" && fail "rev-parse left index.lock" || pass "rev-parse: no lock"

# 1b: git status (read-only)
rm -f "$FIXTURE/s1/.git/index.lock"
git -C "$FIXTURE/s1" status > /dev/null
lock_status "$FIXTURE/s1" "after status" && fail "status left index.lock" || pass "status: no lock"

# 1c: git show-ref (read-only)
rm -f "$FIXTURE/s1/.git/index.lock"
git -C "$FIXTURE/s1" show-ref --verify --quiet refs/heads/main 2>/dev/null; true
lock_status "$FIXTURE/s1" "after show-ref" && fail "show-ref left index.lock" || pass "show-ref: no lock"

# 1d: git config (read-only)
rm -f "$FIXTURE/s1/.git/index.lock"
git -C "$FIXTURE/s1" config user.name > /dev/null
lock_status "$FIXTURE/s1" "after config" && fail "config left index.lock" || pass "config: no lock"

# 1e: git log (read-only)
rm -f "$FIXTURE/s1/.git/index.lock"
git -C "$FIXTURE/s1" log -1 --format=%s HEAD > /dev/null
lock_status "$FIXTURE/s1" "after log" && fail "log left index.lock" || pass "log: no lock"

# 1f: git diff (read-only)
rm -f "$FIXTURE/s1/.git/index.lock"
git -C "$FIXTURE/s1" diff > /dev/null
lock_status "$FIXTURE/s1" "after diff" && fail "diff left index.lock" || pass "diff: no lock"

# 1g: git rev-list (read-only)
rm -f "$FIXTURE/s1/.git/index.lock"
git -C "$FIXTURE/s1" rev-list HEAD --reverse > /dev/null
lock_status "$FIXTURE/s1" "after rev-list" && fail "rev-list left index.lock" || pass "rev-list: no lock"

# 1h: git apply without --index (working tree only)
rm -f "$FIXTURE/s1/.git/index.lock"
echo "modified" > "$FIXTURE/s1/file.txt"
git -C "$FIXTURE/s1" diff > "$FIXTURE/s1_patch.diff"
git -C "$FIXTURE/s1" checkout -- file.txt
lock_status "$FIXTURE/s1" "before apply (no --index)"
git -C "$FIXTURE/s1" apply "$FIXTURE/s1_patch.diff"
lock_status "$FIXTURE/s1" "after apply (no --index)" && fail "apply (no --index) left index.lock" || pass "apply (no --index): no lock"

# 1i: git checkout -b (writes index)
make_repo "$FIXTURE/s1b"
echo "data" > "$FIXTURE/s1b/file.txt"
git -C "$FIXTURE/s1b" add . && git -C "$FIXTURE/s1b" commit -m "init" --quiet
git -C "$FIXTURE/s1b" checkout -b "test-branch" HEAD
lock_status "$FIXTURE/s1b" "after checkout -b" && fail "checkout -b left index.lock" || pass "checkout -b: no lock"

# 1j: git checkout -b on dirty working tree with uncommitted change
rm -f "$FIXTURE/s1/.git/index.lock"
git -C "$FIXTURE/s1" checkout -b "new-branch" HEAD 2>/dev/null; true
lock_status "$FIXTURE/s1" "after checkout -b (dirty)" && fail "checkout -b (dirty) left index.lock" || pass "checkout -b (dirty): no lock"

# 1k: git add (writes index)
echo "add me" > "$FIXTURE/s1/new.txt"
rm -f "$FIXTURE/s1/.git/index.lock"
lock_status "$FIXTURE/s1" "before add"
git -C "$FIXTURE/s1" add new.txt
lock_status "$FIXTURE/s1" "after add" && fail "add left index.lock" || pass "add: no lock"

# 1l: git add -A (writes index, more files)
rm -f "$FIXTURE/s1/.git/index.lock"
git -C "$FIXTURE/s1" add -A
lock_status "$FIXTURE/s1" "after add -A" && fail "add -A left index.lock" || pass "add -A: no lock"

# 1m: git commit (writes index + ref)
rm -f "$FIXTURE/s1/.git/index.lock"
git -C "$FIXTURE/s1" commit -m "commit test" --quiet
lock_status "$FIXTURE/s1" "after commit" && fail "commit left index.lock" || pass "commit: no lock"

# 1n: git switch (writes index)
rm -f "$FIXTURE/s1b/.git/index.lock"
git -C "$FIXTURE/s1b" switch main
lock_status "$FIXTURE/s1b" "after switch" && fail "switch left index.lock" || pass "switch: no lock"

# 1o: git merge --ff-only (writes index + ref)
# Reset to a state where ff-merge is possible
git -C "$FIXTURE/s1b" branch ff-branch HEAD  # same as main, should ff
git -C "$FIXTURE/s1b" merge --ff-only ff-branch --quiet
lock_status "$FIXTURE/s1b" "after merge --ff-only" && fail "merge --ff-only left index.lock" || pass "merge --ff-only: no lock"

# 1p: git branch -D (ref update only, no index)
git -C "$FIXTURE/s1b" branch -D ff-branch --quiet
lock_status "$FIXTURE/s1b" "after branch -D" && fail "branch -D left index.lock" || pass "branch -D: no lock"

# 1q: git rebase --onto
git -C "$FIXTURE/s1" commit --allow-empty -m "extra" --quiet
git -C "$FIXTURE/s1" commit --allow-empty -m "extra2" --quiet
rm -f "$FIXTURE/s1/.git/index.lock"
git -C "$FIXTURE/s1" rebase --onto HEAD~2 HEAD~1 HEAD --quiet 2>/dev/null; true
lock_status "$FIXTURE/s1" "after rebase --onto" && fail "rebase --onto left index.lock" || pass "rebase --onto: no lock"

echo ""
echo "Section 1 complete: all read-only and write operations clean up their locks."

# ============================================================================
# Section 2: Simulate the exact draft_run apply loop with lock tracing
# ============================================================================
echo ""
echo "================================================================"
echo "Section 2: Simulate draft_run apply loop with lock tracing"
echo "================================================================"

# Create a "project" repo (simulates the host project)
make_repo "$FIXTURE/project"
# Simulate the repo state: has baseline.tar tracked (the known problematic scenario)
echo "project init" > "$FIXTURE/project/README.md"
echo "baseline placeholder" > "$FIXTURE/project/baseline.tar"
git -C "$FIXTURE/project" add . && git -C "$FIXTURE/project" commit -m "initial commit" --quiet
INITIAL_COMMIT=$(git -C "$FIXTURE/project" rev-parse HEAD)

# Create simulated patches (like the real bundle)
# Patch 1: add a new file and modify another (text only)
mkdir -p "$FIXTURE/patches"
echo "new file content" > "$FIXTURE/project/new_doc.md"
echo "modified line 2" >> "$FIXTURE/project/README.md"
git -C "$FIXTURE/project" add -A
git -C "$FIXTURE/project" commit -m "prep patch 1" --quiet
PATCH1_SHA=$(git -C "$FIXTURE/project" rev-parse HEAD)

# Generate patch 1 with --binary + strip-index (mimicking the fix)
git -C "$FIXTURE/project" diff --binary "$INITIAL_COMMIT".."$PATCH1_SHA" \
  | awk '/^index / { saved=$0; getline nl; if (nl ~ /^GIT binary patch/) print saved; print nl; next } 1' \
  > "$FIXTURE/patches/0001-patch1.diff"

# Patch 2: modify two more files (text only)
echo "# Section 2" >> "$FIXTURE/project/new_doc.md"
echo "another line" >> "$FIXTURE/project/README.md"
git -C "$FIXTURE/project" add -A
git -C "$FIXTURE/project" commit -m "prep patch 2" --quiet
PATCH2_SHA=$(git -C "$FIXTURE/project" rev-parse HEAD)

git -C "$FIXTURE/project" diff --binary "$PATCH1_SHA".."$PATCH2_SHA" \
  | awk '/^index / { saved=$0; getline nl; if (nl ~ /^GIT binary patch/) print saved; print nl; next } 1' \
  > "$FIXTURE/patches/0002-patch2.diff"

# Reset project back to initial commit for the simulation
git -C "$FIXTURE/project" reset --hard "$INITIAL_COMMIT" --quiet

# Now simulate draft_run step by step, checking locks after each git operation
echo ""
echo "--- Step 2a: checkout -b to create draft branch ---"
lock_status "$FIXTURE/project" "before checkout -b"
git -C "$FIXTURE/project" checkout -b "draft/test-bundle-emergency-abc123" HEAD
lock_status "$FIXTURE/project" "after checkout -b"

echo ""
echo "--- Step 2b: write and commit .draft-state ---"
echo "source_branch: main
from_hash: ${INITIAL_COMMIT}
author: test <test>
session_ts: 20260503-055209
host_branch: fix_binary_diff_pipeline
diff_count: 2
exported-at: 2026-05-03 05:52:09
drafted-at: 20260503-060000" > "$FIXTURE/project/.draft-state"

lock_status "$FIXTURE/project" "before git add .draft-state"
git -C "$FIXTURE/project" add .draft-state
lock_status "$FIXTURE/project" "after git add .draft-state"

lock_status "$FIXTURE/project" "before git commit .draft-state"
git -C "$FIXTURE/project" commit -m ".draft-state" --quiet
lock_status "$FIXTURE/project" "after git commit .draft-state"

echo ""
echo "--- Step 2c: apply patches (simulating draft_run loop) ---"
echo "Patches: $(ls "$FIXTURE/patches/"*.diff 2>/dev/null | wc -l)"
echo ""

for diff_file in "$FIXTURE/patches/"*.diff; do
  echo "  Applying: $(basename "$diff_file")"

  # Before apply — check lock
  lock_status "$FIXTURE/project" "before apply: $(basename "$diff_file")"

  # git apply (no --index, working tree only)
  if git -C "$FIXTURE/project" apply < <(strip_index "$diff_file"); then
    lock_status "$FIXTURE/project" "after apply: $(basename "$diff_file")"
  else
    lock_status "$FIXTURE/project" "AFTER APPLY FAILED: $(basename "$diff_file")"
    fail "git apply failed for $(basename "$diff_file") — aborting loop"
    break
  fi

  # git add -A
  lock_status "$FIXTURE/project" "before add -A (post-apply: $(basename "$diff_file"))"
  git -C "$FIXTURE/project" add -A
  lock_status "$FIXTURE/project" "after add -A (post-apply: $(basename "$diff_file"))"

  # git commit
  lock_status "$FIXTURE/project" "before commit (post-apply: $(basename "$diff_file"))"
  git -C "$FIXTURE/project" commit -m "Apply $(basename "$diff_file")" --quiet
  lock_status "$FIXTURE/project" "after commit (post-apply: $(basename "$diff_file"))"
done

# At the end, verify no lock was left
if lock_status "$FIXTURE/project" "end of draft_run simulation"; then
  fail "Stale index.lock found at end of draft_run simulation"
else
  pass "No stale lock at end of draft_run simulation"
fi

echo ""
echo "--- Step 2d: verify commits were created ---"
if git -C "$FIXTURE/project" log --oneline | head -5 > /dev/null 2>&1; then
  pass "Commits exist after draft simulation"
  git -C "$FIXTURE/project" log --oneline | head -5
else
  fail "No commits found after draft simulation"
fi

# ============================================================================
# Section 3: Test with a stale lock left before apply loop
# ============================================================================
echo ""
echo "================================================================"
echo "Section 3: Stale lock detection — what happens at each step"
echo "================================================================"

# Create fresh repo for this test
make_repo "$FIXTURE/s3"
echo "content" > "$FIXTURE/s3/file.txt"
git -C "$FIXTURE/s3" add . && git -C "$FIXTURE/s3" commit -m "init" --quiet

# Create a simple patch
echo "new line" >> "$FIXTURE/s3/file.txt"
git -C "$FIXTURE/s3" diff > "$FIXTURE/s3_patch.diff"
git -C "$FIXTURE/s3" checkout -- file.txt

echo ""
echo "--- Step 3a: apply with pre-existing stale lock ---"
touch "$FIXTURE/s3/.git/index.lock"
lock_status "$FIXTURE/s3" "stale lock placed"

# git apply without --index should work even with stale lock
echo "  Trying git apply (no --index) with stale lock..."
if git -C "$FIXTURE/s3" apply "$FIXTURE/s3_patch.diff" 2>/dev/null; then
  pass "git apply (no --index) succeeds despite stale lock"
else
  fail "git apply (no --index) fails with stale lock — this is the bug!"
fi
lock_status "$FIXTURE/s3" "after apply with stale lock"

# Clean up
git -C "$FIXTURE/s3" checkout -- file.txt 2>/dev/null || true

echo ""
echo "--- Step 3b: git add -A with pre-existing stale lock ---"
# Remove the lock and recreates it
rm -f "$FIXTURE/s3/.git/index.lock"
touch "$FIXTURE/s3/file.txt"  # restore content
touch "$FIXTURE/s3/new_add.txt"
touch "$FIXTURE/s3/.git/index.lock"
lock_status "$FIXTURE/s3" "stale lock placed before add -A"

echo "  Trying git add -A with stale lock..."
if git -C "$FIXTURE/s3" add -A 2>/dev/null; then
  fail "git add -A succeeded despite stale lock — unexpected"
else
  pass "git add -A fails with stale lock (expected)"
fi

rm -f "$FIXTURE/s3/.git/index.lock"

echo ""
echo "--- Step 3c: git commit with pre-existing stale lock ---"
git -C "$FIXTURE/s3" add -A 2>/dev/null || true
touch "$FIXTURE/s3/.git/index.lock"
lock_status "$FIXTURE/s3" "stale lock placed before commit"

echo "  Trying git commit with stale lock..."
if git -C "$FIXTURE/s3" commit -m "test commit" --quiet 2>/dev/null; then
  fail "git commit succeeded despite stale lock — unexpected"
else
  pass "git commit fails with stale lock (expected)"
fi

rm -f "$FIXTURE/s3/.git/index.lock"

echo ""
echo "--- Step 3d: git checkout -b with pre-existing stale lock ---"
touch "$FIXTURE/s3/.git/index.lock"
echo "  Trying git checkout -b with stale lock..."
if git -C "$FIXTURE/s3" checkout -b "stale-branch" 2>/dev/null; then
  fail "git checkout -b succeeded despite stale lock — unexpected"
else
  pass "git checkout -b fails with stale lock (expected)"
fi

rm -f "$FIXTURE/s3/.git/index.lock"

echo ""
echo "--- Step 3e: git rebase --onto with pre-existing stale lock ---"
make_repo "$FIXTURE/s3e"
echo "a" > "$FIXTURE/s3e/file.txt"
git -C "$FIXTURE/s3e" add . && git -C "$FIXTURE/s3e" commit -m "init" --quiet
echo "b" >> "$FIXTURE/s3e/file.txt"
git -C "$FIXTURE/s3e" add . && git -C "$FIXTURE/s3e" commit -m "second" --quiet
echo "c" >> "$FIXTURE/s3e/file.txt"
git -C "$FIXTURE/s3e" add . && git -C "$FIXTURE/s3e" commit -m "third" --quiet

touch "$FIXTURE/s3e/.git/index.lock"
echo "  Trying git rebase --onto with stale lock..."
if git -C "$FIXTURE/s3e" rebase --onto HEAD~2 HEAD~1 HEAD 2>/dev/null; then
  fail "git rebase --onto succeeded despite stale lock — unexpected"
else
  pass "git rebase --onto fails with stale lock (expected)"
fi

rm -f "$FIXTURE/s3e/.git/index.lock"

# ============================================================================
# Section 4: Simulate confirm_run with lock tracing
# ============================================================================
echo ""
echo "================================================================"
echo "Section 4: Simulate confirm_run with lock tracing"
echo "================================================================"

# Set up a proper draft branch like confirm_run expects
make_repo "$FIXTURE/s4"
echo "project init" > "$FIXTURE/s4/README.md"
git -C "$FIXTURE/s4" add . && git -C "$FIXTURE/s4" commit -m "initial" --quiet
S4_INIT=$(git -C "$FIXTURE/s4" rev-parse HEAD)

# Simulate two patches on a draft branch (like after draft_run succeeds)
echo "# Section A" > "$FIXTURE/s4/doc.md"
git -C "$FIXTURE/s4" checkout -b "draft/simulation-abc" HEAD
git -C "$FIXTURE/s4" add doc.md
git -C "$FIXTURE/s4" commit -m ".draft-state" --quiet
S4_DRAFT_STATE=$(git -C "$FIXTURE/s4" rev-parse HEAD)
echo "doc body" >> "$FIXTURE/s4/README.md"
git -C "$FIXTURE/s4" add -A
git -C "$FIXTURE/s4" commit -m "Apply 0001-patch1.diff" --quiet
echo "more content" >> "$FIXTURE/s4/doc.md"
git -C "$FIXTURE/s4" add -A
git -C "$FIXTURE/s4" commit -m "Apply 0002-patch2.diff" --quiet

echo ""
echo "--- Step 4a: git show-ref --verify (target branch exists) ---"
lock_status "$FIXTURE/s4" "before show-ref"
git -C "$FIXTURE/s4" show-ref --verify --quiet refs/heads/main 2>/dev/null; true
lock_status "$FIXTURE/s4" "after show-ref"

echo ""
echo "--- Step 4b: rev-list to find first commit ---"
lock_status "$FIXTURE/s4" "before rev-list"
read -r S4_FIRST < <(git -C "$FIXTURE/s4" rev-list "${S4_INIT}..HEAD" --reverse)
lock_status "$FIXTURE/s4" "after rev-list"

echo ""
echo "--- Step 4c: rebase --onto to drop .draft-state commit ---"
echo "  DRAFT_STATE_COMMIT=${S4_DRAFT_STATE:0:7}"
echo "  CURRENT_BRANCH=$(git -C "$FIXTURE/s4" rev-parse --abbrev-ref HEAD)"
echo "  Rebase: --onto ${S4_DRAFT_STATE}~1 ${S4_DRAFT_STATE} HEAD"
lock_status "$FIXTURE/s4" "before rebase --onto"

if git -C "$FIXTURE/s4" rebase --onto "${S4_DRAFT_STATE}^" "$S4_DRAFT_STATE" HEAD 2>/dev/null; then
  pass "rebase --onto to drop .draft-state succeeds"
  lock_status "$FIXTURE/s4" "after rebase --onto"
else
  lock_status "$FIXTURE/s4" "after rebase --onto FAILED"
  fail "rebase --onto to drop .draft-state failed"
fi

# Check that .draft-state commit was dropped
S4_LOG=$(git -C "$FIXTURE/s4" log --oneline 2>/dev/null)
if echo "$S4_LOG" | grep -q ".draft-state"; then
  fail ".draft-state commit still present after rebase --onto"
else
  pass ".draft-state commit successfully dropped"
fi

echo ""
echo "--- Step 4d: rebase onto target branch ---"
lock_status "$FIXTURE/s4" "before rebase onto main"
if git -C "$FIXTURE/s4" rebase main 2>/dev/null; then
  pass "rebase onto main succeeds"
  lock_status "$FIXTURE/s4" "after rebase onto main"
else
  lock_status "$FIXTURE/s4" "after rebase onto main FAILED"
  fail "rebase onto main failed"
fi

echo ""
echo "--- Step 4e: switch to target and ff-merge ---"
lock_status "$FIXTURE/s4" "before switch main"
git -C "$FIXTURE/s4" switch main --quiet
lock_status "$FIXTURE/s4" "after switch main"

# Find the draft branch name (in a real scenario it's tracked in .draft-state)
DRAFT_BRANCH=$(git -C "$FIXTURE/s4" branch --list 'draft/*' | head -1 | tr -d ' *')
if [[ -n "$DRAFT_BRANCH" ]]; then
  lock_status "$FIXTURE/s4" "before merge --ff-only $DRAFT_BRANCH"
  if git -C "$FIXTURE/s4" merge --ff-only "$DRAFT_BRANCH" --quiet 2>/dev/null; then
    pass "ff-merge succeeds"
    lock_status "$FIXTURE/s4" "after merge --ff-only"
  else
    lock_status "$FIXTURE/s4" "after merge --ff-only FAILED"
    fail "ff-merge failed"
  fi
else
  fail "No draft branch found for ff-merge test"
fi

echo ""
echo "--- Step 4f: delete draft branch ---"
lock_status "$FIXTURE/s4" "before branch -D"
git -C "$FIXTURE/s4" branch -D "$DRAFT_BRANCH" 2>/dev/null; true
lock_status "$FIXTURE/s4" "after branch -D"

# Final check
if lock_status "$FIXTURE/s4" "end of confirm_run simulation"; then
  fail "Stale index.lock found at end of confirm_run simulation"
else
  pass "No stale lock at end of confirm_run simulation"
fi

# ============================================================================
# Section 5: Stress test — repeated apply iterations with forced interruption
# ============================================================================
echo ""
echo "================================================================"
echo "Section 5: Stress test — interrupt during critical operations"
echo "================================================================"

make_repo "$FIXTURE/s5"
echo "init" > "$FIXTURE/s5/file.txt"
git -C "$FIXTURE/s5" add . && git -C "$FIXTURE/s5" commit -m "init" --quiet

# Create 5 patches
for i in 1 2 3 4 5; do
  echo "iteration $i" >> "$FIXTURE/s5/file.txt"
  git -C "$FIXTURE/s5" diff > "$FIXTURE/s5_patch_${i}.diff"
  git -C "$FIXTURE/s5" checkout -- file.txt
done

echo ""
echo "--- Step 5a: detect a stale lock before the loop ---"
# Simulate the exact scenario: stale lock exists
touch "$FIXTURE/s5/.git/index.lock"
lock_status "$FIXTURE/s5" "stale lock placed"

# git apply should still work (no --index)
echo "  git apply (iteration 1) with stale lock..."
if git -C "$FIXTURE/s5" apply "$FIXTURE/s5_patch_1.diff" 2>/dev/null; then
  pass "git apply iteration 1 succeeds despite stale lock"
else
  fail "git apply iteration 1 failed with stale lock"
fi

# Then git add -A will fail
echo "  git add -A with stale lock..."
if git -C "$FIXTURE/s5" add -A 2>/dev/null; then
  fail "git add -A unexpectedly succeeded with stale lock"
else
  pass "git add -A fails with stale lock (expected — index.lock blocks write)"
fi

# Verify the lock is still there
lock_status "$FIXTURE/s5" "lock still present after add failure"

# This confirms the scenario: if a stale lock exists before the loop,
# git apply (first step of iteration 1) succeeds, but add fails.
# However, the second iteration's git apply would also need to check...

# Clean up
rm -f "$FIXTURE/s5/.git/index.lock"
git -C "$FIXTURE/s5" checkout -- file.txt 2>/dev/null || true

echo ""
echo "--- Step 5b: test with lock created mid-loop (simulating race condition) ---"
# Apply iteration 1 normally
git -C "$FIXTURE/s5" apply "$FIXTURE/s5_patch_1.diff"
git -C "$FIXTURE/s5" add -A
git -C "$FIXTURE/s5" commit -m "Apply patch 1" --quiet

# Now place a stale lock (simulating a concurrent git operation or
# filesystem-level issue where the lock was left by a previous command
# that appeared to succeed)
touch "$FIXTURE/s5/.git/index.lock"
lock_status "$FIXTURE/s5" "stale lock placed after commit, before iteration 2"

# Try iteration 2
echo "  git apply (iteration 2) with stale lock..."
if git -C "$FIXTURE/s5" apply "$FIXTURE/s5_patch_2.diff" 2>/dev/null; then
  pass "git apply iteration 2 succeeds despite stale lock"
else
  fail "git apply iteration 2 failed with stale lock — this is the reported error!"
fi

lock_status "$FIXTURE/s5" "after iteration 2 git apply (lock still present)"

# git add would fail
echo "  git add -A (iteration 2) with stale lock..."
if git -C "$FIXTURE/s5" add -A 2>/dev/null; then
  fail "git add -A iteration 2 succeeded despite stale lock"
else
  pass "git add -A iteration 2 fails with stale lock (expected)"
fi

rm -f "$FIXTURE/s5/.git/index.lock"

echo ""
echo "--- Step 5c: confirm shutdown (signal-based interruption) leaves lock ---"
make_repo "$FIXTURE/s5c"
echo "init" > "$FIXTURE/s5c/file.txt"
git -C "$FIXTURE/s5c" add . && git -C "$FIXTURE/s5c" commit -m "init" --quiet

# Simulate: what happens if git add is killed mid-flight?
# We can't easily test this with SIGKILL, but we can simulate the effect:
# Create a half-written lock file (zero-byte lock — what git creates first)
touch "$FIXTURE/s5c/.git/index.lock"

echo "  Trying git status with zero-byte stale lock..."
if git -C "$FIXTURE/s5c" status > /dev/null 2>&1; then
  pass "git status works despite zero-byte stale lock"
else
  fail "git status fails with zero-byte stale lock"
fi

echo "  Trying git add with zero-byte stale lock..."
if git -C "$FIXTURE/s5c" add -A 2>/dev/null; then
  fail "git add succeeded with zero-byte stale lock"
else
  pass "git add fails with zero-byte stale lock (expected)"
fi

rm -f "$FIXTURE/s5c/.git/index.lock"

echo ""
echo "--- Step 5d: what precise git command fails in draft_run when lock exists? ---"
echo "  draft_run apply loop does: git apply (no --index), then git add -A"
echo "  If a stale lock pre-exists BEFORE the loop:"
echo "    - git apply (iteration 1) succeeds (no lock needed)"
echo "    - git add -A (iteration 1) fails (needs lock)"
echo "    - Script terminates via set -e before iteration 2"
echo ""
echo "  If a stale lock appears BETWEEN iterations:"
echo "    - git apply (iteration 2) would fail because..."
echo "      wait — it DOESN'T need the lock!"
echo ""
echo "  => The second git apply should NOT fail with 'index.lock exists'"
echo "     unless there is a git feature or config that makes it need the lock."

# Test: git apply via process substitution (like draft_run does)
echo ""
echo "--- Step 5e: git apply via process substitution, same as draft_run ---"
make_repo "$FIXTURE/s5e"
echo "base" > "$FIXTURE/s5e/file.txt"
git -C "$FIXTURE/s5e" add . && git -C "$FIXTURE/s5e" commit -m "init" --quiet
echo "modified" > "$FIXTURE/s5e/file.txt"
git -C "$FIXTURE/s5e" diff > "$FIXTURE/s5e_patch.diff"
git -C "$FIXTURE/s5e" checkout -- file.txt

touch "$FIXTURE/s5e/.git/index.lock"
lock_status "$FIXTURE/s5e" "stale lock before git apply (process sub)"
# This is exactly what draft_run line 283 does:
if ! git -C "$FIXTURE/s5e" apply < <(strip_index "$FIXTURE/s5e_patch.diff") 2>/dev/null; then
  fail "git apply via process sub failed with stale lock — would break draft_run"
else
  pass "git apply via process sub succeeds despite stale lock (as expected)"
fi
lock_status "$FIXTURE/s5e" "after git apply (process sub)"

rm -f "$FIXTURE/s5e/.git/index.lock"

# ============================================================================
# Section 6: Re-test applying the actual bundle patches
# ============================================================================
echo ""
echo "================================================================"
echo "Section 6: Apply actual bundle patches (reproducing the scenario)"
echo "================================================================"

# Use the actual patches from the bundle if available
BUNDLE_DIR="$HOME/workspace/output/bundles/20260503-055209-fix_binary_diff_pipeline"

if [[ -d "$BUNDLE_DIR/patches" ]]; then
  echo "Bundle found: $BUNDLE_DIR"

  # Check patch content for anything that might trigger index lock
  for pf in "$BUNDLE_DIR/patches/"*.diff; do
    echo "  $(basename "$pf"):"
    echo "    size: $(wc -c < "$pf") bytes"
    echo "    index lines: $(grep -c '^index ' "$pf")"
    if grep -q 'GIT binary patch' "$pf" 2>/dev/null; then
      echo "    contains binary patch: YES"
    else
      echo "    contains binary patch: no"
    fi
    # Check for anything unusual in the patch
    if grep -q '^mode change' "$pf" 2>/dev/null; then
      echo "    mode changes: YES"
    fi
    if grep -q '^new file mode 120000' "$pf" 2>/dev/null; then
      echo "    symlinks: YES"
    fi
    if grep -q '^rename from\|^rename to' "$pf" 2>/dev/null; then
      echo "    renames: YES"
    fi
    if grep -q '^copy from\|^copy to' "$pf" 2>/dev/null; then
      echo "    copies: YES"
    fi
    if grep -q '^diff --git.*/[^ ]*\.[^ ]*$' "$pf" 2>/dev/null; then
      : # normal extension
    fi
    # Check if any file path has unusual characters
    echo ""
  done

  # Now reproduce the exact scenario
  make_repo "$FIXTURE/s6"
  echo "# agent-sandbox" > "$FIXTURE/s6/README.md"
  mkdir -p "$FIXTURE/s6/libs" "$FIXTURE/s6/tests" "$FIXTURE/s6/docs/devlog/handovers" "$FIXTURE/s6/docs/development" "$FIXTURE/s6/tests/knowledge"

  # Populate the files that the patches modify (simulating the repo state before patches)
  # These are just placeholders to make the patches apply cleanly
  echo '#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" \&\& pwd)/session.sh"' > "$FIXTURE/s6/libs/sandbox-entrypoint.sh"
  echo '#!/usr/bin/env bash
set -euo pipefail

# snapshot_functions
snapshot_copy_to_sandbox() { echo "copy"; }
snapshot_init_git() { echo "init"; }
' > "$FIXTURE/s6/libs/snapshot.sh"
  echo '#!/usr/bin/env bash' > "$FIXTURE/s6/tests/test_snapshot_container.sh"
  echo "# Testing Policy" > "$FIXTURE/s6/docs/development/testing_policy.md"
  echo '#!/usr/bin/env bash
set -euo pipefail
git diff | grep -v index
' > "$FIXTURE/s6/libs/package_branch.sh"
  echo '#!/usr/bin/env bash
set -euo pipefail
git diff | grep -v index
' > "$FIXTURE/s6/libs/package_diff.sh"

  git -C "$FIXTURE/s6" add .
  git -C "$FIXTURE/s6" commit -m "initial state" --quiet
  S6_INIT=$(git -C "$FIXTURE/s6" rev-parse HEAD)

  echo "Repo initialized at $S6_INIT"

  # Now simulate draft_run with these actual patches
  echo ""
  echo "--- Applying bundle patches (mimicking exact draft_run behavior) ---"
  git -C "$FIXTURE/s6" checkout -b "draft/bundles-emergency_fixes-${S6_INIT:0:6}" HEAD

  echo "source_branch: main
from_hash: ${S6_INIT}
author: agent <agent>
session_ts: 20260503-055209
host_branch: fix_binary_diff_pipeline
diff_count: 2
exported-at: 2026-05-03 05:52:09
drafted-at: 20260503-060000" > "$FIXTURE/s6/.draft-state"

  git -C "$FIXTURE/s6" add .draft-state
  git -C "$FIXTURE/s6" commit -m ".draft-state" --quiet

  # Apply each patch, checking lock
  for diff_file in "$BUNDLE_DIR/patches/"*.diff; do
    echo ""
    echo "  Applying: $(basename "$diff_file")"
    lock_status "$FIXTURE/s6" "before apply: $(basename "$diff_file")"

    if ! git -C "$FIXTURE/s6" apply < <(strip_index "$diff_file") 2>&1; then
      lock_status "$FIXTURE/s6" "AFTER APPLY FAILED: $(basename "$diff_file")"
      fail "Failed to apply $(basename "$diff_file")"
      continue
    fi
    lock_status "$FIXTURE/s6" "after apply: $(basename "$diff_file")"

    lock_status "$FIXTURE/s6" "before add -A"
    git -C "$FIXTURE/s6" add -A
    lock_status "$FIXTURE/s6" "after add -A"

    lock_status "$FIXTURE/s6" "before commit"
    git -C "$FIXTURE/s6" commit -m "Apply $(basename "$diff_file")" --quiet
    lock_status "$FIXTURE/s6" "after commit"
  done

  # Final check
  echo ""
  if lock_status "$FIXTURE/s6" "end of bundle apply"; then
    fail "Stale index.lock found after bundle apply"
  else
    pass "No stale lock after bundle apply — patches apply cleanly"
  fi

  # Verify both patches applied by checking log
  COMMIT_COUNT=$(git -C "$FIXTURE/s6" log --oneline "${S6_INIT}..HEAD" 2>/dev/null | wc -l)
  echo "  Commits on draft branch: $COMMIT_COUNT (expected: 3 = .draft-state + 2 patches)"
  if [[ "$COMMIT_COUNT" -eq 3 ]]; then
    pass "All 3 commits created (draft-state + 2 patches)"
  else
    fail "Expected 3 commits, got $COMMIT_COUNT"
  fi

else
  echo "Bundle not found at $BUNDLE_DIR — skipping section 6"
  pass "SKIP: bundle not available (test environment)"
fi

# ============================================================================
# Summary
# ============================================================================
echo ""
echo "================================================================"
echo "Results: $PASS passed, $FAIL failed"
echo "================================================================"
echo ""

if [[ "$FAIL" -gt 0 ]]; then
  echo "FAILURES DETECTED. Review output above for details."
else
  echo "All assertions passed."
fi

[[ "$FAIL" -eq 0 ]]

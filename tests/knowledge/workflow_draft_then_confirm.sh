#!/usr/bin/env bash
# tests/knowledge/workflow_draft_then_confirm.sh
#
# End-to-end knowledge test: draft_run -> confirm_run.
# Sources the real libs/draft_workflow.sh to test actual function behavior.
#
# Purpose: Validate that the full make draft -> make confirm workflow
# completes correctly: draft branch created, patches applied, then
# rebased and merged back to source branch. No stale locks left behind.
#
# References:
#   - libs/draft_workflow.sh
#   - libs/session.sh
#   - Makefile.template (Make targets for draft / confirm)
#
# Run manually:  bash tests/knowledge/workflow_draft_then_confirm.sh
# Expected:     All assertions pass, exit 0.

set -uo pipefail

# REPO_ROOT = repo root (two levels up from tests/knowledge/)
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/tests/libs/test_common.sh"
FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

echo "Fixture: $FIXTURE"
echo ""

# Source the real functions
source "$REPO_ROOT/libs/draft_workflow.sh"
source "$REPO_ROOT/libs/session.sh"

# ============================================================================
# Setup: create a project repo (simulates the host project)
# ============================================================================
echo "================================================================"
echo "Setup: project repo + session export"
echo "================================================================"

PROJECT_DIR="$FIXTURE/project"
SANDBOX_DIR="$FIXTURE/sandbox"
SOURCE_BRANCH="main"

mkdir -p "$PROJECT_DIR"
mkdir -p "$SANDBOX_DIR/.workspace/session-diffs"

git init --quiet --initial-branch=main "$PROJECT_DIR"
git -C "$PROJECT_DIR" config user.email "test@test"
git -C "$PROJECT_DIR" config user.name "Test User"

echo "# My Project" > "$PROJECT_DIR/README.md"
echo '#!/usr/bin/env bash' > "$PROJECT_DIR/build.sh"
echo 'echo "hello"' >> "$PROJECT_DIR/build.sh"
chmod +x "$PROJECT_DIR/build.sh"
mkdir -p "$PROJECT_DIR/src"
echo "fn main() {}" > "$PROJECT_DIR/src/main.rs"

git -C "$PROJECT_DIR" add -A
git -C "$PROJECT_DIR" commit -m "initial project state" --quiet
INIT_SHA=$(git -C "$PROJECT_DIR" rev-parse HEAD)

echo "Project initialized at commit ${INIT_SHA:0:7} on branch $SOURCE_BRANCH"
echo ""

# ============================================================================
# Create a session export (like package_branch would produce)
# ============================================================================
SESSION_TS="20260503-120000"
SANITIZED_BRANCH="fix_something"
EXPORT_BASENAME="${SESSION_TS}-${SANITIZED_BRANCH}"
EXPORT_DIR="$FIXTURE/sandbox/.workspace/session-diffs/$EXPORT_BASENAME"

# Use the fixture helper to create proper session structure
source "$REPO_ROOT/tests/libs/session_fixtures.sh"
make_session_fixture "$EXPORT_DIR" 2

echo "Session export created at: $EXPORT_DIR"
echo ""

# ============================================================================
# PHASE 1: draft_run
# ============================================================================
echo ""
echo "================================================================"
echo "PHASE 1: make draft (draft_run)"
echo "================================================================"

BRANCH_SUMMARY="knowledge_test"
BRANCH_FROM=""  # use HEAD
SESSION_ARG=""  # auto-resolve (newest)
DIFFS_ARG=""
FORCE=""

# Verify pre-conditions
echo "--- Precondition: on source branch ---"
CURRENT_BRANCH=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD)
if [[ "$CURRENT_BRANCH" == "$SOURCE_BRANCH" ]]; then
  pass "On source branch before draft"
else
  fail "Expected $SOURCE_BRANCH, got $CURRENT_BRANCH"
fi

echo ""
echo "--- Precondition: no existing draft branch ---"
if git -C "$PROJECT_DIR" show-ref --verify --quiet refs/heads/draft/* 2>/dev/null; then
  fail "Draft branch already exists"
else
  pass "No existing draft branch"
fi

echo ""
echo "--- Precondition: .draft-state does not exist ---"
if [[ -f "$PROJECT_DIR/.draft-state" ]]; then
  fail ".draft-state already exists"
else
  pass "No pre-existing .draft-state"
fi

echo ""
echo "--- Precondition: file-1.txt does not exist ---"
if [[ -f "$PROJECT_DIR/file-1.txt" ]]; then
  fail "file-1.txt already exists"
else
  pass "file-1.txt does not exist (will be created by patches)"
fi

echo ""
echo ""
echo "--- Collecting patches ---"
PATCHES_DIR="$EXPORT_DIR/patches"
PATCH_LIST=$(draft_collect_patches "$PATCHES_DIR" "$DIFFS_ARG" || true)
DIFF_COUNT=$(echo "$PATCH_LIST" | grep -c . || true)
echo "Found $DIFF_COUNT patches"

echo "--- Creating draft branch ---"
set +e
draft_run "$PROJECT_DIR" "$SANDBOX_DIR" "$SESSION_ARG" "$BRANCH_FROM" "$BRANCH_SUMMARY" "$DIFF_COUNT"
DRAFT_RESULT=$?
set -e

echo ""
echo "--- Branch creation exit code: $DRAFT_RESULT ---"
if [[ "$DRAFT_RESULT" -eq 0 ]]; then
  pass "draft_run completed successfully"
else
  fail "draft_run failed with exit code $DRAFT_RESULT"
fi

echo ""
echo "--- Applying patches ---"
AUTHOR="$(git -C "$PROJECT_DIR" config user.name) <$(git -C "$PROJECT_DIR" config user.email)>"
echo "$PATCH_LIST" | draft_apply_patches "$PROJECT_DIR" "$AUTHOR" false false
draft_apply_uncommitted "$PROJECT_DIR" "$EXPORT_DIR" "$AUTHOR" false false
echo "Patches applied successfully"

echo ""
echo "--- Post-condition: on draft branch ---"
CURRENT_BRANCH=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD)
if [[ "$CURRENT_BRANCH" == draft/* ]]; then
  pass "On draft branch: $CURRENT_BRANCH"
else
  fail "Expected draft/* branch, got $CURRENT_BRANCH"
fi

echo ""
echo "--- Post-condition: draft branch exists ---"
if git -C "$PROJECT_DIR" show-ref --verify --quiet "refs/heads/$CURRENT_BRANCH" 2>/dev/null; then
  pass "Draft branch reference exists"
else
  fail "Draft branch reference missing"
fi

echo ""
echo "--- Post-condition: .draft-state exists on draft branch ---"
DRAFT_STATE_CONTENT=$(git -C "$PROJECT_DIR" show "${CURRENT_BRANCH}:.draft-state" 2>/dev/null || echo "")
if [[ -n "$DRAFT_STATE_CONTENT" ]]; then
  pass ".draft-state present on draft branch"
else
  fail ".draft-state missing on draft branch"
fi

echo ""
echo "--- Post-condition: patches applied (files created by diffs) ---"
if [[ -f "$PROJECT_DIR/file-1.txt" ]]; then
  pass "file-1.txt created (patch 1 applied)"
else
  fail "file-1.txt missing (patch 1 not applied)"
fi
if [[ -f "$PROJECT_DIR/file-2.txt" ]]; then
  pass "file-2.txt created (patch 2 applied)"
else
  fail "file-2.txt missing (patch 2 not applied)"
fi

echo ""
echo "--- Post-condition: original files still present ---"
if [[ -f "$PROJECT_DIR/README.md" ]]; then
  pass "README.md still exists"
else
  fail "README.md missing"
fi
if [[ -f "$PROJECT_DIR/build.sh" ]]; then
  pass "build.sh still exists"
else
  fail "build.sh missing"
fi
if [[ -f "$PROJECT_DIR/src/main.rs" ]]; then
  pass "src/main.rs still exists"
else
  fail "src/main.rs missing"
fi

echo ""
echo "--- Post-condition: .git/index.lock absent ---"
if [[ -f "$PROJECT_DIR/.git/index.lock" ]]; then
  fail "Stale .git/index.lock present after draft_run"
else
  pass "No stale .git/index.lock after draft_run"
fi

# ============================================================================
# PHASE 2: confirm_run
# ============================================================================
echo ""
echo "================================================================"
echo "PHASE 2: make confirm (confirm_run)"
echo "================================================================"

echo "--- Precondition: source branch has no draft changes ---"
git -C "$PROJECT_DIR" checkout "$SOURCE_BRANCH" --quiet
if [[ ! -f "$PROJECT_DIR/file-1.txt" ]]; then
  pass "$SOURCE_BRANCH branch does not have draft changes (pre-rebase)"
else
  fail "$SOURCE_BRANCH already has file-1.txt"
fi

# Return to draft branch
git -C "$PROJECT_DIR" checkout "$CURRENT_BRANCH" --quiet

echo ""
echo "--- Executing confirm_run (target: $SOURCE_BRANCH) ---"
set +e
confirm_run "$PROJECT_DIR" "$SANDBOX_DIR" "$SOURCE_BRANCH"
CONFIRM_RESULT=$?
set -e

echo ""
echo "--- confirm_run exit code: $CONFIRM_RESULT ---"
if [[ "$CONFIRM_RESULT" -eq 0 ]]; then
  pass "confirm_run completed successfully"
else
  fail "confirm_run failed with exit code $CONFIRM_RESULT"
fi

echo ""
echo "--- Post-condition: switched to target branch ---"
CURRENT_BRANCH=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD)
if [[ "$CURRENT_BRANCH" == "$SOURCE_BRANCH" ]]; then
  pass "On target branch: $CURRENT_BRANCH"
else
  fail "Expected $SOURCE_BRANCH, got $CURRENT_BRANCH"
fi

echo ""
echo "--- Post-condition: draft branch deleted ---"
REMAINING_DRAFTS=$(git -C "$PROJECT_DIR" branch --list 'draft/*' 2>/dev/null | wc -l)
if [[ "$REMAINING_DRAFTS" -eq 0 ]]; then
  pass "No draft branches remain"
else
  fail "$REMAINING_DRAFTS draft branch(es) remain"
fi

echo ""
echo "--- Post-condition: changes are on target branch ---"
if [[ -f "$PROJECT_DIR/file-1.txt" ]]; then
  pass "file-1.txt present on target branch"
else
  fail "file-1.txt missing from target branch"
fi
if [[ -f "$PROJECT_DIR/file-2.txt" ]]; then
  pass "file-2.txt present on target branch"
else
  fail "file-2.txt missing from target branch"
fi

echo ""
echo "--- Post-condition: expected number of commits on target ---"
COMMITS_ON_TARGET=$(git -C "$PROJECT_DIR" rev-list --count "$INIT_SHA..HEAD" 2>/dev/null)
if [[ "$COMMITS_ON_TARGET" -eq 2 ]]; then
  pass "Exactly 2 new commits on target (the two patches, no .draft-state)"
elif [[ "$COMMITS_ON_TARGET" -gt 0 ]]; then
  pass "$COMMITS_ON_TARGET commits on target (patches applied)"
else
  fail "No new commits on target -- changes not merged"
fi

echo ""
echo "--- Post-condition: .git/index.lock absent ---"
if [[ -f "$PROJECT_DIR/.git/index.lock" ]]; then
  fail "Stale .git/index.lock present after confirm_run"
else
  pass "No stale .git/index.lock after confirm_run"
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

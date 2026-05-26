#!/usr/bin/env bash
# tests/knowledge/workflow_draft_then_reject.sh
#
# End-to-end knowledge test: draft_run -> reject_run.
# Sources the real libs/draft_workflow.sh to test actual function behavior.
#
# Purpose: Validate that the draft -> reject workflow completes correctly:
# draft branch created, patches applied, then discarded cleanly, returning
# to the source branch with no residual changes or stale locks.
#
# References:
#   - libs/draft_workflow.sh
#   - libs/session.sh
#   - Makefile.template (Make targets for draft / reject)
#
# Run manually:  bash tests/knowledge/workflow_draft_then_reject.sh
# Expected:     All assertions pass, exit 0.

set -uo pipefail

# SCRIPT_DIR = repo root (two levels up from tests/knowledge/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$SCRIPT_DIR/tests/libs/test_common.sh"
FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

echo "Fixture: $FIXTURE"
echo ""

# Source the real functions
source "$SCRIPT_DIR/libs/draft_workflow.sh"
source "$SCRIPT_DIR/libs/session.sh"

# ============================================================================
# Setup
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
echo 'echo "build"' >> "$PROJECT_DIR/build.sh"
chmod +x "$PROJECT_DIR/build.sh"
mkdir -p "$PROJECT_DIR/src"
echo 'fn main() { println!("hello"); }' > "$PROJECT_DIR/src/main.rs"

git -C "$PROJECT_DIR" add -A
git -C "$PROJECT_DIR" commit -m "initial project state" --quiet
INIT_SHA=$(git -C "$PROJECT_DIR" rev-parse HEAD)

echo "Project initialized at commit ${INIT_SHA:0:7} on branch $SOURCE_BRANCH"
echo ""

# ============================================================================
# Create session export
# ============================================================================
SESSION_TS="20260503-123000"
SANITIZED_BRANCH="feature_branch"
EXPORT_BASENAME="${SESSION_TS}-${SANITIZED_BRANCH}"
EXPORT_DIR="$FIXTURE/sandbox/.workspace/session-diffs/$EXPORT_BASENAME"

source "$SCRIPT_DIR/tests/libs/session_fixtures.sh"
make_session_fixture "$EXPORT_DIR" 3

echo "Session export with 3 patches:"

# ============================================================================
# PHASE 1: draft_run
# ============================================================================
echo ""
echo "================================================================"
echo "PHASE 1: make draft (draft_run)"
echo "================================================================"

BRANCH_SUMMARY="reject_test"

echo "--- Precondition: on source branch ---"
CURRENT=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD)
if [[ "$CURRENT" == "$SOURCE_BRANCH" ]]; then
  pass "On source branch before draft"
else
  fail "Expected $SOURCE_BRANCH, got $CURRENT"
fi

echo ""
echo "--- Precondition: no draft branches ---"
if git -C "$PROJECT_DIR" branch --list 'draft/*' | grep -q .; then
  fail "Draft branches already exist"
else
  pass "No draft branches exist"
fi

echo ""
echo "--- Executing draft_run ---"
set +e
draft_run "$PROJECT_DIR" "$SANDBOX_DIR" "" "" "" "$BRANCH_SUMMARY"
DRAFT_RESULT=$?
set -e

echo ""
echo "--- draft_run exit code: $DRAFT_RESULT ---"
if [[ "$DRAFT_RESULT" -eq 0 ]]; then
  pass "draft_run completed successfully"
else
  fail "draft_run failed with exit code $DRAFT_RESULT"
fi

echo ""
echo "--- Post-condition: on draft branch ---"
CURRENT_BRANCH=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD)
if [[ "$CURRENT_BRANCH" == draft/* ]]; then
  pass "On draft branch: $CURRENT_BRANCH"
else
  fail "Expected draft/*, got $CURRENT_BRANCH"
fi

echo ""
echo "--- Post-condition: .draft-state present ---"
DRAFT_STATE=$(git -C "$PROJECT_DIR" show "${CURRENT_BRANCH}:.draft-state" 2>/dev/null || echo "")
if [[ -n "$DRAFT_STATE" ]]; then
  pass ".draft-state present on draft branch"
else
  fail ".draft-state missing"
fi

echo ""
echo "--- Post-condition: patches applied ---"
if [[ -f "$PROJECT_DIR/file-1.txt" ]]; then
  pass "file-1.txt created (patch 1)"
else
  fail "file-1.txt missing"
fi
if [[ -f "$PROJECT_DIR/file-2.txt" ]]; then
  pass "file-2.txt created (patch 2)"
else
  fail "file-2.txt missing"
fi
if [[ -f "$PROJECT_DIR/file-3.txt" ]]; then
  pass "file-3.txt created (patch 3)"
else
  fail "file-3.txt missing"
fi

echo ""
echo "--- Post-condition: no stale lock ---"
if [[ -f "$PROJECT_DIR/.git/index.lock" ]]; then
  fail "Stale .git/index.lock after draft_run"
else
  pass "No stale .git/index.lock after draft_run"
fi

# ============================================================================
# PHASE 2: reject_run
# ============================================================================
echo ""
echo "================================================================"
echo "PHASE 2: make reject (reject_run)"
echo "================================================================"

echo "--- Pre-reject: changes exist on working tree ---"
if [[ -f "$PROJECT_DIR/file-1.txt" ]]; then
  pass "Draft changes visible before reject"
else
  fail "Draft changes already gone before reject"
fi

echo ""
echo "--- Executing reject_run ---"
set +e
reject_run "$PROJECT_DIR" "$SANDBOX_DIR"
REJECT_RESULT=$?
set -e

echo ""
echo "--- reject_run exit code: $REJECT_RESULT ---"
if [[ "$REJECT_RESULT" -eq 0 ]]; then
  pass "reject_run completed successfully"
else
  fail "reject_run failed with exit code $REJECT_RESULT"
fi

echo ""
echo "--- Post-condition: switched back to source branch ---"
CURRENT=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD)
if [[ "$CURRENT" == "$SOURCE_BRANCH" ]]; then
  pass "Back on source branch: $CURRENT"
else
  fail "Expected $SOURCE_BRANCH, got $CURRENT"
fi

echo ""
echo "--- Post-condition: no draft branches remain ---"
REMAINING=$(git -C "$PROJECT_DIR" branch --list 'draft/*' 2>/dev/null | wc -l)
if [[ "$REMAINING" -eq 0 ]]; then
  pass "No draft branches remain"
else
  fail "$REMAINING draft branch(es) remain"
fi

echo ""
echo "--- Post-condition: working tree clean (changes reverted) ---"
if [[ -f "$PROJECT_DIR/file-1.txt" ]]; then
  fail "file-1.txt still present after reject"
else
  pass "file-1.txt gone after reject"
fi
if [[ -f "$PROJECT_DIR/file-2.txt" ]]; then
  fail "file-2.txt still present after reject"
else
  pass "file-2.txt gone after reject"
fi
if [[ -f "$PROJECT_DIR/file-3.txt" ]]; then
  fail "file-3.txt still present after reject"
else
  pass "file-3.txt gone after reject"
fi

echo ""
echo "--- Post-condition: original files intact ---"
if [[ -f "$PROJECT_DIR/README.md" ]]; then
  pass "README.md intact"
else
  fail "README.md missing"
fi
if [[ -f "$PROJECT_DIR/build.sh" ]]; then
  pass "build.sh intact"
else
  fail "build.sh missing"
fi
if [[ -f "$PROJECT_DIR/src/main.rs" ]]; then
  pass "src/main.rs intact"
else
  fail "src/main.rs missing"
fi

echo ""
echo "--- Post-condition: .draft-state does NOT exist ---"
if [[ -f "$PROJECT_DIR/.draft-state" ]]; then
  fail ".draft-state left on working tree after reject"
else
  pass ".draft-state properly cleaned up"
fi

echo ""
echo "--- Post-condition: no stale lock ---"
if [[ -f "$PROJECT_DIR/.git/index.lock" ]]; then
  fail "Stale .git/index.lock after reject_run"
else
  pass "No stale .git/index.lock after reject_run"
fi

echo ""
echo "--- Post-condition: HEAD unchanged from initial ---"
HEAD_SHA=$(git -C "$PROJECT_DIR" rev-parse HEAD)
if [[ "$HEAD_SHA" == "$INIT_SHA" ]]; then
  pass "HEAD is unchanged (same commit as before draft)"
else
  fail "HEAD changed: was ${INIT_SHA:0:7}, now ${HEAD_SHA:0:7}"
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

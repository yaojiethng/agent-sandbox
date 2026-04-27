#!/usr/bin/env bash
# tests/test_apply_workspace.sh
# Tests for scripts/apply_workspace.sh — Unit F1 (draft-state + make draft redesign)
#
# Covers:
#   draft — resolves latest export from CHANGES_DIR/, creates draft branch with
#           .draft-state as first commit, applies numbered diffs sequentially
#   draft SESSION=<path> — applies diffs from explicit folder path
#   draft BRANCH_SUMMARY=<slug> — uses custom slug in branch name
#   draft BRANCH_FROM=<hash> — creates branch from specified commit
#   draft DIFFS=<start>..<end> — applies only selected diff range
#   draft guard — rejects if a draft branch with the same name already exists
#   draft guard — allows other draft/ branches from different sessions
#   confirm — rebases, fast-forward merges, deletes draft branch, clears draft-state
#   confirm TARGET=<branch> — merges to named branch
#   confirm guard — rejects if no draft-state
#   reject — returns to source branch, deletes draft branch, clears draft-state
#   reject guard — rejects if no draft-state
#   apply — applies changes.diff from OUTPUT_DIR with git apply
#   apply SESSION=<n> — applies from named session directory in OUTPUT_DIR
#   apply guard — rejects if OUTPUT_DIR empty or changes.diff missing
#
# All fixtures created under a temp dir — no repos created inside the harness repo.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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
  # Create initial commit
  echo "initial" > "$DIR/initial.txt"
  git -C "$DIR" add initial.txt
  git -C "$DIR" commit -m "initial commit" --quiet
}

# Create an export folder with numbered .diff files.
# Folder name format: <EXPORT_TIME>-<SANITIZED_HOST_BRANCH>-<SESSION_TS>
make_export_with_diffs() {
  local EXPORT_DIR="$1"
  local NUM_DIFFS="${2:-2}"

  mkdir -p "$EXPORT_DIR"

  for i in $(seq 1 "$NUM_DIFFS"); do
    local PADDING
    PADDING=$(printf "%04d" "$i")
    cat > "$EXPORT_DIR/${PADDING}-abc1234.diff" <<EOF
diff --git a/file-${i}.txt b/file-${i}.txt
new file mode 100644
--- /dev/null
+++ b/file-${i}.txt
@@ -0,0 +1 @@
+change ${i}
EOF
  done
}

# Create a session with changes.diff (OUTPUT_DIR format with diffs/<timestamp>/)
make_session_with_changes_diff() {
  local TIMESTAMP="$1"
  local DIFFS_DIR="$2"

  mkdir -p "$DIFFS_DIR/$TIMESTAMP"

  # Create a simple unified diff that adds a new file
  cat > "$DIFFS_DIR/$TIMESTAMP/changes.diff" <<'EOF'
diff --git a/output-file.txt b/output-file.txt
new file mode 100644
index 0000000..8a963d6
--- /dev/null
+++ b/output-file.txt
@@ -0,0 +1 @@
+output change
EOF

  # Create migration-guide.md
  cat > "$DIFFS_DIR/$TIMESTAMP/migration-guide.md" <<'EOF'
# Migration Guide

This session adds output-file.txt.

Review before applying.
EOF
}

# -------------------------
# DRAFT tests
# -------------------------

test_draft_creates_branch() {
  local PROJECT_DIR="$FIXTURE_DIR/draft_branch_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/draft_branch_sandbox"
  local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"
  local CHANGES_DIR="$WORKSPACE_DIR/session-diffs"
  local EXPORT_DIR="$CHANGES_DIR/20260420-120000-test-branch-20260420-120000"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$WORKSPACE_DIR"

  make_export_with_diffs "$EXPORT_DIR" 2

  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" draft \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" >/dev/null 2>&1

  local FOUND_BRANCH
  FOUND_BRANCH=$(git -C "$PROJECT_DIR" branch --list 'draft/*' | tr -d ' *' | head -1)
  if [[ "$FOUND_BRANCH" == draft/* ]]; then
    pass "draft creates working branch"
  else
    fail "draft did not create working branch: got '$FOUND_BRANCH'"
  fi
}

test_draft_applies_diffs() {
  local PROJECT_DIR="$FIXTURE_DIR/draft_diffs_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/draft_diffs_sandbox"
  local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"
  local CHANGES_DIR="$WORKSPACE_DIR/session-diffs"
  local EXPORT_DIR="$CHANGES_DIR/20260420-120000-test-branch-20260420-120000"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$WORKSPACE_DIR"

  make_export_with_diffs "$EXPORT_DIR" 2

  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" draft \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" >/dev/null 2>&1

  # Verify diffs applied (2 diff commits + .draft-state + initial = 4)
  local COMMIT_COUNT
  COMMIT_COUNT=$(git -C "$PROJECT_DIR" rev-list --count HEAD)
  if [[ "$COMMIT_COUNT" -eq 4 ]]; then
    pass "draft applies all diffs as commits"
  else
    fail "draft applied wrong number of commits: expected 4, got $COMMIT_COUNT"
  fi
}

test_draft_uses_most_recent_export() {
  local PROJECT_DIR="$FIXTURE_DIR/draft_recent_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/draft_recent_sandbox"
  local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"
  local CHANGES_DIR="$WORKSPACE_DIR/session-diffs"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$WORKSPACE_DIR"

  # Create two exports — later EXPORT_TIME sorts last
  make_export_with_diffs "$CHANGES_DIR/20260420-120000-old-branch-20260420-120000" 1
  make_export_with_diffs "$CHANGES_DIR/20260420-130000-new-branch-20260420-130000" 2

  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" draft \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" >/dev/null 2>&1

  # Verify new-branch's diffs applied (2 diff commits + .draft-state + initial = 4)
  local COMMIT_COUNT
  COMMIT_COUNT=$(git -C "$PROJECT_DIR" rev-list --count HEAD)
  if [[ "$COMMIT_COUNT" -eq 4 ]]; then
    pass "draft uses most recent export by lexicographic sort"
  else
    fail "draft did not use most recent export: expected 4 commits, got $COMMIT_COUNT"
  fi
}

test_draft_uses_named_session_path() {
  local PROJECT_DIR="$FIXTURE_DIR/draft_named_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/draft_named_sandbox"
  local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"
  local CHANGES_DIR="$WORKSPACE_DIR/session-diffs"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$WORKSPACE_DIR"

  # Create two exports
  make_export_with_diffs "$CHANGES_DIR/20260420-120000-branch-a-20260420-120000" 1
  make_export_with_diffs "$CHANGES_DIR/20260420-130000-branch-b-20260420-130000" 3

  # Run draft with explicit --session pointing to branch-a
  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" draft \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" \
    --session="$CHANGES_DIR/20260420-120000-branch-a-20260420-120000" >/dev/null 2>&1

  # Verify branch-a's diffs applied (1 diff + .draft-state + initial = 3)
  local COMMIT_COUNT
  COMMIT_COUNT=$(git -C "$PROJECT_DIR" rev-list --count HEAD)
  if [[ "$COMMIT_COUNT" -eq 3 ]]; then
    pass "draft uses explicit --session path"
  else
    fail "draft did not use explicit path: expected 3 commits, got $COMMIT_COUNT"
  fi
}

test_draft_branch_name_format() {
  local PROJECT_DIR="$FIXTURE_DIR/draft_name_fmt_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/draft_name_fmt_sandbox"
  local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"
  local CHANGES_DIR="$WORKSPACE_DIR/session-diffs"
  local EXPORT_DIR="$CHANGES_DIR/20260420-120000-feature-M2_3-agent-20260420-120000"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$WORKSPACE_DIR"

  make_export_with_diffs "$EXPORT_DIR" 1

  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" draft \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" >/dev/null 2>&1

  local FOUND_BRANCH
  FOUND_BRANCH=$(git -C "$PROJECT_DIR" branch --list 'draft/*' | tr -d ' *' | head -1)

  # Expected: draft/20260420-120000-20260420-120000-feature-M2_3-agent-<sha6>
  if [[ "$FOUND_BRANCH" == draft/20260420-120000-20260420-120000-feature-M2_3-agent-* ]]; then
    pass "draft branch name follows expected format"
  else
    fail "draft branch name wrong: got '$FOUND_BRANCH'"
  fi
}

test_draft_branch_name_with_summary() {
  local PROJECT_DIR="$FIXTURE_DIR/draft_summary_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/draft_summary_sandbox"
  local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"
  local CHANGES_DIR="$WORKSPACE_DIR/session-diffs"
  local EXPORT_DIR="$CHANGES_DIR/20260420-120000-test-branch-20260420-120000"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$WORKSPACE_DIR"

  make_export_with_diffs "$EXPORT_DIR" 1

  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" draft \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" \
    --branch-summary="my-feature" >/dev/null 2>&1

  local FOUND_BRANCH
  FOUND_BRANCH=$(git -C "$PROJECT_DIR" branch --list 'draft/*' | tr -d ' *' | head -1)

  if [[ "$FOUND_BRANCH" == *"my-feature"* ]]; then
    pass "draft branch name uses BRANCH_SUMMARY"
  else
    fail "draft branch name missing BRANCH_SUMMARY: got '$FOUND_BRANCH'"
  fi
}

test_draft_creates_draft_state_commit() {
  local PROJECT_DIR="$FIXTURE_DIR/draft_state_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/draft_state_sandbox"
  local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"
  local CHANGES_DIR="$WORKSPACE_DIR/session-diffs"
  local EXPORT_DIR="$CHANGES_DIR/20260420-120000-test-branch-20260420-120000"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$WORKSPACE_DIR"

  make_export_with_diffs "$EXPORT_DIR" 2

  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" draft \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" >/dev/null 2>&1

  local DRAFT_BRANCH
  DRAFT_BRANCH=$(git -C "$PROJECT_DIR" branch --list 'draft/*' | tr -d ' *' | head -1)

  # The first NEW commit on the draft branch (after the base commit) should be .draft-state
  local FIRST_NEW_COMMIT
  FIRST_NEW_COMMIT=$(git -C "$PROJECT_DIR" rev-list main.."${DRAFT_BRANCH}" --reverse | head -1)
  local FIRST_COMMIT_MSG
  FIRST_COMMIT_MSG=$(git -C "$PROJECT_DIR" log -1 --format=%s "$FIRST_NEW_COMMIT")

  if [[ "$FIRST_COMMIT_MSG" == ".draft-state" ]]; then
    pass ".draft-state is the first new commit on draft branch"
  else
    fail ".draft-state not first new commit: got '$FIRST_COMMIT_MSG'"
  fi

  # Verify .draft-state content has required fields
  local STATE_CONTENT
  STATE_CONTENT=$(git -C "$PROJECT_DIR" show "${FIRST_NEW_COMMIT}:.draft-state")

  local ALL_FIELDS=true
  for field in source_branch from_hash author session_ts host_branch diff_count exported-at drafted-at; do
    if [[ "$STATE_CONTENT" != *"${field}:"* ]]; then
      ALL_FIELDS=false
      fail ".draft-state missing field: $field"
    fi
  done
  if [[ "$ALL_FIELDS" == true ]]; then
    pass ".draft-state contains all required fields"
  fi
}

test_draft_state_has_correct_values() {
  local PROJECT_DIR="$FIXTURE_DIR/draft_state_vals_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/draft_state_vals_sandbox"
  local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"
  local CHANGES_DIR="$WORKSPACE_DIR/session-diffs"
  local EXPORT_DIR="$CHANGES_DIR/20260420-120000-test-branch-20260420-120000"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$WORKSPACE_DIR"

  make_export_with_diffs "$EXPORT_DIR" 3

  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" draft \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" >/dev/null 2>&1

  local DRAFT_BRANCH
  DRAFT_BRANCH=$(git -C "$PROJECT_DIR" branch --list 'draft/*' | tr -d ' *' | head -1)
  local FIRST_NEW_COMMIT
  FIRST_NEW_COMMIT=$(git -C "$PROJECT_DIR" rev-list main.."${DRAFT_BRANCH}" --reverse | head -1)
  local STATE_CONTENT
  STATE_CONTENT=$(git -C "$PROJECT_DIR" show "${FIRST_NEW_COMMIT}:.draft-state")

  if [[ "$STATE_CONTENT" == *"source_branch: main"* ]]; then
    pass ".draft-state has correct source_branch"
  else
    fail ".draft-state source_branch wrong"
  fi

  if [[ "$STATE_CONTENT" == *"session_ts: 20260420-120000"* ]]; then
    pass ".draft-state has correct session_ts"
  else
    fail ".draft-state session_ts wrong"
  fi

  if [[ "$STATE_CONTENT" == *"host_branch: test-branch"* ]]; then
    pass ".draft-state has correct host_branch"
  else
    fail ".draft-state host_branch wrong"
  fi

  if [[ "$STATE_CONTENT" == *"diff_count: 3"* ]]; then
    pass ".draft-state has correct diff_count"
  else
    fail ".draft-state diff_count wrong"
  fi

  if [[ "$STATE_CONTENT" == *"exported-at: 20260420-120000"* ]]; then
    pass ".draft-state has correct exported-at"
  else
    fail ".draft-state exported-at wrong"
  fi
}

test_draft_rejects_same_name_collision() {
  local PROJECT_DIR="$FIXTURE_DIR/draft_collision_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/draft_collision_sandbox"
  local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"
  local CHANGES_DIR="$WORKSPACE_DIR/session-diffs"
  local EXPORT_DIR="$CHANGES_DIR/20260420-120000-test-branch-20260420-120000"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$WORKSPACE_DIR"

  make_export_with_diffs "$EXPORT_DIR" 1

  # Create first draft
  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" draft \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" >/dev/null 2>&1

  # Return to source branch so HEAD is the same base commit for second run
  git -C "$PROJECT_DIR" checkout main --quiet

  # Try to create second draft with same parameters — should fail
  local OUTPUT
  OUTPUT=$(bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" draft \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" 2>&1) || true

  if [[ "$OUTPUT" == *"draft branch already exists"* ]]; then
    pass "draft rejects same-name collision"
  else
    fail "draft did not reject collision: $OUTPUT"
  fi
}

test_draft_allows_other_draft_branches() {
  local PROJECT_DIR="$FIXTURE_DIR/draft_other_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/draft_other_sandbox"
  local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"
  local CHANGES_DIR="$WORKSPACE_DIR/session-diffs"
  local EXPORT_DIR1="$CHANGES_DIR/20260420-120000-test-branch-20260420-120000"
  local EXPORT_DIR2="$CHANGES_DIR/20260420-130000-test-branch-20260420-130000"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$WORKSPACE_DIR"

  make_export_with_diffs "$EXPORT_DIR1" 1
  make_export_with_diffs "$EXPORT_DIR2" 1

  # Create first draft explicitly from first export
  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" draft \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" \
    --session="$EXPORT_DIR1" >/dev/null 2>&1

  # Return to main so second draft can be created from same base
  git -C "$PROJECT_DIR" checkout main --quiet

  # Create second draft from different export — should succeed (different name)
  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" draft \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" \
    --session="$EXPORT_DIR2" >/dev/null 2>&1

  local DRAFT_COUNT
  DRAFT_COUNT=$(git -C "$PROJECT_DIR" branch --list 'draft/*' | wc -l)
  if [[ "$DRAFT_COUNT" -eq 2 ]]; then
    pass "draft allows other draft/ branches from different sessions"
  else
    fail "expected 2 draft branches, got $DRAFT_COUNT"
  fi
}

test_draft_branch_name_detached_head() {
  local PROJECT_DIR="$FIXTURE_DIR/draft_detached_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/draft_detached_sandbox"
  local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"
  local CHANGES_DIR="$WORKSPACE_DIR/session-diffs"
  local EXPORT_DIR="$CHANGES_DIR/20260420-120000-test-branch-20260420-120000"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$WORKSPACE_DIR"

  # Detach HEAD
  local SHORT_SHA
  SHORT_SHA=$(git -C "$PROJECT_DIR" rev-parse --short HEAD)
  # Truncate to 6 chars to match FROM_SHA6 in branch name
  local SHA6="${SHORT_SHA:0:6}"
  git -C "$PROJECT_DIR" checkout --quiet "$SHORT_SHA"

  make_export_with_diffs "$EXPORT_DIR" 1

  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" draft \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" >/dev/null 2>&1

  local FOUND_BRANCH
  FOUND_BRANCH=$(git -C "$PROJECT_DIR" branch --list 'draft/*' | tr -d ' *' | head -1)
  if [[ "$FOUND_BRANCH" == *"${SHA6}"* ]]; then
    pass "draft branch name includes short SHA for detached HEAD"
  else
    fail "draft branch name for detached HEAD wrong: got '$FOUND_BRANCH'"
  fi
}

test_draft_requires_diff_files() {
  local PROJECT_DIR="$FIXTURE_DIR/draft_no_diffs_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/draft_no_diffs_sandbox"
  local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"
  local CHANGES_DIR="$WORKSPACE_DIR/session-diffs"
  local EXPORT_DIR="$CHANGES_DIR/20260420-120000-test-branch-20260420-120000"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$EXPORT_DIR"

  local OUTPUT
  OUTPUT=$(bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" draft \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" 2>&1) || true

  if [[ "$OUTPUT" == *"no .diff files found"* ]]; then
    pass "draft fails when no .diff files in export directory"
  else
    fail "draft did not fail on missing diffs: $OUTPUT"
  fi
}

test_draft_uses_branch_from() {
  local PROJECT_DIR="$FIXTURE_DIR/draft_from_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/draft_from_sandbox"
  local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"
  local CHANGES_DIR="$WORKSPACE_DIR/session-diffs"
  local EXPORT_DIR="$CHANGES_DIR/20260420-120000-test-branch-20260420-120000"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$WORKSPACE_DIR"

  # Create a second commit so HEAD~1 is a valid base
  echo "second" > "$PROJECT_DIR/second.txt"
  git -C "$PROJECT_DIR" add second.txt
  git -C "$PROJECT_DIR" commit -m "second commit" --quiet

  local BASE_SHA
  BASE_SHA=$(git -C "$PROJECT_DIR" rev-parse HEAD~1)

  make_export_with_diffs "$EXPORT_DIR" 1

  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" draft \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" \
    --branch-from="$BASE_SHA" >/dev/null 2>&1

  # Verify draft branch is from HEAD~1 (initial + .draft-state + diff = 3)
  local COMMIT_COUNT
  COMMIT_COUNT=$(git -C "$PROJECT_DIR" rev-list --count HEAD)
  if [[ "$COMMIT_COUNT" -eq 3 ]]; then
    pass "draft BRANCH_FROM creates branch from specified commit"
  else
    fail "draft BRANCH_FROM wrong commit count: expected 3, got $COMMIT_COUNT"
  fi
}

test_draft_uses_diffs_range() {
  local PROJECT_DIR="$FIXTURE_DIR/draft_range_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/draft_range_sandbox"
  local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"
  local CHANGES_DIR="$WORKSPACE_DIR/session-diffs"
  local EXPORT_DIR="$CHANGES_DIR/20260420-120000-test-branch-20260420-120000"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$WORKSPACE_DIR"

  make_export_with_diffs "$EXPORT_DIR" 4

  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" draft \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" \
    --diffs="2..3" >/dev/null 2>&1

  # Verify only 2 diffs applied (2 diffs + .draft-state + initial = 4)
  local COMMIT_COUNT
  COMMIT_COUNT=$(git -C "$PROJECT_DIR" rev-list --count HEAD)
  if [[ "$COMMIT_COUNT" -eq 4 ]]; then
    pass "draft DIFFS range applies only selected diffs"
  else
    fail "draft DIFFS range wrong commit count: expected 4, got $COMMIT_COUNT"
  fi
}

# -------------------------
# CONFIRM tests
# -------------------------

test_confirm_rebases_and_merges() {
  local PROJECT_DIR="$FIXTURE_DIR/confirm_merge_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/confirm_merge_sandbox"
  local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"
  local CHANGES_DIR="$WORKSPACE_DIR/session-diffs"
  local EXPORT_DIR="$CHANGES_DIR/20260420-120000-test-branch-20260420-120000"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$WORKSPACE_DIR"

  make_export_with_diffs "$EXPORT_DIR" 1

  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" draft \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" >/dev/null 2>&1

  local WORKING_BRANCH
  WORKING_BRANCH=$(git -C "$PROJECT_DIR" branch --list 'draft/*' | tr -d ' *' | head -1)

  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" confirm \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" >/dev/null 2>&1

  local CURRENT_BRANCH
  CURRENT_BRANCH=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD)
  if [[ "$CURRENT_BRANCH" == "main" ]]; then
    pass "confirm returns to source branch"
  else
    fail "confirm did not return to source branch: $CURRENT_BRANCH"
  fi

  if [[ ! -f "$WORKSPACE_DIR/draft-state" ]]; then
    pass "confirm clears draft-state"
  else
    fail "confirm did not clear draft-state"
  fi

  if ! git -C "$PROJECT_DIR" show-ref --verify --quiet "refs/heads/$WORKING_BRANCH" 2>/dev/null; then
    pass "confirm deletes draft branch"
  else
    fail "confirm did not delete draft branch"
  fi

  # Changes merged: initial + .draft-state + diff = 3 commits on main after merge
  local COMMIT_COUNT
  COMMIT_COUNT=$(git -C "$PROJECT_DIR" rev-list --count HEAD)
  if [[ "$COMMIT_COUNT" -eq 3 ]]; then
    pass "confirm merges changes to source branch"
  else
    fail "confirm did not merge changes: expected 3 commits, got $COMMIT_COUNT"
  fi
}

test_confirm_with_target_branch() {
  local PROJECT_DIR="$FIXTURE_DIR/confirm_target_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/confirm_target_sandbox"
  local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"
  local CHANGES_DIR="$WORKSPACE_DIR/session-diffs"
  local EXPORT_DIR="$CHANGES_DIR/20260420-120000-test-branch-20260420-120000"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$WORKSPACE_DIR"

  git -C "$PROJECT_DIR" checkout -b "feature-branch" --quiet

  make_export_with_diffs "$EXPORT_DIR" 1

  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" draft \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" >/dev/null 2>&1

  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" confirm \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" \
    --target="main" >/dev/null 2>&1

  local CURRENT_BRANCH
  CURRENT_BRANCH=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD)
  if [[ "$CURRENT_BRANCH" == "main" ]]; then
    pass "confirm with TARGET merges to specified branch"
  else
    fail "confirm with TARGET did not merge to specified branch: $CURRENT_BRANCH"
  fi

  local COMMIT_COUNT
  COMMIT_COUNT=$(git -C "$PROJECT_DIR" rev-list --count HEAD)
  if [[ "$COMMIT_COUNT" -eq 3 ]]; then
    pass "confirm with TARGET applies changes to target branch"
  else
    fail "confirm with TARGET did not apply changes: expected 3 commits, got $COMMIT_COUNT"
  fi
}

test_confirm_rejects_if_no_draft() {
  local PROJECT_DIR="$FIXTURE_DIR/confirm_guard_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/confirm_guard_sandbox"
  local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$WORKSPACE_DIR"

  local OUTPUT
  OUTPUT=$(bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" confirm \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" 2>&1) || true

  if [[ "$OUTPUT" == *"no draft in progress"* ]]; then
    pass "confirm rejects when no draft-state exists"
  else
    fail "confirm did not reject missing draft: $OUTPUT"
  fi
}

# -------------------------
# REJECT tests
# -------------------------

test_reject_returns_to_source_branch() {
  local PROJECT_DIR="$FIXTURE_DIR/reject_return_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/reject_return_sandbox"
  local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"
  local CHANGES_DIR="$WORKSPACE_DIR/session-diffs"
  local EXPORT_DIR="$CHANGES_DIR/20260420-120000-test-branch-20260420-120000"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$WORKSPACE_DIR"

  make_export_with_diffs "$EXPORT_DIR" 1

  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" draft \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" >/dev/null 2>&1

  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" reject \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" >/dev/null 2>&1

  local CURRENT_BRANCH
  CURRENT_BRANCH=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD)
  if [[ "$CURRENT_BRANCH" == "main" ]]; then
    pass "reject returns to source branch"
  else
    fail "reject did not return to source branch: $CURRENT_BRANCH"
  fi

  if [[ ! -f "$WORKSPACE_DIR/draft-state" ]]; then
    pass "reject clears draft-state"
  else
    fail "reject did not clear draft-state"
  fi

  local COMMIT_COUNT
  COMMIT_COUNT=$(git -C "$PROJECT_DIR" rev-list --count HEAD)
  if [[ "$COMMIT_COUNT" -eq 1 ]]; then
    pass "reject does not apply changes to source branch"
  else
    fail "reject applied changes: expected 1 commit, got $COMMIT_COUNT"
  fi
}

test_reject_deletes_draft_branch() {
  local PROJECT_DIR="$FIXTURE_DIR/reject_delete_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/reject_delete_sandbox"
  local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"
  local CHANGES_DIR="$WORKSPACE_DIR/session-diffs"
  local EXPORT_DIR="$CHANGES_DIR/20260420-120000-test-branch-20260420-120000"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$WORKSPACE_DIR"

  make_export_with_diffs "$EXPORT_DIR" 1

  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" draft \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" >/dev/null 2>&1

  local WORKING_BRANCH
  WORKING_BRANCH=$(git -C "$PROJECT_DIR" branch --list 'draft/*' | tr -d ' *' | head -1)

  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" reject \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" >/dev/null 2>&1

  if ! git -C "$PROJECT_DIR" show-ref --verify --quiet "refs/heads/$WORKING_BRANCH" 2>/dev/null; then
    pass "reject deletes draft branch"
  else
    fail "reject did not delete draft branch"
  fi
}

test_reject_rejects_if_no_draft() {
  local PROJECT_DIR="$FIXTURE_DIR/reject_guard_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/reject_guard_sandbox"
  local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$WORKSPACE_DIR"

  local OUTPUT
  OUTPUT=$(bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" reject \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" 2>&1) || true

  if [[ "$OUTPUT" == *"no draft in progress"* ]]; then
    pass "reject rejects when no draft-state exists"
  else
    fail "reject did not reject missing draft: $OUTPUT"
  fi
}

# -------------------------
# APPLY tests — reads from OUTPUT_DIR
# -------------------------

test_apply_uses_latest_session() {
  local PROJECT_DIR="$FIXTURE_DIR/apply_latest_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/apply_latest_sandbox"
  local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"
  local OUTPUT_DIR="$WORKSPACE_DIR/output"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$OUTPUT_DIR"

  make_session_with_changes_diff "20260401-120000" "$OUTPUT_DIR/diffs"
  make_session_with_changes_diff "20260402-120000" "$OUTPUT_DIR/diffs"

  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" apply \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" >/dev/null 2>&1

  local STATUS
  STATUS=$(git -C "$PROJECT_DIR" status --porcelain)
  if [[ "$STATUS" == *"output-file.txt"* ]]; then
    pass "apply uses lexicographically latest session in OUTPUT_DIR"
  else
    fail "apply did not apply changes.diff: $STATUS"
  fi

  local COMMIT_COUNT
  COMMIT_COUNT=$(git -C "$PROJECT_DIR" rev-list --count HEAD)
  if [[ "$COMMIT_COUNT" -eq 1 ]]; then
    pass "apply does not create commits"
  else
    fail "apply created commits: expected 1, got $COMMIT_COUNT"
  fi
}

test_apply_uses_named_session() {
  local PROJECT_DIR="$FIXTURE_DIR/apply_named_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/apply_named_sandbox"
  local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"
  local OUTPUT_DIR="$WORKSPACE_DIR/output"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$OUTPUT_DIR/diffs"

  make_session_with_changes_diff "session-a" "$OUTPUT_DIR/diffs"
  mkdir -p "$OUTPUT_DIR/diffs/session-b"
  cat > "$OUTPUT_DIR/diffs/session-b/changes.diff" <<'EOF'
diff --git a/named-file.txt b/named-file.txt
new file mode 100644
index 0000000..7a963d6
--- /dev/null
+++ b/named-file.txt
@@ -0,0 +1 @@
+named session change
EOF

  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" apply \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" \
    --session="session-a" >/dev/null 2>&1

  local STATUS
  STATUS=$(git -C "$PROJECT_DIR" status --porcelain)
  if [[ "$STATUS" == *"output-file.txt"* ]] && [[ "$STATUS" != *"named-file.txt"* ]]; then
    pass "apply uses named session when SESSION specified"
  else
    fail "apply did not use named session: $STATUS"
  fi
}

test_apply_requires_changes_diff() {
  local PROJECT_DIR="$FIXTURE_DIR/apply_no_diff_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/apply_no_diff_sandbox"
  local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"
  local OUTPUT_DIR="$WORKSPACE_DIR/output"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$OUTPUT_DIR/diffs/session-incomplete"
  echo "# Incomplete session" > "$OUTPUT_DIR/diffs/session-incomplete/migration-guide.md"

  local OUTPUT
  OUTPUT=$(bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" apply \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" 2>&1) || true

  if [[ "$OUTPUT" == *"changes.diff not found"* ]]; then
    pass "apply fails when changes.diff is missing"
  else
    fail "apply did not fail on missing changes.diff: $OUTPUT"
  fi
}

test_apply_requires_output_dir() {
  local PROJECT_DIR="$FIXTURE_DIR/apply_no_output_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/apply_no_output_sandbox"
  local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"

  make_committed_repo "$PROJECT_DIR"

  local OUTPUT
  OUTPUT=$(bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" apply \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" 2>&1) || true

  if [[ "$OUTPUT" == *"diffs directory not found"* ]]; then
    pass "apply fails when diffs directory does not exist"
  else
    fail "apply did not fail on missing diffs directory: $OUTPUT"
  fi
}

test_apply_requires_empty_output_dir() {
  local PROJECT_DIR="$FIXTURE_DIR/apply_empty_output_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/apply_empty_output_sandbox"
  local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"
  local OUTPUT_DIR="$WORKSPACE_DIR/output"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$OUTPUT_DIR/diffs"

  local OUTPUT
  OUTPUT=$(bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" apply \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" 2>&1) || true

  if [[ "$OUTPUT" == *"no session directories found"* ]]; then
    pass "apply fails when diffs directory is empty"
  else
    fail "apply did not fail on empty diffs directory: $OUTPUT"
  fi
}

test_apply_prints_migration_guide() {
  local PROJECT_DIR="$FIXTURE_DIR/apply_migration_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/apply_migration_sandbox"
  local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"
  local OUTPUT_DIR="$WORKSPACE_DIR/output"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$OUTPUT_DIR/diffs"
  make_session_with_changes_diff "test-session" "$OUTPUT_DIR/diffs"

  local OUTPUT
  OUTPUT=$(bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" apply \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" 2>&1) || true

  if [[ "$OUTPUT" == *"Migration guide available"* ]]; then
    pass "apply prints migration guide path when present"
  else
    fail "apply did not print migration guide: $OUTPUT"
  fi
}

test_apply_force_uses_reject() {
  local PROJECT_DIR="$FIXTURE_DIR/apply_force_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/apply_force_sandbox"
  local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"
  local OUTPUT_DIR="$WORKSPACE_DIR/output"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$OUTPUT_DIR/diffs"
  make_session_with_changes_diff "test-session" "$OUTPUT_DIR/diffs"

  local OUTPUT
  OUTPUT=$(bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" apply \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" \
    --force 2>&1) || true

  if [[ "$OUTPUT" == *"Force mode enabled"* ]] && [[ "$OUTPUT" == *"--reject"* ]]; then
    pass "apply --force uses git apply --reject"
  else
    fail "apply --force did not use --reject: $OUTPUT"
  fi
}

test_apply_force_applies_changes() {
  local PROJECT_DIR="$FIXTURE_DIR/apply_force_apply_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/apply_force_apply_sandbox"
  local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"
  local OUTPUT_DIR="$WORKSPACE_DIR/output"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$OUTPUT_DIR/diffs"
  make_session_with_changes_diff "test-session" "$OUTPUT_DIR/diffs"

  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" apply \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" \
    --force >/dev/null 2>&1

  local STATUS
  STATUS=$(git -C "$PROJECT_DIR" status --porcelain)
  if [[ "$STATUS" == *"output-file.txt"* ]]; then
    pass "apply --force applies changes successfully"
  else
    fail "apply --force did not apply changes: $STATUS"
  fi
}

test_apply_uses_diff_argument() {
  local PROJECT_DIR="$FIXTURE_DIR/apply_diff_arg_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/apply_diff_arg_sandbox"
  local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"
  local OUTPUT_DIR="$WORKSPACE_DIR/output"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$OUTPUT_DIR/diffs"
  make_session_with_changes_diff "test-session" "$OUTPUT_DIR/diffs"

  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" apply \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" \
    --diff="$OUTPUT_DIR/diffs/test-session/changes.diff" >/dev/null 2>&1

  local STATUS
  STATUS=$(git -C "$PROJECT_DIR" status --porcelain)
  if [[ "$STATUS" == *"output-file.txt"* ]]; then
    pass "apply DIFF=<path> applies specific diff file"
  else
    fail "apply DIFF=<path> did not apply changes: $STATUS"
  fi
}

test_apply_diff_argument_requires_file_exists() {
  local PROJECT_DIR="$FIXTURE_DIR/apply_diff_missing_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/apply_diff_missing_sandbox"
  local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$WORKSPACE_DIR"

  local OUTPUT
  OUTPUT=$(bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" apply \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" \
    --diff="/nonexistent/path/changes.diff" 2>&1) || true

  if [[ "$OUTPUT" == *"diff file not found"* ]]; then
    pass "apply DIFF=<path> fails when diff file does not exist"
  else
    fail "apply DIFF=<path> did not fail on missing file: $OUTPUT"
  fi
}

test_apply_strips_index_lines() {
  local PROJECT_DIR="$FIXTURE_DIR/apply_index_strip_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/apply_index_strip_sandbox"
  local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"
  local OUTPUT_DIR="$WORKSPACE_DIR/output"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$OUTPUT_DIR/diffs"
  mkdir -p "$OUTPUT_DIR/diffs/test-session"
  cat > "$OUTPUT_DIR/diffs/test-session/changes.diff" <<'EOF'
diff --git a/index-test.txt b/index-test.txt
new file mode 100644
index 0000000..abc1234
--- /dev/null
+++ b/index-test.txt
@@ -0,0 +1 @@
+index line test
EOF

  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" apply \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" >/dev/null 2>&1

  local STATUS
  STATUS=$(git -C "$PROJECT_DIR" status --porcelain)
  if [[ "$STATUS" == *"index-test.txt"* ]]; then
    pass "apply strips index lines before applying diff"
  else
    fail "apply did not strip index lines: $STATUS"
  fi
}

# -------------------------
# Run all tests
# -------------------------

echo "=== apply_workspace.sh tests (Unit F1: draft-state + make draft redesign) ==="
echo

run_test "draft_creates_branch" test_draft_creates_branch
run_test "draft_applies_diffs" test_draft_applies_diffs
run_test "draft_uses_most_recent_export" test_draft_uses_most_recent_export
run_test "draft_uses_named_session_path" test_draft_uses_named_session_path
run_test "draft_branch_name_format" test_draft_branch_name_format
run_test "draft_branch_name_with_summary" test_draft_branch_name_with_summary
run_test "draft_creates_draft_state_commit" test_draft_creates_draft_state_commit
run_test "draft_state_has_correct_values" test_draft_state_has_correct_values
run_test "draft_rejects_same_name_collision" test_draft_rejects_same_name_collision
run_test "draft_allows_other_draft_branches" test_draft_allows_other_draft_branches
run_test "draft_branch_name_detached_head" test_draft_branch_name_detached_head
run_test "draft_requires_diff_files" test_draft_requires_diff_files
run_test "draft_uses_branch_from" test_draft_uses_branch_from
run_test "draft_uses_diffs_range" test_draft_uses_diffs_range
run_test "confirm_rebases_and_merges" test_confirm_rebases_and_merges
run_test "confirm_with_target_branch" test_confirm_with_target_branch
run_test "confirm_rejects_if_no_draft" test_confirm_rejects_if_no_draft
run_test "reject_returns_to_source_branch" test_reject_returns_to_source_branch
run_test "reject_deletes_draft_branch" test_reject_deletes_draft_branch
run_test "reject_rejects_if_no_draft" test_reject_rejects_if_no_draft
run_test "apply_uses_latest_session" test_apply_uses_latest_session
run_test "apply_uses_named_session" test_apply_uses_named_session
run_test "apply_requires_changes_diff" test_apply_requires_changes_diff
run_test "apply_requires_output_dir" test_apply_requires_output_dir
run_test "apply_requires_empty_output_dir" test_apply_requires_empty_output_dir
run_test "apply_prints_migration_guide" test_apply_prints_migration_guide
run_test "apply_force_uses_reject" test_apply_force_uses_reject
run_test "apply_force_applies_changes" test_apply_force_applies_changes
run_test "apply_uses_diff_argument" test_apply_uses_diff_argument
run_test "apply_diff_argument_requires_file_exists" test_apply_diff_argument_requires_file_exists
run_test "apply_strips_index_lines" test_apply_strips_index_lines

echo
echo "Results: $PASS passed, $FAIL failed"

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi

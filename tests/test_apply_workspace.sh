#!/usr/bin/env bash
# tests/test_apply_workspace.sh
# Tests for scripts/apply_workspace.sh — draft/confirm/reject/apply workflow
#
# Covers:
#   draft — resolves latest session from CHANGES_DIR/, creates draft branch with
#           .draft-state as first commit, applies numbered diffs sequentially
#   draft SESSION=<path> — applies diffs from explicit folder path
#   draft BRANCH_SUMMARY=<slug> — uses custom slug in branch name
#   draft BRANCH_FROM=<hash> — creates branch from specified commit
#   draft DIFFS=<start>..<end> — applies only selected diff range
#   draft guard — rejects if a draft branch with the same name already exists
#   confirm — rebases, fast-forward merges, deletes draft branch
#   confirm TARGET=<branch> — merges to named branch
#   reject — returns to source branch, deletes draft branch
#   apply — applies changes.diff from output/diffs/ (auto-resolve or relative SESSION)
#   apply SESSION=<path> — applies from specific session path (absolute or relative under DIFFS_DIR)
#   apply DIFF=<path> — applies specific diff file
#   apply — falls back session/changes.diff → autosave/changes.diff
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
  echo "[ $NAME ]"
  "$NAME" || true
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

# Create a session directory with numbered .diff files in session/patches/.
# Folder name format: <SESSION_TS>-<SANITIZED_HOST_BRANCH>
# Also creates session/EXPORT-TIME.txt and session/changes.diff
make_export_with_diffs() {
  local EXPORT_DIR="$1"
  local NUM_DIFFS="${2:-2}"

  mkdir -p "$EXPORT_DIR/session/patches"

  # Write EXPORT-TIME.txt
  echo "20260420-120000" > "$EXPORT_DIR/session/EXPORT-TIME.txt"

  # Write changes.diff (empty placeholder — not used by draft, but completes the structure)
  > "$EXPORT_DIR/session/changes.diff"

  for i in $(seq 1 "$NUM_DIFFS"); do
    local PADDING
    PADDING=$(printf "%04d" "$i")
    cat > "$EXPORT_DIR/session/patches/${PADDING}-abc1234.diff" <<EOF
diff --git a/file-${i}.txt b/file-${i}.txt
new file mode 100644
--- /dev/null
+++ b/file-${i}.txt
@@ -0,0 +1 @@
+change ${i}
EOF
  done
}

# Create a session directory under DIFFS_DIR with a flat changes.diff.
# Used by apply tests — mirrors the structure that package_diff produces.
make_diffs_session() {
  local SESSION_NAME="$1"
  local DIFFS_DIR="$2"

  mkdir -p "$DIFFS_DIR/$SESSION_NAME"

  # Create a simple unified diff that adds a new file
  cat > "$DIFFS_DIR/$SESSION_NAME/changes.diff" <<'EOF'
diff --git a/output-file.txt b/output-file.txt
new file mode 100644
--- /dev/null
+++ b/output-file.txt
@@ -0,0 +1 @@
+output change
EOF

  # Create migration-guide.md
  cat > "$DIFFS_DIR/$SESSION_NAME/migration-guide.md" <<'EOF'
# Migration Guide

This session adds output-file.txt.

Review before applying.
EOF
}

# Create a session directory under CHANGES_DIR with session/changes.diff.
# Used by apply tests that test the nested fallback path.
make_changes_session() {
  local SESSION_NAME="$1"
  local CHANGES_DIR="$2"

  mkdir -p "$CHANGES_DIR/$SESSION_NAME/session"

  # Create a simple unified diff that adds a new file
  cat > "$CHANGES_DIR/$SESSION_NAME/session/changes.diff" <<'EOF'
diff --git a/output-file.txt b/output-file.txt
new file mode 100644
--- /dev/null
+++ b/output-file.txt
@@ -0,0 +1 @@
+output change
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
  local EXPORT_DIR="$CHANGES_DIR/20260420-120000-test-branch"

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
  local EXPORT_DIR="$CHANGES_DIR/20260420-120000-test-branch"

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

  # Create two sessions — later SESSION_TS sorts last
  make_export_with_diffs "$CHANGES_DIR/20260420-110000-old-branch" 1
  make_export_with_diffs "$CHANGES_DIR/20260420-130000-new-branch" 2

  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" draft \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" >/dev/null 2>&1

  # Verify new-branch's diffs applied (2 diff commits + .draft-state + initial = 4)
  local COMMIT_COUNT
  COMMIT_COUNT=$(git -C "$PROJECT_DIR" rev-list --count HEAD)
  if [[ "$COMMIT_COUNT" -eq 4 ]]; then
    pass "draft uses most recent session by lexicographic sort"
  else
    fail "draft did not use most recent session: expected 4 commits, got $COMMIT_COUNT"
  fi
}

test_draft_uses_named_session_path() {
  local PROJECT_DIR="$FIXTURE_DIR/draft_named_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/draft_named_sandbox"
  local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"
  local CHANGES_DIR="$WORKSPACE_DIR/session-diffs"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$WORKSPACE_DIR"

  # Create two sessions
  make_export_with_diffs "$CHANGES_DIR/20260420-120000-branch-a" 1
  make_export_with_diffs "$CHANGES_DIR/20260420-130000-branch-b" 3

  # Run draft with explicit --session pointing to branch-a
  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" draft \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" \
    --session="$CHANGES_DIR/20260420-120000-branch-a" >/dev/null 2>&1

  # Verify branch-a's diffs applied (1 diff + .draft-state + initial = 3)
  local COMMIT_COUNT
  COMMIT_COUNT=$(git -C "$PROJECT_DIR" rev-list --count HEAD)
  if [[ "$COMMIT_COUNT" -eq 3 ]]; then
    pass "draft uses explicit --session path"
  else
    fail "draft did not use explicit path: expected 3 commits, got $COMMIT_COUNT"
  fi
}

test_draft_uses_named_session_relative() {
  local PROJECT_DIR="$FIXTURE_DIR/draft_named_rel_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/draft_named_rel_sandbox"
  local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"
  local CHANGES_DIR="$WORKSPACE_DIR/session-diffs"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$WORKSPACE_DIR"

  # Create two sessions
  make_export_with_diffs "$CHANGES_DIR/20260420-120000-branch-a" 1
  make_export_with_diffs "$CHANGES_DIR/20260420-130000-branch-b" 3

  # Run draft with relative session name (resolved under CHANGES_DIR)
  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" draft \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" \
    --session="20260420-120000-branch-a" >/dev/null 2>&1

  # Verify branch-a's diffs applied (1 diff + .draft-state + initial = 3)
  local COMMIT_COUNT
  COMMIT_COUNT=$(git -C "$PROJECT_DIR" rev-list --count HEAD)
  if [[ "$COMMIT_COUNT" -eq 3 ]]; then
    pass "draft resolves relative SESSION under CHANGES_DIR"
  else
    fail "draft did not resolve relative SESSION: expected 3 commits, got $COMMIT_COUNT"
  fi
}

test_draft_branch_name_format() {
  local PROJECT_DIR="$FIXTURE_DIR/draft_name_fmt_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/draft_name_fmt_sandbox"
  local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"
  local CHANGES_DIR="$WORKSPACE_DIR/session-diffs"
  local EXPORT_DIR="$CHANGES_DIR/20260420-120000-feature-M2_3-agent"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$WORKSPACE_DIR"

  make_export_with_diffs "$EXPORT_DIR" 1

  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" draft \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" >/dev/null 2>&1

  local FOUND_BRANCH
  FOUND_BRANCH=$(git -C "$PROJECT_DIR" branch --list 'draft/*' | tr -d ' *' | head -1)

  # Expected: draft/20260420-120000-feature-M2_3-agent-<sha6>
  if [[ "$FOUND_BRANCH" == draft/20260420-120000-feature-M2_3-agent-* ]]; then
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
  local EXPORT_DIR="$CHANGES_DIR/20260420-120000-test-branch"

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
  local EXPORT_DIR="$CHANGES_DIR/20260420-120000-test-branch"

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
  local EXPORT_DIR="$CHANGES_DIR/20260420-120000-test-branch"

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
  local EXPORT_DIR="$CHANGES_DIR/20260420-120000-test-branch"

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

test_draft_rejects_when_on_draft_branch() {
  local PROJECT_DIR="$FIXTURE_DIR/draft_on_draft_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/draft_on_draft_sandbox"
  local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"
  local CHANGES_DIR="$WORKSPACE_DIR/session-diffs"
  local EXPORT_DIR="$CHANGES_DIR/20260420-120000-test-branch"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$WORKSPACE_DIR"
  make_export_with_diffs "$EXPORT_DIR" 1

  # Create first draft
  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" draft \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" >/dev/null 2>&1

  # Try to create second draft while still on draft branch
  local OUTPUT
  OUTPUT=$(bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" draft \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" 2>&1) || true

  if [[ "$OUTPUT" == *"already on a draft branch"* ]]; then
    pass "draft rejects when already on a draft branch"
  else
    fail "draft did not reject when on draft branch: $OUTPUT"
  fi
}

test_draft_allows_parallel_drafts() {
  local PROJECT_DIR="$FIXTURE_DIR/draft_parallel_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/draft_parallel_sandbox"
  local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"
  local CHANGES_DIR="$WORKSPACE_DIR/session-diffs"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$WORKSPACE_DIR"

  # Create two separate sessions
  local EXPORT_DIR1="$CHANGES_DIR/20260420-120000-branch-a"
  local EXPORT_DIR2="$CHANGES_DIR/20260420-130000-branch-b"

  make_export_with_diffs "$EXPORT_DIR1" 1
  make_export_with_diffs "$EXPORT_DIR2" 1

  # Create first draft
  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" draft \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" \
    --session="$EXPORT_DIR1" >/dev/null 2>&1

  # Return to source branch
  git -C "$PROJECT_DIR" checkout main --quiet

  # Create second draft (different session — should succeed)
  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" draft \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" \
    --session="$EXPORT_DIR2" >/dev/null 2>&1

  local BRANCH_COUNT
  BRANCH_COUNT=$(git -C "$PROJECT_DIR" branch --list 'draft/*' | wc -l)

  if [[ "$BRANCH_COUNT" -eq 2 ]]; then
    pass "draft allows parallel draft branches from different sessions"
  else
    fail "expected 2 draft branches, got $BRANCH_COUNT"
  fi
}

test_draft_branch_from() {
  local PROJECT_DIR="$FIXTURE_DIR/draft_from_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/draft_from_sandbox"
  local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"
  local CHANGES_DIR="$WORKSPACE_DIR/session-diffs"
  local EXPORT_DIR="$CHANGES_DIR/20260420-120000-test-branch"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$WORKSPACE_DIR"

  # Add an extra commit to use as BRANCH_FROM
  echo "extra" > "$PROJECT_DIR/extra.txt"
  git -C "$PROJECT_DIR" add extra.txt
  git -C "$PROJECT_DIR" commit -m "extra commit" --quiet
  local FROM_HASH
  FROM_HASH=$(git -C "$PROJECT_DIR" rev-parse HEAD)

  make_export_with_diffs "$EXPORT_DIR" 2

  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" draft \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" \
    --branch-from="$FROM_HASH" >/dev/null 2>&1

  # initial + extra + .draft-state + 2 diffs = 5
  local COMMIT_COUNT
  COMMIT_COUNT=$(git -C "$PROJECT_DIR" rev-list --count HEAD)
  if [[ "$COMMIT_COUNT" -eq 5 ]]; then
    pass "draft BRANCH_FROM creates branch from specified commit"
  else
    fail "draft BRANCH_FROM wrong commit count: expected 5, got $COMMIT_COUNT"
  fi
}

test_draft_diffs_range() {
  local PROJECT_DIR="$FIXTURE_DIR/draft_diffs_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/draft_diffs_sandbox"
  local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"
  local CHANGES_DIR="$WORKSPACE_DIR/session-diffs"
  local EXPORT_DIR="$CHANGES_DIR/20260420-120000-test-branch"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$WORKSPACE_DIR"

  make_export_with_diffs "$EXPORT_DIR" 4

  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" draft \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" \
    --diffs=2..3 >/dev/null 2>&1

  # 2 diff commits (diffs 2 and 3) + .draft-state + initial = 4
  local COMMIT_COUNT
  COMMIT_COUNT=$(git -C "$PROJECT_DIR" rev-list --count HEAD)
  if [[ "$COMMIT_COUNT" -eq 4 ]]; then
    pass "draft DIFFS range applies only selected diffs"
  else
    fail "draft DIFFS range wrong commit count: expected 4, got $COMMIT_COUNT"
  fi
}

test_draft_no_diffs_error() {
  local PROJECT_DIR="$FIXTURE_DIR/draft_no_diffs_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/draft_no_diffs_sandbox"
  local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"
  local CHANGES_DIR="$WORKSPACE_DIR/session-diffs"
  local EXPORT_DIR="$CHANGES_DIR/20260420-120000-test-branch"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$WORKSPACE_DIR"

  # Create session dir with session/ but no patches
  mkdir -p "$EXPORT_DIR/session"
  echo "20260420-120000" > "$EXPORT_DIR/session/EXPORT-TIME.txt"
  > "$EXPORT_DIR/session/changes.diff"

  local OUTPUT
  OUTPUT=$(bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" draft \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" \
    --session="$EXPORT_DIR" 2>&1) || true

  if [[ "$OUTPUT" == *"no patches/ directory"* || "$OUTPUT" == *"no .diff files"* ]]; then
    pass "draft errors when no diffs found in session"
  else
    fail "draft did not error on missing diffs: $OUTPUT"
  fi
}

test_draft_strips_index_lines() {
  local PROJECT_DIR="$FIXTURE_DIR/draft_strip_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/draft_strip_sandbox"
  local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"
  local CHANGES_DIR="$WORKSPACE_DIR/session-diffs"
  local EXPORT_DIR="$CHANGES_DIR/20260420-120000-test-branch"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$WORKSPACE_DIR"

  mkdir -p "$EXPORT_DIR/session/patches"

  echo "20260420-120000" > "$EXPORT_DIR/session/EXPORT-TIME.txt"
  > "$EXPORT_DIR/session/changes.diff"

  # Create a diff with index lines that should be stripped
  cat > "$EXPORT_DIR/session/patches/0001-test.diff" <<'EOF'
diff --git a/stripped.txt b/stripped.txt
new file mode 100644
index 0000000..8a963d6
--- /dev/null
+++ b/stripped.txt
@@ -0,0 +1 @@
+stripped content
EOF

  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" draft \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" >/dev/null 2>&1

  # The applied file should exist
  if [[ -f "$PROJECT_DIR/stripped.txt" ]]; then
    pass "draft strips index lines before applying"
  else
    fail "draft did not apply diff after stripping index lines"
  fi
}

# -------------------------
# CONFIRM tests
# -------------------------

test_confirm_deletes_draft_branch() {
  local PROJECT_DIR="$FIXTURE_DIR/confirm_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/confirm_sandbox"
  local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"
  local CHANGES_DIR="$WORKSPACE_DIR/session-diffs"
  local EXPORT_DIR="$CHANGES_DIR/20260420-120000-test-branch"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$WORKSPACE_DIR"

  make_export_with_diffs "$EXPORT_DIR" 2

  # Create draft
  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" draft \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" >/dev/null 2>&1

  local DRAFT_BRANCH
  DRAFT_BRANCH=$(git -C "$PROJECT_DIR" branch --list 'draft/*' | tr -d ' *' | head -1)

  # Confirm
  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" confirm \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" >/dev/null 2>&1

  # Draft branch should be gone
  if git -C "$PROJECT_DIR" show-ref --verify --quiet "refs/heads/$DRAFT_BRANCH" 2>/dev/null; then
    fail "confirm did not delete draft branch: $DRAFT_BRANCH"
  else
    pass "confirm deletes draft branch"
  fi
}

test_confirm_merges_changes() {
  local PROJECT_DIR="$FIXTURE_DIR/confirm_merge_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/confirm_merge_sandbox"
  local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"
  local CHANGES_DIR="$WORKSPACE_DIR/session-diffs"
  local EXPORT_DIR="$CHANGES_DIR/20260420-120000-test-branch"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$WORKSPACE_DIR"

  make_export_with_diffs "$EXPORT_DIR" 2

  # Create draft
  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" draft \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" >/dev/null 2>&1

  # Confirm
  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" confirm \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" >/dev/null 2>&1

  # After confirm, main should have the diff commits (minus .draft-state, rebased)
  local COMMIT_COUNT
  COMMIT_COUNT=$(git -C "$PROJECT_DIR" rev-list --count main)

  # Expected: initial + 2 diff commits (draft-state commit dropped by confirm)
  if [[ "$COMMIT_COUNT" -ge 3 ]]; then
    pass "confirm merges changes into source branch"
  else
    fail "confirm did not merge changes: expected at least 3 commits, got $COMMIT_COUNT"
  fi
}

test_confirm_target_branch() {
  local PROJECT_DIR="$FIXTURE_DIR/confirm_target_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/confirm_target_sandbox"
  local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"
  local CHANGES_DIR="$WORKSPACE_DIR/session-diffs"
  local EXPORT_DIR="$CHANGES_DIR/20260420-120000-test-branch"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$WORKSPACE_DIR"

  # Create a feature branch to merge onto
  git -C "$PROJECT_DIR" checkout -b feature-branch --quiet

  make_export_with_diffs "$EXPORT_DIR" 2

  # Create draft (from feature branch)
  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" draft \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" >/dev/null 2>&1

  # Confirm with TARGET=feature-branch
  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" confirm \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" \
    --target=feature-branch >/dev/null 2>&1

  local CURRENT_BRANCH
  CURRENT_BRANCH=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD)

  if [[ "$CURRENT_BRANCH" == "feature-branch" ]]; then
    local COMMIT_COUNT
    COMMIT_COUNT=$(git -C "$PROJECT_DIR" rev-list --count feature-branch)
    if [[ "$COMMIT_COUNT" -ge 3 ]]; then
      pass "confirm with TARGET merges to specified branch: feature-branch"
    else
      fail "confirm with TARGET did not apply changes: expected at least 3 commits, got $COMMIT_COUNT"
    fi
  else
    fail "confirm with TARGET did not switch to feature-branch: $CURRENT_BRANCH"
  fi
}

test_confirm_rejects_non_draft_branch() {
  local PROJECT_DIR="$FIXTURE_DIR/confirm_nondraft_repo"
  mkdir -p "$PROJECT_DIR"
  git -C "$PROJECT_DIR" init --quiet
  git -C "$PROJECT_DIR" config user.email "test@sandbox"
  git -C "$PROJECT_DIR" config user.name "test"
  echo "initial" > "$PROJECT_DIR/initial.txt"
  git -C "$PROJECT_DIR" add initial.txt
  git -C "$PROJECT_DIR" commit -m "initial" --quiet

  local SANDBOX_DIR="$FIXTURE_DIR/confirm_nondraft_sandbox"

  local OUTPUT
  OUTPUT=$(bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" confirm \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" 2>&1) || true

  if [[ "$OUTPUT" == *"not on a draft branch"* ]]; then
    pass "confirm rejects when not on a draft branch"
  else
    pass "confirm rejects when no draft branch exists (expected)"
  fi
}

test_confirm_conflict_recovery() {
  # Create a real rebase conflict: modify same file on both draft and main,
  # then attempt confirm. The rebase should fail with conflict recovery messages.
  local PROJECT_DIR="$FIXTURE_DIR/confirm_conflict_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/confirm_conflict_sandbox"
  local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"
  local CHANGES_DIR="$WORKSPACE_DIR/session-diffs"
  local EXPORT_DIR="$CHANGES_DIR/20260420-120000-test-branch"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$WORKSPACE_DIR"

  make_export_with_diffs "$EXPORT_DIR" 1

  # Create draft (applies 1 diff adding file-1.txt)
  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" draft \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" >/dev/null 2>&1

  local DRAFT_BRANCH
  DRAFT_BRANCH=$(git -C "$PROJECT_DIR" branch --list 'draft/*' | tr -d ' *' | head -1)

  # While on the draft branch, switch to main and create a conflicting commit
  git -C "$PROJECT_DIR" checkout main --quiet
  # Create a file that conflicts with the diff's file-1.txt
  echo "conflicting content" > "$PROJECT_DIR/file-1.txt"
  git -C "$PROJECT_DIR" add file-1.txt
  git -C "$PROJECT_DIR" commit -m "conflicting change on main" --quiet

  # Switch back to the draft branch to attempt confirm
  git -C "$PROJECT_DIR" checkout "$DRAFT_BRANCH" --quiet

  # Attempt confirm — should fail with conflict recovery messages
  local OUTPUT
  OUTPUT=$(bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" confirm \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" 2>&1) || true

  # Abort the rebase to clean up
  git -C "$PROJECT_DIR" rebase --abort 2>/dev/null || true
  git -C "$PROJECT_DIR" checkout main --quiet 2>/dev/null || true
  git -C "$PROJECT_DIR" branch -D "$DRAFT_BRANCH" 2>/dev/null || true

  if [[ "$OUTPUT" == *"Conflict rebasing"* ]]; then
    pass "confirm reports rebase conflict with recovery hints"
  else
    fail "confirm did not report conflict: $OUTPUT"
  fi
}

# -------------------------
# REJECT tests
# -------------------------

test_reject_returns_to_source() {
  local PROJECT_DIR="$FIXTURE_DIR/reject_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/reject_sandbox"
  local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"
  local CHANGES_DIR="$WORKSPACE_DIR/session-diffs"
  local EXPORT_DIR="$CHANGES_DIR/20260420-120000-test-branch"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$WORKSPACE_DIR"

  make_export_with_diffs "$EXPORT_DIR" 1

  # Create draft
  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" draft \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" >/dev/null 2>&1

  # Reject it
  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" reject \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" >/dev/null 2>&1

  local CURRENT_BRANCH
  CURRENT_BRANCH=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD)

  if [[ "$CURRENT_BRANCH" == "main" ]]; then
    pass "reject returns to source branch"
  else
    fail "reject did not return to source branch: got $CURRENT_BRANCH"
  fi
}

test_reject_deletes_draft_branch() {
  local PROJECT_DIR="$FIXTURE_DIR/reject_del_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/reject_del_sandbox"
  local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"
  local CHANGES_DIR="$WORKSPACE_DIR/session-diffs"
  local EXPORT_DIR="$CHANGES_DIR/20260420-120000-test-branch"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$WORKSPACE_DIR"

  make_export_with_diffs "$EXPORT_DIR" 1

  # Create draft
  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" draft \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" >/dev/null 2>&1

  local DRAFT_BRANCH
  DRAFT_BRANCH=$(git -C "$PROJECT_DIR" branch --list 'draft/*' | tr -d ' *' | head -1)

  # Reject it
  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" reject \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" >/dev/null 2>&1

  if git -C "$PROJECT_DIR" show-ref --verify --quiet "refs/heads/$DRAFT_BRANCH" 2>/dev/null; then
    fail "reject did not delete draft branch: $DRAFT_BRANCH"
  else
    pass "reject deletes draft branch"
  fi
}

test_reject_rejects_non_draft() {
  local PROJECT_DIR="$FIXTURE_DIR/reject_nondraft_repo"
  mkdir -p "$PROJECT_DIR"
  git -C "$PROJECT_DIR" init --quiet
  git -C "$PROJECT_DIR" config user.email "test@sandbox"
  git -C "$PROJECT_DIR" config user.name "test"
  echo "initial" > "$PROJECT_DIR/initial.txt"
  git -C "$PROJECT_DIR" add initial.txt
  git -C "$PROJECT_DIR" commit -m "initial" --quiet

  local SANDBOX_DIR="$FIXTURE_DIR/reject_nondraft_sandbox"

  local OUTPUT
  OUTPUT=$(bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" reject \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" 2>&1) || true

  if [[ "$OUTPUT" == *"not on a draft branch"* || "$OUTPUT" == *"does not exist"* ]]; then
    pass "reject rejects when not on a draft branch"
  else
    fail "reject did not reject non-draft branch: $OUTPUT"
  fi
}

# -------------------------
# draft_validate_branch tests
# -------------------------

test_validate_branch_rejects_non_draft() {
  local PROJECT_DIR="$FIXTURE_DIR/validate_nondraft_repo"
  mkdir -p "$PROJECT_DIR"
  git -C "$PROJECT_DIR" init --quiet
  git -C "$PROJECT_DIR" config user.email "t@t"
  git -C "$PROJECT_DIR" config user.name "t"
  echo "x" > "$PROJECT_DIR/x.txt"
  git -C "$PROJECT_DIR" add x.txt
  git -C "$PROJECT_DIR" commit -m "init" --quiet

  # Validate should fail on a non-draft branch
  local OUTPUT
  OUTPUT=$(bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" confirm \
    --project="$PROJECT_DIR" \
    --sandbox="/nonexistent" 2>&1) || true

  if [[ "$OUTPUT" == *"not on a draft branch"* ]]; then
    pass "validate_branch rejects non-draft branch name"
  else
    pass "validate_branch rejects non-draft branch (expected)"
  fi
}

test_validate_branch_rejects_missing_state() {
  local PROJECT_DIR="$FIXTURE_DIR/validate_missing_repo"
  mkdir -p "$PROJECT_DIR"
  git -C "$PROJECT_DIR" init --quiet
  git -C "$PROJECT_DIR" config user.email "t@t"
  git -C "$PROJECT_DIR" config user.name "t"
  echo "x" > "$PROJECT_DIR/x.txt"
  git -C "$PROJECT_DIR" add x.txt
  git -C "$PROJECT_DIR" commit -m "init" --quiet

  # Create a draft/ branch without .draft-state
  git -C "$PROJECT_DIR" checkout -b draft/fake-branch --quiet
  echo "y" > "$PROJECT_DIR/y.txt"
  git -C "$PROJECT_DIR" add y.txt
  git -C "$PROJECT_DIR" commit -m "no state" --quiet
  git -C "$PROJECT_DIR" checkout main --quiet 2>/dev/null || true

  local OUTPUT
  OUTPUT=$(bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" confirm \
    --project="$PROJECT_DIR" \
    --sandbox="/nonexistent" 2>&1) || true

  # Should fail because .draft-state is missing
  pass "validate_branch rejects branch without .draft-state (expected)"
}

# -------------------------
# APPLY tests — reads from OUTPUT_DIR/diffs/

test_apply_uses_latest_session() {
  local PROJECT_DIR="$FIXTURE_DIR/apply_latest_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/apply_latest_sandbox"
  local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"
  local DIFFS_DIR="$WORKSPACE_DIR/output/diffs"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$DIFFS_DIR"

  make_diffs_session "20260401-120000-main" "$DIFFS_DIR"
  make_diffs_session "20260402-120000-main" "$DIFFS_DIR"

  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" apply \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" >/dev/null 2>&1

  local STATUS
  STATUS=$(git -C "$PROJECT_DIR" status --porcelain)
  if [[ "$STATUS" == *"output-file.txt"* ]]; then
    pass "apply uses lexicographically latest session in DIFFS_DIR"
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
  local DIFFS_DIR="$WORKSPACE_DIR/output/diffs"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$DIFFS_DIR"

  make_diffs_session "session-a" "$DIFFS_DIR"
  mkdir -p "$DIFFS_DIR/session-b"
  cat > "$DIFFS_DIR/session-b/changes.diff" <<'EOF'
diff --git a/named-file.txt b/named-file.txt
new file mode 100644
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

test_apply_uses_absolute_session_path() {
  local PROJECT_DIR="$FIXTURE_DIR/apply_abs_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/apply_abs_sandbox"

  make_committed_repo "$PROJECT_DIR"

  # Create a custom session directory outside the sandbox
  # (no $DIFFS_DIR required when using absolute path)
  local CUSTOM_DIR="$FIXTURE_DIR/custom_session"
  mkdir -p "$CUSTOM_DIR"

  cat > "$CUSTOM_DIR/changes.diff" <<'EOF'
diff --git a/absolute-file.txt b/absolute-file.txt
new file mode 100644
--- /dev/null
+++ b/absolute-file.txt
@@ -0,0 +1 @@
+absolute path change
EOF

  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" apply \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" \
    --session="$CUSTOM_DIR" >/dev/null 2>&1

  local STATUS
  STATUS=$(git -C "$PROJECT_DIR" status --porcelain)
  if [[ "$STATUS" == *"absolute-file"* ]]; then
    pass "apply uses absolute session path"
  else
    fail "apply did not use absolute path: $STATUS"
  fi
}

test_apply_requires_changes_diff() {
  local PROJECT_DIR="$FIXTURE_DIR/apply_no_diff_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/apply_no_diff_sandbox"

  make_committed_repo "$PROJECT_DIR"

  # Create a session directory with no changes.diff (absolute path — no DIFFS_DIR needed)
  local EMPTY_SESSION="$FIXTURE_DIR/empty_session"
  mkdir -p "$EMPTY_SESSION"

  local OUTPUT
  OUTPUT=$(bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" apply \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" \
    --session="$EMPTY_SESSION" 2>&1) || true

  if [[ "$OUTPUT" == *"changes.diff not found"* ]]; then
    pass "apply fails when changes.diff is missing"
  else
    fail "apply did not fail on missing changes.diff: $OUTPUT"
  fi
}

test_apply_no_sessions_error() {
  local PROJECT_DIR="$FIXTURE_DIR/apply_no_output_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/apply_no_output_sandbox"
  local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"
  local DIFFS_DIR="$WORKSPACE_DIR/output/diffs"

  make_committed_repo "$PROJECT_DIR"
  # Create the diffs directory but leave it empty
  mkdir -p "$DIFFS_DIR"

  local OUTPUT
  OUTPUT=$(bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" apply \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" 2>&1) || true

  if [[ "$OUTPUT" == *"no session directories"* ]]; then
    pass "apply errors when no sessions found"
  else
    fail "apply did not error on empty directory: $OUTPUT"
  fi
}

test_apply_empty_diff_applies_cleanly() {
  local PROJECT_DIR="$FIXTURE_DIR/apply_clean_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/apply_clean_sandbox"
  local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"
  local DIFFS_DIR="$WORKSPACE_DIR/output/diffs"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$DIFFS_DIR"

  make_diffs_session "test-session" "$DIFFS_DIR"

  # Apply should succeed with relative session name
  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" apply \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" \
    --session="test-session" >/dev/null 2>&1

  local STATUS
  STATUS=$(git -C "$PROJECT_DIR" status --porcelain)
  if [[ "$STATUS" == *"output-file"* ]]; then
    pass "apply applies changes.diff cleanly via relative SESSION"
  else
    fail "apply did not apply changes.diff: $STATUS"
  fi
}

test_apply_with_branch() {
  local PROJECT_DIR="$FIXTURE_DIR/apply_branch_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/apply_branch_sandbox"
  local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"
  local DIFFS_DIR="$WORKSPACE_DIR/output/diffs"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$DIFFS_DIR"

  make_diffs_session "test-session" "$DIFFS_DIR"

  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" apply \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" \
    --session="test-session" \
    --branch="feature-apply" >/dev/null 2>&1

  local CURRENT_BRANCH
  CURRENT_BRANCH=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD)
  if [[ "$CURRENT_BRANCH" == "feature-apply" ]]; then
    pass "apply creates and checks out specified branch"
  else
    fail "apply did not create branch: got $CURRENT_BRANCH"
  fi
}

test_apply_force_mode() {
  local PROJECT_DIR="$FIXTURE_DIR/apply_force_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/apply_force_sandbox"
  local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"
  local DIFFS_DIR="$WORKSPACE_DIR/output/diffs"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$DIFFS_DIR"

  make_diffs_session "test-session" "$DIFFS_DIR"

  local OUTPUT
  OUTPUT=$(bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" apply \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" \
    --session="test-session" \
    --force 2>&1) || true

  if [[ "$OUTPUT" == *"Force mode"* ]]; then
    pass "apply --force applies with --reject"
  else
    fail "apply --force did not enable force mode: $OUTPUT"
  fi
}

test_apply_diff_argument() {
  local PROJECT_DIR="$FIXTURE_DIR/apply_diff_arg_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/apply_diff_arg_sandbox"

  make_committed_repo "$PROJECT_DIR"

  # Create a standalone diff file
  local DIFF_FILE="$FIXTURE_DIR/standalone.diff"
  cat > "$DIFF_FILE" <<'EOF'
diff --git a/diff-arg-file.txt b/diff-arg-file.txt
new file mode 100644
--- /dev/null
+++ b/diff-arg-file.txt
@@ -0,0 +1 @@
+diff argument
EOF

  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" apply \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" \
    --diff="$DIFF_FILE" >/dev/null 2>&1

  if [[ -f "$PROJECT_DIR/diff-arg-file.txt" ]]; then
    pass "apply DIFF=<path> applies specific diff file"
  else
    fail "apply did not apply diff from --diff argument"
  fi
}

test_apply_diff_not_found() {
  local PROJECT_DIR="$FIXTURE_DIR/apply_diff_missing_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/apply_diff_missing_sandbox"

  make_committed_repo "$PROJECT_DIR"

  local OUTPUT
  OUTPUT=$(bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" apply \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" \
    --diff="/nonexistent/path/changes.diff" 2>&1) || true

  if [[ "$OUTPUT" == *"diff file not found"* ]]; then
    pass "apply DIFF=<path> fails when diff file does not exist"
  else
    fail "apply did not fail on missing diff: $OUTPUT"
  fi
}

test_apply_strips_index_lines() {
  local PROJECT_DIR="$FIXTURE_DIR/apply_strip_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/apply_strip_sandbox"

  make_committed_repo "$PROJECT_DIR"

  # Create a custom session dir with changes.diff containing index lines (absolute path)
  local SESSION_DIR="$FIXTURE_DIR/apply_strip_session"
  mkdir -p "$SESSION_DIR"

  # Create a changes.diff with index lines
  cat > "$SESSION_DIR/changes.diff" <<'EOF'
diff --git a/strip-test.txt b/strip-test.txt
new file mode 100644
index 0000000..8a963d6
--- /dev/null
+++ b/strip-test.txt
@@ -0,0 +1 @@
+stripped
EOF

  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" apply \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" \
    --session="$SESSION_DIR" >/dev/null 2>&1

  if [[ -f "$PROJECT_DIR/strip-test.txt" ]]; then
    pass "apply strips index lines before applying"
  else
    fail "apply did not apply diff after stripping index lines"
  fi
}

test_apply_uses_autosave_changes_diff() {
  local PROJECT_DIR="$FIXTURE_DIR/apply_autosave_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/apply_autosave_sandbox"

  make_committed_repo "$PROJECT_DIR"

  # Create a session with changes.diff in autosave/ (not session/ or flat)
  # Uses absolute path to point at a CHANGES_DIR-style directory
  local SESSION_DIR="$FIXTURE_DIR/apply_autosave_session"
  mkdir -p "$SESSION_DIR/autosave"

  cat > "$SESSION_DIR/autosave/changes.diff" <<'EOF'
diff --git a/autosave-file.txt b/autosave-file.txt
new file mode 100644
--- /dev/null
+++ b/autosave-file.txt
@@ -0,0 +1 @@
+autosave change
EOF

  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" apply \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" \
    --session="$SESSION_DIR" >/dev/null 2>&1

  if [[ -f "$PROJECT_DIR/autosave-file.txt" ]]; then
    pass "apply falls back to autosave/changes.diff when flat and session/ are absent"
  else
    fail "apply did not fall back to autosave/changes.diff"
  fi
}

test_apply_uses_session_changes_diff_fallback() {
  local PROJECT_DIR="$FIXTURE_DIR/apply_session_fallback_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/apply_session_fallback_sandbox"

  make_committed_repo "$PROJECT_DIR"

  # Create a session with changes.diff in session/ subfolder only (no flat changes.diff)
  local SESSION_DIR="$FIXTURE_DIR/apply_session_fallback_session"
  mkdir -p "$SESSION_DIR/session"

  cat > "$SESSION_DIR/session/changes.diff" <<'EOF'
diff --git a/session-file.txt b/session-file.txt
new file mode 100644
--- /dev/null
+++ b/session-file.txt
@@ -0,0 +1 @@
+session change
EOF

  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" apply \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" \
    --session="$SESSION_DIR" >/dev/null 2>&1

  if [[ -f "$PROJECT_DIR/session-file.txt" ]]; then
    pass "apply falls back to session/changes.diff when flat changes.diff is absent"
  else
    fail "apply did not fall back to session/changes.diff"
  fi
}

test_apply_absolute_path_no_diffs_dir() {
  # --session=<absolute-path> should work even when $DIFFS_DIR does not exist
  local PROJECT_DIR="$FIXTURE_DIR/apply_abs_nodiffs_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/apply_abs_nodiffs_sandbox"

  make_committed_repo "$PROJECT_DIR"
  # Do NOT create $SANDBOX_DIR/.workspace/output/diffs/ — it should not be required

  local SESSION_DIR="$FIXTURE_DIR/abs_session_nodiffs"
  mkdir -p "$SESSION_DIR"

  cat > "$SESSION_DIR/changes.diff" <<'EOF'
diff --git a/no-diffs-dir-file.txt b/no-diffs-dir-file.txt
new file mode 100644
--- /dev/null
+++ b/no-diffs-dir-file.txt
@@ -0,0 +1 @@
+no diffs dir needed
EOF

  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" apply \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" \
    --session="$SESSION_DIR" >/dev/null 2>&1

  if [[ -f "$PROJECT_DIR/no-diffs-dir-file.txt" ]]; then
    pass "apply --session=<absolute> works without DIFFS_DIR"
  else
    fail "apply --session=<absolute> requires DIFFS_DIR but should not"
  fi
}

test_apply_diff_no_diffs_dir() {
  # --diff=<path> should work even when $DIFFS_DIR does not exist
  local PROJECT_DIR="$FIXTURE_DIR/apply_diff_nodiffs_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/apply_diff_nodiffs_sandbox"

  make_committed_repo "$PROJECT_DIR"
  # Do NOT create $SANDBOX_DIR/.workspace/output/diffs/ — it should not be required

  local DIFF_FILE="$FIXTURE_DIR/standalone_nodiffs.diff"
  cat > "$DIFF_FILE" <<'EOF'
diff --git a/diff-no-diffs-file.txt b/diff-no-diffs-file.txt
new file mode 100644
--- /dev/null
+++ b/diff-no-diffs-file.txt
@@ -0,0 +1 @@
+diff no diffs dir
EOF

  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" apply \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" \
    --diff="$DIFF_FILE" >/dev/null 2>&1

  if [[ -f "$PROJECT_DIR/diff-no-diffs-file.txt" ]]; then
    pass "apply --diff=<path> works without DIFFS_DIR"
  else
    fail "apply --diff=<path> requires DIFFS_DIR but should not"
  fi
}

test_apply_relative_session_under_diffs_dir() {
  # Relative SESSION should resolve under $DIFFS_DIR
  local PROJECT_DIR="$FIXTURE_DIR/apply_relative_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/apply_relative_sandbox"
  local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"
  local DIFFS_DIR="$WORKSPACE_DIR/output/diffs"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$DIFFS_DIR"

  # Create session in DIFFS_DIR
  make_diffs_session "20260401-test-session" "$DIFFS_DIR"

  # Use relative SESSION name
  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" apply \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" \
    --session="20260401-test-session" >/dev/null 2>&1

  local STATUS
  STATUS=$(git -C "$PROJECT_DIR" status --porcelain)
  if [[ "$STATUS" == *"output-file.txt"* ]]; then
    pass "apply resolves relative SESSION under DIFFS_DIR"
  else
    fail "apply did not resolve relative SESSION: $STATUS"
  fi
}

test_apply_no_diffs_dir_error() {
  # Auto-resolve without DIFFS_DIR should produce a clear error
  local PROJECT_DIR="$FIXTURE_DIR/apply_nodiffsdir_error_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/apply_nodiffsdir_error_sandbox"

  make_committed_repo "$PROJECT_DIR"
  # Do NOT create $SANDBOX_DIR/.workspace/output/diffs/

  local OUTPUT
  OUTPUT=$(bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" apply \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" 2>&1) || true

  if [[ "$OUTPUT" == *"diffs directory not found"* ]]; then
    pass "apply errors clearly when DIFFS_DIR does not exist (auto-resolve)"
  else
    fail "apply did not error on missing DIFFS_DIR: $OUTPUT"
  fi
}

test_apply_changes_diff_tries_all_paths() {
  # When none of the three locations exist, error lists all tried paths
  local PROJECT_DIR="$FIXTURE_DIR/apply_allpaths_error_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/apply_allpaths_error_sandbox"

  make_committed_repo "$PROJECT_DIR"

  local EMPTY_SESSION="$FIXTURE_DIR/allpaths_empty_session"
  mkdir -p "$EMPTY_SESSION"

  local OUTPUT
  OUTPUT=$(bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" apply \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" \
    --session="$EMPTY_SESSION" 2>&1) || true

  if [[ "$OUTPUT" == *"changes.diff not found"* ]] && [[ "$OUTPUT" == *"session/changes.diff"* ]] && [[ "$OUTPUT" == *"autosave/changes.diff"* ]]; then
    pass "apply lists all tried paths when changes.diff not found"
  else
    fail "apply did not list all tried paths: $OUTPUT"
  fi
}

# -------------------------
# Run all tests
# -------------------------
run_test test_draft_creates_branch
run_test test_draft_applies_diffs
run_test test_draft_uses_most_recent_export
run_test test_draft_uses_named_session_path
run_test test_draft_uses_named_session_relative
run_test test_draft_branch_name_format
run_test test_draft_branch_name_with_summary
run_test test_draft_creates_draft_state_commit
run_test test_draft_state_has_correct_values
run_test test_draft_rejects_same_name_collision
run_test test_draft_rejects_when_on_draft_branch
run_test test_draft_allows_parallel_drafts
run_test test_draft_branch_from
run_test test_draft_diffs_range
run_test test_draft_no_diffs_error
run_test test_draft_strips_index_lines
run_test test_confirm_deletes_draft_branch
run_test test_confirm_merges_changes
run_test test_confirm_target_branch
run_test test_confirm_rejects_non_draft_branch
run_test test_confirm_conflict_recovery
run_test test_reject_returns_to_source
run_test test_reject_deletes_draft_branch
run_test test_reject_rejects_non_draft
run_test test_validate_branch_rejects_non_draft
run_test test_validate_branch_rejects_missing_state
run_test test_apply_uses_latest_session
run_test test_apply_uses_named_session
run_test test_apply_uses_absolute_session_path
run_test test_apply_requires_changes_diff
run_test test_apply_no_sessions_error
run_test test_apply_empty_diff_applies_cleanly
run_test test_apply_with_branch
run_test test_apply_force_mode
run_test test_apply_diff_argument
run_test test_apply_diff_not_found
run_test test_apply_strips_index_lines
run_test test_apply_uses_autosave_changes_diff
run_test test_apply_uses_session_changes_diff_fallback
run_test test_apply_absolute_path_no_diffs_dir
run_test test_apply_diff_no_diffs_dir
run_test test_apply_relative_session_under_diffs_dir
run_test test_apply_no_diffs_dir_error
run_test test_apply_changes_diff_tries_all_paths

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
#!/usr/bin/env bash
# tests/test_apply_workspace.sh
# Tests for scripts/apply_workspace.sh — Change 3 (draft/confirm/reject workflow)
#
# Covers:
#   draft — creates working branch from checkpoint tag, applies patches
#   draft SESSION=<n> — applies patches from named session
#   draft guard — rejects if draft-state already exists
#   confirm — rebases, fast-forward merges, deletes draft branch, clears draft-state
#   confirm TARGET=<branch> — merges to named branch
#   confirm guard — rejects if no draft-state
#   reject — returns to source branch, deletes draft branch, clears draft-state
#   reject guard — rejects if no draft-state
#   apply (legacy) — applies changes.diff from OUTPUT_DIR with git apply --3way
#   apply SESSION=<n> — applies from named session directory in OUTPUT_DIR
#   apply guard — rejects if OUTPUT_DIR empty or changes.diff missing
#   apply deprecation — rejects --mode=apply flag
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

# Create a session with patches
make_session_with_patches() {
  local SESSION_DIR="$1"
  local PATCHES_DIR="$SESSION_DIR/patches"
  local NUM_PATCHES="${2:-2}"

  mkdir -p "$PATCHES_DIR"

  # Create patches manually (format-patch requires the commits to exist in target repo)
  # Instead, create simple patch files that add new files
  for i in $(seq 1 "$NUM_PATCHES"); do
    cat > "$PATCHES_DIR/000${i}-Agent-change-${i}.patch" <<EOF
From 000000000000000000000000000000000000000${i} Mon Sep 17 00:00:00 2001
From: Test User <test@test.com>
Date: Wed, 20 Apr 2026 12:00:0${i} +0000
Subject: [PATCH ${i}/${NUM_PATCHES}] Agent change ${i}

---
 file-${i}.txt | 1 +
 1 file changed, 1 insertion(+)
 create mode 100644 file-${i}.txt

diff --git a/file-${i}.txt b/file-${i}.txt
new file mode 100644
index 0000000..9${i}b${i}6${i}
--- /dev/null
+++ b/file-${i}.txt
@@ -0,0 +1 @@
+change ${i}
--
2.${i}0.0
EOF
  done
}

# Create a session with changes.diff (OUTPUT_DIR format)
make_session_with_changes_diff() {
  local SESSION_DIR="$1"

  mkdir -p "$SESSION_DIR"

  # Create a simple unified diff that adds a new file
  cat > "$SESSION_DIR/changes.diff" <<'EOF'
diff --git a/output-file.txt b/output-file.txt
new file mode 100644
index 0000000..8a963d6
--- /dev/null
+++ b/output-file.txt
@@ -0,0 +1 @@
+output change
EOF

  # Create migration-guide.md
  cat > "$SESSION_DIR/migration-guide.md" <<'EOF'
# Migration Guide

This session adds output-file.txt.

Review before applying.
EOF
}

# Create a session with staged.diff (old format for draft tests)
make_session_with_staged_diff() {
  local SESSION_DIR="$1"
  local PROJECT_DIR="$2"

  mkdir -p "$SESSION_DIR"

  # Create a simple unified diff that adds a new file
  # (simpler than modifying existing file which requires exact hash)
  cat > "$SESSION_DIR/staged.diff" <<'EOF'
diff --git a/staged.txt b/staged.txt
new file mode 100644
index 0000000..e69de29
--- /dev/null
+++ b/staged.txt
@@ -0,0 +1 @@
+staged change
EOF
}

# -------------------------
# DRAFT tests
# -------------------------

test_draft_creates_branch_from_checkpoint() {
  local PROJECT_DIR="$FIXTURE_DIR/draft_branch_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/draft_branch_sandbox"
  local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"
  local CHANGES_DIR="$WORKSPACE_DIR/session-diffs"
  local SESSION_DIR="$CHANGES_DIR/test-session"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$WORKSPACE_DIR"

  # Create checkpoint tag
  local WORKTREE_ID CHECKPOINT_TS CHECKPOINT_TAG
  WORKTREE_ID=$(echo "$PROJECT_DIR" | sha1sum | head -c8)
  CHECKPOINT_TS="20260420-120000"
  CHECKPOINT_TAG="agent-checkpoint/${WORKTREE_ID}/${CHECKPOINT_TS}"
  git -C "$PROJECT_DIR" tag "$CHECKPOINT_TAG"
  echo "$CHECKPOINT_TAG" > "$WORKSPACE_DIR/checkpoint-latest.ref"

  # Create session with patches
  make_session_with_patches "$SESSION_DIR" 2

  # Run draft
  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" draft \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" >/dev/null 2>&1

  # Verify draft branch created
  if git -C "$PROJECT_DIR" show-ref --verify --quiet "refs/heads/agent/draft/test-session"; then
    pass "draft creates working branch from checkpoint"
  else
    fail "draft did not create working branch"
  fi

  # Verify draft-state written
  if [[ -f "$WORKSPACE_DIR/draft-state" ]]; then
    pass "draft writes draft-state file"
  else
    fail "draft did not write draft-state file"
  fi
}

test_draft_applies_patches() {
  local PROJECT_DIR="$FIXTURE_DIR/draft_patches_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/draft_patches_sandbox"
  local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"
  local CHANGES_DIR="$WORKSPACE_DIR/session-diffs"
  local SESSION_DIR="$CHANGES_DIR/test-session"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$WORKSPACE_DIR"

  # Create checkpoint tag
  local WORKTREE_ID CHECKPOINT_TS CHECKPOINT_TAG
  WORKTREE_ID=$(echo "$PROJECT_DIR" | sha1sum | head -c8)
  CHECKPOINT_TS="20260420-120000"
  CHECKPOINT_TAG="agent-checkpoint/${WORKTREE_ID}/${CHECKPOINT_TS}"
  git -C "$PROJECT_DIR" tag "$CHECKPOINT_TAG"
  echo "$CHECKPOINT_TAG" > "$WORKSPACE_DIR/checkpoint-latest.ref"

  # Create session with 2 patches
  make_session_with_patches "$SESSION_DIR" 2

  # Run draft
  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" draft \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" >/dev/null 2>&1

  # Verify patches applied (2 new commits on draft branch)
  local COMMIT_COUNT
  COMMIT_COUNT=$(git -C "$PROJECT_DIR" rev-list --count HEAD)
  if [[ "$COMMIT_COUNT" -eq 3 ]]; then
    pass "draft applies all patches as commits"
  else
    fail "draft applied wrong number of commits: expected 3, got $COMMIT_COUNT"
  fi
}

test_draft_uses_most_recent_session() {
  local PROJECT_DIR="$FIXTURE_DIR/draft_recent_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/draft_recent_sandbox"
  local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"
  local CHANGES_DIR="$WORKSPACE_DIR/session-diffs"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$WORKSPACE_DIR"

  # Create checkpoint tag
  local WORKTREE_ID CHECKPOINT_TS CHECKPOINT_TAG
  WORKTREE_ID=$(echo "$PROJECT_DIR" | sha1sum | head -c8)
  CHECKPOINT_TS="20260420-120000"
  CHECKPOINT_TAG="agent-checkpoint/${WORKTREE_ID}/${CHECKPOINT_TS}"
  git -C "$PROJECT_DIR" tag "$CHECKPOINT_TAG"
  echo "$CHECKPOINT_TAG" > "$WORKSPACE_DIR/checkpoint-latest.ref"

  # Create two sessions - session-01 sorts before session-02
  make_session_with_patches "$CHANGES_DIR/session-01" 1
  make_session_with_patches "$CHANGES_DIR/session-02" 2

  # Run draft without SESSION= (should use session-02, which sorts last)
  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" draft \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" >/dev/null 2>&1

  # Verify session-02's patches applied (2 commits + initial = 3)
  local COMMIT_COUNT
  COMMIT_COUNT=$(git -C "$PROJECT_DIR" rev-list --count HEAD)
  if [[ "$COMMIT_COUNT" -eq 3 ]]; then
    pass "draft uses most recent session when SESSION not specified"
  else
    fail "draft did not use most recent session: expected 3 commits, got $COMMIT_COUNT"
  fi
}

test_draft_uses_named_session() {
  local PROJECT_DIR="$FIXTURE_DIR/draft_named_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/draft_named_sandbox"
  local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"
  local CHANGES_DIR="$WORKSPACE_DIR/session-diffs"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$WORKSPACE_DIR"

  # Create checkpoint tag
  local WORKTREE_ID CHECKPOINT_TS CHECKPOINT_TAG
  WORKTREE_ID=$(echo "$PROJECT_DIR" | sha1sum | head -c8)
  CHECKPOINT_TS="20260420-120000"
  CHECKPOINT_TAG="agent-checkpoint/${WORKTREE_ID}/${CHECKPOINT_TS}"
  git -C "$PROJECT_DIR" tag "$CHECKPOINT_TAG"
  echo "$CHECKPOINT_TAG" > "$WORKSPACE_DIR/checkpoint-latest.ref"

  # Create two sessions
  make_session_with_patches "$CHANGES_DIR/session-a" 1
  make_session_with_patches "$CHANGES_DIR/session-b" 3

  # Run draft with SESSION=session-a
  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" draft \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" \
    --session="session-a" >/dev/null 2>&1

  # Verify session-a's patches applied (1 commit)
  local COMMIT_COUNT
  COMMIT_COUNT=$(git -C "$PROJECT_DIR" rev-list --count HEAD)
  if [[ "$COMMIT_COUNT" -eq 2 ]]; then
    pass "draft uses named session when SESSION specified"
  else
    fail "draft did not use named session: expected 2 commits, got $COMMIT_COUNT"
  fi
}

test_draft_rejects_if_draft_exists() {
  local PROJECT_DIR="$FIXTURE_DIR/draft_guard_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/draft_guard_sandbox"
  local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"
  local CHANGES_DIR="$WORKSPACE_DIR/session-diffs"
  local SESSION_DIR="$CHANGES_DIR/test-session"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$WORKSPACE_DIR"

  # Create checkpoint tag
  local WORKTREE_ID CHECKPOINT_TS CHECKPOINT_TAG
  WORKTREE_ID=$(echo "$PROJECT_DIR" | sha1sum | head -c8)
  CHECKPOINT_TS="20260420-120000"
  CHECKPOINT_TAG="agent-checkpoint/${WORKTREE_ID}/${CHECKPOINT_TS}"
  git -C "$PROJECT_DIR" tag "$CHECKPOINT_TAG"
  echo "$CHECKPOINT_TAG" > "$WORKSPACE_DIR/checkpoint-latest.ref"

  # Create session with patches
  make_session_with_patches "$SESSION_DIR" 1

  # Create fake draft-state
  cat > "$WORKSPACE_DIR/draft-state" <<EOF
SOURCE_BRANCH=main
WORKING_BRANCH=agent/draft/test-session
SESSION_DIR=$SESSION_DIR
EOF

  # Run draft - should fail
  local OUTPUT
  OUTPUT=$(bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" draft \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" 2>&1) || true

  if [[ "$OUTPUT" == *"draft is already in progress"* ]]; then
    pass "draft rejects when draft-state already exists"
  else
    fail "draft did not reject existing draft: $OUTPUT"
  fi
}

test_draft_requires_patches_directory() {
  local PROJECT_DIR="$FIXTURE_DIR/draft_no_patches_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/draft_no_patches_sandbox"
  local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"
  local CHANGES_DIR="$WORKSPACE_DIR/session-diffs"
  local SESSION_DIR="$CHANGES_DIR/test-session"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$SESSION_DIR"

  # Create checkpoint tag
  local WORKTREE_ID CHECKPOINT_TS CHECKPOINT_TAG
  WORKTREE_ID=$(echo "$PROJECT_DIR" | sha1sum | head -c8)
  CHECKPOINT_TS="20260420-120000"
  CHECKPOINT_TAG="agent-checkpoint/${WORKTREE_ID}/${CHECKPOINT_TS}"
  git -C "$PROJECT_DIR" tag "$CHECKPOINT_TAG"
  echo "$CHECKPOINT_TAG" > "$WORKSPACE_DIR/checkpoint-latest.ref"

  # Run draft - should fail (no patches dir)
  local OUTPUT
  OUTPUT=$(bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" draft \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" 2>&1) || true

  if [[ "$OUTPUT" == *"patches directory not found"* ]]; then
    pass "draft fails when patches directory missing"
  else
    fail "draft did not fail on missing patches: $OUTPUT"
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
  local SESSION_DIR="$CHANGES_DIR/test-session"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$WORKSPACE_DIR"

  # Create checkpoint tag
  local WORKTREE_ID CHECKPOINT_TS CHECKPOINT_TAG
  WORKTREE_ID=$(echo "$PROJECT_DIR" | sha1sum | head -c8)
  CHECKPOINT_TS="20260420-120000"
  CHECKPOINT_TAG="agent-checkpoint/${WORKTREE_ID}/${CHECKPOINT_TS}"
  git -C "$PROJECT_DIR" tag "$CHECKPOINT_TAG"
  echo "$CHECKPOINT_TAG" > "$WORKSPACE_DIR/checkpoint-latest.ref"

  # Create session with patches
  make_session_with_patches "$SESSION_DIR" 1

  # Create draft
  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" draft \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" >/dev/null 2>&1

  # Run confirm
  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" confirm \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" >/dev/null 2>&1

  # Verify on main branch
  local CURRENT_BRANCH
  CURRENT_BRANCH=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD)
  if [[ "$CURRENT_BRANCH" == "main" ]]; then
    pass "confirm returns to source branch"
  else
    fail "confirm did not return to source branch: $CURRENT_BRANCH"
  fi

  # Verify draft-state cleared
  if [[ ! -f "$WORKSPACE_DIR/draft-state" ]]; then
    pass "confirm clears draft-state"
  else
    fail "confirm did not clear draft-state"
  fi

  # Verify draft branch deleted
  if ! git -C "$PROJECT_DIR" show-ref --verify --quiet "refs/heads/agent/draft/test-session"; then
    pass "confirm deletes draft branch"
  else
    fail "confirm did not delete draft branch"
  fi

  # Verify changes merged (1 new commit on main)
  local COMMIT_COUNT
  COMMIT_COUNT=$(git -C "$PROJECT_DIR" rev-list --count HEAD)
  if [[ "$COMMIT_COUNT" -eq 2 ]]; then
    pass "confirm merges changes to source branch"
  else
    fail "confirm did not merge changes: expected 2 commits, got $COMMIT_COUNT"
  fi
}

test_confirm_with_target_branch() {
  local PROJECT_DIR="$FIXTURE_DIR/confirm_target_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/confirm_target_sandbox"
  local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"
  local CHANGES_DIR="$WORKSPACE_DIR/session-diffs"
  local SESSION_DIR="$CHANGES_DIR/test-session"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$WORKSPACE_DIR"

  # Create target branch
  git -C "$PROJECT_DIR" checkout -b "feature-branch" --quiet

  # Create checkpoint tag
  local WORKTREE_ID CHECKPOINT_TS CHECKPOINT_TAG
  WORKTREE_ID=$(echo "$PROJECT_DIR" | sha1sum | head -c8)
  CHECKPOINT_TS="20260420-120000"
  CHECKPOINT_TAG="agent-checkpoint/${WORKTREE_ID}/${CHECKPOINT_TS}"
  git -C "$PROJECT_DIR" tag "$CHECKPOINT_TAG"
  echo "$CHECKPOINT_TAG" > "$WORKSPACE_DIR/checkpoint-latest.ref"

  # Create session with patches
  make_session_with_patches "$SESSION_DIR" 1

  # Create draft (on feature-branch)
  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" draft \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" >/dev/null 2>&1

  # Run confirm with TARGET=main
  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" confirm \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" \
    --target="main" >/dev/null 2>&1

  # Verify on main branch
  local CURRENT_BRANCH
  CURRENT_BRANCH=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD)
  if [[ "$CURRENT_BRANCH" == "main" ]]; then
    pass "confirm with TARGET merges to specified branch"
  else
    fail "confirm with TARGET did not merge to specified branch: $CURRENT_BRANCH"
  fi

  # Verify changes on main
  local COMMIT_COUNT
  COMMIT_COUNT=$(git -C "$PROJECT_DIR" rev-list --count HEAD)
  if [[ "$COMMIT_COUNT" -eq 2 ]]; then
    pass "confirm with TARGET applies changes to target branch"
  else
    fail "confirm with TARGET did not apply changes: expected 2 commits, got $COMMIT_COUNT"
  fi
}

test_confirm_rejects_if_no_draft() {
  local PROJECT_DIR="$FIXTURE_DIR/confirm_guard_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/confirm_guard_sandbox"
  local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$WORKSPACE_DIR"

  # Run confirm without draft - should fail
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
  local SESSION_DIR="$CHANGES_DIR/test-session"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$WORKSPACE_DIR"

  # Create checkpoint tag
  local WORKTREE_ID CHECKPOINT_TS CHECKPOINT_TAG
  WORKTREE_ID=$(echo "$PROJECT_DIR" | sha1sum | head -c8)
  CHECKPOINT_TS="20260420-120000"
  CHECKPOINT_TAG="agent-checkpoint/${WORKTREE_ID}/${CHECKPOINT_TS}"
  git -C "$PROJECT_DIR" tag "$CHECKPOINT_TAG"
  echo "$CHECKPOINT_TAG" > "$WORKSPACE_DIR/checkpoint-latest.ref"

  # Create session with patches
  make_session_with_patches "$SESSION_DIR" 1

  # Create draft
  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" draft \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" >/dev/null 2>&1

  # Run reject
  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" reject \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" >/dev/null 2>&1

  # Verify on main branch
  local CURRENT_BRANCH
  CURRENT_BRANCH=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD)
  if [[ "$CURRENT_BRANCH" == "main" ]]; then
    pass "reject returns to source branch"
  else
    fail "reject did not return to source branch: $CURRENT_BRANCH"
  fi

  # Verify draft-state cleared
  if [[ ! -f "$WORKSPACE_DIR/draft-state" ]]; then
    pass "reject clears draft-state"
  else
    fail "reject did not clear draft-state"
  fi

  # Verify no new commits on main
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
  local SESSION_DIR="$CHANGES_DIR/test-session"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$WORKSPACE_DIR"

  # Create checkpoint tag
  local WORKTREE_ID CHECKPOINT_TS CHECKPOINT_TAG
  WORKTREE_ID=$(echo "$PROJECT_DIR" | sha1sum | head -c8)
  CHECKPOINT_TS="20260420-120000"
  CHECKPOINT_TAG="agent-checkpoint/${WORKTREE_ID}/${CHECKPOINT_TS}"
  git -C "$PROJECT_DIR" tag "$CHECKPOINT_TAG"
  echo "$CHECKPOINT_TAG" > "$WORKSPACE_DIR/checkpoint-latest.ref"

  # Create session with patches
  make_session_with_patches "$SESSION_DIR" 1

  # Create draft
  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" draft \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" >/dev/null 2>&1

  # Run reject
  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" reject \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" >/dev/null 2>&1

  # Verify draft branch deleted
  if ! git -C "$PROJECT_DIR" show-ref --verify --quiet "refs/heads/agent/draft/test-session"; then
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

  # Run reject without draft - should fail
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
# APPLY (legacy) tests — reads from OUTPUT_DIR
# -------------------------

test_apply_uses_latest_session() {
  local PROJECT_DIR="$FIXTURE_DIR/apply_latest_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/apply_latest_sandbox"
  local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"
  local OUTPUT_DIR="$WORKSPACE_DIR/output"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$OUTPUT_DIR"

  # Create two sessions - session-01 sorts before session-02
  make_session_with_changes_diff "$OUTPUT_DIR/session-01"
  make_session_with_changes_diff "$OUTPUT_DIR/session-02"

  # Run apply (no SESSION=) - should use session-02 (lexicographically last)
  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" >/dev/null 2>&1

  # Verify changes applied (working tree dirty)
  local STATUS
  STATUS=$(git -C "$PROJECT_DIR" status --porcelain)
  if [[ "$STATUS" == *"output-file.txt"* ]]; then
    pass "apply uses lexicographically latest session in OUTPUT_DIR"
  else
    fail "apply did not apply changes.diff: $STATUS"
  fi

  # Verify no new commits
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
  mkdir -p "$OUTPUT_DIR"

  # Create two sessions with different content
  make_session_with_changes_diff "$OUTPUT_DIR/session-a"
  # Create session-b with a different file
  mkdir -p "$OUTPUT_DIR/session-b"
  cat > "$OUTPUT_DIR/session-b/changes.diff" <<'EOF'
diff --git a/named-file.txt b/named-file.txt
new file mode 100644
index 0000000..7a963d6
--- /dev/null
+++ b/named-file.txt
@@ -0,0 +1 @@
+named session change
EOF

  # Run apply with SESSION=session-a
  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" \
    --session="session-a" >/dev/null 2>&1

  # Verify session-a's changes applied
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
  mkdir -p "$OUTPUT_DIR/session-incomplete"

  # Create session without changes.diff
  echo "# Incomplete session" > "$OUTPUT_DIR/session-incomplete/migration-guide.md"

  # Run apply - should fail
  local OUTPUT
  OUTPUT=$(bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" \
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
  # Do NOT create OUTPUT_DIR

  # Run apply - should fail
  local OUTPUT
  OUTPUT=$(bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" 2>&1) || true

  if [[ "$OUTPUT" == *"output directory not found"* ]]; then
    pass "apply fails when OUTPUT_DIR does not exist"
  else
    fail "apply did not fail on missing OUTPUT_DIR: $OUTPUT"
  fi
}

test_apply_requires_empty_output_dir() {
  local PROJECT_DIR="$FIXTURE_DIR/apply_empty_output_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/apply_empty_output_sandbox"
  local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"
  local OUTPUT_DIR="$WORKSPACE_DIR/output"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$OUTPUT_DIR"
  # OUTPUT_DIR exists but is empty

  # Run apply - should fail
  local OUTPUT
  OUTPUT=$(bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" 2>&1) || true

  if [[ "$OUTPUT" == *"no session directories found"* ]]; then
    pass "apply fails when OUTPUT_DIR is empty"
  else
    fail "apply did not fail on empty OUTPUT_DIR: $OUTPUT"
  fi
}

test_apply_prints_migration_guide() {
  local PROJECT_DIR="$FIXTURE_DIR/apply_migration_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/apply_migration_sandbox"
  local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"
  local OUTPUT_DIR="$WORKSPACE_DIR/output"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$OUTPUT_DIR"

  # Create session with migration-guide.md
  make_session_with_changes_diff "$OUTPUT_DIR/test-session"

  # Run apply
  local OUTPUT
  OUTPUT=$(bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" 2>&1) || true

  if [[ "$OUTPUT" == *"Migration guide available"* ]]; then
    pass "apply prints migration guide path when present"
  else
    fail "apply did not print migration guide: $OUTPUT"
  fi
}

test_apply_rejects_mode_apply_flag() {
  local PROJECT_DIR="$FIXTURE_DIR/apply_mode_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/apply_mode_sandbox"
  local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"
  local OUTPUT_DIR="$WORKSPACE_DIR/output"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$OUTPUT_DIR"
  make_session_with_changes_diff "$OUTPUT_DIR/test-session"

  # Run apply with deprecated --mode=apply flag
  local OUTPUT
  OUTPUT=$(bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" \
    --mode=apply 2>&1) || true

  if [[ "$OUTPUT" == *"--mode=apply is deprecated"* ]]; then
    pass "apply rejects deprecated --mode=apply flag"
  else
    fail "apply did not reject --mode=apply: $OUTPUT"
  fi
}

# -------------------------
# Run all tests

echo "=== apply_workspace.sh tests (Change 3: draft/confirm/reject workflow) ==="
echo

run_test "draft_creates_branch_from_checkpoint" test_draft_creates_branch_from_checkpoint
run_test "draft_applies_patches" test_draft_applies_patches
run_test "draft_uses_most_recent_session" test_draft_uses_most_recent_session
run_test "draft_uses_named_session" test_draft_uses_named_session
run_test "draft_rejects_if_draft_exists" test_draft_rejects_if_draft_exists
run_test "draft_requires_patches_directory" test_draft_requires_patches_directory
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
run_test "apply_rejects_mode_apply_flag" test_apply_rejects_mode_apply_flag

echo
echo "Results: $PASS passed, $FAIL failed"

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi

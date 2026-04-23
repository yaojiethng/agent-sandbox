#!/usr/bin/env bash
# tests/test_apply_workspace.sh
# Tests for scripts/apply_workspace.sh — Unit E (draft redesign)
#
# Covers:
#   draft — creates working branch from HEAD, applies .diff files via git apply
#   draft SESSION=<branch> — applies diffs from named branch directory
#   draft BRANCH_FROM=<hash> — creates branch from specified commit
#   draft DIFFS=<start>..<end> — applies only selected diff range
#   draft guard — rejects if draft-state already exists
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

# Create a session with numbered .diff files in a branch-name folder
make_session_with_diffs() {
  local BRANCH_DIR="$1"
  local NUM_DIFFS="${2:-2}"

  mkdir -p "$BRANCH_DIR"

  for i in $(seq 1 "$NUM_DIFFS"); do
    local PADDING
    PADDING=$(printf "%04d" "$i")
    cat > "$BRANCH_DIR/${PADDING}-abc1234.diff" <<EOF
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

test_draft_creates_branch() {
  local PROJECT_DIR="$FIXTURE_DIR/draft_branch_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/draft_branch_sandbox"
  local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"
  local CHANGES_DIR="$WORKSPACE_DIR/session-diffs"
  local BRANCH_DIR="$CHANGES_DIR/test-branch"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$WORKSPACE_DIR"

  # Create session with diffs
  make_session_with_diffs "$BRANCH_DIR" 2

  # Run draft
  export SESSION_TS="20260420-120000"
  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" draft \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" >/dev/null 2>&1

  # Verify draft branch created
  local FOUND_BRANCH
  FOUND_BRANCH=$(git -C "$PROJECT_DIR" branch --list 'draft/*' | tr -d ' *' | head -1)
  if [[ "$FOUND_BRANCH" == draft/* ]]; then
    pass "draft creates working branch"
  else
    fail "draft did not create working branch: got '$FOUND_BRANCH'"
  fi

  # Verify draft-state written
  if [[ -f "$WORKSPACE_DIR/draft-state" ]]; then
    pass "draft writes draft-state file"
  else
    fail "draft did not write draft-state file"
  fi
}

test_draft_applies_diffs() {
  local PROJECT_DIR="$FIXTURE_DIR/draft_diffs_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/draft_diffs_sandbox"
  local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"
  local CHANGES_DIR="$WORKSPACE_DIR/session-diffs"
  local BRANCH_DIR="$CHANGES_DIR/test-branch"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$WORKSPACE_DIR"

  # Create session with 2 diffs
  make_session_with_diffs "$BRANCH_DIR" 2

  # Run draft
  export SESSION_TS="20260420-120000"
  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" draft \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" >/dev/null 2>&1

  # Verify diffs applied (2 new commits on draft branch)
  local COMMIT_COUNT
  COMMIT_COUNT=$(git -C "$PROJECT_DIR" rev-list --count HEAD)
  if [[ "$COMMIT_COUNT" -eq 3 ]]; then
    pass "draft applies all diffs as commits"
  else
    fail "draft applied wrong number of commits: expected 3, got $COMMIT_COUNT"
  fi
}

test_draft_uses_most_recent_branch() {
  local PROJECT_DIR="$FIXTURE_DIR/draft_recent_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/draft_recent_sandbox"
  local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"
  local CHANGES_DIR="$WORKSPACE_DIR/session-diffs"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$WORKSPACE_DIR"

  # Create two branch directories - branch-01 sorts before branch-02
  make_session_with_diffs "$CHANGES_DIR/branch-01" 1
  make_session_with_diffs "$CHANGES_DIR/branch-02" 2

  # Run draft without SESSION= (should use branch-02, which sorts last)
  export SESSION_TS="20260420-120000"
  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" draft \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" >/dev/null 2>&1

  # Verify branch-02's diffs applied (2 commits + initial = 3)
  local COMMIT_COUNT
  COMMIT_COUNT=$(git -C "$PROJECT_DIR" rev-list --count HEAD)
  if [[ "$COMMIT_COUNT" -eq 3 ]]; then
    pass "draft uses most recent branch directory when SESSION not specified"
  else
    fail "draft did not use most recent branch: expected 3 commits, got $COMMIT_COUNT"
  fi
}

test_draft_uses_named_branch() {
  local PROJECT_DIR="$FIXTURE_DIR/draft_named_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/draft_named_sandbox"
  local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"
  local CHANGES_DIR="$WORKSPACE_DIR/session-diffs"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$WORKSPACE_DIR"

  # Create two branch directories
  make_session_with_diffs "$CHANGES_DIR/branch-a" 1
  make_session_with_diffs "$CHANGES_DIR/branch-b" 3

  # Run draft with SESSION=branch-a
  export SESSION_TS="20260420-120000"
  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" draft \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" \
    --session="branch-a" >/dev/null 2>&1

  # Verify branch-a's diffs applied (1 commit)
  local COMMIT_COUNT
  COMMIT_COUNT=$(git -C "$PROJECT_DIR" rev-list --count HEAD)
  if [[ "$COMMIT_COUNT" -eq 2 ]]; then
    pass "draft uses named branch when SESSION specified"
  else
    fail "draft did not use named branch: expected 2 commits, got $COMMIT_COUNT"
  fi
}

test_draft_uses_sanitized_branch_name() {
  local PROJECT_DIR="$FIXTURE_DIR/draft_sanitized_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/draft_sanitized_sandbox"
  local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"
  local CHANGES_DIR="$WORKSPACE_DIR/session-diffs"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$WORKSPACE_DIR"

  # Directory uses dashes (sanitized from slashes)
  make_session_with_diffs "$CHANGES_DIR/feature-M2_3-agent" 1

  # Pass original branch name with slashes
  export SESSION_TS="20260420-120000"
  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" draft \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" \
    --session="feature/M2_3/agent" >/dev/null 2>&1

  # Verify diffs applied (1 commit)
  local COMMIT_COUNT
  COMMIT_COUNT=$(git -C "$PROJECT_DIR" rev-list --count HEAD)
  if [[ "$COMMIT_COUNT" -eq 2 ]]; then
    pass "draft sanitizes slashes in branch name for directory lookup"
  else
    fail "draft did not resolve sanitized branch name: expected 2 commits, got $COMMIT_COUNT"
  fi
}

test_draft_branch_name_preserves_slashes() {
  local PROJECT_DIR="$FIXTURE_DIR/draft_slashes_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/draft_slashes_sandbox"
  local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"
  local CHANGES_DIR="$WORKSPACE_DIR/session-diffs"
  local BRANCH_DIR="$CHANGES_DIR/test-branch"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$WORKSPACE_DIR"

  # Switch to a branch with slashes
  git -C "$PROJECT_DIR" checkout -b "feature/M2_3-agent-session-history" --quiet

  # Create session with diffs
  make_session_with_diffs "$BRANCH_DIR" 1

  # Run draft
  export SESSION_TS="20260421-143000"
  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" draft \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" >/dev/null 2>&1

  # Verify draft branch name preserves slashes and appends session-ts
  local FOUND_BRANCH
  FOUND_BRANCH=$(git -C "$PROJECT_DIR" branch --list 'draft/*' | tr -d ' *' | head -1)
  if [[ "$FOUND_BRANCH" == *"feature/M2_3-agent-session-history"* ]]; then
    pass "draft branch name preserves slashes and disambiguates with session-ts"
  else
    fail "draft branch name wrong: expected feature/M2_3-agent-session-history in '$FOUND_BRANCH'"
  fi
}

test_draft_branch_name_detached_head() {
  local PROJECT_DIR="$FIXTURE_DIR/draft_detached_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/draft_detached_sandbox"
  local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"
  local CHANGES_DIR="$WORKSPACE_DIR/session-diffs"
  local BRANCH_DIR="$CHANGES_DIR/test-branch"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$WORKSPACE_DIR"

  # Detach HEAD
  local SHORT_SHA
  SHORT_SHA=$(git -C "$PROJECT_DIR" rev-parse --short HEAD)
  git -C "$PROJECT_DIR" checkout --quiet "$SHORT_SHA"

  # Create session with diffs
  make_session_with_diffs "$BRANCH_DIR" 1

  # Run draft
  export SESSION_TS="20260421-143000"
  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" draft \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" >/dev/null 2>&1

  # Verify draft branch name uses short SHA for detached HEAD
  local FOUND_BRANCH
  FOUND_BRANCH=$(git -C "$PROJECT_DIR" branch --list 'draft/*' | tr -d ' *' | head -1)
  if [[ "$FOUND_BRANCH" == "draft/${SHORT_SHA}-20260421-143000" ]]; then
    pass "draft branch name uses short SHA for detached HEAD"
  else
    fail "draft branch name for detached HEAD: expected 'draft/${SHORT_SHA}-20260421-143000', got '$FOUND_BRANCH'"
  fi
}

test_draft_rejects_if_draft_exists() {
  local PROJECT_DIR="$FIXTURE_DIR/draft_guard_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/draft_guard_sandbox"
  local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"
  local CHANGES_DIR="$WORKSPACE_DIR/session-diffs"
  local BRANCH_DIR="$CHANGES_DIR/test-branch"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$WORKSPACE_DIR"

  # Create session with diffs
  make_session_with_diffs "$BRANCH_DIR" 1

  # Create fake draft-state
  cat > "$WORKSPACE_DIR/draft-state" <<EOF
SOURCE_BRANCH=main
WORKING_BRANCH=draft/main-test
SESSION_DIR=$BRANCH_DIR
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

test_draft_requires_diff_files() {
  local PROJECT_DIR="$FIXTURE_DIR/draft_no_diffs_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/draft_no_diffs_sandbox"
  local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"
  local CHANGES_DIR="$WORKSPACE_DIR/session-diffs"
  local BRANCH_DIR="$CHANGES_DIR/test-branch"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$BRANCH_DIR"

  # Run draft - should fail (empty branch dir, no .diff files)
  local OUTPUT
  OUTPUT=$(bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" draft \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" 2>&1) || true

  if [[ "$OUTPUT" == *"no .diff files found"* ]]; then
    pass "draft fails when no .diff files in branch directory"
  else
    fail "draft did not fail on missing diffs: $OUTPUT"
  fi
}

test_draft_uses_branch_from() {
  local PROJECT_DIR="$FIXTURE_DIR/draft_from_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/draft_from_sandbox"
  local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"
  local CHANGES_DIR="$WORKSPACE_DIR/session-diffs"
  local BRANCH_DIR="$CHANGES_DIR/test-branch"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$WORKSPACE_DIR"

  # Create a second commit so HEAD~1 is a valid base
  echo "second" > "$PROJECT_DIR/second.txt"
  git -C "$PROJECT_DIR" add second.txt
  git -C "$PROJECT_DIR" commit -m "second commit" --quiet

  local BASE_SHA
  BASE_SHA=$(git -C "$PROJECT_DIR" rev-parse HEAD~1)

  # Create session with 1 diff
  make_session_with_diffs "$BRANCH_DIR" 1

  # Run draft with BRANCH_FROM=HEAD~1
  export SESSION_TS="20260420-120000"
  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" draft \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" \
    --branch-from="$BASE_SHA" >/dev/null 2>&1

  # Verify draft branch is from HEAD~1 (2 commits: initial + diff)
  local COMMIT_COUNT
  COMMIT_COUNT=$(git -C "$PROJECT_DIR" rev-list --count HEAD)
  if [[ "$COMMIT_COUNT" -eq 2 ]]; then
    pass "draft BRANCH_FROM creates branch from specified commit"
  else
    fail "draft BRANCH_FROM wrong commit count: expected 2, got $COMMIT_COUNT"
  fi
}

test_draft_uses_diffs_range() {
  local PROJECT_DIR="$FIXTURE_DIR/draft_range_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/draft_range_sandbox"
  local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"
  local CHANGES_DIR="$WORKSPACE_DIR/session-diffs"
  local BRANCH_DIR="$CHANGES_DIR/test-branch"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$WORKSPACE_DIR"

  # Create session with 4 diffs
  make_session_with_diffs "$BRANCH_DIR" 4

  # Run draft with DIFFS=2..3 (apply only diffs 2 and 3)
  export SESSION_TS="20260420-120000"
  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" draft \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" \
    --diffs="2..3" >/dev/null 2>&1

  # Verify only 2 diffs applied (2 commits + initial = 3)
  local COMMIT_COUNT
  COMMIT_COUNT=$(git -C "$PROJECT_DIR" rev-list --count HEAD)
  if [[ "$COMMIT_COUNT" -eq 3 ]]; then
    pass "draft DIFFS range applies only selected diffs"
  else
    fail "draft DIFFS range wrong commit count: expected 3, got $COMMIT_COUNT"
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
  local BRANCH_DIR="$CHANGES_DIR/test-branch"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$WORKSPACE_DIR"

  # Create session with 1 diff
  make_session_with_diffs "$BRANCH_DIR" 1

  # Create draft
  export SESSION_TS="20260420-120000"
  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" draft \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" >/dev/null 2>&1

  # Capture working branch name before confirm deletes it
  local WORKING_BRANCH
  WORKING_BRANCH=$(git -C "$PROJECT_DIR" branch --list 'draft/*' | tr -d ' *' | head -1)

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
  if ! git -C "$PROJECT_DIR" show-ref --verify --quiet "refs/heads/$WORKING_BRANCH"; then
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
  local BRANCH_DIR="$CHANGES_DIR/test-branch"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$WORKSPACE_DIR"

  # Create target branch
  git -C "$PROJECT_DIR" checkout -b "feature-branch" --quiet

  # Create session with 1 diff
  make_session_with_diffs "$BRANCH_DIR" 1

  # Create draft (on feature-branch)
  export SESSION_TS="20260420-120000"
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
  local BRANCH_DIR="$CHANGES_DIR/test-branch"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$WORKSPACE_DIR"

  # Create session with 1 diff
  make_session_with_diffs "$BRANCH_DIR" 1

  # Create draft
  export SESSION_TS="20260420-120000"
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
  local BRANCH_DIR="$CHANGES_DIR/test-branch"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$WORKSPACE_DIR"

  # Create session with 1 diff
  make_session_with_diffs "$BRANCH_DIR" 1

  # Create draft
  export SESSION_TS="20260420-120000"
  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" draft \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" >/dev/null 2>&1

  # Capture working branch name before reject deletes it
  local WORKING_BRANCH
  WORKING_BRANCH=$(git -C "$PROJECT_DIR" branch --list 'draft/*' | tr -d ' *' | head -1)

  # Run reject
  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" reject \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" >/dev/null 2>&1

  # Verify draft branch deleted
  if ! git -C "$PROJECT_DIR" show-ref --verify --quiet "refs/heads/$WORKING_BRANCH"; then
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

  # Create two sessions - 20260401 sorts before 20260402
  make_session_with_changes_diff "20260401-120000" "$OUTPUT_DIR/diffs"
  make_session_with_changes_diff "20260402-120000" "$OUTPUT_DIR/diffs"

  # Run apply (no SESSION=) - should use session-02 (lexicographically last)
  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" apply \
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
  mkdir -p "$OUTPUT_DIR/diffs"

  # Create two sessions with different content
  make_session_with_changes_diff "session-a" "$OUTPUT_DIR/diffs"
  # Create session-b with a different file
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

  # Run apply with SESSION=session-a
  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" apply \
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
  mkdir -p "$OUTPUT_DIR/diffs/session-incomplete"

  # Create session without changes.diff
  echo "# Incomplete session" > "$OUTPUT_DIR/diffs/session-incomplete/migration-guide.md"

  # Run apply - should fail
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
  # Do NOT create OUTPUT_DIR

  # Run apply - should fail
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
  # diffs directory exists but is empty

  # Run apply - should fail
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

  # Create session with migration-guide.md
  make_session_with_changes_diff "test-session" "$OUTPUT_DIR/diffs"

  # Run apply
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

  # Create session with changes.diff
  make_session_with_changes_diff "test-session" "$OUTPUT_DIR/diffs"

  # Run apply with --force
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

test_apply_force_uses_reject_mode() {
  local PROJECT_DIR="$FIXTURE_DIR/apply_force_mode_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/apply_force_mode_sandbox"
  local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"
  local OUTPUT_DIR="$WORKSPACE_DIR/output"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$OUTPUT_DIR/diffs"

  # Create session with changes.diff
  make_session_with_changes_diff "test-session" "$OUTPUT_DIR/diffs"

  # Run apply with --force
  local OUTPUT
  OUTPUT=$(bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" apply \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" \
    --force 2>&1) || true

  if [[ "$OUTPUT" == *"Force mode enabled"* ]]; then
    pass "apply --force enables force mode"
  else
    fail "apply --force did not enable force mode: $OUTPUT"
  fi
}

test_apply_force_applies_changes() {
  local PROJECT_DIR="$FIXTURE_DIR/apply_force_apply_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/apply_force_apply_sandbox"
  local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"
  local OUTPUT_DIR="$WORKSPACE_DIR/output"

  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$OUTPUT_DIR/diffs"

  # Create session with changes.diff
  make_session_with_changes_diff "test-session" "$OUTPUT_DIR/diffs"

  # Run apply with --force
  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" apply \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" \
    --force >/dev/null 2>&1

  # Verify changes applied
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

  # Create session with changes.diff
  make_session_with_changes_diff "test-session" "$OUTPUT_DIR/diffs"

  # Run apply with DIFF argument pointing to specific diff file
  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" apply \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" \
    --diff="$OUTPUT_DIR/diffs/test-session/changes.diff" >/dev/null 2>&1

  # Verify changes applied
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

  # Run apply with DIFF argument pointing to non-existent file
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

  # Create a diff with an index line
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

  # Run apply - should succeed despite index line having SHA
  bash "$SCRIPT_DIR/../scripts/apply_workspace.sh" apply \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" >/dev/null 2>&1

  # Verify changes applied (index line should have been stripped)
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

echo "=== apply_workspace.sh tests (Unit E: draft redesign) ==="
echo

run_test "draft_creates_branch" test_draft_creates_branch
run_test "draft_applies_diffs" test_draft_applies_diffs
run_test "draft_uses_most_recent_branch" test_draft_uses_most_recent_branch
run_test "draft_uses_named_branch" test_draft_uses_named_branch
run_test "draft_uses_sanitized_branch_name" test_draft_uses_sanitized_branch_name
run_test "draft_branch_name_preserves_slashes" test_draft_branch_name_preserves_slashes
run_test "draft_branch_name_detached_head" test_draft_branch_name_detached_head
run_test "draft_rejects_if_draft_exists" test_draft_rejects_if_draft_exists
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
run_test "apply_force_uses_reject_mode" test_apply_force_uses_reject_mode
run_test "apply_force_applies_changes" test_apply_force_applies_changes
run_test "apply_uses_diff_argument" test_apply_uses_diff_argument
run_test "apply_diff_argument_requires_file_exists" test_apply_diff_argument_requires_file_exists
run_test "apply_strips_index_lines" test_apply_strips_index_lines

echo
echo "Results: $PASS passed, $FAIL failed"

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi

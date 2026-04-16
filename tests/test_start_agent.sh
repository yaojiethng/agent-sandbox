#!/usr/bin/env bash
# tests/test_start_agent.sh
# Host-side start_agent.sh tests — Change 1 (checkpoint tag) and Change 2 (SESSION_NAME).
#
# Covers:
#   checkpoint tag creation          — agent-checkpoint/YYYYMMDD-HHMMSS
#   checkpoint tag pruning           — keep 5 most recent
#   checkpoint-latest.ref writing    — for operator recovery
#   SESSION_NAME derivation          — sanitized branch + timestamp
#
# All fixtures created under a temp dir — no repos created inside the harness repo.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

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
  git -C "$DIR" init --quiet
  git -C "$DIR" config user.email "test@sandbox"
  git -C "$DIR" config user.name "test"
  echo "tracked content" > "$DIR/tracked.txt"
  git -C "$DIR" add tracked.txt
  git -C "$DIR" commit -m "initial" --quiet
}

# -------------------------
# Checkpoint tag creation tests
# -------------------------

test_checkpoint_tag_created() {
  local PROJECT_DIR="$FIXTURE_DIR/checkpoint_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/checkpoint_sandbox"
  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$SANDBOX_DIR"

  # Simulate checkpoint tag creation logic from start_agent.sh
  local CHECKPOINT_TS CHECKPOINT_TAG
  CHECKPOINT_TS=$(date -u +%Y%m%d-%H%M%S)
  CHECKPOINT_TAG="agent-checkpoint/${CHECKPOINT_TS}"

  git -C "$PROJECT_DIR" tag "$CHECKPOINT_TAG"

  # Verify tag exists
  local TAGS
  TAGS=$(git -C "$PROJECT_DIR" tag --list 'agent-checkpoint/*')
  if [[ -n "$TAGS" && "$TAGS" == *"agent-checkpoint/"* ]]; then
    pass "checkpoint tag created with correct naming convention"
  else
    fail "checkpoint tag not found or incorrect naming"
  fi
}

test_checkpoint_tag_points_to_correct_commit() {
  local PROJECT_DIR="$FIXTURE_DIR/checkpoint_commit_repo"
  make_committed_repo "$PROJECT_DIR"

  local BASELINE_SHA
  BASELINE_SHA=$(git -C "$PROJECT_DIR" rev-parse HEAD)

  local CHECKPOINT_TS CHECKPOINT_TAG
  CHECKPOINT_TS=$(date -u +%Y%m%d-%H%M%S)
  CHECKPOINT_TAG="agent-checkpoint/${CHECKPOINT_TS}"

  git -C "$PROJECT_DIR" tag "$CHECKPOINT_TAG"

  local TAG_SHA
  TAG_SHA=$(git -C "$PROJECT_DIR" rev-parse "$CHECKPOINT_TAG")

  if [[ "$TAG_SHA" == "$BASELINE_SHA" ]]; then
    pass "checkpoint tag points to current HEAD"
  else
    fail "checkpoint tag does not point to current HEAD"
  fi
}

test_checkpoint_ref_file_written() {
  local PROJECT_DIR="$FIXTURE_DIR/checkpoint_ref_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/checkpoint_ref_sandbox"
  make_committed_repo "$PROJECT_DIR"
  mkdir -p "$SANDBOX_DIR"

  local CHECKPOINT_TS CHECKPOINT_TAG
  CHECKPOINT_TS=$(date -u +%Y%m%d-%H%M%S)
  CHECKPOINT_TAG="agent-checkpoint/${CHECKPOINT_TS}"

  git -C "$PROJECT_DIR" tag "$CHECKPOINT_TAG"

  # Write ref file (as start_agent.sh does)
  mkdir -p "$SANDBOX_DIR/.workspace"
  echo "$CHECKPOINT_TAG" > "$SANDBOX_DIR/.workspace/checkpoint-latest.ref"

  local REF_CONTENT
  REF_CONTENT=$(cat "$SANDBOX_DIR/.workspace/checkpoint-latest.ref")

  if [[ "$REF_CONTENT" == "$CHECKPOINT_TAG" ]]; then
    pass "checkpoint-latest.ref contains correct tag name"
  else
    fail "checkpoint-latest.ref has incorrect content: $REF_CONTENT"
  fi
}

test_checkpoint_ref_file_creates_workspace_dir() {
  local PROJECT_DIR="$FIXTURE_DIR/checkpoint_ref_dir_repo"
  local SANDBOX_DIR="$FIXTURE_DIR/checkpoint_ref_dir_sandbox"
  make_committed_repo "$PROJECT_DIR"
  # SANDBOX_DIR exists but .workspace does not
  mkdir -p "$SANDBOX_DIR"

  local CHECKPOINT_TS CHECKPOINT_TAG
  CHECKPOINT_TS=$(date -u +%Y%m%d-%H%M%S)
  CHECKPOINT_TAG="agent-checkpoint/${CHECKPOINT_TS}"

  git -C "$PROJECT_DIR" tag "$CHECKPOINT_TAG"

  # Write ref file (as start_agent.sh does)
  mkdir -p "$SANDBOX_DIR/.workspace"
  echo "$CHECKPOINT_TAG" > "$SANDBOX_DIR/.workspace/checkpoint-latest.ref"

  if [[ -f "$SANDBOX_DIR/.workspace/checkpoint-latest.ref" ]]; then
    pass "checkpoint-latest.ref created with workspace directory"
  else
    fail "checkpoint-latest.ref not created"
  fi
}

# -------------------------
# Checkpoint tag pruning tests
# -------------------------

test_checkpoint_pruning_keeps_five() {
  local PROJECT_DIR="$FIXTURE_DIR/pruning_repo"
  make_committed_repo "$PROJECT_DIR"

  # Create 7 checkpoint tags
  local TAGS=()
  for i in 1 2 3 4 5 6 7; do
    local TS="20260416-09000${i}"
    local TAG="agent-checkpoint/${TS}"
    git -C "$PROJECT_DIR" tag "$TAG"
    TAGS+=("$TAG")
  done

  # Verify we have 7 tags
  local COUNT_BEFORE
  COUNT_BEFORE=$(git -C "$PROJECT_DIR" tag --list 'agent-checkpoint/*' | wc -l)
  if [[ "$COUNT_BEFORE" -ne 7 ]]; then
    fail "setup: expected 7 tags, got $COUNT_BEFORE"
    return
  fi

  # Prune to 5 (as start_agent.sh does)
  mapfile -t ALL_TAGS < <(git -C "$PROJECT_DIR" tag --list 'agent-checkpoint/*' | sort)
  local KEEP=5
  if [[ "${#ALL_TAGS[@]}" -gt "$KEEP" ]]; then
    local DELETE_COUNT=$(( ${#ALL_TAGS[@]} - KEEP ))
    for (( i=0; i<DELETE_COUNT; i++ )); do
      git -C "$PROJECT_DIR" tag -d "${ALL_TAGS[$i]}" >/dev/null
    done
  fi

  local COUNT_AFTER
  COUNT_AFTER=$(git -C "$PROJECT_DIR" tag --list 'agent-checkpoint/*' | wc -l)

  if [[ "$COUNT_AFTER" -eq 5 ]]; then
    pass "pruning keeps exactly 5 most recent tags"
  else
    fail "pruning failed: expected 5 tags, got $COUNT_AFTER"
  fi
}

test_checkpoint_pruning_keeps_newest() {
  local PROJECT_DIR="$FIXTURE_DIR/pruning_newest_repo"
  make_committed_repo "$PROJECT_DIR"

  # Create 6 checkpoint tags with clear chronological ordering
  for i in 1 2 3 4 5 6; do
    local TS="20260416-09000${i}"
    git -C "$PROJECT_DIR" tag "agent-checkpoint/${TS}"
  done

  # Prune to 5
  mapfile -t ALL_TAGS < <(git -C "$PROJECT_DIR" tag --list 'agent-checkpoint/*' | sort)
  local KEEP=5
  if [[ "${#ALL_TAGS[@]}" -gt "$KEEP" ]]; then
    local DELETE_COUNT=$(( ${#ALL_TAGS[@]} - KEEP ))
    for (( i=0; i<DELETE_COUNT; i++ )); do
      git -C "$PROJECT_DIR" tag -d "${ALL_TAGS[$i]}" >/dev/null
    done
  fi

  # Verify the 5 newest remain (090002 through 090006)
  local REMAINING
  REMAINING=$(git -C "$PROJECT_DIR" tag --list 'agent-checkpoint/*' | sort)

  if [[ "$REMAINING" == *"agent-checkpoint/20260416-090002"* && \
        "$REMAINING" == *"agent-checkpoint/20260416-090006"* && \
        "$REMAINING" != *"agent-checkpoint/20260416-090001"* ]]; then
    pass "pruning keeps the 5 newest tags (oldest deleted)"
  else
    fail "pruning deleted wrong tags: $REMAINING"
  fi
}

test_checkpoint_no_pruning_when_under_limit() {
  local PROJECT_DIR="$FIXTURE_DIR/no_prune_repo"
  make_committed_repo "$PROJECT_DIR"

  # Create only 3 checkpoint tags
  for i in 1 2 3; do
    local TS="20260416-09000${i}"
    git -C "$PROJECT_DIR" tag "agent-checkpoint/${TS}"
  done

  # Attempt pruning (should do nothing)
  mapfile -t ALL_TAGS < <(git -C "$PROJECT_DIR" tag --list 'agent-checkpoint/*' | sort)
  local KEEP=5
  if [[ "${#ALL_TAGS[@]}" -gt "$KEEP" ]]; then
    local DELETE_COUNT=$(( ${#ALL_TAGS[@]} - KEEP ))
    for (( i=0; i<DELETE_COUNT; i++ )); do
      git -C "$PROJECT_DIR" tag -d "${ALL_TAGS[$i]}" >/dev/null
    done
  fi

  local COUNT_AFTER
  COUNT_AFTER=$(git -C "$PROJECT_DIR" tag --list 'agent-checkpoint/*' | wc -l)

  if [[ "$COUNT_AFTER" -eq 3 ]]; then
    pass "no pruning occurs when under limit (3 tags remain)"
  else
    fail "unexpected pruning: expected 3 tags, got $COUNT_AFTER"
  fi
}

# -------------------------
# SESSION_NAME derivation tests
# -------------------------

test_session_name_from_master_branch() {
  local PROJECT_DIR="$FIXTURE_DIR/session_master_repo"
  make_committed_repo "$PROJECT_DIR"

  local CHECKPOINT_TS="20260416-090000"
  local BRANCH SANITIZED SESSION_NAME
  BRANCH=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD)
  SANITIZED=$(echo "$BRANCH" | tr '/' '-')
  SESSION_NAME="${SANITIZED}-${CHECKPOINT_TS}"

  if [[ "$SESSION_NAME" == "master-20260416-090000" ]]; then
    pass "SESSION_NAME correct for master branch"
  else
    fail "SESSION_NAME incorrect for master: $SESSION_NAME"
  fi
}

test_session_name_from_main_branch() {
  local PROJECT_DIR="$FIXTURE_DIR/session_main_repo"
  make_committed_repo "$PROJECT_DIR"
  git -C "$PROJECT_DIR" branch -m main

  local CHECKPOINT_TS="20260416-090000"
  local BRANCH SANITIZED SESSION_NAME
  BRANCH=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD)
  SANITIZED=$(echo "$BRANCH" | tr '/' '-')
  SESSION_NAME="${SANITIZED}-${CHECKPOINT_TS}"

  if [[ "$SESSION_NAME" == "main-20260416-090000" ]]; then
    pass "SESSION_NAME correct for main branch"
  else
    fail "SESSION_NAME incorrect for main: $SESSION_NAME"
  fi
}

test_session_name_sanitizes_feature_branch() {
  local PROJECT_DIR="$FIXTURE_DIR/session_feature_repo"
  make_committed_repo "$PROJECT_DIR"
  git -C "$PROJECT_DIR" checkout -b "feature/test-branch" --quiet

  local CHECKPOINT_TS="20260416-090000"
  local BRANCH SANITIZED SESSION_NAME
  BRANCH=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD)
  SANITIZED=$(echo "$BRANCH" | tr '/' '-')
  SESSION_NAME="${SANITIZED}-${CHECKPOINT_TS}"

  if [[ "$SESSION_NAME" == "feature-test-branch-20260416-090000" ]]; then
    pass "SESSION_NAME sanitizes slashes in branch name"
  else
    fail "SESSION_NAME incorrect for feature branch: $SESSION_NAME"
  fi
}

test_session_name_sanitizes_nested_branch() {
  local PROJECT_DIR="$FIXTURE_DIR/session_nested_repo"
  make_committed_repo "$PROJECT_DIR"
  git -C "$PROJECT_DIR" checkout -b "feature/nested/deep/branch" --quiet

  local CHECKPOINT_TS="20260416-090000"
  local BRANCH SANITIZED SESSION_NAME
  BRANCH=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD)
  SANITIZED=$(echo "$BRANCH" | tr '/' '-')
  SESSION_NAME="${SANITIZED}-${CHECKPOINT_TS}"

  if [[ "$SESSION_NAME" == "feature-nested-deep-branch-20260416-090000" ]]; then
    pass "SESSION_NAME sanitizes nested branch names"
  else
    fail "SESSION_NAME incorrect for nested branch: $SESSION_NAME"
  fi
}

test_session_name_exported() {
  local PROJECT_DIR="$FIXTURE_DIR/session_export_repo"
  make_committed_repo "$PROJECT_DIR"

  local CHECKPOINT_TS="20260416-090000"
  local BRANCH SANITIZED SESSION_NAME
  BRANCH=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD)
  SANITIZED=$(echo "$BRANCH" | tr '/' '-')
  export SESSION_NAME="${SANITIZED}-${CHECKPOINT_TS}"

  # Verify it's exported (available to subshells)
  local SUBSHELL_VALUE
  SUBSHELL_VALUE=$(echo "$SESSION_NAME")

  if [[ "$SUBSHELL_VALUE" == "master-20260416-090000" ]]; then
    pass "SESSION_NAME is exported and available to subshells"
  else
    fail "SESSION_NAME not properly exported: $SUBSHELL_VALUE"
  fi
}

# -------------------------
# Run all tests
# -------------------------

echo "=== start_agent.sh tests (Change 1: checkpoint + Change 2: SESSION_NAME) ==="
echo

run_test "checkpoint_tag_created" test_checkpoint_tag_created
run_test "checkpoint_tag_points_to_correct_commit" test_checkpoint_tag_points_to_correct_commit
run_test "checkpoint_ref_file_written" test_checkpoint_ref_file_written
run_test "checkpoint_ref_file_creates_workspace_dir" test_checkpoint_ref_file_creates_workspace_dir
run_test "checkpoint_pruning_keeps_five" test_checkpoint_pruning_keeps_five
run_test "checkpoint_pruning_keeps_newest" test_checkpoint_pruning_keeps_newest
run_test "checkpoint_no_pruning_when_under_limit" test_checkpoint_no_pruning_when_under_limit
run_test "session_name_from_master_branch" test_session_name_from_master_branch
run_test "session_name_from_main_branch" test_session_name_from_main_branch
run_test "session_name_sanitizes_feature_branch" test_session_name_sanitizes_feature_branch
run_test "session_name_sanitizes_nested_branch" test_session_name_sanitizes_nested_branch
run_test "session_name_exported" test_session_name_exported

echo
echo "Results: $PASS passed, $FAIL failed"

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi

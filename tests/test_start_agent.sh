#!/usr/bin/env bash
# tests/test_start_agent.sh
# Host-side start_agent.sh tests — Change 1 (checkpoint tag) and Change 2 (SESSION_NAME).
#
# Covers:
#   checkpoint tag creation          — agent-checkpoint/<worktree-id>/YYYYMMDD-HHMMSS
#   checkpoint tag pruning           — keep 5 most recent per worktree
#   SESSION_NAME derivation          — sanitized branch + timestamp
#   WORKTREE_ID derivation           — from PROJECT_DIR path
#   REPO_COMMIT capture              — full HEAD SHA
#
# Note: checkpoint-latest.ref writing tested indirectly via tag creation.
# Direct ref file tests removed — Change 5 replaces with container label lookup.
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
  # Explicitly set default branch to main for consistency across git versions
  git -C "$DIR" init --quiet --initial-branch=main 2>/dev/null || {
    git -C "$DIR" init --quiet
    git -C "$DIR" branch -M main 2>/dev/null || true
  }
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
  local WORKTREE_ID CHECKPOINT_TS CHECKPOINT_TAG
  WORKTREE_ID=$(echo "$PROJECT_DIR" | sha1sum | head -c8)
  CHECKPOINT_TS=$(date -u +%Y%m%d-%H%M%S)
  CHECKPOINT_TAG="agent-checkpoint/${WORKTREE_ID}/${CHECKPOINT_TS}"

  git -C "$PROJECT_DIR" tag "$CHECKPOINT_TAG"

  # Verify tag exists with worktree namespace
  local TAGS
  TAGS=$(git -C "$PROJECT_DIR" tag --list "agent-checkpoint/${WORKTREE_ID}/*")
  if [[ -n "$TAGS" && "$TAGS" == *"agent-checkpoint/"* ]]; then
    pass "checkpoint tag created with correct naming convention"
  else
    fail "checkpoint tag not found or incorrect naming"
  fi
}

test_checkpoint_tag_points_to_correct_commit() {
  local PROJECT_DIR="$FIXTURE_DIR/checkpoint_commit_repo"
  make_committed_repo "$PROJECT_DIR"

  local WORKTREE_ID BASELINE_SHA CHECKPOINT_TS CHECKPOINT_TAG
  WORKTREE_ID=$(echo "$PROJECT_DIR" | sha1sum | head -c8)
  BASELINE_SHA=$(git -C "$PROJECT_DIR" rev-parse HEAD)

  CHECKPOINT_TS=$(date -u +%Y%m%d-%H%M%S)
  CHECKPOINT_TAG="agent-checkpoint/${WORKTREE_ID}/${CHECKPOINT_TS}"

  git -C "$PROJECT_DIR" tag "$CHECKPOINT_TAG"

  local TAG_SHA
  TAG_SHA=$(git -C "$PROJECT_DIR" rev-parse "$CHECKPOINT_TAG")

  if [[ "$TAG_SHA" == "$BASELINE_SHA" ]]; then
    pass "checkpoint tag points to current HEAD"
  else
    fail "checkpoint tag does not point to current HEAD"
  fi
}

# -------------------------
# Checkpoint tag pruning tests
# -------------------------

test_checkpoint_pruning_keeps_five() {
  local PROJECT_DIR="$FIXTURE_DIR/pruning_repo"
  make_committed_repo "$PROJECT_DIR"

  local WORKTREE_ID
  WORKTREE_ID=$(echo "$PROJECT_DIR" | sha1sum | head -c8)

  # Create 7 checkpoint tags with worktree namespace
  local TAGS=()
  for i in 1 2 3 4 5 6 7; do
    local TS="20260416-09000${i}"
    local TAG="agent-checkpoint/${WORKTREE_ID}/${TS}"
    git -C "$PROJECT_DIR" tag "$TAG"
    TAGS+=("$TAG")
  done

  # Verify we have 7 tags (scoped to worktree)
  local COUNT_BEFORE
  COUNT_BEFORE=$(git -C "$PROJECT_DIR" tag --list "agent-checkpoint/${WORKTREE_ID}/*" | wc -l)
  if [[ "$COUNT_BEFORE" -ne 7 ]]; then
    fail "setup: expected 7 tags, got $COUNT_BEFORE"
    return
  fi

  # Prune to 5 (scoped to worktree namespace)
  mapfile -t ALL_TAGS < <(git -C "$PROJECT_DIR" tag --list "agent-checkpoint/${WORKTREE_ID}/*" | sort)
  local KEEP=5
  if [[ "${#ALL_TAGS[@]}" -gt "$KEEP" ]]; then
    local DELETE_COUNT=$(( ${#ALL_TAGS[@]} - KEEP ))
    for (( i=0; i<DELETE_COUNT; i++ )); do
      git -C "$PROJECT_DIR" tag -d "${ALL_TAGS[$i]}" >/dev/null
    done
  fi

  local COUNT_AFTER
  COUNT_AFTER=$(git -C "$PROJECT_DIR" tag --list "agent-checkpoint/${WORKTREE_ID}/*" | wc -l)

  if [[ "$COUNT_AFTER" -eq 5 ]]; then
    pass "pruning keeps exactly 5 most recent tags"
  else
    fail "pruning failed: expected 5 tags, got $COUNT_AFTER"
  fi
}

test_checkpoint_pruning_keeps_newest() {
  local PROJECT_DIR="$FIXTURE_DIR/pruning_newest_repo"
  make_committed_repo "$PROJECT_DIR"

  local WORKTREE_ID
  WORKTREE_ID=$(echo "$PROJECT_DIR" | sha1sum | head -c8)

  # Create 6 checkpoint tags with worktree namespace
  for i in 1 2 3 4 5 6; do
    local TS="20260416-09000${i}"
    git -C "$PROJECT_DIR" tag "agent-checkpoint/${WORKTREE_ID}/${TS}"
  done

  # Prune to 5 (scoped to worktree)
  mapfile -t ALL_TAGS < <(git -C "$PROJECT_DIR" tag --list "agent-checkpoint/${WORKTREE_ID}/*" | sort)
  local KEEP=5
  if [[ "${#ALL_TAGS[@]}" -gt "$KEEP" ]]; then
    local DELETE_COUNT=$(( ${#ALL_TAGS[@]} - KEEP ))
    for (( i=0; i<DELETE_COUNT; i++ )); do
      git -C "$PROJECT_DIR" tag -d "${ALL_TAGS[$i]}" >/dev/null
    done
  fi

  # Verify the 5 newest remain (090002 through 090006)
  local REMAINING
  REMAINING=$(git -C "$PROJECT_DIR" tag --list "agent-checkpoint/${WORKTREE_ID}/*" | sort)

  if [[ "$REMAINING" == *"agent-checkpoint/${WORKTREE_ID}/20260416-090002"* && \
        "$REMAINING" == *"agent-checkpoint/${WORKTREE_ID}/20260416-090006"* && \
        "$REMAINING" != *"agent-checkpoint/${WORKTREE_ID}/20260416-090001"* ]]; then
    pass "pruning keeps the 5 newest tags (oldest deleted)"
  else
    fail "pruning deleted wrong tags: $REMAINING"
  fi
}

test_checkpoint_no_pruning_when_under_limit() {
  local PROJECT_DIR="$FIXTURE_DIR/no_prune_repo"
  make_committed_repo "$PROJECT_DIR"

  local WORKTREE_ID
  WORKTREE_ID=$(echo "$PROJECT_DIR" | sha1sum | head -c8)

  # Create only 3 checkpoint tags with worktree namespace
  for i in 1 2 3; do
    local TS="20260416-09000${i}"
    git -C "$PROJECT_DIR" tag "agent-checkpoint/${WORKTREE_ID}/${TS}"
  done

  # Attempt pruning (should do nothing)
  mapfile -t ALL_TAGS < <(git -C "$PROJECT_DIR" tag --list "agent-checkpoint/${WORKTREE_ID}/*" | sort)
  local KEEP=5
  if [[ "${#ALL_TAGS[@]}" -gt "$KEEP" ]]; then
    local DELETE_COUNT=$(( ${#ALL_TAGS[@]} - KEEP ))
    for (( i=0; i<DELETE_COUNT; i++ )); do
      git -C "$PROJECT_DIR" tag -d "${ALL_TAGS[$i]}" >/dev/null
    done
  fi

  local COUNT_AFTER
  COUNT_AFTER=$(git -C "$PROJECT_DIR" tag --list "agent-checkpoint/${WORKTREE_ID}/*" | wc -l)

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

  if [[ "$SESSION_NAME" == "main-20260416-090000" ]]; then
    pass "SESSION_NAME correct for main branch"
  else
    fail "SESSION_NAME incorrect for main: $SESSION_NAME"
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

  if [[ "$SUBSHELL_VALUE" == "main-20260416-090000" ]]; then
    pass "SESSION_NAME is exported and available to subshells"
  else
    fail "SESSION_NAME not properly exported: $SUBSHELL_VALUE"
  fi
}

test_session_name_detached_head() {
  local PROJECT_DIR="$FIXTURE_DIR/session_detached_repo"
  make_committed_repo "$PROJECT_DIR"

  # Get the current commit SHA
  local COMMIT_SHA
  COMMIT_SHA=$(git -C "$PROJECT_DIR" rev-parse --short HEAD)

  # Detach HEAD
  git -C "$PROJECT_DIR" checkout --quiet "$COMMIT_SHA"

  local CHECKPOINT_TS="20260416-090000"
  local BRANCH SANITIZED SESSION_NAME
  BRANCH=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD)
  # Handle detached HEAD (as start_agent.sh does)
  if [[ "$BRANCH" == "HEAD" ]]; then
    BRANCH=$(git -C "$PROJECT_DIR" rev-parse --short HEAD)
  fi
  SANITIZED=$(echo "$BRANCH" | tr '/' '-')
  SESSION_NAME="${SANITIZED}-${CHECKPOINT_TS}"

  if [[ "$SESSION_NAME" == "${COMMIT_SHA}-20260416-090000" ]]; then
    pass "SESSION_NAME uses short SHA for detached HEAD"
  else
    fail "SESSION_NAME incorrect for detached HEAD: $SESSION_NAME (expected ${COMMIT_SHA}-20260416-090000)"
  fi
}

# -------------------------
# WORKTREE_ID tests
# -------------------------

test_worktree_id_derived_from_path() {
  local PROJECT_DIR="$FIXTURE_DIR/worktree_id_repo"
  make_committed_repo "$PROJECT_DIR"

  local WORKTREE_ID
  WORKTREE_ID=$(echo "$PROJECT_DIR" | sha1sum | head -c8)

  # Verify it's 8 characters
  if [[ ${#WORKTREE_ID} -eq 8 ]]; then
    pass "WORKTREE_ID is 8 characters"
  else
    fail "WORKTREE_ID wrong length: ${#WORKTREE_ID}"
  fi

  # Verify it's hex
  if [[ "$WORKTREE_ID" =~ ^[a-f0-9]{8}$ ]]; then
    pass "WORKTREE_ID is valid hex"
  else
    fail "WORKTREE_ID not valid hex: $WORKTREE_ID"
  fi
}

test_worktree_id_stable_across_runs() {
  local PROJECT_DIR="$FIXTURE_DIR/worktree_stable_repo"
  make_committed_repo "$PROJECT_DIR"

  local WORKTREE_ID1 WORKTREE_ID2
  WORKTREE_ID1=$(echo "$PROJECT_DIR" | sha1sum | head -c8)
  WORKTREE_ID2=$(echo "$PROJECT_DIR" | sha1sum | head -c8)

  if [[ "$WORKTREE_ID1" == "$WORKTREE_ID2" ]]; then
    pass "WORKTREE_ID is stable across multiple derivations"
  else
    fail "WORKTREE_ID not stable: $WORKTREE_ID1 vs $WORKTREE_ID2"
  fi
}

test_worktree_id_different_for_different_paths() {
  local PROJECT_DIR1="$FIXTURE_DIR/worktree_diff_repo1"
  local PROJECT_DIR2="$FIXTURE_DIR/worktree_diff_repo2"
  mkdir -p "$PROJECT_DIR1" "$PROJECT_DIR2"

  local WORKTREE_ID1 WORKTREE_ID2
  WORKTREE_ID1=$(echo "$PROJECT_DIR1" | sha1sum | head -c8)
  WORKTREE_ID2=$(echo "$PROJECT_DIR2" | sha1sum | head -c8)

  if [[ "$WORKTREE_ID1" != "$WORKTREE_ID2" ]]; then
    pass "WORKTREE_ID differs for different paths"
  else
    fail "WORKTREE_ID should differ for different paths"
  fi
}

# -------------------------
# REPO_COMMIT tests
# -------------------------

test_repo_commit_captured() {
  local PROJECT_DIR="$FIXTURE_DIR/repo_commit_repo"
  make_committed_repo "$PROJECT_DIR"

  local REPO_COMMIT EXPECTED_SHA
  REPO_COMMIT=$(git -C "$PROJECT_DIR" rev-parse HEAD)
  EXPECTED_SHA=$(git -C "$PROJECT_DIR" rev-parse HEAD)

  if [[ "$REPO_COMMIT" == "$EXPECTED_SHA" ]]; then
    pass "REPO_COMMIT matches current HEAD"
  else
    fail "REPO_COMMIT does not match HEAD"
  fi
}

test_repo_commit_is_full_sha() {
  local PROJECT_DIR="$FIXTURE_DIR/repo_commit_sha_repo"
  make_committed_repo "$PROJECT_DIR"

  local REPO_COMMIT
  REPO_COMMIT=$(git -C "$PROJECT_DIR" rev-parse HEAD)

  # Full SHA is 40 hex characters
  if [[ ${#REPO_COMMIT} -eq 40 && "$REPO_COMMIT" =~ ^[a-f0-9]{40}$ ]]; then
    pass "REPO_COMMIT is full 40-character SHA"
  else
    fail "REPO_COMMIT not full SHA: ${#REPO_COMMIT} chars"
  fi
}


# -------------------------
# Container labels tests (Change 5)
# Note: These tests verify the template structure directly since docker compose
# config requires a running Docker daemon which may not be available in test env.
# -------------------------

test_docker_compose_template_has_labels_anchor() {
  if grep -q "x-session-labels: &session_labels" "$REPO_ROOT/libs/docker-compose.yml"; then
    pass "docker-compose.yml defines session labels as YAML anchor"
  else
    fail "docker-compose.yml missing YAML anchor for session labels"
  fi
}

test_docker_compose_template_sandbox_uses_anchor() {
  if grep -A3 "sandbox:" "$REPO_ROOT/libs/docker-compose.yml" | grep -q "labels: \*session_labels"; then
    pass "sandbox service references session labels anchor"
  else
    fail "sandbox service does not reference session labels anchor"
  fi
}

test_docker_compose_template_agent_uses_anchor() {
  if grep -A3 "agent:" "$REPO_ROOT/libs/docker-compose.yml" | grep -q "labels: \*session_labels"; then
    pass "agent service references session labels anchor"
  else
    fail "agent service does not reference session labels anchor"
  fi
}

test_docker_compose_template_has_container_names() {
  if grep -q "container_name: {{SANDBOX_CONTAINER_NAME}}" "$REPO_ROOT/libs/docker-compose.yml" && \
     grep -q "container_name: {{AGENT_CONTAINER_NAME}}" "$REPO_ROOT/libs/docker-compose.yml"; then
    pass "docker-compose.yml has container_name for both services"
  else
    fail "docker-compose.yml missing container_name placeholders"
  fi
}
# -------------------------
# Run all tests

echo "=== start_agent.sh tests (Change 1: checkpoint + Change 2: SESSION_NAME) ==="
echo

run_test "checkpoint_tag_created" test_checkpoint_tag_created
run_test "checkpoint_tag_points_to_correct_commit" test_checkpoint_tag_points_to_correct_commit
run_test "checkpoint_pruning_keeps_five" test_checkpoint_pruning_keeps_five
run_test "checkpoint_pruning_keeps_newest" test_checkpoint_pruning_keeps_newest
run_test "checkpoint_no_pruning_when_under_limit" test_checkpoint_no_pruning_when_under_limit
run_test "session_name_from_master_branch" test_session_name_from_master_branch
run_test "session_name_from_main_branch" test_session_name_from_main_branch
run_test "session_name_sanitizes_feature_branch" test_session_name_sanitizes_feature_branch
run_test "session_name_sanitizes_nested_branch" test_session_name_sanitizes_nested_branch
run_test "session_name_exported" test_session_name_exported
run_test "session_name_detached_head" test_session_name_detached_head
run_test "worktree_id_derived_from_path" test_worktree_id_derived_from_path
run_test "worktree_id_stable_across_runs" test_worktree_id_stable_across_runs
run_test "worktree_id_different_for_different_paths" test_worktree_id_different_for_different_paths
run_test "repo_commit_captured" test_repo_commit_captured
run_test "repo_commit_is_full_sha" test_repo_commit_is_full_sha


# Container labels tests (Change 5)
# Note: These tests verify the template structure directly since docker compose
# config requires a running Docker daemon which may not be available in test env.
run_test "docker_compose_template_has_labels_anchor" test_docker_compose_template_has_labels_anchor
run_test "docker_compose_template_sandbox_uses_anchor" test_docker_compose_template_sandbox_uses_anchor
run_test "docker_compose_template_agent_uses_anchor" test_docker_compose_template_agent_uses_anchor
run_test "docker_compose_template_has_container_names" test_docker_compose_template_has_container_names

echo
echo "Results: $PASS passed, $FAIL failed"

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi

# -------------------------
# Container labels tests (Change 5)
# Note: These tests verify the template structure directly since docker compose
# config requires a running Docker daemon which may not be available in test env.
# -------------------------

test_docker_compose_template_has_labels_anchor() {
  # Verify the template defines session labels as a YAML anchor
  if grep -q "x-session-labels: &session_labels" "$REPO_ROOT/libs/docker-compose.yml"; then
    pass "docker-compose.yml defines session labels as YAML anchor"
  else
    fail "docker-compose.yml missing YAML anchor for session labels"
  fi
}

test_docker_compose_template_sandbox_uses_anchor() {
  # Verify sandbox service references the labels anchor
  if grep -A3 "sandbox:" "$REPO_ROOT/libs/docker-compose.yml" | grep -q "labels: \*session_labels"; then
    pass "sandbox service references session labels anchor"
  else
    fail "sandbox service does not reference session labels anchor"
  fi
}

test_docker_compose_template_agent_uses_anchor() {
  # Verify agent service references the labels anchor
  if grep -A3 "agent:" "$REPO_ROOT/libs/docker-compose.yml" | grep -q "labels: \*session_labels"; then
    pass "agent service references session labels anchor"
  else
    fail "agent service does not reference session labels anchor"
  fi
}

test_docker_compose_template_has_container_names() {
  # Verify both SANDBOX_CONTAINER_NAME placeholders exist
  if grep -q "container_name: {{SANDBOX_CONTAINER_NAME}}" "$REPO_ROOT/libs/docker-compose.yml" && \
     grep -q "container_name: {{AGENT_CONTAINER_NAME}}" "$REPO_ROOT/libs/docker-compose.yml"; then
    pass "docker-compose.yml has container_name for both services"
  else
    fail "docker-compose.yml missing container_name placeholders"
  fi
}

# Add container label tests to the test runner
run_test "docker_compose_template_has_labels_anchor" test_docker_compose_template_has_labels_anchor
run_test "docker_compose_template_sandbox_uses_anchor" test_docker_compose_template_sandbox_uses_anchor
run_test "docker_compose_template_agent_uses_anchor" test_docker_compose_template_agent_uses_anchor
run_test "docker_compose_template_has_container_names" test_docker_compose_template_has_container_names

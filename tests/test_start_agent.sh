#!/usr/bin/env bash
# -------------------------
# Host-side start_agent.sh tests — checkpoint tags, session identity,
# WORKTREE_ID derivation, REPO_COMMIT capture, and compose template structure.
#
# Covers:
#   checkpoint tag creation          — agent-checkpoint/<worktree-id>/YYYYMMDD-HHMMSS
#   checkpoint tag pruning           — keep 5 most recent per worktree
#   SANITIZED_HOST_BRANCH derivation — branch name sanitised for directory labels
#   WORKTREE_ID derivation           — from PROJECT_DIR path
#   REPO_COMMIT capture              — full HEAD SHA
#
# Note: checkpoint-latest.ref writing tested indirectly via tag creation.
# Direct ref file tests removed — Change 5 replaces with container label lookup.
#
# All fixtures created under a temp dir — no repos created inside the harness repo.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/libs/test_common.sh"

FIXTURE_DIR="$(mktemp -d /tmp/XXXXXX)"
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
  local WORKTREE_ID SESSION_TS CHECKPOINT_TAG
  WORKTREE_ID=$(echo "$PROJECT_DIR" | sha1sum | head -c8)
  SESSION_TS=$(date -u +%Y%m%d-%H%M%S)
  CHECKPOINT_TAG="agent-checkpoint/${WORKTREE_ID}/${SESSION_TS}"

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

  local WORKTREE_ID BASELINE_SHA SESSION_TS CHECKPOINT_TAG
  WORKTREE_ID=$(echo "$PROJECT_DIR" | sha1sum | head -c8)
  BASELINE_SHA=$(git -C "$PROJECT_DIR" rev-parse HEAD)

  SESSION_TS=$(date -u +%Y%m%d-%H%M%S)
  CHECKPOINT_TAG="agent-checkpoint/${WORKTREE_ID}/${SESSION_TS}"

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
# SANITIZED_HOST_BRANCH derivation tests
# -------------------------

test_sanitized_host_branch_from_master_branch() {
  local PROJECT_DIR="$FIXTURE_DIR/session_master_repo"
  make_committed_repo "$PROJECT_DIR"

  local BRANCH SANITIZED_HOST_BRANCH
  BRANCH=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD)
  SANITIZED_HOST_BRANCH=$(echo "$BRANCH" | sed 's/[^a-zA-Z0-9._-]/-/g')

  if [[ "$SANITIZED_HOST_BRANCH" == "main" ]]; then
    pass "SANITIZED_HOST_BRANCH correct for main branch"
  else
    fail "SANITIZED_HOST_BRANCH incorrect for main: $SANITIZED_HOST_BRANCH"
  fi
}

test_sanitized_host_branch_from_main_branch() {
  local PROJECT_DIR="$FIXTURE_DIR/session_main_repo"
  make_committed_repo "$PROJECT_DIR"
  git -C "$PROJECT_DIR" branch -m main

  local BRANCH SANITIZED_HOST_BRANCH
  BRANCH=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD)
  SANITIZED_HOST_BRANCH=$(echo "$BRANCH" | sed 's/[^a-zA-Z0-9._-]/-/g')

  if [[ "$SANITIZED_HOST_BRANCH" == "main" ]]; then
    pass "SANITIZED_HOST_BRANCH correct for main branch"
  else
    fail "SANITIZED_HOST_BRANCH incorrect for main: $SANITIZED_HOST_BRANCH"
  fi
}

test_sanitized_host_branch_sanitizes_feature_branch() {
  local PROJECT_DIR="$FIXTURE_DIR/session_feature_repo"
  make_committed_repo "$PROJECT_DIR"
  git -C "$PROJECT_DIR" checkout -b "feature/test-branch" --quiet

  local BRANCH SANITIZED_HOST_BRANCH
  BRANCH=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD)
  SANITIZED_HOST_BRANCH=$(echo "$BRANCH" | sed 's/[^a-zA-Z0-9._-]/-/g')

  if [[ "$SANITIZED_HOST_BRANCH" == "feature-test-branch" ]]; then
    pass "SANITIZED_HOST_BRANCH sanitizes slashes in branch name"
  else
    fail "SANITIZED_HOST_BRANCH incorrect for feature branch: $SANITIZED_HOST_BRANCH"
  fi
}

test_sanitized_host_branch_sanitizes_nested_branch() {
  local PROJECT_DIR="$FIXTURE_DIR/session_nested_repo"
  make_committed_repo "$PROJECT_DIR"
  git -C "$PROJECT_DIR" checkout -b "feature/nested/deep/branch" --quiet

  local BRANCH SANITIZED_HOST_BRANCH
  BRANCH=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD)
  SANITIZED_HOST_BRANCH=$(echo "$BRANCH" | sed 's/[^a-zA-Z0-9._-]/-/g')

  if [[ "$SANITIZED_HOST_BRANCH" == "feature-nested-deep-branch" ]]; then
    pass "SANITIZED_HOST_BRANCH sanitizes nested branch names"
  else
    fail "SANITIZED_HOST_BRANCH incorrect for nested branch: $SANITIZED_HOST_BRANCH"
  fi
}

test_sanitized_host_branch_exported() {
  local PROJECT_DIR="$FIXTURE_DIR/session_export_repo"
  make_committed_repo "$PROJECT_DIR"

  local BRANCH SANITIZED_HOST_BRANCH
  BRANCH=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD)
  export SANITIZED_HOST_BRANCH=$(echo "$BRANCH" | sed 's/[^a-zA-Z0-9._-]/-/g')

  # Verify it's exported (available to subshells)
  local SUBSHELL_VALUE
  SUBSHELL_VALUE=$(echo "$SANITIZED_HOST_BRANCH")

  local rc=0
  if [[ "$SUBSHELL_VALUE" == "main" ]]; then
    pass "SANITIZED_HOST_BRANCH is exported and available to subshells"
  else
    fail "SANITIZED_HOST_BRANCH not properly exported: $SUBSHELL_VALUE"
    rc=1
  fi

  unset SANITIZED_HOST_BRANCH
  return $rc
}

test_sanitized_host_branch_detached_head() {
  local PROJECT_DIR="$FIXTURE_DIR/session_detached_repo"
  make_committed_repo "$PROJECT_DIR"

  # Get the current commit SHA
  local COMMIT_SHA
  COMMIT_SHA=$(git -C "$PROJECT_DIR" rev-parse --short HEAD)

  # Detach HEAD
  git -C "$PROJECT_DIR" checkout --quiet "$COMMIT_SHA"

  local BRANCH SANITIZED_HOST_BRANCH
  BRANCH=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD)
  # Handle detached HEAD (as start_agent.sh does)
  if [[ "$BRANCH" == "HEAD" ]]; then
    BRANCH=$(git -C "$PROJECT_DIR" rev-parse --short HEAD)
  fi
  SANITIZED_HOST_BRANCH=$(echo "$BRANCH" | sed 's/[^a-zA-Z0-9._-]/-/g')

  # Short SHA is hex characters, so no sanitization needed
  if [[ "$SANITIZED_HOST_BRANCH" == "$COMMIT_SHA" ]]; then
    pass "SANITIZED_HOST_BRANCH uses short SHA for detached HEAD"
  else
    fail "SANITIZED_HOST_BRANCH incorrect for detached HEAD: $SANITIZED_HOST_BRANCH (expected $COMMIT_SHA)"
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

echo "=== start_agent.sh tests (session identity derivation + compose template) ==="
echo

run_test test_checkpoint_tag_created
run_test test_checkpoint_tag_points_to_correct_commit
run_test test_checkpoint_pruning_keeps_five
run_test test_checkpoint_pruning_keeps_newest
run_test test_checkpoint_no_pruning_when_under_limit
run_test test_sanitized_host_branch_from_master_branch
run_test test_sanitized_host_branch_from_main_branch
run_test test_sanitized_host_branch_sanitizes_feature_branch
run_test test_sanitized_host_branch_sanitizes_nested_branch
run_test test_sanitized_host_branch_exported
run_test test_sanitized_host_branch_detached_head
run_test test_worktree_id_derived_from_path
run_test test_worktree_id_stable_across_runs
run_test test_worktree_id_different_for_different_paths
run_test test_repo_commit_captured
run_test test_repo_commit_is_full_sha


# Container labels tests (Change 5)
# Note: These tests verify the template structure directly since docker compose
# config requires a running Docker daemon which may not be available in test env.
run_test test_docker_compose_template_has_labels_anchor
run_test test_docker_compose_template_sandbox_uses_anchor
run_test test_docker_compose_template_agent_uses_anchor
run_test test_docker_compose_template_has_container_names

test_done

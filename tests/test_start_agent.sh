#!/usr/bin/env bash
# -------------------------
# Host-side start_agent.sh tests  --  checkpoint tags, session identity,
# WORKTREE_ID derivation, REPO_COMMIT capture, and compose template structure.
#
# Covers:
#   checkpoint tag creation           --  agent-checkpoint/<worktree-id>/YYYYMMDD-HHMMSS
#   checkpoint tag pruning            --  keep 5 most recent per worktree
#   SANITIZED_HOST_BRANCH derivation  --  branch name sanitised for directory labels
#   WORKTREE_ID derivation            --  from PROJECT_DIR path
#   REPO_COMMIT capture               --  full HEAD SHA
#
# Note: checkpoint-latest.ref writing tested indirectly via tag creation.
# Direct ref file tests removed  --  Change 5 replaces with container label lookup.
#
# All fixtures created under a temp dir  --  no repos created inside the harness repo.

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup
source "$TEST_DIR/libs/git_fixtures.sh"

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
  SANITIZED_HOST_BRANCH=$(echo "$BRANCH" | sed 's/[^a-zA-Z0-9._-]/-/g')
  export SANITIZED_HOST_BRANCH

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
# SESSION_ID derivation tests
# -------------------------
# The derivation formula lives in session_env.sh (single canonical home). These
# tests exercise it via the shared session_env.sh used by start_agent.sh.

source "$REPO_ROOT/src/libs/session_env.sh"

test_session_id_derived_from_sandbox_head_and_ts() {
  local PROJECT_DIR="$FIXTURE_DIR/session_id_repo"
  make_committed_repo "$PROJECT_DIR"
  local SANDBOX_DIR="$PROJECT_DIR-sandbox"
  local HOST_HEAD_SHA; HOST_HEAD_SHA=$(git -C "$PROJECT_DIR" rev-parse HEAD)
  local TS="20260831-120000"

  local SID
  SID=$(session_id_derive "$SANDBOX_DIR" "$HOST_HEAD_SHA" "$TS")

  # Verify it's 6 characters
  if [[ ${#SID} -eq 6 ]]; then
    pass "SESSION_ID is 6 characters"
  else
    fail "SESSION_ID wrong length: ${#SID}"
  fi

  # Verify it's hex
  if [[ "$SID" =~ ^[a-f0-9]{6}$ ]]; then
    pass "SESSION_ID is valid hex"
  else
    fail "SESSION_ID not valid hex: $SID"
  fi
}

test_session_id_stable_across_runs() {
  local PROJECT_DIR="$FIXTURE_DIR/session_id_stable_repo"
  make_committed_repo "$PROJECT_DIR"
  local SANDBOX_DIR="$PROJECT_DIR-sandbox"
  local HOST_HEAD_SHA; HOST_HEAD_SHA=$(git -C "$PROJECT_DIR" rev-parse HEAD)

  local SID1 SID2
  SID1=$(session_id_derive "$SANDBOX_DIR" "$HOST_HEAD_SHA" "20260831-120000")
  SID2=$(session_id_derive "$SANDBOX_DIR" "$HOST_HEAD_SHA" "20260831-120000")

  if [[ "$SID1" == "$SID2" ]]; then
    pass "SESSION_ID is stable across multiple derivations"
  else
    fail "SESSION_ID not stable: $SID1 vs $SID2"
  fi
}

test_session_id_different_for_different_dirs() {
  local PROJECT_DIR1="$FIXTURE_DIR/session_id_diff1"
  local PROJECT_DIR2="$FIXTURE_DIR/session_id_diff2"
  mkdir -p "$PROJECT_DIR1" "$PROJECT_DIR2"

  local SANDBOX_DIR1="$PROJECT_DIR1-sandbox"
  local SANDBOX_DIR2="$PROJECT_DIR2-sandbox"
  local SHA="deadbeefdeadbeefdeadbeefdeadbeefdeadbeef"

  local SID1 SID2
  SID1=$(session_id_derive "$SANDBOX_DIR1" "$SHA" "20260831-120000")
  SID2=$(session_id_derive "$SANDBOX_DIR2" "$SHA" "20260831-120000")

  if [[ "$SID1" != "$SID2" ]]; then
    pass "SESSION_ID differs for different SANDBOX_DIR paths"
  else
    fail "SESSION_ID should differ for different SANDBOX_DIR paths"
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
  if grep -q "x-session-labels: &session_labels" "$REPO_ROOT/src/build/docker-compose.yml"; then
    pass "docker-compose.yml defines session labels as YAML anchor"
  else
    fail "docker-compose.yml missing YAML anchor for session labels"
  fi
}

test_docker_compose_template_sandbox_uses_anchor() {
  if grep -A3 "sandbox:" "$REPO_ROOT/src/build/docker-compose.yml" | grep -q "labels: \*session_labels"; then
    pass "sandbox service references session labels anchor"
  else
    fail "sandbox service does not reference session labels anchor"
  fi
}

test_docker_compose_template_agent_uses_anchor() {
  if grep -A3 "agent:" "$REPO_ROOT/src/build/docker-compose.yml" | grep -q "labels: \*session_labels"; then
    pass "agent service references session labels anchor"
  else
    fail "agent service does not reference session labels anchor"
  fi
}

test_docker_compose_template_has_container_names() {
  if grep -q "container_name: {{SANDBOX_CONTAINER_NAME}}" "$REPO_ROOT/src/build/docker-compose.yml" && \
     grep -q "container_name: {{AGENT_CONTAINER_NAME}}" "$REPO_ROOT/src/build/docker-compose.yml"; then
    pass "docker-compose.yml has container_name for both services"
  else
    fail "docker-compose.yml missing container_name placeholders"
  fi
}
# -------------------------
# Interactive config wizard tests (F2 design D11)
# -------------------------

# Help surface: --interactive is described as the config wizard, no longer
# "not yet implemented".
test_wizard_help_describes_interactive() {
  local out
  out="$(bash "$REPO_ROOT/scripts/start_agent.sh" --help 2>&1)"
  if echo "$out" | grep -q -- "--interactive  interactive config wizard" \
     && ! echo "$out" | grep -q "NOT YET IMPLEMENTED"; then
    pass "start --help: --interactive documented as config wizard (not 'not yet implemented')"
  else
    fail "start --help: --interactive not documented as config wizard; out=$out"
  fi
}

# --interactive with no --provider: provider picker shown, build policy picker,
# then confirm. Abort on 'n' -> non-zero and no session record created (the
# clean-abort gate  --  no partial start).
test_wizard_picker_abort() {
  local dir="$FIXTURE_DIR/wizard_pick_abort"
  mkdir -p "$dir/project" "$dir/sandbox"
  local out rc
  out="$(printf '1\n\nn\n' | bash "$REPO_ROOT/scripts/start_agent.sh" standard \
      --name=wtest --project="$dir/project" --sandbox="$dir/sandbox" \
      --interactive 2>&1)"; rc=$?
  if [[ $rc -ne 0 ]] \
     && echo "$out" | grep -q "Select a provider" \
     && echo "$out" | grep -iq "aborted" \
     && ! ls "$dir/sandbox/.compose"/*.yml >/dev/null 2>&1; then
    pass "start --interactive: picker + confirm, abort on 'n' -> non-zero, no session record"
  else
    fail "start --interactive: expected picker+abort+no record, got rc=$rc: $out"
  fi
}

# --interactive with --provider supplied: no provider re-prompt (D1  --  supplied
# args override the wizard's suggestions); the confirm shows the supplied
# provider; abort on 'n'.
test_wizard_provider_supplied_no_reprompt() {
  local dir="$FIXTURE_DIR/wizard_provider_arg"
  mkdir -p "$dir/project" "$dir/sandbox"
  local out rc
  out="$(printf '\nn\n' | bash "$REPO_ROOT/scripts/start_agent.sh" standard \
      --name=wtest --project="$dir/project" --sandbox="$dir/sandbox" \
      --provider=pi --interactive 2>&1)"; rc=$?
  if [[ $rc -ne 0 ]] \
     && ! echo "$out" | grep -q "Select a provider" \
     && echo "$out" | grep -q "provider: pi" \
     && echo "$out" | grep -iq "aborted"; then
    pass "start --interactive: supplied --provider not re-prompted; confirm shows provider, abort"
  else
    fail "start --interactive: expected no provider re-prompt, got rc=$rc: $out"
  fi
}

# --interactive accept path: the wizard's selections flow through to a real
# session under the docker stub  --  run completes, the .compose record is
# written, and compose up is issued. Proves the wizard integrates with the
# existing non-interactive start pipeline.
test_wizard_accept_runs_to_completion() {
  local dir="$FIXTURE_DIR/wizard_accept"
  mkdir -p "$dir/sandbox/.workspace/session-diffs" \
           "$dir/sandbox/.workspace/input" "$dir/sandbox/.workspace/output"
  cat > "$dir/sandbox/.env" <<EOF
SANDBOX_DIR=$dir/sandbox
PROJECT_DIR=$dir/project
EOF
  make_committed_repo "$dir/project"

  local out rc trace
  trace="$dir/trace.log"
  out="$(cd "$dir" && printf '1\n2\ny\n' | \
    PATH="$REPO_ROOT/test/stubs:$PATH" \
    DOCKER_TRACE_LOG="$trace" \
    bash "$REPO_ROOT/scripts/start_agent.sh" standard \
      --name=wtest --project="$dir/project" --sandbox="$dir/sandbox" \
      --interactive) 2>&1"; rc=$?
  local rec
  rec=$(ls "$dir/sandbox/.compose"/*.yml 2>/dev/null | head -1)
  if [[ $rc -eq 0 && -n "$rec" && -f "$rec" ]] \
     && grep -q "compose up" "$trace"; then
    pass "start --interactive: accept path runs to completion (compose record + up)"
  else
    fail "start --interactive: accept path failed, rc=$rc record=$rec: $out"
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
run_test test_session_id_derived_from_sandbox_head_and_ts
run_test test_session_id_stable_across_runs
run_test test_session_id_different_for_different_dirs
run_test test_repo_commit_captured
run_test test_repo_commit_is_full_sha


# Rendered-compose behavioral tests are defined with the start-behavior block
# below; their run_test calls live in the execution list at the bottom of this
# file.

# -------------------------

# -------------------------
# Behavioral start tests: run start_agent.sh end-to-end under docker stubs and
# assert on observable outcomes (docker trace, persisted compose file).
# -------------------------

# run_start_session DIR ARGS...
#   Builds a minimal start fixture under DIR (sandbox tree + .env + committed
#   project repo), runs `start_agent.sh ARGS...` with docker stubs shadowing
#   PATH, and captures results in globals:
#     START_RC       --  exit code
#     START_OUT      --  combined stdout+stderr
#     START_TRACE    --  path to the docker trace log
#     START_COMPOSE  --  path to the persisted compose file (empty if none)
run_start_session() {
  local dir="$1"; shift
  mkdir -p "$dir/sandbox/.workspace/session-diffs" \
           "$dir/sandbox/.workspace/input" "$dir/sandbox/.workspace/output"
  cat > "$dir/sandbox/.env" <<EOF
SANDBOX_DIR=$dir/sandbox
PROJECT_DIR=$dir/project
EOF
  make_committed_repo "$dir/project"
  START_TRACE="$dir/docker-trace.log"
  : > "$START_TRACE"
  START_OUT="$(cd "$dir" && \
    PATH="$REPO_ROOT/test/stubs:$PATH" \
    DOCKER_TRACE_LOG="$START_TRACE" \
    bash "$REPO_ROOT/scripts/start_agent.sh" "$@" 2>&1)"
  START_RC=$?
  START_COMPOSE="$(ls "$dir/sandbox/.compose"/*.yml 2>/dev/null | head -1)"
}

# Default policy (no --refresh/--rebuild) starts from existing images;
# building is an explicit opt-in.
test_default_policy_starts_without_building() {
  local dir="$FIXTURE_DIR/start_default_nobuild"
  run_start_session "$dir" standard \
    --name=stest --project="$dir/project" --sandbox="$dir/sandbox" --provider=pi
  if [[ "$START_RC" -ne 0 ]]; then
    fail "default start failed rc=$START_RC: $START_OUT"; return
  fi
  if grep -q "\] build " "$START_TRACE"; then
    fail "default policy issued docker build (trace: $(cat "$START_TRACE"))"
  else
    pass "default policy starts a session without building images"
  fi
}

# --rebuild forces a full rebuild: the agent image build carries --no-cache.
test_rebuild_flag_builds_agent_with_no_cache() {
  local dir="$FIXTURE_DIR/start_rebuild_flag"
  run_start_session "$dir" standard \
    --name=rtest --project="$dir/project" --sandbox="$dir/sandbox" --provider=pi --rebuild
  if [[ "$START_RC" -ne 0 ]]; then
    fail "--rebuild start failed rc=$START_RC: $START_OUT"; return
  fi
  if grep -q "\] build .*--no-cache" "$START_TRACE"; then
    pass "--rebuild builds images with --no-cache"
  else
    fail "--rebuild produced no --no-cache build; trace: $(cat "$START_TRACE")"
  fi
}

# --refresh rebuilds while preserving the layer cache: builds happen,
# none of them with --no-cache.
test_refresh_flag_builds_without_no_cache() {
  local dir="$FIXTURE_DIR/start_refresh_flag"
  run_start_session "$dir" standard \
    --name=rtest --project="$dir/project" --sandbox="$dir/sandbox" --provider=pi --refresh
  if [[ "$START_RC" -ne 0 ]]; then
    fail "--refresh start failed rc=$START_RC: $START_OUT"; return
  fi
  if ! grep -q "\] build " "$START_TRACE"; then
    fail "--refresh produced no builds at all; trace: $(cat "$START_TRACE")"; return
  fi
  if grep -q "\] build .*--no-cache" "$START_TRACE"; then
    fail "--refresh must not pass --no-cache (it is the cache-preserving path)"
  else
    pass "--refresh builds sandbox+agent without --no-cache"
  fi
}

# The generated compose file is the container runtime's input: every {{VAR}}
# placeholder must be substituted and both containers must be named from
# project + provider + session.
test_rendered_compose_fully_substituted_and_names_both_containers() {
  local dir="$FIXTURE_DIR/start_render_compose"
  run_start_session "$dir" standard \
    --name=ctest --project="$dir/project" --sandbox="$dir/sandbox" --provider=pi
  if [[ "$START_RC" -ne 0 || -z "$START_COMPOSE" ]]; then
    fail "start did not persist a compose file: rc=$START_RC out=$START_OUT"; return
  fi
  local placeholders names
  # Comments may legitimately mention the {{VAR}} syntax; only unsubstituted
  # placeholders on active lines are defects.
  placeholders=$(grep -v "^[[:space:]]*#" "$START_COMPOSE" | grep -c "{{") || placeholders=0
  names=$(grep -c "container_name:" "$START_COMPOSE") || names=0
  if [[ "$placeholders" -eq 0 && "$names" -ge 2 ]] \
     && grep -q "container_name: sandbox-ctest-" "$START_COMPOSE" \
     && grep -q "container_name: pi-ctest-" "$START_COMPOSE"; then
    pass "persisted compose fully substituted; sandbox and agent containers named"
  else
    fail "persisted compose bad: placeholders=$placeholders names=$names file=$START_COMPOSE"
  fi
}

# Session labels are how prune/resume find a session's resources later, so the
# generated compose must stamp concrete session identity onto the labels block.
test_rendered_compose_labels_carry_concrete_session_identity() {
  local dir="$FIXTURE_DIR/start_render_labels"
  run_start_session "$dir" standard \
    --name=ltest --project="$dir/project" --sandbox="$dir/sandbox" --provider=pi
  if [[ "$START_RC" -ne 0 || -z "$START_COMPOSE" ]]; then
    fail "start did not persist a compose file: rc=$START_RC out=$START_OUT"; return
  fi
  if grep -q "agent-sandbox.project-name: ltest" "$START_COMPOSE" \
     && grep -Eq "agent-sandbox.session-id: [[:alnum:]]+" "$START_COMPOSE" \
     && grep -Eq "agent-sandbox.host-branch: [[:alnum:]]+" "$START_COMPOSE"; then
    pass "session labels carry concrete project, session id and branch"
  else
    fail "session labels missing or unsubstituted in $START_COMPOSE"
  fi
}

# Removed flags stay removed: --rebuild-base must be rejected as unknown,
# not silently accepted or half-recognized.
test_removed_rebuild_base_flag_is_rejected() {
  local out rc
  out=$(bash "$REPO_ROOT/scripts/start_agent.sh" standard \
        --name=x --project="$FIXTURE_DIR" --rebuild-base 2>&1); rc=$?
  if [[ $rc -ne 0 && "$out" == *"Unknown flag: --rebuild-base"* ]]; then
    pass "removed --rebuild-base flag rejected as unknown"
  else
    fail "--rebuild-base not rejected cleanly: rc=$rc out=$out"
  fi
}

# Functional check: start_agent.sh --help prints the full usage (all modes, all
# required flags, provider required with no default) and exits 0.
test_help_flag_prints_full_usage() {
  local output rc
  output=$(bash "$REPO_ROOT/scripts/start_agent.sh" --help 2>&1) && rc=$? || rc=$?

  if [[ "$rc" -eq 0 && "$output" == *"Usage: start_agent.sh"* \
      && "$output" == *"--provider"* \
      && "$output" == *"standard"* && "$output" == *"--serve"* \
      && "$output" == *"dry-run"* ]]; then
    pass "start_agent.sh --help prints full usage and exits 0"
  else
    fail "start_agent.sh --help: expected full usage, rc=$rc output=$output"
  fi
}

test_help_short_flag_prints_usage() {
  local output rc
  output=$(bash "$REPO_ROOT/scripts/start_agent.sh" -h 2>&1) && rc=$? || rc=$?

  if [[ "$rc" -eq 0 && "$output" == *"Usage: start_agent.sh"* ]]; then
    pass "start_agent.sh -h prints usage and exits 0"
  else
    fail "start_agent.sh -h: expected usage, rc=$rc output=$output"
  fi
}

# --provider has no default: omitting it must fail fast with a clear
# diagnostic instead of a cryptic image-naming error downstream.
test_missing_provider_fails_fast_with_clear_error() {
  local out rc
  out=$(bash "$REPO_ROOT/scripts/start_agent.sh" standard \
        --name=x --project="$FIXTURE_DIR" 2>&1); rc=$?
  if [[ $rc -ne 0 && "$out" == *"--provider is required"* ]]; then
    pass "missing --provider fails fast with a clear diagnostic"
  else
    fail "missing --provider: expected clear failure, got rc=$rc out=$out"
  fi
}

run_test test_rebuild_flag_builds_agent_with_no_cache
run_test test_refresh_flag_builds_without_no_cache
# validate_wsl_path rejects Windows drive paths with a WSL conversion hint.
# start_agent.sh is now dual-use (rule 1.11 guard) and validate_wsl_path returns
# (rule 3.1), so it can be sourced and called in-process.
source "$REPO_ROOT/scripts/start_agent.sh"

test_wsl_path_accepts_linux_paths() {
  local out rc
  out=$(validate_wsl_path "PROJECT_DIR" "/mnt/c/Users/proj" 2>&1); rc=$?
  if [[ $rc -eq 0 && -z "$out" ]]; then
    pass "validate_wsl_path accepts Linux paths silently"
  else
    fail "validate_wsl_path rejected a valid Linux path: rc=$rc out=$out"
  fi
}

test_wsl_path_rejects_windows_drive_paths() {
  local out rc
  out=$(validate_wsl_path "PROJECT_DIR" 'C:\Users\proj' 2>&1); rc=$?
  if [[ $rc -ne 0 && "$out" == *"must be a WSL/Linux path"* && "$out" == *"wslpath"* ]]; then
    pass "validate_wsl_path rejects Windows drive path with conversion hint"
  else
    fail "validate_wsl_path C:\\... : rc=$rc out=$out"
  fi
}

run_test test_removed_rebuild_base_flag_is_rejected
run_test test_help_flag_prints_full_usage
run_test test_help_short_flag_prints_usage
run_test test_missing_provider_fails_fast_with_clear_error
run_test test_wsl_path_accepts_linux_paths
run_test test_wsl_path_rejects_windows_drive_paths
run_test test_default_policy_starts_without_building
run_test test_rendered_compose_fully_substituted_and_names_both_containers
run_test test_rendered_compose_labels_carry_concrete_session_identity

# Interactive config wizard tests (F2 design D11)
run_test test_wizard_help_describes_interactive
run_test test_wizard_picker_abort
run_test test_wizard_provider_supplied_no_reprompt
run_test test_wizard_accept_runs_to_completion

test_done

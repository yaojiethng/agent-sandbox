#!/usr/bin/env bash
# tests/test_3way_merge_regression.sh
#
# Regression tests for the git am --3way switchover.
#
# These tests exercise the current patch-application code path
# (_apply_patch_file + apply_and_commit) and the proposed 3-way path
# (git format-patch + git am --3way). Tests that fail on the current
# code path but pass on the proposed path are gated behind a
# ENABLE_3WAY flag.
#
# Without ENABLE_3WAY:
#   - Tests the current git apply pipeline
#   - Expected: rename/modify and delete/recreate tests FAIL
#
# With ENABLE_3WAY=true:
#   - Tests the proposed git am --3way pipeline
#   - Expected: ALL tests PASS
#
# Run:  bash tests/test_3way_merge_regression.sh              # current pipeline
#       ENABLE_3WAY=true bash tests/test_3way_merge_regression.sh  # proposed pipeline
#
# References:
#   - handover 20260801-06-investigation-3way_merge_baseline.md
#   - tests/knowledge/knowledge_3way_merge_baseline.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/libs/test_common.sh"
test_setup

AGENT_SANDBOX_REPO="$REPO_ROOT"
source "$AGENT_SANDBOX_REPO/src/libs/diff.sh"
source "$SCRIPT_DIR/libs/git_fixtures.sh"

ENABLE_3WAY="${ENABLE_3WAY:-false}"

# =============================================================================
# Helpers
# =============================================================================

# create_scenario_repo DIR
# Creates a host repo with one commit. Creates a sandbox clone via the
# synthetic-root + bundle pattern (the proposed approach). If ENABLE_3WAY
# is false, creates a sandbox via the current git init + tar approach.
# Sets SESSION_STATE so current pipeline functions work.
create_scenario_repo() {
  local HOST="$1/host"
  local SANDBOX="$1/sandbox"

  rm -rf "$HOST" "$SANDBOX"
  mkdir -p "$HOST"
  git -C "$HOST" init --quiet --initial-branch=main 2>/dev/null || {
    git -C "$HOST" init --quiet
    git -C "$HOST" branch -M main 2>/dev/null || true
  }
  git -C "$HOST" config user.email "host@test"
  git -C "$HOST" config user.name "Host"
  echo "host baseline" > "$HOST/file.txt"
  git -C "$HOST" add file.txt
  git -C "$HOST" commit -m "host baseline" --quiet

  if [[ "$ENABLE_3WAY" == "true" ]]; then
    # Proposed: synthetic root + bundle → clone
    local TREE
    TREE=$(git -C "$HOST" rev-parse HEAD^{tree})
    local ROOT
    ROOT=$(echo "agent-sandbox: baseline" | git -C "$HOST" commit-tree "$TREE")
    git -C "$HOST" update-ref refs/heads/_baseline "$ROOT"
    local BUNDLE="$HOST-head.bundle"
    git -C "$HOST" bundle create "$BUNDLE" _baseline --quiet
    git -C "$HOST" update-ref -d refs/heads/_baseline

    git clone "$BUNDLE" "$SANDBOX" --quiet 2>/dev/null
    git -C "$SANDBOX" checkout _baseline --quiet
    # Write SESSION_STATE with init_sha pointing to the synthetic root
    mkdir -p "$SANDBOX/.git"
    echo "init_sha=$ROOT" > "$SANDBOX/.git/SESSION_STATE"
  else
    # Current: git init + unpack (simulate baseline.tar)
    mkdir -p "$SANDBOX"
    git -C "$SANDBOX" init --quiet
    git -C "$SANDBOX" config user.email "agent@sandbox"
    git -C "$SANDBOX" config user.name "agent"
    # Copy host file state (simulating tar unpack)
    cp "$HOST/file.txt" "$SANDBOX/file.txt"
    git -C "$SANDBOX" add file.txt
    git -C "$SANDBOX" commit -m "agent-sandbox: baseline" --quiet
    local INIT_SHA
    INIT_SHA=$(git -C "$SANDBOX" rev-list --max-parents=0 HEAD)
    echo "init_sha=$INIT_SHA" > "$SANDBOX/.git/SESSION_STATE"
  fi
}

# current_apply_patches SANDBOX PATCH_DIR
# Applies patches via current _apply_patch_file + staged commit (simulates
# draft_apply_patches flow). Returns 0 on success, 1 if any fails.
current_apply_patches() {
  local PROJECT_DIR="$1"
  local PATCH_DIR="$2"
  local AUTHOR="Test <test@test>"

  git -C "$PROJECT_DIR" config user.email "test@test"
  git -C "$PROJECT_DIR" config user.name "Test"

  local PATCHES
  mapfile -t PATCHES < <(ls "$PATCH_DIR"/*.diff 2>/dev/null | sort)

  for PATCH in "${PATCHES[@]}"; do
    local COMMIT_MSG
    COMMIT_MSG=$(basename "$PATCH" .diff | sed 's/^[0-9]*-//')
    _apply_patch_file "$PROJECT_DIR" "$PATCH" false false || return 1
    git -C "$PROJECT_DIR" add -A
    git -C "$PROJECT_DIR" commit -m "$COMMIT_MSG" --author="$AUTHOR" --quiet || return 1
  done
}

# proposed_apply_patches HOST SANDBOX
# Fetches _baseline into host, exports format-patch from sandbox, applies
# via git am --3way. Returns 0 on success, 1 on failure.
proposed_apply_patches() {
  local HOST="$1"
  local SANDBOX="$2"

  git -C "$HOST" fetch "$SANDBOX/.git" '+refs/heads/_baseline:refs/heads/_baseline' --quiet 2>/dev/null

  local PATCH_DIR="$SANDBOX/patches"
  rm -rf "$PATCH_DIR"
  mkdir -p "$PATCH_DIR"

  local BASE
  BASE=$(git -C "$SANDBOX" rev-list --max-parents=0 HEAD)
  git -C "$SANDBOX" format-patch -o "$PATCH_DIR" "${BASE}..HEAD" --quiet 2>/dev/null

  local PATCHES=("$PATCH_DIR"/*.patch)
  # No patches = no change, succeed
  [[ -f "${PATCHES[0]}" ]] || return 0

  for PATCH in "${PATCHES[@]}"; do
    git -C "$HOST" am --3way "$PATCH" --quiet 2>/dev/null || {
      git -C "$HOST" am --abort 2>/dev/null || true
      return 1
    }
  done
}

# =============================================================================
# Test 1: rename → modify (incident scenario)
#
# Without 3-way: git apply fails because the rename creates a new file
#   and the subsequent modify references the renamed path with context
#   that doesn't match the add/create diff.
# With 3-way: git am --3way handles the rename and applies both cleanly.
# =============================================================================
test_rename_then_modify() {
  echo "[test_rename_then_modify]"
  local DIR
  DIR=$(mktemp -d)

  create_scenario_repo "$DIR"
  local HOST="$DIR/host"
  local SANDBOX="$DIR/sandbox"

  # Agent: rename file, then modify it
  git -C "$SANDBOX" mv file.txt renamed.txt
  git -C "$SANDBOX" commit -m "rename file.txt to renamed.txt" --quiet
  echo "agent modification" >> "$SANDBOX/renamed.txt"
  git -C "$SANDBOX" add renamed.txt
  git -C "$SANDBOX" commit -m "modify renamed.txt" --quiet

  if [[ "$ENABLE_3WAY" == "true" ]]; then
    # Proposed path
    proposed_apply_patches "$HOST" "$SANDBOX" || {
      fail "rename→modify — git am --3way should succeed"; rm -rf "$DIR"; return 1
    }
    pass "rename→modify (3-way)"
  else
    # Current path: export diffs from sandbox, apply to host
    local PATCH_DIR="$SANDBOX/exported"
    rm -rf "$PATCH_DIR"
    mkdir -p "$PATCH_DIR"
    local INIT_SHA
    INIT_SHA=$(grep init_sha "$SANDBOX/.git/SESSION_STATE" | cut -d= -f2)
    local INDEX=1
    local PREV="$INIT_SHA"
    for COMMIT in $(git -C "$SANDBOX" rev-list "${INIT_SHA}..HEAD" --reverse); do
      local DIFF_FILE
      DIFF_FILE=$(printf "%s/%04d-%s.diff" "$PATCH_DIR" "$INDEX" "$COMMIT")
      git -C "$SANDBOX" diff "$PREV".."$COMMIT" \
        | strip_index_lines \
        | sed -e '$a\' \
        > "$DIFF_FILE"
      PREV="$COMMIT"
      INDEX=$((INDEX + 1))
    done

    # Apply to host
    if current_apply_patches "$HOST" "$PATCH_DIR"; then
      pass "rename→modify (current — unexpected success)"
    else
      fail "rename→modify — git apply fails on rename chain (expected: 3-way would fix)"
    fi
  fi

  # If apply succeeded, verify renamed.txt exists
  if [[ -f "$HOST/renamed.txt" ]]; then
    local CONTENT
    CONTENT=$(tail -1 "$HOST/renamed.txt")
    if [[ "$CONTENT" == "agent modification" ]]; then
      pass "rename→modify — content correct"
    else
      fail "rename→modify — wrong content: $CONTENT"
    fi
  fi

  rm -rf "$DIR"
}

# =============================================================================
# Test 2: delete → recreate
#
# Without 3-way: git apply gets confused when a file is deleted then
#   recreated — the recreation diff references a deleted file.
# With 3-way: git am --3way handles the lifecycle correctly.
# =============================================================================
test_delete_then_recreate() {
  echo "[test_delete_then_recreate]"
  local DIR
  DIR=$(mktemp -d)

  create_scenario_repo "$DIR"
  local HOST="$DIR/host"
  local SANDBOX="$DIR/sandbox"

  # Create a file, delete it, recreate with different content
  echo "original" > "$SANDBOX/deleteme.txt"
  git -C "$SANDBOX" add deleteme.txt
  git -C "$SANDBOX" commit -m "create deleteme.txt" --quiet
  git -C "$SANDBOX" rm deleteme.txt --quiet
  git -C "$SANDBOX" commit -m "delete deleteme.txt" --quiet
  echo "recreated content" > "$SANDBOX/deleteme.txt"
  git -C "$SANDBOX" add deleteme.txt
  git -C "$SANDBOX" commit -m "recreate deleteme.txt" --quiet

  if [[ "$ENABLE_3WAY" == "true" ]]; then
    proposed_apply_patches "$HOST" "$SANDBOX" || {
      fail "delete→recreate — git am --3way should succeed"; rm -rf "$DIR"; return 1
    }
    pass "delete→recreate (3-way)"
  else
    local PATCH_DIR="$SANDBOX/exported"
    rm -rf "$PATCH_DIR"
    mkdir -p "$PATCH_DIR"
    local INIT_SHA
    INIT_SHA=$(grep init_sha "$SANDBOX/.git/SESSION_STATE" | cut -d= -f2)
    local INDEX=1
    local PREV="$INIT_SHA"
    for COMMIT in $(git -C "$SANDBOX" rev-list "${INIT_SHA}..HEAD" --reverse); do
      local DIFF_FILE
      DIFF_FILE=$(printf "%s/%04d-%s.diff" "$PATCH_DIR" "$INDEX" "$COMMIT")
      git -C "$SANDBOX" diff "$PREV".."$COMMIT" \
        | strip_index_lines \
        | sed -e '$a\' \
        > "$DIFF_FILE"
      PREV="$COMMIT"
      INDEX=$((INDEX + 1))
    done

    if current_apply_patches "$HOST" "$PATCH_DIR"; then
      pass "delete→recreate (current — unexpected success)"
    else
      fail "delete→recreate — git apply fails on delete→recreate chain (expected: 3-way would fix)"
    fi
  fi

  if [[ -f "$HOST/deleteme.txt" ]]; then
    local CONTENT
    CONTENT=$(cat "$HOST/deleteme.txt")
    if [[ "$CONTENT" == "recreated content" ]]; then
      pass "delete→recreate — content correct"
    else
      fail "delete→recreate — wrong content: $CONTENT"
    fi
  fi

  rm -rf "$DIR"
}

# =============================================================================
# Test 3: baseline tree integrity (applies to both paths)
#
# The synthetic root commit tree must match host HEAD tree.
# This is a prerequisite for 3-way merge to work.
# =============================================================================
test_baseline_tree_integrity() {
  echo "[test_baseline_tree_integrity]"
  local DIR
  DIR=$(mktemp -d)

  create_scenario_repo "$DIR"
  local HOST="$DIR/host"
  local SANDBOX="$DIR/sandbox"

  local HOST_TREE
  HOST_TREE=$(git -C "$HOST" rev-parse HEAD^{tree})

  if [[ "$ENABLE_3WAY" == "true" ]]; then
    local SANDBOX_TREE
    SANDBOX_TREE=$(git -C "$SANDBOX" log --format="%T" -1 _baseline)

    if [[ "$HOST_TREE" != "$SANDBOX_TREE" ]]; then
      fail "baseline tree mismatch: host=$HOST_TREE sandbox=$SANDBOX_TREE"; rm -rf "$DIR"; return 1
    fi
    pass "baseline tree integrity (3-way)"
  else
    # Current: sandbox tree is from git commit -m "agent-sandbox: baseline"
    # It should match host tree since we copied file.txt
    local SANDBOX_TREE
    SANDBOX_TREE=$(git -C "$SANDBOX" rev-parse HEAD^{tree})

    # The tree may differ because git init + commit creates a different tree
    # (different author, timestamp in commit, not in tree). Tree should be same
    # since file content is identical.
    if [[ "$HOST_TREE" != "$SANDBOX_TREE" ]]; then
      fail "baseline tree mismatch (current): host=$HOST_TREE sandbox=$SANDBOX_TREE"
      rm -rf "$DIR"; return 1
    fi
    pass "baseline tree integrity (current)"
  fi

  rm -rf "$DIR"
}

# =============================================================================
# Test 4: simple modification (baseline — should work on both paths)
# =============================================================================
test_simple_modification() {
  echo "[test_simple_modification]"
  local DIR
  DIR=$(mktemp -d)

  create_scenario_repo "$DIR"
  local HOST="$DIR/host"
  local SANDBOX="$DIR/sandbox"

  # Agent: simple file modification (no rename, no delete)
  echo "agent change" >> "$SANDBOX/file.txt"
  git -C "$SANDBOX" add file.txt
  git -C "$SANDBOX" commit -m "simple modification" --quiet

  if [[ "$ENABLE_3WAY" == "true" ]]; then
    proposed_apply_patches "$HOST" "$SANDBOX" || {
      fail "simple modification — git am --3way should succeed"; rm -rf "$DIR"; return 1
    }
    pass "simple modification (3-way)"
  else
    local PATCH_DIR="$SANDBOX/exported"
    rm -rf "$PATCH_DIR"
    mkdir -p "$PATCH_DIR"
    local INIT_SHA
    INIT_SHA=$(grep init_sha "$SANDBOX/.git/SESSION_STATE" | cut -d= -f2)
    local INDEX=1
    local PREV="$INIT_SHA"
    for COMMIT in $(git -C "$SANDBOX" rev-list "${INIT_SHA}..HEAD" --reverse); do
      local DIFF_FILE
      DIFF_FILE=$(printf "%s/%04d-%s.diff" "$PATCH_DIR" "$INDEX" "$COMMIT")
      git -C "$SANDBOX" diff "$PREV".."$COMMIT" \
        | strip_index_lines \
        | sed -e '$a\' \
        > "$DIFF_FILE"
      PREV="$COMMIT"
      INDEX=$((INDEX + 1))
    done

    current_apply_patches "$HOST" "$PATCH_DIR" || {
      fail "simple modification — git apply should succeed (baseline test)"; rm -rf "$DIR"; return 1
    }
    pass "simple modification (current)"
  fi

  grep -q "agent change" "$HOST/file.txt" || {
    fail "simple modification — change not found"; rm -rf "$DIR"; return 1
  }

  rm -rf "$DIR"
}

# =============================================================================
main() {
  local MODE
  if [[ "$ENABLE_3WAY" == "true" ]]; then
    MODE="3-WAY MERGE (proposed)"
  else
    MODE="CURRENT PIPELINE (git apply)"
  fi

  echo "=== test_3way_merge_regression — $MODE ==="
  echo ""

  test_baseline_tree_integrity
  test_simple_modification
  test_rename_then_modify
  test_delete_then_recreate

  echo ""
  if [[ "$ENABLE_3WAY" == "true" ]]; then
    echo "Expected: ALL tests PASS (3-way merge resolves rename/delete chains)"
  else
    echo "Expected: rename→modify and delete→recreate FAIL (git apply limitation)"
  fi
  echo ""

  test_done "test_3way_merge_regression"
}

main "$@"

#!/usr/bin/env bash
# tests/test_checkpoint.sh
# Unit tests for SHA-based identity derivation.
#
# Covers:
#   SANDBOX_ID derivation formula — 8-char hex hash from SANDBOX_DIR and HOST_HEAD_SHA
#
# Note: checkpoint_* functions were removed in 20260422-04-impl-remove_checkpoint_tags.md.
# worktree_id_derive tests migrated to SANDBOX_ID derivation tests in M2.7.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/libs/test_common.sh"
source "$SCRIPT_DIR/libs/git_fixtures.sh"

FIXTURE_DIR="$(mktemp -d /tmp/XXXXXX)"
trap 'rm -rf "$FIXTURE_DIR"' EXIT

# Helper: compute SANDBOX_ID same way start_agent.sh does.
sandbox_id_derive() {
  local sandbox_dir="$1"
  local host_head_sha="$2"
  echo "${sandbox_dir}:${host_head_sha}" | sha256sum | cut -c1-8
}

# -------------------------
# SANDBOX_ID derivation tests
# -------------------------

test_sandbox_id_returns_8_chars() {
  local dir="$FIXTURE_DIR/sid_8_repo"
  make_committed_repo "$dir"
  local sha; sha=$(git -C "$dir" rev-parse HEAD)
  local sid
  sid=$(sandbox_id_derive "$dir" "$sha")

  if [[ ${#sid} -eq 8 ]]; then
    pass "SANDBOX_ID is 8 characters"
  else
    fail "SANDBOX_ID returned ${#sid} chars, expected 8"
  fi
}

test_sandbox_id_is_hex() {
  local dir="$FIXTURE_DIR/sid_hex_repo"
  make_committed_repo "$dir"
  local sha; sha=$(git -C "$dir" rev-parse HEAD)
  local sid
  sid=$(sandbox_id_derive "$dir" "$sha")

  if [[ "$sid" =~ ^[a-f0-9]{8}$ ]]; then
    pass "SANDBOX_ID is valid hex"
  else
    fail "SANDBOX_ID returned non-hex: $sid"
  fi
}

test_sandbox_id_stable_across_calls() {
  local dir="$FIXTURE_DIR/sid_stable_repo"
  make_committed_repo "$dir"
  local sha; sha=$(git -C "$dir" rev-parse HEAD)

  local sid1 sid2
  sid1=$(sandbox_id_derive "$dir" "$sha")
  sid2=$(sandbox_id_derive "$dir" "$sha")

  if [[ "$sid1" == "$sid2" ]]; then
    pass "SANDBOX_ID is stable across multiple calls"
  else
    fail "SANDBOX_ID not stable: $sid1 vs $sid2"
  fi
}

test_sandbox_id_different_for_different_sandbox_dirs() {
  local dir1="$FIXTURE_DIR/sid_diff_dir1"
  local dir2="$FIXTURE_DIR/sid_diff_dir2"
  local sha_repo="$FIXTURE_DIR/sid_diff_sha_repo"
  make_committed_repo "$sha_repo"
  mkdir -p "$dir1" "$dir2"
  local sha; sha=$(git -C "$sha_repo" rev-parse HEAD)

  local sid1 sid2
  sid1=$(sandbox_id_derive "$dir1" "$sha")
  sid2=$(sandbox_id_derive "$dir2" "$sha")

  if [[ "$sid1" != "$sid2" ]]; then
    pass "SANDBOX_ID differs for different SANDBOX_DIR paths"
  else
    fail "SANDBOX_ID should differ for different SANDBOX_DIR paths"
  fi
}

test_sandbox_id_different_for_different_commits() {
  local dir="$FIXTURE_DIR/sid_diff_commit_repo"
  make_committed_repo "$dir"

  # Use two different commits in the same repo
  local sha1; sha1=$(git -C "$dir" rev-parse HEAD)

  # Create a second commit
  echo "change" > "$dir/newfile.txt"
  git -C "$dir" add -A
  git -C "$dir" commit -m "second commit"
  local sha2; sha2=$(git -C "$dir" rev-parse HEAD)

  local sid1 sid2
  sid1=$(sandbox_id_derive "$dir" "$sha1")
  sid2=$(sandbox_id_derive "$dir" "$sha2")

  if [[ "$sid1" != "$sid2" ]]; then
    pass "SANDBOX_ID differs for different HOST_HEAD_SHA values"
  else
    fail "SANDBOX_ID should differ for different HOST_HEAD_SHA values"
  fi
}

# -------------------------
# Run all tests
# -------------------------

echo "=== SANDBOX_ID derivation unit tests ==="
echo

run_test test_sandbox_id_returns_8_chars
run_test test_sandbox_id_is_hex
run_test test_sandbox_id_stable_across_calls
run_test test_sandbox_id_different_for_different_sandbox_dirs
run_test test_sandbox_id_different_for_different_commits

test_done

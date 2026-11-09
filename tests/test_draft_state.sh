#!/usr/bin/env bash
# tests/test_draft_state.sh
# Unit tests for libs/draft_state.sh  --  folder name parsing, the branch-local
# draft record, and branch validation.
# Pins cite: docs/adr/diff_packaging.md (2026-11-08 record decision).

#
# Covers:
#   draft_parse_folder_name         --  4 parsing sub-cases (no session-id, with session-id, edge, legit hex suffix)
#   draft_guard_no_collision        --  exact branch-ref collision, distinct identities
#   draft_record_write / clear      --  both keys written and removed
#   draft_validate_branch           --  branch shape, missing record, field invariants

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup
source "$TEST_DIR/libs/git_fixtures.sh"
source "$REPO_ROOT/src/libs/draft_state.sh"


# =============================================================================
# draft_parse_folder_name
# =============================================================================

# Given: a folder name in <session-ts>-<branch> shape, no session-id suffix
# When:  draft_parse_folder_name runs
# Then:  SESSION_TS and SANITIZED_HOST_BRANCH split at column 15, SESSION_ID stays empty
# Asserts: the base split.
test_parse_folder_name_basic() {
  local SESSION_TS="" SANITIZED_HOST_BRANCH="" SESSION_ID=""
  draft_parse_folder_name "20260420-120000-feature-branch"

  assert_eq "$SESSION_TS" "20260420-120000" "draft_parse_folder_name extracts SESSION_TS"

  assert_eq "$SANITIZED_HOST_BRANCH" "feature-branch" "draft_parse_folder_name extracts SANITIZED_HOST_BRANCH"

  assert_empty "$SESSION_ID" "draft_parse_folder_name leaves SESSION_ID empty when no session-id present"
}

# Given: a folder name with a trailing 6-hex session-id
# When:  draft_parse_folder_name runs
# Then:  the suffix is SESSION_ID and the branch loses it
# Asserts: session-id recovery by shape.
test_parse_folder_name_with_session_id() {
  local SESSION_TS="" SANITIZED_HOST_BRANCH="" SESSION_ID=""
  draft_parse_folder_name "20260420-120000-feature-branch-a1b2c3"

  assert_eq "$SESSION_TS" "20260420-120000" "draft_parse_folder_name extracts SESSION_TS with session-id present"

  assert_eq "$SANITIZED_HOST_BRANCH" "feature-branch" "draft_parse_folder_name strips session-id from SANITIZED_HOST_BRANCH"

  assert_eq "$SESSION_ID" "a1b2c3" "draft_parse_folder_name extracts SESSION_ID from trailing hex"
}

# Given: branch names with underscores, a 5-char suffix, and a non-hex suffix
# When:  draft_parse_folder_name runs
# Then:  underscores survive, and neither non-6-hex suffix becomes SESSION_ID
# Asserts: the boundary of the session-id shape test (a branch that legitimately ends in six hex chars is not covered).
test_parse_folder_name_edge_cases() {
  # Branch with underscores and numbers
  local SESSION_TS="" SANITIZED_HOST_BRANCH="" SESSION_ID=""
  draft_parse_folder_name "20260420-120000-feature_M2_3-agent"

  assert_eq "$SANITIZED_HOST_BRANCH" "feature_M2_3-agent" "draft_parse_folder_name handles underscores in branch name"

  # Trailing chars that look like hex but aren't 6 chars
  SESSION_TS="" SANITIZED_HOST_BRANCH="" SESSION_ID=""
  draft_parse_folder_name "20260420-120000-branch-abc12"  # 5 chars
  assert_eq "$SESSION_ID" "" "draft_parse_folder_name does not treat 5-char hex suffix as SESSION_ID"

  # Trailing non-hex
  SESSION_TS="" SANITIZED_HOST_BRANCH="" SESSION_ID=""
  draft_parse_folder_name "20260420-120000-branch-xyz789"
  assert_eq "$SESSION_ID" "" "draft_parse_folder_name does not treat non-hex suffix as SESSION_ID"
}

# Given: a branch name that ends in exactly six hex characters
# When:  draft_parse_folder_name runs
# Then:  the shape rule reads the suffix as SESSION_ID and strips it from the branch
# Asserts: the shape rule claims any trailing six-hex run, whatever the branch name meant.
test_parse_folder_name_hex_suffix_claimed() {
  local SESSION_TS="" SANITIZED_HOST_BRANCH="" SESSION_ID=""
  draft_parse_folder_name "20260420-120000-branch-abcdef"

  assert_eq "$SESSION_ID" "abcdef" "draft_parse_folder_name claims a trailing six-hex branch suffix"

  assert_eq "$SANITIZED_HOST_BRANCH" "branch" "draft_parse_folder_name removes the claimed suffix"
}

# =============================================================================
# draft_guard_no_collision
# =============================================================================

# Given: a repo with no draft branch of that name
# When:  draft_guard_no_collision runs
# Then:  it returns 0
# Asserts: the absence side of the collision guard.
test_guard_no_collision_no_branch() {
  local DIR="$FIXTURE_DIR/guard_none"
  make_committed_repo "$DIR"

  if draft_guard_no_collision "$DIR" "draft/nonexistent" 2>/dev/null; then
    pass "draft_guard_no_collision passes when branch does not exist"
  else
    fail "draft_guard_no_collision should pass for absent branch"
  fi
}

# Given: a repo holding the exact draft branch
# When:  draft_guard_no_collision runs
# Then:  it returns non-zero
# Asserts: the exact-ref collision is refused.
test_guard_no_collision_detects_branch() {
  local DIR="$FIXTURE_DIR/guard_exists"
  make_committed_repo "$DIR"
  git -C "$DIR" branch "draft/existing-branch"

  if draft_guard_no_collision "$DIR" "draft/existing-branch" 2>/dev/null; then
    fail "draft_guard_no_collision should reject existing branch"
  else
    pass "draft_guard_no_collision rejects existing branch"
  fi
}

# Given: a repo holding a draft branch with a different name
# When:  draft_guard_no_collision runs for another draft name
# Then:  it returns 0
# Asserts: the guard is exact-ref, not a repo-wide singleton.
test_guard_no_collision_allows_distinct_identity() {
  local DIR="$FIXTURE_DIR/guard_distinct"
  make_committed_repo "$DIR"
  git -C "$DIR" branch "draft/other-bundle"

  if draft_guard_no_collision "$DIR" "draft/new-bundle" 2>/dev/null; then
    pass "draft_guard_no_collision allows a distinct draft identity"
  else
    fail "draft_guard_no_collision should allow a distinct draft identity"
  fi
}

# =============================================================================
# draft_record_write / draft_record_clear
# =============================================================================

# Given: a repo and a draft branch name
# When:  draft_record_write runs
# Then:  both record keys carry their values
# Asserts: the writer's key names and values.
test_record_write() {
  local DIR="$FIXTURE_DIR/record_write"
  make_committed_repo "$DIR"
  local BASE
  BASE=$(get_init_sha "$DIR")

  draft_record_write "$DIR" "draft/record" "main" "$BASE"

  assert_eq "$(git -C "$DIR" config --local --get branch.draft/record.agent-sandbox-source)" \
    "main" "draft_record_write writes source_branch"
  assert_eq "$(git -C "$DIR" config --local --get branch.draft/record.agent-sandbox-fork)" \
    "$BASE" "draft_record_write writes fork_point"
}

# Given: a written record
# When:  draft_record_clear runs
# Then:  both keys are absent
# Asserts: the cleanup path for a branch that was never created.
test_record_clear() {
  local DIR="$FIXTURE_DIR/record_clear"
  make_committed_repo "$DIR"
  local BASE
  BASE=$(get_init_sha "$DIR")
  draft_record_write "$DIR" "draft/record" "main" "$BASE"

  draft_record_clear "$DIR" "draft/record"

  if git -C "$DIR" config --local --get branch.draft/record.agent-sandbox-source >/dev/null 2>&1; then
    fail "draft_record_clear left source_branch in the record"
  else
    pass "draft_record_clear removes source_branch"
  fi
  if git -C "$DIR" config --local --get branch.draft/record.agent-sandbox-fork >/dev/null 2>&1; then
    fail "draft_record_clear left fork_point in the record"
  else
    pass "draft_record_clear removes fork_point"
  fi
}

# =============================================================================
# draft_validate_branch
# =============================================================================

# Given: a repo checked out on a non-draft branch
# When:  draft_validate_branch runs
# Then:  it reports 'not on a draft branch'
# Asserts: the draft-prefix guard.
test_validate_not_on_draft_branch() {
  local DIR="$FIXTURE_DIR/validate_not_draft"
  make_committed_repo "$DIR"

  local OUTPUT
  OUTPUT=$(draft_validate_branch "$DIR" 2>&1) || true
  if echo "$OUTPUT" | grep -q "not on a draft branch"; then
    pass "draft_validate_branch rejects non-draft branch"
  else
    fail "draft_validate_branch should reject non-draft branch"
  fi
}

# Given: a draft branch with no record
# When:  draft_validate_branch runs
# Then:  it reports the missing record
# Asserts: the record-presence guard.
test_validate_missing_record() {
  local DIR="$FIXTURE_DIR/validate_missing_record"
  make_committed_repo "$DIR"
  git -C "$DIR" checkout -b "draft/no-record" --quiet

  local OUTPUT
  OUTPUT=$(draft_validate_branch "$DIR" 2>&1) || true
  if echo "$OUTPUT" | grep -q "draft record not found"; then
    pass "draft_validate_branch rejects a branch missing the record"
  else
    fail "draft_validate_branch should reject a branch without the record, got: $OUTPUT"
  fi
}

# Given: a valid draft branch with a source record
# When:  draft_validate_branch runs
# Then:  it returns 0 and sets the source and current branch
# Asserts: the happy path.
test_validate_success() {
  local DIR="$FIXTURE_DIR/validate_ok"
  make_committed_repo "$DIR"
  local BASE
  BASE=$(get_init_sha "$DIR")
  git -C "$DIR" checkout -b "draft/valid-branch" --quiet
  draft_record_write "$DIR" "draft/valid-branch" "main" "$BASE"

  DRAFT_SOURCE_BRANCH=""
  DRAFT_CURRENT_BRANCH=""
  if draft_validate_branch "$DIR"; then
    pass "draft_validate_branch succeeds on a valid draft branch"
  else
    fail "draft_validate_branch should succeed on a valid draft branch"
    return
  fi

  assert_eq "$DRAFT_SOURCE_BRANCH" "main" "draft_validate_branch sets DRAFT_SOURCE_BRANCH"
  assert_eq "$DRAFT_CURRENT_BRANCH" "draft/valid-branch" "draft_validate_branch sets DRAFT_CURRENT_BRANCH"
}

# Given: a branch record with no source_branch key
# When:  draft_validate_branch runs
# Then:  it reports the missing source field
# Asserts: the source-field invariant, not just record presence.
test_validate_missing_source_branch() {
  local DIR="$FIXTURE_DIR/validate_no_source"
  make_committed_repo "$DIR"
  local BASE
  BASE=$(get_init_sha "$DIR")
  git -C "$DIR" checkout -b "draft/no-source" --quiet
  git -C "$DIR" config --local branch.draft/no-source.agent-sandbox-fork "$BASE"

  local OUTPUT
  OUTPUT=$(draft_validate_branch "$DIR" 2>&1) || true
  if echo "$OUTPUT" | grep -q "missing 'source_branch'"; then
    pass "draft_validate_branch rejects a record without source_branch"
  else
    fail "draft_validate_branch should reject a record without source_branch, got: $OUTPUT"
  fi
}

# Given: a branch record whose fork_point is not a commit
# When:  draft_record_read reads the fork key
# Then:  it returns the literal value
# Asserts: the record reader does not resolve history.
test_record_read_returns_fork_point() {
  local DIR="$FIXTURE_DIR/record_bad_fork"
  make_committed_repo "$DIR"
  git -C "$DIR" checkout -b "draft/bad-fork" --quiet
  draft_record_write "$DIR" "draft/bad-fork" "main" "not-a-commit"

  local OUTPUT
  OUTPUT=$(draft_record_read "$DIR" "draft/bad-fork" fork) || {
    fail "draft_record_read should return the recorded fork point"
    return
  }
  assert_eq "$OUTPUT" "not-a-commit" "draft_record_read returns the literal fork point"
}

# Given: a branch record with a key outside the two-key contract
# When:  draft_validate_branch runs
# Then:  it sets only the source and current branch
# Asserts: the reader reads only its own keys.
test_validate_ignores_unknown_keys() {
  local DIR="$FIXTURE_DIR/validate_unknown_key"
  make_committed_repo "$DIR"
  local BASE
  BASE=$(get_init_sha "$DIR")
  git -C "$DIR" checkout -b "draft/unknown-key" --quiet
  draft_record_write "$DIR" "draft/unknown-key" "main" "$BASE"
  git -C "$DIR" config --local branch.draft/unknown-key.agent-sandbox-ghost "ghost"

  DRAFT_SOURCE_BRANCH=""
  DRAFT_CURRENT_BRANCH=""
  if draft_validate_branch "$DIR" 2>/dev/null; then
    assert_eq "$DRAFT_CURRENT_BRANCH" "draft/unknown-key" \
      "draft_validate_branch reports the checked-out branch, not the crafted key"
    assert_eq "$DRAFT_SOURCE_BRANCH" "main" \
      "draft_validate_branch reads only the source key"
  else
    fail "draft_validate_branch should succeed on a record with an extra key"
  fi
}

# =============================================================================
# Run all
# =============================================================================

run_test test_parse_folder_name_basic
run_test test_parse_folder_name_with_session_id
run_test test_parse_folder_name_edge_cases
run_test test_parse_folder_name_hex_suffix_claimed
run_test test_guard_no_collision_no_branch
run_test test_guard_no_collision_detects_branch
run_test test_guard_no_collision_allows_distinct_identity
run_test test_record_write
run_test test_record_clear
run_test test_validate_not_on_draft_branch
run_test test_validate_missing_record
run_test test_validate_success
run_test test_validate_missing_source_branch
run_test test_record_read_returns_fork_point
run_test test_validate_ignores_unknown_keys

test_done

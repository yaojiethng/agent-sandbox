#!/usr/bin/env bash
# tests/test_draft_state.sh
# Unit tests for libs/draft_state.sh  --  folder name parsing, state I/O, branch validation.
#
# Covers:
#   draft_parse_folder_name         --  3 parsing sub-cases (no session-id, with session-id, edge)
#   draft_guard_no_collision        --  collision detection
#   draft_write_state               --  field ordering and optional session_id
#   draft_read_state_from_branch    --  key-value parsing from committed .draft-state
#   draft_validate_branch           --  branch shape, missing .draft-state, field invariants

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup
source "$TEST_DIR/libs/git_fixtures.sh"
source "$REPO_ROOT/src/libs/draft_state.sh"


# =============================================================================
# draft_parse_folder_name
# =============================================================================

test_parse_folder_name_basic() {
  local SESSION_TS="" SANITIZED_HOST_BRANCH="" SESSION_ID=""
  draft_parse_folder_name "20260420-120000-feature-branch"

  if [[ "$SESSION_TS" == "20260420-120000" ]]; then
    pass "draft_parse_folder_name extracts SESSION_TS"
  else
    fail "draft_parse_folder_name: expected SESSION_TS=20260420-120000, got $SESSION_TS"
  fi

  if [[ "$SANITIZED_HOST_BRANCH" == "feature-branch" ]]; then
    pass "draft_parse_folder_name extracts SANITIZED_HOST_BRANCH"
  else
    fail "draft_parse_folder_name: expected SANITIZED_HOST_BRANCH=feature-branch, got $SANITIZED_HOST_BRANCH"
  fi

  if [[ -z "$SESSION_ID" ]]; then
    pass "draft_parse_folder_name leaves SESSION_ID empty when no session-id present"
  else
    fail "draft_parse_folder_name: expected SESSION_ID empty, got $SESSION_ID"
  fi
}

test_parse_folder_name_with_session_id() {
  local SESSION_TS="" SANITIZED_HOST_BRANCH="" SESSION_ID=""
  draft_parse_folder_name "20260420-120000-feature-branch-a1b2c3"

  if [[ "$SESSION_TS" == "20260420-120000" ]]; then
    pass "draft_parse_folder_name extracts SESSION_TS with session-id present"
  else
    fail "draft_parse_folder_name: expected SESSION_TS=20260420-120000, got $SESSION_TS"
  fi

  if [[ "$SANITIZED_HOST_BRANCH" == "feature-branch" ]]; then
    pass "draft_parse_folder_name strips session-id from SANITIZED_HOST_BRANCH"
  else
    fail "draft_parse_folder_name: expected SANITIZED_HOST_BRANCH=feature-branch, got $SANITIZED_HOST_BRANCH"
  fi

  if [[ "$SESSION_ID" == "a1b2c3" ]]; then
    pass "draft_parse_folder_name extracts SESSION_ID from trailing hex"
  else
    fail "draft_parse_folder_name: expected SESSION_ID=a1b2c3, got $SESSION_ID"
  fi
}

test_parse_folder_name_edge_cases() {
  # Branch with underscores and numbers
  local SESSION_TS="" SANITIZED_HOST_BRANCH="" SESSION_ID=""
  draft_parse_folder_name "20260420-120000-feature_M2_3-agent"

  if [[ "$SANITIZED_HOST_BRANCH" == "feature_M2_3-agent" ]]; then
    pass "draft_parse_folder_name handles underscores in branch name"
  else
    fail "draft_parse_folder_name: expected feature_M2_3-agent, got $SANITIZED_HOST_BRANCH"
  fi

  # Trailing chars that look like hex but aren't 6 chars
  SESSION_TS="" SANITIZED_HOST_BRANCH="" SESSION_ID=""
  draft_parse_folder_name "20260420-120000-branch-abc12"  # 5 chars
  if [[ "$SESSION_ID" == "" ]]; then
    pass "draft_parse_folder_name does not treat 5-char hex suffix as SESSION_ID"
  else
    fail "draft_parse_folder_name: expected SESSION_ID empty for 5-char suffix, got $SESSION_ID"
  fi

  # Trailing non-hex
  SESSION_TS="" SANITIZED_HOST_BRANCH="" SESSION_ID=""
  draft_parse_folder_name "20260420-120000-branch-xyz789"
  if [[ "$SESSION_ID" == "" ]]; then
    pass "draft_parse_folder_name does not treat non-hex suffix as SESSION_ID"
  else
    fail "draft_parse_folder_name: expected SESSION_ID empty for non-hex suffix, got $SESSION_ID"
  fi
}

# =============================================================================
# draft_guard_no_collision
# =============================================================================

test_guard_no_collision_no_branch() {
  local DIR="$FIXTURE_DIR/guard_none"
  make_committed_repo "$DIR"

  if draft_guard_no_collision "$DIR" "draft/nonexistent"; then
    pass "draft_guard_no_collision passes when branch does not exist"
  else
    fail "draft_guard_no_collision should pass for absent branch"
  fi
}

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

# =============================================================================
# draft_write_state
# =============================================================================

test_write_state_basic() {
  local OUTPUT
  OUTPUT=$(draft_write_state "main" "abc123" "Agent" "20260420-120000" "feat-x" "3" "20260420-120000" "20260420-130000")

  if echo "$OUTPUT" | grep -q "^source_branch: main$"; then
    pass "draft_write_state includes source_branch"
  else
    fail "draft_write_state missing source_branch"
  fi
  if echo "$OUTPUT" | grep -q "^from_hash: abc123$"; then
    pass "draft_write_state includes from_hash"
  else
    fail "draft_write_state missing from_hash"
  fi
  if echo "$OUTPUT" | grep -q "^diff_count: 3$"; then
    pass "draft_write_state includes diff_count"
  else
    fail "draft_write_state missing diff_count"
  fi
  if ! echo "$OUTPUT" | grep -q "^session_id:"; then
    pass "draft_write_state omits session_id when not given"
  else
    fail "draft_write_state should omit session_id when absent"
  fi
}

test_write_state_with_session_id() {
  local OUTPUT
  OUTPUT=$(draft_write_state "main" "abc123" "Agent" "20260420-120000" "feat-x" "3" "20260420-120000" "20260420-130000" "a1b2c3")

  if echo "$OUTPUT" | grep -q "^session_id: a1b2c3$"; then
    pass "draft_write_state includes session_id when given"
  else
    fail "draft_write_state should include session_id when provided"
  fi
}

# =============================================================================
# draft_read_state_from_branch
# =============================================================================

test_read_state_success() {
  local DIR="$FIXTURE_DIR/read_ok"
  make_committed_repo "$DIR"
  git -C "$DIR" checkout -b "draft/my-branch" --quiet

  # Commit a minimal .draft-state
  cat > "$DIR/.draft-state" <<'EOF'
source_branch: main
from_hash: abc123
author: Agent
session_ts: 20260420-120000
host_branch: feat-x
diff_count: 3
exported-at: 20260420-120000
drafted-at: 20260420-130000
EOF
  git -C "$DIR" add .draft-state
  git -C "$DIR" commit -m ".draft-state" --quiet

  local OUTPUT
  OUTPUT=$(draft_read_state_from_branch "$DIR" "draft/my-branch") || {
    fail "draft_read_state_from_branch should succeed"
    return
  }
  pass "draft_read_state_from_branch succeeds on valid branch"

  # Check key fields materialized as shell variable assignments
  eval "$OUTPUT" 2>/dev/null || true
  if [[ "${source_branch:-}" == "main" ]]; then
    pass "draft_read_state_from_branch yields correct source_branch (via eval)"
  else
    fail "draft_read_state_from_branch: expected source_branch=main after eval, got '${source_branch:-}'"
  fi
}

test_read_state_branch_nonexistent() {
  local DIR="$FIXTURE_DIR/read_missing_branch"
  make_committed_repo "$DIR"

  if draft_read_state_from_branch "$DIR" "draft/nonexistent" 2>/dev/null; then
    fail "draft_read_state_from_branch should fail for nonexistent branch"
  else
    pass "draft_read_state_from_branch fails for nonexistent branch"
  fi
}

test_read_state_missing_dot_draft_state() {
  local DIR="$FIXTURE_DIR/read_missing_state"
  make_committed_repo "$DIR"
  git -C "$DIR" checkout -b "draft/no-state" --quiet
  # Create an empty commit  --  no .draft-state
  echo "dummy" > "$DIR/dummy.txt"
  git -C "$DIR" add dummy.txt
  git -C "$DIR" commit -m "no draft state" --quiet

  if draft_read_state_from_branch "$DIR" "draft/no-state" 2>/dev/null; then
    fail "draft_read_state_from_branch should fail when .draft-state missing"
  else
    pass "draft_read_state_from_branch fails when .draft-state missing"
  fi
}

# =============================================================================
# draft_validate_branch
# =============================================================================

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

test_validate_missing_dot_draft_state() {
  local DIR="$FIXTURE_DIR/validate_missing_state"
  make_committed_repo "$DIR"
  git -C "$DIR" checkout -b "draft/no-dot-state" --quiet
  echo "dummy" > "$DIR/dummy.txt"
  git -C "$DIR" add dummy.txt
  git -C "$DIR" commit -m "no dot-state" --quiet

  local OUTPUT
  OUTPUT=$(draft_validate_branch "$DIR" 2>&1) || true
  if echo "$OUTPUT" | grep -q "\.draft-state not found"; then
    pass "draft_validate_branch rejects branch missing .draft-state"
  else
    fail "draft_validate_branch should reject branch without .draft-state, got: $OUTPUT"
  fi
}

test_validate_success() {
  local DIR="$FIXTURE_DIR/validate_ok"
  make_committed_repo "$DIR"
  local INIT_SHA
  INIT_SHA=$(git -C "$DIR" rev-parse HEAD)

  git -C "$DIR" checkout -b "draft/valid-branch" --quiet
  cat > "$DIR/.draft-state" <<EOF
source_branch: main
from_hash: $INIT_SHA
author: Agent
session_ts: 20260420-120000
host_branch: valid-branch
diff_count: 1
exported-at: 20260420-120000
drafted-at: 20260420-130000
EOF
  git -C "$DIR" add .draft-state
  git -C "$DIR" commit -m ".draft-state" --quiet
  echo "change" > "$DIR/file2.txt"
  git -C "$DIR" add file2.txt
  git -C "$DIR" commit -m "feat: actual change" --quiet

  local OUTPUT
  OUTPUT=$(draft_validate_branch "$DIR" 2>&1) || {
    fail "draft_validate_branch should succeed on valid draft branch"
    return
  }
  pass "draft_validate_branch succeeds on valid draft branch"

  # Check it prints CURRENT_BRANCH and DRAFT_STATE_COMMIT
  if echo "$OUTPUT" | grep -q "CURRENT_BRANCH=draft/valid-branch"; then
    pass "draft_validate_branch prints CURRENT_BRANCH"
  else
    fail "draft_validate_branch should print CURRENT_BRANCH"
  fi
  if echo "$OUTPUT" | grep -q "DRAFT_STATE_COMMIT="; then
    pass "draft_validate_branch prints DRAFT_STATE_COMMIT"
  else
    fail "draft_validate_branch should print DRAFT_STATE_COMMIT"
  fi
}

test_validate_missing_from_hash() {
  local DIR="$FIXTURE_DIR/validate_no_from"
  make_committed_repo "$DIR"
  local INIT_SHA
  INIT_SHA=$(git -C "$DIR" rev-parse HEAD)

  git -C "$DIR" checkout -b "draft/no-from-hash" --quiet
  # .draft-state missing the from_hash field
  cat > "$DIR/.draft-state" <<'EOF'
source_branch: main
author: Agent
session_ts: 20260420-120000
host_branch: no-from-hash
diff_count: 1
exported-at: 20260420-120000
drafted-at: 20260420-130000
EOF
  git -C "$DIR" add .draft-state
  git -C "$DIR" commit -m ".draft-state" --quiet
  echo "change" > "$DIR/file2.txt"
  git -C "$DIR" add file2.txt
  git -C "$DIR" commit -m "feat: change" --quiet

  local OUTPUT
  OUTPUT=$(draft_validate_branch "$DIR" 2>&1) || true
  if echo "$OUTPUT" | grep -q "missing 'from_hash' field"; then
    pass "draft_validate_branch rejects .draft-state without from_hash"
  else
    fail "draft_validate_branch should reject missing from_hash, got: $OUTPUT"
  fi
}

test_validate_dropped_state_commit_warns_and_continues() {
  # If the '.draft-state' commit lost its message (e.g. rebase -i reword),
  # the lookup finds nothing: function must WARN, emit DRAFT_STATE_COMMIT=,
  # and still succeed with CURRENT_BRANCH (confirm's drop step is skipped).
  local DIR="$FIXTURE_DIR/validate_dropped"
  make_committed_repo "$DIR"
  local INIT_SHA
  INIT_SHA=$(git -C "$DIR" rev-parse HEAD)

  git -C "$DIR" checkout -b "draft/dropped-state" --quiet
  cat > "$DIR/.draft-state" <<EOF
source_branch: main
from_hash: $INIT_SHA
author: Agent
EOF
  git -C "$DIR" add .draft-state
  git -C "$DIR" commit -m "reworded away" --quiet

  local OUTPUT RC=0
  OUTPUT=$(draft_validate_branch "$DIR" 2>&1 </dev/null) || RC=$?

  if [[ $RC -eq 0 && "$OUTPUT" == *"commit may have been dropped during rebase"* \
     && "$OUTPUT" == *"DRAFT_STATE_COMMIT="* && "$OUTPUT" == *"CURRENT_BRANCH=draft/dropped-state"* ]]
  then
    pass "draft_validate_branch: dropped state commit -> warn, empty DRAFT_STATE_COMMIT, rc0"
  else
    fail "dropped-commit path broken: rc=$RC out='$OUTPUT'"
  fi
}

# =============================================================================
# Run all
# =============================================================================

run_test test_parse_folder_name_basic
run_test test_parse_folder_name_with_session_id
run_test test_parse_folder_name_edge_cases
run_test test_guard_no_collision_no_branch
run_test test_guard_no_collision_detects_branch
run_test test_write_state_basic
run_test test_write_state_with_session_id
run_test test_read_state_success
run_test test_read_state_branch_nonexistent
run_test test_read_state_missing_dot_draft_state
run_test test_validate_not_on_draft_branch
run_test test_validate_missing_dot_draft_state
run_test test_validate_success
run_test test_validate_missing_from_hash
run_test test_validate_dropped_state_commit_warns_and_continues

test_done

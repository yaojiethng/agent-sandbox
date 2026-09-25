#!/usr/bin/env bash
# tests/test_draft_state.sh
# Unit tests for libs/draft_state.sh  --  folder name parsing, state I/O, branch validation.
# Pins cite: devlog/discussions/design_apply_draft_workflow.md (state schema, guard surface).

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

  if draft_guard_no_collision "$DIR" "draft/nonexistent"; then
    pass "draft_guard_no_collision passes when branch does not exist"
  else
    fail "draft_guard_no_collision should pass for absent branch"
  fi
}

# Given: a repo holding the draft branch
# When:  draft_guard_no_collision runs
# Then:  it returns non-zero
# Asserts: the collision is refused.
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

# Given: the eight required field values and no session id
# When:  draft_write_state runs
# Then:  source_branch, from_hash, and diff_count appear and session_id does not
# Asserts: field emission and the optional session_id (author, session_ts, host_branch, exported-at, and drafted-at are not asserted).
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

# Given: the eight fields plus a session id
# When:  draft_write_state runs
# Then:  session_id appears with its value
# Asserts: the optional-field branch.
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

# Given: a draft branch whose tip commit carries .draft-state
# When:  draft_read_state_from_branch runs and the output is eval'd
# Then:  it returns 0 and source_branch is materialised
# Asserts: the branch-scoped read and the eval contract (the emitted quoting is shell-escaped).
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

# Given: a repo with no such branch
# When:  draft_read_state_from_branch runs
# Then:  it returns non-zero
# Asserts: failure at rc level only - the 'branch does not exist' diagnostic is not asserted, and the guard is result-redundant.
test_read_state_branch_nonexistent() {
  local DIR="$FIXTURE_DIR/read_missing_branch"
  make_committed_repo "$DIR"

  if draft_read_state_from_branch "$DIR" "draft/nonexistent" 2>/dev/null; then
    fail "draft_read_state_from_branch should fail for nonexistent branch"
  else
    pass "draft_read_state_from_branch fails for nonexistent branch"
  fi
}

# Given: a draft branch whose commits hold no .draft-state
# When:  draft_read_state_from_branch runs
# Then:  it returns non-zero
# Asserts: the missing-record path.
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

# Given: a draft branch whose commits hold no .draft-state
# When:  draft_validate_branch runs
# Then:  it reports the missing record
# Asserts: the record-presence guard.
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

# Given: a valid draft branch with a from_hash and one later commit
# When:  draft_validate_branch runs
# Then:  it returns 0 and prints CURRENT_BRANCH and DRAFT_STATE_COMMIT
# Asserts: the happy path and the state-commit lookup.
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

# Given: a .draft-state with no from_hash field, after a prior validate call in the same process
# When:  draft_validate_branch runs
# Then:  it reports the missing field
# Asserts: the field invariant - and, because the pre-clear locals are load-bearing, that state cannot leak between calls.
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

# Given: a .draft-state commit whose message no longer matches (reworded during rebase -i)
# When:  draft_validate_branch runs
# Then:  it warns, emits an empty DRAFT_STATE_COMMIT, and still returns 0 with CURRENT_BRANCH
# Asserts: the dropped-commit path the confirm drop step relies on.
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
# eval injection
# =============================================================================

# make_poisoned_state DIR BRANCH MARKER_SUBST MARKER_BT
#   Commit .draft-state on BRANCH with a command substitution and a backtick in
#   field values. The markers name the files those payloads would create.
make_poisoned_state() {
  local DIR="$1" BRANCH="$2" MARKER_SUBST="$3" MARKER_BT="$4"
  make_committed_repo "$DIR"
  local INIT_SHA
  INIT_SHA=$(git -C "$DIR" rev-parse HEAD)
  git -C "$DIR" checkout -b "$BRANCH" --quiet
  {
    printf 'source_branch: %s\n' "main"
    printf 'from_hash: %s\n' "$INIT_SHA"
    printf 'author: %s\n' "\$(touch $MARKER_SUBST)"
    printf 'session_ts: %s\n' "20260420-120000"
    printf 'host_branch: %s\n' "\`touch $MARKER_BT\`"
    printf 'diff_count: %s\n' "1"
    printf 'exported-at: %s\n' "20260420-120000"
    printf 'drafted-at: %s\n' "20260420-130000"
  } > "$DIR/.draft-state"
  git -C "$DIR" add .draft-state
  git -C "$DIR" commit -m ".draft-state" --quiet
}

# Given: a .draft-state whose field values carry a command substitution and a backtick
# When:  draft_validate_branch emits assignments and the caller evals them
# Then:  neither payload runs and each value survives as literal text
# Asserts: field values are escaped at the eval boundary.
test_validate_escapes_field_values() {
  local DIR="$FIXTURE_DIR/validate_injection"
  local MARKER_SUBST="$DIR/pwned_subst"
  local MARKER_BT="$DIR/pwned_backtick"
  make_poisoned_state "$DIR" "draft/injection" "$MARKER_SUBST" "$MARKER_BT"

  local OUTPUT
  OUTPUT=$(draft_validate_branch "$DIR" 2>/dev/null) || true
  eval "$OUTPUT" 2>/dev/null || true

  if [[ -e "$MARKER_SUBST" || -e "$MARKER_BT" ]]; then
    fail "draft_validate_branch output executed a field payload on eval"
  else
    pass "draft_validate_branch escapes field values so eval cannot execute them"
  fi

  if [[ "${author:-}" == "\$(touch $MARKER_SUBST)" ]]; then
    pass "draft_validate_branch preserves a literal field value through eval"
  else
    fail "draft_validate_branch changed the field value: '${author:-}'"
  fi
}

# Given: a .draft-state whose field values carry a command substitution and a backtick
# When:  draft_read_state_from_branch emits assignments and the caller evals them
# Then:  neither payload runs and each value survives as literal text
# Asserts: field values are escaped at the eval boundary.
test_read_state_escapes_field_values() {
  local DIR="$FIXTURE_DIR/read_injection"
  local MARKER_SUBST="$DIR/pwned_subst"
  local MARKER_BT="$DIR/pwned_backtick"
  make_poisoned_state "$DIR" "draft/read-injection" "$MARKER_SUBST" "$MARKER_BT"

  local OUTPUT
  OUTPUT=$(draft_read_state_from_branch "$DIR" "draft/read-injection") || true
  eval "$OUTPUT" 2>/dev/null || true

  if [[ -e "$MARKER_SUBST" || -e "$MARKER_BT" ]]; then
    fail "draft_read_state_from_branch output executed a field payload on eval"
  else
    pass "draft_read_state_from_branch escapes field values so eval cannot execute them"
  fi

  if [[ "${author:-}" == "\$(touch $MARKER_SUBST)" ]]; then
    pass "draft_read_state_from_branch preserves a literal field value through eval"
  else
    fail "draft_read_state_from_branch changed the field value: '${author:-}'"
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
run_test test_validate_escapes_field_values
run_test test_read_state_escapes_field_values

test_done


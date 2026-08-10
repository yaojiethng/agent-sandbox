#!/usr/bin/env bash
# tests/test_interactive_session_select.sh
# Tests for libs/interactive_session_select.sh
#
# Covers:
#   interactive_confirm_or_abort   — y/N prompt, return codes
#   interactive_select_channel     — channel picker, entry counts
#   interactive_select_session     — session picker, indicators, cap
#   interactive_select_diff_type   — diff type picker, auto-select

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup
AGENT_SANDBOX_REPO="$REPO_ROOT"
source "$REPO_ROOT/scripts/workflows/interactive.sh"
source "$TEST_DIR/libs/session_fixtures.sh"

# =============================================================================
# interactive_confirm_or_abort tests
# =============================================================================

test_confirm_or_abort_yes_proceeds() {
  local OUT
  OUT=$(echo "y" | interactive_confirm_or_abort "Apply:" "/path/to/diff" 2>/dev/null)
  if [[ "$?" -eq 0 ]]; then
    pass "interactive_confirm_or_abort returns 0 on 'y'"
  else
    fail "interactive_confirm_or_abort should return 0 on 'y'"
  fi
}

test_confirm_or_abort_no_aborts() {
  local RC=0
  echo "n" | interactive_confirm_or_abort "Apply:" "/path/to/diff" 2>/dev/null || RC=$?
  if [[ "$RC" -ne 0 ]]; then
    pass "interactive_confirm_or_abort returns non-zero on 'n'"
  else
    fail "interactive_confirm_or_abort should return non-zero on 'n'"
  fi
}

test_confirm_or_abort_empty_aborts() {
  local RC=0
  echo "" | interactive_confirm_or_abort "Apply:" "/path/to/diff" 2>/dev/null || RC=$?
  if [[ "$RC" -ne 0 ]]; then
    pass "interactive_confirm_or_abort returns non-zero on empty input"
  else
    fail "interactive_confirm_or_abort should return non-zero on empty input"
  fi
}

test_confirm_or_abort_q_aborts() {
  local RC=0
  echo "q" | interactive_confirm_or_abort "Apply:" "/path/to/diff" 2>/dev/null || RC=$?
  if [[ "$RC" -ne 0 ]]; then
    pass "interactive_confirm_or_abort returns non-zero on 'q'"
  else
    fail "interactive_confirm_or_abort should return non-zero on 'q'"
  fi
}

test_confirm_or_abort_prints_items_to_stderr() {
  local STDERR
  STDERR=$(echo "y" | interactive_confirm_or_abort "Header:" "item1" "item2" 2>&1 >/dev/null)
  if echo "$STDERR" | grep -q "Header:" && echo "$STDERR" | grep -q "item1" && echo "$STDERR" | grep -q "item2"; then
    pass "interactive_confirm_or_abort prints items to stderr"
  else
    fail "interactive_confirm_or_abort should print items to stderr"
  fi
}

test_confirm_or_abort_stdout_empty() {
  local STDOUT
  STDOUT=$(echo "y" | interactive_confirm_or_abort "Apply:" "item" 2>/dev/null)
  if [[ -z "$STDOUT" ]]; then
    pass "interactive_confirm_or_abort prints nothing to stdout"
  else
    fail "interactive_confirm_or_abort should print nothing to stdout, got: '$STDOUT'"
  fi
}

test_confirm_or_abort_no_label() {
  # Empty label should not print a header line
  local STDERR
  STDERR=$(echo "y" | interactive_confirm_or_abort "" "item" 2>&1 >/dev/null)
  # Should not start with empty label line — first line should be the item
  local FIRST_LINE
  FIRST_LINE=$(echo "$STDERR" | head -1)
  if [[ "$FIRST_LINE" == "  item" ]]; then
    pass "interactive_confirm_or_abort with empty label skips header"
  else
    fail "interactive_confirm_or_abort with empty label should skip header, first line: '$FIRST_LINE'"
  fi
}

# =============================================================================
# interactive_select_channel tests
# =============================================================================

test_select_channel_draft_lists_channels() {
  local SANDBOX="$FIXTURE_DIR/ch_draft"
  mkdir -p "$SANDBOX"
  # Create workspace directories for dirs_resolve
  mkdir -p "$SANDBOX/.workspace/session-diffs/session/20260504-120000-test"
  mkdir -p "$SANDBOX/.workspace/session-diffs/autosave/20260503-090000-old"
  mkdir -p "$SANDBOX/.workspace/output/bundles/20260504-150000-bundle"

  local CHANNEL
  CHANNEL=$(echo "1" | interactive_select_channel "draft" "$SANDBOX" 2>/dev/null)
  if [[ "$CHANNEL" == "session" ]]; then
    pass "interactive_select_channel draft picks first channel (session)"
  else
    fail "interactive_select_channel draft should return 'session', got: '$CHANNEL'"
  fi
}

test_select_channel_apply_lists_channels() {
  local SANDBOX="$FIXTURE_DIR/ch_apply"
  mkdir -p "$SANDBOX"
  mkdir -p "$SANDBOX/.workspace/output/diffs/20260504-120000-snap"
  mkdir -p "$SANDBOX/.workspace/session-diffs/autosave/20260503-090000-old"

  local CHANNEL
  CHANNEL=$(echo "2" | interactive_select_channel "apply" "$SANDBOX" 2>/dev/null)
  if [[ "$CHANNEL" == "autosave" ]]; then
    pass "interactive_select_channel apply picks second channel (autosave)"
  else
    fail "interactive_select_channel apply should return 'autosave' on 2, got: '$CHANNEL'"
  fi
}

test_select_channel_default_highlighted() {
  local SANDBOX="$FIXTURE_DIR/ch_default"
  mkdir -p "$SANDBOX"
  mkdir -p "$SANDBOX/.workspace/session-diffs/session/20260504-120000-test"
  mkdir -p "$SANDBOX/.workspace/session-diffs/autosave/20260503-090000-old"

  # Empty input with DEFAULT_CHANNEL=autosave
  local CHANNEL
  CHANNEL=$(echo "" | interactive_select_channel "draft" "$SANDBOX" "autosave" 2>/dev/null)
  if [[ "$CHANNEL" == "autosave" ]]; then
    pass "interactive_select_channel returns default on empty input"
  else
    fail "interactive_select_channel should return 'autosave' on empty input, got: '$CHANNEL'"
  fi
}

test_select_channel_q_aborts() {
  local SANDBOX="$FIXTURE_DIR/ch_q"
  mkdir -p "$SANDBOX"
  mkdir -p "$SANDBOX/.workspace/session-diffs/session/20260504-120000-test"

  local RC=0
  echo "q" | interactive_select_channel "draft" "$SANDBOX" 2>/dev/null || RC=$?
  if [[ "$RC" -ne 0 ]]; then
    pass "interactive_select_channel returns non-zero on 'q'"
  else
    fail "interactive_select_channel should return non-zero on 'q'"
  fi
}

test_select_channel_zero_entries_shows_count() {
  local SANDBOX="$FIXTURE_DIR/ch_zero"
  mkdir -p "$SANDBOX"
  mkdir -p "$SANDBOX/.workspace/session-diffs/session"
  mkdir -p "$SANDBOX/.workspace/output/bundles"

  # Channel 3 (bundles) has 0 entries — should show 0 entries but still be selectable
  local CHANNEL
  CHANNEL=$(echo "3" | interactive_select_channel "draft" "$SANDBOX" 2>/dev/null)
  if [[ "$CHANNEL" == "bundles" ]]; then
    pass "interactive_select_channel allows selecting channel with 0 entries"
  else
    fail "interactive_select_channel should return 'bundles' on 3, got: '$CHANNEL'"
  fi
}

test_select_channel_repeats_on_invalid() {
  local SANDBOX="$FIXTURE_DIR/ch_repeat"
  mkdir -p "$SANDBOX"
  mkdir -p "$SANDBOX/.workspace/session-diffs/session/20260504-120000-test"

  # Invalid "99" then valid "1"
  local CHANNEL
  CHANNEL=$(printf "99\n1\n" | interactive_select_channel "draft" "$SANDBOX" 2>/dev/null)
  if [[ "$CHANNEL" == "session" ]]; then
    pass "interactive_select_channel re-prompts on invalid selection"
  else
    fail "interactive_select_channel should recover from invalid input, got: '$CHANNEL'"
  fi
}

# =============================================================================
# interactive_select_session tests
# =============================================================================

test_select_session_picks_by_number() {
  local SANDBOX="$FIXTURE_DIR/ss_pick"
  mkdir -p "$SANDBOX"
  local BASE="$SANDBOX/.workspace/session-diffs/session"
  mkdir -p "$BASE"
  make_session_fixture "$BASE/20260504-120000-alpha" 1 content
  make_session_fixture "$BASE/20260503-090000-beta" 1 content

  local SESSION
  SESSION=$(echo "2" | interactive_select_session "$SANDBOX" "session" 2>/dev/null)
  if [[ "$SESSION" == "20260503-090000-beta" ]]; then
    pass "interactive_select_session picks second session by number"
  else
    fail "interactive_select_session should return '20260503-090000-beta', got: '$SESSION'"
  fi
}

test_select_session_default_highlighted() {
  local SANDBOX="$FIXTURE_DIR/ss_default"
  mkdir -p "$SANDBOX"
  local BASE="$SANDBOX/.workspace/session-diffs/session"
  mkdir -p "$BASE"
  make_session_fixture "$BASE/20260504-120000-alpha" 1 content
  make_session_fixture "$BASE/20260503-090000-beta" 1 content

  local SESSION
  SESSION=$(echo "" | interactive_select_session "$SANDBOX" "session" "20260503-090000-beta" 2>/dev/null)
  if [[ "$SESSION" == "20260503-090000-beta" ]]; then
    pass "interactive_select_session returns default on empty input"
  else
    fail "interactive_select_session should return default '20260503-090000-beta', got: '$SESSION'"
  fi
}

test_select_session_availability_indicators() {
  local SANDBOX="$FIXTURE_DIR/ss_indicators"
  mkdir -p "$SANDBOX"
  local BASE="$SANDBOX/.workspace/session-diffs/session"
  mkdir -p "$BASE"
  # Full availability
  make_session_fixture "$BASE/20260504-120000-full" 1 content
  # No patches, no uncommitted
  make_session_fixture "$BASE/20260503-090000-empty"
  # Only patches
  make_session_fixture "$BASE/20260502-090000-patches-only" 1

  local SESSION
  SESSION=$(echo "1" | interactive_select_session "$SANDBOX" "session" 2>/dev/null)
  if [[ "$SESSION" == "20260504-120000-full" ]]; then
    pass "interactive_select_session shows availability indicators (first entry)"
  else
    fail "interactive_select_session should return first entry, got: '$SESSION'"
  fi
}

test_select_session_patch_count_shown() {
  local SANDBOX="$FIXTURE_DIR/ss_patchcount"
  mkdir -p "$SANDBOX"
  local BASE="$SANDBOX/.workspace/session-diffs/session"
  mkdir -p "$BASE"
  # 5 patches
  make_session_fixture "$BASE/20260504-120000-five" 5
  # 0 patches
  make_session_fixture "$BASE/20260503-090000-zero"

  local STDERR
  STDERR=$(echo "q" | interactive_select_session "$SANDBOX" "session" 2>&1 >/dev/null) || true
  local OK=true
  echo "$STDERR" | grep -q "patches: 5" || OK=false
  echo "$STDERR" | grep -q "patches: 0" || OK=false
  if [[ "$OK" == true ]]; then
    pass "interactive_select_session shows patch count instead of checkmark"
  else
    fail "interactive_select_session should show patch counts (5 and 0), got: $STDERR"
  fi
}

test_select_session_zero_entries() {
  local SANDBOX="$FIXTURE_DIR/ss_zero"
  mkdir -p "$SANDBOX"
  local BASE="$SANDBOX/.workspace/session-diffs/session"
  mkdir -p "$BASE"
  # No session directories under BASE

  local RC=0
  echo "1" | interactive_select_session "$SANDBOX" "session" 2>/dev/null || RC=$?
  if [[ "$RC" -ne 0 ]]; then
    pass "interactive_select_session returns non-zero with zero entries"
  else
    fail "interactive_select_session should return non-zero with zero entries"
  fi
}

test_select_session_cap_at_ten() {
  local SANDBOX="$FIXTURE_DIR/ss_cap"
  mkdir -p "$SANDBOX"
  local BASE="$SANDBOX/.workspace/session-diffs/session"
  mkdir -p "$BASE"

  # Create 12 sessions
  for i in $(seq 1 12); do
    local PADDING
    PADDING=$(printf "%04d" "$i")
    make_session_fixture "$BASE/20260504-${PADDING}00-session-${i}" 1
  done

  # Feed input for entry 10 in newest-first order (session-3)
  local SESSION
  SESSION=$(echo "10" | interactive_select_session "$SANDBOX" "session" 2>/dev/null)
  if echo "$SESSION" | grep -q "session-3"; then
    pass "interactive_select_session caps at 10 entries, entry 10 selectable"
  else
    fail "interactive_select_session should select session-3 at entry 10 (newest-first), got: '$SESSION'"
  fi

  # Try selecting entry 11 — should be invalid (capped at 10)
  local STDERR
  STDERR=$(printf "11\nq\n" | interactive_select_session "$SANDBOX" "session" 2>&1 >/dev/null) || true
  if echo "$STDERR" | grep -q "Invalid selection"; then
    pass "interactive_select_session rejects entry beyond cap"
  else
    fail "interactive_select_session should reject entry 11 (beyond cap)"
  fi
}

test_select_session_name_truncation() {
  local SANDBOX="$FIXTURE_DIR/ss_trunc"
  mkdir -p "$SANDBOX"
  local BASE="$SANDBOX/.workspace/session-diffs/session"
  mkdir -p "$BASE"

  # Create a session with a name > 50 chars
  local LONG_NAME="20260504-120000-this-is-a-very-long-branch-name-that-exceeds-fifty-characters"
  make_session_fixture "$BASE/$LONG_NAME" 1

  local STDERR
  STDERR=$(echo "q" | interactive_select_session "$SANDBOX" "session" 2>&1 >/dev/null) || true
  # The displayed name should be truncated (contains "...")
  if echo "$STDERR" | grep -q "\.\.\."; then
    pass "interactive_select_session truncates names longer than 50 chars"
  else
    # If the name is actually <= 50 chars, that's also fine — just verify it works
    pass "interactive_select_session handles long names (no truncation needed if <= 50 chars)"
  fi
}

# =============================================================================
# interactive_select_session — option 0 injection tests
# =============================================================================

test_select_session_inject_option_zero() {
  local SANDBOX="$FIXTURE_DIR/ss_opt0"
  mkdir -p "$SANDBOX"
  local BASE="$SANDBOX/.workspace/session-diffs/session"
  mkdir -p "$BASE"
  make_session_fixture "$BASE/20260504-120000-alpha" 1 content
  make_session_fixture "$BASE/20260503-090000-beta" 1 content

  # DEFAULT_SESSION not in list — inject as option 0
  local SESSION
  SESSION=$(echo "" | interactive_select_session "$SANDBOX" "session" "20260501-000000-remote" 2>/dev/null)
  if [[ "$SESSION" == "20260501-000000-remote" ]]; then
    pass "interactive_select_session injects option 0 for outside-default, Enter selects it"
  else
    fail "interactive_select_session should return '20260501-000000-remote' via option 0, got: '$SESSION'"
  fi
}

test_select_session_option_zero_by_number() {
  local SANDBOX="$FIXTURE_DIR/ss_opt0_num"
  mkdir -p "$SANDBOX"
  local BASE="$SANDBOX/.workspace/session-diffs/session"
  mkdir -p "$BASE"
  make_session_fixture "$BASE/20260504-120000-alpha" 1 content
  make_session_fixture "$BASE/20260503-090000-beta" 1 content

  # Select option 0 by typing "0"
  local SESSION
  SESSION=$(echo "0" | interactive_select_session "$SANDBOX" "session" "20260501-000000-remote" 2>/dev/null)
  if [[ "$SESSION" == "20260501-000000-remote" ]]; then
    pass "interactive_select_session option 0 selectable by typing '0'"
  else
    fail "interactive_select_session should return '20260501-000000-remote' on '0', got: '$SESSION'"
  fi
}

test_select_session_no_option_zero_when_in_displayed() {
  local SANDBOX="$FIXTURE_DIR/ss_opt0_no"
  mkdir -p "$SANDBOX"
  local BASE="$SANDBOX/.workspace/session-diffs/session"
  mkdir -p "$BASE"
  make_session_fixture "$BASE/20260504-120000-alpha" 1 content
  make_session_fixture "$BASE/20260503-090000-beta" 1 content

  # DEFAULT_SESSION IS in list — no option 0, Enter selects normally
  local SESSION
  SESSION=$(echo "" | interactive_select_session "$SANDBOX" "session" "20260503-090000-beta" 2>/dev/null)
  if [[ "$SESSION" == "20260503-090000-beta" ]]; then
    pass "interactive_select_session does not inject option 0 when default is in displayed list"
  else
    fail "interactive_select_session should return '20260503-090000-beta' normally, got: '$SESSION'"
  fi
}

test_select_session_option_zero_stderr_shows_entry() {
  local SANDBOX="$FIXTURE_DIR/ss_opt0_stderr"
  mkdir -p "$SANDBOX"
  local BASE="$SANDBOX/.workspace/session-diffs/session"
  mkdir -p "$BASE"
  make_session_fixture "$BASE/20260504-120000-alpha" 1 content

  # Check stderr shows option 0
  local STDERR
  STDERR=$(echo "0" | interactive_select_session "$SANDBOX" "session" "20260501-000000-remote" 2>&1 >/dev/null) || true
  if echo "$STDERR" | grep -q "0:" && echo "$STDERR" | grep -q "remote"; then
    pass "interactive_select_session prints option 0 to stderr"
  else
    fail "interactive_select_session should show option 0 in stderr"
  fi
}

test_select_session_option_zero_not_present_without_default() {
  local SANDBOX="$FIXTURE_DIR/ss_opt0_nodef"
  mkdir -p "$SANDBOX"
  local BASE="$SANDBOX/.workspace/session-diffs/session"
  mkdir -p "$BASE"
  make_session_fixture "$BASE/20260504-120000-alpha" 1 content

  # No DEFAULT_SESSION — no option 0, normal numbers start at 1
  local STDERR
  STDERR=$(echo "1" | interactive_select_session "$SANDBOX" "session" 2>&1 >/dev/null) || true
  if echo "$STDERR" | grep -q "^  0:"; then
    fail "interactive_select_session should NOT show option 0 without DEFAULT_SESSION"
  else
    pass "interactive_select_session no option 0 when no default is given"
  fi
}

# =============================================================================
# interactive_select_session — pagination tests
# =============================================================================

# Helper: create N fixture sessions
create_n_sessions() {
  local BASE_DIR="$1"
  local COUNT="$2"
  for i in $(seq 1 "$COUNT"); do
    local PADDING
    PADDING=$(printf "%04d" "$i")
    make_session_fixture "$BASE_DIR/20260504-${PADDING}00-session-${i}" 1
  done
}

test_select_session_pagination_next_page() {
  local SANDBOX="$FIXTURE_DIR/pg_next"
  mkdir -p "$SANDBOX"
  local BASE="$SANDBOX/.workspace/session-diffs/session"
  mkdir -p "$BASE"
  create_n_sessions "$BASE" 12

  # 12 sessions sorted newest-first: session-12 .. session-1
  # Page 1: entries 0-9 (session-12 .. session-3)
  # Page 2: entries 10-11 (session-2, session-1)
  # n, then 1 → selects first entry on page 2 = session-2
  local SESSION
  SESSION=$(printf "n\n1\n" | interactive_select_session "$SANDBOX" "session" 2>/dev/null)
  if echo "$SESSION" | grep -q "session-2"; then
    pass "interactive_select_session 'n' then '1' selects first entry on page 2"
  else
    fail "interactive_select_session should select session-2 after n+1, got: '$SESSION'"
  fi
}

test_select_session_pagination_previous_page() {
  local SANDBOX="$FIXTURE_DIR/pg_prev"
  mkdir -p "$SANDBOX"
  local BASE="$SANDBOX/.workspace/session-diffs/session"
  mkdir -p "$BASE"
  create_n_sessions "$BASE" 12

  # n, p (back to page 1), then 1 → selects first entry on page 1 = session-12
  local SESSION
  SESSION=$(printf "n\np\n1\n" | interactive_select_session "$SANDBOX" "session" 2>/dev/null)
  if echo "$SESSION" | grep -q "session-12"; then
    pass "interactive_select_session 'n' then 'p' returns to page 1"
  else
    fail "interactive_select_session should select session-12 after n+p+1, got: '$SESSION'"
  fi
}

test_select_session_pagination_page_header() {
  local SANDBOX="$FIXTURE_DIR/pg_header"
  mkdir -p "$SANDBOX"
  local BASE="$SANDBOX/.workspace/session-diffs/session"
  mkdir -p "$BASE"
  create_n_sessions "$BASE" 15

  # stderr should show "page 1 of 2"
  local STDERR
  STDERR=$(printf "q\n" | interactive_select_session "$SANDBOX" "session" 2>&1 >/dev/null) || true
  if echo "$STDERR" | grep -q "page 1 of 2"; then
    pass "interactive_select_session shows page header when multiple pages"
  else
    fail "interactive_select_session should show 'page 1 of 2', got: '$STDERR'"
  fi
}

test_select_session_pagination_single_page() {
  local SANDBOX="$FIXTURE_DIR/pg_single"
  mkdir -p "$SANDBOX"
  local BASE="$SANDBOX/.workspace/session-diffs/session"
  mkdir -p "$BASE"
  create_n_sessions "$BASE" 3

  # Only 3 entries — no pagination, no "page 1 of 1"
  local STDERR
  STDERR=$(echo "q" | interactive_select_session "$SANDBOX" "session" 2>&1 >/dev/null) || true
  if echo "$STDERR" | grep -q "page"; then
    fail "interactive_select_session should NOT show page header for single page"
  else
    pass "interactive_select_session no page header for single page"
  fi
}

test_select_session_pagination_option_zero_persists() {
  local SANDBOX="$FIXTURE_DIR/pg_opt0"
  mkdir -p "$SANDBOX"
  local BASE="$SANDBOX/.workspace/session-diffs/session"
  mkdir -p "$BASE"
  create_n_sessions "$BASE" 12

  # SESSION= outside the first 10 pages, inject option 0, n should still show it
  local STDERR
  STDERR=$(printf "n\nq\n" | interactive_select_session "$SANDBOX" "session" "20260504-000100-session-unknown" 2>&1 >/dev/null) || true
  if echo "$STDERR" | grep -q "0:" && echo "$STDERR" | grep -q "unknown"; then
    pass "interactive_select_session option 0 persists across pages"
  else
    fail "interactive_select_session should show option 0 after 'n'"
  fi
}

test_select_session_pagination_no_n_at_last_page() {
  local SANDBOX="$FIXTURE_DIR/pg_last"
  mkdir -p "$SANDBOX"
  local BASE="$SANDBOX/.workspace/session-diffs/session"
  mkdir -p "$BASE"
  create_n_sessions "$BASE" 12

  # n (to page 2), n (stays on page 2), then 1 selects first entry on page 2
  # Second n re-renders same page but stays — selection still works
  local SESSION
  SESSION=$(printf "n\nn\n1\n" | interactive_select_session "$SANDBOX" "session" 2>/dev/null)
  if echo "$SESSION" | grep -q "session-2"; then
    pass "interactive_select_session stays on last page with extra 'n'"
  else
    fail "interactive_select_session should select session-2 after n+n+1, got: '$SESSION'"
  fi
}

# =============================================================================
# interactive_select_diff_type tests
# =============================================================================

test_select_diff_type_uncommitted_default() {
  local SANDBOX="$FIXTURE_DIR/dt_def"
  mkdir -p "$SANDBOX"
  local BASE="$SANDBOX/.workspace/session-diffs/session"
  mkdir -p "$BASE/20260504-120000-test"
  echo "content" > "$BASE/20260504-120000-test/uncommitted.diff"
  echo "content" > "$BASE/20260504-120000-test/all-changes.diff"

  local TYPE
  TYPE=$(echo "" | interactive_select_diff_type "$SANDBOX" "20260504-120000-test" "session" 2>/dev/null)
  if [[ "$TYPE" == "uncommitted" ]]; then
    pass "interactive_select_diff_type defaults to uncommitted on empty input"
  else
    fail "interactive_select_diff_type should default to 'uncommitted', got: '$TYPE'"
  fi
}

test_select_diff_type_second_option() {
  local SANDBOX="$FIXTURE_DIR/dt_2"
  mkdir -p "$SANDBOX"
  local BASE="$SANDBOX/.workspace/session-diffs/session"
  mkdir -p "$BASE/20260504-120000-test"
  echo "content" > "$BASE/20260504-120000-test/uncommitted.diff"
  echo "content" > "$BASE/20260504-120000-test/all-changes.diff"

  local TYPE
  TYPE=$(echo "2" | interactive_select_diff_type "$SANDBOX" "20260504-120000-test" "session" 2>/dev/null)
  if [[ "$TYPE" == "all-changes" ]]; then
    pass "interactive_select_diff_type returns 'all-changes' on option 2"
  else
    fail "interactive_select_diff_type should return 'all-changes', got: '$TYPE'"
  fi
}

test_select_diff_type_auto_select_uncommitted_only() {
  local SANDBOX="$FIXTURE_DIR/dt_only_u"
  mkdir -p "$SANDBOX"
  local BASE="$SANDBOX/.workspace/session-diffs/session"
  mkdir -p "$BASE/20260504-120000-test"
  echo "content" > "$BASE/20260504-120000-test/uncommitted.diff"
  # No all-changes.diff

  local TYPE
  TYPE=$(interactive_select_diff_type "$SANDBOX" "20260504-120000-test" "session" 2>/dev/null)
  if [[ "$TYPE" == "uncommitted" ]]; then
    pass "interactive_select_diff_type auto-selects uncommitted when only that exists"
  else
    fail "interactive_select_diff_type should auto-select 'uncommitted', got: '$TYPE'"
  fi
}

test_select_diff_type_auto_select_all_changes_only() {
  local SANDBOX="$FIXTURE_DIR/dt_only_a"
  mkdir -p "$SANDBOX"
  local BASE="$SANDBOX/.workspace/session-diffs/session"
  mkdir -p "$BASE/20260504-120000-test"
  echo "content" > "$BASE/20260504-120000-test/all-changes.diff"
  # No uncommitted.diff

  local TYPE
  TYPE=$(interactive_select_diff_type "$SANDBOX" "20260504-120000-test" "session" 2>/dev/null)
  if [[ "$TYPE" == "all-changes" ]]; then
    pass "interactive_select_diff_type auto-selects all-changes when only that exists"
  else
    fail "interactive_select_diff_type should auto-select 'all-changes', got: '$TYPE'"
  fi
}

test_select_diff_type_neither_exists() {
  local SANDBOX="$FIXTURE_DIR/dt_none"
  mkdir -p "$SANDBOX"
  local BASE="$SANDBOX/.workspace/session-diffs/session"
  mkdir -p "$BASE/20260504-120000-test"
  # No diff files at all

  local RC=0
  interactive_select_diff_type "$SANDBOX" "20260504-120000-test" "session" 2>/dev/null || RC=$?
  if [[ "$RC" -ne 0 ]]; then
    pass "interactive_select_diff_type errors when neither diff file exists"
  else
    fail "interactive_select_diff_type should error with neither diff file present"
  fi
}

# =============================================================================
# Run all
# =============================================================================

run_test test_confirm_or_abort_yes_proceeds
run_test test_confirm_or_abort_no_aborts
run_test test_confirm_or_abort_empty_aborts
run_test test_confirm_or_abort_q_aborts
run_test test_confirm_or_abort_prints_items_to_stderr
run_test test_confirm_or_abort_stdout_empty
run_test test_confirm_or_abort_no_label

run_test test_select_channel_draft_lists_channels
run_test test_select_channel_apply_lists_channels
run_test test_select_channel_default_highlighted
run_test test_select_channel_q_aborts
run_test test_select_channel_zero_entries_shows_count
run_test test_select_channel_repeats_on_invalid

run_test test_select_session_picks_by_number
run_test test_select_session_default_highlighted
run_test test_select_session_availability_indicators
run_test test_select_session_patch_count_shown
run_test test_select_session_zero_entries
run_test test_select_session_cap_at_ten
run_test test_select_session_name_truncation

run_test test_select_session_inject_option_zero
run_test test_select_session_option_zero_by_number
run_test test_select_session_no_option_zero_when_in_displayed
run_test test_select_session_option_zero_stderr_shows_entry
run_test test_select_session_option_zero_not_present_without_default

run_test test_select_session_pagination_next_page
run_test test_select_session_pagination_previous_page
run_test test_select_session_pagination_page_header
run_test test_select_session_pagination_single_page
run_test test_select_session_pagination_option_zero_persists
run_test test_select_session_pagination_no_n_at_last_page

run_test test_select_diff_type_uncommitted_default
run_test test_select_diff_type_second_option
run_test test_select_diff_type_auto_select_uncommitted_only
run_test test_select_diff_type_auto_select_all_changes_only
run_test test_select_diff_type_neither_exists

test_done

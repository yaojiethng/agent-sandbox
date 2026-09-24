#!/usr/bin/env bash
# tests/test_interactive_session_select.sh
# Tests for libs/interactive_session_select.sh
# Pins cite: docs/architecture/tool_interface.md l.132-135 (channel table);
#             devlog/discussions/design_apply_draft_workflow.md (channel directories).

#
# Covers:
#   interactive_confirm_or_abort    --  y/N prompt, return codes
#   interactive_select_channel      --  channel picker, entry counts
#   interactive_select_bundle      --  session picker, indicators, cap

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup
export AGENT_SANDBOX_REPO="$REPO_ROOT"
source "$REPO_ROOT/scripts/workflows/interactive.sh"
source "$TEST_DIR/libs/session_fixtures.sh"
source "$TEST_DIR/libs/git_fixtures.sh"

# =============================================================================
# interactive_confirm_or_abort tests
# =============================================================================

test_confirm_or_abort_yes_proceeds() {
  if echo "y" | interactive_confirm_or_abort "Apply:" "/path/to/diff" > /dev/null 2>&1; then
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
  assert_empty "$STDOUT" "interactive_confirm_or_abort prints nothing to stdout"
}

test_confirm_or_abort_no_label() {
  # Empty label should not print a header line
  local STDERR
  STDERR=$(echo "y" | interactive_confirm_or_abort "" "item" 2>&1 >/dev/null)
  # Should not start with empty label line  --  first line should be the item
  local FIRST_LINE
  FIRST_LINE=$(echo "$STDERR" | head -1)
  assert_eq "$FIRST_LINE" "  item" "interactive_confirm_or_abort with empty label skips header"
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
  assert_eq "$CHANNEL" "session" "interactive_select_channel draft picks first channel (session)"
}

test_select_channel_default_highlighted() {
  local SANDBOX="$FIXTURE_DIR/ch_default"
  mkdir -p "$SANDBOX"
  mkdir -p "$SANDBOX/.workspace/session-diffs/session/20260504-120000-test"
  mkdir -p "$SANDBOX/.workspace/session-diffs/autosave/20260503-090000-old"

  # Empty input with DEFAULT_CHANNEL=autosave
  local CHANNEL
  CHANNEL=$(echo "" | interactive_select_channel "draft" "$SANDBOX" "autosave" 2>/dev/null)
  assert_eq "$CHANNEL" "autosave" "interactive_select_channel returns default on empty input"
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

  # Channel 3 (bundles) has 0 entries  --  should show 0 entries but still be selectable
  local CHANNEL
  CHANNEL=$(echo "3" | interactive_select_channel "draft" "$SANDBOX" 2>/dev/null)
  assert_eq "$CHANNEL" "bundles" "interactive_select_channel allows selecting channel with 0 entries"
}

test_select_channel_repeats_on_invalid() {
  local SANDBOX="$FIXTURE_DIR/ch_repeat"
  mkdir -p "$SANDBOX"
  mkdir -p "$SANDBOX/.workspace/session-diffs/session/20260504-120000-test"

  # Invalid "99" then valid "1"
  local CHANNEL
  CHANNEL=$(printf "99\n1\n" | interactive_select_channel "draft" "$SANDBOX" 2>/dev/null)
  assert_eq "$CHANNEL" "session" "interactive_select_channel re-prompts on invalid selection"
}

# =============================================================================
# interactive_select_bundle tests
# =============================================================================

test_select_session_picks_by_number() {
  local SANDBOX="$FIXTURE_DIR/ss_pick"
  mkdir -p "$SANDBOX"
  local BASE="$SANDBOX/.workspace/session-diffs/session"
  mkdir -p "$BASE"
  make_session_fixture "$BASE/20260504-120000-alpha" 1 content
  make_session_fixture "$BASE/20260503-090000-beta" 1 content

  local BUNDLE
  BUNDLE=$(echo "2" | interactive_select_bundle "$SANDBOX" "session" 2>/dev/null)
  assert_eq "$BUNDLE" "20260503-090000-beta" "interactive_select_bundle picks second session by number"
}

test_select_session_default_highlighted() {
  local SANDBOX="$FIXTURE_DIR/ss_default"
  mkdir -p "$SANDBOX"
  local BASE="$SANDBOX/.workspace/session-diffs/session"
  mkdir -p "$BASE"
  make_session_fixture "$BASE/20260504-120000-alpha" 1 content
  make_session_fixture "$BASE/20260503-090000-beta" 1 content

  local BUNDLE
  BUNDLE=$(echo "" | interactive_select_bundle "$SANDBOX" "session" "20260503-090000-beta" 2>/dev/null)
  assert_eq "$BUNDLE" "20260503-090000-beta" "interactive_select_bundle returns default on empty input"
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

  local BUNDLE
  BUNDLE=$(echo "1" | interactive_select_bundle "$SANDBOX" "session" 2>/dev/null)
  assert_eq "$BUNDLE" "20260504-120000-full" "interactive_select_bundle shows availability indicators (first entry)"
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
  STDERR=$(echo "q" | interactive_select_bundle "$SANDBOX" "session" 2>&1 >/dev/null) || true
  local OK=true
  # The bundle table shows the patch count as a PATCHES column value;
  # anchor the count to the row's trailing UNCOMMITTED cell ([ ]) so the
  # digit in the STATE cell (e.g. "5M ago") cannot match.
  echo "$STDERR" | grep -qE -- "-five.*[[:space:]]5[[:space:]]+\\[" || OK=false
  echo "$STDERR" | grep -qE -- "-zero.*[[:space:]]0[[:space:]]+\\[" || OK=false
  if [[ "$OK" == true ]]; then
    pass "interactive_select_bundle shows patch count instead of checkmark"
  else
    fail "interactive_select_bundle should show patch counts (5 and 0), got: $STDERR"
  fi
}

test_select_session_zero_entries() {
  local SANDBOX="$FIXTURE_DIR/ss_zero"
  mkdir -p "$SANDBOX"
  local BASE="$SANDBOX/.workspace/session-diffs/session"
  mkdir -p "$BASE"
  # No session directories under BASE

  local RC=0
  echo "1" | interactive_select_bundle "$SANDBOX" "session" 2>/dev/null || RC=$?
  if [[ "$RC" -ne 0 ]]; then
    pass "interactive_select_bundle returns non-zero with zero entries"
  else
    fail "interactive_select_bundle should return non-zero with zero entries"
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
  local BUNDLE
  BUNDLE=$(echo "10" | interactive_select_bundle "$SANDBOX" "session" 2>/dev/null)
  if echo "$BUNDLE" | grep -q "session-3"; then
    pass "interactive_select_bundle caps at 10 entries, entry 10 selectable"
  else
    fail "interactive_select_bundle should select session-3 at entry 10 (newest-first), got: '$BUNDLE'"
  fi

  # Try selecting entry 11  --  should be invalid (capped at 10)
  local STDERR
  STDERR=$(printf "11\nq\n" | interactive_select_bundle "$SANDBOX" "session" 2>&1 >/dev/null) || true
  if echo "$STDERR" | grep -q "Invalid selection"; then
    pass "interactive_select_bundle rejects entry beyond cap"
  else
    fail "interactive_select_bundle should reject entry 11 (beyond cap)"
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
  STDERR=$(echo "q" | interactive_select_bundle "$SANDBOX" "session" 2>&1 >/dev/null) || true
  # The displayed name should be truncated (contains "...")
  # The fixture name exceeds 50 chars, so truncation must happen: a missing
  # "..." is a regression, not an acceptable alternative.
  if echo "$STDERR" | grep -q "\.\.\."; then
    pass "interactive_select_bundle truncates names longer than 50 chars"
  else
    fail "expected truncated name with '...', got: $STDERR"
  fi
}

# =============================================================================
# interactive_select_bundle  --  option 0 injection tests
# =============================================================================

test_select_session_inject_option_zero() {
  local SANDBOX="$FIXTURE_DIR/ss_opt0"
  mkdir -p "$SANDBOX"
  local BASE="$SANDBOX/.workspace/session-diffs/session"
  mkdir -p "$BASE"
  make_session_fixture "$BASE/20260504-120000-alpha" 1 content
  make_session_fixture "$BASE/20260503-090000-beta" 1 content

  # DEFAULT_BUNDLE not in list  --  inject as option 0
  local BUNDLE
  BUNDLE=$(echo "" | interactive_select_bundle "$SANDBOX" "session" "20260501-000000-remote" 2>/dev/null)
  assert_eq "$BUNDLE" "20260501-000000-remote" "interactive_select_bundle injects option 0 for outside-default, Enter selects it"
}

test_select_session_option_zero_by_number() {
  local SANDBOX="$FIXTURE_DIR/ss_opt0_num"
  mkdir -p "$SANDBOX"
  local BASE="$SANDBOX/.workspace/session-diffs/session"
  mkdir -p "$BASE"
  make_session_fixture "$BASE/20260504-120000-alpha" 1 content
  make_session_fixture "$BASE/20260503-090000-beta" 1 content

  # Select option 0 by typing "0"
  local BUNDLE
  BUNDLE=$(echo "0" | interactive_select_bundle "$SANDBOX" "session" "20260501-000000-remote" 2>/dev/null)
  assert_eq "$BUNDLE" "20260501-000000-remote" "interactive_select_bundle option 0 selectable by typing '0'"
}

test_select_session_no_option_zero_when_in_displayed() {
  local SANDBOX="$FIXTURE_DIR/ss_opt0_no"
  mkdir -p "$SANDBOX"
  local BASE="$SANDBOX/.workspace/session-diffs/session"
  mkdir -p "$BASE"
  make_session_fixture "$BASE/20260504-120000-alpha" 1 content
  make_session_fixture "$BASE/20260503-090000-beta" 1 content

  # DEFAULT_BUNDLE IS in list  --  no option 0, Enter selects normally
  local BUNDLE
  BUNDLE=$(echo "" | interactive_select_bundle "$SANDBOX" "session" "20260503-090000-beta" 2>/dev/null)
  assert_eq "$BUNDLE" "20260503-090000-beta" "interactive_select_bundle does not inject option 0 when default is in displayed list"
}

test_select_session_option_zero_stderr_shows_entry() {
  local SANDBOX="$FIXTURE_DIR/ss_opt0_stderr"
  mkdir -p "$SANDBOX"
  local BASE="$SANDBOX/.workspace/session-diffs/session"
  mkdir -p "$BASE"
  make_session_fixture "$BASE/20260504-120000-alpha" 1 content

  # Check stderr shows option 0
  local STDERR
  STDERR=$(echo "0" | interactive_select_bundle "$SANDBOX" "session" "20260501-000000-remote" 2>&1 >/dev/null) || true
  if echo "$STDERR" | grep -q "0:" && echo "$STDERR" | grep -q "remote"; then
    pass "interactive_select_bundle prints option 0 to stderr"
  else
    fail "interactive_select_bundle should show option 0 in stderr"
  fi
}

test_select_session_option_zero_not_present_without_default() {
  local SANDBOX="$FIXTURE_DIR/ss_opt0_nodef"
  mkdir -p "$SANDBOX"
  local BASE="$SANDBOX/.workspace/session-diffs/session"
  mkdir -p "$BASE"
  make_session_fixture "$BASE/20260504-120000-alpha" 1 content

  # No DEFAULT_BUNDLE  --  no option 0, normal numbers start at 1
  local STDERR
  STDERR=$(echo "1" | interactive_select_bundle "$SANDBOX" "session" 2>&1 >/dev/null) || true
  if echo "$STDERR" | grep -q "^  0:"; then
    fail "interactive_select_bundle should NOT show option 0 without DEFAULT_BUNDLE"
  else
    pass "interactive_select_bundle no option 0 when no default is given"
  fi
}

# =============================================================================
# interactive_select_bundle  --  pagination tests
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
  # n, then 1 -> selects first entry on page 2 = session-2
  local BUNDLE
  BUNDLE=$(printf "n\n1\n" | interactive_select_bundle "$SANDBOX" "session" 2>/dev/null)
  if echo "$BUNDLE" | grep -q "session-2"; then
    pass "interactive_select_bundle 'n' then '1' selects first entry on page 2"
  else
    fail "interactive_select_bundle should select session-2 after n+1, got: '$BUNDLE'"
  fi
}

test_select_session_pagination_previous_page() {
  local SANDBOX="$FIXTURE_DIR/pg_prev"
  mkdir -p "$SANDBOX"
  local BASE="$SANDBOX/.workspace/session-diffs/session"
  mkdir -p "$BASE"
  create_n_sessions "$BASE" 12

  # n, p (back to page 1), then 1 -> selects first entry on page 1 = session-12
  local BUNDLE
  BUNDLE=$(printf "n\np\n1\n" | interactive_select_bundle "$SANDBOX" "session" 2>/dev/null)
  if echo "$BUNDLE" | grep -q "session-12"; then
    pass "interactive_select_bundle 'n' then 'p' returns to page 1"
  else
    fail "interactive_select_bundle should select session-12 after n+p+1, got: '$BUNDLE'"
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
  STDERR=$(printf "q\n" | interactive_select_bundle "$SANDBOX" "session" 2>&1 >/dev/null) || true
  if echo "$STDERR" | grep -q "page 1 of 2"; then
    pass "interactive_select_bundle shows page header when multiple pages"
  else
    fail "interactive_select_bundle should show 'page 1 of 2', got: '$STDERR'"
  fi
}

test_select_session_pagination_single_page() {
  local SANDBOX="$FIXTURE_DIR/pg_single"
  mkdir -p "$SANDBOX"
  local BASE="$SANDBOX/.workspace/session-diffs/session"
  mkdir -p "$BASE"
  create_n_sessions "$BASE" 3

  # Only 3 entries  --  no pagination, no "page 1 of 1"
  local STDERR
  STDERR=$(echo "q" | interactive_select_bundle "$SANDBOX" "session" 2>&1 >/dev/null) || true
  if echo "$STDERR" | grep -q "page"; then
    fail "interactive_select_bundle should NOT show page header for single page"
  else
    pass "interactive_select_bundle no page header for single page"
  fi
}

test_select_session_pagination_option_zero_persists() {
  local SANDBOX="$FIXTURE_DIR/pg_opt0"
  mkdir -p "$SANDBOX"
  local BASE="$SANDBOX/.workspace/session-diffs/session"
  mkdir -p "$BASE"
  create_n_sessions "$BASE" 12

  # BUNDLE= outside the first 10 pages, inject option 0, n should still show it
  local STDERR
  STDERR=$(printf "n\nq\n" | interactive_select_bundle "$SANDBOX" "session" "20260504-000100-session-unknown" 2>&1 >/dev/null) || true
  if echo "$STDERR" | grep -q "0:" && echo "$STDERR" | grep -q "unknown"; then
    pass "interactive_select_bundle option 0 persists across pages"
  else
    fail "interactive_select_bundle should show option 0 after 'n'"
  fi
}

test_select_session_pagination_no_n_at_last_page() {
  local SANDBOX="$FIXTURE_DIR/pg_last"
  mkdir -p "$SANDBOX"
  local BASE="$SANDBOX/.workspace/session-diffs/session"
  mkdir -p "$BASE"
  create_n_sessions "$BASE" 12

  # n (to page 2), n (stays on page 2), then 1 selects first entry on page 2
  # Second n re-renders same page but stays  --  selection still works
  local BUNDLE
  BUNDLE=$(printf "n\nn\n1\n" | interactive_select_bundle "$SANDBOX" "session" 2>/dev/null)
  if echo "$BUNDLE" | grep -q "session-2"; then
    pass "interactive_select_bundle stays on last page with extra 'n'"
  else
    fail "interactive_select_bundle should select session-2 after n+n+1, got: '$BUNDLE'"
  fi
}


# =============================================================================
# interactive_select_bundle  --  STATE / AGE columns + current-branch hint
# =============================================================================

test_select_session_state_and_age_columns() {
  local SANDBOX="$FIXTURE_DIR/ss_stateage"
  mkdir -p "$SANDBOX"
  local BASE="$SANDBOX/.workspace/session-diffs/session"
  mkdir -p "$BASE"
  make_session_fixture "$BASE/20260504-120000-alpha" 1

  # Without a PROJECT_DIR git repo the AGE cell is "not in tree"; the header
  # carries the new BUNDLE/STATE/AGE/... column titles.
  local STDERR
  STDERR=$(echo "q" | interactive_select_bundle "$SANDBOX" "session" 2>&1 >/dev/null) || true
  local OK=true
  echo "$STDERR" | grep -q "STATE" || OK=false
  echo "$STDERR" | grep -q "AGE" || OK=false
  echo "$STDERR" | grep -q "not in tree" || OK=false
  if [[ "$OK" == true ]]; then
    pass "interactive_select_bundle renders STATE/AGE columns"
  else
    fail "interactive_select_bundle should show STATE/AGE columns, got: $STDERR"
  fi
}

test_select_session_current_branch_hint() {
  local SANDBOX="$FIXTURE_DIR/ss_branchhint"
  mkdir -p "$SANDBOX"
  local BASE="$SANDBOX/.workspace/session-diffs/session"
  mkdir -p "$BASE"
  make_session_fixture "$BASE/20260504-120000-alpha" 1

  local PROJ="$FIXTURE_DIR/ss_branchhint_proj"
  make_committed_repo "$PROJ"
  git -C "$PROJ" checkout -q -b feat/bundle-hint
  # PROJECT_DIR is read by interactive_select_bundle in the sourced
  # interactive.sh; ShellCheck cannot trace the cross-source read.
  # shellcheck disable=SC2034
  PROJECT_DIR="$PROJ"

  local STDERR
  STDERR=$(echo "q" | interactive_select_bundle "$SANDBOX" "session" 2>&1 >/dev/null) || true
  if echo "$STDERR" | grep -qE "current branch: feat/bundle-hint"; then
    pass "interactive_select_bundle prints the current project branch"
  else
    fail "interactive_select_bundle should show the current branch, got: $STDERR"
  fi
  unset PROJECT_DIR
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
run_test test_select_session_state_and_age_columns
run_test test_select_session_current_branch_hint

test_done


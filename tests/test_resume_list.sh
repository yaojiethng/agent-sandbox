#!/usr/bin/env bash
# tests/test_resume_list.sh
# Unit tests for src/libs/resume_list.sh  --  the resumable-session inventory and
# the table the resume command renders: the enumeration, the empty-inventory
# guidance, the work and state maps, the row cell, and both render modes.
#
# The library sources session_inventory.sh and reaches every field on disk, so
# the fixtures here are a registry directory of records, a committed project, the
# session log, and (for live state) a docker stub on PATH.

# The units assign SANDBOX_DIR, RESUME_INVENTORY, _STATE_MAP and _WORK_MAP as the
# library under test reads them; shellcheck cannot see the cross-file reads.
# shellcheck disable=SC2034
set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/git_fixtures.sh"

source "$REPO_ROOT/src/libs/resume_list.sh"

# make_record FILE AGENT_IMG SANDBOX_IMG [extra label lines...]
make_record() {
  local f="$1" agent="$2" sandbox="$3"; shift 3
  {
    echo "services:"
    echo "  sandbox:"
    echo "    image: $sandbox"
    echo "  agent:"
    echo "    image: $agent"
    local l
    for l in "$@"; do echo "    agent-sandbox.$l"; done
  } > "$f"
}

# A docker stub that prints the map lines _resume_state_map reads:
# `<session-id> <state>` per line.
make_docker_stub() {
  local dir="$1"
  mkdir -p "$dir"
  cat > "$dir/docker" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "${DOCKER_STUB_PS_LINES:-}"
STUB
  chmod +x "$dir/docker"
}

# =============================================================================
# _resume_truncate_branch
# =============================================================================

# Given: branch names shorter than and equal to the row limit
# When:  _resume_truncate_branch runs
# Then:  each is returned unchanged
# Asserts: no truncation below or at the width.
test_truncate_branch_leaves_short_names_whole() {
  local short="main" exact="feature/42-"   # 11 chars: the limit
  if [[ "$(_resume_truncate_branch "$short")" == "$short" \
     && "$(_resume_truncate_branch "$exact")" == "$exact" ]]; then
    pass "_resume_truncate_branch leaves names at or under the limit whole"
  else
    fail "short-name handling: '${short}'->'$(_resume_truncate_branch "$short")' '${exact}'->'$(_resume_truncate_branch "$exact")'"
  fi
}

# Given: a branch name longer than the limit
# When:  _resume_truncate_branch runs
# Then:  it keeps the first 11 characters and appends an ellipsis
# Asserts: the row width the paged table depends on.
test_truncate_branch_cuts_long_names_to_the_limit() {
  local long="feature/42-render-the-resume-table"
  local got
  got="$(_resume_truncate_branch "$long")"
  if [[ "$got" == "feature/42-..." ]]; then
    pass "_resume_truncate_branch truncates to 11 characters plus an ellipsis"
  else
    fail "long-name handling: got '$got' (length ${#got})"
  fi
}

# =============================================================================
# _no_sessions
# =============================================================================

# Given: a provider filter with no matching session
# When:  _no_sessions runs
# Then:  it names that provider on stderr and returns 1
# Asserts: the filtered empty-inventory message.
test_no_sessions_names_the_provider_filter() {
  local out rc=0
  out="$(PROVIDER_FILTER="hermes" SANDBOX_DIR="$FIXTURE_DIR/nosbx" _no_sessions 2>&1)" || rc=$?
  if [[ $rc -eq 1 && "$out" == *"no resumable sessions for provider 'hermes'"* ]]; then
    pass "_no_sessions names the provider filter and returns 1"
  else
    fail "_no_sessions filtered message: rc=$rc out='$out'"
  fi
}

# Given: no provider filter
# When:  _no_sessions runs
# Then:  it names the registry directory and the start remedy, and returns 1
# Asserts: the unfiltered guidance pair.
test_no_sessions_prints_the_registry_path_and_start_hint() {
  local sbx="$FIXTURE_DIR/nosessions_sbx"
  mkdir -p "$sbx"
  local out rc=0
  out="$(PROVIDER_FILTER="" SANDBOX_DIR="$sbx" _no_sessions 2>&1)" || rc=$?
  if [[ $rc -eq 1 && "$out" == *"$sbx/.compose"* && "$out" == *"make start"* ]]; then
    pass "_no_sessions names the registry path and the start remedy"
  else
    fail "_no_sessions guidance: rc=$rc out='$out'"
  fi
}

# =============================================================================
# _resume_work_map
# =============================================================================

# Given: an inventory entry with no checkpoint anywhere
# When:  _resume_work_map runs
# Then:  the session maps to the no-work marker
# Asserts: the never-exported arm.
test_work_map_marks_a_session_without_exports() {
  local sbx="$FIXTURE_DIR/work_none"
  mkdir -p "$sbx/.workspace/session-diffs"
  SANDBOX_DIR="$sbx"
  RESUME_INVENTORY=( "sess-a|pi|20260820-100000|main|fresh|||" )
  _resume_work_map
  local got="${_WORK_MAP[sess-a]:-unset}"
  if [[ "$got" == "--" ]]; then
    pass "_resume_work_map marks a session with no checkpoint as --"
  else
    fail "work map for an unexported session: '$got'"
  fi
}

# Given: an autosave checkpoint with two patches and a non-empty uncommitted diff
# When:  _resume_work_map runs
# Then:  the session maps to "<patches>c+u"
# Asserts: the commit count and the uncommitted marker.
test_work_map_counts_patches_and_the_uncommitted_marker() {
  local sbx="$FIXTURE_DIR/work_autosave"
  local as="$sbx/.workspace/session-diffs/autosave/sess-a"
  mkdir -p "$as/patches"
  : > "$as/patches/0001-a.diff"
  : > "$as/patches/0002-b.diff"
  printf 'work\n' > "$as/uncommitted.diff"
  SANDBOX_DIR="$sbx"
  RESUME_INVENTORY=( "sess-a|pi|20260820-100000|main|fresh|||" )
  _resume_work_map
  local got="${_WORK_MAP[sess-a]:-unset}"
  if [[ "$got" == "2c+u" ]]; then
    pass "_resume_work_map counts patches and marks uncommitted work"
  else
    fail "work map with two patches and an uncommitted diff: '$got'"
  fi
}

# Given: both an autosave checkpoint and a newer session export for one session
# When:  _resume_work_map runs
# Then:  the autosave checkpoint supplies the count
# Asserts: the documented precedence (autosave is the live checkpoint).
test_work_map_prefers_the_autosave_checkpoint() {
  local sbx="$FIXTURE_DIR/work_pref"
  local as="$sbx/.workspace/session-diffs/autosave/sess-a"
  local se="$sbx/.workspace/session-diffs/session/20260821-100000-sess-a"
  mkdir -p "$as/patches" "$se/patches"
  : > "$as/patches/0001-a.diff"
  : > "$se/patches/0001-a.diff"
  : > "$se/patches/0002-b.diff"
  : > "$se/patches/0003-c.diff"
  touch -d "2030-01-01" "$se"
  SANDBOX_DIR="$sbx"
  RESUME_INVENTORY=( "sess-a|pi|20260820-100000|main|fresh|||" )
  _resume_work_map
  local got="${_WORK_MAP[sess-a]:-unset}"
  if [[ "$got" == "1c" ]]; then
    pass "_resume_work_map prefers the autosave checkpoint over a newer export"
  else
    fail "autosave precedence: '$got' (expected the autosave count 1c)"
  fi
}

# =============================================================================
# _resume_state_map
# =============================================================================

# Given: docker reporting one running and one exited container
# When:  _resume_state_map runs
# Then:  the running session maps to running and the exited one to stopped
# Asserts: the state vocabulary the rows and the picker share.
test_state_map_reads_running_and_stopped() {
  local stub="$FIXTURE_DIR/state_stub"
  make_docker_stub "$stub"
  PATH="$stub:$PATH" DOCKER_STUB_PS_LINES=$'sess-a running\nsess-b exited' _resume_state_map
  if [[ "${_STATE_MAP[sess-a]:-}" == "running" && "${_STATE_MAP[sess-b]:-}" == "stopped" ]]; then
    pass "_resume_state_map maps running and every other state to stopped"
  else
    fail "state map: sess-a='${_STATE_MAP[sess-a]:-}' sess-b='${_STATE_MAP[sess-b]:-}'"
  fi
}

# Given: docker producing no output
# When:  _resume_state_map runs
# Then:  the map is empty, so rows render the log-only state
# Asserts: the docker-absent arm.
test_state_map_is_empty_without_docker_output() {
  local stub="$FIXTURE_DIR/state_stub_empty"
  make_docker_stub "$stub"
  PATH="$stub:$PATH" _resume_state_map
  if [[ "${#_STATE_MAP[@]}" -eq 0 ]]; then
    pass "_resume_state_map stays empty when docker reports nothing"
  else
    fail "state map should be empty, has ${#_STATE_MAP[@]} entries"
  fi
}

# =============================================================================
# _resume_state_cell
# =============================================================================

# Given: a session with no lifecycle events in its log
# When:  _resume_state_cell runs
# Then:  the cell is a dash
# Asserts: the no-evidence arm.
test_state_cell_without_events_is_a_dash() {
  local sbx="$FIXTURE_DIR/cell_none"
  mkdir -p "$sbx/.compose"
  _STATE_MAP=()
  local cell
  cell="$(SANDBOX_DIR="$sbx" _resume_state_cell "sess-a")"
  if [[ "$cell" == "-" ]]; then
    pass "_resume_state_cell renders a dash with no lifecycle event"
  else
    fail "no-event cell: '$cell'"
  fi
}

# Given: a started event and a later stopped event, with docker reporting the container running
# When:  _resume_state_cell runs
# Then:  docker's verb wins and no time is attached
# Asserts: the override that catches a crashed container whose log still says started.
test_state_cell_lets_docker_override_the_log_verb() {
  local sbx="$FIXTURE_DIR/cell_override"
  mkdir -p "$sbx/.compose"
  SANDBOX_DIR="$sbx" session_log_set "sess-a" last_started "20260820-100000"
  SANDBOX_DIR="$sbx" session_log_set "sess-a" last_stopped "20260820-110000"
  _STATE_MAP=( [sess-a]="running" )
  local cell
  cell="$(SANDBOX_DIR="$sbx" _resume_state_cell "sess-a")"
  if [[ "$cell" == "running" ]]; then
    pass "_resume_state_cell prefers the live docker verb over the log"
  else
    fail "docker override: cell='$cell'"
  fi
}

# Given: only a started event, with docker silent
# When:  _resume_state_cell runs
# Then:  the cell is the log verb with its relative age
# Asserts: the log-truth arm and the verb-first cell shape.
test_state_cell_reports_the_log_event_with_its_age() {
  local sbx="$FIXTURE_DIR/cell_log"
  mkdir -p "$sbx/.compose"
  SANDBOX_DIR="$sbx" session_log_set "sess-a" last_started "20260820-100000"
  _STATE_MAP=()
  local cell
  cell="$(SANDBOX_DIR="$sbx" _resume_state_cell "sess-a")"
  if [[ "$cell" == started* && "$cell" != "started" ]]; then
    pass "_resume_state_cell carries the log verb and a relative age"
  else
    fail "log-only cell: '$cell'"
  fi
}

# =============================================================================
# _resume_render_rows
# =============================================================================

# Given: three inventory entries, one stale, and a page size of two
# When:  _resume_render_rows runs in list mode
# Then:  it prints the header and exactly the first two rows, indented, with the staleness marker
# Asserts: the page cap and the row shape.
test_render_rows_list_mode_pages_and_marks_stale() {
  local sbx="$FIXTURE_DIR/render_list"
  mkdir -p "$sbx/.compose"
  _STATE_MAP=()
  RESUME_INVENTORY=(
    "sess-a|pi|20260820-100000|main|stale|||"
    "sess-b|pi|20260819-100000|dev|fresh|||"
    "sess-c|pi|20260818-100000|main|fresh|||"
  )
  local out
  # In-process, not a command substitution: the bookkeeping the assertion reads
  # lives in this shell, not in a subshell. The page size is set on the call so
  # it cannot leak to a later unit.
  SANDBOX_DIR="$sbx" RESUME_LIST_PAGE_SIZE=2 _resume_render_rows list > "$FIXTURE_DIR/render_list.out" 2>&1
  out="$(cat "$FIXTURE_DIR/render_list.out")"
  local rows
  rows="$(printf '%s\n' "$out" | grep -c '^  sess-')"
  if [[ "$out" == *"SESSION"* && "$rows" -eq 2 \
     && "$out" == *"sess-a"*" [SANDBOX_STALE]"* && "$out" != *"sess-c"* ]]; then
    pass "_resume_render_rows pages the list and marks the stale row"
  else
    fail "list render: rows=$rows out='$out'"
  fi
}

# Given: three inventory entries and a page size of one
# When:  _resume_render_rows runs in interactive mode
# Then:  the picker holds all three entries and nothing is printed
# Asserts: interactive mode hands the picker every entry and does its own paging.
test_render_rows_interactive_fills_the_picker() {
  local sbx="$FIXTURE_DIR/render_interactive"
  mkdir -p "$sbx/.compose"
  _STATE_MAP=()
  RESUME_INVENTORY=(
    "sess-a|pi|20260820-100000|main|fresh|||"
    "sess-b|pi|20260819-100000|dev|fresh|||"
    "sess-c|pi|20260818-100000|main|fresh|||"
  )
  local out
  # In-process, not a command substitution: the picker the assertion reads lives
  # in this shell. The page size is set on the call so it cannot leak to a later unit.
  SANDBOX_DIR="$sbx" RESUME_LIST_PAGE_SIZE=1 _resume_render_rows interactive > "$FIXTURE_DIR/render_interactive.out" 2>&1
  out="$(cat "$FIXTURE_DIR/render_interactive.out")"
  if [[ "${#PICKER[@]}" -eq 3 && -z "$out" \
     && "${PICKER[0]}" == sess-a\|* && "$_RESUME_HEADER" == *SESSION* ]]; then
    pass "_resume_render_rows fills the picker with every entry and prints nothing"
  else
    fail "interactive render: picker=${#PICKER[@]} first='${PICKER[0]:-}' out='$out'"
  fi
}

# =============================================================================
# build_inventory
# =============================================================================

# Given: a registry with two resumable records, a dry-run record, and a committed project
# When:  build_inventory runs
# Then:  the inventory holds the two, newest session-ts first, in the eight-field row shape
# Asserts: the dry-run skip, the sort, and the field order the renderer reads.
test_build_inventory_skips_dry_run_and_sorts_newest_first() {
  local sbx="$FIXTURE_DIR/inv_sbx"
  local proj="$FIXTURE_DIR/inv_proj"
  mkdir -p "$sbx/.compose"
  make_committed_repo "$proj"
  local sha
  sha="$(git -C "$proj" rev-parse HEAD)"

  make_record "$sbx/.compose/sess-a.yml" "pi-agent-proj" "proj-sbx" \
    "session-ts: 20260820-100000" "host-branch: main" "host-head-sha: $sha"
  make_record "$sbx/.compose/sess-b.yml" "opencode-agent-proj" "proj-sbx" \
    "session-ts: 20260821-090000" "host-branch: dev" "host-head-sha: $sha"
  make_record "$sbx/.compose/dryrun-abc123.yml" "pi-agent-proj" "proj-sbx" \
    "session-ts: 20260822-110000" "host-branch: main" "host-head-sha: $sha"

  SANDBOX_DIR="$sbx" PROJECT_DIR="$proj" PROVIDER_FILTER="" build_inventory

  local first fields
  first="${RESUME_INVENTORY[0]:-}"
  fields="$(printf '%s\n' "$first" | awk -F'|' '{print NF}')"
  if [[ "${#RESUME_INVENTORY[@]}" -eq 2 \
     && "$first" == "sess-b|opencode|20260821-090000|dev|"* \
     && "$fields" -eq 8 ]]; then
    pass "build_inventory skips dry-run records, sorts newest first, and emits eight fields"
  else
    fail "build_inventory: count=${#RESUME_INVENTORY[@]} first='$first' fields=$fields"
  fi
}

# ---------------------------------------------------------------------------
# Run all
# ---------------------------------------------------------------------------

run_test test_truncate_branch_leaves_short_names_whole
run_test test_truncate_branch_cuts_long_names_to_the_limit
run_test test_no_sessions_names_the_provider_filter
run_test test_no_sessions_prints_the_registry_path_and_start_hint
run_test test_work_map_marks_a_session_without_exports
run_test test_work_map_counts_patches_and_the_uncommitted_marker
run_test test_work_map_prefers_the_autosave_checkpoint
run_test test_state_map_reads_running_and_stopped
run_test test_state_map_is_empty_without_docker_output
run_test test_state_cell_without_events_is_a_dash
run_test test_state_cell_lets_docker_override_the_log_verb
run_test test_state_cell_reports_the_log_event_with_its_age
run_test test_render_rows_list_mode_pages_and_marks_stale
run_test test_render_rows_interactive_fills_the_picker
run_test test_build_inventory_skips_dry_run_and_sorts_newest_first

test_done test_resume_list.sh

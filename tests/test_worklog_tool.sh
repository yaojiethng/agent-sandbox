#!/usr/bin/env bash
# TEST_DEADLINE: 60
# tests/test_worklog_tool.sh
# Behavioural tests for scripts/worklog.sh -- the work-log record seam.
#
# Covers:
#   latest      -- the tip record on a track
#   active      -- the one record whose status is Active
#   reserve-id  -- the next free id in each track's reserved block
#   collision   -- two tracks on one date take disjoint ids
#   list        -- only the named track's records
#   track       -- the marker names the current track
#   path        -- the root is read from the one declaration
#
# The fixture is a synthetic repository root carrying a copy of the real
# declaration, so the tool's parse is the subject rather than the live tree.
#
# Run:   bash tests/test_worklog_tool.sh
# Exit:  0 = all passed, non-zero = failure count

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/.." && pwd)"

source "$TEST_DIR/libs/test_common.sh"
test_setup

TOOL="$REPO_ROOT/scripts/worklog.sh"

make_root() {
  local root="$1"
  mkdir -p "$root/src/build"
  mkdir -p "$root/devlog/handovers/M3.5.1"
  mkdir -p "$root/devlog/handovers/M3.5.2"
  cp "$REPO_ROOT/src/build/record-layout.json" "$root/src/build/record-layout.json"
  printf 'ids: 20-39\n' > "$root/devlog/handovers/M3.5.1/README.md"
  printf 'ids: 40-59\n' > "$root/devlog/handovers/M3.5.2/README.md"
}

write_handover() {
  local path="$1" date="$2" status="$3" milestone="$4"
  mkdir -p "$(dirname "$path")"
  {
    printf -- '---\n'
    printf 'date: %s\n' "$date"
    printf 'milestone: %s\n' "$milestone"
    printf 'type: Implementation\n'
    printf 'status: %s\n' "$status"
    printf -- '---\n\n'
    printf '# Handover - Test\n\n'
    printf '## Objective\n\nTest.\n\n'
    printf '## Scope\n\nTest.\n\n'
    printf '## Acceptance criteria\n\nTest.\n\n'
    printf '## Decisions\n\nNone.\n\n'
    printf '## Decisions pending\n\nNone.\n\n'
    printf '## Findings\n\nNone.\n\n'
    printf '## Completed\n\nNo file changes this iteration.\n'
  } > "$path"
}

test_latest_returns_the_tip() {
  local root; root="$(mktemp -d)"; make_root "$root"
  write_handover "$root/devlog/handovers/M3.5.1/20261105-20-impl-a.md" 2026-11-05 Closed "M3.5.1 - Test"
  write_handover "$root/devlog/handovers/M3.5.1/20261105-21-impl-b.md" 2026-11-05 Closed "M3.5.1 - Test"
  local out
  out="$("$TOOL" latest --root "$root" --track M3.5.1)"
  assert_contains "$out" "20261105-21-impl-b.md" "the latest record is the tip"
  rm -rf "$root"
}

test_active_returns_the_open_record() {
  local root; root="$(mktemp -d)"; make_root "$root"
  write_handover "$root/devlog/handovers/M3.5.1/20261105-20-impl-a.md" 2026-11-05 Closed "M3.5.1 - Test"
  write_handover "$root/devlog/handovers/M3.5.1/20261105-21-impl-b.md" 2026-11-05 Active "M3.5.1 - Test"
  local out
  out="$("$TOOL" active --root "$root" --track M3.5.1)"
  assert_contains "$out" "20261105-21-impl-b.md" "the active record is the open one"
  rm -rf "$root"
}

test_reserve_id_uses_the_track_block() {
  local root; root="$(mktemp -d)"; make_root "$root"
  write_handover "$root/devlog/handovers/M3.5.1/20261105-20-impl-a.md" 2026-11-05 Closed "M3.5.1 - Test"
  write_handover "$root/devlog/handovers/M3.5.1/20261105-21-impl-b.md" 2026-11-05 Closed "M3.5.1 - Test"
  local first second
  first="$("$TOOL" reserve-id --root "$root" --track M3.5.1 --date 20261105)"
  second="$("$TOOL" reserve-id --root "$root" --track M3.5.2 --date 20261105)"
  assert_eq "$first" "20261105-22" "the first track takes the next id in its block"
  assert_eq "$second" "20261105-40" "the second track's block is disjoint"
  rm -rf "$root"
}

test_list_returns_only_the_track() {
  local root; root="$(mktemp -d)"; make_root "$root"
  write_handover "$root/devlog/handovers/M3.5.1/20261105-20-impl-a.md" 2026-11-05 Closed "M3.5.1 - Test"
  write_handover "$root/devlog/handovers/M3.5.2/20261105-40-impl-b.md" 2026-11-05 Closed "M3.5.2 - Test"
  local out
  out="$("$TOOL" list --root "$root" --track M3.5.1)"
  assert_contains "$out" "M3.5.1/20261105-20-impl-a.md" "the track's record is listed"
  assert_not_contains "$out" "M3.5.2" "another track's record is not listed"
  rm -rf "$root"
}

test_latest_reads_a_flat_record_by_milestone() {
  local root; root="$(mktemp -d)"; make_root "$root"
  write_handover "$root/devlog/handovers/20261105-15-impl-flat.md" 2026-11-05 Closed "M3.5.1 - Test"
  local out
  out="$("$TOOL" latest --root "$root" --track M3.5.1)"
  assert_contains "$out" "20261105-15-impl-flat.md" "a flat record's track comes from its milestone field"
  rm -rf "$root"
}

test_track_reads_the_marker() {
  local root; root="$(mktemp -d)"; make_root "$root"
  mkdir -p "$root/.scratchpad"
  printf 'M3.5.1\n' > "$root/.scratchpad/worklog-track"
  local out
  out="$("$TOOL" track --root "$root")"
  assert_eq "$out" "M3.5.1" "the marker names the current track"
  rm -rf "$root"
}

test_path_reads_the_declaration() {
  local root; root="$(mktemp -d)"; make_root "$root"
  local out
  out="$("$TOOL" path handover --root "$root")"
  assert_eq "$out" "devlog/handovers" "the root comes from the one declaration"
  rm -rf "$root"
}

run_test test_latest_returns_the_tip
run_test test_latest_reads_a_flat_record_by_milestone
run_test test_active_returns_the_open_record
run_test test_reserve_id_uses_the_track_block
run_test test_list_returns_only_the_track
run_test test_track_reads_the_marker
run_test test_path_reads_the_declaration


test_latest_refuses_a_retired_branch_track() {
  local root; root="$(mktemp -d)"; make_root "$root"
  write_handover "$root/devlog/handovers/M3.5.1/20261105-20-impl-a.md" 2026-11-05 Closed "M3.5.1 - Test"
  git -C "$root" init -q
  git -C "$root" checkout -q -b feat/M3_5_9-retired
  local rc=0 out
  out="$("$TOOL" latest --root "$root" 2>&1)" || rc=$?
  assert_rc 1 "$rc" "a track that retired is an error, never another track's record"
  assert_contains "$out" 'M3.5.9' 'the stale track is named'
  assert_contains "$out" 'Pass --track' 'the repair is named'
  rm -rf "$root"
}

test_latest_answers_the_named_track() {
  local root; root="$(mktemp -d)"; make_root "$root"
  write_handover "$root/devlog/handovers/M3.5.1/20261105-20-impl-a.md" 2026-11-05 Closed "M3.5.1 - Test"
  write_handover "$root/devlog/handovers/M3.5.2/20261105-41-impl-b.md" 2026-11-05 Closed "M3.5.2 - Test"
  git -C "$root" init -q
  git -C "$root" checkout -q -b feat/M3_5_1-live
  local out
  out="$("$TOOL" latest --root "$root")"
  assert_contains "$out" "20261105-20-impl-a.md" "the caller's own track answers"
  out="$("$TOOL" latest --root "$root" --track M3.5.2)"
  assert_contains "$out" "20261105-41-impl-b.md" '--track names another track'
  rm -rf "$root"
}

test_latest_reports_an_empty_tree() {
  local root; root="$(mktemp -d)"; make_root "$root"
  local rc=0 out
  out="$("$TOOL" latest --root "$root" 2>&1)" || rc=$?
  assert_rc 1 "$rc" 'no record is a failure to answer, not a silent empty read'
  assert_contains "$out" '--track' 'the failure names the flag that fixes it'
  assert_contains "$out" '--all' 'the failure names the override'
  rm -rf "$root"
}

run_test test_latest_refuses_a_retired_branch_track
run_test test_latest_answers_the_named_track
run_test test_latest_reports_an_empty_tree


test_all_answers_across_tracks() {
  local root; root="$(mktemp -d)"; make_root "$root"
  write_handover "$root/devlog/handovers/M3.5.1/20261105-20-impl-a.md" 2026-11-05 Closed "M3.5.1 - Test"
  write_handover "$root/devlog/handovers/M3.5.2/20261105-41-impl-b.md" 2026-11-05 Closed "M3.5.2 - Test"
  git -C "$root" init -q
  git -C "$root" checkout -q -b feat/M3_5_9-retired
  local out
  out="$("$TOOL" latest --root "$root" --all)"
  assert_contains "$out" "20261105-41-impl-b.md" '--all answers across every track'
  rm -rf "$root"
}

test_error_lists_the_live_tracks() {
  local root; root="$(mktemp -d)"; make_root "$root"
  write_handover "$root/devlog/handovers/M3.5.1/20261105-20-impl-a.md" 2026-11-05 Closed "M3.5.1 - Test"
  local rc=0 out
  out="$("$TOOL" latest --root "$root" --track NOPE 2>&1)" || rc=$?
  assert_rc 1 "$rc" 'an unknown track is an error'
  assert_contains "$out" 'M3.5.1' 'the error lists the live tracks'
  assert_contains "$out" '--all' 'the error names the override'
  rm -rf "$root"
}

test_help_states_every_read() {
  local out
  out="$("$TOOL" --help)"
  assert_contains "$out" '--all' 'the usage states the all-tracks override'
  assert_contains "$out" 'reserve-id --track T' 'the usage states the required flag'
}

run_test test_all_answers_across_tracks
run_test test_error_lists_the_live_tracks
run_test test_help_states_every_read

test_done

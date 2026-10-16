#!/usr/bin/env bash
# Tests for the session-memory skill's tool, session-memory.mjs.
#
# Covers:
#   note    --  an occurrence appends and the view gains one directive;
#               a restatement appends to the log and adds no view line
#   wake    --  the view is newest first, and empty says so
#   merge   --  two view lines become one summary with the combined range
#   budget  --  the seventeenth line asks for a merge
#   zoom    --  a range prints the log entries
#   forget  --  a summary drops and the originals resurface
#   mark    --  a mark resets the diff
#   clip    --  a view line is cut to the character bound
#   render  --  the block lands in the caller's file under the caller's heading

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup

SM="$REPO_ROOT/src/reasoning/providers/pi/config/agent/skills/session-memory/session-memory.mjs"

run_sm() {
  local d="$1"
  shift
  node "$SM" --log "$d/SESSION_MEMORY_LOG.jsonl" "$@"
}

test_wake_empty() {
  local d
  d="$(get_fixture_dir)"
  assert_eq "$(run_sm "$d" wake)" "steering: none" "an empty view says so"
}

test_note_appends() {
  local d out
  d="$(get_fixture_dir)"
  out="$(run_sm "$d" note "file the push and pop handovers under M3.2.3")"
  assert_contains "$out" "appended n=1" "note appends the first occurrence"
  assert_eq "$(run_sm "$d" wake)" "[1-1] file the push and pop handovers under M3.2.3" "wake prints the view"
}

test_view_newest_first() {
  local d out
  d="$(get_fixture_dir)"
  run_sm "$d" note "first" >/dev/null
  run_sm "$d" note "second" >/dev/null
  out="$(run_sm "$d" wake)"
  assert_eq "$out" "$(printf '%s\n%s' "[2-2] second" "[1-1] first")" "the view is newest first"
}

test_restatement_adds_no_line() {
  local d
  d="$(get_fixture_dir)"
  run_sm "$d" note "hold the fork stack open" >/dev/null
  run_sm "$d" note "hold the fork stack open, repeated" --restates 1 >/dev/null
  assert_eq "$(run_sm "$d" wake)" "[1-1] hold the fork stack open" "a restatement adds no view line"
  assert_eq "$(wc -l < "$d/SESSION_MEMORY_LOG.jsonl")" "2" "both occurrences reach the log"
}

test_merge_compresses() {
  local d
  d="$(get_fixture_dir)"
  run_sm "$d" note "a" >/dev/null
  run_sm "$d" note "b" >/dev/null
  run_sm "$d" merge 1 2 "a and b" >/dev/null
  assert_eq "$(run_sm "$d" wake)" "[1-2] a and b" "merge replaces two lines with one summary"
}

test_budget_asks_for_a_merge() {
  local d i out=""
  d="$(get_fixture_dir)"
  for i in $(seq 1 17); do
    out="$(run_sm "$d" note "directive $i")"
  done
  assert_contains "$out" "merge due" "the seventeenth line asks for a merge"
}

test_zoom_prints_range() {
  local d out
  d="$(get_fixture_dir)"
  run_sm "$d" note "a" >/dev/null
  run_sm "$d" note "b" >/dev/null
  out="$(run_sm "$d" zoom 1-1)"
  assert_contains "$out" '"n":1' "zoom prints the range"
}

test_forget_resurfaces() {
  local d
  d="$(get_fixture_dir)"
  run_sm "$d" note "a" >/dev/null
  run_sm "$d" note "b" >/dev/null
  run_sm "$d" merge 1 2 "a and b" >/dev/null
  run_sm "$d" forget 1-2 >/dev/null
  assert_eq "$(run_sm "$d" wake)" "$(printf '%s\n%s' "[2-2] b" "[1-1] a")" "forget drops the summary and resurfaces the originals"
}

test_mark_resets_the_diff() {
  local d out
  d="$(get_fixture_dir)"
  run_sm "$d" note "a" >/dev/null
  run_sm "$d" mark >/dev/null
  run_sm "$d" note "b" >/dev/null
  out="$(run_sm "$d" diff)"
  assert_contains "$out" "appended: n=2" "diff reports the occurrence since the mark"
  assert_contains "$out" "view added: [2-2]" "diff reports the view line since the mark"
}

test_clip_to_the_bound() {
  local d long line text
  d="$(get_fixture_dir)"
  long="$(printf 'x%.0s' $(seq 1 300))"
  run_sm "$d" note "$long" >/dev/null
  line="$(run_sm "$d" wake)"
  text="${line#*] }"
  assert_eq "${#text}" "240" "a view line is clipped to 240 characters"
}

test_render_writes_the_block() {
  local d
  d="$(get_fixture_dir)"
  printf '## The tree\n\nbody\n' > "$d/TRACKER.md"
  run_sm "$d" note "a directive" >/dev/null
  node "$SM" --log "$d/SESSION_MEMORY_LOG.jsonl" --block "$d/TRACKER.md" --heading "## Session memory" render >/dev/null
  local out
  out="$(cat "$d/TRACKER.md")"
  assert_contains "$out" "## The tree" "the block write leaves the rest of the file alone"
  assert_contains "$out" "## Session memory" "the block appends the heading"
  assert_contains "$out" "[1-1] a directive" "the block carries the view"
}

run_test test_wake_empty
run_test test_note_appends
run_test test_view_newest_first
run_test test_restatement_adds_no_line
run_test test_merge_compresses
run_test test_budget_asks_for_a_merge
run_test test_zoom_prints_range
run_test test_forget_resurfaces
run_test test_mark_resets_the_diff
run_test test_clip_to_the_bound
run_test test_render_writes_the_block

test_done

#!/usr/bin/env bash
# Tests for scripts/steer.mjs, the steering memory modelled on OptMem.
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

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup

run_steer() {
  local d="$1"
  shift
  node "$REPO_ROOT/scripts/steer.mjs" --dir "$d" "$@"
}

test_wake_empty() {
  local d
  d="$(get_fixture_dir)"
  assert_eq "$(run_steer "$d" wake)" "steering: none" "an empty view says so"
}

test_note_appends() {
  local d out
  d="$(get_fixture_dir)"
  out="$(run_steer "$d" note "file the push and pop handovers under M3.2.3")"
  assert_contains "$out" "appended n=1" "note appends the first occurrence"
  assert_eq "$(run_steer "$d" wake)" "[1-1] file the push and pop handovers under M3.2.3" "wake prints the view"
}

test_view_newest_first() {
  local d out
  d="$(get_fixture_dir)"
  run_steer "$d" note "first" >/dev/null
  run_steer "$d" note "second" >/dev/null
  out="$(run_steer "$d" wake)"
  assert_eq "$out" "$(printf '%s\n%s' "[2-2] second" "[1-1] first")" "the view is newest first"
}

test_restatement_adds_no_line() {
  local d
  d="$(get_fixture_dir)"
  run_steer "$d" note "hold the fork stack open" >/dev/null
  run_steer "$d" note "hold the fork stack open, repeated" --restates 1 >/dev/null
  assert_eq "$(run_steer "$d" wake)" "[1-1] hold the fork stack open" "a restatement adds no view line"
  assert_eq "$(wc -l < "$d/STEERING_LOG.jsonl")" "2" "both occurrences reach the log"
}

test_merge_compresses() {
  local d
  d="$(get_fixture_dir)"
  run_steer "$d" note "a" >/dev/null
  run_steer "$d" note "b" >/dev/null
  run_steer "$d" merge 1 2 "a and b" >/dev/null
  assert_eq "$(run_steer "$d" wake)" "[1-2] a and b" "merge replaces two lines with one summary"
}

test_budget_asks_for_a_merge() {
  local d i out=""
  d="$(get_fixture_dir)"
  for i in $(seq 1 17); do
    out="$(run_steer "$d" note "directive $i")"
  done
  assert_contains "$out" "merge due" "the seventeenth line asks for a merge"
}

test_zoom_prints_range() {
  local d out
  d="$(get_fixture_dir)"
  run_steer "$d" note "a" >/dev/null
  run_steer "$d" note "b" >/dev/null
  out="$(run_steer "$d" zoom 1-1)"
  assert_contains "$out" '"n":1' "zoom prints the range"
}

test_forget_resurfaces() {
  local d
  d="$(get_fixture_dir)"
  run_steer "$d" note "a" >/dev/null
  run_steer "$d" note "b" >/dev/null
  run_steer "$d" merge 1 2 "a and b" >/dev/null
  run_steer "$d" forget 1-2 >/dev/null
  assert_eq "$(run_steer "$d" wake)" "$(printf '%s\n%s' "[2-2] b" "[1-1] a")" "forget drops the summary and resurfaces the originals"
}

test_mark_resets_the_diff() {
  local d out
  d="$(get_fixture_dir)"
  run_steer "$d" note "a" >/dev/null
  run_steer "$d" mark >/dev/null
  run_steer "$d" note "b" >/dev/null
  out="$(run_steer "$d" diff)"
  assert_contains "$out" "appended: n=2" "diff reports the occurrence since the mark"
  assert_contains "$out" "view added: [2-2]" "diff reports the view line since the mark"
}

test_clip_to_the_bound() {
  local d long line text
  d="$(get_fixture_dir)"
  long="$(printf 'x%.0s' $(seq 1 300))"
  run_steer "$d" note "$long" >/dev/null
  line="$(run_steer "$d" wake)"
  text="${line#*] }"
  assert_eq "${#text}" "240" "a view line is clipped to 240 characters"
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

test_done

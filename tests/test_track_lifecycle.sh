#!/usr/bin/env bash
# TEST_DEADLINE: 60
# tests/test_track_lifecycle.sh
# Behavioural tests for scripts/check_track_lifecycle.sh -- the handover track
# lifecycle gate.
#
# Covers:
#   a live track whose milestone the changelog closes  -- rc 1; the folder is
#                                                named with its repair
#   a live track whose milestone is open               -- rc 0
#   a work-unit folder (`T7`) the changelog never closes -- rc 0, because it is
#                                                not a milestone track
#   a folder named `archive`                          -- rc 0, because it names
#                                                no closed milestone id
#   a missing changelog                                -- rc 1, the gate cannot
#                                                read the closure state
#
# The fixtures sit under $FIXTURE_DIR, outside the repo tree, and the gate is
# pointed at them with `--root`, so the repository's own tracks are never the
# subject.
#
# Run:   bash tests/test_track_lifecycle.sh
# Exit:  0 = all passed, non-zero = failure count

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/.." && pwd)"

source "$TEST_DIR/libs/test_common.sh"
test_setup

GATE="$REPO_ROOT/scripts/check_track_lifecycle.sh"

# write_changelog ROOT ID...  --  a changelog closing each named milestone.
write_changelog() {
  local root="$1"
  shift
  mkdir -p "$root/devlog"
  {
    printf '# Changelog\n\n'
    local id
    for id in "$@"; do printf '## %s - A closed milestone\n\nOutcome.\n\n' "$id"; done
  } > "$root/devlog/changelog.md"
}

# write_track ROOT ID  --  a live track folder carrying one record.
write_track() {
  local root="$1" id="$2"
  mkdir -p "$root/devlog/handovers/$id"
  printf -- '---\nstatus: Closed\n---\n\n# A record\n' > "$root/devlog/handovers/$id/20260101-01-impl-x.md"
}

test_closed_milestone_with_a_live_track_fails() {
  local root="$FIXTURE_DIR/t1" rc=0 out
  write_changelog "$root" M3.4.2
  write_track "$root" M3.4.2
  out="$(bash "$GATE" --root="$root" 2>&1)" || rc=$?
  assert_rc 1 "$rc" 'a live track for a closed milestone fails'
  assert_contains "$out" 'M3.4.2: a live track' 'the folder is named'
  assert_contains "$out" 'delete the folder' 'the repair is named'
}

test_open_milestone_track_passes() {
  local root="$FIXTURE_DIR/t2" rc=0 out
  write_changelog "$root" M3.4.2
  write_track "$root" M3.5.1
  out="$(bash "$GATE" --root="$root" 2>&1)" || rc=$?
  assert_rc 0 "$rc" 'a track whose milestone is open passes'
}

test_work_unit_folder_passes() {
  local root="$FIXTURE_DIR/t3" rc=0 out
  write_changelog "$root" M3.4.2
  write_track "$root" T7
  out="$(bash "$GATE" --root="$root" 2>&1)" || rc=$?
  assert_rc 0 "$rc" 'a folder the changelog never closes is not a milestone track'
}

test_archive_named_folder_passes() {
  local root="$FIXTURE_DIR/t4" rc=0 out
  write_changelog "$root" M3.4.2
  write_track "$root" archive
  out="$(bash "$GATE" --root="$root" 2>&1)" || rc=$?
  assert_rc 0 "$rc" 'a folder named archive names no closed milestone id'
}

test_missing_changelog_cannot_run() {
  local root="$FIXTURE_DIR/t5" rc=0 out
  write_track "$root" M3.4.2
  out="$(bash "$GATE" --root="$root" 2>&1)" || rc=$?
  assert_rc 1 "$rc" 'a missing changelog stops the gate'
  assert_contains "$out" 'changelog.md is missing' 'the missing record is named'
}

run_test test_closed_milestone_with_a_live_track_fails
run_test test_open_milestone_track_passes
run_test test_work_unit_folder_passes
run_test test_archive_named_folder_passes
run_test test_missing_changelog_cannot_run

test_done

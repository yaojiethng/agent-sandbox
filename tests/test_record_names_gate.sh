#!/usr/bin/env bash
# TEST_DEADLINE: 60
# tests/test_record_names_gate.sh
# Behavioural tests for scripts/check_record_names.sh -- the exploration-record
# name gate -- and the scripts/lint/record-name.mjs scanner it wraps.
#
# Covers:
#   a conforming name            -- rc 0, and the scan says how many it read
#   a name carrying the per-day index  -- rc 1; the index slot is named as the
#                                    handover's, which is the defect the gate
#                                    exists for
#   a name with no status        -- rc 1; the shape is named
#   an unknown type              -- rc 1; the vocabulary is named
#   an unknown status            -- rc 1; the vocabulary is named
#   an old-format name before the cutover -- rc 0, because the convention lets
#                                    an old name stand until the record is edited
#   a named file                 -- enforced regardless of date
#   a record under archive/      -- not scanned
#
# The fixtures sit under $FIXTURE_DIR, outside the repo tree, and the scan is
# pointed at them with RECORD_NAME_SCAN_ROOT so the repository's own records are
# never the subject. RECORD_NAME_CUTOVER moves the cutover where a test needs it.
#
# Run:   bash tests/test_record_names_gate.sh
# Exit:  0 = all passed, non-zero = failure count

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/.." && pwd)"

source "$TEST_DIR/libs/test_common.sh"
test_setup

GATE="$REPO_ROOT/scripts/check_record_names.sh"

# write_record PATH  --  a conforming exploration record.
write_record() {
  local path="$1"
  mkdir -p "$(dirname "$path")"
  {
    printf -- '---\n'
    printf 'date: 2026-10-26\n'
    printf 'type: Report\n'
    printf 'status: settled\n'
    printf -- '---\n\n'
    printf '# A record\n'
  } > "$path"
}

test_conforming_name_passes() {
  local root="$FIXTURE_DIR/t1" rc=0 out
  write_record "$root/devlog/discussions/20261026-report-settled-x.md"
  out="$(RECORD_NAME_SCAN_ROOT="$root" bash "$GATE" 2>&1)" || rc=$?
  assert_rc 0 "$rc" 'a conforming name passes'
  assert_contains "$out" 'clean across 1 record' 'the scan reports what it read'
}

test_index_in_a_discussion_name_flagged() {
  local root="$FIXTURE_DIR/t2" rc=0 out
  write_record "$root/devlog/discussions/20261026-06-report-settled-x.md"
  out="$(RECORD_NAME_SCAN_ROOT="$root" bash "$GATE" 2>&1)" || rc=$?
  assert_rc 1 "$rc" 'a per-day index in a discussion name fails'
  assert_contains "$out" 'per-day index' 'the index slot is named'
  assert_contains "$out" 'belongs to the handover record' 'and the record it belongs to'
}

test_missing_status_flagged() {
  local root="$FIXTURE_DIR/t3" rc=0 out
  write_record "$root/devlog/discussions/20261026-report-x.md"
  out="$(RECORD_NAME_SCAN_ROOT="$root" bash "$GATE" 2>&1)" || rc=$?
  assert_rc 1 "$rc" 'a name with no status fails'
  assert_contains "$out" 'YYYYMMDD-{type}-{status}-{description}' 'the shape is named'
}

test_unknown_type_flagged() {
  local root="$FIXTURE_DIR/t4" rc=0 out
  write_record "$root/devlog/discussions/20261026-note-settled-x.md"
  out="$(RECORD_NAME_SCAN_ROOT="$root" bash "$GATE" 2>&1)" || rc=$?
  assert_rc 1 "$rc" 'an unknown type fails'
  assert_contains "$out" '"note" is not one of' 'the vocabulary is named'
}

test_unknown_status_flagged() {
  local root="$FIXTURE_DIR/t5" rc=0 out
  write_record "$root/devlog/discussions/20261026-report-finished-x.md"
  out="$(RECORD_NAME_SCAN_ROOT="$root" bash "$GATE" 2>&1)" || rc=$?
  assert_rc 1 "$rc" 'an unknown status fails'
  assert_contains "$out" '"finished" is not one of' 'the vocabulary is named'
}

test_before_cutover_is_exempt() {
  local root="$FIXTURE_DIR/t6" rc=0 out
  write_record "$root/devlog/discussions/20261023-report-x.md"
  out="$(RECORD_NAME_SCAN_ROOT="$root" bash "$GATE" 2>&1)" || rc=$?
  assert_rc 0 "$rc" 'an old-format name dated before the cutover is exempt'
  assert_contains "$out" 'clean across 1 record' 'the record is still read'
}

test_named_file_ignores_cutover() {
  local root="$FIXTURE_DIR/t7" rc=0 out
  write_record "$root/devlog/discussions/20261023-report-x.md"
  out="$(bash "$GATE" "$root/devlog/discussions/20261023-report-x.md" 2>&1)" || rc=$?
  assert_rc 1 "$rc" 'a named file is enforced regardless of date'
  assert_contains "$out" 'does not match' 'the shape is named'
}

test_archive_not_scanned() {
  local root="$FIXTURE_DIR/t8" rc=0 out
  write_record "$root/devlog/discussions/archive/20261026-report-x.md"
  write_record "$root/devlog/discussions/20261026-report-settled-live.md"
  out="$(RECORD_NAME_SCAN_ROOT="$root" bash "$GATE" 2>&1)" || rc=$?
  assert_rc 0 "$rc" 'a record under archive/ is not scanned'
  assert_contains "$out" 'clean across 1 record' 'and the live record is the only subject'
}

run_test test_conforming_name_passes
run_test test_index_in_a_discussion_name_flagged
run_test test_missing_status_flagged
run_test test_unknown_type_flagged
run_test test_unknown_status_flagged
run_test test_before_cutover_is_exempt
run_test test_named_file_ignores_cutover
run_test test_archive_not_scanned

test_done

#!/usr/bin/env bash
# TEST_DEADLINE: 60
# tests/test_record_lifecycle_gate.sh
# Behavioural tests for scripts/check_record_lifecycle.sh -- the exploration
# record lifecycle gate -- and the scripts/lint/record-lifecycle.mjs scanner it
# wraps.
#
# Covers:
#   a concluded record an open row names  -- rc 0; the scan says what it read
#   a concluded record no row names       -- rc 1; deletion is named
#   a rejected record no row names        -- rc 1; the same rule covers it
#   an open record no row names           -- rc 0, because the record has not
#                                    concluded, so it is not a deletion yet
#   a closed row naming a record          -- rc 1; the link is named, and the
#                                    repair is stated
#   a closed row naming a different row's record -- rc 1, so the scan does not
#                                    assume the name appears once
#   a record dated before the cutover     -- rc 0 for both rules
#   a missing roadmap                     -- rc 0, and every concluded record is
#                                    then a deletion, so the scan says so
#
# The fixtures sit under $FIXTURE_DIR, outside the repo tree, and the scan is
# pointed at them with RECORD_LIFECYCLE_SCAN_ROOT so the repository's own
# records are never the subject. RECORD_CUTOVER moves the cutover where a test
# needs it.
#
# Run:   bash tests/test_record_lifecycle_gate.sh
# Exit:  0 = all passed, non-zero = failure count

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/.." && pwd)"

source "$TEST_DIR/libs/test_common.sh"
test_setup

GATE="$REPO_ROOT/scripts/check_record_lifecycle.sh"

# write_record ROOT NAME  --  a record whose state is in its name.
write_record() {
  local root="$1" name="$2"
  mkdir -p "$root/devlog/discussions"
  printf '# A record\n' > "$root/devlog/discussions/$name"
}

# write_roadmap ROOT LINE...  --  a roadmap carrying the given rows.
write_roadmap() {
  local root="$1"
  shift
  mkdir -p "$root/devlog"
  {
    printf -- '---\ntitle: roadmap\n---\n\n'
    local line
    for line in "$@"; do printf '%s\n' "$line"; done
  } > "$root/devlog/roadmap.md"
}

test_concluded_and_owned_passes() {
  local root="$FIXTURE_DIR/t1" rc=0 out
  write_record "$root" 20261105-design-concluded-x.md
  write_roadmap "$root" '- [ ] **A row** -- the record `20261105-design-concluded-x.md` holds the design'
  out="$(RECORD_LIFECYCLE_SCAN_ROOT="$root" bash "$GATE" 2>&1)" || rc=$?
  assert_rc 0 "$rc" 'a concluded record an open row names is clean'
  assert_contains "$out" 'clean across 1 record(s)' 'the scan reports what it read'
}

test_concluded_and_orphaned_flagged() {
  local root="$FIXTURE_DIR/t2" rc=0 out
  write_record "$root" 20261105-design-concluded-x.md
  write_roadmap "$root" '- [x] **Another row** -- nothing to do with the record'
  out="$(RECORD_LIFECYCLE_SCAN_ROOT="$root" bash "$GATE" 2>&1)" || rc=$?
  assert_rc 1 "$rc" 'a concluded record no open row names fails'
  assert_contains "$out" 'deletion that has not run' 'the deletion is named'
}

test_rejected_and_orphaned_flagged() {
  local root="$FIXTURE_DIR/t3" rc=0 out
  write_record "$root" 20261105-design-rejected-x.md
  write_roadmap "$root" '- [ ] **An open row** -- names something else'
  out="$(RECORD_LIFECYCLE_SCAN_ROOT="$root" bash "$GATE" 2>&1)" || rc=$?
  assert_rc 1 "$rc" 'a rejected record no open row names fails'
  assert_contains "$out" 'state "rejected"' 'the state is named'
}

test_open_and_orphaned_passes() {
  local root="$FIXTURE_DIR/t4" rc=0 out
  write_record "$root" 20261105-study-open-x.md
  write_roadmap "$root" '- [ ] **An open row** -- names something else'
  out="$(RECORD_LIFECYCLE_SCAN_ROOT="$root" bash "$GATE" 2>&1)" || rc=$?
  assert_rc 0 "$rc" 'an orphaned record that has not concluded is not a deletion'
}

test_closed_row_link_flagged() {
  local root="$FIXTURE_DIR/t5" rc=0 out
  write_record "$root" 20261105-design-open-x.md
  write_roadmap "$root" '- [x] **A closed row** -- see `20261105-design-open-x.md`'
  out="$(RECORD_LIFECYCLE_SCAN_ROOT="$root" bash "$GATE" 2>&1)" || rc=$?
  assert_rc 1 "$rc" 'a closed row naming a record fails'
  assert_contains "$out" 'carries no discussion link' 'the rule is named'
  assert_contains "$out" 're-point the record to an open row' 'the repair is named'
}

test_closed_row_link_to_a_second_record_flagged() {
  local root="$FIXTURE_DIR/t6" rc=0 out
  write_record "$root" 20261105-design-open-a.md
  write_record "$root" 20261105-design-open-b.md
  write_roadmap "$root" \
    '- [ ] **An open row** -- the record `20261105-design-open-a.md` holds the design' \
    '- [x] **A closed row** -- the record `20261105-design-open-b.md` holds the design'
  out="$(RECORD_LIFECYCLE_SCAN_ROOT="$root" bash "$GATE" 2>&1)" || rc=$?
  assert_rc 1 "$rc" 'only the closed row is at fault'
  assert_contains "$out" '20261105-design-open-b.md' 'the record the closed row names is reported'
}

test_before_cutover_is_exempt() {
  local root="$FIXTURE_DIR/t7" rc=0 out
  write_record "$root" 20261104-design-settled-x.md
  write_roadmap "$root" '- [x] **A closed row** -- see `20261104-design-settled-x.md`'
  out="$(RECORD_LIFECYCLE_SCAN_ROOT="$root" bash "$GATE" 2>&1)" || rc=$?
  assert_rc 0 "$rc" 'a record dated before the cutover is exempt from both rules'
  assert_contains "$out" 'clean across 0 record(s)' 'and is not counted as a subject'
}

test_cutover_moves() {
  local root="$FIXTURE_DIR/t8" rc=0 out
  write_record "$root" 20261104-design-settled-x.md
  write_roadmap "$root" '- [x] **A closed row** -- see `20261104-design-settled-x.md`'
  out="$(RECORD_CUTOVER=20261101 RECORD_LIFECYCLE_SCAN_ROOT="$root" bash "$GATE" 2>&1)" || rc=$?
  assert_rc 1 "$rc" 'moving the cutover earlier makes the same record a subject'
}

test_missing_roadmap_flags_every_ended_record() {
  local root="$FIXTURE_DIR/t9" rc=0 out
  write_record "$root" 20261105-design-concluded-x.md
  out="$(RECORD_LIFECYCLE_SCAN_ROOT="$root" bash "$GATE" 2>&1)" || rc=$?
  assert_rc 1 "$rc" 'with no roadmap, no row owns anything'
  assert_contains "$out" 'no open roadmap row names it' 'the reason is the tenancy'
}

run_test test_concluded_and_owned_passes
run_test test_concluded_and_orphaned_flagged
run_test test_rejected_and_orphaned_flagged
run_test test_open_and_orphaned_passes
run_test test_closed_row_link_flagged
run_test test_closed_row_link_to_a_second_record_flagged
run_test test_before_cutover_is_exempt
run_test test_cutover_moves
run_test test_missing_roadmap_flags_every_ended_record

test_done

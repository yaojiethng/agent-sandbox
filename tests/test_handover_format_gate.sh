#!/usr/bin/env bash
# TEST_DEADLINE: 60
# tests/test_handover_format_gate.sh
# Behavioural tests for scripts/check_handover_format.sh -- the cutover-scoped
# handover format gate -- and the scripts/lint/handover-format.mjs scanner it
# wraps.
#
# Covers:
#   a conforming handover        --  rc 0
#   a bold-header handover       --  rc 1; the missing YAML block is named
#   a forbidden section          --  rc 1; the section and its line are named
#   a missing required section   --  rc 1
#   a bad frontmatter value      --  rc 1
#   the default scan             --  flags a live record with no frontmatter
#                                    block, and skips the archive/ folder
#   a named file                 --  enforced regardless of date, so the same
#                                    tool audits history on demand
#   the staged mode              --  rc 0 when nothing is staged
#
# The fixtures sit under $FIXTURE_DIR, outside the repo tree, and the scan is
# pointed at them with HANDOVER_FORMAT_SCAN_ROOT so the repository's own
# handovers are never the subject.
#
# Run:   bash tests/test_handover_format_gate.sh
# Exit:  0 = all passed, non-zero = failure count

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/.." && pwd)"

source "$TEST_DIR/libs/test_common.sh"
test_setup

GATE="$REPO_ROOT/scripts/check_handover_format.sh"

# write_handover PATH DATE  --  a conforming handover file.
write_handover() {
  local path="$1" date="$2"
  mkdir -p "$(dirname "$path")"
  {
    printf -- '---\n'
    printf 'date: %s\n' "$date"
    printf 'milestone: T1 - Test\n'
    printf 'type: Workflow\n'
    printf 'status: Active\n'
    printf -- '---\n\n'
    printf '# Handover - Test\n\n'
    printf '## Objective\n\nTest.\n\n'
    printf '## Scope\n\nTest.\n\n'
    printf '## Acceptance criteria\n\nTest.\n\n'
    printf '## Hot files\n\nTest.\n\n'
    printf '## Decisions\n\nNone.\n\n'
    printf '## Decisions pending\n\nNone.\n\n'
    printf '## Findings\n\nNone.\n\n'
    printf '## Completed\n\nNo file changes this iteration.\n'
  } > "$path"
}

# write_bold_handover PATH  --  the pre-YAML header form, dated before the cutover.
write_bold_handover() {
  local path="$1"
  mkdir -p "$(dirname "$path")"
  {
    printf '# Agent Handover\n\n'
    printf '**Date:** 2026-01-01\n'
    printf '**Status:** Closed\n\n'
    printf '## Objective\n\nOld form.\n'
  } > "$path"
}

test_conforming_handover_passes() {
  local file="$FIXTURE_DIR/t1/devlog/handovers/20261004-01-workflow-x.md" rc=0
  write_handover "$file" 2026-10-04
  bash "$GATE" "$file" > /dev/null 2>&1 || rc=$?
  assert_rc 0 "$rc" 'a conforming handover passes'
}

test_bold_header_flagged() {
  local file="$FIXTURE_DIR/t2/devlog/handovers/20260101-01-workflow-old.md" rc=0 out
  write_bold_handover "$file"
  out="$(bash "$GATE" "$file" 2>&1)" || rc=$?
  assert_rc 1 "$rc" 'a bold-header handover fails'
  assert_contains "$out" 'no YAML frontmatter block' 'the missing frontmatter is named'
}

test_forbidden_section_flagged() {
  local file="$FIXTURE_DIR/t3/devlog/handovers/20261004-01-workflow-x.md" rc=0 out
  write_handover "$file" 2026-10-04
  printf '## Deferred\n\nAn item.\n' >> "$file"
  out="$(bash "$GATE" "$file" 2>&1)" || rc=$?
  assert_rc 1 "$rc" 'a Deferred section fails'
  assert_contains "$out" 'forbidden section `## Deferred`' 'the section is named'
}

test_missing_required_section_flagged() {
  local file="$FIXTURE_DIR/t4/devlog/handovers/20261004-01-workflow-x.md" rc=0 out
  write_handover "$file" 2026-10-04
  grep -v '^## Findings$' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
  out="$(bash "$GATE" "$file" 2>&1)" || rc=$?
  assert_rc 1 "$rc" 'a missing required section fails'
  assert_contains "$out" 'missing required section `## Findings`' 'the section is named'
}

test_bad_frontmatter_value_flagged() {
  local file="$FIXTURE_DIR/t5/devlog/handovers/20261004-01-workflow-x.md" rc=0 out
  write_handover "$file" 2026-10-04
  sed -i 's/^status: Active$/status: Done/' "$file"
  out="$(bash "$GATE" "$file" 2>&1)" || rc=$?
  assert_rc 1 "$rc" 'a bad status fails'
  assert_contains "$out" 'status' 'the field is named'
}

test_default_scan_flags_block_absent_record() {
  local root="$FIXTURE_DIR/t6" rc=0 out
  write_bold_handover "$root/devlog/handovers/20260101-01-workflow-old.md"
  write_handover "$root/devlog/handovers/20261004-01-workflow-new.md" 2026-10-04
  out="$(HANDOVER_FORMAT_SCAN_ROOT="$root" bash "$GATE" 2>&1)" || rc=$?
  assert_rc 1 "$rc" 'the default scan flags a live record with no block'
  assert_contains "$out" 'no YAML frontmatter block' 'the missing block is named'
}

test_default_scan_skips_archive() {
  local root="$FIXTURE_DIR/t9" rc=0 out
  write_bold_handover "$root/devlog/handovers/archive/20260101-01-workflow-old.md"
  write_handover "$root/devlog/handovers/20261004-01-workflow-new.md" 2026-10-04
  out="$(HANDOVER_FORMAT_SCAN_ROOT="$root" bash "$GATE" 2>&1)" || rc=$?
  assert_rc 0 "$rc" 'a record under archive/ is not scanned'
  assert_contains "$out" 'clean across 1 handover' 'and the live record is the only subject'
}

test_named_file_ignores_cutover() {
  local root="$FIXTURE_DIR/t7" rc=0
  write_bold_handover "$root/devlog/handovers/20260101-01-workflow-old.md"
  bash "$GATE" "$root/devlog/handovers/20260101-01-workflow-old.md" > /dev/null 2>&1 || rc=$?
  assert_rc 1 "$rc" 'a named file is enforced regardless of date'
}

test_file_list_without_force_respects_cutover() {
  local root="$FIXTURE_DIR/t8" file="$FIXTURE_DIR/t8/devlog/handovers/20260101-01-workflow-old.md" rc=0 out
  write_bold_handover "$file"
  out="$(node "$REPO_ROOT/scripts/lint/handover-format.mjs" --root="$root" "$file" 2>&1)" || rc=$?
  assert_rc 0 "$rc" 'a file list without --force keeps the cutover'
  assert_contains "$out" 'clean across 0 handover' 'so the old record is skipped'
}

test_staged_with_nothing_staged_is_clean() {
  local rc=0 out
  out="$(bash "$GATE" --staged 2>&1)" || rc=$?
  assert_rc 0 "$rc" 'nothing staged enforces nothing'
  assert_contains "$out" 'Clean' 'and says so'
}

run_test test_conforming_handover_passes
run_test test_bold_header_flagged
run_test test_forbidden_section_flagged
run_test test_missing_required_section_flagged
run_test test_bad_frontmatter_value_flagged
run_test test_default_scan_flags_block_absent_record
run_test test_default_scan_skips_archive
run_test test_named_file_ignores_cutover
run_test test_file_list_without_force_respects_cutover
run_test test_staged_with_nothing_staged_is_clean

test_done

#!/usr/bin/env bash
# TEST_DEADLINE: 45
#   The gate runs markdownlint-cli2 over the tree per assertion, so the honest
#   cost is about 30s. The declaration is a budget, not a licence.
# tests/test_doc_wrap_legacy_gate.sh
# Behavioural tests for scripts/check_doc_wrap_legacy.sh -- the gate that ends a
# doc-wrap file exemption when the file is next edited -- and for the rule's
# DOC_WRAP_ENFORCE seam that makes it possible.
#
# Covers:
#   an unstaged run        --  clean; nothing is staged to enforce
#   a touched legacy file  --  rc 1, naming the file and its findings
#   a touched clean file   --  rc 0 (no entry, so no enforcement)
#   a grandfathered file   --  rc 0 even with wrap debt: a closed record is
#                              never reflowed
#   the seam itself        --  exempt un-enforced, flagged under DOC_WRAP_ENFORCE
#
# The tests use the repository's own config and its real legacy list, because
# that is what ships. Each named file is either listed as legacy or not, and its
# wrap state changes only when someone reflows it -- which is the change this
# mechanism exists to cause, and a reflow that fixes a file without dropping its
# entry fails these tests rather than passing quietly.

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/.." && pwd)"

source "$TEST_DIR/libs/test_common.sh"
test_setup

GATE="$REPO_ROOT/scripts/check_doc_wrap_legacy.sh"

LEGACY_WITH_DEBT="docs/adr/command_flag_parsing.md"
GRANDFATHERED="devlog/changelog.md"

test_unstaged_run_is_clean() {
  local rc=0 out
  out="$(bash "$GATE" --staged 2>&1)" || rc=$?
  assert_rc 0 "$rc" 'an unstaged run enforces nothing'
  assert_contains "$out" 'clean' 'and says so'
}

test_touched_legacy_file_fails() {
  local rc=0 out
  out="$(bash "$GATE" "$LEGACY_WITH_DEBT" 2>&1)" || rc=$?
  assert_rc 1 "$rc" 'a touched legacy file with wrapped prose fails'
  assert_contains "$out" "$LEGACY_WITH_DEBT" 'the file is named'
  assert_contains "$out" 'one physical line' 'and its finding is reported'
}

test_touched_clean_file_passes() {
  local rc=0
  bash "$GATE" "$GATE" > /dev/null 2>&1 || rc=$?
  assert_rc 0 "$rc" 'a file with no legacy entry carries no enforcement'
}

test_grandfathered_file_is_never_enforced() {
  local rc=0
  bash "$GATE" "$GRANDFATHERED" > /dev/null 2>&1 || rc=$?
  assert_rc 0 "$rc" 'a grandfathered record is never enforced'
}

test_the_seam_flags_only_when_enforced() {
  local exempt_rc=0 enforced_rc=0 enforced_out
  (cd "$REPO_ROOT" && markdownlint-cli2 "$LEGACY_WITH_DEBT" > /dev/null 2>&1) || exempt_rc=$?
  enforced_out="$(cd "$REPO_ROOT" && DOC_WRAP_ENFORCE="$LEGACY_WITH_DEBT" markdownlint-cli2 "$LEGACY_WITH_DEBT" 2>&1)" || enforced_rc=$?
  assert_rc 0 "$exempt_rc" 'the tree-wide run exempts the file'
  assert_rc 1 "$enforced_rc" 'and the enforcement list flags it'
  assert_contains "$enforced_out" 'one physical line' 'the rule reports the wrap'
}

run_test test_unstaged_run_is_clean
run_test test_touched_legacy_file_fails
run_test test_touched_clean_file_passes
run_test test_grandfathered_file_is_never_enforced
run_test test_the_seam_flags_only_when_enforced

test_done

#!/usr/bin/env bash
# TEST_DEADLINE: 30
# tests/test_record_citations.sh
# Behavioural tests for `scripts/check_record_citations.sh`, the project gate
# that resolves a roadmap's dated record citations. The history-cleanup audit
# runs this gate at each commit; the gate itself checks the tree it is given.
#
# Covers:
#   a missing citation                      -- finding
#   an existing citation                    -- clean
#   a citation with a fragment             -- resolves to its file
#   an absent roadmap                       -- skipped, clean
#
# Run:   bash tests/test_record_citations.sh
# Exit:  0 = all passed, non-zero = failure count

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/.." && pwd)"
GATE="$REPO_ROOT/scripts/check_record_citations.sh"

# shellcheck source=libs/test_common.sh
source "$TEST_DIR/libs/test_common.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

new_repo() {
  local d="$1"
  mkdir -p "$d/devlog/handovers/M" || return 1
  printf '# roadmap\n' >"$d/devlog/roadmap.md"
}

gate() {
  local d="$1"
  ( cd "$d" && bash "$GATE" --root="$d" )
}

test_a_missing_citation_is_named() {
  local d="$WORK/missing" out rc=0
  new_repo "$d" || fail "fixture"
  printf '| row | [a](handovers/M/20260101-01-a.md) |\n' >>"$d/devlog/roadmap.md"
  out=$(gate "$d") || rc=$?
  assert_rc 1 "$rc" "rc"
  assert_contains "$out" "citation does not resolve" "the gate names the missing citation"
}

test_an_existing_citation_passes() {
  local d="$WORK/ok" out rc=0
  new_repo "$d" || fail "fixture"
  printf '# a\n' >"$d/devlog/handovers/M/20260101-01-a.md"
  printf '| row | [a](handovers/M/20260101-01-a.md) |\n' >>"$d/devlog/roadmap.md"
  out=$(gate "$d") || rc=$?
  assert_rc 0 "$rc" "rc"
  assert_contains "$out" "Clean" "the clean citation passes"
}

test_an_anchor_resolves_to_its_file() {
  local d="$WORK/anchor" out rc=0
  new_repo "$d" || fail "fixture"
  printf '# a\n' >"$d/devlog/handovers/M/20260101-02-b.md"
  printf '| row | [b](handovers/M/20260101-02-b.md#the-record) |\n' >>"$d/devlog/roadmap.md"
  out=$(gate "$d") || rc=$?
  assert_rc 0 "$rc" "rc"
  assert_contains "$out" "Clean" "a fragment resolves to its file"
}

test_an_absent_roadmap_is_skipped() {
  local d="$WORK/absent" out rc=0
  mkdir -p "$d" || fail "fixture"
  out=$(gate "$d") || rc=$?
  assert_rc 0 "$rc" "rc"
  assert_contains "$out" "Clean" "no roadmap is a skip, not a finding"
}

run_test test_a_missing_citation_is_named
run_test test_an_existing_citation_passes
run_test test_an_anchor_resolves_to_its_file
run_test test_an_absent_roadmap_is_skipped

test_done record_citations

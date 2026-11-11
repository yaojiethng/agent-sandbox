#!/usr/bin/env bash
# TEST_DEADLINE: 120
# tests/test_history_cleanup_audit.sh
# Behavioural tests for the history-cleanup audit,
# workflow/coding-agent/skills/history-cleanup/scripts/audit.sh.
#
# The failure this covers: the audit's checks were run by hand, five passes in a
# row, and each pass found one more class of defect the pass before had missed.
# A check that has never failed is not a check, so every check is given a range
# built to violate it, and the clean range is given the same audit to prove the
# findings are not the default answer.
#
# Covers:
#   a record rewritten after its birth      -- finding, check 1
#   a roadmap link to a missing record      -- finding, check 2
#   a path added then deleted in the range  -- finding, check 3
#   an empty commit                         -- finding, check 6
#   a commit whose own gate fails           -- finding, check 5
#   a manifest row whose subject is wrong   -- finding, check 7
#   a clean range                           -- rc 0, no finding
#
# Run:   bash tests/test_history_cleanup_audit.sh
# Exit:  0 = all passed, non-zero = failure count

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/.." && pwd)"
AUDIT="$REPO_ROOT/workflow/coding-agent/skills/history-cleanup/scripts/audit.sh"

# shellcheck source=libs/test_common.sh
source "$TEST_DIR/libs/test_common.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# new_repo DIR  --  a repo whose gate always passes, one base commit, nothing else.
new_repo() {
  local d="$1"
  mkdir -p "$d" || return 1
  (
    cd "$d" || return 1
    git init -q .
    git config user.email t@example.com
    git config user.name t
    printf '#!/bin/sh\nexit 0\n' >gate.sh
    chmod +x gate.sh
    mkdir -p devlog/handovers/M
    printf '# roadmap\n' >devlog/roadmap.md
    git add -A
    git commit -qm "base"
  )
}

audit() {
  local d="$1"
  shift
  ( cd "$d" && bash "$AUDIT" "$@" )
}

test_a_record_rewritten_after_birth_is_named() {
  local d="$WORK/rec" out rc=0
  new_repo "$d" || fail "fixture"
  (
    cd "$d" || exit 1
    printf '# a\n' >devlog/handovers/M/20260101-01-a.md
    git add -A && git commit -qm "add record a"
    printf 'more\n' >>devlog/handovers/M/20260101-01-a.md
    git add -A && git commit -qm "rewrite record a"
  ) || fail "fixture commits"
  out=$(audit "$d" "$(git -C "$d" rev-list --max-parents=0 HEAD)" HEAD --gate=gate.sh) || rc=$?
  assert_rc 1 "$rc" "rc"
  assert_contains "$out" "record rewritten after birth" "check 1 names the record"
}

test_a_missing_citation_is_named() {
  local d="$WORK/cite" out rc=0
  new_repo "$d" || fail "fixture"
  (
    cd "$d" || exit 1
    printf '| row | [b](handovers/M/20260101-02-b.md) |\n' >>devlog/roadmap.md
    git add -A && git commit -qm "cite a missing record"
  ) || fail "fixture commit"
  out=$(audit "$d" "$(git -C "$d" rev-list --max-parents=0 HEAD)" HEAD --gate=gate.sh) || rc=$?
  assert_rc 1 "$rc" "rc"
  assert_contains "$out" "citation does not resolve" "check 2 names the link"
}

test_a_path_born_and_buried_is_named() {
  local d="$WORK/buried" out rc=0
  new_repo "$d" || fail "fixture"
  (
    cd "$d" || exit 1
    printf 'x\n' >tmp.txt
    git add -A && git commit -qm "add tmp"
    git rm -q tmp.txt && git commit -qm "delete tmp"
  ) || fail "fixture commits"
  out=$(audit "$d" "$(git -C "$d" rev-list --max-parents=0 HEAD)" HEAD --gate=gate.sh) || rc=$?
  assert_rc 1 "$rc" "rc"
  assert_contains "$out" "added then deleted inside the range" "check 3 names the path"
}

test_an_empty_commit_is_named() {
  local d="$WORK/empty" out rc=0
  new_repo "$d" || fail "fixture"
  ( cd "$d" && git commit -q --allow-empty -m "empty" ) || fail "fixture commit"
  out=$(audit "$d" "$(git -C "$d" rev-list --max-parents=0 HEAD)" HEAD --gate=gate.sh) || rc=$?
  assert_rc 1 "$rc" "rc"
  assert_contains "$out" "empty commit" "check 6 names the commit"
}

test_a_failing_gate_is_named() {
  local d="$WORK/gate" out rc=0
  new_repo "$d" || fail "fixture"
  (
    cd "$d" || exit 1
    printf '#!/bin/sh\nexit 1\n' >gate.sh
    git add -A && git commit -qm "break the gate"
  ) || fail "fixture commit"
  out=$(audit "$d" "$(git -C "$d" rev-list --max-parents=0 HEAD)" HEAD --gate=gate.sh) || rc=$?
  assert_rc 1 "$rc" "rc"
  assert_contains "$out" "gate fails at" "check 5 names the commit"
}

test_a_manifest_subject_that_differs_is_named() {
  local d="$WORK/manifest" out rc=0 sha
  new_repo "$d" || fail "fixture"
  (
    cd "$d" || exit 1
    printf '# a\n' >devlog/handovers/M/20260101-03-c.md
    git add -A && git commit -qm "add record c"
  ) || fail "fixture commit"
  sha=$(git -C "$d" rev-parse HEAD)
  printf '%s\t%s\t%s\n' "$sha" "a subject the commit does not have" "devlog/roadmap.md" >"$WORK/manifest.tsv"
  out=$(audit "$d" "$(git -C "$d" rev-list --max-parents=0 HEAD)" HEAD --gate=gate.sh --manifest="$WORK/manifest.tsv") || rc=$?
  assert_rc 1 "$rc" "rc"
  assert_contains "$out" "manifest subject differs" "check 7 names the row"
}

test_a_clean_range_reports_clean() {
  local d="$WORK/clean" out rc=0
  new_repo "$d" || fail "fixture"
  (
    cd "$d" || exit 1
    printf '# a\n' >devlog/handovers/M/20260101-04-d.md
    printf '| row | [d](handovers/M/20260101-04-d.md) |\n' >>devlog/roadmap.md
    git add -A && git commit -qm "add record d and cite it"
  ) || fail "fixture commit"
  out=$(audit "$d" "$(git -C "$d" rev-list --max-parents=0 HEAD)" HEAD --gate=gate.sh) || rc=$?
  assert_rc 0 "$rc" "rc"
  assert_contains "$out" "audit: clean" "the clean range passes"
}

test_a_reference_that_differs_is_named() {
  local d="$WORK/ref" out rc=0 base
  new_repo "$d" || fail "fixture"
  base=$(git -C "$d" rev-list --max-parents=0 HEAD)
  (
    cd "$d" || exit 1
    printf 'changed\n' >>gate.sh
    git add -A && git commit -qm "change a non-record file"
  ) || fail "fixture commit"
  git -C "$d" tag reference-tip "$base"
  out=$(audit "$d" "$base" HEAD --gate=gate.sh --reference=reference-tip) || rc=$?
  assert_rc 1 "$rc" "rc"
  assert_contains "$out" "non-record content differs" "check 4 names the difference"
}

test_an_inversion_is_reported_not_counted() {
  local d="$WORK/inv" out rc=0
  new_repo "$d" || fail "fixture"
  (
    cd "$d" || exit 1
    printf 'a line long enough to clear the floor\n' >notes.txt
    git add -A && git commit -qm "add a line"
    printf 'replacement line that is also long enough\n' >notes.txt
    git add -A && git commit -qm "replace the line"
  ) || fail "fixture commits"
  out=$(audit "$d" "$(git -C "$d" rev-list --max-parents=0 HEAD)" HEAD --gate=gate.sh) || rc=$?
  assert_rc 0 "$rc" "an inversion is not a finding"
  assert_contains "$out" "total 1 line(s)" "check 8 reports the inversion"
}

run_test test_a_record_rewritten_after_birth_is_named
run_test test_a_missing_citation_is_named
run_test test_a_path_born_and_buried_is_named
run_test test_an_empty_commit_is_named
run_test test_a_failing_gate_is_named
run_test test_a_manifest_subject_that_differs_is_named
run_test test_a_clean_range_reports_clean
run_test test_a_reference_that_differs_is_named
run_test test_an_inversion_is_reported_not_counted

test_done

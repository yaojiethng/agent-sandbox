#!/usr/bin/env bash
# TEST_DEADLINE: 120
# tests/test_history_cleanup_audit.sh
# Behavioural tests for the history-cleanup audit,
# workflow/coding-agent/skills/git-discipline/runbooks/history-cleanup/scripts/audit.sh.
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
#   a non-record change at the tip          -- finding, check 4
#   a record-only change at the tip         -- clean, check 4 excludes it
#   a record change in each record tree     -- clean, check 4 excludes all of them
#   a record root not named                 -- clean, check 1 skipped
#   a roadmap change with no task-list paths -- finding, check 4 treats it as content
#   an addition that does not cover a change -- finding, check 4 still runs
#   a clean range                           -- rc 0, no finding
#
# Run:   bash tests/test_history_cleanup_audit.sh
# Exit:  0 = all passed, non-zero = failure count

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/.." && pwd)"
AUDIT="$REPO_ROOT/workflow/coding-agent/skills/git-discipline/runbooks/history-cleanup/scripts/audit.sh"

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

test_a_record_change_at_the_tip_is_excluded() {
  local d="$WORK/record" out rc=0 base
  new_repo "$d" || fail "fixture"
  base=$(git -C "$d" rev-list --max-parents=0 HEAD)
  (
    cd "$d" || exit 1
    printf '# a\n' >devlog/handovers/M/20260101-05-e.md
    git add -A && git commit -qm "add record e"
  ) || fail "fixture commit"
  out=$(audit "$d" "$base" HEAD --gate=gate.sh --reference="$base") || rc=$?
  assert_rc 0 "$rc" "a record-only change is not a finding"
  assert_contains "$out" "audit: clean" "check 4 excludes the record path"
}

# Given: a base that carries every record tree
# When:  the tip changes only those records
# Then:  check 4 excludes all of them and the range is clean
test_a_record_change_in_each_record_tree_is_excluded() {
  local d="$WORK/records" out rc=0 base
  new_repo "$d" || fail "fixture"
  (
    cd "$d" || exit 1
    mkdir -p devlog/discussions
    printf '# future\n' >devlog/roadmap_future.md
    printf '# feedback\n' >devlog/AGENT_FEEDBACK.md
    printf '# changelog\n' >devlog/changelog.md
    printf '# discussion\n' >devlog/discussions/x.md
    git add -A && git commit -q --amend -m base
  ) || fail "fixture base"
  base=$(git -C "$d" rev-list --max-parents=0 HEAD)
  (
    cd "$d" || exit 1
    for f in devlog/roadmap.md devlog/roadmap_future.md \
      devlog/AGENT_FEEDBACK.md devlog/changelog.md devlog/discussions/x.md; do
      printf 'more\n' >>"$f"
    done
    git add -A && git commit -qm "update records"
  ) || fail "fixture commit"
  out=$(audit "$d" "$base" HEAD --gate=gate.sh --reference="$base") || rc=$?
  assert_rc 0 "$rc" "a record-only change in each tree is not a finding"
  assert_contains "$out" "audit: clean" "check 4 excludes the roadmaps, feedback, discussions and changelog"
}

# Given: a record range with no record root named
# When:  the audit runs with --records=
# Then:  check 1 is skipped and the range is clean
test_no_record_root_skips_check_1() {
  local d="$WORK/norecords" out rc=0
  new_repo "$d" || fail "fixture"
  (
    cd "$d" || exit 1
    printf '# a\n' >devlog/handovers/M/20260101-07-g.md
    git add -A && git commit -qm "add record g"
    printf 'more\n' >>devlog/handovers/M/20260101-07-g.md
    git add -A && git commit -qm "rewrite record g"
  ) || fail "fixture commits"
  out=$(audit "$d" "$(git -C "$d" rev-list --max-parents=0 HEAD)" HEAD --gate=gate.sh --records= --record-paths=) || rc=$?
  assert_rc 0 "$rc" "rc"
  assert_contains "$out" "skipped: no record root" "check 1 names the skip"
}

# Given: a roadmap change at the tip and no task-list record paths
# When:  check 4 runs with --record-paths=
# Then:  the roadmap is content and the difference is a finding
test_no_record_paths_keeps_the_roadmap_as_content() {
  local d="$WORK/nopaths" out rc=0 base
  new_repo "$d" || fail "fixture"
  base=$(git -C "$d" rev-list --max-parents=0 HEAD)
  (
    cd "$d" || exit 1
    printf 'more\n' >>devlog/roadmap.md
    git add -A && git commit -qm "update the roadmap"
  ) || fail "fixture commit"
  out=$(audit "$d" "$base" HEAD --gate=gate.sh --reference="$base" --record-paths=) || rc=$?
  assert_rc 1 "$rc" "rc"
  assert_contains "$out" "non-record content differs" "check 4 treats the roadmap as content"
}

# Given: a non-record change and an addition that does not name it
# When:  check 4 runs
# Then:  it reports the change; naming the change as an addition is clean
test_an_addition_does_not_disable_the_content_check() {
  local d="$WORK/addition" out rc=0 base
  new_repo "$d" || fail "fixture"
  base=$(git -C "$d" rev-list --max-parents=0 HEAD)
  (
    cd "$d" || exit 1
    printf 'new content\n' >notes.txt
    git add -A && git commit -qm "add notes"
  ) || fail "fixture commit"
  out=$(audit "$d" "$base" HEAD --gate=gate.sh --reference="$base" --addition=other.txt) || rc=$?
  assert_rc 1 "$rc" "an addition that does not name the change leaves check 4 running"
  assert_contains "$out" "non-record content differs" "check 4 reports the change"
  rc=0
  out=$(audit "$d" "$base" HEAD --gate=gate.sh --reference="$base" --addition=notes.txt) || rc=$?
  assert_rc 0 "$rc" "an addition that names the change is excluded"
  assert_contains "$out" "audit: clean" "check 4 excludes the named addition"
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
run_test test_a_record_change_at_the_tip_is_excluded
run_test test_a_record_change_in_each_record_tree_is_excluded
run_test test_no_record_root_skips_check_1
run_test test_no_record_paths_keeps_the_roadmap_as_content
run_test test_an_addition_does_not_disable_the_content_check
run_test test_an_inversion_is_reported_not_counted

test_done

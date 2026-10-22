#!/usr/bin/env bash
# Tests for the history-cleanup detector, `scripts/inversions.mjs` in the skill.
#
# The detector reads a commit range and reports every ordered pair where a later
# commit removes a content line an earlier one added. Its two traps are silent:
# a detector that cannot match a line and a range with no inversion print the
# same report. A fixture whose inversion is known before the run is what
# separates them, so every case below builds its own commits.
#
# Covers:
#   inversion  --  a line written then removed inside the range names both commits
#   deletion   --  a file added then deleted whole names both commits
#   floor      --  a line under the eight-character floor is not reported
#   clean      --  a range that holds no inversion reports "none", and a pair is
#                 compared only when both its commits sit inside the range

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DETECTOR="$REPO_ROOT/workflow/coding-agent/skills/history-cleanup/scripts/inversions.mjs"

# The fixture repository. Git runs through `-C` rather than a `cd`, so the
# calling shell never leaves the real repository behind.
FIXTURE_REPO="$FIXTURE_DIR/repo"
make_fixture() {
  mkdir -p "$FIXTURE_REPO"
  git -C "$FIXTURE_REPO" init -q
  commit() {
    git -C "$FIXTURE_REPO" add -A
    git -C "$FIXTURE_REPO" -c user.email=t@example.com -c user.name=t commit -q -m "$1"
  }

  printf 'base line of prose\n' > "$FIXTURE_REPO/base.md"
  commit "zero"
  C0="$(git -C "$FIXTURE_REPO" rev-parse --short HEAD)"

  printf 'alpha line of prose\nbeta line of prose\ntiny\n' > "$FIXTURE_REPO/notes.md"
  commit "one"
  C1="$(git -C "$FIXTURE_REPO" rev-parse --short HEAD)"

  printf 'gamma line of prose\nbeta line of prose\n' > "$FIXTURE_REPO/notes.md"
  commit "two"
  C2="$(git -C "$FIXTURE_REPO" rev-parse --short HEAD)"

  printf 'delta line of prose\n' > "$FIXTURE_REPO/gone.md"
  commit "three"
  C3="$(git -C "$FIXTURE_REPO" rev-parse --short HEAD)"

  git -C "$FIXTURE_REPO" rm -q gone.md
  commit "four"
  C4="$(git -C "$FIXTURE_REPO" rev-parse --short HEAD)"
}

# detect BASE TIP  --  run the detector over a range and set DETECT_OUT
detect() {
  DETECT_OUT="$(cd "$FIXTURE_REPO" && VERBOSE=1 node "$DETECTOR" "$1" "$2" 2>&1)"
  DETECT_RC=$?
}

test_inversion() {
  detect "$C0" "$C2"
  assert_rc 0 "$DETECT_RC" "the detector exits 0"
  assert_contains "$DETECT_OUT" "$C1 -> $C2" "the pair is named by both commits"
  assert_contains "$DETECT_OUT" "notes.md" "the file is named"
  assert_contains "$DETECT_OUT" "alpha line of prose" "the replaced line is named in full"
}

test_deletion() {
  detect "$C2" "$C4"
  assert_rc 0 "$DETECT_RC" "the detector exits 0"
  assert_contains "$DETECT_OUT" "$C3 -> $C4" "a file added then deleted names both commits"
  assert_contains "$DETECT_OUT" "gone.md" "the deleted file is named"
  assert_contains "$DETECT_OUT" "delta line of prose" "the deleted line is named in full"
}

test_floor() {
  detect "$C0" "$C2"
  assert_not_contains "$DETECT_OUT" "tiny" "a line under the floor is not reported"
}

test_clean() {
  detect "$C1" "$C2"
  assert_rc 0 "$DETECT_RC" "the detector exits 0 on a clean range"
  assert_contains "$DETECT_OUT" "none" "a write outside the range is not paired with its removal inside it"
  detect "$C3" "$C4"
  assert_contains "$DETECT_OUT" "none" "a range holding one commit of a pair reports none"
}

make_fixture
run_test test_inversion
run_test test_deletion
run_test test_floor
run_test test_clean

test_done "history-cleanup detector"

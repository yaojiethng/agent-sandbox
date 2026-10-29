#!/usr/bin/env bash
# TEST_DEADLINE: 60
# tests/test_eval_fixtures.sh
# Behavioural tests for scripts/check_eval_fixtures.sh, the gate that holds a
# frozen eval fixture to its SHA256SUMS manifest.
#
# The failure this gate exists for: a find and replace across the tree rewrites
# a frozen `.orig` fixture, every test stays green, and the eval later grades a
# different subject than the one its case was built on. Text files announce
# nothing, so the manifest is the only thing that can notice.
#
# Covers:
#   a conforming fixture                    --  rc 0
#   a frozen file edited in place           --  rc 1; the file is named as changed
#   a frozen file removed                   --  rc 1; the file is named as missing
#   a file added to a fixture subdirectory  --  rc 1; the file is named as unnamed
#   a file at the fixture root              --  rc 0; the fixture's own description
#                                              is not a frozen subject
#   a fixture directory with no manifest    --  rc 1; the directory is named
#   a root that is not there                --  rc 2
#   this repository's own fixtures          --  rc 0, so the shipped set is held
#
# Fixtures are built under $FIXTURE_DIR and the scan is pointed at them with
# EVAL_FIXTURE_ROOT, so this repository's own fixtures are never rewritten.
#
# Run:   bash tests/test_eval_fixtures.sh
# Exit:  0 = all passed, non-zero = failure count

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/.." && pwd)"

source "$TEST_DIR/libs/test_common.sh"
test_setup

GATE="$REPO_ROOT/scripts/check_eval_fixtures.sh"

# new_root  --  a fixture root, empty.
new_root() {
  get_fixture_dir
}

# write_fixture ROOT  --  one sealed fixture: a payload archive and its one-line pin.
write_fixture() {
  local root="$1"
  mkdir -p "$root/case1/src/room"
  printf 'frozen text\n' >"$root/case1/src/room/a.md.orig"
  ( cd "$root/case1/src" && tar --sort=name --mtime='@0' --owner=0 --group=0 \
      --numeric-owner -cf - room | gzip -n ) >"$root/case1/payload.tar.gz"
  rm -rf "$root/case1/src"
  ( cd "$root/case1" && sha256sum payload.tar.gz >SHA256SUMS )
  printf '# the fixture\n' >"$root/case1/README.md"
  printf 'provenance\n' >"$root/case1/SOURCES.md"
}

run_gate() {
  RUN_OUT="$(EVAL_FIXTURE_ROOT="$1" bash "$GATE" 2>&1)"
  RUN_RC=$?
}

test_conforming_fixture_is_clean() {
  local root; root="$(new_root)"
  write_fixture "$root"
  run_gate "$root"
  assert_rc 0 "$RUN_RC" "a fixture matching its manifest passes"
  assert_contains "$RUN_OUT" "clean across 1 fixture" "the count is reported"
}

test_an_edited_frozen_file_is_named() {
  local root; root="$(new_root)"
  write_fixture "$root"
  printf 'rewritten\n' >>"$root/case1/payload.tar.gz"
  run_gate "$root"
  assert_rc 1 "$RUN_RC" "a rewritten archive fails"
  assert_contains "$RUN_OUT" "CHANGED" "the finding is a change"
  assert_contains "$RUN_OUT" "case1/payload.tar.gz" "the archive is named"
}

test_a_removed_frozen_file_is_named() {
  local root; root="$(new_root)"
  write_fixture "$root"
  rm "$root/case1/payload.tar.gz"
  run_gate "$root"
  assert_rc 1 "$RUN_RC" "a missing archive fails"
  assert_contains "$RUN_OUT" "MISSING" "the finding is an absence"
}

test_an_unlisted_file_in_a_subdirectory_is_named() {
  local root; root="$(new_root)"
  write_fixture "$root"
  mkdir -p "$root/case1/room"
  printf 'loose\n' >"$root/case1/room/b.md.orig"
  run_gate "$root"
  assert_rc 1 "$RUN_RC" "a loose file beside the archive has no provenance"
  assert_contains "$RUN_OUT" "UNNAMED" "the finding is unnamed"
  assert_contains "$RUN_OUT" "case1/room/b.md.orig" "the file is named"
}

test_a_root_file_is_not_a_frozen_subject() {
  local root; root="$(new_root)"
  write_fixture "$root"
  run_gate "$root"
  assert_rc 0 "$RUN_RC" "the fixture's own description is read, not hashed"
}

test_a_fixture_without_a_manifest_is_named() {
  local root; root="$(new_root)"
  write_fixture "$root"
  mkdir -p "$root/case2"
  printf 'nothing holds me\n' >"$root/case2/payload.tar.gz"
  run_gate "$root"
  assert_rc 1 "$RUN_RC" "an unhashed fixture fails"
  assert_contains "$RUN_OUT" "NOMANIFEST" "the finding is the absence of a manifest"
  assert_contains "$RUN_OUT" "case2" "the directory is named"
}

test_a_missing_root_is_refused() {
  local out rc
  out="$(EVAL_FIXTURE_ROOT="$FIXTURE_DIR/nope" bash "$GATE" 2>&1)"
  rc=$?
  assert_rc 2 "$rc" "a root that is not there is a usage error"
  assert_contains "$out" "no such fixture root" "the reason is named"
}

test_the_repository_fixtures_are_clean() {
  local out rc
  out="$(bash "$GATE" 2>&1)"
  rc=$?
  assert_rc 0 "$rc" "the shipped fixtures match their manifests"
  assert_contains "$out" "clean across" "the run reports a count"
}

run_test test_conforming_fixture_is_clean
run_test test_an_edited_frozen_file_is_named
run_test test_a_removed_frozen_file_is_named
run_test test_an_unlisted_file_in_a_subdirectory_is_named
run_test test_a_root_file_is_not_a_frozen_subject
run_test test_a_fixture_without_a_manifest_is_named
run_test test_a_missing_root_is_refused
run_test test_the_repository_fixtures_are_clean

test_done

#!/usr/bin/env bash
# TEST_DEADLINE: 60
# tests/test_build_context_gate.sh  --  the build-context gate's branches.
#
# The COPY-contract test in tests/test_build_context.sh is a different subject:
# it asserts that every COPY source exists. This file asserts that the context
# and the manifest's declared inputs agree.
#
# Each test builds a fixture outside the repo tree and points the gate at it
# with BUILD_CONTEXT_SCAN_ROOT, so the repository's own context is never the
# subject.
#
# Run:   bash tests/test_build_context_gate.sh
# Exit:  0 = all passed, non-zero = failure count

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup

GATE="$REPO_ROOT/scripts/check_build_context.sh"

# write_fixture ROOT  --  one manifest source, one ignored dir, one manifest
write_fixture() {
  local root="$1"
  mkdir -p "$root/src/build" "$root/src/a" "$root/src/b"
  printf '{"image":[{"source":"src/a/","destination":"/x"}]}\n' > "$root/src/build/container-interface.json"
  printf 'src/b/\nsrc/build/\n' > "$root/.dockerignore"
  printf 'x' > "$root/src/a/x"
  printf 'y' > "$root/src/b/y"
}

# run_gate  --  the wrapper against the fixture; RUN_OUT and RUN_RC
run_gate() {
  RUN_OUT="$(BUILD_CONTEXT_SCAN_ROOT="$FIXTURE_DIR" bash "$GATE" 2>&1)"
  RUN_RC=$?
}

test_a_conforming_context_is_clean_and_reports_its_size() {
  write_fixture "$FIXTURE_DIR"
  run_gate
  assert_rc 0 "$RUN_RC" "the declared inputs and the ignore file agree"
  assert_contains "$RUN_OUT" "Context: 2 files, 19 bytes" "the check reports the context's files and bytes"
}

test_an_excluded_source_is_a_finding() {
  write_fixture "$FIXTURE_DIR"
  printf 'src/a/\n' >> "$FIXTURE_DIR/.dockerignore"
  run_gate
  assert_rc 1 "$RUN_RC" "an excluded source fails the gate"
  assert_contains "$RUN_OUT" "Finding: the context excludes the manifest source src/a" "the excluded source is named"
}

test_an_included_path_no_source_owns_is_a_finding() {
  write_fixture "$FIXTURE_DIR"
  mkdir -p "$FIXTURE_DIR/src/c"
  printf 'z' > "$FIXTURE_DIR/src/c/z"
  run_gate
  assert_rc 1 "$RUN_RC" "an unowned path fails the gate"
  assert_contains "$RUN_OUT" "Finding: the context includes src/c/z, which no manifest source owns" "the unowned path is named"
}

test_a_dockerfile_is_exempt_and_included() {
  write_fixture "$FIXTURE_DIR"
  mkdir -p "$FIXTURE_DIR/src/x"
  printf 'z' > "$FIXTURE_DIR/src/x/base.dockerfile"
  run_gate
  assert_rc 0 "$RUN_RC" "a dockerfile no source owns is not a finding"
  assert_contains "$RUN_OUT" "Context: 3 files, 20 bytes" "the dockerfile is part of the context's size"
}

test_a_negated_pattern_reincludes_one_file() {
  write_fixture "$FIXTURE_DIR"
  printf 'k' > "$FIXTURE_DIR/src/a/keep"
  printf 'src/a/\n!src/a/keep\n' >> "$FIXTURE_DIR/.dockerignore"
  run_gate
  assert_rc 0 "$RUN_RC" "the negated pattern keeps the source alive"
  assert_contains "$RUN_OUT" "Context: 2 files, 38 bytes" "only the kept file and the ignore file are counted"
}

test_a_missing_ignore_file_fails_closed() {
  write_fixture "$FIXTURE_DIR"
  rm "$FIXTURE_DIR/.dockerignore"
  run_gate
  assert_rc 1 "$RUN_RC" "a missing ignore file fails the gate"
  assert_contains "$RUN_OUT" "Finding: the ignore file .dockerignore is missing" "the missing file is named"
}

test_an_unsupported_pattern_is_a_finding() {
  write_fixture "$FIXTURE_DIR"
  printf '*.log\n' >> "$FIXTURE_DIR/.dockerignore"
  run_gate
  assert_rc 1 "$RUN_RC" "a glob the gate cannot evaluate fails it"
  assert_contains "$RUN_OUT" "Finding: the ignore pattern *.log is not a path prefix" "the unsupported pattern is named"
}

# Given: a manifest with a `build` row whose source the context carries but no
#        image copies
# When:  the gate runs
# Then:  the path is owned, because the builder reads it
# Asserts: a build-only input is declared rather than left unowned
test_a_build_source_is_owned() {
  write_fixture "$FIXTURE_DIR"
  mkdir -p "$FIXTURE_DIR/src/reg"
  printf 'z' > "$FIXTURE_DIR/src/reg/lock.json"
  printf '{"image":[{"source":"src/a/","destination":"/x"}],"build":[{"source":"src/reg/"}]}\n' \
    > "$FIXTURE_DIR/src/build/container-interface.json"
  run_gate
  assert_rc 0 "$RUN_RC" "a build source owns its paths"
  assert_contains "$RUN_OUT" "Context: 3 files" "the build source is in the context"
}

# Given: the same fixture with the build row removed
# When:  the gate runs
# Then:  the same path is a finding, so the row is what makes it owned
# Asserts: the positive check's paired negative
test_without_the_build_row_the_same_path_is_unowned() {
  write_fixture "$FIXTURE_DIR"
  mkdir -p "$FIXTURE_DIR/src/reg"
  printf 'z' > "$FIXTURE_DIR/src/reg/lock.json"
  run_gate
  assert_rc 1 "$RUN_RC" "the same path is unowned without the row"
  assert_contains "$RUN_OUT" "which no manifest source owns" "the unowned path is named"
}

# Given: a Dockerfile no manifest row mentions, whose COPY reads a path the
#        ignore file excludes
# When:  the gate runs
# Then:  the path is a finding, named with the Dockerfile that reads it
# Asserts: a second build sharing the context cannot be broken by the ignore
#          file, which is what happened when the capability image is built
test_a_dockerfile_copy_source_is_owned() {
  write_fixture "$FIXTURE_DIR"
  mkdir -p "$FIXTURE_DIR/src/cap" "$FIXTURE_DIR/src/x"
  printf 'z' > "$FIXTURE_DIR/src/cap/entry.sh"
  printf 'COPY src/cap/ /opt/cap/\n' > "$FIXTURE_DIR/src/x/dockerfile"
  printf 'src/cap/\n' >> "$FIXTURE_DIR/.dockerignore"
  run_gate
  assert_rc 1 "$RUN_RC" "an excluded COPY source fails the gate"
  assert_contains "$RUN_OUT" "the context excludes src/cap, which src/x/dockerfile copies" "the Dockerfile is named"
}

# Given: the same Dockerfile, with its COPY source kept in the context
# When:  the gate runs
# Then:  the source is owned and the Dockerfile is exempt from being owned
# Asserts: the COPY line widens the owner set, and needs no manifest row
test_a_dockerfile_copy_source_owns_its_path() {
  write_fixture "$FIXTURE_DIR"
  mkdir -p "$FIXTURE_DIR/src/cap" "$FIXTURE_DIR/src/x"
  printf 'z' > "$FIXTURE_DIR/src/cap/entry.sh"
  printf 'COPY src/cap/ /opt/cap/\n' > "$FIXTURE_DIR/src/x/dockerfile"
  run_gate
  assert_rc 0 "$RUN_RC" "the COPY source is owned without a manifest row"
  assert_contains "$RUN_OUT" "Context: 4 files" "the Dockerfile and its source are both in the context"
}

# Given: a COPY from another build stage and one of `.`
# When:  the gate runs
# Then:  neither claims a context path: `--from` reads a stage, `.` would own the
#        whole tree
# Asserts: the two sources that do not name a repository path are skipped
test_a_stage_copy_and_a_dot_source_do_not_own_the_tree() {
  write_fixture "$FIXTURE_DIR"
  mkdir -p "$FIXTURE_DIR/src/c" "$FIXTURE_DIR/src/x"
  printf 'z' > "$FIXTURE_DIR/src/c/z"
  printf 'COPY --from=build /out /app\nCOPY . /app\n' > "$FIXTURE_DIR/src/x/dockerfile"
  run_gate
  assert_rc 1 "$RUN_RC" "the unowned path is still a finding"
  assert_contains "$RUN_OUT" "the context includes src/c/z" "a dot source did not adopt the tree"
}

run_test test_a_conforming_context_is_clean_and_reports_its_size
run_test test_a_build_source_is_owned
run_test test_without_the_build_row_the_same_path_is_unowned
run_test test_an_excluded_source_is_a_finding
run_test test_an_included_path_no_source_owns_is_a_finding
run_test test_a_dockerfile_is_exempt_and_included
run_test test_a_dockerfile_copy_source_is_owned
run_test test_a_dockerfile_copy_source_owns_its_path
run_test test_a_stage_copy_and_a_dot_source_do_not_own_the_tree
run_test test_a_negated_pattern_reincludes_one_file
run_test test_a_missing_ignore_file_fails_closed
run_test test_an_unsupported_pattern_is_a_finding

test_done

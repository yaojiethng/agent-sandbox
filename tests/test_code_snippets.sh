#!/usr/bin/env bash
# TEST_DEADLINE: 60
# tests/test_code_snippets.sh
# Behavioural tests for scripts/check_code_snippets.sh, the gate that holds a
# documentation code block to the source it claims.
#
# The failure this gate exists for: a reference document copies a command list
# out of the Makefile template, the template moves on, and the document keeps
# teaching a command that aborts. Nothing about a fenced block announces that it
# is a copy, so nothing reads the copy back against its original.
#
# Covers:
#   a declared derived block matching its source  --  rc 0
#   a derived block whose source moved on         --  rc 1; STALE is named
#   a derived block naming no such file           --  rc 1; NOSOURCE is named
#   an illustrative block                         --  rc 0, with no source read
#   an undeclared block with no baseline entry    --  rc 1; UNDECLARED is named
#   an undeclared block the baseline holds        --  rc 0, and the count is reported
#   a baseline entry whose block is gone          --  rc 1; PRUNABLE is named
#   a marker naming an unknown kind               --  rc 1; UNKNOWN-KIND is named
#   --update                                      --  rewrites the baseline
#   a root with no baseline                       --  rc 2
#   this repository's own docs                    --  rc 0, so the shipped set is held
#
# Fixtures are built under a temp root and the scan is pointed at it with
# --root, so this repository's own documentation is never rewritten.
#
# Run:   bash tests/test_code_snippets.sh
# Exit:  0 = all passed, non-zero = failure count

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/.." && pwd)"

source "$TEST_DIR/libs/test_common.sh"
test_setup

GATE="$REPO_ROOT/scripts/check_code_snippets.sh"
LINT="$REPO_ROOT/scripts/lint/code-snippets.mjs"

# new_root  --  an empty tree shaped like the repository the gate reads.
new_root() {
  local root
  root="$(mktemp -d "$FIXTURE_ROOT/root.XXXXXX")"
  mkdir -p "$root/docs/reference" "$root/scripts/templates" "$root/scripts/lint"
  printf 'build:\n\t@echo building\nrelease:\n\t@echo releasing\n' >"$root/scripts/templates/Makefile.template"
  : >"$root/scripts/lint/code-snippets.baseline"
  printf '%s\n' "$root"
}

# write_doc ROOT BODY  --  a document at docs/reference/guide.md.
write_doc() {
  printf '%s\n' "$2" >"$1/docs/reference/guide.md"
}

run_gate() {
  RUN_OUT="$(bash "$GATE" --root "$1" 2>&1)"
  RUN_RC=$?
}

test_a_derived_block_matching_its_source_passes() {
  local root; root="$(new_root)"
  write_doc "$root" '<!-- snippet: derived scripts/templates/Makefile.template -->
```make
build:
	@echo building
```'
  run_gate "$root"
  assert_rc 0 "$RUN_RC" "a derived block still in its source passes"
  assert_contains "$RUN_OUT" "clean, 1 block(s)" "the block count is reported"
}

test_a_derived_block_whose_source_moved_on_fails() {
  local root; root="$(new_root)"
  write_doc "$root" '<!-- snippet: derived scripts/templates/Makefile.template -->
```make
deploy:
	@echo deploying
```'
  run_gate "$root"
  assert_rc 1 "$RUN_RC" "a derived block its source no longer holds fails"
  assert_contains "$RUN_OUT" "STALE" "the finding is named"
  assert_contains "$RUN_OUT" "scripts/templates/Makefile.template" "the source is named"
}

test_a_derived_block_naming_no_file_fails() {
  local root; root="$(new_root)"
  write_doc "$root" '<!-- snippet: derived scripts/gone.sh -->
```sh
echo gone
```'
  run_gate "$root"
  assert_rc 1 "$RUN_RC" "a derived block with no source file fails"
  assert_contains "$RUN_OUT" "NOSOURCE" "the finding is named"
}

test_an_illustrative_block_is_not_read_against_a_source() {
  local root; root="$(new_root)"
  write_doc "$root" '<!-- snippet: illustrative -->
```text
# <Title>
```'
  run_gate "$root"
  assert_rc 0 "$RUN_RC" "an illustrative block passes"
}

test_an_undeclared_block_fails() {
  local root; root="$(new_root)"
  write_doc "$root" '```make
build:
	@echo building
```'
  node "$LINT" --root "$root" --update >/dev/null 2>&1
  write_doc "$root" '```make
release:
	@echo releasing
```'
  run_gate "$root"
  assert_rc 1 "$RUN_RC" "a block added after the baseline fails"
  assert_contains "$RUN_OUT" "UNDECLARED" "the finding is named"
}

test_a_grandfathered_block_passes() {
  local root; root="$(new_root)"
  write_doc "$root" '```make
build:
	@echo building
```'
  node "$LINT" --root "$root" --update >/dev/null 2>&1
  run_gate "$root"
  assert_rc 0 "$RUN_RC" "a block the baseline holds passes"
  assert_contains "$RUN_OUT" "clean, 1 block(s)" "the block count is reported"
}

test_a_baseline_entry_with_no_block_is_prunable() {
  local root; root="$(new_root)"
  write_doc "$root" '```make
build:
	@echo building
```'
  node "$LINT" --root "$root" --update >/dev/null 2>&1
  write_doc "$root" '# a document with no code'
  run_gate "$root"
  assert_rc 1 "$RUN_RC" "a baseline entry with no block fails"
  assert_contains "$RUN_OUT" "PRUNABLE" "the finding is named"
}

test_an_unknown_kind_fails() {
  local root; root="$(new_root)"
  write_doc "$root" '<!-- snippet: copied from somewhere -->
```sh
echo hi
```'
  run_gate "$root"
  assert_rc 1 "$RUN_RC" "an unknown marker kind fails"
  assert_contains "$RUN_OUT" "UNKNOWN-KIND" "the finding is named"
}

test_update_rewrites_the_baseline() {
  local root; root="$(new_root)"
  write_doc "$root" '```make
build:
	@echo building
```'
  node "$LINT" --root "$root" --update >/dev/null 2>&1
  assert_file_exists "$root/scripts/lint/code-snippets.baseline" "the baseline is written"
  write_doc "$root" '```make
release:
	@echo releasing
```'
  node "$LINT" --root "$root" --update >/dev/null 2>&1
  run_gate "$root"
  assert_rc 0 "$RUN_RC" "an updated baseline covers the new block"
}

test_a_root_with_no_baseline_is_refused() {
  local root; root="$(new_root)"
  rm -f "$root/scripts/lint/code-snippets.baseline"
  write_doc "$root" '```sh
echo hi
```'
  run_gate "$root"
  assert_rc 2 "$RUN_RC" "a tree with no baseline is not graded"
  assert_contains "$RUN_OUT" "no baseline" "the missing baseline is named"
}

test_the_archive_is_not_read() {
  local root; root="$(new_root)"
  mkdir -p "$root/docs/adr/archive"
  printf '```sh\necho old\n```\n' >"$root/docs/adr/archive/20260101-adr-settled-old.md"
  write_doc "$root" '# a document with no code'
  node "$LINT" --root "$root" --update >/dev/null 2>&1
  run_gate "$root"
  assert_rc 0 "$RUN_RC" "a record's code block is not held to today's source"
  assert_contains "$RUN_OUT" "clean, 0 block(s)" "the archived block is not counted"
}

test_this_repository_is_clean() {
  RUN_OUT="$(cd "$REPO_ROOT" && bash scripts/check_code_snippets.sh 2>&1)"
  RUN_RC=$?
  assert_rc 0 "$RUN_RC" "the shipped docs pass their own gate"
}

run_test test_a_derived_block_matching_its_source_passes
run_test test_a_derived_block_whose_source_moved_on_fails
run_test test_a_derived_block_naming_no_file_fails
run_test test_an_illustrative_block_is_not_read_against_a_source
run_test test_an_undeclared_block_fails
run_test test_a_grandfathered_block_passes
run_test test_a_baseline_entry_with_no_block_is_prunable
run_test test_an_unknown_kind_fails
run_test test_update_rewrites_the_baseline
run_test test_a_root_with_no_baseline_is_refused
run_test test_the_archive_is_not_read
run_test test_this_repository_is_clean

test_done

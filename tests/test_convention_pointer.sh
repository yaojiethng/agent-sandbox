#!/usr/bin/env bash
# tests/test_convention_pointer.sh
# Behavioural test for the convention pointer: every `## Project conventions`
# section carries the one sentence that names where conventions live and what to
# do when one is missing.
#
# The rule exists because the sentence used to be a 239-character paragraph
# copied into every carrier. It is now one sentence, so the check is what keeps
# a new carrier from arriving with its own wording or with none.
#
# Covers:
#   the repository tree      -- every section carries the sentence
#   a section without it     -- named as an offender
#   a section with it        -- not named
#   a file with no section   -- never named

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/.." && pwd)"

source "$TEST_DIR/libs/test_common.sh"
test_setup

POINTER='Read each convention below at `.agents/skills/<name>/SKILL.md`; if one is missing or holds the seeded stub, raise it to the operator.'

# offenders ROOT -- print each file whose `## Project conventions` section does
# not carry the pointer sentence, as a path relative to ROOT.
offenders() {
  local root="$1" file
  while IFS= read -r file; do
    # A gate reads the repository, not the session scratch: a gitignored file is
    # part of no tree a review sees, and `.scratchpad/` holds throwaway drafts.
    if git -C "$root" check-ignore -q "$file" 2>/dev/null; then
      continue
    fi
    grep -qF "$POINTER" "$file" || printf '%s\n' "${file#"$root"/}"
  done < <(grep -rl '^## Project conventions$' --include='*.md' "$root" 2>/dev/null | sort)
}

# write_doc DIR NAME BODY -- one fixture document.
write_doc() {
  mkdir -p "$(dirname "$1/$2")"
  printf '%s\n' "$3" > "$1/$2"
}

test_repository_carries_the_pointer() {
  local out; out="$(offenders "$REPO_ROOT")"
  assert_empty "$out" "every Project conventions section carries the pointer"
}

test_missing_pointer_is_named() {
  local dir="$FIXTURE_DIR/tree"
  write_doc "$dir" "workflow/prompts/a.md" "## Project conventions

Read each convention at its own path, in whatever form the project keeps.

- \`task-list\`"
  local out; out="$(offenders "$dir")"
  assert_eq "$out" "workflow/prompts/a.md" "a section without the pointer is named"
}

test_present_pointer_passes() {
  local dir="$FIXTURE_DIR/tree2"
  write_doc "$dir" "workflow/prompts/b.md" "## Project conventions

$POINTER

- \`task-list\`"
  local out; out="$(offenders "$dir")"
  assert_empty "$out" "a section with the pointer is not named"
}

test_file_without_the_section_is_ignored() {
  local dir="$FIXTURE_DIR/tree3"
  write_doc "$dir" "docs/guide.md" "# Guide

A document that names no conventions."
  local out; out="$(offenders "$dir")"
  assert_empty "$out" "a document with no section is never named"
}

run_test test_repository_carries_the_pointer
run_test test_missing_pointer_is_named
run_test test_present_pointer_passes
run_test test_file_without_the_section_is_ignored

test_done convention_pointer

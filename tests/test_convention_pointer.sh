#!/usr/bin/env bash
# tests/test_convention_pointer.sh
# Behavioural test for the project-conventions block: every `## Project conventions`
# section points at the project's convention root, and states the branch that
# matters where those conventions are absent -- a shipped prompt or skill also
# runs in a project that keeps none of them.
#
# The wording is deliberately not pinned. The block carries sixteen copies of one
# sentence today, and a test that compares the sentence against its own copy
# keeps a copy rather than a rule. What a carrier can actually get wrong is
# omitting the block, dropping the path, or dropping the absent-conventions
# branch; those are what this checks, in any wording.
#
# Covers:
#   1. the repository's sections all carry the path and the branch
#   2. a section with no convention path is named
#   3. a section with no absent-conventions branch is named
#   4. a section carrying both passes
#   5. a document with no section is never named

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/.." && pwd)"

source "$TEST_DIR/libs/test_common.sh"
test_setup

# The project's convention root, as the skills name it.
CONVENTION_ROOT='.agents/skills/'
# Any wording of the absent-conventions branch carries one of these words.
ABSENT_BRANCH='missing|absent|stub'

# section_of FILE -- print the `## Project conventions` section of FILE.
section_of() {
  awk '
    /^## Project conventions$/ { inside = 1; print; next }
    inside && /^## / { exit }
    inside { print }
  ' "$1"
}

# offenders ROOT -- print each file whose section carries neither the convention
# path nor the absent-conventions branch, as a path relative to ROOT.
offenders() {
  local root="$1" file section
  while IFS= read -r file; do
    # A gate reads the repository, not the session scratch: a gitignored file is
    # part of no tree a review sees, and `.scratchpad/` holds throwaway drafts.
    if git -C "$root" check-ignore -q "$file" 2>/dev/null; then
      continue
    fi
    section="$(section_of "$file")"
    grep -qF "$CONVENTION_ROOT" <<<"$section" || { printf '%s\n' "${file#"$root"/}"; continue; }
    grep -qE "$ABSENT_BRANCH" <<<"$section" || { printf '%s\n' "${file#"$root"/}"; continue; }
  done < <(grep -rl '^## Project conventions$' --include='*.md' "$root" 2>/dev/null | sort)
}

# write_doc DIR NAME BODY -- one fixture document.
write_doc() {
  mkdir -p "$(dirname "$1/$2")"
  printf '%s\n' "$3" > "$1/$2"
}

test_repository_carries_the_block() {
  local out; out="$(offenders "$REPO_ROOT")"
  assert_empty "$out" "every Project conventions section names the convention root and the absent branch"
}

test_missing_path_is_named() {
  local dir="$FIXTURE_DIR/tree"
  write_doc "$dir" "workflow/prompts/a.md" "## Project conventions

Read the project conventions; if one is missing, skip that arm and report it.

- \`task-list\`"
  local out; out="$(offenders "$dir")"
  assert_eq "$out" "workflow/prompts/a.md" "a section without the convention path is named"
}

test_missing_branch_is_named() {
  local dir="$FIXTURE_DIR/tree2"
  write_doc "$dir" "workflow/prompts/b.md" "## Project conventions

Read each convention at \`.agents/skills/<name>/SKILL.md\`.

- \`task-list\`"
  local out; out="$(offenders "$dir")"
  assert_eq "$out" "workflow/prompts/b.md" "a section without the absent branch is named"
}

test_conforming_section_passes() {
  local dir="$FIXTURE_DIR/tree3"
  write_doc "$dir" "workflow/prompts/c.md" "## Project conventions

Read each convention at \`.agents/skills/<name>/SKILL.md\`, and skip a convention that is absent or still a stub, naming which one you skipped.

- \`task-list\`"
  local out; out="$(offenders "$dir")"
  assert_empty "$out" "a section naming the root and the branch is not named"
}

test_file_without_the_section_is_ignored() {
  local dir="$FIXTURE_DIR/tree4"
  write_doc "$dir" "docs/guide.md" "# Guide

A document that names no conventions."
  local out; out="$(offenders "$dir")"
  assert_empty "$out" "a document with no section is never named"
}

run_test test_repository_carries_the_block
run_test test_missing_path_is_named
run_test test_missing_branch_is_named
run_test test_conforming_section_passes
run_test test_file_without_the_section_is_ignored

test_done convention_pointer

#!/usr/bin/env bash
# tests/test_document_shape.sh
# Behavioural tests for scripts/lint/document-shape.mjs -- the gate that holds
# every instruction document's frontmatter and every shipping document's reader.
# The principle body shape is a convention, not this gate's subject; the
# principle frontmatter gate is tested in test_principle_frontmatter.sh.
#
# Covers:
#   a malformed block            --  flagged, naming the parse
#   a non-boolean flag           --  flagged: pi tests it with `=== true`
#   a shipping document's reader --  flagged when absent, clean when declared
#   a principle body             --  not checked: the body shape is a convention
#   a non-principle skill        --  scanned, because the gate covers every skill
#
# The whole-tree behaviour is the lint umbrella's job (check_document_shape.sh in
# scripts/lint.sh), not a fixture unit test's: see .agents/skills/testing/patterns/assertions.md,
# the whole-tree scan pattern.

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/.." && pwd)"

source "$TEST_DIR/libs/test_common.sh"
test_setup

GATE="$REPO_ROOT/scripts/check_document_shape.sh"

# make_root NAME -- a fixture root whose only declared skill root is the
# project's own `.agents/skills`, which every scan reads.
make_root() {
  local name="$1"
  local dir="$FIXTURE_DIR/$name"
  mkdir -p "$dir/.agents/skills"
  printf '%s' "$dir"
}

# write_skill ROOT NAME BODY -- a skill file under the root's `.agents/skills`.
write_skill() {
  local root="$1" name="$2" body="$3"
  mkdir -p "$root/.agents/skills/$name"
  printf '%s\n' "$body" > "$root/.agents/skills/$name/SKILL.md"
}

# write_prompt ROOT BODY -- a prompt under the root's own `.agents/prompts`,
# which the manifest declares as an instruction root.
write_prompt() {
  local root="$1" body="$2"
  mkdir -p "$root/.agents/prompts"
  printf '%s\n' "$body" > "$root/.agents/prompts/fixture.md"
}

# run_gate ROOT -- the gate's combined output, and its exit status in GATE_RC.
run_gate() {
  local root="$1"
  GATE_OUT="$(DOCUMENT_SHAPE_SCAN_ROOT="$root" bash "$GATE" 2>&1)"
  GATE_RC=$?
}

test_principle_body_is_not_checked() {
  local root
  root="$(make_root body)"
  write_skill "$root" principle-example "---
name: principle-example
description: \"fixture\"
---

# One example judgement

## Steps

1. Read the record.
"
  run_gate "$root"
  assert_eq_num 0 "$GATE_RC" 'a principle body departs from the convention and the gate does not read it'
  assert_contains "$GATE_OUT" 'clean across 1 instruction file(s)' 'the run names what it read'
}

test_broken_block_is_flagged() {
  local root
  root="$(make_root broken_block)"
  write_prompt "$root" '---
description: "a value that never closes
---

# Fixture'
  run_gate "$root"
  assert_ne 0 "$GATE_RC" 'a block that does not parse fails the gate'
  assert_contains "$GATE_OUT" 'frontmatter does not parse' 'the finding names the parse'
}

test_non_boolean_flag_is_flagged() {
  local root
  root="$(make_root non_boolean_flag)"
  write_skill "$root" x "---
name: x
description: \"fixture\"
disable-model-invocation: yes
---

# X
"
  run_gate "$root"
  assert_ne 0 "$GATE_RC" 'a string flag fails the gate'
  assert_contains "$GATE_OUT" 'disable-model-invocation is "yes"' 'the finding names the field and its value'
}

test_shipping_document_without_a_reader_is_flagged() {
  local root
  root="$(make_root no_reader)"
  mkdir -p "$root/docs/reference"
  printf '%s\n' '---' 'description: fixture' '---' '' '# Undeclared' > "$root/docs/reference/undeclared.md"
  GATE_OUT="$(DOCUMENT_SHAPE_SCAN_ROOT="$root" DOCUMENT_SHAPE_SHIPPED_ROOTS=docs/reference bash "$GATE" 2>&1)"
  GATE_RC=$?
  assert_ne 0 "$GATE_RC" 'a shipping document with no reader fails the gate'
  assert_contains "$GATE_OUT" 'no reader declared' 'the finding names the missing declaration'
}

test_a_non_principle_skill_is_scanned() {
  local root
  root="$(make_root every_skill)"
  write_skill "$root" note-taking "---
name: note-taking
description: a skill: an unquoted colon
---

# Take a note
"
  run_gate "$root"
  assert_ne 0 "$GATE_RC" 'the parse covers every skill, not only the principles'
  assert_contains "$GATE_OUT" 'note-taking/SKILL.md' 'the finding names the non-principle skill'
}

run_test test_principle_body_is_not_checked
run_test test_broken_block_is_flagged
run_test test_non_boolean_flag_is_flagged
run_test test_shipping_document_without_a_reader_is_flagged
run_test test_a_non_principle_skill_is_scanned

test_done

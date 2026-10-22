#!/usr/bin/env bash
# tests/test_document_shape.sh
# Behavioural tests for scripts/lint/document-shape.mjs -- the gate that holds
# every instruction document's frontmatter and every `principle-` skill's shape.
#
# Covers:
#   a conforming principle        --  clean, and the run names the skill count
#   a `##` heading below the title --  flagged as a part that is not a bold lead-in
#   a missing `**The test.**`     --  flagged by name
#   the why before the pattern    --  flagged: the order is fixed
#   a named part after the test   --  flagged: named parts sit before the test
#   a title-case title            --  flagged, naming the word
#   a skill with no `principle-`  --  clean, and its departure is not read
#   a root with no principle      --  not read; the module tree is what fails closed
#   a declared claim              --  clean, and the map names the skill under it
#   no claim declared             --  flagged: a principle carries one
#   a claim the table lacks       --  flagged, naming the set the table states
#   --map                         --  prints one row per skill and a total that
#                                     matches the skills read
#   a broken block                --  flagged, naming the parse
#   a non-boolean flag            --  flagged: pi tests it with `=== true`
#   a shipping document's reader  --  flagged when absent, clean when declared
#
# The subject is derived from the directory name, so the non-principle case is
# the rule's boundary: a runbook skill departs from the shape on purpose and the
# gate must not read it.
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

# conforming BODY -- the six parts, so a case can replace one line of them.
conforming() {
  local extra="${1:-}"
  printf '%s' "---
name: principle-example
description: \"fixture\"
metadata:
  claim: evidence
---

# One example judgement

State the judgement in one sentence.

**The pattern.** The wrong form beside the right form.

**Why.** The wrong form fails silently.

$extra**The test.** Ask the question of the draft."
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

test_conforming_principle_is_clean() {
  local root
  root="$(make_root conforming)"
  write_skill "$root" principle-example "$(conforming)"
  run_gate "$root"
  assert_eq_num 0 "$GATE_RC" 'a conforming principle passes'
  assert_contains "$GATE_OUT" 'clean across 1 instruction file(s), 0 shipping document(s) and 1 principle skill(s)' 'the run names what it read'
}

test_heading_below_the_title_is_flagged() {
  local root
  root="$(make_root heading)"
  write_skill "$root" principle-example "$(conforming | sed 's|^\*\*Why\.\*\*|## Why|')"
  run_gate "$root"
  assert_ne 0 "$GATE_RC" 'a heading below the title fails the gate'
  assert_contains "$GATE_OUT" 'a `##` heading below the title' 'the finding names the heading'
}

test_missing_test_is_flagged() {
  local root
  root="$(make_root no_test)"
  write_skill "$root" principle-example "$(conforming | grep -v '^\*\*The test\.\*\*')"
  run_gate "$root"
  assert_ne 0 "$GATE_RC" 'a principle with no test fails the gate'
  assert_contains "$GATE_OUT" 'missing `**The test.**`' 'the finding names the missing part'
}

test_why_before_the_pattern_is_flagged() {
  local root
  root="$(make_root order)"
  write_skill "$root" principle-example "$(conforming | sed 's|^\*\*The pattern\.\*\*.*|**Why.** The wrong form fails silently.\n\n**The pattern.** The wrong form beside the right form.|; s|^\*\*Why\.\*\* The wrong form fails silently\.$||')"
  run_gate "$root"
  assert_ne 0 "$GATE_RC" 'the why before the pattern fails the gate'
  assert_contains "$GATE_OUT" 'must follow `**The pattern.**`' 'the finding names the order'
}

test_named_part_after_the_test_is_flagged() {
  local root
  root="$(make_root part_after)"
  write_skill "$root" principle-example "$(conforming '**The test.** Ask the question of the draft.

**Where a rule wins.** A caveat.
')"
  run_gate "$root"
  assert_ne 0 "$GATE_RC" 'a named part after the test fails the gate'
  assert_contains "$GATE_OUT" 'a named part belongs between' 'the finding names the placement'
}

test_title_case_title_is_flagged() {
  local root
  root="$(make_root title_case)"
  write_skill "$root" principle-example "$(conforming | sed 's|^# One example judgement|# One Example Judgement|')"
  run_gate "$root"
  assert_ne 0 "$GATE_RC" 'a title-case title fails the gate'
  assert_contains "$GATE_OUT" 'the title is not sentence case' 'the finding names the case'
}

test_skill_without_the_name_segment_is_not_read() {
  local root
  root="$(make_root not_a_principle)"
  write_skill "$root" note-taking "---
name: note-taking
description: \"fixture\"
---

# Take a note

## Steps

1. Read the record.
"
  write_skill "$root" principle-example "$(conforming)"
  run_gate "$root"
  assert_eq_num 0 "$GATE_RC" 'a runbook skill departs on purpose and is not read'
  assert_contains "$GATE_OUT" '1 principle skill(s)' 'only the principle counts'
}

test_a_fixture_root_with_no_principle_is_not_read() {
  local root
  root="$(make_root empty)"
  write_skill "$root" note-taking "---
name: note-taking
description: \"fixture\"
---

# Take a note
"
  run_gate "$root"
  assert_eq_num 0 "$GATE_RC" 'a fixture with no principle is a tree with no corpus to check'
  assert_contains "$GATE_OUT" '0 principle skill(s)' 'the run says how much corpus it read'
}

test_declared_claim_is_clean_and_mapped() {
  local root out
  root="$(make_root claimed)"
  write_skill "$root" principle-example "$(conforming)"
  run_gate "$root"
  assert_eq_num 0 "$GATE_RC" 'a declared claim passes'
  out="$(DOCUMENT_SHAPE_SCAN_ROOT="$root" bash "$GATE" --map 2>&1)"
  assert_contains "$out" "evidence	principle-example" 'the map names the skill under its claim'
  assert_contains "$out" 'claim map: 1 skill(s) across 1 claim(s) of 1' 'the map totals what it read'
}

test_missing_claim_is_flagged() {
  local root
  root="$(make_root no_claim)"
  write_skill "$root" principle-example "$(conforming | sed '/^metadata:$/,+1d')"
  run_gate "$root"
  assert_ne 0 "$GATE_RC" 'a principle with no claim fails the gate'
  assert_contains "$GATE_OUT" 'no claim declared' 'the finding names the missing declaration'
}

test_unknown_claim_is_flagged() {
  local root
  root="$(make_root unknown_claim)"
  write_skill "$root" principle-example "$(conforming | sed 's|^  claim: evidence|  claim: vibes|')"
  run_gate "$root"
  assert_ne 0 "$GATE_RC" 'a claim the table lacks fails the gate'
  assert_contains "$GATE_OUT" 'claim `vibes` is not in the authoring convention' 'the finding names the claim and its home'
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
  write_skill "$root" principle-example "$(conforming | sed 's|^metadata:$|disable-model-invocation: yes\nmetadata:|')"
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

run_test test_conforming_principle_is_clean
run_test test_broken_block_is_flagged
run_test test_non_boolean_flag_is_flagged
run_test test_shipping_document_without_a_reader_is_flagged
run_test test_heading_below_the_title_is_flagged
run_test test_missing_test_is_flagged
run_test test_why_before_the_pattern_is_flagged
run_test test_named_part_after_the_test_is_flagged
run_test test_title_case_title_is_flagged
run_test test_skill_without_the_name_segment_is_not_read
run_test test_a_fixture_root_with_no_principle_is_not_read
run_test test_declared_claim_is_clean_and_mapped
run_test test_missing_claim_is_flagged
run_test test_unknown_claim_is_flagged

test_done

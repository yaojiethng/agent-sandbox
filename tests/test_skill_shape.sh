#!/usr/bin/env bash
# tests/test_skill_shape.sh
# Behavioural tests for scripts/lint/skill-shape.mjs -- the gate that holds every
# skill whose name carries `principle-` to one shape.
#
# Covers:
#   a conforming principle        --  clean, and the run names the skill count
#   a `##` heading below the title --  flagged as a part that is not a bold lead-in
#   a missing `**The test.**`     --  flagged by name
#   the why before the pattern    --  flagged: the order is fixed
#   a named part after the test   --  flagged: named parts sit before the test
#   a title-case title            --  flagged, naming the word
#   a skill with no `principle-`  --  clean, and its departure is not read
#   a root with no principle      --  the gate fails closed rather than over nothing
#   a declared claim              --  clean, and the map names the skill under it
#   no claim declared             --  flagged: a principle carries one
#   a claim the table lacks       --  flagged, naming the set the table states
#   --map                         --  prints one row per skill and a total that
#                                     matches the skills read
#
# The subject is derived from the directory name, so the non-principle case is
# the rule's boundary: a runbook skill departs from the shape on purpose and the
# gate must not read it.
#
# The whole-tree behaviour is the lint umbrella's job (check_skill_shape.sh in
# scripts/lint.sh), not a fixture unit test's: see testing-conventions.md
# Anti-Pattern 8.

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/.." && pwd)"

source "$TEST_DIR/libs/test_common.sh"
test_setup

GATE="$REPO_ROOT/scripts/check_skill_shape.sh"

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

# run_gate ROOT -- the gate's combined output, and its exit status in GATE_RC.
run_gate() {
  local root="$1"
  GATE_OUT="$(SKILL_SHAPE_SCAN_ROOT="$root" bash "$GATE" 2>&1)"
  GATE_RC=$?
}

test_conforming_principle_is_clean() {
  local root
  root="$(make_root conforming)"
  write_skill "$root" principle-example "$(conforming)"
  run_gate "$root"
  assert_eq_num 0 "$GATE_RC" 'a conforming principle passes'
  assert_contains "$GATE_OUT" 'skill shape: clean across 1 skill(s)' 'the run names the skill count'
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
  assert_contains "$GATE_OUT" 'clean across 1 skill(s)' 'only the principle counts'
}

test_root_with_no_principle_fails_closed() {
  local root
  root="$(make_root empty)"
  write_skill "$root" note-taking "---
name: note-taking
description: \"fixture\"
---

# Take a note
"
  run_gate "$root"
  assert_ne 0 "$GATE_RC" 'a scan over no principle fails rather than reporting clean'
  assert_contains "$GATE_OUT" 'the gate would pass over nothing' 'the failure names why it could not run'
}

test_declared_claim_is_clean_and_mapped() {
  local root out
  root="$(make_root claimed)"
  write_skill "$root" principle-example "$(conforming)"
  run_gate "$root"
  assert_eq_num 0 "$GATE_RC" 'a declared claim passes'
  out="$(SKILL_SHAPE_SCAN_ROOT="$root" bash "$GATE" --map 2>&1)"
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

run_test test_conforming_principle_is_clean
run_test test_heading_below_the_title_is_flagged
run_test test_missing_test_is_flagged
run_test test_why_before_the_pattern_is_flagged
run_test test_named_part_after_the_test_is_flagged
run_test test_title_case_title_is_flagged
run_test test_skill_without_the_name_segment_is_not_read
run_test test_root_with_no_principle_fails_closed
run_test test_declared_claim_is_clean_and_mapped
run_test test_missing_claim_is_flagged
run_test test_unknown_claim_is_flagged

test_done

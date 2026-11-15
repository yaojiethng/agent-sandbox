#!/usr/bin/env bash
# Tests for scripts/judgement_inventory.mjs, the judgement inventory lever.
#
# The lever's subject is the provider root's judgement skills. The fixture
# builds that root under FIXTURE_DIR, one skill per structural fact, so the test
# does not depend on the real corpus's current field population.
#
# Covers:
#   fact    -- an unresolved declared name, a missing field, an explicit empty
#              list, and a duplicate declared name are each reported
#   edge    -- a prose link to another judgement is a candidate; a link to a
#              non-judgement skill is not
#   answer  -- two runs print the same JSON, and an unreadable root refuses
#
# The known set is bound before it is asserted on: the test asserts which names
# the lever discovered, not a count, so adding a fixture skill is visible.

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup

REPO_ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LEVER="$REPO_ROOT_DIR/scripts/judgement_inventory.mjs"
ROOT_REL="src/reasoning/agent-runtime/pi/config/agent/skills"

write_skill() {
  local root="$1" name="$2" frontmatter="$3" body="${4:-}"
  mkdir -p "$root/$ROOT_REL/$name"
  {
    printf -- '---\n'
    printf '%s\n' "$frontmatter"
    printf -- '---\n\n'
    printf '# %s\n\n' "$name"
    printf '%s\n' "$body"
  } > "$root/$ROOT_REL/$name/SKILL.md"
}

build_fixture() {
  local d="$1"
  write_skill "$d" principle-a \
    'name: principle-a
description: "a judgement with duplicates and an unresolved name"
metadata:
  neighbours:
    - principle-b
    - principle-b
    - principle-missing' \
    'See [b](../principle-b/SKILL.md) and [not a judgement](../not-a-judgement/SKILL.md).'
  write_skill "$d" principle-b \
    'name: principle-b
description: "a judgement that declares no neighbour"
metadata:
  neighbours: []'
  write_skill "$d" principle-c \
    'name: principle-c
description: "a judgement with no neighbours field"'
  write_skill "$d" principle-d \
    'name: principle-d
description: "a judgement with one valid neighbour"
metadata:
  neighbours:
    - principle-a'
  write_skill "$d" not-a-judgement \
    'name: not-a-judgement
description: "a support skill, not a judgement"'
}

json() {
  node "$LEVER" --root "$1" --json
}

names() {
  node -e 'const d=JSON.parse(process.argv[1]);console.log(d.judgements.map(j=>j.name).join(","))' "$1"
}

state_of() {
  node -e 'const d=JSON.parse(process.argv[1]);const j=d.judgements.find(x=>x.name===process.argv[2]);console.log(j?j.state:"absent")' "$1" "$2"
}

kinds_of() {
  node -e 'const d=JSON.parse(process.argv[1]);console.log(d.findings.filter(f=>f.skill===process.argv[2]).map(f=>f.kind).sort().join(","))' "$1" "$2"
}

cross_of() {
  node -e 'const d=JSON.parse(process.argv[1]);const j=d.judgements.find(x=>x.name===process.argv[2]);console.log(j?j.crossLinks.join(","):"absent")' "$1" "$2"
}

test_the_judgement_set_is_named() {
  local d out
  d="$(get_fixture_dir)"
  build_fixture "$d"
  out="$(json "$d")"
  assert_eq "$(names "$out")" "principle-a,principle-b,principle-c,principle-d" \
    "the lever reads judgement names and ignores a support skill"
}

test_unresolved_name_is_reported() {
  local d out
  d="$(get_fixture_dir)"
  build_fixture "$d"
  out="$(json "$d")"
  assert_eq "$(kinds_of "$out" principle-a)" "duplicate-neighbour,unresolved-neighbour" \
    "a duplicate and a name that resolves to no judgement are two findings"
}

test_missing_field_is_reported() {
  local d out
  d="$(get_fixture_dir)"
  build_fixture "$d"
  out="$(json "$d")"
  assert_eq "$(state_of "$out" principle-c)" "missing" "an absent field is the missing state"
  assert_eq "$(kinds_of "$out" principle-c)" "missing-field" "the absent field is reported"
}

test_explicit_empty_is_not_missing() {
  local d out
  d="$(get_fixture_dir)"
  build_fixture "$d"
  out="$(json "$d")"
  assert_eq "$(state_of "$out" principle-b)" "empty" "an explicit empty list is its own state"
  assert_eq "$(kinds_of "$out" principle-b)" "" "an explicit empty list is not a missing field"
}

test_a_valid_declaration_is_clean() {
  local d out
  d="$(get_fixture_dir)"
  build_fixture "$d"
  out="$(json "$d")"
  assert_eq "$(kinds_of "$out" principle-d)" "" "a name that resolves is not a finding"
}

test_a_prose_link_is_a_candidate() {
  local d out
  d="$(get_fixture_dir)"
  build_fixture "$d"
  out="$(json "$d")"
  assert_eq "$(cross_of "$out" principle-a)" "principle-b" \
    "a prose link to another judgement is surfaced, and a non-judgement link is not"
}

test_two_runs_are_identical() {
  local d first second
  d="$(get_fixture_dir)"
  build_fixture "$d"
  first="$(json "$d")"
  second="$(json "$d")"
  assert_eq "$first" "$second" "the inventory is deterministic"
}

test_an_unreadable_root_refuses() {
  local d out rc
  d="$(get_fixture_dir)"
  out="$(node "$LEVER" --root "$d/absent" --json 2>&1)"
  rc=$?
  assert_eq "$rc" "2" "a root without the skills tree is a failed run"
  assert_contains "$out" "no skills root at" "the refusal names the missing root"
}

run_test test_the_judgement_set_is_named
run_test test_unresolved_name_is_reported
run_test test_missing_field_is_reported
run_test test_explicit_empty_is_not_missing
run_test test_a_valid_declaration_is_clean
run_test test_a_prose_link_is_a_candidate
run_test test_two_runs_are_identical
run_test test_an_unreadable_root_refuses

test_done

#!/usr/bin/env bash
# tests/test_principle_frontmatter.sh
# TEST_DEADLINE: 15
# Tests for scripts/lint/principle-frontmatter.mjs, the principle frontmatter gate.
#
# The fixture builds the provider root under FIXTURE_DIR. The neighbour rules
# keep their tests, and the declaration fields gain one case each: name,
# description, the conditional leitwort/intent/mechanism, and the forbidden
# disable-model-invocation.

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup

REPO_ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GATE="$REPO_ROOT_DIR/scripts/lint/principle-frontmatter.mjs"
ROOT_REL="src/reasoning/agent-runtime/pi/config/agent/skills"

write_skill() {
  local root="$1" name="$2" frontmatter="$3"
  mkdir -p "$root/$ROOT_REL/$name"
  {
    printf -- '---\n'
    printf '%s\n' "$frontmatter"
    printf -- '---\n\n# %s\n' "$name"
  } > "$root/$ROOT_REL/$name/SKILL.md"
}

build_root() {
  local d="$1"
  write_skill "$d" principle-a \
    'name: principle-a
description: "a principle"'
  write_skill "$d" principle-b \
    'name: principle-b
description: "a principle with no neighbour"
metadata:
  neighbours: []'
}

run_gate() {
  local root="$1"
  shift
  node "$GATE" --root "$root" "$@"
}

test_a_missing_field_fails() {
  local d out
  d="$(get_fixture_dir)"
  build_root "$d"
  out="$(run_gate "$d" 2>&1)"
  assert_eq "$?" "1" "a principle with no field fails"
  assert_contains "$out" "missing-field" "the finding names the missing declaration"
}

test_an_explicit_empty_list_is_clean() {
  local d out
  d="$(get_fixture_dir)"
  build_root "$d"
  write_skill "$d" principle-a \
    'name: principle-a
description: "a principle with no neighbour"
metadata:
  neighbours: []'
  out="$(run_gate "$d" 2>&1)"
  assert_eq "$?" "0" "an explicit empty list declares no neighbour and passes"
  assert_contains "$out" "0 finding(s)" "the clean run reports no finding"
}

test_an_unresolved_name_fails() {
  local d out
  d="$(get_fixture_dir)"
  build_root "$d"
  write_skill "$d" principle-a \
    'name: principle-a
description: "a principle"
metadata:
  neighbours:
    - principle-missing'
  out="$(run_gate "$d" 2>&1)"
  assert_eq "$?" "1" "a declared name with no live principle fails"
  assert_contains "$out" "unresolved-neighbour" "the finding names the unresolved neighbour"
}

test_a_duplicate_name_fails() {
  local d out
  d="$(get_fixture_dir)"
  build_root "$d"
  write_skill "$d" principle-a \
    'name: principle-a
description: "a principle"
metadata:
  neighbours:
    - principle-b
    - principle-b'
  out="$(run_gate "$d" 2>&1)"
  assert_eq "$?" "1" "a name declared twice fails"
  assert_contains "$out" "duplicate-neighbour" "the finding names the duplicate"
}

test_a_self_name_fails() {
  local d out
  d="$(get_fixture_dir)"
  build_root "$d"
  write_skill "$d" principle-a \
    'name: principle-a
description: "a principle"
metadata:
  neighbours:
    - principle-a'
  out="$(run_gate "$d" 2>&1)"
  assert_eq "$?" "1" "a principle naming itself fails"
  assert_contains "$out" "self-neighbour" "the finding names the self reference"
}

test_a_malformed_value_fails() {
  local d out
  d="$(get_fixture_dir)"
  build_root "$d"
  write_skill "$d" principle-a \
    'name: principle-a
description: "a principle"
metadata:
  neighbours: not-a-list'
  out="$(run_gate "$d" 2>&1)"
  assert_eq "$?" "1" "a value that is not a list fails"
  assert_contains "$out" "malformed-neighbours" "the finding names the malformed value"
}

test_a_missing_name_fails() {
  local d out
  d="$(get_fixture_dir)"
  build_root "$d"
  write_skill "$d" principle-a \
    'description: "a principle"
metadata:
  neighbours: []'
  out="$(run_gate "$d" 2>&1)"
  assert_eq "$?" "1" "a principle with no name fails"
  assert_contains "$out" "missing-name" "the finding names the missing name"
}

test_a_name_mismatch_fails() {
  local d out
  d="$(get_fixture_dir)"
  build_root "$d"
  write_skill "$d" principle-a \
    'name: principle-wrong
description: "a principle"
metadata:
  neighbours: []'
  out="$(run_gate "$d" 2>&1)"
  assert_eq "$?" "1" "a name that does not match the directory fails"
  assert_contains "$out" "name-mismatch" "the finding names the mismatch"
}

test_a_missing_description_fails() {
  local d out
  d="$(get_fixture_dir)"
  build_root "$d"
  write_skill "$d" principle-a \
    'name: principle-a
metadata:
  neighbours: []'
  out="$(run_gate "$d" 2>&1)"
  assert_eq "$?" "1" "a principle with no description fails"
  assert_contains "$out" "missing-description" "the finding names the missing description"
}

test_a_malformed_conditional_field_fails() {
  local d out field
  d="$(get_fixture_dir)"
  build_root "$d"
  for field in leitwort intent mechanism; do
    write_skill "$d" principle-a \
      "name: principle-a
description: \"a principle\"
metadata:
  neighbours: []
  $field: []"
    out="$(run_gate "$d" 2>&1)"
    assert_eq "$?" "1" "a malformed $field fails"
    assert_contains "$out" "malformed-$field" "the finding names the $field"
  done
}

test_a_principle_with_only_the_required_fields_is_clean() {
  local d out
  d="$(get_fixture_dir)"
  build_root "$d"
  write_skill "$d" principle-a \
    'name: principle-a
description: "a principle"
metadata:
  neighbours: []'
  out="$(run_gate "$d" 2>&1)"
  assert_eq "$?" "0" "the conditional fields are optional"
  assert_contains "$out" "0 finding(s)" "the clean run reports no finding"
}

test_a_principle_with_the_conditional_fields_is_clean() {
  local d out
  d="$(get_fixture_dir)"
  build_root "$d"
  write_skill "$d" principle-a \
    'name: principle-a
description: "a principle"
metadata:
  neighbours: []
  leitwort: proximity
  intent: keep the rule and its caveat together
  mechanism: place the parts in one spot'
  out="$(run_gate "$d" 2>&1)"
  assert_eq "$?" "0" "well-formed conditional fields pass"
  assert_contains "$out" "0 finding(s)" "the clean run reports no finding"
}

test_disable_model_invocation_fails() {
  local d out
  d="$(get_fixture_dir)"
  build_root "$d"
  write_skill "$d" principle-a \
    'name: principle-a
description: "a principle"
disable-model-invocation: true
metadata:
  neighbours: []'
  out="$(run_gate "$d" 2>&1)"
  assert_eq "$?" "1" "a principle that hides itself fails"
  assert_contains "$out" "disable-model-invocation" "the finding names the forbidden field"
}

test_an_unknown_argument_refuses() {
  local d out
  d="$(get_fixture_dir)"
  build_root "$d"
  out="$(run_gate "$d" --update 2>&1)"
  assert_eq "$?" "2" "the removed --update argument is refused"
  assert_contains "$out" "unknown argument" "the refusal names the bad argument"
}

run_test test_a_missing_field_fails
run_test test_an_explicit_empty_list_is_clean
run_test test_an_unresolved_name_fails
run_test test_a_duplicate_name_fails
run_test test_a_self_name_fails
run_test test_a_malformed_value_fails
run_test test_a_missing_name_fails
run_test test_a_name_mismatch_fails
run_test test_a_missing_description_fails
run_test test_a_malformed_conditional_field_fails
run_test test_a_principle_with_only_the_required_fields_is_clean
run_test test_a_principle_with_the_conditional_fields_is_clean
run_test test_disable_model_invocation_fails
run_test test_an_unknown_argument_refuses

test_done

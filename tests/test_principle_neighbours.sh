#!/usr/bin/env bash
# tests/test_principle_neighbours.sh
# TEST_DEADLINE: 15
# Tests for scripts/lint/principle-neighbours.mjs, the principle-neighbour gate.
#
# There is no baseline. The fixture builds the provider root under FIXTURE_DIR,
# and each test states only the case it reads: a missing field fails, an
# explicit `[]` passes, and the structural findings still fail.

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup

REPO_ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GATE="$REPO_ROOT_DIR/scripts/lint/principle-neighbours.mjs"
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
run_test test_an_unknown_argument_refuses

test_done

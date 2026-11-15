#!/usr/bin/env bash
# tests/test_principle_neighbours.sh
# TEST_DEADLINE: 15
# Tests for scripts/lint/principle-neighbours.mjs, the principle-neighbour gate.
#
# The fixture builds the provider root under FIXTURE_DIR and a baseline beside
# it, so each test states only the case it reads. The baseline's only rule is
# the gate's: a principle absent from it fails, and an entry that has gained
# the field fails until --update drops it.

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

write_baseline() {
  local path="$1"
  shift
  {
    printf '# test baseline\n'
    for name in "$@"; do printf '%s\n' "$name"; done
  } > "$path"
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
  local root="$1" baseline="$2"
  shift 2
  node "$GATE" --root "$root" --baseline "$baseline" "$@"
}

test_a_baselined_missing_field_is_clean() {
  local d out
  d="$(get_fixture_dir)"
  build_root "$d"
  write_baseline "$d/baseline" principle-a
  out="$(run_gate "$d" "$d/baseline" 2>&1)"
  assert_eq "$?" "0" "a missing field named in the baseline passes"
  assert_contains "$out" "0 finding(s)" "the clean run reports no finding"
}

test_an_unbaselined_missing_field_fails() {
  local d out
  d="$(get_fixture_dir)"
  build_root "$d"
  write_baseline "$d/baseline"
  out="$(run_gate "$d" "$d/baseline" 2>&1)"
  assert_eq "$?" "1" "a missing field outside the baseline fails"
  assert_contains "$out" "unbaselined-missing" "the finding names the missing declaration"
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
  write_baseline "$d/baseline"
  out="$(run_gate "$d" "$d/baseline" 2>&1)"
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
  write_baseline "$d/baseline"
  out="$(run_gate "$d" "$d/baseline" 2>&1)"
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
  write_baseline "$d/baseline"
  out="$(run_gate "$d" "$d/baseline" 2>&1)"
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
  write_baseline "$d/baseline"
  out="$(run_gate "$d" "$d/baseline" 2>&1)"
  assert_eq "$?" "1" "a value that is not a list fails"
  assert_contains "$out" "malformed-neighbours" "the finding names the malformed value"
}

test_an_explicit_empty_list_is_clean() {
  local d out
  d="$(get_fixture_dir)"
  build_root "$d"
  write_baseline "$d/baseline" principle-a
  out="$(run_gate "$d" "$d/baseline" 2>&1)"
  assert_eq "$?" "0" "an explicit empty list declares no neighbour and passes"
}

test_a_stale_baseline_fails_until_update_drops_it() {
  local d out
  d="$(get_fixture_dir)"
  build_root "$d"
  write_skill "$d" principle-a \
    'name: principle-a
description: "a principle with no neighbour"
metadata:
  neighbours: []'
  write_baseline "$d/baseline" principle-b
  out="$(run_gate "$d" "$d/baseline" 2>&1)"
  assert_eq "$?" "1" "a baseline entry that now declares a field fails"
  assert_contains "$out" "stale-baseline" "the finding names the stale entry"

  run_gate "$d" "$d/baseline" --update > /dev/null 2>&1
  assert_eq "$?" "0" "--update drops the stale entry"
  out="$(run_gate "$d" "$d/baseline" 2>&1)"
  assert_eq "$?" "0" "the gate is clean after --update"
  if grep -qx principle-b "$d/baseline"; then
    fail "--update left the declared principle in the baseline"
  else
    pass "--update removed the declared principle from the baseline"
  fi
}

test_update_refuses_to_add_a_new_principle() {
  local d out
  d="$(get_fixture_dir)"
  build_root "$d"
  write_baseline "$d/baseline" principle-b
  out="$(run_gate "$d" "$d/baseline" --update 2>&1)"
  assert_eq "$?" "1" "--update refuses to add a principle that has no field"
  assert_contains "$out" "refusing to add principle-a" "the refusal names the new principle"
  if grep -qx principle-a "$d/baseline"; then
    fail "--update added the new principle to the baseline"
  else
    pass "--update did not add the new principle"
  fi
}

test_a_missing_baseline_refuses() {
  local d out
  d="$(get_fixture_dir)"
  build_root "$d"
  out="$(run_gate "$d" "$d/absent" 2>&1)"
  assert_eq "$?" "2" "a run without a baseline cannot decide"
  assert_contains "$out" "no baseline at" "the refusal names the missing baseline"
}

test_update_refuses_while_a_structural_finding_is_open() {
  local d out
  d="$(get_fixture_dir)"
  build_root "$d"
  write_skill "$d" principle-a \
    'name: principle-a
description: "a principle"
metadata:
  neighbours:
    - principle-missing'
  write_baseline "$d/baseline"
  out="$(run_gate "$d" "$d/baseline" --update 2>&1)"
  assert_eq "$?" "1" "--update refuses an unresolved declaration"
  assert_contains "$out" "unresolved-neighbour" "--update reports the structural finding"
  if grep -qx principle-a "$d/baseline"; then
    fail "--update grandfathered the principle while a finding was open"
  else
    pass "--update wrote nothing while a finding was open"
  fi
}

run_test test_a_baselined_missing_field_is_clean
run_test test_an_unbaselined_missing_field_fails
run_test test_an_unresolved_name_fails
run_test test_a_duplicate_name_fails
run_test test_a_self_name_fails
run_test test_a_malformed_value_fails
run_test test_an_explicit_empty_list_is_clean
run_test test_a_stale_baseline_fails_until_update_drops_it
run_test test_update_refuses_to_add_a_new_principle
run_test test_a_missing_baseline_refuses
run_test test_update_refuses_while_a_structural_finding_is_open

test_done

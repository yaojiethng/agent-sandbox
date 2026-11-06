#!/usr/bin/env bash
# Tests for the unit vocabulary gate: a bare record-entity use fails, while the
# quantifier, the compound and the test-unit domain pass.

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup

RULE="$REPO_ROOT/scripts/lint/unit.mjs"

run_in() {
  ( cd "$1" && node "$RULE" 2>&1 )
}

unit_entity_use_fails() {
  local d; d="$(mktemp -d)"
  mkdir -p "$d/.agents/skills"
  printf '# X\n\nThe unit closes.\n' > "$d/.agents/skills/x.md"
  local out rc
  out="$(run_in "$d")"; rc=$?
  assert_eq "$rc" "1" "a bare entity use fails"
  assert_contains "$out" "x.md" "the finding names the file"
  rm -rf "$d"
}

unit_quantifier_passes() {
  local d; d="$(mktemp -d)"
  mkdir -p "$d/.agents/skills"
  printf '# X\n\nThe change lands in the same unit of work.\n' > "$d/.agents/skills/x.md"
  local out rc
  out="$(run_in "$d")"; rc=$?
  assert_eq "$rc" "0" "a quantifier passes"
  assert_contains "$out" "clear across" "the report says clear"
  rm -rf "$d"
}

unit_compound_passes() {
  local d; d="$(mktemp -d)"
  mkdir -p "$d/.agents/skills"
  printf '# X\n\nA unit test and its unit suite.\n' > "$d/.agents/skills/x.md"
  local out rc
  out="$(run_in "$d")"; rc=$?
  assert_eq "$rc" "0" "the test-unit compound passes"
  rm -rf "$d"
}

unit_test_domain_is_exempt() {
  local d; d="$(mktemp -d)"
  mkdir -p "$d/.agents/skills/testing"
  printf '# X\n\nThe unit asserts the behaviour.\n' > "$d/.agents/skills/testing/x.md"
  local out rc
  out="$(run_in "$d")"; rc=$?
  assert_eq "$rc" "0" "the test unit domain is exempt"
  rm -rf "$d"
}

unit_terminology_home_is_exempt() {
  local d; d="$(mktemp -d)"
  mkdir -p "$d/docs/reference"
  printf '# Terms\n\n`unit` is a bag term.\n' > "$d/docs/reference/terminology.md"
  local out rc
  out="$(run_in "$d")"; rc=$?
  assert_eq "$rc" "0" "the term's home is exempt"
  rm -rf "$d"
}

run_test unit_entity_use_fails
run_test unit_quantifier_passes
run_test unit_compound_passes
run_test unit_test_domain_is_exempt
run_test unit_terminology_home_is_exempt

test_done

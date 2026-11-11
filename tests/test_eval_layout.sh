#!/usr/bin/env bash
# TEST_DEADLINE: 60
# tests/test_eval_layout.sh
# Behavioural tests for scripts/check_eval_layout.sh and the eval layout reader,
# .agents/skills/evals/scripts/layout.sh.
#
# The failure this gate exists for: the eval layout had three owners - the skill's
# prose, the harness reference's stores table, and constants inside two scripts -
# and nothing compared them. A declaration with one reader removes the second
# statement; the gate fails when a consumer reads a key the declaration lost, when
# a declared key no consumer reads, and when a consumer stops sourcing the reader.
#
# Covers:
#   the repository's own layout            -- rc 0
#   a declared key no consumer reads       -- rc 1; the key is named
#   a consumer reading an undeclared key   -- rc 1; the key is named
#   a consumer that does not source the reader -- rc 1
#   a declaration that does not parse      -- rc 1
#   a missing consumer                     -- rc 1
#   the reader                             -- the value, the override file, rc 2 on a missing key
#   the consumers carry no layout literal  -- the paths come from the declaration only
#
# Run:   bash tests/test_eval_layout.sh
# Exit:  0 = all passed, non-zero = failure count

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/.." && pwd)"

source "$TEST_DIR/libs/test_common.sh"
test_setup

GATE="$REPO_ROOT/scripts/check_eval_layout.sh"
READER="$REPO_ROOT/.agents/skills/evals/scripts/layout.sh"
RUN_CASE="$REPO_ROOT/.agents/skills/evals/scripts/run_case.sh"
FIXTURES_GATE="$REPO_ROOT/scripts/check_eval_fixtures.sh"

# make_root  --  a tree the gate reads: a declaration, the reader and two consumers.
make_root() {
  local root; root="$(get_fixture_dir)"
  mkdir -p "$root/.agents/skills/evals/assets" "$root/.agents/skills/evals/scripts" "$root/scripts"
  cp "$READER" "$root/.agents/skills/evals/scripts/layout.sh"
  printf '{"caseRoot": "tests/eval", "gradeDir": "grade"}\n' \
    >"$root/.agents/skills/evals/assets/layout.json"
  printf '#!/usr/bin/env bash\nsource "$(dirname "$0")/layout.sh"\nlayout_get caseRoot\n' \
    >"$root/.agents/skills/evals/scripts/run_case.sh"
  printf '#!/usr/bin/env bash\nsource "$REPO_ROOT/.agents/skills/evals/scripts/layout.sh"\nlayout_get gradeDir\n' \
    >"$root/scripts/check_eval_fixtures.sh"
  printf '%s\n' "$root"
}

run_gate_root() {
  RUN_OUT="$(bash "$GATE" "$1" 2>&1)"
  RUN_RC=$?
}

test_the_repository_layout_is_clean() {
  run_gate_root "$REPO_ROOT"
  assert_rc 0 "$RUN_RC" "the repository's own layout passes"
  assert_contains "$RUN_OUT" "Eval-layout gate: clean" "the run reports its verdict"
}

test_a_declared_key_no_consumer_reads_is_named() {
  local root; root="$(make_root)"
  jq '. + {unusedKey: "nowhere"}' "$root/.agents/skills/evals/assets/layout.json" \
    >"$root/.agents/skills/evals/assets/layout.next"
  mv "$root/.agents/skills/evals/assets/layout.next" "$root/.agents/skills/evals/assets/layout.json"
  run_gate_root "$root"
  assert_rc 1 "$RUN_RC" "a declared key no consumer reads fails"
  assert_contains "$RUN_OUT" "unusedKey" "the dead key is named"
}

test_a_consumer_reading_an_undeclared_key_is_named() {
  local root; root="$(make_root)"
  printf '#!/usr/bin/env bash\nsource "$(dirname "$0")/layout.sh"\nlayout_get missingKey\n' \
    >"$root/.agents/skills/evals/scripts/run_case.sh"
  run_gate_root "$root"
  assert_rc 1 "$RUN_RC" "a key the declaration does not carry fails"
  assert_contains "$RUN_OUT" "missingKey" "the undeclared key is named"
}

test_a_consumer_that_does_not_source_the_reader_is_named() {
  local root; root="$(make_root)"
  printf '#!/usr/bin/env bash\nlayout_get caseRoot\n' \
    >"$root/.agents/skills/evals/scripts/run_case.sh"
  run_gate_root "$root"
  assert_rc 1 "$RUN_RC" "a consumer outside the reader fails"
  assert_contains "$RUN_OUT" "does not source layout.sh" "the refusal names the reader"
}

test_a_declaration_that_does_not_parse_is_named() {
  local root; root="$(make_root)"
  printf '[]\n' >"$root/.agents/skills/evals/assets/layout.json"
  run_gate_root "$root"
  assert_rc 1 "$RUN_RC" "a declaration that is not an object of strings fails"
  assert_contains "$RUN_OUT" "is not an object" "the refusal names the shape"
}

test_a_missing_consumer_is_named() {
  local root; root="$(make_root)"
  rm -f "$root/scripts/check_eval_fixtures.sh"
  run_gate_root "$root"
  assert_rc 1 "$RUN_RC" "a missing consumer fails"
  assert_contains "$RUN_OUT" "is missing" "the refusal names the absence"
}

test_the_reader_returns_the_declared_value() {
  local dir; dir="$(get_fixture_dir)"
  printf '{"caseRoot": "from-the-declaration"}\n' >"$dir/layout.json"
  local out
  out="$(bash -c 'source "$1"; layout_get caseRoot "$2"' _ "$READER" "$dir/layout.json")"
  assert_eq "$out" "from-the-declaration" "the reader returns the declared value"
  bash -c 'source "$1"; layout_get absent "$2"' _ "$READER" "$dir/layout.json" >/dev/null 2>&1
  assert_rc 2 "$?" "a key the declaration does not carry is a usage error"
}

test_the_reader_expands_the_declared_home() {
  local dir; dir="$(get_fixture_dir)"
  printf '{"outputRoot": "$HOME/out"}\n' >"$dir/layout.json"
  local out
  out="$(HOME="/tmp/declared-home" bash -c 'source "$1"; expand_home "$(layout_get outputRoot "$2")"' _ "$READER" "$dir/layout.json")"
  assert_eq "$out" "/tmp/declared-home/out" "a declared \$HOME value expands"
}

test_the_consumers_carry_no_layout_literal() {
  local out
  out="$(grep -nE '\$OUT/(fixture|grade|grade-raw)|/cell-|case-%02d' "$RUN_CASE" "$FIXTURES_GATE" || true)"
  assert_empty "$out" "the run's directories come from the declaration, not a literal"
}

run_test test_the_repository_layout_is_clean
run_test test_a_declared_key_no_consumer_reads_is_named
run_test test_a_consumer_reading_an_undeclared_key_is_named
run_test test_a_consumer_that_does_not_source_the_reader_is_named
run_test test_a_declaration_that_does_not_parse_is_named
run_test test_a_missing_consumer_is_named
run_test test_the_reader_returns_the_declared_value
run_test test_the_reader_expands_the_declared_home
run_test test_the_consumers_carry_no_layout_literal

test_done

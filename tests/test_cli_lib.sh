#!/usr/bin/env bash
# tests/test_cli_lib.sh
# Unit tests for libs/cli.sh  --  parse_args and its collect-mode variant
# parse_args_collect (the agent-sandbox dispatcher entry point).
#
# Covers:
#   parse_args          --  value/boolean/literal specs; strict vs tolerant;
#                           --help exit code
#   parse_args_collect  --  spec flags route into vars, unmatched args are
#                           appended in order to the sink array, never error

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup
source "$REPO_ROOT/src/libs/cli.sh"

_test_usage() { echo "usage: test" >&2; }

# ---------------------------------------------------------------------------
# parse_args
# ---------------------------------------------------------------------------

test_parse_args_value_flag() {
  DELIVERY=""
  parse_args _test_usage --delivery=DELIVERY -- --delivery=copy >/dev/null 2>&1
  assert_eq "$DELIVERY" "copy" "parse_args: value flag sets the target var"
}

test_parse_args_boolean_flag() {
  FORCE=""
  parse_args _test_usage --force -- --force >/dev/null 2>&1
  assert_eq "$FORCE" "true" "parse_args: boolean flag sets the target var"
}

test_parse_args_unknown_strict_fails() {
  parse_args _test_usage --known -- --bogus >/dev/null 2>&1
  local rc=$?
  if [[ "$rc" == 1 ]]; then
    pass "parse_args: strict mode rejects an unknown flag with rc 1"
  else
    fail "parse_args: strict mode rc=$rc, expected 1"
  fi
}

test_parse_args_tolerant_drops_unknown() {
  _CLI_TOLERANT=1
  parse_args _test_usage --known -- --bogus >/dev/null 2>&1
  local rc=$?
  unset _CLI_TOLERANT
  if [[ "$rc" == 0 ]]; then
    pass "parse_args: tolerant mode ignores an unknown flag (rc 0)"
  else
    fail "parse_args: tolerant mode rc=$rc, expected 0"
  fi
}

test_parse_args_help_exits_2() {
  parse_args _test_usage --known -- --help x >/dev/null 2>&1
  local rc=$?
  if [[ "$rc" == 2 ]]; then
    pass "parse_args: --help prints usage and exits 2"
  else
    fail "parse_args: --help rc=$rc, expected 2"
  fi
}

# ---------------------------------------------------------------------------
# parse_args_collect
# ---------------------------------------------------------------------------

test_collect_routes_specs_and_appends_rest() {
  PASSTHROUGH=()
  ENV_REL=""
  PROJECT_NAME=""
  parse_args_collect PASSTHROUGH --env=ENV_REL --name=PROJECT_NAME \
      -- --env=prod --name=abc --serve tail --flag=x end
  assert_eq "${PASSTHROUGH[*]}" "--serve tail --flag=x end" \
      "collect: unmatched args appended in order"
  assert_eq "$ENV_REL" "prod" "collect: value flag routes into its var"
  assert_eq "$PROJECT_NAME" "abc" "collect: second value flag routes correctly"
}

test_collect_never_errors_on_unknown() {
  PASSTHROUGH=()
  parse_args_collect PASSTHROUGH --known -- --bogus --garbage=x
  local rc=$?
  if [[ "$rc" == 0 ]]; then
    pass "collect: unknown args do not error (rc 0)"
  else
    fail "collect: rc=$rc, expected 0"
  fi
  assert_eq "${PASSTHROUGH[*]}" "--bogus --garbage=x" \
      "collect: all unmatched args land in the sink"
}

test_collect_empty_args() {
  PASSTHROUGH=()
  parse_args_collect PASSTHROUGH --env=ENV_REL
  assert_eq "${#PASSTHROUGH[@]}" "0" "collect: no args means an empty sink"
}

test_collect_boolean_spec_not_sinked() {
  PASSTHROUGH=()
  VERBOSE=""
  parse_args_collect PASSTHROUGH --verbose -- --verbose v1
  assert_eq "$VERBOSE" "true" "collect: boolean spec routes into its var"
  assert_eq "${PASSTHROUGH[*]}" "v1" "collect: boolean flag not collected"
}

test_collect_literal_spec_not_sinked() {
  PASSTHROUGH=()
  parse_args_collect PASSTHROUGH --permissive -- p1 p2
  assert_eq "${PASSTHROUGH[*]}" "p1 p2" "collect: literal spec consumed, rest collected"
}

test_collect_appends_to_predeclared_sink() {
  local -a pre=(seed)
  parse_args_collect pre -- low high
  assert_eq "${pre[*]}" "seed low high" "collect: appends to a caller-owned sink"
}

test_collect_help_not_special() {
  PASSTHROUGH=()
  parse_args_collect PASSTHROUGH -- --help -h --other
  assert_eq "${PASSTHROUGH[*]}" "--help -h --other" \
      "collect: help flags pass through; help routing stays with the caller"
}

test_collect_bare_value_flag_consumed() {
  PASSTHROUGH=()
  ENV_REL=""
  parse_args_collect PASSTHROUGH --env=ENV_REL -- bar
  assert_eq "$ENV_REL" "" "collect: bare value flag sets an empty value"
  assert_eq "${PASSTHROUGH[*]}" "bar" "collect: bare value flag not collected"
}

test_collect_has_no_stale_registry() {
  PASSTHROUGH=()
  parse_args_collect PASSTHROUGH --env=ENV_REL -- --env=prod
  assert_eq "$ENV_REL" "prod" "collect: first parse routes its own spec"
  PASSTHROUGH=()
  parse_args_collect PASSTHROUGH --name=NAME -- --env=other kept
  assert_eq "$ENV_REL" "prod" "collect: an earlier spec flag is not re-routed by a stale registry"
  assert_eq "${PASSTHROUGH[*]}" "--env=other kept" \
      "collect: flag from an earlier spec is collected by this parse's registry"
}

# ---------------------------------------------------------------------------
# Runner
# ---------------------------------------------------------------------------

run_test test_parse_args_value_flag
run_test test_parse_args_boolean_flag
run_test test_parse_args_unknown_strict_fails
run_test test_parse_args_tolerant_drops_unknown
run_test test_parse_args_help_exits_2
run_test test_collect_routes_specs_and_appends_rest
run_test test_collect_never_errors_on_unknown
run_test test_collect_empty_args
run_test test_collect_boolean_spec_not_sinked
run_test test_collect_literal_spec_not_sinked
run_test test_collect_appends_to_predeclared_sink
run_test test_collect_help_not_special
run_test test_collect_bare_value_flag_consumed
run_test test_collect_has_no_stale_registry

echo "${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]]
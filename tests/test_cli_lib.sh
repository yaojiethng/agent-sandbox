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

# Given: a spec --delivery=DELIVERY and the arg --delivery=copy
# When:  parse_args runs
# Then:  DELIVERY is copy
# Asserts: the value-flag route.
test_parse_args_value_flag() {
  DELIVERY=""
  parse_args _test_usage --delivery=DELIVERY -- --delivery=copy >/dev/null 2>&1
  assert_eq "$DELIVERY" "copy" "parse_args: value flag sets the target var"
}

# Given: a spec --force and the arg --force
# When:  parse_args runs
# Then:  FORCE is true
# Asserts: boolean flag registration and defaulting.
test_parse_args_boolean_flag() {
  FORCE=""
  parse_args _test_usage --force -- --force >/dev/null 2>&1
  assert_eq "$FORCE" "true" "parse_args: boolean flag sets the target var"
}

# Given: an unknown flag in strict mode
# When:  parse_args runs
# Then:  rc 1 and usage is printed
# Asserts: strict rejection.
test_parse_args_unknown_strict_fails() {
  parse_args _test_usage --known -- --bogus >/dev/null 2>&1
  local rc=$?
  if [[ "$rc" == 1 ]]; then
    pass "parse_args: strict mode rejects an unknown flag with rc 1"
  else
    fail "parse_args: strict mode rc=$rc, expected 1"
  fi
}

# Given: _CLI_TOLERANT=1 and an unknown flag
# When:  parse_args runs
# Then:  rc 0
# Asserts: drop mode (the surface prune.sh uses).
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

# Given: _CLI_TOLERANT=1 and an unknown flag
# When:  parse_args runs with stderr captured
# Then:  rc 0 and a warning names the ignored argument
# Asserts: drop mode is not silent (the fail-open it once was).
test_parse_args_tolerant_warns_on_unknown() {
  _CLI_TOLERANT=1
  local OUT
  OUT=$(parse_args _test_usage --known -- --dry-runn 2>&1)
  local rc=$?
  unset _CLI_TOLERANT
  assert_rc 0 "$rc" "tolerant mode keeps rc 0 on an unknown flag"
  assert_contains "$OUT" "--dry-runn" "tolerant mode warns about the ignored argument"
}

# Given: a value flag with no `=value`
# When:  parse_args runs
# Then:  rc 1 and the target var is not poisoned with the flag name
# Asserts: a bare value flag is rejected, not consumed as its own value.
test_parse_args_bare_value_flag_rejected() {
  PROJECT_NAME=""
  parse_args _test_usage --name=PROJECT_NAME -- --name >/dev/null 2>&1
  local rc=$?
  if [[ "$rc" == 1 && "$PROJECT_NAME" == "" ]]; then
    pass "parse_args: a bare value flag is rejected (rc 1)"
  else
    fail "parse_args: bare value flag rc=$rc PROJECT_NAME='$PROJECT_NAME', expected rc 1 and empty"
  fi
}

# Given: a boolean flag given an explicit value
# When:  parse_args runs
# Then:  rc 1
# Asserts: a boolean flag does not silently accept a value.
test_parse_args_boolean_with_value_rejected() {
  FORCE=""
  parse_args _test_usage --force -- --force=0 >/dev/null 2>&1
  local rc=$?
  if [[ "$rc" == 1 ]]; then
    pass "parse_args: a boolean flag with a value is rejected (rc 1)"
  else
    fail "parse_args: boolean with value rc=$rc, expected 1"
  fi
}

# Given: `--help` after a `--` terminator
# When:  parse_args runs
# Then:  help is not triggered (the arg is treated as a positional)
# Asserts: a positional that spells --help can be passed.
test_parse_args_help_after_separator_not_special() {
  local RC=0
  parse_args _test_usage --known -- -- --help >/dev/null 2>&1 || RC=$?
  if [[ "$RC" != 2 ]]; then
    pass 'parse_args: --help after -- does not trigger help'
  else
    fail 'parse_args: --help after -- still triggered help'
  fi
}

# Given: --help among the args
# When:  parse_args runs
# Then:  usage is printed and rc 2
# Asserts: help routing on the strict surface.
test_parse_args_help_exits_2() {
  local OUT RC=0
  OUT=$(parse_args _test_usage --known -- --help x 2>&1) || RC=$?
  if [[ "$RC" == 2 && "$OUT" == *"usage"* ]]; then
    pass "parse_args: --help prints usage and exits 2"
  else
    fail "parse_args: --help rc=$RC out='$OUT', expected rc 2 printing usage"
  fi
}

# ---------------------------------------------------------------------------
# parse_args_collect
# ---------------------------------------------------------------------------

# Given: two value specs and mixed args in collect mode
# When:  parse_args_collect runs
# Then:  both specs route and every unmatched arg appends in order
# Asserts: the collect core.
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

# Given: only unknown args in collect mode
# When:  parse_args_collect runs
# Then:  rc 0 and every arg lands in the sink
# Asserts: collect never errors.
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

# Given: no args after the separator
# When:  parse_args_collect runs
# Then:  the sink is empty
# Asserts: the no-argument case.
test_collect_empty_args() {
  PASSTHROUGH=()
  parse_args_collect PASSTHROUGH --env=ENV_REL
  assert_eq "${#PASSTHROUGH[@]}" "0" "collect: no args means an empty sink"
}

# Given: a boolean spec and the args --verbose v1
# When:  parse_args_collect runs
# Then:  VERBOSE is true and only v1 is collected
# Asserts: a boolean flag is consumed, not sinked.
test_collect_boolean_spec_not_sinked() {
  PASSTHROUGH=()
  VERBOSE=""
  parse_args_collect PASSTHROUGH --verbose -- --verbose v1
  assert_eq "$VERBOSE" "true" "collect: boolean spec routes into its var"
  assert_eq "${PASSTHROUGH[*]}" "v1" "collect: boolean flag not collected"
}

# Given: a --permissive spec and two positional args
# When:  parse_args_collect runs
# Then:  both args are collected
# Asserts: sink contents only - the spec is registered as a boolean because the dashed arm precedes the literal arm, so this does not exercise the literal kind (finding 42).
test_collect_literal_spec_not_sinked() {
  PASSTHROUGH=()
  parse_args_collect PASSTHROUGH --permissive -- p1 p2
  assert_eq "${PASSTHROUGH[*]}" "p1 p2" "collect: literal spec consumed, rest collected"
}

# Given: a caller-owned sink pre-seeded with one entry
# When:  parse_args_collect runs
# Then:  the new args append after the seed
# Asserts: the nameref appends rather than replacing.
test_collect_appends_to_predeclared_sink() {
  local -a pre=(seed)
  parse_args_collect pre -- low high
  assert_eq "${pre[*]}" "seed low high" "collect: appends to a caller-owned sink"
}

# Given: --help, -h, and --other in collect mode
# When:  parse_args_collect runs
# Then:  all three are collected and no usage is printed
# Asserts: help routing belongs to the caller in collect mode.
test_collect_help_not_special() {
  PASSTHROUGH=()
  parse_args_collect PASSTHROUGH -- --help -h --other
  assert_eq "${PASSTHROUGH[*]}" "--help -h --other" \
      "collect: help flags pass through; help routing stays with the caller"
}

# Given: a value spec and a bare `--env` flag with no value
# When:  parse_args_collect runs
# Then:  the bare flag is forwarded to the sink, not assigned to its var
# Asserts: collect mode forwards a missing value for the leaf to reject.
test_collect_bare_value_flag_forwarded() {
  PASSTHROUGH=()
  ENV_REL=""
  parse_args_collect PASSTHROUGH --env=ENV_REL -- --env --other
  assert_eq "$ENV_REL" "" "collect: bare value flag does not poison its var"
  assert_eq "${PASSTHROUGH[*]}" "--env --other" "collect: bare value flag is forwarded"
}

# Given: a value spec and the arg bar
# When:  parse_args_collect runs
# Then:  ENV_REL stays empty and bar is collected
# Asserts: a positional arg after the separator is collected, not assigned.
test_collect_bare_value_flag_consumed() {
  PASSTHROUGH=()
  ENV_REL=""
  parse_args_collect PASSTHROUGH --env=ENV_REL -- bar
  assert_eq "$ENV_REL" "" "collect: bare value flag sets an empty value"
  assert_eq "${PASSTHROUGH[*]}" "bar" "collect: bare value flag not collected"
}

# Given: two consecutive parses with different specs
# When:  the second parse sees a flag only the first spec declared
# Then:  it is collected, not routed
# Asserts: the per-call registry dies with the call.
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
run_test test_parse_args_tolerant_warns_on_unknown
run_test test_parse_args_bare_value_flag_rejected
run_test test_parse_args_boolean_with_value_rejected
run_test test_parse_args_help_after_separator_not_special
run_test test_parse_args_help_exits_2
run_test test_collect_routes_specs_and_appends_rest
run_test test_collect_never_errors_on_unknown
run_test test_collect_empty_args
run_test test_collect_boolean_spec_not_sinked
run_test test_collect_literal_spec_not_sinked
run_test test_collect_appends_to_predeclared_sink
run_test test_collect_help_not_special
run_test test_collect_bare_value_flag_forwarded
run_test test_collect_bare_value_flag_consumed
run_test test_collect_has_no_stale_registry
test_done test_cli_lib

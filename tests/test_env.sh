#!/usr/bin/env bash
# tests/test_env.sh
# Unit tests for src/libs/env.sh  --  the shared simple KEY=VALUE loader.
# Behavioral contract asserted directly so the library can be reused by other
# loaders without re-reading session_env.sh.

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup
source "$REPO_ROOT/src/libs/env.sh"

test_env_load_exports_valid_line() {
  local F="$FIXTURE_DIR/v.env"
  printf 'FOO=bar\n' > "$F"
  env_load "$F"
  if [[ "${FOO:-unset}" == "bar" ]]; then
    pass "env_load exports a simple KEY=VALUE line"
  else
    fail "FOO='${FOO:-unset}'"
  fi
}

test_env_load_skips_comments_and_blanks() {
  local F="$FIXTURE_DIR/c.env"
  printf '# c\n\n  \n\t# tab\nK=ok\n' > "$F"
  env_load "$F"
  if [[ "${K:-unset}" == "ok" && -z "${c:-}" ]]; then
    pass "env_load skips comment and blank lines"
  else
    fail "K='${K:-unset}'"
  fi
}

test_env_load_trims_value_padding() {
  local F="$FIXTURE_DIR/t.env"
  printf 'V=  padded  \n' > "$F"
  env_load "$F"
  if [[ "${V:-unset}" == "padded" ]]; then
    pass "env_load trims surrounding value whitespace"
  else
    fail "V='[${V:-unset}]'"
  fi
}

test_env_load_skips_invalid_key_with_warning() {
  local F="$FIXTURE_DIR/i.env"
  printf '1BAD=odd\nGOOD=1\n' > "$F"
  local OUT
  OUT=$(env_load "$F" 2>&1; printf '|%s' "${GOOD:-unset}")
  if [[ "$OUT" == *"invalid variable name"* && "$OUT" == *"|1" ]]; then
    pass "env_load skips a non-identifier key with a warning"
  else
    fail "GOOD handling wrong: out='$OUT'"
  fi
}

run_test test_env_load_exports_valid_line
run_test test_env_load_skips_comments_and_blanks
run_test test_env_load_trims_value_padding
run_test test_env_load_skips_invalid_key_with_warning

test_done test_env.sh
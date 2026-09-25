#!/usr/bin/env bash
# tests/test_env.sh
# Unit tests for src/libs/env.sh  --  the shared simple KEY=VALUE loader.
# Behavioral contract asserted directly so the library can be reused by other
# loaders without re-reading session_env.sh.

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup
source "$REPO_ROOT/src/libs/env.sh"

# Given: a .env line of the form K=val # not-a-comment
# When:  env_load runs
# Then:  K holds the whole tail, comment text included
# Asserts: there is no inline-comment rule - pinned so a reader does not assume otherwise
test_env_load_keeps_inline_comment_text_as_value() {
  local F="$FIXTURE_DIR/inline.env"
  printf 'K=val # not-a-comment\n' > "$F"
  env_load "$F"
  if [[ "${K:-}" == "val # not-a-comment" ]]; then
    pass "env_load keeps inline text after a value (no inline comments)  --  pinned"
  else
    fail "inline handling changed: K='[${K:-}]'  --  update this pin if intentional"
  fi
}

# Given: a .env holding ' = ', '  =baz', a whitespace-only line, a bare CR, and a CRLF assignment, run under set -e
# When:  env_load runs
# Then:  rc 0, FOO=bar, baz unset, MYKEY=ok
# Asserts: the regression where a whitespace-only key reached export '=' and aborted the caller under errexit
test_env_load_skips_whitespace_only_key_lines() {
  local F="$FIXTURE_DIR/ws_key.env"
  printf 'FOO=bar\n = \n  =baz\n  \n\t\r\nMYKEY=ok\r\n' > "$F"

  local OUT RC=0
  OUT=$(set -e; env_load "$F" 2>&1 </dev/null \
        && printf '%s|%s|%s|' "${FOO:-unset}" "${baz:-unset}" "${MYKEY:-unset}") || RC=$?

  if [[ $RC -eq 0 && "$OUT" == "bar|unset|ok|" ]]; then
    pass "env_load skips whitespace-only-key lines without error"
  else
    fail "whitespace-only-key line broke parsing: rc=$RC out='$OUT'"
  fi
}

# Given: a .env whose first line is an indented comment, run under set -e
# When:  env_load runs
# Then:  rc 0 and FOO=bar
# Asserts: the regression where an indented comment exported a comment-derived name
test_env_load_skips_indented_comments() {
  local F="$FIXTURE_DIR/indented.env"
  printf '  # indented comment\nFOO=bar\n' > "$F"

  local OUT RC=0
  OUT=$(set -e; env_load "$F" 2>&1 </dev/null && printf '%s|' "${FOO:-unset}") || RC=$?

  if [[ $RC -eq 0 && "$OUT" == "bar|" ]]; then
    pass "env_load skips indented comment lines"
  else
    fail "indented comment broke parsing: rc=$RC out='$OUT'"
  fi
}

# Given: a .env whose key carries a trailing TAB and a CRLF ending, and whose value is space-padded
# When:  env_load runs
# Then:  MYKEY holds the trimmed value
# Asserts: key whitespace and CRLF endings are stripped, not folded into the name
test_env_load_strips_key_whitespace_and_crlf() {
  local F="$FIXTURE_DIR/crlf.env"
  printf 'MYKEY\t\r=  padded value  \r\n' > "$F"
  env_load "$F"
  if [[ "${MYKEY:-}" == "padded value" ]]; then
    pass "env_load strips key whitespace and CRLF line endings"
  else
    fail "whitespace handling broken: MYKEY='[${MYKEY:-}]'"
  fi
}

# Given: a .env file containing FOO=bar
# When:  env_load is called on it
# Then:  FOO holds bar
# Asserts: the happy path - one simple assignment reaches the environment.
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

# Given: a file with a comment, blank and whitespace-only lines, a tab comment, and K=ok
# When:  env_load runs
# Then:  K is ok and no variable named c exists
# Asserts: comment and blank lines are inert; comment text never becomes a variable.
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

# Given: V= with a space-padded value
# When:  env_load runs
# Then:  V is exactly padded, with no surrounding spaces
# Asserts: surrounding whitespace on the value is removed.
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

# Given: a line written with an `export` prefix
# When:  env_load runs
# Then:  the named variable is set and no prefixed name exists
# Asserts: an optional export keyword is stripped, not folded into the name.
test_env_load_strips_export_prefix() {
  local F="$FIXTURE_DIR/export.env"
  printf 'export EXPORTED=yes\n' > "$F"
  env_load "$F"
  if [[ "${EXPORTED:-unset}" == "yes" && -z "${exportEXPORTED:-}" ]]; then
    pass "env_load strips an export prefix"
  else
    fail "export prefix mishandled: EXPORTED='${EXPORTED:-unset}'"
  fi
}

# Given: a non-comment line with no equals sign, followed by a valid line
# When:  env_load runs with stderr captured
# Then:  the stray name is unset, a warning is printed, and loading continues
# Asserts: a line without `=` is rejected, not defined as empty.
test_env_load_skips_line_without_equals() {
  local F="$FIXTURE_DIR/noeq.env"
  printf 'NOEQ\nAFTER=1\n' > "$F"
  local OUT
  OUT=$(env_load "$F" 2>&1; printf '|%s|%s' "${NOEQ:-unset}" "${AFTER:-unset}")
  if [[ "$OUT" == *"without '='"* && "$OUT" == *"|unset|1" ]]; then
    pass "env_load skips a line without '=' and continues"
  else
    fail "no-equals line mishandled: out='$OUT'"
  fi
}

# Given: 1BAD=odd followed by GOOD=1
# When:  env_load runs with stderr captured
# Then:  the output contains "invalid variable name" and GOOD=1 was still applied
# Asserts: a non-identifier key is skipped with a warning, and the loader continues.
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
run_test test_env_load_strips_export_prefix
run_test test_env_load_skips_line_without_equals
run_test test_env_load_skips_invalid_key_with_warning
run_test test_env_load_keeps_inline_comment_text_as_value
run_test test_env_load_skips_whitespace_only_key_lines
run_test test_env_load_skips_indented_comments
run_test test_env_load_strips_key_whitespace_and_crlf

test_done test_env.sh
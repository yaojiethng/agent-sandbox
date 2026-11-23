#!/usr/bin/env bash
# tests/test_env.sh
# Unit tests for src/libs/env.sh  --  the one parser for simple KEY=VALUE env
# files. The parser prints and never exports, so each case asserts on
# env_parse's output or on env_get's return value, not on the shell's state.

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup
source "$REPO_ROOT/src/libs/env.sh"

# Given: a .env line of the form K=val # not-a-comment
# When:  env_get reads K
# Then:  it returns the whole tail, comment text included
# Asserts: there is no inline-comment rule.
test_env_get_keeps_inline_comment_text_as_value() {
  local F="$FIXTURE_DIR/inline.env"
  printf 'K=val # not-a-comment\n' > "$F"
  assert_eq 'val # not-a-comment' "$(env_get "$F" K)" "no inline-comment rule"
}

# Given: a file whose first entry has a whitespace-only key line before it
# When:  env_parse runs
# Then:  the stray line produces no entry and no error
# Asserts: a key that is only whitespace is skipped, not defined as empty.
test_env_parse_skips_whitespace_only_key_lines() {
  local F="$FIXTURE_DIR/wsonly.env"
  printf '  =x\nA=1\n' > "$F"
  local RC=0 OUT
  OUT=$(env_parse "$F" 2>&1) || RC=$?
  assert_eq "0" "$RC" "a whitespace-only key line is not an error"
  assert_eq "A=1" "$OUT" "only the valid entry is printed"
}

# Given: an indented comment line
# When:  env_parse runs
# Then:  it is skipped silently
# Asserts: comment detection is leading-whitespace tolerant.
test_env_parse_skips_indented_comments() {
  local F="$FIXTURE_DIR/indented.env"
  printf '   # indented\nA=1\n' > "$F"
  assert_eq "A=1" "$(env_parse "$F" 2>&1)" "an indented comment is inert"
}

# Given: keys padded with spaces and values ending in CRLF, and one exported
# When:  env_parse runs
# Then:  the keys are trimmed and the CRLF is gone
# Asserts: key whitespace and CRLF are stripped from both sides of the entry.
test_env_parse_strips_key_whitespace_and_crlf() {
  local F="$FIXTURE_DIR/crlf.env"
  printf ' K1 =v1\r\nexport K2=v2\r\n' > "$F"
  assert_eq "$(printf 'K1=v1\nK2=v2')" "$(env_parse "$F")" "keys trimmed, CRLF stripped"
}

# Given: a .env file containing FOO=bar
# When:  env_parse runs
# Then:  it prints FOO=bar
# Asserts: the happy path -- one simple assignment round-trips.
test_env_parse_reads_a_simple_line() {
  local F="$FIXTURE_DIR/v.env"
  printf 'FOO=bar\n' > "$F"
  assert_eq "FOO=bar" "$(env_parse "$F")" "a simple KEY=VALUE line is parsed"
}

# Given: a file with comment, blank and whitespace-only lines around K=ok
# When:  env_parse runs
# Then:  only K=ok is printed
# Asserts: comment and blank lines are inert; comment text never becomes a key.
test_env_parse_skips_comments_and_blanks() {
  local F="$FIXTURE_DIR/c.env"
  printf '# c\n\n  \n\t# tab\nK=ok\n' > "$F"
  assert_eq "K=ok" "$(env_parse "$F")" "comment and blank lines are skipped"
}

# Given: V= with a space-padded value
# When:  env_get reads V
# Then:  it returns the value with no surrounding whitespace
# Asserts: surrounding whitespace on the value is removed.
test_env_parse_trims_value_padding() {
  local F="$FIXTURE_DIR/t.env"
  printf 'V=  padded  \n' > "$F"
  assert_eq "padded" "$(env_get "$F" V)" "surrounding value whitespace is trimmed"
}

# Given: a line written with an `export` prefix
# When:  env_get reads the key
# Then:  it returns the value under the bare name
# Asserts: an optional export keyword is stripped, not folded into the name.
test_env_parse_strips_export_prefix() {
  local F="$FIXTURE_DIR/export.env"
  printf 'export EXPORTED=yes\n' > "$F"
  assert_eq "EXPORTED=yes" "$(env_parse "$F")" "the export prefix is stripped"
}

# Given: a non-comment line with no equals sign, followed by a valid line
# When:  env_parse runs with stderr captured
# Then:  a warning names the bad line and the valid entry is still printed
# Asserts: a line without `=` is rejected, not defined as empty.
test_env_parse_skips_line_without_equals() {
  local F="$FIXTURE_DIR/noeq.env"
  printf 'NOEQ\nAFTER=1\n' > "$F"
  local OUT
  OUT=$(env_parse "$F" 2>&1)
  assert_contains "$OUT" "without '='" "the warning names the malformed line"
  assert_contains "$OUT" "AFTER=1" "the valid line still parses"
  assert_not_contains "$OUT" "NOEQ=" "the malformed line produced no entry"
}

# Given: 1BAD=odd followed by GOOD=1
# When:  env_parse runs with stderr captured
# Then:  the output warns "invalid variable name" and still prints GOOD=1
# Asserts: a non-identifier key is skipped with a warning, and parsing continues.
test_env_parse_skips_invalid_key_with_warning() {
  local F="$FIXTURE_DIR/i.env"
  printf '1BAD=odd\nGOOD=1\n' > "$F"
  local OUT
  OUT=$(env_parse "$F" 2>&1)
  assert_contains "$OUT" "invalid variable name" "the warning names the invalid key"
  assert_contains "$OUT" "GOOD=1" "the valid line still parses"
}

# Given: a .env with a comment line and a valid assignment
# When:  env_parse runs with stderr captured
# Then:  stderr is empty and the assignment is printed
# Asserts: a comment line is skipped silently, not warned about as malformed.
test_env_parse_comment_lines_are_warning_free() {
  local F="$FIXTURE_DIR/comment_free.env"
  printf '# a comment\nK=ok\n' > "$F"
  local errfile="$FIXTURE_DIR/comment_free.err"
  local OUT
  OUT=$(env_parse "$F" 2>"$errfile")
  assert_eq "K=ok" "$OUT" "the comment line is inert"
  assert_eq "" "$(cat "$errfile")" "a comment line produces no warning"
}

# Given: a record, and a reader that has read a key from it
# When:  a child process reads its own environment
# Then:  the child sees nothing
# Asserts: reading a record key is a call, not an assignment. A record key
#          reaches a reader as a return value, never as a child's environment.
test_env_parse_does_not_export_to_child_process() {
  local F="$FIXTURE_DIR/child.env"
  printf 'FOO=bar\n' > "$F"
  local SEEN
  SEEN=$(env_get "$F" FOO)
  assert_eq "bar" "$SEEN" "the read returns the value"
  assert_eq "" "$(bash -c 'printf "%s" "${FOO:-}"')" "no record key reaches a child's environment"
}

# Given: a .env holding a double-quoted and a single-quoted value with padding
# When:  env_get reads them
# Then:  each returns the unquoted contents, padding intact
# Asserts: one layer of matching quotes is stripped; padding inside quotes survives.
test_env_parse_strips_matching_quotes() {
  local F="$FIXTURE_DIR/quoted.env"
  printf 'D="a b"\n%s\n' "S='  keep  '" > "$F"
  assert_eq "a b" "$(env_get "$F" D)" "a double-quoted value is unquoted"
  assert_eq "  keep  " "$(env_get "$F" S)" "quoting preserves inner padding"
}

# Given: an unbalanced quote, an embedded quote, an interior quote pair, a lone quote
# When:  env_get reads each
# Then:  each value is verbatim: the ends-pairing rule never strips an interior pair
# Asserts: only a value fully enclosed by one quote pair, with no quote inside, is stripped.
test_env_parse_keeps_unbalanced_and_embedded_quotes() {
  local F="$FIXTURE_DIR/unbalanced.env"
  printf 'U="abc\nE=a"b"c\nP="a" and "b"\nW="\n' > "$F"
  assert_eq '"abc' "$(env_get "$F" U)" "an unbalanced leading quote stays"
  assert_eq 'a"b"c' "$(env_get "$F" E)" "an embedded quote stays"
  assert_eq '"a" and "b"' "$(env_get "$F" P)" "an interior quote pair stays"
  assert_eq '"' "$(env_get "$F" W)" "a lone quote stays"
}

# Given: an empty quoted value and a quoted value behind an export prefix
# When:  env_get reads them
# Then:  Z is empty and Q holds the unquoted contents
# Asserts: quote stripping applies after the export-prefix and empty-value paths.
test_env_parse_strips_quotes_on_empty_and_exported_values() {
  local F="$FIXTURE_DIR/emptyquoted.env"
  printf 'Z=""\nexport Q="x y"\n' > "$F"
  assert_eq "" "$(env_get "$F" Z)" "an empty quoted value is empty"
  assert_eq "x y" "$(env_get "$F" Q)" "quotes are stripped behind an export prefix"
}

# Given: a .env whose keys are named LINE, KEY and VALUE (parser scratch names before the prefix)
# When:  env_parse runs
# Then:  all three entries are printed with their values
# Asserts: only the _env_ prefix is reserved; ordinary names cannot be swallowed.
test_env_parse_accepts_keys_named_like_former_scratch_names() {
  local F="$FIXTURE_DIR/shadow.env"
  printf 'LINE=one\nKEY=two\nVALUE=three\n' > "$F"
  assert_eq "$(printf 'LINE=one\nKEY=two\nVALUE=three')" "$(env_parse "$F")" \
    "LINE, KEY and VALUE parse as ordinary keys"
}

# Given: a .env key that starts with the parser's _env_ scratch prefix
# When:  env_parse runs with stderr captured
# Then:  the key is skipped with a warning and parsing continues
# Asserts: a key cannot take the place of a parser scratch variable.
test_env_parse_skips_scratch_prefixed_key_with_warning() {
  local F="$FIXTURE_DIR/scratchprefix.env"
  printf '_env_line=x\nAFTER=1\n' > "$F"
  local OUT
  OUT=$(env_parse "$F" 2>&1)
  assert_contains "$OUT" "shadows the parser's scratch" "the warning names the reserved prefix"
  assert_contains "$OUT" "AFTER=1" "parsing continues past the skipped key"
}

# Given: a record that states the same key twice
# When:  env_get reads it
# Then:  the first value wins and the second is ignored
# Asserts: a record has one value per key, so a later append cannot outlive the
#          value a reader already saw.
test_env_get_returns_the_first_occurrence() {
  local F="$FIXTURE_DIR/dup.env"
  printf 'K=first\nK=second\n' > "$F"
  assert_eq "first" "$(env_get "$F" K)" "the first occurrence wins"
}

# Given: a missing file and a missing key
# When:  env_parse and env_get run
# Then:  both print nothing and succeed
# Asserts: absence is the caller's judgement, not the parser's error.
test_env_get_absent_file_and_key_are_empty() {
  assert_eq "" "$(env_parse "$FIXTURE_DIR/absent.env")" "a missing file prints nothing"
  assert_eq "0" "$?" "a missing file is not an error"
  assert_eq "" "$(env_get "$FIXTURE_DIR/absent.env" K)" "a missing key is empty"
}

run_test test_env_get_keeps_inline_comment_text_as_value
run_test test_env_parse_skips_whitespace_only_key_lines
run_test test_env_parse_skips_indented_comments
run_test test_env_parse_strips_key_whitespace_and_crlf
run_test test_env_parse_reads_a_simple_line
run_test test_env_parse_skips_comments_and_blanks
run_test test_env_parse_trims_value_padding
run_test test_env_parse_strips_export_prefix
run_test test_env_parse_skips_line_without_equals
run_test test_env_parse_skips_invalid_key_with_warning
run_test test_env_parse_comment_lines_are_warning_free
run_test test_env_parse_does_not_export_to_child_process
run_test test_env_parse_strips_matching_quotes
run_test test_env_parse_keeps_unbalanced_and_embedded_quotes
run_test test_env_parse_strips_quotes_on_empty_and_exported_values
run_test test_env_parse_accepts_keys_named_like_former_scratch_names
run_test test_env_parse_skips_scratch_prefixed_key_with_warning
run_test test_env_get_returns_the_first_occurrence
run_test test_env_get_absent_file_and_key_are_empty

test_done test_env.sh

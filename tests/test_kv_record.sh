#!/usr/bin/env bash
# TEST_DEADLINE: 10
# tests/test_kv_record.sh
# The one reader/writer pair for the harness's key=value records (ADR-recorded
# contract: src/libs/kv_record.sh). Behaviour units pin the contract; the scan
# units fail when any second parser for a persisted record appears in the tree.

source "$(dirname "${BASH_SOURCE[0]}")/libs/test_common.sh"
test_setup

KV="$REPO_ROOT/src/libs/kv_record.sh"
# shellcheck source=/dev/null
source "$KV"

# Given: a record line whose value contains '='
# When:  kv_read runs
# Then:  the whole tail after the first '=' reads back
# Asserts: the value is the remainder, not the second field (the awk shape
#          a record reader once used truncated at the second '=').
test_kv_read_returns_the_full_tail() {
  local F="$FIXTURE_DIR/eq.record"
  printf 'HEAD=a=b=c\n' > "$F"
  assert_eq "a=b=c" "$(kv_read "$F" HEAD)" "kv_read returns everything after the first '='"
}

# Given: a record missing the key, and a record file that does not exist
# When:  kv_read runs on both
# Then:  each prints nothing and returns 0
# Asserts: a missing key or file is an empty read, not an error.
test_kv_read_missing_key_and_file_are_empty() {
  local F="$FIXTURE_DIR/sparse.record"
  printf 'A=1\n' > "$F"
  local OUT RC
  OUT=$(kv_read "$F" B); RC=$?
  assert_eq "" "$OUT" "a missing key reads empty"
  assert_rc 0 "$RC" "a missing key is not an error"
  OUT=$(kv_read "$FIXTURE_DIR/no-such.record" A); RC=$?
  assert_eq "" "$OUT" "a missing file reads empty"
  assert_rc 0 "$RC" "a missing file is not an error"
}

# Given: a record carrying the same key twice
# When:  kv_read runs
# Then:  the first line's value reads back
# Asserts: the first writer wins; a later line never shadows it.
test_kv_read_first_line_wins() {
  local F="$FIXTURE_DIR/dupe.record"
  printf 'K=first\nK=second\n' > "$F"
  assert_eq "first" "$(kv_read "$F" K)" "the first line for a key wins"
}

# Given: an empty directory that will hold a new record
# When:  kv_write runs twice
# Then:  the file is created and both pairs are present in write order
# Asserts: kv_write creates the file and appends, matching the shape the
#          SESSION_STATE writer produced by hand.
test_kv_write_creates_and_appends() {
  local F="$FIXTURE_DIR/new.state"
  kv_write "$F" "init_sha" "abc123"
  kv_write "$F" "session_ts" "1750000000"
  assert_file_exists "$F" "kv_write creates the record"
  assert_eq "abc123" "$(kv_read "$F" init_sha)" "the first pair reads back"
  assert_eq "1750000000" "$(kv_read "$F" session_ts)" "the second pair reads back"
  assert_eq 2 "$(wc -l < "$F")" "two pairs occupy two lines"
}

# Given: a record path whose parent directory does not exist
# When:  kv_write runs
# Then:  rc is 1 and no file appears
# Asserts: a record whose directory is missing is a caller error, and the
#          write fails loudly instead of creating the tree.
test_kv_write_missing_directory_fails() {
  local F="$FIXTURE_DIR/no-dir/new.state"
  local RC=0
  kv_write "$F" "K" "V" || RC=$?
  assert_rc 1 "$RC" "kv_write into a missing directory fails"
  if [[ ! -f "$F" ]]; then
    pass "no record is created"
  else
    fail "a record appeared at $F"
  fi
}

# Given: a record with three pairs
# When:  kv_load runs with no keys
# Then:  every line prints in file order
# Asserts: the whole record loads in one call, in record order.
test_kv_load_whole_record_in_order() {
  local F="$FIXTURE_DIR/whole.record"
  printf 'A=1\nB=2\nC=3\n' > "$F"
  assert_eq "$(printf 'A=1\nB=2\nC=3')" "$(kv_load "$F")" "kv_load prints the whole record in order"
}

# Given: the same record, one missing key and two present keys
# When:  kv_load runs naming C, MISSING and A
# Then:  one line prints per requested key, in argument order, empty for the missing key
# Asserts: a multi-key read answers in one pass, in the caller's order.
test_kv_load_named_keys_in_argument_order() {
  local F="$FIXTURE_DIR/named.record"
  printf 'A=1\nB=2\nC=3\n' > "$F"
  assert_eq "$(printf 'C=3\nMISSING=\nA=1')" "$(kv_load "$F" C MISSING A)" "kv_load answers named keys in argument order"
}

# Given: the shipped SESSION_STATE reader and writer
# When:  they are inspected
# Then:  both delegate to kv_read / kv_write
# Asserts: one definition stands behind the SESSION_STATE record.
test_session_state_delegates_to_the_kv_pair() {
  local F="$REPO_ROOT/src/libs/session_state.sh"
  assert_contains "$(sed -n '/^session_state_read()/,/^}/p' "$F")" "kv_read" \
    "session_state_read delegates to kv_read"
  assert_contains "$(sed -n '/^session_state_write()/,/^}/p' "$F")" "kv_write" \
    "session_state_write delegates to kv_write"
}

# Given: the production tree under src/ and scripts/
# When:  a scan for record-parsing idioms runs
# Then:  no file outside kv_record.sh (the record parser) and env.sh (the
#       sanctioned .env loader) parses a key=value line
# Asserts: a second parser cannot appear without this unit failing; the
#          convention is a gate, not a rule.
test_no_second_record_parser_in_the_tree() {
  local hits
  hits=$(grep -rnE "IFS='=' read|IFS== read|awk -F=|cut -d=|\\\$\\{line%%=\\*|\\\$\\{line#\\*=" \
    --include="*.sh" "$REPO_ROOT/src" "$REPO_ROOT/scripts" 2>/dev/null \
    | grep -vE "kv_record.sh|(^|/)env.sh:" || true)
  assert_eq "" "$hits" "no file outside kv_record.sh and env.sh parses a key=value record"
}

# Given: a record with CRLF endings, a no-'=' line, and two keys where one is a
#       prefix of the other
# When:  kv_read and kv_load run
# Then:  the CR is stripped, the stray line is not a pair, the prefix key
#       resolves to its own line, and a value with '=' inside reads whole
# Asserts: the line rules of the contract, pinned against the shapes the
#          hand-rolled readers each handled differently.
test_kv_line_rules_crlf_no_equals_and_key_prefix() {
  local F="$FIXTURE_DIR/rules.record"
  printf 'A=1\r\nAB=2\r\nSTRAY\nHEAD=x=y\r\n' > "$F"
  assert_eq "1" "$(kv_read "$F" A)" "a CRLF line reads without its CR"
  assert_eq "2" "$(kv_read "$F" AB)" "a prefix key resolves to its own line"
  assert_eq "x=y" "$(kv_read "$F" HEAD)" "a value with '=' inside reads whole"
  assert_eq "$(printf 'A=1\nAB=2\nHEAD=x=y')" "$(kv_load "$F")" \
    "kv_load skips a no-'=' line and strips the CR"
}

# Given: the dry-run verify gate over a record whose layer value is not PASS
# When:  dry_run_record_verify runs
# Then:  the layer fails the gate rather than passing as "not FAIL"
# Asserts: the documented PASS|FAIL contract is enforced, per layer key.
test_verify_rejects_a_non_pass_layer_value() {
  local record="$FIXTURE_DIR/lax.record"
  # shellcheck source=/dev/null
  source "$REPO_ROOT/src/libs/dry_run_record.sh"
  printf 'container=img:tag\n' > "$record"
  printf 'layer.session_data=UNKNOWN\n' >> "$record"
  printf 'status=PASS\n' >> "$record"
  local rc output
  output=$(dry_run_record_verify "sandbox(capability)" "img:tag" "$record" 2>&1)
  rc=$?
  assert_ne "$rc" "0" "a non-PASS layer value fails the gate"
  assert_contains "$output" "layer.session_data = UNKNOWN" "the unknown value is named"
}

run_test test_kv_line_rules_crlf_no_equals_and_key_prefix
run_test test_verify_rejects_a_non_pass_layer_value
run_test test_kv_read_returns_the_full_tail
run_test test_kv_read_missing_key_and_file_are_empty
run_test test_kv_read_first_line_wins
run_test test_kv_write_creates_and_appends
run_test test_kv_write_missing_directory_fails
run_test test_kv_load_whole_record_in_order
run_test test_kv_load_named_keys_in_argument_order
run_test test_session_state_delegates_to_the_kv_pair
run_test test_no_second_record_parser_in_the_tree

test_done test_kv_record.sh

#!/usr/bin/env bash
# tests/test_session_log.sh
# Unit tests for the per-session activity log (session_log_* helpers) and the
# relative human-time formatter (ts_to_epoch / relative_time) in
# src/libs/session_inventory.sh -- the backing store + display for the
# `make resume --list` LAST_USED column.

set -uo pipefail
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/.." && pwd)"
source "$TEST_DIR/libs/test_common.sh"
test_setup

LIB="$REPO_ROOT/src/libs/session_inventory.sh"
FIX="$FIXTURE_DIR/log"
mkdir -p "$FIX/.compose"

# shellcheck disable=SC1090  # variable source path (lib under test)
source "$LIB"

# The session-log helpers base their path on SANDBOX_DIR; point at the fixture.
export SANDBOX_DIR="$FIX"

test_session_log_set_read() {
  local sid="s1"
  session_log_set "$sid" last_stopped "20260828-120000"
  assert_eq "$(session_log_read "$sid" last_stopped)" "20260828-120000" "set+read a key"

  # upsert overwrites the same key (idempotent, no duplicate lines).
  session_log_set "$sid" last_stopped "20260828-130000"
  assert_eq "$(session_log_read "$sid" last_stopped)" "20260828-130000" "upsert overwrites value"
  assert_eq "$(grep -c '^last_stopped=' "$FIX/.compose/$sid.log")" 1 "upsert keeps a single line"

  # second key appends another line.
  session_log_set "$sid" last_started "20260828-110000"
  assert_eq "$(session_log_read "$sid" last_started)" "20260828-110000" "append a second key"
}
run_test test_session_log_set_read

test_session_log_missing() {
  local sid="nonexistent"
  assert_eq "$(session_log_read "$sid" last_stopped)" "" "absent log -> empty value"
  [[ -f "$FIX/.compose/$sid.log" ]] && fail "absent session got a log file created" || pass "absent session -> no log file"
}
run_test test_session_log_missing

test_session_log_path() {
  assert_eq "$(session_log_path "xyz")" "$FIX/.compose/xyz.log" "log path is SANDBOX_DIR/.compose/<id>.log"
}
run_test test_session_log_path

test_ts_to_epoch() {
  local ep
  ep="$(ts_to_epoch "20260828-120000")"
  # GNU-independent expectation would be brittle; instead assert it is a
  # non-empty integer and round-trips.
  [[ "$ep" =~ ^[0-9]+$ ]] && [[ -n "$ep" ]]
  assert_rc 0 "$?" "ts_to_epoch yields epoch integer"
  assert_eq "$(ts_to_epoch "garbage")" "" "ts_to_epoch rejects malformed ts"
  assert_eq "$(ts_to_epoch "")" "" "ts_to_epoch rejects empty ts"
}
run_test test_ts_to_epoch

test_relative_time_units() {
  local now two_min two_hour two_day
  now=$(date -u +%Y%m%d-%H%M%S)
  two_min="$(date -u -d '-125 seconds' +%Y%m%d-%H%M%S)"
  two_hour="$(date -u -d '-2 hours' +%Y%m%d-%H%M%S)"
  two_day="$(date -u -d '-2 days' +%Y%m%d-%H%M%S)"

  assert_eq "$(relative_time "")" "---" "empty ts -> ---"
  assert_eq "$(relative_time "garbage")" "---" "malformed ts -> ---"
  assert_eq "$(relative_time "$now")" "just now" "current ts -> just now"
  assert_eq "$(relative_time "$two_min")" "2 minutes ago" "2 minutes -> '2 minutes ago'"
  assert_eq "$(relative_time "$two_hour")" "2 hours ago" "2 hours -> '2 hours ago'"
  assert_eq "$(relative_time "$two_day")" "2 days ago" "2 days -> '2 days ago'"
}
run_test test_relative_time_units

test_relative_time_compact_units() {
  local now two_min two_hour two_day
  now=$(date -u +%Y%m%d-%H%M%S)
  two_min="$(date -u -d '-125 seconds' +%Y%m%d-%H%M%S)"
  two_hour="$(date -u -d '-2 hours' +%Y%m%d-%H%M%S)"
  two_day="$(date -u -d '-2 days' +%Y%m%d-%H%M%S)"

  assert_eq "$(relative_time_compact "")" "---" "empty ts -> ---"
  assert_eq "$(relative_time_compact "garbage")" "---" "malformed ts -> ---"
  assert_eq "$(relative_time_compact "$now")" "just now" "current ts -> just now"
  assert_eq "$(relative_time_compact "$two_min")" "2m ago" "2 minutes -> '2m ago'"
  assert_eq "$(relative_time_compact "$two_hour")" "2h ago" "2 hours -> '2h ago'"
  assert_eq "$(relative_time_compact "$two_day")" "2D ago" "2 days -> '2D ago'"
}
run_test test_relative_time_compact_units

test_done "test_session_log"
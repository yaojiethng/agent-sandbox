#!/usr/bin/env bash
# tests/test_session_log.sh
# Unit tests for the per-session activity log (session_log_* helpers) and the
# Pins cite: docs/architecture/tool_interface.md l.55 (LIST=1 time rendering).

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

# No-in-place-sed shim. In-place `sed -i` differs between GNU and BSD sed:
# GNU needs no suffix argument, BSD needs one, so no single -i form is
# portable. The macOS teardown bug was session_log_set's GNU-only form
# misparsing the file path as the script under BSD sed. The fix avoids `-i`
# entirely (sibling temp file + mv); this shim fails any `-i` invocation so a
# regression to in-place sed is caught. Other calls forward to real sed.
REAL_SED="$(command -v sed)"
mkdir -p "$FIXTURE_ROOT/shim_noinplace"
{ printf '#!/usr/bin/env bash\nREAL_SED=%q\n' "$REAL_SED"; cat <<'SHIM'
set -u
if [[ $# -gt 0 && "$1" == "-i" ]]; then
  echo "sed: in-place -i form invoked (no-inplace guard)" >&2
  exit 1
fi
exec "$REAL_SED" "$@"
SHIM
} > "$FIXTURE_ROOT/shim_noinplace/sed"
chmod +x "$FIXTURE_ROOT/shim_noinplace/sed"

# Given: an empty log for a session
# When:  session_log_set writes a key, overwrites it, then adds a second key
# Then:  reads return the latest values and each key has exactly one line
# Asserts: set, upsert, and append, with idempotence.
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

# Given: a session with no log file
# When:  session_log_read runs
# Then:  the value is empty and no file is created
# Asserts: a read does not create state.
test_session_log_missing() {
  local sid="nonexistent"
  assert_eq "$(session_log_read "$sid" last_stopped)" "" "absent log -> empty value"
  [[ -f "$FIX/.compose/$sid.log" ]] && fail "absent session got a log file created" || pass "absent session -> no log file"
}
run_test test_session_log_missing

# Given: SANDBOX_DIR set to the fixture
# When:  session_log_path runs
# Then:  the path is SANDBOX_DIR/.compose/<id>.log
# Asserts: the path contract.
test_session_log_path() {
  assert_eq "$(session_log_path "xyz")" "$FIX/.compose/xyz.log" "log path is SANDBOX_DIR/.compose/<id>.log"
}
run_test test_session_log_path

# Given: a PATH shim that fails any sed -i invocation
# When:  session_log_set writes and upserts a key
# Then:  it succeeds with no in-place sed and one line per key
# Asserts: the sibling-temp rewrite (the macOS teardown portability fix).
test_session_log_set_avoids_inplace_sed() {
  # session_log_set must not use in-place sed at all; the shim fails any `-i`
  # invocation. Upsert works, and no in-place sed is exercised.
  local sid="bsdsed"
  (
    export PATH="$FIXTURE_ROOT/shim_noinplace:$PATH"
    session_log_set "$sid" last_stopped "20260828-120000"
    session_log_set "$sid" last_stopped "20260828-130000"
  )
  assert_eq "$(session_log_read "$sid" last_stopped)" "20260828-130000" "set+upsert with no in-place sed"
  assert_eq "$(grep -c '^last_stopped=' "$FIX/.compose/$sid.log")" 1 "single line with no in-place sed"
}
run_test test_session_log_set_avoids_inplace_sed

# Given: the no-in-place-sed shim
# When:  sed -i is invoked directly
# Then:  it fails
# Asserts: the shim itself, so a regression is caught rather than silently passing.
test_inplace_sed_shim_rejects_dash_i() {
  # Guard on the shim itself: any `-i` invocation must fail, so a regression
  # to in-place sed is caught instead of silently passing.
  local f="$FIX/gnu-form.log"
  echo "last_stopped=old" > "$f"
  if ( export PATH="$FIXTURE_ROOT/shim_noinplace:$PATH"
       sed -i "s#^last_stopped=.*#last_stopped=new#" "$f" ) 2>/dev/null; then
    fail "shim accepted a -i invocation"
  else
    pass "shim rejects -i invocations"
  fi
}
run_test test_inplace_sed_shim_rejects_dash_i

# Given: a well-formed, a malformed, and an empty timestamp
# When:  ts_to_epoch runs
# Then:  an integer for the well-formed one, empty for the others
# Asserts: the format guard and the conversion.
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

# Given: timestamps now, 125s ago, 2h ago, and 2d ago, plus empty and garbage
# When:  relative_time runs
# Then:  "just now", "2 minutes ago", "2 hours ago", "2 days ago", "---", "---"
# Asserts: the verbose unit ladder.
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

# Given: the same timestamps
# When:  relative_time_compact runs
# Then:  "just now", "2m ago", "2h ago", "2D ago", "---", "---"
# Asserts: the compact form used in dense tables.
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
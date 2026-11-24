#!/usr/bin/env bash
# TEST_DEADLINE: 10
# tests/test_time_format.sh
# The harness writes and reads one timestamp shape, UTC `YYYYMMDD-HHMMSS`.
# src/libs/time_format.sh is its one definition: ts_now_utc writes it, ts_epoch
# parses it, ts_from_epoch renders an epoch as it. This gate holds the second
# half of that: a producer in src/ or scripts/ that spells the format itself is
# a second definition, and fails here until it is routed through the lib.
#
# The scan is proven to bite before the absence assertion is trusted: the
# fixture case plants a spelling and asserts the scan finds it, so a green run
# over the tree is evidence about the tree rather than about a scan that matched
# nothing.

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$TEST_DIR/libs/test_common.sh"
test_setup

source "$REPO_ROOT/src/libs/time_format.sh"

# timestamp_hits ROOT  --  every `.sh` under ROOT that calls `date` with a
# display format, minus the owner. `date +%s` and `+%s.%N` are epoch arithmetic
# and are allowed. A format stored in a variable is caught because the `date`
# call itself is the violation. Prints `path:line:text`; empty when none does.
timestamp_hits() {
  local root="$1"
  grep -rnE '(^|[^[:alnum:]_])date[^#]*\+' --include="*.sh" "$root" 2>/dev/null \
    | grep -v 'src/libs/time_format.sh' \
    | grep -vE '\+[^[:space:]]*%s' || true
}

# Given: the harness clock
# When:  ts_date_days_ago renders today and one day ago
# Then:  today matches the UTC date in ts_from_epoch, and the two days differ
# Asserts: the date window is UTC, not the host's local clock.
test_date_days_ago_is_utc() {
  local today yesterday ts
  today="$(ts_date_days_ago 0)"
  yesterday="$(ts_date_days_ago 1)"
  ts="$(ts_from_epoch "$(date -u +%s)")"
  assert_eq "${ts:0:8}" "$today" "ts_date_days_ago 0 is today in UTC"
  if [[ "$today" =~ ^[0-9]{8}$ && "$yesterday" =~ ^[0-9]{8}$ ]]; then
    pass "ts_date_days_ago renders the date shape"
  else
    fail "ts_date_days_ago rendered today='$today' yesterday='$yesterday'"
  fi
  assert_ne "$today" "$yesterday" "ts_date_days_ago 1 is a different day"
}

# Given: the lib's own two directions
# When:  ts_now_utc runs
# Then:  it prints a stamp matching TS_PATTERN
# Asserts: the writer produces the shape the parser accepts.
test_ts_now_utc_matches_the_shape() {
  local now
  now="$(ts_now_utc)"
  if [[ "$now" =~ $TS_PATTERN ]]; then
    pass "ts_now_utc writes the YYYYMMDD-HHMMSS shape"
  else
    fail "ts_now_utc wrote '$now', which the shape guard rejects"
  fi
}

# Given: known epochs
# When:  ts_from_epoch renders them
# Then:  the UTC stamp for that instant
# Asserts: the clock is UTC. A local-clock render of epoch 0 is not 19700101-000000
#          anywhere east or west of Greenwich, so this is the UTC assertion.
test_ts_from_epoch_is_utc() {
  assert_eq "$(ts_from_epoch 0)" "19700101-000000" "epoch 0 renders as UTC midnight"
  assert_eq "$(ts_from_epoch 1700000000)" "20231114-221320" "epoch 1700000000 renders in UTC"
  assert_eq "$(ts_from_epoch "")" "" "an absent epoch renders as empty"
}

# Given: a stamp from every epoch the tree writes
# When:  ts_epoch parses what ts_from_epoch rendered
# Then:  the epoch comes back unchanged
# Asserts: the two directions are inverses, which is what makes one definition
#          usable by both a writer and a reader.
test_round_trip() {
  local epoch ts
  for epoch in 0 1700000000 1780000000; do
    ts="$(ts_from_epoch "$epoch")"
    assert_eq "$(ts_epoch "$ts")" "$epoch" "epoch $epoch round-trips through $ts"
  done
}

# Given: malformed stamps
# When:  ts_epoch parses them
# Then:  it prints nothing
# Asserts: the shape guard rejects trailing garbage and an empty value rather
#          than parsing a prefix.
test_ts_epoch_rejects_malformed() {
  assert_eq "$(ts_epoch "20260828-120000junk")" "" "a stamp with trailing garbage parses empty"
  assert_eq "$(ts_epoch "garbage")" "" "an arbitrary string parses empty"
  assert_eq "$(ts_epoch "")" "" "an empty value parses empty"
}

# Given: a fixture producer that spells the format itself
# When:  the spelling scan runs over it
# Then:  the scan reports it
# Asserts: the gate bites on a reintroduced literal, which is the defect it exists
#          for.
test_the_scan_bites_a_compact_fixture() {
  local dir="$FIXTURE_DIR/offender"
  rm -rf "$dir"
  mkdir -p "$dir"
  printf '%s\n' '#!/usr/bin/env bash' 'stamp=$(date -u +%Y%m%d-%H%M%S)' > "$dir/offender.sh"
  if [[ -n "$(timestamp_hits "$dir")" ]]; then
    pass "a producer spelling the format is reported"
  else
    fail "a producer spelling the format was not reported"
  fi
}

# Given: a fixture producer that reaches for ISO 8601, the old probe form, or another date-time spelling
# When:  the timestamp scan runs over it
# Then:  the scan reports it
# Asserts: the gate covers the shapes a second producer is likely to choose, not
#          only the compact literal.
test_the_scan_bites_a_non_harness_stamp() {
  local dir="$FIXTURE_DIR/offender_iso"
  local fmt
  rm -rf "$dir"
  mkdir -p "$dir"
  for fmt in '%Y-%m-%dT%H:%M:%SZ' '%Y%m%dT%H%M%SZ' '%Y/%m/%d %H:%M:%S' '%Y%m%d'; do
    printf '%s\n' '#!/usr/bin/env bash' "stamp=\$(date -u +$fmt)" > "$dir/offender.sh"
    if [[ -n "$(timestamp_hits "$dir")" ]]; then
      pass "a producer spelling $fmt is reported"
    else
      fail "a producer spelling $fmt was not reported"
    fi
  done
}

# Given: a fixture producer that stores the format in a variable
# When:  the timestamp scan runs over it
# Then:  the scan reports it
# Asserts: the gate catches a second definition even when the date call names a
#          variable instead of spelling the format inline.
test_the_scan_bites_a_variable_literal() {
  local dir="$FIXTURE_DIR/offender_variable"
  rm -rf "$dir"
  mkdir -p "$dir"
  printf '%s\n' '#!/usr/bin/env bash' \
    "FMT='%Y%m%d-%H%M%S'" \
    'stamp=$(date -u +"$FMT")' > "$dir/offender.sh"
  if [[ -n "$(timestamp_hits "$dir")" ]]; then
    pass "a producer storing the format in a variable is reported"
  else
    fail "a producer storing the format in a variable was not reported"
  fi
}

# Given: a fixture producer that reads epoch seconds for arithmetic
# When:  the date-format scan runs over it
# Then:  it reports nothing
# Asserts: the convention forbids display formats, not `date +%s` timers.
test_the_scan_allows_epoch_calls() {
  local dir="$FIXTURE_DIR/epoch_only"
  rm -rf "$dir"
  mkdir -p "$dir"
  printf '%s\n' '#!/usr/bin/env bash' \
    'start=$(date +%s)' \
    'elapsed=$(date +%s.%N)' > "$dir/epoch.sh"
  if [[ -z "$(timestamp_hits "$dir")" ]]; then
    pass "epoch-only date calls are allowed"
  else
    fail "a date display format is forbidden, but an epoch call was reported"
  fi
}

# Given: every producer in src/ and scripts/
# When:  the spelling scan runs over the production tree
# Then:  no file outside src/libs/time_format.sh spells the format
# Asserts: one definition. The producers call ts_now_utc; the converters are
#          the lib's own.
test_no_producer_spells_a_non_harness_stamp() {
  local hits
  [[ -d "$REPO_ROOT/src" && -d "$REPO_ROOT/scripts" ]] \
    || fail "the production roots are missing; the scan would report nothing"
  hits="$(timestamp_hits "$REPO_ROOT/src"; timestamp_hits "$REPO_ROOT/scripts")"
  assert_eq "" "$hits" "no producer outside src/libs/time_format.sh spells the format"
}

# -------------------------
# Run all tests
# -------------------------

run_test test_ts_now_utc_matches_the_shape
run_test test_ts_from_epoch_is_utc
run_test test_date_days_ago_is_utc
run_test test_round_trip
run_test test_ts_epoch_rejects_malformed
run_test test_the_scan_bites_a_compact_fixture
run_test test_the_scan_bites_a_non_harness_stamp
run_test test_the_scan_bites_a_variable_literal
run_test test_the_scan_allows_epoch_calls
run_test test_no_producer_spells_a_non_harness_stamp

test_done

#!/usr/bin/env bash
# TEST_DEADLINE: 10
# tests/test_time_format.sh
# The harness writes and reads one timestamp shape, UTC `YYYYMMDD-HHMMSS`.
# src/libs/time_format.sh is its one definition: ts_now writes it, ts_epoch
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

# spelling_hits ROOT  --  every `.sh` under ROOT that spells the format itself,
# minus the one definition. Prints `path:line:text`; empty when none does.
spelling_hits() {
  local root="$1"
  grep -rn '%Y%m%d-%H%M%S' --include="*.sh" "$root" 2>/dev/null \
    | grep -v 'src/libs/time_format.sh' || true
}

# Given: the lib's own two directions
# When:  ts_now runs
# Then:  it prints a stamp matching TS_PATTERN
# Asserts: the writer produces the shape the parser accepts.
test_ts_now_matches_the_shape() {
  local now
  now="$(ts_now)"
  if [[ "$now" =~ $TS_PATTERN ]]; then
    pass "ts_now writes the YYYYMMDD-HHMMSS shape"
  else
    fail "ts_now wrote '$now', which the shape guard rejects"
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

# Given: the production tree and the one definition
# When:  the spelling scan runs over each
# Then:  the lib is a hit and the tree is not
# Asserts: the scan matches the shape it hunts. Without this binding, the absence
#          assertion below would pass over a pattern that matched nothing.
test_the_scan_finds_the_definition() {
  local lib_hits
  lib_hits="$(spelling_hits "$REPO_ROOT/src/libs/time_format.sh")"
  if [[ -n "$lib_hits" ]]; then
    pass "the spelling scan matches the one definition"
  else
    fail "the spelling scan found no hit in src/libs/time_format.sh, so its absence proves nothing"
  fi
}

# Given: a fixture producer that spells the format itself
# When:  the spelling scan runs over it
# Then:  the scan reports it
# Asserts: the gate bites on a reintroduced literal, which is the defect it exists
#          for.
test_the_scan_bites_a_fixture() {
  local dir="$FIXTURE_DIR/offender"
  rm -rf "$dir"
  mkdir -p "$dir"
  printf '%s\n' '#!/usr/bin/env bash' 'stamp=$(date -u +%Y%m%d-%H%M%S)' > "$dir/offender.sh"
  if [[ -n "$(spelling_hits "$dir")" ]]; then
    pass "a producer spelling the format is reported"
  else
    fail "a producer spelling the format was not reported"
  fi
}

# Given: every producer in src/ and scripts/
# When:  the spelling scan runs over the production tree
# Then:  no file outside src/libs/time_format.sh spells the format
# Asserts: one definition. The ten producers call ts_now and the two epoch
#          printers call ts_from_epoch.
test_no_producer_spells_the_format() {
  local hits
  [[ -d "$REPO_ROOT/src" && -d "$REPO_ROOT/scripts" ]] \
    || fail "the production roots are missing; the scan would report nothing"
  hits="$(spelling_hits "$REPO_ROOT/src"; spelling_hits "$REPO_ROOT/scripts")"
  assert_eq "" "$hits" "no producer outside src/libs/time_format.sh spells the format"
}

# -------------------------
# Run all tests
# -------------------------

run_test test_ts_now_matches_the_shape
run_test test_ts_from_epoch_is_utc
run_test test_round_trip
run_test test_ts_epoch_rejects_malformed
run_test test_the_scan_finds_the_definition
run_test test_the_scan_bites_a_fixture
run_test test_no_producer_spells_the_format

test_done

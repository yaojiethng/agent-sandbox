#!/usr/bin/env bash
# tests/test_stop_acceptance.sh
# The stop acceptance check's assertions, driven by fixture probe artifacts.
#
# The check reads a probe run's artifacts. These cases build the artifact set by
# hand, so each assertion is exercised without docker: the durations, the daemon
# exit codes, a call that never returned, and a missing die event.
#
# Run:
#   bash tests/test_stop_acceptance.sh

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup

ACCEPTANCE="$REPO_ROOT/scripts/stop_acceptance.sh"

# fixture_run DIR MODE: build a report plus its artifact directory under DIR and
# print the report path. The caller then overwrites the artifacts it cares about.
fixture_run() {
  local dir="$1" mode="${2:-perform-stop}"
  local stamp="20260101T000000Z"
  local run_dir="$dir/stop/$stamp"
  mkdir -p "$run_dir"
  printf '  "mode": "%s",\n' "$mode" >"$dir/stop/$stamp.json"
  : >"$run_dir/stop_calls.log"
  : >"$run_dir/events.log"
  : >"$run_dir/containers.txt"
  printf '%s' "$dir/stop/$stamp.json"
}

write_call() {
  local report="$1" args="$2" seconds="$3" end="$4"
  printf '{"args": "%s", "start": "1", "end": %s, "seconds": %s, "rc": 0}\n' \
    "$args" "$end" "$seconds" >>"${report%.json}/stop_calls.log"
}

write_die() {
  local report="$1" code="$2"
  printf '{"Action":"die","Actor":{"Attributes":{"exitCode":"%s","name":"c1"}},"timeNano":2}\n' \
    "$code" >>"${report%.json}/events.log"
}

# Given: no --report
# When:  the check runs
# Then:  it refuses with a non-zero status
test_missing_report_is_refused() {
  local rc=0 out
  out="$(bash "$ACCEPTANCE" 2>&1)" || rc=$?
  assert_ne 0 "$rc" "a missing --report exits non-zero"
  assert_contains "$out" "--report is required" "the refusal names the missing flag"
}

# Given: a report whose mode is read-only
# When:  the check runs
# Then:  it fails, because nothing was stopped
test_read_only_report_fails() {
  local dir report rc=0 out
  dir="$(get_fixture_dir)"
  report="$(fixture_run "$dir" read-only)"
  out="$(bash "$ACCEPTANCE" --report="$report" 2>&1)" || rc=$?
  assert_ne 0 "$rc" "a read-only report fails the acceptance"
  assert_contains "$out" "perform-stop" "the failure names the missing perform-stop run"
}

# Given: a fast stop that ended on SIGTERM, and no recorded containers
# When:  the check runs
# Then:  every assertion holds
test_fast_graceful_stop_passes() {
  local dir report rc=0 out
  dir="$(get_fixture_dir)"
  report="$(fixture_run "$dir")"
  write_call "$report" "ps -aq" "0.05" '"2"'
  write_call "$report" "stop c1" "0.42" '"3"'
  write_die "$report" "143"
  out="$(bash "$ACCEPTANCE" --report="$report" 2>&1)" || rc=$?
  assert_rc 0 "$rc" "a fast graceful stop passes"
  assert_contains "$out" "took 0.42s" "the check names the measured stop duration"
  assert_contains "$out" "VERDICT: PASS" "the verdict is PASS"
}

# Given: a stop that took the whole grace and ended in SIGKILL
# When:  the check runs
# Then:  it fails on both the duration and the exit code
test_grace_burn_stop_fails() {
  local dir report rc=0 out
  dir="$(get_fixture_dir)"
  report="$(fixture_run "$dir")"
  write_call "$report" "stop c1" "10.783" '"11"'
  write_die "$report" "137"
  out="$(bash "$ACCEPTANCE" --report="$report" 2>&1)" || rc=$?
  assert_ne 0 "$rc" "a grace-burn stop fails the acceptance"
  assert_contains "$out" "10.783s" "the failure names the measured duration"
  assert_contains "$out" "137" "the failure names the SIGKILL exit code"
}

# Given: a docker call that never returned
# When:  the check runs
# Then:  it fails and names the unfinished call
test_unreturned_call_fails() {
  local dir report rc=0 out
  dir="$(get_fixture_dir)"
  report="$(fixture_run "$dir")"
  write_call "$report" "stop c1" "null" 'null'
  write_die "$report" "143"
  out="$(bash "$ACCEPTANCE" --report="$report" 2>&1)" || rc=$?
  assert_ne 0 "$rc" "an unfinished docker call fails the acceptance"
  assert_contains "$out" "did not return" "the failure names the unfinished call"
}

# Given: no die event at all
# When:  the check runs
# Then:  it fails, because the stop's outcome is unproven
test_missing_die_event_fails() {
  local dir report rc=0 out
  dir="$(get_fixture_dir)"
  report="$(fixture_run "$dir")"
  write_call "$report" "stop c1" "0.30" '"2"'
  out="$(bash "$ACCEPTANCE" --report="$report" 2>&1)" || rc=$?
  assert_ne 0 "$rc" "a missing die event fails the acceptance"
  assert_contains "$out" "unproven" "the failure says the outcome is unproven"
}

run_test test_missing_report_is_refused
run_test test_read_only_report_fails
run_test test_fast_graceful_stop_passes
run_test test_grace_burn_stop_fails
run_test test_unreturned_call_fails
run_test test_missing_die_event_fails

test_done "stop_acceptance"

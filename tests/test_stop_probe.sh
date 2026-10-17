#!/usr/bin/env bash
# tests/test_stop_probe.sh  --  the stop forensics probe's report shape, its
# read-only safety contract, and its timing wrapper.
#
# The probe runs on the host against a real docker; here the docker stub stands
# in for it. Every run gets the stub first on PATH and a fixture input
# directory, never a real docker and never the repo's own .compose.
#
# Run:
#   bash tests/test_stop_probe.sh

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup

STUB_DIR="$REPO_ROOT/tests/stubs"
PROBE="$REPO_ROOT/scripts/stop_probe.sh"
PROBE_OUT=""
PROBE_RC=0

# probe ARGS...  --  run the probe under the stub and capture its combined
# output in PROBE_OUT and its exit status in PROBE_RC. The status rides a
# global so the call need not sit in a condition.
probe() {
  PROBE_RC=0
  PROBE_OUT="$(PATH="$STUB_DIR:$PATH" bash "$PROBE" "$@" 2>&1)" || PROBE_RC=$?
}

# report_path INPUT_DIR  --  the one report the probe wrote under INPUT_DIR.
report_path() {
  find "$1/stop" -name '*.json' -print -quit 2>/dev/null
}

# require_jq  --  the report assertions parse JSON, so a case without jq skips
# (jq is present in this container; the guard keeps the gate honest elsewhere).
require_jq() {
  command -v jq >/dev/null 2>&1 || skip "jq is not installed"
}

# Given: the probe invoked with --help
# When:  it runs
# Then:  it prints the usage banner and returns 0
test_help_prints_usage_and_exits_zero() {
  probe --help
  assert_rc 0 "$PROBE_RC" "--help exits 0"
  assert_contains "$PROBE_OUT" "Usage: bash scripts/stop_probe.sh" "--help prints the usage banner"
}

# Given: a call with no --sandbox
# When:  the probe runs
# Then:  it refuses with a non-zero status and writes no report
test_missing_sandbox_fails_without_a_report() {
  local input
  input="$(get_fixture_dir)/input"
  mkdir -p "$input"
  probe --name=myproj --input-dir="$input"
  assert_ne 0 "$PROBE_RC" "a missing --sandbox exits non-zero"
  assert_eq_num "$(find "$input" -name '*.json' | wc -l)" 0 "no report is written when --sandbox is missing"
}

# Given: a fixture sandbox and a stub docker that answers no version
# When:  the probe runs read-only
# Then:  a JSON report is written, the verdict is FAIL with a non-empty failure
#        list, and the two stop-path checks report read-only mode
test_read_only_run_writes_a_json_verdict() {
  require_jq
  local sbx input
  sbx="$(get_fixture_dir)/sbx"
  input="$(get_fixture_dir)/input"
  mkdir -p "$sbx" "$input"
  export DOCKER_TRACE_LOG="$FIXTURE_DIR/trace.log"
  : > "$DOCKER_TRACE_LOG"
  probe --sandbox="$sbx" --name=myproj --input-dir="$input"
  assert_rc 1 "$PROBE_RC" "a read-only stub run reports FAIL without aborting"
  local report
  report="$(report_path "$input")"
  assert_file_exists "$report" "the report is written even when the verdict is FAIL"
  assert_run 0 "jq -e . '$report'" "the report parses as JSON"
  assert_eq "$(jq -r 'has("timestamp") and has("verdict") and has("repo_root") and has("repo_head") and has("repo_branch") and has("sandbox_dir") and has("project_name") and has("mode") and has("host") and has("engine") and has("identity") and has("compose_records") and has("containers") and has("events") and has("stop_calls") and has("calibration") and has("checks") and has("failures")' "$report")" "true" "every required top-level key is present"
  assert_eq "$(jq -r '.mode' "$report")" "read-only" "the report records read-only mode"
  assert_eq "$(jq -r '.checks[] | select(.name == "events") | .result' "$report")" "INCONCLUSIVE" "events is INCONCLUSIVE in read-only mode"
  assert_eq "$(jq -r '.checks[] | select(.name == "events") | .detail' "$report")" "read-only mode" "the events detail names read-only mode"
  assert_eq "$(jq -r '.checks[] | select(.name == "stop_calls") | .result' "$report")" "INCONCLUSIVE" "stop_calls is INCONCLUSIVE in read-only mode"
  assert_eq "$(jq -r '.checks[] | select(.name == "stop_calls") | .detail' "$report")" "read-only mode" "the stop_calls detail names read-only mode"
  assert_eq "$(jq -r '.verdict' "$report")" "FAIL" "the verdict is FAIL when a check fails"
  assert_ne "$(jq -r '.failures | length' "$report")" "0" "the failure list is non-empty"
}

# Given: a read-only run against a sandbox whose containers the stub reports
# When:  the probe finishes
# Then:  no docker stop or rm names a sandbox container, and the stop script
#        trace is empty; read-only mode honours its no-stop contract. The
#        calibration stop names the probe's own throwaway container, not a
#        sandbox container, so it is outside what this case asserts.
test_read_only_run_stops_nothing() {
  local sbx input
  sbx="$(get_fixture_dir)/sbx"
  input="$(get_fixture_dir)/input"
  mkdir -p "$sbx" "$input"
  export DOCKER_TRACE_LOG="$FIXTURE_DIR/trace.log"
  : > "$DOCKER_TRACE_LOG"
  export DOCKER_STUB_PS_IDS="abc123def456 fedcba654321"
  probe --sandbox="$sbx" --name=myproj --input-dir="$input"
  if trace_has "stop abc123def456"; then
    fail "read-only mode invoked docker stop on a sandbox container"
  else
    pass "read-only mode issued no docker stop for a sandbox container"
  fi
  if trace_has "rm abc123def456"; then
    fail "read-only mode invoked docker rm on a sandbox container"
  else
    pass "read-only mode issued no docker rm for a sandbox container"
  fi
  local report
  report="$(report_path "$input")"
  assert_empty "$(cat "${report%.json}/stop-trace.log" 2>/dev/null)" "read-only mode never ran the stop script"
}

# Given: --perform-stop and a stub reporting two containers
# When:  the probe runs
# Then:  the report records perform-stop, the stop_calls array carries numeric
#        seconds, and the timing wrapper logged a matched BEGIN/END pair per call
test_perform_stop_records_every_docker_call() {
  require_jq
  local sbx input
  sbx="$(get_fixture_dir)/sbx"
  input="$(get_fixture_dir)/input"
  mkdir -p "$sbx" "$input"
  export DOCKER_TRACE_LOG="$FIXTURE_DIR/trace.log"
  : > "$DOCKER_TRACE_LOG"
  export DOCKER_STUB_PS_IDS="abc123def456 fedcba654321"
  probe --sandbox="$sbx" --name=myproj --input-dir="$input" --perform-stop
  assert_rc 1 "$PROBE_RC" "a perform-stop stub run reports FAIL without aborting"
  local report
  report="$(report_path "$input")"
  assert_eq "$(jq -r '.mode' "$report")" "perform-stop" "the report records perform-stop mode"
  assert_run 0 "jq -e '(.stop_calls | length) >= 1 and (.stop_calls | all(.[]; (.seconds | type) == \"number\"))' '$report'" "every stop call carries numeric seconds"
  local run_dir begin end
  run_dir="${report%.json}"
  begin="$(grep -c '^BEGIN ' "$run_dir/docker-calls.log" || true)"
  end="$(grep -c '^END ' "$run_dir/docker-calls.log" || true)"
  assert_matches "$begin" '^[1-9][0-9]*$' "the timing wrapper logged at least one call"
  assert_eq "$begin" "$end" "every BEGIN has a matching END"
}

# Given: a sandbox whose .compose record sets stop_grace_period
# When:  the probe runs, then a second run drops the record
# Then:  the first reports INCONCLUSIVE naming the value and flags the record,
#        and the second says no record sets it
test_compose_records_surface_a_stop_grace_period() {
  require_jq
  local sbx input1 input2
  sbx="$(get_fixture_dir)/sbx"
  input1="$(get_fixture_dir)/input1"
  input2="$(get_fixture_dir)/input2"
  mkdir -p "$sbx/.compose" "$input1" "$input2"
  printf 'services:\n  app:\n    stop_grace_period: 30s\n' > "$sbx/.compose/s.yml"
  export DOCKER_TRACE_LOG="$FIXTURE_DIR/trace.log"
  : > "$DOCKER_TRACE_LOG"
  probe --sandbox="$sbx" --name=myproj --input-dir="$input1"
  local report1 detail1
  report1="$(report_path "$input1")"
  detail1="$(jq -r '.checks[] | select(.name == "compose_records") | .detail' "$report1")"
  assert_eq "$(jq -r '.checks[] | select(.name == "compose_records") | .result' "$report1")" "INCONCLUSIVE" "a stop_grace_period record makes compose_records INCONCLUSIVE"
  assert_contains "$detail1" "30s" "the detail names the grace value"
  assert_eq "$(jq -r '.compose_records[0].has_stop_grace_period' "$report1")" "true" "the record is flagged as setting stop_grace_period"

  rm -f "$sbx/.compose/s.yml"
  printf 'services: {}\n' > "$sbx/.compose/other.yml"
  : > "$DOCKER_TRACE_LOG"
  probe --sandbox="$sbx" --name=myproj --input-dir="$input2"
  local report2 detail2
  report2="$(report_path "$input2")"
  detail2="$(jq -r '.checks[] | select(.name == "compose_records") | .detail' "$report2")"
  assert_contains "$detail2" "none sets stop_grace_period" "the run without the record says no record sets it"
  assert_ne "$detail2" "$detail1" "the two runs report different details"
}

# Given: a sandbox workspace and no --input-dir and no INPUT_DIR
# When:  the probe runs
# Then:  the report lands under the sandbox's own .workspace/input/stop
test_default_input_dir_is_the_sandbox_workspace() {
  local sbx
  sbx="$(get_fixture_dir)/sbx"
  mkdir -p "$sbx/.workspace/input"
  export DOCKER_TRACE_LOG="$FIXTURE_DIR/trace.log"
  : > "$DOCKER_TRACE_LOG"
  unset INPUT_DIR WORKSPACE_DIR_NAME INPUT_DIR_NAME CHANGES_DIR_NAME OUTPUT_DIR_NAME
  probe --sandbox="$sbx" --name=myproj
  assert_dir_exists "$sbx/.workspace/input/stop" "the default report directory is <sandbox>/.workspace/input/stop"
  assert_eq_num "$(find "$sbx/.workspace/input/stop" -name '*.json' | wc -l)" 1 "the report landed under the default input directory"
}

# Given: a stub multi-field inspect line for one stopped container
# When:  the probe runs across exit codes 0, 137 and 143
# Then:  the container element carries the parsed fields and the containers
#        check is PASS for each allowed exit code
test_containers_inspect_line_parses_and_passes() {
  require_jq
  local code sbx input report line
  for code in 0 137 143; do
    sbx="$(get_fixture_dir)/sbx"
    input="$(get_fixture_dir)/input"
    mkdir -p "$sbx" "$input"
    export DOCKER_TRACE_LOG="$FIXTURE_DIR/trace.log"
    : > "$DOCKER_TRACE_LOG"
    export DOCKER_STUB_PS_IDS="cid1"
    line="$(printf 'cname1|exited|%s|SIGTERM|2026-01-01T00:00:01Z|/app' "$code")"
    export DOCKER_STUB_INSPECT_LINE="$line"
    probe --sandbox="$sbx" --name=myproj --input-dir="$input"
    report="$(report_path "$input")"
    assert_eq "$(jq -r '.checks[] | select(.name == "containers") | .result' "$report")" "PASS" "exit code ${code} makes the containers check PASS"
    assert_eq "$(jq -r '.containers[0].exit_code' "$report")" "$code" "the container element carries the parsed exit code ${code}"
  done
  assert_eq "$(jq -r '.containers[0].name' "$report")" "cname1" "the container element carries the parsed name"
  assert_eq "$(jq -r '.containers[0].status' "$report")" "exited" "the container element carries the parsed status"
  assert_eq "$(jq -r '.containers[0].stop_signal' "$report")" "SIGTERM" "the container element carries the parsed stop signal"
  assert_eq "$(jq -r '.containers[0].stop_signal' "$report")" "SIGTERM" "the container element carries the parsed stop signal"
  assert_eq "$(jq -r '.containers[0].finished_at' "$report")" "2026-01-01T00:00:01Z" "the container element carries the parsed finish time"
  assert_eq "$(jq -r '.containers[0].path' "$report")" "/app" "the container element carries the parsed path"
  assert_eq "$(jq -r '.containers[0].path' "$report")" "/app" "the container element carries the parsed entrypoint path"
}

# Given: a stub inspect line for one running container
# When:  the probe runs
# Then:  the containers check is INCONCLUSIVE with a detail naming the
#        still-running container, never FAIL
test_running_container_is_inconclusive() {
  require_jq
  local sbx input report
  sbx="$(get_fixture_dir)/sbx"
  input="$(get_fixture_dir)/input"
  mkdir -p "$sbx" "$input"
  export DOCKER_TRACE_LOG="$FIXTURE_DIR/trace.log"
  : > "$DOCKER_TRACE_LOG"
  export DOCKER_STUB_PS_IDS="cid1"
  DOCKER_STUB_INSPECT_LINE="$(printf 'cname1|running|0|SIGTERM||/app')"
  export DOCKER_STUB_INSPECT_LINE
  probe --sandbox="$sbx" --name=myproj --input-dir="$input"
  report="$(report_path "$input")"
  assert_eq "$(jq -r '.checks[] | select(.name == "containers") | .result' "$report")" "INCONCLUSIVE" "a running container makes the containers check INCONCLUSIVE"
  assert_contains "$(jq -r '.checks[] | select(.name == "containers") | .detail' "$report")" "still running" "the containers detail says the container is still running"
}

# Given: --perform-stop with matched containers from two session ids and
#        neither --session-id nor --all-sessions
# When:  the probe runs
# Then:  it is refused before anything is stopped: events and stop_calls are
#        FAIL with a refused: detail naming both session ids, the process exits
#        non-zero, and the timing wrapper logged no docker call
test_multi_session_perform_stop_is_refused() {
  require_jq
  local sbx input report run_dir events_detail stop_calls_detail
  sbx="$(get_fixture_dir)/sbx"
  input="$(get_fixture_dir)/input"
  mkdir -p "$sbx" "$input"
  export DOCKER_TRACE_LOG="$FIXTURE_DIR/trace.log"
  : > "$DOCKER_TRACE_LOG"
  export DOCKER_STUB_PS_IDS="cid1 cid2"
  export DOCKER_STUB_SESSION_ID_LABELS="cid1:s1 cid2:s2"
  DOCKER_STUB_INSPECT_LINE="$(printf 'cname1|exited|0|SIGTERM|2026-01-01T00:00:01Z|/app')"
  export DOCKER_STUB_INSPECT_LINE
  probe --sandbox="$sbx" --name=myproj --input-dir="$input" --perform-stop
  assert_ne 0 "$PROBE_RC" "an unscoped multi-session stop exits non-zero"
  report="$(report_path "$input")"
  run_dir="${report%.json}"
  events_detail="$(jq -r '.checks[] | select(.name == "events") | .detail' "$report")"
  stop_calls_detail="$(jq -r '.checks[] | select(.name == "stop_calls") | .detail' "$report")"
  assert_eq "$(jq -r '.checks[] | select(.name == "events") | .result' "$report")" "FAIL" "the events check is FAIL when the stop is refused"
  assert_eq "$(jq -r '.checks[] | select(.name == "stop_calls") | .result' "$report")" "FAIL" "the stop_calls check is FAIL when the stop is refused"
  assert_matches "$events_detail" '^refused:' "the events detail starts with refused:"
  assert_matches "$stop_calls_detail" '^refused:' "the stop_calls detail starts with refused:"
  assert_contains "$events_detail" "s1" "the refusal names the first session id"
  assert_contains "$events_detail" "s2" "the refusal names the second session id"
  assert_empty "$(cat "$run_dir/docker-calls.log")" "no docker stop reached the timing wrapper"
}

# Given: --perform-stop --session-id=s2 with the same two-session fixture
# When:  the probe runs
# Then:  the stop is not refused and the bash -x trace of stop.sh carries the
#        session scoping
test_session_id_scopes_the_stop() {
  require_jq
  local sbx input report run_dir trace
  sbx="$(get_fixture_dir)/sbx"
  input="$(get_fixture_dir)/input"
  mkdir -p "$sbx" "$input"
  export DOCKER_TRACE_LOG="$FIXTURE_DIR/trace.log"
  : > "$DOCKER_TRACE_LOG"
  export DOCKER_STUB_PS_IDS="cid1 cid2"
  export DOCKER_STUB_SESSION_ID_LABELS="cid1:s1 cid2:s2"
  DOCKER_STUB_INSPECT_LINE="$(printf 'cname1|exited|0|SIGTERM|2026-01-01T00:00:01Z|/app')"
  export DOCKER_STUB_INSPECT_LINE
  probe --sandbox="$sbx" --name=myproj --input-dir="$input" --perform-stop --session-id=s2
  report="$(report_path "$input")"
  run_dir="${report%.json}"
  trace="$(cat "$run_dir/stop-trace.log")"
  assert_not_contains "$(jq -r '.checks[] | select(.name == "stop_calls") | .detail' "$report")" "refused:" "the session-scoped stop is not refused"
  assert_not_empty "$trace" "the session-scoped run invoked stop.sh"
  assert_contains "$trace" "--session-id=s2" "the stop trace carries the session scoping"
}


# Given: event JSON where a container is killed and dies 10.78s later with exit 137
# When:  a scoped perform-stop runs
# Then:  the events check fails and names SIGKILL and the grace
# Asserts: a grace burn is reported as a failure, not as a stopped container.
test_sigkill_after_grace_fails_events() {
  require_jq
  local sbx input report
  sbx="$(get_fixture_dir)/sbx"
  input="$(get_fixture_dir)/input"
  mkdir -p "$sbx" "$input"
  export DOCKER_TRACE_LOG="$FIXTURE_DIR/trace.log"
  export DOCKER_STUB_PS_IDS="cid1"
  export DOCKER_STUB_SESSION_ID_LABELS="cid1:s1"
  DOCKER_STUB_INSPECT_LINE='cname1|exited|137|SIGTERM|2026-01-01T00:00:11Z|/app'
  export DOCKER_STUB_INSPECT_LINE
  DOCKER_STUB_EVENTS_LINES="$(printf '%s\n%s' \
    '{"Action":"kill","Actor":{"Attributes":{"name":"cname1"}},"timeNano":1000000000}' \
    '{"Action":"die","Actor":{"Attributes":{"exitCode":"137","name":"cname1"}},"timeNano":11783000000}')"
  export DOCKER_STUB_EVENTS_LINES
  probe --sandbox="$sbx" --name=myproj --input-dir="$input" --perform-stop --session-id=s1
  report="$(report_path "$input")"
  assert_eq "$(jq -r '.checks[] | select(.name == "events") | .result' "$report")" "FAIL" "a grace-burn SIGKILL fails the events check"
  assert_contains "$(jq -r '.checks[] | select(.name == "events") | .detail' "$report")" "SIGKILL" "the events detail names SIGKILL"
  assert_eq_num "$(jq -r '.events[0].exit_code' "$report")" 137 "the event carries the container exit code"
}

# Given: event JSON where a container dies 0.4s after the signal with exit 143
# When:  a scoped perform-stop runs
# Then:  the events check passes and the gap is measured in seconds
# Asserts: a graceful term is not reported as a SIGKILL.
test_graceful_term_passes_events() {
  require_jq
  local sbx input report
  sbx="$(get_fixture_dir)/sbx"
  input="$(get_fixture_dir)/input"
  mkdir -p "$sbx" "$input"
  export DOCKER_TRACE_LOG="$FIXTURE_DIR/trace.log"
  export DOCKER_STUB_PS_IDS="cid1"
  export DOCKER_STUB_SESSION_ID_LABELS="cid1:s1"
  DOCKER_STUB_INSPECT_LINE='cname1|exited|143|SIGTERM|2026-01-01T00:00:01Z|/app'
  export DOCKER_STUB_INSPECT_LINE
  DOCKER_STUB_EVENTS_LINES="$(printf '%s\n%s' \
    '{"Action":"kill","Actor":{"Attributes":{"name":"cname1"}},"timeNano":1000000000}' \
    '{"Action":"die","Actor":{"Attributes":{"exitCode":"143","name":"cname1"}},"timeNano":1400000000}')"
  export DOCKER_STUB_EVENTS_LINES
  probe --sandbox="$sbx" --name=myproj --input-dir="$input" --perform-stop --session-id=s1
  report="$(report_path "$input")"
  assert_eq "$(jq -r '.checks[] | select(.name == "events") | .result' "$report")" "PASS" "a graceful term passes the events check"
  assert_eq "$(jq -r '.events[0].exit_code' "$report")" "143" "the event carries exit code 143"
  assert_eq "$(jq -r '.events[0].seconds' "$report")" "0.4" "the signal-to-die gap is reported in seconds"
}
run_test test_help_prints_usage_and_exits_zero
run_test test_missing_sandbox_fails_without_a_report
run_test test_read_only_run_writes_a_json_verdict
run_test test_read_only_run_stops_nothing
run_test test_perform_stop_records_every_docker_call
run_test test_compose_records_surface_a_stop_grace_period
run_test test_default_input_dir_is_the_sandbox_workspace
run_test test_containers_inspect_line_parses_and_passes
run_test test_running_container_is_inconclusive
run_test test_multi_session_perform_stop_is_refused
run_test test_session_id_scopes_the_stop
run_test test_sigkill_after_grace_fails_events
run_test test_graceful_term_passes_events

test_done "stop_probe"

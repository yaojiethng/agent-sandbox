#!/usr/bin/env bash
# scripts/stop_acceptance.sh
# The stop acceptance check: assert on one stop probe's evidence, not on a story.
#
# The stop path is a container-level property. A unit test cannot reproduce the
# PID 1 signal rule, so the acceptance reads the artifacts a real run left: the
# per-call durations, the daemon's own events with their exit codes, and the
# state of the containers the stop matched. The reviewer runs the probe, then
# this check over its report.
#
# Usage:
#   bash scripts/stop_acceptance.sh --report=<probe report.json> [options]
#
# Options:
#   --report=<path>            The probe report to judge. Required.
#   --max-stop-seconds=<n>     The pass ceiling for one `docker stop`. Default 2.
#   --help
#
# Asserts, in order:
#   1. the report came from a perform-stop run;
#   2. every recorded docker call returned;
#   3. the slowest `docker stop` is under the ceiling;
#   4. no container died with exit code 137, which is the grace-burn SIGKILL;
#   5. no matched container is still running, and its exit code is 0 or 143.
#
# Posture: a stop that still burns the grace fails here, and the failure names
# the measured seconds and the exit code that produced it.

_self_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$_self_dir/.." && pwd)"

source "$REPO_ROOT/src/libs/cli.sh"

REPORT=""
MAX_STOP_SECONDS="2"

usage() {
  cat <<'USAGE'
Usage: bash scripts/stop_acceptance.sh --report=<probe report.json> [options]

Judges one stop probe run and exits non-zero when the stop did not end cleanly.

Options:
  --report=<path>          The probe report to judge. Required.
  --max-stop-seconds=<n>   The pass ceiling for one docker stop. Default 2.
  -h, --help               Print this help.
USAGE
}

say() { echo "stop_acceptance: $*"; }

die() {
  echo "stop_acceptance: ERROR: $*" >&2
  exit 1
}

# read_report_mode REPORT  --  the report's mode field, or empty.
read_report_mode() {
  sed -n 's/^  "mode": "\([^"]*\)".*/\1/p' "$1" | head -n1
}

# slowest_stop CALLS_FILE  --  the largest `seconds` among the `stop` calls.
# The calls file is one JSON object per line, so the stop call is the line whose
# args start with `stop ` and whose seconds field is the fourth key.
slowest_stop() {
  local file="$1"
  local line max="0"
  while IFS= read -r line; do
    [[ "$line" == *'"args": "stop '* ]] || continue
    local sec
    sec="$(printf '%s' "$line" | sed -n 's/.*"seconds": \([0-9.]*\).*/\1/p')"
    [[ -n "$sec" ]] || continue
    max="$(awk -v a="$sec" -v b="$max" 'BEGIN{print (a>b)?a:b}')"
  done <"$file"
  printf '%s' "$max"
}

# die_exit_codes EVENTS_FILE  --  one exit code per die event, space separated.
# Empty when the stream holds no die event.
die_exit_codes() {
  local file="$1"
  sed -n 's/.*"Action":"die".*"exitCode":"\([0-9]*\)".*/\1/p' "$file" | tr '\n' ' '
}

main() {
  parse_args usage \
    --report=REPORT \
    --max-stop-seconds=MAX_STOP_SECONDS \
    -- "$@"
  local rc=$?
  if [[ $rc -eq 2 ]]; then exit 0; fi
  [[ $rc -eq 0 ]] || exit 1

  [[ -n "$REPORT" ]] || die "--report is required"
  [[ -f "$REPORT" ]] || die "no such report: $REPORT"

  local run_dir="${REPORT%.json}"
  [[ -d "$run_dir" ]] || die "the report has no artifact directory beside it: $run_dir"
  local calls="$run_dir/stop_calls.log"
  local events="$run_dir/events.log"
  local containers="$run_dir/containers.txt"
  [[ -f "$calls" ]] || die "missing artifact: $calls"
  [[ -f "$events" ]] || die "missing artifact: $events"

  local failures=0

  local mode
  mode="$(read_report_mode "$REPORT")"
  if [[ "$mode" == "perform-stop" ]]; then
    say "mode: perform-stop"
  else
    say "FAIL mode is '${mode:-unknown}', so nothing was stopped; run the probe with --perform-stop"
    failures=$(( failures + 1 ))
  fi

  local no_end
  no_end="$(grep -c '"end": null' "$calls" 2>/dev/null || true)"
  if [[ "${no_end:-0}" -gt 0 ]]; then
    say "FAIL ${no_end} docker call(s) did not return"
    failures=$(( failures + 1 ))
  else
    say "PASS every recorded docker call returned"
  fi

  local slowest
  slowest="$(slowest_stop "$calls")"
  if [[ -z "$slowest" ]]; then
    say "FAIL no docker stop call was recorded"
    failures=$(( failures + 1 ))
  elif awk -v s="$slowest" -v m="$MAX_STOP_SECONDS" 'BEGIN{exit !(s >= m)}'; then
    say "FAIL the slowest docker stop took ${slowest}s, ceiling ${MAX_STOP_SECONDS}s"
    failures=$(( failures + 1 ))
  else
    say "PASS the slowest docker stop took ${slowest}s, ceiling ${MAX_STOP_SECONDS}s"
  fi

  local codes
  codes="$(die_exit_codes "$events")"
  if [[ -z "$codes" ]]; then
    say "FAIL no die event was recorded, so the stop's exit code is unproven"
    failures=$(( failures + 1 ))
  elif [[ " $codes " == *" 137 "* ]]; then
    say "FAIL a container died with 137, the grace-burn SIGKILL (codes: ${codes% })"
    failures=$(( failures + 1 ))
  else
    say "PASS no container was SIGKILLed after the grace (codes: ${codes% })"
  fi

  if [[ ! -s "$containers" ]]; then
    say "PASS no container id was recorded, so nothing can be left running"
  elif ! command -v docker >/dev/null 2>&1; then
    say "FAIL containers were recorded but docker is not on PATH, so residue is unproven"
    failures=$(( failures + 1 ))
  else
    local id state code running=0 bad=0
    while IFS= read -r id; do
      [[ -n "$id" ]] || continue
      state="$(docker inspect --format '{{.State.Status}} {{.State.ExitCode}}' "$id" 2>/dev/null)"
      if [[ -z "$state" ]]; then
        say "PASS container ${id:0:12} is gone"
        continue
      fi
      read -r state code <<<"$state"
      if [[ "$state" == "running" ]]; then
        say "FAIL container ${id:0:12} is still running"
        running=$(( running + 1 ))
      elif [[ "$code" != "0" && "$code" != "143" ]]; then
        say "FAIL container ${id:0:12} exited ${code}, not 0 or 143"
        bad=$(( bad + 1 ))
      else
        say "PASS container ${id:0:12} exited ${code}"
      fi
    done <"$containers"
    failures=$(( failures + running + bad ))
  fi

  if (( failures > 0 )); then
    say "VERDICT: FAIL, ${failures} assertion(s) did not hold"
    exit 1
  fi
  say "VERDICT: PASS"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  set -uo pipefail
  main "$@"
fi

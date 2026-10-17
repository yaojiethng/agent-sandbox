#!/usr/bin/env bash
# scripts/stop_signal_matrix.sh
# Host-side signal matrix: which container PID 1 shape exits on SIGTERM.
#
# The agent's container takes the full `docker stop` grace and is then SIGKILLed,
# so `make stop` shows an eleven second silent wait and the started session ends
# with 137. Three shapes can explain or fix it, and theory alone cannot pick one:
#
#   bash-child   bash is PID 1 and runs the agent as a foreground child, which is
#                what src/reasoning/entrypoint.sh does today
#   exec-child   the agent is exec'd, so it becomes PID 1
#   init-child   an init (tini) is PID 1 and the agent is its child
#
# Linux delivers a signal whose disposition is SIG_DFL to the init of a PID
# namespace as a no-op, so a PID 1 with no handler neither exits nor forwards.
# The matrix measures which of the three shapes actually exits inside the grace,
# on the real runtime, with the image that ran.
#
# Usage, on the host:
#
#   bash scripts/stop_signal_matrix.sh [options]
#
# Options:
#   --image=<name>      Agent image to test. Default: pi-agent-agent-sandbox.
#   --stop-timeout=<n>  Seconds of grace per row. Default: docker's own 10.
#   --input-dir=<path>  Where to write the report. Defaults to $INPUT_DIR.
#   --dry-run           Print the three commands and exit, without docker.
#   --keep              Leave the row containers behind for inspection.
#   -h, --help          Print this help.
#
# Each row starts one container from the image, records the PID 1 signal mask
# from /proc/1/status, times `docker stop`, and records the container exit code.
# A row whose observation contradicts its expectation fails the run, so a wrong
# model is reported rather than silently measured.
#
# The report lands at <input-dir>/stop-signal/<timestamp>.json and reaches the
# agent read-only at input/stop-signal/<timestamp>.json.

_self_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$_self_dir/.." && pwd)"

source "$REPO_ROOT/src/build/image.sh"
source "$REPO_ROOT/src/libs/cli.sh"
source "$REPO_ROOT/src/libs/dirs.sh"

MATRIX_IMAGE=""
MATRIX_STOP_TIMEOUT=""
MATRIX_INPUT_DIR=""
MATRIX_DRY_RUN=false
MATRIX_KEEP=false
DEFAULT_IMAGE="pi-agent-agent-sandbox"

usage() {
  cat <<'USAGE'
Usage: bash scripts/stop_signal_matrix.sh [options]

Measures how each container PID 1 shape answers SIGTERM, and writes one JSON
report to <input-dir>/stop-signal/<timestamp>.json.

Options:
  --image=<name>      Agent image to test. Default: pi-agent-agent-sandbox.
  --stop-timeout=<n>  Seconds of grace per row. Default: docker's own 10.
  --input-dir=<path>  Where to write the report. Defaults to $INPUT_DIR.
  --dry-run           Print the three commands and exit, without docker.
  --keep              Leave the row containers behind for inspection.
  -h, --help          Print this help.

A row whose observation contradicts its expectation fails the run.
USAGE
}

say() { echo "stop_signal_matrix: $*" >&2; }

die() {
  echo "stop_signal_matrix: ERROR: $*" >&2
  exit 1
}

# json_string TEXT
json_string() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\t'/\\t}"
  printf '"%s"' "$s"
}

# expect_verdict SECONDS EXIT_CODE TIMEOUT EXPECT: compare one row against the
# model that row declares.
#   burn  -- the row's PID 1 holds TERM at its default disposition, so the
#            grace runs out and docker sends SIGKILL (exit 137)
#   term  -- a forwarder delivers the signal, so the container ends inside the
#            grace with 143 (or 0 if it shut itself down cleanly)
# A row whose outcome lands in neither window is ambiguous, and the run fails on
# it rather than reporting a pass.
expect_verdict() {
  local seconds="$1" exit_code="$2" timeout="${3:-10}" expect="$4"
  local limit_for_exit=$(( timeout + 3 ))
  if awk -v s="$seconds" -v l="$limit_for_exit" 'BEGIN{exit !(s >= l)}'; then
    if [[ "$expect" == "burn" && "$exit_code" == "137" ]]; then echo "expected"; else echo "unexpected"; fi
    return 0
  fi
  if awk -v s="$seconds" 'BEGIN{exit !(s < 2)}'; then
    if [[ "$expect" == "term" ]] && [[ "$exit_code" == "143" || "$exit_code" == "0" ]]; then
      echo "expected"
    else
      echo "unexpected"
    fi
    return 0
  fi
  echo "ambiguous"
}

# run_row NAME EXPECT ENTRYPOINT_ARGS...: start, probe /proc/1/status, stop,
# record. Prints one JSON object on stdout and one aligned table line on stderr.
run_row() {
  local name="$1"; shift
  local expect="$1"; shift
  local container="stop-matrix-${name}-$$"
  local id="" sigign="" sigcgt="" seconds="" exit_code="" verdict=""

  if ! docker run -d --name "$container" "$@" >/dev/null 2>&1; then
    say "$name: the container did not start"
    printf '{"name": %s, "status": "did-not-start"}' "$(json_string "$name")"
    return 1
  fi
  ROW_CONTAINERS+=("$container")

  # The container is up as soon as run returns; the PID 1 mask is stable.
  sigign="$(docker exec "$container" cat /proc/1/status 2>/dev/null | sed -n 's/^SigIgn:[[:space:]]*//p')"
  sigcgt="$(docker exec "$container" cat /proc/1/status 2>/dev/null | sed -n 's/^SigCgt:[[:space:]]*//p')"
  id="$(docker inspect --format '{{.Id}}' "$container" 2>/dev/null)"

  local start end
  start="$(date +%s.%N)"
  if [[ -n "$MATRIX_STOP_TIMEOUT" ]]; then
    docker stop --time "$MATRIX_STOP_TIMEOUT" "$container" >/dev/null 2>&1
  else
    docker stop "$container" >/dev/null 2>&1
  fi
  end="$(date +%s.%N)"
  seconds="$(awk -v s="$start" -v e="$end" 'BEGIN{printf "%.2f", e - s}')"
  exit_code="$(docker inspect --format '{{.State.ExitCode}}' "$container" 2>/dev/null)"
  verdict="$(expect_verdict "$seconds" "${exit_code:-unknown}" "${MATRIX_STOP_TIMEOUT:-10}" "$expect")"

  printf 'stop_signal_matrix: %-10s model=%-4s stop=%6ss exit=%-3s SigIgn=%s SigCgt=%s -> %s\n' \
    "$name" "$expect" "$seconds" "${exit_code:-?}" "${sigign:-?}" "${sigcgt:-?}" "$verdict" >&2
  printf '{"name": %s, "model": %s, "container": %s, "id": %s, "stop_seconds": %s, "exit_code": %s, "sig_ign": %s, "sig_cgt": %s, "verdict": %s}' \
    "$(json_string "$name")" "$(json_string "$expect")" "$(json_string "$container")" "$(json_string "$id")" \
    "${seconds:-null}" "${exit_code:-null}" "$(json_string "$sigign")" "$(json_string "$sigcgt")" \
    "$(json_string "$verdict")"
}

cleanup() {
  [[ "$MATRIX_KEEP" == true ]] && return 0
  local c
  for c in ${ROW_CONTAINERS[@]+"${ROW_CONTAINERS[@]}"}; do
    docker rm -f "$c" >/dev/null 2>&1 || true
  done
}

plan_rows() {
  say "image ${MATRIX_IMAGE}, grace ${MATRIX_STOP_TIMEOUT:-docker default}"
  say "row bash-child: docker run -d --name <c> --entrypoint bash ${MATRIX_IMAGE} -c 'sleep 600 & wait' (model: burn)"
  say "row exec-child: docker run -d --name <c> --entrypoint sleep ${MATRIX_IMAGE} 600 (model: burn)"
  say "row init-child: docker run -d --init --name <c> --entrypoint sleep ${MATRIX_IMAGE} 600 (model: term)"
}

main() {
  parse_args usage \
    --image=MATRIX_IMAGE \
    --stop-timeout=MATRIX_STOP_TIMEOUT \
    --input-dir=MATRIX_INPUT_DIR \
    --dry-run:MATRIX_DRY_RUN \
    --keep:MATRIX_KEEP \
    -- "$@"
  local rc=$?
  if [[ $rc -eq 2 ]]; then exit 0; fi
  [[ $rc -eq 0 ]] || exit 1

  [[ -n "$MATRIX_IMAGE" ]] || MATRIX_IMAGE="$DEFAULT_IMAGE"

  if [[ "$MATRIX_DRY_RUN" == true ]]; then
    plan_rows
    exit 0
  fi

  command -v docker >/dev/null 2>&1 || die "docker is not on PATH"
  docker image inspect "$MATRIX_IMAGE" >/dev/null 2>&1 \
    || die "image not present: ${MATRIX_IMAGE} (build it first, or pass --image=<name>)"

  if [[ -z "$MATRIX_INPUT_DIR" ]]; then
    MATRIX_INPUT_DIR="${INPUT_DIR:-}"
  fi
  [[ -n "$MATRIX_INPUT_DIR" ]] || die "no output directory: set \$INPUT_DIR or pass --input-dir=<path>"
  [[ -d "$MATRIX_INPUT_DIR" ]] || die "output directory does not exist: $MATRIX_INPUT_DIR"
  [[ -w "$MATRIX_INPUT_DIR" ]] || die "output directory is not writable: $MATRIX_INPUT_DIR"

  local stamp run_dir report
  stamp="$(date -u +%Y%m%dT%H%M%SZ)"
  run_dir="$MATRIX_INPUT_DIR/stop-signal/$stamp"
  report="$run_dir/matrix.json"
  mkdir -p "$run_dir" || die "could not create $run_dir"

  trap cleanup EXIT

  plan_rows

  local -a rows=()
  local row
  row="$(run_row bash-child burn --entrypoint bash "$MATRIX_IMAGE" -c 'sleep 600 & wait')" || true
  rows+=("$row")
  row="$(run_row exec-child burn --entrypoint sleep "$MATRIX_IMAGE" 600)" || true
  rows+=("$row")
  row="$(run_row init-child term --init --entrypoint sleep "$MATRIX_IMAGE" 600)" || true
  rows+=("$row")

  {
    printf '{\n'
    printf '  "timestamp": %s,\n' "$(json_string "$stamp")"
    printf '  "image": %s,\n' "$(json_string "$MATRIX_IMAGE")"
    printf '  "stop_timeout": %s,\n' "${MATRIX_STOP_TIMEOUT:-null}"
    printf '  "repo_head": %s,\n' "$(json_string "$(git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null)")"
    printf '  "rows": [\n'
    local i=0
    for row in "${rows[@]}"; do
      (( i > 0 )) && printf ',\n'
      printf '    %s' "$row"
      i=$(( i + 1 ))
    done
    printf '\n  ]\n}\n'
  } >"$report"

  say "wrote $report"

  local unexpected=0
  for row in "${rows[@]}"; do
    [[ "$row" == *'"verdict": "unexpected"'* ]] && unexpected=$(( unexpected + 1 ))
    [[ "$row" == *'"status": "did-not-start"'* ]] && unexpected=$(( unexpected + 1 ))
  done
  if (( unexpected > 0 )); then
    say "VERDICT: FAIL, ${unexpected} row(s) contradict the model"
    exit 1
  fi
  say "VERDICT: PASS, every row matches the model"
}

ROW_CONTAINERS=()

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  set -uo pipefail
  main "$@"
fi

#!/usr/bin/env bash
# scripts/dispatch.sh
#
# The runner-seam entry point. Resolves a role to an assignment and the runtime
# that reaches it, then prints the command that runs one subagent, or runs it
# with `--run` and records what the attempt ended in.
#
# Usage:
#   dispatch.sh --role _IMPLEMENTER --brief <file> --dir <dir> \
#               [--model <provider>/<model>] [--thinking <level>] \
#               [--session <id>] [--run]
#   dispatch.sh --role <role> --brief <file> --worker --run \
#               [--base <rev>] [--run-dir <dir>]
#   dispatch.sh --list-roles
#   dispatch.sh --status [--json]
#   dispatch.sh --check --role <role>
#
# A brief names a role, not a runtime: the shell resolves the role's ordered
# entries, the machine decides which entry may be attempted now, and this script
# builds the command. `--model` is the caller's pin;
# a pin bypasses selection because a pinned run is not routed, and a seat run
# refuses one because a review's seats are the rotation over the role.
#
# `--worker` is the read-write mode: one delegated run that edits the tree and
# returns a change set. It attributes that set to `--base`, captures one
# recovery point for the caller's uncommitted work before the first attempt,
# writes each attempt's log under `--run-dir`, and advances to the next entry
# only while the tree is unchanged. It requires `--run`, because a worker
# invocation that only printed a command would measure nothing.
#
# Exit codes: 0 ran or printed. 2 usage. 3 blocked, every entry is cooling, and
# the message names the earliest wait. 4 unroutable, every entry is dead. Any
# other code is the last attempt's own, so a caller sees the worker's failure.
#
# This script is control flow; libs/dispatch/ holds the role table, the runtime
# decision, the argv shapes and the route machine, and libs/dispatch_worker.sh
# holds the git measurement and the supervision.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO_ROOT/src/libs/dispatch_worker.sh"
DISPATCH_CLI="$REPO_ROOT/src/libs/dispatch/cli.ts"
# The CLI chooses the table, so the override is passed through only when the
# operator set one, and no function here picks a path.
TABLE_ARGS=()
if [[ -n "${DISPATCH_REC_FILE:-}" ]]; then
  TABLE_ARGS=(--file "$DISPATCH_REC_FILE")
fi

ROLE=""
BRIEF=""
DIR="$(pwd)"
MODEL=""
THINKING=""
SESSION=""
RUN=0
WORKER=0
SEATS=1
SEATS_GIVEN=0
DIR_GIVEN=0
BASE="HEAD"
RUN_DIR=""
BASE_GIVEN=0
RUNDIR_GIVEN=0
LIST_ROLES=0
STATUS=0
STATUS_JSON=0
CHECK=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --role) ROLE="${2:-}"; shift 2 ;;
    --brief) BRIEF="${2:-}"; shift 2 ;;
    --dir) DIR="${2:-}"; DIR_GIVEN=1; shift 2 ;;
    --model) MODEL="${2:-}"; shift 2 ;;
    --thinking) THINKING="${2:-}"; shift 2 ;;
    --session) SESSION="${2:-}"; shift 2 ;;
    --run) RUN=1; shift ;;
    --seats)
      if [[ -z "${2:-}" ]]; then
        echo "dispatch: --seats requires a value" >&2
        exit 2
      fi
      SEATS="$2"
      SEATS_GIVEN=1
      shift 2
      ;;
    --worker) WORKER=1; shift ;;
    --base)
      if [[ -z "${2:-}" ]]; then
        echo "dispatch: --base requires a value" >&2
        exit 2
      fi
      BASE="$2"
      BASE_GIVEN=1
      shift 2
      ;;
    --run-dir)
      if [[ -z "${2:-}" ]]; then
        echo "dispatch: --run-dir requires a value" >&2
        exit 2
      fi
      RUN_DIR="$2"
      RUNDIR_GIVEN=1
      shift 2
      ;;
    --list-roles) LIST_ROLES=1; shift ;;
    --status) STATUS=1; shift ;;
    --json) STATUS_JSON=1; shift ;;
    --check) CHECK=1; shift ;;
    -h|--help)
      sed -n '2,/^$/p' "${BASH_SOURCE[0]}" | sed '$d'
      exit 0
      ;;
    *)
      echo "dispatch: unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

if (( WORKER && ! RUN )); then
  echo "dispatch: --worker requires --run" >&2
  exit 2
fi
if (( BASE_GIVEN && ! WORKER )); then
  echo "dispatch: --base is worker mode only" >&2
  exit 2
fi
if (( RUNDIR_GIVEN && ! WORKER && ! SEATS_GIVEN )); then
  echo "dispatch: --run-dir is worker or seat mode only" >&2
  exit 2
fi
if ! [[ "$SEATS" =~ ^[0-9]+$ ]] || (( SEATS < 1 )); then
  echo "dispatch: --seats needs a count of at least 1" >&2
  exit 2
fi
if (( SEATS_GIVEN )) && (( ! RUN )); then
  echo "dispatch: --seats requires --run" >&2
  exit 2
fi
if (( SEATS_GIVEN )) && (( WORKER )); then
  echo "dispatch: --seats is not a worker flag; a worker returns one change set" >&2
  exit 2
fi
if (( SEATS_GIVEN )) && [[ -n "$MODEL" ]]; then
  echo "dispatch: --seats cannot be pinned; a pin names one assignment" >&2
  exit 2
fi

if (( LIST_ROLES )); then
  node "$DISPATCH_CLI" table roles ${TABLE_ARGS[@]+"${TABLE_ARGS[@]}"}
  exit 0
fi

if (( STATUS )); then
  if (( STATUS_JSON )); then
    node "$DISPATCH_CLI" status --json
  else
    node "$DISPATCH_CLI" status
  fi
  exit $?
fi

if (( CHECK )); then
  if [[ -z "$ROLE" ]]; then
    echo "dispatch: --check requires --role" >&2
    exit 2
  fi
  rc=0
  node "$DISPATCH_CLI" table check --role "$ROLE" ${TABLE_ARGS[@]+"${TABLE_ARGS[@]}"} || rc=$?
  exit "$rc"
fi

if [[ -z "$ROLE" ]]; then
  echo "dispatch: --role is required" >&2
  exit 2
fi
if [[ -z "$BRIEF" ]]; then
  echo "dispatch: --brief is required" >&2
  exit 2
fi
if [[ ! -f "$BRIEF" ]]; then
  echo "dispatch: brief not found: $BRIEF" >&2
  exit 2
fi
if [[ ! -s "$BRIEF" ]]; then
  echo "dispatch: brief is empty: $BRIEF" >&2
  exit 2
fi

# worker_preflight -- refuse a worker invocation that cannot run, then print
# what the run is attributable to and where its evidence lands.
#
# The pre-state is captured once, before the first attempt, because every
# attempt can reset the tree and the caller's uncommitted work must have one
# recovery point for the whole run. The role is resolved here, not by the walk,
# so a role the table does not name refuses before the header claims a run
# exists.
worker_preflight() {
  local root base_sha pre entry assignments=""

  if [[ -n "$RUN_DIR" ]]; then
    if [[ ! -d "$RUN_DIR" ]]; then
      printf 'dispatch: run directory not found: %s\n' "$RUN_DIR" >&2
      exit 2
    fi
    if [[ ! -w "$RUN_DIR" ]]; then
      printf 'dispatch: run directory is not writable: %s\n' "$RUN_DIR" >&2
      exit 2
    fi
  else
    RUN_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dispatch-worker.XXXXXX")"
  fi

  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    printf 'dispatch: not inside a git work tree: %s\n' "$PWD" >&2
    exit 1
  fi
  root="$(git rev-parse --show-toplevel)"
  REPO_TREE="$root"
  # The change set is measured in the repository, so the worker edits there
  # rather than in whatever subdirectory the caller happened to invoke from.
  # A caller who named another directory is told, because ignoring a flag reads
  # as agreement with it.
  if (( DIR_GIVEN )); then
    printf 'dispatch: --dir is not a worker flag; a worker edits the repository root: %s\n' "$root" >&2
    exit 2
  fi
  DIR="$root"

  base_sha="$(dispatch_base_sha "$root" "$BASE")"
  if [[ -z "$base_sha" ]]; then
    printf 'dispatch: base revision not found: %s\n' "$BASE" >&2
    exit 1
  fi
  BASE_SHA="$base_sha"

  pre="$(dispatch_pre_state "$root")" || exit 1
  PRE_STATE="$pre"

  # A role the table cannot resolve refuses here, before the header claims a run
  # exists, and the message names the role.
  assignments="$(node "$DISPATCH_CLI" table list --role "$ROLE" ${TABLE_ARGS[@]+"${TABLE_ARGS[@]}"})" || exit 1
  ENTRIES=()
  while IFS= read -r entry; do
    [[ -n "$entry" ]] && ENTRIES+=("$entry")
  done <<<"$assignments"

  TIMEOUT="${DISPATCH_TIMEOUT:-1800}"

  printf 'brief: %s\nrole: %s\nbase: %s\npre-state: %s\nrun dir: %s\n' \
    "$BRIEF" "$ROLE" "$BASE_SHA" "$PRE_STATE" "$RUN_DIR"
}

# The role's ordered entries, as the table wrote them. Worker mode resolves them
# in its preflight, so every refusal there precedes the header.
ENTRIES=()
if (( WORKER )); then
  worker_preflight
else
  entries_text="$(node "$DISPATCH_CLI" table list --role "$ROLE" ${TABLE_ARGS[@]+"${TABLE_ARGS[@]}"})" || exit 1
  while IFS= read -r entry; do
    [[ -n "$entry" ]] && ENTRIES+=("$entry")
  done <<<"$entries_text"
fi

# choose_entry [START] -- set ENTRY to the assignment this dispatch will attempt,
# from the entries at index START and later.
#
# A pinned model is the whole answer. Otherwise the machine decides, and this
# function exits with the machine's code when nothing may be attempted.
choose_entry() {
  local start="${1:-0}"
  if [[ -n "$MODEL" ]]; then
    ENTRY="$MODEL"
    [[ -n "$THINKING" ]] && ENTRY="$MODEL at $THINKING"
    return 0
  fi
  local -a sel=()
  local i out rc
  for (( i = start; i < ${#ENTRIES[@]}; i++ )); do
    sel+=(--entry "${ENTRIES[i]}")
  done
  rc=0
  out="$(node "$DISPATCH_CLI" select "${sel[@]}")" || rc=$?
  case "$rc" in
    0)
      ENTRY="${out#run }"
      return 0
      ;;
    3)
      local iso reason routes
      read -r _ iso reason routes <<<"$out"
      printf 'dispatch: blocked until %s (%s): %s\n' "$iso" "$reason" "$routes" >&2
      exit 3
      ;;
    4)
      printf 'dispatch: unroutable: %s\n' "${out#unroutable }" >&2
      exit 4
      ;;
    *)
      exit "$rc"
      ;;
  esac
}

# build_command -- set CMD, ROUTE, LEVEL, RUNTIME and METERED from ENTRY.
build_command() {
  local model resolved
  model="${ENTRY%% at *}"
  LEVEL="${THINKING:-}"
  if [[ -z "$LEVEL" && "$ENTRY" == *" at "* ]]; then
    LEVEL="${ENTRY#* at }"
  fi
  ROUTE="$model"
  # The runtime is the entry's own. A fallback or a pin may name a runtime the
  # role's head does not, and the stall window and the metered count follow it.
  # A pin is the caller's value, so it is resolved as one and refused as one.
  if [[ -n "$MODEL" ]]; then
    resolved="$(node "$DISPATCH_CLI" table resolve --role "$ROLE" --pin "$MODEL" \
      ${TABLE_ARGS[@]+"${TABLE_ARGS[@]}"})" || return 1
  else
    resolved="$(node "$DISPATCH_CLI" table resolve --role "$ROLE" --entry "$ENTRY" \
      ${TABLE_ARGS[@]+"${TABLE_ARGS[@]}"})" || return 1
  fi
  RUNTIME="${resolved##* }"
  METERED=()
  if [[ "$RUNTIME" == "opencode" ]]; then
    METERED=(--metered)
  fi
  local -a build=(node "$DISPATCH_CLI" command --role "$ROLE" --brief "$BRIEF" --dir "$DIR" --model "$model")
  if [[ -n "$LEVEL" ]]; then
    build+=(--thinking "$LEVEL")
  fi
  if [[ -n "$SESSION" ]]; then
    build+=(--session "$SESSION")
  fi
  CMD="$("${build[@]}" ${TABLE_ARGS[@]+"${TABLE_ARGS[@]}"})"
}

# report_failures -- print the attempts of this walk that failed, with the
# verdict each ended in, so a caller reads every candidate even when a later one
# succeeded. Only a worker attempt is recorded here, so a general run prints
# nothing and its output is unchanged.
report_failures() {
  (( ${#FAILED[@]} )) || return 0
  printf 'failures: %d\n' "${#FAILED[@]}"
  printf '  %s\n' "${FAILED[@]}"
}

# seat_run -- a review-shaped run: n seats over the role's candidates.
#
# The seating, the rotation and what an outcome does to it are the library's
# (src/libs/dispatch/seats.ts). This function is the process half: it fires the
# seats the library orders, in one turn, and hands each attempt's outcome back.
# A turn ends when its slowest attempt does, so the turn costs one attempt rather
# than the sum and the candidate set has one writer per turn. Nothing sleeps: a
# turn the library cannot fill ends the run as blocked and names the wait.
seat_run() {
  local state="$RUN_DIR/seats.json" out="$RUN_DIR/seats.start" i line seat runtime entry log rc turn=0
  local -a fire_seat=() fire_rt=() fire_entry=() pidof=() results=()

  node "$DISPATCH_CLI" seats start --state "$state" --role "$ROLE" \
    --seats "$SEATS" ${TABLE_ARGS[@]+"${TABLE_ARGS[@]}"} >"$out" || return $?

  while :; do
    fire_seat=(); fire_rt=(); fire_entry=(); pidof=()
    while read -r line; do
      case "$line" in
        turn*) turn="${line#turn }" ;;
        fire*)
          read -r _ seat runtime entry <<<"$line"
          fire_seat+=("$seat"); fire_rt+=("$runtime"); fire_entry+=("$entry")
          ;;
        blocked*)
          printf 'dispatch: blocked: %s\n' "${line#blocked }" >&2
          return 3
          ;;
        finished)
          printf 'seat run: %s seats over role %s\n' "$SEATS" "$ROLE"
          return 0
          ;;
      esac
    done < "$out"

    if (( ${#fire_seat[@]} == 0 )); then
      printf 'dispatch: blocked: no seat may be attempted now\n' >&2
      return 3
    fi

    for i in "${!fire_seat[@]}"; do
      seat="${fire_seat[i]}"; runtime="${fire_rt[i]}"; ENTRY="${fire_entry[i]}"
      build_command || return 1
      log="$RUN_DIR/seat$seat-turn$turn.log"
      dispatch_run_supervised "$CMD" "$log" "$TIMEOUT" "$DISPATCH_CLI" \
        "$(dispatch_stall_window "$runtime")" </dev/null &
      pidof[i]=$!
    done

    results=()
    for i in "${!fire_seat[@]}"; do
      seat="${fire_seat[i]}"
      log="$RUN_DIR/seat$seat-turn$turn.log"
      rc=0
      wait "${pidof[i]}" || rc=$?
      printf 'seat %s turn %s: %s rc=%s log=%s\n' "$seat" "$turn" "${fire_entry[i]}" "$rc" "$log"
      results+=(--result "$seat:$rc:$log")
    done

    out="$RUN_DIR/seats.turn$turn"
    rc=0
    node "$DISPATCH_CLI" seats turn --state "$state" \
      ${TABLE_ARGS[@]+"${TABLE_ARGS[@]}"} "${results[@]}" >"$out" || rc=$?
    if (( rc != 0 )); then
      if (( rc == 3 )); then
        printf 'dispatch: blocked: %s\n' "$(sed -n 's/^blocked //p' "$out")" >&2
      fi
      return "$rc"
    fi
  done
}

if (( SEATS_GIVEN )); then
  TIMEOUT="${DISPATCH_TIMEOUT:-1800}"
  # A seat run is read-only, and a review reads one revision: a dirty tree makes
  # the report unattributable to a commit, which is the check the reviewer's old
  # runner made in code.
  if [[ -n "$(git -C "${DIR:-.}" status --porcelain 2>/dev/null)" ]]; then
    printf 'dispatch: the working tree is dirty; a review reads one revision: %s\n' "${DIR:-.}" >&2
    exit 1
  fi
  if (( RUNDIR_GIVEN )); then
    if [[ ! -d "$RUN_DIR" || ! -w "$RUN_DIR" ]]; then
      printf 'dispatch: run directory is not a writable directory: %s\n' "$RUN_DIR" >&2
      exit 2
    fi
  else
    RUN_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dispatch-seats.XXXXXX")"
  fi
  printf 'role: %s\nseats: %s\nrun dir: %s\n' "$ROLE" "$SEATS" "$RUN_DIR"
  seat_run
  exit $?
fi

choose_entry
build_command

if (( ! RUN )); then
  printf '%s\n' "$CMD"
  exit 0
fi

# may_advance CLASS SCOPE RC LOG -- whether the walk may attempt another entry
# after an attempt that ended CLASS with SCOPE, exited RC and logged to LOG.
# One predicate, so the two rules sit side by side.
#
# The general walk repeats the route machine's rule: a capability failure at the
# request or the account is not repaired by another model, an unclassified
# failure is not guessed at, and a timeout would cost the next entry the same
# budget without evidence that it fares better.
#
# A worker adds the tree, and the tree decides: a second model over a first
# model's edits mixes two workers' work, so a changed tree stops the walk
# whatever the attempt's class. An attempt that left the tree alone spent its
# model, and the walk names the next entry.
may_advance() {
  local class="$1" scope="$2" rc="$3" log="$4"
  case "$class" in
    timeout)
      printf 'dispatch: not retried: a timeout is the same budget again\n' >&2
      return 1
      ;;
  esac
  if (( WORKER )); then
    if [[ "$TREE_CHANGED" == "yes" ]]; then
      printf 'dispatch: the worker exited rc=%s after changing the tree: %s\n' "$rc" "$log" >&2
      return 1
    fi
    return 0
  fi
  case "$class:$scope" in
    capability:request|capability:account)
      printf 'dispatch: not retried: the repair is not another model\n' >&2
      return 1
      ;;
    unknown:*)
      printf 'dispatch: not retried: the failure is not classified\n' >&2
      return 1
      ;;
  esac
  return 0
}


# The walk: run the attempt, record what it ended in, and advance only when the
# outcome says another attempt can help.
attempt=0
next_index=0
FAILED=()
max=${#ENTRIES[@]}
(( max < 1 )) && max=1
# A pinned model is the only entry the walk may attempt, so a worker run makes
# one attempt rather than treating the role's list as candidates.
if (( WORKER )) && [[ -n "$MODEL" ]]; then
  max=1
fi
while :; do
  attempt=$(( attempt + 1 ))

  if (( WORKER )); then
    # Every attempt keeps its own log as evidence, so the previous one is
    # renamed off the current path before this attempt opens it.
    if (( attempt > 1 )); then
      mv "$LOG" "$RUN_DIR/worker-attempt-$(( attempt - 1 )).log"
    fi
    LOG="$RUN_DIR/worker.log"
    LEVEL_NOTE=""
    [[ -n "$LEVEL" ]] && LEVEL_NOTE=" at $LEVEL"
    printf 'attempt %s: model %s%s\ncommand: %s\n' "$attempt" "$ROUTE" "$LEVEL_NOTE" "$CMD"
    if ! dispatch_change_set "$REPO_TREE" "$BASE_SHA" \
      "$RUN_DIR/changes-before.txt" "$RUN_DIR/changes.err"; then
      printf 'dispatch: the change set could not be computed before the attempt: %s\n' \
        "$(tr '\n' ' ' <"$RUN_DIR/changes.err")" >&2
      exit 1
    fi
    start=$(date +%s)
  else
    LOG="$(mktemp)"
  fi

  rc=0
  if (( WORKER )); then
    dispatch_run_supervised "$CMD" "$LOG" "$TIMEOUT" "$DISPATCH_CLI" \
      "$(dispatch_stall_window "$RUNTIME")" || rc=$?
    elapsed=$(( $(date +%s) - start ))
    # The CLI can exit 0 having printed nothing. The log is the only evidence
    # that a worker ran, so an empty one is a failure, not a success.
    if (( rc == 0 )) && [[ ! -s "$LOG" ]]; then
      printf 'dispatch: the worker exited 0 with an empty log, so no work is evidenced\n' >&2
      rc=1
    fi
    if ! dispatch_change_set "$REPO_TREE" "$BASE_SHA" \
      "$RUN_DIR/changes.txt" "$RUN_DIR/changes.err"; then
      printf 'dispatch: the change set could not be computed after the attempt: %s\n' \
        "$(tr '\n' ' ' <"$RUN_DIR/changes.err")" >&2
      exit 1
    fi
    changed="$(awk 'END { print NR }' "$RUN_DIR/changes.txt")"
    TREE_CHANGED=no
    cmp -s "$RUN_DIR/changes-before.txt" "$RUN_DIR/changes.txt" || TREE_CHANGED=yes
    if [[ "$TREE_CHANGED" == "yes" ]]; then
      printf 'dispatch: attempt %d left this change set (%s):\n' "$attempt" "$RUN_DIR/changes.txt" >&2
      sed 's/^/  /' "$RUN_DIR/changes.txt" >&2
    fi
  else
    bash -c "$CMD" >"$LOG" 2>&1 || rc=$?
  fi

  if (( rc == 0 )); then
    # A pinned run is not routed, so it teaches the memory nothing: recording it
    # would let a pin revive a route the router had put to sleep.
    if [[ -z "$MODEL" ]]; then
      node "$DISPATCH_CLI" record --route "$ROUTE" --class success --scope none "${METERED[@]}" >/dev/null
    fi
    report_failures
    if (( WORKER )); then
      printf 'rc=%s %ss changed=%s model=%s log=%s\n' \
        "$rc" "$elapsed" "$changed" "$ROUTE" "$LOG"
    else
      cat "$LOG"
      rm -f "$LOG"
    fi
    exit 0
  fi

  text="$(tail -c 4000 "$LOG" | tr '\n' ' ')"
  read -r _pclass class scope reason refresh <<<"$(node "$DISPATCH_CLI" classify --text "$text")"
  record_args=(--route "$ROUTE" --class "$class" --scope "$scope" --text "$text" "${METERED[@]}")
  [[ "$reason" != "-" ]] && record_args+=(--reason "$reason")
  [[ "$refresh" != "-" ]] && record_args+=(--refresh-at "$refresh")
  [[ -n "$MODEL" ]] || node "$DISPATCH_CLI" record "${record_args[@]}" >/dev/null
  if (( WORKER )); then
    FAILED+=("$ROUTE ($_pclass $class $scope $reason $refresh)")
  fi

  cat "$LOG" >&2
  if (( WORKER )); then
    printf 'attempt %s failed: rc=%s %ss changed=%s verdict=%s msg=%s log=%s\n' \
      "$attempt" "$rc" "$elapsed" "$changed" "$_pclass $class $scope $reason $refresh" \
      "${text:0:160}" "$LOG"
  else
    rm -f "$LOG"
  fi
  printf 'dispatch: attempt %d on %s ended %s (%s)\n' "$attempt" "$ROUTE" "$class" "$scope" >&2

  if ! may_advance "$class" "$scope" "$rc" "$LOG"; then
    report_failures
    exit "$rc"
  fi

  if (( attempt >= max )); then
    printf 'dispatch: every entry was attempted\n' >&2
    report_failures
    exit "$rc"
  fi

  # A worker attempt spends its entry: the route machine keeps a route that
  # failed without saying anything about itself in the table, so selecting over
  # the whole list again would re-run the model that just failed.
  if (( WORKER )); then
    next_index=$attempt
  fi
  choose_entry "$next_index"
  build_command
done

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
#   dispatch.sh --role <role> --brief <file> --seats <n> --run \
#               [--model <provider>/<model>] [--thinking <level>] [--run-dir <dir>]
#   dispatch.sh --list-roles
#   dispatch.sh --status [--json]
#   dispatch.sh --check --role <role>
#
# A brief names a role, not a runtime: the shell resolves the role's ordered
# entries, the machine decides which entry may be attempted now, and this script
# builds the command. `--model` is the caller's pin: resolution is the default
# mechanism, and a caller who names the assignment takes it as given, so a pin
# bypasses selection and a seat run seats every seat on it.
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
# The CLI chooses the table from DISPATCH_REC_FILE; `--file` stays its explicit
# override for a test that needs another file.

ROLE=""
BRIEF=""
DIR="$(pwd)"
MODEL=""
THINKING=""
SESSION=""
MODE=""
RUN=0
SEATS=1
BASE="HEAD"
RUN_DIR=""
declare -A GIVEN=()

# set_mode MODE -- one mode per call. A second, different mode flag refuses,
# because the mode is a decision rather than a sum of booleans.
set_mode() {
  if [[ -n "$MODE" && "$MODE" != "$1" ]]; then
    printf 'dispatch: --%s and --%s are alternatives\n' "$MODE" "$1" >&2
    exit 2
  fi
  MODE="$1"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --role) ROLE="${2:-}"; shift 2 ;;
    --brief) BRIEF="${2:-}"; shift 2 ;;
    --dir) GIVEN[--dir]=1; DIR="${2:-}"; shift 2 ;;
    --model) MODEL="${2:-}"; shift 2 ;;
    --thinking) THINKING="${2:-}"; shift 2 ;;
    --session) SESSION="${2:-}"; shift 2 ;;
    --run) RUN=1; shift ;;
    --seats)
      if [[ -z "${2:-}" ]]; then
        echo "dispatch: --seats requires a value" >&2
        exit 2
      fi
      set_mode seats
      SEATS="$2"
      shift 2
      ;;
    --worker) set_mode worker; shift ;;
    --base)
      if [[ -z "${2:-}" ]]; then
        echo "dispatch: --base requires a value" >&2
        exit 2
      fi
      GIVEN[--base]=1
      BASE="$2"
      shift 2
      ;;
    --run-dir)
      if [[ -z "${2:-}" ]]; then
        echo "dispatch: --run-dir requires a value" >&2
        exit 2
      fi
      GIVEN[--run-dir]=1
      RUN_DIR="$2"
      shift 2
      ;;
    --list-roles) set_mode list; shift ;;
    --status) set_mode status; shift ;;
    --json) GIVEN[--json]=1; shift ;;
    --check) set_mode check; shift ;;
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

# The mode is one value, written by the flag that names it: print (the default),
# run, worker, seats, list, status or check.
if (( RUN )); then
  [[ -z "$MODE" ]] && MODE=run
fi
[[ -z "$MODE" ]] && MODE=print

if [[ "$MODE" == worker || "$MODE" == seats ]] && (( ! RUN )); then
  printf 'dispatch: --%s requires --run\n' "$MODE" >&2
  exit 2
fi
# Which modes may carry a flag that is not itself a mode. One relation, so a
# new flag is one row rather than a fifth if-block, and the parse refuses the
# combination wherever it appears.
declare -A FLAG_MODES=(
  [--base]="worker|worker mode only"
  [--run-dir]="worker seats|worker or seat mode only"
  [--json]="status|status mode only"
)
for flag in "${!FLAG_MODES[@]}"; do
  [[ -z "${GIVEN[$flag]:-}" ]] && continue
  belongs="${FLAG_MODES[$flag]%%|*}"
  where="${FLAG_MODES[$flag]#*|}"
  if [[ " $belongs " != *" $MODE "* ]]; then
    printf 'dispatch: %s is %s\n' "$flag" "$where" >&2
    exit 2
  fi
done
if [[ "$MODE" == seats ]]; then
  if ! [[ "$SEATS" =~ ^[0-9]+$ ]] || (( SEATS < 1 )); then
    echo "dispatch: --seats needs a count of at least 1" >&2
    exit 2
  fi
fi

case "$MODE" in
  list)
    node "$DISPATCH_CLI" table roles
    exit 0
    ;;
  status)
    if [[ -n "${GIVEN[--json]:-}" ]]; then
      node "$DISPATCH_CLI" status --json
    else
      node "$DISPATCH_CLI" status
    fi
    exit $?
    ;;
  check)
    if [[ -z "$ROLE" ]]; then
      echo "dispatch: --check requires --role" >&2
      exit 2
    fi
    rc=0
    node "$DISPATCH_CLI" table check --role "$ROLE" || rc=$?
    exit "$rc"
    ;;
esac

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
  local root base_sha pre entry

  dispatch_run_dir "${TMPDIR:-/tmp}/dispatch-worker.XXXXXX" || exit 2

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
  if [[ -n "${GIVEN[--dir]:-}" ]]; then
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
  node "$DISPATCH_CLI" table list --role "$ROLE" >/dev/null || exit 1

  TIMEOUT="${DISPATCH_TIMEOUT:-1800}"

  printf 'brief: %s\nrole: %s\nbase: %s\npre-state: %s\nrun dir: %s\n' \
    "$BRIEF" "$ROLE" "$BASE_SHA" "$PRE_STATE" "$RUN_DIR"
}

if [[ "$MODE" == worker ]]; then
  worker_preflight
fi

# plan_run [FLAGS...] -- one library call resolves and plans an attempt. Sets
# CMD, ROUTE, LEVEL, RUNTIME and METERED. The library owns the selection from
# the role's whole list, so the shell never holds an assignment's text as a
# cursor, and this is the one place the plan record is decoded.
plan_run() {
  local out first
  local -a plan=(node "$DISPATCH_CLI" plan --role "$ROLE" --brief "$BRIEF" --dir "$DIR" "$@")
  [[ -n "$SESSION" ]] && plan+=(--session "$SESSION")
  out="$("${plan[@]}")" || return $?
  first="$(head -n 1 <<<"$out")"
  IFS='|' read -r ROUTE LEVEL RUNTIME <<<"$first"
  METERED=()
  [[ "$RUNTIME" == opencode ]] && METERED=(--metered)
  CMD="$(tail -n +2 <<<"$out")"
}

# plan_attempt [MODEL LEVEL] -- one attempt's argv. With no argument the caller's
# pin applies; a seat passes the assignment it was dealt.
plan_attempt() {
  local model="${1-$MODEL}" level="${2-$THINKING}"
  local -a flags=()
  [[ -n "$model" ]] && flags+=(--model "$model")
  [[ -n "$level" ]] && flags+=(--thinking "$level")
  plan_run "${flags[@]}"
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
  local state="$RUN_DIR/seats.json" out="$RUN_DIR/seats.start" i seat runtime log rc turn=0
  local -a fire_seat=() fire_rt=() fire_key=() fire_level=() fire_entry=() pidof=() results=()

  local -a pin_args=()
  [[ -n "$MODEL" ]] && pin_args+=(--model "$MODEL")
  [[ -n "$THINKING" ]] && pin_args+=(--thinking "$THINKING")
  node "$DISPATCH_CLI" seats start --state "$state" --role "$ROLE" \
    --seats "$SEATS" ${pin_args[@]+"${pin_args[@]}"} >"$out" || return $?

  while :; do
    fire_seat=(); fire_rt=(); fire_key=(); fire_level=(); fire_entry=(); pidof=()
    # The plan is NUL-delimited records, so a field can carry any character and
    # the reader never splits one on a separator it did not declare.
    while IFS= read -r -d '' kind; do
      case "$kind" in
        turn) IFS= read -r -d '' turn ;;
        fire)
          IFS= read -r -d '' seat
          IFS= read -r -d '' runtime
          IFS= read -r -d '' key
          IFS= read -r -d '' level
          IFS= read -r -d '' entry
          fire_seat+=("$seat"); fire_rt+=("$runtime"); fire_key+=("$key")
          fire_level+=("$level"); fire_entry+=("$entry")
          ;;
        finished)
          printf 'seat run: %s seats over role %s\n' "$SEATS" "$ROLE"
          return 0
          ;;
      esac
    done < "$out"

    for i in "${!fire_seat[@]}"; do
      seat="${fire_seat[i]}"; runtime="${fire_rt[i]}"
      plan_attempt "${fire_key[i]}" "${fire_level[i]}" || return 1
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
      results+=(--seat "$seat" --rc "$rc" --log "$log")
    done

    out="$RUN_DIR/seats.turn$turn"
    rc=0
    node "$DISPATCH_CLI" seats turn --state "$state" "${results[@]}" >"$out" || rc=$?
    if (( rc != 0 )); then
      # A blocked turn names its wait on stderr, which this shell passes through.
      return "$rc"
    fi
  done
}

if [[ "$MODE" == seats ]]; then
  TIMEOUT="${DISPATCH_TIMEOUT:-1800}"
  # A seat run is read-only, and a review reads one revision: a dirty tree makes
  # the report unattributable to a commit, which is the check the reviewer's old
  # runner made in code.
  if [[ -n "$(git -C "${DIR:-.}" status --porcelain 2>/dev/null)" ]]; then
    printf 'dispatch: the working tree is dirty; a review reads one revision: %s\n' "${DIR:-.}" >&2
    exit 1
  fi
  dispatch_run_dir "${TMPDIR:-/tmp}/dispatch-seats.XXXXXX" || exit 2
  printf 'role: %s\nseats: %s\nrun dir: %s\n' "$ROLE" "$SEATS" "$RUN_DIR"
  seat_run
  exit $?
fi

plan_attempt || exit $?

if [[ "$MODE" != run && "$MODE" != worker ]]; then
  printf '%s\n' "$CMD"
  exit 0
fi

# attempt_open -- the log path, the pre-state measurement and the attempt header.
# The worker keeps each attempt's log as its evidence; a general run writes one
# temporary log and prints it on success.
attempt_open() {
  if [[ "$MODE" == worker ]]; then
    # Every attempt keeps its own log as evidence, so the previous one is
    # renamed off the current path before this attempt opens it.
    if (( attempt > 1 )); then
      mv "$LOG" "$RUN_DIR/worker-attempt-$(( attempt - 1 )).log"
    fi
    LOG="$RUN_DIR/worker.log"
    local note=""
    [[ -n "$LEVEL" ]] && note=" at $LEVEL"
    printf 'attempt %s: model %s%s\ncommand: %s\n' "$attempt" "$ROUTE" "$note" "$CMD"
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
}

# attempt_exec -- one attempt: supervised for a worker, a plain shell for a
# general run, whose printed command is the caller's own.
attempt_exec() {
  if [[ "$MODE" == worker ]]; then
    dispatch_run_supervised "$CMD" "$LOG" "$TIMEOUT" "$DISPATCH_CLI" \
      "$(dispatch_stall_window "$RUNTIME")" || rc=$?
    elapsed=$(( $(date +%s) - start ))
  else
    bash -c "$CMD" >"$LOG" 2>&1 || rc=$?
  fi
}

# attempt_close -- the post-attempt change set and its report.
attempt_close() {
  [[ "$MODE" == worker ]] || return 0
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
}

attempt=0
FAILED=()
while :; do
  attempt=$(( attempt + 1 ))
  emptylog=no
  rc=0
  attempt_open
  attempt_exec
  attempt_close

  # A process that exits 0 having printed nothing is an observation of nothing:
  # the log is the only evidence that an attempt ran. Empty means no
  # non-whitespace in the tail, which is the seat path's reading of the same
  # rule. The walk owns the rule and the message; the shell reports the fact.
  text="$(tail -c 4000 "$LOG")"
  if (( rc == 0 )) && [[ -z "${text//[[:space:]]/}" ]]; then
    rc=1
    emptylog=yes
  fi

  if (( rc == 0 )); then
    # An attempt is an observation of the route, whichever chose it: a pin reads
    # no route, and still records what its attempt ended in.
    node "$DISPATCH_CLI" record --route "$ROUTE" --class success --scope none "${METERED[@]}" >/dev/null
    report_failures
    if [[ "$MODE" == worker ]]; then
      printf 'rc=%s %ss changed=%s model=%s log=%s\n' \
        "$rc" "$elapsed" "$changed" "$ROUTE" "$LOG"
    else
      cat "$LOG"
      rm -f "$LOG"
    fi
    exit 0
  fi

  read -r _pclass class scope reason refresh <<<"$(node "$DISPATCH_CLI" classify --text "$(tr '\n' ' ' <<<"$text")")"
  record_args=(--route "$ROUTE" --class "$class" --scope "$scope" "${METERED[@]}")
  [[ "$reason" != "-" ]] && record_args+=(--reason "$reason")
  [[ "$refresh" != "-" ]] && record_args+=(--refresh-at "$refresh")
  node "$DISPATCH_CLI" record "${record_args[@]}" >/dev/null
  if [[ "$MODE" == worker ]]; then
    FAILED+=("$ROUTE ($_pclass $class $scope $reason $refresh)")
  fi

  cat "$LOG" >&2
  if [[ "$MODE" == worker ]]; then
    printf 'attempt %s failed: rc=%s %ss changed=%s verdict=%s msg=%s log=%s\n' \
      "$attempt" "$rc" "$elapsed" "$changed" "$_pclass $class $scope $reason $refresh" \
      "${text:0:160}" "$LOG"
  else
    rm -f "$LOG"
  fi
  printf 'dispatch: attempt %d on %s ended %s (%s)\n' "$attempt" "$ROUTE" "$class" "$scope" >&2

  walk_args=(--class "$class" --scope "$scope")
  if [[ "$MODE" == worker ]]; then
    walk_args+=(--worker)
    [[ "$TREE_CHANGED" == "yes" ]] && walk_args+=(--tree-changed)
  fi
  [[ "$emptylog" == "yes" ]] && walk_args+=(--empty-log)
  if ! node "$DISPATCH_CLI" walk "${walk_args[@]}"; then
    report_failures
    exit "$rc"
  fi

  # A pin is the caller's whole answer, so it is attempted once. Otherwise the
  # library selects from the role's list: every outcome that reaches here left
  # its route unselectable, so the next plan visits the next entry, and an
  # exhausted list answers blocked or unroutable with the library's own message.
  if [[ -n "$MODEL" ]]; then
    printf 'dispatch: every entry was attempted\n' >&2
    report_failures
    exit "$rc"
  fi
  plan_attempt || exit $?
done

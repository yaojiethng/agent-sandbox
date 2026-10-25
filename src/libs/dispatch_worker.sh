#!/usr/bin/env bash
# libs/dispatch_worker.sh
#
# The worker half of the runner seam: the measurement of an attempt's change
# set, the recovery point for the caller's uncommitted work, and the process
# supervision that ends an attempt which cannot succeed.
#
# Nothing here reads a role table or picks a model. The entrypoint decides
# which model an attempt names; this file answers only what the tree holds and
# whether the attempt is still alive, so a second reader of the role table
# cannot appear beside the first.
#
# No set -euo pipefail here  --  this file is always sourced, never executed
# directly. Safety settings are inherited from the parent script.

# dispatch_base_sha ROOT REV  --  print the commit REV names, or nothing. An
# empty answer is a value here, not a refusal: `HEAD` on an unreachable tree and
# a mistyped revision are the same question, and the caller names the answer as
# the value it must refuse.
dispatch_base_sha() {
  local root="$1" rev="$2" sha
  sha="$(git -C "$root" rev-parse --verify --quiet "${rev}^{commit}" 2>/dev/null)" || sha=""
  printf '%s' "$sha"
  return 0
}

# dispatch_pre_state ROOT  --  print `none` on a clean tree, or the stash commit
# that holds the tracked modifications and the index.
#
# A worker edits with --auto and can reset the tree, so this commit is the
# caller's only copy of that work. `git stash create` writes a dangling commit
# without touching the tree or the index, and it does not capture untracked
# files. A capture that fails, or that does not resolve to a commit, is a
# refusal rather than a value: a caller holding an unusable recovery point
# would read it as recoverable.
dispatch_pre_state() {
  local root="$1" out rc=0
  if [[ -z "$(git -C "$root" status --porcelain)" ]]; then
    printf 'none'
    return 0
  fi
  out="$(git -C "$root" stash create)" || rc=$?
  if (( rc != 0 )); then
    printf 'dispatch: the pre-state could not be captured: git stash create exited %s: %s\n' \
      "$rc" "$out" >&2
    return 1
  fi
  if [[ -n "$out" ]]; then
    if ! git -C "$root" cat-file -e "${out}^{commit}" 2>/dev/null; then
      printf 'dispatch: the pre-state does not resolve to a commit: %s\n' "$out" >&2
      return 1
    fi
    printf '%s' "$out"
    return 0
  fi
  printf 'none'
}

# dispatch_change_set ROOT BASE OUT ERR  --  write the change set from BASE to
# the working tree as name-status lines, deduplicated by path, and return
# non-zero when git fails.
#
# Both diffs are needed: the working-tree view misses content the index still
# holds, and the untracked list is in neither. The caller writes the set before
# and after an attempt, so the difference between the two sets is the attempt's
# own contribution; the caller's uncommitted work sits in both and cancels.
dispatch_change_set() {
  local root="$1" base="$2" out="$3" err="$4" raw
  raw="$(
    {
      git -C "$root" diff --name-status "$base" \
        && git -C "$root" diff --cached --name-status "$base" \
        && git -C "$root" ls-files --others --exclude-standard | sed 's/^/??\t/'
    } 2>"$err"
  )" || return 1
  printf '%s\n' "$raw" | awk -F'\t' 'NF && !seen[$NF]++' >"$out"
}

# dispatch_refusal_line LOG CLI  --  print the first error-bearing line, outside
# the title model's lines, whose verdict the classifier does not answer
# `unknown`; print nothing when there is none.
#
# The trigger is the provider's own sentence and the verdict is the classifier's,
# so the refusal vocabulary has one home: a pattern added beside the classifier
# reaches this reader with no copy to keep in step. `agent=title` lines are
# excluded because the title model's failure is not the run's failure. A line
# the classifier answers `unknown` is not evidence that the attempt cannot
# succeed, so the scan continues to the next line instead of stopping on it.
#
# The block is bounded because the classifier is a process: a worker log holding
# a failing test suite holds hundreds of lines containing `error`, so the first
# twelve are asked about in one call rather than one call each.
dispatch_refusal_line() {
  local log="$1" cli="$2" candidates refused
  [[ -f "$log" ]] || return 0
  candidates="$(grep -v 'agent=title' "$log" 2>/dev/null | grep -i 'error' | head -n 12)"
  [[ -z "$candidates" ]] && return 0
  refused="$(node "$cli" refusal --text "$candidates" 2>/dev/null)" || return 0
  printf '%s' "$refused"
}

# dispatch_run_supervised CMD LOG LIMIT CLI [STALL]  --  run one attempt in the
# foreground of this call, and end it the moment it cannot succeed.
#
# A refused request is retried silently by the CLI, which prints only its
# banner and then stays alive on an event subscription it never closes, so two
# signals end an attempt early: a refusal line in the log, and a log that has
# stopped growing while still holding almost nothing. Without them a spent
# model would consume the whole limit before the caller could reach the next
# entry. setsid puts the attempt in its own process group, so ending the attempt
# reaches the processes it started.
#
# STALL is the silence window the caller chose for this runtime; 15 seconds when
# the caller passes nothing. DISPATCH_POLL sets the poll interval, in seconds.
dispatch_run_supervised() {
  local cmd="$1" log="$2" limit="$3" cli="$4"
  local stall="${5:-${DISPATCH_STALL:-15}}"
  local poll="${DISPATCH_POLL:-1}"
  local launcher=(bash -c)
  command -v setsid >/dev/null 2>&1 && launcher=(setsid bash -c)

  : >"$log"
  "${launcher[@]}" "$cmd" >"$log" 2>&1 &
  local pid=$! rc=0 start size=0 last_size=-1 last_change asked_size=-1 refused
  start=$(date +%s)
  last_change=$start
  while kill -0 "$pid" 2>/dev/null; do
    size=$(wc -c <"$log" 2>/dev/null || printf '0')
    # The classifier is a process, so it is asked once per new output rather
    # than once per poll: a line it has already answered cannot change its
    # verdict, and a found refusal ends the attempt here.
    if (( size != asked_size )); then
      asked_size=$size
      refused="$(dispatch_refusal_line "$log" "$cli")"
      if [[ -n "$refused" ]]; then
        dispatch_stop_process "$pid" "$log" "the model refused the request: $refused"
        return 1
      fi
    fi
    if (( size != last_size )); then
      last_size=$size
      last_change=$(date +%s)
    elif (( size < 1024 && $(date +%s) - last_change >= stall )); then
      # The silence is evidence only where the runtime was expected to speak.
      dispatch_stop_process "$pid" "$log" \
        "no output for ${stall}s, which is how this runtime retries a refused request"
      return 1
    fi
    if (( $(date +%s) - start >= limit )); then
      dispatch_stop_process "$pid" "$log" "the time limit of ${limit}s expired"
      return 1
    fi
    sleep "$poll"
  done
  wait "$pid" || rc=$?
  return "$rc"
}

# dispatch_stall_window RUNTIME  --  how long silence may last before an
# attempt is ended.
#
# The OpenCode CLI prints its refusal in about a second and then stays alive on
# an event subscription it never closes, so silence there means a refusal. pi
# prints its banner and then nothing until the run finishes, which takes
# minutes, so silence there is a run in progress and the attempt's own time
# limit is the only bound. A window shorter than a pi run ends every pi attempt
# at the window, which is how a role's paid fallback became unreachable.
dispatch_stall_window() {
  case "$1" in
    opencode) printf '%s' "${DISPATCH_STALL:-15}" ;;
    *) printf '%s' "${DISPATCH_TIMEOUT:-1800}" ;;
  esac
}

# dispatch_stop_process PID LOG REASON  --  end one attempt's process group and
# record why in its log, so the caller reads the cause instead of an exit code.
dispatch_stop_process() {
  local pid="$1" log="$2" reason="$3"
  kill -TERM -- "-$pid" 2>/dev/null || kill -TERM "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
  printf 'aborted: %s\n' "$reason" >>"$log"
}

# dispatch_run_dir TEMPLATE -- validate a caller's run directory or create one.
#
# The worker and the seat run both keep their evidence in a run directory, so
# both refuse an unusable path before an attempt spends anything, with one
# message. Sets RUN_DIR; a caller that named one keeps it.
dispatch_run_dir() {
  local template="$1"
  if [[ -n "${RUN_DIR:-}" ]]; then
    if [[ ! -d "$RUN_DIR" ]]; then
      printf 'dispatch: run directory not found: %s\n' "$RUN_DIR" >&2
      return 1
    fi
    if [[ ! -w "$RUN_DIR" ]]; then
      printf 'dispatch: run directory is not writable: %s\n' "$RUN_DIR" >&2
      return 1
    fi
    return 0
  fi
  RUN_DIR="$(mktemp -d "$template")" || return 1
}

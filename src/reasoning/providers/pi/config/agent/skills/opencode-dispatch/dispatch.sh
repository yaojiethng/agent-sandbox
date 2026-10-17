#!/usr/bin/env bash
# src/reasoning/providers/pi/config/agent/skills/opencode-dispatch/dispatch.sh
#
# Dispatch one general OpenCode worker over one brief file.
#
# A worker is a read-write delegated run: it edits the tree, runs tests, and
# returns a change set. It is not read-only like pi-reviewer-dispatch, so the
# caller attributes the change set to a named base revision.
#
# The command is built through the runner seam (src/libs/dispatch.sh), so the
# pi/opencode flag mapping has one home. The worker runs in the foreground of
# one call, so it is never orphaned.
#
# Refuses a missing or empty brief, an absent or unwritable scratch directory,
# and an unresolvable base revision.
#
# Prints the brief, role, candidate list, run directory, base revision and
# pre-state recovery point, one line per attempt, then one line: rc, seconds,
# changed-file count, the model that produced the change set, and the log.
#
# Fallback. The role's line may list several models, separated by `;`. They are
# tried in file order, and the next one runs only when the attempt failed without
# touching the tree, so a second model never inherits a first model's edits. An
# attempt is stopped the moment its log carries a refusal the CLI would retry
# silently (a rate limit, unfunded access, a disabled model), so a spent free
# tier costs seconds rather than the whole timeout.
#
# Exit codes: 0 = a worker ran and logged. 1 = a refusal, or every candidate
# failed.
#
# Usage: bash dispatch.sh <brief-file> <scratch-dir> [role]
#
# Env: OPENCODE_DISPATCH_MODEL     pins one model; unset reads the role's line
#      OPENCODE_DISPATCH_THINKING  default high
#      OPENCODE_DISPATCH_TIMEOUT   per attempt, default 1800
#      OPENCODE_DISPATCH_STALL     silence, in seconds, that ends an attempt,
#                                  default 15
#      OPENCODE_DISPATCH_BASE      default HEAD

set -euo pipefail

readonly DEFAULT_MODEL="opencode/deepseek-v4.1-flash-free"
readonly DEFAULT_THINKING="high"
readonly DEFAULT_ROLE="_IMPLEMENTER"
readonly DEFAULT_TIMEOUT=1800
readonly DEFAULT_BASE="HEAD"

usage() {
  printf 'usage: bash dispatch.sh <brief-file> <scratch-dir> [role]\n' >&2
  exit 1
}

# refuses <what> <why>
refuse() {
  printf 'refusing: %s\n  %s\n' "$1" "$2" >&2
  exit 1
}

# role_candidates ROLE  --  one "<pair> <level>" line per model the role's line
# names, in file order. The first is the role's primary model; the rest are the
# fallbacks the operator listed after it. A role with no line, or a line with no
# value, yields nothing, and the caller falls back to the built-in default.
role_candidates() {
  local role="$1" file entry pair level
  file="$(dispatch_rec_file)" || return 1
  [[ -f "$file" ]] || return 0
  while IFS= read -r entry; do
    entry="$(printf '%s' "$entry" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    [[ -n "$entry" ]] || continue
    if [[ "$entry" == *" at "* ]]; then
      pair="${entry%% at *}"
      level="${entry##* at }"
    else
      pair="$entry"
      level=""
    fi
    printf '%s %s\n' "$pair" "${level:-$DEFAULT_THINKING}"
  done < <(grep -E "^${role}:" "$file" | head -n 1 | cut -d: -f2- | tr ';' '\n')
}

# refusal_in LOG  --  the refusal the run's own model reported, or empty. The
# title model's failure is not the run's failure, so its lines are excluded by
# agent name.
refusal_in() {
  { grep -v 'agent=title' "$1" 2>/dev/null \
      | grep -oE 'Rate limit exceeded|Insufficient account funds|Model access is disabled|FreeTierError' \
      | head -n 1; } || true
}

# refusal_class LOG  --  the class of a refusal the CLI printed, or `unknown`.
# The message is the provider's own text; the client discards the response type
# and its `retry-after`, so the text is the only classification the log carries.
refusal_class() {
  case "$(refusal_in "$1")" in
    'Rate limit exceeded'|'Insufficient account funds') printf 'quota' ;;
    'Model access is disabled'|'FreeTierError') printf 'capability' ;;
    *) printf 'unknown' ;;
  esac
}

# run_worker CMD LOG LIMIT  --  run one attempt, and stop it the moment it cannot
# succeed. A refused request is retried silently by the CLI and prints nothing
# beyond its banner, so two signals end an attempt early: a refusal signature in
# the log, and a log that has stopped growing while still holding almost
# nothing. Without them a spent model would consume the whole limit before the
# caller could reach a fallback.
run_worker() {
  local cmd="$1" log="$2" limit="$3"
  local stall="${OPENCODE_DISPATCH_STALL:-15}"
  local launcher=(bash -c)
  command -v setsid >/dev/null 2>&1 && launcher=(setsid bash -c)

  : >"$log"
  "${launcher[@]}" "$cmd" >"$log" 2>&1 &
  local pid=$! rc=0 start size=0 last_size=-1 last_change
  start=$(date +%s)
  last_change=$start
  while kill -0 "$pid" 2>/dev/null; do
    if [[ -n "$(refusal_in "$log")" ]]; then
      stop_worker "$pid" "$log" "the model refused the request: $(refusal_in "$log")"
      return 1
    fi
    size=$(wc -c <"$log" 2>/dev/null || printf '0')
    if (( size != last_size )); then
      last_size=$size
      last_change=$(date +%s)
    elif (( size < 1024 && $(date +%s) - last_change >= stall )); then
      stop_worker "$pid" "$log" "no output for ${stall}s, which is how the CLI retries a refused request"
      return 1
    fi
    if (( $(date +%s) - start >= limit )); then
      stop_worker "$pid" "$log" "the time limit of ${limit}s expired"
      return 1
    fi
    sleep 1
  done
  wait "$pid" || rc=$?
  return "$rc"
}

# stop_worker PID LOG REASON  --  end one attempt and record why in its log, so
# the caller reads the cause rather than an exit code alone.
stop_worker() {
  local pid="$1" log="$2" reason="$3"
  kill -TERM -- "-$pid" 2>/dev/null || kill -TERM "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
  printf 'aborted: %s\n' "$reason" >>"$log"
}

# write_change_set ROOT BASE OUT  --  the change set from BASE to the working
# tree: the working diff, the staged diff and the untracked paths, deduplicated
# by path. Both diff calls are needed, because the working-tree view misses
# content the index still holds. Exits non-zero when git fails, so the caller can
# name the failure instead of reporting an empty set.
write_change_set() {
  local root="$1" base="$2" out="$3" err="$4" rc=0
  {
    git -C "$root" diff --name-status "$base" || exit
    git -C "$root" diff --cached --name-status "$base" || exit
    git -C "$root" ls-files --others --exclude-standard | sed 's/^/??\t/' || exit
  } 2>"$err" | awk -F'\t' '!seen[$NF]++' >"$out" || rc=$?
  return "$rc"
}

main() {
  [[ $# -ge 2 && $# -le 3 ]] || usage
  local brief="$1" scratch="$2" role="${3:-$DEFAULT_ROLE}"

  [[ -f "$brief" ]] || refuse "brief not found" "$brief"
  [[ -s "$brief" ]] || refuse "brief is empty" "$brief"
  [[ -d "$scratch" ]] || refuse "scratch directory not found" "$scratch"
  [[ -w "$scratch" ]] || refuse "scratch directory is not writable" "$scratch"
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
    || refuse "not inside a git work tree" "$PWD"

  local repo_root
  repo_root="$(git rev-parse --show-toplevel)"
  # shellcheck source=/dev/null
  source /opt/sandbox/lib/dispatch.sh

  # The base names the revision the reported change set is attributable to.
  # A dirty tree is allowed, so a later pass over the same unit runs in place.
  local base="${OPENCODE_DISPATCH_BASE:-$DEFAULT_BASE}"
  local base_sha
  base_sha="$(git -C "$repo_root" rev-parse --verify --quiet "${base}^{commit}")" || true
  [[ -n "$base_sha" ]] || refuse "base revision not found" "$base"

  # The recovery point for the caller's uncommitted work. A worker runs with
  # --auto and can reset the tree, so a dirty tree is stashed first. git stash
  # create writes a dangling commit of the tracked modifications and the index
  # without touching the tree; it does not capture untracked files. The stash
  # is the caller's only copy of that work, so a capture that fails or does
  # not resolve to a commit is a refusal, not a value.
  local pre="none"
  if [[ -n "$(git -C "$repo_root" status --porcelain)" ]]; then
    local pre_out pre_rc=0
    pre_out="$(git -C "$repo_root" stash create)" || pre_rc=$?
    [[ "$pre_rc" -eq 0 ]] \
      || refuse "the pre-state could not be captured" "git stash create exited $pre_rc: $pre_out"
    if [[ -n "$pre_out" ]]; then
      git -C "$repo_root" cat-file -e "${pre_out}^{commit}" 2>/dev/null \
        || refuse "the pre-state does not resolve to a commit" "$pre_out"
      pre="$pre_out"
    fi
  fi

  local timeout_secs="${OPENCODE_DISPATCH_TIMEOUT:-$DEFAULT_TIMEOUT}"

  # The candidates are the role's models in file order: the primary first, the
  # operator's fallbacks after it. A model named in the environment is the only
  # candidate, so a caller can pin one model and get no fallback.
  local -a candidates=()
  if [[ -n "${OPENCODE_DISPATCH_MODEL:-}" ]]; then
    candidates=("${OPENCODE_DISPATCH_MODEL} ${OPENCODE_DISPATCH_THINKING:-$DEFAULT_THINKING}")
  else
    local candidate
    while IFS= read -r candidate; do
      [[ -n "$candidate" ]] && candidates+=("$candidate")
    done < <(role_candidates "$role")
    (( ${#candidates[@]} )) || candidates=("$DEFAULT_MODEL $DEFAULT_THINKING")
  fi

  local run_dir
  run_dir="$(mktemp -d "$scratch/opencode-dispatch.XXXXXX")"
  printf 'brief: %s\nrole: %s\ncandidates: %s\nrun dir: %s\nbase: %s\npre-state: %s\n' \
    "$brief" "$role" "$(printf '%s, ' "${candidates[@]}" | sed 's/, $//')" "$run_dir" "$base_sha" "$pre"

  local attempt=0 rc=0 start elapsed chosen="" changed=0 cmd pair level log refused_note=""
  local -a refused=()
  for candidate in "${candidates[@]}"; do
    attempt=$(( attempt + 1 ))
    pair="${candidate% *}"
    level="${candidate##* }"
    [[ "$level" == "$candidate" ]] && level="$DEFAULT_THINKING"
    cmd="$(dispatch_command "$role" "$brief" "$repo_root" "$pair" "$level")"
    # The seam baked into the image may predate the flags that put the CLI's
    # error channel on stderr. Insert them when the builder omits them; a seam
    # that carries them makes this a no-op.
    if [[ "$cmd" != *"--print-logs"* ]]; then
      cmd="${cmd/ run / run --print-logs --log-level ERROR }"
    fi

    log="$run_dir/worker.log"
    if (( attempt > 1 )); then
      mv "$log" "$run_dir/worker-attempt-$(( attempt - 1 )).log"
    fi
    printf 'attempt %s: model %s at %s\ncommand: %s\n' "$attempt" "$pair" "$level" "$cmd"

    # The change set is the unit's, measured from the base. The caller's own
    # uncommitted work sits in it too, so the attempt's contribution is the
    # difference between the set before it ran and the set after, and only a
    # difference means the worker touched the tree.
    write_change_set "$repo_root" "$base_sha" "$run_dir/changes-before.txt" "$run_dir/changes.err" \
      || refuse "the change set could not be computed" "git failed before the worker ran: $(tr '\n' ' ' <"$run_dir/changes.err")"

    start=$(date +%s)
    rc=0
    run_worker "$cmd" "$log" "$timeout_secs" || rc=$?
    elapsed=$(( $(date +%s) - start ))

    write_change_set "$repo_root" "$base_sha" "$run_dir/changes.txt" "$run_dir/changes.err" \
      || refuse "the change set could not be computed" "git failed after the worker ran: $(tr '\n' ' ' <"$run_dir/changes.err")"
    changed="$(awk 'END { print NR }' "$run_dir/changes.txt")"
    local touched="no"
    cmp -s "$run_dir/changes-before.txt" "$run_dir/changes.txt" || touched="yes"

    if [[ "$rc" -eq 0 && -s "$log" ]]; then
      chosen="$pair"
      break
    fi
    if [[ "$touched" == "yes" ]]; then
      # The attempt touched the tree, so a second model would mix two workers'
      # edits. Report the attempt and leave the advance to the caller.
      refuse "the worker exited rc=$rc after changing the tree" "$log"
    fi
    printf 'attempt %s failed: rc=%s %ss changed=0 class=%s log=%s\n' \
      "$attempt" "$rc" "$elapsed" "$(refusal_class "$log")" "$log"
    refused+=("$pair ($(refusal_class "$log"))")
  done

  [[ -n "$chosen" ]] || refused_note="${refused[*]:-none}"
  if (( ${#refused[@]} )); then
    printf 'failures: %s\n' "${#refused[@]}"
    printf '  %s\n' "${refused[@]}"
  fi
  [[ -n "$chosen" ]] || refuse "every candidate failed" "${refused_note:-none}"
  printf 'rc=%s %ss changed=%s model=%s log=%s\n' "$rc" "$elapsed" "$changed" "$chosen" "$log"
}

main "$@"

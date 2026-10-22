#!/usr/bin/env bash
# src/reasoning/providers/pi/config/agent/skills/pi-reviewer-dispatch/dispatch.sh
#
# Dispatch the pinned reviewer pair over one brief file.
#
# A reviewer is a read-only delegated run: it takes a brief, holds judgement
# against it, and returns a report. It writes nothing, so the only evidence it
# leaves is its log and its session file.
#
# The scratch directory is a required argument and has no default. The provider
# AGENTS.md defines that path, the calling skill follows the definition, and
# this script carries no copy of the value to drift from it.
#
# Refuses a missing or empty brief, an absent or unwritable scratch directory,
# and a dirty working tree. A reviewer reading content its caller is still
# editing produces findings that cannot be attributed to a revision.
#
# Prints one line per reviewer: label, rc, seconds, effective model, log path.
#
# Exit codes: 0 = every reviewer ran and logged. 1 = a refusal, or a reviewer
# that produced no work or bound a model other than the one requested.
#
# Usage: bash dispatch.sh <brief-file> <scratch-dir>
#
# Env: REVIEW_TIMEOUT  per-reviewer seconds (default 900)

set -euo pipefail

readonly DEFAULT_TIMEOUT=900

# label|provider|model|thinking level
readonly REVIEWERS=(
  "fast|opencode-go|deepseek-v4.1-flash|high"
  "flash|deepseek|deepseek-flash|high"
)

usage() {
  printf 'usage: bash dispatch.sh <brief-file> <scratch-dir>\n' >&2
  exit 1
}

# refuses <what> <why>
refuse() {
  printf 'refusing: %s\n  %s\n' "$1" "$2" >&2
  exit 1
}

main() {
  [[ $# -eq 2 ]] || usage
  local brief="$1" scratch="$2"

  [[ -f "$brief" ]] || refuse "brief not found" "$brief"
  [[ -s "$brief" ]] || refuse "brief is empty" "$brief"
  [[ -d "$scratch" ]] || refuse "scratch directory not found" "$scratch"
  [[ -w "$scratch" ]] || refuse "scratch directory is not writable" "$scratch"

  git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
    || refuse "not inside a git work tree" "$PWD"
  local dirty
  dirty="$(git status --porcelain)"
  [[ -z "$dirty" ]] || refuse "the working tree is dirty" "$dirty"

  local run_dir
  run_dir="$(mktemp -d "$scratch/review-dispatch.XXXXXX")"
  local timeout_secs="${REVIEW_TIMEOUT:-$DEFAULT_TIMEOUT}"
  printf 'brief: %s\nscratch: %s\nrun dir: %s\n' "$brief" "$scratch" "$run_dir"

  local entry label provider model level session log
  local -a pids=() labels=() sessions=() logs=()
  for entry in "${REVIEWERS[@]}"; do
    IFS='|' read -r label provider model level <<<"$entry"
    session="$run_dir/$label.jsonl"
    log="$run_dir/$label.log"
    labels+=("$label")
    sessions+=("$session")
    logs+=("$log")
    timeout "$timeout_secs" pi \
      --provider "$provider" \
      --model "$model" \
      --thinking "$level" \
      --session "$session" \
      -p "$(cat "$brief")" >"$log" 2>&1 &
    pids+=("$!")
  done

  local i rc start elapsed requested actual failed=0
  for i in "${!labels[@]}"; do
    rc=0
    start=$(date +%s)
    wait "${pids[$i]}" || rc=$?
    elapsed=$(( $(date +%s) - start ))
    IFS='|' read -r label provider requested level <<<"${REVIEWERS[$i]}"

    if [[ ! -s "${logs[$i]}" ]]; then
      printf '%-6s rc=%-3s %4ss  NO OUTPUT  %s\n' "$label" "$rc" "$elapsed" "${logs[$i]}"
      failed=1
      continue
    fi
    actual="$(grep -o '"model":"[^"]*"' "${sessions[$i]}" 2>/dev/null | sort -u | head -1 || true)"
    actual="${actual#\"model\":\"}"
    actual="${actual%\"}"
    if [[ -n "$actual" && "$actual" != "$requested" ]]; then
      printf '%-6s rc=%-3s %4ss  BOUND %s, requested %s  %s\n' \
        "$label" "$rc" "$elapsed" "$actual" "$requested" "${logs[$i]}"
      failed=1
      continue
    fi
    printf '%-6s rc=%-3s %4ss  model=%s  %s\n' \
      "$label" "$rc" "$elapsed" "${actual:-unverified}" "${logs[$i]}"
    [[ "$rc" -eq 0 ]] || failed=1
  done

  [[ "$failed" -eq 0 ]] || refuse "one or more reviewers produced no usable work" "see the run dir above"
}

main "$@"

#!/usr/bin/env bash
# src/reasoning/providers/pi/config/agent/bin/review-dispatch.sh
#
# Run two reviewer seats over one brief file. Provisioned to
# $AGENT_HOME/agent/bin/review-dispatch.sh beside the AGENTS.md section that
# instructs a review dispatch.
#
# A pair is not decided here. The caller resolves the role line and passes the
# pair and its thinking level, so this script holds no model, no provider and
# no fallback: a pair pinned inside a dispatch site is the bypass the role
# table exists to close. Two seats of one pair is the repeat the contract
# names, not two families.
#
# Refuses a malformed pair, a missing or empty brief, an absent or unwritable
# scratch directory, and a dirty working tree. A reviewer reading content its
# caller is still editing produces findings that cannot be attributed to a
# revision.
#
# Prints one line per seat: seat, rc, seconds, effective model, log path.
#
# Exit codes: 0 = both seats logged and bound the requested model. 1 = a
# refusal, or a seat that produced no work or bound another model.
#
# Usage: bash review-dispatch.sh <brief-file> <scratch-dir> <pair> <level>
#
# Env: REVIEW_TIMEOUT  per-seat seconds (default 900)

set -euo pipefail

readonly DEFAULT_TIMEOUT=900
readonly SEATS=(a b)

usage() {
  printf 'usage: bash review-dispatch.sh <brief-file> <scratch-dir> <pair> <level>\n' >&2
  exit 1
}

# refuse <what> <why>
refuse() {
  printf 'refusing: %s\n  %s\n' "$1" "$2" >&2
  exit 1
}

main() {
  [[ $# -eq 4 ]] || usage
  local brief="$1" scratch="$2" pair="$3" level="$4"

  [[ "$pair" == */* ]] || refuse "pair is not provider/model" "$pair"
  local provider="${pair%%/*}" model="${pair#*/}"
  [[ -n "$provider" && -n "$model" ]] || refuse "pair is not provider/model" "$pair"
  [[ -n "$level" ]] || refuse "thinking level is empty" "$pair"

  [[ -f "$brief" ]] || refuse "brief not found" "$brief"
  [[ -s "$brief" ]] || refuse "brief is empty" "$brief"
  [[ -d "$scratch" ]] || refuse "scratch directory not found" "$scratch"
  [[ -w "$scratch" ]] || refuse "scratch directory is not writable" "$scratch"

  git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
    || refuse "not inside a git work tree" "$PWD"
  local dirty
  dirty="$(git status --porcelain)"
  [[ -z "$dirty" ]] || refuse "the working tree is dirty" "$dirty"

  local run_dir timeout_secs
  run_dir="$(mktemp -d "$scratch/review-dispatch.XXXXXX")"
  timeout_secs="${REVIEW_TIMEOUT:-$DEFAULT_TIMEOUT}"
  printf 'brief: %s\nscratch: %s\npair: %s\nrun dir: %s\n' \
    "$brief" "$scratch" "$pair" "$run_dir"

  local seat session log
  local -a pids=()
  for seat in "${SEATS[@]}"; do
    session="$run_dir/$seat.jsonl"
    log="$run_dir/$seat.log"
    timeout "$timeout_secs" pi \
      --provider "$provider" \
      --model "$model" \
      --thinking "$level" \
      --session "$session" \
      -p "$(cat "$brief")" >"$log" 2>&1 &
    pids+=("$!")
  done

  local i rc start elapsed actual failed=0
  for i in "${!SEATS[@]}"; do
    seat="${SEATS[$i]}"
    log="$run_dir/$seat.log"
    session="$run_dir/$seat.jsonl"
    rc=0
    start=$(date +%s)
    wait "${pids[$i]}" || rc=$?
    elapsed=$(( $(date +%s) - start ))

    if [[ ! -s "$log" ]]; then
      printf '%-4s rc=%-3s %4ss  NO OUTPUT  %s\n' "$seat" "$rc" "$elapsed" "$log"
      failed=1
      continue
    fi
    actual="$(grep -o '"model":"[^"]*"' "$session" 2>/dev/null | sort -u | head -1 || true)"
    actual="${actual#\"model\":\"}"
    actual="${actual%\"}"
    if [[ -n "$actual" && "$actual" != "$model" ]]; then
      printf '%-4s rc=%-3s %4ss  BOUND %s, requested %s  %s\n' \
        "$seat" "$rc" "$elapsed" "$actual" "$model" "$log"
      failed=1
      continue
    fi
    printf '%-4s rc=%-3s %4ss  model=%s  %s\n' \
      "$seat" "$rc" "$elapsed" "${actual:-unverified}" "$log"
    [[ "$rc" -eq 0 ]] || failed=1
  done

  [[ "$failed" -eq 0 ]] || refuse "one or more seats produced no usable work" "see the run dir above"
}

main "$@"

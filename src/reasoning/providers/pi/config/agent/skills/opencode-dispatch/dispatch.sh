#!/usr/bin/env bash
# src/reasoning/providers/pi/config/agent/skills/opencode-dispatch/dispatch.sh
#
# Dispatch one general OpenCode worker over one brief file.
#
# A worker is a read-write delegated run: it edits the tree, runs tests, and
# returns a change set. It is not read-only like pi-reviewer-dispatch, so the
# caller commits from a clean tree and attributes the diff.
#
# The command is built through the runner seam (src/libs/dispatch.sh), so the
# pi/opencode flag mapping has one home. The worker runs in the foreground of
# one call, so it is never orphaned.
#
# Refuses a missing or empty brief, an absent or unwritable scratch directory,
# and a dirty working tree.
#
# Prints the run directory and one line: rc, seconds, changed-file count, log.
#
# Exit codes: 0 = the worker ran and logged. 1 = a refusal, or a worker that
# produced no output or exited non-zero.
#
# Usage: bash dispatch.sh <brief-file> <scratch-dir> [role]
#
# Env: OPENCODE_DISPATCH_MODEL     default opencode/deepseek-v4.1-flash-free
#      OPENCODE_DISPATCH_THINKING  default high
#      OPENCODE_DISPATCH_TIMEOUT   default 1800

set -euo pipefail

readonly DEFAULT_MODEL="opencode/deepseek-v4.1-flash-free"
readonly DEFAULT_THINKING="high"
readonly DEFAULT_ROLE="_IMPLEMENTER"
readonly DEFAULT_TIMEOUT=1800

usage() {
  printf 'usage: bash dispatch.sh <brief-file> <scratch-dir> [role]\n' >&2
  exit 1
}

# refuses <what> <why>
refuse() {
  printf 'refusing: %s\n  %s\n' "$1" "$2" >&2
  exit 1
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
  local dirty
  dirty="$(git status --porcelain)"
  [[ -z "$dirty" ]] || refuse "the working tree is dirty" "$dirty"

  local repo_root
  repo_root="$(git rev-parse --show-toplevel)"
  # shellcheck source=/dev/null
  source /opt/sandbox/lib/dispatch.sh

  local model="${OPENCODE_DISPATCH_MODEL:-$DEFAULT_MODEL}"
  local level="${OPENCODE_DISPATCH_THINKING:-$DEFAULT_THINKING}"
  local timeout_secs="${OPENCODE_DISPATCH_TIMEOUT:-$DEFAULT_TIMEOUT}"

  local cmd
  cmd="$(dispatch_command "$role" "$brief" "$repo_root" "$model" "$level")"

  local run_dir
  run_dir="$(mktemp -d "$scratch/opencode-dispatch.XXXXXX")"
  printf 'brief: %s\nrole: %s\nmodel: %s\nrun dir: %s\ncommand: %s\n' \
    "$brief" "$role" "$model" "$run_dir" "$cmd"

  local rc=0 start elapsed
  start=$(date +%s)
  timeout "$timeout_secs" bash -c "$cmd" >"$run_dir/worker.log" 2>&1 || rc=$?
  elapsed=$(( $(date +%s) - start ))

  git -C "$repo_root" status --porcelain >"$run_dir/changes.txt" 2>&1 || true
  local changed
  changed="$(awk 'END { print NR }' "$run_dir/changes.txt")"
  printf 'rc=%s %ss changed=%s log=%s\n' "$rc" "$elapsed" "$changed" "$run_dir/worker.log"

  [[ -s "$run_dir/worker.log" ]] || refuse "the worker produced no output" "$run_dir"
  [[ "$rc" -eq 0 ]] || refuse "the worker exited rc=$rc" "$run_dir/worker.log"
}

main "$@"

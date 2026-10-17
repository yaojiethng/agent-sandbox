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
# Prints the brief, role, model, run directory, base revision and pre-state
# recovery point, then one line: rc, seconds, changed-file count, log.
#
# Exit codes: 0 = the worker ran and logged. 1 = a refusal, or a worker that
# produced no output or exited non-zero.
#
# Usage: bash dispatch.sh <brief-file> <scratch-dir> [role]
#
# Env: OPENCODE_DISPATCH_MODEL     default opencode/deepseek-v4.1-flash-free
#      OPENCODE_DISPATCH_THINKING  default high
#      OPENCODE_DISPATCH_TIMEOUT   default 1800
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

  local model="${OPENCODE_DISPATCH_MODEL:-$DEFAULT_MODEL}"
  local level="${OPENCODE_DISPATCH_THINKING:-$DEFAULT_THINKING}"
  local timeout_secs="${OPENCODE_DISPATCH_TIMEOUT:-$DEFAULT_TIMEOUT}"

  local cmd
  cmd="$(dispatch_command "$role" "$brief" "$repo_root" "$model" "$level")"

  local run_dir
  run_dir="$(mktemp -d "$scratch/opencode-dispatch.XXXXXX")"
  printf 'brief: %s\nrole: %s\nmodel: %s\nrun dir: %s\nbase: %s\npre-state: %s\ncommand: %s\n' \
    "$brief" "$role" "$model" "$run_dir" "$base_sha" "$pre" "$cmd"

  local rc=0 start elapsed
  start=$(date +%s)
  timeout "$timeout_secs" bash -c "$cmd" >"$run_dir/worker.log" 2>&1 || rc=$?
  elapsed=$(( $(date +%s) - start ))

  # The change set is the unit's: the diff from the base to the working tree,
  # plus the staged diff and the untracked paths, deduplicated by path. Both
  # diff calls are needed, because the working-tree view misses content the
  # index still holds. A git failure here is caught and routed through refuse,
  # so the caller reads a named refusal rather than a bare exit.
  local changes_rc=0
  {
    git -C "$repo_root" diff --name-status "$base_sha" || exit
    git -C "$repo_root" diff --cached --name-status "$base_sha" || exit
    git -C "$repo_root" ls-files --others --exclude-standard | sed 's/^/??\t/' || exit
  } 2>"$run_dir/changes.err" | awk -F'\t' '!seen[$NF]++' >"$run_dir/changes.txt" || changes_rc=$?
  [[ "$changes_rc" -eq 0 ]] \
    || refuse "the change set could not be computed" "git exited $changes_rc: $(tr '\n' ' ' <"$run_dir/changes.err")"
  local changed
  changed="$(awk 'END { print NR }' "$run_dir/changes.txt")"
  printf 'rc=%s %ss changed=%s log=%s\n' "$rc" "$elapsed" "$changed" "$run_dir/worker.log"

  [[ -s "$run_dir/worker.log" ]] || refuse "the worker produced no output" "$run_dir"
  [[ "$rc" -eq 0 ]] || refuse "the worker exited rc=$rc" "$run_dir/worker.log"
}

main "$@"

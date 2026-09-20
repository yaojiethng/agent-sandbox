#!/usr/bin/env bash
# src/libs/session_save_policy.sh
# The session save lifecycle: whether a save is needed, the baseline it
# compares against, and one autosave cycle that performs the save.
# The decision functions are pure policy over git state and the previous
# export's .export-status record. autosave_cycle drives the export pipeline: it
# is handed the export command, so the sequence is testable without docker.
#
# Provides:
#   session_save_needed SANDBOX_DIR BASELINE  --  decide whether to save
#   save_decision SANDBOX_DIR EXPORT_DIR LABEL  --  resolve the baseline and decide
#   autosave_tick PATH_FN CHANGES_DIR SANDBOX_DIR SESSION_ID EXPORT_CMD...  --  one tick
#   autosave_cycle CHECKPOINT_DIR CHANNEL_DIR SANDBOX_DIR EXPORT_CMD...  --  one cycle

_self_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_self_dir/export_status.sh"
source "$_self_dir/session_state.sh"

# session_save_needed SANDBOX_DIR BASELINE
#   Decides whether an autosave/session save must run.
#   Returns:
#     0  save      -- the working tree is dirty (any uncommitted or untracked
#                     change; always save), or HEAD differs from BASELINE
#                     (new commits since the last save).
#     1  skip      -- the tree is clean and HEAD equals BASELINE.
#     2  undeterminable -- git could not read the repository. Distinct from
#                     "skip" so the caller never reports a broken sandbox as
#                     "nothing to save"; the caller saves or fails loudly.
#
#   BASELINE is the comparison point: the HEAD the previous save captured, or
#   init_sha on the first save. Callers resolve it with _save_baseline.
session_save_needed() {
  local _sandbox_dir="$1" _baseline="$2"
  local _dirty _head
  if ! _dirty=$(git -C "$_sandbox_dir" status --porcelain 2>/dev/null); then
    return 2   # git cannot read the tree  --  undeterminable, not "clean"
  fi
  if [[ -n "$_dirty" ]]; then
    return 0   # dirty tree  --  always save
  fi
  if ! _head=$(git -C "$_sandbox_dir" rev-parse HEAD 2>/dev/null); then
    return 2   # no resolvable HEAD  --  undeterminable
  fi
  [[ -n "$_head" && "$_head" != "$_baseline" ]]
}

# save_decision SANDBOX_DIR EXPORT_DIR LABEL
#   The caller-facing form of session_save_needed: resolves the baseline from
#   EXPORT_DIR's own .export-status (falling back to init_sha), then returns 0
#   when a save must run and 1 when there is nothing to save. Prints the
#   operator diagnostic for both the skip and the undeterminable case. Callers
#   do not switch on the raw status; this helper owns that decision so the
#   three-way mapping lives in one place (bash-coding-conventions.md 3.2).
#   LABEL names the caller in the diagnostic.
save_decision() {
  local _sandbox_dir="${1:?save_decision requires a sandbox dir}" _export_dir="${2:-}" _label="${3:-save}" _rc=0
  local _baseline
  _baseline=$(_save_baseline "$_sandbox_dir" "$_export_dir")
  session_save_needed "$_sandbox_dir" "$_baseline" || _rc=$?
  case "$_rc" in
    0) return 0 ;;
    1) echo "$_label: nothing to save  --  clean tree at last-saved HEAD" >&2; return 1 ;;
    2) echo "$_label: cannot read the sandbox repository; saving anyway" >&2; return 0 ;;
    *) echo "$_label: unknown save status $_rc; saving anyway" >&2; return 0 ;;
  esac
}

# _save_baseline SANDBOX_DIR EXPORT_DIR
#   The comparison point for session_save_needed: the HEAD the previous
#   SUCCESS export in EXPORT_DIR captured (its .export-status HEAD line), or
#   init_sha when EXPORT_DIR has no successful export (first save). This folds
#   level 1 (baseline = init_sha) and level 2 (baseline = last saved HEAD)
#   into one rule: after the first save, the baseline is whatever that save
#   recorded, so "nothing new since last save" is the check that runs.
_save_baseline() {
  local _sandbox_dir="$1" _export_dir="$2"
  local _head=""
  if export_status_is_success "$_export_dir"; then
    _head=$(export_status_read "$_export_dir" HEAD)
  fi
  if [[ -n "$_head" ]]; then
    echo "$_head"
    return 0
  fi
  session_state_read "$_sandbox_dir" "init_sha" 2>/dev/null || true
}


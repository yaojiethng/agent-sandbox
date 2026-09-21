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
#   session_export_needed SANDBOX_DIR  --  the exit-time session-export decision
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

# session_export_needed SANDBOX_DIR
#   The exit-time session-export decision. The baseline is the durable branch
#   point (SESSION_STATE init_sha), never an autosave checkpoint: a session
#   that did any work must produce its durable exit bundle even when an
#   autosave already captured the state. The autosave dir is an ephemeral,
#   overwritten fallback slot, not a durable record, so it must not suppress
#   the session export.
#   Returns:
#     0  run       -- the tree is dirty or HEAD differs from the branch point.
#     1  skip      -- the tree is clean at the branch point (no work at all).
#     2  undeterminable -- git cannot read the repository; the caller saves or
#                    fails loudly.
session_export_needed() {
  local _sandbox_dir="${1:?session_export_needed requires a sandbox dir}" _rc=0
  local _baseline
  _baseline=$(session_state_read "$_sandbox_dir" "init_sha" 2>/dev/null || true)
  session_save_needed "$_sandbox_dir" "$_baseline" || _rc=$?
  case "$_rc" in
    0) return 0 ;;
    1) echo "session-export: nothing to save  --  clean tree at the branch point" >&2; return 1 ;;
    2) echo "session-export: cannot read the sandbox repository; saving anyway" >&2; return 0 ;;
    *) echo "session-export: unknown save status $_rc; saving anyway" >&2; return 0 ;;
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

# autosave_cycle CHECKPOINT_DIR CHANNEL_DIR SANDBOX_DIR EXPORT_CMD...
#   One autosave cycle. Builds the next checkpoint at a staging path beside
#   CHECKPOINT_DIR's channel, runs EXPORT_CMD against it, and swaps it into
#   place only on success.
#   Returns:
#     0  the checkpoint was swapped in.
#     1  the export or the swap failed; the previous checkpoint is kept.
#     2  nothing to save; the live checkpoint is untouched.
#
#   CHECKPOINT_DIR is the checkpoint directory itself (the caller resolves it
#   with routing's export_path, so the channel layout keeps one owner).
#
#   The staging path must NOT sit inside the channel: every reader enumerates
#   the channel's direct children (the interactive pickers,
#   resolve_latest_dir_by_mtime, resolve_source_for_draft), so a staging
#   directory there would be selected as a bundle after an interrupted cycle.
#   The channel parent is created before the swap because `mv` into a missing
#   destination directory fails, and the live checkpoint is moved aside rather
#   than deleted so a failed swap can restore it.
#
#   EXPORT_CMD is the export verb, called as EXPORT_CMD SANDBOX_DIR STAGE_DIR
#   SESSION_ID. The cycle supplies all three arguments, so a caller cannot drop
#   or misorder them; taking the verb as a parameter keeps the shipped sequence
#   testable without docker.
autosave_cycle() {
  local as_dir="${1:?autosave_cycle requires the checkpoint dir}"
  local channel_dir="${2:?autosave_cycle requires the channel dir}"
  local sandbox_dir="${3:?autosave_cycle requires a sandbox dir}"
  shift 3
  local export_cmd=("$@")

  local as_stage as_old as_side
  # The staging, aside, and rescued-log paths sit beside the channel, not inside
  # it: the channel's direct children are what every reader enumerates.
  as_side="$(dirname "$channel_dir")"
  as_stage="$as_side/.autosave-staging-$(basename "$as_dir")"
  as_old="$as_side/.autosave-previous-$(basename "$as_dir")"
  local rc=0

  # Recover a checkpoint left aside by a cycle killed mid-swap before deciding
  # anything else: if the live path is missing but the aside path is present,
  # the aside path holds the only checkpoint, and no reader scans it. Doing this
  # first means even a "nothing to save" cycle restores it, and lets the stale
  # staging path be cleared before the decision can return early.
  mkdir -p "$channel_dir"
  rm -rf "$as_stage"
  if [[ ! -d "$as_dir" && -d "$as_old" ]]; then
    mv "$as_old" "$as_dir"
  fi

  # The decision and its diagnostics belong to save_decision; this function maps
  # its boolean back onto "skip" (2).
  save_decision "$sandbox_dir" "$as_dir" "autosave" || return 2

  mkdir -p "$as_stage"
  echo "autosave: checkpoint started  --  $as_dir" >&2
  # The cycle supplies the first two arguments from state it already holds, so a
  # caller cannot drop or misorder them: EXPORT_CMD is called as
  # EXPORT_CMD SANDBOX_DIR STAGE_DIR SESSION_ID. The sandbox dir was previously
  # passed twice, once here and once by the caller, and one copy was dropped --
  # which broke every autosave in production while the suite stayed green.
  "${export_cmd[@]}" "$sandbox_dir" "$as_stage" "$(basename "$as_dir")" || rc=$?
  if (( rc != 0 )); then
    # The export writes its diagnostic inside the directory it was handed, which
    # is the staging path about to be removed. Rescue the log beside the channel
    # first, or the operator loses the file the export just announced.
    local _log
    for _log in "$as_stage"/*EXPORT-ERROR.log; do
      [[ -f "$_log" ]] || continue
      mv "$_log" "$as_side/" 2>/dev/null || true
    done
    rm -rf "$as_stage"
    local _kept=""
    [[ -d "$as_dir" ]] && _kept="; previous checkpoint kept"
    echo "autosave: checkpoint FAILED (exit $rc)${_kept}  --  $as_dir" >&2
    return 1
  fi

  rm -rf "$as_old"
  [[ -d "$as_dir" ]] && mv "$as_dir" "$as_old"
  rc=0
  mv "$as_stage" "$as_dir" || rc=$?
  if (( rc != 0 )); then
    rm -rf "$as_stage"
    [[ -d "$as_old" ]] && mv "$as_old" "$as_dir"
    echo "autosave: checkpoint swap FAILED (exit $rc); previous checkpoint kept  --  $as_dir" >&2
    return 1
  fi
  rm -rf "$as_old"
  echo "autosave: checkpoint SUCCESS  --  $as_dir" >&2
}

# autosave_tick PATH_FN CHANGES_DIR SANDBOX_DIR SESSION_ID EXPORT_CMD...
#   One autosave tick: resolve the checkpoint path via PATH_FN (export_path from
#   routing.sh, passed in so this module stays free of the channel layout), then
#   run the cycle. Returns whatever autosave_cycle returns -- 0 swapped in,
#   1 export or swap failed, 2 nothing to save -- and 1 as well when SESSION_ID
#   is unset, since there is then no checkpoint path to write. The caller loops
#   on this and absorbs every status, because a tick's outcome is not a reason
#   to end the loop.
autosave_tick() {
  local path_fn="${1:?autosave_tick requires a path function}"
  local changes_dir="${2:?autosave_tick requires a changes dir}"
  local sandbox_dir="${3:?autosave_tick requires a sandbox dir}"
  local session_id="${4:-}"
  shift 4

  local checkpoint=""
  checkpoint=$("$path_fn" "$changes_dir" "autosave" "$session_id" 2>/dev/null) || checkpoint=""
  if [[ -z "$checkpoint" ]]; then
    echo "autosave: SESSION_ID is unset; skipping tick" >&2
    return 1
  fi
  autosave_cycle "$checkpoint" "$changes_dir/autosave" "$sandbox_dir" "$@"
}

# autosave_loop INTERVAL PATH_FN CHANGES_DIR SANDBOX_DIR SESSION_ID EXPORT_CMD
#   The autosave loop: every INTERVAL seconds, run one tick. Every non-zero
#   status a tick can return (1 export or swap failed, 2 nothing to save, 1 for
#   an unset session id) is an outcome of that tick, never a reason to end the
#   loop, so each call absorbs its status. Runs in the foreground; the caller
#   backgrounds it and tracks the PID for teardown.
autosave_loop() {
  local interval="${1:?autosave_loop requires an interval}"
  local path_fn="${2:?autosave_loop requires a path function}"
  local changes_dir="${3:?autosave_loop requires a changes dir}"
  local sandbox_dir="${4:?autosave_loop requires a sandbox dir}"
  local session_id="${5:-}"
  shift 5
  while true; do
    sleep "$interval"
    autosave_tick "$path_fn" "$changes_dir" "$sandbox_dir" "$session_id" "$@" || true
  done
}

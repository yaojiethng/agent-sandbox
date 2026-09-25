#!/usr/bin/env bash
# src/libs/resume_list.sh
# Session inventory + display for the resume command. Sourced by
# scripts/resume_agent.sh (and any tool showing the resumable-session table).
#
# Shared module globals: RESUME_INVENTORY (the parsed table), _WORK_MAP /
# _STATE_MAP (rendering inputs), _RESUME_HEADER (column header). Callers set
# SANDBOX_DIR, PROVIDER_FILTER, RESUME_LIST_PAGE_SIZE before building.

source "$(dirname "${BASH_SOURCE[0]}")/session_inventory.sh"

# Enumerate the session inventory into RESUME_INVENTORY: one line per record of
# the form `SESSION_ID|provider|session-ts|branch|sandbox-stale`, optionally
# filtered by PROVIDER_FILTER. Uses the shared `enumerate_records` core from
# session_inventory.sh. Dry-run records are skipped (session_is_dry_run): their
# volume is destroyed at dry-run teardown, so they are not resumable -- but
# they stay visible to prune, which is what reclaims stale ones. `stale` is
# "fresh"/"stale"/"unknown" (registry-truth, D7  --  see session_stale). Zero
# docker calls: every field is on-disk.
RESUME_INVENTORY=()
build_inventory() {
  RESUME_INVENTORY=()
  local current_sha stale last_used host_sha branch_age line sid provider ts branch
  current_sha="$(project_current_sha)"
  while IFS= read -r line; do
    IFS='|' read -r sid provider ts branch <<< "$line"
    session_is_dry_run "$sid" && continue
    stale="$(session_stale "$SANDBOX_DIR/.compose/$sid.yml" "$current_sha")"
    last_used="$(session_log_read "$sid" last_stopped)"
    host_sha="$(record_label "$SANDBOX_DIR/.compose/$sid.yml" host-head-sha)"
    branch_age="$(project_branch_age "$host_sha")"
    RESUME_INVENTORY+=( "$sid|$provider|$ts|$branch|$stale|$last_used|$host_sha|$branch_age" )
  done < <(enumerate_records)
  # Newest first by session-ts.
  local sorted
  sorted="$(printf '%s\n' "${RESUME_INVENTORY[@]:-}" | sort -t'|' -k3 -r)"
  RESUME_INVENTORY=()
  while IFS= read -r line; do
    [[ -n "$line" ]] && RESUME_INVENTORY+=( "$line" )
  done <<< "$sorted"
  return 0
}

# _no_sessions  --  emit the empty-inventory guidance and return 1. Shared by
# the --list and --interactive branches (same message in both). Returns rather
# than exits, per the library rule in bash-coding-conventions.md 3.1: callers
# run under `set -euo pipefail`, so the status aborts them identically.
_no_sessions() {
  if [[ -n "$PROVIDER_FILTER" ]]; then
    echo "Error: no resumable sessions for provider '$PROVIDER_FILTER'." >&2
  else
    echo "No resumable sessions found (${SANDBOX_DIR:-<sandbox>}/.compose)." >&2
    echo "  Start a session first: make start" >&2
  fi
  return 1
}

# -------------------------
# Inventory display (shared by --list and --interactive)
# -------------------------
# Row shape (compact): sid | provider | branch | age | work | state.
#   BRANCH -- truncated to 11 chars (+ ...) so long branch names cannot blow
#             the row width; the full name is on the record.
#   AGE    -- the wall-clock age of the last lifecycle event: `up <t>`
#             (started t ago) or `down <t>` (stopped t ago), per the
#             operator's event-ordering model. start/stop events are
#             linearizable (log timestamps are lexicographically comparable),
#             so the last event is the relevant one. Docker is the
#             authoritative override on the verb (a crashed container's log
#             still says up); docker absent -> log-truth only; no events at
#             all -> `-`. By the shared AGE/STATE convention (see below) this
#             "how long ago" value sits under the AGE header.
#   WORK   -- host-side proxy for saved work: newest checkpoint for the session
#             id under session-diffs (autosave dir, else newest session export):
#             `<N>c` commits (the sandbox state; the export wraps them as
#             patches), `+u` when uncommitted.diff is non-empty; `--` when
#             the session never exported. Volume-truth (git inside the sandbox)
#             would cost one docker run per session  --  the cost class already
#             rejected for list-time staleness.
#   STATE  -- the branch's commit state: how many commits the current project
#             HEAD is ahead of the session's recorded host-head commit
#             ("N commit[s] ago"), "0 commits ago" when the recorded head
#             equals HEAD, "not in tree" when the recorded head is not a
#             resolvable commit in the current project, "-" when the record
#             has no host-head sha. By the shared AGE/STATE convention (AGE =
#             wall-clock, STATE = commit distance) this sits under STATE.
# Image-sig value is dropped from rows (diagnostic clutter); the actionable
# staleness marker [SANDBOX_STALE] is kept (exact words -- pinned by tests).
_RESUME_BRANCH_MAX=11

declare -A _WORK_MAP=()   # sid -> "<N>c[+u]" (filled by _resume_work_map)
declare -A _STATE_MAP=()  # sid -> running|stopped (filled by _resume_state_map)

_resume_truncate_branch() {
  local b="$1"
  if (( ${#b} > _RESUME_BRANCH_MAX )); then
    echo "${b:0:_RESUME_BRANCH_MAX}..."
  else
    echo "$b"
  fi
}

# _resume_work_map  --  fill _WORK_MAP[sid]="<N>c[+u]" / "--" from session-diffs.
_resume_work_map() {
  _WORK_MAP=()
  local changes="$SANDBOX_DIR/.workspace/session-diffs"
  local sid d dir patches unc best_mt mt
  for sid in $(printf '%s\n' "${RESUME_INVENTORY[@]}" | cut -d'|' -f1); do
    _WORK_MAP[$sid]="--"
    # Newest checkpoint for this sid: autosave dir first, else newest session
    # export entry (names end in -<sid>).
    dir=""
    if [[ -d "$changes/autosave/$sid" ]]; then
      dir="$changes/autosave/$sid"
    elif [[ -d "$changes/session" ]]; then
      best_mt=-1
      while IFS= read -r d; do
        [[ "${d##*/}" != *-"$sid" ]] && continue
        mt=$(stat -c %Y "$d" 2>/dev/null || echo 0)
        (( mt > best_mt )) && { best_mt=$mt; dir="$d"; }
      done < <(find "$changes/session" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)
    fi
    [[ -z "$dir" ]] && continue
    patches=$(find "$dir/patches" -maxdepth 1 -name '*.diff' 2>/dev/null | wc -l | tr -d ' ')
    unc=""
    [[ -s "$dir/uncommitted.diff" ]] && unc="+u"
    _WORK_MAP[$sid]="${patches}c${unc}"
  done
}

# _resume_state_map  --  fill _STATE_MAP[sid] from one docker ps -a call.
# Docker absent or errored -> empty map (rows render `-`).
_resume_state_map() {
  _STATE_MAP=()
  local sid st
  while read -r sid st; do
    [[ -z "$sid" ]] && continue
    case "$st" in
      running) _STATE_MAP[$sid]="running" ;;
      *)       _STATE_MAP[$sid]="stopped" ;;
    esac
  done < <(docker ps -a --filter label=agent-sandbox.session-id \
             --format '{{.Label "agent-sandbox.session-id"}} {{.State}}' 2>/dev/null || true)
}

# _resume_state_cell SID  --  the merged STATE cell: last event (start/stop)
# from the activity log, verb overridden by live docker state.
_resume_state_cell() {
  local sid="$1"
  local started stopped docker_verb t
  started=$(session_log_read "$sid" last_started)
  stopped=$(session_log_read "$sid" last_stopped)
  docker_verb="${_STATE_MAP[$sid]:-}"

  # Last log event wins (timestamps are lexicographically comparable).
  local last_verb last_t
  if [[ -n "$started" && ( -z "$stopped" || "$started" > "$stopped" ) ]]; then
    last_verb="started"; last_t="$started"
  elif [[ -n "$stopped" ]]; then
    last_verb="stopped"; last_t="$stopped"
  else
    echo "-"; return 0
  fi

  # Docker overrides the verb when it disagrees with the log (crash, docker
  # restart, manual stop). Time stays from the log when it matches the verb.
  if [[ -n "$docker_verb" && "$docker_verb" != "$last_verb" ]]; then
    echo "${docker_verb}"
    return 0
  fi
  t=$(relative_time_compact "$last_t")
  [[ "$t" == "---" ]] && { echo "$last_verb"; return 0; }
  echo "$last_verb $t"
}

# _resume_render_rows MODE  --  MODE=list renders the paged table to stderr;
# MODE=interactive fills the PICKER array (value|display) and _RESUME_HEADER.
_resume_render_rows() {
  local MODE="$1"
  _resume_work_map
  _resume_state_map
  # Column header (no leading offset: list mode adds its own 2-space margin,
  # the interactive picker aligns it under the numbered rows).
  _RESUME_HEADER=$(printf '%-7s %-9s %-14s %-14s %-6s %-13s' \
    "SESSION" "PROVIDER" "BRANCH" "AGE" "WORK" "STATE")

  local _line sid provider ts branch stale last_used host_sha branch_age
  local _br _state_val _wall_val work
  if [[ "$MODE" == "list" ]]; then echo "  $_RESUME_HEADER"; fi

  [[ "$MODE" == "interactive" ]] && PICKER=()
  # list mode caps the table at the page size (footer hints at the rest);
  # interactive mode hands the picker ALL entries  --  interactive_pick does
  # its own pagination.
  local -a _LINES
  if [[ "$MODE" == "list" ]]; then
    _LINES=( "${RESUME_INVENTORY[@]:0:$RESUME_LIST_PAGE_SIZE}" )
  else
    _LINES=( "${RESUME_INVENTORY[@]}" )
  fi
  for _line in "${_LINES[@]}"; do
    IFS='|' read -r sid provider ts branch stale last_used host_sha branch_age <<< "$_line"
    _br=$(_resume_truncate_branch "$branch")
    [[ "$stale" == "stale" ]] && _br+=" [SANDBOX_STALE]"
    # By language, STATE holds the branch's commit state (how many commits the
    # current HEAD is ahead of the recorded host-head) and AGE holds the last
    # lifecycle event's wall-clock age ("down 5m ago", "running"). Same
    # convention as the draft bundle table.
    _state_val="$branch_age"
    work="${_WORK_MAP[$sid]:---}"
    _wall_val=$(_resume_state_cell "$sid")
    local row
    row=$(printf '%-7s %-9s %-14s %-14s %-6s %-13s' \
      "$sid" "$provider" "$_br" "$_wall_val" "$work" "$_state_val")
    if [[ "$MODE" == "list" ]]; then
      echo "  $row"
    else
      PICKER+=( "$sid|$row" )
    fi
  done
}

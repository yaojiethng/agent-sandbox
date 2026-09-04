#!/usr/bin/env bash
# scripts/resume_agent.sh  --  Resume entrypoint: continues a previously-started
# agent session.
#
# Usage:
#   ./resume_agent.sh --name=<project_name> --project=<path> --sandbox=<path> \
#       [--env=<rel>] [--session-id=<id>] [--list] [--interactive] [--provider=<n>]
#
# This is the split-out resume command (F2 two-command design, design session
# `20260821-02`). `start_agent.sh` begins a NEW session; resume continues an
# existing one. The unified session inventory is the `.compose/<session-id>.yml`
# registry: every session (copy or mount delivery) writes a record there, and
# resume reads identity back from it.
#
# Host-side prelude (paths, image names, .env, branch, delivery, uid/gid) is
# shared with start_agent.sh via src/libs/session_env.sh.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO_ROOT/src/libs/common.sh"

# Max inventory entries shown per page by --list and --interactive. Canonical
# value lives in src/libs/common.sh (INTERACTIVE_MAX_ENTRIES)  --  shared with
# the draft picker so both consumers agree.
RESUME_LIST_PAGE_SIZE="$INTERACTIVE_MAX_ENTRIES"

# -------------------------
# Usage / help
# -------------------------
usage() {
  cat <<'EOF'
Usage: resume_agent.sh [--name=<n>] [--sandbox=<path>] [flags]

Resume a previously-started agent session. To begin a NEW session, use
`make start` / `agent-sandbox start` instead.

Preferred invocation through the sandbox Makefile:
  make resume SESSION_ID=<id>      --  resume a specific session (MOST COMMON)
  make resume LIST=1               --  list resumable sessions
  make resume INTERACTIVE=1        --  interactive picker + confirm

or directly:
  agent-sandbox resume --list
  agent-sandbox resume --session-id=<id> --name=<n> --sandbox=<path>

Flags:
  --list             list the `.compose/` session records (fast, no resume;
                     capped at 10 rows)
  --session-id=<id>  resume the session with this SESSION_ID (direct, silent; recommended)
  --interactive      interactive picker + confirm over the session inventory
  --provider=<n>     filter the session inventory by provider (with --list / --interactive)

--session-id is the preferred resume path: it selects exactly one session and
resumes silently. See `make resume LIST=1` to discover a session's id.
EOF
}

RESUME_LIST=false
SESSION_ID_ARG=""
INTERACTIVE_FLAG=false
PROVIDER_FILTER=""
PROJECT_NAME=""
PROJECT_DIR=""
SANDBOX_DIR=""

for ARG in "$@"; do
  case "$ARG" in
    --list)             RESUME_LIST=true ;;
    --session-id=*)     SESSION_ID_ARG="${ARG#--session-id=}" ;;
    --interactive)      INTERACTIVE_FLAG=true ;;
    --provider=*)       PROVIDER_FILTER="${ARG#--provider=}" ;;
    --name=*)           PROJECT_NAME="${ARG#--name=}" ;;
    --project=*)        PROJECT_DIR="${ARG#--project=}" ;;
    --sandbox=*)        SANDBOX_DIR="${ARG#--sandbox=}" ;;
    # Accepted for CLI parity; ignored -- resume reads ENV_FILE from the
    # session record, not from the flag.
    --env=*)            : ;;
    -h|--help)          usage; exit 0 ;;
    *)                  echo "Unknown flag: $ARG" >&2; usage >&2; exit 1 ;;
  esac
done

# Canonicalize the sandbox dir once so inventory/record lookup, identity, and
# any downstream label filter agree regardless of path spelling. Fails loudly
# when a non-empty value is unresolvable. Empty (bare/list/interactive resume
# argument parsing) is left for the downstream required-flag validation to
# report.
if [[ -n "$SANDBOX_DIR" ]]; then
  if ! canon_dir="$(sandbox_dir_canon "$SANDBOX_DIR")"; then exit 1; fi
  SANDBOX_DIR="$canon_dir"
fi

# -------------------------
# Inventory helpers (shared)
# -------------------------
# Recover a field from a .compose/<session-id>.yml registry record. Provider is
# read from the agent service image (`image: <provider>-agent-<lower-project>`);
# session metadata from the agent-sandbox labels; staleness from the record's
# host-head-sha vs the current project HEAD (worktree identity -- the exact
# comparison, ADR harness_versioning.md). Image staleness is retired: the
# recorded image digests are identity, not freshness.
source "$REPO_ROOT/src/libs/session_inventory.sh"

# Enumerate the session inventory into RESUME_INVENTORY: one line per record of
# the form `SESSION_ID|provider|session-ts|branch|sandbox-stale`, optionally
# filtered by PROVIDER_FILTER. Uses the shared `enumerate_records` core from
# session_inventory.sh. `stale` is "fresh"/"stale"/"unknown" (registry-truth,
# D7  --  see session_stale). Zero docker calls: every field is on-disk.
RESUME_INVENTORY=()
build_inventory() {
  RESUME_INVENTORY=()
  local current_sha stale last_used short_sha line sid provider ts branch
  current_sha="$(project_current_sha)"
  while IFS= read -r line; do
    IFS='|' read -r sid provider ts branch <<< "$line"
    stale="$(session_stale "$SANDBOX_DIR/.compose/$sid.yml" "$current_sha")"
    last_used="$(session_log_read "$sid" last_stopped)"
    short_sha="$(record_label "$SANDBOX_DIR/.compose/$sid.yml" host-head-sha)" && short_sha="${short_sha:0:7}"
    RESUME_INVENTORY+=( "$sid|$provider|$ts|$branch|$stale|$last_used|$short_sha" )
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

# _no_sessions  --  emit the empty-inventory guidance and exit 1. Shared by the
# --list and --interactive branches (same message in both).
_no_sessions() {
  if [[ -n "$PROVIDER_FILTER" ]]; then
    echo "Error: no resumable sessions for provider '$PROVIDER_FILTER'." >&2
  else
    echo "No resumable sessions found (${SANDBOX_DIR:-<sandbox>}/.compose)." >&2
    echo "  Start a session first: make start" >&2
  fi
  exit 1
}

# -------------------------
# Inventory display (shared by --list and --interactive)
# -------------------------
# Row shape (compact): sid | provider | started | branch | work | state | last used.
#   WORK   -- host-side proxy for saved work: newest checkpoint for the session
#             id under session-diffs (autosave dir, else newest session export):
#             `<N>c` commits (the sandbox state; the export wraps them as patches), `+u` when uncommitted.diff is non-empty; `--` when
#             the session never exported. Volume-truth (git inside the sandbox)
#             would cost one docker run per session  --  the cost class already
#             rejected for list-time staleness.
#   STATE  -- one merged cell: the LAST lifecycle event, per the operator's
#             event-ordering model. start/stop events are linearizable (log
#             timestamps are lexicographically comparable), so the last event
#             is the relevant one: `up <t>` (started t ago) or `down <t>`
#             (stopped t ago). Docker is the authoritative override on the
#             verb (a crashed container's log still says up); docker absent ->
#             log-truth only; no events at all -> `-`. Creation time
#             (session-ts) stays on the record; it is not the actionable
#             number.
#   BRANCH -- truncated to 16 chars (+ ...) so long branch names cannot blow
#             the row width; the full name is on the record.
# Image-sig value is dropped from rows (diagnostic clutter); the actionable
# staleness marker [SANDBOX_STALE] is kept (exact words --
# pinned by tests).
_RESUME_BRANCH_MAX=16
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

# _resume_state_cell SID CREATION_TS  --  the merged STATE cell: last event
# (start/stop) from the activity log, verb overridden by live docker state.
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
  _RESUME_HEADER=$(printf '  %-8s  %-9s  %-19s  %-7s  %-12s' \
    "SESSION" "PROVIDER" "BRANCH" "WORK" "STATE")

  local _line sid provider ts branch stale last_used short_sha
  local _br work state
  if [[ "$MODE" == "list" ]]; then echo "$_RESUME_HEADER"; fi

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
    IFS='|' read -r sid provider ts branch stale last_used short_sha <<< "$_line"
    _br=$(_resume_truncate_branch "$branch")
    [[ "$stale" == "stale" ]] && _br+=" [SANDBOX_STALE]"
    work="${_WORK_MAP[$sid]:---}"
    state=$(_resume_state_cell "$sid" "$ts")
    local row
    row=$(printf '%-8s  %-9s  %-19s  %-7s  %-12s' \
      "$sid" "$provider" "$_br" "$work" "$state")
    if [[ "$MODE" == "list" ]]; then
      echo "  $row"
    else
      PICKER+=( "$sid|$row" )
    fi
  done
}

# -------------------------
# Dispatch  --  command shape (ID 07)
# -------------------------
# 1) --list -> list .compose records (enriched, optional provider filter).
# 2) --interactive -> picker over the inventory, confirm, then resume.
# 3) --session-id=<id> -> resume path.
# 4) bare (no target flags) -> help hinting --list / --interactive.
if [[ "$RESUME_LIST" == true ]]; then
  build_inventory
  [[ "${#RESUME_INVENTORY[@]}" -gt 0 ]] || _no_sessions
  _resume_render_rows "list"
  if [[ "${#RESUME_INVENTORY[@]}" -gt "$RESUME_LIST_PAGE_SIZE" ]]; then
    echo "  (...$(( ${#RESUME_INVENTORY[@]} - RESUME_LIST_PAGE_SIZE )) more session(s)  --  use --interactive or --provider=<n> to narrow)" >&2
  fi
  exit 0
fi

if [[ "$INTERACTIVE_FLAG" == true ]]; then
  build_inventory
  [[ "${#RESUME_INVENTORY[@]}" -gt 0 ]] || _no_sessions

  # Picker rows share the --list row builder; interactive_pick renders the
  # column header under the title on every page. Explicit --interactive always
  # shows the picker + confirm, even for a sole record (decision I-1)  --  the
  # deliberately slow mode.
  source "$REPO_ROOT/scripts/workflows/interactive.sh"
  _resume_render_rows "interactive"
  chosen="$(interactive_pick "Resume which session?" PICKER "" "$RESUME_LIST_PAGE_SIZE" "$_RESUME_HEADER")" || exit 1

  # Confirm display re-reads the chosen entry's fields from the in-memory
  # inventory (build_inventory already parsed the record) rather than
  # re-parsing it from disk.
  disp_provider=""; disp_ts=""; disp_branch=""
  for _line in "${RESUME_INVENTORY[@]}"; do
    IFS='|' read -r sid provider ts branch stale last_used short_sha <<< "$_line"
    if [[ "$sid" == "$chosen" ]]; then
      disp_provider="$provider"; disp_ts="$ts"; disp_branch="$branch"; break
    fi
  done
  if ! interactive_confirm_or_abort "Resume session $chosen?" \
       "provider: $disp_provider" "created: $disp_ts" "branch: $disp_branch"; then
    exit 1
  fi

  SESSION_ID_ARG="$chosen"
fi

if [[ -n "$PROVIDER_FILTER" && -z "$SESSION_ID_ARG" && "$RESUME_LIST" != true && "$INTERACTIVE_FLAG" != true ]]; then
  echo "Error: --provider=<n> is an inventory filter; use with --list or --interactive." >&2
  usage >&2
  exit 1
fi

if [[ -z "$SESSION_ID_ARG" ]]; then
  echo "Error: no resume target given (need --session-id=<id>, --list, or --interactive)." >&2
  usage >&2
  exit 1
fi

if [[ -z "$PROJECT_NAME" || -z "$PROJECT_DIR" || -z "$SANDBOX_DIR" ]]; then
  echo "Error: --name, --project, and --sandbox are required (via agent-sandbox resume or make resume)." >&2
  usage >&2
  exit 1
fi

# -------------------------
# Identity recovery from the registry record
# -------------------------
# The .compose/<session-id>.yml record embeds the session identity (labels +
# image names) baked by compose_generate. Provider is recovered from the agent
# service image (`<provider>-agent-<project>`); SESSION_TS/HOST_HEAD_SHA from
# the session labels. This is the record-as-inventory (D7) + identity recovery
# required to resume (ID 06).
RECORD_FILE="$SANDBOX_DIR/.compose/$SESSION_ID_ARG.yml"
if [[ ! -f "$RECORD_FILE" ]]; then
  echo "Error: no session record found for session-id '$SESSION_ID_ARG'." >&2
  echo "  Expected: $RECORD_FILE" >&2
  echo "  Use --list to see resumable sessions." >&2
  exit 1
fi

# Agent image line -> provider; session labels -> SESSION_TS / HOST_HEAD_SHA.
local_provider="$(record_provider "$RECORD_FILE")"
if [[ -z "$local_provider" ]]; then
  echo "Error: could not recover provider from session record $RECORD_FILE" >&2
  exit 1
fi

# -------------------------
# Shared host-side prelude (phase 1 + 2)
# -------------------------
source "$REPO_ROOT/src/libs/session_env.sh"
session_env_common_init "$SANDBOX_DIR" "$PROJECT_NAME" "$PROJECT_DIR"

mkdir -p "$CHANGES_DIR" "$INPUT_DIR" "$OUTPUT_DIR"

# Session labels -> SESSION_TS / HOST_HEAD_SHA.
SESSION_TS="$(record_label "$RECORD_FILE" session-ts)"
export SESSION_TS
HOST_HEAD_SHA="$(record_label "$RECORD_FILE" host-head-sha)"
export HOST_HEAD_SHA

session_env_names "$PROJECT_NAME" "$local_provider" "$SANDBOX_DIR" "$SESSION_ID_ARG"

echo "Resuming session $SESSION_ID (provider: $PROVIDER_NAME, delivery: $SANDBOX_TYPE)"

# Resume never rebuilds missing images (preflight with build_missing=false) and
# never resets the volume  --  it continues the existing session.
source "$REPO_ROOT/scripts/build.sh"
preflight "$PROVIDER_NAME" "$PROJECT_NAME" "$REPO_ROOT" "false"

exec "$REPO_ROOT/scripts/run_agent.sh" standard \
  --name="$PROJECT_NAME" \
  --sandbox="$SANDBOX_DIR" \
  --env="$ENV_FILE" \
  --provider="$PROVIDER_NAME"
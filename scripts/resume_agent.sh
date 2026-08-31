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
    --env=*)            ENV_REL="${ARG#--env=}" ;;
    -h|--help)          usage; exit 0 ;;
    *)                  echo "Unknown flag: $ARG" >&2; usage >&2; exit 1 ;;
  esac
done

# -------------------------
# Inventory helpers (shared)
# -------------------------
# Recover a field from a .compose/<session-id>.yml registry record. Provider is
# read from the agent service image (`image: <provider>-agent-<lower-project>`);
# session metadata from the agent-sandbox labels; staleness from the record's
# host-head-sha vs the current project HEAD (sandbox) and its images vs the
# recomputed source sig (image). Shared with prune.sh. This lib also brings in
# the image-staleness criterion (it sources src/libs/container_sig.sh).
source "$REPO_ROOT/src/libs/session_inventory.sh"

# Enumerate the session inventory into RESUME_INVENTORY: one line per record of
# the form `SESSION_ID|provider|session-ts|branch|sandbox-stale|image-stale`,
# optionally filtered by PROVIDER_FILTER. Uses the shared `enumerate_records`
# core from session_inventory.sh and layers the two staleness columns on top.
# `stale` is "fresh"/"stale"/"unknown" (registry-truth, D7  --  see session_stale).
RESUME_INVENTORY=()
build_inventory() {
  RESUME_INVENTORY=()
  local current_sha stale image_stale last_used short_sha image_sig line sid provider ts branch
  current_sha="$(project_current_sha)"
  while IFS= read -r line; do
    IFS='|' read -r sid provider ts branch <<< "$line"
    stale="$(session_stale "$SANDBOX_DIR/.compose/$sid.yml" "$current_sha")"
    image_stale="$(record_image_stale "$SANDBOX_DIR/.compose/$sid.yml" "$REPO_ROOT")"
    last_used="$(session_log_read "$sid" last_stopped)"
    short_sha="$(record_label "$SANDBOX_DIR/.compose/$sid.yml" host-head-sha)" && short_sha="${short_sha:0:7}"
    image_sig="$(record_label "$SANDBOX_DIR/.compose/$sid.yml" image-sig)" && image_sig="${image_sig:0:7}"
    RESUME_INVENTORY+=( "$sid|$provider|$ts|$branch|$stale|$image_stale|$last_used|$short_sha|$image_sig" )
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
# Dispatch  --  command shape (ID 07)
# -------------------------
# 1) --list -> list .compose records (enriched, optional provider filter).
# 2) --interactive -> picker over the inventory, confirm, then resume.
# 3) --session-id=<id> -> resume path.
# 4) bare (no target flags) -> help hinting --list / --interactive.
if [[ "$RESUME_LIST" == true ]]; then
  build_inventory
  [[ "${#RESUME_INVENTORY[@]}" -gt 0 ]] || _no_sessions
  printf '  %-8s  %-24s  %-14s  %-24s  %s\n' "SESSION_ID" "PROVIDER (IMAGE-SIG)" "STARTED" "BRANCH" "LAST_USED"
  _line=; sid=; provider=; ts=; branch=; stale=; image_stale=; last_used=; short_sha=; image_sig=
  _prov=; _br=
  for _line in "${RESUME_INVENTORY[@]:0:$RESUME_LIST_PAGE_SIZE}"; do
    IFS='|' read -r sid provider ts branch stale image_stale last_used short_sha image_sig <<< "$_line"
    # PROVIDER cell: `pi (<image-sig:0:7>)` + co-located image warning; BRANCH
    # cell: `<branch> (<short sha>)` + co-located workspace/sandbox warning.
    _prov="$provider"
    [[ -n "$image_sig" ]] && _prov+=" ($image_sig)"
    [[ "$image_stale" == "stale" ]] && _prov+=" [IMAGE_STALE]"
    _br="$branch"
    [[ -n "$short_sha" ]] && _br+=" ($short_sha)"
    [[ "$stale" == "stale" ]] && _br+=" [SANDBOX_STALE]"
    printf '  %-8s  %-24s  %-14s  %-24s  %s\n' "$sid" "$_prov" "$(relative_time "$ts")" "$_br" "$(relative_time "$last_used")"
  done
  if [[ "${#RESUME_INVENTORY[@]}" -gt "$RESUME_LIST_PAGE_SIZE" ]]; then
    echo "  (...$(( ${#RESUME_INVENTORY[@]} - RESUME_LIST_PAGE_SIZE )) more session(s)  --  use --interactive or --provider=<n> to narrow)" >&2
  fi
  exit 0
fi

if [[ "$INTERACTIVE_FLAG" == true ]]; then
  build_inventory
  [[ "${#RESUME_INVENTORY[@]}" -gt 0 ]] || _no_sessions

  # Build the picker entries (value|display), then pick + confirm. Only the
  # stale states co-located with the column they describe ([SANDBOX_STALE] by
  # branch, [IMAGE_STALE] by provider); fresh/unknown carry no marker
  # marker (honest  --  unknown is not "ok"). Paged at RESUME_LIST_PAGE_SIZE.
  # Explicit --interactive always shows the picker + confirm, even for a sole
  # record (decision I-1)  --  the deliberately slow mode.
  PICKER=(); _line=; sid=; provider=; ts=; branch=; stale=; image_stale=; last_used=; short_sha=; image_sig=
  for _line in "${RESUME_INVENTORY[@]}"; do
    IFS='|' read -r sid provider ts branch stale image_stale last_used short_sha image_sig <<< "$_line"
    _std=""; [[ "$stale" == "stale" ]]       && _std=" [SANDBOX_STALE]"
    _img=""; [[ "$image_stale" == "stale" ]] && _img=" [IMAGE_STALE]"
    _prov="$provider"; [[ -n "$image_sig" ]] && _prov+=" ($image_sig)"
    _br="$branch"; [[ -n "$short_sha" ]] && _br+=" ($short_sha)"
    PICKER+=( "$sid|$sid  $_prov$_img  $(relative_time "$ts")  $_br$_std  $(relative_time "$last_used")" )
  done
  source "$REPO_ROOT/scripts/workflows/interactive.sh"
  chosen="$(interactive_pick "Resume which session?" PICKER "" "$RESUME_LIST_PAGE_SIZE")" || exit 1

  # Confirm display re-reads the chosen entry's fields from the in-memory
  # inventory (build_inventory already parsed the record) rather than
  # re-parsing it from disk.
  disp_provider=""; disp_ts=""; disp_branch=""
  for _line in "${RESUME_INVENTORY[@]}"; do
    IFS='|' read -r sid provider ts branch stale image_stale last_used short_sha image_sig <<< "$_line"
    if [[ "$sid" == "$chosen" ]]; then
      disp_provider="$provider"; disp_ts="$ts"; disp_branch="$branch"; break
    fi
  done
  if ! interactive_confirm_or_abort "Resume session $chosen?" \
       "provider: $disp_provider" "started: $disp_ts" "branch: $disp_branch"; then
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
export SANDBOX_ID; SANDBOX_ID=$(sandbox_id_derive "$SANDBOX_DIR" "$HOST_HEAD_SHA")

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
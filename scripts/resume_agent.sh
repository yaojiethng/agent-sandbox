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

# ENV_REL is parsed here and read by the sourced session_env_common_init to
# set ENV_FILE (same consumer as start_agent.sh); shellcheck cannot follow the
# sourced scope, so the variable appears unused in this file.
# shellcheck disable=SC2034
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
ENV_REL=""

source "$REPO_ROOT/src/libs/cli.sh"
_CLI_UNKNOWN_WORD="Unknown flag"
parse_args usage \
  --list:RESUME_LIST \
  --session-id=SESSION_ID_ARG \
  --interactive:INTERACTIVE_FLAG \
  --provider=PROVIDER_FILTER \
  --env=ENV_REL \
  --name=PROJECT_NAME \
  --project=PROJECT_DIR \
  --sandbox=SANDBOX_DIR \
  -- "$@"
[ $? -eq 2 ] && exit 0

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
source "$REPO_ROOT/src/libs/resume_list.sh"

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
  _label="Resume which session?"
  _label="$_label  --  current branch: $(project_current_branch)"
  chosen="$(interactive_pick "$_label" PICKER "" "$RESUME_LIST_PAGE_SIZE" "$_RESUME_HEADER")" || exit 1

  # Confirm display re-reads the chosen entry's fields from the in-memory
  # inventory (build_inventory already parsed the record) rather than
  # re-parsing it from disk.
  disp_provider=""; disp_ts=""; disp_branch=""
  for _line in "${RESUME_INVENTORY[@]}"; do
    IFS='|' read -r sid provider ts branch stale last_used host_sha branch_age <<< "$_line"
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

if [[ -z "$SANDBOX_DIR" ]]; then
  echo "Error: --sandbox is required (via agent-sandbox resume or make resume)." >&2
  echo "  --name and --project are resolved from .env in the sandbox dir when omitted." >&2
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

# Delivery is recovered from the record, never inherited from the environment
# (a silently-propagated default would let a mount session resume as copy).
# Ambient SANDBOX_TYPE is flagged if present so stale operator habits surface.
local_delivery="$(env_field "$RECORD_FILE" SANDBOX_TYPE)"
case "$local_delivery" in
  copy|mount) ;;
  *)
    echo "Error: session record $RECORD_FILE carries no delivery (SANDBOX_TYPE env literal)." >&2
    echo "  Records written before the delivery contract cannot be resumed safely; re-start instead." >&2
    exit 1
    ;;
esac
if [[ -n "${SANDBOX_TYPE:-}" ]]; then
  echo "Warning: ambient SANDBOX_TYPE=$SANDBOX_TYPE ignored  --  delivery recovered from the record: $local_delivery" >&2
fi
if [[ -z "$local_provider" ]]; then
  echo "Error: could not recover provider from session record $RECORD_FILE" >&2
  exit 1
fi

# Flatten is recovered from the record, never inherited from the environment
# (same rule as delivery: persist and re-consume). Records written before the
# flatten contract have no FLATTEN literal -- default to full (false).
local_flatten="$(env_field "$RECORD_FILE" FLATTEN)"
case "$local_flatten" in
  true|false|"") ;;
  *)
    echo "Error: session record $RECORD_FILE carries an invalid FLATTEN literal: $local_flatten" >&2
    exit 1
    ;;
esac
local_flatten="${local_flatten:-false}"

# -------------------------
# Shared host-side prelude (phase 1 + 2)
# -------------------------
source "$REPO_ROOT/src/libs/session_env.sh"
session_env_common_init "$PROJECT_NAME" "$PROJECT_DIR" "$SANDBOX_DIR"

mkdir -p "$CHANGES_DIR" "$INPUT_DIR" "$OUTPUT_DIR"

# Session labels -> SESSION_TS / HOST_HEAD_SHA.
SESSION_TS="$(record_label "$RECORD_FILE" session-ts)"
export SESSION_TS
HOST_HEAD_SHA="$(record_label "$RECORD_FILE" host-head-sha)"
export HOST_HEAD_SHA

session_env_names "$PROJECT_NAME" "$local_provider" "$SANDBOX_DIR" "$SESSION_ID_ARG"

echo "Resuming session $SESSION_ID (provider: $PROVIDER_NAME, delivery: $local_delivery, flatten: $local_flatten)"

# Mount delivery: cross-check the record's FLATTEN against the worktree's
# recorded mode. A mismatch means operator-level interference (the worktree
# recreated under a different mode). Warn; resume continues with the record's
# value and the recorded mode stays authoritative for the next start.
if [[ "$local_delivery" == "mount" && -f "$WORKTREE_DIR/.git/config" ]]; then
  wt_flatten="$(git -C "$WORKTREE_DIR" config agent-sandbox.flatten 2>/dev/null || echo "")"
  if [[ -n "$wt_flatten" && "$wt_flatten" != "$local_flatten" ]]; then
    echo "Warning: worktree at $WORKTREE_DIR records history mode '$wt_flatten' but the session record says '$local_flatten'. Resume continues with the record value." >&2
  fi
fi

# Resume never rebuilds missing images (preflight with build_missing=false) and
# never resets the volume  --  it continues the existing session.
source "$REPO_ROOT/scripts/build.sh"
preflight "$PROVIDER_NAME" "$PROJECT_NAME" "$REPO_ROOT" "false"

flatten_arg=()
[[ "$local_flatten" == "true" ]] && flatten_arg=(--flatten)

exec "$REPO_ROOT/scripts/run_agent.sh" standard \
  --name="$PROJECT_NAME" \
  --sandbox="$SANDBOX_DIR" \
  --env="$ENV_FILE" \
  --provider="$PROVIDER_NAME" \
  --delivery="$local_delivery" \
  "${flatten_arg[@]}"
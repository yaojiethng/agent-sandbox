#!/usr/bin/env bash
# scripts/resume_agent.sh — Resume entrypoint: continues a previously-started
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

# -------------------------
# Usage / help
# -------------------------
usage() {
  cat <<'EOF'
Usage: resume_agent.sh [--name=<n>] [--sandbox=<path>] [flags]

Resume a previously-started agent session. To begin a NEW session, use
`make start` / `agent-sandbox start` instead.

Preferred invocation through the sandbox Makefile:
  make resume SESSION_ID=<id>     — resume a specific session (MOST COMMON)
  make resume --list              — list resumable sessions
  make resume --interactive       — interactive picker + confirm

or directly:
  agent-sandbox resume --list
  agent-sandbox resume --session-id=<id> --name=<n> --sandbox=<path>

Flags:
  --list             list the `.compose/` session records (fast, no resume)
  --session-id=<id>  resume the session with this SESSION_ID (direct, silent; recommended)
  --interactive      NOT YET IMPLEMENTED — interactive picker + confirm (slow mode)
  --provider=<n>     NOT YET IMPLEMENTED — filter the session inventory by provider

--session-id is the preferred resume path: it selects exactly one session and
resumes silently. See `make resume --list` to discover a session's id.
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
# Dispatch — command shape (ID 07)
# -------------------------
# 1) --list → list .compose record filenames.
# 2) --interactive / --provider (without --session-id) → not yet implemented.
# 3) --session-id=<id> → resume path.
# 4) bare (no target flags) → help hinting --list / --interactive.
if [[ "$RESUME_LIST" == true ]]; then
  COMPOSE_DIR="${SANDBOX_DIR:-}/.compose"
  if [[ -z "$SANDBOX_DIR" || ! -d "$COMPOSE_DIR" ]]; then
    echo "Error: no session records found (${COMPOSE_DIR})." >&2
    echo "  Start a session first: make start" >&2
    exit 1
  fi
  echo "Resumable sessions (make resume SESSION_ID=<id>):"
  find "$COMPOSE_DIR" -maxdepth 1 -name '*.yml' -printf '%f\n' | sed 's/\.yml$//' | sort
  exit 0
fi

if [[ "$INTERACTIVE_FLAG" == true ]]; then
  echo "Error: --interactive (interactive resume picker) is not yet implemented." >&2
  echo "  Use --session-id=<id> to resume a specific session, or --list to discover ids." >&2
  exit 1
fi

if [[ -n "$PROVIDER_FILTER" ]]; then
  echo "Error: --provider=<n> (inventory filter) is not yet implemented." >&2
  echo "  Use --session-id=<id> to resume a specific session." >&2
  exit 1
fi

if [[ -z "$SESSION_ID_ARG" ]]; then
  echo "Error: no resume target given (need --session-id=<id> or --list)." >&2
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

# Agent image line → provider: `image: <provider>-agent-<lower-project>`.
local_provider="$(grep -m1 -E '^[[:space:]]+image:[[:space:]]*[^.]+-agent-[^-]+' "$RECORD_FILE" \
  | sed -E 's/.*image:[[:space:]]*([^[:space:]]+)-agent-.*/\1/')"
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

# Session labels → SESSION_TS / HOST_HEAD_SHA.
SESSION_TS="$(grep -m1 -E '[[:space:]]*agent-sandbox\.session-ts:' "$RECORD_FILE" \
  | sed -E 's/.*session-ts:[[:space:]]*//')"
export SESSION_TS
HOST_HEAD_SHA="$(grep -m1 -E '[[:space:]]*agent-sandbox\.host-head-sha:' "$RECORD_FILE" \
  | sed -E 's/.*host-head-sha:[[:space:]]*//')"
export HOST_HEAD_SHA
export SANDBOX_ID; SANDBOX_ID=$(echo "${SANDBOX_DIR}:${HOST_HEAD_SHA}" | sha256sum | cut -c1-8)

session_env_names "$PROJECT_NAME" "$local_provider" "$SANDBOX_DIR" "$SESSION_ID_ARG"

echo "Resuming session $SESSION_ID (provider: $PROVIDER_NAME, delivery: $SANDBOX_TYPE)"

# Resume never rebuilds missing images (preflight with build_missing=false) and
# never resets the volume — it continues the existing session.
source "$REPO_ROOT/scripts/build.sh"
preflight "$PROVIDER_NAME" "$PROJECT_NAME" "$REPO_ROOT" "false"

exec "$REPO_ROOT/scripts/run_agent.sh" standard \
  --name="$PROJECT_NAME" \
  --sandbox="$SANDBOX_DIR" \
  --env="$ENV_FILE" \
  --provider="$PROVIDER_NAME"
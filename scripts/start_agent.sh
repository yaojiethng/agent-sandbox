#!/usr/bin/env bash
# scripts/start_agent.sh
# Usage:
#   ./start_agent.sh <mode> --name=<project_name> --project=<path> [--sandbox=<path>] [--env=<rel>] [--provider=<n>]
#
# Modes:
#   standard   — normal execution, network access allowed
#   dry-run    — liveness check only, no agent started
#   serve      — provider serve mode, port exposed at SERVE_PORT
#
# Required flags:
#   --name=<project_name>   display name; used for log output
#   --project=<path>        absolute WSL/Linux path to the project directory on the host
#
# Optional flags:
#   --sandbox=<path>        absolute WSL/Linux path to the sandbox directory
#   --env=<rel>             path to .env file, relative to SANDBOX_DIR (default: .env)
#   --provider=<n>          provider name (default: opencode)
#
# Responsibility: host-side pre-flight only — path validation, .env loading,
# git validation, workspace setup, snapshot pipeline.
# Compose generation and container lifecycle are owned by scripts/run_agent.sh.
#
# This script is designed to be executed, not sourced. It exports variables
# for docker compose and run_agent.sh, then replaces itself via exec —
# exports do not leak back into the caller's shell.

set -euo pipefail

# -------------------------
# Paths
# -------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# REPO_ROOT assumes this script lives at scripts/
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# -------------------------
# Args
# -------------------------
MODE="${1:-}"
shift || true

if [[ -z "$MODE" ]]; then
  echo "Usage: $0 <mode:standard|dry-run|serve> --name=<n> --project=<path> [--sandbox=<path>] [--env=<rel>] [--provider=<n>]"
  exit 1
fi

# -------------------------
# Flag parsing
# -------------------------
PROJECT_NAME=""
PROJECT_DIR=""
SANDBOX_DIR_OVERRIDE=""
ENV_REL=".env"
PROVIDER_NAME=""
REFRESH=false
REBUILD=false
RESUME=false

for ARG in "$@"; do
  case "$ARG" in
    --name=*)     PROJECT_NAME="${ARG#--name=}" ;;
    --project=*)  PROJECT_DIR="${ARG#--project=}" ;;
    --sandbox=*)  SANDBOX_DIR_OVERRIDE="${ARG#--sandbox=}" ;;

    --env=*)      ENV_REL="${ARG#--env=}" ;;
    --provider=*) PROVIDER_NAME="${ARG#--provider=}" ;;
    --refresh)    REFRESH=true ;;
    --rebuild)    REBUILD=true ;;
    --resume)     RESUME=true ;;
    *)
      echo "Unknown flag: $ARG"
      exit 1
      ;;
  esac
done

if [[ -z "$PROJECT_NAME" || -z "$PROJECT_DIR" ]]; then
  echo "Error: --name and --project are required"
  exit 1
fi

# -------------------------
# SANDBOX_DIR derivation
# -------------------------
if [[ -n "$SANDBOX_DIR_OVERRIDE" ]]; then
  SANDBOX_DIR="$SANDBOX_DIR_OVERRIDE"
else
  SANDBOX_DIR="$(dirname "$PROJECT_DIR")/$(basename "$PROJECT_DIR")-sandbox"
fi

# -------------------------
# Path validation
# -------------------------
validate_wsl_path() {
  local PATH_VAR="$1"
  local PATH_VAL="$2"
  if [[ "$PATH_VAL" =~ ^[A-Za-z]:\\ ]]; then
    echo "Error: $PATH_VAR must be a WSL/Linux path, not a Windows path."
    echo "  Got:      $PATH_VAL"
    echo "  Convert:  wslpath '$PATH_VAL'"
    exit 1
  fi
}

validate_wsl_path "PROJECT_DIR" "$PROJECT_DIR"
validate_wsl_path "SANDBOX_DIR" "$SANDBOX_DIR"

if [[ ! -d "$PROJECT_DIR" ]]; then
  echo "Error: PROJECT_DIR does not exist: $PROJECT_DIR"
  exit 1
fi

# -------------------------
# .env loading
# -------------------------
ENV_FILE="$SANDBOX_DIR/$ENV_REL"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Error: .env not found: $ENV_FILE"
  echo "  SANDBOX_DIR has not been onboarded. Run:"
  echo "    agent-sandbox onboard --name=$PROJECT_NAME --project=$PROJECT_DIR --sandbox=$SANDBOX_DIR"
  exit 1
fi

# Source only simple KEY=VALUE lines; skip comments and blanks.
# Variables are exported for docker compose and run_agent.sh.
while IFS='=' read -r KEY VALUE || [[ -n "$KEY" ]]; do
  [[ "$KEY" =~ ^#.*$ || -z "$KEY" ]] && continue
  KEY="${KEY//[$'\r\n\t ']/}"
  VALUE="${VALUE//[$'\r\n']/}"
  VALUE="${VALUE#"${VALUE%%[! ]*}"}"
  VALUE="${VALUE%"${VALUE##*[! ]}"}"
  export "$KEY=$VALUE"
done < "$ENV_FILE"

# -------------------------
# Derive harness paths from SANDBOX_DIR
# -------------------------
# The .env file stores only the primitive (SANDBOX_DIR). Derived paths
# are produced here directly (no longer via dirs.sh/dirs_resolve).
# These values must match the x-workspace anchor in libs/docker-compose.yml.
export SNAPSHOT_DIR="${SANDBOX_DIR}/.snapshot"
export CHANGES_DIR="${SANDBOX_DIR}/.workspace/session-diffs"
export INPUT_DIR="${SANDBOX_DIR}/.workspace/input"
export OUTPUT_DIR="${SANDBOX_DIR}/.workspace/output"

# -------------------------
# Image name derivation
# -------------------------
source "$REPO_ROOT/src/build/image.sh"
source "$REPO_ROOT/scripts/build.sh"

export SANDBOX_IMAGE_NAME; SANDBOX_IMAGE_NAME="$(sandbox_image_name "$PROJECT_NAME")"
export AGENT_IMAGE_NAME;   AGENT_IMAGE_NAME="$(agent_image_name "$PROVIDER_NAME" "$PROJECT_NAME")"

# -------------------------
# Git validation
# -------------------------
if [[ ! -d "$PROJECT_DIR/.git" ]]; then
  echo "Error: PROJECT_DIR is not a git repository: $PROJECT_DIR"
  echo "  Initialise it first:"
  echo "    git -C '$PROJECT_DIR' init"
  echo "    git -C '$PROJECT_DIR' add -A"
  echo "    git -C '$PROJECT_DIR' commit -m 'initial'"
  exit 1
fi

if ! git -C "$PROJECT_DIR" rev-parse HEAD >/dev/null 2>&1; then
  echo "Error: git repository has no commits: $PROJECT_DIR"
  echo "  Create an initial commit first:"
  echo "    git -C '$PROJECT_DIR' add -A"
  echo "    git -C '$PROJECT_DIR' commit -m 'initial'"
  exit 1
fi

# -------------------------
# Session identity — persisted as .run-identity for volume-based resume
# -------------------------
# Session identity — volume discovery and resume
# -------------------------
# With multi-volume concurrency, each session gets its own named volume
# ({{RUN_ID}}-sandbox-data). Volume labels carry session identity.
# On first start, identity is computed fresh and a new volume is created
# by compose. On resume, identity is read from the existing volume's labels.
# .run-identity persists as a backward-compatibility cache.
#
# Volume discovery functions
# -------------------------
discover_volumes() {
  # Emit "session-ts|volume-name", sort descending by timestamp, extract names.
  # docker volume ls has no sort flag; sorting on the label value requires
  # emitting it into the format string alongside the name.
  docker volume ls \
    --filter "label=agent-sandbox.sandbox-dir=${SANDBOX_DIR}" \
    --filter "label=agent-sandbox.session-ts" \
    --format '{{index .Labels "agent-sandbox.session-ts"}}|{{.Name}}' 2>/dev/null \
    | sort -r \
    | cut -d'|' -f2 || true
}

volume_label() {
  local vol="$1" label="$2"
  docker volume inspect "$vol" \
    --format "{{index .Labels \"$label\"}}" 2>/dev/null || true
}

volume_is_stale() {
  local vol="$1"
  local vol_sha
  vol_sha=$(volume_label "$vol" "agent-sandbox.host-head-sha")
  local current_sha
  current_sha=$(git -C "$PROJECT_DIR" rev-parse HEAD)
  [[ "$vol_sha" != "$current_sha" ]]
}

volume_in_use() {
  local vol="$1"
  local containers
  containers=$(docker ps --filter "volume=$vol" --format '{{.ID}}' 2>/dev/null || true)
  [[ -n "$containers" ]]
}

RUN_IDENTITY="$SANDBOX_DIR/.run-identity"

_new_session_identity() {
  # Compute fresh identity and write .run-identity.
  # Called for both default new-session and --refresh paths.
  RESUME_SESSION=false
  rm -f "$RUN_IDENTITY"

  export SESSION_TS; SESSION_TS=$(date -u +%Y%m%d-%H%M%S)
  export HOST_HEAD_SHA; HOST_HEAD_SHA=$(git -C "$PROJECT_DIR" rev-parse HEAD)
  export SANDBOX_ID; SANDBOX_ID=$(echo "${SANDBOX_DIR}:${HOST_HEAD_SHA}" | sha256sum | cut -c1-8)
  export RUN_ID; RUN_ID=$(echo "${SESSION_TS}:${SANDBOX_ID}" | sha256sum | cut -c1-6)

  {
    echo "SESSION_TS=${SESSION_TS}"
    echo "RUN_ID=${RUN_ID}"
    echo "HOST_HEAD_SHA=${HOST_HEAD_SHA}"
    echo "SANDBOX_ID=${SANDBOX_ID}"
  } > "$RUN_IDENTITY"
}

_resume_from_volume() {
  # Read identity from a volume (passed as $1) and set up resume state.
  # Exits with error if the volume lacks identity labels.
  local vol="$1"

  # Volume locking check
  if volume_in_use "$vol"; then
    echo "Error: volume $vol is in use by another session."
    echo "  Stop the active session first: make stop"
    exit 1
  fi

  export SESSION_TS; SESSION_TS=$(volume_label "$vol" "agent-sandbox.session-ts")
  export RUN_ID; RUN_ID=$(volume_label "$vol" "agent-sandbox.run-id")
  export HOST_HEAD_SHA; HOST_HEAD_SHA=$(volume_label "$vol" "agent-sandbox.host-head-sha")

  if [[ -z "$SESSION_TS" || -z "$RUN_ID" ]]; then
    echo "Error: volume $vol has no session identity labels."
    echo "  The volume may be from an older harness version."
    echo "  Remove it and start fresh: make start"
    exit 1
  fi

  export SANDBOX_ID; SANDBOX_ID=$(echo "${SANDBOX_DIR}:${HOST_HEAD_SHA}" | sha256sum | cut -c1-8)

  {
    echo "SESSION_TS=${SESSION_TS}"
    echo "RUN_ID=${RUN_ID}"
    echo "HOST_HEAD_SHA=${HOST_HEAD_SHA}"
    echo "SANDBOX_ID=${SANDBOX_ID}"
  } > "$RUN_IDENTITY"

  RESUME_SESSION=true
  echo "Resuming session — volume: $vol"
}

# auto_resume_or_new — default path when neither --refresh nor --resume is set.
# 0 volumes          → new session
# 1 non-stale        → resume silently
# 0 non-stale, 1 stale → resume stale + warn
# 2+ total           → interactive picker
_auto_resume_or_new() {
  VOLUMES=()
  while IFS= read -r vol; do
    [[ -n "$vol" ]] && VOLUMES+=("$vol")
  done < <(discover_volumes)

  VOLUME_COUNT="${#VOLUMES[@]}"

  if [[ "$VOLUME_COUNT" -eq 0 ]]; then
    _new_session_identity
    return
  fi

  # Build lists of non-stale and stale volumes
  local NON_STALE=() STALE=()
  for vol in "${VOLUMES[@]}"; do
    if volume_is_stale "$vol"; then
      STALE+=("$vol")
    else
      NON_STALE+=("$vol")
    fi
  done

  # Case: 1 non-stale, 0 stale — resume it silently
  if [[ "${#NON_STALE[@]}" -eq 1 ]] && [[ "${#STALE[@]}" -eq 0 ]]; then
    _resume_from_volume "${NON_STALE[0]}"
    return
  fi

  # Case: 0 non-stale, 1 stale — resume with a warning
  if [[ "${#NON_STALE[@]}" -eq 0 ]] && [[ "${#STALE[@]}" -eq 1 ]]; then
    echo "Warning: project HEAD has moved since this session started."
    echo "  The sandbox repo may be out of date."
    echo "  Use --resume to select a different session if needed."
    _resume_from_volume "${STALE[0]}"
    return
  fi

  # Case: multiple volumes, or mixed — interactive picker
  _show_volume_picker
}

# _show_volume_picker — interactive volume selection (shared by --resume and auto path)
_show_volume_picker() {
  echo ""
  echo "Sessions found for this sandbox directory:"
  echo ""

  local i=1
  for vol in "${VOLUMES[@]}"; do
    local ts rid br sha stale_str
    ts=$(volume_label "$vol" "agent-sandbox.session-ts")
    rid=$(volume_label "$vol" "agent-sandbox.run-id")
    br=$(volume_label "$vol" "agent-sandbox.host-branch")
    sha=$(volume_label "$vol" "agent-sandbox.host-head-sha")
    stale_str=""
    volume_is_stale "$vol" && stale_str=" [STALE]"
    printf "  %d) %s  RUN_ID: %s  branch: %s (%.7s)%s\n" \
      "$i" "$ts" "$rid" "$br" "$sha" "$stale_str"
    (( i++ )) || true
  done
  local NEW_OPTION="$i"
  printf "  %d) [start new session]\n" "$NEW_OPTION"
  echo ""

  local SELECTION=""
  while [[ -z "$SELECTION" ]]; do
    printf "Select (1-%d): " "$NEW_OPTION"
    read -r SELECTION
    if [[ ! "$SELECTION" =~ ^[0-9]+$ ]] || \
       [[ "$SELECTION" -lt 1 ]] || \
       [[ "$SELECTION" -gt "$NEW_OPTION" ]]; then
      echo "  Invalid selection. Enter 1-$NEW_OPTION."
      SELECTION=""
    fi
  done

  if [[ "$SELECTION" -eq "$NEW_OPTION" ]]; then
    echo "Starting new session"
    _new_session_identity
  else
    _resume_from_volume "${VOLUMES[$((SELECTION - 1))]}"
  fi
}

if [[ "${REFRESH:-false}" == "true" ]]; then
  echo "Refresh requested — starting new session"
  _new_session_identity
elif [[ "${RESUME:-false}" == "true" ]]; then
  # --resume: always show the interactive picker
  VOLUMES=()
  while IFS= read -r vol; do
    [[ -n "$vol" ]] && VOLUMES+=("$vol")
  done < <(discover_volumes)

  VOLUME_COUNT="${#VOLUMES[@]}"

  if [[ "$VOLUME_COUNT" -eq 0 ]]; then
    echo "No existing sessions — starting new session"
    _new_session_identity
  else
    _show_volume_picker
  fi
else
  # Default: auto-resume non-stale, or picker, or new session
  _auto_resume_or_new
fi

# -------------------------
# SANITIZED_HOST_BRANCH and CONTAINER_NAME derivation
# -------------------------
# SANITIZED_HOST_BRANCH is the host branch name captured at session start,
# sanitised for use in directory names and Docker labels. Slashes are
# replaced with dashes; all non-alphanumeric characters (except dash,
# underscore, dot) are replaced with dashes.
BRANCH_NAME=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD)
# Handle detached HEAD: use short SHA instead of literal "HEAD"
if [[ "$BRANCH_NAME" == "HEAD" ]]; then
  BRANCH_NAME=$(git -C "$PROJECT_DIR" rev-parse --short HEAD)
fi
export SANITIZED_HOST_BRANCH=$(echo "$BRANCH_NAME" | sed 's/[^a-zA-Z0-9._-]/-/g')
export SANDBOX_CONTAINER_NAME="sandbox-${PROJECT_NAME}-${RUN_ID}"
export AGENT_CONTAINER_NAME="${PROVIDER_NAME}-${PROJECT_NAME}-${RUN_ID}"
unset BRANCH_NAME
echo "Host branch: $SANITIZED_HOST_BRANCH"
echo "Host HEAD SHA: $HOST_HEAD_SHA"
echo "Sandbox ID: $SANDBOX_ID"
echo "Run ID: $RUN_ID"
echo "Sandbox container name: $SANDBOX_CONTAINER_NAME"
echo "Agent container name: $AGENT_CONTAINER_NAME"

# -------------------------
# Workspace directory setup and snapshot pipeline
# -------------------------
if [[ "$RESUME_SESSION" == true ]]; then
  # Resume path: workspace dirs should already exist (bind mounts),
  # but ensure they do in case the user cleaned them manually.
  mkdir -p "$CHANGES_DIR" "$INPUT_DIR" "$OUTPUT_DIR"
  echo "Resuming session — snapshot pipeline skipped (volume has existing git state)"
else
  # Clean the snapshot directory before building a fresh snapshot.
  # Without this, files from a previous run that are no longer in PROJECT_DIR
  # (deleted, moved, or newly gitignored) would persist in the snapshot and
  # propagate into the sandbox.
  rm -rf "$SNAPSHOT_DIR"
  mkdir -p "$SNAPSHOT_DIR"
  mkdir -p "$CHANGES_DIR" "$INPUT_DIR" "$OUTPUT_DIR"

  source "$REPO_ROOT/src/capability/snapshot.sh"

  echo "Building snapshot..."
  snapshot_copy_worktree "$PROJECT_DIR" "$SNAPSHOT_DIR"
  snapshot_archive_head "$PROJECT_DIR" "$SNAPSHOT_DIR"

  snapshot_validate "$SNAPSHOT_DIR"
  echo "Snapshot ready."
fi

# -------------------------
# Rebuild (if requested)
# -------------------------
# --refresh: rebuild sandbox and provider (base skipped if exists).
# --rebuild: rebuild everything from scratch including base (supersedes --refresh).
# Export host UID/GID for build pipeline
HOST_UID="$(id -u)"
HOST_GID="$(id -g)"

if [[ "$REBUILD" == true ]]; then
  echo "Rebuilding everything from scratch: $PROVIDER_NAME..."
  build_sandbox "$PROJECT_NAME" "$REPO_ROOT" "$HOST_UID" "$HOST_GID"
  build_agent "$PROVIDER_NAME" "$PROJECT_NAME" "$REPO_ROOT" "--no-cache" "$HOST_UID" "$HOST_GID"
elif [[ "$REFRESH" == true ]]; then
  echo "Refreshing sandbox and provider: $PROVIDER_NAME..."
  build_sandbox "$PROJECT_NAME" "$REPO_ROOT" "$HOST_UID" "$HOST_GID"
  build_agent "$PROVIDER_NAME" "$PROJECT_NAME" "$REPO_ROOT" "" "$HOST_UID" "$HOST_GID"
fi

# -------------------------
# Preflight
# -------------------------
preflight "$PROVIDER_NAME" "$PROJECT_NAME" "$REPO_ROOT" "$SANDBOX_DIR"

# -------------------------
# Dispatch to run_agent.sh
# -------------------------
# Compose generation and container lifecycle are owned by scripts/run_agent.sh.
# All .env variables and derived image names are already exported above.
# RESET_VOLUME is forwarded when --refresh or --rebuild is set, signalling
# run_agent.sh to destroy the existing volume before starting new containers.
RESET_VOLUME_FLAG=""
if [[ "${REFRESH:-false}" == "true" || "${REBUILD:-false}" == "true" ]]; then
  RESET_VOLUME_FLAG="--reset-volume"
elif [[ "$RESUME_SESSION" != true ]]; then
  # Default new-session path also resets the volume (fresh start).
  RESET_VOLUME_FLAG="--reset-volume"
fi

exec "$SCRIPT_DIR/run_agent.sh" "$MODE" \
  --name="$PROJECT_NAME" \
  --sandbox="$SANDBOX_DIR" \
  --env="$ENV_FILE" \
  --provider="$PROVIDER_NAME" \
  $RESET_VOLUME_FLAG

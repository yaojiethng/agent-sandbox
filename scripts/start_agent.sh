#!/usr/bin/env bash
# scripts/start_agent.sh
# Usage:
#   ./start_agent.sh <mode> --name=<project_name> --project=<path> [--sandbox=<path>] [--brief=<rel>] [--env=<rel>] [--provider=<n>]
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
#   --brief=<rel>           path to agent brief, relative to SANDBOX_DIR;
#                           copied into SANDBOX_DIR/.workspace/input/brief.md
#   --env=<rel>             path to .env file, relative to SANDBOX_DIR (default: .env)
#   --provider=<n>          provider name (default: opencode)
#
# Responsibility: host-side pre-flight only — path validation, .env loading,
# git validation, workspace setup, snapshot pipeline, brief resolution.
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
  echo "Usage: $0 <mode:standard|dry-run|serve> --name=<n> --project=<path> [--sandbox=<path>] [--brief=<rel>] [--env=<rel>] [--provider=<n>]"
  exit 1
fi

# -------------------------
# Flag parsing
# -------------------------
PROJECT_NAME=""
PROJECT_DIR=""
SANDBOX_DIR_OVERRIDE=""
AGENT_BRIEF=""
ENV_REL=".env"
PROVIDER_NAME="opencode"

for ARG in "$@"; do
  case "$ARG" in
    --name=*)     PROJECT_NAME="${ARG#--name=}" ;;
    --project=*)  PROJECT_DIR="${ARG#--project=}" ;;
    --sandbox=*)  SANDBOX_DIR_OVERRIDE="${ARG#--sandbox=}" ;;
    --brief=*)    AGENT_BRIEF="${ARG#--brief=}" ;;
    --env=*)      ENV_REL="${ARG#--env=}" ;;
    --provider=*) PROVIDER_NAME="${ARG#--provider=}" ;;
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
# Required .env var validation
# -------------------------
REQUIRED_ENV_VARS=(
  SNAPSHOT_DIR
  CHANGES_DIR
  INPUT_DIR
  OUTPUT_DIR
)

for VAR in "${REQUIRED_ENV_VARS[@]}"; do
  if [[ -z "${!VAR:-}" ]]; then
    echo "Error: required variable '$VAR' is missing from $ENV_FILE"
    echo "  Re-run onboarding to regenerate .env:"
    echo "    agent-sandbox onboard --name=$PROJECT_NAME --project=$PROJECT_DIR --sandbox=$SANDBOX_DIR"
    exit 1
  fi
done

# -------------------------
# Image name derivation
# -------------------------
source "$REPO_ROOT/libs/containers.sh"

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
# Worktree ID
# -------------------------
# Derive a stable worktree identifier from the PROJECT_DIR path.
# This is used to namespace checkpoint tags per-worktree.
_WORKTREE_ID=$(echo "$PROJECT_DIR" | sha1sum | head -c8)
export WORKTREE_ID="$_WORKTREE_ID"
unset _WORKTREE_ID

# -------------------------
# Checkpoint tag 
# -------------------------
CHECKPOINT_TS=$(date -u +%Y%m%d-%H%M%S)
CHECKPOINT_TAG="agent-checkpoint/${WORKTREE_ID}/${CHECKPOINT_TS}"

git -C "$PROJECT_DIR" tag "$CHECKPOINT_TAG"
echo "Checkpoint tag created: $CHECKPOINT_TAG"

# Prune old checkpoint tags — keep the 5 most recent for this worktree.
# Scope pruning to this worktree's namespace only.
mapfile -t _ALL_CHECKPOINT_TAGS < <(git -C "$PROJECT_DIR" tag --list "agent-checkpoint/${WORKTREE_ID}/*" | sort)
_KEEP=5
if [[ "${#_ALL_CHECKPOINT_TAGS[@]}" -gt "$_KEEP" ]]; then
  _DELETE_COUNT=$(( ${#_ALL_CHECKPOINT_TAGS[@]} - _KEEP ))
  for (( _i=0; _i<_DELETE_COUNT; _i++ )); do
    git -C "$PROJECT_DIR" tag -d "${_ALL_CHECKPOINT_TAGS[$_i]}" >/dev/null
    echo "Pruned checkpoint tag: ${_ALL_CHECKPOINT_TAGS[$_i]}"
  done
fi
unset _ALL_CHECKPOINT_TAGS _KEEP _DELETE_COUNT _i

# Write latest ref for operator recovery and apply workflow.
mkdir -p "$SANDBOX_DIR/.workspace"
echo "$CHECKPOINT_TAG" > "$SANDBOX_DIR/.workspace/checkpoint-latest.ref"

# -------------------------
# REPO_COMMIT capture
# -------------------------
# Capture the current HEAD commit for image labeling (future use).
export REPO_COMMIT=$(git -C "$PROJECT_DIR" rev-parse HEAD)

# -------------------------
# SESSION_NAME derivation 
# -------------------------
_BRANCH=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD)
# Handle detached HEAD: use short SHA instead of literal "HEAD"
if [[ "$_BRANCH" == "HEAD" ]]; then
  _BRANCH=$(git -C "$PROJECT_DIR" rev-parse --short HEAD)
fi
_SANITIZED=$(echo "$_BRANCH" | tr '/' '-')
export SESSION_NAME="${_SANITIZED}-${CHECKPOINT_TS}"
unset _BRANCH _SANITIZED
echo "Session name: $SESSION_NAME"

# -------------------------
# Workspace directory setup
# -------------------------
# Clean the snapshot directory before building a fresh snapshot.
# Without this, files from a previous run that are no longer in PROJECT_DIR
# (deleted, moved, or newly gitignored) would persist in the snapshot and
# propagate into the sandbox.
rm -rf "$SNAPSHOT_DIR"
mkdir -p "$SNAPSHOT_DIR"
mkdir -p "$CHANGES_DIR"
mkdir -p "$INPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# -------------------------
# Snapshot pipeline (host side)
# -------------------------
source "$REPO_ROOT/libs/snapshot.sh"

echo "Building snapshot..."
snapshot_copy_worktree "$PROJECT_DIR" "$SNAPSHOT_DIR"
snapshot_archive_head "$PROJECT_DIR" "$SNAPSHOT_DIR"

snapshot_validate "$SNAPSHOT_DIR"
echo "Snapshot ready."

# -------------------------
# Brief resolution
# -------------------------
if [[ -n "$AGENT_BRIEF" ]]; then
  BRIEF_PATH="$(cd "$SANDBOX_DIR" && realpath "$AGENT_BRIEF")"

  validate_wsl_path "AGENT_BRIEF" "$BRIEF_PATH"

  if [[ ! -f "$BRIEF_PATH" ]]; then
    echo "Error: AGENT_BRIEF file not found: $BRIEF_PATH"
    exit 1
  fi

  cp "$BRIEF_PATH" "$INPUT_DIR/brief.md"
fi

# -------------------------
# Stop any running session containers
# -------------------------
# Checks for containers with the project's compose label before calling stop.sh.
# Avoids noise from stop.sh's "no containers found" message on a clean start.
# stop.sh uses Docker Compose project labels — catches all containers for this
# project regardless of which provider ran previously.
_COMPOSE_PROJECT="$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]')"
_COMPOSE_PROJECT="${_COMPOSE_PROJECT//[^a-z0-9-]/-}"
if [[ -n "$(docker ps -aq --filter "label=com.docker.compose.project=${_COMPOSE_PROJECT}")" ]]; then
  echo "Stopping previous session ($PROJECT_NAME)..."
  "$SCRIPT_DIR/stop.sh" --name="$PROJECT_NAME" --sandbox="$SANDBOX_DIR"
fi
unset _COMPOSE_PROJECT

# -------------------------
# Preflight
# -------------------------
preflight "$PROVIDER_NAME" "$PROJECT_NAME" "$REPO_ROOT" "$SANDBOX_DIR"

# -------------------------
# Dispatch to run_agent.sh
# -------------------------
# Compose generation and container lifecycle are owned by scripts/run_agent.sh.
# All .env variables and derived image names are already exported above.
exec "$SCRIPT_DIR/run_agent.sh" "$MODE" \
  --name="$PROJECT_NAME" \
  --sandbox="$SANDBOX_DIR" \
  --env="$ENV_FILE" \
  --provider="$PROVIDER_NAME"

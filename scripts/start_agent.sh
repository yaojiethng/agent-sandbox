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

for ARG in "$@"; do
  case "$ARG" in
    --name=*)     PROJECT_NAME="${ARG#--name=}" ;;
    --project=*)  PROJECT_DIR="${ARG#--project=}" ;;
    --sandbox=*)  SANDBOX_DIR_OVERRIDE="${ARG#--sandbox=}" ;;

    --env=*)      ENV_REL="${ARG#--env=}" ;;
    --provider=*) PROVIDER_NAME="${ARG#--provider=}" ;;
    --refresh)    REFRESH=true ;;
    --rebuild)    REBUILD=true ;;
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
# On first start, identity values are computed fresh and written to
# $SANDBOX_DIR/.run-identity. On resume, values are read from this file
# so that the host-side env vars (SESSION_TS, RUN_ID, HOST_HEAD_SHA,
# SANDBOX_ID) always match what the volume's SESSION_STATE contains.
# This prevents divergence between diff_export (reads env vars) and
# package_branch (reads SESSION_STATE).
RUN_IDENTITY="$SANDBOX_DIR/.run-identity"

if [[ -f "$RUN_IDENTITY" && "${REFRESH:-false}" != "true" ]]; then
  # Resume path: read identity from file, re-export for compose
  echo "Resuming session — reading identity from $RUN_IDENTITY"
  while IFS='=' read -r KEY VALUE || [[ -n "$KEY" ]]; do
    [[ "$KEY" =~ ^#.*$ || -z "$KEY" ]] && continue
    KEY="${KEY//[$'\r\n\t ']/}"
    VALUE="${VALUE//[$'\r\n']/}"
    export "$KEY=$VALUE"
  done < "$RUN_IDENTITY"
  RESUME_SESSION=true
else
  RESUME_SESSION=false
  if [[ "${REFRESH:-false}" == "true" ]]; then
    echo "Refresh requested — clearing session identity and volume"
    rm -f "$RUN_IDENTITY"
  fi

  # Fresh init: compute identity values
  # SESSION_TS is the one source of truth for the session timestamp.
  # All derived names (container names, artefact directories) reference
  # this variable — no downstream date calls.
  export SESSION_TS; SESSION_TS=$(date -u +%Y%m%d-%H%M%S)

  # SANDBOX_ID — 8-char hex hash identifying a sandbox instance at a
  # specific host commit. Composed of SANDBOX_DIR (path identity) and
  # HOST_HEAD_SHA (codebase version). Two sandboxes at different directories
  # or different host commits produce different SANDBOX_IDs.
  export HOST_HEAD_SHA; HOST_HEAD_SHA=$(git -C "$PROJECT_DIR" rev-parse HEAD)
  export SANDBOX_ID; SANDBOX_ID=$(echo "${SANDBOX_DIR}:${HOST_HEAD_SHA}" | sha256sum | cut -c1-8)

  # RUN_ID — 6-char hex hash identifying a single session run. Composed of
  # SESSION_TS (temporal factor) and SANDBOX_ID (instance factor). Replaces
  # SESSION_TS in container names and artefact paths while SESSION_TS is
  # preserved for human readability.
  export RUN_ID; RUN_ID=$(echo "${SESSION_TS}:${SANDBOX_ID}" | sha256sum | cut -c1-6)

  # Write .run-identity for future resumes
  {
    echo "SESSION_TS=${SESSION_TS}"
    echo "RUN_ID=${RUN_ID}"
    echo "HOST_HEAD_SHA=${HOST_HEAD_SHA}"
    echo "SANDBOX_ID=${SANDBOX_ID}"
  } > "$RUN_IDENTITY"
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
[[ "${REFRESH:-false}" == "true" || "${REBUILD:-false}" == "true" ]] && RESET_VOLUME_FLAG="--reset-volume"

exec "$SCRIPT_DIR/run_agent.sh" "$MODE" \
  --name="$PROJECT_NAME" \
  --sandbox="$SANDBOX_DIR" \
  --env="$ENV_FILE" \
  --provider="$PROVIDER_NAME" \
  $RESET_VOLUME_FLAG

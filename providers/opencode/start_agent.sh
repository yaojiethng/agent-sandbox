#!/usr/bin/env bash
# start_agent.sh
# Usage:
#   ./start_agent.sh <mode> --name=<project_name> --project=<path> [--sandbox=<path>] [--brief=<rel>] [--env=<rel>] [--serve]
#
# Modes:
#   standard   — normal execution, network access allowed
#   dry-run    — liveness check only, no agent started
#
# Required flags:
#   --name=<project_name>   display name; used for image naming
#   --project=<path>        absolute WSL/Linux path to the project directory on the host
#
# Optional flags:
#   --sandbox=<path>        absolute WSL/Linux path to the sandbox directory
#                           defaults to <parent-of-PROJECT_DIR>/<project-dir-name>-sandbox
#   --brief=<rel>           path to agent brief, relative to SANDBOX_DIR
#   --env=<rel>             path to .env file, relative to SANDBOX_DIR
#                           supported env vars: SERVE_PORT (default: 46553)
#                                               OPENCODE_SERVER_PASSWORD
#   --serve                 start OpenCode in serve mode
#
# Note: PROJECT_DIR must be a git repository with at least one commit.
#       The Docker image must already exist — run agent-sandbox build first.

set -euo pipefail

# -------------------------
# Directory name definitions
# Single source of truth — passed to container as env vars
# -------------------------
AGENT_INPUT_DIR_NAME=".agent-input"
AGENT_WORKSPACE_DIR_NAME=".workspace"

# -------------------------
# Paths
# -------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# REPO_ROOT assumes this script lives at providers/opencode/
# If the script moves, update the relative path below accordingly.
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# -------------------------
# Args
# -------------------------
MODE="${1:-}"
shift || true

if [[ -z "$MODE" ]]; then
  echo "Usage: $0 <mode:standard|dry-run> --name=<n> --project=<path> [--sandbox=<path>] [--brief=<rel>] [--env=<rel>] [--serve]"
  exit 1
fi

# -------------------------
# Flag parsing (order agnostic)
# -------------------------
PROJECT_NAME=""
PROJECT_DIR=""
SANDBOX_DIR_OVERRIDE=""
AGENT_BRIEF=""
ENV_REL=""
SERVE=false

for ARG in "$@"; do
  case "$ARG" in
    --name=*)    PROJECT_NAME="${ARG#--name=}" ;;
    --project=*) PROJECT_DIR="${ARG#--project=}" ;;
    --sandbox=*) SANDBOX_DIR_OVERRIDE="${ARG#--sandbox=}" ;;
    --brief=*)   AGENT_BRIEF="${ARG#--brief=}" ;;
    --env=*)     ENV_REL="${ARG#--env=}" ;;
    --serve)     SERVE=true ;;
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
# Env loading
# -------------------------
if [[ -n "$ENV_REL" ]]; then
  ENV_FILE="$SANDBOX_DIR/$ENV_REL"
  if [[ ! -f "$ENV_FILE" ]]; then
    echo "Error: env file not found: $ENV_FILE"
    exit 1
  fi
  # Source only simple KEY=VALUE lines, skip comments and blanks
  while IFS='=' read -r KEY VALUE || [[ -n "$KEY" ]]; do
    [[ "$KEY" =~ ^#.*$ || -z "$KEY" ]] && continue
    KEY="${KEY//[$'\r\n\t ']/}"
    VALUE="${VALUE//[$'\r\n']/}"
    VALUE="${VALUE#"${VALUE%%[! ]*}"}"
    VALUE="${VALUE%"${VALUE##*[! ]}"}"
    export "$KEY=$VALUE"
  done < "$ENV_FILE"
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

if [[ ! -f "$PROJECT_DIR/.gitignore" ]]; then
  echo "Warning: no .gitignore found in $PROJECT_DIR"
  echo "  All untracked files will be copied into the sandbox."
  echo "  Consider adding a .gitignore to exclude secrets, build artifacts, etc."
fi

# -------------------------
# Sandbox directory setup
# -------------------------
AGENT_INPUT_DIR="$SANDBOX_DIR/$AGENT_INPUT_DIR_NAME"
AGENT_WORKSPACE_DIR="$SANDBOX_DIR/$AGENT_WORKSPACE_DIR_NAME"
SNAPSHOT_DIR="$AGENT_INPUT_DIR/snapshot"

mkdir -p "$AGENT_WORKSPACE_DIR/changes"
mkdir -p "$SNAPSHOT_DIR"
mkdir -p "$AGENT_INPUT_DIR/input"

# -------------------------
# Snapshot pipeline (host side)
# -------------------------
# Enumerates and copies project files into .agent-input/snapshot/.
# git ls-files runs on the host — the container never touches PROJECT_DIR directly.
source "$REPO_ROOT/lib/snapshot.sh"

echo "Building snapshot..."
(cd "$PROJECT_DIR" && snapshot_enumerate_files "$PROJECT_DIR") \
  | (cd "$PROJECT_DIR" && snapshot_copy_files "$PROJECT_DIR" "$SNAPSHOT_DIR")

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

  cp "$BRIEF_PATH" "$AGENT_INPUT_DIR/brief.md"
fi

# -------------------------
# Mount and env construction
# -------------------------
# .agent-input is mounted read-only — input channel: snapshot, brief, operator files.
# .workspace is mounted read-write — output channel: patch, logs.
# PROJECT_DIR is not mounted — the agent has no direct access to the host repo.
MOUNT_ARGS=(
  -v "$AGENT_INPUT_DIR:/home/agentuser/$AGENT_INPUT_DIR_NAME:ro"
  -v "$AGENT_WORKSPACE_DIR:/home/agentuser/$AGENT_WORKSPACE_DIR_NAME:rw"
)

# Pass directory name definitions to the container so both sides share one source of truth
ENV_DIR_ARGS=(
  -e "AGENT_INPUT_DIR_NAME=$AGENT_INPUT_DIR_NAME"
  -e "AGENT_WORKSPACE_DIR_NAME=$AGENT_WORKSPACE_DIR_NAME"
)

IMAGE_NAME="opencode-agent-${PROJECT_NAME,,}"

# -------------------------
# Image check
# -------------------------
IMAGE_EXISTS=$(docker image inspect "$IMAGE_NAME" >/dev/null 2>&1 && echo yes || echo no)
if [[ "$IMAGE_EXISTS" != yes ]]; then
  echo "Error: Docker image not found: $IMAGE_NAME"
  echo "  Build it first: make build"
  exit 1
fi

# -------------------------
# Mode handling
# -------------------------
case "$MODE" in
  dry-run)
    echo "Running dry-run..."
    docker run --rm \
      "${MOUNT_ARGS[@]}" \
      "${ENV_DIR_ARGS[@]}" \
      -v "$REPO_ROOT/scripts/dry_run.sh:/dry_run.sh:ro" \
      "$IMAGE_NAME" \
      bash /dry_run.sh
    echo "PASS" > "$AGENT_WORKSPACE_DIR/changes/liveness.txt"
    echo ""
    echo "=== liveness: PASS ==="
    exit 0
    ;;

  standard)
    echo "Starting container: $PROJECT_NAME"
    ;;

  *)
    echo "Unknown mode: $MODE. Valid modes: standard, dry-run"
    exit 1
    ;;
esac

# -------------------------
# Command construction
# -------------------------
CMD=("opencode")
PORT_ARGS=()
ENV_ARGS=()
ECHO_ENV_ARGS=()

if [[ -n "${OPENCODE_SERVER_PASSWORD:-}" ]]; then
  ENV_ARGS+=(-e "OPENCODE_SERVER_PASSWORD=$OPENCODE_SERVER_PASSWORD")
  ECHO_ENV_ARGS+=(-e "OPENCODE_SERVER_PASSWORD=***")
fi

if [[ "$SERVE" == true ]]; then
  PORT="${SERVE_PORT:-46553}"
  CMD=("opencode" "serve" "--hostname" "0.0.0.0" "--port" "$PORT")
  PORT_ARGS=(-p "127.0.0.1:$PORT:$PORT")
fi

# -------------------------
# Run container
# -------------------------
echo "+ docker run -it --rm ${MOUNT_ARGS[*]} ${PORT_ARGS[*]+"${PORT_ARGS[*]}"} ${ECHO_ENV_ARGS[*]+"${ECHO_ENV_ARGS[*]}"} ${ENV_DIR_ARGS[*]} --name $IMAGE_NAME $IMAGE_NAME ${CMD[*]}"
docker run -it --rm \
  "${MOUNT_ARGS[@]}" \
  "${ENV_DIR_ARGS[@]}" \
  ${PORT_ARGS[@]+"${PORT_ARGS[@]}"} \
  ${ENV_ARGS[@]+"${ENV_ARGS[@]}"} \
  --name "$IMAGE_NAME" \
  "$IMAGE_NAME" \
  "${CMD[@]}"

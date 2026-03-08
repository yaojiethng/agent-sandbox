#!/usr/bin/env bash
# start-agent.sh
# Usage:
#   ./start-agent.sh <project_name> <mode:standard|safe|dry-run> [--serve] [--build] [--machine=<suffix>]
#
# Modes:
#   standard   — normal execution, network access allowed
#   safe       — reserved for no-network execution (M6, not yet implemented)
#   dry-run    — liveness check only, no agent started
#
# Project config is read from:
#   projects/<project_name>/opencode.conf             (default)
#   projects/<project_name>/opencode.<suffix>.conf    (if --machine=<suffix> is provided)
#
# Optional env file:
#   projects/<project_name>/.env                      (sourced if present)
#   Supported env vars: SERVE_PORT (default: 46553)
#
# Config keys:
#   PROJECT_NAME   — display name (optional, defaults to <project_name>)
#   PROJECT_ROOT   — absolute WSL/Linux path to the project on the host
#   AGENT_BRIEF    — path to brief.md, relative to the conf file (optional)
#
# PROJECT_ROOT is mounted read-only into the container. The entrypoint copies
# tracked and untracked non-ignored files into sandbox/ using git ls-files,
# so .gitignore is respected at copy time.
#
# Note: PROJECT_ROOT must be a git repository with at least one commit.
#       PROJECT_ROOT typically differs per machine — use opencode.<machine>.conf
#       for machine-specific overrides.
#
# Container mount base path: /home/agentuser/project/

set -euo pipefail

CONTAINER_PROJECT_BASE="/home/agentuser/project"

# -------------------------
# Args
# -------------------------
PROJECT="${1:-}"
MODE="${2:-}"
shift 2 || true

if [[ -z "$PROJECT" || -z "$MODE" ]]; then
  echo "Usage: $0 <project_name> <mode:standard|safe|dry-run> [--serve] [--build] [--machine=<suffix>]"
  exit 1
fi

# -------------------------
# Flag parsing (order agnostic)
# -------------------------
SERVE=false
BUILD=false
MACHINE=""

for ARG in "$@"; do
  case "$ARG" in
    --serve) SERVE=true ;;
    --build) BUILD=true ;;
    --machine=*) MACHINE="${ARG#--machine=}" ;;
    *)
      echo "Unknown flag: $ARG"
      exit 1
      ;;
  esac
done

# -------------------------
# Config loading
# -------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# REPO_ROOT assumes this script lives at providers/opencode/scripts/
# If the script moves, update the relative path below accordingly.
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

if [[ -n "$MACHINE" ]]; then
  CONF_FILE="$REPO_ROOT/projects/$PROJECT/opencode.$MACHINE.conf"
  if [[ ! -f "$CONF_FILE" ]]; then
    echo "Error: machine config file not found: $CONF_FILE"
    exit 1
  fi
else
  CONF_FILE="$REPO_ROOT/projects/$PROJECT/opencode.conf"
  if [[ ! -f "$CONF_FILE" ]]; then
    echo "Error: config file not found: $CONF_FILE"
    exit 1
  fi
fi

PROJECT_NAME=""
PROJECT_ROOT=""
AGENT_BRIEF=""

while IFS='=' read -r KEY VALUE || [[ -n "$KEY" ]]; do
  [[ "$KEY" =~ ^#.*$ || -z "$KEY" ]] && continue
  KEY="${KEY//[$'\r\n\t ']/}"
  VALUE="${VALUE//[$'\r\n']/}"
  VALUE="${VALUE#"${VALUE%%[! ]*}"}"   # strip leading spaces
  VALUE="${VALUE%"${VALUE##*[! ]}"}"   # strip trailing spaces
  case "$KEY" in
    PROJECT_NAME)  PROJECT_NAME="$VALUE" ;;
    PROJECT_ROOT)  PROJECT_ROOT="$VALUE" ;;
    AGENT_BRIEF)   AGENT_BRIEF="$VALUE"  ;;
  esac
done < "$CONF_FILE"

PROJECT_NAME="${PROJECT_NAME:-$PROJECT}"

# -------------------------
# Env loading
# -------------------------
ENV_FILE="$REPO_ROOT/projects/$PROJECT/.env"
if [[ -f "$ENV_FILE" ]]; then
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

if [[ -z "$PROJECT_ROOT" ]]; then
  echo "Error: PROJECT_ROOT is not set in $CONF_FILE"
  exit 1
fi

validate_wsl_path "PROJECT_ROOT" "$PROJECT_ROOT"

if [[ ! -d "$PROJECT_ROOT" ]]; then
  echo "Error: PROJECT_ROOT does not exist: $PROJECT_ROOT"
  exit 1
fi

# -------------------------
# Git validation
# -------------------------
if [[ ! -d "$PROJECT_ROOT/.git" ]]; then
  echo "Error: PROJECT_ROOT is not a git repository: $PROJECT_ROOT"
  echo "  Initialise it first:"
  echo "    git -C '$PROJECT_ROOT' init"
  echo "    git -C '$PROJECT_ROOT' add -A"
  echo "    git -C '$PROJECT_ROOT' commit -m 'initial'"
  exit 1
fi

if ! git -C "$PROJECT_ROOT" rev-parse HEAD >/dev/null 2>&1; then
  echo "Error: git repository has no commits: $PROJECT_ROOT"
  echo "  Create an initial commit first:"
  echo "    git -C '$PROJECT_ROOT' add -A"
  echo "    git -C '$PROJECT_ROOT' commit -m 'initial'"
  exit 1
fi

if [[ ! -f "$PROJECT_ROOT/.gitignore" ]]; then
  echo "Warning: no .gitignore found in $PROJECT_ROOT"
  echo "  All untracked files will be copied into the sandbox."
  echo "  Consider adding a .gitignore to exclude secrets, build artifacts, etc."
fi

# -------------------------
# Workspace setup
# -------------------------
mkdir -p "$PROJECT_ROOT/.workspace/changes"

# -------------------------
# Mount construction
# -------------------------

# PROJECT_ROOT is mounted read-only — the entrypoint copies files into sandbox/.
# .workspace is mounted read-write — it is the agent's output channel.
# The rw .workspace bind-mount shadows the ro .workspace inside PROJECT_ROOT,
# so the agent cannot read .workspace contents (e.g. .env) via the ro mount.
MOUNT_ARGS=(
  -v "$PROJECT_ROOT:$CONTAINER_PROJECT_BASE:ro"
  -v "$PROJECT_ROOT/.workspace:$CONTAINER_PROJECT_BASE/.workspace:rw"
)

# -------------------------
# Brief resolution
# -------------------------
if [[ -n "$AGENT_BRIEF" ]]; then
  CONF_DIR="$(dirname "$CONF_FILE")"
  BRIEF_PATH="$(cd "$CONF_DIR" && realpath "$AGENT_BRIEF")"

  validate_wsl_path "AGENT_BRIEF" "$BRIEF_PATH"

  if [[ ! -f "$BRIEF_PATH" ]]; then
    echo "Error: AGENT_BRIEF file not found: $BRIEF_PATH"
    exit 1
  fi

  MOUNT_ARGS+=(-v "$BRIEF_PATH:$CONTAINER_PROJECT_BASE/.workspace/brief.md:ro")
fi

IMAGE_NAME="opencode-agent-$PROJECT"
DOCKERFILE_DIR="$REPO_ROOT/providers/opencode/docker"

# -------------------------
# Build logic
# -------------------------
IMAGE_EXISTS=$(docker image inspect "$IMAGE_NAME" >/dev/null 2>&1 && echo yes || echo no)

if [[ "$BUILD" == true || "$IMAGE_EXISTS" != yes ]]; then
  echo "Building Docker image: $IMAGE_NAME"
  docker build -t "$IMAGE_NAME" "$DOCKERFILE_DIR"
fi

# -------------------------
# Mode handling
# -------------------------
case "$MODE" in
  dry-run)
    echo "Running dry-run (liveness check)..."
    echo "+ docker run --rm ${MOUNT_ARGS[*]} $IMAGE_NAME bash -c 'mkdir -p project/.workspace/changes && echo PASS > project/.workspace/changes/liveness.txt'"
    docker run --rm \
      "${MOUNT_ARGS[@]}" \
      "$IMAGE_NAME" \
      bash -c 'mkdir -p project/.workspace/changes && echo PASS > project/.workspace/changes/liveness.txt'
    exit 0
    ;;

  safe)
    echo "Safe mode (no-network) is reserved for M6 and not yet implemented."
    exit 0
    ;;

  standard)
    echo "Starting container: $PROJECT_NAME"
    ;;

  *)
    echo "Unknown mode: $MODE. Valid modes: standard, safe, dry-run"
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
echo "+ docker run -it --rm ${MOUNT_ARGS[*]} ${PORT_ARGS[*]+"${PORT_ARGS[*]}"} ${ECHO_ENV_ARGS[*]+"${ECHO_ENV_ARGS[*]}"} --name $IMAGE_NAME $IMAGE_NAME ${CMD[*]}"
docker run -it --rm \
  "${MOUNT_ARGS[@]}" \
  ${PORT_ARGS[@]+"${PORT_ARGS[@]}"} \
  ${ENV_ARGS[@]+"${ENV_ARGS[@]}"} \
  --name "$IMAGE_NAME" \
  "$IMAGE_NAME" \
  "${CMD[@]}"
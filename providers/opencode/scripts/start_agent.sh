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
#   MOUNTS         — comma-separated list of <folder>:<permission> pairs
#                    e.g. MOUNTS=src:ro,tests:ro
#                    .workspace is always mounted rw and must not be listed here
#   FILES          — comma-separated list of <file>:<permission> pairs
#                    e.g. FILES=readme.md:ro,contributors.md:ro
#                    for individual files at PROJECT_ROOT that are not in a mounted folder
#
# Note: PROJECT_ROOT typically differs per machine. All other keys are usually
#       machine-agnostic and can be shared in opencode.conf.
#
# Container mount base path: /home/agentuser/project/
# Each MOUNTS entry maps $PROJECT_ROOT/<folder> → /home/agentuser/project/<folder>

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
MOUNTS=""
FILES=""

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
    MOUNTS)        MOUNTS="$VALUE"       ;;
    FILES)         FILES="$VALUE"        ;;
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
# Git validation + bundle creation
# -------------------------

# PROJECT_ROOT must be a git repo with at least one commit for the bundle workflow.
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

mkdir -p "$PROJECT_ROOT/.workspace/changes"

echo "Creating bundle snapshot..."

# Determine if working tree is dirty (staged, unstaged, or untracked changes)
DIRTY=false
if ! git -C "$PROJECT_ROOT" diff --quiet 2>/dev/null; then DIRTY=true; fi
if ! git -C "$PROJECT_ROOT" diff --cached --quiet 2>/dev/null; then DIRTY=true; fi
if [[ $(git -C "$PROJECT_ROOT" ls-files --others --exclude-standard | wc -l) -gt 0 ]]; then
  DIRTY=true
fi

if [[ "$DIRTY" == true ]]; then
  # Temp commit captures working tree state excluding gitignored files,
  # so secrets (e.g. .env) never enter the bundle.
  # Stage tracked modifications, then add untracked non-ignored files.
  git -C "$PROJECT_ROOT" add -u
  git -C "$PROJECT_ROOT" ls-files --others --exclude-standard -z \
    | xargs -0 -r git -C "$PROJECT_ROOT" add --
  git -C "$PROJECT_ROOT" commit -m "agent-sandbox: bundle snapshot" --quiet

  # Bundle the last 2 commits (patch C + temp snapshot) using rev-list range.
  # Guard: if repo only has 1 commit, HEAD~2 does not exist — bundle all.
  REPO_DEPTH=$(git -C "$PROJECT_ROOT" rev-list --count HEAD)
  if [[ "$REPO_DEPTH" -ge 2 ]]; then
    git -C "$PROJECT_ROOT" bundle create "$PROJECT_ROOT/.workspace/repo.bundle" \
      HEAD "^HEAD~2" --quiet
  else
    git -C "$PROJECT_ROOT" bundle create "$PROJECT_ROOT/.workspace/repo.bundle" \
      HEAD --quiet
  fi

  git -C "$PROJECT_ROOT" reset HEAD~1 --mixed --quiet
  echo "  Bundle tip: HEAD + uncommitted changes (gitignored files excluded)"
else
  # Bundle only HEAD using rev-list range.
  # Guard: if repo only has 1 commit, HEAD~1 does not exist — bundle all.
  REPO_DEPTH=$(git -C "$PROJECT_ROOT" rev-list --count HEAD)
  if [[ "$REPO_DEPTH" -ge 1 ]]; then
    git -C "$PROJECT_ROOT" bundle create "$PROJECT_ROOT/.workspace/repo.bundle" \
      HEAD "^HEAD~1" --quiet
  else
    git -C "$PROJECT_ROOT" bundle create "$PROJECT_ROOT/.workspace/repo.bundle" \
      HEAD --quiet
  fi
  echo "  Bundle tip: HEAD (working tree clean)"
fi

# -------------------------
# Mount construction
# -------------------------

# .workspace is always rw — implicit, never declared in MOUNTS
MOUNT_ARGS=(-v "$PROJECT_ROOT/.workspace:$CONTAINER_PROJECT_BASE/.workspace:rw")

# Parse MOUNTS=folder:permission,folder:permission
if [[ -n "$MOUNTS" ]]; then
  IFS=',' read -ra MOUNT_ENTRIES <<< "$MOUNTS"
  for ENTRY in "${MOUNT_ENTRIES[@]}"; do
    FOLDER="${ENTRY%%:*}"
    PERMISSION="${ENTRY##*:}"
    FOLDER="${FOLDER//[$'\r\n\t ']/}"
    PERMISSION="${PERMISSION//[$'\r\n\t ']/}"

    if [[ "$FOLDER" == ".workspace" ]]; then
      echo "Error: .workspace must not be listed in MOUNTS — it is always mounted rw."
      exit 1
    fi

    if [[ "$PERMISSION" != "ro" && "$PERMISSION" != "rw" ]]; then
      echo "Error: invalid permission '$PERMISSION' for mount '$FOLDER'. Use ro or rw."
      exit 1
    fi

    HOST_PATH="$PROJECT_ROOT/$FOLDER"
    CONTAINER_PATH="$CONTAINER_PROJECT_BASE/$FOLDER"

    if [[ ! -d "$HOST_PATH" ]]; then
      echo "Error: mount source does not exist: $HOST_PATH"
      exit 1
    fi

    MOUNT_ARGS+=(-v "$HOST_PATH:$CONTAINER_PATH:$PERMISSION")
  done
fi

# Parse FILES=file:permission,file:permission
if [[ -n "$FILES" ]]; then
  IFS=',' read -ra FILE_ENTRIES <<< "$FILES"
  for ENTRY in "${FILE_ENTRIES[@]}"; do
    FILENAME="${ENTRY%%:*}"
    PERMISSION="${ENTRY##*:}"
    FILENAME="${FILENAME//[$'\r\n\t ']/}"
    PERMISSION="${PERMISSION//[$'\r\n\t ']/}"

    if [[ "$PERMISSION" != "ro" && "$PERMISSION" != "rw" ]]; then
      echo "Error: invalid permission '$PERMISSION' for file '$FILENAME'. Use ro or rw."
      exit 1
    fi

    HOST_PATH="$PROJECT_ROOT/$FILENAME"
    CONTAINER_PATH="$CONTAINER_PROJECT_BASE/$FILENAME"

    if [[ ! -f "$HOST_PATH" ]]; then
      echo "Error: file mount source does not exist: $HOST_PATH"
      exit 1
    fi

    MOUNT_ARGS+=(-v "$HOST_PATH:$CONTAINER_PATH:$PERMISSION")
  done
fi

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

# Forward server password if set
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

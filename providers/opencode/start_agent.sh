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
#   --brief=<rel>           path to agent brief, relative to SANDBOX_DIR;
#                           copied into SANDBOX_DIR/.workspace/input/brief.md
#   --env=<rel>             path to .env file, relative to SANDBOX_DIR (default: .env)
#   --serve                 apply docker-compose.serve.yml overlay
#
# Expects SANDBOX_DIR to have been prepared by: agent-sandbox onboard
# If .env is missing, onboarding has not been run — error with instructions.

set -euo pipefail

# -------------------------
# Paths
# -------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# REPO_ROOT assumes this script lives at providers/opencode/
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
# Flag parsing
# -------------------------
PROJECT_NAME=""
PROJECT_DIR=""
SANDBOX_DIR_OVERRIDE=""
AGENT_BRIEF=""
ENV_REL=".env"
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

# Source only simple KEY=VALUE lines; skip comments and blanks
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
  SANDBOX_IMAGE_NAME
  AGENT_IMAGE_NAME
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
# Workspace directory setup
# -------------------------
mkdir -p "$SNAPSHOT_DIR"
mkdir -p "$CHANGES_DIR"
mkdir -p "$INPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# -------------------------
# Snapshot pipeline (host side)
# -------------------------
source "$REPO_ROOT/libs/snapshot.sh"

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

  cp "$BRIEF_PATH" "$INPUT_DIR/brief.md"
fi

# -------------------------
# Compose file resolution
# -------------------------
COMPOSE_FILE="$SANDBOX_DIR/docker-compose.yml"

if [[ ! -f "$COMPOSE_FILE" ]]; then
  echo "Error: compose file not found: $COMPOSE_FILE"
  echo "  Re-run onboarding to restore missing files:"
  echo "    agent-sandbox onboard --name=$PROJECT_NAME --project=$PROJECT_DIR --sandbox=$SANDBOX_DIR"
  exit 1
fi

COMPOSE_ARGS=(
  --project-directory "$SANDBOX_DIR"
  -f "$COMPOSE_FILE"
)

# -------------------------
# Mode handling
# -------------------------
case "$MODE" in
  dry-run)
    echo "Running dry-run..."
    DRY_RUN_OVERLAY="$SANDBOX_DIR/docker-compose.dry-run.yml"
    if [[ ! -f "$DRY_RUN_OVERLAY" ]]; then
      echo "Error: dry-run overlay not found: $DRY_RUN_OVERLAY"
      echo "  Place docker-compose.dry-run.yml in SANDBOX_DIR for dry-run mode."
      exit 1
    fi
    DRY_RUN_SCRIPT="$(realpath "$REPO_ROOT/scripts/dry_run.sh")"

    DRY_RUN_COMPOSE_ARGS=(
      --project-directory "$SANDBOX_DIR"
      -f "$COMPOSE_FILE"
      -f "$DRY_RUN_OVERLAY"
    )

    DRY_RUN_SCRIPT="$DRY_RUN_SCRIPT" \
      docker compose "${DRY_RUN_COMPOSE_ARGS[@]}" up -d

    DRY_RUN_SCRIPT="$DRY_RUN_SCRIPT" \
      docker compose "${DRY_RUN_COMPOSE_ARGS[@]}" exec agent bash /dry_run.sh

    DRY_RUN_SCRIPT="$DRY_RUN_SCRIPT" \
      docker compose "${DRY_RUN_COMPOSE_ARGS[@]}" down -v
    echo ""
    echo "=== liveness: PASS ==="
    exit 0
    ;;

  standard)
    echo "Starting agent: $PROJECT_NAME"
    ;;

  *)
    echo "Unknown mode: $MODE. Valid modes: standard, dry-run"
    exit 1
    ;;
esac

# -------------------------
# Serve mode overlay
# -------------------------
if [[ "$SERVE" == true ]]; then
  SERVE_OVERLAY="$SANDBOX_DIR/docker-compose.serve.yml"
  if [[ ! -f "$SERVE_OVERLAY" ]]; then
    echo "Error: serve overlay not found: $SERVE_OVERLAY"
    echo "  Place docker-compose.serve.yml in SANDBOX_DIR for serve mode."
    exit 1
  fi
  COMPOSE_ARGS+=(-f "$SERVE_OVERLAY")
fi

# -------------------------
# Run
# -------------------------
# Tear down any previous session containers and volumes before starting.
docker compose "${COMPOSE_ARGS[@]}" down -v 2>/dev/null || true

if [[ "$SERVE" == true ]]; then
  echo "+ docker compose up --detach (sandbox → agent)"
  docker compose "${COMPOSE_ARGS[@]}" up -d
  echo "Agent running in serve mode. Stop with: docker compose down -v"
else
  echo "+ starting sandbox..."
  docker compose "${COMPOSE_ARGS[@]}" up -d sandbox

  # Poll until sandbox is healthy before attaching the agent.
  # depends_on: service_healthy only applies to compose up, not compose run.
  SANDBOX_CONTAINER="${SANDBOX_IMAGE_NAME}"
  echo "+ waiting for sandbox to be healthy..."
  until [[ "$(docker inspect --format '{{.State.Health.Status}}' "$SANDBOX_CONTAINER" 2>/dev/null)" == "healthy" ]]; do
    sleep 1
  done
  echo "+ sandbox healthy."

  echo "+ attaching to agent (TUI)..."
  docker compose "${COMPOSE_ARGS[@]}" run --rm agent

  echo "+ tearing down..."
  docker compose "${COMPOSE_ARGS[@]}" down -v
fi

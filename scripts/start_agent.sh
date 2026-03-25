#!/usr/bin/env bash
# scripts/start_agent.sh
# Usage:
#   ./start_agent.sh <mode> --name=<project_name> --project=<path> [--sandbox=<path>] [--brief=<rel>] [--env=<rel>]
#
# Modes:
#   standard   — normal execution, network access allowed
#   dry-run    — liveness check only, no agent started
#   serve      — OpenCode in server mode, port exposed at SERVE_PORT
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
#
# Expects SANDBOX_DIR to have been prepared by: agent-sandbox onboard
# If .env is missing, onboarding has not been run — error with instructions.

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
  echo "Usage: $0 <mode:standard|dry-run|serve> --name=<n> --project=<path> [--sandbox=<path>] [--brief=<rel>] [--env=<rel>]"
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
PROVIDER_NAME="opencode"   # default provider; override with --provider=<n>

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
# Variables are exported so docker compose and the provider run script inherit them.
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
# Dispatch to provider
# -------------------------
source "$REPO_ROOT/libs/containers.sh"

preflight "$PROVIDER_NAME" "$PROJECT_NAME" "$REPO_ROOT"

PROVIDER_RUN="$REPO_ROOT/providers/$PROVIDER_NAME/run.sh"

if [[ ! -f "$PROVIDER_RUN" ]]; then
  echo "Error: provider run script not found: $PROVIDER_RUN"
  echo "  Is '$PROVIDER_NAME' a valid provider under providers/?"
  exit 1
fi

exec "$PROVIDER_RUN" "$MODE" --name="$PROJECT_NAME" --sandbox="$SANDBOX_DIR" --provider="$PROVIDER_NAME"

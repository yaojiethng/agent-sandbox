#!/usr/bin/env bash
# run.sh
# Usage:
#   ./run.sh <mode> --name=<project_name> --project=<path> [--sandbox=<path>] [--serve] [--rebuild]
#
# Modes:
#   standard   — bring up both containers via docker compose
#   dry-run    — bring up both containers, exec dry_run.sh, tear down
#
# Required flags:
#   --name=<project_name>   project name; used to derive image names
#   --project=<path>        absolute path to project directory
#
# Optional flags:
#   --sandbox=<path>        absolute path to sandbox directory
#                           defaults to <parent-of-PROJECT_DIR>/<project-dir-name>-sandbox
#   --serve                 apply docker-compose.serve.yml overlay
#   --rebuild               build both images before starting
#
# Expects SANDBOX_DIR to already be prepared by start_agent.sh:
#   - .env written with image names and paths
#   - docker-compose.yml present
#   - .snapshot/ populated
#   - .workspace/ subdirs created
#
# TODO: start_agent.sh and run.sh overlap in responsibility. When
# start_agent.sh is refactored into a pure pre-flight script, run.sh
# becomes the sole compose entry point, not start_agent.sh.

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
  echo "Usage: $0 <mode:standard|dry-run> --name=<n> --project=<path> [--sandbox=<path>] [--serve] [--rebuild]"
  exit 1
fi

# -------------------------
# Flag parsing
# -------------------------
PROJECT_NAME=""
PROJECT_DIR=""
SANDBOX_DIR_OVERRIDE=""
SERVE=false
REBUILD=false

for ARG in "$@"; do
  case "$ARG" in
    --name=*)    PROJECT_NAME="${ARG#--name=}" ;;
    --project=*) PROJECT_DIR="${ARG#--project=}" ;;
    --sandbox=*) SANDBOX_DIR_OVERRIDE="${ARG#--sandbox=}" ;;
    --serve)     SERVE=true ;;
    --rebuild)   REBUILD=true ;;
    # Tolerated — passed through from Makefile but not needed here
    --brief=*)   ;;
    --env=*)     ;;
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
# Rebuild
# -------------------------
if [[ "$REBUILD" == true ]]; then
  echo "Building sandbox image..."
  "$SCRIPT_DIR/build_sandbox.sh" --name="$PROJECT_NAME" --sandbox="$SANDBOX_DIR"
  echo "Building agent image..."
  "$SCRIPT_DIR/build_agent.sh" --name="$PROJECT_NAME"
fi

# -------------------------
# Compose file resolution
# -------------------------
COMPOSE_FILE="$SANDBOX_DIR/docker-compose.yml"

if [[ ! -f "$COMPOSE_FILE" ]]; then
  echo "Error: compose file not found: $COMPOSE_FILE"
  echo "  Ensure start_agent.sh has run to prepare SANDBOX_DIR, or place docker-compose.yml manually."
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
    exit 1
  fi
  COMPOSE_ARGS+=(-f "$SERVE_OVERLAY")
fi

# -------------------------
# Run
# -------------------------
docker compose "${COMPOSE_ARGS[@]}" down -v 2>/dev/null || true

if [[ "$SERVE" == true ]]; then
  echo "+ docker compose up --detach (sandbox → agent)"
  docker compose "${COMPOSE_ARGS[@]}" up -d
  echo "Agent running in serve mode. Stop with: docker compose down -v"
else
  echo "+ starting sandbox..."
  docker compose "${COMPOSE_ARGS[@]}" up -d sandbox

  SANDBOX_CONTAINER="agent-sandbox-${PROJECT_NAME,,}"
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

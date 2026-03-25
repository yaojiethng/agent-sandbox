#!/usr/bin/env bash
# providers/opencode/run.sh
# Handles compose invocation for the OpenCode provider.
# Called by scripts/start_agent.sh after pre-flight completes.
#
# Usage:
#   ./run.sh <mode> --name=<project_name> --sandbox=<path>
#
# Modes:
#   standard   — OpenCode TUI attached to terminal
#   serve      — OpenCode in server mode, port exposed at SERVE_PORT
#   dry-run    — liveness check only
#   headless   — reserved, not yet implemented
#
# Expects .env variables (AUTOSAVE_INTERVAL, SERVE_PORT, etc.) to be
# present in the environment, exported by scripts/start_agent.sh.

set -euo pipefail

# -------------------------
# Paths
# -------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# REPO_ROOT assumes this script lives at providers/opencode/
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$REPO_ROOT/libs/containers.sh"

# -------------------------
# Args
# -------------------------
MODE="${1:-}"
shift || true

if [[ -z "$MODE" ]]; then
  echo "Usage: $0 <mode:standard|dry-run|serve> --name=<n> --sandbox=<path>"
  exit 1
fi

# -------------------------
# Flag parsing
# -------------------------
PROJECT_NAME=""
SANDBOX_DIR=""
PROVIDER_NAME="opencode"

for ARG in "$@"; do
  case "$ARG" in
    --name=*)     PROJECT_NAME="${ARG#--name=}" ;;
    --sandbox=*)  SANDBOX_DIR="${ARG#--sandbox=}" ;;
    --provider=*) PROVIDER_NAME="${ARG#--provider=}" ;;
    *)
      echo "Unknown flag: $ARG"
      exit 1
      ;;
  esac
done

if [[ -z "$PROJECT_NAME" || -z "$SANDBOX_DIR" ]]; then
  echo "Error: --name and --sandbox are required"
  exit 1
fi

# -------------------------
# SERVE_PORT resolution
# -------------------------
SERVE_PORT_DEFAULT=46553
if [[ -z "${SERVE_PORT:-}" ]]; then
  echo "Warning: SERVE_PORT is not set in .env — falling back to default ($SERVE_PORT_DEFAULT)"
  SERVE_PORT="$SERVE_PORT_DEFAULT"
fi

# -------------------------
# Compose file resolution
# -------------------------
COMPOSE_FILE="$SANDBOX_DIR/docker-compose.yml"

if [[ ! -f "$COMPOSE_FILE" ]]; then
  echo "Error: compose file not found: $COMPOSE_FILE"
  echo "  Re-run onboarding to restore missing files:"
  echo "    agent-sandbox onboard --name=$PROJECT_NAME --sandbox=$SANDBOX_DIR"
  exit 1
fi

COMPOSE_ARGS=(
  --project-directory "$SANDBOX_DIR"
  -f "$COMPOSE_FILE"
)

# -------------------------
# Mode dispatch
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

  serve)
    SERVE_OVERLAY="$SANDBOX_DIR/docker-compose.serve.yml"
    if [[ ! -f "$SERVE_OVERLAY" ]]; then
      echo "Error: serve overlay not found: $SERVE_OVERLAY"
      echo "  Place docker-compose.serve.yml in SANDBOX_DIR for serve mode."
      exit 1
    fi
    COMPOSE_ARGS+=(-f "$SERVE_OVERLAY")
    ;;

  standard)
    # No overlay needed
    ;;

  headless)
    echo "Error: headless mode is reserved and not yet implemented"
    exit 1
    ;;

  *)
    echo "Error: unsupported mode '$MODE'. Supported modes: standard, dry-run, serve"
    exit 1
    ;;
esac

# -------------------------
# Run
# -------------------------
# Tear down any previous session containers and volumes before starting.
docker compose "${COMPOSE_ARGS[@]}" down -v 2>/dev/null || true

if [[ "$MODE" == "serve" ]]; then
  echo "Starting agent: $PROJECT_NAME (serve mode)"
  docker compose "${COMPOSE_ARGS[@]}" up -d
  echo "Agent running in serve mode. Stop with: docker compose down -v"
  echo "server listening on http://0.0.0.0:${SERVE_PORT}"
else
  echo "Starting agent: $PROJECT_NAME"
  echo "+ starting sandbox..."
  docker compose "${COMPOSE_ARGS[@]}" up -d sandbox

  # Poll until sandbox is healthy before attaching the agent.
  # depends_on: service_healthy only applies to compose up, not compose run.
  # Container name is pinned via container_name: in the compose template — no
  # Compose-generated suffix. Resolved from the same convention as the template.
  SANDBOX_CONTAINER="$(sandbox_container_name "$PROJECT_NAME")"
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

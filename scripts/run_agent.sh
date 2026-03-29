#!/usr/bin/env bash
# scripts/run_agent.sh
# Owns the full provider container lifecycle for a single agent session.
# Called by scripts/start_agent.sh after pre-flight and snapshot pipeline.
#
# Usage:
#   ./run_agent.sh <mode> --name=<project_name> --sandbox=<path> --env=<path> --provider=<n>
#
# Modes:
#   standard   — agent TUI attached to terminal
#   serve      — provider serve mode, companion services started
#   dry-run    — liveness check only, no agent interaction
#   headless   — reserved, not yet implemented
#
# Provider config lifecycle (all modes except dry-run):
#   copy-in:  handled inside the container by provider-entrypoint.sh before
#             the agent command runs. Seeds /opt/context/config/ files into
#             AGENT_HOME if absent (first run), then resumes from AGENT_HOME
#             state on subsequent runs.
#   copy-out: EXIT trap in provider-entrypoint.sh writes AGENT_HOME to
#             workspace/output/.<provider>/ on container exit. run_agent.sh
#             moves that to $SANDBOX_DIR/.<provider>/ after the container exits.
#
# Compose file assembly follows deterministic conventions:
#   base:             libs/docker-compose.yml
#   provider overlay: providers/<n>/docker-compose.<n>.yml  (merged if exists)
#   mode overlay:
#     dry-run:        libs/docker-compose.dry-run.yml
#     serve:          providers/<n>/docker-compose.serve.yml
#
# Provider hooks:
#   providers/<n>/setup.sh  (sourced if exists, before compose generation)
#   If setup.sh exits non-zero, the session aborts with a clear error attributing
#   the failure to the provider setup hook.
#
# Separation:
#   scripts/  — control flow; entry points and session orchestration
#   libs/     — reusable utility functions; no control flow

set -euo pipefail

# -------------------------
# Paths
# -------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# REPO_ROOT assumes this script lives at scripts/
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$REPO_ROOT/libs/containers.sh"
source "$REPO_ROOT/libs/compose.sh"

# -------------------------
# Args
# -------------------------
MODE="${1:-}"
shift || true

if [[ -z "$MODE" ]]; then
  echo "Usage: $0 <mode:standard|dry-run|serve> --name=<n> --sandbox=<path> --env=<path> --provider=<n>"
  exit 1
fi

# -------------------------
# Flag parsing
# -------------------------
PROJECT_NAME=""
SANDBOX_DIR=""
ENV_FILE=""
PROVIDER_NAME=""

for ARG in "$@"; do
  case "$ARG" in
    --name=*)     PROJECT_NAME="${ARG#--name=}" ;;
    --sandbox=*)  SANDBOX_DIR="${ARG#--sandbox=}" ;;
    --env=*)      ENV_FILE="${ARG#--env=}" ;;
    --provider=*) PROVIDER_NAME="${ARG#--provider=}" ;;
    *)
      echo "Unknown flag: $ARG"
      exit 1
      ;;
  esac
done

if [[ -z "$PROJECT_NAME" || -z "$SANDBOX_DIR" || -z "$ENV_FILE" || -z "$PROVIDER_NAME" ]]; then
  echo "Error: --name, --sandbox, --env, and --provider are required"
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
# Provider setup hook
# -------------------------
# Sources providers/<n>/setup.sh if it exists.
# setup.sh is responsible for:
#   - exporting provider-specific vars needed before compose generation
#   - pre-creating $SANDBOX_DIR/.<provider>/ so the bind mount source exists
# If setup.sh exits non-zero, the session aborts with an attribution message.
PROVIDER_SETUP="$REPO_ROOT/providers/$PROVIDER_NAME/setup.sh"

if [[ -f "$PROVIDER_SETUP" ]]; then
  if ! source "$PROVIDER_SETUP"; then
    echo "Error: provider setup hook failed: $PROVIDER_SETUP"
    echo "  Fix the error in providers/$PROVIDER_NAME/setup.sh before retrying."
    exit 1
  fi
fi

# -------------------------
# Compose file assembly
# -------------------------
COMPOSE_TEMPLATE="$REPO_ROOT/libs/docker-compose.yml"
DRY_RUN_OVERLAY="$REPO_ROOT/libs/docker-compose.dry-run.yml"
PROVIDER_OVERLAY="$REPO_ROOT/providers/$PROVIDER_NAME/docker-compose.${PROVIDER_NAME}.yml"
SERVE_OVERLAY="$REPO_ROOT/providers/$PROVIDER_NAME/docker-compose.serve.yml"

if [[ ! -f "$COMPOSE_TEMPLATE" ]]; then
  echo "Error: compose template not found: $COMPOSE_TEMPLATE"
  echo "  The agent-sandbox repo may be incomplete or out of date."
  exit 1
fi

COMPOSE_FILES=("$COMPOSE_TEMPLATE")

# Provider overlay is optional — merged if present.
if [[ -f "$PROVIDER_OVERLAY" ]]; then
  COMPOSE_FILES+=("$PROVIDER_OVERLAY")
fi

case "$MODE" in
  dry-run)
    if [[ ! -f "$DRY_RUN_OVERLAY" ]]; then
      echo "Error: dry-run overlay not found: $DRY_RUN_OVERLAY"
      exit 1
    fi
    export DRY_RUN_SCRIPT
    DRY_RUN_SCRIPT="$(realpath "$REPO_ROOT/scripts/dry_run.sh")"
    COMPOSE_FILES+=("$DRY_RUN_OVERLAY")
    ;;
  serve)
    if [[ ! -f "$SERVE_OVERLAY" ]]; then
      echo "Error: serve overlay not found: $SERVE_OVERLAY"
      echo "  Expected at providers/$PROVIDER_NAME/docker-compose.serve.yml"
      exit 1
    fi
    COMPOSE_FILES+=("$SERVE_OVERLAY")
    ;;
  standard|headless)
    ;;
esac

COMPOSE_OUT="$(mktemp --suffix=.yml)"
trap 'rm -f "$COMPOSE_OUT"' EXIT

compose_generate "$COMPOSE_OUT" "$PROJECT_NAME" "$PROVIDER_NAME" "${COMPOSE_FILES[@]}"

# -------------------------
# Compose args
# -------------------------
compose_args "$PROJECT_NAME" "$SANDBOX_DIR" "$COMPOSE_OUT"

# -------------------------
# Mode dispatch
# -------------------------
case "$MODE" in
  dry-run)
    echo "Running dry-run..."
    compose_dry_run "$DRY_RUN_SCRIPT"
    exit 0
    ;;

  serve|standard)
    # Handled below
    ;;

  headless)
    echo "Error: headless mode is reserved and not yet implemented"
    exit 1
    ;;

  *)
    echo "Error: unsupported mode '$MODE'. Supported modes: standard, serve, dry-run"
    exit 1
    ;;
esac

# -------------------------
# Provider config paths
# -------------------------
# copy-in is handled inside the container by provider-entrypoint.sh.
# copy-out: provider-entrypoint.sh EXIT trap writes AGENT_HOME to
# workspace/output/.<provider>/; run_agent.sh moves it here after exit.
PROVIDER_CONFIG_HOST="$SANDBOX_DIR/.$PROVIDER_NAME"
PROVIDER_CONFIG_OUT="$SANDBOX_DIR/.workspace/output/.$PROVIDER_NAME"
AGENT_CONTAINER="$(agent_container_name "$PROVIDER_NAME" "$PROJECT_NAME")"

# -------------------------
# Post-exit copy-out move
# -------------------------
# Moves workspace/output/.<provider>/ (written by provider-entrypoint.sh EXIT
# trap) to $SANDBOX_DIR/.<provider>/ after the container exits.
# No-op if the container produced no output (e.g. crashed before copy-out ran).
_provider_persist() {
  if [[ -d "$PROVIDER_CONFIG_OUT" ]] && [[ -n "$(ls -A "$PROVIDER_CONFIG_OUT" 2>/dev/null)" ]]; then
    echo "+ persisting provider config to $PROVIDER_CONFIG_HOST"
    rm -rf "$PROVIDER_CONFIG_HOST"
    mv "$PROVIDER_CONFIG_OUT" "$PROVIDER_CONFIG_HOST"
  else
    echo "+ no provider config output found — skipping persist"
  fi
}

# -------------------------
# Run
# -------------------------
compose_teardown

if [[ "$MODE" == "serve" ]]; then
  echo "Starting agent: $PROJECT_NAME (serve mode)"
  docker compose "${COMPOSE_ARGS[@]}" up -d
  echo "Stop with: make stop"
  echo "Interactive web running on http://127.0.0.1:${SERVE_PORT}"

  # Wait for the agent container to exit (triggered by make stop / docker stop).
  # Keeps run_agent.sh alive so persist and teardown run in sequence after exit.
  docker wait "$AGENT_CONTAINER" >/dev/null 2>&1 || true

  _provider_persist

  echo "+ tearing down..."
  docker compose "${COMPOSE_ARGS[@]}" down -v

else
  echo "Starting agent: $PROJECT_NAME"
  echo "+ starting sandbox..."
  docker compose "${COMPOSE_ARGS[@]}" up -d sandbox

  compose_sandbox_wait "$PROJECT_NAME"

  echo "+ attaching to agent..."
  docker compose "${COMPOSE_ARGS[@]}" run --rm agent

  _provider_persist

  echo "+ tearing down..."
  docker compose "${COMPOSE_ARGS[@]}" down -v
fi

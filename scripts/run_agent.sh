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
#   copy-in:  provider-entrypoint.sh copies $SANDBOX_DIR/.<provider>/ (mounted
#             at /opt/provider-config/) into AGENT_HOME before the agent starts.
#   copy-out: provider-entrypoint.sh EXIT trap copies AGENT_HOME back to
#             /opt/provider-config/ on container exit. Since /opt/provider-config/
#             is bind-mounted from $SANDBOX_DIR/.<provider>/, state is persisted
#             to the host automatically — no move step required here.
#
# Host identity for UID mapping
# Compose file assembly follows deterministic conventions:
#   base:             libs/docker-compose.yml
#   provider overlay: src/reasoning/providers/<n>/docker-compose.<n>.yml  (merged if exists)
#   mode overlay:
#     dry-run:        libs/docker-compose.dry-run.yml
#     serve:          src/reasoning/providers/<n>/docker-compose.serve.yml
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
# REPO_ROOT assumes this script lives at scripts/
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source "$REPO_ROOT/src/build/image.sh"
source "$REPO_ROOT/scripts/build.sh"
source "$REPO_ROOT/src/build/compose.sh"

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
RESET_VOLUME=false

for ARG in "$@"; do
  case "$ARG" in
    --name=*)     PROJECT_NAME="${ARG#--name=}" ;;
    --sandbox=*)  SANDBOX_DIR="${ARG#--sandbox=}" ;;
    --env=*)      ENV_FILE="${ARG#--env=}" ;;
    --provider=*) PROVIDER_NAME="${ARG#--provider=}" ;;
    --reset-volume) RESET_VOLUME=true ;;
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
# setup.sh is responsible for exporting provider-specific vars needed before
# compose generation.
# If setup.sh exits non-zero, the session aborts with an attribution message.
PROVIDER_SETUP="$REPO_ROOT/src/reasoning/providers/$PROVIDER_NAME/setup.sh"

if [[ -f "$PROVIDER_SETUP" ]]; then
  if ! source "$PROVIDER_SETUP"; then
    echo "Error: provider setup hook failed: $PROVIDER_SETUP"
    echo "  Fix the error in src/reasoning/providers/$PROVIDER_NAME/setup.sh before retrying."
    exit 1
  fi
fi

# -------------------------
# Provider config directory
# -------------------------
# Ensure provider config dir exists with correct ownership before Docker mounts it.
# Docker creates missing bind mount sources as root-owned; pre-creating avoids
# permission failures in provider-entrypoint.sh copy-out.
mkdir -p "$SANDBOX_DIR/.$PROVIDER_NAME"

# -------------------------
# Host identity for UID mapping
export HOST_UID
HOST_UID="$(id -u)"
export HOST_GID
HOST_GID="$(id -g)"

# Compose file assembly
# -------------------------
COMPOSE_TEMPLATE="$REPO_ROOT/src/build/docker-compose.yml"
DRY_RUN_OVERLAY="$REPO_ROOT/src/build/docker-compose.dry-run.yml"
PROVIDER_OVERLAY="$REPO_ROOT/src/reasoning/providers/$PROVIDER_NAME/docker-compose.${PROVIDER_NAME}.yml"
SERVE_OVERLAY="$REPO_ROOT/src/reasoning/providers/$PROVIDER_NAME/docker-compose.serve.yml"

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
    DRY_RUN_SCRIPT="$(realpath "$REPO_ROOT/scripts/dry_run_reasoning.sh")"
    export DRY_RUN_CAPABILITY_SCRIPT
    DRY_RUN_CAPABILITY_SCRIPT="$(realpath "$REPO_ROOT/scripts/dry_run_capability.sh")"
    COMPOSE_FILES+=("$DRY_RUN_OVERLAY")
    ;;
  serve)
    if [[ ! -f "$SERVE_OVERLAY" ]]; then
      echo "Error: serve overlay not found: $SERVE_OVERLAY"
      echo "  Expected at src/reasoning/providers/$PROVIDER_NAME/docker-compose.serve.yml"
      exit 1
    fi
    COMPOSE_FILES+=("$SERVE_OVERLAY")
    ;;
  standard|headless)
    ;;
esac

# Persist the merged compose file at a stable path in the sandbox so the
# session's compose configuration survives for inspection and compose-aware
# tooling after the run (docker compose -f .compose/<run-id>.yml ...). Named
# by RUN_ID — resume reuses the same RUN_ID and overwrites; each unique
# session leaves one record. RUN_ID is always exported by start_agent.sh;
# fall back to the sandbox-dir hash (as compose_args does) for direct
# invocation. Containers mount only SANDBOX_DIR subdirectories, so this file
# is never visible in the agent workspace.
COMPOSE_DIR="$SANDBOX_DIR/.compose"
mkdir -p "$COMPOSE_DIR"
if [[ -n "${RUN_ID:-}" ]]; then
  COMPOSE_OUT="$COMPOSE_DIR/$RUN_ID.yml"
else
  COMPOSE_OUT="$COMPOSE_DIR/$(echo "$SANDBOX_DIR" | sha256sum | cut -c1-6).yml"
fi

# Teardown runs on every exit after TEARDOWN_NEEDED is set — agent
# completion, agent failure, compose up failure, sandbox-wait failure — so
# containers and network never leak. The pre-run cleanup (stop-previous-
# project), dry-run, headless, and flag-error exits all happen before
# TEARDOWN_NEEDED is set and are therefore not re-torn-down. The persisted
# compose file is intentionally kept (session record), not removed here.
# shellcheck disable=SC2317  # invoked via trap, not called directly
_session_cleanup() {
  [[ "${TEARDOWN_NEEDED:-}" == "1" ]] || return 0
  echo "+ tearing down..."
  session_teardown
}
trap _session_cleanup EXIT

compose_generate "$COMPOSE_OUT" "$PROJECT_NAME" "$PROVIDER_NAME" "${COMPOSE_FILES[@]}"

# -------------------------
# Compose args
# -------------------------
compose_args "$PROJECT_NAME" "$SANDBOX_DIR" "$COMPOSE_OUT" "${RUN_ID:-}"

# -------------------------
# Mode dispatch
# -------------------------
case "$MODE" in
  dry-run)
    echo "Running dry-run..."
    compose_dry_run "$DRY_RUN_SCRIPT" "$DRY_RUN_CAPABILITY_SCRIPT" "$SANDBOX_DIR" "$RESET_VOLUME"
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
# Run
# -------------------------
if [[ "$RESET_VOLUME" == "true" ]]; then
  # start_agent.sh already removed old volumes for this sandbox dir.
  # Skip compose teardown — the new compose project (by RUN_ID) doesn't
  # exist yet, and the old project used a different RUN_ID.
  :
else
  session_teardown
fi

# The mode branch only runs the session; the EXIT trap (_session_cleanup)
# ends it. Both modes block until the agent session is over (serve: docker
# wait returns on make stop; standard: compose run returns when the agent
# exits) — see the docker-wait comment below for why this ordering matters.
agent_rc=0
TEARDOWN_NEEDED=1
if [[ "$MODE" == "serve" ]]; then
  echo "Starting agent: $PROJECT_NAME (serve mode)"
  docker compose "${COMPOSE_ARGS[@]}" up -d
  echo "Stop with: make stop"
  echo "Interactive web running on http://127.0.0.1:${SERVE_PORT}"

  # Wait for the agent container to exit (triggered by make stop / docker stop).
  # Keeps run_agent.sh alive so teardown runs after the provider-entrypoint
  # EXIT trap has fired and copy-out to /opt/provider-config/ is complete.
  # The container's exit code on make stop is SIGTERM/SIGKILL (137/143) — not
  # a session result — so it is swallowed here and serve exits 0 (teardown is
  # handled by run_agent.sh's own EXIT trap, _session_cleanup).
  docker wait "$AGENT_CONTAINER_NAME" >/dev/null 2>&1 || true

else
  echo "Starting agent: $PROJECT_NAME"
  echo "+ starting sandbox..."
  docker compose "${COMPOSE_ARGS[@]}" up -d sandbox 2>&1 | (grep -vE '^ ?Container |^ ?Network |^ ?Volume |^ ?$' || true)

  compose_sandbox_wait "$PROJECT_NAME"

  echo "+ attaching to agent..."
  # Capture the agent's exit code instead of letting set -e abort: teardown
  # (via the EXIT trap) must run even when the agent fails (containers +
  # network leak otherwise), and the rc is propagated to the caller below.
  docker compose "${COMPOSE_ARGS[@]}" run --rm --name "$AGENT_CONTAINER_NAME" agent || agent_rc=$?
fi

# Exit semantics: standard propagates the agent's exit code; serve exits 0
# (its session ends via make stop, not agent completion). Teardown already
# ran in the EXIT trap (_session_cleanup).
exit "$agent_rc"
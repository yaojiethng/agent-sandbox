#!/usr/bin/env bash
# scripts/run_agent.sh
# Owns the full provider container lifecycle for a single agent session.
# Called by scripts/start_agent.sh after pre-flight and snapshot pipeline.
#
# Usage:
#   ./run_agent.sh <mode> --name=<project_name> --sandbox=<path> --env=<path> --provider=<n>
#
# Modes:
#   standard    --  agent TUI attached to terminal
#   serve       --  provider serve mode, companion services started
#   dry-run     --  liveness check only, no agent interaction
#   headless    --  reserved, not yet implemented
#
# Provider config lifecycle (all modes except dry-run):
#   copy-in:  provider-entrypoint.sh copies $SANDBOX_DIR/.<provider>/ (mounted
#             at /opt/provider-config/) into AGENT_HOME before the agent starts.
#   copy-out: provider-entrypoint.sh EXIT trap copies AGENT_HOME back to
#             /opt/provider-config/ on container exit. Since /opt/provider-config/
#             is bind-mounted from $SANDBOX_DIR/.<provider>/, state is persisted
#             to the host automatically  --  no move step required here.
#
# Host identity for UID mapping
# Compose file assembly follows deterministic conventions:
#   base:             src/build/docker-compose.yml
#   delivery overlay: src/build/docker-compose.copy.yml | src/build/docker-compose.mount.yml
#                     (selected by SANDBOX_TYPE, default copy)
#   provider overlay: src/reasoning/providers/<n>/docker-compose.<n>.yml  (merged if exists)
#   mode overlay:
#     dry-run:        src/build/docker-compose.dry-run.yml
#     serve:          src/reasoning/providers/<n>/docker-compose.serve.yml
#
# Provider hooks:
#   providers/<n>/setup.sh  (sourced if exists, before compose generation)
#   If setup.sh exits non-zero, the session aborts with a clear error attributing
#   the failure to the provider setup hook.
#
# Separation:
#   scripts/   --  control flow; entry points and session orchestration
#   libs/      --  reusable utility functions; no control flow

set -euo pipefail

# -------------------------
# Paths
# -------------------------
# REPO_ROOT assumes this script lives at scripts/
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source "$REPO_ROOT/src/build/image.sh"
source "$REPO_ROOT/scripts/build.sh"
source "$REPO_ROOT/src/build/compose.sh"
source "$REPO_ROOT/src/libs/session_inventory.sh"

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
  echo "Warning: SERVE_PORT is not set in .env  --  falling back to default ($SERVE_PORT_DEFAULT)"
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
  # The setup path is provider-selected and validated by the -f check;
# ShellCheck cannot follow it statically.
# shellcheck disable=SC1090
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
# The compose file set is selected at generation time per delivery type
# (SANDBOX_TYPE=copy|mount, default copy): base template + delivery overlay +
# provider overlay (if present) + mode overlay (dry-run/serve). The delivery
# overlay carries the per-delivery wiring: copy -> named volume (content is
# host-side seeded, no snapshot mount); mount -> worktree bind mount
# (docker-compose.copy.yml /.mount.yml).
COMPOSE_TEMPLATE="$REPO_ROOT/src/build/docker-compose.yml"
COPY_OVERLAY="$REPO_ROOT/src/build/docker-compose.copy.yml"
MOUNT_OVERLAY="$REPO_ROOT/src/build/docker-compose.mount.yml"
DRY_RUN_OVERLAY="$REPO_ROOT/src/build/docker-compose.dry-run.yml"
PROVIDER_OVERLAY="$REPO_ROOT/src/reasoning/providers/$PROVIDER_NAME/docker-compose.${PROVIDER_NAME}.yml"
SERVE_OVERLAY="$REPO_ROOT/src/reasoning/providers/$PROVIDER_NAME/docker-compose.serve.yml"

if [[ ! -f "$COMPOSE_TEMPLATE" ]]; then
  echo "Error: compose template not found: $COMPOSE_TEMPLATE"
  echo "  The agent-sandbox repo may be incomplete or out of date."
  exit 1
fi

# Delivery type  --  SANDBOX_TYPE=copy|mount, default copy. Copy is the only
# implemented delivery today; mount is wired for the compose file set and
# gains full behavior in M2.6.6 delivery enablement.
DELIVERY_TYPE="${SANDBOX_TYPE:-copy}"
case "$DELIVERY_TYPE" in
  copy|mount) ;;
  *)
    echo "Error: invalid SANDBOX_TYPE: $DELIVERY_TYPE (expected 'copy' or 'mount')" >&2
    exit 1
    ;;
esac

# Mount delivery worktree  --  single shared host worktree per sandbox. Default
# ${SANDBOX_DIR}/.worktree; overridable via WORKTREE_DIR (custom mount point,
# injected into compose at generation). Only the mount overlay reads it.
export WORKTREE_DIR="${WORKTREE_DIR:-$SANDBOX_DIR/.worktree}"

COMPOSE_FILES=("$COMPOSE_TEMPLATE")

# Delivery overlay  --  selected by DELIVERY_TYPE.
if [[ "$DELIVERY_TYPE" == "copy" ]]; then
  if [[ ! -f "$COPY_OVERLAY" ]]; then
    echo "Error: copy delivery overlay not found: $COPY_OVERLAY" >&2
    exit 1
  fi
  COMPOSE_FILES+=("$COPY_OVERLAY")
else
  if [[ ! -f "$MOUNT_OVERLAY" ]]; then
    echo "Error: mount delivery overlay not found: $MOUNT_OVERLAY" >&2
    exit 1
  fi
  COMPOSE_FILES+=("$MOUNT_OVERLAY")
fi

# Provider overlay is optional  --  merged if present.
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
# tooling after the run (docker compose -f .compose/<session-id>.yml ...). Named
# by SESSION_ID  --  resume reuses the same SESSION_ID and overwrites; each unique
# session leaves one record. SESSION_ID is always exported by start_agent.sh;
# fall back to the sandbox-dir hash (as compose_args does) for direct
# invocation. Containers mount only SANDBOX_DIR subdirectories, so this file
# is never visible in the agent workspace.
COMPOSE_DIR="$SANDBOX_DIR/.compose"
mkdir -p "$COMPOSE_DIR"
if [[ -n "${SESSION_ID:-}" ]]; then
  COMPOSE_OUT="$COMPOSE_DIR/$SESSION_ID.yml"
else
  COMPOSE_OUT="$COMPOSE_DIR/$(echo "$SANDBOX_DIR" | sha256sum | cut -c1-6).yml"
fi

# Teardown runs on every exit after TEARDOWN_NEEDED is set  --  agent
# completion, agent failure, compose up failure, sandbox-wait failure  --  so
# containers and network never leak. The pre-run cleanup (stop-previous-
# project), dry-run, headless, and flag-error exits all happen before
# TEARDOWN_NEEDED is set and are therefore not re-torn-down. The persisted
# compose file is intentionally kept (session record), not removed here.
# shellcheck disable=SC2317  # invoked via trap, not called directly
_session_cleanup() {
  [[ "${TEARDOWN_NEEDED:-}" == "1" ]] || return 0
  echo "+ tearing down..."
  session_teardown
  # Record the stop in the per-session activity log (time since last stop is
  # shown by `make resume --list`). Only the post-session teardown (TEARDOWN_NEEDED)
  # writes it -- NOT the pre-run cleanup -- so a session isn't marked stopped
  # before it has started.
  if [[ -n "${SESSION_ID:-}" ]]; then
    session_log_set "$SESSION_ID" last_stopped "$(date -u +%Y%m%d-%H%M%S)"
    echo "Resume this session later: make resume SESSION_ID=$SESSION_ID"
  fi
}
trap _session_cleanup EXIT

compose_generate "$COMPOSE_OUT" "$PROJECT_NAME" "$PROVIDER_NAME" "${COMPOSE_FILES[@]}"

# -------------------------
# Compose args
# -------------------------
compose_args "$PROJECT_NAME" "$SANDBOX_DIR" "$COMPOSE_OUT" "${SESSION_ID:-}"

# -------------------------
# Volume seed (copy delivery, fresh start)
# -------------------------
# start_agent.sh always runs with --reset-volume (fresh session); resume never
# does. So RESET_VOLUME=true marks exactly the fresh-init case: the sandbox
# volume does not exist yet and must be seeded before the sandbox container
# starts. The seed tar carries the operator's working tree (git-enumerated)
# plus the HEAD baseline; the container-side init (snapshot_init_git) turns it
# into the index=HEAD / worktree=disk state.
seed_sandbox_volume() {
  if [[ -z "${PROJECT_DIR:-}" ]]; then
    echo "Error: PROJECT_DIR is not set  --  cannot build the seed tar" >&2
    return 1
  fi
  source "$REPO_ROOT/src/capability/snapshot.sh"
  local seed_tar
  seed_tar=$(mktemp /tmp/agent-sandbox-seed.XXXXXX.tar) || { echo "Error: mktemp failed" >&2; return 1; }
  if ! snapshot_seed_tar "$PROJECT_DIR" "$seed_tar"; then
    rm -f "$seed_tar"
    return 1
  fi
  # Create the sandbox container (and its volume) without starting it, then
  # extract the seed tar into the volume through the container's mount path.
  # docker cp writes through the volume mount, so the data lands in the
  # volume; the entrypoint's fresh-init path consumes it from there.
  if ! docker compose "${COMPOSE_ARGS[@]}" create sandbox >/dev/null 2>&1; then
    echo "Error: docker compose create sandbox failed  --  cannot seed the volume" >&2
    rm -f "$seed_tar"
    return 1
  fi
  local cid
  # The sandbox container name is deterministic (baked via container_name: in
  # the compose template and exported as SANDBOX_CONTAINER_NAME). `docker
  # compose ps -q` cannot be used here: it does not list containers in the
  # created-but-never-started state.
  cid="${SANDBOX_CONTAINER_NAME:-}"
  if [[ -z "$cid" ]]; then
    cid=$(docker compose "${COMPOSE_ARGS[@]}" ps -aq sandbox 2>/dev/null)
  fi
  if [[ -z "$cid" ]] || ! docker inspect "$cid" >/dev/null 2>&1; then
    echo "Error: sandbox container not found after create  --  cannot seed the volume" >&2
    echo "  Expected container: ${SANDBOX_CONTAINER_NAME:-<unset SANDBOX_CONTAINER_NAME>}" >&2
    rm -f "$seed_tar"
    return 1
  fi
  if ! docker cp - "$cid:/home/agentuser/sandbox" < "$seed_tar"; then
    echo "Error: docker cp seed failed  --  cannot seed the volume" >&2
    rm -f "$seed_tar"
    return 1
  fi
  # Post-transfer verification: docker cp from stdin always reports
  # "Successfully copied 0B" (the byte counter covers the local-file copy
  # path, not stdin extraction), so success output proves nothing. Read the
  # sentinel baseline back out of the volume -- docker cp works on stopped
  # containers and writes through the volume mount -- and fail the start if
  # the seed did not land. A bad seed would otherwise surface only as a
  # container that never initializes.
  local verify_tar="$seed_tar.verify"
  if ! docker cp "$cid:/home/agentuser/sandbox/.agent-sandbox-seed/baseline.tar" "$verify_tar" \
    || [[ ! -s "$verify_tar" ]]; then
    echo "Error: seed verification failed  --  baseline.tar not found in the sandbox volume after docker cp" >&2
    echo "  The volume may not have received the seed. Check: docker inspect $cid" >&2
    rm -f "$seed_tar" "$verify_tar"
    return 1
  fi
  rm -f "$seed_tar" "$verify_tar"
  echo "Sandbox volume seeded (baseline.tar verified in volume)."
}

# Transport switch (handover 20260904-04): "helper" (default) seeds via the
# one-shot seeder service (ADR 2026-09-04 entry); "legacy" keeps the docker cp
# pipeline for comparison until its removal (scheduled with handover 20260904-03,
# step 3 of the operator plan).
SEED_TRANSPORT="${SEED_TRANSPORT:-helper}"

seed_sandbox_volume_helper() {
  if [[ -z "${PROJECT_DIR:-}" ]]; then
    echo "Error: PROJECT_DIR is not set  --  cannot seed the volume" >&2
    return 1
  fi
  # The seeder's exit code is the only readiness signal (ADR completion-signal
  # block): event-driven wait via `compose run`, bounded by a hard timeout. On
  # failure the session volume is discarded  --  a half-seeded volume must
  # never boot. The sandbox container is created by the normal start flow
  # afterward; the healthcheck then passes immediately (the seeder wrote .git).
  local seed_timeout="${SEED_TIMEOUT:-300}"
  local rc=0
  # -T + closed stdin: compose run allocates a TTY and attaches stdin by
  # default; from the non-interactive start pipeline that attach never closes
  # and compose hangs after the container exits (observed live, handover
  # 20260904-05). Non-interactive run lets the exit code propagate.
  timeout "$seed_timeout" docker compose "${COMPOSE_ARGS[@]}" run --rm -T seeder < /dev/null || rc=$?
  if (( rc != 0 )); then
    if (( rc == 124 )); then
      echo "Error: seeder timed out after ${seed_timeout}s  --  aborting start" >&2
    else
      echo "Error: seeder failed (exit $rc)  --  aborting start" >&2
    fi
    echo "  Seeder output above names the failure. Discarding the session volume." >&2
    docker compose "${COMPOSE_ARGS[@]}" down --volumes --remove-orphans >/dev/null 2>&1 || true
    return 1
  fi
  echo "Sandbox volume seeded and verified (git status parity)."
}

if [[ "$RESET_VOLUME" == "true" && "$DELIVERY_TYPE" == "copy" ]]; then
  if [[ "$SEED_TRANSPORT" == "legacy" ]]; then
    echo "+ seeding sandbox volume (legacy docker cp transport)..."
    seed_sandbox_volume || exit 1
  else
    seed_sandbox_volume_helper || exit 1
  fi
fi

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
  # Skip compose teardown  --  the new compose project (by SESSION_ID) doesn't
  # exist yet, and the old project used a different SESSION_ID.
  :
else
  session_teardown
fi

# The mode branch only runs the session; the EXIT trap (_session_cleanup)
# ends it. Both modes block until the agent session is over (serve: docker
# wait returns on make stop; standard: compose run returns when the agent
# exits)  --  see the docker-wait comment below for why this ordering matters.
agent_rc=0
TEARDOWN_NEEDED=1
# Session is now actively running: record last_started and clear last_stopped so
# `make resume --list` shows the session as in-use (LAST_USED = ---) rather than
# its last stop. Skipped for dry-run, which exits before this point.
if [[ -n "${SESSION_ID:-}" ]]; then
  session_log_set "$SESSION_ID" last_started "$(date -u +%Y%m%d-%H%M%S)"
  session_log_set "$SESSION_ID" last_stopped ""
fi
if [[ "$MODE" == "serve" ]]; then
  echo "Starting agent: $PROJECT_NAME (serve mode)"
  docker compose "${COMPOSE_ARGS[@]}" up -d
  echo "Stop with: make stop"
  echo "Interactive web running on http://127.0.0.1:${SERVE_PORT}"

  # Wait for the agent container to exit (triggered by make stop / docker stop).
  # Keeps run_agent.sh alive so teardown runs after the provider-entrypoint
  # EXIT trap has fired and copy-out to /opt/provider-config/ is complete.
  # The container's exit code on make stop is SIGTERM/SIGKILL (137/143)  --  not
  # a session result  --  so it is swallowed here and serve exits 0 (teardown is
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
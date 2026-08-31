#!/usr/bin/env bash
# scripts/stop.sh
#
# Stops containers for a given sandbox.
# Identifies containers by label-based filtering  --  does not invoke
# docker compose and does not require resolved compose environment variables.
#
# Usage:
#   stop.sh --name=<project_name> --sandbox=<path> [--session-id=<id>] [--prune]
#
# Filter logic:
#   Default: agent-sandbox.project-name + agent-sandbox.sandbox-dir labels
#   --session-id: additionally filter by agent-sandbox.session-id label (stop specific session only)
#   --prune:  after stopping, remove aged containers, images, and networks
#             for this project+sandbox instance older than PRUNE_AGE_DAYS

set -euo pipefail

usage() {
  cat <<EOF
Usage: agent-sandbox stop --name=<name> --sandbox=<path> [--project=<path>] [--session-id=<id>] [--prune]

Stops containers for a given sandbox.

Required:
  --name=<name>       Project name
  --sandbox=<path>    Path to the sandbox directory

Optional:
  --project=<path>   Project repository path (forwarded to prune for staleness)
  --session-id=<id>  Stop only the specific session (by agent-sandbox.session-id label)
  --prune             After stopping, run the registry-based prune (prune.sh)
EOF
}

# REPO_ROOT assumes this script lives at scripts/
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO_ROOT/src/libs/common.sh"

SESSION_ID=""
PRUNE=false
PROJECT_DIR=""

parse_help_flag "$@"
parse_base_flags "$@"

# Parse stop-specific flags (after --name and --sandbox are consumed)
for ARG in "$@"; do
  case "$ARG" in
    --name=*|--sandbox=*) ;;
    --project=*)       PROJECT_DIR="${ARG#--project=}" ;;
    --session-id=*)  SESSION_ID="${ARG#--session-id=}" ;;
    --prune)     PRUNE=true ;;
    *)
      echo "Unknown argument: $ARG" >&2
      usage >&2
      exit 1
      ;;
  esac
done

check_base_flags

# -------------------------
# Build label filters
# -------------------------

LABEL_FILTERS=(
  --filter "label=agent-sandbox.project-name=${PROJECT_NAME}"
  --filter "label=agent-sandbox.sandbox-dir=${SANDBOX_DIR}"
)

if [[ -n "$SESSION_ID" ]]; then
  LABEL_FILTERS+=(--filter "label=agent-sandbox.session-id=${SESSION_ID}")
fi

# -------------------------
# Stop and remove containers
# -------------------------

# Capture via command substitution, not `mapfile < <(cmd)`: under
# `set -euo pipefail` a docker failure must abort, and process substitution
# swallows the exit status. Convert the newline-separated capture to an array;
# an empty capture yields one empty element from the here-string, so reset it.
ids_out="$(docker ps -aq "${LABEL_FILTERS[@]}")"
mapfile -t CONTAINER_IDS <<< "$ids_out"
if [[ ${#CONTAINER_IDS[@]} -eq 1 && -z "${CONTAINER_IDS[0]}" ]]; then
  CONTAINER_IDS=()
fi

if [[ ${#CONTAINER_IDS[@]} -eq 0 ]]; then
  echo "No containers found for ${PROJECT_NAME} (sandbox: ${SANDBOX_DIR})${SESSION_ID:+ session: ${SESSION_ID}}"
else
  echo "Stopping containers for ${PROJECT_NAME} (sandbox: ${SANDBOX_DIR})${SESSION_ID:+ session: ${SESSION_ID}}"
  # Containers are disposable  --  durable state lives in the named volume +
  # bind mounts (Container State Contract). Remove them so the network can
  # be freed and no stopped containers accumulate.
  docker stop "${CONTAINER_IDS[@]}"
  # Removal races run_agent.sh's EXIT-trap `compose down`, which may already
  # be removing these containers, so `docker rm` can report "already in
  # progress". The containers are disposable, so tolerate removal failure and
  # reconcile on the next stop. `docker stop` above stays fail-closed.
  docker rm "${CONTAINER_IDS[@]}" || true
  echo "Containers stopped and removed."
  if [[ -n "$SESSION_ID" ]]; then
    echo "Resume this session later: make resume SESSION_ID=$SESSION_ID"
  fi
fi

# -------------------------
# Remove the session network (by label  --  no project-name parsing)
# -------------------------

# The compose-created default network carries the session labels, so it is
# found by the same LABEL_FILTERS used for containers (including --session-id
# scoping when set). It can only be removed once no container references it
# (handled above by removing the containers).
net_ids_out="$(docker network ls -q "${LABEL_FILTERS[@]}")"
mapfile -t NETWORK_IDS <<< "$net_ids_out"
if [[ ${#NETWORK_IDS[@]} -eq 1 && -z "${NETWORK_IDS[0]}" ]]; then
  NETWORK_IDS=()
fi
if [[ ${#NETWORK_IDS[@]} -gt 0 ]]; then
  echo "Removing session networks for ${PROJECT_NAME} (sandbox: ${SANDBOX_DIR})"
  docker network rm "${NETWORK_IDS[@]}" 2>/dev/null || true
  echo "Networks removed."
fi

# -------------------------
# Prune (if requested  --  delegates to prune.sh)
# -------------------------

if [[ "$PRUNE" == true ]]; then
  if [[ -z "$PROJECT_DIR" ]]; then
    echo "Error: --prune requires --project (for registry staleness)." >&2
    exit 1
  fi
  "$REPO_ROOT/scripts/prune.sh" \
    --name="$PROJECT_NAME" \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR"
fi

echo "Done."

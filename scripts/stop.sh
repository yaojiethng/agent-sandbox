#!/usr/bin/env bash
# scripts/stop.sh
#
# Stops containers for a given sandbox.
# Identifies containers by label-based filtering — does not invoke
# docker compose and does not require resolved compose environment variables.
#
# Usage:
#   stop.sh --name=<project_name> --sandbox=<path> [--run-id=<id>] [--prune]
#
# Filter logic:
#   Default: agent-sandbox.project-name + agent-sandbox.sandbox-dir labels
#   --run-id: additionally filter by agent-sandbox.run-id label (stop specific run only)
#   --prune:  after stopping, remove aged containers, images, and networks
#             for this project+sandbox instance older than PRUNE_AGE_DAYS

set -euo pipefail

PRUNE_AGE_DAYS=3

usage() {
  cat <<EOF
Usage: agent-sandbox stop --name=<name> --sandbox=<path> [--run-id=<id>] [--prune]

Stops containers for a given sandbox.

Required:
  --name=<name>       Project name
  --sandbox=<path>    Path to the sandbox directory

Optional:
  --run-id=<id>       Stop only the specific run (by agent-sandbox.run-id label)
  --prune             After stopping, remove aged containers, images, and networks
                        older than ${PRUNE_AGE_DAYS} days
EOF
}

# REPO_ROOT assumes this script lives at scripts/
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO_ROOT/src/libs/common.sh"

RUN_ID=""
PRUNE=false

parse_help_flag "$@"
parse_base_flags "$@"

# Parse stop-specific flags (after --name and --sandbox are consumed)
for ARG in "$@"; do
  case "$ARG" in
    --name=*|--sandbox=*) ;;
    --run-id=*)  RUN_ID="${ARG#--run-id=}" ;;
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

if [[ -n "$RUN_ID" ]]; then
  LABEL_FILTERS+=(--filter "label=agent-sandbox.run-id=${RUN_ID}")
fi

# -------------------------
# Stop and remove containers
# -------------------------

CONTAINER_IDS=$(docker ps -aq "${LABEL_FILTERS[@]}")

if [[ -z "$CONTAINER_IDS" ]]; then
  echo "No containers found for ${PROJECT_NAME} (sandbox: ${SANDBOX_DIR})${RUN_ID:+ run: ${RUN_ID}}"
else
  echo "Stopping containers for ${PROJECT_NAME} (sandbox: ${SANDBOX_DIR})${RUN_ID:+ run: ${RUN_ID}}"
  # Word splitting is intentional
  # shellcheck disable=SC2086
  docker stop $CONTAINER_IDS
  # Containers are disposable — durable state lives in the named volume +
  # bind mounts (Container State Contract). Remove them so the network can
  # be freed and no stopped containers accumulate.
  # shellcheck disable=SC2086
  docker rm $CONTAINER_IDS
  echo "Containers stopped and removed."
fi

# -------------------------
# Remove the session network (by label — no project-name parsing)
# -------------------------

# The compose-created default network carries the session labels, so it is
# found by the same LABEL_FILTERS used for containers (including --run-id
# scoping when set). It can only be removed once no container references it
# (handled above by removing the containers).
NETWORK_IDS=$(docker network ls -q "${LABEL_FILTERS[@]}")
if [[ -n "$NETWORK_IDS" ]]; then
  echo "Removing session networks for ${PROJECT_NAME} (sandbox: ${SANDBOX_DIR})"
  # Word splitting is intentional
  # shellcheck disable=SC2086
  docker network rm $NETWORK_IDS 2>/dev/null || true
  echo "Networks removed."
fi

# -------------------------
# Prune (if requested — delegates to prune.sh)
# -------------------------

if [[ "$PRUNE" == true ]]; then
  "$REPO_ROOT/scripts/prune.sh" \
    --name="$PROJECT_NAME" \
    --sandbox="$SANDBOX_DIR"
fi

echo "Done."

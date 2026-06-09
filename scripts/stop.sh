#!/usr/bin/env bash
# scripts/stop.sh
#
# Stops containers and removes project-scoped volumes for a given sandbox.
# Identifies containers by label-based filtering — does not invoke
# docker compose and does not require resolved compose environment variables.
#
# Usage:
#   stop.sh --name=<project_name> --sandbox=<path> [--run-id=<id>] [--prune]
#
# Filter logic:
#   Default: agent-sandbox.project-name + agent-sandbox.sandbox-dir labels
#   --run-id: additionally filter by agent-sandbox.run-id label (stop specific run only)
#   --prune:  after stopping, remove orphaned containers, images, and volumes
#             for this project+sandbox instance older than PRUNE_AGE_DAYS

set -euo pipefail

PRUNE_AGE_DAYS=3

usage() {
  cat <<EOF
Usage: agent-sandbox stop --name=<name> --sandbox=<path> [--run-id=<id>] [--prune]

Stops containers and removes project-scoped volumes for a given sandbox.

Required:
  --name=<name>       Project name
  --sandbox=<path>    Path to the sandbox directory

Optional:
  --run-id=<id>       Stop only the specific run (by agent-sandbox.run-id label)
  --prune             After stopping, remove orphaned resources older than ${PRUNE_AGE_DAYS} days
EOF
}

# Source shared flag parsing (sets SCRIPT_DIR, PROJECT_NAME, SANDBOX_DIR;
# provides parse_help_flag, parse_base_flags, check_base_flags).
_common_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../src/libs" && pwd)"
source "$_common_dir/common.sh"

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
  # shellcheck disable=SC2086
  docker rm $CONTAINER_IDS
  echo "Containers stopped."
fi

# -------------------------
# Remove project-scoped anonymous volumes
# -------------------------

VOLUME_FILTERS=(
  --filter "label=agent-sandbox.project-name=${PROJECT_NAME}"
  --filter "label=agent-sandbox.sandbox-dir=${SANDBOX_DIR}"
)

if [[ -n "$RUN_ID" ]]; then
  VOLUME_FILTERS+=(--filter "label=agent-sandbox.run-id=${RUN_ID}")
fi

VOLUME_IDS=$(docker volume ls -q "${VOLUME_FILTERS[@]}")
if [[ -n "$VOLUME_IDS" ]]; then
  echo "Removing volumes for ${PROJECT_NAME}..."
  # shellcheck disable=SC2086
  docker volume rm $VOLUME_IDS
fi

# -------------------------
# Prune (if requested — delegates to prune.sh)
# -------------------------

if [[ "$PRUNE" == true ]]; then
  "$SCRIPT_DIR/prune.sh" \
    --name="$PROJECT_NAME" \
    --sandbox="$SANDBOX_DIR"
fi

echo "Done."

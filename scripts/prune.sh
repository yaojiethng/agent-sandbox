#!/usr/bin/env bash
# scripts/prune.sh
#
# Removes orphaned containers, images, and volumes for a given project+sandbox
# instance that are older than PRUNE_AGE_DAYS.
#
# Usage:
#   prune.sh --name=<project_name> --sandbox=<path>
#
# Can be called standalone or via `make stop PRUNE=1` (which delegates here).

set -euo pipefail

PRUNE_AGE_DAYS=3

usage() {
  cat <<EOF
Usage: agent-sandbox prune --name=<name> --sandbox=<path>

Removes orphaned containers, images, and volumes for a given project+sandbox
instance that are older than ${PRUNE_AGE_DAYS} days.

Required:
  --name=<name>       Project name
  --sandbox=<path>    Path to the sandbox directory
EOF
}

PROJECT_NAME=""
SANDBOX_DIR=""

for ARG in "$@"; do
  case "$ARG" in
    --help|-h) usage; exit 0 ;;
  esac
done

for ARG in "$@"; do
  case "$ARG" in
    --name=*)    PROJECT_NAME="${ARG#--name=}" ;;
    --sandbox=*) SANDBOX_DIR="${ARG#--sandbox=}" ;;
    *)
      echo "Unknown argument: $ARG" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$PROJECT_NAME" || -z "$SANDBOX_DIR" ]]; then
  echo "Error: --name and --sandbox are required" >&2
  usage >&2
  exit 1
fi

echo "Pruning orphaned resources older than ${PRUNE_AGE_DAYS} days..."

# Build the label filter string for docker system prune.
# docker system prune --filter supports label=<key>=<value> format.
local_filter="label=agent-sandbox.project-name=${PROJECT_NAME}"
local_filter="${local_filter},label=agent-sandbox.sandbox-dir=${SANDBOX_DIR}"

# Prune containers, images, and volumes with the label filter and age threshold
docker system prune \
  --force \
  --all \
  --filter "${local_filter}" \
  --filter "until=${PRUNE_AGE_DAYS}d" \
  2>/dev/null || true

# Also prune anonymous volumes that escaped the label filter
# (volumes created without labels during old sessions)
docker volume prune --force --filter "label!=agent-sandbox.project-name" 2>/dev/null || true

echo "Prune complete."

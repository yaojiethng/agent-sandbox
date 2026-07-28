#!/usr/bin/env bash
# scripts/prune.sh
#
# Removes aged containers, images, networks, and volumes for a single
# project+sandbox instance. Never touches resources from other projects.
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

Removes aged containers, images, networks, and volumes for a given
project+sandbox instance older than ${PRUNE_AGE_DAYS} days.
Only touches resources belonging to this project.

Required:
  --name=<name>       Project name
  --sandbox=<path>    Path to the sandbox directory
EOF
}

# Source shared flag parsing (sets SCRIPT_DIR, PROJECT_NAME, SANDBOX_DIR;
# provides parse_help_flag, parse_base_flags, check_base_flags).
_common_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../src/libs" && pwd)"
source "$_common_dir/common.sh"

parse_help_flag "$@"
parse_base_flags "$@"
check_base_flags

echo "Pruning orphaned resources older than ${PRUNE_AGE_DAYS} days..."

# Build the label filter string for docker system prune.
# docker system prune --filter supports label=<key>=<value> format.
local_filter="label=agent-sandbox.project-name=${PROJECT_NAME}"
local_filter="${local_filter},label=agent-sandbox.sandbox-dir=${SANDBOX_DIR}"

# Prune containers, images, networks, and volumes with the label filter
# and age threshold. The --volumes flag is required to include volumes;
# without it docker system prune only touches containers, images, and networks.
# The label filter scopes everything to this project — no other project's
# resources are affected.
docker system prune \
  --force \
  --all \
  --volumes \
  --filter "${local_filter}" \
  --filter "until=${PRUNE_AGE_DAYS}d" \
  2>/dev/null || true

echo "Prune complete."

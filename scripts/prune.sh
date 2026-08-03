#!/usr/bin/env bash
# scripts/prune.sh
#
# Removes aged containers, images, networks, and volumes for a single
# project+sandbox instance. Never touches resources from other projects.
# Volumes are only removed when no associated container (stopped or
# running) references them — container persistence ensures a stopped
# container keeps its volume until the container itself ages out.
#
# Usage:
#   prune.sh --name=<project_name> --sandbox=<path> [--stale]
#
#   --stale    Prune only stale volumes (host-head-sha != current HEAD) immediately,
#              bypassing the age threshold. Non-stale volumes are left untouched.
#              Also prunes aged containers, images, and networks as normal.
#
# Can be called standalone or via `make stop PRUNE=1 STALE=1` (which delegates here).

set -euo pipefail

PRUNE_AGE_DAYS=3
STALE_ONLY=false

usage() {
  cat <<EOF
Usage: agent-sandbox prune --name=<name> --sandbox=<path> [--stale]

Removes aged containers, images, and networks for a given
project+sandbox instance older than ${PRUNE_AGE_DAYS} days.
Only touches resources belonging to this project.

Options:
  --stale    Prune only stale volumes immediately (no age check).

Required:
  --name=<name>       Project name
  --sandbox=<path>    Path to the sandbox directory
EOF
}

# Parse --stale before sourcing common.sh (which only handles --name/--sandbox).
for ARG in "$@"; do
  case "$ARG" in
    --stale) STALE_ONLY=true ;;
  esac
done

# Source shared flag parsing (sets SCRIPT_DIR, PROJECT_NAME, SANDBOX_DIR;
# provides parse_help_flag, parse_base_flags, check_base_flags).
_common_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../src/libs" && pwd)"
source "$_common_dir/common.sh"

parse_help_flag "$@"
parse_base_flags "$@"
check_base_flags

if [[ "$STALE_ONLY" == true ]]; then
  echo "Pruning stale volumes immediately..."

  current_sha=$(git -C "$PROJECT_DIR" rev-parse HEAD)

  docker volume ls \
    --filter "label=agent-sandbox.sandbox-dir=${SANDBOX_DIR}" \
    --format '{{.Name}}' 2>/dev/null \
  | while read -r vol; do
    [[ -z "$vol" ]] && continue

    vol_sha=$(docker volume inspect "$vol" \
      --format '{{index .Labels "agent-sandbox.host-head-sha"}}' 2>/dev/null || true)

    if [[ -z "$vol_sha" ]]; then
      echo "  Skipping $vol (no host-head-sha label — may be from older harness)"
      continue
    fi

    if [[ "$vol_sha" != "$current_sha" ]]; then
      echo "  Removing stale volume: $vol (SHA: ${vol_sha:0:7}, current: ${current_sha:0:7})"
      docker volume rm "$vol" 2>/dev/null || \
        echo "  Warning: could not remove $vol (may be in use by a container)"
    else
      echo "  Keeping fresh volume: $vol"
    fi
  done

  echo "Stale volume prune complete."
else
  echo "Pruning orphaned resources older than ${PRUNE_AGE_DAYS} days..."

  # Build the label filter string for docker system prune.
  # docker system prune --filter supports label=<key>=<value> format.
  local_filter="label=agent-sandbox.project-name=${PROJECT_NAME}"
  local_filter="${local_filter},label=agent-sandbox.sandbox-dir=${SANDBOX_DIR}"

  # Prune containers, images, networks, and volumes with the label filter
  # and age threshold. Docker prevents volume removal while any container
  # (even stopped) references it — container and volume lifecycle are
  # naturally coupled: the container must age out before its volume can
  # be pruned.
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
fi

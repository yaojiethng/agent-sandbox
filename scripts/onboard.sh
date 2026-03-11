#!/usr/bin/env bash
# scripts/onboard.sh
#
# Dispatches `agent-sandbox onboard <workflow>` to the corresponding
# workflow/<n>/onboard.sh script.
#
# Workflow is resolved by name: workflow/<n>/onboard.sh
# To add a new workflow, create workflow/<n>/onboard.sh.
#
# Usage:
#   onboard.sh <workflow> <flags>

set -euo pipefail

AGENT_SANDBOX_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

WORKFLOW="${1:-}"
shift || true

if [[ -z "$WORKFLOW" ]]; then
  echo "ERROR: workflow is required." >&2
  echo "Usage: agent-sandbox onboard <workflow> <flags>" >&2
  echo "Available workflows:" >&2
  for dir in "$AGENT_SANDBOX_REPO/workflow/"/*/; do
    [[ -f "${dir}scripts/onboard.sh" ]] && echo "  $(basename "$dir")" >&2
  done
  exit 1
fi

WORKFLOW_SCRIPT="$AGENT_SANDBOX_REPO/workflow/$WORKFLOW/scripts/onboard.sh"

if [[ ! -f "$WORKFLOW_SCRIPT" ]]; then
  echo "ERROR: Unknown workflow: $WORKFLOW" >&2
  echo "Available workflows:" >&2
  for dir in "$AGENT_SANDBOX_REPO/workflow/"/*/; do
    [[ -f "${dir}scripts/onboard.sh" ]] && echo "  $(basename "$dir")" >&2
  done
  exit 1
fi

exec "$WORKFLOW_SCRIPT" "$@"

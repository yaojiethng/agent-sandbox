#!/usr/bin/env bash
# scripts/apply_workspace_inplace.sh
#
# Applies staged.diff to the current branch of PROJECT_ROOT without committing.
# The operator reviews and commits manually after verifying the result.
#
# Usage: apply_workspace_inplace.sh <PROJECT_ROOT> <WORKSPACE_DIR>

set -euo pipefail

PROJECT_ROOT="${1:-}"
WORKSPACE_DIR="${2:-}"
STAGED_DIFF="$WORKSPACE_DIR/changes/staged.diff"

if [[ -z "$PROJECT_ROOT" || -z "$WORKSPACE_DIR" ]]; then
  echo "Usage: apply_workspace_inplace.sh <PROJECT_ROOT> <WORKSPACE_DIR>" >&2
  exit 1
fi

if [[ ! -d "$PROJECT_ROOT" ]]; then
  echo "Error: PROJECT_ROOT does not exist: $PROJECT_ROOT" >&2
  exit 1
fi

if [[ ! -f "$STAGED_DIFF" ]]; then
  echo "Error: staged.diff not found at $STAGED_DIFF" >&2
  exit 1
fi

if [[ ! -s "$STAGED_DIFF" ]]; then
  echo "Error: staged.diff is empty — nothing to apply" >&2
  exit 1
fi

# Validate git state: must be a repo with at least one commit.
if ! git -C "$PROJECT_ROOT" rev-parse --git-dir > /dev/null 2>&1; then
  echo "Error: $PROJECT_ROOT is not a git repository" >&2
  exit 1
fi

if ! git -C "$PROJECT_ROOT" rev-parse HEAD > /dev/null 2>&1; then
  echo "Error: $PROJECT_ROOT has no commits — cannot apply patch" >&2
  exit 1
fi

echo "Applying staged.diff to current branch in $PROJECT_ROOT..."
git -C "$PROJECT_ROOT" apply --3way "$STAGED_DIFF"
echo "Done. Review changes and commit manually."

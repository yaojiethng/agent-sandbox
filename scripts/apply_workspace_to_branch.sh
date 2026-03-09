#!/usr/bin/env bash
# scripts/apply_workspace_to_branch.sh
#
# Checks out a named branch in PROJECT_ROOT and applies staged.diff.
# Creates the branch if it does not exist. Does not commit.
# The operator reviews and commits manually after verifying the result.
#
# Usage: apply_workspace_to_branch.sh <PROJECT_ROOT> <WORKSPACE_DIR> <BRANCH>

set -euo pipefail

PROJECT_ROOT="${1:-}"
WORKSPACE_DIR="${2:-}"
BRANCH="${3:-}"
STAGED_DIFF="$WORKSPACE_DIR/changes/staged.diff"

if [[ -z "$PROJECT_ROOT" || -z "$WORKSPACE_DIR" || -z "$BRANCH" ]]; then
  echo "Usage: apply_workspace_to_branch.sh <PROJECT_ROOT> <WORKSPACE_DIR> <BRANCH>" >&2
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

# Checkout or create the target branch.
if git -C "$PROJECT_ROOT" show-ref --verify --quiet "refs/heads/$BRANCH"; then
  echo "Checking out existing branch: $BRANCH"
  git -C "$PROJECT_ROOT" checkout "$BRANCH"
else
  echo "Creating and checking out new branch: $BRANCH"
  git -C "$PROJECT_ROOT" checkout -b "$BRANCH"
fi

echo "Applying staged.diff to branch $BRANCH in $PROJECT_ROOT..."
git -C "$PROJECT_ROOT" apply --3way "$STAGED_DIFF"
echo "Done. Review changes and commit manually."

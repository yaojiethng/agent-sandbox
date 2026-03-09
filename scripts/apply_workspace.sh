#!/usr/bin/env bash
# scripts/apply_workspace.sh
#
# Applies staged.diff to PROJECT_ROOT without committing.
# The operator reviews and commits manually after verifying the result.
#
# Usage:
#   apply_workspace.sh --root=<path> [--branch=<n>]
#
# Options:
#   --root=<path>    absolute path to the project root (required)
#   --branch=<n>     branch to apply to; created if it does not exist (optional)
#                    if omitted, applies to the current branch

set -euo pipefail

# -------------------------
# Flag parsing
# -------------------------
PROJECT_ROOT=""
BRANCH=""

for ARG in "$@"; do
  case "$ARG" in
    --root=*)   PROJECT_ROOT="${ARG#--root=}" ;;
    --branch=*) BRANCH="${ARG#--branch=}" ;;
    *)
      echo "Unknown flag: $ARG" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$PROJECT_ROOT" ]]; then
  echo "Usage: apply_workspace.sh --root=<path> [--branch=<n>]" >&2
  exit 1
fi

STAGED_DIFF="$PROJECT_ROOT/.workspace/changes/staged.diff"

# -------------------------
# Validation
# -------------------------
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

if ! git -C "$PROJECT_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  echo "Error: $PROJECT_ROOT is not a git repository" >&2
  exit 1
fi

if ! git -C "$PROJECT_ROOT" rev-parse HEAD >/dev/null 2>&1; then
  echo "Error: $PROJECT_ROOT has no commits — cannot apply patch" >&2
  exit 1
fi

# -------------------------
# Branch checkout
# -------------------------
if [[ -n "$BRANCH" ]]; then
  if git -C "$PROJECT_ROOT" show-ref --verify --quiet "refs/heads/$BRANCH"; then
    echo "Checking out existing branch: $BRANCH"
    git -C "$PROJECT_ROOT" checkout "$BRANCH"
  else
    echo "Creating and checking out new branch: $BRANCH"
    git -C "$PROJECT_ROOT" checkout -b "$BRANCH"
  fi
fi

# -------------------------
# Apply
# -------------------------
echo "Applying staged.diff to $(git -C "$PROJECT_ROOT" branch --show-current) in $PROJECT_ROOT..."
git -C "$PROJECT_ROOT" apply --3way "$STAGED_DIFF"
echo "Done. Review changes and commit manually."

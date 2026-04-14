#!/usr/bin/env bash
# scripts/apply_workspace.sh
#
# Applies staged.diff to PROJECT_DIR without committing.
# The operator reviews and commits manually after verifying the result.
#
# Usage:
#   apply_workspace.sh --project=<path> --sandbox=<path> [--branch=<n>]
#
# Options:
#   --project=<path>   absolute path to the project directory (required) — git operations target this
#   --sandbox=<path>   absolute path to the sandbox directory (required) — staged.diff is read from here
#   --branch=<n>       branch to apply to; created if it does not exist (optional)
#                      if omitted, applies to the current branch

set -euo pipefail

# -------------------------
# Flag parsing
# -------------------------
PROJECT_DIR=""
SANDBOX_DIR=""
BRANCH=""

for ARG in "$@"; do
  case "$ARG" in
    --project=*) PROJECT_DIR="${ARG#--project=}" ;;
    --sandbox=*) SANDBOX_DIR="${ARG#--sandbox=}" ;;
    --branch=*)  BRANCH="${ARG#--branch=}" ;;
    *)
      echo "Unknown flag: $ARG" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$PROJECT_DIR" || -z "$SANDBOX_DIR" ]]; then
  echo "Usage: apply_workspace.sh --project=<path> --sandbox=<path> [--branch=<n>]" >&2
  exit 1
fi

STAGED_DIFF="$SANDBOX_DIR/.workspace/changes/staged.diff"

# -------------------------
# Validation
# -------------------------
if [[ ! -d "$PROJECT_DIR" ]]; then
  echo "Error: PROJECT_DIR does not exist: $PROJECT_DIR" >&2
  exit 1
fi

if [[ ! -d "$SANDBOX_DIR" ]]; then
  echo "Error: SANDBOX_DIR does not exist: $SANDBOX_DIR" >&2
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

if ! git -C "$PROJECT_DIR" rev-parse --git-dir >/dev/null 2>&1; then
  echo "Error: $PROJECT_DIR is not a git repository" >&2
  exit 1
fi

if ! git -C "$PROJECT_DIR" rev-parse HEAD >/dev/null 2>&1; then
  echo "Error: $PROJECT_DIR has no commits — cannot apply patch" >&2
  exit 1
fi

# -------------------------
# Branch checkout
# -------------------------
if [[ -n "$BRANCH" ]]; then
  if git -C "$PROJECT_DIR" show-ref --verify --quiet "refs/heads/$BRANCH"; then
    echo "Checking out existing branch: $BRANCH"
    git -C "$PROJECT_DIR" checkout "$BRANCH"
  else
    echo "Creating and checking out new branch: $BRANCH"
    git -C "$PROJECT_DIR" checkout -b "$BRANCH"
  fi
fi

# -------------------------
# Apply
# -------------------------
echo "Applying staged.diff to $(git -C "$PROJECT_DIR" branch --show-current) in $PROJECT_DIR..."
git -C "$PROJECT_DIR" apply --3way "$STAGED_DIFF"
echo "Done. Review changes and commit manually."

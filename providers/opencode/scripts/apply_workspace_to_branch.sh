#!/usr/bin/env bash
# apply_workspace.sh
# Applies the agent's patch.diff from .workspace/changes/ to the target project.
#
# Usage:
#   ./apply_workspace.sh <project_name> <branch_name> [--machine=<suffix>]
#
# Reads PROJECT_ROOT from projects/<project_name>/opencode.conf
# Applies .workspace/changes/patch.diff to PROJECT_ROOT using git apply.
# Commits the result to <branch_name> for review.

set -euo pipefail

# -------------------------
# Args
# -------------------------
PROJECT="${1:-}"
BRANCH="${2:-}"
shift 2 || true

if [[ -z "$PROJECT" || -z "$BRANCH" ]]; then
  echo "Usage: $0 <project_name> <branch_name> [--machine=<suffix>]"
  exit 1
fi

# -------------------------
# Flag parsing
# -------------------------
MACHINE=""

for ARG in "$@"; do
  case "$ARG" in
    --machine=*) MACHINE="${ARG#--machine=}" ;;
    *)
      echo "Unknown flag: $ARG"
      exit 1
      ;;
  esac
done

# -------------------------
# Config loading
# -------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# REPO_ROOT assumes this script lives at providers/opencode/scripts/
# If the script moves, update the relative path below accordingly.
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

if [[ -n "$MACHINE" ]]; then
  CONF_FILE="$REPO_ROOT/projects/$PROJECT/opencode.$MACHINE.conf"
  if [[ ! -f "$CONF_FILE" ]]; then
    echo "Error: machine config file not found: $CONF_FILE"
    exit 1
  fi
else
  CONF_FILE="$REPO_ROOT/projects/$PROJECT/opencode.conf"
  if [[ ! -f "$CONF_FILE" ]]; then
    echo "Error: config file not found: $CONF_FILE"
    exit 1
  fi
fi

PROJECT_ROOT=""
PROJECT_NAME=""

while IFS='=' read -r KEY VALUE || [[ -n "$KEY" ]]; do
  [[ "$KEY" =~ ^#.*$ || -z "$KEY" ]] && continue
  KEY="${KEY//[$'\r\n\t ']/}"
  VALUE="${VALUE//[$'\r\n']/}"
  VALUE="${VALUE#"${VALUE%%[! ]*}"}"   # strip leading spaces
  VALUE="${VALUE%"${VALUE##*[! ]}"}"   # strip trailing spaces
  case "$KEY" in
    PROJECT_ROOT)  PROJECT_ROOT="$VALUE" ;;
    PROJECT_NAME)  PROJECT_NAME="$VALUE" ;;
  esac
done < "$CONF_FILE"

PROJECT_NAME="${PROJECT_NAME:-$PROJECT}"

if [[ -z "$PROJECT_ROOT" ]]; then
  echo "Error: PROJECT_ROOT is not set in $CONF_FILE"
  exit 1
fi

if [[ ! -d "$PROJECT_ROOT" ]]; then
  echo "Error: PROJECT_ROOT does not exist: $PROJECT_ROOT"
  exit 1
fi

# -------------------------
# Patch resolution
# -------------------------
PATCH_FILE="$PROJECT_ROOT/.workspace/changes/patch.diff"

if [[ ! -f "$PATCH_FILE" ]]; then
  echo "Error: patch file not found: $PATCH_FILE"
  echo "Has the container run and exited cleanly?"
  exit 1
fi

if [[ ! -s "$PATCH_FILE" ]]; then
  echo "patch.diff is empty — no changes to apply."
  exit 0
fi

# -------------------------
# Git validation
# -------------------------
if [[ ! -d "$PROJECT_ROOT/.git" ]]; then
  echo "Error: PROJECT_ROOT is not a git repository: $PROJECT_ROOT"
  echo "git apply requires a git repo as the target."
  exit 1
fi

# -------------------------
# Apply patch
# -------------------------
cd "$PROJECT_ROOT"

echo "Checking out branch: $BRANCH"
git checkout -B "$BRANCH"

echo "Applying patch: $PATCH_FILE"
git -c core.fileMode=false apply --allow-empty --3way "$PATCH_FILE"

echo ""
echo "Done. Patch applied to branch '$BRANCH'."
echo "Review with: git diff main..$BRANCH"
echo "Stage and commit when ready: git add -A && git commit"

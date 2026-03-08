#!/usr/bin/env bash
# apply_workspace_inplace.sh
# Applies the agent's patch.diff directly to the current branch, no staging or commit.
#
# Usage:
#   ./apply_workspace_inplace.sh <project_name> [--machine=<suffix>]

set -euo pipefail

# -------------------------
# Args
# -------------------------
PROJECT="${1:-}"
shift 1 || true

if [[ -z "$PROJECT" ]]; then
  echo "Usage: $0 <project_name> [--machine=<suffix>]"
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
  VALUE="${VALUE#"${VALUE%%[! ]*}"}"
  VALUE="${VALUE%"${VALUE##*[! ]}"}"
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
  echo "  git apply requires a git repo as the target. Initialise it first:"
  echo "    git -C '$PROJECT_ROOT' init"
  echo "    git -C '$PROJECT_ROOT' add -A"
  echo "    git -C '$PROJECT_ROOT' commit -m 'initial'"
  exit 1
fi

if ! git -C "$PROJECT_ROOT" rev-parse HEAD >/dev/null 2>&1; then
  echo "Error: git repository has no commits: $PROJECT_ROOT"
  echo "  Create an initial commit first:"
  echo "    git -C '$PROJECT_ROOT' add -A"
  echo "    git -C '$PROJECT_ROOT' commit -m 'initial'"
  exit 1
fi

# -------------------------
# Apply patch
# -------------------------
cd "$PROJECT_ROOT"

echo "Applying patch: $PATCH_FILE"
git -c core.fileMode=false apply --allow-empty --3way "$PATCH_FILE"

echo ""
echo "Done. Patch applied to working tree on current branch."
echo "Review with: git diff"
echo "Stage and commit when ready: git add -A && git commit"

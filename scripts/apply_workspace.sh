#!/usr/bin/env bash
# scripts/apply_workspace.sh
#
# Apply workflow for agent-sandbox session artefacts.
#
# Commands:
#   draft   [--project=<path>] [--sandbox=<path>] [--session=<name>]
#             Create a working branch agent/draft/<session-name> from the
#             checkpoint tag. Apply all patches via git am --3way with
#             per-patch author reset. Write .workspace/draft-state.
#
#   confirm [--project=<path>] [--sandbox=<path>] [--target=<branch>]
#             Rebase draft branch onto target, fast-forward merge to target,
#             delete working branch, clear draft-state.
#
#   reject  [--project=<path>] [--sandbox=<path>]
#             Checkout SOURCE_BRANCH, delete working branch, clear draft-state.
#
#   (legacy, no command arg)  [--project=<path>] [--sandbox=<path>] [--branch=<n>]
#             Apply changes.diff from OUTPUT_DIR to PROJECT_DIR with git apply --3way.
#             No commits created. Operator reviews and commits manually.
#             Reads from reasoning layer output channel (.workspace/output/).
#             The --mode=apply flag is deprecated and removed.
#
# .workspace/draft-state format:
#   SOURCE_BRANCH=<branch>
#   WORKING_BRANCH=<branch>
#   SESSION_DIR=<rel-path>
#
# Cleanup policy:
#   OUTPUT_DIR is not cleared automatically. Operator clears manually between sessions if desired.

set -euo pipefail

# -------------------------
# Parse command
# -------------------------
COMMAND=""
if [[ $# -gt 0 && "$1" != --* ]]; then
  COMMAND="$1"
  shift
fi

# -------------------------
# Flag parsing
# -------------------------
PROJECT_DIR=""
SANDBOX_DIR=""
SESSION_ARG=""
TARGET_BRANCH=""
APPLY_BRANCH=""
MODE=""

for ARG in "$@"; do
  case "$ARG" in
    --project=*) PROJECT_DIR="${ARG#--project=}" ;;
    --sandbox=*) SANDBOX_DIR="${ARG#--sandbox=}" ;;
    --session=*) SESSION_ARG="${ARG#--session=}" ;;
    --target=*)  TARGET_BRANCH="${ARG#--target=}" ;;
    --branch=*)  APPLY_BRANCH="${ARG#--branch=}" ;;
    --mode=*)    MODE="${ARG#--mode=}" ;;
    *)
      echo "Unknown flag: $ARG" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$PROJECT_DIR" || -z "$SANDBOX_DIR" ]]; then
  echo "Usage: apply_workspace.sh <draft|confirm|reject> --project=<path> --sandbox=<path> [flags]" >&2
  exit 1
fi

WORKSPACE_DIR="$SANDBOX_DIR/.workspace"
CHANGES_DIR="$WORKSPACE_DIR/session-diffs"
OUTPUT_DIR="$WORKSPACE_DIR/output"
DRAFT_STATE_FILE="$WORKSPACE_DIR/draft-state"
CHECKPOINT_REF_FILE="$WORKSPACE_DIR/checkpoint-latest.ref"

# -------------------------
# Common validation
# -------------------------
if [[ ! -d "$PROJECT_DIR" ]]; then
  echo "Error: PROJECT_DIR does not exist: $PROJECT_DIR" >&2
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
# DRAFT
# -------------------------
if [[ "$COMMAND" == "draft" ]]; then
  if [[ ! -d "$CHANGES_DIR" ]]; then
    echo "Error: changes directory not found: $CHANGES_DIR" >&2
    exit 1
  fi

  # Resolve session directory
  if [[ -n "$SESSION_ARG" ]]; then
    SESSION_DIR="$CHANGES_DIR/$SESSION_ARG"
    SESSION_NAME="$SESSION_ARG"
  else
    # Most recent session under session-diffs/ (by directory mtime)
    SESSION_DIR=$(find "$CHANGES_DIR" -mindepth 1 -maxdepth 1 -type d \
      | sort -t/ -k1,1 | tail -n 1)
    if [[ -z "$SESSION_DIR" ]]; then
      echo "Error: no session directories found under $CHANGES_DIR" >&2
      echo "  Run a session first, or specify --session=<name>" >&2
      exit 1
    fi
    SESSION_NAME=$(basename "$SESSION_DIR")
  fi

  PATCHES_DIR="$SESSION_DIR/patches"
  if [[ ! -d "$PATCHES_DIR" ]]; then
    echo "Error: patches directory not found: $PATCHES_DIR" >&2
    echo "  Session artefacts were produced by an older harness version." >&2
    echo "  Use: make apply --mode=apply (legacy flat-diff fallback)" >&2
    exit 1
  fi

  mapfile -t PATCHES < <(find "$PATCHES_DIR" -name '*.patch' | sort)
  if [[ "${#PATCHES[@]}" -eq 0 ]]; then
    echo "Error: no .patch files found in $PATCHES_DIR" >&2
    echo "  The session may have produced no commits." >&2
    exit 1
  fi

  # Resolve checkpoint tag
  if [[ ! -f "$CHECKPOINT_REF_FILE" ]]; then
    echo "Error: checkpoint-latest.ref not found: $CHECKPOINT_REF_FILE" >&2
    echo "  Cannot determine base tag for draft branch." >&2
    exit 1
  fi
  CHECKPOINT_TAG=$(cat "$CHECKPOINT_REF_FILE")
  if ! git -C "$PROJECT_DIR" rev-parse --verify "$CHECKPOINT_TAG" >/dev/null 2>&1; then
    echo "Error: checkpoint tag not found in repository: $CHECKPOINT_TAG" >&2
    exit 1
  fi

  # Guard: reject if draft-state already exists
  if [[ -f "$DRAFT_STATE_FILE" ]]; then
    echo "Error: a draft is already in progress." >&2
    echo "  Run 'make confirm' or 'make reject' before starting a new draft." >&2
    echo "  State file: $DRAFT_STATE_FILE" >&2
    exit 1
  fi

  SOURCE_BRANCH=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD)
  WORKING_BRANCH="agent/draft/${SESSION_NAME}"

  echo "Creating draft branch '$WORKING_BRANCH' from $CHECKPOINT_TAG..."
  git -C "$PROJECT_DIR" checkout -b "$WORKING_BRANCH" "$CHECKPOINT_TAG"

  # Apply patches with per-patch author reset
  AUTHOR="$(git -C "$PROJECT_DIR" config user.name) <$(git -C "$PROJECT_DIR" config user.email)>"
  for patch in "${PATCHES[@]}"; do
    echo "Applying: $(basename "$patch")"
    git -C "$PROJECT_DIR" am --3way "$patch"
    git -C "$PROJECT_DIR" commit --amend --author="$AUTHOR" --no-edit
  done

  # Write draft-state
  cat > "$DRAFT_STATE_FILE" <<EOF
SOURCE_BRANCH=${SOURCE_BRANCH}
WORKING_BRANCH=${WORKING_BRANCH}
SESSION_DIR=${SESSION_DIR}
EOF

  echo ""
  echo "Draft ready on branch: $WORKING_BRANCH"
  echo "Review with: git -C '$PROJECT_DIR' log -p HEAD~${#PATCHES[@]}..HEAD"
  echo "Then: make confirm   (or: make reject)"

  exit 0
fi

# -------------------------
# CONFIRM
# -------------------------
if [[ "$COMMAND" == "confirm" ]]; then
  if [[ ! -f "$DRAFT_STATE_FILE" ]]; then
    echo "Error: no draft in progress — draft-state not found: $DRAFT_STATE_FILE" >&2
    echo "  Run 'make draft' first." >&2
    exit 1
  fi

  # Read state
  source "$DRAFT_STATE_FILE"

  MERGE_TARGET="${TARGET_BRANCH:-$SOURCE_BRANCH}"

  if ! git -C "$PROJECT_DIR" rev-parse --verify "$MERGE_TARGET" >/dev/null 2>&1; then
    echo "Error: target branch does not exist: $MERGE_TARGET" >&2
    echo "  Specify a different target: make confirm TARGET=<branch>" >&2
    exit 1
  fi

  echo "Rebasing $WORKING_BRANCH onto $MERGE_TARGET..."
  git -C "$PROJECT_DIR" checkout "$WORKING_BRANCH"
  git -C "$PROJECT_DIR" rebase "$MERGE_TARGET"

  echo "Fast-forward merging $WORKING_BRANCH into $MERGE_TARGET..."
  git -C "$PROJECT_DIR" switch "$MERGE_TARGET"
  git -C "$PROJECT_DIR" merge --ff-only "$WORKING_BRANCH"

  echo "Deleting working branch: $WORKING_BRANCH"
  git -C "$PROJECT_DIR" branch -d "$WORKING_BRANCH"

  rm -f "$DRAFT_STATE_FILE"

  echo ""
  echo "Done. Changes merged into $MERGE_TARGET."
  echo "Session artefacts retained at: $SESSION_DIR"

  exit 0
fi

# -------------------------
# REJECT
# -------------------------
if [[ "$COMMAND" == "reject" ]]; then
  if [[ ! -f "$DRAFT_STATE_FILE" ]]; then
    echo "Error: no draft in progress — draft-state not found: $DRAFT_STATE_FILE" >&2
    exit 1
  fi

  # Read state
  source "$DRAFT_STATE_FILE"

  echo "Rejecting draft. Returning to $SOURCE_BRANCH..."
  git -C "$PROJECT_DIR" checkout "$SOURCE_BRANCH"

  if git -C "$PROJECT_DIR" show-ref --verify --quiet "refs/heads/$WORKING_BRANCH"; then
    git -C "$PROJECT_DIR" branch -D "$WORKING_BRANCH"
    echo "Deleted working branch: $WORKING_BRANCH"
  fi

  rm -f "$DRAFT_STATE_FILE"

  echo "Draft rejected. PROJECT_DIR restored to $SOURCE_BRANCH."
  echo "Session artefacts retained at: $SESSION_DIR"

  exit 0
fi

# -------------------------
# LEGACY — no command (reads from OUTPUT_DIR)
# -------------------------
if [[ -z "$COMMAND" ]]; then
  # Deprecation notice for old --mode=apply flag
  if [[ -n "$MODE" ]]; then
    echo "Error: --mode=apply is deprecated and has been removed." >&2
    echo "  make apply now reads from OUTPUT_DIR by default." >&2
    exit 1
  fi

  # Resolve session directory from OUTPUT_DIR
  if [[ ! -d "$OUTPUT_DIR" ]]; then
    echo "Error: output directory not found: $OUTPUT_DIR" >&2
    echo "  No session artefacts have been produced yet." >&2
    exit 1
  fi

  if [[ -n "$SESSION_ARG" ]]; then
    # Explicit session name provided
    SESSION_DIR="$OUTPUT_DIR/$SESSION_ARG"
    if [[ ! -d "$SESSION_DIR" ]]; then
      echo "Error: session directory not found: $SESSION_DIR" >&2
      echo "  Specify a valid session name or omit SESSION= to use the latest." >&2
      exit 1
    fi
  else
    # Lexicographically last entry in OUTPUT_DIR (by basename sort)
    SESSION_DIR=$(find "$OUTPUT_DIR" -mindepth 1 -maxdepth 1 -type d \
      | sort | tail -n 1)
    if [[ -z "$SESSION_DIR" ]]; then
      echo "Error: no session directories found in $OUTPUT_DIR" >&2
      echo "  Run a session first, or specify SESSION=<name>." >&2
      exit 1
    fi
  fi

  CHANGES_DIFF="$SESSION_DIR/changes.diff"
  if [[ ! -f "$CHANGES_DIFF" ]]; then
    echo "Error: changes.diff not found in session directory: $CHANGES_DIFF" >&2
    echo "  Session artefacts may be incomplete or from an older format." >&2
    exit 1
  fi

  # Print migration guide path if present (operator should read before applying)
  MIGRATION_GUIDE="$SESSION_DIR/migration-guide.md"
  if [[ -f "$MIGRATION_GUIDE" ]]; then
    echo "Migration guide available: $MIGRATION_GUIDE"
    echo "  Review before proceeding."
    echo ""
  fi

  if [[ -n "$APPLY_BRANCH" ]]; then
    if git -C "$PROJECT_DIR" show-ref --verify --quiet "refs/heads/$APPLY_BRANCH"; then
      echo "Checking out existing branch: $APPLY_BRANCH"
      git -C "$PROJECT_DIR" checkout "$APPLY_BRANCH"
    else
      echo "Creating and checking out new branch: $APPLY_BRANCH"
      git -C "$PROJECT_DIR" checkout -b "$APPLY_BRANCH"
    fi
  fi

  echo "Applying changes.diff from $(basename "$SESSION_DIR") to $(git -C "$PROJECT_DIR" branch --show-current)..."
  APPLY_OUTPUT=$(git -C "$PROJECT_DIR" apply --3way "$CHANGES_DIFF" 2>&1) || {
    echo "Error: git apply failed with conflicts." >&2
    echo "$APPLY_OUTPUT" >&2
    echo "" >&2
    echo "Conflicts must be resolved manually." >&2
    exit 1
  }

  # Count changed files from the diff
  FILES_CHANGED=$(grep -c "^diff --git" "$CHANGES_DIFF" || echo "0")

  echo ""
  echo "Done. Files changed: $FILES_CHANGED"
  echo "Review changes and commit manually."
  echo "Session artefacts retained at: $SESSION_DIR"

  exit 0
fi

echo "Unknown command: $COMMAND" >&2
echo "Valid commands: draft, confirm, reject" >&2
exit 1

#!/usr/bin/env bash
# scripts/apply_workspace.sh
#
# Apply workflow for agent-sandbox session artefacts.
#
# Commands:
#   draft   [--project=<path>] [--sandbox=<path>] [--session=<name>]
#             Create a working branch draft/<branch>-<session-ts> from HEAD.
#             Apply all patches via git am --3way with per-patch author reset.
#             Write .workspace/draft-state.
#
#   confirm [--project=<path>] [--sandbox=<path>] [--target=<branch>]
#             Rebase draft branch onto target, fast-forward merge to target,
#             delete working branch (-D, always force-delete), clear draft-state.
#
#   reject  [--project=<path>] [--sandbox=<path>]
#             Checkout SOURCE_BRANCH, delete working branch, clear draft-state.
#
#   apply   [--project=<path>] [--sandbox=<path>] [--session=<n>] [--branch=<n>] [--force]
#             Apply changes.diff from OUTPUT_DIR to PROJECT_DIR using git apply
#             with index lines stripped — context-line matching only, no blob SHA
#             validation, tolerant of index drift and sequential application.
#             No commits created. Operator reviews and commits manually.
#             Reads from reasoning layer output channel (.workspace/output/).
#             --force: apply with --reject; .rej files left for manual resolution.
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
# Resolve paths
# -------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

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
FORCE=false

for ARG in "$@"; do
  case "$ARG" in
    --project=*) PROJECT_DIR="${ARG#--project=}" ;;
    --sandbox=*) SANDBOX_DIR="${ARG#--sandbox=}" ;;
    --session=*) SESSION_ARG="${ARG#--session=}" ;;
    --target=*)  TARGET_BRANCH="${ARG#--target=}" ;;
    --branch=*)  APPLY_BRANCH="${ARG#--branch=}" ;;
    --force)     FORCE=true ;;
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
    echo "  Re-run the session with the current harness to produce format-patch output." >&2
    exit 1
  fi

  mapfile -t PATCHES < <(find "$PATCHES_DIR" -name '*.patch' | sort)
  if [[ "${#PATCHES[@]}" -eq 0 ]]; then
    echo "Error: no .patch files found in $PATCHES_DIR" >&2
    echo "  The session may have produced no commits." >&2
    exit 1
  fi

  # Default to HEAD as the base commit (FROM argument added in Unit E)
  BASE_COMMIT="HEAD"

  # Guard: reject if draft-state already exists
  if [[ -f "$DRAFT_STATE_FILE" ]]; then
    echo "Error: a draft is already in progress." >&2
    echo "  Run 'make confirm' or 'make reject' before starting a new draft." >&2
    echo "  State file: $DRAFT_STATE_FILE" >&2
    exit 1
  fi

  SOURCE_BRANCH=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD)
  # Handle detached HEAD: use short SHA instead of literal "HEAD"
  if [[ "$SOURCE_BRANCH" == "HEAD" ]]; then
    SOURCE_BRANCH=$(git -C "$PROJECT_DIR" rev-parse --short HEAD)
  fi

  WORKING_BRANCH="draft/${SOURCE_BRANCH}-${SESSION_TS}"

  echo "Creating draft branch '$WORKING_BRANCH' from $BASE_COMMIT..."
  git -C "$PROJECT_DIR" checkout -b "$WORKING_BRANCH" "$BASE_COMMIT"

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
  git -C "$PROJECT_DIR" branch -D "$WORKING_BRANCH"

  rm -f "$DRAFT_STATE_FILE"

  echo ""
  echo "Done. Changes merged into $MERGE_TARGET."
  echo "Session artefacts retained at: $SESSION_DIR"

  # SYNC=1: trigger baseline advancement in running container
  # advance_baseline.sh implemented in Change 6
  if [[ "${SYNC:-}" == "1" ]]; then
    # Find container by label
    CONTAINER=$(docker ps --filter "label=agent-sandbox.project-dir=${PROJECT_DIR}" \
      --format '{{.Names}}' | head -n 1)
    if [[ -n "$CONTAINER" ]]; then
      # Validate session name matches
      CONTAINER_SESSION=$(docker inspect --format '{{index .Config.Labels "agent-sandbox.session-name"}}' "$CONTAINER" 2>/dev/null || echo "")
      SESSION_NAME_FROM_STATE=$(basename "$SESSION_DIR")
      if [[ "$CONTAINER_SESSION" != "$SESSION_NAME_FROM_STATE" ]]; then
        echo "Warning: container session ($CONTAINER_SESSION) does not match confirmed session ($SESSION_NAME_FROM_STATE)." >&2
        echo "  Skipping baseline advancement." >&2
      elif docker exec "$CONTAINER" test -f /usr/local/bin/advance_baseline.sh 2>/dev/null; then
        echo "Triggering baseline advancement for session: $SESSION_NAME_FROM_STATE"
        docker exec "$CONTAINER" advance_baseline.sh "$SESSION_NAME_FROM_STATE"
      fi
    fi
    # If no container running, SYNC=1 is silently ignored
  fi

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
# APPLY — reads from OUTPUT_DIR/diffs/
# -------------------------
if [[ "$COMMAND" == "apply" ]]; then
  # Resolve session directory from OUTPUT_DIR/diffs/
  DIFFS_DIR="$OUTPUT_DIR/diffs"

  if [[ ! -d "$DIFFS_DIR" ]]; then
    echo "Error: diffs directory not found: $DIFFS_DIR" >&2
    echo "  No session artefacts have been produced yet." >&2
    exit 1
  fi

  if [[ -n "$SESSION_ARG" ]]; then
    # Explicit session name provided
    SESSION_DIR="$DIFFS_DIR/$SESSION_ARG"
    if [[ ! -d "$SESSION_DIR" ]]; then
      echo "Error: session directory not found: $SESSION_DIR" >&2
      echo "  Specify a valid session name or omit SESSION= to use the latest." >&2
      exit 1
    fi
  else
    # Lexicographically last entry in DIFFS_DIR (by basename sort)
    SESSION_DIR=$(find "$DIFFS_DIR" -mindepth 1 -maxdepth 1 -type d \
      | sort | tail -n 1)
    if [[ -z "$SESSION_DIR" ]]; then
      echo "Error: no session directories found in $DIFFS_DIR" >&2
      echo "  Run a session first, or specify SESSION=<name>." >&2
      exit 1
    fi
  fi

  CHANGES_DIFF="$SESSION_DIR/changes.diff"
  if [[ ! -f "$CHANGES_DIFF" ]]; then
    echo "Error: changes.diff not found in session directory: $CHANGES_DIFF" >&2
    echo "  Session artefacts may be incomplete or from a different version." >&2
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

  if [[ "$FORCE" == true ]]; then
    echo "Force mode enabled: applying with --reject; .rej files will be created for conflicts."
    grep -v '^index ' "$CHANGES_DIFF" | git -C "$PROJECT_DIR" apply --reject || {
      echo "" >&2
      echo "Warning: some hunks failed to apply." >&2
      echo "Review .rej files and resolve manually." >&2
    }
  else
    # Strip index lines before applying — removes blob SHA validation so git apply
    # matches by context lines only. Tolerates index drift and sequential application.
    grep -v '^index ' "$CHANGES_DIFF" | git -C "$PROJECT_DIR" apply || {
      echo "Error: git apply failed." >&2
      echo "" >&2
      echo "Hint: use --force (make apply FORCE=1) to apply with --reject and create .rej files for conflicts." >&2
      exit 1
    }
  fi

  # Count changed files from the diff
  FILES_CHANGED=$(grep -c "^diff --git" "$CHANGES_DIFF" || echo "0")

  echo ""
  echo "Done. Files changed: $FILES_CHANGED"
  if [[ "$FORCE" == true ]]; then
    echo "Force mode: check for .rej files and resolve any failed hunks."
  else
    echo "Review changes and commit manually."
  fi
  echo "Session artefacts retained at: $SESSION_DIR"

  exit 0
fi

# -------------------------
# SYNC
# -------------------------
if [[ "$COMMAND" == "sync" ]]; then
  # Find container by label
  CONTAINER=$(docker ps --filter "label=agent-sandbox.project-dir=${PROJECT_DIR}" \
    --format '{{.Names}}' | head -n 1)
  if [[ -z "$CONTAINER" ]]; then
    echo "Error: no running container found for project: $PROJECT_DIR" >&2
    echo "  Start a session first, or run 'make start'." >&2
    exit 1
  fi

  # advance_baseline.sh implemented in Change 6
  if docker exec "$CONTAINER" test -f /usr/local/bin/advance_baseline.sh 2>/dev/null; then
    echo "Triggering baseline advancement for all unadvanced sessions..."
    docker exec "$CONTAINER" advance_baseline.sh --all
  else
    echo "Note: advance_baseline.sh not yet implemented (Change 6)."
    echo "  Container is running but cannot advance baseline yet."
  fi

  exit 0
fi

echo "Unknown command: $COMMAND" >&2
echo "Valid commands: draft, confirm, reject, apply, sync" >&2
exit 1

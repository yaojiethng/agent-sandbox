#!/usr/bin/env bash
# scripts/apply_workspace.sh
#
# Apply workflow for agent-sandbox session artefacts.
#
# Commands:
#   draft   [--project=<path>] [--sandbox=<path>] [--session=<path>] [--branch-from=<hash>]
#             [--diffs=<start>..<end>] [--branch-summary=<slug>]
#             Create a working branch draft/<export_time>-<session_ts>-<branch>-<sha6> from HEAD.
#             Apply numbered diffs from the resolved export folder via git apply (index stripped),
#             staging and committing each. The first commit on the branch is .draft-state.
#             Resolves latest export from $CHANGES_DIR/ by lexicographic sort unless --session
#             specifies an explicit path.
#
#   confirm [--project=<path>] [--sandbox=<path>] [--target=<branch>]
#             Read .draft-state from the draft branch. Rebase onto target,
#             fast-forward merge to target, delete working branch, clear draft-state.
#
#   reject  [--project=<path>] [--sandbox=<path>]
#             Read source_branch from .draft-state on the draft branch.
#             Checkout source branch, delete working branch, clear draft-state.
#
#   apply   [--project=<path>] [--sandbox=<path>] [--session=<n>] [--branch=<n>] [--diff=<path>] [--force]
#             Apply changes.diff from OUTPUT_DIR to PROJECT_DIR using git apply
#             with index lines stripped — context-line matching only, no blob SHA
#             validation, tolerant of index drift and sequential application.
#             No commits created. Operator reviews and commits manually.
#             Reads from reasoning layer output channel (.workspace/output/).
#             --diff=<path>: apply specific diff file instead of resolving from OUTPUT_DIR.
#             --force: apply with --reject; .rej files left for manual resolution.
#
# .draft-state format (committed as first commit on draft branch):
#   source_branch: <branch>
#   from_hash: <sha>
#   author: <name> <email>
#   session_ts: <YYYYMMDD-HHMMSS>
#   host_branch: <sanitized-branch-name>
#   diff_count: <n>
#   exported-at: <YYYYMMDD-HHMMSS>
#   drafted-at: <YYYYMMDD-HHMMSS>
#
# Legacy backward-compat:
#   $WORKSPACE_DIR/draft-state file is also written for F2 transition.
#
# Cleanup policy:
#   OUTPUT_DIR is not cleared automatically. Operator clears manually between sessions if desired.

set -euo pipefail

# -------------------------
# Resolve paths
# -------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source shared draft utilities
source "$REPO_ROOT/libs/draft.sh"

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
DIFF_ARG=""
BRANCH_FROM_ARG=""
DIFFS_ARG=""
BRANCH_SUMMARY=""
FORCE=false

for ARG in "$@"; do
  case "$ARG" in
    --project=*)     PROJECT_DIR="${ARG#--project=}" ;;
    --sandbox=*)     SANDBOX_DIR="${ARG#--sandbox=}" ;;
    --session=*)     SESSION_ARG="${ARG#--session=}" ;;
    --target=*)      TARGET_BRANCH="${ARG#--target=}" ;;
    --branch=*)      APPLY_BRANCH="${ARG#--branch=}" ;;
    --diff=*)        DIFF_ARG="${ARG#--diff=}" ;;
    --branch-from=*) BRANCH_FROM_ARG="${ARG#--branch-from=}" ;;
    --diffs=*)       DIFFS_ARG="${ARG#--diffs=}" ;;
    --branch-summary=*) BRANCH_SUMMARY="${ARG#--branch-summary=}" ;;
    --force)         FORCE=true ;;
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

  # Resolve target export folder
  if [[ -n "$SESSION_ARG" ]]; then
    # Explicit path override — can be any folder, including $OUTPUT_DIR/bundles/
    EXPORT_DIR="$SESSION_ARG"
    if [[ ! -d "$EXPORT_DIR" ]]; then
      echo "Error: session directory not found: $EXPORT_DIR" >&2
      exit 1
    fi
  else
    # Default: latest export from $CHANGES_DIR/ by lexicographic sort
    if [[ ! -d "$CHANGES_DIR" ]]; then
      echo "Error: changes directory not found: $CHANGES_DIR" >&2
      exit 1
    fi
    EXPORT_DIR=$(draft_resolve_latest_export "$CHANGES_DIR") || exit 1
  fi

  # Parse session identity from folder name
  EXPORT_BASENAME=$(basename "$EXPORT_DIR")
  draft_parse_folder_name "$EXPORT_BASENAME"

  # Collect diff files
  mapfile -t DIFF_FILES < <(find "$EXPORT_DIR" -maxdepth 1 -name '*.diff' | sort)
  if [[ "${#DIFF_FILES[@]}" -eq 0 ]]; then
    echo "Error: no .diff files found in $EXPORT_DIR" >&2
    echo "  The session may have produced no commits." >&2
    exit 1
  fi

  # Apply optional DIFFS range filter
  if [[ -n "$DIFFS_ARG" ]]; then
    START_NUM=$(echo "$DIFFS_ARG" | cut -d. -f1)
    END_NUM=$(echo "$DIFFS_ARG" | cut -d. -f3)
    if [[ -z "$START_NUM" || -z "$END_NUM" ]]; then
      echo "Error: invalid DIFFS range format: $DIFFS_ARG" >&2
      echo "  Expected: <start>..<end> (e.g. 2..4)" >&2
      exit 1
    fi
    FILTERED_DIFFS=()
    for df in "${DIFF_FILES[@]}"; do
      BASENAME=$(basename "$df")
      NUM="${BASENAME%%-*}"
      if [[ "$NUM" =~ ^[0-9]+$ ]]; then
        NUM_INT=$((10#$NUM))
        if [[ "$NUM_INT" -ge "$START_NUM" && "$NUM_INT" -le "$END_NUM" ]]; then
          FILTERED_DIFFS+=("$df")
        fi
      fi
    done
    if [[ "${#FILTERED_DIFFS[@]}" -eq 0 ]]; then
      echo "Error: no diffs in range $DIFFS_ARG found in $EXPORT_DIR" >&2
      exit 1
    fi
    DIFF_FILES=("${FILTERED_DIFFS[@]}")
  fi

  # Resolve base commit and source branch
  BASE_COMMIT="${BRANCH_FROM_ARG:-HEAD}"
  SOURCE_BRANCH=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD)
  if [[ "$SOURCE_BRANCH" == "HEAD" ]]; then
    SOURCE_BRANCH=$(git -C "$PROJECT_DIR" rev-parse --short HEAD)
  fi
  FROM_HASH=$(git -C "$PROJECT_DIR" rev-parse "$BASE_COMMIT")
  FROM_SHA6="${FROM_HASH:0:6}"

  # Compute branch slug
  if [[ -n "$BRANCH_SUMMARY" ]]; then
    BRANCH_SLUG="$BRANCH_SUMMARY"
  else
    BRANCH_SLUG="$SANITIZED_HOST_BRANCH"
  fi

  # Compute draft branch name
  WORKING_BRANCH="draft/${EXPORT_TIME}-${SESSION_TS}-${BRANCH_SLUG}-${FROM_SHA6}"

  # Guard: same-name collision only
  draft_guard_no_collision "$PROJECT_DIR" "$WORKING_BRANCH" || exit 1

  # Author for commits
  AUTHOR="$(git -C "$PROJECT_DIR" config user.name) <$(git -C "$PROJECT_DIR" config user.email)>"

  # Create draft branch
  echo "Creating draft branch '$WORKING_BRANCH' from ${FROM_HASH:0:7}..."
  git -C "$PROJECT_DIR" checkout -b "$WORKING_BRANCH" "$BASE_COMMIT"

  # Write .draft-state and commit it as the first commit on the branch
  DRAFTED_AT=$(date -u +%Y%m%d-%H%M%S)
  DRAFT_STATE_CONTENT=$(draft_write_state \
    "$SOURCE_BRANCH" \
    "$FROM_HASH" \
    "$AUTHOR" \
    "$SESSION_TS" \
    "$SANITIZED_HOST_BRANCH" \
    "${#DIFF_FILES[@]}" \
    "$EXPORT_TIME" \
    "$DRAFTED_AT")

  echo "$DRAFT_STATE_CONTENT" > "$PROJECT_DIR/.draft-state"
  git -C "$PROJECT_DIR" add .draft-state
  git -C "$PROJECT_DIR" commit -m ".draft-state" --author="$AUTHOR"

  # Apply diffs sequentially with git apply (index lines stripped), stage, and commit
  for diff_file in "${DIFF_FILES[@]}"; do
    echo "Applying: $(basename "$diff_file")"
    grep -v '^index ' "$diff_file" | git -C "$PROJECT_DIR" apply
    git -C "$PROJECT_DIR" add -A
    git -C "$PROJECT_DIR" commit -m "Apply $(basename "$diff_file")" --author="$AUTHOR"
  done

  # Backward-compat: write legacy draft-state file for F2 transition
  cat > "$DRAFT_STATE_FILE" <<EOF
SOURCE_BRANCH=${SOURCE_BRANCH}
WORKING_BRANCH=${WORKING_BRANCH}
SESSION_DIR=${EXPORT_DIR}
EOF

  # Operator hint
  echo ""
  echo "Draft branch created: $WORKING_BRANCH"
  echo "Export: $EXPORT_DIR"
  echo "Diffs applied: ${#DIFF_FILES[@]}"
  echo "Branch point: ${FROM_HASH:0:7}"
  echo ""
  echo "Shape your commits, then confirm:"
  echo ""
  echo "  git rebase -i ${SOURCE_BRANCH}"
  echo "  make confirm [TARGET=${SOURCE_BRANCH}]"
  echo ""
  echo "To discard: make reject"

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
      # Validate session identity matches
      CONTAINER_SESSION_TS=$(docker inspect --format '{{index .Config.Labels "agent-sandbox.session-ts"}}' "$CONTAINER" 2>/dev/null || echo "")
      CONTAINER_HOST_BRANCH=$(docker inspect --format '{{index .Config.Labels "agent-sandbox.host-branch"}}' "$CONTAINER" 2>/dev/null || echo "")
      SESSION_ID_FROM_DIR=$(basename "$SESSION_DIR")
      # Directory name format: <EXPORT_TIME>-<SANITIZED_HOST_BRANCH>-<SESSION_TS>
      # Both CONTAINER_SESSION_TS and CONTAINER_HOST_BRANCH must appear in the dir name
      if [[ -n "$CONTAINER_SESSION_TS" && "$SESSION_ID_FROM_DIR" != *"$CONTAINER_SESSION_TS"* ]] \
         || [[ -n "$CONTAINER_HOST_BRANCH" && "$SESSION_ID_FROM_DIR" != *"$CONTAINER_HOST_BRANCH"* ]]; then
        echo "Warning: container session identity does not match confirmed session directory." >&2
        echo "  Container: session-ts=$CONTAINER_SESSION_TS host-branch=$CONTAINER_HOST_BRANCH" >&2
        echo "  Directory: $SESSION_ID_FROM_DIR" >&2
        echo "  Skipping baseline advancement." >&2
      elif docker exec "$CONTAINER" test -f /usr/local/bin/advance_baseline.sh 2>/dev/null; then
        echo "Triggering baseline advancement for session: $SESSION_ID_FROM_DIR"
        docker exec "$CONTAINER" advance_baseline.sh "$SESSION_ID_FROM_DIR"
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
  CHANGES_DIFF=""
  SESSION_DIR=""

  if [[ -n "$DIFF_ARG" ]]; then
    # Explicit diff path provided
    CHANGES_DIFF="$DIFF_ARG"
    if [[ ! -f "$CHANGES_DIFF" ]]; then
      echo "Error: diff file not found: $CHANGES_DIFF" >&2
      exit 1
    fi
    SESSION_DIR=$(dirname "$CHANGES_DIFF")
  else
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

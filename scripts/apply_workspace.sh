#!/usr/bin/env bash
# scripts/apply_workspace.sh
#
# Apply workflow for agent-sandbox session artefacts.
#
# Commands:
#   draft   [--project=<path>] [--sandbox=<path>] [--session=<name|path>] [--branch-from=<hash>]
#             [--diffs=<start>..<end>] [--branch-summary=<slug>]
#             Create a working branch draft/<session_ts>-<branch>-<sha6> from HEAD.
#             Apply numbered diffs from the resolved session folder via git apply
#             (index stripped), staging and committing each. The first commit on
#             the branch is .draft-state.
#
#             --session=<path> - absolute path used as-is (must contain session/patches/
#               with numbered .diff files); relative path resolved under $CHANGES_DIR/.
#             No --session - auto-resolve: find the latest session directory with a
#               valid session/ subfolder. If none found, error with helpful hints.
#
#   confirm [--project=<path>] [--sandbox=<path>] [--target=<branch>]
#             Read .draft-state from the draft branch. Rebase onto target,
#             fast-forward merge to target, delete working branch, clear draft-state.
#
#   reject  [--project=<path>] [--sandbox=<path>]
#             Read source_branch from .draft-state on the draft branch.
#             Checkout source branch, delete working branch, clear draft-state.
#
#   apply   [--project=<path>] [--sandbox=<path>] [--session=<name|path>] [--branch=<n>] [--diff=<path>] [--force]
#             Apply changes.diff from OUTPUT_DIR to PROJECT_DIR using git apply
#             with index lines stripped — context-line matching only, no blob SHA
#             validation, tolerant of index drift and sequential application.
#             No commits created. Operator reviews and commits manually.
#             Reads from reasoning layer output channel (.workspace/output/diffs/).
#             --session=<name> resolves relative under $OUTPUT_DIR/diffs/; --session=<absolute-path>
#             uses the path directly (no $OUTPUT_DIR/diffs/ required).
#             Resolves changes.diff: flat path first, then session/changes.diff,
#             then autosave/changes.diff.
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
  echo "Error: $PROJECT_DIR has no commits - cannot apply patch" >&2
  exit 1
fi

# -------------------------
# DRAFT
# -------------------------
if [[ "$COMMAND" == "draft" ]]; then

  # Determine the patches directory to use.
  # --session can point to:
  #   1. A session top-level dir (e.g. .../session-diffs/20260420-120000-main)
  #      → we look for session/patches/ inside it
  #   2. A subfolder directly (e.g. .../session-diffs/20260420-120000-main/session
  #      or .../session-diffs/20260420-120000-main/autosave)
  #      → we look for patches/ inside it
  #   3. No --session → auto-resolve to latest session with valid session/patches/
  if [[ -n "$SESSION_ARG" ]]; then
    # Explicit path - absolute used as-is; relative resolved under $CHANGES_DIR
    if [[ "$SESSION_ARG" == /* ]]; then
      SESSION_PATH="$SESSION_ARG"
    else
      SESSION_PATH="$CHANGES_DIR/$SESSION_ARG"
    fi
    if [[ ! -d "$SESSION_PATH" ]]; then
      echo "Error: session path not found: $SESSION_PATH" >&2
      echo "  Relative paths resolve under: $CHANGES_DIR" >&2
      if [[ -d "$CHANGES_DIR" ]]; then
        echo "  Available sessions:" >&2
        ls -1 "$CHANGES_DIR" >&2 2>/dev/null || echo "    (none)" >&2
      fi
      exit 1
    fi

    # Determine if SESSION_PATH points to a top-level session dir or a subfolder
    if [[ -d "$SESSION_PATH/session/patches" ]]; then
      # Top-level session dir → use session/patches/
      EXPORT_DIR="$SESSION_PATH"
      PATCHES_DIR="$SESSION_PATH/session/patches"
      echo "Using session: $SESSION_PATH (session/patches/)"
    elif [[ -d "$SESSION_PATH/patches" ]]; then
      # Subfolder (session/ or autosave/) → use patches/ inside it
      PATCHES_DIR="$SESSION_PATH/patches"
      # Walk up to get the session top-level dir for folder name parsing
      EXPORT_DIR="$(dirname "$SESSION_PATH")"
      echo "Using session: $SESSION_PATH (patches/)"
    else
      echo "Error: no patches/ directory found in $SESSION_PATH" >&2
      echo "  Expected: $SESSION_PATH/session/patches/ or $SESSION_PATH/patches/" >&2
      exit 1
    fi
  else
    # Auto-resolve: find the latest session directory with a valid session/ subfolder
    if [[ ! -d "$CHANGES_DIR" ]]; then
      echo "Error: changes directory not found: $CHANGES_DIR" >&2
      echo "  Expected: $CHANGES_DIR/<timestamp>-<branch>/session/patches/" >&2
      exit 1
    fi

    LATEST_SESSION=""
    LATEST_WITH_AUTOSAVE=""

    # Iterate session dirs from newest to oldest (lexicographic reverse)
    while IFS= read -r CANDIDATE; do
      [[ -z "$CANDIDATE" ]] && continue

      # Check if this candidate has a session/patches/ directory with diffs
      if [[ -d "$CANDIDATE/session/patches" ]] && \
         ls "$CANDIDATE/session/patches/"*.diff >/dev/null 2>&1; then
        LATEST_SESSION="$CANDIDATE"
        break  # Found the newest valid session - done
      fi

      # Track latest directory with autosave only (for error messaging)
      # Only set if we haven't found a valid session yet - since we iterate
      # newest-to-oldest, this captures any directory that has autosave/ but
      # not session/patches/ above the newest valid session.
      if [[ -z "$LATEST_WITH_AUTOSAVE" ]] && [[ -d "$CANDIDATE/autosave" ]]; then
        LATEST_WITH_AUTOSAVE="$CANDIDATE"
      fi
    done < <(find "$CHANGES_DIR" -mindepth 1 -maxdepth 1 -type d | sort -r)

    if [[ -n "$LATEST_SESSION" ]]; then
      EXPORT_DIR="$LATEST_SESSION"
      PATCHES_DIR="$LATEST_SESSION/session/patches"
      echo "Auto-resolved session: $LATEST_SESSION"
    else
      # No valid session found - produce helpful error
      echo "Error: no completed session found in $CHANGES_DIR" >&2
      echo "  Contents:" >&2
      ls -1 "$CHANGES_DIR" >&2 2>/dev/null || echo "    (empty or unreadable)" >&2
      if [[ -n "$LATEST_WITH_AUTOSAVE" ]]; then
        echo "  Autosave checkpoint(s) found but no completed session." >&2
        echo "  Latest autosave: $LATEST_WITH_AUTOSAVE/autosave/" >&2
        echo "  Run again with --session=<path-to-autosave> to apply autosave diffs." >&2
      fi
      exit 1
    fi
  fi

  # Parse session identity from folder name
  EXPORT_BASENAME=$(basename "$EXPORT_DIR")
  draft_parse_folder_name "$EXPORT_BASENAME"

  # Read EXPORT_TIME from session/EXPORT-TIME.txt
  EXPORT_TIME=$(draft_read_export_time "$EXPORT_DIR")
  if [[ -z "$EXPORT_TIME" ]]; then
    EXPORT_TIME="unknown"
  fi

  # Collect numbered diff files from the resolved patches directory
  mapfile -t DIFF_FILES < <(find "$PATCHES_DIR" -maxdepth 1 -name '[0-9][0-9][0-9][0-9]*.diff' | sort)
  if [[ "${#DIFF_FILES[@]}" -eq 0 ]]; then
    echo "Error: no .diff files found in $PATCHES_DIR" >&2
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
      BNAME=$(basename "$df")
      NUM="${BNAME%%-*}"
      if [[ "$NUM" =~ ^[0-9]+$ ]]; then
        NUM_INT=$((10#$NUM))
        if [[ "$NUM_INT" -ge "$START_NUM" && "$NUM_INT" -le "$END_NUM" ]]; then
          FILTERED_DIFFS+=("$df")
        fi
      fi
    done
    if [[ "${#FILTERED_DIFFS[@]}" -eq 0 ]]; then
      echo "Error: no diffs in range $DIFFS_ARG found in $PATCHES_DIR" >&2
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

  # Compute draft branch name: draft/<SESSION_TS>-<BRANCH>-<SHA6>
  WORKING_BRANCH="draft/${SESSION_TS}-${BRANCH_SLUG}-${FROM_SHA6}"

  # Guard: don't allow drafting from a draft branch
  CURRENT_BRANCH=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD)
  if [[ "$CURRENT_BRANCH" == draft/* ]]; then
    echo "Error: already on a draft branch: $CURRENT_BRANCH" >&2
    echo "  Run 'make reject' or 'make confirm' first." >&2
    exit 1
  fi

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
  # Use process substitution to avoid SIGPIPE from grep in a pipeline (set -euo pipefail)
  echo "Patches directory: $PATCHES_DIR"
  echo "Applying ${#DIFF_FILES[@]} diffs..."
  for diff_file in "${DIFF_FILES[@]}"; do
    echo "  Applying: $(basename "$diff_file")"
    if ! git -C "$PROJECT_DIR" apply < <(grep -v '^index ' "$diff_file"); then
      echo "Error: failed to apply $(basename "$diff_file")" >&2
      echo "  Patch file: $diff_file" >&2
      git -C "$PROJECT_DIR" diff --stat HEAD >&2 || true
      exit 1
    fi
    git -C "$PROJECT_DIR" add -A
    git -C "$PROJECT_DIR" commit -m "Apply $(basename "$diff_file")" --author="$AUTHOR"
  done

  # Operator hint
  echo ""
  echo "Draft branch created: $WORKING_BRANCH"
  echo "Session: $EXPORT_DIR"
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
  # Validate we're on a proper draft branch; read .draft-state into caller scope
  eval "$(draft_validate_branch "$PROJECT_DIR")" || exit 1

  MERGE_TARGET="${TARGET_BRANCH:-$source_branch}"

  if ! git -C "$PROJECT_DIR" rev-parse --verify "$MERGE_TARGET" >/dev/null 2>&1; then
    echo "Error: target branch does not exist: $MERGE_TARGET" >&2
    echo "  Specify a different target: make confirm TARGET=<branch>" >&2
    exit 1
  fi

  # 1. Drop .draft-state commit
  # Process substitution avoids SIGPIPE from head in a pipeline (set -euo pipefail)
  read -r DRAFT_STATE_COMMIT < <(git -C "$PROJECT_DIR" rev-list "${from_hash}..${CURRENT_BRANCH}" --reverse)
  echo "Dropping .draft-state commit..."
  if ! git -C "$PROJECT_DIR" rebase --onto "${DRAFT_STATE_COMMIT}^" "$DRAFT_STATE_COMMIT" "$CURRENT_BRANCH"; then
    echo "Error: failed to drop .draft-state commit" >&2
    exit 1
  fi

  # 2. Rebase draft onto target
  echo "Rebasing $CURRENT_BRANCH onto $MERGE_TARGET..."
  if ! git -C "$PROJECT_DIR" rebase "$MERGE_TARGET" "$CURRENT_BRANCH"; then
    echo ""
    echo "Conflict rebasing $CURRENT_BRANCH onto $MERGE_TARGET."
    echo ""
    echo "Resolve conflicts, then run:"
    echo ""
    echo "  git rebase --continue          # after resolving each conflict"
    echo "  make confirm                   # retry the merge once rebase is clean"
    echo ""
    echo "To abort and return to the draft branch:"
    echo ""
    echo "  git rebase --abort"
    echo "  make confirm                   # retry from scratch once draft is ready"
    echo ""
    echo "To discard the draft entirely:"
    echo ""
    echo "  git rebase --abort"
    echo "  make reject"
    exit 1
  fi

  # 3. Fast-forward merge
  echo "Fast-forward merging $CURRENT_BRANCH into $MERGE_TARGET..."
  git -C "$PROJECT_DIR" switch "$MERGE_TARGET"
  git -C "$PROJECT_DIR" merge --ff-only "$CURRENT_BRANCH"

  # 4. Delete draft branch
  echo "Deleting draft branch: $CURRENT_BRANCH"
  git -C "$PROJECT_DIR" branch -D "$CURRENT_BRANCH"

  echo ""
  echo "Done. Changes merged into $MERGE_TARGET."

  exit 0
fi

# -------------------------
# REJECT
# -------------------------
if [[ "$COMMAND" == "reject" ]]; then
  # Validate we're on a proper draft branch; read .draft-state into caller scope
  eval "$(draft_validate_branch "$PROJECT_DIR")" || exit 1

  echo "Rejecting draft. Returning to $source_branch..."
  git -C "$PROJECT_DIR" checkout "$source_branch"

  if git -C "$PROJECT_DIR" show-ref --verify --quiet "refs/heads/$CURRENT_BRANCH" 2>/dev/null; then
    git -C "$PROJECT_DIR" branch -D "$CURRENT_BRANCH"
    echo "Deleted draft branch: $CURRENT_BRANCH"
  fi

  echo "Draft rejected. PROJECT_DIR restored to $source_branch."

  exit 0
fi

# -------------------------
# APPLY — reads from OUTPUT_DIR/diffs/
# -------------------------
if [[ "$COMMAND" == "apply" ]]; then
  CHANGES_DIFF=""
  SESSION_DIR=""

  if [[ -n "$DIFF_ARG" ]]; then
    # Explicit diff path provided — no session resolution needed
    CHANGES_DIFF="$DIFF_ARG"
    if [[ ! -f "$CHANGES_DIFF" ]]; then
      echo "Error: diff file not found: $CHANGES_DIFF" >&2
      exit 1
    fi
    SESSION_DIR=$(dirname "$CHANGES_DIFF")
  else
    # Resolve session directory from OUTPUT_DIR/diffs/
    DIFFS_DIR="$OUTPUT_DIR/diffs"

    if [[ -n "$SESSION_ARG" ]]; then
      # Explicit session path — absolute used as-is; relative resolved under $DIFFS_DIR
      if [[ "$SESSION_ARG" == /* ]]; then
        SESSION_DIR="$SESSION_ARG"
        # Absolute paths do not require $DIFFS_DIR to exist
      else
        # Relative path — must have $DIFFS_DIR
        if [[ ! -d "$DIFFS_DIR" ]]; then
          echo "Error: diffs directory not found: $DIFFS_DIR" >&2
          echo "  No session artefacts have been produced yet." >&2
          exit 1
        fi
        SESSION_DIR="$DIFFS_DIR/$SESSION_ARG"
      fi
      if [[ ! -d "$SESSION_DIR" ]]; then
        echo "Error: session directory not found: $SESSION_DIR" >&2
        if [[ "$SESSION_ARG" != /* ]]; then
          echo "  Relative paths resolve under: $DIFFS_DIR" >&2
        fi
        echo "  Specify a valid session name or use an absolute path." >&2
        exit 1
      fi
    else
      # Auto-resolve: lexicographically last entry in DIFFS_DIR
      if [[ ! -d "$DIFFS_DIR" ]]; then
        echo "Error: diffs directory not found: $DIFFS_DIR" >&2
        echo "  Expected: $DIFFS_DIR/<session>/changes.diff" >&2
        echo "  No session artefacts have been produced yet." >&2
        exit 1
      fi

      SESSION_DIR=$(find "$DIFFS_DIR" -mindepth 1 -maxdepth 1 -type d \
        | sort | tail -n 1)
      if [[ -z "$SESSION_DIR" ]]; then
        echo "Error: no session directories found in $DIFFS_DIR" >&2
        echo "  Run a session first, or specify SESSION=<name>." >&2
        exit 1
      fi
    fi

    # Resolve changes.diff: try flat, then session/, then autosave/
    CHANGES_DIFF=""
    if [[ -f "$SESSION_DIR/changes.diff" ]]; then
      CHANGES_DIFF="$SESSION_DIR/changes.diff"
    elif [[ -f "$SESSION_DIR/session/changes.diff" ]]; then
      CHANGES_DIFF="$SESSION_DIR/session/changes.diff"
    elif [[ -f "$SESSION_DIR/autosave/changes.diff" ]]; then
      CHANGES_DIFF="$SESSION_DIR/autosave/changes.diff"
    else
      echo "Error: changes.diff not found in session directory: $SESSION_DIR" >&2
      echo "  Tried: $SESSION_DIR/changes.diff" >&2
      echo "        $SESSION_DIR/session/changes.diff" >&2
      echo "        $SESSION_DIR/autosave/changes.diff" >&2
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

  echo "Applying $CHANGES_DIFF to $(git -C "$PROJECT_DIR" branch --show-current)..."

  if [[ "$FORCE" == true ]]; then
    echo "Force mode enabled: applying with --reject; .rej files will be created for conflicts."
    if ! git -C "$PROJECT_DIR" apply --reject < <(grep -v '^index ' "$CHANGES_DIFF"); then
      echo "" >&2
      echo "Warning: some hunks failed to apply." >&2
      echo "Review .rej files and resolve manually." >&2
    fi
  else
    # Strip index lines before applying - removes blob SHA validation so git apply
    # matches by context lines only. Tolerates index drift and sequential application.
    # Uses process substitution to avoid SIGPIPE from grep in a pipeline (set -euo pipefail).
    if ! git -C "$PROJECT_DIR" apply < <(grep -v '^index ' "$CHANGES_DIFF"); then
      echo "Error: git apply failed." >&2
      echo "  Diff file: $CHANGES_DIFF" >&2
      echo "  Target branch: $(git -C "$PROJECT_DIR" branch --show-current)" >&2
      echo "" >&2
      echo "Hint: use --force (make apply FORCE=1) to apply with --reject and create .rej files for conflicts." >&2
      exit 1
    fi
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

echo "Unknown command: $COMMAND" >&2
echo "Valid commands: draft, confirm, reject, apply" >&2
exit 1
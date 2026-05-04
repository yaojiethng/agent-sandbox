#!/usr/bin/env bash
# libs/draft_workflow.sh
#
# Draft branch lifecycle workflow: draft, confirm, reject.
# Sourced by agent-sandbox.sh — not executed standalone.
#
# Depends on: libs/session.sh, git, standard shell utilities.

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/session.sh"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/routing.sh"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/diff.sh"

# =============================================================================
# Internal helpers (absorbed from libs/draft.sh)
# =============================================================================

# Find the lexicographically last directory entry under BASE_DIR.
draft_resolve_latest_export() {
  local BASE_DIR="$1"
  if [[ ! -d "$BASE_DIR" ]]; then
    echo "Error: directory not found: $BASE_DIR" >&2
    return 1
  fi

  local LATEST
  LATEST=$(find "$BASE_DIR" -mindepth 1 -maxdepth 1 -type d | sort | tail -n 1)
  if [[ -z "$LATEST" ]]; then
    echo "Error: no export folders found under $BASE_DIR" >&2
    return 1
  fi
  echo "$LATEST"
}

# Parse folder name format: <SESSION_TS>-<SANITIZED_HOST_BRANCH>
draft_parse_folder_name() {
  local BASENAME="$1"
  SESSION_TS="${BASENAME:0:15}"
  SANITIZED_HOST_BRANCH="${BASENAME:16}"
}

# Read EXPORT-TIME.txt from session directory.
draft_read_export_time() {
  local SESSION_DIR="$1"
  local EXPORT_TIME_FILE="${SESSION_DIR}/session/EXPORT-TIME.txt"
  if [[ -f "$EXPORT_TIME_FILE" ]]; then
    head -n 1 "$EXPORT_TIME_FILE"
  else
    echo ""
  fi
}

# Abort if a draft branch with the exact name already exists.
draft_guard_no_collision() {
  local PROJECT_DIR="$1"
  local BRANCH_NAME="$2"
  if git -C "$PROJECT_DIR" show-ref --verify --quiet "refs/heads/$BRANCH_NAME" 2>/dev/null; then
    echo "Error: draft branch already exists: $BRANCH_NAME" >&2
    echo "  Run 'make reject' to discard it, or use a different BRANCH_SUMMARY." >&2
    return 1
  fi
}

# Produce .draft-state content string; caller writes to file or commits.
draft_write_state() {
  local SOURCE_BRANCH="$1"
  local FROM_HASH="$2"
  local AUTHOR="$3"
  local SESSION_TS="$4"
  local HOST_BRANCH="$5"
  local DIFF_COUNT="$6"
  local EXPORTED_AT="$7"
  local DRAFTED_AT="$8"

  cat <<EOF
source_branch: ${SOURCE_BRANCH}
from_hash: ${FROM_HASH}
author: ${AUTHOR}
session_ts: ${SESSION_TS}
host_branch: ${HOST_BRANCH}
diff_count: ${DIFF_COUNT}
exported-at: ${EXPORTED_AT}
drafted-at: ${DRAFTED_AT}
EOF
}

# Read .draft-state from the tip of the given branch.
# Prints shell variable assignments to stdout for eval by caller.
draft_read_state_from_branch() {
  local PROJECT_DIR="$1"
  local BRANCH_NAME="$2"

  if ! git -C "$PROJECT_DIR" show-ref --verify --quiet "refs/heads/$BRANCH_NAME" 2>/dev/null; then
    echo "Error: branch does not exist: $BRANCH_NAME" >&2
    return 1
  fi

  local STATE_CONTENT
  STATE_CONTENT=$(git -C "$PROJECT_DIR" show "${BRANCH_NAME}:.draft-state" 2>/dev/null) || {
    echo "Error: .draft-state not found on branch: $BRANCH_NAME" >&2
    return 1
  }

  while IFS=':' read -r KEY VALUE; do
    [[ -z "$KEY" ]] && continue
    KEY=$(echo "$KEY" | tr -d ' ' | tr '-' '_')
    VALUE=$(echo "$VALUE" | sed 's/^ *//')
    printf '%s="%s"\n' "$KEY" "$VALUE"
  done <<< "$STATE_CONTENT"
}

# Validate current branch is a proper draft branch.
# On success: prints variable assignments (including CURRENT_BRANCH) and returns 0.
# On failure: prints error to stderr and returns 1.
draft_validate_branch() {
  local PROJECT_DIR="$1"

  local CURRENT_BRANCH
  CURRENT_BRANCH=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null) || {
    echo "Error: not in a git repository" >&2
    return 1
  }

  if [[ "$CURRENT_BRANCH" != draft/* ]]; then
    echo "Error: not on a draft branch (current: $CURRENT_BRANCH)" >&2
    return 1
  fi

  local STATE_CONTENT
  STATE_CONTENT=$(git -C "$PROJECT_DIR" show "${CURRENT_BRANCH}:.draft-state" 2>/dev/null) || {
    echo "Error: .draft-state not found on branch: $CURRENT_BRANCH" >&2
    return 1
  }

  while IFS=':' read -r KEY VALUE; do
    [[ -z "$KEY" ]] && continue
    KEY=$(echo "$KEY" | tr -d ' ' | tr '-' '_')
    VALUE=$(echo "$VALUE" | sed 's/^ *//')
    printf -v "$KEY" '%s' "$VALUE"
    printf '%s="%s"\n' "$KEY" "$VALUE"
  done <<< "$STATE_CONTENT"

  if [[ -z "${from_hash:-}" ]]; then
    echo "Error: .draft-state on $CURRENT_BRANCH is missing 'from_hash' field" >&2
    return 1
  fi

  # Find .draft-state commit by message — it may not be the first commit after
  # from_hash if the user ran git rebase -i (which is the recommended workflow
  # for shaping commits before confirm).
  local DRAFT_STATE_COMMIT
  DRAFT_STATE_COMMIT=$(git -C "$PROJECT_DIR" log "${from_hash}..${CURRENT_BRANCH}" --reverse --format="%H" --grep="^\.draft-state$" 2>/dev/null | head -1)

  if [[ -z "$DRAFT_STATE_COMMIT" ]]; then
    echo "Warning: .draft-state commit not found between ${from_hash:0:7}..${CURRENT_BRANCH}" >&2
    echo "  The commit may have been dropped during rebase. Skipping drop step." >&2
    echo "DRAFT_STATE_COMMIT="
  else
    echo "DRAFT_STATE_COMMIT=$DRAFT_STATE_COMMIT"
  fi

  echo "CURRENT_BRANCH=$CURRENT_BRANCH"
}

# =============================================================================
# draft_run — create draft branch, apply patches
# =============================================================================

draft_run() {
  local PROJECT_DIR="$1"
  local SOURCE_DIR="$2"      # absolute path to session export directory
  local SESSION_NAME="$3"    # session name (from folder basename)
  local BRANCH_FROM_ARG="$4"
  local DIFFS_ARG="$5"
  local BRANCH_SUMMARY="$6"

  validate_project_dir "$PROJECT_DIR" || return 1
  draft_clear_stale_lock "$PROJECT_DIR" || return 1

  # --- Validate SOURCE_DIR ---
  if [[ ! -d "$SOURCE_DIR" ]]; then
    echo "Error: source directory not found: $SOURCE_DIR" >&2
    return 1
  fi

  # --- Resolve patches directory ---
  local PATCHES_DIR=""
  if [[ -d "$SOURCE_DIR/patches" ]]; then
    PATCHES_DIR="$SOURCE_DIR/patches"
    echo "Using source: $SOURCE_DIR (patches/)"
  else
    echo "Error: no patches/ directory found in $SOURCE_DIR" >&2
    return 1
  fi

  # --- Parse session identity from folder name ---
  local SESSION_TS SANITIZED_HOST_BRANCH
  draft_parse_folder_name "$SESSION_NAME"

  # --- Read export time from EXPORT-TIME.txt if present ---
  local EXPORT_TIME=""
  if [[ -f "$SOURCE_DIR/EXPORT-TIME.txt" ]]; then
    EXPORT_TIME=$(head -n 1 "$SOURCE_DIR/EXPORT-TIME.txt")
  fi
  [[ -z "$EXPORT_TIME" ]] && EXPORT_TIME="unknown"

  # --- Collect numbered diff files ---
  local DIFF_FILES=()
  while IFS= read -r -d '' f; do
    DIFF_FILES+=("$f")
  done < <(find "$PATCHES_DIR" -maxdepth 1 -name '[0-9][0-9][0-9][0-9]*.diff' -print0 | sort -z)

  if [[ "${#DIFF_FILES[@]}" -eq 0 ]]; then
    echo "Error: no .diff files found in $PATCHES_DIR" >&2
    echo "  The session may have produced no commits." >&2
    return 1
  fi

  # --- Apply optional DIFFS range filter ---
  if [[ -n "$DIFFS_ARG" ]]; then
    local START_NUM END_NUM
    START_NUM=$(echo "$DIFFS_ARG" | cut -d. -f1)
    END_NUM=$(echo "$DIFFS_ARG" | cut -d. -f3)
    if [[ -z "$START_NUM" || -z "$END_NUM" ]]; then
      echo "Error: invalid DIFFS range format: $DIFFS_ARG" >&2
      echo "  Expected: <start>..<end> (e.g. 2..4)" >&2
      return 1
    fi

    local FILTERED_DIFFS=()
    for df in "${DIFF_FILES[@]}"; do
      local BNAME NUM NUM_INT
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
      return 1
    fi
    DIFF_FILES=("${FILTERED_DIFFS[@]}")
  fi

  # --- Resolve base commit and source branch ---
  local BASE_COMMIT SOURCE_BRANCH FROM_HASH FROM_SHA6
  BASE_COMMIT="${BRANCH_FROM_ARG:-HEAD}"
  SOURCE_BRANCH=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD)
  if [[ "$SOURCE_BRANCH" == "HEAD" ]]; then
    SOURCE_BRANCH=$(git -C "$PROJECT_DIR" rev-parse --short HEAD)
  fi
  FROM_HASH=$(git -C "$PROJECT_DIR" rev-parse "$BASE_COMMIT")
  FROM_SHA6="${FROM_HASH:0:6}"

  # --- Compute branch slug ---
  local BRANCH_SLUG
  if [[ -n "$BRANCH_SUMMARY" ]]; then
    BRANCH_SLUG="$BRANCH_SUMMARY"
  else
    BRANCH_SLUG="$SANITIZED_HOST_BRANCH"
  fi

  # --- Compute draft branch name ---
  local WORKING_BRANCH
  WORKING_BRANCH="draft/${SESSION_TS}-${BRANCH_SLUG}-${FROM_SHA6}"

  # --- Guard: don't draft from a draft branch ---
  local CURRENT_BRANCH
  CURRENT_BRANCH=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD)
  if [[ "$CURRENT_BRANCH" == draft/* ]]; then
    echo "Error: already on a draft branch: $CURRENT_BRANCH" >&2
    echo "  Run 'make reject' or 'make confirm' first." >&2
    return 1
  fi

  # --- Guard: collision ---
  draft_guard_no_collision "$PROJECT_DIR" "$WORKING_BRANCH" || return 1

  # --- Author for commits ---
  local AUTHOR
  AUTHOR="$(git -C "$PROJECT_DIR" config user.name) <$(git -C "$PROJECT_DIR" config user.email)>"

  # --- Create draft branch ---
  echo "Creating draft branch '$WORKING_BRANCH' from ${FROM_HASH:0:7}..."
  git -C "$PROJECT_DIR" checkout -b "$WORKING_BRANCH" "$BASE_COMMIT"

  # --- Write .draft-state and commit it ---
  local DRAFTED_AT DRAFT_STATE_CONTENT
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

  # --- Apply diffs sequentially ---
  echo "Patches directory: $PATCHES_DIR"
  echo "Applying ${#DIFF_FILES[@]} diffs..."
  for diff_file in "${DIFF_FILES[@]}"; do
    echo "  Applying: $(basename "$diff_file")"
    if ! git -C "$PROJECT_DIR" apply --ignore-whitespace < <(strip_index_lines < "$diff_file"); then
      echo "Error: failed to apply $(basename "$diff_file")" >&2
      echo "  Patch file: $diff_file" >&2
      git -C "$PROJECT_DIR" diff --stat HEAD >&2 || true
      return 1
    fi
    git -C "$PROJECT_DIR" add -A
    git -C "$PROJECT_DIR" commit -m "Apply $(basename "$diff_file")" --author="$AUTHOR"
  done

  # --- Apply uncommitted.diff if present ---
  local UNCOMMITTED_DIFF="$SOURCE_DIR/uncommitted.diff"
  if [[ -f "$UNCOMMITTED_DIFF" && -s "$UNCOMMITTED_DIFF" ]]; then
    echo ""
    echo "Applying uncommitted.diff..."
    if ! git -C "$PROJECT_DIR" apply --ignore-whitespace < <(strip_index_lines < "$UNCOMMITTED_DIFF"); then
      echo "Error: failed to apply uncommitted.diff" >&2
      echo "  File: $UNCOMMITTED_DIFF" >&2
      return 1
    fi
    git -C "$PROJECT_DIR" add -A
    git -C "$PROJECT_DIR" commit -m "Apply uncommitted.diff" --author="$AUTHOR"
    echo "  Applied: uncommitted.diff"
  fi

  # --- Operator hint ---
  echo ""
  echo "Draft branch created: $WORKING_BRANCH"
  echo "Source: $SOURCE_DIR"
  echo "Diffs applied: ${#DIFF_FILES[@]}"
  echo "Branch point: ${FROM_HASH:0:7}"
  [[ -f "$UNCOMMITTED_DIFF" && -s "$UNCOMMITTED_DIFF" ]] && echo "Uncommitted diff applied: yes"
  echo ""
  echo "Shape your commits, then confirm:"
  echo ""
  echo "  git rebase -i ${SOURCE_BRANCH}"
  echo "  make confirm [TARGET=${SOURCE_BRANCH}]"
  echo ""
  echo "To discard: make reject"
}

# =============================================================================
# confirm_run — rebase, fast-forward merge, delete draft branch
# =============================================================================

confirm_run() {
  local PROJECT_DIR="$1"
  local SANDBOX_DIR="$2"
  local TARGET_BRANCH="$3"

  validate_project_dir "$PROJECT_DIR" || return 1
  draft_clear_stale_lock "$PROJECT_DIR" || return 1

  # Validate draft branch and read .draft-state into local scope
  local DRAFT_VALIDATION
  DRAFT_VALIDATION=$(draft_validate_branch "$PROJECT_DIR") || return 1
  eval "$DRAFT_VALIDATION"

  local MERGE_TARGET="${TARGET_BRANCH:-$source_branch}"

  if ! git -C "$PROJECT_DIR" rev-parse --verify "$MERGE_TARGET" >/dev/null 2>&1; then
    echo "Error: target branch does not exist: $MERGE_TARGET" >&2
    echo "  Specify a different target: make confirm TARGET=<branch>" >&2
    return 1
  fi

  # 1. Drop .draft-state commit (if found — user may have already removed it during rebase)
  if [[ -n "${DRAFT_STATE_COMMIT:-}" ]]; then
    echo "Dropping .draft-state commit..."
    if ! git -C "$PROJECT_DIR" rebase --onto "${DRAFT_STATE_COMMIT}^" "$DRAFT_STATE_COMMIT" "$CURRENT_BRANCH"; then
      echo "Error: failed to drop .draft-state commit" >&2
      return 1
    fi
  else
    echo ".draft-state commit not found — skipping drop step."
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
    return 1
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
}

# =============================================================================
# reject_run — checkout source branch, delete draft branch
# =============================================================================

reject_run() {
  local PROJECT_DIR="$1"
  local SANDBOX_DIR="$2"

  validate_project_dir "$PROJECT_DIR" || return 1
  draft_clear_stale_lock "$PROJECT_DIR" || return 1

  # Validate draft branch and read .draft-state into local scope
  local DRAFT_VALIDATION
  DRAFT_VALIDATION=$(draft_validate_branch "$PROJECT_DIR") || return 1
  eval "$DRAFT_VALIDATION"

  echo "Rejecting draft. Returning to $source_branch..."
  git -C "$PROJECT_DIR" checkout "$source_branch"

  if git -C "$PROJECT_DIR" show-ref --verify --quiet "refs/heads/$CURRENT_BRANCH" 2>/dev/null; then
    git -C "$PROJECT_DIR" branch -D "$CURRENT_BRANCH"
    echo "Deleted draft branch: $CURRENT_BRANCH"
  fi

  echo "Draft rejected. PROJECT_DIR restored to $source_branch."
}

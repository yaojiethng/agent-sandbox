#!/usr/bin/env bash
# scripts/workflows/draft.sh
#
# Draft branch workflow: create draft branch, apply patches.
# Sourced by agent-sandbox.sh — not executed standalone.
#
# Depends on: libs/session_state.sh, git, standard shell utilities.

set -euo pipefail

# Derive repo root from own path when exec'd.
_draft_self="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SANDBOX_REPO="${AGENT_SANDBOX_REPO:-$(cd "$_draft_self/../.." && pwd)}"

source "$AGENT_SANDBOX_REPO/src/libs/draft_state.sh"
source "$AGENT_SANDBOX_REPO/src/libs/session_state.sh"
source "$AGENT_SANDBOX_REPO/scripts/guards.sh"
source "$AGENT_SANDBOX_REPO/src/libs/routing.sh"
source "$AGENT_SANDBOX_REPO/src/libs/diff.sh"

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
    local COMMIT_MSG
    COMMIT_MSG=$(draft_resolve_commit_message "$diff_file")
    git -C "$PROJECT_DIR" commit -m "$COMMIT_MSG" --author="$AUTHOR"
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
# main — entry point when exec'd by agent-sandbox draft
# =============================================================================

# Parses flags forwarded from agent-sandbox.sh dispatch and calls draft_run.
# Expected flags: --project=<dir> --sandbox=<dir> [--session=<name>] [--channel=<c>] [--branch-from=<n>] [--diffs=<r>] [--branch-summary=<s>]
main() {
  local PROJECT_DIR=""
  local SANDBOX_DIR=""
  local SESSION_ARG=""
  local CHANNEL_ARG=""
  local BRANCH_FROM=""
  local DIFFS=""
  local BRANCH_SUMMARY=""

  for ARG in "$@"; do
    case "$ARG" in
      --project=*)     PROJECT_DIR="${ARG#--project=}" ;;
      --sandbox=*)     SANDBOX_DIR="${ARG#--sandbox=}" ;;
      --session=*)     SESSION_ARG="${ARG#--session=}" ;;
      --channel=*)     CHANNEL_ARG="${ARG#--channel=}" ;;
      --branch-from=*) BRANCH_FROM="${ARG#--branch-from=}" ;;
      --diffs=*)       DIFFS="${ARG#--diffs=}" ;;
      --branch-summary=*) BRANCH_SUMMARY="${ARG#--branch-summary=}" ;;
      *)
        echo "Error: unknown flag: $ARG" >&2
        exit 1
        ;;
    esac
  done

  if [[ -z "$PROJECT_DIR" || -z "$SANDBOX_DIR" ]]; then
    echo "Error: --project and --sandbox are required" >&2
    exit 1
  fi

  local CHANNEL="${CHANNEL_ARG:-session}"
  local ROUTER_RESULT
  ROUTER_RESULT=$(resolve_source_for_draft "$SANDBOX_DIR" "$CHANNEL" "$SESSION_ARG") || exit 1
  local SOURCE_DIR SESSION_NAME
  SOURCE_DIR=$(echo "$ROUTER_RESULT" | cut -f1)
  SESSION_NAME=$(echo "$ROUTER_RESULT" | cut -f2)
  draft_run "$PROJECT_DIR" "$SOURCE_DIR" "$SESSION_NAME" "$BRANCH_FROM" "$DIFFS" "$BRANCH_SUMMARY"
}

# Guard: only run main() when executed directly, not when sourced
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi

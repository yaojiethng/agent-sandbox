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
# draft_collect_patches — collect and filter numbered diff files
# =============================================================================

# draft_collect_patches PATCHES_DIR [DIFFS_RANGE]
#
# Collects numbered diff files from PATCHES_DIR, optionally filtered by
# DIFFS_RANGE (format: <start>..<end>). Prints the file list to stdout,
# one per line. Returns 1 if no matching diffs are found.
draft_collect_patches() {
  local PATCHES_DIR="$1"
  local DIFFS_RANGE="${2:-}"

  if [[ ! -d "$PATCHES_DIR" ]]; then
    return 1
  fi

  local DIFF_FILES=()
  while IFS= read -r -d '' f; do
    DIFF_FILES+=("$f")
  done < <(find "$PATCHES_DIR" -maxdepth 1 -name '[0-9][0-9][0-9][0-9]*.diff' -print0 | sort -z)

  if [[ "${#DIFF_FILES[@]}" -eq 0 ]]; then
    return 1
  fi

  if [[ -n "$DIFFS_RANGE" ]]; then
    local START_NUM END_NUM
    START_NUM=$(echo "$DIFFS_RANGE" | cut -d. -f1)
    END_NUM=$(echo "$DIFFS_RANGE" | cut -d. -f3)
    if [[ -z "$START_NUM" || -z "$END_NUM" ]]; then
      echo "Error: invalid DIFFS range format: $DIFFS_RANGE" >&2
      echo "  Expected: <start>..<end> (e.g. 2..4)" >&2
      return 1
    fi

    local FILTERED=()
    for df in "${DIFF_FILES[@]}"; do
      local BNAME NUM NUM_INT
      BNAME=$(basename "$df")
      NUM="${BNAME%%-*}"
      if [[ "$NUM" =~ ^[0-9]+$ ]]; then
        NUM_INT=$((10#$NUM))
        if [[ "$NUM_INT" -ge "$START_NUM" && "$NUM_INT" -le "$END_NUM" ]]; then
          FILTERED+=("$df")
        fi
      fi
    done

    if [[ "${#FILTERED[@]}" -eq 0 ]]; then
      echo "Error: no diffs in range $DIFFS_RANGE found" >&2
      return 1
    fi
    DIFF_FILES=("${FILTERED[@]}")
  fi

  printf '%s\n' "${DIFF_FILES[@]}"
}

# =============================================================================
# draft_create_and_init_branch — guards, branch creation, .draft-state
# =============================================================================

# draft_create_and_init_branch PROJECT_DIR WORKING_BRANCH BASE_COMMIT \
#   SOURCE_BRANCH FROM_HASH AUTHOR SESSION_TS SANITIZED_HOST_BRANCH \
#   DIFF_COUNT EXPORT_TIME
#
# Runs guard checks, creates the draft branch, writes .draft-state, and
# commits it. Prints the branch creation message. Returns 1 on guard failure.
draft_create_and_init_branch() {
  local PROJECT_DIR="$1"
  local WORKING_BRANCH="$2"
  local BASE_COMMIT="$3"
  local SOURCE_BRANCH="$4"
  local FROM_HASH="$5"
  local AUTHOR="$6"
  local SESSION_TS="$7"
  local SANITIZED_HOST_BRANCH="$8"
  local DIFF_COUNT="$9"
  local EXPORT_TIME="${10:-unknown}"

  # Guard: don\''t draft from a draft branch
  local CURRENT_BRANCH
  CURRENT_BRANCH=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD)
  if [[ "$CURRENT_BRANCH" == draft/* ]]; then
    echo "Error: already on a draft branch: $CURRENT_BRANCH" >&2
    echo "  Run \''make reject\'' or \''make confirm\'' first." >&2
    return 1
  fi

  # Guard: collision
  draft_guard_no_collision "$PROJECT_DIR" "$WORKING_BRANCH" || return 1

  # Create draft branch
  echo "Creating draft branch \''$WORKING_BRANCH\'' from ${FROM_HASH:0:7}..."
  git -C "$PROJECT_DIR" checkout -b "$WORKING_BRANCH" "$BASE_COMMIT"

  # Write .draft-state and commit it
  local DRAFTED_AT DRAFT_STATE_CONTENT
  DRAFTED_AT=$(date -u +%Y%m%d-%H%M%S)
  DRAFT_STATE_CONTENT=$(draft_write_state \
    "$SOURCE_BRANCH" \
    "$FROM_HASH" \
    "$AUTHOR" \
    "$SESSION_TS" \
    "$SANITIZED_HOST_BRANCH" \
    "$DIFF_COUNT" \
    "$EXPORT_TIME" \
    "$DRAFTED_AT")

  echo "$DRAFT_STATE_CONTENT" > "$PROJECT_DIR/.draft-state"
  git -C "$PROJECT_DIR" add .draft-state
  git -C "$PROJECT_DIR" commit -m ".draft-state" --author="$AUTHOR"
}

# =============================================================================
# draft_apply_patches — apply and commit diffs sequentially
# =============================================================================

# draft_apply_patches PROJECT_DIR DIFF_LIST_FILE AUTHOR
#
# Reads diff file paths from DIFF_LIST_FILE (one per line), applies each
# with git apply and commits with the resolved commit message.
# Returns 1 if any patch fails to apply.
draft_apply_patches() {
  local PROJECT_DIR="$1"
  local DIFF_LIST_FILE="$2"
  local AUTHOR="$3"

  while IFS= read -r diff_file; do
    [[ -z "$diff_file" ]] && continue
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
  done < "$DIFF_LIST_FILE"
}

# =============================================================================
# draft_apply_uncommitted — apply uncommitted.diff if present
# =============================================================================

# draft_apply_uncommitted PROJECT_DIR SOURCE_DIR AUTHOR
#
# Applies uncommitted.diff from SOURCE_DIR if it exists and is non-empty.
# Commits with a fixed message. Prints status to stdout.
draft_apply_uncommitted() {
  local PROJECT_DIR="$1"
  local SOURCE_DIR="$2"
  local AUTHOR="$3"

  local UNCOMMITTED_DIFF="$SOURCE_DIR/uncommitted.diff"
  if [[ ! -f "$UNCOMMITTED_DIFF" || ! -s "$UNCOMMITTED_DIFF" ]]; then
    return 0
  fi

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
}

# =============================================================================
# draft_run — create draft branch, apply patches
# =============================================================================

draft_run() {
  local PROJECT_DIR="$1" SOURCE_DIR="$2" SESSION_NAME="$3"
  local BRANCH_FROM_ARG="$4" DIFFS_ARG="$5" BRANCH_SUMMARY="$6"

  validate_project_dir "$PROJECT_DIR" || return 1
  draft_clear_stale_lock "$PROJECT_DIR" || return 1

  [[ -d "$SOURCE_DIR" ]] || { echo "Error: source not found: $SOURCE_DIR" >&2; return 1; }
  local PATCHES_DIR="$SOURCE_DIR/patches"
  [[ -d "$PATCHES_DIR" ]] || { echo "Error: no patches/ in $SOURCE_DIR" >&2; return 1; }

  local SESSION_TS SANITIZED_HOST_BRANCH
  draft_parse_folder_name "$SESSION_NAME"

  local PATCH_LIST; PATCH_LIST=$(mktemp /tmp/draft_patches_XXXXXX)
  draft_collect_patches "$PATCHES_DIR" "$DIFFS_ARG" > "$PATCH_LIST" || {
    local RC=$?; rm -f "$PATCH_LIST"
    echo "Error: no .diff files found in $PATCHES_DIR" >&2; return $RC
  }
  local DIFF_COUNT; DIFF_COUNT=$(wc -l < "$PATCH_LIST")

  local BASE_COMMIT="${BRANCH_FROM_ARG:-HEAD}"
  local SOURCE_BRANCH; SOURCE_BRANCH=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD)
  [[ "$SOURCE_BRANCH" != "HEAD" ]] || SOURCE_BRANCH=$(git -C "$PROJECT_DIR" rev-parse --short HEAD)
  local FROM_HASH; FROM_HASH=$(git -C "$PROJECT_DIR" rev-parse "$BASE_COMMIT")
  local BRANCH_SLUG="${BRANCH_SUMMARY:-$SANITIZED_HOST_BRANCH}"
  local WORKING_BRANCH="draft/${SESSION_TS}-${BRANCH_SLUG}-${FROM_HASH:0:6}"

  local AUTHOR; AUTHOR="$(git -C "$PROJECT_DIR" config user.name) <$(git -C "$PROJECT_DIR" config user.email)>"
  local EXPORT_TIME=""
  [[ ! -f "$SOURCE_DIR/EXPORT-TIME.txt" ]] || EXPORT_TIME=$(head -n 1 "$SOURCE_DIR/EXPORT-TIME.txt")
  [[ -n "$EXPORT_TIME" ]] || EXPORT_TIME="unknown"

  draft_create_and_init_branch "$PROJECT_DIR" "$WORKING_BRANCH" "$BASE_COMMIT" \
    "$SOURCE_BRANCH" "$FROM_HASH" "$AUTHOR" "$SESSION_TS" \
    "$SANITIZED_HOST_BRANCH" "$DIFF_COUNT" "$EXPORT_TIME" || { rm -f "$PATCH_LIST"; return 1; }

  draft_apply_patches "$PROJECT_DIR" "$PATCH_LIST" "$AUTHOR" || { rm -f "$PATCH_LIST"; return 1; }
  rm -f "$PATCH_LIST"
  draft_apply_uncommitted "$PROJECT_DIR" "$SOURCE_DIR" "$AUTHOR" || return 1

  local UC=""
  [[ -f "$SOURCE_DIR/uncommitted.diff" && -s "$SOURCE_DIR/uncommitted.diff" ]] && UC="yes"
  echo -e "\nDraft branch created: $WORKING_BRANCH\nSource: $SOURCE_DIR\nDiffs applied: $DIFF_COUNT\nBranch point: ${FROM_HASH:0:7}\nUncommitted diff applied: $UC\n\nShape your commits, then confirm:\n\n  git rebase -i ${SOURCE_BRANCH}\n  make confirm [TARGET=${SOURCE_BRANCH}]\n\nTo discard: make reject"
}


# =============================================================================
# main — entry point when exec'd by agent-sandbox draft
# =============================================================================

# Parses flags forwarded from agent-sandbox.sh dispatch and calls draft_run.
# Expected flags: --project=<dir> --sandbox=<dir> [--session=<name>] [--channel=<c>] [--branch-from=<n>] [--diffs=<r>] [--branch-summary=<s>] [--interactive]
main() {
  local PROJECT_DIR=""
  local SANDBOX_DIR=""
  local SESSION_ARG=""
  local CHANNEL_ARG=""
  local BRANCH_FROM=""
  local DIFFS=""
  local BRANCH_SUMMARY=""
  local INTERACTIVE=false

  for ARG in "$@"; do
    case "$ARG" in
      --project=*)     PROJECT_DIR="${ARG#--project=}" ;;
      --sandbox=*)     SANDBOX_DIR="${ARG#--sandbox=}" ;;
      --session=*)     SESSION_ARG="${ARG#--session=}" ;;
      --channel=*)     CHANNEL_ARG="${ARG#--channel=}" ;;
      --branch-from=*) BRANCH_FROM="${ARG#--branch-from=}" ;;
      --diffs=*)       DIFFS="${ARG#--diffs=}" ;;
      --branch-summary=*) BRANCH_SUMMARY="${ARG#--branch-summary=}" ;;
      --interactive)   INTERACTIVE=true ;;
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

  # Interactive mode (and non-interactive with both channel+session given)
  if [[ "$INTERACTIVE" == true ]]; then
    source "$AGENT_SANDBOX_REPO/scripts/workflows/interactive.sh"

    if [[ -n "$CHANNEL_ARG" && -n "$SESSION_ARG" ]]; then
      # Both channel and session given: skip pickers, show patch list + confirm
      local ROUTER_RESULT
      ROUTER_RESULT=$(resolve_source_for_draft "$SANDBOX_DIR" "$CHANNEL_ARG" "$SESSION_ARG") || exit 1
      local SOURCE_DIR SESSION_NAME
      SOURCE_DIR=$(echo "$ROUTER_RESULT" | cut -f1)
      SESSION_NAME=$(echo "$ROUTER_RESULT" | cut -f2)

      local -a PATCH_ITEMS=("Draft from: $SESSION_NAME" "  Patches:")
      local PATCH_COUNT=0
      while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        PATCH_ITEMS+=("    $(basename "$f")")
        PATCH_COUNT=$((PATCH_COUNT + 1))
      done < <(find "$SOURCE_DIR/patches" -maxdepth 1 -name '*.diff' -print0 2>/dev/null | xargs -0 -I{} basename {} | sort)

      if [[ "$PATCH_COUNT" -eq 0 ]]; then
        echo "Error: no .diff files found in $SOURCE_DIR/patches" >&2
        exit 1
      fi

      if [[ -f "$SOURCE_DIR/uncommitted.diff" && -s "$SOURCE_DIR/uncommitted.diff" ]]; then
        PATCH_ITEMS+=("  Uncommitted: uncommitted.diff (non-empty)")
      fi

      interactive_confirm_or_abort "" "${PATCH_ITEMS[@]}" || exit 1
      echo "Running: make draft FROM=${CHANNEL_ARG} SESSION=${SESSION_NAME}"
      draft_run "$PROJECT_DIR" "$SOURCE_DIR" "$SESSION_NAME" "$BRANCH_FROM" "$DIFFS" "$BRANCH_SUMMARY"
      exit $?
    fi

    # Step 1: pick channel
    CHANNEL_ARG=$(interactive_select_channel "draft" "$SANDBOX_DIR" "${CHANNEL_ARG:-}") || exit 1
    # Step 2: pick session
    local SESSION_NAME
    SESSION_NAME=$(interactive_select_session "$SANDBOX_DIR" "$CHANNEL_ARG" "${SESSION_ARG:-}") || exit 1

    local ROUTER_RESULT
    ROUTER_RESULT=$(resolve_source_for_draft "$SANDBOX_DIR" "$CHANNEL_ARG" "$SESSION_NAME") || exit 1
    local SOURCE_DIR
    SOURCE_DIR=$(echo "$ROUTER_RESULT" | cut -f1)
    echo "Running: make draft FROM=${CHANNEL_ARG} SESSION=${SESSION_NAME}"
    draft_run "$PROJECT_DIR" "$SOURCE_DIR" "$SESSION_NAME" "$BRANCH_FROM" "$DIFFS" "$BRANCH_SUMMARY"
    exit $?
  fi

  # Non-interactive path
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
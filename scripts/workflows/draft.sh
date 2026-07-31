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
#   DIFF_COUNT EXPORT_TIME [RUN_ID]
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
  local RUN_ID="${11:-}"

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
    "$DRAFTED_AT" \
    "$RUN_ID")

  echo "$DRAFT_STATE_CONTENT" > "$PROJECT_DIR/.draft-state"
  git -C "$PROJECT_DIR" add .draft-state
  git -C "$PROJECT_DIR" commit -m ".draft-state" --author="$AUTHOR"
}

# =============================================================================
# draft_apply_patches — apply and commit diffs sequentially
# =============================================================================

# draft_apply_patches PROJECT_DIR DIFF_LIST_FILE AUTHOR [FORCE] [PERMISSIVE]
#
# Reads diff file paths from stdin (one per line), applies each via
# apply_and_commit with the resolved commit message.
# FORCE=true applies with --reject; PERMISSIVE=true retries with --recount.
# Returns 1 if any patch fails to apply (unless FORCE=true).
draft_apply_patches() {
  local PROJECT_DIR="$1"
  local AUTHOR="$2"
  local FORCE="${3:-false}"
  local PERMISSIVE="${4:-false}"

  while IFS= read -r diff_file; do
    [[ -z "$diff_file" ]] && continue
    local COMMIT_MSG
    COMMIT_MSG=$(draft_resolve_commit_message "$diff_file")
    echo "  Applying: $(basename "$diff_file")"
    apply_and_commit "$PROJECT_DIR" "$diff_file" "$COMMIT_MSG" "$AUTHOR" "$FORCE" "$PERMISSIVE" || {
      echo "Error: failed to apply $(basename "$diff_file")" >&2
      echo "  Patch file: $diff_file" >&2
      git -C "$PROJECT_DIR" diff --stat HEAD >&2 || true
      return 1
    }
  done
}

# =============================================================================
# draft_apply_uncommitted — apply uncommitted.diff if present
# =============================================================================

# draft_apply_uncommitted PROJECT_DIR SOURCE_DIR AUTHOR [FORCE] [PERMISSIVE]
#
# Applies uncommitted.diff from SOURCE_DIR if it exists and is non-empty.
# Uses apply_and_commit. FORCE=true applies with --reject;
# PERMISSIVE=true retries with --recount.
draft_apply_uncommitted() {
  local PROJECT_DIR="$1"
  local SOURCE_DIR="$2"
  local AUTHOR="$3"
  local FORCE="${4:-false}"
  local PERMISSIVE="${5:-false}"

  local UNCOMMITTED_DIFF="$SOURCE_DIR/uncommitted.diff"
  if [[ ! -f "$UNCOMMITTED_DIFF" || ! -s "$UNCOMMITTED_DIFF" ]]; then
    return 0
  fi

  echo ""
  echo "Applying uncommitted.diff..."
  apply_and_commit "$PROJECT_DIR" "$UNCOMMITTED_DIFF" "Apply uncommitted.diff" "$AUTHOR" "$FORCE" "$PERMISSIVE" || {
    echo "Error: failed to apply uncommitted.diff" >&2
    echo "  File: $UNCOMMITTED_DIFF" >&2
    return 1
  }
  echo "  Applied: uncommitted.diff"
}

# =============================================================================
# draft_run — create draft branch (no apply)
# =============================================================================

# draft_run PROJECT_DIR SOURCE_DIR SESSION_NAME BRANCH_FROM_ARG
#           BRANCH_SUMMARY DIFF_COUNT
#
# Creates a draft branch, writes .draft-state, and prints branch info.
# Accepts DIFF_COUNT (pre-collected by main()) for the .draft-state record.
# Does NOT apply patches — the caller (main()) handles the apply loop.
# Prints branch info to stdout for the caller's summary.
draft_run() {
  local PROJECT_DIR="$1" SOURCE_DIR="$2" SESSION_NAME="$3"
  local BRANCH_FROM_ARG="$4" BRANCH_SUMMARY="$5" DIFF_COUNT="$6"

  validate_project_dir "$PROJECT_DIR" || return 1
  draft_clear_stale_lock "$PROJECT_DIR" || return 1

  [[ -d "$SOURCE_DIR" ]] || { echo "Error: source not found: $SOURCE_DIR" >&2; return 1; }
  local PATCHES_DIR="$SOURCE_DIR/patches"
  [[ -d "$PATCHES_DIR" ]] || { echo "Error: no patches/ in $SOURCE_DIR" >&2; return 1; }

  local SESSION_TS SANITIZED_HOST_BRANCH RUN_ID
  draft_parse_folder_name "$SESSION_NAME"

  [[ "$DIFF_COUNT" -gt 0 ]] || { echo "Error: no .diff files found in $PATCHES_DIR" >&2; return 1; }

  local BASE_COMMIT="${BRANCH_FROM_ARG:-HEAD}"
  local SOURCE_BRANCH; SOURCE_BRANCH=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD)
  [[ "$SOURCE_BRANCH" != "HEAD" ]] || SOURCE_BRANCH=$(git -C "$PROJECT_DIR" rev-parse --short HEAD)
  local FROM_HASH; FROM_HASH=$(git -C "$PROJECT_DIR" rev-parse "$BASE_COMMIT")
  local BRANCH_SLUG="${BRANCH_SUMMARY:-$SANITIZED_HOST_BRANCH}"
  local IDENTITY="${RUN_ID:-$SESSION_TS}"
  local WORKING_BRANCH="draft/${IDENTITY}-${BRANCH_SLUG}-${FROM_HASH:0:6}"

  local AUTHOR; AUTHOR="$(git -C "$PROJECT_DIR" config user.name) <$(git -C "$PROJECT_DIR" config user.email)>"
  local EXPORT_TIME=""
  [[ ! -f "$SOURCE_DIR/EXPORT-TIME.txt" ]] || EXPORT_TIME=$(head -n 1 "$SOURCE_DIR/EXPORT-TIME.txt")
  [[ -n "$EXPORT_TIME" ]] || EXPORT_TIME="unknown"

  draft_create_and_init_branch "$PROJECT_DIR" "$WORKING_BRANCH" "$BASE_COMMIT" \
    "$SOURCE_BRANCH" "$FROM_HASH" "$AUTHOR" "$SESSION_TS" \
    "$SANITIZED_HOST_BRANCH" "$DIFF_COUNT" "$EXPORT_TIME" "$RUN_ID" || return 1

  echo "Draft branch created: $WORKING_BRANCH"
  echo "Branch point: ${FROM_HASH:0:7}"
  echo "Source: $SOURCE_DIR"
  echo "Diffs to apply: $DIFF_COUNT"
}


# =============================================================================
# usage — print help text
# =============================================================================

usage() {
  cat <<EOF
Usage: agent-sandbox draft --project=<path> --sandbox=<path> [options]

Creates a draft branch and applies session patches.

Required:
  --project=<path>    Path to the git repository
  --sandbox=<path>    Path to the sandbox directory

Options:
  --session=<name>        Named session to apply (default: newest)
  --channel=<name>        Resolution channel: session, autosave, bundles (default: session)
  --branch-from=<commit>  Base commit for the draft branch (default: HEAD)
  --diffs=<start>..<end>  Range of patches to apply
  --branch-summary=<slug> Override branch name suffix
  --force                 Apply with --reject; .rej files for conflicts
  --permissive            Retry with --recount on apply failure
  --interactive           Interactive picker mode
EOF
}

# =============================================================================
# _run_draft_workflow — common orchestration after source resolution
# =============================================================================

# _run_draft_workflow PROJECT_DIR SOURCE_DIR SESSION_NAME
#                      BRANCH_FROM DIFFS BRANCH_SUMMARY FORCE PERMISSIVE
#                      [PATCH_LIST]
#
# Orchestrates: collect patches → count → create branch → apply loop →
# apply uncommitted → summary. Called by main() after source resolution.
# If PATCH_LIST (newline-separated, one file per line) is provided, uses it
# instead of re-collecting — avoids double enumeration when the caller
# (interactive path) has already collected the list for display.
_run_draft_workflow() {
  local PROJECT_DIR="$1" SOURCE_DIR="$2" SESSION_NAME="$3"
  local BRANCH_FROM="$4" DIFFS="$5" BRANCH_SUMMARY="$6"
  local FORCE="$7" PERMISSIVE="$8"
  local PATCH_LIST="${9:-}"

  local PATCHES_DIR="$SOURCE_DIR/patches"
  if [[ -z "$PATCH_LIST" ]]; then
    PATCH_LIST=$(draft_collect_patches "$PATCHES_DIR" "$DIFFS" || true)
  fi
  local DIFF_COUNT
  DIFF_COUNT=$(echo "$PATCH_LIST" | grep -c . || true)
  [[ "$DIFF_COUNT" -gt 0 ]] || { echo "Error: no .diff files found in $PATCHES_DIR" >&2; return 1; }

  # Create branch (branch-creation only)
  draft_run "$PROJECT_DIR" "$SOURCE_DIR" "$SESSION_NAME" \
    "$BRANCH_FROM" "$BRANCH_SUMMARY" "$DIFF_COUNT" || return 1

  # Resolve author for apply+commit loop
  local AUTHOR
  AUTHOR="$(git -C "$PROJECT_DIR" config user.name) <$(git -C "$PROJECT_DIR" config user.email)>"

  # Create savepoint before applying patches. On failure, reset to this
  # point to avoid leaving the draft branch in a partially-applied state.
  # Local tag — never pushed by default git push.
  git -C "$PROJECT_DIR" tag -d draft-savepoint 2>/dev/null || true
  git -C "$PROJECT_DIR" tag draft-savepoint

  # Apply patches
  printf '%s\n' "$PATCH_LIST" | draft_apply_patches "$PROJECT_DIR" "$AUTHOR" "$FORCE" "$PERMISSIVE" || {
    echo "Rolling back to savepoint..."
    git -C "$PROJECT_DIR" reset --hard draft-savepoint
    git -C "$PROJECT_DIR" tag -d draft-savepoint
    return 1
  }

  # Apply uncommitted.diff
  draft_apply_uncommitted "$PROJECT_DIR" "$SOURCE_DIR" "$AUTHOR" "$FORCE" "$PERMISSIVE" || {
    echo "Rolling back to savepoint..."
    git -C "$PROJECT_DIR" reset --hard draft-savepoint
    git -C "$PROJECT_DIR" tag -d draft-savepoint
    return 1
  }

  # Success — clean up savepoint
  git -C "$PROJECT_DIR" tag -d draft-savepoint

  # Summary
  local UC=""
  [[ -f "$SOURCE_DIR/uncommitted.diff" && -s "$SOURCE_DIR/uncommitted.diff" ]] && UC="yes"
  echo ""
  echo "Diffs applied: $DIFF_COUNT"
  [[ -n "$UC" ]] && echo "Uncommitted diff applied: $UC"
  echo ""
  echo "Shape your commits, then confirm:"
  echo "  git rebase -i $(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '<source>')"
  echo "  make confirm [TARGET=<target>]"
  echo ""
  echo "To discard: make reject"
}

# =============================================================================
# main — entry point when exec'd by agent-sandbox draft
# =============================================================================

# Parses flags forwarded from agent-sandbox.sh dispatch and calls
# _run_draft_workflow after resolving the source.
# Expected flags: --project=<dir> --sandbox=<dir> [--session=<name>]
#   [--channel=<c>] [--branch-from=<n>] [--diffs=<r>]
#   [--branch-summary=<s>] [--force] [--permissive] [--interactive]
main() {
  for ARG in "$@"; do
    case "$ARG" in
      --help|-h) usage; exit 0 ;;
    esac
  done

  local PROJECT_DIR=""
  local SANDBOX_DIR=""
  local SESSION_ARG=""
  local CHANNEL_ARG=""
  local BRANCH_FROM=""
  local DIFFS=""
  local BRANCH_SUMMARY=""
  local FORCE=false
  local PERMISSIVE=false
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
      --force)         FORCE=true ;;
      --permissive)    PERMISSIVE=true ;;
      --interactive)   INTERACTIVE=true ;;
      *)
        echo "Unknown argument: $ARG" >&2
        usage >&2
        exit 1
        ;;
    esac
  done

  if [[ -z "$PROJECT_DIR" || -z "$SANDBOX_DIR" ]]; then
    usage >&2
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

      local PATCH_LIST
      PATCH_LIST=$(draft_collect_patches "$SOURCE_DIR/patches" "$DIFFS" || true)
      local PATCH_COUNT
      PATCH_COUNT=$(echo "$PATCH_LIST" | grep -c . || true)

      if [[ "$PATCH_COUNT" -eq 0 ]]; then
        echo "Error: no .diff files found in $SOURCE_DIR/patches" >&2
        exit 1
      fi

      local -a PATCH_ITEMS=("Draft from: $SESSION_NAME" "  Patches:")
      while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        PATCH_ITEMS+=("    $(basename "$f")")
      done <<< "$PATCH_LIST"

      if [[ -f "$SOURCE_DIR/uncommitted.diff" && -s "$SOURCE_DIR/uncommitted.diff" ]]; then
        PATCH_ITEMS+=("  Uncommitted: uncommitted.diff (non-empty)")
      fi

      interactive_confirm_or_abort "" "${PATCH_ITEMS[@]}" || exit 1
      echo "Running: make draft FROM=${CHANNEL_ARG} SESSION=${SESSION_NAME}"
      _run_draft_workflow "$PROJECT_DIR" "$SOURCE_DIR" "$SESSION_NAME" \
        "$BRANCH_FROM" "$DIFFS" "$BRANCH_SUMMARY" "$FORCE" "$PERMISSIVE" "$PATCH_LIST"
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
    _run_draft_workflow "$PROJECT_DIR" "$SOURCE_DIR" "$SESSION_NAME" \
      "$BRANCH_FROM" "$DIFFS" "$BRANCH_SUMMARY" "$FORCE" "$PERMISSIVE"
    exit $?
  fi

  # Non-interactive path
  local CHANNEL="${CHANNEL_ARG:-session}"
  local ROUTER_RESULT
  ROUTER_RESULT=$(resolve_source_for_draft "$SANDBOX_DIR" "$CHANNEL" "$SESSION_ARG") || exit 1
  local SOURCE_DIR SESSION_NAME
  SOURCE_DIR=$(echo "$ROUTER_RESULT" | cut -f1)
  SESSION_NAME=$(echo "$ROUTER_RESULT" | cut -f2)
  _run_draft_workflow "$PROJECT_DIR" "$SOURCE_DIR" "$SESSION_NAME" \
    "$BRANCH_FROM" "$DIFFS" "$BRANCH_SUMMARY" "$FORCE" "$PERMISSIVE"
}

# Guard: only run main() when executed directly, not when sourced
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
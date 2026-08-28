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
#   DIFF_COUNT EXPORT_TIME [SESSION_ID]
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
  local SESSION_ID="${11:-}"

  # Guard: don't draft from a draft branch
  local CURRENT_BRANCH
  CURRENT_BRANCH=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD)
  if [[ "$CURRENT_BRANCH" == draft/* ]]; then
    echo "Error: already on a draft branch: $CURRENT_BRANCH" >&2
    echo "  Run 'make reject' or 'make confirm' first." >&2
    return 1
  fi

  # Guard: collision
  draft_guard_no_collision "$PROJECT_DIR" "$WORKING_BRANCH" || return 1

  # Create draft branch
  echo "Creating draft branch '$WORKING_BRANCH' from ${FROM_HASH:0:7}..."
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
    "$SESSION_ID")

  echo "$DRAFT_STATE_CONTENT" > "$PROJECT_DIR/.draft-state"
  git -C "$PROJECT_DIR" add .draft-state
  git -C "$PROJECT_DIR" commit -m ".draft-state" --author="$AUTHOR"
}

# =============================================================================
# draft_apply_patches — apply and commit diffs sequentially
# =============================================================================

# draft_apply_patches PROJECT_DIR DIFF_LIST_FILE AUTHOR [FORCE]
#
# Reads diff file paths from stdin (one per line), applies each via
# apply_and_commit with the resolved commit message.
# Returns 1 if any patch fails to apply (unless FORCE=true).
draft_apply_patches() {
  local PROJECT_DIR="$1"
  local AUTHOR="$2"
  local FORCE="${3:-false}"

  while IFS= read -r diff_file; do
    [[ -z "$diff_file" ]] && continue
    local COMMIT_MSG
    COMMIT_MSG=$(draft_resolve_commit_message "$diff_file")
    echo "  Applying: $(basename "$diff_file")"
    apply_and_commit "$PROJECT_DIR" "$diff_file" "$COMMIT_MSG" "$AUTHOR" "$FORCE" || {
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

# draft_apply_uncommitted PROJECT_DIR SOURCE_DIR AUTHOR [FORCE]
#
# Applies uncommitted.diff from SOURCE_DIR if it exists and is non-empty.
# Does NOT commit — the diff is applied to the working tree only, leaving
# the operator to review and commit manually.
draft_apply_uncommitted() {
  local PROJECT_DIR="$1"
  local SOURCE_DIR="$2"
  local AUTHOR="$3"
  local FORCE="${4:-false}"

  local UNCOMMITTED_DIFF="$SOURCE_DIR/uncommitted.diff"
  if [[ ! -f "$UNCOMMITTED_DIFF" || ! -s "$UNCOMMITTED_DIFF" ]]; then
    return 0
  fi

  echo ""
  echo "Applying uncommitted.diff (working tree only — not committed)..."
  _apply_patch_file "$PROJECT_DIR" "$UNCOMMITTED_DIFF" "$FORCE" || {
    echo "Error: failed to apply uncommitted.diff" >&2
    echo "  File: $UNCOMMITTED_DIFF" >&2
    return 1
  }
  echo "  Applied: uncommitted.diff"
}

# =============================================================================
# _ingest_export_metadata — parse and validate .export-status
# =============================================================================

# _ingest_export_metadata SOURCE_DIR BRANCH_FROM_ARG PROJECT_DIR \
#     OUT_BASE_COMMIT OUT_EXPORT_TIME OUT_INIT_SHA
#
# Parses .export-status from SOURCE_DIR (when present) and resolves
# BASE_COMMIT from BRANCH_FROM_ARG (defaulting to HEAD). Returns the
# three values via nameref output params.
#
# An explicit BRANCH_FROM_ARG takes control of the fork point, so it
# skips metadata validation entirely (documented escape hatch for
# sources without a .export-status, e.g. legacy bundles). Without one,
# a missing or incomplete .export-status is an error.
#
# INIT_SHA records only the patch-generation point. Per design it is
# "information, not the fork point" — it feeds the divergence warning
# below and its absence is never fatal. Returns 1 with an error message
# on failure.
_ingest_export_metadata() {
  local _source_dir="$1"
  local _branch_from="$2"
  local _project_dir="$3"
  local -n _out_base="$4"
  local -n _out_time="$5"
  local -n _out_init="$6"

  # An explicit --branch-from opts out of .export-status validation: the
  # operator has chosen the fork point, so metadata is advisory only.
  local _explicit_from=""
  [[ -n "$_branch_from" ]] && _explicit_from=1

  # Read .export-status (optional metadata). When absent, only proceed
  # if --branch-from was explicitly given; otherwise error clearly.
  local _es="$_source_dir/.export-status"
  local _time="" _init=""
  if [[ -f "$_es" ]]; then
    _time=$(grep '^TIMESTAMP=' "$_es" | cut -d= -f2- || true)
    _init=$(grep '^INIT_SHA=' "$_es" | cut -d= -f2- || true)
  elif [[ -z "$_explicit_from" ]]; then
    echo "Error: .export-status not found in $_source_dir" >&2
    echo "  This directory was not produced by a recent diff_export or package_branch run." >&2
    echo "  Re-export the session or use an explicit --branch-from to skip metadata validation." >&2
    return 1
  fi

  # TIMESTAMP is always written by the exporter; its absence here means
  # the .export-status is incomplete. Accept when --branch-from was given
  # (EXPORT_TIME then defaults to "unknown"); otherwise error.
  if [[ -z "$_time" && -z "$_explicit_from" ]]; then
    echo "Error: TIMESTAMP field missing or empty in .export-status" >&2
    return 1
  fi

  # Resolve BASE_COMMIT
  local _base="$_branch_from"
  [[ -n "$_base" ]] || _base="HEAD"

  if ! git -C "$_project_dir" rev-parse --verify "$_base" >/dev/null 2>&1; then
    echo "Error: BASE_COMMIT '$_base' does not resolve to a valid commit" >&2
    echo "  Set --branch-from to a valid ref" >&2
    return 1
  fi

  # Warn if baseline differs from patch generation point
  if [[ -n "$_init" ]]; then
    local _resolved
    _resolved=$(git -C "$_project_dir" rev-parse "$_base")
    if [[ "$_resolved" != "$_init" ]]; then
      echo "Warning: patches were generated from ${_init:0:7} but branch is forking from ${_resolved:0:7}" >&2
      echo "  If patches fail to apply, set --branch-from explicitly" >&2
    fi
  fi

  _out_base="$_base"
  _out_time="$_time"
  _out_init="$_init"
}

# =============================================================================
# draft_run — create draft branch (no apply)
# =============================================================================

# draft_run PROJECT_DIR SOURCE_DIR BUNDLE_NAME BRANCH_FROM_ARG
#           BRANCH_SUMMARY DIFF_COUNT AUTHOR
#
# Creates a draft branch, writes .draft-state, and prints branch info.
# Accepts DIFF_COUNT (pre-collected by main()) for the .draft-state record.
# Does NOT apply patches — the caller (main()) handles the apply loop.
# Prints branch info to stdout for the caller's summary.
draft_run() {
  local PROJECT_DIR="$1" SOURCE_DIR="$2" BUNDLE_NAME="$3"
  local BRANCH_FROM_ARG="$4" BRANCH_SUMMARY="$5" DIFF_COUNT="$6"
  local AUTHOR="$7"

  validate_project_dir "$PROJECT_DIR" || return 1
  draft_clear_stale_lock "$PROJECT_DIR" || return 1

  [[ -d "$SOURCE_DIR" ]] || { echo "Error: source not found: $SOURCE_DIR" >&2; return 1; }
  local PATCHES_DIR="$SOURCE_DIR/patches"
  [[ -d "$PATCHES_DIR" ]] || [[ "$DIFF_COUNT" -eq 0 ]] || { echo "Error: no patches/ in $SOURCE_DIR" >&2; return 1; }

  local SESSION_TS SANITIZED_HOST_BRANCH SESSION_ID
  draft_parse_folder_name "$BUNDLE_NAME"

  # Allow DIFF_COUNT=0 when only uncommitted.diff is present
  : "${DIFF_COUNT:?}"

  # Ingest and validate export metadata
  local BASE_COMMIT EXPORT_TIME _dummy_init
  _ingest_export_metadata "$SOURCE_DIR" "$BRANCH_FROM_ARG" "$PROJECT_DIR" \
    BASE_COMMIT EXPORT_TIME _dummy_init || return 1

  local SOURCE_BRANCH; SOURCE_BRANCH=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD)
  [[ "$SOURCE_BRANCH" != "HEAD" ]] || SOURCE_BRANCH=$(git -C "$PROJECT_DIR" rev-parse --short HEAD)
  local FROM_HASH; FROM_HASH=$(git -C "$PROJECT_DIR" rev-parse "$BASE_COMMIT")
  local BRANCH_SLUG="${BRANCH_SUMMARY:-$SANITIZED_HOST_BRANCH}"
  local IDENTITY="${SESSION_ID:-$SESSION_TS}"
  local WORKING_BRANCH="draft/${IDENTITY}-${BRANCH_SLUG}-${FROM_HASH:0:6}"

  draft_create_and_init_branch "$PROJECT_DIR" "$WORKING_BRANCH" "$BASE_COMMIT" \
    "$SOURCE_BRANCH" "$FROM_HASH" "$AUTHOR" "$SESSION_TS" \
    "$SANITIZED_HOST_BRANCH" "$DIFF_COUNT" "$EXPORT_TIME" "$SESSION_ID" || return 1

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
  --bundle=<name>         Named bundle to apply (default: newest)
  --channel=<name>        Resolution channel: session, autosave, bundles (default: session)
  --branch-from=<commit>  Base commit for the draft branch (default: HEAD)
  --diffs=<start>..<end>  Range of patches to apply
  --branch-summary=<slug> Override branch name suffix
  --force                 Apply with --reject; .rej files for conflicts
  --permissive            No-op: permissive apply is the default (kept for compatibility)
  --strict                Disable --recount retry on apply failure
  --interactive           Interactive picker mode
EOF
}

# =============================================================================
# _draft_rollback — failure rollback for _run_draft_workflow
# =============================================================================

# _draft_rollback PROJECT_DIR SOURCE_BRANCH
#
# Resets to the draft-savepoint (the fork point before .draft-state was
# committed), returns the operator to the branch that was current before
# draft_run checked out the draft branch, and deletes the savepoint tag.
# Guards against restoring to a branch that no longer exists (fall back to
# the savepoint commit) so the operator is never left on the empty draft/*
# branch. The branch-creation guard in draft_create_and_init_branch already
# refuses to draft from a draft/* branch, so a clean rollback must not leave
# the operator there either.
_draft_rollback() {
  local PROJECT_DIR="$1" SOURCE_BRANCH="$2"

  echo "Rolling back to savepoint..."
  git -C "$PROJECT_DIR" reset --hard draft-savepoint

  if git -C "$PROJECT_DIR" rev-parse --verify --quiet "refs/heads/$SOURCE_BRANCH" >/dev/null; then
    git -C "$PROJECT_DIR" checkout -q "$SOURCE_BRANCH"
  else
    echo "Warning: source branch '$SOURCE_BRANCH' no longer exists; leaving at savepoint commit (detached)." >&2
    git -C "$PROJECT_DIR" checkout -q --detach draft-savepoint
  fi

  git -C "$PROJECT_DIR" tag -d draft-savepoint
}

# =============================================================================
# _run_draft_workflow — common orchestration after source resolution
# =============================================================================

# _run_draft_workflow PROJECT_DIR SOURCE_DIR BUNDLE_NAME
#                      BRANCH_FROM DIFFS BRANCH_SUMMARY FORCE
#                      [PATCH_LIST]
#
# Orchestrates: collect patches → count → create branch → apply loop →
# apply uncommitted → summary. Called by main() after source resolution.
# If PATCH_LIST (newline-separated, one file per line) is provided, uses it
# instead of re-collecting — avoids double enumeration when the caller
# (interactive path) has already collected the list for display.
_run_draft_workflow() {
  local PROJECT_DIR="$1" SOURCE_DIR="$2" BUNDLE_NAME="$3"
  local BRANCH_FROM="$4" DIFFS="$5" BRANCH_SUMMARY="$6"
  local FORCE="$7"
  local PATCH_LIST="${9:-}"

  local PATCHES_DIR="$SOURCE_DIR/patches"
  if [[ -z "$PATCH_LIST" ]]; then
    PATCH_LIST=$(draft_collect_patches "$PATCHES_DIR" "$DIFFS" || true)
  fi
  local DIFF_COUNT
  DIFF_COUNT=$(echo "$PATCH_LIST" | grep -c . || true)
  if [[ "$DIFF_COUNT" -eq 0 ]]; then
    if [[ -f "$SOURCE_DIR/uncommitted.diff" && -s "$SOURCE_DIR/uncommitted.diff" ]]; then
      DIFF_COUNT=0
    else
      echo "Error: no .diff files in $PATCHES_DIR and no uncommitted.diff" >&2
      return 1
    fi
  fi

  # Validate BRANCH_FROM via shared metadata ingestion.
  # Defaults empty to HEAD; validates the commit exists.
  # Also reads .export-status for TIMESTAMP so draft_run can use it.
  local _validated_base _dummy_time _dummy_init
  _ingest_export_metadata "$SOURCE_DIR" "$BRANCH_FROM" "$PROJECT_DIR" \
    _validated_base _dummy_time _dummy_init || return 1

  # Create savepoint at the branch point BEFORE .draft-state is committed.
  # On failure, reset to this to avoid leaving the draft branch partially applied.
  # Local tag — never pushed by default git push.
  # Tag the RESOLVED base (_validated_base defaults to HEAD when --branch-from
  # is omitted) — the raw BRANCH_FROM may be empty, which git would reject.
  git -C "$PROJECT_DIR" tag -d draft-savepoint 2>/dev/null || true
  git -C "$PROJECT_DIR" tag draft-savepoint "$_validated_base"

  # Capture the branch current before draft_run checks out the draft branch, so
  # a failed apply can return the operator to it (and never leave them on draft/*).
  local SOURCE_BRANCH
  SOURCE_BRANCH=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD)
  [[ "$SOURCE_BRANCH" != "HEAD" ]] || SOURCE_BRANCH=$(git -C "$PROJECT_DIR" rev-parse --short HEAD)

  # Resolve author once for both branch creation and apply+commit
  local AUTHOR
  AUTHOR="$(git -C "$PROJECT_DIR" config user.name) <$(git -C "$PROJECT_DIR" config user.email)>"

  # Create branch (branch-creation only)
  draft_run "$PROJECT_DIR" "$SOURCE_DIR" "$BUNDLE_NAME" \
    "$BRANCH_FROM" "$BRANCH_SUMMARY" "$DIFF_COUNT" "$AUTHOR" || return 1

  # Apply patches
  printf '%s\n' "$PATCH_LIST" | draft_apply_patches "$PROJECT_DIR" "$AUTHOR" "$FORCE" || {
    _draft_rollback "$PROJECT_DIR" "$SOURCE_BRANCH"
    return 1
  }

  # Apply uncommitted.diff
  draft_apply_uncommitted "$PROJECT_DIR" "$SOURCE_DIR" "$AUTHOR" "$FORCE" || {
    _draft_rollback "$PROJECT_DIR" "$SOURCE_BRANCH"
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
# Expected flags: --project=<dir> --sandbox=<dir> [--bundle=<name>]
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
  local BUNDLE_ARG=""
  local CHANNEL_ARG=""
  local BRANCH_FROM=""
  local DIFFS=""
  local BRANCH_SUMMARY=""
  local FORCE=false
  local INTERACTIVE=false

  for ARG in "$@"; do
    case "$ARG" in
      --project=*)     PROJECT_DIR="${ARG#--project=}" ;;
      --sandbox=*)     SANDBOX_DIR="${ARG#--sandbox=}" ;;
      --bundle=*)      BUNDLE_ARG="${ARG#--bundle=}" ;;
      --channel=*)     CHANNEL_ARG="${ARG#--channel=}" ;;
      --branch-from=*) BRANCH_FROM="${ARG#--branch-from=}" ;;
      --diffs=*)       DIFFS="${ARG#--diffs=}" ;;
      --branch-summary=*) BRANCH_SUMMARY="${ARG#--branch-summary=}" ;;
      --force)         FORCE=true ;;
      --permissive)    true ;;  # no-op: permissive is the default, kept for compatibility
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

    if [[ -n "$CHANNEL_ARG" && -n "$BUNDLE_ARG" ]]; then
      # Both channel and bundle given: skip pickers, show patch list + confirm
      local ROUTER_RESULT
      ROUTER_RESULT=$(resolve_source_for_draft "$SANDBOX_DIR" "$CHANNEL_ARG" "$BUNDLE_ARG") || exit 1
      local SOURCE_DIR BUNDLE_NAME
      SOURCE_DIR=$(echo "$ROUTER_RESULT" | cut -f1)
      BUNDLE_NAME=$(echo "$ROUTER_RESULT" | cut -f2)

      local PATCH_LIST
      PATCH_LIST=$(draft_collect_patches "$SOURCE_DIR/patches" "$DIFFS" || true)
      local PATCH_COUNT
      PATCH_COUNT=$(echo "$PATCH_LIST" | grep -c . || true)

      if [[ "$PATCH_COUNT" -eq 0 ]]; then
        if [[ -f "$SOURCE_DIR/uncommitted.diff" && -s "$SOURCE_DIR/uncommitted.diff" ]]; then
          echo "No committed patches; uncommitted.diff will be applied."
        else
          echo "Error: no .diff files in $SOURCE_DIR/patches and no uncommitted.diff" >&2
          exit 1
        fi
      fi

      local -a PATCH_ITEMS=("Draft from: $BUNDLE_NAME" "  Patches:")
      while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        PATCH_ITEMS+=("    $(basename "$f")")
      done <<< "$PATCH_LIST"

      if [[ -f "$SOURCE_DIR/uncommitted.diff" && -s "$SOURCE_DIR/uncommitted.diff" ]]; then
        PATCH_ITEMS+=("  Uncommitted: uncommitted.diff (non-empty)")
      fi

      interactive_confirm_or_abort "" "${PATCH_ITEMS[@]}" || exit 1
      echo "Running: make draft FROM=${CHANNEL_ARG} BUNDLE=${BUNDLE_NAME}"
      _run_draft_workflow "$PROJECT_DIR" "$SOURCE_DIR" "$BUNDLE_NAME" \
        "$BRANCH_FROM" "$DIFFS" "$BRANCH_SUMMARY" "$FORCE" "$PATCH_LIST"
      exit $?
    fi

    # Step 1: pick channel
    CHANNEL_ARG=$(interactive_select_channel "draft" "$SANDBOX_DIR" "${CHANNEL_ARG:-}") || exit 1
    # Step 2: pick bundle
    local BUNDLE_NAME
    BUNDLE_NAME=$(interactive_select_bundle "$SANDBOX_DIR" "$CHANNEL_ARG" "${BUNDLE_ARG:-}") || exit 1

    local ROUTER_RESULT
    ROUTER_RESULT=$(resolve_source_for_draft "$SANDBOX_DIR" "$CHANNEL_ARG" "$BUNDLE_NAME") || exit 1
    local SOURCE_DIR
    SOURCE_DIR=$(echo "$ROUTER_RESULT" | cut -f1)
    echo "Running: make draft FROM=${CHANNEL_ARG} BUNDLE=${BUNDLE_NAME}"
    _run_draft_workflow "$PROJECT_DIR" "$SOURCE_DIR" "$BUNDLE_NAME" \
      "$BRANCH_FROM" "$DIFFS" "$BRANCH_SUMMARY" "$FORCE"
    exit $?
  fi

  # Non-interactive path
  local CHANNEL="${CHANNEL_ARG:-session}"
  local ROUTER_RESULT
  ROUTER_RESULT=$(resolve_source_for_draft "$SANDBOX_DIR" "$CHANNEL" "$BUNDLE_ARG") || exit 1
  local SOURCE_DIR BUNDLE_NAME
  SOURCE_DIR=$(echo "$ROUTER_RESULT" | cut -f1)
  BUNDLE_NAME=$(echo "$ROUTER_RESULT" | cut -f2)
  _run_draft_workflow "$PROJECT_DIR" "$SOURCE_DIR" "$BUNDLE_NAME" \
    "$BRANCH_FROM" "$DIFFS" "$BRANCH_SUMMARY" "$FORCE"
}

# Guard: only run main() when executed directly, not when sourced
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
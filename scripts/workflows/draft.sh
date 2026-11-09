#!/usr/bin/env bash
# scripts/workflows/draft.sh
#
# Draft branch workflow: create a draft branch at the bundle's branch point, apply patches.
# Exec'd directly by agent-sandbox.sh (dispatch); main() runs only when not
# sourced, so test suites may source this file for its functions.
#
# Depends on: libs/session_state.sh, git, standard shell utilities.

set -euo pipefail

# Derive repo root from own path when exec'd.
_draft_self="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SANDBOX_REPO="${AGENT_SANDBOX_REPO:-$(cd "$_draft_self/../.." && pwd)}"

source "$AGENT_SANDBOX_REPO/src/libs/draft_state.sh"
source "$AGENT_SANDBOX_REPO/src/libs/session_state.sh"
source "$AGENT_SANDBOX_REPO/src/libs/export_status.sh"
source "$AGENT_SANDBOX_REPO/scripts/guards.sh"
source "$AGENT_SANDBOX_REPO/src/libs/routing.sh"
source "$AGENT_SANDBOX_REPO/src/libs/diff.sh"
source "$AGENT_SANDBOX_REPO/src/libs/cli.sh"

# =============================================================================
# draft_collect_patches  --  collect and filter numbered diff files
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
# draft_create_and_init_branch  --  guards, record, branch creation
# =============================================================================

# draft_create_and_init_branch PROJECT_DIR WORKING_BRANCH COMMIT SOURCE_BRANCH
#
# Runs guard checks, writes the branch-local draft record, and creates the
# branch. Clears the record if branch creation fails. Adds no metadata commit.
# Returns 1 on guard or creation failure.
draft_create_and_init_branch() {
  local PROJECT_DIR="$1"
  local WORKING_BRANCH="$2"
  local COMMIT="$3"
  local SOURCE_BRANCH="$4"

  # Guard: don't draft from a draft branch
  local CURRENT_BRANCH
  CURRENT_BRANCH=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD)
  if [[ "$CURRENT_BRANCH" == draft/* ]]; then
    echo "Error: already on a draft branch: $CURRENT_BRANCH" >&2
    echo "  Run 'make reject' or 'make confirm' first." >&2
    return 1
  fi

  # Guard: exact branch-ref collision
  draft_guard_no_collision "$PROJECT_DIR" "$WORKING_BRANCH" || return 1

  # The record is written before the branch exists. If the branch cannot be
  # created, remove it so no inert section is left behind.
  draft_record_write "$PROJECT_DIR" "$WORKING_BRANCH" "$SOURCE_BRANCH" "$COMMIT" || return 1

  echo "Creating draft branch '$WORKING_BRANCH' from ${COMMIT:0:7}..."
  if ! git -C "$PROJECT_DIR" checkout -b "$WORKING_BRANCH" "$COMMIT"; then
    draft_record_clear "$PROJECT_DIR" "$WORKING_BRANCH"
    echo "Error: failed to create draft branch: $WORKING_BRANCH" >&2
    return 1
  fi
}

# =============================================================================
# draft_apply_patches  --  apply and commit diffs sequentially
# =============================================================================

# draft_apply_patches PROJECT_DIR AUTHOR [FORCE]
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
# draft_apply_uncommitted  --  apply uncommitted.diff if present
# =============================================================================

# draft_apply_uncommitted PROJECT_DIR SOURCE_DIR AUTHOR [FORCE]
#
# Applies uncommitted.diff from SOURCE_DIR if it exists and is non-empty.
# Does NOT commit  --  the diff is applied to the working tree only, leaving
# the operator to review and commit manually.
draft_apply_uncommitted() {
  local PROJECT_DIR="$1"
  local SOURCE_DIR="$2"
  local AUTHOR="$3"
  local FORCE="${4:-false}"

  local UNCOMMITTED_DIFF="$SOURCE_DIR/uncommitted.diff"
  [[ -f "$UNCOMMITTED_DIFF" ]] || return 0

  # Exists but carries no changes: skip with a warning instead of letting
  # git apply reject it.
  if diff_is_empty "$UNCOMMITTED_DIFF"; then
    echo "Warning: uncommitted.diff is present but contains no changes; skipping." >&2
    return 0
  fi

  echo ""
  echo "Applying uncommitted.diff (working tree only -- not committed)..."
  _apply_patch_file "$PROJECT_DIR" "$UNCOMMITTED_DIFF" "$FORCE" || {
    echo "Error: failed to apply uncommitted.diff" >&2
    echo "  File: $UNCOMMITTED_DIFF" >&2
    return 1
  }
  echo "  Applied: uncommitted.diff"
}

# =============================================================================
# _ingest_export_metadata  --  read the bundle metadata and resolve the fork point
# =============================================================================

# _ingest_export_metadata SOURCE_DIR BRANCH_FROM_ARG PROJECT_DIR
#
# Prints the resolved base commit to stdout; diagnostics go to stderr.
# BASE_COMMIT is BRANCH_FROM_ARG when given, else the package branch point
# from .branch-point.
#
# An explicit BRANCH_FROM_ARG is validated on its own and wins even when
# .branch-point is malformed; such a package point is reported as ignored.
# Without one, a missing or malformed .branch-point is an error, and there
# is no fallback to .export-status INIT_SHA or HEAD. The explicit path also
# tolerates a missing .export-status for legacy bundles.
#
# Returns 1 with an error message on failure.
_ingest_export_metadata() {
  local _source_dir="$1"
  local _branch_from="$2"
  local _project_dir="$3"

  # An explicit --branch-from is the operator's authority. The package
  # metadata is read best-effort so an override can still be reported.
  local _explicit_from=""
  [[ -n "$_branch_from" ]] && _explicit_from=1

  # .export-status is the marker of a bundle produced by this pipeline.
  # An explicit --branch-from may skip it for a legacy source directory.
  local _es="$_source_dir/.export-status"
  if [[ ! -f "$_es" && -z "$_explicit_from" ]]; then
    echo "Error: .export-status not found in $_source_dir" >&2
    echo "  This directory was not produced by a recent diff_export or package_branch run." >&2
    echo "  Re-export the session or use an explicit --branch-from to skip metadata validation." >&2
    return 1
  fi

  # The package record borrows the export-status key=value reader; the
  # roadmap row "Record shape: one KV read/write pair" owns the split.
  local _package_point
  _package_point=$(kv_read "$_source_dir/.branch-point" BRANCH_POINT)

  # Resolve BASE_COMMIT. The package branch point is the default; an
  # explicit value overrides it and is validated without the package.
  local _base=""
  if [[ -n "$_explicit_from" ]]; then
    _base="$_branch_from"
  elif [[ -z "$_package_point" ]]; then
    echo "Error: .branch-point has no BRANCH_POINT in $_source_dir" >&2
    echo "  Re-export the bundle, or pass BRANCH_FROM=<commit> (--branch-from) to set the fork point." >&2
    return 1
  else
    _base="$_package_point"
  fi

  if ! git_commit_exists "$_project_dir" "$_base"; then
    if [[ -n "$_explicit_from" ]]; then
      echo "Error: BASE_COMMIT '$_base' does not resolve to a valid commit" >&2
      echo "  Set --branch-from to a valid ref" >&2
    else
      echo "Error: BRANCH_POINT '$_base' in .branch-point does not resolve to a valid commit" >&2
      echo "  Re-export the bundle, or pass BRANCH_FROM=<commit> (--branch-from) to set the fork point." >&2
    fi
    return 1
  fi

  # Resolve once so the branch name, the record and the hint all carry the
  # same commit rather than the ref the operator typed.
  _base=$(git -C "$_project_dir" rev-parse --verify "${_base}^{commit}") || return 1

  # Keep the package point visible when the operator overrides it. A
  # malformed package point is ignored, not fatal, because the explicit
  # value already decides the fork.
  if [[ -n "$_explicit_from" && -n "$_package_point" ]]; then
    local _package_resolved
    if ! git_commit_exists "$_project_dir" "$_package_point"; then
      echo "Warning: .branch-point BRANCH_POINT '$_package_point' does not resolve; using BRANCH_FROM ${_base:0:7}" >&2
    else
      _package_resolved=$(git -C "$_project_dir" rev-parse --verify "${_package_point}^{commit}")
      if [[ "$_base" != "$_package_resolved" ]]; then
        echo "Warning: BRANCH_FROM ${_base:0:7} overrides the package branch point ${_package_resolved:0:7}" >&2
      fi
    fi
  fi

  printf '%s\n' "$_base"
}

# =============================================================================
# draft_run  --  create draft branch (no apply)
# =============================================================================

# draft_run PROJECT_DIR SOURCE_DIR BUNDLE_NAME BASE_COMMIT
#           BRANCH_SUMMARY DIFF_COUNT
#
# Creates a draft branch, writes its branch-local record, and prints branch info.
# Accepts the already-resolved BASE_COMMIT and DIFF_COUNT (pre-collected by
# main()) for the summary. Does NOT apply patches  --  the caller (main())
# handles the apply loop. Prints branch info to stdout for the caller's summary.
# Sets DRAFT_WORKING_BRANCH in the caller's scope (no local  --  intentional)
# so the caller can roll back the exact branch this call created.
draft_run() {
  local PROJECT_DIR="$1" SOURCE_DIR="$2" BUNDLE_NAME="$3"
  local BASE_COMMIT="$4" BRANCH_SUMMARY="$5" DIFF_COUNT="$6"

  validate_project_dir "$PROJECT_DIR" || return 1
  draft_clear_stale_lock "$PROJECT_DIR" || return 1

  # Clean-tree guard: drafting from a dirty tree folds WIP into the review
  # branch (checkout -b carries it; git add -A sweeps it into draft commits).
  # Never bypassed by --force -- force only tolerates apply conflicts, never an
  # unclean fork base.
  refuse_dirty_tree "$PROJECT_DIR" "make draft" || return 1

  [[ -d "$SOURCE_DIR" ]] || { echo "Error: source not found: $SOURCE_DIR" >&2; return 1; }
  local PATCHES_DIR="$SOURCE_DIR/patches"
  [[ -d "$PATCHES_DIR" ]] || [[ "$DIFF_COUNT" -eq 0 ]] || { echo "Error: no patches/ in $SOURCE_DIR" >&2; return 1; }

  local SESSION_TS SANITIZED_HOST_BRANCH SESSION_ID
  draft_parse_folder_name "$BUNDLE_NAME"

  # Allow DIFF_COUNT=0 when only uncommitted.diff is present
  : "${DIFF_COUNT:?}"

  local SOURCE_BRANCH; SOURCE_BRANCH="$(project_current_ref "$PROJECT_DIR")"
  local FROM_HASH="$BASE_COMMIT"
  local BRANCH_SLUG="${BRANCH_SUMMARY:-$SANITIZED_HOST_BRANCH}"
  local IDENTITY="${SESSION_ID:-$SESSION_TS}"
  local WORKING_BRANCH="draft/${IDENTITY}-${BRANCH_SLUG}-${FROM_HASH:0:6}"
  DRAFT_WORKING_BRANCH="$WORKING_BRANCH"

  draft_create_and_init_branch "$PROJECT_DIR" "$WORKING_BRANCH" "$FROM_HASH" \
    "$SOURCE_BRANCH" || return 1

  echo "Draft branch created: $WORKING_BRANCH"
  echo "Source: $SOURCE_DIR"
  echo "Diffs to apply: $DIFF_COUNT"
}


# =============================================================================
# usage  --  print help text
# =============================================================================

usage() {
  cat <<EOF
Usage: agent-sandbox draft --project=<path> --sandbox=<path> [options]

Creates a draft branch and applies session patches.

or, from a sandbox Makefile: make draft [FROM=<channel>] BUNDLE=<name> [BRANCH_FROM=<commit>]

Required:
  --project=<path>    Path to the git repository
  --sandbox=<path>    Path to the sandbox directory

Options:
  --bundle=<name>         Named bundle to apply (required; --interactive picks from a list)
  --channel=<name>        Resolution channel: session, autosave, bundles (default: session)
  --branch-from=<commit>  Override the fork point from the bundle's .branch-point
  --diffs=<start>..<end>  Range of patches to apply
  --branch-summary=<slug> Override branch name suffix
  --force                 Apply with --reject; .rej files for conflicts
  --permissive            No-op: permissive apply is the default (kept for compatibility)
  --interactive           Interactive picker mode
EOF
}

# =============================================================================
# _draft_rollback  --  failure rollback for _run_draft_workflow
# =============================================================================

# _draft_rollback PROJECT_DIR SOURCE_BRANCH DRAFT_BRANCH
#
# Resets to the fork point recorded on DRAFT_BRANCH, returns the operator to
# the branch that was current before draft_run checked out the draft branch,
# and deletes the exact draft branch draft_run created. Guards against restoring
# to a branch that no longer exists (fall back to the recorded fork commit) so
# the operator is never left on the empty draft/* branch. The branch-creation
# guard in draft_create_and_init_branch already refuses to draft from a
# draft/* branch, so a clean rollback must not leave the operator there either.
_draft_rollback() {
  local PROJECT_DIR="$1" SOURCE_BRANCH="$2" DRAFT_BRANCH="${3:-}"

  if [[ -z "$DRAFT_BRANCH" ]]; then
    echo "Error: cannot roll back without the draft branch name." >&2
    return 1
  fi

  local FORK_POINT
  FORK_POINT=$(draft_record_read "$PROJECT_DIR" "$DRAFT_BRANCH" fork) || {
    echo "Error: cannot roll back: no fork point recorded for $DRAFT_BRANCH." >&2
    return 1
  }
  if [[ -z "$FORK_POINT" ]]; then
    echo "Error: cannot roll back: no fork point recorded for $DRAFT_BRANCH." >&2
    return 1
  fi

  echo "Rolling back to the draft fork point..."
  git -C "$PROJECT_DIR" reset --hard "$FORK_POINT"

  if git -C "$PROJECT_DIR" rev-parse --verify --quiet "refs/heads/$SOURCE_BRANCH" >/dev/null; then
    git -C "$PROJECT_DIR" checkout -q "$SOURCE_BRANCH"
  else
    echo "Warning: source branch '$SOURCE_BRANCH' no longer exists; leaving at the fork commit (detached)." >&2
    git -C "$PROJECT_DIR" checkout -q --detach "$FORK_POINT"
  fi

  # Delete the exact draft branch this run created, so a later draft does not
  # collide on branch creation. Guarded: only an existing draft/* branch.
  if [[ "$DRAFT_BRANCH" == draft/* ]] \
    && git -C "$PROJECT_DIR" rev-parse --verify --quiet "refs/heads/$DRAFT_BRANCH" >/dev/null; then
    git -C "$PROJECT_DIR" branch -q -D "$DRAFT_BRANCH"
    echo "Deleted partial draft branch '$DRAFT_BRANCH'."
  fi
}

# =============================================================================
# _run_draft_workflow  --  common orchestration after source resolution
# =============================================================================

# _run_draft_workflow PROJECT_DIR SOURCE_DIR BUNDLE_NAME
#                      BRANCH_FROM DIFFS BRANCH_SUMMARY FORCE
#                      [PATCH_LIST]
#
# Orchestrates: collect patches -> count -> create branch -> apply loop ->
# apply uncommitted -> summary. Called by main() after source resolution.
# If PATCH_LIST (newline-separated, one file per line) is provided, uses it
# instead of re-collecting  --  avoids double enumeration when the caller
# (interactive path) has already collected the list for display.
_run_draft_workflow() {
  local PROJECT_DIR="$1" SOURCE_DIR="$2" BUNDLE_NAME="$3"
  local BRANCH_FROM="$4" DIFFS="$5" BRANCH_SUMMARY="$6"
  local FORCE="$7"
  local PATCH_LIST="${8:-}"

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

  # Resolve BRANCH_FROM once. An empty value resolves to the bundle's
  # .branch-point; the commit must exist.
  local BASE_COMMIT
  BASE_COMMIT=$(_ingest_export_metadata "$SOURCE_DIR" "$BRANCH_FROM" "$PROJECT_DIR") || return 1

  # Capture the branch current before draft_run checks out the draft branch, so
  # a failed apply can return the operator to it (and never leave them on draft/*).
  local SOURCE_BRANCH
  SOURCE_BRANCH="$(project_current_ref "$PROJECT_DIR")"

  # Resolve author once for both branch creation and apply+commit
  local AUTHOR
  AUTHOR="$(git -C "$PROJECT_DIR" config user.name) <$(git -C "$PROJECT_DIR" config user.email)>"

  # Create branch (branch-creation only). draft_run sets DRAFT_WORKING_BRANCH
  # in this scope -- the exact branch it created, so a failed apply can be
  # rolled back to the source branch with the partial draft branch removed.
  DRAFT_WORKING_BRANCH=""
  draft_run "$PROJECT_DIR" "$SOURCE_DIR" "$BUNDLE_NAME" \
    "$BASE_COMMIT" "$BRANCH_SUMMARY" "$DIFF_COUNT" || return 1

  # Apply patches
  printf '%s\n' "$PATCH_LIST" | draft_apply_patches "$PROJECT_DIR" "$AUTHOR" "$FORCE" || {
    _draft_rollback "$PROJECT_DIR" "$SOURCE_BRANCH" "$DRAFT_WORKING_BRANCH"
    return 1
  }

  # Apply uncommitted.diff
  draft_apply_uncommitted "$PROJECT_DIR" "$SOURCE_DIR" "$AUTHOR" "$FORCE" || {
    _draft_rollback "$PROJECT_DIR" "$SOURCE_BRANCH" "$DRAFT_WORKING_BRANCH"
    return 1
  }

  # Summary
  local UC=""
  [[ -f "$SOURCE_DIR/uncommitted.diff" && -s "$SOURCE_DIR/uncommitted.diff" ]] && UC="yes"
  echo ""
  echo "Diffs applied: $DIFF_COUNT"
  [[ -n "$UC" ]] && echo "Uncommitted diff applied: $UC"
  echo ""
  draft_print_confirm_hint "$PROJECT_DIR" "$SOURCE_BRANCH" "$BASE_COMMIT"
}

# =============================================================================
# draft_print_confirm_hint  --  print the confirm direction that applies
#
#   draft_print_confirm_hint <project-dir> <source-branch> <branch-point>
#
# Which route applies is decided here, not by the agent: `make confirm`
# fast-forwards the target, so it only works when the target is an ancestor of
# the draft tip. After a rebase inside the container it is not, and telling the
# operator to fast-forward would send them into a failed merge. Both routes
# state the fork point, so the operator never has to recover it from chat.
# =============================================================================
draft_print_confirm_hint() {
  local PROJECT_DIR="$1"
  local SOURCE_BRANCH="$2"
  local BRANCH_POINT="$3"

  echo "Branch point: ${BRANCH_POINT:0:7}"

  if git -C "$PROJECT_DIR" merge-base --is-ancestor "$SOURCE_BRANCH" HEAD >/dev/null 2>&1; then
    echo "Shape your commits, then confirm:"
    echo "  git rebase -i ${SOURCE_BRANCH}"
    echo "  make confirm TARGET_BRANCH=${SOURCE_BRANCH}"
    echo ""
    echo "To discard: make reject"
    echo "To apply one diff without a branch: make apply DIFF=<path>"
  else
    echo "This bundle replaces history on ${SOURCE_BRANCH}; it cannot fast-forward."
    echo "Create a new branch from the reviewed series instead:"
    echo "  make confirm TARGET_BRANCH=<new-branch> NEW=1"
    echo ""
    echo "That leaves ${SOURCE_BRANCH} untouched and prints the two commands"
    echo "that move it onto the series."
    echo ""
    echo "To discard instead: make reject"
    echo "To apply one diff without a branch: make apply DIFF=<path>"
  fi
}

# =============================================================================
# _resolve_draft_source  --  resolve a draft source into globals
# =============================================================================

# _resolve_draft_source SANDBOX_DIR CHANNEL BUNDLE
#   Resolves the session export source for a draft and sets SOURCE_DIR and
#   BUNDLE_NAME in the caller's scope (deliberately not local -- main()'s
#   three paths consume them). Returns 1 when resolution fails.
#
#   A non-interactive draft must name its bundle. Auto-picking the newest was
#   the source of a stale-session draft, so an empty BUNDLE is an error here
#   rather than a silent fallback; the picker (INTERACTIVE=1) is the guided
#   path. The interactive paths always pass a resolved name, so only the
#   non-interactive path reaches the guard.
_resolve_draft_source() {
  local SANDBOX_DIR="$1"
  local CHANNEL="$2"
  local BUNDLE="$3"

  if [[ -z "$BUNDLE" ]]; then
    echo "Error: no bundle named for a non-interactive draft." >&2
    echo "  Name one:  make draft BUNDLE=<name>" >&2
    echo "  Pick one:  make draft INTERACTIVE=1" >&2
    return 1
  fi

  local result
  result=$(resolve_source_for_draft "$SANDBOX_DIR" "$CHANNEL" "$BUNDLE") || return 1
  SOURCE_DIR=$(echo "$result" | cut -f1)
  BUNDLE_NAME=$(echo "$result" | cut -f2)
}

# =============================================================================
# main  --  entry point when exec'd by agent-sandbox draft
# =============================================================================

# Parses flags forwarded from agent-sandbox.sh dispatch and calls
# _run_draft_workflow after resolving the source.
# Expected flags: --project=<dir> --sandbox=<dir> [--bundle=<name>]
#   [--channel=<c>] [--branch-from=<n>] [--diffs=<r>]
#   [--branch-summary=<s>] [--force] [--permissive] [--interactive]
main() {
  local rc=0
  parse_args usage \
    --project=PROJECT_DIR \
    --sandbox=SANDBOX_DIR \
    --bundle=BUNDLE_ARG \
    --channel=CHANNEL_ARG \
    --branch-from=BRANCH_FROM \
    --diffs=DIFFS \
    --branch-summary=BRANCH_SUMMARY \
    --force \
    --permissive \
    --interactive \
    -- "$@" || rc=$?
  if [[ $rc -eq 2 ]]; then exit 0; fi
  [[ $rc -eq 0 ]] || exit 1

  if [[ -z "$PROJECT_DIR" || -z "$SANDBOX_DIR" ]]; then
    usage >&2
    exit 1
  fi

  # Interactive mode (and non-interactive with both channel+session given)
  if [[ "$INTERACTIVE" == true ]]; then
    source "$AGENT_SANDBOX_REPO/scripts/workflows/interactive.sh"

    if [[ -n "$CHANNEL_ARG" && -n "$BUNDLE_ARG" ]]; then
      # Both channel and bundle given: skip pickers, show patch list + confirm
      _resolve_draft_source "$SANDBOX_DIR" "$CHANNEL_ARG" "$BUNDLE_ARG" || exit 1

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
      # Terminal: the interactive arms below would run a second draft.
      exit
    fi

    # Step 1: pick channel
    CHANNEL_ARG=$(interactive_select_channel "draft" "$SANDBOX_DIR" "${CHANNEL_ARG:-}") || exit 1
    # Step 2: pick bundle
    BUNDLE_NAME=$(interactive_select_bundle "$SANDBOX_DIR" "$CHANNEL_ARG" "${BUNDLE_ARG:-}") || exit 1

    _resolve_draft_source "$SANDBOX_DIR" "$CHANNEL_ARG" "$BUNDLE_NAME" || exit 1
    echo "Running: make draft FROM=${CHANNEL_ARG} BUNDLE=${BUNDLE_NAME}"
    _run_draft_workflow "$PROJECT_DIR" "$SOURCE_DIR" "$BUNDLE_NAME" \
      "$BRANCH_FROM" "$DIFFS" "$BRANCH_SUMMARY" "$FORCE"
    # Terminal: the non-interactive path below would run a second draft.
    exit
  fi

  # Non-interactive path. resolve_source_for_draft applies the channel default
  # ("session") to an empty value, so main does not repeat it.
  _resolve_draft_source "$SANDBOX_DIR" "${CHANNEL_ARG:-}" "$BUNDLE_ARG" || exit 1
  _run_draft_workflow "$PROJECT_DIR" "$SOURCE_DIR" "$BUNDLE_NAME" \
    "$BRANCH_FROM" "$DIFFS" "$BRANCH_SUMMARY" "$FORCE"
}

# Guard: only run main() when executed directly, not when sourced
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
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
# draft_create_and_init_branch  --  guards, branch creation, .draft-state
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
# _draft_branch_point_read  --  read the package fork point
# =============================================================================

# _draft_branch_point_read SOURCE_DIR
#   Prints BRANCH_POINT from SOURCE_DIR/.branch-point, or the empty string
#   when the file or the key is absent. This is the only default source for
#   the draft fork point; .export-status INIT_SHA is not a fallback.
_draft_branch_point_read() {
  local _dir="$1"
  local _file="$_dir/.branch-point"
  [[ -r "$_file" ]] || return 0
  while IFS='=' read -r _k _v; do
    if [[ "$_k" == "BRANCH_POINT" ]]; then
      printf '%s\n' "$_v"
      return 0
    fi
  done < "$_file"
  return 0
}

# =============================================================================
# _ingest_export_metadata  --  read the bundle metadata and resolve the fork point
# =============================================================================

# _ingest_export_metadata SOURCE_DIR BRANCH_FROM_ARG PROJECT_DIR \
#     OUT_BASE_COMMIT OUT_EXPORT_TIME OUT_BRANCH_POINT
#
# Reads .export-status for TIMESTAMP and .branch-point for BRANCH_POINT.
# BASE_COMMIT is BRANCH_FROM_ARG when given, else the package branch point.
# Returns the three values via nameref output params.
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
  local -n _out_base="$4"
  local -n _out_time="$5"
  local -n _out_branch_point="$6"

  # An explicit --branch-from is the operator's authority. The package
  # metadata is read best-effort so an override can still be reported.
  local _explicit_from=""
  [[ -n "$_branch_from" ]] && _explicit_from=1

  # Read .export-status (optional metadata). When absent, only proceed
  # if --branch-from was explicitly given; otherwise error clearly.
  local _es="$_source_dir/.export-status"
  local _time=""
  if [[ -f "$_es" ]]; then
    _time=$(export_status_read "$_source_dir" TIMESTAMP)
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

  local _package_point
  _package_point=$(_draft_branch_point_read "$_source_dir")

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

  # Keep the package point visible when the operator overrides it. A
  # malformed package point is ignored, not fatal, because the explicit
  # value already decides the fork.
  if [[ -n "$_explicit_from" && -n "$_package_point" ]]; then
    local _resolved _package_resolved
    _resolved=$(git -C "$_project_dir" rev-parse "$_base")
    if ! git_commit_exists "$_project_dir" "$_package_point"; then
      echo "Warning: .branch-point BRANCH_POINT '$_package_point' does not resolve; using BRANCH_FROM ${_resolved:0:7}" >&2
    else
      _package_resolved=$(git -C "$_project_dir" rev-parse "$_package_point")
      if [[ "$_resolved" != "$_package_resolved" ]]; then
        echo "Warning: BRANCH_FROM ${_resolved:0:7} overrides the package branch point ${_package_resolved:0:7}" >&2
      fi
    fi
  fi

  _out_base="$_base"
  _out_time="$_time"
  _out_branch_point="$_package_point"
}

# =============================================================================
# draft_run  --  create draft branch (no apply)
# =============================================================================

# draft_run PROJECT_DIR SOURCE_DIR BUNDLE_NAME BRANCH_FROM_ARG
#           BRANCH_SUMMARY DIFF_COUNT AUTHOR
#
# Creates a draft branch, writes .draft-state, and prints branch info.
# Accepts DIFF_COUNT (pre-collected by main()) for the .draft-state record.
# Does NOT apply patches  --  the caller (main()) handles the apply loop.
# Prints branch info to stdout for the caller's summary. Sets DRAFT_WORKING_BRANCH
# in the caller's scope (no local  --  intentional) so the caller can roll back
# the exact branch this call created.
draft_run() {
  local PROJECT_DIR="$1" SOURCE_DIR="$2" BUNDLE_NAME="$3"
  local BRANCH_FROM_ARG="$4" BRANCH_SUMMARY="$5" DIFF_COUNT="$6"
  local AUTHOR="$7"

  validate_project_dir "$PROJECT_DIR" || return 1
  draft_clear_stale_lock "$PROJECT_DIR" || return 1

  # Clean-tree guard: drafting from a dirty tree folds WIP into the review
  # branch (checkout -b carries it; git add -A sweeps it into draft commits).
  # Never bypassed by --force -- force only tolerates apply conflicts, never an
  # unclean fork base. The hint tells the operator how to proceed.
  local _tree_rc=0
  require_clean_working_tree "$PROJECT_DIR" || _tree_rc=$?
  if [[ "$_tree_rc" -eq 2 ]]; then
    echo "Error: make draft cannot read the working tree state." >&2
    clean_tree_hint_unreadable
    return 1
  fi
  if [[ "$_tree_rc" -eq 1 ]]; then
    echo "Error: make draft requires a clean working tree." >&2
    clean_tree_hint
    return 1
  fi

  [[ -d "$SOURCE_DIR" ]] || { echo "Error: source not found: $SOURCE_DIR" >&2; return 1; }
  local PATCHES_DIR="$SOURCE_DIR/patches"
  [[ -d "$PATCHES_DIR" ]] || [[ "$DIFF_COUNT" -eq 0 ]] || { echo "Error: no patches/ in $SOURCE_DIR" >&2; return 1; }

  local SESSION_TS SANITIZED_HOST_BRANCH SESSION_ID
  draft_parse_folder_name "$BUNDLE_NAME"

  # Allow DIFF_COUNT=0 when only uncommitted.diff is present
  : "${DIFF_COUNT:?}"

  # Ingest and validate export metadata
  local BASE_COMMIT EXPORT_TIME _dummy_point
  _ingest_export_metadata "$SOURCE_DIR" "$BRANCH_FROM_ARG" "$PROJECT_DIR" \
    BASE_COMMIT EXPORT_TIME _dummy_point || return 1

  local SOURCE_BRANCH; SOURCE_BRANCH="$(project_current_ref "$PROJECT_DIR")"
  local FROM_HASH; FROM_HASH=$(git -C "$PROJECT_DIR" rev-parse "$BASE_COMMIT")
  local BRANCH_SLUG="${BRANCH_SUMMARY:-$SANITIZED_HOST_BRANCH}"
  local IDENTITY="${SESSION_ID:-$SESSION_TS}"
  local WORKING_BRANCH="draft/${IDENTITY}-${BRANCH_SLUG}-${FROM_HASH:0:6}"
  DRAFT_WORKING_BRANCH="$WORKING_BRANCH"

  draft_create_and_init_branch "$PROJECT_DIR" "$WORKING_BRANCH" "$BASE_COMMIT" \
    "$SOURCE_BRANCH" "$FROM_HASH" "$AUTHOR" "$SESSION_TS" \
    "$SANITIZED_HOST_BRANCH" "$DIFF_COUNT" "$EXPORT_TIME" "$SESSION_ID" || return 1

  echo "Draft branch created: $WORKING_BRANCH"
  echo "Branch point: ${FROM_HASH:0:7}"
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

# _draft_rollback PROJECT_DIR SOURCE_BRANCH
#
# Resets to the draft-savepoint (the fork point before .draft-state was
# committed), returns the operator to the branch that was current before
# draft_run checked out the draft branch, and deletes the savepoint tag and
# the exact draft branch draft_run created ($3). Guards against restoring to
# a branch that no longer exists (fall back to the savepoint commit) so the
# operator is never left on the empty draft/* branch. The branch-creation
# guard in draft_create_and_init_branch already refuses to draft from a
# draft/* branch, so a clean rollback must not leave the operator there
# either.
_draft_rollback() {
  local PROJECT_DIR="$1" SOURCE_BRANCH="$2" DRAFT_BRANCH="${3:-}"

  echo "Rolling back to savepoint..."
  git -C "$PROJECT_DIR" reset --hard draft-savepoint

  if git -C "$PROJECT_DIR" rev-parse --verify --quiet "refs/heads/$SOURCE_BRANCH" >/dev/null; then
    git -C "$PROJECT_DIR" checkout -q "$SOURCE_BRANCH"
  else
    echo "Warning: source branch '$SOURCE_BRANCH' no longer exists; leaving at savepoint commit (detached)." >&2
    git -C "$PROJECT_DIR" checkout -q --detach draft-savepoint
  fi

  # Delete the exact draft branch this run created, so a later draft does not
  # collide on branch creation. Guarded: only an existing draft/* branch.
  if [[ -n "$DRAFT_BRANCH" && "$DRAFT_BRANCH" == draft/* ]] \
    && git -C "$PROJECT_DIR" rev-parse --verify --quiet "refs/heads/$DRAFT_BRANCH" >/dev/null; then
    git -C "$PROJECT_DIR" branch -q -D "$DRAFT_BRANCH"
    echo "Deleted partial draft branch '$DRAFT_BRANCH'."
  fi

  git -C "$PROJECT_DIR" tag -d draft-savepoint
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

  # Validate BRANCH_FROM via shared metadata ingestion.
  # An empty value resolves to the bundle's .branch-point; the commit must exist.
  # Also reads .export-status for TIMESTAMP so draft_run can use it.
  local _validated_base _dummy_time _dummy_point
  _ingest_export_metadata "$SOURCE_DIR" "$BRANCH_FROM" "$PROJECT_DIR" \
    _validated_base _dummy_time _dummy_point || return 1

  # Create savepoint at the branch point BEFORE .draft-state is committed.
  # On failure, reset to this to avoid leaving the draft branch partially applied.
  # Local tag  --  never pushed by default git push.
  # Tag the RESOLVED base (_validated_base defaults to HEAD when --branch-from
  # is omitted)  --  the raw BRANCH_FROM may be empty, which git would reject.
  git -C "$PROJECT_DIR" tag -d draft-savepoint 2>/dev/null || true
  git -C "$PROJECT_DIR" tag draft-savepoint "$_validated_base"

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
    "$BRANCH_FROM" "$BRANCH_SUMMARY" "$DIFF_COUNT" "$AUTHOR" || return 1

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

  # Success  --  clean up savepoint
  git -C "$PROJECT_DIR" tag -d draft-savepoint

  # Summary
  local UC=""
  [[ -f "$SOURCE_DIR/uncommitted.diff" && -s "$SOURCE_DIR/uncommitted.diff" ]] && UC="yes"
  echo ""
  echo "Diffs applied: $DIFF_COUNT"
  [[ -n "$UC" ]] && echo "Uncommitted diff applied: $UC"
  echo ""
  draft_print_confirm_hint "$PROJECT_DIR" "$SOURCE_BRANCH" "$_validated_base"
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
    -- "$@"
  local rc=$?
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
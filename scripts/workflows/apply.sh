#!/usr/bin/env bash
# scripts/workflows/apply.sh
#
# Diff application workflow: apply a diff file to the project working tree.
# Sourced by agent-sandbox.sh — not executed standalone.
#
# Depends on: AGENT_SANDBOX_REPO, src/libs/diff.sh, git, standard shell utilities.

set -euo pipefail

# Derive repo root from own path when exec'd (main() below uses this).
# When sourced (by agent-sandbox.sh), AGENT_SANDBOX_REPO is already set.
_apply_self="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SANDBOX_REPO="${AGENT_SANDBOX_REPO:-$(cd "$_apply_self/../.." && pwd)}"

source "$AGENT_SANDBOX_REPO/scripts/guards.sh"
source "$AGENT_SANDBOX_REPO/src/libs/session_state.sh"
source "$AGENT_SANDBOX_REPO/src/libs/diff.sh"

# =============================================================================
# apply_run — apply a diff file
# =============================================================================

# apply_run PROJECT_DIR DIFF_FILE APPLY_BRANCH FORCE STRICT
#
# Applies a diff file to the project working tree. Does not create commits —
# leaves changes unstaged for operator review.
#
# Args:
#   PROJECT_DIR   — absolute path to the target git repository
#   DIFF_FILE     — absolute path to a diff file (uncommitted.diff or similar)
#   APPLY_BRANCH  — optional branch to checkout/create before applying
#   FORCE         — if true, apply with --reject; .rej files for conflicts
#   STRICT        — if true, disable --recount retry on apply failure
#                   to handle minor hunk-context drift (line reorders,
#                   whitespace shifts that don't affect the content delta)
#
# No internal path resolution — the caller (router in agent-sandbox.sh or
# explicit --diff=<path>) supplies the file path directly.
apply_run() {
  local PROJECT_DIR="$1"
  local DIFF_FILE="$2"
  local APPLY_BRANCH="${3:-}"
  local FORCE="${4:-false}"
  local STRICT="${5:-false}"

  if [[ -z "$PROJECT_DIR" || -z "$DIFF_FILE" ]]; then
    echo "apply_run: PROJECT_DIR and DIFF_FILE are required" >&2
    return 1
  fi

  if [[ ! -f "$DIFF_FILE" ]]; then
    echo "Error: diff file not found: $DIFF_FILE" >&2
    return 1
  fi

  validate_project_dir "$PROJECT_DIR" || return 1
  draft_clear_stale_lock "$PROJECT_DIR" || return 1

  # Optionally check out branch
  if [[ -n "$APPLY_BRANCH" ]]; then
    if git -C "$PROJECT_DIR" show-ref --verify --quiet "refs/heads/$APPLY_BRANCH"; then
      echo "Checking out existing branch: $APPLY_BRANCH"
      git -C "$PROJECT_DIR" checkout "$APPLY_BRANCH"
    else
      echo "Creating and checking out new branch: $APPLY_BRANCH"
      git -C "$PROJECT_DIR" checkout -b "$APPLY_BRANCH"
    fi
  fi

  echo "Applying $(basename "$DIFF_FILE") to $(git -C "$PROJECT_DIR" branch --show-current)..."

  if [[ "$FORCE" == true ]]; then
    echo "Force mode enabled: applying with --reject; .rej files will be created for conflicts."
  fi

  _apply_patch_file "$PROJECT_DIR" "$DIFF_FILE" "$FORCE" "$STRICT" || return 1

  # Count changed files from the diff
  local FILES_CHANGED
  FILES_CHANGED=$(grep -c "^diff --git" "$DIFF_FILE" || echo "0")

  echo ""
  echo "Done. Files changed: $FILES_CHANGED"
  if [[ "$FORCE" == true ]]; then
    echo "Force mode: check for .rej files and resolve any failed hunks."
  else
    echo "Review changes and commit manually."
  fi
  echo "Diff source: $DIFF_FILE"
}

# =============================================================================
# usage — print help text
# =============================================================================

usage() {
  cat <<EOF
Usage: agent-sandbox apply --project=<path> --sandbox=<path> [options]

Applies a diff file to the project working tree. Does not commit.

Required:
  --project=<path>    Path to the git repository
  --sandbox=<path>    Path to the sandbox directory

Options:
  --diff=<path>       Apply a specific diff file (default: auto-resolve)
  --branch=<name>     Check out or create a branch before applying
  --channel=<name>    Resolution channel: diffs, session, autosave (default: diffs)
  --bundle=<name>     Named bundle to resolve from (default: newest)
  --diff-type=<type>  Diff file type: uncommitted or all-changes (default: uncommitted)
  --force             Apply with --reject for conflicts
  --permissive        Retry with --recount on failure
  --interactive       Interactive picker mode
EOF
}

# =============================================================================
# main — entry point when exec'd by agent-sandbox apply
# =============================================================================

# Parses flags forwarded from agent-sandbox.sh dispatch and calls apply_run.
# Expected flags: --project=<dir> --sandbox=<dir> [--diff=<path>] [--branch=<n>] [--force] [--permissive] [--interactive]
main() {
  for ARG in "$@"; do
    case "$ARG" in
      --help|-h) usage; exit 0 ;;
    esac
  done

  local PROJECT_DIR=""
  local SANDBOX_DIR=""
  local DIFF_FILE=""
  local APPLY_BRANCH=""
  local FORCE=false
  local STRICT=false
  local CHANNEL=""
  local BUNDLE=""
  local INTERACTIVE=false
  local DIFF_TYPE=""

  for ARG in "$@"; do
    case "$ARG" in
      --project=*)     PROJECT_DIR="${ARG#--project=}" ;;
      --sandbox=*)     SANDBOX_DIR="${ARG#--sandbox=}" ;;
      --diff=*)        DIFF_FILE="${ARG#--diff=}" ;;
      --branch=*)      APPLY_BRANCH="${ARG#--branch=}" ;;
      --force)         FORCE=true ;;
      --permissive)    true ;;  # no-op, kept for compatibility
      --channel=*)     CHANNEL="${ARG#--channel=}" ;;
      --bundle=*)      BUNDLE="${ARG#--bundle=}" ;;
      --interactive)   INTERACTIVE=true ;;
      --diff-type=*)   DIFF_TYPE="${ARG#--diff-type=}" ;;
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

  # Interactive mode: let the operator pick or confirm via picker
  if [[ "$INTERACTIVE" == true ]]; then
    source "$AGENT_SANDBOX_REPO/scripts/workflows/interactive.sh"

    if [[ -n "$DIFF_FILE" ]]; then
      # --diff given: confirm with y/N and apply directly
      interactive_confirm_or_abort "Apply:" "$DIFF_FILE" || exit 1
      echo "Running: make apply DIFF=${DIFF_FILE}"
      apply_run "$PROJECT_DIR" "$DIFF_FILE" "$APPLY_BRANCH" "$FORCE" "$STRICT"
      exit $?
    fi

    # Step 1: pick channel (default from --channel or diffs)
    source "$AGENT_SANDBOX_REPO/src/libs/routing.sh"
    local CHANNEL
    CHANNEL=$(interactive_select_channel "apply" "$SANDBOX_DIR" "${CHANNEL:-diffs}") || exit 1
    # Step 2: pick bundle
    local BUNDLE
    BUNDLE=$(interactive_select_bundle "$SANDBOX_DIR" "$CHANNEL" "$BUNDLE") || exit 1
    # Step 3: pick diff type
    local DIFF_TYPE
    DIFF_TYPE=$(interactive_select_diff_type "$SANDBOX_DIR" "$BUNDLE" "$CHANNEL") || exit 1

    # Resolve the diff file path
    _resolve_paths "$SANDBOX_DIR"
    local BASE_DIR
    BASE_DIR=$(resolve_channel_base_dir "$CHANNEL") || exit 1
    local DIFF_FILE="${BASE_DIR}/${BUNDLE}/${DIFF_TYPE}.diff"
    if [[ ! -f "$DIFF_FILE" ]]; then
      echo "Error: diff file not found: $DIFF_FILE" >&2
      exit 1
    fi

    if [[ "$DIFF_TYPE" == "uncommitted" ]]; then
      echo "Running: make apply FROM=${CHANNEL} BUNDLE=${BUNDLE}"
    else
      echo "Running: make apply DIFF=${DIFF_FILE}"
    fi
    apply_run "$PROJECT_DIR" "$DIFF_FILE" "$APPLY_BRANCH" "$FORCE" "$STRICT"
    exit $?
  fi

  # Non-interactive path
  if [[ -n "$DIFF_FILE" ]]; then
    apply_run "$PROJECT_DIR" "$DIFF_FILE" "$APPLY_BRANCH" "$FORCE" "$STRICT"
  else
    source "$AGENT_SANDBOX_REPO/src/libs/routing.sh"
    local CHANNEL="${CHANNEL:-diffs}"
    local DIFF_TYPE="${DIFF_TYPE:-uncommitted}"

    # Resolve the diff file within the selected bundle, then swap the diff
    # file type (uncommitted vs all-changes)
    local RESOLVED
    RESOLVED=$(resolve_diff_for_apply "$SANDBOX_DIR" "$CHANNEL" "$BUNDLE") || exit 1
    local DIFF_FILE="${RESOLVED%/*}/${DIFF_TYPE}.diff"
    if [[ ! -f "$DIFF_FILE" ]]; then
      echo "Error: diff file not found: $DIFF_FILE" >&2
      echo "  Available types: uncommitted.diff, all-changes.diff" >&2
      exit 1
    fi
    apply_run "$PROJECT_DIR" "$DIFF_FILE" "$APPLY_BRANCH" "$FORCE" "$STRICT"
  fi
}

# Guard: only run main() when executed directly, not when sourced
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi

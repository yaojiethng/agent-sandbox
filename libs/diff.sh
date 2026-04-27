#!/usr/bin/env bash
# libs/diff.sh
# Diff pipeline functions for agent-sandbox.
# Sourced by sandbox-entrypoint.sh (capability layer).
#
# Functions:
#   diff_commit_pending  SANDBOX_DIR
#   diff_generate        SANDBOX_DIR  BASELINE_SHA  OUTPUT_FILE
#   diff_format_patch    SANDBOX_DIR  BASELINE_SHA  PATCHES_DIR
#   diff_on_exit         SANDBOX_DIR  BASELINE_SHA  CHANGES_DIR  SESSION_TS  SANITIZED_HOST_BRANCH
#   diff_on_autosave     SANDBOX_DIR  BASELINE_SHA  CHANGES_DIR  SESSION_TS  SANITIZED_HOST_BRANCH
#
# Directory structure under CHANGES_DIR/<SESSION_TS>-<SANITIZED_HOST_BRANCH>/:
#
#   session/
#     EXPORT-TIME.txt       — timestamp of the exit export (audit trail)
#     changes.diff          — uncommitted changes vs HEAD (before sweep commit)
#     staged.diff           — net delta INIT_SHA..HEAD (after sweep commit)
#     patches/
#       0001-<sha>.diff     — per-commit diffs from package_branch
#
#   autosave/
#     EXPORT-TIME.txt       — timestamp of the last autosave tick
#     changes.diff          — uncommitted changes vs HEAD (no sweep; agent still running)
#     patches/
#       0001-<sha>.diff     — per-commit diffs from package_branch
#
# Both subfolders are overwritten on each call. The session/ and autosave/
# separation prevents race conditions between the EXIT trap and the autosave
# loop writing to the same files.
#
# Note: package_branch() has been moved to libs/package_branch.sh

# SESSION_TS and SANITIZED_HOST_BRANCH are the session identity primitives.
# They are injected into the container environment at session start and passed
# as arguments to diff functions. SESSION_NAME is not used — directory paths
# are composed from these primitives directly.

# -------------------------
# diff_commit_pending
#
# Stages and commits any uncommitted changes in SANDBOX_DIR.
# A failed commit is an explicit error — no silent partial diffs.
# No-op if the working tree and index are clean with no untracked files.
# -------------------------
diff_commit_pending() {
  local SANDBOX_DIR="$1"

  if [[ -z "$SANDBOX_DIR" ]]; then
    echo "diff_commit_pending: SANDBOX_DIR is required" >&2
    return 1
  fi

  # Check for tracked changes (modified/deleted) and untracked files.
  # git diff and git diff --cached cover tracked changes; git ls-files covers untracked.
  local HAS_TRACKED_CHANGES HAS_UNTRACKED
  git -C "$SANDBOX_DIR" diff --quiet && HAS_TRACKED_CHANGES=0 || HAS_TRACKED_CHANGES=1
  git -C "$SANDBOX_DIR" diff --cached --quiet && true || HAS_TRACKED_CHANGES=1
  HAS_UNTRACKED=$(git -C "$SANDBOX_DIR" ls-files --others --exclude-standard | wc -l)

  if [[ "$HAS_TRACKED_CHANGES" -eq 1 || "$HAS_UNTRACKED" -gt 0 ]]; then
    git -C "$SANDBOX_DIR" add -A
    git -C "$SANDBOX_DIR" commit -m "agent-sandbox: uncommitted changes on exit" --quiet
  fi
}

# -------------------------
# diff_generate
#
# Computes git diff from BASELINE_SHA to HEAD in SANDBOX_DIR.
# Writes result to OUTPUT_FILE. No-op (no file written) if no changes.
# -------------------------
diff_generate() {
  local SANDBOX_DIR="$1"
  local BASELINE_SHA="$2"
  local OUTPUT_FILE="$3"

  if [[ -z "$SANDBOX_DIR" || -z "$BASELINE_SHA" || -z "$OUTPUT_FILE" ]]; then
    echo "diff_generate: SANDBOX_DIR, BASELINE_SHA, and OUTPUT_FILE are required" >&2
    return 1
  fi

  if git -C "$SANDBOX_DIR" diff --quiet "${BASELINE_SHA}..HEAD"; then
    echo "diff_generate: no changes detected against baseline ${BASELINE_SHA}" >&2
  else
    git -C "$SANDBOX_DIR" diff --binary -M "${BASELINE_SHA}..HEAD" > "$OUTPUT_FILE"
    echo "diff_generate: diff written to ${OUTPUT_FILE}" >&2
  fi
}

# -------------------------
# diff_write_changes_diff
#
# Writes uncommitted changes vs HEAD to OUTPUT_FILE.
# Strips git index lines and trailing whitespace for clean git apply.
# Writes an empty file if there are no uncommitted changes.
# -------------------------
diff_write_changes_diff() {
  local SANDBOX_DIR="$1"
  local OUTPUT_FILE="$2"

  # Stage untracked files so they appear in diff HEAD (git add -N = add to index
  # without content, so diff shows them). Restore staged state after.
  local UNTRACKED_STAGED=()
  local UNTRACKED
  UNTRACKED=$(git -C "$SANDBOX_DIR" ls-files --others --exclude-standard 2>/dev/null || true)
  if [[ -n "$UNTRACKED" ]]; then
    while IFS= read -r F; do
      git -C "$SANDBOX_DIR" add -N -- "$F" 2>/dev/null && UNTRACKED_STAGED+=("$F")
    done <<< "$UNTRACKED"
  fi

  if git -C "$SANDBOX_DIR" diff --quiet HEAD 2>/dev/null; then
    > "$OUTPUT_FILE"
  else
    git -C "$SANDBOX_DIR" diff HEAD \
      | grep -v '^index ' \
      | sed 's/[[:space:]]*$//' \
      | sed -e '$a\\' \
      > "$OUTPUT_FILE"
  fi

  # Restore staged state for untracked files
  if [[ ${#UNTRACKED_STAGED[@]} -gt 0 ]]; then
    git -C "$SANDBOX_DIR" restore --staged -- "${UNTRACKED_STAGED[@]}" 2>/dev/null || true
  fi
}

# -------------------------
# diff_format_patch
#
# Generates per-commit patch files from BASELINE_SHA to HEAD in SANDBOX_DIR.
# Writes numbered .patch files to PATCHES_DIR (e.g. 0001-....patch).
# No-op if there are no commits since baseline.
# -------------------------
diff_format_patch() {
  local SANDBOX_DIR="$1"
  local BASELINE_SHA="$2"
  local PATCHES_DIR="$3"

  if [[ -z "$SANDBOX_DIR" || -z "$BASELINE_SHA" || -z "$PATCHES_DIR" ]]; then
    echo "diff_format_patch: SANDBOX_DIR, BASELINE_SHA, and PATCHES_DIR are required" >&2
    return 1
  fi

  # Check if there are any commits since baseline
  if git -C "$SANDBOX_DIR" rev-list --count "${BASELINE_SHA}..HEAD" | grep -q '^0$'; then
    echo "diff_format_patch: no commits since baseline ${BASELINE_SHA}" >&2
    return 0
  fi

  mkdir -p "$PATCHES_DIR"
  git -C "$SANDBOX_DIR" format-patch "${BASELINE_SHA}..HEAD" \
    --output-directory "$PATCHES_DIR"
  
  local PATCH_COUNT
  PATCH_COUNT=$(ls -1 "$PATCHES_DIR"/*.patch 2>/dev/null | wc -l)
  echo "diff_format_patch: generated ${PATCH_COUNT} patch(es) in ${PATCHES_DIR}" >&2
}

# -------------------------
# diff_on_exit
#
# Captures uncommitted changes, commits pending changes, writes session
# artefacts, and calls package_branch. Called by the EXIT trap in
# sandbox-entrypoint.sh.
#
# Output layout under CHANGES_DIR/<SESSION_TS>-<SANITIZED_HOST_BRANCH>/:
#   session/EXPORT-TIME.txt   — audit trail timestamp
#   session/changes.diff      — uncommitted vs HEAD (before sweep)
#   session/staged.diff       — net delta INIT_SHA..HEAD (after sweep)
#   session/patches/          — per-commit .diff files from package_branch
# -------------------------
diff_on_exit() {
  local SANDBOX_DIR="$1"
  local BASELINE_SHA="$2"
  local CHANGES_DIR="$3"
  local SESSION_TS="$4"
  local SANITIZED_HOST_BRANCH="$5"

  if [[ -z "$SANDBOX_DIR" || -z "$BASELINE_SHA" || -z "$CHANGES_DIR" || -z "$SESSION_TS" || -z "$SANITIZED_HOST_BRANCH" ]]; then
    echo "diff_on_exit: SANDBOX_DIR, BASELINE_SHA, CHANGES_DIR, SESSION_TS, and SANITIZED_HOST_BRANCH are required" >&2
    return 1
  fi

  local OUTPUT_DIR="${CHANGES_DIR}/${SESSION_TS}-${SANITIZED_HOST_BRANCH}"
  local SESSION_DIR="${OUTPUT_DIR}/session"
  mkdir -p "$SESSION_DIR/patches"

  # Record export time for audit trail
  local EXPORT_TIME
  EXPORT_TIME=$(date -u +%Y%m%d-%H%M%S)
  echo "$EXPORT_TIME" > "$SESSION_DIR/EXPORT-TIME.txt"

  # Capture uncommitted changes BEFORE committing
  diff_write_changes_diff "$SANDBOX_DIR" "${SESSION_DIR}/changes.diff"

  # Commit any pending changes (sweep commit)
  echo "diff_on_exit: staging final diff..." >&2
  diff_commit_pending "$SANDBOX_DIR"

  # staged.diff — net delta from baseline to HEAD (after sweep)
  diff_generate "$SANDBOX_DIR" "$BASELINE_SHA" "${SESSION_DIR}/staged.diff"

  # Per-commit .diff files from package_branch
  local INIT_SHA=""
  if [[ -f "${SANDBOX_DIR}/.git/INIT_SHA" ]]; then
    INIT_SHA=$(cat "${SANDBOX_DIR}/.git/INIT_SHA")
  else
    echo "diff_on_exit: INIT_SHA not found, skipping package_branch" >&2
  fi

  if [[ -n "$INIT_SHA" ]]; then
    # Resolve package_branch.sh relative to this file (works in container and test envs)
    local _diff_sh_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "${_diff_sh_dir}/package_branch.sh"
    package_branch "$SANDBOX_DIR" "$INIT_SHA" "${SESSION_DIR}/patches"
  fi
}

# -------------------------
# diff_on_autosave
#
# Generates autosave artefacts without committing pending changes.
# The agent is still running; committing here would interfere
# with the agent's own git operations.
# Overwrites the autosave/ subfolder on each tick — one snapshot per
# session, updated in place.
# Called by the autosave loop in sandbox-entrypoint.sh.
#
# Output layout under CHANGES_DIR/<SESSION_TS>-<SANITIZED_HOST_BRANCH>/:
#   autosave/EXPORT-TIME.txt   — audit trail timestamp (last tick)
#   autosave/changes.diff      — uncommitted vs HEAD (no sweep)
#   autosave/patches/          — per-commit .diff files from package_branch
# -------------------------
diff_on_autosave() {
  local SANDBOX_DIR="$1"
  local BASELINE_SHA="$2"
  local CHANGES_DIR="$3"
  local SESSION_TS="$4"
  local SANITIZED_HOST_BRANCH="$5"

  if [[ -z "$SANDBOX_DIR" || -z "$BASELINE_SHA" || -z "$CHANGES_DIR" || -z "$SESSION_TS" || -z "$SANITIZED_HOST_BRANCH" ]]; then
    echo "diff_on_autosave: SANDBOX_DIR, BASELINE_SHA, CHANGES_DIR, SESSION_TS, and SANITIZED_HOST_BRANCH are required" >&2
    return 1
  fi

  local OUTPUT_DIR="${CHANGES_DIR}/${SESSION_TS}-${SANITIZED_HOST_BRANCH}"
  local AUTOSAVE_DIR="${OUTPUT_DIR}/autosave"
  mkdir -p "$AUTOSAVE_DIR/patches"

  # Record export time for audit trail
  local EXPORT_TIME
  EXPORT_TIME=$(date -u +%Y%m%d-%H%M%S)
  echo "$EXPORT_TIME" > "$AUTOSAVE_DIR/EXPORT-TIME.txt"

  echo "diff_on_autosave: writing checkpoint..." >&2

  # Uncommitted changes vs HEAD (no sweep — agent is still running)
  diff_write_changes_diff "$SANDBOX_DIR" "${AUTOSAVE_DIR}/changes.diff"

  # Per-commit .diff files from package_branch (committed work since INIT_SHA)
  local INIT_SHA=""
  if [[ -f "${SANDBOX_DIR}/.git/INIT_SHA" ]]; then
    INIT_SHA=$(cat "${SANDBOX_DIR}/.git/INIT_SHA")
  fi

  if [[ -n "$INIT_SHA" ]]; then
    local _diff_sh_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "${_diff_sh_dir}/package_branch.sh"
    package_branch "$SANDBOX_DIR" "$INIT_SHA" "${AUTOSAVE_DIR}/patches"
  fi

  echo "diff_on_autosave: checkpoint written to ${AUTOSAVE_DIR}" >&2
}
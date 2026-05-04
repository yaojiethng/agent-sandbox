#!/usr/bin/env bash
# libs/diff.sh
# Diff pipeline functions for agent-sandbox.
# Sourced by sandbox-entrypoint.sh (capability layer) and package_branch.sh.
#
# Functions:
#   write_uncommitted_diff   SANDBOX_DIR  OUTPUT_FILE
#   write_all_changes_diff   SANDBOX_DIR  OUTPUT_FILE
#   write_changed_files      SANDBOX_DIR  SINCE_SHA  OUTPUT_DIR
#   diff_on_exit             SANDBOX_DIR  CHANGES_DIR  SESSION_TS  SANITIZED_HOST_BRANCH
#   diff_on_autosave         SANDBOX_DIR  CHANGES_DIR  SESSION_TS  SANITIZED_HOST_BRANCH
#
# Directory structure under CHANGES_DIR/<SESSION_TS>-<SANITIZED_HOST_BRANCH>/:
#
#   session/
#     EXPORT-TIME.txt          — timestamp of the exit export (audit trail)
#     uncommitted.diff         — uncommitted changes vs HEAD (via write_uncommitted_diff)
#     all-changes.diff         — net delta INIT_SHA..HEAD (via write_all_changes_diff)
#     patches/
#       0001-<sha>.diff        — per-commit diffs from package_branch dispatcher
#     changed-files/
#       MANIFEST.txt
#       <path>/<file>          — working tree copies of all changed files
#
#   autosave/
#     EXPORT-TIME.txt          — timestamp of the last autosave tick
#     uncommitted.diff         — uncommitted changes vs HEAD (no sweep; agent running)
#     patches/
#       0001-<sha>.diff        — per-commit diffs from package_branch dispatcher
#     changed-files/
#       MANIFEST.txt
#       <path>/<file>          — working tree copies of all changed files
#
# Both subfolders are overwritten on each call. The session/ and autosave/
# separation prevents race conditions between the EXIT trap and the autosave
# loop writing to the same files.

# SESSION_TS and SANITIZED_HOST_BRANCH are the session identity primitives.
# They are injected into the container environment at session start and passed
# as arguments to diff functions.

# -------------------------
# Source session.sh for session_state_read
_DIFF_SH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_DIFF_SH_DIR/session.sh"

# -------------------------
# write_uncommitted_diff
#
# Writes uncommitted changes vs HEAD to OUTPUT_FILE.
# Strips git index lines and trailing whitespace for clean git apply.
# Stages untracked files temporarily (via git add -N) so they appear in the
# diff, then restores staged state after. Writes an empty file if no changes.
# -------------------------
write_uncommitted_diff() {
  local SANDBOX_DIR="$1"
  local OUTPUT_FILE="$2"

  if [[ -z "$SANDBOX_DIR" || -z "$OUTPUT_FILE" ]]; then
    echo "write_uncommitted_diff: SANDBOX_DIR and OUTPUT_FILE are required" >&2
    return 1
  fi

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
# write_all_changes_diff
#
# Writes a unified diff of all changes since INIT_SHA (committed + uncommitted)
# to OUTPUT_FILE. Reads init_sha from SESSION_STATE.
# Stages untracked files temporarily (via git add -N) so they appear in the
# diff, then restores staged state after. Writes an empty file if no changes.
# Uses `git diff INIT_SHA` (not range syntax) so uncommitted changes are
# included alongside committed changes.
# -------------------------
write_all_changes_diff() {
  local SANDBOX_DIR="$1"
  local OUTPUT_FILE="$2"

  if [[ -z "$SANDBOX_DIR" || -z "$OUTPUT_FILE" ]]; then
    echo "write_all_changes_diff: SANDBOX_DIR and OUTPUT_FILE are required" >&2
    return 1
  fi

  local INIT_SHA
  INIT_SHA=$(session_state_read "$SANDBOX_DIR" "init_sha")
  if [[ -z "$INIT_SHA" ]]; then
    echo "write_all_changes_diff: init_sha not found in SESSION_STATE" >&2
    return 1
  fi

  # Stage untracked files so they appear in the diff
  local UNTRACKED_STAGED=()
  local UNTRACKED
  UNTRACKED=$(git -C "$SANDBOX_DIR" ls-files --others --exclude-standard 2>/dev/null || true)
  if [[ -n "$UNTRACKED" ]]; then
    while IFS= read -r F; do
      git -C "$SANDBOX_DIR" add -N -- "$F" 2>/dev/null && UNTRACKED_STAGED+=("$F")
    done <<< "$UNTRACKED"
  fi

  if git -C "$SANDBOX_DIR" diff --quiet "$INIT_SHA" 2>/dev/null; then
    > "$OUTPUT_FILE"
  else
    git -C "$SANDBOX_DIR" diff "$INIT_SHA" \
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
# write_changed_files
#
# Copies all changed files since SINCE_SHA into OUTPUT_DIR/changed-files/,
# preserving directory structure relative to repo root. Produces MANIFEST.txt
# listing every copied file. Deleted files are skipped. Untracked files are
# included.
# -------------------------
write_changed_files() {
  local SANDBOX_DIR="$1"
  local SINCE_SHA="$2"
  local OUTPUT_DIR="$3"

  if [[ -z "$SANDBOX_DIR" || -z "$SINCE_SHA" || -z "$OUTPUT_DIR" ]]; then
    echo "write_changed_files: SANDBOX_DIR, SINCE_SHA, and OUTPUT_DIR are required" >&2
    return 1
  fi

  local CHANGED_FILES_DIR="$OUTPUT_DIR/changed-files"
  mkdir -p "$CHANGED_FILES_DIR"

  # Build deduplicated file list: diff --name-only (committed/staged/unstaged)
  # plus ls-files --others (untracked). sort -u deduplicates.
  local FILE_LIST
  FILE_LIST=$({
    git -C "$SANDBOX_DIR" diff --name-only "$SINCE_SHA" 2>/dev/null || true
    git -C "$SANDBOX_DIR" ls-files --others --exclude-standard 2>/dev/null || true
  } | sort -u)

  local COPY_COUNT=0
  while IFS= read -r F; do
    [[ -z "$F" ]] && continue
    # Skip deleted files — they no longer exist in the working tree
    [[ -f "$SANDBOX_DIR/$F" ]] || continue
    mkdir -p "$CHANGED_FILES_DIR/$(dirname "$F")"
    cp "$SANDBOX_DIR/$F" "$CHANGED_FILES_DIR/$F"
    COPY_COUNT=$((COPY_COUNT + 1))
  done <<< "$FILE_LIST"

  # Write manifest
  if [[ "$COPY_COUNT" -gt 0 ]]; then
    echo "$FILE_LIST" > "$CHANGED_FILES_DIR/MANIFEST.txt"
  else
    # Remove empty directory
    rmdir "$CHANGED_FILES_DIR" 2>/dev/null || true
  fi
}

# -------------------------
# diff_on_exit
#
# Thin dispatcher: creates output directory, writes EXPORT-TIME.txt, calls
# package_branch which orchestrates all four output operations.
# Called by the EXIT trap in sandbox-entrypoint.sh.
# No sweep commit — uncommitted changes are captured in uncommitted.diff.
#
# Output layout under CHANGES_DIR/<SESSION_TS>-<SANITIZED_HOST_BRANCH>/:
#   session/EXPORT-TIME.txt
#   session/patches/
#   session/uncommitted.diff
#   session/all-changes.diff
#   session/changed-files/
# -------------------------
diff_on_exit() {
  local SANDBOX_DIR="$1"
  local CHANGES_DIR="$2"
  local SESSION_TS="$3"
  local SANITIZED_HOST_BRANCH="$4"

  if [[ -z "$SANDBOX_DIR" || -z "$CHANGES_DIR" || -z "$SESSION_TS" || -z "$SANITIZED_HOST_BRANCH" ]]; then
    echo "diff_on_exit: SANDBOX_DIR, CHANGES_DIR, SESSION_TS, and SANITIZED_HOST_BRANCH are required" >&2
    return 1
  fi

  local OUTPUT_DIR="${CHANGES_DIR}/${SESSION_TS}-${SANITIZED_HOST_BRANCH}"
  local SESSION_DIR="${OUTPUT_DIR}/session"
  mkdir -p "$SESSION_DIR"

  # Record export time for audit trail
  local EXPORT_TIME
  EXPORT_TIME=$(date -u +%Y%m%d-%H%M%S)
  echo "$EXPORT_TIME" > "$SESSION_DIR/EXPORT-TIME.txt"

  # Delegate to package_branch dispatcher
  echo "diff_on_exit: packaging session artefacts..." >&2
  local _diff_sh_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  source "${_diff_sh_dir}/package_branch.sh"
  package_branch "$SANDBOX_DIR" "$SESSION_DIR"
}

# -------------------------
# diff_on_autosave
#
# Thin dispatcher: creates output directory, writes EXPORT-TIME.txt, calls
# package_branch which orchestrates all four output operations.
# No sweep commit — agent is still running; committing would interfere.
# Overwrites the autosave/ subfolder on each tick.
# Called by the autosave loop in sandbox-entrypoint.sh.
#
# Output layout under CHANGES_DIR/<SESSION_TS>-<SANITIZED_HOST_BRANCH>/:
#   autosave/EXPORT-TIME.txt
#   autosave/patches/
#   autosave/uncommitted.diff
#   autosave/all-changes.diff
#   autosave/changed-files/
# -------------------------
diff_on_autosave() {
  local SANDBOX_DIR="$1"
  local CHANGES_DIR="$2"
  local SESSION_TS="$3"
  local SANITIZED_HOST_BRANCH="$4"

  if [[ -z "$SANDBOX_DIR" || -z "$CHANGES_DIR" || -z "$SESSION_TS" || -z "$SANITIZED_HOST_BRANCH" ]]; then
    echo "diff_on_autosave: SANDBOX_DIR, CHANGES_DIR, SESSION_TS, and SANITIZED_HOST_BRANCH are required" >&2
    return 1
  fi

  local OUTPUT_DIR="${CHANGES_DIR}/${SESSION_TS}-${SANITIZED_HOST_BRANCH}"
  local AUTOSAVE_DIR="${OUTPUT_DIR}/autosave"
  mkdir -p "$AUTOSAVE_DIR"

  # Record export time for audit trail
  local EXPORT_TIME
  EXPORT_TIME=$(date -u +%Y%m%d-%H%M%S)
  echo "$EXPORT_TIME" > "$AUTOSAVE_DIR/EXPORT-TIME.txt"

  echo "diff_on_autosave: writing checkpoint..." >&2

  # Delegate to package_branch dispatcher
  local _diff_sh_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  source "${_diff_sh_dir}/package_branch.sh"
  package_branch "$SANDBOX_DIR" "$AUTOSAVE_DIR"
}

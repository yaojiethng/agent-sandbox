#!/usr/bin/env bash
# libs/diff.sh
# Diff pipeline functions for agent-sandbox.
# Sourced by sandbox-entrypoint.sh (capability layer).
#
# Functions:
#   write_uncommitted_diff   SANDBOX_DIR  OUTPUT_FILE
#   write_all_changes_diff   SANDBOX_DIR  INIT_SHA  OUTPUT_FILE
#   write_changed_files      SANDBOX_DIR  SINCE_SHA  OUTPUT_DIR
#   diff_generate            SANDBOX_DIR  since_sha  OUTPUT_FILE
#   diff_format_patch        SANDBOX_DIR  since_sha  PATCHES_DIR
#   diff_on_exit             SANDBOX_DIR  CHANGES_DIR  SESSION_TS  SANITIZED_HOST_BRANCH
#   diff_on_autosave         SANDBOX_DIR  CHANGES_DIR  SESSION_TS  SANITIZED_HOST_BRANCH
#
# Directory structure under CHANGES_DIR/<SESSION_TS>-<SANITIZED_HOST_BRANCH>/:
#
#   session/
#     EXPORT-TIME.txt       — timestamp of the exit export (audit trail)
#     uncommitted.diff      — uncommitted changes vs HEAD
#     all-changes.diff      — net delta INIT_SHA..HEAD (includes committed + uncommitted)
#     patches/
#       0001-<sha>.diff     — per-commit diffs from package_branch
#     changed-files/        — working tree copies of all changed files + MANIFEST.txt
#
#   autosave/
#     EXPORT-TIME.txt       — timestamp of the last autosave tick
#     uncommitted.diff      — uncommitted changes vs HEAD
#     all-changes.diff      — net delta INIT_SHA..HEAD
#     patches/
#       0001-<sha>.diff     — per-commit diffs from package_branch
#     changed-files/        — working tree copies of all changed files + MANIFEST.txt
#
# Both subfolders are overwritten on each call. The session/ and autosave/
# separation prevents race conditions between the EXIT trap and the autosave
# loop writing to the same files.

# SESSION_TS and SANITIZED_HOST_BRANCH are the session identity primitives.
# They are injected into the container environment at session start and passed
# as arguments to diff functions. SESSION_NAME is not used — directory paths
# are composed from these primitives directly.

# -------------------------
# write_uncommitted_diff
#
# Writes uncommitted changes vs HEAD to OUTPUT_FILE.
# Strips git index lines and trailing whitespace for clean git apply.
# Writes an empty file if there are no uncommitted changes.
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
# Writes all changes since INIT_SHA to OUTPUT_FILE (git diff INIT_SHA..HEAD).
# Includes both committed and uncommitted changes.
# Writes nothing (no file) if there are no changes.
# -------------------------
write_all_changes_diff() {
  local SANDBOX_DIR="$1"
  local INIT_SHA="$2"
  local OUTPUT_FILE="$3"

  if [[ -z "$SANDBOX_DIR" || -z "$INIT_SHA" || -z "$OUTPUT_FILE" ]]; then
    echo "write_all_changes_diff: SANDBOX_DIR, INIT_SHA, and OUTPUT_FILE are required" >&2
    return 1
  fi

  # Stage untracked files so they appear in diff
  local UNTRACKED_STAGED=()
  local UNTRACKED
  UNTRACKED=$(git -C "$SANDBOX_DIR" ls-files --others --exclude-standard 2>/dev/null || true)
  if [[ -n "$UNTRACKED" ]]; then
    while IFS= read -r F; do
      git -C "$SANDBOX_DIR" add -N -- "$F" 2>/dev/null && UNTRACKED_STAGED+=("$F")
    done <<< "$UNTRACKED"
  fi

  if git -C "$SANDBOX_DIR" diff --quiet "${INIT_SHA}" 2>/dev/null; then
    echo "write_all_changes_diff: no changes detected since ${INIT_SHA}" >&2
  else
    git -C "$SANDBOX_DIR" diff --binary -M "${INIT_SHA}" > "$OUTPUT_FILE"
    echo "write_all_changes_diff: diff written to ${OUTPUT_FILE}" >&2
  fi

  # Restore staged state for untracked files
  if [[ ${#UNTRACKED_STAGED[@]} -gt 0 ]]; then
    git -C "$SANDBOX_DIR" restore --staged -- "${UNTRACKED_STAGED[@]}" 2>/dev/null || true
  fi
}

# -------------------------
# write_changed_files
#
# Copies all files changed since SINCE_SHA into OUTPUT_DIR/changed-files/,
# preserving directory structure relative to repo root.
# Writes OUTPUT_DIR/changed-files/MANIFEST.txt with sorted unique paths.
# Skips deleted files (no longer in working tree).
# Removes changed-files/ entirely if no files exist to copy.
#
# Two-source file list:
#   git diff --name-only SINCE_SHA  — committed, staged, and unstaged changes
#   git ls-files --others           — untracked files
# -------------------------
write_changed_files() {
  local SANDBOX_DIR="$1"
  local SINCE_SHA="$2"
  local OUTPUT_DIR="$3"

  if [[ -z "$SANDBOX_DIR" || -z "$SINCE_SHA" || -z "$OUTPUT_DIR" ]]; then
    echo "write_changed_files: SANDBOX_DIR, SINCE_SHA, and OUTPUT_DIR are required" >&2
    return 1
  fi

  local CHANGED_DIR="$OUTPUT_DIR/changed-files"
  mkdir -p "$CHANGED_DIR"

  # Build sorted unique manifest from two sources
  {
    git -C "$SANDBOX_DIR" diff --name-only "$SINCE_SHA" 2>/dev/null || true
    git -C "$SANDBOX_DIR" ls-files --others --exclude-standard 2>/dev/null || true
  } | sort -u > "$CHANGED_DIR/MANIFEST.txt"

  # Remove empty lines
  sed -i '/^$/d' "$CHANGED_DIR/MANIFEST.txt" 2>/dev/null || \
    sed -i '' '/^$/d' "$CHANGED_DIR/MANIFEST.txt" 2>/dev/null || true

  # Copy files that exist in working tree; skip deleted files
  local COUNT=0
  while IFS= read -r F; do
    [[ -z "$F" ]] && continue
    [[ -f "$SANDBOX_DIR/$F" ]] || continue
    mkdir -p "$CHANGED_DIR/$(dirname "$F")"
    cp "$SANDBOX_DIR/$F" "$CHANGED_DIR/$F"
    COUNT=$((COUNT + 1))
  done < "$CHANGED_DIR/MANIFEST.txt"

  # Clean up if nothing to copy
  if [[ "$COUNT" -eq 0 ]]; then
    rm -rf "$CHANGED_DIR"
  fi
}

# -------------------------
# diff_generate
#
# Computes git diff from since_sha to HEAD in SANDBOX_DIR.
# Writes result to OUTPUT_FILE. No-op (no file written) if no changes.
# -------------------------
diff_generate() {
  local SANDBOX_DIR="$1"
  local since_sha="$2"
  local OUTPUT_FILE="$3"

  if [[ -z "$SANDBOX_DIR" || -z "$since_sha" || -z "$OUTPUT_FILE" ]]; then
    echo "diff_generate: SANDBOX_DIR, since_sha, and OUTPUT_FILE are required" >&2
    return 1
  fi

  if git -C "$SANDBOX_DIR" diff --quiet "${since_sha}..HEAD"; then
    echo "diff_generate: no changes detected against ${since_sha}" >&2
  else
    git -C "$SANDBOX_DIR" diff --binary -M "${since_sha}..HEAD" > "$OUTPUT_FILE"
    echo "diff_generate: diff written to ${OUTPUT_FILE}" >&2
  fi
}

# -------------------------
# diff_format_patch
#
# Generates per-commit patch files from since_sha to HEAD in SANDBOX_DIR.
# Writes numbered .patch files to PATCHES_DIR (e.g. 0001-....patch).
# No-op if there are no commits since the given sha.
# -------------------------
diff_format_patch() {
  local SANDBOX_DIR="$1"
  local since_sha="$2"
  local PATCHES_DIR="$3"

  if [[ -z "$SANDBOX_DIR" || -z "$since_sha" || -z "$PATCHES_DIR" ]]; then
    echo "diff_format_patch: SANDBOX_DIR, since_sha, and PATCHES_DIR are required" >&2
    return 1
  fi

  # Check if there are any commits since baseline
  if git -C "$SANDBOX_DIR" rev-list --count "${since_sha}..HEAD" | grep -q '^0$'; then
    echo "diff_format_patch: no commits since ${since_sha}" >&2
    return 0
  fi

  mkdir -p "$PATCHES_DIR"
  git -C "$SANDBOX_DIR" format-patch "${since_sha}..HEAD" \
    --output-directory "$PATCHES_DIR"

  local PATCH_COUNT
  PATCH_COUNT=$(ls -1 "$PATCHES_DIR"/*.patch 2>/dev/null | wc -l)
  echo "diff_format_patch: generated ${PATCH_COUNT} patch(es) in ${PATCHES_DIR}" >&2
}

# -------------------------
# diff_on_exit
#
# Captures session artefacts via the package_branch dispatcher.
# Called by the EXIT trap in sandbox-entrypoint.sh.
#
# Output layout under CHANGES_DIR/<SESSION_TS>-<SANITIZED_HOST_BRANCH>/:
#   session/EXPORT-TIME.txt   — audit trail timestamp
#   session/uncommitted.diff  — uncommitted vs HEAD
#   session/all-changes.diff  — net delta INIT_SHA..HEAD
#   session/patches/          — per-commit .diff files
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

  local OUTPUT_DIR="${CHANGES_DIR}/${SESSION_TS}-${SANITIZED_HOST_BRANCH}/session"
  mkdir -p "$OUTPUT_DIR"

  # Record export time for audit trail
  local EXPORT_TIME
  EXPORT_TIME=$(date -u +%Y%m%d-%H%M%S)
  echo "$EXPORT_TIME" > "$OUTPUT_DIR/EXPORT-TIME.txt"

  # Source package_branch.sh and call the dispatcher for unified output
  local _diff_sh_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  source "${_diff_sh_dir}/package_branch.sh"
  package_branch "$SANDBOX_DIR" "$OUTPUT_DIR"
}

# -------------------------
# diff_on_autosave
#
# Generates autosave artefacts via the package_branch dispatcher.
# Overwrites the autosave/ subfolder on each tick.
# Called by the autosave loop in sandbox-entrypoint.sh.
#
# Output layout under CHANGES_DIR/<SESSION_TS>-<SANITIZED_HOST_BRANCH>/:
#   autosave/EXPORT-TIME.txt   — audit trail timestamp (last tick)
#   autosave/uncommitted.diff  — uncommitted vs HEAD
#   autosave/all-changes.diff  — net delta INIT_SHA..HEAD
#   autosave/patches/          — per-commit .diff files
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

  local OUTPUT_DIR="${CHANGES_DIR}/${SESSION_TS}-${SANITIZED_HOST_BRANCH}/autosave"
  mkdir -p "$OUTPUT_DIR"

  # Record export time for audit trail
  local EXPORT_TIME
  EXPORT_TIME=$(date -u +%Y%m%d-%H%M%S)
  echo "$EXPORT_TIME" > "$OUTPUT_DIR/EXPORT-TIME.txt"

  echo "diff_on_autosave: writing checkpoint..." >&2

  # Source package_branch.sh and call the dispatcher for unified output
  local _diff_sh_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  source "${_diff_sh_dir}/package_branch.sh"
  package_branch "$SANDBOX_DIR" "$OUTPUT_DIR"

  echo "diff_on_autosave: checkpoint written to ${OUTPUT_DIR}" >&2
}

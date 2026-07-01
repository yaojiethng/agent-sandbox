#!/usr/bin/env bash
# libs/diff.sh
# Diff pipeline functions for agent-sandbox.
# Sourced by sandbox-entrypoint.sh (capability layer) and package_branch.sh.
#
# Functions:
#   write_uncommitted_diff   SANDBOX_DIR  OUTPUT_FILE
#   write_all_changes_diff   SANDBOX_DIR  OUTPUT_FILE
#   write_changed_files      SANDBOX_DIR  SINCE_SHA  OUTPUT_DIR
#
# All three functions are pure primitives — no dispatch logic, no session
# resolution. Path construction is the caller's responsibility.
#
# Directory layout under OUTPUT_DIR/ (caller constructs the path):
#
#   EXPORT-TIME.txt          — timestamp of the export (audit trail)
#   uncommitted.diff         — uncommitted changes vs HEAD
#   all-changes.diff         — net delta INIT_SHA..HEAD
#   patches/
#     0001-<sha>.diff        — per-commit diffs from package_branch dispatcher
#   changed-files/
#     MANIFEST.txt
#     <path>/<file>          — working tree copies of all changed files

# -------------------------
# Source session_state.sh for session_state_read; source routing.sh for path helpers
_self_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_self_dir/session_state.sh"
source "$_self_dir/routing.sh"

# -------------------------
# strip_index_lines
#
# Filters git diff output: strips index lines from text diffs (cosmetic),
# preserves index lines for binary diffs (required by git apply).
#
# Without this filter, index lines from text diffs cause cosmetic SHA
# mismatches when applying across repos with different histories.
# Without preserving binary index lines, git apply rejects binary patches.
#
# Usage:  git diff ... | strip_index_lines > file.diff
#         git apply --ignore-whitespace < <(strip_index_lines < file.diff)
# -------------------------
strip_index_lines() {
  awk '/^index / { saved=$0; getline nl; if (nl ~ /^GIT binary patch/) print saved; print nl; next } 1'
}

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
      | strip_index_lines \
      | sed -e '/^[+]/ s/[[:space:]]*$//' -e '/^[-]/ s/[[:space:]]*$//' \
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
# Writes a unified diff of all changes since a baseline (committed + uncommitted)
# to OUTPUT_FILE. Reads init_sha from SESSION_STATE by default, or uses an
# explicit SINCE_SHA if provided (for --baseline flag).
# Stages untracked files temporarily (via git add -N) so they appear in the
# diff, then restores staged state after. Writes an empty file if no changes.
# Uses `git diff <baseline>` (not range syntax) so uncommitted changes are
# included alongside committed changes.
#
# Args:
#   SANDBOX_DIR  — path to the git repository
#   OUTPUT_FILE  — path to write the diff to
#   SINCE_SHA    — optional explicit baseline SHA; if omitted, reads init_sha
#                  from SESSION_STATE
# -------------------------
write_all_changes_diff() {
  local SANDBOX_DIR="$1"
  local OUTPUT_FILE="$2"
  local SINCE_SHA="${3:-}"

  if [[ -z "$SANDBOX_DIR" || -z "$OUTPUT_FILE" ]]; then
    echo "write_all_changes_diff: SANDBOX_DIR and OUTPUT_FILE are required" >&2
    return 1
  fi

  if [[ -z "$SINCE_SHA" ]]; then
    SINCE_SHA=$(session_state_read "$SANDBOX_DIR" "init_sha")
    if [[ -z "$SINCE_SHA" ]]; then
      echo "write_all_changes_diff: init_sha not found in SESSION_STATE and no SINCE_SHA provided" >&2
      return 1
    fi
  fi

  local INIT_SHA="$SINCE_SHA"

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
      | strip_index_lines \
      | sed -e '/^[+]/ s/[[:space:]]*$//' -e '/^[-]/ s/[[:space:]]*$//' \
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

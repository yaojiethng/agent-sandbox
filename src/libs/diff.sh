#!/usr/bin/env bash
# libs/diff.sh
# Diff pipeline functions for agent-sandbox.
# Sourced by sandbox-entrypoint.sh (capability layer) and package_branch.sh.
#
# Functions:
#   _apply_patch_file        PROJECT_DIR  DIFF_FILE  FORCE
#   apply_and_commit         PROJECT_DIR  DIFF_FILE  COMMIT_MSG  AUTHOR  [FORCE]
#   write_uncommitted_diff   SANDBOX_DIR  OUTPUT_FILE
#   write_all_changes_diff   SANDBOX_DIR  OUTPUT_FILE
#   write_changed_files      SANDBOX_DIR  SINCE_SHA  OUTPUT_DIR
#
# All three functions are pure primitives — no dispatch logic, no session
# resolution. Path construction is the caller's responsibility.
#
# Directory layout under OUTPUT_DIR/ (caller constructs the path):
#
#   .export-status           — consolidated metadata (STATUS, TIMESTAMP, INIT_SHA)
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
# _diff_stage_untracked SANDBOX_DIR
#   Stages untracked files intent-to-add (`git add -N`) so they appear in
#   diffs, without adding their content to the index. Populates the global
#   array _DIFF_STAGED_UNTRACKED for _diff_restore_untracked.
_diff_stage_untracked() {
  local dir="$1"
  _DIFF_STAGED_UNTRACKED=()
  local untracked f
  untracked=$(git -C "$dir" ls-files --others --exclude-standard 2>/dev/null || true)
  [[ -n "$untracked" ]] || return 0
  while IFS= read -r f; do
    git -C "$dir" add -N -- "$f" 2>/dev/null && _DIFF_STAGED_UNTRACKED+=("$f")
  done <<< "$untracked"
}

# _diff_restore_untracked SANDBOX_DIR
#   Restores the index state changed by _diff_stage_untracked.
_diff_restore_untracked() {
  local dir="$1"
  if [[ ${#_DIFF_STAGED_UNTRACKED[@]} -gt 0 ]]; then
    git -C "$dir" restore --staged -- "${_DIFF_STAGED_UNTRACKED[@]}" 2>/dev/null || true
  fi
}

# _write_git_diff SANDBOX_DIR BASE OUTPUT_FILE
#   Writes `git diff BASE` to OUTPUT_FILE with index lines stripped and a
#   guaranteed trailing newline. Writes an empty file when there are no
#   changes vs BASE. Single source of truth for the verbatim-diff contract
#   shared by write_uncommitted_diff and write_all_changes_diff.
_write_git_diff() {
  local dir="$1" base="$2" out="$3"
  if git -C "$dir" diff --quiet "$base" 2>/dev/null; then
    > "$out"
  else
    git -C "$dir" diff "$base" \
      | strip_index_lines \
      | sed -e '$a\\' \
      > "$out"
  fi
}

strip_index_lines() {
  awk '/^index / { saved=$0; getline nl; if (nl ~ /^GIT binary patch/) print saved; print nl; next } 1'
}

# -------------------------
# _apply_patch_file
#
# Core git apply logic shared by apply_run (apply-only) and
# apply_and_commit (apply + commit). Strips index lines, handles three
# modes:
#   normal     — git apply --ignore-whitespace; on failure retries with
#                --recount for relaxed hunk-context matching (permissive
#                by default).
#   force      — git apply --reject; creates .rej files for conflicts,
#                never returns 1 (warnings printed to stderr)
#
# Usage:
#   _apply_patch_file PROJECT_DIR DIFF_FILE FORCE
#
# Returns:
#   0 — patch applied successfully (or force mode, conflicts tolerated)
#   1 — patch failed to apply (recount retry also failed)
# -------------------------
_apply_patch_file() {
  local PROJECT_DIR="$1"
  local DIFF_FILE="$2"
  local FORCE="${3:-false}"

  if [[ "$FORCE" == true ]]; then
    git -C "$PROJECT_DIR" apply --reject < <(strip_index_lines < "$DIFF_FILE") || \
      echo "Warning: some hunks failed to apply. Review .rej files." >&2
    return 0
  fi

  # Normal mode: try --ignore-whitespace first; on failure, retry with
  # --recount for relaxed hunk-context matching (permissive by default).
  if ! git -C "$PROJECT_DIR" apply --ignore-whitespace < <(strip_index_lines < "$DIFF_FILE"); then
    if git -C "$PROJECT_DIR" apply --check --recount --ignore-whitespace < <(strip_index_lines < "$DIFF_FILE") 2>/dev/null; then
      echo "Normal apply failed; retrying with --recount (relaxed context matching)..." >&2
      git -C "$PROJECT_DIR" apply --recount --ignore-whitespace < <(strip_index_lines < "$DIFF_FILE")
    else
      echo "Error: git apply failed." >&2
      echo "  Diff file: $DIFF_FILE" >&2
      echo "  Target: $(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)" >&2
      echo "" >&2
      echo "Hints:" >&2
      echo "  Use FORCE=true to apply with --reject (.rej files for conflicts)." >&2
      return 1
    fi
  fi

  return 0
}

# -------------------------
# diff_is_empty
#
# True when DIFF_FILE exists and carries no `diff --git` headers, i.e.
# represents zero changes. Shared by all apply paths to honor the decided
# empty-diff behavior: skip uncommitted.diff with a warning; land bundle
# members as message-bearing empty commits with a warning.
# -------------------------
diff_is_empty() {
  local DIFF_FILE="$1"
  [[ -f "$DIFF_FILE" ]] || return 1
  ! grep -q "^diff --git" "$DIFF_FILE"
}

# -------------------------
# apply_and_commit
#
# Applies a diff file via _apply_patch_file, then stages all changes and
# commits. Used by draft_apply_patches for per-patch commit workflow.
#
# Usage:
#   apply_and_commit PROJECT_DIR DIFF_FILE COMMIT_MSG AUTHOR [FORCE]
#
# Does NOT leave changes unstaged — after success, everything is committed.
# Returns 1 if apply fails (and FORCE is not set).
# -------------------------
apply_and_commit() {
  local PROJECT_DIR="$1"
  local DIFF_FILE="$2"
  local COMMIT_MSG="$3"
  local AUTHOR="$4"
  local FORCE="${5:-false}"

  if [[ -z "$PROJECT_DIR" || -z "$DIFF_FILE" || -z "$COMMIT_MSG" || -z "$AUTHOR" ]]; then
    echo "apply_and_commit: PROJECT_DIR, DIFF_FILE, COMMIT_MSG, and AUTHOR are required" >&2
    return 1
  fi

  if [[ ! -f "$DIFF_FILE" ]]; then
    echo "Error: diff file not found: $DIFF_FILE" >&2
    return 1
  fi

  # Empty member diff: no patch to apply, but the associated commit message
  # must still survive in history. Land an empty commit. No `git add -A` --
  # an empty member means no intended change, so unrelated working-tree
  # noise must not be swept into it.
  if diff_is_empty "$DIFF_FILE"; then
    echo "Warning: $(basename "$DIFF_FILE") is empty; creating an empty commit for its message." >&2
    git -C "$PROJECT_DIR" commit --allow-empty -m "$COMMIT_MSG" --author="$AUTHOR"
    return 0
  fi

  _apply_patch_file "$PROJECT_DIR" "$DIFF_FILE" "$FORCE" || return 1

  git -C "$PROJECT_DIR" add -A
  git -C "$PROJECT_DIR" commit -m "$COMMIT_MSG" --author="$AUTHOR"

  return 0
}

# -------------------------
# write_uncommitted_diff
#
# Writes uncommitted changes vs HEAD to OUTPUT_FILE.
# Strips git index (blob-hash) metadata lines only, so the patch carries the
# exact source bytes (trailing whitespace, CRLF, no-newline-at-EOF preserved)
# and generation/application stay consistent. Stages untracked files
# temporarily (via git add -N) so they appear in the diff, then restores
# staged state after. Writes an empty file if no changes.
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
  _diff_stage_untracked "$SANDBOX_DIR"
  _write_git_diff "$SANDBOX_DIR" HEAD "$OUTPUT_FILE"
  _diff_restore_untracked "$SANDBOX_DIR"
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
  _diff_stage_untracked "$SANDBOX_DIR"
  _write_git_diff "$SANDBOX_DIR" "$INIT_SHA" "$OUTPUT_FILE"
  _diff_restore_untracked "$SANDBOX_DIR"
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

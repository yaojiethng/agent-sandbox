#!/usr/bin/env bash
# libs/package_diff.sh
#
# Package changed files and a unified diff into an output directory.
#
# Produces:
#   <outdir>/changes.diff          — unified diff against baseline, suitable for patch -p1
#   <outdir>/changed-files/        — full copies of every changed file, preserving
#                                    directory structure relative to repo root
#
# Usage:
#   package_diff.sh [--baseline=<sha>] [--name=<label>] [--outdir=<path>]
#
#   --baseline=<sha>   Git ref to diff against.
#                      Inside the container: resolved automatically from INIT_SHA
#                      file in .git/, then first repo commit.
#                      On the host: required; no default applied.
#   --name=<label>     Short snake_case label for the output directory.
#                      Output directory is always <timestamp>-<label>-<SESSION_TS>.
#                      Default: derived from the most-changed path in the diff.
#   --outdir=<path>    Parent directory for output. Default: ~/workspace/output
#                      if that path exists (inside container), otherwise
#                      <repo-root>/.package-diff-output on the host.
#   --session-summary=<text>  Short description for the output folder name.
#                      Default: "snapshot".
#   --session-ts=<ts>  Session timestamp for the output folder name suffix.
#                      Default: derived from SESSION_TS environment variable.
#
# Alias registration (host only — done by agent-sandbox onboard):
#   git config --local alias.package-diff \
#     '!bash $(git rev-parse --show-toplevel)/../agent-sandbox/libs/package_diff.sh'
#
# Inside the container, invoke directly — the alias is not registered in the
# sandbox .git/config:
#   bash ~/sandbox/libs/package_diff.sh [--baseline=<sha>] [--name=<label>]

set -euo pipefail

# -------------------------
# Locate repo root
# -------------------------
if ! REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null); then
  echo "Error: not inside a git repository." >&2
  exit 1
fi

# -------------------------
# Flag parsing
# -------------------------
BASELINE=""
NAME_ARG=""
OUTDIR_ARG=""
SESSION_SUMMARY_ARG=""
SESSION_TS_ARG=""

for ARG in "$@"; do
  case "$ARG" in
    --baseline=*)        BASELINE="${ARG#--baseline=}" ;;
    --name=*)            NAME_ARG="${ARG#--name=}" ;;
    --outdir=*)          OUTDIR_ARG="${ARG#--outdir=}" ;;
    --session-summary=*) SESSION_SUMMARY_ARG="${ARG#--session-summary=}" ;;
    --session-ts=*)      SESSION_TS_ARG="${ARG#--session-ts=}" ;;
    --help)
      grep '^#' "$0" | grep -v '^#!/' | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "Unknown argument: $ARG" >&2
      echo "Usage: package_diff.sh [--baseline=<sha>] [--name=<label>] [--outdir=<path>] [--session-summary=<text>] [--session-ts=<ts>]" >&2
      exit 1
      ;;
  esac
done

# -------------------------
# Detect container context
# -------------------------
IN_CONTAINER=0
[[ -d "$HOME/workspace/output" ]] && IN_CONTAINER=1

# -------------------------
# Resolve and validate baseline
# -------------------------
if [[ -z "$BASELINE" ]]; then
  if [[ -n "${BASELINE_SHA:-}" ]]; then
    BASELINE="$BASELINE_SHA"
  elif [[ -f "$REPO_ROOT/.git/INIT_SHA" ]]; then
    BASELINE=$(cat "$REPO_ROOT/.git/INIT_SHA")
  elif [[ "$IN_CONTAINER" -eq 1 ]]; then
    # Last resort inside container: diff against first commit
    BASELINE=$(git -C "$REPO_ROOT" rev-list --max-parents=0 HEAD)
  else
    echo "Error: --baseline is required when running outside the container." >&2
    echo "  Usage: package_diff.sh --baseline=<sha>" >&2
    echo "  Inside the container, INIT_SHA is written at container init." >&2
    exit 1
  fi
fi

if ! git -C "$REPO_ROOT" rev-parse --verify "$BASELINE^{commit}" >/dev/null 2>&1; then
  echo "Error: baseline ref is not a commit: $BASELINE" >&2
  exit 1
fi

# -------------------------
# Resolve output parent directory
# -------------------------
if [[ -n "$OUTDIR_ARG" ]]; then
  PARENT_DIR="$OUTDIR_ARG"
elif [[ "$IN_CONTAINER" -eq 1 ]]; then
  PARENT_DIR="$HOME/workspace/output"
else
  PARENT_DIR="$REPO_ROOT/.package-diff-output"
fi
mkdir -p "$PARENT_DIR"

# -------------------------
# Resolve session summary
# -------------------------
# SESSION_SUMMARY is a short description for the output folder name.
# Can be set via --session-summary flag, --name flag (legacy alias),
# or defaults to "snapshot".
if [[ -n "$SESSION_SUMMARY_ARG" ]]; then
  SESSION_SUMMARY="$SESSION_SUMMARY_ARG"
elif [[ -n "$NAME_ARG" ]]; then
  SESSION_SUMMARY="$NAME_ARG"
else
  SESSION_SUMMARY="snapshot"
fi

# -------------------------
# Resolve session timestamp
# -------------------------
SESSION_TS="${SESSION_TS_ARG:-${SESSION_TS:-}}"

# -------------------------
# Create output directory
# -------------------------
EXPORT_TIME=$(date -u +%Y%m%d-%H%M%S)
OUTDIR="$PARENT_DIR/diffs/${EXPORT_TIME}-${SESSION_SUMMARY}-${SESSION_TS}"
mkdir -p "$OUTDIR"

# -------------------------
# Check for changes
# -------------------------
UNTRACKED=$(git -C "$REPO_ROOT" ls-files --others --exclude-standard 2>/dev/null || true)

if [[ -z "$(git -C "$REPO_ROOT" diff --name-only "$BASELINE" 2>/dev/null)$UNTRACKED$(git -C "$REPO_ROOT" diff --cached --name-only 2>/dev/null)" ]]; then
  echo "Nothing to package — no changes found relative to $BASELINE." >&2
  rm -rf "$OUTDIR"
  exit 0
fi

# -------------------------
# Generate diff
#
# Produces a unified diff consumable by `patch -p1`. The `index <sha>..<sha>`
# lines emitted by git diff encode blob SHAs that cause `git apply` to reject
# diffs when the index has drifted. Stripping them makes the diff purely
# context-line based — patch applies by matching surrounding lines only,
# which is tolerant of index state and sequential application.
#
# Whitespace normalisation: strip trailing whitespace per line, ensure exactly
# one trailing newline before EOF.
# -------------------------
UNTRACKED_STAGED=()
if [[ -n "$UNTRACKED" ]]; then
  while IFS= read -r F; do
    git -C "$REPO_ROOT" add -N -- "$F" 2>/dev/null && UNTRACKED_STAGED+=("$F")
  done <<< "$UNTRACKED"
fi

git -C "$REPO_ROOT" diff "$BASELINE" \
  | grep -v '^index ' \
  | sed 's/[[:space:]]*$//' \
  | sed -e '$a\' \
  > "$OUTDIR/changes.diff"

if [[ ${#UNTRACKED_STAGED[@]} -gt 0 ]]; then
  git -C "$REPO_ROOT" restore --staged -- "${UNTRACKED_STAGED[@]}" 2>/dev/null || true
fi

DIFF_LINES=$(wc -l < "$OUTDIR/changes.diff" | tr -d ' ')

# -------------------------
# Copy changed files
#
# Copies every modified or untracked file into <outdir>/changed-files/,
# preserving directory structure relative to repo root. Provides full file
# content alongside the diff for manual inspection or recovery.
# -------------------------
CHANGED_FILES_DIR="$OUTDIR/changed-files"
mkdir -p "$CHANGED_FILES_DIR"

CHANGED_FILE_COUNT=0

# Tracked files that differ from baseline
while IFS= read -r F; do
  [[ -z "$F" ]] && continue
  # Skip deleted files — they no longer exist in the working tree
  [[ -f "$REPO_ROOT/$F" ]] || continue
  mkdir -p "$CHANGED_FILES_DIR/$(dirname "$F")"
  cp "$REPO_ROOT/$F" "$CHANGED_FILES_DIR/$F"
  CHANGED_FILE_COUNT=$((CHANGED_FILE_COUNT + 1))
done < <(git -C "$REPO_ROOT" diff --name-only "$BASELINE" 2>/dev/null || true)

# Staged files not yet in the diff above
while IFS= read -r F; do
  [[ -z "$F" ]] && continue
  # Skip if already copied (may overlap with diff --name-only)
  [[ -f "$CHANGED_FILES_DIR/$F" ]] && continue
  # Skip deleted files — they no longer exist in the working tree
  [[ -f "$REPO_ROOT/$F" ]] || continue
  mkdir -p "$CHANGED_FILES_DIR/$(dirname "$F")"
  cp "$REPO_ROOT/$F" "$CHANGED_FILES_DIR/$F"
  CHANGED_FILE_COUNT=$((CHANGED_FILE_COUNT + 1))
done < <(git -C "$REPO_ROOT" diff --cached --name-only 2>/dev/null || true)

# Untracked files
if [[ -n "$UNTRACKED" ]]; then
  while IFS= read -r F; do
    [[ -z "$F" ]] && continue
    # Skip if already copied (shouldn't overlap, but be safe)
    [[ -f "$CHANGED_FILES_DIR/$F" ]] && continue
    mkdir -p "$CHANGED_FILES_DIR/$(dirname "$F")"
    cp "$REPO_ROOT/$F" "$CHANGED_FILES_DIR/$F"
    CHANGED_FILE_COUNT=$((CHANGED_FILE_COUNT + 1))
  done <<< "$UNTRACKED"
fi

# Remove changed-files dir if empty (shouldn't happen given the earlier
# no-changes check, but be defensive)
if [[ "$CHANGED_FILE_COUNT" -eq 0 ]]; then
  rmdir "$CHANGED_FILES_DIR" 2>/dev/null || true
fi

# -------------------------
# Summary
# -------------------------
echo "Output directory: $OUTDIR"
echo "Diff size:        ${DIFF_LINES} lines"
if [[ "$CHANGED_FILE_COUNT" -gt 0 ]]; then
  echo "Changed files:    ${CHANGED_FILE_COUNT}"
fi
echo ""
echo "Contents:"
echo "  $OUTDIR/changes.diff"
if [[ "$CHANGED_FILE_COUNT" -gt 0 ]]; then
  echo "  $OUTDIR/changed-files/  (${CHANGED_FILE_COUNT} files)"
fi

#!/usr/bin/env bash
# libs/package_diff.sh
#
# Package uncommitted changes into an output directory.
#
# Produces:
#   <outdir>/uncommitted.diff      — unified diff of uncommitted changes vs HEAD
#   <outdir>/changed-files/        — full copies of every changed file, preserving
#                                    directory structure relative to repo root
#
# Usage:
#   package_diff.sh [--name=<label>] [--outdir=<path>]
#
#   --name=<label>     Short snake_case label for the output directory.
#                      Output directory is always <timestamp>-<label>-<SESSION_TS>.
#                      Default: derived from the most-changed path in the diff.
#   --outdir=<path>    Parent directory for output. Default: ~/workspace/output
#                      if that path exists (inside container), otherwise
#                      <repo-root>/.package-diff-output on the host.
#   --session-summary=<text>  Short description for the output folder name.
#                      Default: "snapshot".
#   --session-ts=<ts>  Session timestamp for the output folder name suffix.
#                      Default: derived from SESSION_STATE or SESSION_TS env var.
#
# Alias registration (host only — done by agent-sandbox onboard):
#   git config --local alias.package-diff \
#     '!bash $(git rev-parse --show-toplevel)/../agent-sandbox/libs/package_diff.sh'
#
# Inside the container, invoke directly — the alias is not registered in the
# sandbox .git/config:
#   bash ~/sandbox/libs/package_diff.sh [--name=<label>]

set -euo pipefail

# -------------------------
# Source shared session infrastructure
# -------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/session.sh"
source "$SCRIPT_DIR/diff.sh"

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
NAME_ARG=""
OUTDIR_ARG=""
SESSION_SUMMARY_ARG=""
SESSION_TS_ARG=""

for ARG in "$@"; do
  case "$ARG" in
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
      echo "Usage: package_diff.sh [--name=<label>] [--outdir=<path>] [--session-summary=<text>] [--session-ts=<ts>]" >&2
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
if [[ -n "$SESSION_TS_ARG" ]]; then
  SESSION_TS="$SESSION_TS_ARG"
else
  SESSION_TS=$(session_state_read "$REPO_ROOT" "session_ts")
  if [[ -z "$SESSION_TS" ]]; then
    SESSION_TS="${SESSION_TS:-}"
  fi
fi

# -------------------------
# Create output directory
# -------------------------
EXPORT_TIME=$(date -u +%Y%m%d-%H%M%S)
if [[ -n "$SESSION_TS" ]]; then
  OUTDIR="$PARENT_DIR/diffs/${EXPORT_TIME}-${SESSION_SUMMARY}-${SESSION_TS}"
else
  OUTDIR="$PARENT_DIR/diffs/${EXPORT_TIME}-${SESSION_SUMMARY}"
fi
mkdir -p "$OUTDIR"

# -------------------------
# Check for changes
# -------------------------
UNTRACKED=$(git -C "$REPO_ROOT" ls-files --others --exclude-standard 2>/dev/null || true)

if [[ -z "$(git -C "$REPO_ROOT" diff --name-only HEAD 2>/dev/null)$UNTRACKED$(git -C "$REPO_ROOT" diff --cached --name-only 2>/dev/null)" ]]; then
  echo "Nothing to package — no uncommitted changes found." >&2
  rm -rf "$OUTDIR"
  exit 0
fi

# -------------------------
# Generate uncommitted diff
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

git -C "$REPO_ROOT" diff HEAD \
  | grep -v '^index ' \
  | sed 's/[[:space:]]*$//' \
  | sed -e '$a\' \
  > "$OUTDIR/uncommitted.diff"

if [[ ${#UNTRACKED_STAGED[@]} -gt 0 ]]; then
  git -C "$REPO_ROOT" restore --staged -- "${UNTRACKED_STAGED[@]}" 2>/dev/null || true
fi

DIFF_LINES=$(wc -l < "$OUTDIR/uncommitted.diff" | tr -d ' ')

# -------------------------
# Copy changed files
#
# Delegates to write_changed_files in diff.sh for a unified implementation.
# Uses HEAD as the reference commit since package_diff captures uncommitted
# changes only.
# -------------------------
write_changed_files "$REPO_ROOT" HEAD "$OUTDIR"

# Derive count from manifest for summary
CHANGED_FILE_COUNT=0
if [[ -f "$OUTDIR/changed-files/MANIFEST.txt" ]]; then
  CHANGED_FILE_COUNT=$(grep -c '^.' "$OUTDIR/changed-files/MANIFEST.txt" 2>/dev/null || echo 0)
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
echo "  $OUTDIR/uncommitted.diff"
if [[ "$CHANGED_FILE_COUNT" -gt 0 ]]; then
  echo "  $OUTDIR/changed-files/  (${CHANGED_FILE_COUNT} files)"
fi

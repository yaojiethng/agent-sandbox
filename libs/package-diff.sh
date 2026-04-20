#!/usr/bin/env bash
# libs/package-diff.sh
#
# Package changed files and a unified diff into an output directory.
#
# Produces:
#   <outdir>/changes.diff          — unified diff against baseline
#   <outdir>/changed-files/        — copies of changed files, repo-relative paths
#
# Usage:
#   package-diff.sh [--baseline=<sha>] [--label=<name>] [--outdir=<path>]
#
#   --baseline=<sha>   Git ref to diff against. Default: HEAD (uncommitted changes).
#                      Pass BASELINE_SHA for full session artefacts.
#   --label=<name>     Short snake_case label for the output directory.
#                      Default: derived from the most-changed path in the diff.
#   --outdir=<path>    Parent directory for output. Default: ~/workspace/output
#                      if that path exists (inside container), otherwise
#                      <repo-root>/.package-diff-output on the host.
#
# Registration as a local git alias (done by agent-sandbox onboard):
#   git config --local alias.package-diff \
#     '!bash $(git rev-parse --show-toplevel)/../agent-sandbox/libs/package-diff.sh'
#
# Then invoke as: git package-diff [--baseline=<sha>] [--label=<name>]

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
LABEL_ARG=""
OUTDIR_ARG=""

for ARG in "$@"; do
  case "$ARG" in
    --baseline=*) BASELINE="${ARG#--baseline=}" ;;
    --label=*)    LABEL_ARG="${ARG#--label=}" ;;
    --outdir=*)   OUTDIR_ARG="${ARG#--outdir=}" ;;
    *)
      echo "Unknown argument: $ARG" >&2
      echo "Usage: package-diff.sh [--baseline=<sha>] [--label=<name>] [--outdir=<path>]" >&2
      exit 1
      ;;
  esac
done

# -------------------------
# Resolve and validate baseline
# -------------------------
# Inside the container: env var → .git/BASELINE_SHA file → error
# On the host: --baseline is required; no default applied
if [[ -z "$BASELINE" ]]; then
  # No explicit --baseline. Try container context.
  if [[ -n "${BASELINE_SHA:-}" ]]; then
    BASELINE="$BASELINE_SHA"
  elif [[ -f "$REPO_ROOT/.git/BASELINE_SHA" ]]; then
    BASELINE=$(cat "$REPO_ROOT/.git/BASELINE_SHA")
  else
    # Not inside a container context — require explicit baseline.
    echo "Error: --baseline is required when running outside the container." >&2
    echo "  Usage: package-diff.sh --baseline=<sha>" >&2
    echo "  Inside the container, BASELINE_SHA is set automatically." >&2
    exit 1
  fi
fi

if ! git -C "$REPO_ROOT" rev-parse --verify "$BASELINE" >/dev/null 2>&1; then
  echo "Error: baseline ref not found: $BASELINE" >&2
  exit 1
fi

# -------------------------
# Resolve output parent directory
# -------------------------
if [[ -n "$OUTDIR_ARG" ]]; then
  PARENT_DIR="$OUTDIR_ARG"
elif [[ -d "$HOME/workspace/output" ]]; then
  # Inside container
  PARENT_DIR="$HOME/workspace/output"
else
  # On host
  PARENT_DIR="$REPO_ROOT/.package-diff-output"
fi
mkdir -p "$PARENT_DIR"

# -------------------------
# Derive label
# -------------------------
if [[ -n "$LABEL_ARG" ]]; then
  LABEL="$LABEL_ARG"
else
  # Derive from the most-changed path in the diff.
  # Take the top entry from --stat, extract the path, use its directory or
  # filename (without extension), slugify to snake_case.
  TOP_PATH=$(git -C "$REPO_ROOT" diff --stat "$BASELINE" \
    | head -n -1 \
    | sort -t'|' -k2 -rn \
    | head -n1 \
    | awk '{print $1}' \
    | tr -d ' ')

  if [[ -z "$TOP_PATH" ]]; then
    # No committed diff — check working tree
    TOP_PATH=$(git -C "$REPO_ROOT" diff --name-only \
      | head -n1)
  fi

  if [[ -z "$TOP_PATH" ]]; then
    LABEL="uncommitted_changes"
  else
    # Use the deepest meaningful path component: prefer filename without
    # extension, fall back to parent directory name.
    BASENAME=$(basename "$TOP_PATH")
    STEM="${BASENAME%.*}"
    if [[ -n "$STEM" && "$STEM" != "$BASENAME" ]]; then
      RAW_LABEL="$STEM"
    else
      RAW_LABEL="$(basename "$(dirname "$TOP_PATH")")"
    fi
    # Slugify: lowercase, replace non-alphanumeric with underscore, collapse runs
    LABEL=$(echo "$RAW_LABEL" \
      | tr '[:upper:]' '[:lower:]' \
      | sed 's/[^a-z0-9]/_/g' \
      | sed 's/__*/_/g' \
      | sed 's/^_//;s/_$//')
    [[ -z "$LABEL" ]] && LABEL="changes"
  fi
fi

# -------------------------
# Create output directory
# -------------------------
TIMESTAMP=$(date -u +%Y%m%d%H%M%S)
if [[ -n "$NAME_ARG" ]]; then
  OUTDIR="$PARENT_DIR/${NAME_ARG}"
else
  OUTDIR="$PARENT_DIR/${TIMESTAMP}-${LABEL}"
fi
mkdir -p "$OUTDIR/changed-files"

# -------------------------
# Enumerate changed files
# -------------------------
# Files changed relative to baseline (committed and staged)
COMMITTED=$(git -C "$REPO_ROOT" diff --name-only "$BASELINE" 2>/dev/null || true)
# Staged changes not yet in a commit (only relevant when baseline is HEAD)
STAGED=$(git -C "$REPO_ROOT" diff --cached --name-only 2>/dev/null || true)
# Untracked files
UNTRACKED=$(git -C "$REPO_ROOT" ls-files --others --exclude-standard 2>/dev/null || true)

# Deduplicate and sort
ALL_FILES=$(printf '%s\n' $COMMITTED $STAGED $UNTRACKED \
  | sort -u \
  | grep -v '^$' || true)

if [[ -z "$ALL_FILES" ]]; then
  echo "Nothing to package — no changes found relative to $BASELINE." >&2
  rm -rf "$OUTDIR"
  exit 0
fi

# -------------------------
# Copy changed files
# -------------------------
FILE_COUNT=0
while IFS= read -r F; do
  SRC="$REPO_ROOT/$F"
  if [[ ! -f "$SRC" ]]; then
    # File was deleted — skip copy, will appear in diff
    continue
  fi
  DEST="$OUTDIR/changed-files/$F"
  mkdir -p "$(dirname "$DEST")"
  cp -- "$SRC" "$DEST"
  (( FILE_COUNT++ )) || true
done <<< "$ALL_FILES"

# -------------------------
# Generate diff
# -------------------------
# Stage untracked files with --intent-to-add so they appear in the diff,
# then unstage after. This avoids actually staging them.
UNTRACKED_STAGED=()
if [[ -n "$UNTRACKED" ]]; then
  while IFS= read -r F; do
    git -C "$REPO_ROOT" add -N -- "$F" 2>/dev/null && UNTRACKED_STAGED+=("$F")
  done <<< "$UNTRACKED"
fi

git -C "$REPO_ROOT" diff "$BASELINE" > "$OUTDIR/changes.diff"

# Unstage any intent-to-add files
if [[ ${#UNTRACKED_STAGED[@]} -gt 0 ]]; then
  git -C "$REPO_ROOT" restore --staged -- "${UNTRACKED_STAGED[@]}" 2>/dev/null || true
fi

DIFF_LINES=$(wc -l < "$OUTDIR/changes.diff" | tr -d ' ')

# -------------------------
# Summary
# -------------------------
echo "Output directory: $OUTDIR"
echo "Changed files:    $FILE_COUNT copied"
echo "Diff size:        ${DIFF_LINES} lines"
echo ""
echo "Contents:"
echo "  $OUTDIR/changes.diff"
echo "  $OUTDIR/changed-files/  ($FILE_COUNT files)"

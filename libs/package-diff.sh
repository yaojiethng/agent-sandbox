#!/usr/bin/env bash
# libs/package-diff.sh
#
# Package changed files and a unified diff into an output directory.
#
# Produces:
#   <outdir>/changes.diff          — unified diff against baseline, suitable for patch -p1
#
# Usage:
#   package-diff.sh [--baseline=<sha>] [--name=<label>] [--outdir=<path>]
#
#   --baseline=<sha>   Git ref to diff against.
#                      Inside the container: resolved automatically from BASELINE_SHA
#                      env var, then .git/BASELINE_SHA, then first repo commit.
#                      On the host: required; no default applied.
#   --name=<label>     Short snake_case label for the output directory.
#                      Output directory is always <timestamp>-<label>.
#                      Default: derived from the most-changed path in the diff.
#   --outdir=<path>    Parent directory for output. Default: ~/workspace/output
#                      if that path exists (inside container), otherwise
#                      <repo-root>/.package-diff-output on the host.
#
# Alias registration (host only — done by agent-sandbox onboard):
#   git config --local alias.package-diff \
#     '!bash $(git rev-parse --show-toplevel)/../agent-sandbox/libs/package-diff.sh'
#
# Inside the container, invoke directly — the alias is not registered in the
# sandbox .git/config:
#   bash ~/sandbox/libs/package-diff.sh [--baseline=<sha>] [--name=<label>]

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

for ARG in "$@"; do
  case "$ARG" in
    --baseline=*) BASELINE="${ARG#--baseline=}" ;;
    --name=*)     NAME_ARG="${ARG#--name=}" ;;
    --outdir=*)   OUTDIR_ARG="${ARG#--outdir=}" ;;
    --help)
      grep '^#' "$0" | grep -v '^#!/' | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "Unknown argument: $ARG" >&2
      echo "Usage: package-diff.sh [--baseline=<sha>] [--name=<label>] [--outdir=<path>]" >&2
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
  elif [[ -f "$REPO_ROOT/.git/BASELINE_SHA" ]]; then
    BASELINE=$(cat "$REPO_ROOT/.git/BASELINE_SHA")
  elif [[ "$IN_CONTAINER" -eq 1 ]]; then
    # Last resort inside container: diff against first commit
    BASELINE=$(git -C "$REPO_ROOT" rev-list --max-parents=0 HEAD)
  else
    echo "Error: --baseline is required when running outside the container." >&2
    echo "  Usage: package-diff.sh --baseline=<sha>" >&2
    echo "  Inside the container, BASELINE_SHA is set automatically." >&2
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
# Derive label
# -------------------------
if [[ -n "$NAME_ARG" ]]; then
  LABEL="$NAME_ARG"
else
  # Derive from the most-changed path in the diff.
  TOP_PATH=$(git -C "$REPO_ROOT" diff --stat "$BASELINE" \
    | sed '$d' \
    | sort -t'|' -k2 -rn \
    | head -n1 \
    | awk -F'|' '{print $1}' \
    | tr -d ' ')

  if [[ -z "$TOP_PATH" ]]; then
    TOP_PATH=$(git -C "$REPO_ROOT" diff --name-only | head -n1)
  fi

  if [[ -z "$TOP_PATH" ]]; then
    LABEL="uncommitted_changes"
  else
    BASENAME=$(basename "$TOP_PATH")
    STEM="${BASENAME%.*}"
    if [[ -n "$STEM" && "$STEM" != "$BASENAME" ]]; then
      RAW_LABEL="$STEM"
    else
      RAW_LABEL="$(basename "$(dirname "$TOP_PATH")")"
    fi
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
OUTDIR="$PARENT_DIR/${TIMESTAMP}-${LABEL}"
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
# Summary
# -------------------------
echo "Output directory: $OUTDIR"
echo "Diff size:        ${DIFF_LINES} lines"
echo ""
echo "Contents:"
echo "  $OUTDIR/changes.diff"

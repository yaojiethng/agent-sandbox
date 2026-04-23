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
# Captures uncommitted changes, commits pending changes, generates staged.diff,
# produces format-patch output, and calls package_branch. Called by the EXIT trap
# in sandbox-entrypoint.sh.
# SESSION_TS and SANITIZED_HOST_BRANCH are required — artefacts are written
# under CHANGES_DIR/<EXPORT_TIME>-<SANITIZED_HOST_BRANCH>-<SESSION_TS>/.
# EXPORT_TIME is generated at call time, distinct from SESSION_TS to support
# multiple exports within a session.
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

  local EXPORT_TIME
  EXPORT_TIME=$(date -u +%Y%m%d-%H%M%S)
  local OUTPUT_DIR="${CHANGES_DIR}/${EXPORT_TIME}-${SANITIZED_HOST_BRANCH}-${SESSION_TS}"
  mkdir -p "$OUTPUT_DIR"

  # Capture uncommitted changes BEFORE committing (writes to session dir)
  if git -C "$SANDBOX_DIR" diff --quiet HEAD; then
    echo "diff_on_exit: no uncommitted changes" >&2
    > "$OUTPUT_DIR/changes.diff"
  else
    git -C "$SANDBOX_DIR" diff HEAD \
      | grep -v '^index ' \
      | sed 's/[[:space:]]*$//' \
      | sed -e '$a\' \
      > "$OUTPUT_DIR/changes.diff"
  fi

  echo "diff_on_exit: staging final diff..." >&2
  diff_commit_pending "$SANDBOX_DIR"
  diff_generate "$SANDBOX_DIR" "$BASELINE_SHA" "${OUTPUT_DIR}/staged.diff"
  diff_format_patch "$SANDBOX_DIR" "$BASELINE_SHA" "${OUTPUT_DIR}/patches"

  # Call package_branch to produce numbered .diff files
  local INIT_SHA=""
  if [[ -f "${SANDBOX_DIR}/.git/INIT_SHA" ]]; then
    INIT_SHA=$(cat "${SANDBOX_DIR}/.git/INIT_SHA")
  else
    echo "diff_on_exit: INIT_SHA not found, skipping package_branch" >&2
  fi

  if [[ -n "$INIT_SHA" ]]; then
    # Source package_branch.sh to get the package_branch function
    source /libs/package_branch.sh

    local BRANCH_NAME
    BRANCH_NAME=$(git -C "$SANDBOX_DIR" rev-parse --abbrev-ref HEAD)
    # Handle detached HEAD
    if [[ "$BRANCH_NAME" == "HEAD" ]]; then
      BRANCH_NAME=$(git -C "$SANDBOX_DIR" rev-parse --short HEAD)
    fi
    package_branch "$SANDBOX_DIR" "$INIT_SHA" "$CHANGES_DIR" "$BRANCH_NAME"
  fi
}

# -------------------------
# diff_on_autosave
#
# Generates autosave.diff without committing pending changes.
# The agent is still running; committing here would interfere
# with the agent's own git operations.
# SESSION_TS and SANITIZED_HOST_BRANCH are required — autosave.diff is written
# under CHANGES_DIR/<EXPORT_TIME>-<SANITIZED_HOST_BRANCH>-<SESSION_TS>/.
# Called by the autosave loop in sandbox-entrypoint.sh.
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

  local EXPORT_TIME
  EXPORT_TIME=$(date -u +%Y%m%d-%H%M%S)
  local OUTPUT_DIR="${CHANGES_DIR}/${EXPORT_TIME}-${SANITIZED_HOST_BRANCH}-${SESSION_TS}"
  mkdir -p "$OUTPUT_DIR"

  echo "diff_on_autosave: writing checkpoint diff..." >&2
  diff_generate "$SANDBOX_DIR" "$BASELINE_SHA" "${OUTPUT_DIR}/autosave.diff"
}

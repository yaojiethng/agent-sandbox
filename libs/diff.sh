#!/usr/bin/env bash
# libs/diff.sh
# Diff pipeline functions for agent-sandbox.
# Sourced by sandbox-entrypoint.sh (capability layer).
#
# Functions:
#   diff_commit_pending  SANDBOX_DIR
#   diff_generate        SANDBOX_DIR  BASELINE_SHA  OUTPUT_FILE
#   diff_format_patch    SANDBOX_DIR  BASELINE_SHA  PATCHES_DIR
#   diff_on_exit         SANDBOX_DIR  BASELINE_SHA  CHANGES_DIR [SESSION_NAME]
#   diff_on_autosave     SANDBOX_DIR  BASELINE_SHA  CHANGES_DIR [SESSION_NAME]

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
# Commits pending changes, generates staged.diff, and produces format-patch
# output. Called by the EXIT trap in sandbox-entrypoint.sh.
# SESSION_NAME is optional; if provided, artefacts are written under
# CHANGES_DIR/<session-name>/ for session-scoped organisation.
# If SESSION_NAME is empty, falls back to CHANGES_DIR/ root (backwards compat).
# -------------------------
diff_on_exit() {
  local SANDBOX_DIR="$1"
  local BASELINE_SHA="$2"
  local CHANGES_DIR="$3"
  local SESSION_NAME="${4:-}"

  if [[ -z "$SANDBOX_DIR" || -z "$BASELINE_SHA" || -z "$CHANGES_DIR" ]]; then
    echo "diff_on_exit: SANDBOX_DIR, BASELINE_SHA, and CHANGES_DIR are required" >&2
    return 1
  fi

  # Determine output directory based on SESSION_NAME
  local OUTPUT_DIR
  if [[ -n "$SESSION_NAME" ]]; then
    OUTPUT_DIR="${CHANGES_DIR}/${SESSION_NAME}"
    mkdir -p "$OUTPUT_DIR"
  else
    OUTPUT_DIR="$CHANGES_DIR"
  fi

  echo "diff_on_exit: staging final diff..." >&2
  diff_commit_pending "$SANDBOX_DIR"
  diff_generate "$SANDBOX_DIR" "$BASELINE_SHA" "${OUTPUT_DIR}/staged.diff"
  diff_format_patch "$SANDBOX_DIR" "$BASELINE_SHA" "${OUTPUT_DIR}/patches"
}

# -------------------------
# diff_on_autosave
#
# Generates autosave.diff without committing pending changes.
# The agent is still running; committing here would interfere
# with the agent's own git operations.
# SESSION_NAME is optional; if provided, autosave.diff is written under
# CHANGES_DIR/<session-name>/ for session-scoped organisation.
# If SESSION_NAME is empty, falls back to CHANGES_DIR/ root (backwards compat).
# Called by the autosave loop in sandbox-entrypoint.sh.
# -------------------------
diff_on_autosave() {
  local SANDBOX_DIR="$1"
  local BASELINE_SHA="$2"
  local CHANGES_DIR="$3"
  local SESSION_NAME="${4:-}"

  if [[ -z "$SANDBOX_DIR" || -z "$BASELINE_SHA" || -z "$CHANGES_DIR" ]]; then
    echo "diff_on_autosave: SANDBOX_DIR, BASELINE_SHA, and CHANGES_DIR are required" >&2
    return 1
  fi

  # Determine output directory based on SESSION_NAME
  local OUTPUT_DIR
  if [[ -n "$SESSION_NAME" ]]; then
    OUTPUT_DIR="${CHANGES_DIR}/${SESSION_NAME}"
  else
    OUTPUT_DIR="$CHANGES_DIR"
  fi
  mkdir -p "$OUTPUT_DIR"

  echo "diff_on_autosave: writing checkpoint diff..." >&2
  diff_generate "$SANDBOX_DIR" "$BASELINE_SHA" "${OUTPUT_DIR}/autosave.diff"
}
